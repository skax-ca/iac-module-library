# 출력 계약 — 설계 docs/design/10-vpc-module.md §1.4
#
# 계약 규약:
#  - 출력 이름은 메이저 버전 내에서 안정하다. rename·삭제는 메이저, 추가는 마이너(02 §3).
#  - map 출력의 키는 소비자가 넘긴 subnet_groups 키 그대로다 — 모듈이 키를 변형하지 않는다.
#  - ⚠️ null-safe: vpc_enabled = false면 스칼라는 null, map·list는 빈 값이다(D10).
#    참조 대상이 사라진 뒤에도 소비자 plan이 통과해야 teardown이 성립한다.
#
# 리스트 순서는 AZ 순서(D7의 az_selection 우선순위)다. 맵 순회는 키 사전순이라
# az_selection = ["a", "c", "b"]에서 a·b·c로 뒤집히므로, 순서가 필요한 출력은
# local.az_suffixes를 바깥 루프로 두고 조립한다.

output "vpc_id" {
  description = "VPC ID. vpc_enabled = false면 null이다(D10)."
  value       = one(aws_vpc.this[*].id)
}

output "vpc_cidr_block" {
  description = "VPC primary CIDR. vpc_enabled = false면 null이다."
  value       = one(aws_vpc.this[*].cidr_block)
}

output "secondary_cidr_blocks" {
  description = "연결이 완료된 secondary CIDR 목록. 하나도 없으면 빈 리스트다."
  value       = [for assoc in aws_vpc_ipv4_cidr_block_association.this : assoc.cidr_block]
}

output "subnet_ids_by_group" {
  description = <<-EOT
    그룹 키 → 서브넷 ID 리스트(AZ 순서). 키는 소비자가 넘긴 subnet_groups 키 그대로다.
    하류(eks-cluster 등)는 이 출력을 직접 넘겨받거나, 루트가 다르면 Name 태그로
    data.aws_subnets를 조회한다(03 §3.1 — 네이밍이 결정적이라 성립하는 방식).
  EOT
  value = local.enabled ? {
    for group_name in keys(var.subnet_groups) : group_name => [
      for suffix in local.az_suffixes :
      aws_subnet.this["${group_name}-${suffix}"].id
      if contains(keys(aws_subnet.this), "${group_name}-${suffix}")
    ]
  } : {}
}

output "route_table_ids_by_group" {
  description = <<-EOT
    그룹 키 → 라우팅 테이블 ID 리스트. 운영 라우트(온프레미스→TGW 등)를 얹는 앵커다(D3).
    public·isolated 그룹은 RT를 공유하므로 원소가 1개, private 그룹은 AZ별 RT라 AZ 순서 리스트다.
    앵커에 무엇을 거는지는 모듈이 제약하지 않는다 — 목적지(CIDR·prefix list)와
    타깃(TGW·VGW·peering·ENI 등) 조합이 자유롭다.
  EOT
  value = local.enabled ? {
    for group_name, group in var.subnet_groups : group_name => (
      group.type == "private"
      ? [
        for suffix in local.az_suffixes :
        aws_route_table.private["${group_name}-${suffix}"].id
        if contains(keys(aws_route_table.private), "${group_name}-${suffix}")
      ]
      : [aws_route_table.shared[group_name].id]
    )
  } : {}
}

output "nat_gateway_ids" {
  description = "NAT Gateway ID 리스트(AZ 순서). single_nat_gateway = true면 원소 1개, NAT 비활성이면 빈 리스트다."
  value       = [for suffix in local.nat_suffixes : aws_nat_gateway.this[suffix].id]
}

output "flow_log_group_name" {
  description = "VPC Flow Logs가 기록되는 CloudWatch 로그 그룹 이름. Flow Logs 비활성이면 null이다(D11)."
  value       = one(aws_cloudwatch_log_group.flow_logs[*].name)
}
