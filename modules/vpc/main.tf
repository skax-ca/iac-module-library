# VPC 코어 리소스 — 설계 docs/design/10-vpc-module.md §1.1(D1~D10·D12) · §1.2 · §1.2-1 · §1.3
#
# 리소스 배치 순서는 의존 순서를 따른다: data → vpc → secondary CIDR → subnet → gateway → RT → route → association.
# ⚠️ 이 파일의 모든 리소스는 local.enabled(= var.vpc_enabled) 게이트를 지난다(D10).
#    data source까지 게이트하는 이유는 규약 일관성이다 — 릴리스 게이트가 모듈마다 다른 규칙을 판정할 수 없다.

locals {
  enabled = var.vpc_enabled

  # 02 §1.4(b) — Name 태그의 중간 토큰. 소비자가 약어를 타이핑하지 않도록 모듈이 조합한다.
  name_mid = "${var.naming.workload}-${var.naming.env}-${var.naming.region_code}"

  # ── AZ 해석 (D7) ────────────────────────────────────────────────────────────
  az_names_available = local.enabled ? data.aws_availability_zones.this[0].names : []

  # suffix → AZ 이름. 리전 문자열을 하드코딩하지 않으므로 리전 이식성이 유지된다.
  az_name_by_suffix = {
    for name in local.az_names_available :
    substr(name, length(name) - 1, 1) => name
  }

  # az_selection이 있으면 그 우선순위를, 없으면 리전 AZ 목록의 앞 az_count개를 쓴다.
  # ⚠️ slice의 상한을 min()으로 자르는 이유는 §1.2-1 C6이다 — 리전 AZ가 부족할 때
  #    locals가 index 오류로 죽는 대신 aws_vpc의 precondition이 도메인 메시지로 보고하게 한다.
  az_suffixes = local.enabled ? (
    var.az_selection != null
    ? var.az_selection
    : [
      for name in slice(local.az_names_available, 0, min(var.az_count, length(local.az_names_available))) :
      substr(name, length(name) - 1, 1)
    ]
  ) : []

  # 존재하지 않는 suffix는 null로 두고 precondition이 보고한다(C6).
  az_names = [for suffix in local.az_suffixes : lookup(local.az_name_by_suffix, suffix, null)]

  # ── 서브넷 정의 (그룹 × AZ) ─────────────────────────────────────────────────
  # 키는 "<group>-<az suffix>" — §1.3의 Name purpose 토큰과 같은 형태라 tftest에서 대조가 쉽다.
  subnet_defs = local.enabled ? {
    for def in flatten([
      for group_name, group in var.subnet_groups : [
        # cidrs를 az_suffixes 범위로 잘라낸다(C6). 초과분은 precondition이 D6 위반으로 보고한다.
        for idx, cidr in slice(group.cidrs, 0, min(length(group.cidrs), length(local.az_suffixes))) : {
          key        = "${group_name}-${local.az_suffixes[idx]}"
          group      = group_name
          type       = group.type
          cidr       = cidr
          az_name    = local.az_names[idx]
          az_suffix  = local.az_suffixes[idx]
          eks_role   = group.eks_role
          extra_tags = group.extra_tags
        }
      ]
    ]) : def.key => def
  } : {}

  # ── 그룹 분류 (D1의 라우팅 매트릭스 — §1.2) ─────────────────────────────────
  # public/isolated는 그룹당 RT 1개를 공유하고, private만 AZ별 RT를 갖는다(NAT 경로가 AZ마다 갈리므로).
  shared_rt_group_names = sort([for name, group in var.subnet_groups : name if group.type != "private"])
  public_group_names    = sort([for name, group in var.subnet_groups : name if group.type == "public"])
  private_group_names   = sort([for name, group in var.subnet_groups : name if group.type == "private"])

  # ── NAT 배치 (§1.2) ─────────────────────────────────────────────────────────
  # NAT는 type이 public인 첫 번째 그룹(맵 키 정렬 기준)의 서브넷에 놓는다.
  nat_group = length(local.public_group_names) > 0 ? local.public_group_names[0] : null

  # private 그룹이 없으면 NAT를 만들지 않는다(C5) — 걸어줄 경로가 없고 유휴로도 과금된다.
  nat_enabled = local.enabled && var.enable_nat_gateway && local.nat_group != null && length(local.private_group_names) > 0

  # NAT 호스트 그룹이 커버하는 AZ suffix. subnet_defs의 맵 순서(사전순)가 아니라
  # az_suffixes 순서를 써야 D7의 우선순위가 유지된다(single NAT가 "첫 AZ"에 놓이도록).
  nat_host_suffixes = local.nat_group == null ? [] : slice(
    local.az_suffixes,
    0,
    min(length(var.subnet_groups[local.nat_group].cidrs), length(local.az_suffixes))
  )

  nat_suffixes = local.nat_enabled ? (
    var.single_nat_gateway
    ? slice(local.nat_host_suffixes, 0, min(1, length(local.nat_host_suffixes)))
    : local.nat_host_suffixes
  ) : []

  # D6 precondition용 — private 그룹 중 가장 넓은 AZ 폭.
  max_private_az_count = length(local.private_group_names) > 0 ? max([
    for name in local.private_group_names : length(var.subnet_groups[name].cidrs)
  ]...) : 0
}

data "aws_availability_zones" "this" {
  count = local.enabled ? 1 : 0

  state = "available"

  # Local Zone·Wavelength Zone을 제외한 순수 AZ만 남긴다(provider 공식 예시).
  # D7의 suffix 1글자 매칭이 이름을 "<region><letter>" 형태로 전제하기 때문이다.
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

resource "aws_vpc" "this" {
  count = local.enabled ? 1 : 0

  cidr_block = var.cidr_block

  # C2 — EKS 프라이빗 엔드포인트·VPC 엔드포인트 프라이빗 DNS가 둘 다 요구한다.
  # provider 기본값은 hostnames = false이므로 명시하지 않으면 동작하지 않는다.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "vpc-${local.name_mid}-${var.purpose}"
  })

  lifecycle {
    # D12 — OpenTofu 1.12부터 prevent_destroy가 입력 변수를 참조할 수 있다.
    # ⚠️ Terraform 비호환 지점(04 §5). 재사용 모듈이 소비자에게 삭제 보호를 위임할 수 있는 유일한 수단이다.
    prevent_destroy = var.deletion_protection

    # 계약 검증은 전부 여기 모은다 — 단일 인스턴스 리소스이므로 조건이 한 번만 평가된다.
    # ⚠️ count = 0(파기 방향)이면 precondition도 평가되지 않는다. D10의 teardown 보장에 필요한 동작이다.
    precondition {
      condition     = var.az_count <= length(local.az_names_available)
      error_message = "az_count(${var.az_count})가 이 리전에서 사용 가능한 AZ 수보다 많다. az_count를 줄이거나 다른 리전을 쓴다."
    }

    precondition {
      condition = var.az_selection == null || alltrue([
        for suffix in coalesce(var.az_selection, []) : contains(keys(local.az_name_by_suffix), suffix)
      ])
      error_message = "az_selection에 이 리전에 없는 AZ suffix가 있다. 리전이 실제로 제공하는 suffix만 지정한다."
    }

    # D6 — 그룹의 AZ 수는 cidrs 길이가 결정한다. 잘못된 상태를 표현할 수 없는 인터페이스의 전제 조건.
    precondition {
      condition = alltrue([
        for name, group in var.subnet_groups : length(group.cidrs) >= 2 && length(group.cidrs) <= var.az_count
      ])
      error_message = "subnet_groups의 각 그룹은 cidrs를 2개 이상 az_count(${var.az_count})개 이하로 가져야 한다(D6 — cidrs 길이가 곧 그 그룹의 AZ 수다)."
    }

    # §1.2 — NAT는 public 그룹의 서브넷에 놓이므로 public 그룹 없이는 만들 수 없다.
    precondition {
      condition     = !var.enable_nat_gateway || length(local.private_group_names) == 0 || local.nat_group != null
      error_message = "enable_nat_gateway = true인데 type이 public인 subnet_groups가 없다. NAT를 호스팅할 public 그룹을 추가하거나 enable_nat_gateway = false로 둔다."
    }

    # D6 — per-AZ NAT 모드에서 커버되지 않는 AZ가 생기면 그 AZ의 private 서브넷에 기본 경로가 없다.
    # AZ는 항상 az_selection 앞에서부터 배정되므로(D7) AZ 집합은 접두사 관계다 → 개수 비교로 충분하다.
    precondition {
      condition     = !local.nat_enabled || var.single_nat_gateway || length(local.nat_host_suffixes) >= local.max_private_az_count
      error_message = "per-AZ NAT(single_nat_gateway = false)에서는 NAT 호스트 그룹('${coalesce(local.nat_group, "-")}')의 AZ 수가 private 그룹의 최대 AZ 수(${local.max_private_az_count}) 이상이어야 한다(D6)."
    }
  }
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  for_each = toset(local.enabled ? var.secondary_cidr_blocks : [])

  vpc_id     = aws_vpc.this[0].id
  cidr_block = each.value
}

resource "aws_subnet" "this" {
  for_each = local.subnet_defs

  vpc_id            = aws_vpc.this[0].id
  availability_zone = each.value.az_name
  cidr_block        = each.value.cidr

  # C4 — map_public_ip_on_launch를 설정하지 않는다. public 그룹의 용도는 ELB·NAT 호스팅이고
  # 둘 다 자동 공개 IP가 불필요하다(ALB는 자체 주소, NAT는 EIP).

  tags = merge(
    var.tags,
    each.value.extra_tags,
    # D4 — EKS 태그는 eks_role이 지정된 그룹에만 붙인다(public/private 전체 일괄 부착 금지).
    each.value.eks_role == null ? {} : merge(
      # 현행 필수 태그. 값은 "1"이 공식이다(EKS 네트워킹 요구사항 문서).
      { "kubernetes.io/role/${each.value.eks_role}" = "1" },
      # ⚠️ C8 — cluster 태그는 레거시다. AWS는 신규 클러스터에 더 이상 붙이지 않고
      #    Load Balancer Controller 2.1.1 이하만 요구한다. eks_cluster_name 기본값 null(opt-in).
      var.eks_cluster_name == null ? {} : { "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared" }
    ),
    # D13 — 기계가 조회하는 키. 하류 루트(eks-cluster 등)가 data.aws_subnets로 그룹 단위 조회를
    # 할 수 있게 한다. Name은 사람이 읽는 식별자이고 그 포맷은 거버넌스가 바꿀 수 있으므로,
    # 기계 조회가 Name 문자열을 와일드카드로 파싱하면 네이밍 개정이 곧 하류 장애가 된다.
    # ⚠️ 조회 실패는 에러가 아니라 **빈 결과**라 조용히 잘못 동작한다 — 그래서 opt-in이 아니다.
    { SubnetGroup = each.value.group },
    { Name = "snet-${local.name_mid}-${each.key}" }
  )

  # ⚠️ §1.2 — 서브넷 CIDR가 secondary 대역이면 association이 먼저 associated 상태여야 하는데
  #    OpenTofu가 참조 관계로 추론하지 못한다. 그룹별 대역 판별 없이 전 서브넷에 일괄로 건다.
  depends_on = [aws_vpc_ipv4_cidr_block_association.this]
}

resource "aws_internet_gateway" "this" {
  # C3 — public 그룹이 없으면 IGW를 걸 RT가 없다.
  count = local.enabled && length(local.public_group_names) > 0 ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  tags = merge(var.tags, {
    Name = "igw-${local.name_mid}-${var.purpose}"
  })
}

resource "aws_eip" "nat" {
  for_each = toset(local.nat_suffixes)

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "eip-${local.name_mid}-nat-${each.key}"
  })

  # provider 문서 권고 — EIP는 IGW가 먼저 존재해야 할 수 있다.
  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_suffixes)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.this["${local.nat_group}-${each.key}"].id

  tags = merge(var.tags, {
    Name = "ngw-${local.name_mid}-${local.nat_group}-${each.key}"
  })

  # provider 문서 권고 — 순서를 보장하려면 IGW에 명시적 의존을 둔다.
  depends_on = [aws_internet_gateway.this]
}

# public·isolated 그룹의 공유 RT. isolated는 여기서 끝이다 — 0.0.0.0/0 경로를 만들지 않는다.
# (secondary CIDR 연결 시 local 경로는 AWS가 자동 추가한다.)
resource "aws_route_table" "shared" {
  for_each = toset(local.enabled ? local.shared_rt_group_names : [])

  vpc_id = aws_vpc.this[0].id

  # C7 — extra_tags는 서브넷에만 부착한다(RT는 서브넷과 1:1이 아니다).
  tags = merge(var.tags, {
    Name = "rtb-${local.name_mid}-${each.key}"
  })
}

# private 그룹은 AZ별 RT. NAT 경로가 AZ마다 갈리기 때문이다(§1.2 라우팅 매트릭스).
resource "aws_route_table" "private" {
  for_each = { for key, def in local.subnet_defs : key => def if def.type == "private" }

  vpc_id = aws_vpc.this[0].id

  # each.key가 "<group>-<az suffix>" 이므로 §1.3의 private RT Name 패턴과 그대로 일치한다.
  tags = merge(var.tags, {
    Name = "rtb-${local.name_mid}-${each.key}"
  })
}

# ⚠️ C1 — 구조 라우트를 aws_route_table의 inline route 블록으로 쓰지 않는다.
#    inline route와 aws_route는 혼용 불가(provider: 서로의 규칙을 덮어쓴다)이고,
#    D3는 소비자가 이 RT에 aws_route로 운영 라우트를 얹는 것을 전제한다.
resource "aws_route" "public_internet" {
  for_each = toset(local.enabled ? local.public_group_names : [])

  route_table_id         = aws_route_table.shared[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route" "private_nat" {
  # 커버되지 않는 AZ는 여기서 제외하고 aws_vpc의 precondition이 보고하게 한다(C6).
  for_each = {
    for key, def in local.subnet_defs : key => def
    if local.nat_enabled && def.type == "private" && (var.single_nat_gateway || contains(local.nat_suffixes, def.az_suffix))
  }

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? local.nat_suffixes[0] : each.value.az_suffix].id
}

resource "aws_route_table_association" "shared" {
  for_each = { for key, def in local.subnet_defs : key => def if def.type != "private" }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.shared[each.value.group].id
}

resource "aws_route_table_association" "private" {
  for_each = { for key, def in local.subnet_defs : key => def if def.type == "private" }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
