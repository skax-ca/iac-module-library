# 예제는 루트 모듈이다 — 모듈과 달리 **상한**을 건다(02 §2).
# 모듈은 하한만 선언하고(aws >= 6.0), 상한은 루트가 lock과 함께 통제한다.
terraform {
  # ⚠️ 이 예제는 모듈 **둘**을 쓰므로 하한도 둘 중 높은 쪽을 따른다.
  #      · modules/eks-cluster → >= 1.9.0  (교차변수 validation)
  #      · modules/vpc         → >= 1.12.0 (D12 동적 prevent_destroy)  ← 이쪽이 결정한다
  #    eks-cluster 모듈만 쓰는 소비자는 1.9로도 충분하다 — 하한은 모듈마다 다르다(02 §2 대장).
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
