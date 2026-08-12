# workbench IAM — EKS 접근 1층(주체의 권한)
#
# ⛔ 2층(Access Entry)·3층(cluster SG ingress)은 여기서 만들지 않는다. 그 둘은
#    "클러스터가 누구를 받아들이는가"라서 eks-cluster 모듈이 소유한다 — 허용 소스는
#    소유 모듈이 변수로 파라미터화한다.
#
# ⚠️ 정책 문서를 data.aws_iam_policy_document 가 아니라 jsonencode 로 만든다 — eks-cluster와 다르다.
#    이유는 테스트 가시성이다: mock_provider 아래서 그 data source는 `json` 속성이 통째로 대체되어
#    **정책 내용을 검증할 수 없다**(eks-cluster tests가 실제로 내용을 보지 못하는 이유).
#    이 모듈에서 "권한이 그 클러스터 ARN으로만 한정되는가"는 보안 계약의 핵심이라 가려지면 안 된다.
#    정책 둘 다 몇 줄짜리 고정 구조여서 data source의 값(병합·조건 조립)이 애초에 없다.

resource "aws_iam_role" "this" {
  count = local.enabled ? 1 : 0

  # 카탈로그 `iamr`. purpose 토큰이 곧 용도(workbench)다.
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(var.tags, {
    Name = local.role_name
  })
}

# SSM Session Manager의 전제. Agent가 아웃바운드로 제어 평면에 연결하는 데 필요한 최소 권한이고
# AWS 관리형이다 — 이 계열 정책을 self-author하면 churn을 우리가 떠안는다.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  count = local.enabled ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 파티션을 하드코딩하지 않는다 — GovCloud·중국 리전에서 ARN 접두가 다르다(aws-us-gov·aws-cn).
data "aws_partition" "current" {}

# ── eks:DescribeCluster ───────────────────────────────────────────────────────
#
# `aws eks update-kubeconfig`가 요구하는 유일한 API다. 클러스터 ARN으로 한정해
# "이 workbench는 이 클러스터의 kubeconfig만 만들 수 있다"를 IAM으로 표현한다.
# ⚠️ Resource = "*" 로 넓히면 workbench가 계정의 모든 클러스터에 kubeconfig를 만들 수 있다.
resource "aws_iam_role_policy" "eks_describe" {
  count = local.eks_integration_enabled ? 1 : 0

  # 종속 객체는 약어를 신설하지 않고 부모 이름을 상속한다(약어 카탈로그 규약).
  # ⚠️ inline 정책은 tags를 지원하지 않는다 — 이 이름이 Name 태그가 아니라 식별자 자체다.
  name = "${local.role_name}-eks-policy"
  role = aws_iam_role.this[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "eks:DescribeCluster"
      Resource = var.eks_cluster_arn
    }]
  })
}

# ── 인스턴스 프로파일 ─────────────────────────────────────────────────────────
#
# 인스턴스 프로파일 약어는 카탈로그에 없고 임의 생성은 금지다. 「종속 객체는 약어를 새로 만들지 않고
# 부모 이름을 상속한다」 규약을 적용해 role과 동일한 이름을 쓴다.
# IAM에서 role과 instance profile은 별개 네임스페이스라 충돌하지 않는다.
resource "aws_iam_instance_profile" "this" {
  count = local.enabled ? 1 : 0

  name = local.role_name
  role = aws_iam_role.this[0].name

  tags = merge(var.tags, {
    Name = local.role_name
  })
}
