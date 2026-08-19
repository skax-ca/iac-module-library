# EKS 모듈 인터페이스
#
# 계약: docs/05-modules.md
#
# 관심사 순서
# (정체성 → kill switch/보호 → 클러스터 → 환경 프로파일 → custom networking → 노드 → addon → IAM).
# 설계 문서와 같은 순서로 읽히는 것이 계약 검토에 유리하기 때문이다.

# ── 정체성 ───────────────────────────────────────────────────────────────────

variable "naming" {
  description = <<-EOT
    Name 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로
    소비자는 약어를 직접 타이핑하지 않는다.
    예: {workload = "demo", env = "prd", region_code = "an2"} → eks-demo-prd-an2-main-01
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
    여기에 반복하지 않는다.
  EOT
  type        = map(string)
  default     = {}
}

# ── kill switch · 삭제 보호 ──────────────────────────────────────────────────

variable "cluster_enabled" {
  description = <<-EOT
    kill switch(파괴 방향). false면 이 모듈의 전 리소스를 파기하고 data source 조회까지 건너뛴다.
    참조 대상이 사라진 뒤에도 plan이 통과해야 파기가 가능하기 때문이다.
    false일 때 스칼라 출력은 null, map/list 출력은 빈 값이 된다.

    구현은 upstream `create` 토글에 위임한다 — upstream이 자체 data source까지
    게이트하므로 요건이 이미 충족된다.
  EOT
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = <<-EOT
    삭제 보호(보호 방향). true면 aws_eks_cluster의 네이티브 deletion_protection이
    켜져 클러스터를 지울 수 없다.

    ⚠️ vpc 모듈의 prevent_destroy와 메커니즘이 다르다. 이쪽이 더 강하다 —
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
    # 여기서 plan 시점에 우리 변수 이름으로 해법을 알려준다.
    # ⚠️ 교차변수 validation은 validate가 아니라 plan에서 평가된다 — tests/*.tftest.hcl 이 유일한 검출 지점이다.
    condition     = !(var.deletion_protection && !var.cluster_enabled)
    error_message = "deletion_protection = true인 상태에서는 cluster_enabled = false로 파기할 수 없다. deletion_protection = false로 먼저 apply한 뒤 파기한다."
  }
}

# ── 클러스터 ─────────────────────────────────────────────────────────────────

variable "kubernetes_version" {
  description = <<-EOT
    컨트롤플레인 k8s 마이너 버전. N-1 전략을 기본값으로 둔다.
    ⚠️ 이 목록은 낡는다. EKS standard support 창은 계속 이동하므로 올리기 전에 확인한다.

    ⚠️ **cluster_addons로 addon 버전을 고정해 뒀다면 이 값을 올릴 때 그 버전들도 함께 갱신한다**
. addon 버전은 f(kubernetes_version, region)이라 k8s만 올리면
    "그 버전 없음"으로 apply가 죽는다. 특히 kube-proxy는 정의상 k8s 마이너를 따라간다.
    ⚠️ 버전을 안 고정했다면 upstream이 이 값에 맞는 AWS 기본 버전을 해석하므로 할 일이 없다.
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
    노드·컨트롤플레인 ENI가 놓일 서브넷 ID 목록.

    ⚠️ 그룹 키 이름을 가정하지 않고 ID 리스트로 받는다. vpc 모듈의 subnet_groups 키는 소비자가
    정하는 값이고 vpc 모듈이 그 이름을 강제하지 않으므로, 이쪽이 결합하면 조용히 깨진다.
    키 → ID 매핑은 소비자 루트의 책임이다.
  EOT
  type        = list(string)
}

# ── 환경 프로파일 — 소비자가 조건 분기를 짜지 않게 한다 ──────────────────────

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
    public 엔드포인트 접근을 허용할 CIDR 목록.
    ⚠️ 빈 리스트를 넘기면 EKS가 0.0.0.0/0으로 기본 적용한다 — public을 켤 때는 반드시 좁힌다.

    ℹ️ **endpoint_public_access = false면 이 값은 무시된다** — 모듈이 upstream에 null을 넘기기
    때문이다(main.tf 참조). 값을 지워도 AWS는 직전 값을 계속 반환하지만
    plan에는 나타나지 않는다. 그래서 public을 끌 때 이 변수를 비우지 않아도 무해하다.
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

# ── custom networking — vpc 모듈의 secondary CIDR 서브넷을 전제한다 ───────────

variable "enable_custom_networking" {
  description = <<-EOT
    vpc-cni custom networking 활성화 여부. true면 Pod ENI가 pod_subnet_ids의
    비라우팅 대역에 배치되고, 노드는 subnet_ids의 unique 대역 IP로 SNAT된다.
    구성은 vpc-cni addon의 configuration_values로 선언되므로 helm/manifest 경계를 넘지 않는다.
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

    ami_release_version: 지정하면 그 AMI로 고정한다. null이면 최신 해석(하위호환).
    ⚠️ upstream 서브모듈은 use_latest_ami_release_version 기본이 true라 ami_release_version만
    주면 무시된다. 이 모듈이 use_latest = (ami_release_version == null)로 파생해 핀을 실효화한다.

    ami_type: 노드 AMI 계열이자 **CPU 아키텍처의 결정 지점**이다.
    ⚠️ **instance_types와 아키텍처가 반드시 일치해야 한다.** graviton(t4g·m7g·c7g…)을 쓰려면
    ami_type = "AL2023_ARM_64_STANDARD"를 함께 지정한다 — 기본값이 x86이라 arm 인스턴스만 바꾸면
    **AMI와 CPU가 어긋나 노드가 부팅되지 않는다.** 이 조합은 plan에서 잡히지 않는다(AWS도 nodegroup
    생성 시점에야 실패한다) → 아키텍처 짝은 소비자가 맞춘다.
    ⚠️ ami_release_version도 **아키텍처별로 값이 다르다.** arm으로 바꾸면 핀도 arm SSM 경로에서
    다시 얻는다(README "AMI 버전 고정" 절).

    taints는 리스트로 받아 모듈이 upstream의 map 스키마로 변환한다(facade 번역).
  EOT
  type = map(object({
    instance_types      = list(string)
    min_size            = number
    max_size            = number
    desired_size        = number
    capacity_type       = optional(string, "ON_DEMAND")
    ami_type            = optional(string, "AL2023_x86_64_STANDARD")
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

  # ami_type을 **닫힌 목록으로** 검증하는 이유: 오타의 대가가 비대칭이다.
  # "AL2023_ARM64_STANDARD"(밑줄 누락) 같은 값은 plan을 통과해 **클러스터 생성까지 끝난 뒤**
  # 노드그룹 단계에서 AWS API가 거부한다 — 10분을 버리고 부분 생성 상태가 남는다.
  # 여기서 막으면 몇 초 만에 잡힌다.
  #
  # ⚠️ 이 목록은 낡는다. 출처는 EKS API Reference 의 `Nodegroup.amiType` Valid Values 다.
  #    AWS가 계열을 추가하면 이 목록을 갱신한다 — 갱신 전까지 신형 ami_type이 막힌다는 것이 비용이다.
  #    실제 증거: 위 capacity_type 목록은 AWS가 나중에 추가한 `CAPACITY_BLOCK`을 아직 담고 있지 않다.
  #    (닫힌 검증을 늘릴 때마다 이 유지보수 부채가 함께 늘어난다는 뜻이다.)
  validation {
    condition = alltrue([
      for ng in var.managed_node_groups : contains([
        "AL2023_x86_64_STANDARD", "AL2023_ARM_64_STANDARD",
        "AL2023_x86_64_NEURON", "AL2023_x86_64_NVIDIA", "AL2023_ARM_64_NVIDIA",
        "AL2_x86_64", "AL2_x86_64_GPU", "AL2_ARM_64",
        "BOTTLEROCKET_ARM_64", "BOTTLEROCKET_x86_64",
        "BOTTLEROCKET_ARM_64_FIPS", "BOTTLEROCKET_x86_64_FIPS",
        "BOTTLEROCKET_ARM_64_NVIDIA", "BOTTLEROCKET_x86_64_NVIDIA",
        "BOTTLEROCKET_ARM_64_NVIDIA_FIPS", "BOTTLEROCKET_x86_64_NVIDIA_FIPS",
        "WINDOWS_CORE_2019_x86_64", "WINDOWS_FULL_2019_x86_64",
        "WINDOWS_CORE_2022_x86_64", "WINDOWS_FULL_2022_x86_64",
        "WINDOWS_CORE_2025_x86_64", "WINDOWS_FULL_2025_x86_64",
        "CUSTOM",
      ], ng.ami_type)
    ])
    error_message = "managed_node_groups의 ami_type이 EKS API의 유효값이 아니다. graviton은 AL2023_ARM_64_STANDARD 다(AL2023_ARM64_STANDARD 아님)."
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

# ── addon — baseline 과 merge 되는 증분/override ──────────────────────────────

variable "cluster_addons" {
  description = <<-EOT
    baseline addon(addons.tf)에 병합할 증분·override.

    빈 맵이면 baseline을 그대로 상속한다. 소비자 입력은 baseline과 merge되므로 **누락 != 삭제**다
    (맵을 통째로 대체하면 coredns 삭제 = DNS 중단이 되는 문제를 막는다).
    제거는 enabled = false 명시로만 한다 — 암묵 규약을 두지 않는다.

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

variable "cluster_security_group_additional_rules" {
  description = <<-EOT
    cluster SG에 추가할 규칙. EKS 접근 3층의 소유 지점이다.

    "클러스터가 누구를 네트워크로 받아들이는가"는 클러스터 쪽 결정이므로 이 모듈이 소유한다 —
소유 모듈이 허용 소스 목록을 변수로 열고 rule 도 스스로 만든다.
    외부 모듈이 이 SG에 직접 rule을 붙이면 소유자가 쪼개져 drift 와 충돌이 생긴다.

    upstream 스키마를 그대로 통과시킨다(access_entries와 같은 판단):
      { <키> = { from_port, to_port, protocol = "tcp", type = "ingress",
                 description, source_security_group_id | cidr_blocks | source_node_security_group } }

    예 — workbench 에서 apiserver 443:
      { workbench = { from_port = 443, to_port = 443, description = "kubectl from workbench",
                    source_security_group_id = module.workbench.workbench_security_group_id } }

    ⚠️ 이 규칙이 붙는 SG는 **upstream이 만든 cluster SG**이며 EKS가 자동 생성하는
       primary cluster SG와 다르다. 전자가 vpc_config.security_group_ids 로 클러스터에 붙어
       apiserver ENI 에 적용되므로 도달 경로로 성립한다(outputs.tf의 경고 참조).

    ⚠️ upstream 은 이 규칙을 구형 `aws_security_group_rule` 로 만든다 — 우리 규약이 신규 코드에서
       금지한 리소스지만 upstream 내부라 통제 밖이다. 같은 SG 에 우리가 신형 rule 을
       직접 붙이지 않는 이유이기도 하다.
  EOT
  type        = any
  default     = {}
}

variable "enable_karpenter" {
  description = <<-EOT
    Karpenter IAM 전제조건(컨트롤러 role · 노드 role · instance profile · 중단 SQS) 생성 여부.
    helm 설치와 NodePool/NodeClass는 GitOps 소관이다.

    true면 node 보안그룹에 karpenter.sh/discovery 태그도 함께 부여된다 — NodeClass의
    securityGroupSelectorTerms가 이 태그로 SG를 찾는다.
  EOT
  type        = bool
  default     = true
}

variable "enable_cluster_autoscaler" {
  description = <<-EOT
    Cluster Autoscaler IAM 전제조건(Pod Identity role · least-privilege 정책 · scale-from-zero용
    ASG node-template 태그) 생성 여부. helm 설치는 GitOps 소관.

    true면 managed_node_groups의 각 ASG에 k8s.io/cluster-autoscaler/node-template/label/* ·
    .../taint/* 태그가 붙는다(labels·taints 입력을 그대로 미러링). auto-discovery 태그
    (k8s.io/cluster-autoscaler/enabled 등)는 EKS가 관리형 노드그룹 생성 시 자동으로 붙이므로
    이 모듈이 별도로 만들지 않는다.

    Karpenter와 동시에 켤 수 있다 — 서로 다른 리소스를 다룬다(Karpenter=EC2 직접 프로비저닝,
    CA=managed_node_groups의 ASG). 상호 배제하지 않는다. 단, 워크로드를 taint로 분리하지 않으면
    같은 pending pod에 두 컨트롤러가 동시에 반응해 중복 프로비저닝이 발생할 수 있다
    (근거: karpenter.sh FAQ, aws/karpenter-provider-aws#2543).
  EOT
  type        = bool
  default     = false
}

variable "enable_alb_controller_iam" {
  description = <<-EOT
    AWS Load Balancer Controller용 Pod Identity role 생성 여부.
    ALBC 자체는 community addon이 없어 GitOps helm으로 설치되지만, IAM 전제는 IaC 소관이다.
    기본 false인 이유는 유휴 role과 불필요한 diff를 만들지 않기 위해서다 — 소비자 opt-in.
  EOT
  type        = bool
  default     = false
}

variable "enable_external_dns_iam" {
  description = <<-EOT
    external-dns용 Pod Identity role 생성 여부.
    external-dns는 community addon으로 설치되지만 custom 정책이 필요해 eks-pod-identity에 위임한다.
  EOT
  type        = bool
  default     = false
}

variable "external_dns_hosted_zone_arns" {
  description = <<-EOT
    external-dns 정책을 제한할 Route53 hosted zone ARN 목록.

    ⛔ enable_external_dns_iam = true면 비워 둘 수 없다.
    route53:ChangeResourceRecordSets는 리소스 수준 권한을 요구하는 액션이라 Resource = "*"
    정책을 IAM이 거부한다(400 MalformedPolicyDocument). upstream은 이 목록이 비면 정확히
    그 정책을 만든다 — 즉 이것은 prd 권고가 아니라 **모든 환경의 apply 차단 조건**이다.
  EOT
  type        = list(string)
  default     = []

  validation {
    # AWS는 apply 시점에 400을 내지만,
    # 그 오류는 우리 변수 이름으로 해법을 알려주지 않는다 — plan에서 몇 초 만에 잡는다.
    # ⚠️ cluster_enabled 게이트가 필수다: 파기 경로(kill switch)에서는 external-dns IAM이
    #    애초에 생성되지 않으므로(iam.tf의 create = local.enabled && ...) 막을 이유가 없고,
    #    막으면 "끌 수는 있으나 끈 상태를 유지할 수 없는" 반쪽 kill switch가 된다.
    #    pod_subnet_ids 가드가 같은 이유로 같은 형태를 쓴다.
    condition     = !(var.enable_external_dns_iam && var.cluster_enabled) || length(var.external_dns_hosted_zone_arns) > 0
    error_message = "enable_external_dns_iam = true면 external_dns_hosted_zone_arns가 비어 있을 수 없다. AWS가 Resource = \"*\" 정책을 거부하므로 apply가 실패한다 — 대상 hosted zone ARN을 지정하거나 enable_external_dns_iam = false로 명시한다."
  }
}

variable "enable_argocd_hub_pod_identity" {
  description = <<-EOT
    허브 ArgoCD(argocd-application-controller)가 스포크 계정의 크로스 계정 신뢰 Role을
    assume할 수 있는 Pod Identity role 생성 여부.
    기본 false인 이유는 유휴 role과 불필요한 diff를 만들지 않기 위해서다 — 소비자 opt-in.
  EOT
  type        = bool
  default     = false
}

variable "argocd_namespace" {
  description = <<-EOT
    허브 ArgoCD가 설치된 네임스페이스. Pod Identity association의 namespace로 쓰인다.
    ⚠️ scripts/argocd-seed.sh의 ARGOCD_NAMESPACE와 반드시 일치해야 한다 — 어긋나면
    association이 실제 Pod의 서비스 어카운트와 매칭되지 않아 자격증명을 받지 못한다.
  EOT
  type        = string
  default     = "argocd"
}

variable "argocd_hub_assumable_role_arns" {
  description = <<-EOT
    이 허브가 assume할 수 있는 스포크 크로스 계정 신뢰 Role ARN 목록.
    스포크가 늘 때마다 이 목록에 추가한다(현재는 수동 갱신).

    ⛔ enable_argocd_hub_pod_identity = true면 비워 둘 수 없다.
    sts:AssumeRole은 리소스 수준 권한을 요구하는 액션이라 Resource = "*" 정책을
    IAM이 거부한다(400 MalformedPolicyDocument) — external_dns_hosted_zone_arns와 같은 이유다.
  EOT
  type        = list(string)
  default     = []

  validation {
    # external_dns_hosted_zone_arns와 완전히 같은 이유 — plan 단계에서 미리 막는다.
    # ⚠️ cluster_enabled 게이트가 필수다(위 external_dns_hosted_zone_arns 주석과 같은 이유):
    #    kill switch 경로에서는 argocd hub IAM이 애초에 생성되지 않으므로(iam.tf의
    #    create = local.enabled && ...) 막을 이유가 없고, 막으면 "끌 수는 있으나 끈 상태를
    #    유지할 수 없는" 반쪽 kill switch가 된다.
    condition     = !(var.enable_argocd_hub_pod_identity && var.cluster_enabled) || length(var.argocd_hub_assumable_role_arns) > 0
    error_message = "enable_argocd_hub_pod_identity = true면 argocd_hub_assumable_role_arns가 비어 있을 수 없다. AWS가 Resource = \"*\" 정책을 거부하므로 apply가 실패한다 — 대상 스포크 신뢰 Role ARN을 지정하거나 enable_argocd_hub_pod_identity = false로 명시한다."
  }
}
