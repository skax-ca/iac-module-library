# enterprise 예제 — 설계 docs/design/20-eks-module.md §4 Task 20.6
#
# ⚠️ **이 예제의 목적은 검증이 아니라 "고객사 착수 템플릿"이다.**
#    계약 검증은 modules/eks-cluster/tests/ 가 이미 커버한다(examples/AGENTS.md의 "최소로 유지"
#    원칙에 대한 **의도된 예외**). examples/vpc-enterprise 와 같은 위치다.
#    따라서 여기서는 "왜 이 값인가"를 주석으로 남기는 것이 코드 자체만큼 중요하다.
#
# 보이는 것: custom networking(VPC D9) · Karpenter discovery 양쪽 태그 · 컨트롤러 IAM opt-in ·
#            컨트롤플레인 로깅 · 삭제 보호 · AMI/addon 핀 지점.

locals {
  # 최소 예제와 같은 패턴 — 클러스터 이름을 한 번 정의해 두 모듈에 넘긴다(설계 §2.5).
  cluster_purpose = "main"
  cluster_serial  = "01"
  cluster_name    = "eks-${var.workload}-${var.env}-${var.region_code}-${local.cluster_purpose}-${local.cluster_serial}"
}

module "vpc" {
  source = "../../modules/vpc"

  naming = {
    workload    = var.workload
    env         = var.env
    region_code = var.region_code
  }
  purpose = "main"

  cidr_block = "10.0.0.0/16"

  # ⭐ custom networking(D9)의 전제 — Pod가 소모할 **비라우팅 대역**을 secondary CIDR로 붙인다.
  #    100.64.0.0/10(RFC 6598)은 온프레미스로 라우팅되지 않으므로 Pod IP를 대량으로 써도
  #    사내 IP 계획을 잠식하지 않는다. 노드는 아래 node-uniq의 unique 대역 IP로 SNAT된다.
  secondary_cidr_blocks = ["100.64.0.0/16"]

  az_count = 2
  subnet_groups = {
    "pub-uniq" = {
      type     = "public"
      cidrs    = ["10.0.0.0/24", "10.0.1.0/24"]
      eks_role = "elb"
    }

    # 노드·컨트롤플레인 ENI가 놓이는 unique 대역. 온프레미스 방화벽 오픈 단위이기도 하다.
    "node-uniq" = {
      type     = "private"
      cidrs    = ["10.0.10.0/24", "10.0.11.0/24"]
      eks_role = "internal-elb"

      # ⭐ Karpenter discovery의 **subnet 절반**. SG 절반은 EKS 모듈이 붙인다.
      #    ⚠️ 한쪽만 붙으면 selector가 빈 결과를 내고 프로비저닝이 조용히 실패한다 —
      #       PoC에서 SG 쪽을 빠뜨려 실제로 겪은 사고다.
      extra_tags = {
        "karpenter.sh/discovery" = local.cluster_name
      }
    }

    # Pod ENI(ENIConfig) 전용. /18 둘이면 AZ당 16,382개 IP다 — Pod 밀도를 위해 넉넉히 잡는다.
    # Karpenter 대상이 아니므로 discovery 태그를 붙이지 않는다(노드가 여기 뜨지 않는다).
    "pod-dup" = {
      type  = "private"
      cidrs = ["100.64.0.0/18", "100.64.64.0/18"]
    }
  }

  eks_cluster_name = local.cluster_name

  # prd는 AZ별 NAT로 가용성을 택한다(AZ 장애가 다른 AZ의 아웃바운드를 끊지 않게).
  # ⚠️ NAT는 개당 월 ~$43이 과금된다 — dev는 single_nat_gateway = true 로 비용을 택한다.
  single_nat_gateway = false

  # VPC Flow Logs(D11). 클러스터 트래픽의 감사 근거가 된다.
  flow_logs_enabled = true
}

module "eks" {
  source = "../../modules/eks-cluster"

  naming = {
    workload    = var.workload
    env         = var.env
    region_code = var.region_code
  }
  purpose = local.cluster_purpose
  serial  = local.cluster_serial

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.subnet_ids_by_group["node-uniq"]

  # ── custom networking (VPC D9) ─────────────────────────────────────────────
  enable_custom_networking = true
  pod_subnet_ids           = module.vpc.subnet_ids_by_group["pod-dup"]

  # ── 엔드포인트 — GitOps(pull) 전제이므로 private ────────────────────────────
  # ⚠️ private 클러스터의 kubectl은 VPC 내부(bastion·VPN·DX)에서만 도달한다.
  #    조작 지점을 먼저 설계하지 않으면 apply 후 클러스터를 만질 수 없다.
  endpoint_private_access = true
  endpoint_public_access  = false

  # ── 컨트롤플레인 로깅 ──────────────────────────────────────────────────────
  # trivy AVD-AWS-0038이 지적하는 항목. CloudWatch 비용이 발생하므로 dev는 비워 둘 수 있으나,
  # 감사 대상 환경에서 audit·authenticator는 사실상 필수다.
  enabled_log_types = ["api", "audit", "authenticator"]

  # ── 삭제 보호 (D-EKS-PROTECT) ──────────────────────────────────────────────
  # AWS API 차원 보호라 콘솔에서도 지워지지 않는다.
  # ⚠️ teardown은 2단계다 — deletion_protection = false 로 apply한 뒤 cluster_enabled = false.
  #    이는 결함이 아니라 보호의 정의다.
  deletion_protection = true

  # ── 노드 ───────────────────────────────────────────────────────────────────
  managed_node_groups = {
    # 시스템·컨트롤러 계층. 앱·버스트 워크로드는 Karpenter가 맡는다(설계 §5.1-2).
    # ⚠️ Karpenter 자신도 여기 떠야 한다 — chart affinity가 karpenter.sh/nodepool DoesNotExist를
    #    요구하므로 Karpenter가 만든 노드에는 뜰 수 없다(자기 자신을 부트스트랩할 수 없다).
    system = {
      instance_types = ["m6i.large"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2

      # ⏸ D-NODE-AMI-PIN — 실환경에서는 concrete 버전을 박는다(예: "1.35.6-20260724").
      #    null이면 upstream이 매 plan마다 최신을 해석해 apply 시 **노드 롤링 교체**를 유발한다.
      #    예제는 계정에 붙지 않아 유효한 버전 문자열을 확인할 수 없으므로 null로 둔다.
      ami_release_version = null
    }
  }

  # ── addon ─────────────────────────────────────────────────────────────────
  # 빈 맵이면 baseline 6종을 상속한다. 아래는 **community tier를 opt-in으로 추가**하는 형태다
  # (설계 §2.6 확장 표) — baseline은 merge되므로 사라지지 않는다.
  #
  # ⭐ **버전을 안 주면 AWS 기본 버전이 해석된다**(D-ADDON-VERSION-PIN-1). 모듈은 버전을 들지
  #    않는다 — 업그레이드 주기는 워크로드마다 다르기 때문이다. 프로덕션에서 완전히 고정하려면
  #    addon_version을 여기 박는다. 값 얻는 법과 갱신 규칙은 README "addon 버전 고정" 절 참조.
  #    예) "coredns" = { addon_version = "v1.14.3-eksbuild.3" }
  cluster_addons = {
    # 컨트롤러+CRD는 IaC addon, Issuer/Certificate CR은 GitOps다(§1 경계).
    "cert-manager" = {}
    # 관리형 Route53. 애노테이션은 GitOps 소관이고 IAM은 아래 enable_external_dns_iam이 만든다.
    "external-dns" = {}
  }

  # ── Karpenter · 컨트롤러 IAM ──────────────────────────────────────────────
  enable_karpenter = true

  # ALBC는 community addon이 없어 GitOps helm으로 설치되지만 IAM 전제는 IaC 소관이다(§2.6a).
  enable_alb_controller_iam = true

  enable_external_dns_iam = true
  # ⚠️ **prd에서는 반드시 zone ARN을 좁힌다.** 비워 두면 커뮤니티 정책이 전체 zone(*)을 허용한다.
  #    예제는 계정에 붙지 않아 실제 zone ARN이 없으므로 비워 두되, 이 줄을 지우고 넘어가지 않는다.
  external_dns_hosted_zone_arns = []
}
