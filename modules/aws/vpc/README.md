# vpc

VPC · 서브넷 · NAT · Flow Logs.

## Usage

```hcl
module "vpc" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/aws/vpc?ref=vpc-vX.Y.Z"

  naming     = { workload = "demo", env = "dev", region_code = "an2" }
  cidr_block = "10.0.0.0/16"

  subnet_groups = {
    "pub-uniq"  = { type = "public", cidrs = ["10.0.0.0/24", "10.0.1.0/24"] }
    "node-uniq" = { type = "private", cidrs = ["10.0.10.0/24", "10.0.11.0/24"] }
  }
}
```

`vX.Y.Z`는 자리표시자다. 실제 최신 태그는 `git tag -l 'vpc-v*'`로 확인한다. 9그룹 전체 구성의
실전 예시는 [`examples/enterprise/README.md`](examples/enterprise/README.md)를 참조한다.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.57.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.private_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.shared](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.shared](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_ipv4_cidr_block_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipv4_cidr_block_association) | resource |
| [aws_availability_zones.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | 최대 AZ 슬라이스 수. 그룹별 실제 AZ 수는 subnet\_groups[*].cidrs의 길이가 결정한다.<br/>az\_selection을 지정할 경우 그 길이가 이 값과 같아야 한다. | `number` | `3` | no |
| <a name="input_az_selection"></a> [az\_selection](#input\_az\_selection) | AZ suffix 우선순위 목록. 각 그룹은 이 목록의 앞에서부터 length(cidrs)개 AZ에 배치된다.<br/>예: ["a", "c", "b"] → 2AZ 그룹은 a·c, 3AZ 그룹은 a·c·b.<br/>null이면 리전 AZ 목록의 앞 az\_count개를 그대로 쓴다. | `list(string)` | `null` | no |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | VPC primary CIDR. | `string` | n/a | yes |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | 삭제 보호(보호 방향). true면 aws\_vpc에 prevent\_destroy가 걸려 파괴 계획 자체가 차단된다.<br/>보호를 켠 상태의 파기는 2단계다 — deletion\_protection = false로 apply한 뒤 vpc\_enabled = false.<br/>이는 결함이 아니라 보호의 정의다.<br/><br/>기본값이 false인 이유: 파기가 기본 동작이어야 한다. 보호는 opt-in이다.<br/>소비자 사용 예: deletion\_protection = var.env == "prd" | `bool` | `false` | no |
| <a name="input_eks_cluster_name"></a> [eks\_cluster\_name](#input\_eks\_cluster\_name) | EKS 서브넷 디스커버리 태그(kubernetes.io/cluster/<name>)에 쓸 클러스터 이름.<br/>null이면 클러스터 태그를 붙이지 않는다. | `string` | `null` | no |
| <a name="input_enable_nat_gateway"></a> [enable\_nat\_gateway](#input\_enable\_nat\_gateway) | private 그룹에 NAT Gateway 경로를 구성할지 여부.<br/>NAT는 type이 public인 첫 번째 그룹(맵 키 정렬 기준)의 서브넷에 배치된다.<br/>public 그룹이 없는 상태에서 true면 검증 오류다. | `bool` | `true` | no |
| <a name="input_flow_logs_enabled"></a> [flow\_logs\_enabled](#input\_flow\_logs\_enabled) | VPC Flow Logs 생성 여부. 대상은 CloudWatch Logs로 고정한다. | `bool` | `true` | no |
| <a name="input_flow_logs_kms_key_id"></a> [flow\_logs\_kms\_key\_id](#input\_flow\_logs\_kms\_key\_id) | Flow Logs 로그 그룹 암호화에 쓸 KMS CMK ARN.<br/>KMS 키는 계정 전역 공유·보안 거버넌스 대상이라 모듈이 생성하지 않고 주입받는다.<br/>null이면 CloudWatch 기본 암호화(AWS 관리 키)로 동작한다. | `string` | `null` | no |
| <a name="input_flow_logs_retention_days"></a> [flow\_logs\_retention\_days](#input\_flow\_logs\_retention\_days) | Flow Logs 로그 그룹의 보존 기간(일). 0은 무기한 보존이다.<br/>유효값은 aws\_cloudwatch\_log\_group.retention\_in\_days가 허용하는 값으로 제한된다. | `number` | `30` | no |
| <a name="input_flow_logs_traffic_type"></a> [flow\_logs\_traffic\_type](#input\_flow\_logs\_traffic\_type) | Flow Logs가 수집할 트래픽 종류. | `string` | `"ALL"` | no |
| <a name="input_naming"></a> [naming](#input\_naming) | Name 태그 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로<br/>소비자는 약어를 직접 타이핑하지 않는다.<br/>예: {workload = "demo", env = "dev", region\_code = "an2"} → vpc-demo-dev-an2-main | <pre>object({<br/>    workload    = string<br/>    env         = string<br/>    region_code = string<br/>  })</pre> | n/a | yes |
| <a name="input_purpose"></a> [purpose](#input\_purpose) | Name 태그의 purpose 토큰. VPC 자신과 IGW·Flow Logs 리소스에 쓰인다(서브넷은 그룹 키를 쓴다). | `string` | `"main"` | no |
| <a name="input_secondary_cidr_blocks"></a> [secondary\_cidr\_blocks](#input\_secondary\_cidr\_blocks) | 추가 연결할 secondary CIDR 목록. 예: Pod 전용 ["100.64.0.0/16"].<br/>⚠️ primary가 10.0.0.0/15 범위 안이면 10.0.0.0/16 대역 secondary는 연결할 수 없다.<br/>이 제약은 apply 시 API가 검출하므로 plan 기반 test로는 잡히지 않는다. | `list(string)` | `[]` | no |
| <a name="input_single_nat_gateway"></a> [single\_nat\_gateway](#input\_single\_nat\_gateway) | true면 NAT Gateway 1개를 전 AZ가 공유한다(dev — 비용 우선).<br/>false면 AZ별로 1개씩 만든다(prd — 가용성 우선). | `bool` | `false` | no |
| <a name="input_subnet_groups"></a> [subnet\_groups](#input\_subnet\_groups) | 서브넷 그룹 정의. 키가 곧 Name 태그의 purpose 토큰이 된다.<br/>  type       - "public" \| "private" \| "isolated". 라우팅과 RT 구성을 결정한다<br/>  cidrs      - AZ 순서대로 명시한 CIDR. 리스트 길이가 곧 그 그룹의 AZ 수다<br/>  eks\_role   - "elb" \| "internal-elb" \| null. EKS 서브넷 디스커버리 태그를 붙인다<br/>  extra\_tags - 그룹 단위 추가 태그<br/>그룹 키는 <용도 축약>-<uniq\|dup> 형식을 권고하나 모듈이 강제하지는 않는다.<br/>2 <= length(cidrs) <= az\_count 제약은 main.tf의 precondition이 검증한다. | <pre>map(object({<br/>    type       = string<br/>    cidrs      = list(string)<br/>    eks_role   = optional(string)<br/>    extra_tags = optional(map(string), {})<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | 이 모듈이 만드는 전 리소스에 추가할 태그.<br/>거버넌스 태그(Workload·Env·Owner 등)는 프로젝트 루트의 provider default\_tags 소관이므로<br/>여기에 반복하지 않는다. | `map(string)` | `{}` | no |
| <a name="input_vpc_enabled"></a> [vpc\_enabled](#input\_vpc\_enabled) | kill switch(파괴 방향). false면 이 모듈의 전 리소스를 파기하고 data source 조회까지 건너뛴다.<br/>참조 대상이 사라진 뒤에도 plan이 통과해야 파기가 가능하기 때문이다.<br/>false일 때 스칼라 출력은 null, map/list 출력은 빈 값이 된다. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_flow_log_group_name"></a> [flow\_log\_group\_name](#output\_flow\_log\_group\_name) | VPC Flow Logs가 기록되는 CloudWatch 로그 그룹 이름. Flow Logs 비활성이면 null이다. |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | NAT Gateway ID 리스트(AZ 순서). single\_nat\_gateway = true면 원소 1개, NAT 비활성이면 빈 리스트다. |
| <a name="output_route_table_ids_by_group"></a> [route\_table\_ids\_by\_group](#output\_route\_table\_ids\_by\_group) | 그룹 키 → 라우팅 테이블 ID 리스트. 운영 라우트(온프레미스→TGW 등)를 얹는 앵커다.<br/>public·isolated 그룹은 RT를 공유하므로 원소가 1개, private 그룹은 AZ별 RT라 AZ 순서 리스트다.<br/>앵커에 무엇을 거는지는 모듈이 제약하지 않는다 — 목적지(CIDR·prefix list)와<br/>타깃(TGW·VGW·peering·ENI 등) 조합이 자유롭다. |
| <a name="output_secondary_cidr_blocks"></a> [secondary\_cidr\_blocks](#output\_secondary\_cidr\_blocks) | 연결이 완료된 secondary CIDR 목록. 하나도 없으면 빈 리스트다. |
| <a name="output_subnet_ids_by_group"></a> [subnet\_ids\_by\_group](#output\_subnet\_ids\_by\_group) | 그룹 키 → 서브넷 ID 리스트(AZ 순서). 키는 소비자가 넘긴 subnet\_groups 키 그대로다.<br/>하류(eks-cluster 등)는 이 출력을 직접 넘겨받거나, 루트가 다르면 Name 태그로<br/>data.aws\_subnets를 조회한다 — 네이밍이 결정적이라 성립하는 방식이다. |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | VPC primary CIDR. vpc\_enabled = false면 null이다. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID. vpc\_enabled = false면 null이다. |
<!-- END_TF_DOCS -->
