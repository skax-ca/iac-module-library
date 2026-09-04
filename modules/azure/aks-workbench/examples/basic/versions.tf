# 예제는 루트 모듈이다 — 모듈과 달리 상한을 건다.
# 모듈은 하한만 선언하고(azurerm >= 5.0), 상한은 루트가 lock과 함께 통제한다.
terraform {
  required_version = ">= 1.12.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}
