# 최상위 블록은 `terraform`이다. OpenTofu는 1.12부터 네이티브 대안 `language {}`를 제공하지만
# 채택하지 않았다. 기능적으로 동등한데 Terraform 가독성만 잃는다.
terraform {
  # 하한은 전 모듈 공통 규약이다.
  #
  # ⚠️ 이 모듈 자체는 1.12 기능을 쓰지 않는다. aws_eks_cluster에 네이티브 deletion_protection이
  #    있어 동적 prevent_destroy가 불필요하다. 그래도 하한은 모듈별로 정하지 않고 전 모듈 통일을
  #    따른다. 실행 지점(예제·소비 루트)이 전부 1.12.0이라 이 하한이 소비자를 배제하지 않는다.
  # ⛔ 모듈이 1.12 미만 기능만 쓴다는 이유로 하한을 내리지 않는다. 통일이 규약이다.
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 모듈은 하한만 선언한다. 상한은 루트(examples/·소비 프로젝트)가 lock과 함께 통제한다.
      version = ">= 6.0"
    }
  }
}
