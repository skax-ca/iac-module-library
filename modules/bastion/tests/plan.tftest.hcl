# 계약 검증 — 설계 docs/design/40-bastion.md §7.1 (T-1 ~ T-8)
#
# ⚠️ 이 파일이 계약의 **유일한 검출 지점**이다. 교차변수 validation은 validate가 아니라 plan 시점에
#    평가되므로, examples를 validate까지만 도는 규약으로는 §4.1의 가드가 전혀 잡히지 않는다.
#
# ⚠️ 이 repo는 배포하지 않는다. SSM 등록·세션 접속·kubectl 도달 판정은 **소비 repo 몫**이다(설계 §7.3).
#    여기서 증명하는 것은 "계획이 계약대로 나오는가"까지다.
#
# provider 모킹: command = plan도 data source를 실제 조회한다. 이 repo는 CI에 자격증명이 없으므로
# 모킹 없이는 plan이 죽는다. bastion은 upstream 모듈을 감싸지 않는 스크래치 모듈이라
# eks-cluster가 겪은 override_module 문제(중첩 모듈 입력 표현식)가 없다 — 검증이 훨씬 직접적이다.

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "ap-northeast-2"
    }
  }

  # 모킹은 computed 속성에 임의 문자열을 채우는데, 관리형 정책 ARN은 이 값으로 합성된다.
  # 임의 문자열이 들어가면 provider가 ARN 형식 검증에서 막는다 — 모듈 결함이 아니라 모킹 제약이다.
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
}

variables {
  naming = {
    workload    = "acme"
    env         = "prd"
    region_code = "an2"
  }

  vpc_id    = "vpc-0123456789abcdef0"
  subnet_id = "subnet-0123456789abcdef0"
  ami_id    = "ami-0123456789abcdef0"
}

# ── T-1 · T-2 — 기본 생성과 Name 태그 규약 ────────────────────────────────────
#
# CLAUDE.md 「강제 방식 5」: Name 태그 assertion을 tftest에 포함해 plan 단계에서 네이밍 위반을 잡는다.
# 약어는 카탈로그 SSOT를 따른다: ec2 · sgr · iamr · vol.
run "naming_contract" {
  command = plan

  assert {
    condition     = aws_instance.this[0].tags["Name"] == "ec2-acme-prd-an2-bastion-01"
    error_message = "인스턴스 Name 태그가 규약과 다르다: ${aws_instance.this[0].tags["Name"]}"
  }

  assert {
    condition     = aws_security_group.this[0].tags["Name"] == "sgr-acme-prd-an2-bastion-01"
    error_message = "SG Name 태그가 규약과 다르다: ${aws_security_group.this[0].tags["Name"]}"
  }

  assert {
    # SG는 이름이 곧 식별자인 제약 리소스다(02 §1.5) — 태그와 name 인자가 함께 맞아야 한다.
    condition     = aws_security_group.this[0].name == "sgr-acme-prd-an2-bastion-01"
    error_message = "SG name 인자가 Name 태그와 다르다: ${aws_security_group.this[0].name}"
  }

  assert {
    condition     = aws_iam_role.this[0].name == "iamr-acme-prd-an2-bastion-01"
    error_message = "IAM role 이름이 규약과 다르다: ${aws_iam_role.this[0].name}"
  }

  assert {
    # 인스턴스 프로파일은 약어를 신설하지 않고 role 이름을 상속한다(카탈로그 종속 객체 규약).
    condition     = aws_iam_instance_profile.this[0].name == aws_iam_role.this[0].name
    error_message = "인스턴스 프로파일이 role 이름을 상속하지 않았다 — 카탈로그에 없는 약어를 만들면 안 된다."
  }

  assert {
    # 볼륨 태그는 root_block_device.tags가 아니라 volume_tags로 붙인다(SCP·ABAC 대응, main.tf 주석).
    condition     = aws_instance.this[0].volume_tags["Name"] == "vol-acme-prd-an2-bastion-01"
    error_message = "볼륨 Name 태그가 규약과 다르다: ${aws_instance.this[0].volume_tags["Name"]}"
  }
}

# ── T-4 — 인바운드 0 (D-BASTION-ACCESS의 실물) ────────────────────────────────
#
# ⭐ 이 모듈의 존재 이유에 가장 가까운 테스트다. ingress 규칙이 하나라도 생기면 SSM 전용이라는
#    전제가 깨지고, "경계를 IAM 하나로 수렴시킨다"는 §1.1의 논증이 무효가 된다.
run "no_inbound_rules" {
  command = plan

  assert {
    # 이 모듈은 aws_vpc_security_group_ingress_rule을 **선언조차 하지 않는다**.
    # 선언이 없으므로 egress만 세어 대조한다 — egress 기본값은 CIDR 1개다.
    condition     = length(aws_vpc_security_group_egress_rule.https) == 1
    error_message = "egress 규칙이 1건이어야 한다(443/tcp). 인바운드 규칙은 이 모듈에 존재하지 않는다."
  }

  assert {
    condition = alltrue([
      for r in values(aws_vpc_security_group_egress_rule.https) :
      r.from_port == 443 && r.to_port == 443 && r.ip_protocol == "tcp"
    ])
    error_message = "egress는 443/tcp 하나여야 한다 — SSM·패키지·차트 저장소가 전부 HTTPS다."
  }
}

# ── T-5 — 하드닝 4종 (설계 §4.2, 변수로 열지 않는 것) ─────────────────────────
run "hardening_contract" {
  command = plan

  assert {
    condition     = aws_instance.this[0].metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2가 강제되지 않았다(http_tokens != required)."
  }

  assert {
    condition     = aws_instance.this[0].metadata_options[0].http_put_response_hop_limit == 1
    error_message = "IMDS hop limit이 1이어야 한다."
  }

  assert {
    condition     = aws_instance.this[0].root_block_device[0].encrypted
    error_message = "root 볼륨 암호화는 계약이다 — 변수로 끌 수 없다."
  }

  assert {
    condition     = aws_instance.this[0].root_block_device[0].volume_type == "gp3"
    error_message = "root 볼륨은 gp3여야 한다."
  }

  assert {
    condition     = aws_instance.this[0].root_block_device[0].volume_size == 10
    error_message = "root 볼륨 기본 크기가 10GiB여야 한다 — /var/tmp 다운로드 여유의 근거다."
  }
}

# ⚠️ **하드닝 4종 중 2개는 여기서 검증할 수 없다** — 모킹의 관측 한계다(2026-08-05 실측).
#
#    `key_name`(SSH 키페어 미지정)과 `associate_public_ip_address`(공인 IP 미할당)는
#    **인자를 선언하지 않는 것** 자체가 계약이다. 그런데 둘 다 optional + computed 라
#    mock_provider가 임의 문자열/불리언을 채운다(실측: key_name = "Wb0Vk").
#    실제 apply에서는 null이지만 plan 모킹에서는 그 값을 볼 수 없다.
#
#    ⛔ mock_resource로 null을 강제해 통과시키지 않는다 — 그러면 assertion이 모듈이 아니라
#       **자기 자신의 모킹 설정**을 검증하게 된다. 통과하는 가짜 테스트는 없는 것보다 나쁘다.
#
#    🔑 일반화하면: **"미지정"을 계약으로 삼는 항목은 plan 테스트로 지킬 수 없다.**
#       이 둘의 회귀 방지는 코드 리뷰와 설계 §4.2의 하드닝 목록에 남는다.
#       (공인 IP는 추가로 서브넷의 map_public_ip_on_launch에도 달려 있어 모듈 단독 판정이 애초에 불가능하다.)

# ── T-3 — kill switch (D-BASTION-LIFECYCLE) ───────────────────────────────────
run "kill_switch_disables_everything" {
  command = plan

  variables {
    bastion_enabled = false
  }

  assert {
    condition     = length(aws_instance.this) == 0
    error_message = "bastion_enabled = false인데 인스턴스가 계획됐다."
  }

  assert {
    condition     = length(aws_security_group.this) == 0
    error_message = "bastion_enabled = false인데 SG가 계획됐다."
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.https) == 0
    error_message = "bastion_enabled = false인데 egress 규칙이 계획됐다."
  }

  assert {
    condition     = length(aws_iam_role.this) == 0 && length(aws_iam_instance_profile.this) == 0
    error_message = "bastion_enabled = false인데 IAM 리소스가 계획됐다."
  }

  assert {
    # 출력이 null이어야 소비 루트가 try() 없이 eks-cluster에 그대로 넘겨도 깨지지 않는다(설계 §5.1).
    condition     = output.bastion_instance_id == null && output.bastion_security_group_id == null && output.bastion_iam_role_arn == null
    error_message = "kill switch 상태에서 출력이 null이 아니다 — 소비 루트의 조립이 깨진다."
  }
}

# ── T-6 — EKS 연동 양성 (D-BASTION-SEAM 1층) ──────────────────────────────────
run "eks_integration_creates_scoped_policy" {
  command = plan

  variables {
    eks_cluster_name = "eks-acme-prd-an2-main-01"
    eks_cluster_arn  = "arn:aws:eks:ap-northeast-2:123456789012:cluster/eks-acme-prd-an2-main-01"
    kubectl_version  = "v1.35.7"
  }

  assert {
    condition     = length(aws_iam_role_policy.eks_describe) == 1
    error_message = "EKS 연동을 켰는데 인라인 정책이 계획되지 않았다."
  }

  assert {
    # 종속 객체 이름은 부모(role) 이름을 상속한다.
    condition     = aws_iam_role_policy.eks_describe[0].name == "iamr-acme-prd-an2-bastion-01-eks-policy"
    error_message = "인라인 정책 이름이 부모 role 이름을 상속하지 않았다: ${aws_iam_role_policy.eks_describe[0].name}"
  }

  assert {
    # ⭐ 권한이 **그 클러스터 ARN으로 한정**되는 것이 1층의 핵심이다.
    #    Resource = "*"였다면 bastion이 계정의 모든 클러스터 kubeconfig를 만들 수 있다.
    condition     = strcontains(aws_iam_role_policy.eks_describe[0].policy, "arn:aws:eks:ap-northeast-2:123456789012:cluster/eks-acme-prd-an2-main-01")
    error_message = "인라인 정책이 클러스터 ARN으로 한정되지 않았다."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.eks_describe[0].policy, "eks:DescribeCluster")
    error_message = "인라인 정책에 eks:DescribeCluster가 없다 — update-kubeconfig가 실패한다."
  }
}

# EKS 연동을 끄면 인라인 정책을 만들지 않는다 — 쓰지 않는 권한을 남기지 않는다.
run "eks_integration_off_creates_no_policy" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.eks_describe) == 0
    error_message = "EKS 연동을 켜지 않았는데 인라인 정책이 계획됐다."
  }

  assert {
    # role 자체는 남는다 — SSM 접속은 EKS와 무관하게 성립해야 한다.
    condition     = length(aws_iam_role.this) == 1
    error_message = "EKS 연동과 무관하게 SSM용 role은 있어야 한다."
  }
}

# ── T-7 — EKS 연동 음성 ×2 (교차변수 가드) ────────────────────────────────────
run "reject_cluster_name_without_arn" {
  command = plan

  variables {
    eks_cluster_name = "eks-acme-prd-an2-main-01"
    # eks_cluster_arn 없음 → kubeconfig는 만들어지는데 권한이 없다
  }

  expect_failures = [var.eks_cluster_arn]
}

run "reject_cluster_arn_without_name" {
  command = plan

  variables {
    eks_cluster_arn = "arn:aws:eks:ap-northeast-2:123456789012:cluster/eks-acme-prd-an2-main-01"
    # eks_cluster_name 없음 → 권한은 있는데 kubeconfig가 없다
  }

  expect_failures = [var.eks_cluster_arn]
}

# ── T-8 — ⭐ kill switch × 가드 (파기 경로 보호) ──────────────────────────────
#
# D-EXTDNS-ZONE에서 배운 것의 회수 지점이다(설계 §7.1).
# 가드에 `!var.bastion_enabled ||` 가 없으면 이 케이스가 **거부되고**, 그것은 곧
# "끌 수는 있으나 끈 상태를 유지할 수 없는" 반쪽 kill switch를 뜻한다.
run "guard_does_not_block_kill_switch" {
  command = plan

  variables {
    bastion_enabled  = false
    eks_cluster_name = "eks-acme-prd-an2-main-01"
    # ARN 없음 — 켜져 있었다면 위 T-7이 거부했을 조합이다
  }

  assert {
    condition     = length(aws_instance.this) == 0
    error_message = "파기 경로가 거부되면 안 된다 — 반쪽 kill switch가 된다."
  }
}

# ── egress 가드 ───────────────────────────────────────────────────────────────
#
# 인바운드가 없는 구조라 아웃바운드는 **유일한 경로**다. 비우면 SSM 세션 자체가 성립하지 않는데,
# 그 사실은 apply 후 "접속이 안 된다"로만 드러난다.
run "reject_empty_egress" {
  command = plan

  variables {
    egress_cidr_blocks = []
  }

  expect_failures = [var.egress_cidr_blocks]
}
