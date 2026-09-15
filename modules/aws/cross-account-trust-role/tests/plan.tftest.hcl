# cross-account-trust-role 모듈 계약 검증
#
# ⚠️ 이 파일이 계약의 유일한 검출 지점이다. 교차변수 validation은 validate가 아니라 plan 시점에
#    평가되므로, examples를 validate까지만 도는 규약으로는 변수 가드가 전혀 잡히지 않는다.
#
# ⚠️ 이 repo는 배포하지 않는다. 실제 assume-role 동작 판정은 소비 repo 몫이다.
#    여기서 증명하는 것은 "계획이 계약대로 나오는가"까지다.
#
# provider 모킹: command = plan도 provider 초기화(리전 조회 등)를 실제로 시도한다. 이 repo는
# CI에 자격증명이 없으므로 모킹 없이는 plan이 죽는다. workbench와 같은 이유로 같은 블록을 쓴다.

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "ap-northeast-2"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
}

variables {
  naming = {
    workload    = "spoke1"
    env         = "prd"
    region_code = "an2"
  }

  purpose                = "argocd-hub"
  trusted_principal_arns = ["arn:aws:iam::999988887777:role/iamr-hub-prd-an2-argocd-hub"]
}

# ── naming_contract: Name 태그 규약 ────────────────────────────────────────
#
# CLAUDE.md 「강제 방식 5」: Name 태그 assertion을 tftest에 포함해 plan 단계에서 네이밍 위반을 잡는다.
# 약어는 카탈로그 SSOT를 따른다: iamr.
run "naming_contract" {
  command = plan

  assert {
    condition     = aws_iam_role.this[0].name == "iamr-spoke1-prd-an2-argocd-hub"
    error_message = "IAM role 이름이 규약과 다르다: ${aws_iam_role.this[0].name}"
  }

  assert {
    condition     = aws_iam_role.this[0].tags["Name"] == "iamr-spoke1-prd-an2-argocd-hub"
    error_message = "IAM role Name 태그가 규약과 다르다: ${aws_iam_role.this[0].tags["Name"]}"
  }

  assert {
    condition     = aws_iam_role.this[0].max_session_duration == 3600
    error_message = "기본 session_duration_seconds가 max_session_duration에 반영되지 않았다."
  }
}

# ── kill_switch: enabled = false면 전 리소스·출력이 비어야 한다 ──────────────
run "kill_switch_disables_everything" {
  command = plan

  variables {
    enabled                = false
    trusted_principal_arns = []
  }

  assert {
    condition     = length(aws_iam_role.this) == 0
    error_message = "enabled = false인데 IAM role이 계획됐다."
  }

  assert {
    condition     = output.role_arn == null && output.role_name == null
    error_message = "kill switch 상태에서 출력이 null이 아니다. 소비 루트의 조립이 깨진다."
  }
}

# ── nullable = false 계약: 명시적 null이 crash 대신 default로 대체된다 ─────────
# tags는 merge(var.tags, {...})에 쓰이므로 null이면 "argument must not be null"로
# 죽는 게 nullable 없는 상태의 실제 실패 모드였다(docs/decisions.md 「변수 계약 (nullable)」 참조).
run "nullable_false_falls_back_to_default" {
  command = plan

  variables {
    tags                     = null
    enabled                  = null
    session_duration_seconds = null
  }

  assert {
    condition     = length([for k, v in aws_iam_role.this[0].tags : k if k != "Name"]) == 0
    error_message = "tags = null이 default {}로 대체되지 않아 Name 외 태그가 남아 있다."
  }

  assert {
    condition     = aws_iam_role.this[0].max_session_duration == 3600
    error_message = "session_duration_seconds = null이 default 3600으로 대체되지 않았다."
  }

  assert {
    condition     = length(aws_iam_role.this) == 1
    error_message = "enabled = null이 default true로 대체되지 않았다."
  }
}

# ── reject_root_arn: 계정 root 위임 금지 ────────────────────────────────────
run "reject_root_arn" {
  command = plan

  variables {
    trusted_principal_arns = ["arn:aws:iam::123456789012:root"]
  }

  expect_failures = [var.trusted_principal_arns]
}

# ── reject_wildcard_arn: 와일드카드 경로 금지 ───────────────────────────────
run "reject_wildcard_arn" {
  command = plan

  variables {
    trusted_principal_arns = ["arn:aws:iam::123456789012:role/apps/*"]
  }

  expect_failures = [var.trusted_principal_arns]
}

# ── reject_empty_when_enabled: enabled = true인데 빈 리스트는 무의미 ─────────
run "reject_empty_when_enabled" {
  command = plan

  variables {
    trusted_principal_arns = []
  }

  expect_failures = [var.trusted_principal_arns]
}
