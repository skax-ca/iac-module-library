# VPC Flow Logs — 설계 docs/design/10-vpc-module.md §1.1 D11
#
# 재사용 자산이므로 보안 기본값을 켠 채 배포한다(flow_logs_enabled 기본 true).
# 대상은 CloudWatch Logs로 고정한다 — S3·Firehose는 버킷/스트림 소유권이 모듈 밖이라
# 얇은 모듈 원칙(01 §2.2)을 깨뜨린다. 수요 발생 시 flow_logs_destination_type 확장(마이너).
#
# KMS 키는 계정 전역 공유·보안 거버넌스 대상이라 모듈이 생성하지 않고 ARN을 주입받는다(03 §4).

locals {
  # D10 게이트를 함께 통과해야 한다 — vpc_enabled = false면 Flow Logs도 사라진다.
  flow_logs_enabled = local.enabled && var.flow_logs_enabled

  flow_logs_base_name = "${local.name_mid}-${var.purpose}-flowlog"
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = local.flow_logs_enabled ? 1 : 0

  # 경로형 이름과 Name 태그는 다른 축이다(02 §1.5 제약 리소스와 같은 취급) —
  # CloudWatch 경로 관례를 따르고, 네이밍 규약은 Name 태그가 담당한다.
  name              = "/aws/vpc/flow-log/${local.name_mid}-${var.purpose}"
  retention_in_days = var.flow_logs_retention_days

  # null이면 CloudWatch 기본 암호화(AWS 관리 키)로 동작한다.
  # ⚠️ 변수 참조로 두는 것이 D11의 측정 결과와 직결된다 — trivy가 값을 확정할 수 없어
  #    AVD-AWS-0017(LOW)을 검출하지 않으므로 .trivyignore 등재 없이 게이트를 통과한다.
  kms_key_id = var.flow_logs_kms_key_id

  tags = merge(var.tags, {
    Name = "cwlg-${local.flow_logs_base_name}"
  })
}

resource "aws_iam_role" "flow_logs" {
  count = local.flow_logs_enabled ? 1 : 0

  name = "iamr-${local.flow_logs_base_name}"

  # 공식 신뢰 정책(VPC 사용자 가이드 "IAM role for publishing flow logs to CloudWatch Logs").
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "iamr-${local.flow_logs_base_name}"
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  count = local.flow_logs_enabled ? 1 : 0

  # 카탈로그의 "종속 객체는 부모 이름을 상속한다" 규약 — inline policy는 role 없이 존재할 수 없으므로
  # 새 약어를 만들지 않고 role 이름 + "-policy"를 쓴다(설계 §1.3).
  # ⚠️ inline policy는 tags를 지원하지 않는다. 이 name이 곧 식별자다(제약 리소스).
  name = "iamr-${local.flow_logs_base_name}-policy"
  role = aws_iam_role.flow_logs[0].id

  # 공식 최소 권한 5종을 기준으로, 스트림 단위로 좁힐 수 있는 것만 로그 그룹 ARN에 한정했다.
  # ⚠️ CreateLogGroup·DescribeLogGroups는 목록/생성 API라 Resource를 좁히면 배달이 조용히
  #    실패할 수 있다. Flow Logs 배달 실패는 plan으로 검출되지 않으므로 공식 문서를 따른다.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
        ]
        Resource = "${aws_cloudwatch_log_group.flow_logs[0].arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DescribeLogGroups",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_flow_log" "this" {
  count = local.flow_logs_enabled ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  # vpc_id를 지정하면 traffic_type이 필수다(provider 문서).
  traffic_type = var.flow_logs_traffic_type

  # log_destination_type의 기본값이 cloud-watch-logs이므로 명시하지 않는다 —
  # 대상을 CloudWatch로 고정한 D11의 결정이 기본값과 일치한다.
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn    = aws_iam_role.flow_logs[0].arn

  # 약어 fl은 2026-07-30에 카탈로그에 신규 등재했다(AWS 실제 리소스 ID 접두사 fl-을 따름).
  # 로그 그룹·IAM 역할과 달리 -flowlog 접미사가 없다 — 리소스 자체가 곧 Flow Log이므로
  # 용도를 되풀이할 필요가 없다.
  tags = merge(var.tags, {
    Name = "fl-${local.name_mid}-${var.purpose}"
  })
}
