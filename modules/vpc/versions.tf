# 최상위 블록은 `terraform`이다. OpenTofu 공식 문서는 이를 "only for compatibility with
# Terraform"으로 규정하고 1.12부터 네이티브 대안 `language {}`를 제공하지만, 채택하지 않았다 —
# 기능적으로 동등한데 Terraform 가독성만 잃기 때문이다(04 §5의 "이유를 남긴다" 기준 미달).
terraform {
  # 하한 1.12.0의 근거는 **D12 동적 prevent_destroy**다 — lifecycle의 prevent_destroy가
  # 입력 변수를 참조할 수 있게 된 버전(OpenTofu 1.12). main.tf의 aws_vpc가 이를 쓴다.
  #   · 1.9  = 교차변수 validation (az_selection ↔ az_count). 이것만이면 1.9로 충분했다
  #   · 1.12 = 동적 prevent_destroy  ← 실제 하한을 결정하는 기능
  # 근거 없는 상향은 소비자만 배제한다 — 02 §2 "모듈별 하한 대장" 참조.
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
