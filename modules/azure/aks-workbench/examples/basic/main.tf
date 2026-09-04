# aks-workbench 예제(배포 루트 형태) — vnet과 함께 배선하는 최소 착수 템플릿
#
# 이 예제는 AKS 연동 없이 standalone workbench VM만 보여준다 — aks_cluster_name 등은
# 옵트인이라(README「AKS 연동」절 참조) 최소 착수 형태에는 필요하지 않다.
#
# ⚠️ 실제 배포에서는 identity 생성이 이 root가 아니라 별도 "bootstrap" 계층(사람이
# 저빈도로 수동 실행하는 IaC)에 있어야 한다(aks-cluster examples/basic과 같은 이유).
# 이 예제는 CI가 매 커밋 validate하는 단일 스택이라 편의상 한 파일에 담았을 뿐이다.
#
# ⚠️ 소싱은 상대경로다. 소비 프로젝트는 git tag를 쓴다(README.md 참조).

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.workload}-${var.env}-${var.region_code}-main"
  location = var.location
}

module "vnet" {
  source = "../../../vnet"

  naming = {
    workload    = var.workload
    env         = var.env
    region_code = var.region_code
  }

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = ["10.70.0.0/24"]

  subnet_groups = {
    "workbench" = {
      address_prefixes = ["10.70.0.0/27"]
      nat_routed       = true
    }
  }
}

# aks-workbench 모듈은 identity를 만들지 않는다(README「신원」절 참조).
resource "azurerm_user_assigned_identity" "workbench" {
  name                = "id-${var.workload}-${var.env}-${var.region_code}-workbench-01"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}

module "aks_workbench" {
  source = "../.."

  naming = {
    workload    = var.workload
    env         = var.env
    region_code = var.region_code
  }

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  subnet_id   = module.vnet.subnet_ids_by_group["workbench"]
  identity_id = azurerm_user_assigned_identity.workbench.id

  # SSH가 일상 운영 경로다 — 사무실 공인 IP 예시(README「접속 모델」절 참조). 이 값은
  # 자리표시자이니 실제 apply 전에 소비자 환경의 진짜 CIDR로 바꾼다.
  ssh_ingress_cidrs    = ["203.0.113.0/32"]
  admin_ssh_public_key = var.admin_ssh_public_key

  source_image_reference = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "24.04.202601010"
  }

  # 도구 버전 — 필요한 것만 채운다. null이면 그 슬롯은 설치를 건너뛴다.
  kubectl_version = "v1.35.7"
  helm_version    = "v3.21.3"
}
