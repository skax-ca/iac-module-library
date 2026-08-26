# vnet 모듈 계약 검증
#
# ⚠️ 이 파일이 계약의 유일한 검출 지점이다. 교차변수 validation은 validate가 아니라 plan
#    시점에 평가되므로, examples를 validate까지만 도는 규약으로는 계약 위반이 잡히지 않는다.
#
# mock_provider로 azurerm 전체를 모킹한다 — 이 repo는 배포하지 않아 CI에 Azure 자격증명이
# 없다. 모킹에서는 computed 속성(id·ip_address 등)이 plan 시점에 unknown이다. 따라서
# assertion은 설정값(tags·name·address_prefixes·sku·zones)과 인스턴스 개수·키 집합만 본다
# (modules/aws/vpc/tests/plan.tftest.hcl과 같은 제약).

# mock_resource 는 association 리소스가 소비하는 .id 형식을 맞추기 위해서다 — provider가
# plan 시점에도 리소스 ID를 파싱해 세그먼트 형식을 검증한다(모듈 결함이 아니라 모킹의 제약,
# modules/aws/vpc/tests/plan.tftest.hcl의 ARN 형식 요구와 같은 종류).
mock_provider "azurerm" {
  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.Network/virtualNetworks/example-vnet/subnets/example-subnet"
    }
  }

  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.Network/networkSecurityGroups/example-nsg"
    }
  }

  mock_resource "azurerm_route_table" {
    defaults = {
      id = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.Network/routeTables/example-rt"
    }
  }

  mock_resource "azurerm_nat_gateway" {
    defaults = {
      id = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.Network/natGateways/example-nat"
    }
  }

  mock_resource "azurerm_public_ip" {
    defaults = {
      id = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.Network/publicIPAddresses/example-pip"
    }
  }
}

variables {
  naming = {
    workload    = "demo"
    env         = "dev"
    region_code = "krc"
  }
  resource_group_name = "rg-demo-dev-krc-main"
  location            = "koreacentral"
  address_space       = ["10.60.0.0/24"]

  subnet_groups = {
    "app" = {
      address_prefixes    = ["10.60.0.0/26"]
      nat_routed          = true
      nsg_enabled         = true
      route_table_enabled = true
      extra_tags          = { Extra = "app-only" }
    }
    "data" = {
      address_prefixes = ["10.60.0.64/26"]
      nat_routed       = true
      # nsg_enabled · route_table_enabled 는 기본값(false) 그대로 — 옵트인 기본 꺼짐 검증용.
    }
  }
}

# ── 네이밍 규약 — 릴리스 게이트 필수 항목 ───────────────────────────────────────
run "naming_contract" {
  command = plan

  assert {
    condition     = azurerm_virtual_network.this[0].name == "vnet-demo-dev-krc-main"
    error_message = "VNet 이름이 vnet-<mid>-<purpose> 포맷이 아니다: ${azurerm_virtual_network.this[0].name}"
  }

  assert {
    condition     = azurerm_subnet.this["app"].name == "snet-demo-dev-krc-app"
    error_message = "서브넷 이름이 snet-<mid>-<그룹키> 포맷이 아니다: ${azurerm_subnet.this["app"].name}"
  }

  assert {
    condition     = azurerm_network_security_group.this["app"].name == "nsg-demo-dev-krc-app"
    error_message = "NSG 이름이 nsg-<mid>-<그룹키> 포맷이 아니다: ${azurerm_network_security_group.this["app"].name}"
  }

  assert {
    condition     = azurerm_route_table.this["app"].name == "rt-demo-dev-krc-app"
    error_message = "라우팅 테이블 이름이 rt-<mid>-<그룹키> 포맷이 아니다: ${azurerm_route_table.this["app"].name}"
  }

  assert {
    condition     = azurerm_nat_gateway.this[0].name == "ng-demo-dev-krc-main"
    error_message = "NAT Gateway 이름이 ng-<mid>-<purpose> 포맷이 아니다: ${azurerm_nat_gateway.this[0].name}"
  }

  assert {
    condition     = azurerm_public_ip.nat[0].name == "pip-demo-dev-krc-nat-main"
    error_message = "공용 IP 이름이 pip-<mid>-nat-<purpose> 포맷이 아니다: ${azurerm_public_ip.nat[0].name}"
  }
}

# ── 서브넷은 name 인자만, 태그는 없다 ───────────────────────────────────────────
run "subnet_has_no_tags_argument" {
  command = plan

  assert {
    condition     = azurerm_subnet.this["app"].address_prefixes == tolist(["10.60.0.0/26"])
    error_message = "서브넷 address_prefixes가 그룹 정의와 다르다: ${jsonencode(azurerm_subnet.this["app"].address_prefixes)}"
  }
}

# ── NSG·RT 옵트인 — 그룹마다 기본은 꺼짐 ────────────────────────────────────────
run "nsg_rt_optin_defaults_off" {
  command = plan

  assert {
    condition     = keys(azurerm_network_security_group.this) == ["app"]
    error_message = "NSG가 nsg_enabled = true인 그룹에만 만들어지지 않았다: ${join(",", keys(azurerm_network_security_group.this))}"
  }

  assert {
    condition     = keys(azurerm_route_table.this) == ["app"]
    error_message = "라우팅 테이블이 route_table_enabled = true인 그룹에만 만들어지지 않았다: ${join(",", keys(azurerm_route_table.this))}"
  }

  assert {
    condition     = keys(azurerm_subnet_network_security_group_association.this) == ["app"]
    error_message = "NSG association이 옵트인 그룹에만 걸리지 않았다."
  }

  assert {
    condition     = keys(azurerm_subnet_route_table_association.this) == ["app"]
    error_message = "RT association이 옵트인 그룹에만 걸리지 않았다."
  }
}

# ── extra_tags는 NSG·RT에만 병합 적용된다 ───────────────────────────────────────
run "extra_tags_merge_on_nsg_and_rt_only" {
  command = plan

  variables {
    tags = { Governance = "shared" }
  }

  assert {
    condition = alltrue([
      azurerm_network_security_group.this["app"].tags["Governance"] == "shared",
      azurerm_network_security_group.this["app"].tags["Extra"] == "app-only",
    ])
    error_message = "NSG 태그가 var.tags와 그룹 extra_tags를 병합하지 않았다: ${jsonencode(azurerm_network_security_group.this["app"].tags)}"
  }

  assert {
    condition = alltrue([
      azurerm_route_table.this["app"].tags["Governance"] == "shared",
      azurerm_route_table.this["app"].tags["Extra"] == "app-only",
    ])
    error_message = "라우팅 테이블 태그가 var.tags와 그룹 extra_tags를 병합하지 않았다: ${jsonencode(azurerm_route_table.this["app"].tags)}"
  }
}

# ── NAT는 vnet당 1개, nat_routed 그룹 전부에 연결된다 ───────────────────────────
run "nat_single_gateway_shared_by_all_routed_groups" {
  command = plan

  assert {
    condition     = length(azurerm_nat_gateway.this) == 1 && length(azurerm_public_ip.nat) == 1
    error_message = "NAT Gateway·공용 IP가 vnet당 1개가 아니다."
  }

  assert {
    condition     = keys(azurerm_subnet_nat_gateway_association.this) == ["app", "data"]
    error_message = "NAT association이 nat_routed = true인 그룹 전부에 걸리지 않았다: ${join(",", keys(azurerm_subnet_nat_gateway_association.this))}"
  }

  assert {
    condition     = azurerm_public_ip.nat[0].sku == "Standard" && azurerm_public_ip.nat[0].allocation_method == "Static"
    error_message = "공용 IP SKU가 NAT Gateway SKU(Standard)와 일치하지 않는다 — provider가 이 조합을 거부한다."
  }
}

# ── NAT 수요 0개는 조용히 스킵된다(precondition 없음) ───────────────────────────
run "nat_demand_zero_skips_quietly" {
  command = plan

  variables {
    subnet_groups = {
      "app" = {
        address_prefixes = ["10.60.0.0/26"]
      }
    }
  }

  assert {
    condition = alltrue([
      length(azurerm_nat_gateway.this) == 0,
      length(azurerm_public_ip.nat) == 0,
      length(azurerm_nat_gateway_public_ip_association.this) == 0,
      length(azurerm_subnet_nat_gateway_association.this) == 0,
    ])
    error_message = "nat_routed = true인 그룹이 0개인데 NAT 관련 리소스가 남아 있다."
  }
}

# ── StandardV2는 zones를 받지 않는다(공식 제약) ─────────────────────────────────
run "reject_standardv2_with_zones" {
  command = plan

  variables {
    nat_gateway_sku_name = "StandardV2"
    nat_gateway_zones    = ["1"]
  }

  expect_failures = [var.nat_gateway_zones]
}

run "reject_invalid_nat_sku" {
  command = plan

  variables {
    nat_gateway_sku_name = "Basic"
  }

  expect_failures = [var.nat_gateway_sku_name]
}

# Standard SKU에서는 zones 지정이 정상 동작해야 한다(StandardV2만 거부 대상이다).
run "standard_sku_accepts_zone" {
  command = plan

  variables {
    nat_gateway_sku_name = "Standard"
    nat_gateway_zones    = ["1"]
  }

  assert {
    condition     = azurerm_nat_gateway.this[0].zones == toset(["1"])
    error_message = "Standard SKU에서 nat_gateway_zones가 NAT Gateway에 반영되지 않았다."
  }

  assert {
    condition     = azurerm_public_ip.nat[0].zones == toset(["1"])
    error_message = "Standard SKU에서 nat_gateway_zones가 공용 IP에 반영되지 않았다(SKU와 zones는 둘 다 일치해야 한다)."
  }
}

# ── kill switch ─────────────────────────────────────────────────────────────────
# ⚠️ deletion_protection 기본값 false에 의존한다. true면 삭제 보호 validation이 먼저 차단한다.
run "kill_switch_disables_everything" {
  command = plan

  variables {
    vnet_enabled = false
  }

  assert {
    condition = alltrue([
      length(azurerm_virtual_network.this) == 0,
      length(azurerm_subnet.this) == 0,
      length(azurerm_network_security_group.this) == 0,
      length(azurerm_route_table.this) == 0,
      length(azurerm_subnet_network_security_group_association.this) == 0,
      length(azurerm_subnet_route_table_association.this) == 0,
      length(azurerm_nat_gateway.this) == 0,
      length(azurerm_public_ip.nat) == 0,
      length(azurerm_subnet_nat_gateway_association.this) == 0,
    ])
    error_message = "vnet_enabled = false인데 리소스가 남아 있다."
  }

  # 출력이 에러 대신 null·빈 값을 준다 — 소비자 plan이 깨지지 않아야 teardown이 성립한다.
  assert {
    condition = alltrue([
      output.vnet_id == null,
      output.vnet_name == null,
      output.nat_gateway_id == null,
      output.nat_public_ip_address == null,
    ])
    error_message = "비활성 시 스칼라 출력이 null이 아니다."
  }

  assert {
    condition = alltrue([
      length(output.address_space) == 0,
      length(output.subnet_ids_by_group) == 0,
      length(output.nsg_ids_by_group) == 0,
      length(output.route_table_ids_by_group) == 0,
    ])
    error_message = "비활성 시 리스트·map 출력이 빈 값이 아니다."
  }
}

# ── 계약 위반은 plan에서 차단된다 ───────────────────────────────────────────────
run "reject_teardown_while_protected" {
  command = plan

  variables {
    vnet_enabled        = false
    deletion_protection = true
  }

  expect_failures = [var.deletion_protection]
}
