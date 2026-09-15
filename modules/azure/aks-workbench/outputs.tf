# 출력 계약
#
#  - ⚠️ null-safe: workbench_enabled = false면 스칼라는 전부 null이다.
#    참조 대상이 사라진 뒤에도 소비자 plan이 통과해야 파기가 성립한다.
#
# 계약: docs/module-catalog.md

output "workbench_vm_id" {
  description = "workbench VM의 리소스 ID. workbench_enabled = false면 null이다."
  value       = one(azurerm_linux_virtual_machine.this[*].id)
}

output "workbench_private_ip" {
  description = "workbench VM의 사설 IP. workbench_enabled = false면 null이다."
  value       = one(azurerm_network_interface.this[*].private_ip_address)
}

output "workbench_public_ip" {
  description = <<-EOT
    workbench VM의 공용 IP. public_ip_enabled = false거나 workbench_enabled = false면
    null이다.
  EOT
  value       = one(azurerm_public_ip.this[*].ip_address)
}

output "workbench_nsg_id" {
  description = "workbench NIC에 붙은 NSG의 리소스 ID. workbench_enabled = false면 null이다."
  value       = one(azurerm_network_security_group.this[*].id)
}

output "workbench_system_identity_principal_id" {
  description = <<-EOT
    VM의 system-assigned 신원 Principal ID(감사용). identity 블록은 항상
    "SystemAssigned, UserAssigned"이므로 entra_ssh_login_enabled 값과 무관하게 존재한다.
    workbench_enabled = false면 null이다.
  EOT
  value       = local.enabled ? one(azurerm_linux_virtual_machine.this[0].identity[*].principal_id) : null
}
