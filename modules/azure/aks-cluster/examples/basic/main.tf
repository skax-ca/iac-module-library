# aks-cluster 예제(배포 루트 형태) — vnet과 함께 배선하는 최소 착수 템플릿
#
# 순서(docs/module-catalog.md「aks-cluster」절, identity_id 설명 참조):
#   ① identity 생성 → ② 그 identity에 서브넷의 Network Contributor 역할 부여
#   → ③ aks-cluster 모듈 apply.
# ②를 건너뛰면 ③은 성공하고 노드만 조용히 실패한다 — role assignment가 aks-cluster 모듈
# 밖에 있어 plan에서 잡을 수 없는 죽은 경로이기 때문이다. 이 예제는 그 순서를 실제 리소스
# 그래프(depends_on)로 강제해 보여준다.
#
# ⚠️ 실제 배포에서는 identity 생성·role assignment가 이 root가 아니라 별도 "bootstrap"
# 계층(사람이 저빈도로 수동 실행하는 IaC)에 있어야 한다(docs/decisions.md「Azure 컨테이너
# (aks-cluster)」ADR — CI 신원이 roleAssignments/write를 가지면 안 된다). 이 예제는 CI가
# 매 커밋 validate하는 단일 스택이라 편의상 한 파일에 담았을 뿐, 배포 토폴로지 권고가 아니다.
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
  # secondary 대역을 Pod 서브넷 전용으로 뗀다(RFC 6598) — VNet 주소 공간의 소유는 이 root다.
  address_space = ["10.60.0.0/24", "100.64.0.0/24"]

  subnet_groups = {
    "aks-node" = {
      address_prefixes = ["10.60.0.0/26"]
      nat_routed       = true
      nsg_enabled      = true
    }
    "aks-pod" = {
      address_prefixes = ["100.64.0.0/25"]
    }
  }
}

# ① identity — aks-cluster 모듈은 이 리소스를 만들지 않는다.
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-${var.workload}-${var.env}-${var.region_code}-aks-01"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}

# ② role assignment — VNet 스코프로 부여해 노드·Pod 서브넷 둘 다 덮는다(0-26-a: 내장
# Network Contributor를 쓴다. 커스텀 역할로 좁히지 않는다 — roleAssignments/write를
# 클러스터 identity에 쥐여 주게 된다, docs/decisions.md 참조).
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = module.vnet.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# ③ aks-cluster — 위 role assignment가 끝난 뒤에만 apply되도록 depends_on으로 순서를
# 강제한다(provider 공식 문서가 BYO private DNS zone 시나리오에서 권고하는 것과 같은 패턴).
module "aks_cluster" {
  source = "../.."

  naming = {
    workload    = var.workload
    env         = var.env
    region_code = var.region_code
  }

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  identity_id    = azurerm_user_assigned_identity.aks.id
  node_subnet_id = module.vnet.subnet_ids_by_group["aks-node"]
  pod_subnet_id  = module.vnet.subnet_ids_by_group["aks-pod"]

  system_node_pool = {
    vm_size    = "Standard_D2s_v5"
    node_count = 2
  }

  # 추가(User) 노드 풀 예시 — 그룹 키 "app"이 "npapp"으로 조합된다.
  node_pools = {
    "app" = {
      vm_size    = "Standard_D4s_v5"
      node_count = 2
    }
  }

  depends_on = [azurerm_role_assignment.aks_network_contributor]
}
