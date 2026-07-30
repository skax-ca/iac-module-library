# 예제는 루트 모듈이다 — 모듈과 달리 **상한**을 건다(02 §2).
# 모듈은 하한만 선언하고(aws >= 6.0), 상한은 루트가 lock과 함께 통제한다.
terraform {
  # 모듈이 요구하는 하한과 같다 — D12 동적 prevent_destroy 때문이다(modules/vpc/versions.tf).
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
