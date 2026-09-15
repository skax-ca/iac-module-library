# 예제는 루트 모듈이다. 모듈과 달리 **상한**을 건다.
# 모듈은 하한만 선언하고(aws >= 6.0), 상한은 루트가 lock과 함께 통제한다.
terraform {
  # 전 모듈 하한이 1.12.0으로 통일돼 있어 어느 모듈을 쓰든 같은 값이다.
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
