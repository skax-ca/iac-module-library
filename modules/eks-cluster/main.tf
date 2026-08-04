# EKS 클러스터 facade — 설계 docs/design/20-eks-module.md §2 · §2.5 · §3
#
# 이 모듈은 스크래치가 아니라 **커뮤니티 모듈 wrapper**다(01 §2.2). 여기서 하는 일은 셋이다:
#   ① 소비자 계약(§3.1)을 upstream 변수명으로 번역한다 — upstream rename이 소비 프로젝트로 새지 않게.
#   ② 네이밍 규약(02 §1.4)을 적용한다 — 소비자가 약어를 타이핑하지 않게.
#   ③ kill switch·삭제 보호를 계약에 얹는다(D-EKS-ENABLED / D-EKS-PROTECT).
#
# ⚠️ upstream 핀은 **정확 버전**이다(02 §2). 올릴 때는 CHANGELOG를 읽고 이 파일의 번역이
#    여전히 성립하는지 확인한다 — 그것이 facade가 흡수해야 할 비용이다.
#
# ── Task 20.1 실물 확인 결과 (2026-08-03, v21.24.1 소스 직독) ──────────────────
#   · 루트 변수: create · name · kubernetes_version · vpc_id · subnet_ids · addons ·
#     eks_managed_node_groups · endpoint_{private,public}_access · endpoint_public_access_cidrs ·
#     access_entries · enable_cluster_creator_admin_permissions · enabled_log_types ·
#     node_security_group_tags · deletion_protection · tags  → 전부 실재
#   · `enable_pod_identity`는 **없다**. v21은 Pod Identity가 기본이라 토글 자체가 사라졌다.
#   · karpenter 출력: iam_role_arn · node_iam_role_{arn,name} · instance_profile_name · queue_name
#   · upstream이 자체 data source까지 local.create로 게이트한다 → kill switch를 create에 위임 가능.

locals {
  enabled = var.cluster_enabled

  # 02 §1.4(b) — Name의 중간 토큰. 소비자가 약어를 타이핑하지 않도록 모듈이 조합한다.
  name_mid     = "${var.naming.workload}-${var.naming.env}-${var.naming.region_code}"
  cluster_name = "eks-${local.name_mid}-${var.purpose}-${var.serial}"

  # ── managed 노드그룹 번역 (facade) ─────────────────────────────────────────
  #
  # 맵 키가 노드그룹의 purpose 토큰이 된다 — vpc 모듈이 subnet_groups 키를 서브넷 purpose로
  # 쓰는 것과 같은 규약이다(10 §1.3). serial이 필요하면 소비자가 키에 넣는다(예: "system-01").
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

      # ⚠️ **이 두 줄이 없으면 plan이 죽는다**(tests가 잡은 실제 결함, 2026-08-03).
      #    upstream은 iam_role_use_name_prefix 기본이 true라 role의 name_prefix를
      #    "<노드그룹 이름>-eks-node-group-"으로 만든다. name_prefix 한도는 38자인데
      #    우리 NG 이름(eksn-acme-prd-an2-system = 24자)이면 40자가 되어 초과한다.
      #    → 카탈로그 이름을 직접 지정해 접미사 자체를 없앤다. IAM role 한도는 64자다.
      #
      #    ⚠️ 이것은 §2.6 "IAM 네이밍 이원화"의 예외가 아니라 **카탈로그 준수**다.
      #       이원화가 허용하는 것은 Karpenter 서브모듈이 만드는 role뿐이다.
      iam_role_name            = "iamr-${local.name_mid}-${ng_key}-node"
      iam_role_use_name_prefix = false

      # D-NODE-ARCH — 노드 AMI 계열(=CPU 아키텍처). upstream 서브모듈의 ami_type은 nullable = false
      # (기본 AL2023_x86_64_STANDARD)이고 루트가 each.value.ami_type을 **그대로 넘긴다**(실측).
      # 그래서 facade가 optional의 기본값으로 항상 non-null 문자열을 보장한다 — null을 흘리면
      # 하위 모듈에서 "must not be null"로 죽는다.
      # ⚠️ instance_types와 아키텍처를 맞추는 것은 소비자 몫이다(변수 문서). 어긋나도 plan은 통과한다.
      ami_type = ng.ami_type

      # D-NODE-AMI-PIN — 핀이 있으면 최신 조회를 끈다.
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

  # D-EKS-ENABLED — upstream이 리소스와 data source를 함께 게이트한다(Task 20.1(e) 확인).
  # count 대신 이 토글을 쓰면 module.eks[0] 인덱싱이 사라져 참조가 단순해진다.
  create = local.enabled

  name               = local.cluster_name # facade: 소비자의 cluster_* 계약 → upstream `name`
  kubernetes_version = var.kubernetes_version
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  enabled_log_types  = var.enabled_log_types

  # D-EKS-PROTECT — AWS 네이티브 보호. lifecycle prevent_destroy가 필요 없는 이유다(versions.tf 참조).
  deletion_protection = var.deletion_protection

  endpoint_private_access      = var.endpoint_private_access
  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.public_access_cidrs

  enable_cluster_creator_admin_permissions = true
  access_entries                           = var.access_entries

  # Karpenter discovery는 selector를 **둘** 쓴다: subnetSelectorTerms · securityGroupSelectorTerms.
  # subnet 쪽은 소비자가 vpc 모듈 extra_tags로 붙이고, **SG 쪽은 이 모듈이 붙인다**.
  # ⚠️ PoC에서 SG 태그 누락이 실제 사고였다 — securityGroupSelectorTerms가 빈 결과를 내면
  #    Karpenter 프로비저닝이 실패한다. cluster primary SG가 아니라 **node SG**여야 한다.
  node_security_group_tags = var.enable_karpenter ? {
    "karpenter.sh/discovery" = local.cluster_name
  } : {}

  addons                  = local.addons_final # addons.tf — §2.6 C′
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

  tags = var.tags
}
