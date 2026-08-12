# workbench 모듈 계약 검증
#
# ⚠️ 이 파일이 계약의 유일한 검출 지점이다. 교차변수 validation은 validate가 아니라 plan 시점에
#    평가되므로, examples를 validate까지만 도는 규약으로는 변수 가드가 전혀 잡히지 않는다.
#
# ⚠️ 이 repo는 배포하지 않는다. SSM 등록·세션 접속·kubectl 도달 판정은 소비 repo 몫이다.
#    여기서 증명하는 것은 "계획이 계약대로 나오는가"까지다.
#
# provider 모킹: command = plan도 data source를 실제 조회한다. 이 repo는 CI에 자격증명이 없으므로
# 모킹 없이는 plan이 죽는다. workbench는 upstream 모듈을 감싸지 않는 스크래치 모듈이라
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
    workload    = "demo"
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
    condition     = aws_instance.this[0].tags["Name"] == "ec2-demo-prd-an2-workbench-01"
    error_message = "인스턴스 Name 태그가 규약과 다르다: ${aws_instance.this[0].tags["Name"]}"
  }

  assert {
    condition     = aws_security_group.this[0].tags["Name"] == "sgr-demo-prd-an2-workbench-01"
    error_message = "SG Name 태그가 규약과 다르다: ${aws_security_group.this[0].tags["Name"]}"
  }

  assert {
    # SG는 이름이 곧 식별자인 제약 리소스다 — 태그와 name 인자가 함께 맞아야 한다.
    condition     = aws_security_group.this[0].name == "sgr-demo-prd-an2-workbench-01"
    error_message = "SG name 인자가 Name 태그와 다르다: ${aws_security_group.this[0].name}"
  }

  assert {
    condition     = aws_iam_role.this[0].name == "iamr-demo-prd-an2-workbench-01"
    error_message = "IAM role 이름이 규약과 다르다: ${aws_iam_role.this[0].name}"
  }

  assert {
    # 인스턴스 프로파일은 약어를 신설하지 않고 role 이름을 상속한다(카탈로그 종속 객체 규약).
    condition     = aws_iam_instance_profile.this[0].name == aws_iam_role.this[0].name
    error_message = "인스턴스 프로파일이 role 이름을 상속하지 않았다 — 카탈로그에 없는 약어를 만들면 안 된다."
  }

  assert {
    # 볼륨 태그는 root_block_device.tags가 아니라 volume_tags로 붙인다(SCP·ABAC 대응, main.tf 주석).
    condition     = aws_instance.this[0].volume_tags["Name"] == "vol-demo-prd-an2-workbench-01"
    error_message = "볼륨 Name 태그가 규약과 다르다: ${aws_instance.this[0].volume_tags["Name"]}"
  }
}

# ── T-4 — 인바운드 0 ────────────────────────────────────────────────────────────
#
# 이 모듈의 존재 이유에 가장 가까운 테스트다. ingress 규칙이 하나라도 생기면 SSM 전용이라는
# 전제가 깨지고, 경계를 IAM 하나로 수렴시킨다는 설계 자체가 무효가 된다.
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

# ── T-5 — 하드닝 4종 (변수로 열지 않는 것) ──────────────────────────────────────
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

# ⚠️ **하드닝 4종 중 2개는 여기서 검증할 수 없다** — 모킹의 관측 한계다.
#
#    `key_name`(SSH 키페어 미지정)과 `associate_public_ip_address`(공인 IP 미할당)는
#    **인자를 선언하지 않는 것** 자체가 계약이다. 그런데 둘 다 optional + computed 라
#    mock_provider가 임의 문자열/불리언을 채운다(예: key_name = "Wb0Vk").
#    실제 apply에서는 null이지만 plan 모킹에서는 그 값을 볼 수 없다.
#
#    ⛔ mock_resource로 null을 강제해 통과시키지 않는다 — 그러면 assertion이 모듈이 아니라
#       **자기 자신의 모킹 설정**을 검증하게 된다. 통과하는 가짜 테스트는 없는 것보다 나쁘다.
#
#    일반화하면: "미지정"을 계약으로 삼는 항목은 plan 테스트로 지킬 수 없다.
#    이 둘의 회귀 방지는 코드 리뷰가 맡는다.
#       (공인 IP는 추가로 서브넷의 map_public_ip_on_launch에도 달려 있어 모듈 단독 판정이 애초에 불가능하다.)

# ── T-3 — kill switch ───────────────────────────────────────────────────────────
run "kill_switch_disables_everything" {
  command = plan

  variables {
    workbench_enabled = false
  }

  assert {
    condition     = length(aws_instance.this) == 0
    error_message = "workbench_enabled = false인데 인스턴스가 계획됐다."
  }

  assert {
    condition     = length(aws_security_group.this) == 0
    error_message = "workbench_enabled = false인데 SG가 계획됐다."
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.https) == 0
    error_message = "workbench_enabled = false인데 egress 규칙이 계획됐다."
  }

  assert {
    condition     = length(aws_iam_role.this) == 0 && length(aws_iam_instance_profile.this) == 0
    error_message = "workbench_enabled = false인데 IAM 리소스가 계획됐다."
  }

  assert {
    # 출력이 null이어야 소비 루트가 try() 없이 eks-cluster에 그대로 넘겨도 깨지지 않는다.
    condition     = output.workbench_instance_id == null && output.workbench_security_group_id == null && output.workbench_iam_role_arn == null
    error_message = "kill switch 상태에서 출력이 null이 아니다 — 소비 루트의 조립이 깨진다."
  }
}

# ── T-6 — EKS 연동 양성 (접근 1층) ──────────────────────────────────────────────
run "eks_integration_creates_scoped_policy" {
  command = plan

  variables {
    eks_cluster_name = "eks-demo-prd-an2-main-01"
    eks_cluster_arn  = "arn:aws:eks:ap-northeast-2:123456789012:cluster/eks-demo-prd-an2-main-01"
    kubectl_version  = "v1.35.7"
  }

  assert {
    condition     = length(aws_iam_role_policy.eks_describe) == 1
    error_message = "EKS 연동을 켰는데 인라인 정책이 계획되지 않았다."
  }

  assert {
    # 종속 객체 이름은 부모(role) 이름을 상속한다.
    condition     = aws_iam_role_policy.eks_describe[0].name == "iamr-demo-prd-an2-workbench-01-eks-policy"
    error_message = "인라인 정책 이름이 부모 role 이름을 상속하지 않았다: ${aws_iam_role_policy.eks_describe[0].name}"
  }

  assert {
    # 권한이 그 클러스터 ARN으로 한정되는 것이 1층의 핵심이다.
    #    Resource = "*"였다면 workbench가 계정의 모든 클러스터 kubeconfig를 만들 수 있다.
    condition     = strcontains(aws_iam_role_policy.eks_describe[0].policy, "arn:aws:eks:ap-northeast-2:123456789012:cluster/eks-demo-prd-an2-main-01")
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
    eks_cluster_name = "eks-demo-prd-an2-main-01"
    # eks_cluster_arn 없음 → kubeconfig는 만들어지는데 권한이 없다
  }

  expect_failures = [var.eks_cluster_arn]
}

run "reject_cluster_arn_without_name" {
  command = plan

  variables {
    eks_cluster_arn = "arn:aws:eks:ap-northeast-2:123456789012:cluster/eks-demo-prd-an2-main-01"
    # eks_cluster_name 없음 → 권한은 있는데 kubeconfig가 없다
  }

  expect_failures = [var.eks_cluster_arn]
}

# ── T-8 — kill switch × 가드 (파기 경로 보호) ─────────────────────────────────
#
# 가드에 `!var.workbench_enabled ||` 가 없으면 이 케이스가 **거부되고**, 그것은 곧
# "끌 수는 있으나 끈 상태를 유지할 수 없는" 반쪽 kill switch를 뜻한다.
run "guard_does_not_block_kill_switch" {
  command = plan

  variables {
    workbench_enabled = false
    eks_cluster_name  = "eks-demo-prd-an2-main-01"
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

# ── T-9 — git 은 변수 없이 항상 설치된다 ────────────────────────────────────────
#
# 이 테스트가 지키는 것은 "설치되는가"가 아니라 무조건성이다. git 에 변수를 다시 붙이거나
#    다른 도구 옆의 조건 분기 안으로 옮기면 여기서 깨진다 — 그 형태가 정확히 설계가 기각한 것이다.
# ⚠️ kubectl·helm 을 둘 다 null 로 둔 상태에서 본다. 기본값이 null 이라 이것이 최소 형상이고,
#    "다른 도구를 켜야 git 도 온다"는 결합이 생기면 이 케이스만 실패한다.
#
# plan 단계에서 `user_data` 는 원문 그대로 보인다 — `key_name` 처럼 모킹이 값을 지어내는
# 항목과 달라서, 아래 assertion 들이 템플릿 내용을 직접 검사할 수 있다.
run "git_always_installed" {
  command = plan

  variables {
    kubectl_version = null
    helm_version    = null
  }

  assert {
    condition     = strcontains(aws_instance.this[0].user_data, "dnf install -y git-core")
    error_message = "git-core 설치가 user_data 에 없다 — GitOps seam 의 클론이 성립하지 않는다."
  }
}

# ── T-10 — argocd CLI 는 nullable 핀이다 ────────────────────────────────────────
#
# git(T-9)과 정반대 계약이라 양성·음성을 둘 다 본다. argocd 는 버전이 chart appVersion 에
#    결합되므로 소비자가 고르는 값이고, 지정하지 않으면 **설치되지 않는 것이 계약**이다.
# ⚠️ 음성 케이스를 빼면 "항상 설치"로 바뀌어도 통과한다 — 그러면 T-9 와 구분되지 않는다.
run "argocd_cli_installed_when_pinned" {
  command = plan

  variables {
    argocd_version = "v3.5.0"
  }

  assert {
    # 버전을 URL 에 넣어 본다 — 단순 "argocd" 문자열은 주석에도 있어 통과가 무의미하다.
    condition     = strcontains(aws_instance.this[0].user_data, "releases/download/v3.5.0/argocd-linux-")
    error_message = "argocd_version 을 지정했는데 릴리스 URL 이 user_data 에 없다."
  }
}

# ── T-11 — 기본 인스턴스 타입은 dnf 가 살아남는 크기여야 한다 ──────────────────
#
# t4g.nano(0.5GB)에서 부팅 중 dnf 가
#    OOM-killer 에 죽어 git 이 설치되지 않았다 — T-9 는 통과했는데 실행이 실패했다.
# ⚠️ plan 테스트가 OOM 을 예측할 수는 없다. 여기서 지키는 것은 **그때 내린 결정이 조용히
#    되돌아가지 않는 것**뿐이다 — 비용을 줄이려고 기본값을 내리는 변경이 가장 그럴듯한 회귀다.
#    (비용은 instance_type 이 아니라 workbench_enabled 로 줄인다.)
run "default_instance_type_survives_dnf" {
  command = plan

  assert {
    condition     = aws_instance.this[0].instance_type == "t4g.small"
    error_message = "기본 instance_type 이 t4g.small 이 아니다 — 더 작은 타입은 부팅 중 dnf 가 OOM 으로 죽는다."
  }
}

run "argocd_cli_absent_by_default" {
  command = plan

  assert {
    # 기본값(null)에서 다운로드 URL 이 나오면 "미설치가 기본"이라는 계약이 깨진 것이다.
    condition     = !strcontains(aws_instance.this[0].user_data, "releases/download/")
    error_message = "argocd_version 이 null 인데 argocd 다운로드가 계획됐다 — 기본값 계약 위반."
  }
}

# ── T-12 — kubeconfig 배포 방식 ─────────────────────────────────────────────────
#
# 정본이 0666(world-writable) 이 되어
#    있었고 기본 네임스페이스가 전역 오염돼 있었다. kubeconfig 는 `users[].user.exec` 로 임의
#    명령을 지정할 수 있어, world-writable 은 **로컬 권한 상승 경로**다.
# ⚠️ 여기서 지키는 것은 "kubeconfig 가 생기는가"가 아니다 — 그것은 T-6 이 이미 본다.
#    지키는 것은 두 가지이고, 둘 다 *"편의를 위해 되돌리기 쉬운"* 형태다:
#      ① 정본이 쓰기 가능해지지 않는 것(`0444` 를 지우면 조작이 잠깐 편해진다)
#      ② `ssm-user` 상속 경로가 사라지지 않는 것(`/etc/skel` — 그 사용자는 user_data 시점에
#         아직 존재하지 않는다 — SSM Agent 가 첫 세션에서 useradd 로 만든다)
#      ③ `/etc/profile.d` 전역 export 가 되살아나지 않는 것(그것이 있으면 KUBECONFIG 가
#         홈 사본보다 우선해 ①②가 통째로 무의미해진다)
run "kubeconfig_is_readonly_and_inherited" {
  command = plan

  variables {
    eks_cluster_name = "eks-demo-prd-an2-main-01"
    eks_cluster_arn  = "arn:aws:eks:ap-northeast-2:123456789012:cluster/eks-demo-prd-an2-main-01"
    kubectl_version  = "v1.35.7"
  }

  assert {
    condition     = strcontains(aws_instance.this[0].user_data, "chmod 0444 \"$KUBECONFIG_PATH\"")
    error_message = "정본 kubeconfig 를 읽기 전용으로 잠그지 않는다 — world-writable 이 되면 exec 자격증명 명령을 바꿔 심을 수 있다."
  }

  assert {
    condition     = strcontains(aws_instance.this[0].user_data, "/etc/skel/.kube/config")
    error_message = "skel 상속이 없다 — ssm-user 는 user_data 시점에 존재하지 않으므로 이 경로가 사라지면 그 사용자는 kubeconfig 를 못 받는다."
  }

  assert {
    # 음성: 공유 정본을 전역 KUBECONFIG 로 export 하면 홈 사본이 죽은 경로가 되고
    #       전역 오염이 재발한다.
    #
    # ⛔ 조건을 파일 이름(`/etc/profile.d/kubeconfig.sh`)이나 파일 생성 행위(`> /etc/profile.d/`)로
    #    잡지 말 것. 전자는 "이 파일을 만들지 않는다"는 주석에 걸리고, 후자는 alias·PATH·KREW_ROOT
    #    를 넣으려는 정당한 요구까지 막는다. 지목할 것은 위험 그 자체 — export 구문이다.
    #    자세한 규칙은 이 파일 아래 상자에 있다.
    condition     = !strcontains(aws_instance.this[0].user_data, "export KUBECONFIG=/etc/kubernetes")
    error_message = "공유 정본을 전역 KUBECONFIG 로 export 하고 있다 — 환경변수가 홈 사본보다 우선하므로 사용자별 사본이 무의미해진다."
  }
}

# ══════════════════════════════════════════════════════════════════════════════
# 규칙 — 음성 assertion 은 "이름"이 아니라 "행위"를 지목한다
#
# user_data 는 주석이 본문의 일부다. 어떤 것을 하지 않는다고 설명하는 주석은 그 이름을 반드시
# 포함하므로, 이름으로 음성 판정을 걸면 설명까지 걸린다. 넓게 잡으면 정당한 요구까지 막는다.
#
# 이 저장소에서 실제로 걸린 조건들:
#   `"/etc/profile.d/kubeconfig.sh"`  → "만들지 않는다" 주석이 걸림
#   `"> /etc/profile.d/"`             → 너무 넓어 alias·PATH 설정까지 막음
#   `"KREW_ROOT"`                     → "설정(alias·PATH·KREW_ROOT·…)" 주석이 걸림
#
# ⇒ 지목할 것은 **실행 구문**이다: `export KREW_ROOT=` · `export KUBECONFIG=/etc/kubernetes`.
#   설명문에는 등장하지 않고, 실제로 그 행위를 할 때만 등장한다.
# ══════════════════════════════════════════════════════════════════════════════

# ── T-13·T-14·T-15 — 진단 도구 + 로그인 프로파일 ────────────────────────────────
#
# 기존 3종(kubectl·helm·argocd)과 같은 nullable 핀 계약이라 양성·음성을 둘 다 본다.
#    음성이 없으면 "항상 설치"로 바뀌어도 통과해 T-9(git 의 무조건성)와 구분되지 않는다.
run "tooling_installed_when_pinned" {
  command = plan

  variables {
    kubectl_version         = "v1.35.7"
    eks_node_viewer_version = "v0.7.4"
    krew_version            = "v0.5.0"
  }

  assert {
    # ⚠️ 자산 이름이 `_Linux_<arch>` 다. 이 문자열이 깨지면 x86 에서 404 가 난다 —
    #    다른 도구를 복사해 `amd64` 로 쓰는 것이 가장 그럴듯한 회귀다.
    condition     = strcontains(aws_instance.this[0].user_data, "eks-node-viewer/releases/download/v0.7.4/eks-node-viewer_Linux_")
    error_message = "eks_node_viewer_version 을 지정했는데 릴리스 URL 이 user_data 에 없다."
  }

  assert {
    condition     = strcontains(aws_instance.this[0].user_data, "x86_64")
    error_message = "eks-node-viewer 의 x86 자산 이름 매핑(x86_64)이 없다 — amd64 로 쓰면 404 다."
  }

  assert {
    condition     = strcontains(aws_instance.this[0].user_data, "krew/releases/download/v0.5.0/krew-linux_")
    error_message = "krew_version 을 지정했는데 릴리스 URL 이 user_data 에 없다."
  }

  # T-14 — krew 는 시스템 설치다. 기본값($HOME/.krew)이면 root 홈에 갇힌다.
  assert {
    condition     = strcontains(aws_instance.this[0].user_data, "KREW_ROOT=/usr/local/krew")
    error_message = "KREW_ROOT 가 없다 — krew 기본값은 $HOME/.krew 라 user_data(root)에서 /root/.krew 에 갇힌다."
  }

  assert {
    # 기본 플러그인 세트가 실제로 렌더되는가(목록 변수가 템플릿까지 도달하는지).
    condition     = strcontains(aws_instance.this[0].user_data, "ctx ns neat rbac-tool view-secret whoami")
    error_message = "krew_plugins 기본값이 user_data 에 렌더되지 않았다."
  }

  # T-15 — 로그인 프로파일. 지키는 것은 alias 가 아니라 completion 로드다.
  assert {
    condition     = strcontains(aws_instance.this[0].user_data, "alias k=kubectl")
    error_message = "alias k 가 프로파일에 없다."
  }

  assert {
    # ⚠️ `complete -F <없는함수> k` 는 bash 가 에러 없이 받아들인다 ⇒ 이 줄을
    #    빼먹으면 "설정했는데 안 되는" 상태가 아무 신호 없이 남는다. 그래서 테스트가 지킨다.
    condition     = strcontains(aws_instance.this[0].user_data, "kubectl completion bash")
    error_message = "kubectl completion 로드가 없다 — __start_kubectl 이 정의되지 않아 complete 줄이 조용히 무용지물이 된다."
  }

  assert {
    # ⛔ 리전 하드코딩 금지 — 이 모듈은 리전 이식성이 계약이다(CLAUDE.md 재사용 자산 요건).
    #    mock provider 의 리전이 그대로 렌더되면 통과하고, 문자열을 박아 넣으면 그 값이 남는다.
    condition     = strcontains(aws_instance.this[0].user_data, "export AWS_DEFAULT_REGION=")
    error_message = "AWS_DEFAULT_REGION export 가 프로파일에 없다."
  }
}

run "tooling_absent_by_default" {
  command = plan

  variables {
    kubectl_version = "v1.35.7" # kubectl 은 있지만 진단 도구는 기본값(null)
  }

  assert {
    condition     = !strcontains(aws_instance.this[0].user_data, "eks-node-viewer")
    error_message = "eks_node_viewer_version 이 null 인데 설치가 계획됐다 — 기본값 계약 위반."
  }

  assert {
    # ⛔ `"KREW_ROOT"` 로 잡지 말 것 — 프로파일 블록의 주석이 그 이름을 쓴다.
    #    이름이 아니라 행위(`export KREW_ROOT=`)를 지목한다. 규칙은 위 상자가 소유한다.
    condition     = !strcontains(aws_instance.this[0].user_data, "export KREW_ROOT=")
    error_message = "krew_version 이 null 인데 krew 설정이 계획됐다 — 기본값 계약 위반."
  }
}

# krew 는 kubectl 없이는 의미가 없다 — 그 결합을 모듈(main.tf)이 접는다.
#    이 케이스가 없으면 "kubectl 없이 krew 만 깔린" 형상이 조용히 만들어진다.
run "krew_requires_kubectl" {
  command = plan

  variables {
    kubectl_version = null
    krew_version    = "v0.5.0"
  }

  assert {
    condition     = !strcontains(aws_instance.this[0].user_data, "export KREW_ROOT=")
    error_message = "kubectl 이 없는데 krew 가 계획됐다 — 플러그인을 실행할 kubectl 이 없다."
  }
}
