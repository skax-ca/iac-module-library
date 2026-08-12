# workbench 모듈 인터페이스
#
# 관심사 순서: 정체성 → kill switch → 배치 → 인스턴스 → 도구 → EKS 연동 → egress.
#
# 계약: docs/05-modules.md

# ── 정체성 ───────────────────────────────────────────────────────────────────

variable "naming" {
  description = <<-EOT
    Name 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로
    소비자는 약어를 직접 타이핑하지 않는다.
    예: {workload = "acme", env = "prd", region_code = "an2"} → ec2-acme-prd-an2-workbench-01
  EOT
  type = object({
    workload    = string
    env         = string
    region_code = string
  })
}

variable "purpose" {
  description = "Name 태그의 purpose 토큰."
  type        = string
  default     = "workbench"
}

variable "serial" {
  description = "Name 태그의 일련번호 토큰."
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

# ── kill switch ──────────────────────────────────────────────────────────────

variable "workbench_enabled" {
  description = <<-EOT
    kill switch(파괴 방향). false면 이 모듈의 전 리소스를 파기한다.
    false일 때 스칼라 출력은 전부 null이 된다.

    ⚠️ workbench는 삭제 보호(deletion_protection) 대상이 아니다 — 수시 생성·파기가 정상 운용이고
    상태를 담지 않는다. vpc가 삭제 보호를 갖는 것과 대칭으로 만들지 않는 것이 의도된 차이다.
  EOT
  type        = bool
  default     = true
}

# ── 배치 ─────────────────────────────────────────────────────────────────────

variable "vpc_id" {
  description = "workbench SG를 만들 VPC."
  type        = string
}

variable "subnet_id" {
  description = <<-EOT
    workbench를 놓을 서브넷 **하나**. workbench는 1대이므로 AZ 분산이 의미가 없다 —
    리스트를 받아 내부에서 고르면 "어느 AZ에 떴는지"가 모듈 내부 규칙에 숨는다.

    ⚠️ **private 서브넷 전제**다. 인바운드가 0이므로 public 서브넷은 이득 없이 공격면만 늘린다.
    모듈은 이를 검사하지 않는다 — "public 서브넷 + 공인 IP 미할당"도 기술적으로 유효하고,
    닫힌 검증은 값이 늘 때마다 부채가 되기 때문이다.
  EOT
  type        = string
}

# ── 인스턴스 ─────────────────────────────────────────────────────────────────

variable "ami_id" {
  description = <<-EOT
    AMI ID. 기본값이 없다 = 필수 입력이다.

    ⛔ `.../al2023-ami-latest/...` SSM 파라미터나 most_recent 조회를 쓰지 않는다.
    latest는 AWS 릴리스마다 값이 바뀌어 **리뷰 없이 인스턴스가 재생성**된다.

    ⚠️ 모듈이 기본값을 갖지 않는 이유는 AMI ID가 **리전 종속**이기 때문이다. 핀의 소유자는
    소비 루트다 — addon 버전 핀과 같은 구조다. 값 조회법은 예제 README 참조.
  EOT
  type        = string
}

variable "instance_type" {
  description = <<-EOT
    인스턴스 타입. 기본 t4g.small(arm64, RAM 2GB).

    ⛔ t4g.nano(0.5GB)로 내리지 말 것. 부팅 중 `dnf`가 OOM-killer에 죽는다(실측:
    `Killed process (dnf) total-vm:976324kB`) — git이 설치되지 않아 GitOps 클론이 성립하지 않는다.
    ⚠️ `free -m`이 보여주는 swap은 `/dev/zram0`(RAM 압축)이라 **여유 용량이 아니다.**
    self-hosted runner로 겸용하지 않으므로 빌드 부하는 여전히 고려하지 않는다.
    비용을 줄이려면 타입을 내리는 것이 아니라 workbench_enabled = false로 끈다.

    ⚠️ **ami_id의 아키텍처와 정합해야 한다.** 모듈은 검증하지 않는다 — 검증하려면 AMI를
    조회해야 하고(핀의 취지와 충돌), 타입 문자열에서 아키텍처를 유도하는 것은 닫힌 열거를
    새로 만드는 일이다. 불일치는 apply에서 드러난다.
  EOT
  type        = string
  default     = "t4g.small"
}

variable "root_volume_size" {
  description = <<-EOT
    root EBS 볼륨 크기(GiB). 기본 10은 도구 바이너리 설치에 충분하다.
    ⚠️ user_data가 /var/tmp(루트 EBS)로 다운로드하므로 이 값이 tmpfs 고갈을 막는 근거다.
  EOT
  type        = number
  default     = 10
}

variable "root_volume_kms_key_id" {
  description = <<-EOT
    root 볼륨 암호화에 쓸 고객 관리형 KMS 키 ARN. null이면 AWS 관리형 키를 쓴다.
    ⚠️ 암호화 자체는 끌 수 없다 — encrypted = true는 계약이다.
  EOT
  type        = string
  default     = null
}

# ── 도구 (user_data) ──────────────────────────────────────────────────────────

variable "kubectl_version" {
  description = <<-EOT
    설치할 kubectl 버전(예: "v1.35.7"). null이면 설치하지 않는다.
    클러스터 마이너와 맞춘다 — https://dl.k8s.io/release/stable-<major.minor>.txt 로 확인한다.
  EOT
  type        = string
  default     = null
}

variable "helm_version" {
  description = <<-EOT
    설치할 helm 버전(예: "v3.21.3"). null이면 설치하지 않는다.

    ⚠️ **Day 2 운영 프로파일과 무관하게, self-managed ArgoCD를 쓰면 필수다**.
    seed를 workbench에서 `helm install`로 하기 때문이다.
    helm을 직접 운영하는 프로파일도 이 변수를 쓴다.
  EOT
  type        = string
  default     = null
}

variable "argocd_version" {
  description = <<-EOT
    설치할 argocd CLI 버전(예: "v3.5.0"). null이면 설치하지 않는다.

    ⚠️ chart appVersion과 같은 값을 쓴다. 서로 다른 값을 쓰면
    "UI에서 되는데 CLI에서 안 된다"를 진단할 근거가 사라진다. chart를 올리면 이 핀도 같이 올린다.

    용도는 "로그인해서 쓴다"가 아니다: ① 초기 비밀번호 교체 —
    CLI가 없으면 port-forward + 대화형 SSM 세션이 필요하다 · ② `argocd cluster list`로
    cluster Secret이 내장 in-cluster를 대체하는지 판정(30 판정 ③).
  EOT
  type        = string
  default     = null
}

# ── 진단·조작 도구 ───────────────────────────────────────────────────────────

variable "eks_node_viewer_version" {
  description = <<-EOT
    설치할 eks-node-viewer 버전(예: "v0.7.4"). null이면 설치하지 않는다.

    노드별 CPU/메모리 할당과 비용을 한 화면에서 본다 — Karpenter 가 만든 노드가
    실제로 어떻게 채워졌는지 보는 용도다(그 판정을 kubectl 로 하면 여러 명령이 필요하다).

    ⚠️ **릴리스 자산 이름이 다른 도구와 다르다** — `_Linux_arm64` / `_Linux_x86_64` 이고
    x86 쪽이 `amd64` 가 **아니다**. user-data 템플릿이 전용 매핑을 갖는 이유다.
  EOT
  type        = string
  default     = null
}

variable "krew_version" {
  description = <<-EOT
    설치할 krew(kubectl 플러그인 관리자) 버전(예: "v0.5.0"). null이면 설치하지 않는다.

    `KREW_ROOT=/usr/local/krew` 로 시스템 설치한다. krew 의 기본값은 `$HOME/.krew` 인데,
    user_data 는 root 로 돌기 때문에 그대로 두면 **`/root/.krew` 에 갇힌다** — kubeconfig 에서
    똑같이 겪은 문제다.
    플러그인은 상태가 아니라 바이너리라, 사용자별 사본을 두는 kubeconfig 와 반대로 공유가 옳다.

    ⚠️ kubectl 이 있어야 의미가 있다 — `kubectl_version` 이 null 이면 이 값도 무시된다.
  EOT
  type        = string
  default     = null
}

variable "krew_plugins" {
  description = <<-EOT
    krew 로 설치할 플러그인 목록. `krew_version` 이 null 이면 무시된다.

    기본값은 이 팀이 실제로 쓰는 세트다(전부 krew-index 등재 확인):
      ctx(컨텍스트 전환) · ns(네임스페이스 전환) · neat(출력에서 관리 필드 제거)·
      rbac-tool(권한 조회) · view-secret(Secret 복호화 조회) · whoami(현재 신원)

    ⚠️ **닫힌 열거가 아니다** — 고객사가 다른 세트를 원하면 이 변수로 바꾼다.
    ⛔ 그러나 모듈이 플러그인 이름을 **검증하지는 않는다**. 없는 이름을 주면 부팅 중
    그 플러그인만 실패하고 나머지는 설치된다 — user_data 는 부팅을 멈추지 않는다.
  EOT
  type        = list(string)
  default     = ["ctx", "ns", "neat", "rbac-tool", "view-secret", "whoami"]
}

# ── EKS 연동 — 3층 중 1층만 ──────────────────────────────────────────────────
#
# ⛔ 이 모듈은 Access Entry(2층)도 cluster SG ingress(3층)도 만들지 않는다.
#    그 둘은 "클러스터가 누구를 받아들이는가"라서 eks-cluster 모듈이 소유한다.
#    여기 있는 것은 workbench **자신의 권한**뿐이다.

variable "eks_cluster_name" {
  description = <<-EOT
    kubeconfig를 생성할 EKS 클러스터 이름. null이면 kubeconfig를 만들지 않는다.

    ⚠️ eks_cluster_arn과 **함께 주거나 함께 비운다**(아래 validation).
  EOT
  type        = string
  default     = null
}

variable "eks_cluster_arn" {
  description = <<-EOT
    workbench role의 eks:DescribeCluster 권한을 한정할 클러스터 ARN.
    null이면 인라인 정책을 만들지 않는다 — 쓰지 않는 권한을 남기지 않는다.

    ⚠️ eks_cluster_name과 **함께 주거나 함께 비운다**(아래 validation).
  EOT
  type        = string
  default     = null

  validation {
    # 한쪽만 주면 반쪽 상태가 된다 — 이름만 주면 kubeconfig는 만들어지는데 권한이 없어
    # update-kubeconfig가 실패하고, ARN만 주면 권한은 있는데 kubeconfig가 없다.
    # 둘 다 apply 후에야 드러나므로 plan에서 막는다.
    #
    # ⚠️ workbench_enabled 게이트가 필수다: 파기 경로에서는 IAM도 인스턴스도 생성되지 않으므로
    #    막을 이유가 없고, 막으면 "끌 수는 있으나 끈 상태를 유지할 수 없는" 반쪽 kill switch가 된다.
    #    eks-cluster의 external_dns_hosted_zone_arns·pod_subnet_ids 가드가 같은 이유로 같은 형태다.
    condition     = !var.workbench_enabled || (var.eks_cluster_name == null) == (var.eks_cluster_arn == null)
    error_message = "eks_cluster_name과 eks_cluster_arn은 함께 지정하거나 함께 비워야 한다. 한쪽만 주면 kubeconfig와 권한 중 하나가 빠져 apply 후에야 드러난다."
  }
}

# ── egress ───────────────────────────────────────────────────────────────────

variable "egress_cidr_blocks" {
  description = <<-EOT
    아웃바운드 443/tcp를 허용할 대상 CIDR. 기본은 전체 인터넷이며 NAT를 경유한다.

    SSM 제어 트래픽·패키지·차트 저장소가 전부 HTTPS라 규칙이 하나면 충분하다.
    ⚠️ SSM VPCE 3종을 신설한 완전 격리 VPC라면 VPC CIDR로 좁힐 수 있다.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.egress_cidr_blocks) > 0
    error_message = "egress_cidr_blocks가 비면 SSM Agent가 제어 평면에 연결하지 못해 세션 자체가 성립하지 않는다. 인바운드가 없는 구조라 아웃바운드는 유일한 경로다."
  }
}
