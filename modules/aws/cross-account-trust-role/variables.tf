# cross-account-trust-role 모듈 인터페이스
#
# 관심사 순서: 정체성 → kill switch → 신뢰 principal → 세션 → 태그.
#
# 계약: docs/module-catalog.md

# ── 정체성 ───────────────────────────────────────────────────────────────────

variable "naming" {
  description = <<-EOT
    Name 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로
    소비자는 약어를 직접 타이핑하지 않는다.
    예: {workload = "spoke1", env = "prd", region_code = "an2"} → iamr-spoke1-prd-an2-argocd-hub
  EOT
  type = object({
    workload    = string
    env         = string
    region_code = string
  })
  nullable = false
}

variable "purpose" {
  description = <<-EOT
    Name 태그의 purpose 토큰. 기본값이 없다 = 필수 입력이다.

    ⚠️ 이 모듈은 workbench와 달리 고정 용도(예: "workbench")로 좁히지 않는다 — 여러 목적의
    크로스 계정 신뢰 경계를 만드는 데 재사용되므로 소비자가 매번 명시한다(예: "argocd-hub").
  EOT
  type        = string
  nullable    = false
}

variable "tags" {
  description = <<-EOT
    이 모듈이 만드는 전 리소스에 추가할 태그.
    거버넌스 태그(Workload·Env·Owner 등)는 프로젝트 루트의 provider default_tags 소관이므로
    여기에 반복하지 않는다.
  EOT
  type        = map(string)
  default     = {}
  nullable    = false
}

# ── kill switch ──────────────────────────────────────────────────────────────

variable "enabled" {
  description = <<-EOT
    kill switch(파괴 방향). false면 이 모듈의 전 리소스를 파기한다.
    false일 때 스칼라 출력은 전부 null이 된다.
  EOT
  type        = bool
  default     = true
  nullable    = false
}

# ── 신뢰 principal ───────────────────────────────────────────────────────────

variable "trusted_principal_arns" {
  description = <<-EOT
    이 Role을 assume할 수 있는 IAM Role/User ARN 목록(trust policy의 Principal).

    ⛔ 계정 root(`:root`)나 와일드카드(`*`)는 허용하지 않는다 — 정확히 어느 principal이
    이 신뢰 경계를 넘는지 ARN 단위로 못박는 것이 이 모듈의 존재 이유다(아래 validation).
  EOT
  type        = list(string)
  nullable    = false

  validation {
    condition = alltrue([
      for arn in var.trusted_principal_arns :
      can(regex("^arn:aws:iam::[0-9]{12}:(role|user)/[\\w+=,.@-]+$", arn))
    ])
    error_message = "trusted_principal_arns는 특정 IAM Role/User ARN이어야 한다. 계정 root(':root')·와일드카드('*')는 허용하지 않는다."
  }

  validation {
    # enabled = true인데 아무도 못 믿는 Role은 무의미하다 — 단, 파기 경로(enabled = false)에서는
    # 빈 리스트여도 통과해야 한다. workbench의 eks_cluster_arn 가드와 같은 이유로 같은 형태다:
    # 막으면 "끌 수는 있으나 끈 상태를 유지할 수 없는" 반쪽 kill switch가 된다.
    condition     = length(var.trusted_principal_arns) > 0 || !var.enabled
    error_message = "trusted_principal_arns가 비어 있다 — enabled = true인 상태에서 아무도 assume할 수 없는 Role은 무의미하다."
  }
}

# ── 세션 ─────────────────────────────────────────────────────────────────────

variable "session_duration_seconds" {
  description = "assume-role 세션 최대 지속 시간(초). aws_iam_role의 max_session_duration으로 간다."
  type        = number
  default     = 3600
  nullable    = false
}
