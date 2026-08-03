# EKS 모듈 인터페이스 — 설계 docs/design/20-eks-module.md §3.1
#
# 변수는 설계 §3.1의 관심사 그룹 순서를 따른다
# (정체성 → kill switch/보호 → 클러스터 → 환경 프로파일 → custom networking → 노드 → addon → IAM).
# 설계 문서와 같은 순서로 읽히는 것이 계약 검토에 유리하기 때문이다.

# ── 정체성 (파라미터화 — 01 §4) ───────────────────────────────────────────────

variable "naming" {
  description = <<-EOT
    Name 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로
    소비자는 약어를 직접 타이핑하지 않는다(02 §1.4(b)).
    예: {workload = "acme", env = "prd", region_code = "an2"} → eks-acme-prd-an2-main-01
  EOT
  type = object({
    workload    = string
    env         = string
    region_code = string
  })
}

variable "purpose" {
  description = "클러스터 이름의 purpose 토큰."
  type        = string
  default     = "main"
}

variable "serial" {
  description = "클러스터 이름의 일련번호 토큰."
  type        = string
  default     = "01"
}

variable "tags" {
  description = <<-EOT
    이 모듈이 만드는 전 리소스에 추가할 태그.
    거버넌스 태그(Workload·Env·Owner 등)는 프로젝트 루트의 provider default_tags 소관이므로
    여기에 반복하지 않는다(02 §1.1).
  EOT
  type        = map(string)
  default     = {}
}

# ── kill switch · 삭제 보호 (D-EKS-ENABLED / D-EKS-PROTECT) ───────────────────

variable "cluster_enabled" {
  description = <<-EOT
    kill switch(파괴 방향). false면 이 모듈의 전 리소스를 파기하고 data source 조회까지 건너뛴다.
    참조 대상이 사라진 뒤에도 plan이 통과해야 teardown이 가능하기 때문이다(01 §4).
    false일 때 스칼라 출력은 null, map/list 출력은 빈 값이 된다.

    구현은 upstream `create` 토글에 위임한다 — upstream이 자체 data source까지
    local.create로 게이트하므로 요건이 이미 충족된다(설계 §3.0, Task 20.1(e) 확인).
  EOT
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = <<-EOT
    삭제 보호(보호 방향, D-EKS-PROTECT). true면 aws_eks_cluster의 네이티브 deletion_protection이
    켜져 클러스터를 지울 수 없다.

    ⚠️ vpc 모듈의 D12(prevent_destroy)와 메커니즘이 다르다. 이쪽이 더 강하다 —
    prevent_destroy는 IaC 차원이라 콘솔·CLI 삭제를 막지 못하지만 이것은 AWS API 차원이다.
    vpc가 prevent_destroy를 쓴 것은 VPC에 네이티브 보호가 없어서지 그 방식이 우월해서가 아니다.

    보호를 켠 상태의 teardown은 2단계다 — deletion_protection = false로 apply한 뒤
    cluster_enabled = false. 이는 결함이 아니라 보호의 정의다.
    기본값이 false인 이유: teardown 보장이 기본 동작이어야 한다. 보호는 opt-in이다.
  EOT
  type        = bool
  default     = false

  validation {
    # AWS도 deletion_protection으로 이 조합을 막지만, 그 오류는 apply 시점에 API가 낸다.
    # 여기서 plan 시점에 우리 변수 이름으로 해법을 알려준다(vpc D12에서 검증된 가드).
    # ⚠️ 교차변수 validation은 validate가 아니라 plan에서 평가된다 — tests/*.tftest.hcl 이 유일한 검출 지점이다.
    condition     = !(var.deletion_protection && !var.cluster_enabled)
    error_message = "deletion_protection = true인 상태에서는 cluster_enabled = false로 파기할 수 없다. deletion_protection = false로 먼저 apply한 뒤 파기한다."
  }
}

# ── 클러스터 ─────────────────────────────────────────────────────────────────

variable "kubernetes_version" {
  description = <<-EOT
    컨트롤플레인 k8s 마이너 버전. N-1 전략을 기본값으로 둔다.
    2026-08-03 기준 EKS standard support는 1.36 / 1.35 / 1.34 / 1.33 이고 최신이 1.36이다.

    ⚠️ 이 값을 올릴 때는 addon baseline 핀(addons.tf)도 그 k8s 버전의 호환 버전으로 함께 갱신한다
    (D-ADDON-VERSION-PIN). 핀이 뒤처지면 호환되지 않는 조합이 apply된다.
  EOT
  type        = string
  default     = "1.35"
}

variable "vpc_id" {
  description = "클러스터를 배치할 VPC ID."
  type        = string
}

variable "subnet_ids" {
  description = <<-EOT
    노드·컨트롤플레인 ENI가 놓일 서브넷 ID 목록(설계 §2.5의 node 그룹).

    ⚠️ 그룹 키 이름을 가정하지 않고 ID 리스트로 받는다. vpc 모듈의 subnet_groups 키는 소비자가
    정하는 값이라(10 §1.3 "모듈이 강제하지 않는다") 이쪽이 그 관용에 결합하면 조용히 깨진다.
    키 → ID 매핑은 소비자 루트의 책임이다.
  EOT
  type        = list(string)
}

# ── 환경 프로파일 (소비자가 조건 분기를 짜지 않게 한다 — 01 §4) ────────────────

variable "endpoint_public_access" {
  description = "kube-apiserver public 엔드포인트 활성화 여부. GitOps(pull) 전제이므로 기본은 private이다."
  type        = bool
  default     = false
}

variable "endpoint_private_access" {
  description = "kube-apiserver private 엔드포인트 활성화 여부."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = <<-EOT
    public 엔드포인트 접근을 허용할 CIDR 목록. endpoint_public_access = false면 의미가 없다.
    ⚠️ 빈 리스트를 넘기면 EKS가 0.0.0.0/0으로 기본 적용한다 — public을 켤 때는 반드시 좁힌다.
  EOT
  type        = list(string)
  default     = []
}

variable "enabled_log_types" {
  description = <<-EOT
    컨트롤플레인 로깅 대상. 유효값: api · audit · authenticator · controllerManager · scheduler.

    기본값이 빈 리스트인 이유는 CloudWatch 비용이다. 다만 **보류를 재사용 자산의 기본값으로
    승계하지 않는다** — 소비자가 켤 수 있게 노출하는 것이 이 모듈의 책임이고,
    켤지 말지는 환경 프로파일의 판단이다(prd 권장). trivy AVD-AWS-0038이 지적하는 항목이다.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for t in var.enabled_log_types :
      contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], t)
    ])
    error_message = "enabled_log_types는 api, audit, authenticator, controllerManager, scheduler 중에서만 지정한다."
  }
}

# ── custom networking (설계 §2.5 — VPC D9 전제) ───────────────────────────────

variable "enable_custom_networking" {
  description = <<-EOT
    vpc-cni custom networking 활성화 여부(VPC D9). true면 Pod ENI가 pod_subnet_ids의
    비라우팅 대역에 배치되고, 노드는 subnet_ids의 unique 대역 IP로 SNAT된다.
    구성은 vpc-cni addon의 configuration_values로 선언되므로 §1의 경계 규칙 안에 남는다.
  EOT
  type        = bool
  default     = true
}

variable "pod_subnet_ids" {
  description = <<-EOT
    Pod ENI(ENIConfig)가 놓일 서브넷 ID 목록. enable_custom_networking = true일 때만 쓰인다.
    AZ 매핑은 모듈이 data.aws_subnet으로 해석하므로 입력은 ID 리스트로 단순하게 유지한다.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = !(var.enable_custom_networking && var.cluster_enabled) || length(var.pod_subnet_ids) > 0
    error_message = "enable_custom_networking = true면 pod_subnet_ids가 비어 있을 수 없다. custom networking을 쓰지 않으려면 enable_custom_networking = false로 명시한다."
  }
}

# ── 노드 (시스템 계층 NG — 앱·버스트는 Karpenter) ──────────────────────────────

variable "managed_node_groups" {
  description = <<-EOT
    managed 노드그룹 정의. 맵 키가 노드그룹 이름 토큰이 된다.

    ami_release_version(D-NODE-AMI-PIN): 지정하면 그 AMI로 고정한다. null이면 최신 해석(하위호환).
    ⚠️ upstream 서브모듈은 use_latest_ami_release_version 기본이 true라 ami_release_version만
    주면 무시된다. 이 모듈이 use_latest = (ami_release_version == null)로 파생해 핀을 실효화한다.

    taints는 리스트로 받아 모듈이 upstream의 map 스키마로 변환한다(facade 번역).
  EOT
  type = map(object({
    instance_types      = list(string)
    min_size            = number
    max_size            = number
    desired_size        = number
    capacity_type       = optional(string, "ON_DEMAND")
    ami_release_version = optional(string)
    labels              = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for ng in var.managed_node_groups : contains(["ON_DEMAND", "SPOT"], ng.capacity_type)
    ])
    error_message = "managed_node_groups의 capacity_type은 ON_DEMAND 또는 SPOT이어야 한다."
  }

  validation {
    condition = alltrue([
      for ng in var.managed_node_groups : alltrue([
        for t in ng.taints : contains(["NO_SCHEDULE", "NO_EXECUTE", "PREFER_NO_SCHEDULE"], t.effect)
      ])
    ])
    error_message = "taint의 effect는 NO_SCHEDULE, NO_EXECUTE, PREFER_NO_SCHEDULE 중 하나여야 한다."
  }
}

# ── addon (설계 §2.6 C′ — baseline과 merge되는 증분/override) ──────────────────

variable "cluster_addons" {
  description = <<-EOT
    baseline addon(addons.tf)에 병합할 증분·override.

    빈 맵이면 baseline을 그대로 상속한다. 소비자 입력은 baseline과 merge되므로 **누락 != 삭제**다
    (설계 §2.6-1: 맵을 통째로 대체하면 coredns 삭제 = DNS 중단이 되는 문제를 막는다).
    제거는 enabled = false 명시로만 한다 — 암묵 규약을 두지 않는다(§2.6-2).

    ⚠️ core 4종(vpc-cni · coredns · kube-proxy · eks-pod-identity-agent)은 비활성화할 수 없다.
    eks-pod-identity-agent가 core인 이유는 Karpenter·EBS CSI의 association 생존 전제이기 때문이다 —
    없으면 IAM에는 role이 있는데 Pod가 자격증명을 못 받는 조용한 파손이 된다.
  EOT
  type = map(object({
    enabled       = optional(bool, true)
    addon_version = optional(string)
    configuration = optional(string)
    pod_identity = optional(object({
      role_arn        = string
      service_account = string
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, cfg in var.cluster_addons :
      cfg.enabled if contains(["vpc-cni", "coredns", "kube-proxy", "eks-pod-identity-agent"], name)
    ])
    error_message = "core addon(vpc-cni, coredns, kube-proxy, eks-pod-identity-agent)은 enabled = false로 비활성화할 수 없다."
  }
}

# ── IAM ──────────────────────────────────────────────────────────────────────

variable "access_entries" {
  description = <<-EOT
    EKS Access Entry 정의(aws-auth ConfigMap 대체). upstream 스키마를 그대로 통과시킨다.

    ⚠️ 이 변수는 type = any 다. upstream이 필드를 자주 늘리는 영역이라 facade가 구조를 복제하면
    upstream 변경마다 이 모듈이 막는 문지기가 된다. 계약 안정성보다 통과가 나은 드문 경우다.
  EOT
  type        = any
  default     = {}
}

variable "enable_karpenter" {
  description = <<-EOT
    Karpenter IAM 전제조건(컨트롤러 role · 노드 role · instance profile · 중단 SQS) 생성 여부.
    helm 설치와 NodePool/NodeClass는 GitOps 소관이다(설계 §1 경계).

    true면 node 보안그룹에 karpenter.sh/discovery 태그도 함께 부여된다 — NodeClass의
    securityGroupSelectorTerms가 이 태그로 SG를 찾는다.
  EOT
  type        = bool
  default     = true
}

variable "enable_alb_controller_iam" {
  description = <<-EOT
    AWS Load Balancer Controller용 Pod Identity role 생성 여부(설계 §2.6a).
    ALBC 자체는 community addon이 없어 GitOps helm으로 설치되지만, IAM 전제는 IaC 소관이다.
    기본 false인 이유는 유휴 role과 불필요한 diff를 만들지 않기 위해서다 — 소비자 opt-in.
  EOT
  type        = bool
  default     = false
}

variable "enable_external_dns_iam" {
  description = <<-EOT
    external-dns용 Pod Identity role 생성 여부(설계 §2.6a).
    external-dns는 community addon으로 설치되지만 custom 정책이 필요해 eks-pod-identity에 위임한다.
  EOT
  type        = bool
  default     = false
}

variable "external_dns_hosted_zone_arns" {
  description = <<-EOT
    external-dns 정책을 제한할 Route53 hosted zone ARN 목록.

    ⚠️ 비워 두면 커뮤니티 모듈이 전체 zone(*)을 허용한다. prd에서는 반드시 좁힌다 —
    설계 §2.6a가 "zone ARN 축소가 prd 필수"로 명시한 항목이다.
  EOT
  type        = list(string)
  default     = []
}
