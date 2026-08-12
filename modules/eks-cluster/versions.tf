# 최상위 블록은 `terraform`이다. OpenTofu는 1.12부터 네이티브 대안 `language {}`를 제공하지만
# 채택하지 않았다 — 기능적으로 동등한데 Terraform 가독성만 잃는다.
terraform {
  # 하한은 전 모듈 공통 규약이다.
  #
  # ⚠️ 이 모듈이 1.12 기능을 쓰지 않는다는 판정은 **여전히 사실**이다 —
  #    aws_eks_cluster에 네이티브 deletion_protection이 있어 동적 prevent_destroy가 불필요하다.
  #    상향은 그 판정이 뒤집혀서가 아니라 **하한을 모듈별 근거로 정하는 방식 자체를 그만뒀기** 때문이다.
  #    실행 지점(예제·소비 루트)이 이미 전부 1.12.0이라 분기가 소비자를 배제한 적이 없었다.
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
