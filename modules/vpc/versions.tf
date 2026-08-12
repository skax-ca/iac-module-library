# 최상위 블록은 `terraform`이다. OpenTofu는 1.12부터 네이티브 대안 `language {}`를 제공하지만
# 채택하지 않았다 — 기능적으로 동등한데 Terraform 가독성만 잃는다.
terraform {
  # 하한은 전 모듈 공통 규약이다. 이 모듈에는 별도 근거도 있다:
  # main.tf의 aws_vpc가 쓰는 동적 prevent_destroy(입력 변수 참조)가 1.12부터 가능하다.
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 모듈은 하한만 선언한다. 상한은 루트(examples/·소비 프로젝트)가 lock과 함께 통제한다.
      version = ">= 6.0"
    }
  }
}
