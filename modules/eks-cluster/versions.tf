# 최상위 블록은 `terraform`이다. OpenTofu 공식 문서는 이를 "only for compatibility with
# Terraform"으로 규정하고 1.12부터 네이티브 대안 `language {}`를 제공하지만, 채택하지 않았다 —
# 기능적으로 동등한데 Terraform 가독성만 잃기 때문이다(04 §5의 "이유를 남긴다" 기준 미달).
terraform {
  # D-TOFU-FLOOR(02 §2, 2026-08-05): 전 모듈 하한을 1.12.0으로 통일한다.
  #
  # ⚠️ 이 모듈이 1.12 기능을 쓰지 않는다는 판정은 **여전히 사실**이다(설계 §3.3) —
  #    aws_eks_cluster에 네이티브 deletion_protection이 있어 동적 prevent_destroy가 불필요하다.
  #    상향은 그 판정이 뒤집혀서가 아니라 **하한을 모듈별 근거로 정하는 방식 자체를 그만뒀기** 때문이다.
  #    실행 지점(예제·소비 루트)이 이미 전부 1.12.0이라 분기가 소비자를 배제한 적이 없었다.
  # 🔑 이 값은 한때 1.12.0 → 1.9.0으로 **내려갔던** 자리다(Task 20.1(e)). 통일 이후에는
  #    그런 인하가 다시 일어나지 않는다 — 02 §2가 그것을 D-TOFU-FLOOR의 대가로 명시했다.
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
