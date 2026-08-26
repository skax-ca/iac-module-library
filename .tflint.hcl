# tflint 설정 — 컨벤션·provider 오류 정적 검사 (로컬 검증 절차 + CI 게이트)
# 실행: tflint --init (플러그인 설치) → tflint --recursive

plugin "terraform" {
  enabled = true
  preset  = "recommended" # 미사용 선언·deprecated 문법·네이밍 컨벤션 등
}

plugin "aws" {
  enabled = true
  version = "0.48.0" # 정확 핀 (CLAUDE.md 버전 핀 규칙)
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

plugin "azurerm" {
  enabled = true
  version = "0.32.0" # 정확 핀 (CLAUDE.md 버전 핀 규칙)
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
