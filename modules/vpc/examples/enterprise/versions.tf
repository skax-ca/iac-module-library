# 예제는 루트 모듈이다 — 모듈과 달리 **상한**을 건다.
# 모듈은 하한만 선언하고(aws >= 6.0), 상한은 루트가 lock과 함께 통제한다.
terraform {
  # 전 모듈 공통 하한. vpc의 원래 근거였던 동적 prevent_destroy도
  # 여전히 1.12를 요구하므로 값은 그대로다 — 바뀐 것은 그 값을 **무엇이 정하는가**다.
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
