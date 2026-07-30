# 출력 계약이 **실제로 소비되는지** 보이는 곳이다(examples/AGENTS.md).
# 단순 재노출뿐 아니라 map 키 접근까지 해 봐야 계약이 동작함을 증명한다.

output "vpc_id" {
  description = "생성된 VPC ID."
  value       = module.vpc.vpc_id
}

output "subnet_ids_by_group" {
  description = "그룹 키 → 서브넷 ID 리스트. 키는 이 예제가 넘긴 subnet_groups 키 그대로다."
  value       = module.vpc.subnet_ids_by_group
}

# 소비자가 실제로 하는 일: 자기가 준 키로 되받아 하류 모듈에 넘긴다.
# 키를 모듈이 변형하지 않기 때문에 이 접근이 예측 가능하다(D5).
output "app_subnet_ids" {
  description = "EKS 노드·앱을 놓을 private 서브넷 ID(하류 모듈에 그대로 넘기는 형태)."
  value       = module.vpc.subnet_ids_by_group["app-uniq"]
}

# D3 운영 라우트의 앵커. 온프레미스 대역→TGW 같은 라우트는 이 RT에 소비자가 직접 얹는다.
output "app_route_table_ids" {
  description = "app 그룹의 라우팅 테이블 ID(AZ별). 운영 라우트를 추가할 앵커다."
  value       = module.vpc.route_table_ids_by_group["app-uniq"]
}

output "nat_gateway_ids" {
  description = "NAT Gateway ID. single_nat_gateway = true이므로 1개다."
  value       = module.vpc.nat_gateway_ids
}

output "flow_log_group_name" {
  description = "VPC Flow Logs가 기록되는 CloudWatch 로그 그룹 이름."
  value       = module.vpc.flow_log_group_name
}
