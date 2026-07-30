# minimal 예제 — 설계 docs/design/10-vpc-module.md §1.5(a)
#
# 모듈 계약의 핵심 경로를 최소 비용으로 보인다: public(IGW·NAT 호스팅) + private(NAT 아웃바운드).
# 소비자의 복사 시작점이기도 하다.
#
# ⚠️ 소싱은 **상대경로**다. 이 예제는 현재 코드를 검증해야 하기 때문이다.
#    소비 프로젝트는 git tag로 소싱한다(CLAUDE.md) — 두 방식을 혼동하지 않는다:
#      source = "git::https://github.com/skax-ca/iac-module-library.git//modules/vpc?ref=vpc-v1.0.0"

module "vpc" {
  source = "../../modules/vpc"

  # 소비자는 약어를 타이핑하지 않는다 — 모듈이 리소스별 약어를 조합한다(02 §1.4(b)).
  naming = {
    workload    = var.workload
    env         = var.env
    region_code = var.region_code
  }
  purpose = "main"

  cidr_block = "10.0.0.0/16"

  az_count = 2
  subnet_groups = {
    # 그룹 키가 Name 태그의 purpose 토큰이 된다 → snet-acme-dev-an2-pub-uniq-a
    # 키는 <용도 축약>-<uniq|dup> 형식을 권고한다(이름만으로 온프레미스 라우팅 가능 여부를 판별).
    "pub-uniq" = {
      type  = "public"
      cidrs = ["10.0.0.0/24", "10.0.1.0/24"]
      # 인터넷 대면 LB를 놓을 서브넷임을 EKS에 알린다(D4). ALB는 최소 2AZ가 필요하다.
      eks_role = "elb"
    }
    "app-uniq" = {
      type  = "private"
      cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
    }
  }

  # 예제는 비용 최소 구성 — NAT 1개를 두 AZ가 공유한다.
  # prd는 single_nat_gateway = false(AZ별 NAT)로 가용성을 택한다.
  single_nat_gateway = true
}
