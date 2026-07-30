# enterprise 프리셋 예제 — 설계 docs/design/10-vpc-module.md §1.5(b)
#
# **이 예제의 목적은 검증이 아니라 소비자 착수 템플릿이다.**
# 설계가 처음 이 예제를 요구한 근거(isolated 라우팅·secondary CIDR·AZ 커버리지 precondition이
# minimal에서는 실행되지 않는다)는 Task 10.6의 tofu test가 이미 커버한다. 남은 값은
# **D6~D9의 설계 판단을 그대로 옮긴 9그룹 프리셋**이며, 고객사 착수 시간을 가장 크게 줄이는 자산이다.
#
# ⚠️ 소싱은 상대경로다. 소비 프로젝트는 git tag를 쓴다(examples/vpc/README.md 비교표 참조).

locals {
  # ── CIDR 3계층 (설계 §1.5(b)) ──────────────────────────────────────────────
  # primary는 인프라 전용 소형으로 최소화하고 워크로드는 secondary에 배치한다.
  # ⚠️ primary가 10.0.0.0/15 범위 안이면 10.0.0.0/16 대역 secondary는 연결 불가하므로
  #    uniq secondary는 10.1.0.0/16을 쓴다(§1.2). 100.64.0.0/10은 모든 primary와 조합 가능하다.
  cidr_primary = "10.0.0.0/24"   # uniq 소형 — ep·tgw 전용
  cidr_uniq    = "10.1.0.0/16"   # uniq — 라우팅 가능(온프레미스 도달)
  cidr_dup     = "100.64.0.0/16" # dup 허용 — 비라우팅(RFC 6598)

  # ── cidrsubnet() 파생 (D2) ─────────────────────────────────────────────────
  # 계산의 소유가 모듈이 아니라 **소비자 루트**다. 소비자는 이 locals를 복사해 쓴다.
  #
  # uniq secondary(/16)를 /20 16개로 나눠 앞 2개는 대형(vm)에, 3번째 /20은 다시 /24로 쪼개
  # 나머지 그룹에 배분한다. 겹침은 AWS API가 apply 시 거부하므로 배치를 표로 남긴다:
  #
  #   vm-uniq    /20 × 2  10.1.0.0/20      10.1.16.0/20
  #   pub-uniq   /24 × 2  10.1.32.0/24     10.1.33.0/24    ┐
  #   elb-uniq   /24 × 2  10.1.34.0/24     10.1.35.0/24    │ 모두 10.1.32.0/20 안에서
  #   node-uniq  /24 × 2  10.1.36.0/24     10.1.37.0/24    │ 파생 — 겹치지 않는다
  #   data-uniq  /24 × 3  10.1.38.0/24 …   10.1.40.0/24    │
  #   db-uniq    /26 × 2  10.1.41.0/26     10.1.41.64/26   ┘ (/24 하나를 다시 /26으로)
  #   pod-dup    /18 × 2  100.64.0.0/18    100.64.64.0/18
  #   ep-uniq    /27 × 2  10.0.0.0/27      10.0.0.32/27    ┐ primary /24 안에서
  #   tgw-uniq   /28 × 3  10.0.0.192/28 …  10.0.0.224/28   ┘ 앞/뒤로 떨어뜨려 배치
  uniq_small_block = cidrsubnet(local.cidr_uniq, 4, 2)

  vm_cidrs   = [for i in [0, 1] : cidrsubnet(local.cidr_uniq, 4, i)]
  pub_cidrs  = [for i in [0, 1] : cidrsubnet(local.uniq_small_block, 4, i)]
  elb_cidrs  = [for i in [2, 3] : cidrsubnet(local.uniq_small_block, 4, i)]
  node_cidrs = [for i in [4, 5] : cidrsubnet(local.uniq_small_block, 4, i)]
  data_cidrs = [for i in [6, 7, 8] : cidrsubnet(local.uniq_small_block, 4, i)]
  db_cidrs   = [for i in [0, 1] : cidrsubnet(cidrsubnet(local.uniq_small_block, 4, 9), 2, i)]
  pod_cidrs  = [for i in [0, 1] : cidrsubnet(local.cidr_dup, 2, i)]
  ep_cidrs   = [for i in [0, 1] : cidrsubnet(local.cidr_primary, 3, i)]
  tgw_cidrs  = [for i in [12, 13, 14] : cidrsubnet(local.cidr_primary, 4, i)]
}

module "vpc" {
  source = "../../modules/vpc"

  naming = {
    workload    = var.workload
    env         = var.env
    region_code = var.region_code
  }
  purpose = "main"

  cidr_block            = local.cidr_primary
  secondary_cidr_blocks = [local.cidr_uniq, local.cidr_dup]

  # D7 — 기본 AZ는 a·c로 두고 3AZ 그룹만 b를 추가로 쓴다(서울 리전 관례).
  # 2AZ 그룹이 모두 a·c에 몰리는 것은 의도된 결과다.
  az_count     = 3
  az_selection = ["a", "c", "b"]

  subnet_groups = {
    # 인터넷 대면 LB + NAT 호스팅. ALB 최소 2AZ 충족.
    "pub-uniq" = {
      type     = "public"
      cidrs    = local.pub_cidrs
      eks_role = "elb"
    }

    # 온프레미스 연동 방화벽 오픈 단위. 내부 LB ENI는 아웃바운드 개시가 없어 isolated로 둔다 —
    # 온프레미스 왕복 경로는 TGW 운영 라우트가 추가될 때 생긴다(D3의 의도된 순서).
    "elb-uniq" = {
      type     = "isolated"
      cidrs    = local.elb_cidrs
      eks_role = "internal-elb"
    }

    # VM 워크로드 — NAT 아웃바운드.
    "vm-uniq" = {
      type  = "private"
      cidrs = local.vm_cidrs
    }

    # EKS 노드(D9 custom networking) — node-SNAT의 소스이자 방화벽 오픈 단위.
    "node-uniq" = {
      type  = "private"
      cidrs = local.node_cidrs
    }

    # EKS Pod 전용(D9, ENIConfig). Pod의 VPC 외부 egress는 노드 primary ENI로 SNAT되어
    # 노드 그룹 RT를 타므로 Pod 서브넷엔 기본 경로가 불필요하다 → isolated.
    # EKS 태그를 붙이지 않는 이유: role 태그는 LB 배치용이고, cluster 태그는 EKS 모듈이
    # 서브넷 ID를 명시 전달하므로 필수가 아니다. 필요하면 extra_tags로 부착한다.
    "pod-dup" = {
      type  = "isolated"
      cidrs = local.pod_cidrs
    }

    # RDS 등 관계형(Multi-AZ = 2). 소수 고정 ENI라 소형 CIDR.
    "db-uniq" = {
      type  = "isolated"
      cidrs = local.db_cidrs
    }

    # MSK·OpenSearch·Redis — 3AZ 공식 권장(quorum). db와 분리하는 이유는 AZ 수 요구와
    # IP 소모 프로파일이 다르기 때문이다(D8). 라우팅은 db와 같으므로 분리 근거가 아니다.
    "data-uniq" = {
      type  = "isolated"
      cidrs = local.data_cidrs
    }

    # VPC interface endpoint ENI 전용. b존 호출은 cross-AZ 폴백.
    "ep-uniq" = {
      type  = "isolated"
      cidrs = local.ep_cidrs
    }

    # TGW attachment 전용(/28 권장). ⚠️ 워크로드가 존재하는 모든 AZ를 커버해야 한다 —
    # attachment 없는 AZ의 리소스는 TGW에 도달하지 못한다(공식, D6).
    "tgw-uniq" = {
      type  = "isolated"
      cidrs = local.tgw_cidrs
    }
  }

  # D4 — eks_role이 지정된 그룹(pub-uniq·elb-uniq)에만 cluster 태그가 함께 붙는다.
  # ⚠️ cluster 태그는 레거시다(§1.2-1 C8) — LB Controller 2.1.1 이하만 요구한다.
  eks_cluster_name = "eks-${var.workload}-${var.env}-${var.region_code}-main"

  # 예제는 비용 최소. prd는 false(AZ별 NAT)로 두며, 그때는 pub 그룹의 AZ 수가
  # private 그룹 최대 AZ 수 이상이어야 한다(D6 precondition).
  single_nat_gateway = true
}
