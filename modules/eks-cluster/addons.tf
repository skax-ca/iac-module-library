# addon 관리
#
# 이 파일이 푸는 문제는 하나다: **OpenTofu 변수 default는 전체 대체**라는 것.
# 소비자가 addon 하나를 추가하려고 맵을 넘기면 기본 addon이 통째로 사라지고, 누락분은 in-place
# 삭제된다(coredns 삭제 = DNS 중단). 그래서 baseline을 모듈이 소유하고 소비자 입력과 merge한다 —
# **누락 != 삭제**이고, 제거는 enabled = false 명시로만 일어난다.

# ── AZ 해석 (custom networking용) ─────────────────────────────────────────────
#
# ⚠️ data source도 kill switch 게이트를 지난다. 참조 대상이 사라진 뒤 조회가 살아 있으면
#    plan이 실패해 teardown이 불가능해진다.

data "aws_region" "this" {
  count = local.custom_networking_enabled ? 1 : 0
}

data "aws_subnet" "pod" {
  for_each = local.custom_networking_enabled ? toset(var.pod_subnet_ids) : []

  id = each.value
}

locals {
  custom_networking_enabled = local.enabled && var.enable_custom_networking

  # ── baseline addon ─────────────────────────────────────────────────────────
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

  # ── 버전 소유 경계 ─────────────────────────────────────────────────────────
  #
  # ⛔ 이 파일에 버전 상수 표를 만들지 말 것. 한 번 있었고, 걷어냈다.
  #
  # 모듈이 소유하는 것은 `most_recent = false` 하나다(아래 addons_final). upstream 기본값 true를
  # 끄는 것은 구조적 결정이라 모듈의 몫이고, 그 한 줄이 "매 plan이 최신을 재해석해 리뷰 없이
  # in-place 업데이트"하는 동작을 없앤다.
  #
  # **버전 값은 소비 루트가 소유한다**(`cluster_addons`의 `addon_version`).
  #   ① 경계 — addon 상향은 워크로드 운영 주기에 속한다. 공통 모듈이 값을 들면 고객사 A의
  #      kube-proxy 상향이 모듈 릴리스를 요구하고 그 릴리스가 B·C에게도 간다(CLAUDE.md의
  #      "upstream cadence와 소비자 cadence를 분리한다"를 모듈이 스스로 깨는 구조).
  #   ② 정의역 — addon 버전은 상수가 아니라 f(kubernetes_version, region)이고 두 인자 모두
  #      소비자가 정한다. 두 축 모두 실제 파손이 확인됐다:
  #        k8s  — 1.35 기준 핀을 1.34/1.33에 쓰면 coredns·kube-proxy·metrics-server가 버전 없음
  #        리전 — cert-manager가 an2엔 eksbuild.3, us-east-1·eu-west-1엔 eksbuild.2만 존재
  #
  # 소비자가 값을 안 주면 upstream이 data.aws_eks_addon_version(most_recent = false)로 **그
  # 클러스터의 k8s·리전에 맞는 AWS 기본 버전**을 해석한다(upstream main.tf:759-778 실측).
  # 안전한 기본값이고, 위 두 축 어디에서도 깨지지 않는다.
  #
  # 소비 루트에서 값을 얻는 법은 examples/eks-cluster-enterprise/README.md 참조.

  # vpc-cni는 **노드그룹 생성 전** 적용되어야 초기 노드부터 Pod가 pod 서브넷에 배치된다.
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

  # ebs-csi를 opt-out하면 IAM role도 만들지 않는다. iam.tf가 이 값을 쓴다.
  ebs_csi_enabled = local.enabled && try(local.merged_addons["aws-ebs-csi-driver"].enabled, false)

  # ── 3) custom networking configuration  ───────────────────────────────
  #
  # ENIConfig를 addon의 configuration_values 안에서 만들면 kubernetes_manifest 없이 끝난다 —
  # 즉 "helm/manifest는 GitOps" 경계를 넘지 않는다. 이것이 이 경로를 택한 이유다.
  #
  # ⚠️ securityGroups를 의도적으로 지정하지 않는다. 초기 설계는 "노드 SG 재사용"이었지만
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
  #    모듈 소유 필드가 항상 이기게 한다. vpc-cni의 configuration도 같은 이유다.
  addons_final = {
    for name, cfg in local.merged_addons : name => merge(
      {
        # 모듈이 소유하는 유일한 버전 결정. upstream 기본 true를 끈다.
        # true면 매 plan이 최신 호환 버전을 재조회해 리뷰 없는 in-place 업데이트가 일어난다.
        most_recent = false

        # 버전 **값**은 소비 루트 소유다(위 "버전 소유 경계" 주석).
        # null이면 upstream이 most_recent = false 기준으로 그 클러스터의 k8s·리전에 맞는
        # AWS 기본 버전을 해석한다 — 모듈이 상수를 들 때와 달리 어떤 조합에서도 깨지지 않는다.
        addon_version        = cfg.addon_version
        configuration_values = cfg.configuration
        before_compute       = contains(local.before_compute_addons, name)

        # 소비자 주입 경로 — role 생성은 소비자 소관이다.
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
