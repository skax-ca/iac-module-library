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

# ── 네트워킹 — CNI 모드 선택형(0.2.0부터), 세 모드 전부 이 모듈이 지원한다 ──────

variable "cni_mode" {
  description = <<-EOT
    Pod가 IP를 받는 방식. 세 값 중 하나(모두 network_plugin = "azure" 기반 — kubenet·none은
    노출하지 않는다, 축5 원 결정 유지):

      "overlay"     (기본, 0.3.0부터) — Azure CNI Overlay + Cilium 데이터플레인
                     (network_data_plane = "cilium"로 고정, network_policy도 함께
                     "cilium"로 고정 — provider 문서가 "When network_data_plane is
                     set to cilium, the network_policy field must be set to cilium"
                     이라 명시하고 ARM도 어기면 "Cilium dataplane requires network
                     policy cilium."으로 거부한다, 0.4.0에서 정정). Pod가 VNet 밖 별도 CIDR
                     (pod_cidr, 필수)에서 IP를 받고 클러스터 밖으로 나갈 때 노드 IP로
                     SNAT된다 — NSG 플로우 로그·Network Watcher에서 Pod 단위 관측성이
                     사라진다. 대신 Microsoft의 두 공식 문서가 이 모드를 일반 권고로
                     명시한다: plan-pod-networking("Our general recommendation is to use
                     Azure CNI Overlay")·AKS baseline 참조 아키텍처("we recommend it for
                     most deployments"). 관측성 손실은 유료 애드온 Advanced Container
                     Networking Services(ACNS)의 Container Network Observability(eBPF로
                     SNAT 이전 Pod identity 캡처)로 다른 방식으로 메울 수 있다 — NSG
                     플로우 로그의 완전한 대체재는 아니다(저장 로그는 Cilium 데이터플레인
                     전용, 기본 집계는 개별 Pod IP 대신 워크로드 단위로 뭉침). NAP
                     (enable_karpenter)과 호환된다. 서브넷 IP 소모가 가장 적다(노드당
                     오버레이 /24, VNet IP는 노드만 쓴다, 기본 max-pods도 250으로 가장
                     높다). pod_subnet_id는 반드시 비워야 한다.

      "pod_subnet"  — Azure CNI Pod Subnet(flat). Pod가 node_subnet_id와 분리된 전용
                     서브넷(pod_subnet_id, 필수)에서 VNet IP를 받는다. SNAT 없이 NSG
                     플로우 로그·Network Watcher에서 Pod 단위 관측성이 유지된다(0.1.0~
                     0.2.0의 기본값이었던 축5 원 결정). ⛔ NAP(enable_karpenter = true)와
                     호환되지 않는다 — Dynamic·Static Block 두 방식 모두
                     karpenter-provider-azure가 지원하지 않는다고 메인테이너가 명시했다
                     (github.com/Azure/karpenter-provider-azure#1352, 2026-01-15 오픈,
                     미해결). enable_karpenter의 교차변수 validation이 이 조합을 막는다.
                     Microsoft의 일반 권고 대상이 아니다(plan-pod-networking: 밖에서 Pod로
                     직접 접근해야 하는 명확한 요구가 있을 때만 flat을 쓰라고 명시).

      "node_subnet" — Azure CNI(Legacy/Node Subnet). Pod가 node_subnet_id와 **같은**
                     서브넷에서 VNet IP를 받는다(pod_subnet_id는 반드시 비워야 한다).
                     SNAT 없어 관측성은 "pod_subnet"과 동일하게 유지되면서 NAP도 쓸 수
                     있는 조합이다(공식 문서 확인,
                     learn.microsoft.com/en-us/azure/aks/node-auto-provisioning-networking
                     의 Supported networking configurations 3가지 중 하나). 대가: 서브넷
                     하나가 노드+Pod IP를 함께 소모한다 — 사이징을 다시 해야 한다(공식
                     계산식: (노드수+서지)+(노드수+서지)×max_pods,
                     learn.microsoft.com/en-us/azure/aks/concepts-network-ip-address-planning).
                     Microsoft는 "직접 Pod IP 접근이 필요하고 관리 단순화가 우선일 때"만
                     권고한다.

    ⚠️ `network_profile` 블록 전체가 provider에 의해 ForceNew다(azurerm_kubernetes_cluster
    문서 확인 완료) — "overlay"로 오가는 전환은 클러스터가 재생성된다. "pod_subnet" ↔
    "node_subnet"만은 예외다: pod_subnet_id는 network_profile이 아니라 default_node_pool에
    있어 temporary_name_for_rotation을 통한 노드 풀 순환으로 처리된다(클러스터 전체
    재생성이 아니다).
  EOT
  type        = string
  default     = "overlay"
  nullable    = false

  validation {
    condition     = contains(["pod_subnet", "node_subnet", "overlay"], var.cni_mode)
    error_message = "cni_mode는 \"pod_subnet\", \"node_subnet\", \"overlay\" 중 하나여야 한다."
  }
}

variable "node_subnet_id" {
  description = <<-EOT
    노드가 속할 서브넷 ID(필수, 모든 cni_mode 공통). vnet 모듈의
    subnet_ids_by_group["aks-node"] 등을 넘긴다. 이 서브넷은 위임된 서브넷일 수 없다
    (delegations를 쓰지 않는다) — AKS 공식 제약이다.

    ⚠️ cni_mode = "node_subnet"일 때는 이 서브넷이 Pod IP도 함께 감당한다 — cni_mode
    변수 설명의 사이징 공식을 참고해 충분히 큰 서브넷을 넘긴다.
  EOT
  type        = string
  nullable    = false
}

variable "pod_subnet_id" {
  description = <<-EOT
    Pod가 속할 서브넷 ID. cni_mode = "pod_subnet"일 때만 지정한다(그 외 모드에서는 반드시
    비워야 한다 — 아래 validation). vnet 모듈의 subnet_ids_by_group["aks-pod"] 등을
    넘긴다 — 이 모듈은 Pod 서브넷을 만들지 않는다(소유하지 않은 VNet에 서브넷을 만드는
    경계 위반이자, "CIDR 계산은 소비자 루트가 소유한다"는 규약 위반이기 때문).

    0.2.0도 전 노드 풀(시스템 풀 + var.node_pools 전부)이 이 값 하나를 공유한다. 풀별
    오버라이드는 이월이다 — 서브넷 교체는 노드 풀 순환을 부르므로 나중에 여는 것도
    비파괴 변경이다.
  EOT
  type        = string
  default     = null

  validation {
    condition     = (var.cni_mode == "pod_subnet") == (var.pod_subnet_id != null)
    error_message = "pod_subnet_id는 cni_mode = \"pod_subnet\"일 때만 지정한다(그 외 모드에서는 비워야 한다)."
  }
}

variable "pod_cidr" {
  description = <<-EOT
    cni_mode = "overlay"일 때 Pod IP로 쓸 CIDR(VNet 밖, 노드당 /24를 예약한다 — 공식
    문서 확인). 그 외 모드에서는 반드시 비워야 한다(provider 제약 자체가
    network_plugin_mode가 "overlay"가 아니면 pod_cidr 설정을 막는다).
  EOT
  type        = string
  default     = null

  validation {
    condition     = (var.cni_mode == "overlay") == (var.pod_cidr != null)
    error_message = "pod_cidr는 cni_mode = \"overlay\"일 때만 지정한다(그 외 모드에서는 비워야 한다)."
  }
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

variable "private_cluster_public_fqdn_enabled" {
  description = <<-EOT
    true면 private 클러스터에 추가로 공개 FQDN을 만든다 — 이 이름은 공개 DNS로 조회
    가능하지만 그 이름이 반환하는 IP는 여전히 private다(공식 문서: "A public FQDN
    doesn't create a public API endpoint or remove the requirement for network
    connectivity to the private endpoint"). private_cluster_enabled = false면 무의미
    (provider가 무시). 기본 false — private_cluster_enabled 하나로 공개·비공개를 가르는
    이 모듈의 기존 기본 방침을 그대로 유지하고, 이 옵션은 옵트인이다.

    ForceNew 아님(provider 소스 `kubernetes_cluster_resource.go` 확인 — Update 함수가
    `d.HasChanges("private_cluster_public_fqdn_enabled", ...)`로 in-place 갱신). 이미
    private_cluster_enabled = true로 떠 있는 클러스터에도 재생성 없이 켤 수 있다.

    소비 예: 크로스 구독/크로스 계정에서 API 서버에 접근해야 하는데(예: hub의 GitOps
    컨트롤러가 spoke 클러스터를 관리) 상대 VNet에 이 클러스터의 private DNS zone을 링크할
    방법이 마땅치 않은 경우 — 공개 DNS가 private IP를 직접 반환하므로 zone 링크 없이도
    네트워크 경로(vWAN·피어링 등)만 있으면 이름 해석이 된다. AWS EKS의 private-only
    엔드포인트가 기본으로 하는 것과 같은 메커니즘(공식 문서 `cluster-endpoint.html`:
    "resolved by public DNS servers to a private IP address").
  EOT
  type        = bool
  default     = false
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

# ── Node Auto Provisioning(Karpenter) ───────────────────────────────────────

variable "enable_karpenter" {
  description = <<-EOT
    Node Auto Provisioning(NAP) 활성화 여부. NAP은 오픈소스 Karpenter + AKS Karpenter
    provider(github.com/Azure/karpenter-provider-azure) 기반이다 — eks-cluster의
    enable_karpenter와 개념이 대응한다. 구현 위치는 다르다: AWS는 별도 IAM 리소스 뭉치
    (컨트롤러 role·노드 role·instance profile·중단 SQS)가 필요하지만, Azure는 이 클러스터
    리소스의 필드 하나(node_provisioning_profile.mode)로 끝난다 — 추가 리소스가 없다.

    true면 node_provisioning_profile.mode = "Auto"로 설정한다. default_node_pool(시스템
    노드 풀)은 Auto에서도 여전히 필수다(공식 문서 확인 — NAP이 대체하는 것은 추가 노드 풀
    수요이지 시스템 풀이 아니다). Karpenter NodePool·AKSNodeClass CRD 설치와 실제 노드
    프로비저닝 정책은 이 모듈 밖(GitOps 소관)이다 — eks-cluster가 "helm 설치와
    NodePool/NodeClass는 GitOps 소관"이라고 선을 긋는 것과 같은 경계다.

    ⛔ **네트워킹 조합 확정(2026-09-03, 0.1.0의 "미검증" 딱지를 확정으로 교체)**:
    karpenter-provider-azure 메인테이너가 공식 이슈에서 직접 명시했다 — "Currently
    Karpenter on Azure does not support Azure CNI Pod Subnet (either dynamic IP
    allocation or static block allocation)"(github.com/Azure/karpenter-provider-azure#1352,
    2026-01-15 오픈, 아직 미해결). 즉 cni_mode = "pod_subnet"과는 절대 못 쓴다 — 아래
    validation이 이 조합을 plan에서 차단한다. cni_mode = "node_subnet" 또는 "overlay"를
    쓴다(cni_mode 변수 설명 참조). cni_mode 기본값이 "overlay"(0.3.0부터)라 지금은 기본값
    조합 자체는 NAP과 호환된다 — 그래도 enable_karpenter 기본값은 false로 유지한다. NAP은
    노드 프로비저닝 정책(GitOps가 관리할 NodePool·AKSNodeClass)이 따로 갖춰져야 의미가
    있는 옵트인 기능이라, 소비자가 명시적으로 켜야 한다(eks-cluster의 enable_karpenter
    기본값이 true인 것과는 이 지점에서 대칭을 깬다 — GitOps 준비 없이 기본 켜짐이면
    NodePool 정의가 없는 상태로 NAP만 도는 죽은 설정이 된다). cni_mode = "pod_subnet"으로
    바꾸면서 enable_karpenter = true를 동시에 켜는 조합만 아래 validation이 차단한다.

    이 저장소는 배포하지 않으므로(`.claude/rules/terraform.md`) live Azure로 실제 노드
    프로비저닝까지는 확인할 수 없다 — 스키마 수준(mode 값·default_node_pool 존재·
    network_profile 조합 유효성)만 보장한다.
  EOT
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !var.enable_karpenter || var.cni_mode != "pod_subnet"
    error_message = "enable_karpenter = true는 cni_mode = \"pod_subnet\"과 함께 쓸 수 없다 — karpenter-provider-azure가 Pod Subnet(dynamic·static block 모두)을 지원하지 않는다(github.com/Azure/karpenter-provider-azure#1352). cni_mode를 \"node_subnet\" 또는 \"overlay\"로 바꾸거나 enable_karpenter를 false로 둔다."
  }
}

# ── KEDA(이벤트 기반 오토스케일링) ───────────────────────────────────────────

variable "enable_keda" {
  description = <<-EOT
    KEDA(Kubernetes Event-driven Autoscaling) managed add-on 활성화 여부. eks-cluster에는
    이 변수와 대응하는 것이 없다 — AWS는 KEDA를 GitOps로 소비자가 직접 설치해야 하지만
    (eks-platform-gitops의 addons/catalog/keda.yaml), Azure는 AKS 자신이 operator·metrics
    server까지 완전 관리형으로 제공한다(Microsoft 공식문서 aks/keda-about: "The managed
    KEDA add-on provides a fully supported KEDA installation integrated with AKS"). 그래서
    이 모듈은 `workload_autoscaler_profile.keda_enabled` 필드 하나로 끝난다 — enable_karpenter
    (node_provisioning_profile)와 같은 형태이지만, ScaledObject/ScaledJob은 애플리케이션
    팀이 쓰는 워크로드 리소스라 GitOps 소관 CR조차 없다(NodePool/AKSNodeClass와 다른 지점).

    true면 workload_autoscaler_profile.keda_enabled = true로 설정한다. 이 값은 azurerm
    공식 문서(kubernetes_cluster.html.markdown) 확인 결과 ForceNew 표시가 없어 in-place
    전환이다.

    ⚠️ Workload Identity를 쓰는 경우 공식 문서가 KEDA add-on **이전에** Workload Identity를
    먼저 켜라고 명시한다("If you plan to use workload identity on AKS Standard, enable
    workload identity before enabling the KEDA add-on") — 이 모듈은 workload_identity_enabled
    를 KEDA보다 먼저(같은 리소스 블록 내 선언 순서와 무관하게 apply 시 함께 적용되므로)
    조건화하지 않는다. 순서가 실제로 문제가 되면(예: 이미 워크로드가 KEDA로 스케일 중인
    상태에서 뒤늦게 workload identity를 켜는 경우) 공식 문서의 KEDA operator 파드 재시작
    절차(`kubectl rollout restart deployment keda-operator -n kube-system`)를 소비자가
    수동으로 따른다 — 이 모듈이 자동화하지 않는다(둘 다 opt-in 변수라 동시 최초 활성화가
    일반적인 경로).
  EOT
  type        = bool
  default     = false
  nullable    = false
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

variable "entra_integration_enabled" {
  description = <<-EOT
    entra_admin_group_object_ids 없이도 Entra 통합(Azure RBAC 포함)을 켜는 독립 토글.
    기본 false — 기존처럼 admin 그룹을 지정해야만 켜지는 경로는 그대로 유지된다. true면
    admin 그룹이 비어 있어도 Entra 통합 블록이 생성되고 azure_rbac_enabled = true로
    켜진다(사람 admin 접근 없이, 접근 권한 전부를 소비자가 이 모듈 밖에서 role
    assignment로 부여하는 시나리오 — 예: 크로스 구독 GitOps 컨트롤러 접근).

    ⚠️ Entra 통합은 켠 뒤 되돌릴 수 없다 — Azure가 통합 해제 자체를 지원하지 않는다
    (`az aks update --disable-azure-rbac`는 Azure RBAC만 개별로 끄고, Entra 통합 자체는
    끌 수 없다. 공식 문서 `managed-azure-ad`: "Microsoft Entra integration can't be
    disabled after it's enabled on a cluster."). 되돌리려면 클러스터 재생성이 필요하다.
  EOT
  type        = bool
  default     = false
  nullable    = false
}

variable "local_account_disabled" {
  description = <<-EOT
    true면 로컬 계정(kubeconfig의 클러스터 admin 자격증명)을 비활성화한다. 기본 false로
    브레이크글래스(kube_admin_config) 경로를 유지한다(G2 확정).

    ⚠️ entra_admin_group_object_ids와 entra_integration_enabled가 둘 다 비어/false인
    채로 이 값을 true로 두면 클러스터 접근 수단이 전혀 남지 않는다 — provider도
    local_account_disabled = true일 때 Entra ID RBAC 활성화를 요구한다.
  EOT
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition = !var.local_account_disabled || (
      length(var.entra_admin_group_object_ids) > 0 || var.entra_integration_enabled
    )
    error_message = "local_account_disabled = true이면 entra_admin_group_object_ids 또는 entra_integration_enabled 중 하나로 Entra 통합이 켜져 있어야 한다 — 클러스터 접근 수단이 사라진다."
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

# ── App Routing(web_app_routing) ────────────────────────────────────────────

variable "web_app_routing" {
  description = <<-EOT
    App Routing add-on(`web_app_routing` 블록) 설정. `null`(기본)이면 블록 자체를 만들지
    않는다 — entra_admin_group_object_ids·authorized_ip_ranges와 같은 옵트인 형태다.

    dns_zone_ids              - DNS Zone 리소스 ID 목록(provider 스키마상 블록 안에서는
                                 Required이지만 빈 배열이 유효한 값이다 — 이 변수의 기본값도
                                 `[]`). App Routing의 자동 DNS 레코드 생성을 쓰지 않으면
                                 비워도 된다.
    default_nginx_controller  - 기본 NginxIngressController 커스텀 리소스의 인그레스 타입.
                                 `"None"`·`"Internal"`·`"External"`·`"AnnotationControlled"`
                                 (provider 기본값) 중 하나. Gateway API 경로만 쓰고 레거시
                                 NGINX 인그레스 컨트롤러 자동 생성을 원치 않으면 `"None"`으로
                                 명시한다.

    🔑 **이 변수 하나로 Gateway API·Istio 모드까지 켜지지는 않는다.** azurerm은 아직
    `ingressProfile.gatewayAPI`·`webAppRouting.gatewayAPIImplementations`(관리형 Gateway
    API 설치·Istio 구현체 전환)를 노출하지 않는다(hashicorp/terraform-provider-azurerm#22392,
    확인 시점 2026-09-07) — 그 두 필드는 이 모듈 밖에서 `azapi_update_resource`로 얹어야
    한다(aks-reference-infra의 `live/hub/aks`가 실사용 예). 이 변수의 목적은 그 값 자체를
    대신 켜주는 게 아니라, **azurerm이 실제로 아는 하위 필드(`enabled`·`dns_zone_ids`·
    `default_nginx_controller`)를 이 모듈이 소비자 대신 선언해, azurerm 자신의 plan이 그
    필드들을 두고 azapi와 충돌하지 않게 하는 것**이다 — 이 변수를 넘기지 않은 채
    `azapi_update_resource`로 `ingressProfile.webAppRouting.enabled = true`만 얹으면,
    azurerm이 자기 스키마 안의 `web_app_routing` 블록이 HCL에 없다는 이유로 다음 plan마다
    그 값을 되돌리려 한다(실측: aks-reference-infra의 apply 후 수렴 검증에서 재현).
  EOT
  type = object({
    dns_zone_ids             = optional(list(string), [])
    default_nginx_controller = optional(string)
  })
  default = null

  validation {
    condition = (
      var.web_app_routing == null ||
      var.web_app_routing.default_nginx_controller == null ||
      contains(["None", "Internal", "External", "AnnotationControlled"], var.web_app_routing.default_nginx_controller)
    )
    error_message = "web_app_routing.default_nginx_controller는 \"None\", \"Internal\", \"External\", \"AnnotationControlled\" 중 하나이거나 비워야 한다."
  }
}
