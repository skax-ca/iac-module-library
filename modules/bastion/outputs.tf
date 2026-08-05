# bastion 출력 계약 — 설계 docs/design/40-bastion.md §4.4
#
# ⭐ 아래 둘(security_group_id · iam_role_arn)이 D-BASTION-SEAM의 실물이다.
#    이 모듈은 EKS 접근 2·3층을 만들지 않고 **재료만 내보낸다** — 조립은 소비 루트가 하고,
#    그 형태는 examples/bastion-enterprise가 보여준다(설계 §5).
#
# ⚠️ bastion_enabled = false면 전부 null이다. 소비 루트가 try()나 조건식 없이 eks-cluster에
#    그대로 넘겨도 깨지지 않아야 kill switch가 양쪽을 함께 비운다(설계 §5.1 마지막 문단).

output "bastion_instance_id" {
  description = "SSM 접속 대상. `aws ssm start-session --target <id>` 에 그대로 쓴다."
  value       = one(aws_instance.this[*].id)
}

output "bastion_private_ip" {
  description = "도달성 진단용 private IP."
  value       = one(aws_instance.this[*].private_ip)
}

output "bastion_security_group_id" {
  description = <<-EOT
    bastion SG. **eks-cluster의 cluster SG 추가 규칙 소스로 넘긴다**(설계 §5, 3층).

    ⛔ 이 모듈은 그 규칙을 직접 만들지 않는다 — cluster SG의 rule 소유자를 쪼개면
    drift·충돌이 생긴다(03 §2.3).
  EOT
  value       = one(aws_security_group.this[*].id)
}

output "bastion_iam_role_arn" {
  description = <<-EOT
    bastion role ARN. **eks-cluster의 access_entries principal로 넘긴다**(설계 §5, 2층).

    ⛔ 이 모듈은 Access Entry를 직접 만들지 않는다 — eks-cluster가 이미 access_entries를
    노출하므로 두 번째 경로는 경쟁 SSOT가 된다.
  EOT
  value       = one(aws_iam_role.this[*].arn)
}

output "bastion_iam_role_name" {
  description = "bastion role 이름. 인스턴스 프로파일도 같은 이름이다(카탈로그 상속 규약)."
  value       = one(aws_iam_role.this[*].name)
}
