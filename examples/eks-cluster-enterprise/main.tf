# enterprise 예제 — 설계 docs/design/20-eks-module.md §4 Task 20.6
#
# ⚠️ **이 예제의 목적은 검증이 아니라 "고객사 착수 템플릿"이다.**
#    계약 검증은 modules/eks-cluster/tests/ 가 이미 커버한다(examples/AGENTS.md의 "최소로 유지"
#    원칙에 대한 **의도된 예외**). examples/vpc-enterprise 와 같은 위치다.
#    따라서 여기서는 "왜 이 값인가"를 주석으로 남기는 것이 코드 자체만큼 중요하다.
#
# 보이는 것: custom networking(VPC D9) · Karpenter discovery 양쪽 태그 · 컨트롤러 IAM opt-in ·
#            컨트롤플레인 로깅 · 삭제 보호 · AMI/addon 핀 지점.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  # 최소 예제와 같은 패턴 — 클러스터 이름을 한 번 정의해 두 모듈에 넘긴다(설계 §2.5).
  cluster_purpose = "main"
  cluster_serial  = "01"
  cluster_name    = "eks-${var.workload}-${var.env}-${var.region_code}-${local.cluster_purpose}-${local.cluster_serial}"

  # ⭐ **이 한 줄이 workbench ↔ eks 순환을 끊는다**(40 §5.1-1).
  #    workbench 은 eks_cluster_arn 을 받고, eks 는 access_entries 에 workbench role ARN 을 받는다 —
  #    양쪽이 서로의 출력을 참조하면 순환이다. 클러스터 ARN 은 이름·리전·계정으로 **유도되므로**
  #    루트가 직접 합성한다: 03 §3.1의 1순위("결정적 네이밍으로 값 구성", 결합도 없음).
  #    ⇒ workbench 은 local 만 참조하고, eks 만 module.workbench 을 참조한다. 단방향.
  cluster_arn = "arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${local.cluster_name}"
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

    # 관리 호스트(workbench) 전용. 40 §2.2 — 노드 서브넷과 **분리**하는 이유는 둘이다:
    #   ① node-uniq 에는 karpenter.sh/discovery 태그가 있어 Karpenter 가 그 대역에 노드를 띄운다.
    #      workbench 을 섞으면 "이 대역은 무엇의 것인가"가 흐려진다.
    #   ② 온프레미스 방화벽·보안 그룹 정책을 대역 단위로 쓰는 조직에서 관리 접근을 분리해 기술한다.
    # /24 하나면 workbench 1대에 충분하다 — 넓게 잡을 이유가 없다.
    "vm-uniq" = {
      type  = "private"
      cidrs = ["10.0.20.0/24", "10.0.21.0/24"]
    }
  }

  eks_cluster_name = local.cluster_name

  # prd는 AZ별 NAT로 가용성을 택한다(AZ 장애가 다른 AZ의 아웃바운드를 끊지 않게).
  # ⚠️ NAT는 개당 월 ~$43이 과금된다 — dev는 single_nat_gateway = true 로 비용을 택한다.
  single_nat_gateway = false

  # VPC Flow Logs(D11). 클러스터 트래픽의 감사 근거가 된다.
  flow_logs_enabled = true
}

# ── external-dns가 레코드를 쓸 대상 zone ──────────────────────────────────────
# ⭐ **예제가 zone까지 만드는 이유**: enable_external_dns_iam = true는 zone ARN 없이 성립하지
#    않는다(D-EXTDNS-ZONE). 더미 ARN을 적어 두는 선택지도 있었으나, 고객사가 그대로 복사해
#    apply하면 **존재하지 않는 zone을 가리키는 IAM role이 조용히 만들어진다** — apply가 성공하기
#    때문에 아무도 지적하지 않은 채 굳는 형태다(D13이 지적한 것과 같은 실패 구조).
#
# private zone인 이유: 예제가 만든 VPC 안에서만 해석되면 되므로 도메인 소유·위임이 필요 없다.
#    public zone은 소유 검증 없이 만들어지지만 실제 위임이 없어 허공에 뜨고 과금만 남는다.
resource "aws_route53_zone" "internal" {
  name    = "${var.workload}.internal"
  comment = "example internal zone for external-dns (${local.cluster_name})"

  # private zone은 VPC 연결이 **항상 하나 이상** 있어야 한다(provider 문서).
  vpc {
    vpc_id = module.vpc.vpc_id
  }

  # ⚠️ external-dns는 클러스터 안에서 돌며 **IaC 밖에서** 레코드를 쓴다. 그 레코드가 남아 있으면
  #    zone 삭제가 실패해 예제 teardown이 막힌다. **예제라서 켠다** — 실제 프로젝트에서는 켜지 않는다
  #    (IaC가 모르는 레코드를 말없이 지우는 스위치다).
  force_destroy = true

  tags = {
    Name = "hz-${var.workload}-${var.env}-${var.region_code}-internal"
  }
}

# ── workbench — private 클러스터의 도달 지점 (설계 40) ──────────────────────────
#
# ⭐ **이 예제가 endpoint_public_access = false 이면서 조작 지점이 없던 상태를 닫는다.**
#    아래 eks 블록의 주석이 "조작 지점을 먼저 설계하지 않으면 apply 후 클러스터를 만질 수 없다"고
#    적고 있었는데, 2026-08-05 40 개정 전까지 실제로 그 상태였다.
#
# ⚠️ workbench 은 eks 모듈의 **출력을 참조하지 않는다** — local.cluster_arn(위 순환 해소)만 쓴다.
module "workbench" {
  source = "../../modules/workbench"

  naming = {
    workload    = var.workload
    env         = var.env
    region_code = var.region_code
  }

  vpc_id = module.vpc.vpc_id
  # 관리 호스트 전용 대역의 첫 AZ. workbench 은 1대이므로 AZ 분산이 의미 없다(40 §2.2).
  subnet_id = module.vpc.subnet_ids_by_group["vm-uniq"][0]

  # ⛔ D-WORKBENCH-AMI-PIN — 모듈에 기본값이 **없다**. 리전 종속이라 재사용 자산의 기본값이 될 수 없다.
  #    변수 설명의 조회 명령으로 실제 값을 얻어 커밋한다.
  ami_id = var.workbench_ami_id

  # 도구는 명시 핀. kubectl 은 클러스터 마이너와 맞춘다(1.35 → v1.35.x).
  kubectl_version = "v1.35.7"
  # ⚠️ helm 은 프로파일 B(22 §3) 전용이 아니다 — self-managed ArgoCD 를 쓰면 seed 가
  #    workbench 에서 `helm install` 로 돌기 때문에 필수다(23 §2.1). 핀은 차트에 결합돼 있어
  #    23 §5 가 SSOT 다: argo-cd 10.3.0 과 짝이 되는 helm v3(v4 아님 — 근거는 23 §5).
  helm_version = "v3.21.3"
  # ⭐ chart appVersion 과 **같은 값**을 쓴다(23 §5). 다른 값을 핀하면 "UI 에서 되는데 CLI 에서
  #    안 된다"를 진단할 근거가 사라진다. chart 를 올리면 이 핀도 같이 올린다.
  argocd_version = "v3.5.0"

  # ── 진단·조작 도구 (D-WORKBENCH-TOOLING, 40 §4.3-2) ─────────────────────────
  # 노드별 CPU/메모리 할당과 비용을 한 화면에서 본다 — Karpenter 가 만든 노드가 실제로
  # 어떻게 채워졌는지 보는 용도다.
  eks_node_viewer_version = "v0.7.4"
  # krew 는 KREW_ROOT=/usr/local/krew 로 **시스템 설치**된다(모듈이 처리). 플러그인 목록은
  # 모듈 기본값(ctx·ns·neat·rbac-tool·view-secret·whoami)을 그대로 받는다 —
  # ⛔ 기본값과 같은 값을 여기 다시 적지 않는다(중복은 곧 drift다).
  krew_version = "v0.5.0"

  # EKS 접근 3층 중 **1층만** 여기서 성립한다(D-WORKBENCH-SEAM).
  # 2층(Access Entry)·3층(SG ingress)은 아래 eks 블록이 소유한다.
  eks_cluster_name = local.cluster_name
  eks_cluster_arn  = local.cluster_arn
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
  # ⚠️ private 클러스터의 kubectl은 VPC 내부(workbench·VPN·DX)에서만 도달한다.
  #    조작 지점을 먼저 설계하지 않으면 apply 후 클러스터를 만질 수 없다.
  #    ✅ 위 module.workbench 이 그 지점이다(설계 40). 아래 3층 배선이 도달을 완성한다.
  endpoint_private_access = true
  endpoint_public_access  = false

  # ── EKS 접근 3층 중 2·3층 — D-WORKBENCH-SEAM (설계 40 §5) ─────────────────────
  #
  # 🔑 소유가 갈리는 기준은 **주체냐 대상이냐**다. 1층(eks:DescribeCluster)은 workbench 자신의
  #    권한이라 workbench 모듈이, 2·3층은 "클러스터가 누구를 받아들이는가"라 이 모듈이 소유한다.
  #    03 §2.3이 *"소유 모듈이 허용 소스를 변수로 파라미터화해 owner 가 rule 을 생성한다"* 고 정했다.
  #
  # ⚠️ 세 층이 **모두** 있어야 kubectl 이 닿는다. 빠뜨렸을 때의 증상이 층마다 다르다:
  #      1층 없음 → update-kubeconfig 권한 오류 / 2층 없음 → 401 Unauthorized
  #      3층 없음 → dial tcp …: i/o timeout   ← 인증 계층에 닿지도 못했다는 뜻
  #    PoC 는 앞의 두 층만 갖추고 timeout 을 만났다(40 §3).

  # 2층 — 클러스터 안에서 무엇을 할 수 있는가.
  # ⚠️ ClusterAdmin 은 넓다. SSM 접근 통제가 곧 클러스터 보안이 된다(40 §10-1 세션 로깅).
  #    프로파일 B 의 helm 이 실제로 요구하는 최소 권한은 첫 수행 후 좁힌다(40 §10-3).
  access_entries = {
    workbench = {
      principal_arn = module.workbench.workbench_iam_role_arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  # 3층 — apiserver 에 네트워크로 닿는가.
  cluster_security_group_additional_rules = {
    workbench_kubectl = {
      from_port                = 443
      to_port                  = 443
      description              = "kubectl/helm from workbench"
      source_security_group_id = module.workbench.workbench_security_group_id
    }
  }

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

      # ⭐ D-NODE-ARCH — 아키텍처의 결정 지점. 기본값이 x86 이라 이 예제는 생략해도 같지만,
      #    **노브가 있다는 것을 템플릿에서 보이게** 명시한다.
      #    ⚠️ graviton(t4g·m7g·c7g…)으로 바꾸려면 **두 줄을 함께** 고친다:
      #         instance_types = ["m7g.large"] · ami_type = "AL2023_ARM_64_STANDARD"
      #       한쪽만 바꾸면 AMI 와 CPU 가 어긋나 **노드가 부팅되지 않는다** — plan 은 통과한다.
      #       ami_release_version 도 아키텍처별로 값이 다르다(arm SSM 경로에서 다시 얻는다).
      ami_type = "AL2023_x86_64_STANDARD"

      # ⏸ D-NODE-AMI-PIN — 실환경에서는 concrete 버전을 박는다(예: "1.35.6-20260724").
      #    null이면 upstream이 매 plan마다 최신을 해석해 apply 시 **노드 롤링 교체**를 유발한다.
      #    예제는 계정에 붙지 않아 유효한 버전 문자열을 확인할 수 없으므로 null로 둔다.
      ami_release_version = null
    }
  }

  # ── addon ─────────────────────────────────────────────────────────────────
  # 빈 맵이면 baseline 6종을 상속한다. 아래는 baseline 6종의 **버전을 override** 하고
  # community tier 2종을 **opt-in으로 추가**한 형태다(설계 §2.6 확장 표).
  # ⚠️ **누락 != 삭제**다 — baseline은 merge되므로 여기 안 적어도 사라지지 않는다.
  #    제거는 enabled = false 명시로만 한다. core 4종은 그것도 차단된다.
  # ℹ️ addon_version만 적어도 모듈 소유 필드(vpc-cni의 custom networking 구성, ebs-csi의 pod
  #    identity association)는 **merge 뒤에 재주입**되므로 사라지지 않는다(addons.tf §4).
  #
  # ⭐ **버전 값은 소비 루트가 소유한다**(D-ADDON-VERSION-PIN-1). 모듈은 버전을 들지 않는다 —
  #    업그레이드 주기가 워크로드마다 다르기 때문이다.
  #
  # 🔴 **아래 값을 그대로 복사하지 말 것.** addon 버전은 `f(kubernetes_version, region)`이다.
  #    이 값들은 **k8s 1.35 · ap-northeast-2 의 AWS 기본 버전**(2026-08-04 실측)이고,
  #    다른 k8s 버전이나 리전에서는 *"그 버전 없음"* 으로 apply가 죽는다.
  #    값 얻는 법과 갱신 규칙은 README "addon 버전 고정" 절.
  #
  # 🔑 **왜 최신이 아니라 기본(default) 버전을 박았나**: 기본 버전을 박으면 핀 전후 동작이
  #    같다(무변경). 최신을 박으면 "핀을 추가한다"는 작업에 **업그레이드 결정이 섞여 들어간다** —
  #    상향은 값을 올리는 별도 커밋이어야 plan diff로 리뷰된다.
  cluster_addons = {
    # ── baseline 6종 (버전만 override) ──────────────────────────────────────
    "vpc-cni"                = { addon_version = "v1.22.3-eksbuild.1" }
    "coredns"                = { addon_version = "v1.13.2-eksbuild.11" }
    "kube-proxy"             = { addon_version = "v1.35.3-eksbuild.17" }
    "eks-pod-identity-agent" = { addon_version = "v1.3.10-eksbuild.3" }
    "aws-ebs-csi-driver"     = { addon_version = "v1.63.1-eksbuild.1" }
    "metrics-server"         = { addon_version = "v0.9.0-eksbuild.5" }

    # ── community tier (opt-in 추가) ────────────────────────────────────────
    # 컨트롤러+CRD는 IaC addon, Issuer/Certificate CR은 GitOps다(§1 경계).
    "cert-manager" = { addon_version = "v1.21.0-eksbuild.3" }
    # 관리형 Route53. 애노테이션은 GitOps 소관이고 IAM은 아래 enable_external_dns_iam이 만든다.
    "external-dns" = { addon_version = "v0.21.0-eksbuild.6" }
  }

  # ── Karpenter · 컨트롤러 IAM ──────────────────────────────────────────────
  enable_karpenter = true

  # ALBC는 community addon이 없어 GitOps helm으로 설치되지만 IAM 전제는 IaC 소관이다(§2.6a).
  enable_alb_controller_iam = true

  enable_external_dns_iam = true
  # ⛔ 이 목록은 **비울 수 없다**(D-EXTDNS-ZONE). 비우면 upstream이 Resource = "*" 정책을 만들고
  #    AWS가 400 MalformedPolicyDocument로 거부한다 — 모듈의 교차변수 validation이 plan에서 먼저 막는다.
  external_dns_hosted_zone_arns = [aws_route53_zone.internal.arn]
}
