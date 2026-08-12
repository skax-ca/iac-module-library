# 계약 검증 — 설계 docs/design/20-eks-module.md §4 Task 20.7
#
# ⚠️ 이 파일이 계약의 **유일한 검출 지점**이다. 교차변수 validation은 validate가 아니라
#    plan 시점에 평가되므로(vpc 모듈에서 실측), examples를 validate까지만 도는 규약으로는
#    D-EKS-PROTECT의 파기 차단이나 core addon 보호가 전혀 잡히지 않는다.
#
# ⚠️ **facade 모듈의 관측 한계**: 이 모듈은 계산 결과를 upstream 모듈의 **입력**으로 넘기는데
#    tofu test는 하위 모듈에 들어간 값을 볼 수 없다. 그래서 검증은 셋 중 하나에 건다 —
#      ① 이 모듈이 직접 선언한 리소스(aws_iam_role.ebs_csi)
#      ② 이 모듈의 출력(effective_addon_names·cluster_name·*_iam_role_arn)
#      ③ validation 거부(expect_failures)
#    upstream에 넘어간 addon의 configuration_values 같은 내부는 **여기서 볼 수 없다** —
#    그 층은 라이브 apply에서 확인한다(설계 Task 20.8의 apply 미검증 표 대상).
#
# ⚠️ **cluster_security_group_additional_rules(D-WORKBENCH-SEAM 3층)도 그 한계에 걸린다**(2026-08-05).
#    값이 upstream의 aws_security_group_rule로 흘러가므로 여기서 규칙 내용을 볼 수 없다.
#    ⛔ 억지로 통과하는 assertion을 만들지 않는다 — workbench 모듈에서 세운 기준과 같다
#       ("통과하는 가짜 테스트는 없는 것보다 나쁘다", modules/workbench/tests 참조).
#    ⇒ 이 변수의 회귀 방지는 **examples/workbench-enterprise**가 실제로 소비하고 CI 게이트 ⑤
#      (예제 init + validate)가 도는 것이다. 변수명·타입이 깨지면 그 예제가 먼저 죽는다.
#
# provider 모킹: command = plan도 data source를 실제 조회한다. 이 repo는 배포하지 않아 CI에
# 자격증명이 없으므로 모킹 없이는 plan이 죽는다.

# ⚠️ **override_module은 이 모듈에 쓸 수 없다**(2026-08-03 실측).
#    module.eks를 덮으면 그 안의 중첩 모듈(eks_managed_node_group)이 **입력 표현식에서** 부모의
#    리소스(time_sleep.this[0])를 참조하는데, override가 부모 리소스를 없애 빈 인덱스로 죽는다.
#    중첩 모듈까지 함께 덮어도 마찬가지다 — override는 모듈 실행만 대체하고 **입력 표현식은 그대로
#    평가**하기 때문이다. 반쪽 override가 오히려 더 나쁜 상태를 만든다.
#
# ⇒ 그래서 mock_provider로 간다. 대신 **기본 시나리오에서 managed_node_groups를 비운다** —
#   NG가 있으면 for_each가 중첩 모듈을 깨우고, 그 안의 computed 속성을 전부 모킹해야 plan이 완주한다.
#   그건 우리 계약이 아니라 upstream 내부다.
#   ⚠️ 잃는 것: NG 경로의 plan-time 회귀 가드. NG 이름 길이 결함(iam_role_name)은 이 파일 첫 실행이
#      잡아 main.tf에서 고쳤으나, 그 수정을 **영구히 지키는 테스트는 여기 없다**.
#      NG 형상 검증은 examples/eks-cluster-enterprise 의 라이브 apply가 담당한다(Task 20.8 미검증 표).

mock_provider "aws" {
  # custom networking의 AZ 매핑을 검증하려면 서브넷의 availability_zone이 known이어야 한다.
  mock_data "aws_subnet" {
    defaults = {
      availability_zone = "ap-northeast-2a"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "ap-northeast-2"
    }
  }

  # upstream이 관리형 정책 ARN을 "arn:${partition}:iam::aws:policy/..."로 합성한다.
  # 모킹이 partition에 임의 문자열을 넣으면 provider가 ARN 형식 검증에서 막는다.
  mock_data "aws_partition" {
    defaults = {
      partition          = "aws"
      dns_suffix         = "amazonaws.com"
      id                 = "aws"
      reverse_dns_prefix = "com.amazonaws"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
      id         = "111122223333"
      arn        = "arn:aws:iam::111122223333:root"
    }
  }

  # enable_cluster_creator_admin_permissions = true 가 이 data source의 ARN으로 Access Entry를 만든다.
  # ⚠️ arn은 이 data source의 **입력 인자**라 모킹할 수 없다(non-computed). issuer_arn만 채운다.
  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn = "arn:aws:iam::111122223333:role/mock-session"
    }
  }

  # 모킹은 computed 속성에 임의 문자열을 채우는데 aws provider는 plan 시점에 ARN 형식을 검증한다.
  # 형식이 맞지 않으면 모듈 결함이 아니라 모킹 제약으로 plan이 죽는다(vpc tests와 같은 이유).
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111122223333:role/mock"
    }
  }

  # upstream이 time_sleep의 trigger로 클러스터의 CA 데이터를 읽는다(node_groups.tf).
  # 모킹은 nested block을 빈 리스트로 두므로 [0] 인덱싱에서 죽는다 — 값을 채워 그 층을 통과시킨다.
  mock_resource "aws_eks_cluster" {
    defaults = {
      arn                   = "arn:aws:eks:ap-northeast-2:111122223333:cluster/mock"
      certificate_authority = [{ data = "bW9jaw==" }]
      identity              = [{ oidc = [{ issuer = "https://oidc.eks.ap-northeast-2.amazonaws.com/id/MOCK" }] }]
      # ⚠️ version은 config 값이라 모킹할 수 없다("overriding configuration values is not allowed").
      #    mock으로 채울 수 있는 것은 computed 속성뿐이다.
    }
  }

  # 관리형 정책이 아닌, upstream이 만드는 고객 관리형 정책(cluster_encryption 등)의 ARN.
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::111122223333:policy/mock"
    }
  }

  # Karpenter 서브모듈은 override하지 않는다 — enable_karpenter = false 일 때 출력이 null이 되는지를
  # 봐야 하는데, override하면 항상 값이 나와 그 계약을 검증할 수 없기 때문이다.
  # 대신 EventBridge target이 참조하는 SQS ARN만 형식을 맞춰준다.
  mock_resource "aws_sqs_queue" {
    defaults = {
      arn = "arn:aws:sqs:ap-northeast-2:111122223333:mock-karpenter"
    }
  }

  # 같은 계열의 모킹 제약: upstream이 data.aws_iam_policy_document로 신뢰 정책을 만드는데,
  # 모킹이 json에 임의 문자열을 넣으면 provider가 "not a JSON object"로 거부한다.
  # 유효한 JSON을 주면 그 층을 통과해 **우리가 검증하려는 계약**까지 도달한다.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

# 기본 시나리오: custom networking 켜고 addon은 baseline 상속.
# managed_node_groups는 위 사유로 비운다(NG 계약은 변수 validation으로만 검증한다).
variables {
  naming = {
    workload    = "acme"
    env         = "prd"
    region_code = "an2"
  }
  purpose = "main"
  serial  = "01"

  vpc_id     = "vpc-00000000000000000"
  subnet_ids = ["subnet-node-a", "subnet-node-c"]

  # ⚠️ pod 서브넷을 **1개만** 준다. mock_data는 defaults 하나뿐이라 모든 aws_subnet에 같은 AZ를
  #    돌려주는데, ENIConfig 맵은 AZ를 키로 쓰므로 2개면 "Duplicate object key"로 죽는다.
  #    모듈 결함이 아니라 모킹의 제약이다 — 실제로는 AZ당 서브넷 1개가 정상 형상이다.
  #    (같은 AZ에 pod 서브넷을 둘 주는 것은 소비자 오류이며, 현재는 엔진 메시지로만 드러난다.
  #     도메인 언어 안내는 개선 여지로 남긴다.)
  pod_subnet_ids = ["subnet-pod-a"]

  managed_node_groups = {}
}

# ── AC1 · AC2: 네이밍 규약 (02 §1.4) ─────────────────────────────────────────

run "naming_and_name_tag" {
  command = plan

  assert {
    condition     = output.cluster_name == "eks-acme-prd-an2-main-01"
    error_message = "cluster_name이 eks-<workload>-<env>-<region_code>-<purpose>-<serial> 포맷으로 합성되어야 한다."
  }

  # ⚠️ Name 태그 assertion은 **특정 리소스 주소를 직접 타겟**한다. 전체 IAM 순회를 하면
  #    Karpenter 서브모듈이 만드는 위임 role(upstream 기본 네이밍)이 false-fail로 잡힌다(§2.6 이원화).
  assert {
    condition     = aws_iam_role.ebs_csi[0].tags["Name"] == "iamr-acme-prd-an2-ebs-csi"
    error_message = "모듈이 직접 저작하는 role은 카탈로그 약어(iamr)를 따라야 한다."
  }

  assert {
    condition     = aws_iam_role.ebs_csi[0].name == "iamr-acme-prd-an2-ebs-csi"
    error_message = "IAM role은 이름 자체가 식별자다 — name 인자도 카탈로그를 따라야 한다."
  }

  # Karpenter discovery 태그는 모듈이 조합해 돌려준다. 소비자는 이 값을 VPC 서브넷에도 넣는다.
  assert {
    condition     = output.karpenter_discovery_tag["karpenter.sh/discovery"] == "eks-acme-prd-an2-main-01"
    error_message = "discovery 태그 값은 클러스터 이름과 같아야 한다(subnet·SG 양쪽이 같은 값을 써야 selector가 맞는다)."
  }

  # 🔴 T-6 (D-KARPENTER-NODE-ROLE-NAME) — 이 이름은 **계층 2(GitOps)가 참조하는 계약**이다.
  #    upstream 기본(`Karpenter-<cluster>-<무작위>`)이면 클러스터를 다시 세울 때마다 값이 바뀌어
  #    GitOps 의 EC2NodeClass.spec.role 이 없는 role 을 가리킨다(2026-08-12 실측).
  # ⛔ 음성 판정: 무작위 접미사가 붙지 않을 것 — 여기서 통과하면 재구축이 견딘다.
  assert {
    condition     = output.karpenter_node_iam_role_name == "iamr-acme-prd-an2-karpenter-node"
    error_message = "Karpenter 노드 IAM role 이름은 결정적이어야 한다 — GitOps 가 값으로 참조하므로 재구축마다 바뀌면 안 된다."
  }
}

# ── AC3: addon baseline 상속 (§2.6-1) ────────────────────────────────────────

run "addon_baseline_inherited" {
  command = plan

  # cluster_addons를 비워도 baseline 6종이 살아 있어야 한다.
  # 이 계약이 깨지면 소비자가 addon 하나를 추가했을 때 coredns가 사라진다(= DNS 중단).
  assert {
    condition = output.effective_addon_names == tolist([
      "aws-ebs-csi-driver",
      "coredns",
      "eks-pod-identity-agent",
      "kube-proxy",
      "metrics-server",
      "vpc-cni",
    ])
    error_message = "cluster_addons가 비면 baseline 6종을 그대로 상속해야 한다."
  }
}

run "addon_increment_does_not_replace_baseline" {
  command = plan

  variables {
    # community tier 하나를 추가한다. merge이므로 baseline은 사라지지 않아야 한다.
    cluster_addons = {
      "cert-manager" = {}
    }
  }

  assert {
    condition     = length(output.effective_addon_names) == 7
    error_message = "addon 1개를 추가하면 baseline 6종 + 1 = 7이어야 한다. 6이면 맵이 통째로 대체된 것이다."
  }

  assert {
    condition     = contains(output.effective_addon_names, "coredns")
    error_message = "증분 추가가 baseline을 지우면 안 된다(누락 != 삭제)."
  }
}

# ── AC4: opt-out (§2.6-2) — 제거는 명시로만 ──────────────────────────────────

run "addon_opt_out_removes_addon_and_its_role" {
  command = plan

  variables {
    cluster_addons = {
      "aws-ebs-csi-driver" = { enabled = false }
      "metrics-server"     = { enabled = false }
    }
  }

  assert {
    condition     = length(output.effective_addon_names) == 4
    error_message = "optional addon 2종을 opt-out하면 core 4종만 남아야 한다."
  }

  # ebs-csi를 빼면 그 role도 만들지 않는다 — 쓰지 않는 role을 남기지 않는다(§2.6-4).
  assert {
    condition     = length(aws_iam_role.ebs_csi) == 0
    error_message = "aws-ebs-csi-driver를 opt-out하면 EBS CSI role도 생성하지 않아야 한다."
  }

  assert {
    condition     = output.ebs_csi_iam_role_arn == null
    error_message = "opt-out 시 출력은 에러가 아니라 null이어야 한다(01 §4 출력 계약)."
  }
}

# ── AC5: core addon 보호 (§2.6-2) ────────────────────────────────────────────

run "core_addon_cannot_be_disabled" {
  command = plan

  variables {
    cluster_addons = {
      # eks-pod-identity-agent가 core인 이유: 빠지면 IAM에는 role이 있는데 Pod가 자격증명을
      # 받지 못하는 **조용한 파손**이 된다(Karpenter·EBS CSI의 association 전제).
      "eks-pod-identity-agent" = { enabled = false }
    }
  }

  expect_failures = [var.cluster_addons]
}

run "core_addon_coredns_cannot_be_disabled" {
  command = plan

  variables {
    cluster_addons = {
      "coredns" = { enabled = false }
    }
  }

  expect_failures = [var.cluster_addons]
}

# ── AC6 · AC7: kill switch (D-EKS-ENABLED) ───────────────────────────────────

run "kill_switch_destroys_everything" {
  command = plan

  variables {
    cluster_enabled = false
  }

  # 이 모듈이 직접 선언한 리소스가 사라진다.
  assert {
    condition     = length(aws_iam_role.ebs_csi) == 0
    error_message = "cluster_enabled = false면 모듈이 만든 IAM role도 파기되어야 한다."
  }

  # ⚠️ **출력은 빈 문자열이 아니라 null이어야 한다.** upstream은 cluster_name에 ""를 돌려주는데
  #    facade가 정규화하지 않으면 소비자가 `X == ""`라는 upstream 구현 디테일을 알아야 한다.
  assert {
    condition     = output.cluster_name == null
    error_message = "kill switch 시 cluster_name은 null이어야 한다(빈 문자열이 아니라)."
  }

  assert {
    condition     = output.karpenter_discovery_tag == null
    error_message = "kill switch 시 파생 출력도 null이어야 한다."
  }

  # ⚠️ tolist([])와 직접 비교하면 요소 타입이 갈려(list of string vs list of dynamic) 실패한다.
  #    빈 컬렉션 비교는 길이로 한다.
  assert {
    condition     = length(output.effective_addon_names) == 0
    error_message = "kill switch 시 addon 목록은 비어야 한다."
  }
}

# ── AC8: 삭제 보호 (D-EKS-PROTECT) ───────────────────────────────────────────

run "deletion_protection_blocks_kill_switch" {
  command = plan

  variables {
    deletion_protection = true
    cluster_enabled     = false
  }

  # 보호를 켠 채로 파기하려는 조합을 plan 시점에 거부한다.
  # AWS도 apply 때 막지만, 그 오류는 우리 변수 이름으로 해법을 알려주지 않는다.
  expect_failures = [var.deletion_protection]
}

run "deletion_protection_allowed_when_enabled" {
  command = plan

  variables {
    deletion_protection = true
    cluster_enabled     = true
  }

  # 정상 조합은 통과해야 한다 — 위 거부가 과하게 넓지 않은지 확인하는 음성 테스트다.
  assert {
    condition     = output.cluster_name == "eks-acme-prd-an2-main-01"
    error_message = "deletion_protection = true는 정상 형상에서 계획을 막지 않아야 한다."
  }
}

# ── AC9: custom networking 전제 (§2.5) ───────────────────────────────────────

run "custom_networking_requires_pod_subnets" {
  command = plan

  variables {
    enable_custom_networking = true
    pod_subnet_ids           = []
  }

  # 켜 놓고 서브넷을 안 주면 ENIConfig가 빈 맵이 되어 **조용히 잘못 동작**한다.
  # 계약 위반으로 먼저 잡는다.
  expect_failures = [var.pod_subnet_ids]
}

run "custom_networking_can_be_disabled" {
  command = plan

  variables {
    enable_custom_networking = false
    pod_subnet_ids           = []
  }

  # 끈 상태에서는 pod_subnet_ids가 비어도 정상이다(minimal 예제의 형상).
  assert {
    condition     = contains(output.effective_addon_names, "vpc-cni")
    error_message = "custom networking을 꺼도 vpc-cni는 core라 남아야 한다."
  }
}

# ── AC10: Karpenter 토글 ─────────────────────────────────────────────────────

run "karpenter_disabled_yields_null_outputs" {
  command = plan

  variables {
    enable_karpenter = false
  }

  assert {
    condition     = output.karpenter_node_iam_role_name == null
    error_message = "enable_karpenter = false면 Karpenter 출력은 null이어야 한다."
  }

  assert {
    condition     = output.karpenter_discovery_tag != null
    error_message = "discovery 태그는 Karpenter를 꺼도 계산된다 — 소비자가 나중에 켤 때 같은 값을 써야 하기 때문이다."
  }
}

# ── AC11: 컨트롤러 IAM 위임 (§2.6a) ──────────────────────────────────────────

run "controller_iam_is_opt_in" {
  command = plan

  # 기본값은 off다 — 유휴 role과 불필요한 diff를 만들지 않는다.
  assert {
    condition     = output.alb_controller_iam_role_arn == null
    error_message = "enable_alb_controller_iam 기본값은 false여야 한다."
  }

  assert {
    condition     = output.external_dns_iam_role_arn == null
    error_message = "enable_external_dns_iam 기본값은 false여야 한다."
  }
}

run "controller_iam_opt_in_creates_roles" {
  command = plan

  variables {
    enable_alb_controller_iam = true
    enable_external_dns_iam   = true
    # ⚠️ zone ARN은 선택 사항이 아니다 — 비우면 D-EXTDNS-ZONE 가드가 거부한다.
    #    이 run은 v0.1.0까지 zone ARN 없이 통과했는데, 그것이 곧 2026-08-04 apply를
    #    죽인 형상이었다(설계 §4.1 ❌ 상자). 가드가 생기며 테스트도 실효 형상으로 바뀐다.
    external_dns_hosted_zone_arns = ["arn:aws:route53:::hostedzone/Z0123456789ABCDEFGHIJ"]
  }

  assert {
    condition     = output.alb_controller_iam_role_arn != null
    error_message = "opt-in하면 ALBC role이 생성되어야 한다."
  }

  assert {
    condition     = output.external_dns_iam_role_arn != null
    error_message = "opt-in하면 external-dns role이 생성되어야 한다."
  }
}

# ── D-EXTDNS-ZONE: external-dns zone ARN 전제 (§5.1-8) ───────────────────────

run "external_dns_iam_requires_hosted_zone_arns" {
  command = plan

  variables {
    enable_external_dns_iam       = true
    external_dns_hosted_zone_arns = []
  }

  # route53:ChangeResourceRecordSets는 리소스 수준 권한을 요구해 Resource = "*" 정책을
  # AWS가 400으로 거부한다. 2026-08-04 apply가 실제로 여기서 죽었고, 그때는 plan이 통과했다.
  # 🔑 mock provider는 정책을 AWS에 제출하지 않으므로 assert로는 잡을 수 없다 —
  #    조합 자체를 계약에서 배제하는 것이 유일한 plan-time 검출 경로다.
  expect_failures = [var.external_dns_hosted_zone_arns]
}

run "external_dns_iam_allowed_with_hosted_zone_arns" {
  command = plan

  variables {
    enable_external_dns_iam       = true
    external_dns_hosted_zone_arns = ["arn:aws:route53:::hostedzone/Z0123456789ABCDEFGHIJ"]
  }

  # 위 거부가 과하게 넓지 않은지 확인하는 음성 테스트다(deletion_protection 쌍과 같은 구조).
  assert {
    condition     = output.external_dns_iam_role_arn != null
    error_message = "zone ARN을 주면 external-dns role이 정상 생성되어야 한다."
  }
}

run "external_dns_zone_guard_does_not_block_kill_switch" {
  command = plan

  variables {
    cluster_enabled               = false
    enable_external_dns_iam       = true
    external_dns_hosted_zone_arns = []
  }

  # 🔑 파기 경로는 막지 않는다. iam.tf의 create = local.enabled && var.enable_external_dns_iam
  # 이라 kill switch가 꺼진 상태에서는 IAM 정책이 애초에 만들어지지 않는다 —
  # 여기서 거부하면 "끌 수는 있으나 끈 상태를 유지할 수 없는" 반쪽 kill switch가 된다(D-EKS-ENABLED).
  assert {
    condition     = output.external_dns_iam_role_arn == null
    error_message = "cluster_enabled = false면 external-dns role이 없어야 하고, 가드가 그 계획을 막아서도 안 된다."
  }
}

# ── 환경 프로파일: 컨트롤플레인 로깅 ─────────────────────────────────────────

run "invalid_log_type_is_rejected" {
  command = plan

  variables {
    enabled_log_types = ["api", "typo-scheduler"]
  }

  expect_failures = [var.enabled_log_types]
}

# ── 노드그룹 계약 ────────────────────────────────────────────────────────────

run "invalid_capacity_type_is_rejected" {
  command = plan

  variables {
    managed_node_groups = {
      system = {
        instance_types = ["m6i.large"]
        min_size       = 1
        max_size       = 2
        desired_size   = 1
        capacity_type  = "RESERVED" # ON_DEMAND | SPOT 만 유효
      }
    }
  }

  expect_failures = [var.managed_node_groups]
}

# D-NODE-ARCH — graviton 전환에서 가장 흔한 오타를 plan 시점에 잡는지 확인한다.
# ⚠️ 이 검증이 없으면 클러스터가 다 만들어진 뒤 노드그룹 단계에서 AWS API 가 거부한다(시간 손실 + 부분 생성).
#
# ℹ️ **정상 경로(arm 조합이 plan 을 통과한다)는 여기서 잠그지 않는다.** 이 파일 머리말의 결정대로
#    NG 를 실제로 plan 하면 중첩 모듈이 깨어나 upstream 내부 computed 속성을 전부 모킹해야 한다
#    (실측: mock 이 launch_template.id 에 랜덤 문자열을 넣어 provider 의 'lt-' 형식 검증에서 죽는다).
#    그건 우리 계약이 아니다 — arm 형상 검증은 라이브 apply 가 담당한다(Task 20.8 미검증 표).
#    expect_failures 는 변수 validation 단계에서 끝나 중첩 모듈을 깨우지 않으므로 이 run 은 성립한다.
run "invalid_ami_type_is_rejected" {
  command = plan

  variables {
    managed_node_groups = {
      system = {
        instance_types = ["t4g.medium"]
        min_size       = 1
        max_size       = 2
        desired_size   = 1
        ami_type       = "AL2023_ARM64_STANDARD" # 밑줄 누락 — 올바른 값은 AL2023_ARM_64_STANDARD
      }
    }
  }

  expect_failures = [var.managed_node_groups]
}
