# cross-account-trust-role 출력 계약
#
# ⚠️ enabled = false면 전부 null이다. 소비 루트가 try() 없이 eks-cluster의 access_entries에
#    그대로 넘겨도 깨지지 않아야 kill switch가 양쪽을 함께 비운다.
#
# 계약: docs/module-catalog.md

output "role_arn" {
  description = <<-EOT
    신뢰 Role ARN. 소비 루트가 eks-cluster의 access_entries principal_arn으로 넘긴다.

    ⛔ 이 모듈은 Access Entry를 직접 만들지 않는다. 모듈이 서로를 직접 참조하지 않는다는
    원칙에 따라 배포 루트에서만 연결한다.
  EOT
  value       = try(aws_iam_role.this[0].arn, null)
}

output "role_name" {
  description = "신뢰 Role 이름."
  value       = try(aws_iam_role.this[0].name, null)
}
