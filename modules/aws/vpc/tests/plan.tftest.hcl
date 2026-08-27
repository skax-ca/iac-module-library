# vpc 모듈 계약 검증
#
# ⚠️ 이 파일이 계약의 유일한 검출 지점이다. 교차변수 validation과 precondition은
#    validate가 아니라 plan 시점에 평가되므로, examples를 validate까지만 도는 규약으로는
#    계약 위반이 전혀 잡히지 않는다.
#
# provider를 모킹하는 이유: command = plan도 data.aws_availability_zones를 실제 조회한다.
# 이 repo는 배포하지 않아 CI에 자격증명이 없으므로 모킹 없이는 plan이 죽는다.
# AZ 목록을 고정값으로 주입하면 suffix → AZ 이름 해석까지 검증 대상이 된다.
#
# ⚠️ 모킹에서는 computed 속성(id·arn)이 plan 시점에 unknown이다. 따라서 assertion은
#    설정값(tags·cidr_block·availability_zone·name)과 인스턴스 개수·키 집합만 본다.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c", "ap-northeast-2d"]
    }
  }

  # ⚠️ 모킹은 computed 속성에 임의 문자열을 채우는데, aws provider는 plan 시점에 ARN 형식을
  #    검증한다(aws_flow_log의 log_destination·iam_role_arn). 형식이 맞는 값을 주지 않으면
  #    "invalid ARN: arn: invalid prefix"로 plan이 죽는다 — 모듈 결함이 아니라 모킹의 제약이다.
  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:ap-northeast-2:111122223333:log-group:/aws/vpc/flow-log/mock"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111122223333:role/mock"
    }
  }
}

# 기본 시나리오: public(elb) + private(app) + isolated(db) 3그룹, secondary CIDR 1개.
# az_selection = ["a", "c"]로 "b를 건너뛰는" 서울 리전 관례를 그대로 검증한다.
variables {
  naming = {
    workload    = "demo"
    env         = "dev"
    region_code = "an2"
  }
  cidr_block            = "10.0.0.0/16"
  secondary_cidr_blocks = ["100.64.0.0/16"]
  az_count              = 2
  az_selection          = ["a", "c"]
  eks_cluster_name      = "eks-demo-dev-an2-main"
  single_nat_gateway    = true

  subnet_groups = {
    "pub-uniq" = {
      type     = "public"
      cidrs    = ["10.0.0.0/24", "10.0.1.0/24"]
      eks_role = "elb"
    }
    "app-uniq" = {
      type  = "private"
      cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
    }
    "db-uniq" = {
      type  = "isolated"
      cidrs = ["10.0.20.0/26", "10.0.21.0/26"]
    }
  }
}

# ── 네이밍 규약 — 릴리스 게이트 필수 항목 ───────────────────────────────────────
run "naming_contract" {
  command = plan

  assert {
    condition     = aws_vpc.this[0].tags["Name"] == "vpc-demo-dev-an2-main"
    error_message = "VPC Name이 vpc-<mid>-<purpose> 포맷이 아니다: ${aws_vpc.this[0].tags["Name"]}"
  }

  assert {
    condition     = aws_subnet.this["pub-uniq-a"].tags["Name"] == "snet-demo-dev-an2-pub-uniq-a"
    error_message = "서브넷 Name이 snet-<mid>-<group>-<az> 포맷이 아니다: ${aws_subnet.this["pub-uniq-a"].tags["Name"]}"
  }

  # 하류 루트가 data.aws_subnets로 그룹 조회하는 키.
  # ⚠️ 값은 **그룹 키 그대로**여야 한다(AZ 토큰이 붙지 않는다) — 붙으면 그룹 단위 조회가 깨진다.
  assert {
    condition     = aws_subnet.this["pub-uniq-a"].tags["SubnetGroup"] == "pub-uniq"
    error_message = "SubnetGroup 태그는 AZ 토큰 없이 그룹 키여야 한다: ${aws_subnet.this["pub-uniq-a"].tags["SubnetGroup"]}"
  }

  # 같은 그룹의 다른 AZ 서브넷도 같은 값을 가져야 조회가 2개를 다 잡는다.
  assert {
    condition     = aws_subnet.this["app-uniq-c"].tags["SubnetGroup"] == "app-uniq"
    error_message = "같은 그룹의 서브넷은 AZ와 무관하게 동일한 SubnetGroup 값을 가져야 한다."
  }

  # public·isolated는 그룹당 공유 RT라 AZ 토큰이 없고, private는 AZ별이라 붙는다.
  assert {
    condition     = aws_route_table.shared["db-uniq"].tags["Name"] == "rtb-demo-dev-an2-db-uniq"
    error_message = "공유 RT Name이 rtb-<mid>-<group> 포맷이 아니다: ${aws_route_table.shared["db-uniq"].tags["Name"]}"
  }

  assert {
    condition     = aws_route_table.private["app-uniq-a"].tags["Name"] == "rtb-demo-dev-an2-app-uniq-a"
    error_message = "private RT Name이 rtb-<mid>-<group>-<az> 포맷이 아니다: ${aws_route_table.private["app-uniq-a"].tags["Name"]}"
  }

  assert {
    condition     = aws_internet_gateway.this[0].tags["Name"] == "igw-demo-dev-an2-main"
    error_message = "IGW Name이 igw-<mid>-<purpose> 포맷이 아니다: ${aws_internet_gateway.this[0].tags["Name"]}"
  }

  assert {
    condition     = aws_nat_gateway.this["a"].tags["Name"] == "ngw-demo-dev-an2-pub-uniq-a"
    error_message = "NAT Name이 ngw-<mid>-<nat그룹>-<az> 포맷이 아니다: ${aws_nat_gateway.this["a"].tags["Name"]}"
  }

  assert {
    condition     = aws_eip.nat["a"].tags["Name"] == "eip-demo-dev-an2-nat-a"
    error_message = "EIP Name이 eip-<mid>-nat-<az> 포맷이 아니다: ${aws_eip.nat["a"].tags["Name"]}"
  }

  # Flow Logs 3종.
  assert {
    condition     = aws_cloudwatch_log_group.flow_logs[0].tags["Name"] == "cwlg-demo-dev-an2-main-flowlog"
    error_message = "로그 그룹 Name이 cwlg-<mid>-<purpose>-flowlog 포맷이 아니다: ${aws_cloudwatch_log_group.flow_logs[0].tags["Name"]}"
  }

  assert {
    condition     = aws_iam_role.flow_logs[0].name == "iamr-demo-dev-an2-main-flowlog"
    error_message = "IAM 역할 이름이 iamr-<mid>-<purpose>-flowlog 포맷이 아니다: ${aws_iam_role.flow_logs[0].name}"
  }

  # 종속 객체는 부모 이름을 상속한다(카탈로그 규약). inline 정책은 tags가 없어 name이 곧 식별자다.
  assert {
    condition     = aws_iam_role_policy.flow_logs[0].name == "iamr-demo-dev-an2-main-flowlog-policy"
    error_message = "inline 정책 이름이 <role 이름>-policy가 아니다: ${aws_iam_role_policy.flow_logs[0].name}"
  }

  assert {
    condition     = aws_flow_log.this[0].tags["Name"] == "fl-demo-dev-an2-main"
    error_message = "Flow Log Name이 fl-<mid>-<purpose> 포맷이 아니다: ${aws_flow_log.this[0].tags["Name"]}"
  }

  # CloudWatch 경로형 이름은 Name 태그와 다른 축이다.
  assert {
    condition     = aws_cloudwatch_log_group.flow_logs[0].name == "/aws/vpc/flow-log/demo-dev-an2-main"
    error_message = "로그 그룹 경로가 /aws/vpc/flow-log/<mid>-<purpose>가 아니다: ${aws_cloudwatch_log_group.flow_logs[0].name}"
  }
}

# ── 그룹 × AZ 전개와 AZ 해석 ────────────────────────────────────────────────────
run "group_az_expansion" {
  command = plan

  assert {
    condition     = length(aws_subnet.this) == 6
    error_message = "서브넷 수가 그룹별 cidrs 길이의 합(6)과 다르다: ${length(aws_subnet.this)}"
  }

  # az_selection = ["a", "c"] → b를 건너뛴다. AZ 배정 계약의 핵심이다.
  assert {
    condition     = aws_subnet.this["pub-uniq-c"].availability_zone == "ap-northeast-2c"
    error_message = "az_selection 우선순위가 AZ 이름으로 해석되지 않았다: ${aws_subnet.this["pub-uniq-c"].availability_zone}"
  }

  assert {
    condition     = length([for key in keys(aws_subnet.this) : key if endswith(key, "-b")]) == 0
    error_message = "az_selection에 없는 b존에 서브넷이 생성됐다."
  }

  assert {
    condition     = aws_subnet.this["db-uniq-a"].cidr_block == "10.0.20.0/26"
    error_message = "그룹 cidrs가 AZ 순서대로 배정되지 않았다: ${aws_subnet.this["db-uniq-a"].cidr_block}"
  }

  # secondary CIDR association 수.
  assert {
    condition     = length(aws_vpc_ipv4_cidr_block_association.this) == 1
    error_message = "secondary CIDR association 수가 1이 아니다: ${length(aws_vpc_ipv4_cidr_block_association.this)}"
  }

  # DNS 속성은 모듈이 true로 고정한다.
  assert {
    condition     = aws_vpc.this[0].enable_dns_hostnames && aws_vpc.this[0].enable_dns_support
    error_message = "VPC DNS 속성이 둘 다 true가 아니다."
  }
}

# ── 라우팅 매트릭스 ─────────────────────────────────────────────────────────────
run "routing_matrix" {
  command = plan

  # public·isolated는 그룹당 1개, private만 AZ별.
  assert {
    condition     = length(aws_route_table.shared) == 2 && length(aws_route_table.private) == 2
    error_message = "RT 구성이 라우팅 매트릭스와 다르다(shared 2·private 2 기대): shared=${length(aws_route_table.shared)} private=${length(aws_route_table.private)}"
  }

  assert {
    condition     = keys(aws_route.public_internet) == ["pub-uniq"]
    error_message = "IGW 경로가 public 그룹에만 걸리지 않았다: ${join(",", keys(aws_route.public_internet))}"
  }

  assert {
    condition     = aws_route.public_internet["pub-uniq"].destination_cidr_block == "0.0.0.0/0"
    error_message = "public 기본 경로 목적지가 0.0.0.0/0이 아니다."
  }

  assert {
    condition     = keys(aws_route.private_nat) == ["app-uniq-a", "app-uniq-c"]
    error_message = "NAT 경로가 private 서브넷마다 걸리지 않았다: ${join(",", keys(aws_route.private_nat))}"
  }

  # isolated 그룹에는 0.0.0.0/0 경로가 없어야 한다 — 모듈이 만드는 라우트 어디에도 등장하지 않는다.
  assert {
    condition = length([
      for key in concat(keys(aws_route.private_nat), keys(aws_route.public_internet)) :
      key if startswith(key, "db-uniq")
    ]) == 0
    error_message = "isolated 그룹에 기본 경로가 생성됐다(local 라우트만 있어야 한다)."
  }

  # 모든 서브넷이 RT에 연결된다(공유 4 + private 2).
  assert {
    condition     = length(aws_route_table_association.shared) == 4 && length(aws_route_table_association.private) == 2
    error_message = "RT 연결 수가 서브넷 수와 맞지 않는다: shared=${length(aws_route_table_association.shared)} private=${length(aws_route_table_association.private)}"
  }
}

# ── EKS 태그의 그룹별 이관 ──────────────────────────────────────────────────────
run "eks_tags_per_group" {
  command = plan

  # 공식 요구값은 "1"이다(EKS 네트워킹 요구사항 문서).
  assert {
    condition     = aws_subnet.this["pub-uniq-a"].tags["kubernetes.io/role/elb"] == "1"
    error_message = "eks_role = elb 그룹에 role 태그가 붙지 않았다."
  }

  # cluster 태그는 레거시다 — LB Controller 2.1.1 이하만 요구한다.
  assert {
    condition     = aws_subnet.this["pub-uniq-a"].tags["kubernetes.io/cluster/eks-demo-dev-an2-main"] == "shared"
    error_message = "eks_cluster_name이 지정됐는데 cluster 태그가 붙지 않았다."
  }

  # eks_role 미지정 그룹에는 어떤 kubernetes.io 태그도 붙지 않아야 한다(일괄 부착 금지).
  assert {
    condition = length([
      for key in keys(aws_subnet.this["app-uniq-a"].tags) : key if startswith(key, "kubernetes.io/")
    ]) == 0
    error_message = "eks_role 미지정 그룹에 EKS 태그가 붙었다."
  }

  assert {
    condition = length([
      for key in keys(aws_subnet.this["db-uniq-a"].tags) : key if startswith(key, "kubernetes.io/")
    ]) == 0
    error_message = "eks_role 미지정 isolated 그룹에 EKS 태그가 붙었다."
  }
}

# ── per-AZ NAT ──────────────────────────────────────────────────────────────────
run "per_az_nat" {
  command = plan

  variables {
    single_nat_gateway = false
  }

  assert {
    condition     = keys(aws_nat_gateway.this) == ["a", "c"]
    error_message = "single_nat_gateway = false에서 AZ별 NAT가 만들어지지 않았다: ${join(",", keys(aws_nat_gateway.this))}"
  }

  assert {
    condition     = length(aws_eip.nat) == 2
    error_message = "NAT 수만큼 EIP가 만들어지지 않았다: ${length(aws_eip.nat)}"
  }

  assert {
    condition     = length(aws_route.private_nat) == 2
    error_message = "private 서브넷별 NAT 경로가 2개가 아니다: ${length(aws_route.private_nat)}"
  }
}

# ── kill switch ─────────────────────────────────────────────────────────────────
# ⚠️ deletion_protection 기본값 false에 의존한다. true면 삭제 보호 validation이 먼저 차단한다.
run "kill_switch_disables_everything" {
  command = plan

  variables {
    vpc_enabled = false
  }

  # ⚠️ HCL 표현식은 대괄호·괄호 안이 아니면 줄을 넘길 수 없다. 여러 조건은 alltrue([...])로 묶는다.
  assert {
    condition = alltrue([
      length(aws_vpc.this) == 0,
      length(aws_subnet.this) == 0,
      length(aws_route_table.shared) == 0,
      length(aws_route_table.private) == 0,
      length(aws_route_table_association.shared) == 0,
      length(aws_route_table_association.private) == 0,
    ])
    error_message = "vpc_enabled = false인데 코어 리소스가 남아 있다."
  }

  assert {
    condition = alltrue([
      length(aws_nat_gateway.this) == 0,
      length(aws_eip.nat) == 0,
      length(aws_internet_gateway.this) == 0,
      length(aws_vpc_ipv4_cidr_block_association.this) == 0,
      length(aws_route.public_internet) == 0,
      length(aws_route.private_nat) == 0,
    ])
    error_message = "vpc_enabled = false인데 게이트웨이·라우트·CIDR association이 남아 있다."
  }

  assert {
    condition = alltrue([
      length(aws_flow_log.this) == 0,
      length(aws_cloudwatch_log_group.flow_logs) == 0,
      length(aws_iam_role.flow_logs) == 0,
      length(aws_iam_role_policy.flow_logs) == 0,
    ])
    error_message = "vpc_enabled = false인데 Flow Logs 리소스가 남아 있다(vpc_enabled가 상위 게이트다)."
  }

  # 출력이 에러 대신 null·빈 값을 준다 — 소비자 plan이 깨지지 않아야 teardown이 성립한다.
  assert {
    condition = alltrue([
      output.vpc_id == null,
      output.vpc_cidr_block == null,
      output.flow_log_group_name == null,
    ])
    error_message = "비활성 시 스칼라 출력이 null이 아니다."
  }

  # ⚠️ == {} / == [] 로 비교하면 안 된다. HCL의 ==는 타입까지 비교하므로
  #    map of tuple과 object({})는 둘 다 비어 있어도 동등하지 않다. length()로 본다.
  assert {
    condition = alltrue([
      length(output.subnet_ids_by_group) == 0,
      length(output.route_table_ids_by_group) == 0,
      length(output.nat_gateway_ids) == 0,
      length(output.secondary_cidr_blocks) == 0,
    ])
    error_message = "비활성 시 map·list 출력이 빈 값이 아니다."
  }
}

# ── Flow Logs 개별 kill switch ──────────────────────────────────────────────────
run "flow_logs_can_be_disabled_alone" {
  command = plan

  variables {
    flow_logs_enabled = false
  }

  assert {
    condition = alltrue([
      length(aws_flow_log.this) == 0,
      length(aws_cloudwatch_log_group.flow_logs) == 0,
      length(aws_iam_role.flow_logs) == 0,
      length(aws_iam_role_policy.flow_logs) == 0,
    ])
    error_message = "flow_logs_enabled = false인데 Flow Logs 리소스가 생성됐다."
  }

  # VPC는 그대로 남는다 — 두 스위치는 독립이다.
  assert {
    condition     = length(aws_vpc.this) == 1 && length(aws_subnet.this) == 6
    error_message = "Flow Logs만 껐는데 코어 리소스가 영향을 받았다."
  }

  assert {
    condition     = output.flow_log_group_name == null
    error_message = "Flow Logs 비활성 시 flow_log_group_name이 null이 아니다."
  }
}

# ── confused deputy 방어 ────────────────────────────────────────────────────────
# vpc-flow-logs.amazonaws.com은 전 세계 공용 서비스 principal이라 신뢰 정책에 계정·리소스
# 조건이 없으면 남의 flow log가 우리 로그 그룹으로 배달된다. 조건의 "존재"만 계약으로 잠근다 —
# 조건이 실제 배달을 막는지는 mock으로 증명할 수 없고 실계정 로그 도착으로 판정한다.
run "flow_logs_trust_policy_guards_confused_deputy" {
  command = plan

  # 신뢰 정책은 data source 값으로 조립되고, mock_provider가 data source 값을 채우므로
  # plan 시점에 known이다 — resource의 arn·id가 unknown인 것과 다르다(이 파일 상단 주석 참조).
  assert {
    condition     = jsondecode(aws_iam_role.flow_logs[0].assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] != ""
    error_message = "flow logs 신뢰 정책에 aws:SourceAccount 조건이 없다 — confused deputy 무방비다."
  }

  # ID 대신 와일드카드를 쓰되(순환 참조 회피) vpc-flow-log 리소스 구간으로 한정돼야 한다.
  assert {
    condition     = can(regex(":vpc-flow-log/[*]$", jsondecode(aws_iam_role.flow_logs[0].assume_role_policy).Statement[0].Condition.ArnLike["aws:SourceArn"]))
    error_message = "flow logs 신뢰 정책의 aws:SourceArn이 :vpc-flow-log/* 로 끝나지 않는다."
  }
}

# ── 계약 위반은 plan에서 차단된다 ───────────────────────────────────────────────
# 보호를 켠 상태로는 파기할 수 없다. 우리 변수 이름으로 해법을 알려주는 것이 목적이다.
run "reject_teardown_while_protected" {
  command = plan

  variables {
    vpc_enabled         = false
    deletion_protection = true
  }

  expect_failures = [var.deletion_protection]
}

# az_selection을 지정하면 길이가 az_count와 같아야 한다(교차변수 validation).
run "reject_az_selection_length_mismatch" {
  command = plan

  variables {
    az_count     = 2
    az_selection = ["a", "c", "b"]
  }

  expect_failures = [var.az_selection]
}

# 그룹의 AZ 수는 cidrs 길이가 결정하고, az_count를 넘을 수 없다.
run "reject_group_wider_than_az_count" {
  command = plan

  variables {
    subnet_groups = {
      "pub-uniq" = {
        type  = "public"
        cidrs = ["10.0.0.0/24", "10.0.1.0/24"]
      }
      "app-uniq" = {
        type  = "private"
        cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
      }
    }
  }

  expect_failures = [aws_vpc.this]
}

# NAT는 public 그룹의 서브넷에 놓이므로 public 없이는 만들 수 없다.
run "reject_nat_without_public_group" {
  command = plan

  variables {
    enable_nat_gateway = true
    subnet_groups = {
      "app-uniq" = {
        type  = "private"
        cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
      }
      "db-uniq" = {
        type  = "isolated"
        cidrs = ["10.0.20.0/26", "10.0.21.0/26"]
      }
    }
  }

  expect_failures = [aws_vpc.this]
}

# nullable = false 계약: 명시적 null이 crash 대신 default로 조용히 대체돼야 한다.
# tags는 merge(var.tags, {...})에 쓰이므로 null이면 "argument must not be null"로 죽는 게
# nullable 없는 상태의 실제 실패 모드였다(docs/decisions.md 「변수 계약 (nullable)」 참조).
run "nullable_false_falls_back_to_default" {
  command = plan

  variables {
    tags                = null
    purpose             = null
    vpc_enabled         = null
    deletion_protection = null
  }

  assert {
    condition     = aws_vpc.this[0].tags["Name"] == "vpc-demo-dev-an2-main"
    error_message = "purpose = null이 default \"main\"으로 대체되지 않았다: ${aws_vpc.this[0].tags["Name"]}"
  }

  assert {
    condition     = length([for k, v in aws_vpc.this[0].tags : k if k != "Name"]) == 0
    error_message = "tags = null이 default {}로 대체되지 않아 Name 외 태그가 남아 있다."
  }

  assert {
    condition     = length(aws_vpc.this) == 1
    error_message = "vpc_enabled = null이 default true로 대체되지 않았다."
  }
}

# per-AZ NAT에서 커버되지 않는 AZ가 생기면 그 AZ의 private 서브넷에 기본 경로가 없다.
run "reject_per_az_nat_without_coverage" {
  command = plan

  variables {
    az_count           = 3
    az_selection       = ["a", "c", "b"]
    single_nat_gateway = false
    subnet_groups = {
      "pub-uniq" = {
        type  = "public"
        cidrs = ["10.0.0.0/24", "10.0.1.0/24"]
      }
      "app-uniq" = {
        type  = "private"
        cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
      }
    }
  }

  expect_failures = [aws_vpc.this]
}
