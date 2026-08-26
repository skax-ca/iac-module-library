# eks-cluster

EKS 클러스터 · 노드그룹 · addon · IAM. 커뮤니티 모듈(`terraform-aws-modules/eks`)을 감싼 facade다.

## Usage

```hcl
module "eks" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/aws/eks-cluster?ref=eks-cluster-vX.Y.Z"

  naming     = { workload = "demo", env = "dev", region_code = "an2" }
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.subnet_ids_by_group["node-uniq"]
}
```

`vX.Y.Z`는 자리표시자다. 실제 최신 태그는 `git tag -l 'eks-cluster-v*'`로 확인한다. custom
networking·Karpenter·workbench 연동을 포함한 실전 예시는
[`examples/enterprise/README.md`](examples/enterprise/README.md)를 참조한다.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.57.1 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_alb_controller_pod_identity"></a> [alb\_controller\_pod\_identity](#module\_alb\_controller\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.8.2 |
| <a name="module_argocd_hub_pod_identity"></a> [argocd\_hub\_pod\_identity](#module\_argocd\_hub\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.8.2 |
| <a name="module_cluster_autoscaler_pod_identity"></a> [cluster\_autoscaler\_pod\_identity](#module\_cluster\_autoscaler\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.8.2 |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 21.24.1 |
| <a name="module_external_dns_pod_identity"></a> [external\_dns\_pod\_identity](#module\_external\_dns\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.8.2 |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | terraform-aws-modules/eks/aws//modules/karpenter | 21.24.1 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_autoscaling_group_tag.cluster_autoscaler_node_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group_tag) | resource |
| [aws_iam_role.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.efs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.efs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.ebs_csi_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.efs_csi_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_subnet.pod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_access_entries"></a> [access\_entries](#input\_access\_entries) | EKS Access Entry 정의(aws-auth ConfigMap 대체). upstream 스키마를 그대로 통과시킨다.<br/><br/>⚠️ 이 변수는 type = any 다. upstream이 필드를 자주 늘리는 영역이라 facade가 구조를 복제하면<br/>upstream 변경마다 이 모듈이 막는 문지기가 된다. 계약 안정성보다 통과가 나은 드문 경우다. | `any` | `{}` | no |
| <a name="input_argocd_hub_assumable_role_arns"></a> [argocd\_hub\_assumable\_role\_arns](#input\_argocd\_hub\_assumable\_role\_arns) | 이 허브가 assume할 수 있는 스포크 크로스 계정 신뢰 Role ARN 목록.<br/>스포크가 늘 때마다 이 목록에 추가한다(현재는 수동 갱신).<br/><br/>⛔ enable\_argocd\_hub\_pod\_identity = true면 비워 둘 수 없다.<br/>sts:AssumeRole은 리소스 수준 권한을 요구하는 액션이라 Resource = "*" 정책을<br/>IAM이 거부한다(400 MalformedPolicyDocument) — external\_dns\_hosted\_zone\_arns와 같은 이유다. | `list(string)` | `[]` | no |
| <a name="input_argocd_namespace"></a> [argocd\_namespace](#input\_argocd\_namespace) | 허브 ArgoCD가 설치된 네임스페이스. Pod Identity association의 namespace로 쓰인다.<br/>⚠️ argocd-seed.sh(`eks-reference-infra`)의 ARGOCD\_NAMESPACE와 반드시 일치해야 한다 — 어긋나면<br/>association이 실제 Pod의 서비스 어카운트와 매칭되지 않아 자격증명을 받지 못한다. | `string` | `"argocd"` | no |
| <a name="input_cluster_addons"></a> [cluster\_addons](#input\_cluster\_addons) | baseline addon(addons.tf)에 병합할 증분·override.<br/><br/>빈 맵이면 baseline을 그대로 상속한다. 소비자 입력은 baseline과 merge되므로 **누락 != 삭제**다<br/>(맵을 통째로 대체하면 coredns 삭제 = DNS 중단이 되는 문제를 막는다).<br/>제거는 enabled = false 명시로만 한다 — 암묵 규약을 두지 않는다.<br/><br/>⚠️ core 4종(vpc-cni · coredns · kube-proxy · eks-pod-identity-agent)은 비활성화할 수 없다.<br/>eks-pod-identity-agent가 core인 이유는 Karpenter·EBS CSI의 association 생존 전제이기 때문이다 —<br/>없으면 IAM에는 role이 있는데 Pod가 자격증명을 못 받는 조용한 파손이 된다. | <pre>map(object({<br/>    enabled       = optional(bool, true)<br/>    addon_version = optional(string)<br/>    configuration = optional(string)<br/>    pod_identity = optional(object({<br/>      role_arn        = string<br/>      service_account = string<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_cluster_enabled"></a> [cluster\_enabled](#input\_cluster\_enabled) | kill switch(파괴 방향). false면 이 모듈의 전 리소스를 파기하고 data source 조회까지 건너뛴다.<br/>참조 대상이 사라진 뒤에도 plan이 통과해야 파기가 가능하기 때문이다.<br/>false일 때 스칼라 출력은 null, map/list 출력은 빈 값이 된다.<br/><br/>구현은 upstream `create` 토글에 위임한다 — upstream이 자체 data source까지<br/>게이트하므로 요건이 이미 충족된다. | `bool` | `true` | no |
| <a name="input_cluster_security_group_additional_rules"></a> [cluster\_security\_group\_additional\_rules](#input\_cluster\_security\_group\_additional\_rules) | cluster SG에 추가할 규칙. EKS 접근 3층의 소유 지점이다.<br/><br/>    "클러스터가 누구를 네트워크로 받아들이는가"는 클러스터 쪽 결정이므로 이 모듈이 소유한다 —<br/>소유 모듈이 허용 소스 목록을 변수로 열고 rule 도 스스로 만든다.<br/>    외부 모듈이 이 SG에 직접 rule을 붙이면 소유자가 쪼개져 drift 와 충돌이 생긴다.<br/><br/>    upstream 스키마를 그대로 통과시킨다(access\_entries와 같은 판단):<br/>      { <키> = { from\_port, to\_port, protocol = "tcp", type = "ingress",<br/>                 description, source\_security\_group\_id \| cidr\_blocks \| source\_node\_security\_group } }<br/><br/>    예 — workbench 에서 apiserver 443:<br/>      { workbench = { from\_port = 443, to\_port = 443, description = "kubectl from workbench",<br/>                    source\_security\_group\_id = module.workbench.workbench\_security\_group\_id } }<br/><br/>    ⚠️ 이 규칙이 붙는 SG는 **upstream이 만든 cluster SG**이며 EKS가 자동 생성하는<br/>       primary cluster SG와 다르다. 전자가 vpc\_config.security\_group\_ids 로 클러스터에 붙어<br/>       apiserver ENI 에 적용되므로 도달 경로로 성립한다(outputs.tf의 경고 참조).<br/><br/>    ⚠️ upstream 은 이 규칙을 구형 `aws_security_group_rule` 로 만든다 — 우리 규약이 신규 코드에서<br/>       금지한 리소스지만 upstream 내부라 통제 밖이다. 같은 SG 에 우리가 신형 rule 을<br/>       직접 붙이지 않는 이유이기도 하다. | `any` | `{}` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | 삭제 보호(보호 방향). true면 aws\_eks\_cluster의 네이티브 deletion\_protection이<br/>켜져 클러스터를 지울 수 없다.<br/><br/>⚠️ vpc 모듈의 prevent\_destroy와 메커니즘이 다르다. 이쪽이 더 강하다 —<br/>prevent\_destroy는 IaC 차원이라 콘솔·CLI 삭제를 막지 못하지만 이것은 AWS API 차원이다.<br/>vpc가 prevent\_destroy를 쓴 것은 VPC에 네이티브 보호가 없어서지 그 방식이 우월해서가 아니다.<br/><br/>보호를 켠 상태의 teardown은 2단계다 — deletion\_protection = false로 apply한 뒤<br/>cluster\_enabled = false. 이는 결함이 아니라 보호의 정의다.<br/>기본값이 false인 이유: teardown 보장이 기본 동작이어야 한다. 보호는 opt-in이다. | `bool` | `false` | no |
| <a name="input_enable_alb_controller_iam"></a> [enable\_alb\_controller\_iam](#input\_enable\_alb\_controller\_iam) | AWS Load Balancer Controller용 Pod Identity role 생성 여부.<br/>ALBC 자체는 community addon이 없어 GitOps helm으로 설치되지만, IAM 전제는 IaC 소관이다.<br/>기본 false인 이유는 유휴 role과 불필요한 diff를 만들지 않기 위해서다 — 소비자 opt-in. | `bool` | `false` | no |
| <a name="input_enable_argocd_hub_pod_identity"></a> [enable\_argocd\_hub\_pod\_identity](#input\_enable\_argocd\_hub\_pod\_identity) | 허브 ArgoCD(argocd-application-controller)가 스포크 계정의 크로스 계정 신뢰 Role을<br/>assume할 수 있는 Pod Identity role 생성 여부.<br/>기본 false인 이유는 유휴 role과 불필요한 diff를 만들지 않기 위해서다 — 소비자 opt-in. | `bool` | `false` | no |
| <a name="input_enable_cluster_autoscaler"></a> [enable\_cluster\_autoscaler](#input\_enable\_cluster\_autoscaler) | Cluster Autoscaler IAM 전제조건(Pod Identity role · least-privilege 정책 · scale-from-zero용<br/>ASG node-template 태그) 생성 여부. helm 설치는 GitOps 소관.<br/><br/>true면 managed\_node\_groups의 각 ASG에 k8s.io/cluster-autoscaler/node-template/label/* ·<br/>.../taint/* 태그가 붙는다(labels·taints 입력을 그대로 미러링). auto-discovery 태그<br/>(k8s.io/cluster-autoscaler/enabled 등)는 EKS가 관리형 노드그룹 생성 시 자동으로 붙이므로<br/>이 모듈이 별도로 만들지 않는다.<br/><br/>Karpenter와 동시에 켤 수 있다 — 서로 다른 리소스를 다룬다(Karpenter=EC2 직접 프로비저닝,<br/>CA=managed\_node\_groups의 ASG). 상호 배제하지 않는다. 단, 워크로드를 taint로 분리하지 않으면<br/>같은 pending pod에 두 컨트롤러가 동시에 반응해 중복 프로비저닝이 발생할 수 있다<br/>(근거: karpenter.sh FAQ, aws/karpenter-provider-aws#2543). | `bool` | `false` | no |
| <a name="input_enable_custom_networking"></a> [enable\_custom\_networking](#input\_enable\_custom\_networking) | vpc-cni custom networking 활성화 여부. true면 Pod ENI가 pod\_subnet\_ids의<br/>비라우팅 대역에 배치되고, 노드는 subnet\_ids의 unique 대역 IP로 SNAT된다.<br/>구성은 vpc-cni addon의 configuration\_values로 선언되므로 helm/manifest 경계를 넘지 않는다. | `bool` | `true` | no |
| <a name="input_enable_external_dns_iam"></a> [enable\_external\_dns\_iam](#input\_enable\_external\_dns\_iam) | external-dns용 Pod Identity role 생성 여부.<br/>external-dns는 community addon으로 설치되지만 custom 정책이 필요해 eks-pod-identity에 위임한다. | `bool` | `false` | no |
| <a name="input_enable_karpenter"></a> [enable\_karpenter](#input\_enable\_karpenter) | Karpenter IAM 전제조건(컨트롤러 role · 노드 role · instance profile · 중단 SQS) 생성 여부.<br/>helm 설치와 NodePool/NodeClass는 GitOps 소관이다.<br/><br/>true면 node 보안그룹에 karpenter.sh/discovery 태그도 함께 부여된다 — NodeClass의<br/>securityGroupSelectorTerms가 이 태그로 SG를 찾는다. | `bool` | `true` | no |
| <a name="input_enabled_log_types"></a> [enabled\_log\_types](#input\_enabled\_log\_types) | 컨트롤플레인 로깅 대상. 유효값: api · audit · authenticator · controllerManager · scheduler.<br/><br/>기본값이 빈 리스트인 이유는 CloudWatch 비용이다. 다만 **보류를 재사용 자산의 기본값으로<br/>승계하지 않는다** — 소비자가 켤 수 있게 노출하는 것이 이 모듈의 책임이고,<br/>켤지 말지는 환경 프로파일의 판단이다(prd 권장). trivy AVD-AWS-0038이 지적하는 항목이다. | `list(string)` | `[]` | no |
| <a name="input_endpoint_private_access"></a> [endpoint\_private\_access](#input\_endpoint\_private\_access) | kube-apiserver private 엔드포인트 활성화 여부. | `bool` | `true` | no |
| <a name="input_endpoint_public_access"></a> [endpoint\_public\_access](#input\_endpoint\_public\_access) | kube-apiserver public 엔드포인트 활성화 여부. GitOps(pull) 전제이므로 기본은 private이다. | `bool` | `false` | no |
| <a name="input_external_dns_hosted_zone_arns"></a> [external\_dns\_hosted\_zone\_arns](#input\_external\_dns\_hosted\_zone\_arns) | external-dns 정책을 제한할 Route53 hosted zone ARN 목록.<br/><br/>⛔ enable\_external\_dns\_iam = true면 비워 둘 수 없다.<br/>route53:ChangeResourceRecordSets는 리소스 수준 권한을 요구하는 액션이라 Resource = "*"<br/>정책을 IAM이 거부한다(400 MalformedPolicyDocument). upstream은 이 목록이 비면 정확히<br/>그 정책을 만든다 — 즉 이것은 prd 권고가 아니라 **모든 환경의 apply 차단 조건**이다. | `list(string)` | `[]` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | 컨트롤플레인 k8s 마이너 버전. N-1 전략을 기본값으로 둔다.<br/>    ⚠️ 이 목록은 낡는다. EKS standard support 창은 계속 이동하므로 올리기 전에 확인한다.<br/><br/>    ⚠️ **cluster\_addons로 addon 버전을 고정해 뒀다면 이 값을 올릴 때 그 버전들도 함께 갱신한다**<br/>. addon 버전은 f(kubernetes\_version, region)이라 k8s만 올리면<br/>    "그 버전 없음"으로 apply가 죽는다. 특히 kube-proxy는 정의상 k8s 마이너를 따라간다.<br/>    ⚠️ 버전을 안 고정했다면 upstream이 이 값에 맞는 AWS 기본 버전을 해석하므로 할 일이 없다. | `string` | `"1.35"` | no |
| <a name="input_managed_node_groups"></a> [managed\_node\_groups](#input\_managed\_node\_groups) | managed 노드그룹 정의. 맵 키가 노드그룹 이름 토큰이 된다.<br/><br/>ami\_release\_version: 지정하면 그 AMI로 고정한다. null이면 최신 해석(하위호환).<br/>⚠️ upstream 서브모듈은 use\_latest\_ami\_release\_version 기본이 true라 ami\_release\_version만<br/>주면 무시된다. 이 모듈이 use\_latest = (ami\_release\_version == null)로 파생해 핀을 실효화한다.<br/><br/>ami\_type: 노드 AMI 계열이자 **CPU 아키텍처의 결정 지점**이다.<br/>⚠️ **instance\_types와 아키텍처가 반드시 일치해야 한다.** graviton(t4g·m7g·c7g…)을 쓰려면<br/>ami\_type = "AL2023\_ARM\_64\_STANDARD"를 함께 지정한다 — 기본값이 x86이라 arm 인스턴스만 바꾸면<br/>**AMI와 CPU가 어긋나 노드가 부팅되지 않는다.** 이 조합은 plan에서 잡히지 않는다(AWS도 nodegroup<br/>생성 시점에야 실패한다) → 아키텍처 짝은 소비자가 맞춘다.<br/>⚠️ ami\_release\_version도 **아키텍처별로 값이 다르다.** arm으로 바꾸면 핀도 arm SSM 경로에서<br/>다시 얻는다(README "AMI 버전 고정" 절).<br/><br/>taints는 리스트로 받아 모듈이 upstream의 map 스키마로 변환한다(facade 번역). | <pre>map(object({<br/>    instance_types      = list(string)<br/>    min_size            = number<br/>    max_size            = number<br/>    desired_size        = number<br/>    capacity_type       = optional(string, "ON_DEMAND")<br/>    ami_type            = optional(string, "AL2023_x86_64_STANDARD")<br/>    ami_release_version = optional(string)<br/>    labels              = optional(map(string), {})<br/>    taints = optional(list(object({<br/>      key    = string<br/>      value  = optional(string)<br/>      effect = string<br/>    })), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_naming"></a> [naming](#input\_naming) | Name 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로<br/>소비자는 약어를 직접 타이핑하지 않는다.<br/>예: {workload = "demo", env = "prd", region\_code = "an2"} → eks-demo-prd-an2-main-01 | <pre>object({<br/>    workload    = string<br/>    env         = string<br/>    region_code = string<br/>  })</pre> | n/a | yes |
| <a name="input_pod_subnet_ids"></a> [pod\_subnet\_ids](#input\_pod\_subnet\_ids) | Pod ENI(ENIConfig)가 놓일 서브넷 ID 목록. enable\_custom\_networking = true일 때만 쓰인다.<br/>AZ 매핑은 모듈이 data.aws\_subnet으로 해석하므로 입력은 ID 리스트로 단순하게 유지한다. | `list(string)` | `[]` | no |
| <a name="input_public_access_cidrs"></a> [public\_access\_cidrs](#input\_public\_access\_cidrs) | public 엔드포인트 접근을 허용할 CIDR 목록.<br/>⚠️ 빈 리스트를 넘기면 EKS가 0.0.0.0/0으로 기본 적용한다 — public을 켤 때는 반드시 좁힌다.<br/><br/>ℹ️ **endpoint\_public\_access = false면 이 값은 무시된다** — 모듈이 upstream에 null을 넘기기<br/>때문이다(main.tf 참조). 값을 지워도 AWS는 직전 값을 계속 반환하지만<br/>plan에는 나타나지 않는다. 그래서 public을 끌 때 이 변수를 비우지 않아도 무해하다. | `list(string)` | `[]` | no |
| <a name="input_purpose"></a> [purpose](#input\_purpose) | 클러스터 이름의 purpose 토큰. | `string` | `"main"` | no |
| <a name="input_serial"></a> [serial](#input\_serial) | 클러스터 이름의 일련번호 토큰. | `string` | `"01"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | 노드·컨트롤플레인 ENI가 놓일 서브넷 ID 목록.<br/><br/>⚠️ 그룹 키 이름을 가정하지 않고 ID 리스트로 받는다. vpc 모듈의 subnet\_groups 키는 소비자가<br/>정하는 값이고 vpc 모듈이 그 이름을 강제하지 않으므로, 이쪽이 결합하면 조용히 깨진다.<br/>키 → ID 매핑은 소비자 루트의 책임이다. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | 이 모듈이 만드는 전 리소스에 추가할 태그.<br/>거버넌스 태그(Workload·Env·Owner 등)는 프로젝트 루트의 provider default\_tags 소관이므로<br/>여기에 반복하지 않는다. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | 클러스터를 배치할 VPC ID. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alb_controller_iam_role_arn"></a> [alb\_controller\_iam\_role\_arn](#output\_alb\_controller\_iam\_role\_arn) | AWS Load Balancer Controller의 Pod Identity role ARN(enable\_alb\_controller\_iam = true일 때).<br/>ALBC 자체는 GitOps helm으로 설치되므로, GitOps 저장소가 이 값을 참조한다. |
| <a name="output_argocd_hub_iam_role_arn"></a> [argocd\_hub\_iam\_role\_arn](#output\_argocd\_hub\_iam\_role\_arn) | 허브 ArgoCD(argocd-application-controller)의 Pod Identity role ARN<br/>(enable\_argocd\_hub\_pod\_identity = true일 때). 이 Role은 스포크 계정의 크로스 계정<br/>신뢰 Role(cross-account-trust-role 모듈 소유)을 assume한다. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | EKS 클러스터 ARN.<br/>GitOps 쪽 클러스터 등록이 API URL이 아니라 **ARN**을 요구하므로 계약에 둔다 —<br/>부트스트랩 seam이 어떻게 재결정되든(design/21) ARN은 어느 경로에서도 필요하다. |
| <a name="output_cluster_autoscaler_iam_role_arn"></a> [cluster\_autoscaler\_iam\_role\_arn](#output\_cluster\_autoscaler\_iam\_role\_arn) | Cluster Autoscaler Pod Identity role ARN. GitOps helm values의 서비스 어카운트 annotation이<br/>아니라 Pod Identity association으로 이미 바인딩되어 있다(namespace=kube-system,<br/>service\_account=cluster-autoscaler — 이 모듈이 고정한다). |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | kubeconfig의 certificate-authority-data(base64). |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | kube-apiserver 엔드포인트 URL. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | EKS 클러스터 이름. 소비자가 VPC 모듈의 eks\_cluster\_name·Karpenter discovery 태그와 맞출 값이다. |
| <a name="output_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#output\_cluster\_oidc\_issuer\_url) | OIDC 발급자 URL. |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | **upstream 모듈이 만든** cluster SG ID. vpc\_config.security\_group\_ids 로 클러스터에 붙어<br/>apiserver ENI 에 적용된다 — cluster\_security\_group\_additional\_rules 가 규칙을 붙이는 대상이다.<br/><br/>⚠️ **EKS 서비스가 자동 생성하는 primary cluster SG 와 다르다**(그쪽은 upstream 출력<br/>`cluster_primary_security_group_id` 이며 이 모듈은 노출하지 않는다).<br/>⛔ 이것을 "EKS가 만든 클러스터 보안 그룹"이라고 부르지 말 것 — primary SG 와 구분되지 않아<br/>   workbench 규칙을 어디에 붙일지 판단할 때 오도한다. |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | 실제로 기동된 컨트롤플레인 k8s 버전. 입력 kubernetes\_version과 대조해 승격 여부를 확인한다. |
| <a name="output_ebs_csi_iam_role_arn"></a> [ebs\_csi\_iam\_role\_arn](#output\_ebs\_csi\_iam\_role\_arn) | EBS CSI Driver의 Pod Identity role ARN. opt-in addon이라 cluster\_addons에 aws-ebs-csi-driver를 명시하지 않으면 null이다. |
| <a name="output_effective_addon_names"></a> [effective\_addon\_names](#output\_effective\_addon\_names) | 최종적으로 설치되는 addon 이름 목록(baseline merge + enabled 필터 결과).<br/><br/>소비자가 "내가 넘긴 cluster\_addons가 baseline과 어떻게 합쳐졌는가"를 확인하는 지점이다 —<br/>merge 규약(누락 != 삭제)은 코드를 읽지 않으면 결과를 예측하기 어렵기 때문이다.<br/><br/>⚠️ 이 출력은 **계약 검증의 관측점이기도 하다**. facade 모듈은 계산 결과를 하위 모듈의<br/>입력으로 넘기는데 `tofu test`는 하위 모듈에 들어간 값을 볼 수 없다 — 노출하지 않으면<br/>baseline 상속·opt-out 동작을 config-time에 검증할 방법이 없다. |
| <a name="output_efs_csi_iam_role_arn"></a> [efs\_csi\_iam\_role\_arn](#output\_efs\_csi\_iam\_role\_arn) | EFS CSI Driver의 Pod Identity role ARN. opt-in addon이라 cluster\_addons에 aws-efs-csi-driver를 명시하지 않으면 null이다. |
| <a name="output_external_dns_iam_role_arn"></a> [external\_dns\_iam\_role\_arn](#output\_external\_dns\_iam\_role\_arn) | external-dns의 Pod Identity role ARN(enable\_external\_dns\_iam = true일 때). |
| <a name="output_karpenter_discovery_tag"></a> [karpenter\_discovery\_tag](#output\_karpenter\_discovery\_tag) | Karpenter discovery 태그(맵). NodeClass의 subnetSelectorTerms·securityGroupSelectorTerms가<br/>이 값으로 인프라를 찾는다.<br/><br/>⚠️ 소비자는 **같은 값을 VPC 모듈의 노드 서브넷 그룹 extra\_tags에도** 넣어야 한다.<br/>SG 쪽은 이 모듈이 붙이지만 subnet 쪽은 VPC 모듈 소관이라, 한쪽만 붙으면<br/>selector가 빈 결과를 내고 프로비저닝이 실패한다(PoC의 실제 사고). |
| <a name="output_karpenter_iam_role_arn"></a> [karpenter\_iam\_role\_arn](#output\_karpenter\_iam\_role\_arn) | Karpenter 컨트롤러 role ARN. |
| <a name="output_karpenter_instance_profile_name"></a> [karpenter\_instance\_profile\_name](#output\_karpenter\_instance\_profile\_name) | Karpenter 노드 instance profile 이름. |
| <a name="output_karpenter_node_iam_role_arn"></a> [karpenter\_node\_iam\_role\_arn](#output\_karpenter\_node\_iam\_role\_arn) | Karpenter가 프로비저닝하는 노드의 IAM role ARN. |
| <a name="output_karpenter_node_iam_role_name"></a> [karpenter\_node\_iam\_role\_name](#output\_karpenter\_node\_iam\_role\_name) | Karpenter 노드 IAM role 이름. EC2NodeClass의 role 필드가 ARN이 아니라 이름을 받는다. |
| <a name="output_karpenter_sqs_queue_name"></a> [karpenter\_sqs\_queue\_name](#output\_karpenter\_sqs\_queue\_name) | 스팟 중단·헬스 이벤트를 받는 SQS 큐 이름. |
| <a name="output_node_security_group_id"></a> [node\_security\_group\_id](#output\_node\_security\_group\_id) | 노드 보안 그룹 ID. Karpenter의 securityGroupSelectorTerms가 이 SG의 discovery 태그를 찾는다.<br/>custom networking의 Pod ENI도 이 SG를 상속한다(addons.tf 주석 참조). |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | IAM OIDC 공급자 ARN. IRSA 방식 role의 신뢰 정책이 참조한다(Pod Identity를 쓰면 불필요). |
<!-- END_TF_DOCS -->
