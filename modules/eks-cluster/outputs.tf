# 출력 계약
#
# 계약: docs/module-index.md
#
# 규약:
#   · 소비자가 의존하는 출력 이름은 **메이저 버전 내에서 안정**하다. 이름 변경은 메이저다.
#   · kill switch·opt-out 시 **null**을 돌려준다(에러가 아니라). cluster_enabled = false 인 루트에서도
#     `tofu output`이 성립해야 소비자가 조건 분기를 짜지 않는다.
#
# ⚠️ upstream 출력의 fallback이 일관되지 않다:
#    대부분 try(…, null) 인데 **cluster_name·cluster_id 만 try(…, "")** 로 빈 문자열을 돌려준다.
#    여기서 null로 정규화하는 이유는 그것이 facade의 일이기 때문이다 — 정규화하지 않으면 소비자가
#    `X == null`이 아니라 `X == ""`를 알아야 하고, 그건 upstream 구현 디테일이 우리 계약으로 새는 것이다.

locals {
  # 빈 문자열을 null로 접는다. 다른 출력과 같은 규약을 갖게 하는 것이 목적이다.
  cluster_name_out = local.enabled && module.eks.cluster_name != "" ? module.eks.cluster_name : null
}

# ── 클러스터 정체성 ──────────────────────────────────────────────────────────

output "cluster_name" {
  description = "EKS 클러스터 이름. 소비자가 VPC 모듈의 eks_cluster_name·Karpenter discovery 태그와 맞출 값이다."
  value       = local.cluster_name_out
}

output "cluster_arn" {
  description = <<-EOT
    EKS 클러스터 ARN.
    GitOps 쪽 클러스터 등록이 API URL이 아니라 **ARN**을 요구하므로 계약에 둔다 —
    부트스트랩 seam이 어떻게 재결정되든(design/21) ARN은 어느 경로에서도 필요하다.
  EOT
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "kube-apiserver 엔드포인트 URL."
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "실제로 기동된 컨트롤플레인 k8s 버전. 입력 kubernetes_version과 대조해 승격 여부를 확인한다."
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "kubeconfig의 certificate-authority-data(base64)."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "OIDC 발급자 URL."
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "IAM OIDC 공급자 ARN. IRSA 방식 role의 신뢰 정책이 참조한다(Pod Identity를 쓰면 불필요)."
  value       = module.eks.oidc_provider_arn
}

# ── 보안 그룹 ────────────────────────────────────────────────────────────────

output "cluster_security_group_id" {
  description = <<-EOT
    **upstream 모듈이 만든** cluster SG ID. vpc_config.security_group_ids 로 클러스터에 붙어
    apiserver ENI 에 적용된다 — cluster_security_group_additional_rules 가 규칙을 붙이는 대상이다.

    ⚠️ **EKS 서비스가 자동 생성하는 primary cluster SG 와 다르다**(그쪽은 upstream 출력
    `cluster_primary_security_group_id` 이며 이 모듈은 노출하지 않는다).
    ⛔ 이것을 "EKS가 만든 클러스터 보안 그룹"이라고 부르지 말 것 — primary SG 와 구분되지 않아
       workbench 규칙을 어디에 붙일지 판단할 때 오도한다.
  EOT
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = <<-EOT
    노드 보안 그룹 ID. Karpenter의 securityGroupSelectorTerms가 이 SG의 discovery 태그를 찾는다.
    custom networking의 Pod ENI도 이 SG를 상속한다(addons.tf 주석 참조).
  EOT
  value       = module.eks.node_security_group_id
}

# ── Karpenter (GitOps가 소비) ────────────────────────────────────────────────
#
# enable_karpenter = false 또는 kill switch면 전부 null이다.

output "karpenter_iam_role_arn" {
  description = "Karpenter 컨트롤러 role ARN."
  value       = try(module.karpenter.iam_role_arn, null)
}

output "karpenter_node_iam_role_arn" {
  description = "Karpenter가 프로비저닝하는 노드의 IAM role ARN."
  value       = try(module.karpenter.node_iam_role_arn, null)
}

output "karpenter_node_iam_role_name" {
  description = "Karpenter 노드 IAM role 이름. EC2NodeClass의 role 필드가 ARN이 아니라 이름을 받는다."
  value       = try(module.karpenter.node_iam_role_name, null)
}

output "karpenter_instance_profile_name" {
  description = "Karpenter 노드 instance profile 이름."
  value       = try(module.karpenter.instance_profile_name, null)
}

output "karpenter_sqs_queue_name" {
  description = "스팟 중단·헬스 이벤트를 받는 SQS 큐 이름."
  value       = try(module.karpenter.queue_name, null)
}

output "karpenter_discovery_tag" {
  description = <<-EOT
    Karpenter discovery 태그(맵). NodeClass의 subnetSelectorTerms·securityGroupSelectorTerms가
    이 값으로 인프라를 찾는다.

    ⚠️ 소비자는 **같은 값을 VPC 모듈의 노드 서브넷 그룹 extra_tags에도** 넣어야 한다.
    SG 쪽은 이 모듈이 붙이지만 subnet 쪽은 VPC 모듈 소관이라, 한쪽만 붙으면
    selector가 빈 결과를 내고 프로비저닝이 실패한다(PoC의 실제 사고).
  EOT
  value = local.cluster_name_out == null ? null : {
    "karpenter.sh/discovery" = local.cluster_name_out
  }
}

# ── Cluster Autoscaler (GitOps가 소비) ───────────────────────────────────────
#
# enable_cluster_autoscaler = false 또는 kill switch면 null이다.

output "cluster_autoscaler_iam_role_arn" {
  description = <<-EOT
    Cluster Autoscaler Pod Identity role ARN. GitOps helm values의 서비스 어카운트 annotation이
    아니라 Pod Identity association으로 이미 바인딩되어 있다(namespace=kube-system,
    service_account=cluster-autoscaler — 이 모듈이 고정한다).
  EOT
  value       = try(module.cluster_autoscaler_pod_identity.iam_role_arn, null)
}

# ── addon  ─────────────────────────────────────────────────────────────

output "effective_addon_names" {
  description = <<-EOT
    최종적으로 설치되는 addon 이름 목록(baseline merge + enabled 필터 결과).

    소비자가 "내가 넘긴 cluster_addons가 baseline과 어떻게 합쳐졌는가"를 확인하는 지점이다 —
    merge 규약(누락 != 삭제)은 코드를 읽지 않으면 결과를 예측하기 어렵기 때문이다.

    ⚠️ 이 출력은 **계약 검증의 관측점이기도 하다**. facade 모듈은 계산 결과를 하위 모듈의
    입력으로 넘기는데 `tofu test`는 하위 모듈에 들어간 값을 볼 수 없다 — 노출하지 않으면
    baseline 상속·opt-out 동작을 config-time에 검증할 방법이 없다.
  EOT
  value       = local.enabled ? sort(keys(local.addons_final)) : []
}

# ── 컨트롤러 IAM ─────────────────────────────────────────────────────────────

output "ebs_csi_iam_role_arn" {
  description = "EBS CSI Driver의 Pod Identity role ARN. opt-in addon이라 cluster_addons에 aws-ebs-csi-driver를 명시하지 않으면 null이다."
  value       = try(aws_iam_role.ebs_csi[0].arn, null)
}

output "efs_csi_iam_role_arn" {
  description = "EFS CSI Driver의 Pod Identity role ARN. opt-in addon이라 cluster_addons에 aws-efs-csi-driver를 명시하지 않으면 null이다."
  value       = try(aws_iam_role.efs_csi[0].arn, null)
}

output "alb_controller_iam_role_arn" {
  description = <<-EOT
    AWS Load Balancer Controller의 Pod Identity role ARN(enable_alb_controller_iam = true일 때).
    ALBC 자체는 GitOps helm으로 설치되므로, GitOps 저장소가 이 값을 참조한다.
  EOT
  value       = try(module.alb_controller_pod_identity.iam_role_arn, null)
}

output "external_dns_iam_role_arn" {
  description = "external-dns의 Pod Identity role ARN(enable_external_dns_iam = true일 때)."
  value       = try(module.external_dns_pod_identity.iam_role_arn, null)
}

output "argocd_hub_iam_role_arn" {
  description = <<-EOT
    허브 ArgoCD(argocd-application-controller)의 Pod Identity role ARN
    (enable_argocd_hub_pod_identity = true일 때). 이 Role은 스포크 계정의 크로스 계정
    신뢰 Role(cross-account-trust-role 모듈 소유)을 assume한다.
  EOT
  value       = try(module.argocd_hub_pod_identity.iam_role_arn, null)
}
