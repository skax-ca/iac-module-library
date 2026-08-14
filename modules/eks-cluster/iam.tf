# 컨트롤러 IAM 전제조건
#
# 원칙: baseline 컨트롤러의 IAM 전제는 **IaC(이 모듈)** 소관이고, **정책은 hand-author하지
# 않는다** — AWS 관리형이나 커뮤니티 큐레이션에 위임한다. self-authored 정책은 churn을 우리가 떠안는다.
#
# 두 갈래로 나뉜다:
#   · AWS 관리형 정책으로 충분한 것(EBS CSI) → 이 파일이 role을 직접 만들고 addon이 association을 건다.
#   · custom 정책이 필요한 것(ALBC · external-dns) → terraform-aws-modules/eks-pod-identity에 위임한다.
#
# 네이밍은 이원화되어 있다(의식적 결정): 이 모듈이 직접 저작하는 role은 약어 카탈로그를 지키고
# (`iamr-*`), Karpenter 서브모듈이 만드는 role은 upstream 기본 네이밍을 수용한다.
# upstream이 iam_role_name·node_iam_role_name·queue_name override를 노출하므로 강제가 아니라
# 선택이며, 필요해지면 fork 없이 변수 주입만으로 전환된다.

# ── EBS CSI Driver  ──────────────────────────────────────────────────
#
# addon을 opt-out하면 role도 만들지 않는다 — 쓰지 않는 role을 남기지 않는다.

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  count = local.ebs_csi_enabled ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type = "Service"
      # Pod Identity의 주체다. EKS Capability(capabilities.eks.amazonaws.com)와 다른 principal이니
      # 혼동하지 않는다 — 둘은 용도가 완전히 다르다.
      identifiers = ["pods.eks.amazonaws.com"]
    }

    # Pod Identity는 세션 태그를 요구하므로 TagSession이 함께 있어야 한다.
    actions = ["sts:AssumeRole", "sts:TagSession"]
  }
}

resource "aws_iam_role" "ebs_csi" {
  count = local.ebs_csi_enabled ? 1 : 0

  # 카탈로그 A.6 `iamr`. purpose 토큰이 곧 용도(ebs-csi)다.
  name               = "iamr-${local.name_mid}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role[0].json

  tags = merge(var.tags, {
    Name = "iamr-${local.name_mid}-ebs-csi"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = local.ebs_csi_enabled ? 1 : 0

  role = aws_iam_role.ebs_csi[0].name
  # AWS 관리형 정책에 위임한다 — self-author 하면 churn 을 우리가 떠안는다.
  # ⚠️ 고객 관리형 KMS 키로 볼륨을 암호화하면 KMS 권한이 더 필요하다.
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ── 컨트롤러 IAM 위임  ────────────────────────────────────────────────
#
# 기본값이 false인 이유: 유휴 role과 불필요한 plan diff를 만들지 않기 위해서다. 소비자 opt-in.
# 컨트롤러의 설치 경로(ALBC = GitOps helm, external-dns = IaC addon)와 무관하게 IAM 메커니즘은
# 동일하다 — standalone Pod Identity association이 서비스 어카운트에 바인딩된다.

module "alb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.8.2"

  create = local.enabled && var.enable_alb_controller_iam

  # use_name_prefix = false 라야 카탈로그 이름이 그대로 쓰인다(기본 true는 접미사를 붙인다).
  name            = "iamr-${local.name_mid}-alb-controller"
  use_name_prefix = false

  # 커뮤니티가 유지보수하는 정책을 쓴다 — ALBC 정책은 길고 자주 바뀌어 hand-author 대상이 아니다.
  attach_aws_lb_controller_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = var.tags
}

module "external_dns_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.8.2"

  create = local.enabled && var.enable_external_dns_iam

  name            = "iamr-${local.name_mid}-external-dns"
  use_name_prefix = false

  attach_external_dns_policy = true
  # ⛔ 이 목록이 비면 upstream이 Resource = "*" 정책을 만들고 AWS가 400으로 거부한다.
  #    variables.tf의 교차변수 validation이 그 조합을 plan에서 먼저 막는다.
  external_dns_hosted_zone_arns = var.external_dns_hosted_zone_arns

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-dns"
      service_account = "external-dns"
    }
  }

  tags = var.tags
}

module "cluster_autoscaler_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.8.2"

  create = local.enabled && var.enable_cluster_autoscaler

  name            = "iamr-${local.name_mid}-cluster-autoscaler"
  use_name_prefix = false

  # least-privilege 정책이 커뮤니티 큐레이션이다 — kubernetes/autoscaler AWS README의 권장 정책과
  # 동일한 조건(SetDesiredCapacity·TerminateInstanceInAutoScalingGroup을 클러스터 소유 ASG로
  # 태그 스코핑)을 upstream이 이미 만든다(cluster_autoscaler.tf 실측).
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  # kube-system·cluster-autoscaler는 공식 요구사항이 아니라 관례다(Karpenter의 kube-system과
  # 달리 APF FlowSchema 같은 근거가 없다) — docs/02-choose-your-path.md에 그대로 기록한다.
  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "cluster-autoscaler"
    }
  }

  tags = var.tags
}
