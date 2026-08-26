output "vnet_id" {
  value = module.vnet.vnet_id
}

output "subnet_ids_by_group" {
  value = module.vnet.subnet_ids_by_group
}

output "nat_gateway_id" {
  value = module.vnet.nat_gateway_id
}
