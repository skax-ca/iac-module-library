# VNet · 서브넷 · 옵트인 NSG/라우팅 테이블 · NAT
#
# 리소스 순서는 의존 순서다: vnet → subnet → NSG/RT(옵트인) → association → NAT.
# 모든 리소스가 var.vnet_enabled 게이트를 지난다.
#
# ⛔ azurerm_virtual_network에 subnet·dns_servers 인자를 쓰지 않는다(빈 배열로도 쓰지 않는다).
#    인라인 subnet 블록과 별도 azurerm_subnet 리소스를 병용하면 provider가 규칙을 서로
#    덮어쓴다(공식 경고). 이 모듈은 서브넷을 전부 azurerm_subnet 별도 리소스로만 만든다.
#
# 계약: docs/module-catalog.md

locals {
  enabled = var.vnet_enabled

  # name 인자의 중간 토큰. 소비자가 약어를 타이핑하지 않도록 모듈이 조합한다.
  name_mid = "${var.naming.workload}-${var.naming.env}-${var.naming.region_code}"

  nat_group_names = sort([for name, group in var.subnet_groups : name if group.nat_routed])
  nsg_group_names = sort([for name, group in var.subnet_groups : name if group.nsg_enabled])
  rt_group_names  = sort([for name, group in var.subnet_groups : name if group.route_table_enabled])

  # nat_routed 그룹이 0개면 NAT를 만들지 않는다 — 걸어줄 서브넷이 없고 유휴로도 과금된다.
  # precondition을 걸지 않는다: 기본값 조합(subnet_groups = {})에서도 plan이 깨지면 안 된다.
  nat_enabled = local.enabled && var.nat_gateway_enabled && length(local.nat_group_names) > 0
}

resource "azurerm_virtual_network" "this" {
  count = local.enabled ? 1 : 0

  name                = "vnet-${local.name_mid}-${var.purpose}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space

  tags = var.tags

  lifecycle {
    # 재사용 모듈이 소비자에게 삭제 보호를 위임할 수 있는 유일한 수단이다.
    prevent_destroy = var.deletion_protection
  }
}

resource "azurerm_subnet" "this" {
  for_each = local.enabled ? var.subnet_groups : {}

  name                            = "snet-${local.name_mid}-${each.key}"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this[0].name
  address_prefixes                = each.value.address_prefixes
  default_outbound_access_enabled = each.value.default_outbound_access_enabled

  dynamic "service_endpoint" {
    for_each = each.value.service_endpoints
    content {
      service = service_endpoint.value
    }
  }

  dynamic "delegation" {
    for_each = each.value.delegations
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.name
        actions = delegation.value.actions
      }
    }
  }

  # azurerm_subnet은 tags 인자를 지원하지 않는다 — 공통 규약 "모든 리소스에 태그를 단다"가
  # 서브넷에서는 구조적으로 달성 불가하다(docs/conventions.md Azure 강제 방식 3번).
}

# ── NSG(옵트인) ──────────────────────────────────────────────────────────────
# 룰은 이 모듈이 만들지 않는다. 소비자가 azurerm_network_security_rule 별도 리소스로 얹는다
# (inline security_rule 블록과 혼용하면 provider가 규칙을 덮어쓴다, .claude/rules/terraform.md).

resource "azurerm_network_security_group" "this" {
  for_each = toset(local.enabled ? local.nsg_group_names : [])

  name                = "nsg-${local.name_mid}-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = merge(var.tags, var.subnet_groups[each.key].extra_tags)
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = toset(local.enabled ? local.nsg_group_names : [])

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# ── 라우팅 테이블(옵트인) ─────────────────────────────────────────────────────
# 운영 라우트는 이 모듈이 만들지 않는다. 소비자가 azurerm_route 별도 리소스로 얹는다
# (vpc의 route_table_ids_by_group과 같은 앵커 역할).

resource "azurerm_route_table" "this" {
  for_each = toset(local.enabled ? local.rt_group_names : [])

  name                = "rt-${local.name_mid}-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = merge(var.tags, var.subnet_groups[each.key].extra_tags)
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each = toset(local.enabled ? local.rt_group_names : [])

  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.this[each.key].id
}

# ── NAT — vnet당 1개(존이 아니라 SKU가 이중화를 결정한다) ──────────────────────

resource "azurerm_public_ip" "nat" {
  count = local.nat_enabled ? 1 : 0

  name                = "pip-${local.name_mid}-nat-${var.purpose}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  # public IP SKU는 NAT Gateway SKU와 정확히 같아야 한다(provider 공식 제약).
  sku   = var.nat_gateway_sku_name
  zones = var.nat_gateway_zones

  tags = var.tags
}

resource "azurerm_nat_gateway" "this" {
  count = local.nat_enabled ? 1 : 0

  name                = "ng-${local.name_mid}-${var.purpose}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = var.nat_gateway_sku_name
  zones               = var.nat_gateway_zones

  tags = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count = local.nat_enabled ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  for_each = toset(local.nat_enabled ? local.nat_group_names : [])

  subnet_id      = azurerm_subnet.this[each.key].id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}
