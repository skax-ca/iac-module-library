output "cluster_id" {
  value = module.aks_cluster.cluster_id
}

output "oidc_issuer_url" {
  value = module.aks_cluster.oidc_issuer_url
}

output "node_resource_group" {
  value = module.aks_cluster.node_resource_group
}
