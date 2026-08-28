# aks-cluster

Azure Kubernetes Service(AKS) 클러스터 · 시스템 노드 풀(필수) · 추가 노드 풀(옵트인).

이 모듈은 identity·role assignment·서브넷·리소스 그룹을 만들지 않는다. 전부 입력으로만
받는다 — 재사용 모듈이 만드는 리소스는 소비자의 CI 신원이 그것을 만들 권한을 가져야 한다는
뜻이고, `Microsoft.Authorization/roleAssignments/write`는 그 신원이 자기 자신에게 상위 역할을
부여할 수 있게 만들기 때문이다(`docs/decisions.md`「Azure 컨테이너 (aks-cluster)」ADR 참조).

## Usage

```hcl
module "vnet" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/azure/vnet?ref=vnet-vX.Y.Z"

  naming               = { workload = "demo", env = "prd", region_code = "krc" }
  resource_group_name  = azurerm_resource_group.this.name
  location             = azurerm_resource_group.this.location
  address_space        = ["10.60.0.0/24", "100.64.0.0/24"]

  subnet_groups = {
    "aks-node" = { address_prefixes = ["10.60.0.0/26"], nat_routed = true, nsg_enabled = true }
    "aks-pod"  = { address_prefixes = ["100.64.0.0/25"] }
  }
}

# ① identity → ② role assignment → ③ aks-cluster apply (본문 「순서 의존」 절 참조).
# 실제 배포에서는 ①·②가 이 root가 아니라 별도 bootstrap 계층에 있어야 한다.
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-demo-prd-krc-aks-01"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = module.vnet.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

module "aks_cluster" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/azure/aks-cluster?ref=aks-cluster-vX.Y.Z"

  naming               = { workload = "demo", env = "prd", region_code = "krc" }
  resource_group_name  = azurerm_resource_group.this.name
  location             = azurerm_resource_group.this.location

  identity_id    = azurerm_user_assigned_identity.aks.id
  node_subnet_id = module.vnet.subnet_ids_by_group["aks-node"]
  pod_subnet_id  = module.vnet.subnet_ids_by_group["aks-pod"]

  system_node_pool = { vm_size = "Standard_D2s_v5", node_count = 2 }

  depends_on = [azurerm_role_assignment.aks_network_contributor]
}
```

`vX.Y.Z`는 자리표시자다. 실제 최신 태그는 `git tag -l 'aks-cluster-v*'`로 확인한다. 착수
템플릿(vnet 배선 포함)은 [`examples/basic/`](examples/basic/)를 참조한다.

## 순서 의존 — identity 생성 → role assignment → apply

`identity_id`는 받았는데 그 identity에 서브넷의 `Network Contributor`가 없으면 클러스터는
서고 **노드가 서브넷에 붙지 못한다.** role assignment가 이 모듈 밖에 있어 plan에서 잡을 수
없는 죽은 경로다 — `depends_on`으로 순서를 강제한다(위 Usage 예시 참조).

## `identity_id`가 받는 권한은 두 종류다 — 하나는 우리가 주고, 하나는 Azure가 자동으로 준다

혼동하기 쉬운 지점이라 명시한다. `identity_id`로 넘긴 신원은 서로 다른 두 스코프에서
권한을 받는다.

| 권한 | 스코프 | 누가 부여하는가 | 용도 |
|---|---|---|---|
| `Network Contributor` | `node_subnet_id`·`pod_subnet_id`가 속한 VNet(또는 서브넷) | **소비자(bootstrap 계층)가 명시적으로 부여**(위 「순서 의존」 절) | 노드를 BYO 서브넷에 join |
| `Contributor` | 노드 리소스 그룹(`MC_*`, `node_resource_group` 출력) | **Azure가 클러스터 생성 시 자동 부여**(ARM·CLI·Terraform 무관, BYO user-assigned identity에도 동일 적용) | ingress Load Balancer·AKS 관리 공용 IP·Cluster Autoscaler·Azure Disk/File/Blob CSI 드라이버 관리 |

⚠️ **두 번째 권한은 이 모듈도, 소비자도 별도로 만들 필요가 없다** — 노드 리소스 그룹 자체가
클러스터 생성 시점에 Azure 리소스 프로바이더가 자동으로 만드는 것이라, 그 위의
`Contributor` 부여도 클러스터 생성에 내장된 자동 동작이다(Microsoft 공식 문서
`managed-identity-overview` 확인). 이 권한 덕분에 `type: LoadBalancer` Service를
`kubectl apply`만 해도 Azure가 Standard Load Balancer를 노드 리소스 그룹에 자동으로
만든다 — EKS의 AWS Load Balancer Controller처럼 별도 컨트롤러를 설치할 필요가 없다
(`cloud-controller-manager`가 Azure 관리형 컨트롤 플레인의 일부로 이미 떠 있다). 이
자동 생성은 Terraform state 밖에서 일어나므로 이 모듈에도, 소비 repo에도 관련 리소스가
없다 — 있으면 안 된다.

## Helm으로 설치하는 컨트롤러(ArgoCD·Kyverno 등)에 Azure 신원이 필요한가

**쿠버네티스 API만 건드리는 컨트롤러는 필요 없다.** ArgoCD·Kyverno는 표준 K8s RBAC
(ClusterRole/RoleBinding)만으로 동작한다 — Azure 관리 ID·역할 부여가 없어도 된다.

**Azure ARM API를 실제로 호출하는 컨트롤러**(external-dns, cert-manager+Azure DNS,
self-hosted 형태의 cluster-autoscaler 등)는 다르다 — Microsoft Entra Workload ID(공식
문서의 "Workload identity" 신원 종류, Bring your own identity: **Required**)를 쓴다.
이 모듈이 내보내는 `oidc_issuer_url`·`workload_identity_enabled`가 그 원시 재료이고,
실제 관리 ID 생성·federated identity credential·역할 부여는 전부 이 모듈 밖(bootstrap/
GitOps 계층)이다 — `identity_id`(신원 순서 의존 절)와 같은 경계 원칙이다.

AKS의 managed addon(`azure_policy_enabled`·`oms_agent`·`ingress_application_gateway`
등, 이 모듈은 0.1.0에서 열지 않는다)은 또 다르다 — Azure가 addon 전용 관리 ID를 내부에서
직접 만들고 굴린다(Bring your own identity: **Unsupported**인 것이 그 증거). eks-cluster의
`aws_eks_addon` + 직접 만드는 IAM role 패턴과 달리, 이 addon들은 Terraform으로 IAM을
관리할 필요 자체가 없다.

## 네트워킹 — Azure CNI Pod Subnet(flat) 고정

Overlay는 노출하지 않는다. Pod 트래픽이 노드 IP로 SNAT돼 NSG 플로우 로그·Network Watcher에서
Pod 단위 관측성이 사라지기 때문이다. 노드·Pod 서브넷은 둘 다 `vnet` 모듈이 만들고, 이 모듈은
ID만 입력받는다.

## 노드 풀 이름 — 하이픈 금지, 12자 한도

시스템 노드 풀은 `npsystem` 고정, 추가 노드 풀은 `np<node_pools 키>`로 조합된다. 키는
소문자로 시작하고 소문자+숫자만, 8자 이하여야 한다(`docs/conventions.md`「Azure 강제
방식」6번 — Azure 노드 풀 이름 물리 제약, `temporary_name_for_rotation`이 쓰는 자리를
함께 남긴다).

## Karpenter — Node Auto Provisioning(NAP), 기본 켜짐

`enable_karpenter`(기본 `true`)가 `node_provisioning_profile.mode = "Auto"`를 켠다. AKS의
Node Auto Provisioning(NAP)은 오픈소스 Karpenter + [AKS Karpenter
provider](https://github.com/Azure/karpenter-provider-azure) 기반이다 — `eks-cluster`의
`enable_karpenter`와 개념이 대응하지만 구현 위치가 다르다. AWS는 별도 IAM 리소스 뭉치
(컨트롤러 role·노드 role·instance profile·중단 SQS)가 필요하지만, Azure는 이 필드 하나로
끝난다. `default_node_pool`(시스템 노드 풀)은 Auto에서도 여전히 필수다. Karpenter의
`NodePool`·`AKSNodeClass` CRD 설치와 실제 프로비저닝 정책은 이 모듈 밖(GitOps 소관) —
`eks-cluster`가 "helm 설치와 NodePool/NodeClass는 GitOps 소관"이라고 긋는 경계와 같다.

⚠️ **네트워킹 조합은 검증되지 않았다.** 공식 문서·`karpenter-provider-azure` README의
모든 예제는 Azure CNI Overlay + Cilium 데이터플레인 조합만 쓴다("성능 최적화" 권고이지
강제 문구는 아니다). 그 README의 "Known limitations"는 Windows·Kubenet·Calico·IPv6·
Service Principal·클러스터 stop·생성 후 `outbound_type` 변경 6개만 나열하고 Pod Subnet
모드는 없다 — 이 모듈이 고정한 flat Pod Subnet과의 조합이 명시적으로 배제되지는 않았지만,
실제 검증 사례도 없다. `false`로 끄면 `mode = "Manual"`이 된다.

## `eks-cluster`와의 비대칭

전체 표는 [`docs/module-catalog.md`](../../../docs/module-catalog.md#eks-cluster와의-비대칭)를
참조한다 — IAM/role 리소스를 이 모듈이 만들지 않는 것, 시스템 노드 풀이 필수인 것, 애드온이
없는 것이 핵심 차이다.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 5.3.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_kubernetes_cluster.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster) | resource |
| [azurerm_kubernetes_cluster_node_pool.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_node_pool) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_authorized_ip_ranges"></a> [authorized\_ip\_ranges](#input\_authorized\_ip\_ranges) | API 서버 접근을 허용할 CIDR 목록. 비어 있으면 제한을 걸지 않는다. private\_cluster\_enabled<br/>= true인 클러스터에는 적용되지 않는다(provider 동작 — private 클러스터는 애초에 공개<br/>엔드포인트가 없다). | `list(string)` | `[]` | no |
| <a name="input_cluster_enabled"></a> [cluster\_enabled](#input\_cluster\_enabled) | kill switch(파괴 방향). false면 이 모듈의 전 리소스(클러스터·추가 노드 풀)를 파기한다.<br/>false일 때 스칼라 출력은 null, map 출력은 빈 값이 된다. | `bool` | `true` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | 삭제 보호(보호 방향). true면 azurerm\_kubernetes\_cluster에 prevent\_destroy가 걸려 파괴<br/>계획 자체가 차단된다. AKS에는 네이티브 삭제 보호 인자가 없다 — lifecycle 블록이 유일한<br/>수단이다(modules/azure/vnet과 같은 형태).<br/><br/>보호를 켠 상태의 파기는 2단계다 — deletion\_protection = false로 apply한 뒤<br/>cluster\_enabled = false. | `bool` | `false` | no |
| <a name="input_dns_service_ip"></a> [dns\_service\_ip](#input\_dns\_service\_ip) | kube-dns가 쓸, service\_cidr 범위 내 IP. 변경 시 클러스터가 재생성된다. | `string` | `null` | no |
| <a name="input_enable_karpenter"></a> [enable\_karpenter](#input\_enable\_karpenter) | Node Auto Provisioning(NAP) 활성화 여부. NAP은 오픈소스 Karpenter + AKS Karpenter<br/>provider(github.com/Azure/karpenter-provider-azure) 기반이다 — eks-cluster의<br/>enable\_karpenter와 개념이 대응한다. 구현 위치는 다르다: AWS는 별도 IAM 리소스 뭉치<br/>(컨트롤러 role·노드 role·instance profile·중단 SQS)가 필요하지만, Azure는 이 클러스터<br/>리소스의 필드 하나(node\_provisioning\_profile.mode)로 끝난다 — 추가 리소스가 없다.<br/><br/>true면 node\_provisioning\_profile.mode = "Auto"로 설정한다. default\_node\_pool(시스템<br/>노드 풀)은 Auto에서도 여전히 필수다(공식 문서 확인 — NAP이 대체하는 것은 추가 노드 풀<br/>수요이지 시스템 풀이 아니다). Karpenter NodePool·AKSNodeClass CRD 설치와 실제 노드<br/>프로비저닝 정책은 이 모듈 밖(GitOps 소관)이다 — eks-cluster가 "helm 설치와<br/>NodePool/NodeClass는 GitOps 소관"이라고 선을 긋는 것과 같은 경계다.<br/><br/>⚠️ 네트워킹 조합 확인(2026-08-28): 공식 문서·github.com/Azure/karpenter-provider-azure<br/>README의 예제는 전부 Azure CNI **Overlay** + **Cilium**만 쓰지만("성능 최적화" 권고일<br/>뿐 강제 문구 아님), 그 README의 "Known limitations"(원문 실측 확인)는 Windows·Kubenet·<br/>Calico·IPv6·Service Principal·클러스터 stop·생성 후 outbound\_type 변경 6개만 나열하고<br/>**Pod Subnet 모드는 없다**. 이 모듈이 고정한 **flat Pod Subnet**과의 조합이 명시적으로<br/>배제되지는 않았으나, 실제 예제·검증 사례도 없다(사용자 확인 후 채택, 2026-08-28). 이<br/>저장소는 배포하지 않으므로(`.claude/rules/terraform.md`) live Azure로 실제 노드<br/>프로비저닝까지는 확인할 수 없다 — 스키마 수준(mode 값·default\_node\_pool 존재)만 보장한다. | `bool` | `true` | no |
| <a name="input_entra_admin_group_object_ids"></a> [entra\_admin\_group\_object\_ids](#input\_entra\_admin\_group\_object\_ids) | Entra ID(Azure AD) RBAC를 켤 Admin 그룹의 Object ID 목록. 비어 있으면 Entra 통합<br/>블록 자체를 만들지 않는다 — 잠금이 기본 동작이 아니다(옵트인, G2 확정). | `list(string)` | `[]` | no |
| <a name="input_identity_id"></a> [identity\_id](#input\_identity\_id) | 클러스터 컨트롤 플레인이 쓸 user-assigned managed identity의 리소스 ID(필수).<br/><br/>이 모듈은 identity도 role assignment도 만들지 않는다 — 만들면 소비자의 CI 신원이 그<br/>리소스를 만들 권한(Microsoft.Authorization/roleAssignments/write 포함)을 가져야 하고,<br/>그 권한은 CI 신원이 자기 자신에게 상위 역할을 부여할 수 있게 만든다(축3,<br/>docs/decisions.md「Azure 컨테이너 (aks-cluster)」ADR 참조).<br/><br/>⚠️ 순서 의존: ① identity 생성 → ② node\_subnet\_id·pod\_subnet\_id가 속한 서브넷에 이<br/>identity의 Network Contributor 역할 부여 → ③ 이 모듈 apply. ②를 건너뛰면 ③은 성공하고<br/>노드만 조용히 실패한다 — role assignment가 이 모듈 밖에 있어 plan에서 잡을 수 없는<br/>죽은 경로다. bootstrap 계층이 ①·②를 처리한다. | `string` | n/a | yes |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes 버전. 생략하면 provider가 최신 권장 버전을 쓴다(자동 업그레이드는 하지 않는다). | `string` | `null` | no |
| <a name="input_local_account_disabled"></a> [local\_account\_disabled](#input\_local\_account\_disabled) | true면 로컬 계정(kubeconfig의 클러스터 admin 자격증명)을 비활성화한다. 기본 false로<br/>브레이크글래스(kube\_admin\_config) 경로를 유지한다(G2 확정).<br/><br/>⚠️ entra\_admin\_group\_object\_ids가 비어 있는 채로 이 값을 true로 두면 클러스터 접근<br/>수단이 전혀 남지 않는다 — provider도 local\_account\_disabled = true일 때 Entra ID<br/>RBAC 활성화를 요구한다. | `bool` | `false` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure 리전(필수 입력). | `string` | n/a | yes |
| <a name="input_naming"></a> [naming](#input\_naming) | name 인자 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로<br/>소비자는 약어를 직접 타이핑하지 않는다.<br/>예: {workload = "demo", env = "prd", region\_code = "krc"} → aks-demo-prd-krc-main-01 | <pre>object({<br/>    workload    = string<br/>    env         = string<br/>    region_code = string<br/>  })</pre> | n/a | yes |
| <a name="input_node_pools"></a> [node\_pools](#input\_node\_pools) | 추가(User) 노드 풀 정의. 맵 키가 노드 풀 이름 "np<키>"의 재료가 된다.<br/><br/>키 제약(Azure 물리 제약, docs/conventions.md「Azure 강제 방식」6번): 소문자로 시작,<br/>소문자+숫자만, 8자 이하. `np` 접두사(2자) + 키(최대 8자) = 최대 10자로, AKS 노드 풀<br/>이름 한도(1~12자, Linux)와 temporary\_name\_for\_rotation(순환용 임시 이름, "<이름>t")이<br/>쓰는 자리를 함께 남긴다.<br/><br/>vm\_size              - VM 크기(필수)<br/>node\_count           - 고정 노드 수(auto\_scaling\_enabled = false일 때만 쓰인다)<br/>auto\_scaling\_enabled - true면 min\_count·max\_count로 오토스케일링한다<br/>min\_count/max\_count  - auto\_scaling\_enabled = true일 때만 쓰인다<br/>os\_disk\_size\_gb      - OS 디스크 크기(GB)<br/>max\_pods             - 노드당 최대 파드 수<br/>zones                - 가용 영역 목록<br/>node\_labels          - Kubernetes 노드 라벨<br/>node\_taints          - Kubernetes 노드 taint("key=value:Effect" 형태 문자열 목록)<br/><br/>⛔ Windows 노드 풀은 0.1.0 스코프 밖이다 — 이름 한도가 6자라 위 키 제약이 성립하지<br/>않는다(기술적 불가가 아니라 스코프 결정). | <pre>map(object({<br/>    vm_size              = string<br/>    node_count           = optional(number, 1)<br/>    auto_scaling_enabled = optional(bool, false)<br/>    min_count            = optional(number)<br/>    max_count            = optional(number)<br/>    os_disk_size_gb      = optional(number)<br/>    max_pods             = optional(number)<br/>    zones                = optional(list(string))<br/>    node_labels          = optional(map(string), {})<br/>    node_taints          = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_node_subnet_id"></a> [node\_subnet\_id](#input\_node\_subnet\_id) | 노드가 속할 서브넷 ID(필수). vnet 모듈의 subnet\_ids\_by\_group["aks-node"] 등을 넘긴다.<br/>이 서브넷은 위임된 서브넷일 수 없다(delegations를 쓰지 않는다) — AKS 공식 제약이다. | `string` | n/a | yes |
| <a name="input_pod_subnet_id"></a> [pod\_subnet\_id](#input\_pod\_subnet\_id) | Pod가 속할 서브넷 ID(필수). vnet 모듈의 subnet\_ids\_by\_group["aks-pod"] 등을 넘긴다 —<br/>이 모듈은 Pod 서브넷을 만들지 않는다(소유하지 않은 VNet에 서브넷을 만드는 경계 위반이자,<br/>"CIDR 계산은 소비자 루트가 소유한다"는 규약 위반이기 때문).<br/><br/>0.1.0은 전 노드 풀(시스템 풀 + var.node\_pools 전부)이 이 값 하나를 공유한다. 풀별<br/>오버라이드는 v0.2.0 이월이다 — 서브넷 교체는 노드 풀 순환을 부르므로 나중에 여는 것도<br/>비파괴 변경이다.<br/><br/>네트워킹은 Azure CNI Pod Subnet(flat)로 고정된다 — Overlay는 노출하지 않는다. Overlay는<br/>Pod 트래픽이 노드 IP로 SNAT돼 NSG 플로우 로그·Network Watcher에서 Pod 단위 관측성이<br/>사라진다(소비 repo가 이미 확정한 결정, 축5 참조). 필요해지면 클러스터 재생성이 필요하다<br/>(network\_profile은 ForceNew). | `string` | n/a | yes |
| <a name="input_private_cluster_enabled"></a> [private\_cluster\_enabled](#input\_private\_cluster\_enabled) | true면 API 서버가 내부 IP로만 노출된다(공개 엔드포인트 없음). 변경 시 클러스터가<br/>재생성된다(provider 제약) — eks-cluster의 독립 public/private 토글과 달리 AKS는 이<br/>값 하나로 공개·비공개를 가른다.<br/><br/>기본값 true — eks-cluster의 endpoint\_public\_access 기본값(false, "GitOps(pull)<br/>전제이므로 기본은 private")과 같은 철학을 따른다. ⚠️ 이 축은 ralplan 설계 라운드가<br/>깊게 다루지 않았다(G-A·G2처럼 사용자 확인을 거치지 않음) — 구현 시점에 AWS 자매<br/>모듈과의 대칭을 근거로 판단했다. private\_cluster\_enabled = false로 여는 것은<br/>옵트아웃으로 언제든 가능하다. | `bool` | `true` | no |
| <a name="input_purpose"></a> [purpose](#input\_purpose) | name 인자의 purpose 토큰. 클러스터 자신에 쓰인다. | `string` | `"main"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | 리소스 그룹 이름(필수 주입). 이 모듈은 리소스 그룹을 만들지 않는다. | `string` | n/a | yes |
| <a name="input_serial"></a> [serial](#input\_serial) | name 인자의 일련번호 토큰. | `string` | `"01"` | no |
| <a name="input_service_cidr"></a> [service\_cidr](#input\_service\_cidr) | Kubernetes 서비스 주소 범위. 변경 시 클러스터가 재생성된다. dns\_service\_ip와 함께<br/>지정하거나 함께 비워야 한다(provider 제약). | `string` | `null` | no |
| <a name="input_sku_tier"></a> [sku\_tier](#input\_sku\_tier) | 클러스터 SKU 티어. Free(기본, SLA 없음)·Standard(Uptime SLA)·Premium 중 하나. | `string` | `"Free"` | no |
| <a name="input_system_node_pool"></a> [system\_node\_pool](#input\_system\_node\_pool) | 시스템 노드 풀 설정(default\_node\_pool). AKS는 시스템 노드 풀을 필수로 강제한다 —<br/>eks-cluster의 managed\_node\_groups = {}처럼 빈 값으로 생략할 수 없다(공식 제약,<br/>default\_node\_pool 인자 자체가 Required).<br/><br/>vm\_size              - VM 크기(필수)<br/>node\_count           - 고정 노드 수(auto\_scaling\_enabled = false일 때만 쓰인다)<br/>auto\_scaling\_enabled - true면 min\_count·max\_count로 오토스케일링한다<br/>min\_count/max\_count  - auto\_scaling\_enabled = true일 때만 쓰인다<br/>os\_disk\_size\_gb      - OS 디스크 크기(GB). 생략하면 provider 기본값<br/>max\_pods             - 노드당 최대 파드 수. 생략하면 provider 기본값<br/>zones                - 가용 영역 목록. 생략하면 무존 배치 | <pre>object({<br/>    vm_size              = string<br/>    node_count           = optional(number, 1)<br/>    auto_scaling_enabled = optional(bool, false)<br/>    min_count            = optional(number)<br/>    max_count            = optional(number)<br/>    os_disk_size_gb      = optional(number)<br/>    max_pods             = optional(number)<br/>    zones                = optional(list(string))<br/>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | 이 모듈이 만드는 리소스(클러스터·노드 풀)에 추가할 태그. Azure는 provider 한 곳에서<br/>거버넌스 태그를 주입할 수단이 없어(azurerm에 default\_tags 대응 인자 없음) 리소스마다<br/>명시로 배선한다. | `map(string)` | `{}` | no |
| <a name="input_workload_identity_enabled"></a> [workload\_identity\_enabled](#input\_workload\_identity\_enabled) | Azure AD Workload Identity 활성화 여부. oidc\_issuer\_url 출력은 이 값과 무관하게 항상<br/>나간다(OIDC issuer는 이 모듈이 항상 켠다). 실제 federated identity credential 생성·<br/>역할 부여는 이 모듈 밖(bootstrap 계층)이다 — 이 값과 oidc\_issuer\_url 출력은 그 작업이<br/>딛고 설 원시 재료일 뿐이다. | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | AKS 클러스터 ID. cluster\_enabled = false면 null이다. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | AKS 클러스터 이름. cluster\_enabled = false면 null이다. |
| <a name="output_fqdn"></a> [fqdn](#output\_fqdn) | 클러스터 API 서버 FQDN(공용 엔드포인트). private\_cluster\_enabled = true면 null이다<br/>(provider 동작). cluster\_enabled = false면도 null이다. |
| <a name="output_kubelet_identity_object_id"></a> [kubelet\_identity\_object\_id](#output\_kubelet\_identity\_object\_id) | kubelet이 쓰는 관리 ID의 Object ID(AKS가 노드 리소스 그룹에 자동 생성한 것 — 이 모듈이<br/>만들지 않는다). ACR pull 등 kubelet 신원에 권한을 부여할 때 쓴다. cluster\_enabled =<br/>false면 null이다. |
| <a name="output_node_pool_ids_by_key"></a> [node\_pool\_ids\_by\_key](#output\_node\_pool\_ids\_by\_key) | 추가(User) 노드 풀 키 → 노드 풀 ID. 키는 소비자가 넘긴 node\_pools 키 그대로다.<br/>시스템 노드 풀은 포함하지 않는다(클러스터 리소스 자신이 소유, cluster\_id로 식별한다). |
| <a name="output_node_resource_group"></a> [node\_resource\_group](#output\_node\_resource\_group) | AKS가 노드 리소스를 자동 생성하는 리소스 그룹 이름. cluster\_enabled = false면 null이다. |
| <a name="output_oidc_issuer_url"></a> [oidc\_issuer\_url](#output\_oidc\_issuer\_url) | OIDC issuer URL. Workload Identity Federation 등 신원 배선의 원시 재료다(이 모듈은<br/>federated identity credential을 만들지 않는다). cluster\_enabled = false면 null이다. |
| <a name="output_private_fqdn"></a> [private\_fqdn](#output\_private\_fqdn) | 클러스터 API 서버 FQDN(private\_cluster\_enabled = true일 때만 값이 있다). 그 외에는<br/>null이다. |
<!-- END_TF_DOCS -->
