# vnet 예제(배포 루트 형태) — 최소 착수 템플릿
#
# 리소스 그룹과 vnet을 한 apply에서 세운다 — vnet 모듈이 RG를 읽지 않으므로 성립한다
# (docs/decisions.md 「Azure 네트워킹 (vnet)」 ADR의 "명시 답변" 참조).
#
# ⚠️ 소싱은 상대경로다. 소비 프로젝트는 git tag를 쓴다(README.md 참조).

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.workload}-${var.env}-${var.region_code}-main"
  location = var.location
}

module "vnet" {
  source = "../.."

  naming = {
    workload    = var.workload
    env         = var.env
    region_code = var.region_code
  }

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = ["10.60.0.0/24"]

  # app: 아웃바운드 앱 서브넷 — NAT·NSG·라우팅 테이블 전부 옵트인으로 켠다.
  # data: 라우팅 테이블 없이 NAT·NSG만 — 그룹마다 옵트인을 독립적으로 고를 수 있음을 보여준다.
  subnet_groups = {
    "app" = {
      address_prefixes    = ["10.60.0.0/26"]
      nat_routed          = true
      nsg_enabled         = true
      route_table_enabled = true
    }
    "data" = {
      address_prefixes = ["10.60.0.64/26"]
      nat_routed       = true
      nsg_enabled      = true
    }
  }
}
