# aks-workbench 모듈 인터페이스
#
# 관심사 순서: 정체성 → kill switch → 배치 → 접속 모델 → 신원 → 인증 자료 →
# 이미지·디스크 → AKS 연동 → 도구.
#
# 계약: docs/module-catalog.md

# ── 정체성 ───────────────────────────────────────────────────────────────────

variable "naming" {
  description = <<-EOT
    name 인자 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로
    소비자는 약어를 직접 타이핑하지 않는다.
    예: {workload = "demo", env = "prd", region_code = "krc"} → vm-demo-prd-krc-workbench-01
  EOT
  type = object({
    workload    = string
    env         = string
    region_code = string
  })
  nullable = false
}

variable "purpose" {
  description = "name 인자의 purpose 토큰."
  type        = string
  default     = "workbench"
  nullable    = false
}

variable "serial" {
  description = "name 인자의 일련번호 토큰."
  type        = string
  default     = "01"
  nullable    = false
}

variable "resource_group_name" {
  description = "이 모듈이 만드는 전 리소스를 배치할 리소스 그룹."
  type        = string
  nullable    = false
}

variable "location" {
  description = "리소스를 배치할 Azure 리전."
  type        = string
  nullable    = false
}

variable "tags" {
  description = <<-EOT
    이 모듈이 만드는 전 리소스에 연동할 태그. Azure는 provider 한 곳에서 거버넌스 태그를
    주입할 수 없어(docs/conventions.md「Azure 강제 방식」1번) 모듈이 리소스마다 명시로 넘긴다.
  EOT
  type        = map(string)
  default     = {}
  nullable    = false
}

# ── kill switch ──────────────────────────────────────────────────────────────

variable "workbench_enabled" {
  description = <<-EOT
    kill switch(파괴 방향). false면 이 모듈의 전 리소스를 파기한다.
    false일 때 스칼라 출력은 전부 null이 된다.

    ⚠️ AWS workbench와 동일하게 삭제 보호 대상이 아니다 — 수시 생성·파기가 정상 운용이다.
  EOT
  type        = bool
  default     = true
  nullable    = false
}

# ── 배치 ─────────────────────────────────────────────────────────────────────

variable "subnet_id" {
  description = <<-EOT
    workbench VM을 놓을 서브넷. AWS workbench의 subnet_id(private 서브넷 전제, AZ 분산
    불필요)와 같은 형태다 — workbench는 1대이므로 리스트를 받아 내부에서 고르지 않는다.
  EOT
  type        = string
  nullable    = false
}

# ── 접속 모델 — SSH가 일상 경로, Run Command가 브레이크글래스 ──────────────────

variable "ssh_ingress_cidrs" {
  description = <<-EOT
    SSH(22/tcp) 인바운드를 허용할 CIDR 목록. 소스 무관 — Bastion 서브넷 CIDR·P2S VPN
    풀·ExpressRoute 대역·사무실 공인 IP 전부 이 값으로 받는다.

    이 값이 비어있지 않은 것이 일상 운영이 가능한 상태다. Azure NSG는 규칙을 하나도 안
    만들어도 플랫폼 기본 규칙(AllowVNetInBound)이 같은 VNet·피어링·온프레미스 전체에
    22번을 열어두므로, 이 모듈은 명시적 Deny(priority 4096, main.tf 참조)로 그 기본
    규칙을 실제로 덮는다 — "인바운드 0"은 규칙 개수가 아니라 그 Deny의 존재로 성립한다.

    ⚠️ 기본값이 없다(필수 입력) — ami_id와 같은 계약이다. "진짜 인바운드 0"이 성립하는
    유일한 구성(빈 리스트)이 곧 일상 운영이 불가능한 구성이기도 해서, 침묵하는 기본값에
    맡기면 이 모듈의 안전성 주장이 아무도 쓰지 않을 설정에서만 참이 된다. 빈 리스트를
    원하면 ssh_ingress_cidrs = []를 명시적으로 써야 한다(entra_ssh_login_enabled = false와
    한 세트로 — 아래 변수 설명 참조).
  EOT
  type        = list(string)
  nullable    = false
}

variable "public_ip_enabled" {
  description = <<-EOT
    공용 IP를 만들지 여부. VPN/ExpressRoute로 이미 사설 경로가 있는 소비자는 false로 두고
    ssh_ingress_cidrs에 그 사설 대역만 채운다.
  EOT
  type        = bool
  default     = false
  nullable    = false

  validation {
    # public_ip_enabled = true인데 ssh_ingress_cidrs가 비어 있으면 공용 노출만 만들고
    # 아무도 못 들어오는 죽은 구성이 된다 — plan에서 막는다.
    condition     = !var.workbench_enabled || !var.public_ip_enabled || length(var.ssh_ingress_cidrs) > 0
    error_message = "public_ip_enabled = true인데 ssh_ingress_cidrs가 비어 있다. 공용 IP만 만들고 아무도 접속 못 하는 구성이다."
  }
}

# ── 신원 — dual identity, client_id 유예 없음 ──────────────────────────────────

variable "identity_id" {
  description = <<-EOT
    user-assigned managed identity의 리소스 ID. aks-cluster와 같은 경계 원칙(축3) —
    이 모듈은 identity도 role assignment도 만들지 않는다. custom_data에서
    `az login --identity --resource-id`로 쓴다.
  EOT
  type        = string
  nullable    = false
}

variable "identity_client_id" {
  description = <<-EOT
    identity_id와 같은 identity의 client ID(GUID). kubelogin의 msi 모드가
    `--client-id`로 요구한다(az login과 별개 CLI라 인자 체계가 다르다).

    aks_entra_rbac_enabled = true일 때만 소비된다(kubelogin convert-kubeconfig 슬롯) — 그
    외에는 조건부로 무시되는 값이라 기본값을 null로 둔다. AKS 연동 없이 워크벤치만 쓰는
    소비자는 이 값을 채울 필요가 없다(아래 aks_entra_rbac_enabled 교차 validation 참조).
  EOT
  type        = string
  default     = null
}

# ── 인증 자료 — 소비자 공개키 입력, Entra SSH 확장은 별도 게이트 ────────────────

variable "admin_ssh_public_key" {
  description = <<-EOT
    로컬 관리 계정(admin_username)의 SSH 공개키. 기본값이 없다 = 필수 입력이다.
    private key는 이 모듈이 전혀 다루지 않는다 — 소비자가 자기 공개키만 넘긴다.

    ⚠️ Azure는 VM 생성 시 비밀번호 또는 SSH 키 중 하나를 강제한다(플랫폼 요구). 이
    모듈이 SSH 키만 받는 것은 그중 하나를 고른 선택이다.
  EOT
  type        = string
  nullable    = false
}

variable "admin_username" {
  description = <<-EOT
    로컬 관리 계정 사용자명. admin_ssh_key.username(provider Required)과 VM 로컬 계정
    이름에 공용으로 쓰인다.

    Entra ID SSH(entra_ssh_login_enabled)로 로그인하는 사람은 이 로컬 계정과 완전히
    별개의 자기 신원으로 들어온다 — 이 값은 사실상 브레이크글래스 계정 이름표일 뿐이라
    고정값으로 충분하고, 조직 표준이 있으면 바꿀 수 있게 변수로만 열어 둔다.
  EOT
  type        = string
  default     = "azureuser"
  nullable    = false
}

variable "entra_ssh_login_enabled" {
  description = <<-EOT
    Entra ID 계정으로 SSH 로그인하는 AADSSHLoginForLinux 확장을 만들지 여부. 기본
    true(주 인증 경로) — ssh_ingress_cidrs(네트워크 도달성)와는 직교하는 관심사라 별도
    변수로 분리했다(둘 다 채워야 실제로 Entra SSH를 쓸 수 있다).

    이 확장은 apply 시점에 packages.microsoft.com·login.microsoftonline.com·
    pas.windows.net(전부 443/tcp) + IMDS로 나가는 아웃바운드를 요구한다(MS Learn
    「Network」절). 순수 격리 환경(아웃바운드 자체가 없는 배포)에서는 false로 꺼서 그
    의존 자체를 없앤다 — 이때는 ssh_ingress_cidrs = []와 한 세트로 지정해야 "일상 운영
    불가"라는 결과를 소비자가 plan 시점에 이미 알고 있는 상태로 만든다(README 참조).

    ⚠️ true로 두면 identity에 System-assigned가 강제로 필요하다(이 확장의 요구사항,
    exit code 22) — main.tf의 identity 블록이 이 게이트와 무관하게 항상
    "SystemAssigned, UserAssigned"인 이유다.
  EOT
  type        = bool
  default     = true
  nullable    = false
}

# ── 이미지·디스크 ─────────────────────────────────────────────────────────────

variable "source_image_reference" {
  description = <<-EOT
    OS 이미지 참조. 기본값이 없다(필수 입력) — ami_id와 같은 계약이다. 리전·세대 갱신은
    소비 루트가 소유한다. Ubuntu LTS를 권장한다(Entra SSH 지원 배포판 목록에 Amazon
    Linux 계열이 없다는 것이 결정적 근거 — README 참조).
  EOT
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  nullable = false

  validation {
    condition     = lower(var.source_image_reference.version) != "latest"
    error_message = "source_image_reference.version에 \"latest\"를 쓰지 않는다 — 재현성이 깨진다(같은 코드로 다른 시점에 만든 VM 두 대가 다른 이미지를 갖게 된다). 정확한 버전을 핀한다."
  }
}

variable "os_disk_caching" {
  description = "OS 디스크 캐싱 모드."
  type        = string
  default     = "ReadWrite"
  nullable    = false
}

variable "os_disk_storage_account_type" {
  description = "OS 디스크 스토리지 계정 종류."
  type        = string
  default     = "StandardSSD_LRS"
  nullable    = false
}

variable "os_disk_size_gb" {
  description = <<-EOT
    OS 디스크 크기(GiB). null이면 이미지 기본 크기를 그대로 쓴다.
    ⚠️ 기본값을 두지 않는다 — 이미지 기본 디스크보다 작게 줄 수 없다는 provider 제약이
    있어, 이미지를 정하는 소비 루트가 같이 정하는 게 맞다(모듈이 닫힌 가정을 갖지 않는다).
  EOT
  type        = number
  default     = null
}

variable "os_disk_encryption_set_id" {
  description = <<-EOT
    OS 디스크 암호화에 쓸 Disk Encryption Set ID. null이면 플랫폼 관리형 키를 쓴다
    (암호화 자체는 끌 수 없다 — CMK 사용 여부만 선택).
  EOT
  type        = string
  default     = null
}

# ── VM 크기 ────────────────────────────────────────────────────────────────

variable "vm_size" {
  description = "VM 크기(SKU)."
  type        = string
  default     = "Standard_B2s"
  nullable    = false
}

# ── AKS 연동 — kubeconfig 부트스트랩, aks-cluster와 같은 경계(role assignment는 밖) ──

variable "aks_cluster_name" {
  description = <<-EOT
    kubeconfig를 생성할 AKS 클러스터 이름. null이면 kubeconfig를 만들지 않는다(az CLI
    설치 여부와도 무관하게 그 단계를 건너뛴다).

    ⚠️ aks_resource_group_name과 함께 주거나 함께 비운다(아래 validation).
  EOT
  type        = string
  default     = null
}

variable "aks_resource_group_name" {
  description = <<-EOT
    aks_cluster_name이 속한 리소스 그룹. null이면 kubeconfig를 만들지 않는다.

    ⚠️ aks_cluster_name과 함께 주거나 함께 비운다.
  EOT
  type        = string
  default     = null

  validation {
    # AWS workbench의 eks_cluster_name/eks_cluster_arn 쌍과 같은 이유 — 한쪽만 주면
    # kubeconfig 생성 명령의 인자가 반쪽만 채워져 apply 후(부팅 시점)에야 실패가 드러난다.
    condition     = !var.workbench_enabled || (var.aks_cluster_name == null) == (var.aks_resource_group_name == null)
    error_message = "aks_cluster_name과 aks_resource_group_name은 함께 지정하거나 함께 비워야 한다. 한쪽만 주면 kubeconfig 생성 명령이 반쪽만 채워져 부팅 시점에야 실패가 드러난다."
  }
}

variable "aks_entra_rbac_enabled" {
  description = <<-EOT
    대상 AKS 클러스터가 Entra RBAC(aks-cluster 모듈의 entra_admin_group_object_ids 옵트인)를
    쓰는지. true면 kubelogin convert-kubeconfig -l msi로 kubeconfig를 변환하는 단계가
    추가된다 — 로컬 계정 전용 클러스터에는 이 변환이 불필요하다.

    true면 aks_cluster_name·aks_resource_group_name·identity_client_id·kubelogin_version
    넷 다 값이 있어야 한다(kubelogin 변환 명령 자체가 앞의 셋을 요구하고, 그 명령을
    실행할 kubelogin 바이너리 설치에 버전 핀이 필요하다 — 아래 validation).
  EOT
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition = !var.workbench_enabled || !var.aks_entra_rbac_enabled || (
      var.aks_cluster_name != null &&
      var.aks_resource_group_name != null &&
      var.identity_client_id != null &&
      var.kubelogin_version != null
    )
    error_message = "aks_entra_rbac_enabled = true면 aks_cluster_name·aks_resource_group_name·identity_client_id·kubelogin_version을 전부 지정해야 한다 — kubelogin convert-kubeconfig -l msi가 앞의 셋을 요구하고, 그 명령 자체를 실행할 kubelogin 바이너리 설치에 버전 핀이 필요하다(2026-09-04 code-review 발견: 이 값이 없으면 kubelogin이 설치조차 안 돼 변환이 조용히 실패하고 stale kubeconfig가 그대로 쓰였다)."
  }
}

variable "kubelogin_version" {
  description = <<-EOT
    설치할 kubelogin(Azure/kubelogin) 버전(예: "v0.2.19", "v" 접두사 포함). null이면
    설치하지 않는다 — aks_entra_rbac_enabled = true일 때는 필수(위 validation).

    kubectl_version 등과 달리 기본값을 null로만 두지 않고 aks_entra_rbac_enabled와
    교차 검증하는 이유: 이 값이 없으면 kubelogin 바이너리 자체가 없어
    `kubelogin convert-kubeconfig -l msi`가 "command not found"로 실패하는데, 스크립트에
    set -e가 없어 그 실패가 조용히 넘어가고 변환 안 된 stale kubeconfig가 그대로
    배포되는 문제가 있었다(2026-09-04 aks-reference-infra 실배포 code-review로 발견).
  EOT
  type        = string
  default     = null
}

variable "az_cli_version" {
  description = <<-EOT
    설치할 az CLI 버전(apt 패키지 버전 문자열 전체, codename 포함 — 예:
    "2.72.0-1~noble"). null이면 az CLI를 설치하지 않는다.

    ⚠️ 2.72.0 이상을 권장한다. az login --identity --resource-id는 az CLI 2.69.0부터
    지원되지만, --username으로 UAMI를 지정하는 옛 경로가 아직 살아있던 2.69~2.72
    구간의 혼선을 피하기 위해 그 이후 버전으로 하한을 둔다.

    ⚠️ 이 모듈은 codename을 유도하지 않는다(닫힌 매핑 금지) — 버전 문자열 전체를 그대로
    apt에 넘긴다. source_image_reference가 정하는 배포판·codename과 정합하는 값을
    소비 루트가 함께 관리한다.
  EOT
  type        = string
  default     = null

  validation {
    # aks_cluster_name이 있으면 kubeconfig 부트스트랩(custom_data)이 az CLI를 요구한다.
    # az_cli_version이 null이면 az CLI 자체가 설치되지 않아 그 단계가 부팅 시점에야
    # 조용히 실패한다 — plan에서 막는다.
    condition     = !var.workbench_enabled || var.aks_cluster_name == null || var.az_cli_version != null
    error_message = "aks_cluster_name을 지정했으면 az_cli_version도 함께 지정해야 한다 — az CLI 없이는 kubeconfig 부트스트랩이 성립하지 않는다."
  }
}

# ── 도구(custom_data) — null이면 설치하지 않는다 ────────────────────────────────

variable "kubectl_version" {
  description = "설치할 kubectl 버전(예: \"v1.35.7\"). null이면 설치하지 않는다."
  type        = string
  default     = null
}

variable "helm_version" {
  description = "설치할 helm 버전(예: \"v3.21.3\"). null이면 설치하지 않는다."
  type        = string
  default     = null
}

variable "argocd_version" {
  description = "설치할 argocd CLI 버전(예: \"v3.5.0\"). null이면 설치하지 않는다."
  type        = string
  default     = null
}

variable "krew_version" {
  description = <<-EOT
    설치할 krew(kubectl 플러그인 관리자) 버전(예: "v0.5.0"). null이면 설치하지 않는다.
    kubectl_version이 null이면 이 값도 무시된다.
  EOT
  type        = string
  default     = null
}

variable "krew_plugins" {
  description = <<-EOT
    krew로 설치할 플러그인 목록. krew_version이 null이면 무시된다.
    닫힌 열거가 아니다 — 고객사가 다른 세트를 원하면 이 변수로 바꾼다.
  EOT
  type        = list(string)
  default     = ["ctx", "ns", "neat", "rbac-tool", "view-secret", "whoami"]
  nullable    = false
}

variable "aks_node_viewer_version" {
  description = <<-EOT
    설치할 aks-node-viewer 버전(예: "v0.0.2-alpha"). null이면 설치하지 않는다.

    ⚠️ Azure/aks-node-viewer는 eks-node-viewer의 공식 fork이지만 2024-11 이후 갱신이
    없는 alpha 단계다(리서치 확인) — 프로덕션 의존으로 삼지 말 것. 설치 실패도
    부팅을 막지 않는다(다른 도구 슬롯과 동일).
  EOT
  type        = string
  default     = null
}
