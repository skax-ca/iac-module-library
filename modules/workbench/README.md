# workbench

private 클러스터 운영 지점(SSM 전용, 인바운드 0).

## Usage

```hcl
module "workbench" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/workbench?ref=workbench-vX.Y.Z"

  naming    = { workload = "demo", env = "dev", region_code = "an2" }
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.subnet_ids_by_group["private"][0]
  ami_id    = "ami-xxxxxxxxxxxxxxxxx" # 리전 종속, 조회법은 eks-cluster examples/enterprise "workbench AMI" 절 참조
}
```

`vX.Y.Z`는 자리표시자다. 실제 최신 태그는 `git tag -l 'workbench-v*'`로 확인한다. EKS 연동을
포함한 실전 예시는 [`../eks-cluster/examples/enterprise/README.md`](../eks-cluster/examples/enterprise/README.md)를
참조한다.

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

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.eks_describe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.pricing_lookup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ssm_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID. 기본값이 없다 = 필수 입력이다.<br/><br/>⛔ `.../al2023-ami-latest/...` SSM 파라미터나 most\_recent 조회를 쓰지 않는다.<br/>latest는 AWS 릴리스마다 값이 바뀌어 **리뷰 없이 인스턴스가 재생성**된다.<br/><br/>⚠️ 모듈이 기본값을 갖지 않는 이유는 AMI ID가 **리전 종속**이기 때문이다. 핀의 소유자는<br/>소비 루트다 — addon 버전 핀과 같은 구조다. 값 조회법은 예제 README 참조. | `string` | n/a | yes |
| <a name="input_argocd_version"></a> [argocd\_version](#input\_argocd\_version) | 설치할 argocd CLI 버전(예: "v3.5.0"). null이면 설치하지 않는다.<br/><br/>⚠️ chart appVersion과 같은 값을 쓴다. 서로 다른 값을 쓰면<br/>"UI에서 되는데 CLI에서 안 된다"를 진단할 근거가 사라진다. chart를 올리면 이 핀도 같이 올린다.<br/><br/>용도는 "로그인해서 쓴다"가 아니다: ① 초기 비밀번호 교체 —<br/>CLI가 없으면 port-forward + 대화형 SSM 세션이 필요하다 · ② `argocd cluster list`로<br/>cluster Secret이 내장 in-cluster를 대체하는지 판정(30 판정 ③). | `string` | `null` | no |
| <a name="input_egress_cidr_blocks"></a> [egress\_cidr\_blocks](#input\_egress\_cidr\_blocks) | 아웃바운드 443/tcp를 허용할 대상 CIDR. 기본은 전체 인터넷이며 NAT를 경유한다.<br/><br/>SSM 제어 트래픽·패키지·차트 저장소가 전부 HTTPS라 규칙이 하나면 충분하다.<br/>⚠️ SSM VPCE 3종을 신설한 완전 격리 VPC라면 VPC CIDR로 좁힐 수 있다. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_eks_cluster_arn"></a> [eks\_cluster\_arn](#input\_eks\_cluster\_arn) | workbench role의 eks:DescribeCluster 권한을 한정할 클러스터 ARN.<br/>null이면 인라인 정책을 만들지 않는다 — 쓰지 않는 권한을 남기지 않는다.<br/><br/>⚠️ eks\_cluster\_name과 **함께 주거나 함께 비운다**(아래 validation). | `string` | `null` | no |
| <a name="input_eks_cluster_name"></a> [eks\_cluster\_name](#input\_eks\_cluster\_name) | kubeconfig를 생성할 EKS 클러스터 이름. null이면 kubeconfig를 만들지 않는다.<br/><br/>⚠️ eks\_cluster\_arn과 **함께 주거나 함께 비운다**(아래 validation). | `string` | `null` | no |
| <a name="input_eks_node_viewer_version"></a> [eks\_node\_viewer\_version](#input\_eks\_node\_viewer\_version) | 설치할 eks-node-viewer 버전(예: "v0.7.4"). null이면 설치하지 않는다.<br/><br/>노드별 CPU/메모리 할당과 비용을 한 화면에서 본다 — Karpenter 가 만든 노드가<br/>실제로 어떻게 채워졌는지 보는 용도다(그 판정을 kubectl 로 하면 여러 명령이 필요하다).<br/><br/>⚠️ **릴리스 자산 이름이 다른 도구와 다르다** — `_Linux_arm64` / `_Linux_x86_64` 이고<br/>x86 쪽이 `amd64` 가 **아니다**. user-data 템플릿이 전용 매핑을 갖는 이유다. | `string` | `null` | no |
| <a name="input_helm_version"></a> [helm\_version](#input\_helm\_version) | 설치할 helm 버전(예: "v3.21.3"). null이면 설치하지 않는다.<br/><br/>⚠️ **Day 2 운영 프로파일과 무관하게, self-managed ArgoCD를 쓰면 필수다**.<br/>seed를 workbench에서 `helm install`로 하기 때문이다.<br/>helm을 직접 운영하는 프로파일도 이 변수를 쓴다. | `string` | `null` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | 인스턴스 타입. 기본 t4g.small(arm64, RAM 2GB).<br/><br/>⛔ t4g.nano(0.5GB)로 내리지 말 것. 부팅 중 `dnf`가 OOM-killer에 죽는다(실측:<br/>`Killed process (dnf) total-vm:976324kB`) — git이 설치되지 않아 GitOps 클론이 성립하지 않는다.<br/>⚠️ `free -m`이 보여주는 swap은 `/dev/zram0`(RAM 압축)이라 **여유 용량이 아니다.**<br/>self-hosted runner로 겸용하지 않으므로 빌드 부하는 여전히 고려하지 않는다.<br/>비용을 줄이려면 타입을 내리는 것이 아니라 workbench\_enabled = false로 끈다.<br/><br/>⚠️ **ami\_id의 아키텍처와 정합해야 한다.** 모듈은 검증하지 않는다 — 검증하려면 AMI를<br/>조회해야 하고(핀의 취지와 충돌), 타입 문자열에서 아키텍처를 유도하는 것은 닫힌 열거를<br/>새로 만드는 일이다. 불일치는 apply에서 드러난다. | `string` | `"t4g.small"` | no |
| <a name="input_krew_plugins"></a> [krew\_plugins](#input\_krew\_plugins) | krew 로 설치할 플러그인 목록. `krew_version` 이 null 이면 무시된다.<br/><br/>기본값은 이 팀이 실제로 쓰는 세트다(전부 krew-index 등재 확인):<br/>  ctx(컨텍스트 전환) · ns(네임스페이스 전환) · neat(출력에서 관리 필드 제거) ·<br/>  rbac-tool(권한 조회) · view-secret(Secret 복호화 조회) · whoami(현재 신원)<br/><br/>⚠️ **닫힌 열거가 아니다** — 고객사가 다른 세트를 원하면 이 변수로 바꾼다.<br/>⛔ 그러나 모듈이 플러그인 이름을 **검증하지는 않는다**. 없는 이름을 주면 부팅 중<br/>그 플러그인만 실패하고 나머지는 설치된다 — user\_data 는 부팅을 멈추지 않는다. | `list(string)` | <pre>[<br/>  "ctx",<br/>  "ns",<br/>  "neat",<br/>  "rbac-tool",<br/>  "view-secret",<br/>  "whoami"<br/>]</pre> | no |
| <a name="input_krew_version"></a> [krew\_version](#input\_krew\_version) | 설치할 krew(kubectl 플러그인 관리자) 버전(예: "v0.5.0"). null이면 설치하지 않는다.<br/><br/>`KREW_ROOT=/usr/local/krew` 로 시스템 설치한다. krew 의 기본값은 `$HOME/.krew` 인데,<br/>user\_data 는 root 로 돌기 때문에 그대로 두면 **`/root/.krew` 에 갇힌다** — kubeconfig 에서<br/>똑같이 겪은 문제다.<br/>플러그인은 상태가 아니라 바이너리라, 사용자별 사본을 두는 kubeconfig 와 반대로 공유가 옳다.<br/><br/>⚠️ kubectl 이 있어야 의미가 있다 — `kubectl_version` 이 null 이면 이 값도 무시된다. | `string` | `null` | no |
| <a name="input_kubectl_version"></a> [kubectl\_version](#input\_kubectl\_version) | 설치할 kubectl 버전(예: "v1.35.7"). null이면 설치하지 않는다.<br/>클러스터 마이너와 맞춘다 — https://dl.k8s.io/release/stable-<major.minor>.txt 로 확인한다. | `string` | `null` | no |
| <a name="input_naming"></a> [naming](#input\_naming) | Name 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로<br/>소비자는 약어를 직접 타이핑하지 않는다.<br/>예: {workload = "demo", env = "prd", region\_code = "an2"} → ec2-demo-prd-an2-workbench-01 | <pre>object({<br/>    workload    = string<br/>    env         = string<br/>    region_code = string<br/>  })</pre> | n/a | yes |
| <a name="input_purpose"></a> [purpose](#input\_purpose) | Name 태그의 purpose 토큰. | `string` | `"workbench"` | no |
| <a name="input_root_volume_kms_key_id"></a> [root\_volume\_kms\_key\_id](#input\_root\_volume\_kms\_key\_id) | root 볼륨 암호화에 쓸 고객 관리형 KMS 키 ARN. null이면 AWS 관리형 키를 쓴다.<br/>⚠️ 암호화 자체는 끌 수 없다 — encrypted = true는 계약이다. | `string` | `null` | no |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | root EBS 볼륨 크기(GiB). 기본 10은 도구 바이너리 설치에 충분하다.<br/>⚠️ user\_data가 /var/tmp(루트 EBS)로 다운로드하므로 이 값이 tmpfs 고갈을 막는 근거다. | `number` | `10` | no |
| <a name="input_serial"></a> [serial](#input\_serial) | Name 태그의 일련번호 토큰. | `string` | `"01"` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | workbench를 놓을 서브넷 **하나**. workbench는 1대이므로 AZ 분산이 의미가 없다 —<br/>리스트를 받아 내부에서 고르면 "어느 AZ에 떴는지"가 모듈 내부 규칙에 숨는다.<br/><br/>⚠️ **private 서브넷 전제**다. 인바운드가 0이므로 public 서브넷은 이득 없이 공격면만 늘린다.<br/>모듈은 이를 검사하지 않는다 — "public 서브넷 + 공인 IP 미할당"도 기술적으로 유효하고,<br/>닫힌 검증은 값이 늘 때마다 부채가 되기 때문이다. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | 이 모듈이 만드는 전 리소스에 추가할 태그.<br/>거버넌스 태그(Workload·Env·Owner 등)는 프로젝트 루트의 provider default\_tags 소관이므로<br/>여기에 반복하지 않는다. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | workbench SG를 만들 VPC. | `string` | n/a | yes |
| <a name="input_workbench_enabled"></a> [workbench\_enabled](#input\_workbench\_enabled) | kill switch(파괴 방향). false면 이 모듈의 전 리소스를 파기한다.<br/>false일 때 스칼라 출력은 전부 null이 된다.<br/><br/>⚠️ workbench는 삭제 보호(deletion\_protection) 대상이 아니다 — 수시 생성·파기가 정상 운용이고<br/>상태를 담지 않는다. vpc가 삭제 보호를 갖는 것과 대칭으로 만들지 않는 것이 의도된 차이다. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_workbench_iam_role_arn"></a> [workbench\_iam\_role\_arn](#output\_workbench\_iam\_role\_arn) | workbench role ARN. eks-cluster의 access\_entries principal로 넘긴다(접근 2층).<br/><br/>⛔ 이 모듈은 Access Entry를 직접 만들지 않는다 — eks-cluster가 이미 access\_entries를<br/>노출하므로 두 번째 경로는 경쟁 SSOT가 된다. |
| <a name="output_workbench_iam_role_name"></a> [workbench\_iam\_role\_name](#output\_workbench\_iam\_role\_name) | workbench role 이름. 인스턴스 프로파일도 같은 이름이다(카탈로그 상속 규약). |
| <a name="output_workbench_instance_id"></a> [workbench\_instance\_id](#output\_workbench\_instance\_id) | SSM 접속 대상. `aws ssm start-session --target <id>` 에 그대로 쓴다. |
| <a name="output_workbench_private_ip"></a> [workbench\_private\_ip](#output\_workbench\_private\_ip) | 도달성 진단용 private IP. |
| <a name="output_workbench_security_group_id"></a> [workbench\_security\_group\_id](#output\_workbench\_security\_group\_id) | workbench SG. eks-cluster의 cluster SG 추가 규칙 소스로 넘긴다(접근 3층).<br/><br/>⛔ 이 모듈은 그 규칙을 직접 만들지 않는다 — cluster SG의 rule 소유자를 쪼개면<br/>drift와 충돌이 생긴다. |
<!-- END_TF_DOCS -->
