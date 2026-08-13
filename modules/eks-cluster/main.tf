# EKS 클러스터 facade
#
# 스크래치 모듈이 아니라 커뮤니티 모듈 wrapper다. 여기서 하는 일은 셋이다:
#   ① 소비자 계약을 upstream 변수명으로 번역한다 — upstream rename이 소비 프로젝트로 새지 않게.
#   ② 네이밍 규약을 적용한다 — 소비자가 약어를 타이핑하지 않게.
#   ③ kill switch·삭제 보호를 계약에 얹는다.
#
# ⚠️ upstream 핀은 정확 버전이다. 올릴 때는 CHANGELOG를 읽고 이 파일의 번역이 여전히 성립하는지
#    확인한다 — 그것이 facade가 흡수해야 할 비용이다.
# ⚠️ upstream v21에는 `enable_pod_identity`가 없다. Pod Identity가 기본이라 토글이 사라졌다.
#
# 계약: docs/05-modules.md

locals {
  enabled = var.cluster_enabled

  # Name의 중간 토큰. 소비자가 약어를 타이핑하지 않도록 모듈이 조합한다.
  name_mid     = "${var.naming.workload}-${var.naming.env}-${var.naming.region_code}"
  cluster_name = "eks-${local.name_mid}-${var.purpose}-${var.serial}"

  # ── managed 노드그룹 번역 (facade) ─────────────────────────────────────────
  #
  # 맵 키가 노드그룹의 purpose 토큰이 된다 — vpc 모듈이 subnet_groups 키를 서브넷 purpose로
  # 쓰는 것과 같은 규약이다. serial이 필요하면 소비자가 키에 넣는다(예: "system-01").
  managed_node_groups = {
    for ng_key, ng in var.managed_node_groups : ng_key => {
      name            = "eksn-${local.name_mid}-${ng_key}"
      use_name_prefix = false

      subnet_ids     = var.subnet_ids
      instance_types = ng.instance_types
      min_size       = ng.min_size
      max_size       = ng.max_size
      desired_size   = ng.desired_size
      capacity_type  = ng.capacity_type
      labels         = ng.labels

      # ⚠️ 이 두 줄이 없으면 plan이 죽는다. upstream은 iam_role_use_name_prefix 기본이 true라
      #    role의 name_prefix를 "<노드그룹 이름>-eks-node-group-"으로 만드는데, name_prefix 한도는
      #    38자이고 우리 NG 이름(eksn-demo-prd-an2-system = 24자)이면 40자가 되어 초과한다.
      #    → 이름을 직접 지정해 접미사 자체를 없앤다. IAM role 이름 한도는 64자라 여유가 있다.
      iam_role_name            = "iamr-${local.name_mid}-${ng_key}-node"
      iam_role_use_name_prefix = false

      # 노드 AMI 계열(= CPU 아키텍처). upstream 서브모듈의 ami_type은 nullable = false
      # (기본 AL2023_x86_64_STANDARD)이고 루트가 each.value.ami_type을 **그대로 넘긴다**(실측).
      # 그래서 facade가 optional의 기본값으로 항상 non-null 문자열을 보장한다 — null을 흘리면
      # 하위 모듈에서 "must not be null"로 죽는다.
      # ⚠️ instance_types와 아키텍처를 맞추는 것은 소비자 몫이다(변수 문서). 어긋나도 plan은 통과한다.
      ami_type = ng.ami_type

      # 핀이 있으면 최신 조회를 끈다.
      # ⚠️ upstream eks-managed-node-group은 use_latest_ami_release_version 기본이 true라
      #    release_version = use_latest ? SSM최신 : ami_release_version 으로 갈린다.
      #    파생하지 않으면 ami_release_version을 줘도 **무시되고** 매 plan이 최신을 해석해
      #    노드 롤링 교체를 유발한다(addons의 most_recent 함정과 같은 구조).
      ami_release_version            = ng.ami_release_version
      use_latest_ami_release_version = ng.ami_release_version == null

      # upstream taints는 map(object) 이고 facade는 list다 — 여기서 번역한다.
      # 키를 인덱스로 잡으면 리스트 순서만 바뀌어도 전량 diff가 나므로 (key, effect)를 쓴다.
      # k8s에서 이 쌍은 taint의 자연 식별자다.
      taints = {
        for t in ng.taints : "${t.key}-${lower(replace(t.effect, "_", "-"))}" => t
      }
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.1"

  # upstream이 리소스와 data source를 함께 게이트하므로 kill switch를 이 토글에 위임할 수 있다.
  # count 대신 이 토글을 쓰면 module.eks[0] 인덱싱이 사라져 참조가 단순해진다.
  create = local.enabled

  name               = local.cluster_name # facade: 소비자의 cluster_* 계약 → upstream `name`
  kubernetes_version = var.kubernetes_version
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  enabled_log_types  = var.enabled_log_types

  # AWS 네이티브 삭제 보호. lifecycle prevent_destroy가 필요 없는 이유다.
  deletion_protection = var.deletion_protection

  endpoint_private_access = var.endpoint_private_access
  endpoint_public_access  = var.endpoint_public_access

  # ⚠️ public이 꺼져 있으면 빈 리스트가 아니라 null을 넘긴다.
  #
  # provider 문서 원문: *"Terraform will only perform drift detection of its value
  # **when present in a configuration**."* ⇒ `[]`는 "설정에 있음"이고 `null`만 "없음"이다.
  # 한편 AWS는 public이 꺼진 상태에서 publicAccessCidrs 변경을 **반영하지 않는다**(실측) —
  # 그래서 `[]`를 넘기면 tofu는 계속 지우려 하고 AWS는 안 지워 **영구 diff**가 된다.
  #
  # ⛔ `length(...) > 0`을 조건에 넣지 말 것. 그러면 *public이 켜졌는데 리스트가 빈* 경우까지
  #    null이 되어 **EKS가 0.0.0.0/0으로 여는 것을 더는 감지하지 못한다.** 그 안전망을
  #    diff 편의와 바꾸지 않는다.
  # ⛔ lifecycle ignore_changes 로 풀지 말 것 — 그것은 "어긋나도 눈감는다"이고,
  #    여기 필요한 것은 "public이 꺼졌으니 애초에 관리하지 않는다"다.
  endpoint_public_access_cidrs = var.endpoint_public_access ? var.public_access_cidrs : null

  enable_cluster_creator_admin_permissions = true
  access_entries                           = var.access_entries

  # EKS 접근 3층 — "클러스터가 누구를 네트워크로 받아들이는가".
  # 이 SG는 upstream이 만들어 vpc_config.security_group_ids 에 넣으므로 apiserver ENI 에 적용된다.
  # ⚠️ EKS 가 자동 생성하는 primary cluster SG 와 **다른 SG** 다(outputs.tf 참조).
  security_group_additional_rules = var.cluster_security_group_additional_rules

  # Karpenter discovery는 selector를 **둘** 쓴다: subnetSelectorTerms · securityGroupSelectorTerms.
  # subnet 쪽은 소비자가 vpc 모듈 extra_tags로 붙이고, **SG 쪽은 이 모듈이 붙인다**.
  # ⚠️ PoC에서 SG 태그 누락이 실제 사고였다 — securityGroupSelectorTerms가 빈 결과를 내면
  #    Karpenter 프로비저닝이 실패한다. cluster primary SG가 아니라 **node SG**여야 한다.
  node_security_group_tags = var.enable_karpenter ? {
    "karpenter.sh/discovery" = local.cluster_name
  } : {}

  addons                  = local.addons_final # addons.tf 가 baseline 과 merge 한다
  eks_managed_node_groups = local.managed_node_groups

  tags = var.tags
}

module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter" # ⚠ registry 주소에 /aws 필수
  # 서브모듈 핀은 루트와 같은 버전으로 맞춘다 — 둘이 갈리면 같은 upstream의 두 세대를 동시에 쓰게 된다.
  version = "21.24.1"

  create       = local.enabled && var.enable_karpenter
  cluster_name = module.eks.cluster_name

  # 관리형 정책은 6,144자 한도(조정 불가)를 초과해 LimitExceeded가 난다(PoC 실측, upstream #3563).
  # inline 정책 한도는 10,240자다. 이 값을 끄면 최초 apply가 실패한다.
  enable_inline_policy = true

  # ⚠️ 이름이 결정적이어야 한다. upstream 기본은 `Karpenter-<cluster>-<무작위>` 인데,
  #    GitOps 의 EC2NodeClass.spec.role 이 이 이름을 참조하므로 클러스터를 다시 세우면
  #    접미사가 바뀌어 Karpenter 가 `iam:PassRole` 403 으로 멈춘다.
  #    증상이 교묘하다 — ArgoCD 는 Git 이 요구한 것을 그대로 적용했으니 Synced 로 보고하고,
  #    실패는 한 계층 아래 IAM 에서 난다.
  node_iam_role_name            = "iamr-${local.name_mid}-karpenter-node"
  node_iam_role_use_name_prefix = false

  tags = var.tags
}
