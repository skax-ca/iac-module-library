# VPC 모듈 인터페이스
#
# 관심사 순서: 공통 규약 → 주소 공간 → 환경 프로파일 → Flow Logs.
#
# 계약: docs/05-modules.md

# ── 공통 규약 ────────────────────────────────────────────────────────────────

variable "naming" {
  description = <<-EOT
    Name 태그 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로
    소비자는 약어를 직접 타이핑하지 않는다.
    예: {workload = "demo", env = "dev", region_code = "an2"} → vpc-demo-dev-an2-main
  EOT
  type = object({
    workload    = string
    env         = string
    region_code = string
  })
}

variable "purpose" {
  description = "Name 태그의 purpose 토큰. VPC 자신과 IGW·Flow Logs 리소스에 쓰인다(서브넷은 그룹 키를 쓴다)."
  type        = string
  default     = "main"
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

variable "vpc_enabled" {
  description = <<-EOT
    kill switch(파괴 방향). false면 이 모듈의 전 리소스를 파기하고 data source 조회까지 건너뛴다.
    참조 대상이 사라진 뒤에도 plan이 통과해야 파기가 가능하기 때문이다.
    false일 때 스칼라 출력은 null, map/list 출력은 빈 값이 된다.
  EOT
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = <<-EOT
    삭제 보호(보호 방향). true면 aws_vpc에 prevent_destroy가 걸려 파괴 계획 자체가 차단된다.
    보호를 켠 상태의 파기는 2단계다 — deletion_protection = false로 apply한 뒤 vpc_enabled = false.
    이는 결함이 아니라 보호의 정의다.

    기본값이 false인 이유: 파기가 기본 동작이어야 한다. 보호는 opt-in이다.
    소비자 사용 예: deletion_protection = var.env == "prd"
  EOT
  type        = bool
  default     = false

  validation {
    # 엔진도 prevent_destroy로 이 조합을 막지만, 그 메시지는 우리 변수 이름으로 해법을 알려주지 않는다.
    # 여기서 먼저 잡아 도메인 언어로 안내한다. prevent_destroy는 최종 방어선으로 남는다.
    condition     = !(var.deletion_protection && !var.vpc_enabled)
    error_message = "deletion_protection = true인 상태에서는 vpc_enabled = false로 파기할 수 없다. deletion_protection = false로 먼저 apply한 뒤 파기한다."
  }
}

# ── 주소 공간 ────────────────────────────────────────────────────────────────

variable "cidr_block" {
  description = "VPC primary CIDR."
  type        = string
}

variable "secondary_cidr_blocks" {
  description = <<-EOT
    추가 연결할 secondary CIDR 목록. 예: Pod 전용 ["100.64.0.0/16"].
    ⚠️ primary가 10.0.0.0/15 범위 안이면 10.0.0.0/16 대역 secondary는 연결할 수 없다.
    이 제약은 apply 시 API가 검출하므로 plan 기반 test로는 잡히지 않는다.
  EOT
  type        = list(string)
  default     = []
}

variable "az_count" {
  description = <<-EOT
    최대 AZ 슬라이스 수. 그룹별 실제 AZ 수는 subnet_groups[*].cidrs의 길이가 결정한다.
    az_selection을 지정할 경우 그 길이가 이 값과 같아야 한다.
  EOT
  type        = number
  default     = 3
}

variable "az_selection" {
  description = <<-EOT
    AZ suffix 우선순위 목록. 각 그룹은 이 목록의 앞에서부터 length(cidrs)개 AZ에 배치된다.
    예: ["a", "c", "b"] → 2AZ 그룹은 a·c, 3AZ 그룹은 a·c·b.
    null이면 리전 AZ 목록의 앞 az_count개를 그대로 쓴다.
  EOT
  type        = list(string)
  default     = null

  validation {
    # az_count를 참조하는 교차 변수 validation은 OpenTofu 1.9+ 기능이다.
    # required_version 1.12.0의 근거는 이것이 아니다(versions.tf 참조) — 여기는 사용처일 뿐이다.
    condition     = var.az_selection == null || length(coalesce(var.az_selection, [])) == var.az_count
    error_message = "az_selection을 지정하면 그 길이가 az_count와 같아야 한다."
  }
}

variable "subnet_groups" {
  description = <<-EOT
    서브넷 그룹 정의. 키가 곧 Name 태그의 purpose 토큰이 된다.
      type       - "public" | "private" | "isolated". 라우팅과 RT 구성을 결정한다
      cidrs      - AZ 순서대로 명시한 CIDR. 리스트 길이가 곧 그 그룹의 AZ 수다
      eks_role   - "elb" | "internal-elb" | null. EKS 서브넷 디스커버리 태그를 붙인다
      extra_tags - 그룹 단위 추가 태그
    그룹 키는 <용도 축약>-<uniq|dup> 형식을 권고하나 모듈이 강제하지는 않는다.
    2 <= length(cidrs) <= az_count 제약은 main.tf의 precondition이 검증한다.
  EOT
  type = map(object({
    type       = string
    cidrs      = list(string)
    eks_role   = optional(string)
    extra_tags = optional(map(string), {})
  }))

  validation {
    condition = alltrue([
      for g in var.subnet_groups : contains(["public", "private", "isolated"], g.type)
    ])
    error_message = "subnet_groups의 type은 public, private, isolated 중 하나여야 한다."
  }

  validation {
    # eks_role 미지정(null)도 허용값이다. contains()에 null을 넘기지 않으려고
    # sentinel "-"로 치환해 비교한다 — 조건식 단락 평가에 기대지 않기 위함이다.
    condition = alltrue([
      for g in var.subnet_groups :
      contains(["elb", "internal-elb", "-"], coalesce(g.eks_role, "-"))
    ])
    error_message = "subnet_groups의 eks_role은 elb, internal-elb 중 하나이거나 미지정이어야 한다."
  }
}

# ── 환경 프로파일 — 소비자가 조건 분기를 짜지 않게 한다 ──────────────────────

variable "enable_nat_gateway" {
  description = <<-EOT
    private 그룹에 NAT Gateway 경로를 구성할지 여부.
    NAT는 type이 public인 첫 번째 그룹(맵 키 정렬 기준)의 서브넷에 배치된다.
    public 그룹이 없는 상태에서 true면 검증 오류다.
  EOT
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = <<-EOT
    true면 NAT Gateway 1개를 전 AZ가 공유한다(dev — 비용 우선).
    false면 AZ별로 1개씩 만든다(prd — 가용성 우선).
  EOT
  type        = bool
  default     = false
}

variable "eks_cluster_name" {
  description = <<-EOT
    EKS 서브넷 디스커버리 태그(kubernetes.io/cluster/<name>)에 쓸 클러스터 이름.
    null이면 클러스터 태그를 붙이지 않는다.
  EOT
  type        = string
  default     = null
}

# ── Flow Logs ────────────────────────────────────────────────────────────────

variable "flow_logs_enabled" {
  description = "VPC Flow Logs 생성 여부. 대상은 CloudWatch Logs로 고정한다."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = <<-EOT
    Flow Logs 로그 그룹의 보존 기간(일). 0은 무기한 보존이다.
    유효값은 aws_cloudwatch_log_group.retention_in_days가 허용하는 값으로 제한된다.
  EOT
  type        = number
  default     = 30

  validation {
    # aws provider가 허용하는 값 전체다 — 임의로 늘리거나 줄이지 않는다.
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.flow_logs_retention_days
    )
    error_message = "flow_logs_retention_days는 CloudWatch Logs가 허용하는 값이어야 한다(0 또는 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653)."
  }
}

variable "flow_logs_traffic_type" {
  description = "Flow Logs가 수집할 트래픽 종류."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_logs_traffic_type)
    error_message = "flow_logs_traffic_type은 ACCEPT, REJECT, ALL 중 하나여야 한다."
  }
}

variable "flow_logs_kms_key_id" {
  description = <<-EOT
    Flow Logs 로그 그룹 암호화에 쓸 KMS CMK ARN.
    KMS 키는 계정 전역 공유·보안 거버넌스 대상이라 모듈이 생성하지 않고 주입받는다.
    null이면 CloudWatch 기본 암호화(AWS 관리 키)로 동작한다.
  EOT
  type        = string
  default     = null
}
