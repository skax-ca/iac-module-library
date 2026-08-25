# workbench 출력 계약
#
# EKS 접근은 3층이다: 1층 주체의 권한(iam.tf) · 2층 Access Entry · 3층 cluster SG ingress.
# 이 모듈은 1층만 만들고 2·3층에는 재료(security_group_id · iam_role_arn)만 내보낸다 —
# 조립은 소비 루트가 한다.
#
# ⚠️ workbench_enabled = false면 전부 null이다. 소비 루트가 try()나 조건식 없이 eks-cluster에
#    그대로 넘겨도 깨지지 않아야 kill switch가 양쪽을 함께 비운다.
#
# 계약: docs/module-catalog.md

output "workbench_instance_id" {
  description = "SSM 접속 대상. `aws ssm start-session --target <id>` 에 그대로 쓴다."
  value       = one(aws_instance.this[*].id)
}

output "workbench_private_ip" {
  description = "도달성 진단용 private IP."
  value       = one(aws_instance.this[*].private_ip)
}

output "workbench_security_group_id" {
  description = <<-EOT
    workbench SG. eks-cluster의 cluster SG 추가 규칙 소스로 넘긴다(접근 3층).

    ⛔ 이 모듈은 그 규칙을 직접 만들지 않는다 — cluster SG의 rule 소유자를 쪼개면
    drift와 충돌이 생긴다.
  EOT
  value       = one(aws_security_group.this[*].id)
}

output "workbench_iam_role_arn" {
  description = <<-EOT
    workbench role ARN. eks-cluster의 access_entries principal로 넘긴다(접근 2층).

    ⛔ 이 모듈은 Access Entry를 직접 만들지 않는다 — eks-cluster가 이미 access_entries를
    노출하므로 두 번째 경로는 경쟁 SSOT가 된다.
  EOT
  value       = one(aws_iam_role.this[*].arn)
}

output "workbench_iam_role_name" {
  description = "workbench role 이름. 인스턴스 프로파일도 같은 이름이다(카탈로그 상속 규약)."
  value       = one(aws_iam_role.this[*].name)
}
