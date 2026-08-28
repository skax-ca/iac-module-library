# Azure aks-cluster 모듈 인터페이스
#
# 관심사 순서: 공통 규약 → 배치 → 신원 → 네트워킹 → 시스템 노드 풀 → 추가 노드 풀 → 접근 제어.
#
# 계약: docs/module-catalog.md · docs/decisions.md「Azure 컨테이너 (aks-cluster)」ADR

# ── 공통 규약 ────────────────────────────────────────────────────────────────

variable "naming" {
  description = <<-EOT
    name 인자 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로
    소비자는 약어를 직접 타이핑하지 않는다.
    예: {workload = "demo", env = "prd", region_code = "krc"} → aks-demo-prd-krc-main-01
  EOT
  type = object({
    workload    = string
    env         = string
    region_code = string
  })
  nullable = false
}

variable "purpose" {
  description = "name 인자의 purpose 토큰. 클러스터 자신에 쓰인다."
  type        = string
  default     = "main"
  nullable    = false
}

variable "serial" {
  description = "name 인자의 일련번호 토큰."
  type        = string
  default     = "01"
  nullable    = false
}

variable "tags" {
  description = <<-EOT
    이 모듈이 만드는 리소스(클러스터·노드 풀)에 추가할 태그. Azure는 provider 한 곳에서
    거버넌스 태그를 주입할 수단이 없어(azurerm에 default_tags 대응 인자 없음) 리소스마다
    명시로 배선한다.
  EOT
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "cluster_enabled" {
  description = <<-EOT
    kill switch(파괴 방향). false면 이 모듈의 전 리소스(클러스터·추가 노드 풀)를 파기한다.
    false일 때 스칼라 출력은 null, map 출력은 빈 값이 된다.
  EOT
  type        = bool
  default     = true
  nullable    = false
}

variable "deletion_protection" {
  description = <<-EOT
    삭제 보호(보호 방향). true면 azurerm_kubernetes_cluster에 prevent_destroy가 걸려 파괴
    계획 자체가 차단된다. AKS에는 네이티브 삭제 보호 인자가 없다 — lifecycle 블록이 유일한
    수단이다(modules/azure/vnet과 같은 형태).

    보호를 켠 상태의 파기는 2단계다 — deletion_protection = false로 apply한 뒤
    cluster_enabled = false.
  EOT
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !(var.deletion_protection && !var.cluster_enabled)
    error_message = "deletion_protection = true인 상태에서는 cluster_enabled = false로 파기할 수 없다. deletion_protection = false로 먼저 apply한 뒤 파기한다."
  }
}

# ── 배치 ─────────────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "리소스 그룹 이름(필수 주입). 이 모듈은 리소스 그룹을 만들지 않는다."
  type        = string
  nullable    = false
}

variable "location" {
  description = "Azure 리전(필수 입력)."
  type        = string
  nullable    = false
}

# ── 신원 — 이 모듈은 identity도 role assignment도 만들지 않는다 ─────────────────

variable "identity_id" {
  description = <<-EOT
    클러스터 컨트롤 플레인이 쓸 user-assigned managed identity의 리소스 ID(필수).

    이 모듈은 identity도 role assignment도 만들지 않는다 — 만들면 소비자의 CI 신원이 그
    리소스를 만들 권한(Microsoft.Authorization/roleAssignments/write 포함)을 가져야 하고,
    그 권한은 CI 신원이 자기 자신에게 상위 역할을 부여할 수 있게 만든다(축3,
    docs/decisions.md「Azure 컨테이너 (aks-cluster)」ADR 참조).

    ⚠️ 순서 의존: ① identity 생성 → ② node_subnet_id·pod_subnet_id가 속한 서브넷에 이
    identity의 Network Contributor 역할 부여 → ③ 이 모듈 apply. ②를 건너뛰면 ③은 성공하고
    노드만 조용히 실패한다 — role assignment가 이 모듈 밖에 있어 plan에서 잡을 수 없는
    죽은 경로다. bootstrap 계층이 ①·②를 처리한다.
  EOT
  type        = string
  nullable    = false
}

# ── 네트워킹 — Azure CNI Pod Subnet(flat) 고정, Overlay 미노출 ──────────────────

variable "node_subnet_id" {
  description = <<-EOT
    노드가 속할 서브넷 ID(필수). vnet 모듈의 subnet_ids_by_group["aks-node"] 등을 넘긴다.
    이 서브넷은 위임된 서브넷일 수 없다(delegations를 쓰지 않는다) — AKS 공식 제약이다.
  EOT
  type        = string
  nullable    = false
}

variable "pod_subnet_id" {
  description = <<-EOT
    Pod가 속할 서브넷 ID(필수). vnet 모듈의 subnet_ids_by_group["aks-pod"] 등을 넘긴다 —
    이 모듈은 Pod 서브넷을 만들지 않는다(소유하지 않은 VNet에 서브넷을 만드는 경계 위반이자,
    "CIDR 계산은 소비자 루트가 소유한다"는 규약 위반이기 때문).

    0.1.0은 전 노드 풀(시스템 풀 + var.node_pools 전부)이 이 값 하나를 공유한다. 풀별
    오버라이드는 v0.2.0 이월이다 — 서브넷 교체는 노드 풀 순환을 부르므로 나중에 여는 것도
    비파괴 변경이다.

    네트워킹은 Azure CNI Pod Subnet(flat)로 고정된다 — Overlay는 노출하지 않는다. Overlay는
    Pod 트래픽이 노드 IP로 SNAT돼 NSG 플로우 로그·Network Watcher에서 Pod 단위 관측성이
    사라진다(소비 repo가 이미 확정한 결정, 축5 참조). 필요해지면 클러스터 재생성이 필요하다
    (network_profile은 ForceNew).
  EOT
  type        = string
  nullable    = false
}

variable "service_cidr" {
  description = <<-EOT
    Kubernetes 서비스 주소 범위. 변경 시 클러스터가 재생성된다. dns_service_ip와 함께
    지정하거나 함께 비워야 한다(provider 제약).
  EOT
  type        = string
  default     = null

  validation {
    condition     = (var.service_cidr == null) == (var.dns_service_ip == null)
    error_message = "service_cidr와 dns_service_ip는 둘 다 지정하거나 둘 다 비워야 한다(provider 제약)."
  }
}

variable "dns_service_ip" {
  description = "kube-dns가 쓸, service_cidr 범위 내 IP. 변경 시 클러스터가 재생성된다."
  type        = string
  default     = null
}

variable "private_cluster_enabled" {
  description = <<-EOT
    true면 API 서버가 내부 IP로만 노출된다(공개 엔드포인트 없음). 변경 시 클러스터가
    재생성된다(provider 제약) — eks-cluster의 독립 public/private 토글과 달리 AKS는 이
    값 하나로 공개·비공개를 가른다.

    기본값 true — eks-cluster의 endpoint_public_access 기본값(false, "GitOps(pull)
    전제이므로 기본은 private")과 같은 철학을 따른다. ⚠️ 이 축은 ralplan 설계 라운드가
    깊게 다루지 않았다(G-A·G2처럼 사용자 확인을 거치지 않음) — 구현 시점에 AWS 자매
    모듈과의 대칭을 근거로 판단했다. private_cluster_enabled = false로 여는 것은
    옵트아웃으로 언제든 가능하다.
  EOT
  type        = bool
  default     = true
  nullable    = false
}

variable "authorized_ip_ranges" {
  description = <<-EOT
    API 서버 접근을 허용할 CIDR 목록. 비어 있으면 제한을 걸지 않는다. private_cluster_enabled
    = true인 클러스터에는 적용되지 않는다(provider 동작 — private 클러스터는 애초에 공개
    엔드포인트가 없다).
  EOT
  type        = list(string)
  default     = []
  nullable    = false
}

# ── 시스템 노드 풀 — AKS가 클러스터 리소스의 필수 구성요소로 강제한다 ────────────

variable "system_node_pool" {
  description = <<-EOT
    시스템 노드 풀 설정(default_node_pool). AKS는 시스템 노드 풀을 필수로 강제한다 —
    eks-cluster의 managed_node_groups = {}처럼 빈 값으로 생략할 수 없다(공식 제약,
    default_node_pool 인자 자체가 Required).

    vm_size              - VM 크기(필수)
    node_count           - 고정 노드 수(auto_scaling_enabled = false일 때만 쓰인다)
    auto_scaling_enabled - true면 min_count·max_count로 오토스케일링한다
    min_count/max_count  - auto_scaling_enabled = true일 때만 쓰인다
    os_disk_size_gb      - OS 디스크 크기(GB). 생략하면 provider 기본값
    max_pods             - 노드당 최대 파드 수. 생략하면 provider 기본값
    zones                - 가용 영역 목록. 생략하면 무존 배치
  EOT
  type = object({
    vm_size              = string
    node_count           = optional(number, 1)
    auto_scaling_enabled = optional(bool, false)
    min_count            = optional(number)
    max_count            = optional(number)
    os_disk_size_gb      = optional(number)
    max_pods             = optional(number)
    zones                = optional(list(string))
  })
  nullable = false

  validation {
    condition     = !var.system_node_pool.auto_scaling_enabled || (var.system_node_pool.min_count != null && var.system_node_pool.max_count != null)
    error_message = "system_node_pool.auto_scaling_enabled = true이면 min_count·max_count를 함께 지정한다."
  }
}

# ── 추가(User) 노드 풀 — 이 모듈이 소유한다(축2) ─────────────────────────────────

variable "node_pools" {
  description = <<-EOT
    추가(User) 노드 풀 정의. 맵 키가 노드 풀 이름 "np<키>"의 재료가 된다.

    키 제약(Azure 물리 제약, docs/conventions.md「Azure 강제 방식」6번): 소문자로 시작,
    소문자+숫자만, 8자 이하. `np` 접두사(2자) + 키(최대 8자) = 최대 10자로, AKS 노드 풀
    이름 한도(1~12자, Linux)와 temporary_name_for_rotation(순환용 임시 이름, "<이름>t")이
    쓰는 자리를 함께 남긴다.

    vm_size              - VM 크기(필수)
    node_count           - 고정 노드 수(auto_scaling_enabled = false일 때만 쓰인다)
    auto_scaling_enabled - true면 min_count·max_count로 오토스케일링한다
    min_count/max_count  - auto_scaling_enabled = true일 때만 쓰인다
    os_disk_size_gb      - OS 디스크 크기(GB)
    max_pods             - 노드당 최대 파드 수
    zones                - 가용 영역 목록
    node_labels          - Kubernetes 노드 라벨
    node_taints          - Kubernetes 노드 taint("key=value:Effect" 형태 문자열 목록)

    ⛔ Windows 노드 풀은 0.1.0 스코프 밖이다 — 이름 한도가 6자라 위 키 제약이 성립하지
    않는다(기술적 불가가 아니라 스코프 결정).
  EOT
  type = map(object({
    vm_size              = string
    node_count           = optional(number, 1)
    auto_scaling_enabled = optional(bool, false)
    min_count            = optional(number)
    max_count            = optional(number)
    os_disk_size_gb      = optional(number)
    max_pods             = optional(number)
    zones                = optional(list(string))
    node_labels          = optional(map(string), {})
    node_taints          = optional(list(string), [])
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for key, pool in var.node_pools : can(regex("^[a-z][a-z0-9]{0,7}$", key))
    ])
    error_message = "node_pools 키는 소문자로 시작하고 소문자+숫자만 쓰며 8자 이하여야 한다(Azure 노드 풀 이름 물리 제약)."
  }

  validation {
    condition = alltrue([
      for key, pool in var.node_pools : !pool.auto_scaling_enabled || (pool.min_count != null && pool.max_count != null)
    ])
    error_message = "auto_scaling_enabled = true인 노드 풀은 min_count·max_count를 함께 지정한다."
  }
}

# ── 버전 · SKU ───────────────────────────────────────────────────────────────

variable "kubernetes_version" {
  description = "Kubernetes 버전. 생략하면 provider가 최신 권장 버전을 쓴다(자동 업그레이드는 하지 않는다)."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "클러스터 SKU 티어. Free(기본, SLA 없음)·Standard(Uptime SLA)·Premium 중 하나."
  type        = string
  default     = "Free"
  nullable    = false

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier는 Free, Standard, Premium 중 하나여야 한다."
  }
}

# ── 접근 제어(Entra RBAC) — 옵트인, 로컬 계정 기본 유지(G2 확정) ────────────────

variable "entra_admin_group_object_ids" {
  description = <<-EOT
    Entra ID(Azure AD) RBAC를 켤 Admin 그룹의 Object ID 목록. 비어 있으면 Entra 통합
    블록 자체를 만들지 않는다 — 잠금이 기본 동작이 아니다(옵트인, G2 확정).
  EOT
  type        = list(string)
  default     = []
  nullable    = false
}

variable "local_account_disabled" {
  description = <<-EOT
    true면 로컬 계정(kubeconfig의 클러스터 admin 자격증명)을 비활성화한다. 기본 false로
    브레이크글래스(kube_admin_config) 경로를 유지한다(G2 확정).

    ⚠️ entra_admin_group_object_ids가 비어 있는 채로 이 값을 true로 두면 클러스터 접근
    수단이 전혀 남지 않는다 — provider도 local_account_disabled = true일 때 Entra ID
    RBAC 활성화를 요구한다.
  EOT
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !var.local_account_disabled || length(var.entra_admin_group_object_ids) > 0
    error_message = "local_account_disabled = true이면 entra_admin_group_object_ids를 비워둘 수 없다 — 클러스터 접근 수단이 사라진다."
  }
}

# ── Workload Identity ───────────────────────────────────────────────────────

variable "workload_identity_enabled" {
  description = <<-EOT
    Azure AD Workload Identity 활성화 여부. oidc_issuer_url 출력은 이 값과 무관하게 항상
    나간다(OIDC issuer는 이 모듈이 항상 켠다). 실제 federated identity credential 생성·
    역할 부여는 이 모듈 밖(bootstrap 계층)이다 — 이 값과 oidc_issuer_url 출력은 그 작업이
    딛고 설 원시 재료일 뿐이다.
  EOT
  type        = bool
  default     = false
  nullable    = false
}
