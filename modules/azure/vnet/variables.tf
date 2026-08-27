# Azure vnet 모듈 인터페이스
#
# 관심사 순서: 공통 규약 → 배치 → 주소 공간 → 서브넷 그룹 → 아웃바운드(NAT).
#
# 계약: docs/module-catalog.md

# ── 공통 규약 ────────────────────────────────────────────────────────────────

variable "naming" {
  description = <<-EOT
    name 인자 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로
    소비자는 약어를 직접 타이핑하지 않는다.
    예: {workload = "demo", env = "dev", region_code = "krc"} → vnet-demo-dev-krc-main
  EOT
  type = object({
    workload    = string
    env         = string
    region_code = string
  })
  nullable = false
}

variable "purpose" {
  description = "name 인자의 purpose 토큰. VNet 자신과 NAT Gateway·공용 IP에 쓰인다(서브넷·NSG·라우팅 테이블은 그룹 키를 쓴다)."
  type        = string
  default     = "main"
  nullable    = false
}

variable "tags" {
  description = <<-EOT
    이 모듈이 만드는 리소스에 추가할 태그. Azure는 provider 한 곳에서 거버넌스 태그를 주입할
    수단이 없어(azurerm에 default_tags 대응 인자 없음) 리소스마다 명시로 배선한다.
    서브넷은 tags 인자 자체를 지원하지 않아 이 값이 적용되지 않는다 — NSG·라우팅 테이블에만 붙는다.
  EOT
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "vnet_enabled" {
  description = <<-EOT
    kill switch(파괴 방향). false면 이 모듈의 전 리소스를 파기한다.
    false일 때 스칼라 출력은 null, map 출력은 빈 값이 된다.
  EOT
  type        = bool
  default     = true
  nullable    = false
}

variable "deletion_protection" {
  description = <<-EOT
    삭제 보호(보호 방향). true면 azurerm_virtual_network에 prevent_destroy가 걸려 파괴 계획
    자체가 차단된다. 보호를 켠 상태의 파기는 2단계다 — deletion_protection = false로 apply한
    뒤 vnet_enabled = false.

    보호 범위가 vpc와 다르다: Azure는 vnet 삭제가 내부 서브넷을 함께 지운다. 이 모듈은 vnet
    하나에만 보호를 걸고 서브넷 개별 보호는 제공하지 않는다.

    기본값이 false인 이유: 파기가 기본 동작이어야 한다. 보호는 opt-in이다.
    소비자 사용 예: deletion_protection = var.env == "prd"
  EOT
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !(var.deletion_protection && !var.vnet_enabled)
    error_message = "deletion_protection = true인 상태에서는 vnet_enabled = false로 파기할 수 없다. deletion_protection = false로 먼저 apply한 뒤 파기한다."
  }
}

# ── 배치 ─────────────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = <<-EOT
    리소스 그룹 이름(필수 주입). 이 모듈은 리소스 그룹을 만들지 않는다 — RG 삭제는 내부
    리소스를 state 밖의 것까지 캐스케이드 삭제하므로, 파괴 반경을 이 모듈이 만드는 자산으로
    한정하기 위해서다.
  EOT
  type        = string
  nullable    = false
}

variable "location" {
  description = <<-EOT
    Azure 리전(필수 입력, 리소스 그룹 data source에서 파생하지 않는다). data source 조회는
    "이번 plan에서 변경 예정인 관리 리소스에 직접 의존할 때"만 apply를 연기하는 조건부 동작이라,
    리터럴을 넘기면 배포 성공이 소비자 배선 형태에 좌우된다. 배포 루트는 RG와 vnet을 한
    apply에서 세울 수 있다 — 이 모듈이 RG를 읽지 않기 때문이다.
  EOT
  type        = string
  nullable    = false
}

# ── 주소 공간 ────────────────────────────────────────────────────────────────

variable "address_space" {
  description = "VNet 주소 공간(CIDR 목록)."
  type        = list(string)
  nullable    = false
}

# ── 서브넷 그룹 ──────────────────────────────────────────────────────────────

variable "subnet_groups" {
  description = <<-EOT
    서브넷 그룹 정의. 키가 곧 서브넷·NSG·라우팅 테이블 name 인자의 토큰이 된다.
      address_prefixes                 - 그룹당 서브넷 1개의 CIDR 목록(AZ 리스트가 아니다 —
                                          Azure 서브넷은 존에 속하지 않는다)
      nat_routed                       - true면 이 그룹의 아웃바운드를 NAT Gateway로 보낸다
      nsg_enabled                      - true면 이 그룹에 빈 NSG를 만들고 연결한다(룰은 소비자가
                                          azurerm_network_security_rule로 얹는다)
      route_table_enabled              - true면 이 그룹에 라우팅 테이블을 만들고 연결한다(운영
                                          라우트는 소비자가 azurerm_route로 얹는다)
      default_outbound_access_enabled  - false면 이 서브넷의 기본 아웃바운드 인터넷 접근을 끈다
                                          (provider 기본값과 동일하게 true가 기본)
      service_endpoints                - 이 서브넷에 켤 서비스 엔드포인트 이름 목록
      delegations                      - 이 서브넷을 위임할 Azure 서비스 목록
      extra_tags                       - 그룹 단위 추가 태그. NSG·라우팅 테이블에만 적용된다
                                          (서브넷은 tags 인자 자체가 없다)

    Azure 예약 이름 서브넷(AzureBastionSubnet · GatewaySubnet · AzureFirewallSubnet, 확인한
    것은 이 셋이며 더 있을 수 있다)은 이 모듈이 만들지 않는다 — 서브넷 이름이
    snet-<workload>-<env>-<region>-<그룹키>로 조합되고 이름 오버라이드 인자가 없어 정확한
    예약 이름을 만들 수 없다. 배포 루트가 같은 vnet에 azurerm_subnet으로 직접 만든다.
  EOT
  type = map(object({
    address_prefixes                = list(string)
    nat_routed                      = optional(bool, false)
    nsg_enabled                     = optional(bool, false)
    route_table_enabled             = optional(bool, false)
    default_outbound_access_enabled = optional(bool, true)
    service_endpoints               = optional(list(string), [])
    delegations = optional(list(object({
      name    = string
      actions = list(string)
    })), [])
    extra_tags = optional(map(string), {})
  }))
  default  = {}
  nullable = false
}

# ── 아웃바운드(NAT) — 소비자가 조건 분기를 짜지 않게 한다 ──────────────────────

variable "nat_gateway_enabled" {
  description = <<-EOT
    NAT Gateway 생성 여부. true라도 subnet_groups 중 nat_routed = true인 그룹이 0개면
    조용히 만들지 않는다(수요와 결합, 기본값 조합에서 plan이 깨지지 않게 하기 위해서다).
  EOT
  type        = bool
  default     = true
  nullable    = false
}

variable "nat_gateway_sku_name" {
  description = <<-EOT
    NAT Gateway SKU. "Standard"는 GA이고 무존이거나 단일 존이다. "StandardV2"는 존 이중화를
    제공하지만 preview다(SLA 대상 아님, 일부 리전 미지원) — 배송 모듈의 기본값으로 강제할 수
    없어 기본은 GA인 "Standard"를 쓴다.

    변경은 리소스 재생성을 강제해 아웃바운드 공용 IP가 바뀐다. 고객사 방화벽 allowlist에
    직결되므로 신중히 바꾼다.
  EOT
  type        = string
  default     = "Standard"
  nullable    = false

  validation {
    condition     = contains(["Standard", "StandardV2"], var.nat_gateway_sku_name)
    error_message = "nat_gateway_sku_name은 Standard 또는 StandardV2여야 한다."
  }
}

variable "nat_gateway_zones" {
  description = <<-EOT
    NAT Gateway를 배치할 가용 영역 목록. "Standard" SKU에서만 의미가 있다(0개면 무존, 1개면
    단일 존 배치). "StandardV2"는 zone-redundant가 기본이라 provider가 이 값을 아예 받지
    않는다 — nat_gateway_sku_name = "StandardV2"일 때는 null이거나 빈 리스트여야 한다.
  EOT
  type        = list(string)
  default     = null

  validation {
    condition     = var.nat_gateway_sku_name != "StandardV2" || var.nat_gateway_zones == null || length(var.nat_gateway_zones) == 0
    error_message = "nat_gateway_sku_name = \"StandardV2\"일 때는 nat_gateway_zones를 지정할 수 없다(null이거나 빈 리스트여야 한다) — StandardV2는 zone-redundant가 기본이라 provider가 명시적 zones를 거부한다."
  }
}
