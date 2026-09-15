# 출력 계약이 실제로 소비되는지 보이는 곳.
# GitOps seam(design/21)과 부트스트랩 스크립트가 이 값들을 받는다. seam이 어떤 방식으로
# 재결정되든 필요한 것들이라, 여기 있는 목록이 곧 "모듈이 밖에 지는 의무"다.

output "cluster_name" {
  description = "EKS 클러스터 이름. VPC 디스커버리 태그·Karpenter discovery와 같은 값이다."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "클러스터 ARN. GitOps 클러스터 등록은 API URL이 아니라 ARN을 요구한다."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "kube-apiserver 엔드포인트. private 구성이므로 VPC 내부에서만 도달한다."
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  description = "OIDC 발급자 URL."
  value       = module.eks.cluster_oidc_issuer_url
}

output "node_security_group_id" {
  description = "노드 SG. Karpenter discovery 태그가 이 SG에 붙는다(subnet 절반은 VPC 모듈 소관)."
  value       = module.eks.node_security_group_id
}

# ── Karpenter (GitOps가 소비) ────────────────────────────────────────────────

output "karpenter_discovery_tag" {
  description = <<-EOT
    Karpenter discovery 태그. NodeClass의 subnetSelectorTerms·securityGroupSelectorTerms가 쓴다.
    이 예제는 **양쪽(subnet · SG)에 모두** 이 값을 붙였다. 한쪽만 붙으면 조용히 실패한다.
  EOT
  value       = module.eks.karpenter_discovery_tag
}

output "karpenter_node_iam_role_name" {
  description = "EC2NodeClass의 role 필드가 받는 값. ARN이 아니라 **이름**이다."
  value       = module.eks.karpenter_node_iam_role_name
}

output "karpenter_sqs_queue_name" {
  description = "스팟 중단·헬스 이벤트 큐 이름."
  value       = module.eks.karpenter_sqs_queue_name
}

# ── 컨트롤러 IAM  ─────────────────────────────────────────────────────

output "alb_controller_iam_role_arn" {
  description = "ALBC Pod Identity role ARN. GitOps helm values의 serviceAccount 애노테이션이 아니라, Pod Identity association으로 바인딩된다."
  value       = module.eks.alb_controller_iam_role_arn
}

output "external_dns_iam_role_arn" {
  description = "external-dns Pod Identity role ARN."
  value       = module.eks.external_dns_iam_role_arn
}

output "ebs_csi_iam_role_arn" {
  description = "EBS CSI Driver Pod Identity role ARN."
  value       = module.eks.ebs_csi_iam_role_arn
}

# ── 네트워킹 (custom networking 확인용) ──────────────────────────────────────

output "pod_subnet_ids" {
  description = "Pod ENI(ENIConfig)가 놓인 비라우팅 대역 서브넷. vpc-cni addon configuration에 AZ별로 매핑된다."
  value       = module.vpc.subnet_ids_by_group["pod-dup"]
}

# ── workbench (설계 40) ─────────────────────────────────────────────────────────

output "workbench_instance_id" {
  description = "SSM 접속 대상. `aws ssm start-session --target <id> --region <region>`"
  value       = module.workbench.workbench_instance_id
}

output "workbench_ssm_command" {
  description = "복사해서 바로 쓰는 접속 명령. 인바운드 규칙 0개로 셸에 진입한다."
  value       = "aws ssm start-session --target ${module.workbench.workbench_instance_id} --region ${var.aws_region}"
}
