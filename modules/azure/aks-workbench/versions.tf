terraform {
  required_version = ">= 1.12.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # 모듈은 하한만 선언한다. 상한은 루트(examples/·소비 프로젝트)가 lock과 함께 통제한다.
      version = ">= 5.0"
    }
  }
}
