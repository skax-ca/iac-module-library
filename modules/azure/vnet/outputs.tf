# 출력 계약
#
#  - map 출력의 키는 소비자가 넘긴 subnet_groups 키 그대로다 — 모듈이 키를 변형하지 않는다.
#  - ⚠️ null-safe: vnet_enabled = false면 스칼라는 null, map은 빈 값이다.
#    참조 대상이 사라진 뒤에도 소비자 plan이 통과해야 파기가 성립한다.
#  - vpc(AWS)와 출력 타입이 다른 3곳은 Azure 서브넷이 존(zone)에 속하지 않고 vnet당
#    NAT Gateway가 하나이기 때문이다(docs/module-catalog.md의 「vpc와의 출력 비대칭」 표).
#
# 계약: docs/module-catalog.md

output "vnet_id" {
  description = "VNet ID. vnet_enabled = false면 null이다."
  value       = one(azurerm_virtual_network.this[*].id)
}

output "vnet_name" {
  description = "VNet 이름. vnet_enabled = false면 null이다."
  value       = one(azurerm_virtual_network.this[*].name)
}

output "address_space" {
  description = "VNet 주소 공간. vnet_enabled = false면 빈 리스트다."
  value       = local.enabled ? azurerm_virtual_network.this[0].address_space : []
}

output "subnet_ids_by_group" {
  description = <<-EOT
    그룹 키 → 서브넷 ID. 키는 소비자가 넘긴 subnet_groups 키 그대로다.
    vpc(AWS)의 동명 출력과 달리 map(string)이다 — Azure 서브넷은 존에 속하지 않아
    그룹당 서브넷이 항상 1개다.
  EOT
  value = local.enabled ? {
    for group_name in keys(var.subnet_groups) : group_name => azurerm_subnet.this[group_name].id
  } : {}
}

output "nsg_ids_by_group" {
  description = "nsg_enabled = true인 그룹 키 → NSG ID. 나머지 그룹은 키 자체가 없다(만들지 않았으므로)."
  value = local.enabled ? {
    for group_name in local.nsg_group_names : group_name => azurerm_network_security_group.this[group_name].id
  } : {}
}

output "route_table_ids_by_group" {
  description = <<-EOT
    route_table_enabled = true인 그룹 키 → 라우팅 테이블 ID. 나머지 그룹은 키 자체가 없다.
    운영 라우트(온프레미스 경로 등)를 얹는 앵커다 — 목적지와 타깃 조합은 모듈이 제약하지 않는다.
  EOT
  value = local.enabled ? {
    for group_name in local.rt_group_names : group_name => azurerm_route_table.this[group_name].id
  } : {}
}

output "nat_gateway_id" {
  description = <<-EOT
    NAT Gateway ID. vpc(AWS)의 nat_gateway_ids(list(string))와 달리 단일 string이다 —
    vnet당 NAT Gateway가 1개이고 이중화는 존이 아니라 SKU가 결정한다. NAT 비활성이면 null이다.
  EOT
  value       = one(azurerm_nat_gateway.this[*].id)
}

output "nat_public_ip_address" {
  description = "NAT Gateway에 연결된 공용 IP 주소. NAT 비활성이면 null이다."
  value       = one(azurerm_public_ip.nat[*].ip_address)
}
