# vnet

Azure 가상 네트워크 · 서브넷 그룹 · NAT · 옵트인 NSG · 옵트인 라우팅 테이블.

## Usage

```hcl
resource "azurerm_resource_group" "this" {
  name     = "rg-demo-dev-krc-main"
  location = "koreacentral"
}

module "vnet" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/azure/vnet?ref=vnet-vX.Y.Z"

  naming = { workload = "demo", env = "dev", region_code = "krc" }

  resource_group_name = azurerm_resource_group.this.name
  location             = azurerm_resource_group.this.location
  address_space         = ["10.60.0.0/24"]

  subnet_groups = {
    "app"  = { address_prefixes = ["10.60.0.0/26"], nat_routed = true, nsg_enabled = true }
    "data" = { address_prefixes = ["10.60.0.64/26"], nat_routed = true }
  }
}
```

`vX.Y.Z`는 자리표시자다. 실제 최신 태그는 `git tag -l 'vnet-v*'`로 확인한다. 착수 템플릿은
[`examples/basic/`](examples/basic/)를 참조한다.

Azure 예약 이름 서브넷(`AzureBastionSubnet` · `GatewaySubnet` · `AzureFirewallSubnet`)은 이
모듈이 만들지 않는다. 배포 루트가 같은 vnet에 `azurerm_subnet`으로 직접 만든다. NSG 룰은
소비자가 `azurerm_network_security_rule` 별도 리소스로 얹는다(모듈이 만든 NSG는 비어 있다).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 5.2.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway) | resource |
| [azurerm_nat_gateway_public_ip_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway_public_ip_association) | resource |
| [azurerm_network_security_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_public_ip.nat](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_route_table.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) | resource |
| [azurerm_subnet.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_nat_gateway_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_nat_gateway_association) | resource |
| [azurerm_subnet_network_security_group_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_subnet_route_table_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association) | resource |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_address_space"></a> [address\_space](#input\_address\_space) | VNet 주소 공간(CIDR 목록). | `list(string)` | n/a | yes |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | 삭제 보호(보호 방향). true면 azurerm\_virtual\_network에 prevent\_destroy가 걸려 파괴 계획<br/>자체가 차단된다. 보호를 켠 상태의 파기는 2단계다. deletion\_protection = false로 apply한<br/>뒤 vnet\_enabled = false.<br/><br/>보호 범위가 vpc와 다르다: Azure는 vnet 삭제가 내부 서브넷을 함께 지운다. 이 모듈은 vnet<br/>하나에만 보호를 걸고 서브넷 개별 보호는 제공하지 않는다.<br/><br/>기본값이 false인 이유: 파기가 기본 동작이어야 한다. 보호는 opt-in이다.<br/>소비자 사용 예: deletion\_protection = var.env == "prd" | `bool` | `false` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure 리전(필수 입력, 리소스 그룹 data source에서 파생하지 않는다). data source 조회는<br/>"이번 plan에서 변경 예정인 관리 리소스에 직접 의존할 때"만 apply를 연기하는 조건부 동작이라,<br/>리터럴을 넘기면 배포 성공이 소비자 배선 형태에 좌우된다. 배포 루트는 RG와 vnet을 한<br/>apply에서 세울 수 있다. 이 모듈이 RG를 읽지 않기 때문이다. | `string` | n/a | yes |
| <a name="input_naming"></a> [naming](#input\_naming) | name 인자 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로<br/>소비자는 약어를 직접 타이핑하지 않는다.<br/>예: {workload = "demo", env = "dev", region\_code = "krc"} → vnet-demo-dev-krc-main | <pre>object({<br/>    workload    = string<br/>    env         = string<br/>    region_code = string<br/>  })</pre> | n/a | yes |
| <a name="input_nat_gateway_enabled"></a> [nat\_gateway\_enabled](#input\_nat\_gateway\_enabled) | NAT Gateway 생성 여부. true라도 subnet\_groups 중 nat\_routed = true인 그룹이 0개면<br/>조용히 만들지 않는다(수요와 결합, 기본값 조합에서 plan이 깨지지 않게 하기 위해서다). | `bool` | `true` | no |
| <a name="input_nat_gateway_sku_name"></a> [nat\_gateway\_sku\_name](#input\_nat\_gateway\_sku\_name) | NAT Gateway SKU. "Standard"는 GA이고 무존이거나 단일 존이다. "StandardV2"는 존 이중화를<br/>제공하지만 preview다(SLA 대상 아님, 일부 리전 미지원). 배송 모듈의 기본값으로 강제할 수<br/>없어 기본은 GA인 "Standard"를 쓴다.<br/><br/>변경은 리소스 재생성을 강제해 아웃바운드 공용 IP가 바뀐다. 고객사 방화벽 allowlist에<br/>직결되므로 신중히 바꾼다. | `string` | `"Standard"` | no |
| <a name="input_nat_gateway_zones"></a> [nat\_gateway\_zones](#input\_nat\_gateway\_zones) | NAT Gateway를 배치할 가용 영역 목록. "Standard" SKU에서만 의미가 있다(0개면 무존, 1개면<br/>단일 존 배치). "StandardV2"는 zone-redundant가 기본이라 provider가 이 값을 아예 받지<br/>않는다. nat\_gateway\_sku\_name = "StandardV2"일 때는 null이거나 빈 리스트여야 한다. | `list(string)` | `null` | no |
| <a name="input_purpose"></a> [purpose](#input\_purpose) | name 인자의 purpose 토큰. VNet 자신과 NAT Gateway·공용 IP에 쓰인다(서브넷·NSG·라우팅 테이블은 그룹 키를 쓴다). | `string` | `"main"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | 리소스 그룹 이름(필수 주입). 이 모듈은 리소스 그룹을 만들지 않는다. RG 삭제는 내부<br/>리소스를 state 밖의 것까지 캐스케이드 삭제하므로, 파괴 반경을 이 모듈이 만드는 자산으로<br/>한정하기 위해서다. | `string` | n/a | yes |
| <a name="input_subnet_groups"></a> [subnet\_groups](#input\_subnet\_groups) | 서브넷 그룹 정의. 키가 곧 서브넷·NSG·라우팅 테이블 name 인자의 토큰이 된다.<br/>  address\_prefixes                 - 그룹당 서브넷 1개의 CIDR 목록(AZ 리스트가 아니다.<br/>                                      Azure 서브넷은 존에 속하지 않는다)<br/>  nat\_routed                       - true면 이 그룹의 아웃바운드를 NAT Gateway로 보낸다<br/>  nsg\_enabled                      - true면 이 그룹에 빈 NSG를 만들고 연결한다(룰은 소비자가<br/>                                      azurerm\_network\_security\_rule로 얹는다)<br/>  route\_table\_enabled              - true면 이 그룹에 라우팅 테이블을 만들고 연결한다(운영<br/>                                      라우트는 소비자가 azurerm\_route로 얹는다)<br/>  default\_outbound\_access\_enabled  - false면 이 서브넷의 기본 아웃바운드 인터넷 접근을 끈다<br/>                                      (provider 기본값과 동일하게 true가 기본)<br/>  service\_endpoints                - 이 서브넷에 켤 서비스 엔드포인트 이름 목록<br/>  delegations                      - 이 서브넷을 위임할 Azure 서비스 목록<br/>  extra\_tags                       - 그룹 단위 추가 태그. NSG·라우팅 테이블에만 적용된다<br/>                                      (서브넷은 tags 인자 자체가 없다)<br/><br/>Azure 예약 이름 서브넷(AzureBastionSubnet · GatewaySubnet · AzureFirewallSubnet, 확인한<br/>것은 이 셋이며 더 있을 수 있다)은 이 모듈이 만들지 않는다. 서브넷 이름이<br/>snet-<workload>-<env>-<region>-<그룹키>로 조합되고 이름 오버라이드 인자가 없어 정확한<br/>예약 이름을 만들 수 없다. 배포 루트가 같은 vnet에 azurerm\_subnet으로 직접 만든다. | <pre>map(object({<br/>    address_prefixes                = list(string)<br/>    nat_routed                      = optional(bool, false)<br/>    nsg_enabled                     = optional(bool, false)<br/>    route_table_enabled             = optional(bool, false)<br/>    default_outbound_access_enabled = optional(bool, true)<br/>    service_endpoints               = optional(list(string), [])<br/>    delegations = optional(list(object({<br/>      name    = string<br/>      actions = list(string)<br/>    })), [])<br/>    extra_tags = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | 이 모듈이 만드는 리소스에 추가할 태그. Azure는 provider 한 곳에서 거버넌스 태그를 주입할<br/>수단이 없어(azurerm에 default\_tags 대응 인자 없음) 리소스마다 명시로 배선한다.<br/>서브넷은 tags 인자 자체를 지원하지 않아 이 값이 적용되지 않는다. NSG·라우팅 테이블에만 붙는다. | `map(string)` | `{}` | no |
| <a name="input_vnet_enabled"></a> [vnet\_enabled](#input\_vnet\_enabled) | kill switch(파괴 방향). false면 이 모듈의 전 리소스를 파기한다.<br/>false일 때 스칼라 출력은 null, map 출력은 빈 값이 된다. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_address_space"></a> [address\_space](#output\_address\_space) | VNet 주소 공간. vnet\_enabled = false면 빈 리스트다. |
| <a name="output_nat_gateway_id"></a> [nat\_gateway\_id](#output\_nat\_gateway\_id) | NAT Gateway ID. vpc(AWS)의 nat\_gateway\_ids(list(string))와 달리 단일 string이다.<br/>vnet당 NAT Gateway가 1개이고 이중화는 존이 아니라 SKU가 결정한다. NAT 비활성이면 null이다. |
| <a name="output_nat_public_ip_address"></a> [nat\_public\_ip\_address](#output\_nat\_public\_ip\_address) | NAT Gateway에 연결된 공용 IP 주소. NAT 비활성이면 null이다. |
| <a name="output_nsg_ids_by_group"></a> [nsg\_ids\_by\_group](#output\_nsg\_ids\_by\_group) | nsg\_enabled = true인 그룹 키 → NSG ID. 나머지 그룹은 키 자체가 없다(만들지 않았으므로). |
| <a name="output_route_table_ids_by_group"></a> [route\_table\_ids\_by\_group](#output\_route\_table\_ids\_by\_group) | route\_table\_enabled = true인 그룹 키 → 라우팅 테이블 ID. 나머지 그룹은 키 자체가 없다.<br/>운영 라우트(온프레미스 경로 등)를 얹는 앵커다. 목적지와 타깃 조합은 모듈이 제약하지 않는다. |
| <a name="output_subnet_ids_by_group"></a> [subnet\_ids\_by\_group](#output\_subnet\_ids\_by\_group) | 그룹 키 → 서브넷 ID. 키는 소비자가 넘긴 subnet\_groups 키 그대로다.<br/>vpc(AWS)의 동명 출력과 달리 map(string)이다. Azure 서브넷은 존에 속하지 않아<br/>그룹당 서브넷이 항상 1개다. |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | VNet ID. vnet\_enabled = false면 null이다. |
| <a name="output_vnet_name"></a> [vnet\_name](#output\_vnet\_name) | VNet 이름. vnet\_enabled = false면 null이다. |
<!-- END_TF_DOCS -->
