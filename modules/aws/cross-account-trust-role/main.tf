# cross-account-trust-role 코어 리소스 — 크로스 계정 신뢰 Role 1개
#
# 이 Role의 AWS 권한은 "assume 가능"뿐이다. 정책은 붙이지 않는다 — 실제 K8s 권한은
# 소비 클러스터(eks-cluster의 access_entries가 매핑하는 kubernetes_groups → RBAC)가 전담한다.
# IAM 정책과 K8s RBAC 두 층을 분리하는 것이 최소 권한 설계다.
#
# 계약: docs/module-catalog.md `cross-account-trust-role` 절

locals {
  enabled = var.enabled

  # Name 태그의 중간 토큰. 소비자가 약어를 타이핑하지 않도록 모듈이 조합한다.
  name_mid = "${var.naming.workload}-${var.naming.env}-${var.naming.region_code}"

  # workbench와 달리 serial 토큰이 없다 — 이 모듈은 purpose당 1개만 만드는 것이 전제라
  # 소비자가 매번 다른 purpose를 명시한다(예: "argocd-hub").
  role_name = "iamr-${local.name_mid}-${var.purpose}"
}

# assume-role trust policy. Principal은 특정 IAM Role/User ARN 목록으로만 한정된다
# (variables.tf의 validation이 계정 root·와일드카드를 plan 단계에서 차단).
#
# ⚠️ 정책 문서를 data.aws_iam_policy_document가 아니라 jsonencode로 만든다 — workbench/iam.tf와
# 같은 이유다: mock_provider 아래서 그 data source는 `json` 속성이 통째로 대체되어(실측: "not a
# JSON object" 에러로 plan 자체가 죽는다) 정책 내용을 검증할 수 없다. 이 모듈은 trust policy가
# 유일한 정책이고 조건·병합이 없는 고정 구조라 data source의 값이 애초에 필요 없다.
resource "aws_iam_role" "this" {
  count = local.enabled ? 1 : 0

  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      # sts:TagSession도 허용해야 한다 — 신뢰하는 주체(허브의 argocd_hub_pod_identity Role)가
      # 이미 Pod Identity로 세션 태그를 받은 채로 이 Role을 체이닝 assume하는데, AWS STS는
      # AssumeRole과 TagSession을 별개 액션으로 검사한다. TagSession을 안 열면 세션 태그가
      # 붙은 assume 시도가 403 "not authorized to perform: sts:TagSession"으로 거부된다
      # (실측, 2026-08-20 — hub→spoke 크로스 계정 ArgoCD 인증 실제 apply 중 발견).
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Principal = { AWS = var.trusted_principal_arns }
    }]
  })

  max_session_duration = var.session_duration_seconds

  tags = merge(var.tags, {
    Name = local.role_name
  })
}
