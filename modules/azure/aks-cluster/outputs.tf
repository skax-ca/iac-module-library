# 출력 계약
#
#  - ⚠️ null-safe: cluster_enabled = false면 스칼라는 null, map은 빈 값이다.
#    참조 대상이 사라진 뒤에도 소비자 plan이 통과해야 파기가 성립한다.
#  - oidc_issuer_url·kubelet_identity_object_id는 이 모듈이 identity를 만들지 않고도
#    내보내는 원시 재료다. 실제 Workload Identity Federation 배선은 이 모듈 밖(bootstrap
#    계층)이 한다.
#
# 계약: docs/module-catalog.md

output "cluster_id" {
  description = "AKS 클러스터 ID. cluster_enabled = false면 null이다."
  value       = one(azurerm_kubernetes_cluster.this[*].id)
}

output "cluster_name" {
  description = "AKS 클러스터 이름. cluster_enabled = false면 null이다."
  value       = one(azurerm_kubernetes_cluster.this[*].name)
}

output "oidc_issuer_url" {
  description = <<-EOT
    OIDC issuer URL. Workload Identity Federation 등 신원 배선의 원시 재료다(이 모듈은
    federated identity credential을 만들지 않는다). cluster_enabled = false면 null이다.
  EOT
  value       = one(azurerm_kubernetes_cluster.this[*].oidc_issuer_url)
}

output "kubelet_identity_object_id" {
  description = <<-EOT
    kubelet이 쓰는 관리 ID의 Object ID(AKS가 노드 리소스 그룹에 자동 생성한 것. 이 모듈이
    만들지 않는다). ACR pull 등 kubelet 신원에 권한을 부여할 때 쓴다. cluster_enabled =
    false면 null이다.
  EOT
  value       = local.enabled ? one(azurerm_kubernetes_cluster.this[0].kubelet_identity[*].object_id) : null
}

output "node_resource_group" {
  description = "AKS가 노드 리소스를 자동 생성하는 리소스 그룹 이름. cluster_enabled = false면 null이다."
  value       = one(azurerm_kubernetes_cluster.this[*].node_resource_group)
}

output "fqdn" {
  description = <<-EOT
    클러스터 API 서버 FQDN. private_cluster_enabled = true이고
    private_cluster_public_fqdn_enabled = false(기본값)면 null이다(provider 동작: 이
    조합엔 공개 이름 자체가 없다). private_cluster_public_fqdn_enabled = true면
    private_cluster_enabled = true여도 이 필드가 채워진다. 이 이름은 공개 DNS로 조회
    가능하지만 반환되는 IP는 여전히 private다(private_cluster_public_fqdn_enabled 변수
    설명 참고). cluster_enabled = false면도 null이다.
  EOT
  value       = one(azurerm_kubernetes_cluster.this[*].fqdn)
}

output "private_fqdn" {
  description = <<-EOT
    클러스터 API 서버 FQDN(private_cluster_enabled = true일 때만 값이 있다). 그 외에는
    null이다.
  EOT
  value       = one(azurerm_kubernetes_cluster.this[*].private_fqdn)
}

output "node_pool_ids_by_key" {
  description = <<-EOT
    추가(User) 노드 풀 키 → 노드 풀 ID. 키는 소비자가 넘긴 node_pools 키 그대로다.
    시스템 노드 풀은 포함하지 않는다(클러스터 리소스 자신이 소유, cluster_id로 식별한다).
  EOT
  value = local.enabled ? {
    for key in keys(var.node_pools) : key => azurerm_kubernetes_cluster_node_pool.this[key].id
  } : {}
}
