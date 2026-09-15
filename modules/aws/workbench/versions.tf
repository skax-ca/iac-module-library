# 최상위 블록은 `terraform`이다. `tofu {}` 블록은 존재하지 않는다.
terraform {
  # 하한은 전 모듈 공통 규약이다. 실행 지점(예제·소비 루트)이 이미 전부 1.12.0이라
  # 모듈별 하한 분기는 소비자를 배제한 적이 없고 읽는 비용만 냈다.
  # ⚠️ 1.13 이상을 요구하려면 근거가 필요하다.
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 모듈은 하한만 선언한다. 상한은 루트(examples/·소비 프로젝트)가 lock과 함께 통제한다.
      version = ">= 6.0"
    }
  }
}
