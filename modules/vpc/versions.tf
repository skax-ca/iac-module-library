# 최상위 블록은 `terraform`이다. OpenTofu 공식 문서는 이를 "only for compatibility with
# Terraform"으로 규정하고 1.12부터 네이티브 대안 `language {}`를 제공하지만, 채택하지 않았다 —
# 기능적으로 동등한데 Terraform 가독성만 잃기 때문이다(04 §5의 "이유를 남긴다" 기준 미달).
terraform {
  # D-TOFU-FLOOR(02 §2, 2026-08-05): 전 모듈 하한 1.12.0 통일. 이 모듈은 **값이 바뀌지 않았다**.
  #
  # 원래 근거는 **D12 동적 prevent_destroy**였다 — lifecycle의 prevent_destroy가 입력 변수를
  # 참조할 수 있게 된 버전(OpenTofu 1.12). main.tf의 aws_vpc가 실제로 이를 쓴다.
  # 그 근거는 지금도 유효하나, 이제 하한을 정하는 것은 개별 근거가 아니라 통일 규약이다.
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 모듈은 하한만 선언한다. 상한은 루트(examples/·소비 프로젝트)가 lock과 함께 통제한다
      # — docs/architecture/02-naming-tagging-and-pinning.md §2.
      version = ">= 6.0"
    }
  }
}
