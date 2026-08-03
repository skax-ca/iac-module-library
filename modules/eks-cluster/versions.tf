# 최상위 블록은 `terraform`이다. OpenTofu 공식 문서는 이를 "only for compatibility with
# Terraform"으로 규정하고 1.12부터 네이티브 대안 `language {}`를 제공하지만, 채택하지 않았다 —
# 기능적으로 동등한데 Terraform 가독성만 잃기 때문이다(04 §5의 "이유를 남긴다" 기준 미달).
terraform {
  # 하한 1.9.0은 **기준선**이다 — 근거는 교차변수 validation(deletion_protection ↔ cluster_enabled).
  #
  # ⚠️ vpc 모듈은 1.12.0이지만 이 모듈은 아니다. vpc는 D12 동적 prevent_destroy를 쓰고,
  #    이 모듈은 쓰지 않기 때문이다 — aws_eks_cluster에는 **네이티브 deletion_protection 인자**가
  #    있어서 lifecycle에 기댈 필요가 없다(설계 §3.3, Task 20.1(e) 확인).
  #    "다른 모듈이 1.12니까 여기도"는 근거가 아니다. 근거 없는 상향은 소비자만 배제한다(02 §2).
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 모듈은 하한만 선언한다. 상한은 루트(examples/·소비 프로젝트)가 lock과 함께 통제한다
      # — docs/architecture/02-naming-tagging-and-pinning.md §2.
      version = ">= 6.0"
    }
  }
}
