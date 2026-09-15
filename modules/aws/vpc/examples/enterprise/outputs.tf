# 출력 계약이 실제로 소비되는지 보이는 곳.
# 9그룹 구성에서 map 출력이 왜 고정 리스트보다 나은지가 여기서 드러난다.
# private_subnet_ids 같은 타입 고정 출력으로는 elb/pod/db/data/ep/tgw를 구분할 수 없다.

output "vpc_id" {
  description = "생성된 VPC ID."
  value       = module.vpc.vpc_id
}

output "secondary_cidr_blocks" {
  description = "연결된 secondary CIDR(uniq·dup 2개)."
  value       = module.vpc.secondary_cidr_blocks
}

output "subnet_ids_by_group" {
  description = "9개 그룹 전체의 서브넷 ID. 키는 이 예제가 넘긴 그룹 키 그대로다."
  value       = module.vpc.subnet_ids_by_group
}

# 하류 EKS 모듈이 실제로 받는 형태: 노드와 Pod 서브넷이 분리돼 넘어간다.
output "eks_node_subnet_ids" {
  description = "EKS 노드용 private 서브넷(uniq 대역: node-SNAT 소스)."
  value       = module.vpc.subnet_ids_by_group["node-uniq"]
}

output "eks_pod_subnet_ids" {
  description = "EKS Pod 전용 isolated 서브넷(dup 대역: ENIConfig에 지정)."
  value       = module.vpc.subnet_ids_by_group["pod-dup"]
}

# 온프레미스 대역 라우트는 이 앵커들에 소비자가 직접 얹는다.
# prefix list를 목적지로 쓰면 대역 추가 시 라우트 리소스를 건드리지 않는다.
output "onprem_route_anchor_ids" {
  description = "온프레미스 연동 운영 라우트를 얹을 RT ID(node·vm·elb 그룹)."
  value = concat(
    module.vpc.route_table_ids_by_group["node-uniq"],
    module.vpc.route_table_ids_by_group["vm-uniq"],
    module.vpc.route_table_ids_by_group["elb-uniq"],
  )
}

output "flow_log_group_name" {
  description = "VPC Flow Logs가 기록되는 CloudWatch 로그 그룹 이름."
  value       = module.vpc.flow_log_group_name
}
