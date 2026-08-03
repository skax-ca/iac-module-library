# 예제 출력 — 모듈 계약이 실제로 무엇을 돌려주는지 보인다.
# 소비 프로젝트는 이 값들을 GitOps seam·부트스트랩 스크립트에 넘긴다.

output "cluster_name" {
  description = "EKS 클러스터 이름."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "kube-apiserver 엔드포인트."
  value       = module.eks.cluster_endpoint
}

output "cluster_arn" {
  description = "클러스터 ARN. GitOps 클러스터 등록이 URL이 아니라 ARN을 요구한다."
  value       = module.eks.cluster_arn
}

output "karpenter_discovery_tag" {
  description = <<-EOT
    Karpenter discovery 태그.
    ⚠️ 이 예제는 Karpenter IAM만 만들고 subnet 쪽 태그는 붙이지 않았다(최소 형상).
    실제로 Karpenter를 쓰려면 VPC 모듈의 노드 서브넷 그룹 extra_tags에 이 값을 넣어야 한다 —
    enterprise 예제가 그 형태를 보인다.
  EOT
  value       = module.eks.karpenter_discovery_tag
}

output "ebs_csi_iam_role_arn" {
  description = "EBS CSI Driver Pod Identity role ARN(baseline addon이므로 기본 생성)."
  value       = module.eks.ebs_csi_iam_role_arn
}
