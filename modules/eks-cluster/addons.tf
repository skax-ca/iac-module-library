# addon 관리 (C′) — 설계 docs/design/20-eks-module.md §2.6 · §2.5
#
# 이 파일이 푸는 문제는 하나다: **OpenTofu 변수 default는 전체 대체**라는 것.
# 소비자가 addon 하나를 추가하려고 맵을 넘기면 기본 addon이 통째로 사라지고, 누락분은 in-place
# 삭제된다(coredns 삭제 = DNS 중단). 그래서 baseline을 모듈이 소유하고 소비자 입력과 merge한다 —
# **누락 != 삭제**이고, 제거는 enabled = false 명시로만 일어난다.

# ── AZ 해석 (custom networking용) ─────────────────────────────────────────────
#
# ⚠️ data source도 kill switch 게이트를 지난다. 참조 대상이 사라진 뒤 조회가 살아 있으면
#    plan이 실패해 teardown이 불가능해진다(01 §4).

data "aws_region" "this" {
  count = local.custom_networking_enabled ? 1 : 0
}

data "aws_subnet" "pod" {
  for_each = local.custom_networking_enabled ? toset(var.pod_subnet_ids) : []

  id = each.value
}

locals {
  custom_networking_enabled = local.enabled && var.enable_custom_networking

  # ── baseline addon (설계 §2.6 표) ───────────────────────────────────────────
  #
  # core 4종은 비활성화가 차단된다(variables.tf validation). eks-pod-identity-agent가 core인 것은
  # Karpenter·EBS CSI의 association 생존 전제이기 때문이다 — 빠지면 IAM에는 role이 있는데
  # Pod가 자격증명을 못 받는 **조용한 파손**이 된다.
  baseline_addon_names = [
    "vpc-cni",
    "coredns",
    "kube-proxy",
    "eks-pod-identity-agent",
    "aws-ebs-csi-driver",
    "metrics-server",
  ]

  # ── 버전 핀 (D-ADDON-VERSION-PIN) ───────────────────────────────────────────
  #
  # ⏸ **값이 비어 있다(Task 20.1(d) 미완 — AWS 계정 필요).** 핀은 임의값이 아니라
  #      aws eks describe-addon-versions --kubernetes-version <k8s> --addon-name <name>
  #    의 실측 최신 호환 버전이어야 한다. 추측해서 박으면 도입 plan이 no-op이 아니게 되고,
  #    그건 이 결정이 막으려던 것 자체다.
  #
  # ⛔ **핀이 빈 상태로 릴리스하지 않는다** — D-ADDON-VERSION-PIN 위반이다(설계 Task 20.8).
  #    다만 most_recent = false는 지금도 넘기므로 "매 plan마다 최신을 재해석"하는 동작은 이미 꺼진다.
  #
  # k8s 버전을 올릴 때 이 표도 함께 갱신한다. 핀이 뒤처지면 호환되지 않는 조합이 apply된다.
  addon_version_pins = {
    # baseline
    "vpc-cni"                = null
    "coredns"                = null
    "kube-proxy"             = null
    "eks-pod-identity-agent" = null
    "aws-ebs-csi-driver"     = null
    "metrics-server"         = null

    # community tier (§2.6 확장 표) — baseline이 아니라 **소비자 opt-in**이다.
    # 여기에 핀을 두는 이유는 소비자가 cluster_addons로 추가할 때 핀을 상속받게 하기 위해서다.
    # 핀 정책은 baseline과 동일하다(§2.6-6).
    "fluent-bit"               = null
    "kube-state-metrics"       = null
    "prometheus-node-exporter" = null
    "cert-manager"             = null
    "external-dns"             = null
  }

  # vpc-cni는 **노드그룹 생성 전** 적용되어야 초기 노드부터 Pod가 pod 서브넷에 배치된다(§2.5).
  before_compute_addons = ["vpc-cni"]

  # ── 1) baseline 기본값 ──────────────────────────────────────────────────────
  # 소비자 입력(var.cluster_addons)과 같은 shape이어야 merge가 성립한다.
  baseline_addons = {
    for name in local.baseline_addon_names : name => {
      enabled       = true
      addon_version = null
      configuration = null
      pod_identity  = null
    }
  }

  # ── 2) merge — 소비자가 이긴다. 누락은 삭제가 아니다 ────────────────────────
  merged_addons = merge(local.baseline_addons, var.cluster_addons)

  # ebs-csi를 opt-out하면 IAM role도 만들지 않는다(§2.6-4). iam.tf가 이 값을 쓴다.
  ebs_csi_enabled = local.enabled && try(local.merged_addons["aws-ebs-csi-driver"].enabled, false)

  # ── 3) custom networking configuration (§2.5) ───────────────────────────────
  #
  # ENIConfig를 addon의 configuration_values 안에서 만들면 kubernetes_manifest 없이 끝난다 —
  # 즉 §1의 "helm/manifest는 GitOps" 경계를 넘지 않는다. 이것이 이 경로를 택한 이유다.
  #
  # ⚠️ securityGroups를 **의도적으로 지정하지 않는다.** 설계 §2.5는 "노드 SG 재사용"이라 적었지만
  #    module.eks.node_security_group_id를 module.eks의 입력(addons)에 넣으면 **순환 참조**다.
  #    지정하지 않으면 vpc-cni가 primary ENI의 SG를 상속하는데, 그게 곧 노드 SG다 —
  #    설계 의도가 생략으로 달성된다. 별도 SG 요구가 생기면 그때 변수를 연다.
  vpc_cni_configuration = local.custom_networking_enabled ? jsonencode({
    env = {
      AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"
      ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone"
      # custom networking은 primary ENI를 Pod에 쓰지 않아 max-pods가 준다. prefix delegation이 그 보상이다.
      ENABLE_PREFIX_DELEGATION = "true"
    }
    eniConfig = {
      create = true
      # provider 6.x에서 aws_region의 name·id는 deprecated다 — region 속성을 쓴다.
      region = data.aws_region.this[0].region
      subnets = {
        for id, subnet in data.aws_subnet.pod : subnet.availability_zone => { id = id }
      }
    }
  }) : null

  # ── 4) 최종 변환 + 모듈 소유 필드 재주입 ────────────────────────────────────
  #
  # ⚠️ merge()는 shallow다. 소비자가 ebs-csi의 addon_version만 바꿔도 **엔트리가 통째로 교체**되어
  #    모듈이 넣어둔 pod_identity_association이 사라진다. 그래서 merge **뒤에** 다시 덮어써
  #    모듈 소유 필드가 항상 이기게 한다(§2.6-3). vpc-cni의 configuration도 같은 이유다.
  addons_final = {
    for name, cfg in local.merged_addons : name => merge(
      {
        # D-ADDON-VERSION-PIN — upstream 기본 true를 명시적으로 끈다.
        # true면 매 plan이 최신 호환 버전을 조회해 리뷰 없는 in-place 업데이트가 일어난다.
        most_recent = false

        # 소비자가 버전을 주면 그 값이, 안 주면 baseline 핀이 이긴다(§2.6-6).
        # ⚠️ coalesce는 인자가 전부 null이면 오류다. 핀이 아직 비어 있는 현재는 그 경로를 타므로
        #    try로 null을 돌려준다 — null이면 upstream이 most_recent=false 기준 기본 버전을 쓴다.
        addon_version        = try(coalesce(cfg.addon_version, local.addon_version_pins[name]), null)
        configuration_values = cfg.configuration
        before_compute       = contains(local.before_compute_addons, name)

        # 소비자 주입 경로(§2.6-5) — role 생성은 소비자 소관이다.
        pod_identity_association = cfg.pod_identity != null ? [cfg.pod_identity] : null
      },

      # 재주입 ①: vpc-cni custom networking 구성은 모듈 소유다.
      name == "vpc-cni" && local.custom_networking_enabled
      ? { configuration_values = local.vpc_cni_configuration }
      : {},

      # 재주입 ②: EBS CSI의 association은 모듈이 만든 role을 가리킨다.
      name == "aws-ebs-csi-driver" && local.ebs_csi_enabled
      ? {
        pod_identity_association = [{
          role_arn        = aws_iam_role.ebs_csi[0].arn
          service_account = "ebs-csi-controller-sa"
        }]
      }
      : {},
    )
    if cfg.enabled
  }
}
