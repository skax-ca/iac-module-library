# minimal 예제 — 설계 docs/design/20-eks-module.md §4 Task 20.6
#
# 모듈 계약의 핵심 경로를 최소 비용으로 보인다: VPC 결선 + 시스템 노드그룹 1개 + baseline addon 상속.
# 소비자의 복사 시작점이기도 하다.
#
# ⚠️ 소싱은 **상대경로**다. 이 예제는 현재 코드를 검증해야 하기 때문이다.
#    소비 프로젝트는 git tag로 소싱한다(CLAUDE.md) — 두 방식을 혼동하지 않는다:
#      source = "git::https://github.com/skax-ca/iac-module-library.git//modules/eks-cluster?ref=eks-cluster-v1.0.0"

locals {
  # ⭐ **클러스터 이름을 한 번만 정의해 두 모듈에 넘긴다** — 설계 §2.5의 핵심 패턴이다.
  #
  # 왜 이래야 하는가: EKS 모듈이 VPC의 서브넷에 태그를 쓰고 VPC의 서브넷을 읽으면 **양방향 의존**
  # (순환)이 된다. 그래서 태그 부여는 VPC 모듈이 하고, 양쪽이 **같은 규칙으로 같은 문자열을 각자
  # 유도**한다(03 §3.1의 1순위 "결정적 네이밍"). 이름 규약이 의존성을 지우는 실제 사례다.
  #
  # 대가는 소비자가 두 곳에 값을 넣는다는 것이고, 이 local이 그 대가를 한 줄로 줄인다.
  # 포맷은 EKS 모듈의 합성 규칙과 같아야 한다: eks-<workload>-<env>-<region_code>-<purpose>-<serial>
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

  az_count = 2
  subnet_groups = {
    "pub-uniq" = {
      type     = "public"
      cidrs    = ["10.0.0.0/24", "10.0.1.0/24"]
      eks_role = "elb"
    }
    "node-uniq" = {
      type  = "private"
      cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
      # 내부 LB용 서브넷임을 EKS에 알린다(VPC D4).
      eks_role = "internal-elb"
    }
  }

  # ⭐ 서브넷에 kubernetes.io/cluster/<name> 디스커버리 태그를 붙인다.
  #    이 값이 아래 EKS 모듈이 합성할 이름과 **같아야** 한다.
  eks_cluster_name = local.cluster_name

  # 예제는 비용 최소 구성 — NAT 1개를 두 AZ가 공유한다.
  single_nat_gateway = true
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

  # custom networking(VPC D9)은 Pod 전용 비라우팅 대역을 전제한다. 최소 예제는 그 대역을 만들지
  # 않으므로 **명시적으로 끈다** — 모듈 기본값이 true이기 때문이다.
  # 켜는 형상은 examples/eks-cluster-enterprise 를 본다.
  enable_custom_networking = false

  managed_node_groups = {
    # 맵 키가 노드그룹 purpose 토큰이 된다 → eksn-acme-dev-an2-system
    system = {
      instance_types = ["m6i.large"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2
    }
  }

  # cluster_addons를 비워 두면 baseline 6종을 그대로 상속한다(설계 §2.6).
  # 소비자가 addon 하나를 추가해도 baseline은 사라지지 않는다 — merge되기 때문이다.
}
