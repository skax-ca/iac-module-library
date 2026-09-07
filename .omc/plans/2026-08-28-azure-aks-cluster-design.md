# Azure `aks-cluster` 모듈 설계 (RALPLAN-DR / SHORT)

**상태**: **v4 — Architect 승인 · Critic ITERATE(승인 직전) 반영 완료.** Architect가 v3를
재검토해 승인으로 올렸고(6/6 반영 확인, 비차단 4건), Critic도 v3를 독립 재검토해 "1차 CRITICAL
1건·MAJOR 7건 전부 실증으로 해소"라며 ITERATE(승인 직전)로 올렸다. 남은 6절 문안 3건(N-1·N-2·N-3)·
숫자 2건은 Critic이 "국소 편집, 재검토 불요"로 판단해 Planner 세션 한도 도달 후 team-lead가
직접 반영했다(vnet 라운드 선례와 같은 처리). 실행 착수 전 사용자 확인 필요: **G-A · G2** (3절).
**모드**: SHORT (신규 모듈 1개, **소비자 1명 확정**, 기존 계약 파괴 없음).
**스코프**: **설계 문서만.** `.tf` 파일과 `modules/azure/aks-cluster/` 디렉터리를 만들지 않는다.
**선행 라운드**: `.omc/plans/2026-08-26-azure-vnet-design.md`(vnet, `vnet-v0.2.0` 릴리스 완료).
이 계획은 그 계획의 절 구성과 인수 조건 규율을 그대로 잇는다.

> **v1 → v2 개정**: 소비 repo `aks-reference-infra`에 **이미 확정된 제약 3건**을 반영했다
> (0-21·0-22·0-23, 전부 실물 인용). 파급은 셋이다.
> ① **축 3(신원)이 게이트에서 확정 결정으로 바뀌었다** — 모듈은 identity도 role assignment도
>    만들지 않는다. v1의 권고(주입)와 방향은 같으나 근거가 "경계"에서 **"소비 repo의 보안
>    불변식"** 으로 바뀌어 더 강해졌고, system-assigned가 **원천 배제**됐다.
> ② **축 5(CNI)의 권고가 뒤집혔다** — v1은 overlay 기본을 권고했으나 소비 repo가 **Pod
>    Subnet(flat)** 을 확정했다. v1의 실측(0-4)이 그 결정의 근거를 그대로 뒷받침한다.
> ③ **축 10(Pod 서브넷 소유권)이 신설됐다.**
>
> **v2 → v3 개정** (Architect·Critic 검토 반영). 파급은 다섯이다.
> ① 🔴 **CRITICAL: Step 1이 기계 게이트를 통과할 수 없었다.** `npsystem`(8자)이 7자 한도를,
>    `npsystem`·`npapp` 예시가 *"예시는 `<약어>-`로 시작"* 검사를 위반한다. **스크래치패드에서
>    실증했다**(0-27). → **노드 풀 이름 계약을 약어 카탈로그에서 빼고 `conventions.md`가 소유**한다.
> ② **축 3의 정당화 문장이 실물과 달랐다.** *"AWS에서 이미 정확히 같은 구조를 쓴다"* 는 거짓이다 —
>    `eks-cluster/iam.tf`는 IAM role을 **실제로 만든다**(0-25). 근거를 **"같은 철학, 다른 메커니즘"**
>    으로 교체하고, **5번째 옵션(`data` 조회)** 을 추가했다.
> ③ 🔴 **최대 판돈 미결(0-16-3 라우팅 테이블)이 해소됐다**(0-26). UDR 요구는 **kubenet 전용**이고
>    Azure CNI에는 적용되지 않는다. **이미 배포된 소비 repo root를 고칠 필요가 없다.**
> ④ **확정한 인터페이스가 어떤 `docs/` 산출물에도 안 실리고 있었다** — `vnet` 선례대로
>    「인터페이스 초안」 서브섹션을 복원했다(Step 3).
> ⑤ **인수 조건 버그 3건**(항상 0을 내는 awk · 기준값 오류 · 검증기 누락)을 정정했다.
>
> **v3 → v4 개정**(Critic의 v3 독립 재검토, ITERATE — 승인 직전). 1차 CRITICAL·MAJOR는 전부
> 해소로 재확인됐다. 남은 것은 6절 ADR 초안이 v3 본문 스스로 반증·금지한 내용을 그대로 담고
> 있던 3건과 숫자 오류 2건, 전부 문안 수정이다.
> ① **6절 Consequences가 이미 해소된 리스크(0-16-3)를 미해소로, 반증된 문장을 그대로** 적고
>    있었다 — "세 가지" → "두 가지", "소비 repo를 고쳐야 할 수 있다" 삭제(0-26이 이미 반증).
> ② **6절 Why chosen이 0-25가 "다시 쓰면 안 된다"고 못박은 그 근거**(cross-account-trust-role을
>    "권한 철학" 선례로 인용)를 그대로 쓰고 있었다 — 축 3이 이미 쓴 정정 문장으로 교체.
> ③ **커스텀 역할 위협 모델의 주어가 세 곳(0-26-b·Must NOT Have·기각표)에서 뒤섞여 있었다** —
>    `roleAssignments/write`를 받는 것은 CI 신원이 아니라 **클러스터 identity**다. 결론(내장
>    역할을 쓴다)은 그대로 두고 근거만 정정.
> ④ 8절 체크표 숫자(0절 항목 20→27, 0-16 3건→2건)·ADR 기각 표 행수(18→25)·`variables.tf:68`→66
>    을 실측값으로 정정.

> ⚠️ **vnet 라운드가 세 번 연속 같은 종류로 틀렸다**: 검증하지 않은 것을 근거로 썼다.
> 그 라운드의 P3(**인용 없는 문장은 근거로 쓰지 않는다**)를 이 계획도 그대로 적용한다.
> 0절의 모든 사실 문장에 조회한 원문·조회 경로를 붙였고, 확인하지 못한 것은
> **"규정하지 않는다"** 로 명시했다(0-16·0-17·0-18). 추정으로 채운 문장은 없다.

---

## 0. 착수 전 실측 사항

조회 경로는 셋이다.
① `mcp__opentofu__get-resource-docs`(hashicorp/azurerm 최신, **v5.3.0** — `registry.opentofu.org/v1/providers/hashicorp/azurerm/versions` 실측)
② Microsoft Learn 원문
③ `mcp__opentofu__search-opentofu-registry`

### 0-1. 🔴 AKS 노드 풀 이름은 하이픈을 쓸 수 없다 — 이 저장소의 네이밍 포맷이 물리적으로 안 들어간다

Azure 공식 네이밍 규칙표(`resource-name-rules`, `Microsoft.ContainerService` 절) 원문:

| 리소스 | 스코프 | 길이 | 유효 문자 |
|---|---|---|---|
| `managedClusters` | 리소스 그룹 | 1-63 | *"Alphanumerics, underscores, and hyphens. Start and end with alphanumeric."* |
| `managedClusters / agentPools` | **managed cluster** | **1-12 for Linux, 1-6 for Windows** | *"Lowercase letters and numbers. Can't start with a number."* |

이 저장소의 이름 포맷은 `(약어)-(workload)-(env)-(리전코드)-(purpose)-(일련번호)`로 **하이픈 구분**이다
(`docs/conventions.md` §2). 노드 풀에는 하이픈 자체가 금지이고 길이도 12자다.

**대조**: `modules/aws/eks-cluster/main.tf:27`은 노드그룹 이름을
`"eksn-${local.name_mid}-${ng_key}"`로 조합한다 → `eksn-demo-prd-an2-system`(24자, 하이픈 4개).
**Azure에서는 이 형태가 생성 자체가 불가능하다.**

⚠️ 이것은 `azure.md`의 Storage Account 항목(*"3~24자, 소문자+숫자만, 하이픈 불가"*)과 같은 종류의
물리 제약이지만 **더 강하다**: Storage Account는 하이픈만 빼고 토큰을 이어붙일 수 있으나
(`stdemoprdkrcmain01`, 18자), 노드 풀은 12자라 `npdemoprdkrcsystem`(18자)조차 들어가지 않는다.

### 0-2. `default_node_pool`은 **Required**다 — "노드 풀은 이 모듈 밖"이 성립하지 않는다

`azurerm_kubernetes_cluster` 인자 목록 원문:

> `* `default_node_pool` - (Required) Specifies configuration for "System" mode node pool. A `default_node_pool` block as defined below.`

EKS는 노드그룹이 전부 선택이라 `managed_node_groups = {}`(기본값)로도 클러스터가 선다
(`modules/aws/eks-cluster/variables.tf:241`). **AKS는 시스템 노드 풀이 클러스터 리소스의 필수
구성요소**다. `vnet` 라운드의 0-7(예약 이름 서브넷 = 모듈이 만들 수 없다)과 **반대 방향의
강제**다: 여기서는 모듈이 만들지 **않을** 선택지가 없다.

### 0-3. kubenet은 2028-03-31에 지원이 끝난다 — 배송 모듈이 노출할 손잡이가 아니다

Microsoft Learn `concepts-network-azure-cni-overlay` 원문:

> *"Starting on **March 31, 2028**, Azure Kubernetes Service (AKS) no longer supports kubenet
> networking. To avoid service disruptions, upgrade to Azure Container Networking Interface (CNI)
> Overlay networking before the end-of-support date."*

provider는 여전히 `network_plugin`에 `kubenet`을 받는다(*"Currently supported values are `azure`,
`kubenet` and `none`"*). **provider가 받는다는 것과 배송 모듈이 노출해야 한다는 것은 다르다.**

### 0-4. Azure CNI Overlay와 flat CNI는 서브넷 소요가 다르다

같은 문서 원문:

> *"In overlay networking, only the Kubernetes cluster nodes are assigned IPs from subnets. Pods
> receive IPs from a private CIDR range provided at the time of cluster creation. Each node is
> assigned a `/24` address space carved out from the same CIDR."*

> *"Pod CIDR space must not overlap with the cluster subnet range."* ·
> *"Pod CIDR space must not overlap with directly connected networks, like virtual network peering,
> Azure ExpressRoute, or VPN."*

flat 모드(Azure CNI Pod Subnet)는 반대로 *"assigns pod IPs from a separate subnet reserved for
pods"* 라 **VNet 주소 공간을 소모한다.** 즉 CNI 모드 선택이 `vnet` 모듈에 요구하는
**서브넷 그룹 개수**를 바꾼다(overlay = 노드 서브넷 1개, pod subnet = 2개).

provider 제약 원문: *"`pod_cidr` — This field can only be set when `network_plugin` is set to
`kubenet` or `network_plugin_mode` is set to `overlay`."*

### 0-5. 🔴 `network_profile` 블록 변경은 클러스터를 재생성한다

`azurerm_kubernetes_cluster` 인자 목록 원문:

> `* `network_profile` - (Optional) A `network_profile` block as defined below. **Changing this forces a new resource to be created.**`

⚠️ **CNI 모드를 나중에 바꾸는 비용이 "재배포"다.** 이 사실이 축 5(모드를 하나로 고정할지
둘 다 노출할지)의 판정을 가른다 — 기본값을 잘못 고르면 고객사가 클러스터를 다시 세운다.

### 0-6. 🔴 자체 VNet을 쓰면 Microsoft가 **user-assigned** 컨트롤 플레인 신원을 권고한다

Microsoft Learn `managed-identity-overview`(AKS 관리 ID 개요) 원문 두 곳:

> *"If you're not using the Azure CLI, but you're using **your own VNet**, attached Azure disks,
> static IP address, route table, or user-assigned kubelet identity where those resources are
> outside of the worker node resource group, we recommend using a **user-assigned managed identity
> for the control plane** and manually performing the required role assignment using the principal
> ID of that identity."*

> *"When the control plane uses a system-assigned managed identity, you create the identity at the
> same time as the cluster, so **you can't perform the role assignment until after cluster
> creation**."*

이 모듈의 존재 이유가 *"`vnet` 모듈이 만든 서브넷 위에 AKS를 세운다"* 이므로, 위 조건
(*"your own VNet"*)에 **항상** 해당한다. system-assigned를 쓰면 role assignment가 클러스터
생성 **뒤**로 밀려 IaC 한 번의 apply로 닫히지 않는 순서 문제가 구조적으로 남는다.

기본 동작 원문: *"When you deploy an AKS cluster, a system-assigned managed identity is created for
you by default."* — 즉 **provider 기본값과 Microsoft 권고가 이 시나리오에서 갈린다.**

### 0-7. kubelet 신원은 컨트롤 플레인 신원과 별개다

같은 문서의 요약 표 원문:

| Identity | Name | Default permissions | Bring your own identity |
|---|---|---|---|
| Control plane | *AKS cluster name* | *"Contributor role for node resource group"* | Supported |
| Kubelet | *AKS cluster name*`-agentpool` | *"None; requires an ACR pull role based on the registry permission mode"* | Supported |

> *"If you don't specify a user-assigned managed identity for kubelet, AKS creates a user-assigned
> kubelet identity in the node resource group."*

⚠️ kubelet 신원을 **노드 리소스 그룹 밖**에 두면 컨트롤 플레인 신원에 `Managed Identity Operator`
role이 추가로 필요하다(같은 문서). 즉 kubelet 신원 주입은 role assignment를 하나 더 부른다.

### 0-8. Entra ID RBAC은 블록 하나이고, `local_account_disabled`는 잠금 위험을 만든다

`azure_active_directory_role_based_access_control` 블록 원문(전체 3개 인자):

> `* `tenant_id` - (Optional) ... If this isn't specified the Tenant ID of the current Subscription is used.`
> `* `admin_group_object_ids` - (Optional) A list of Object IDs of Azure Active Directory Groups which should have Admin Role on the Cluster.`
> `* `azure_rbac_enabled` - (Optional) Is Role Based Access Control based on Azure AD enabled?`

관련 최상위 인자:

> `* `local_account_disabled` - (Optional) If `true` local accounts will be disabled.`
> `* `role_based_access_control_enabled` - (Optional) ... Defaults to `true`. **Changing this forces a new resource to be created.**`

출력 쪽 원문(Attributes Reference):

> `* `kube_admin_config` - ... This is only available when Role Based Access Control with Azure Active Directory is enabled **and local accounts enabled**.`

⚠️ **`local_account_disabled = true` + 잘못된 `admin_group_object_ids` = 클러스터 접근 불가.**
`kube_admin_config`(브레이크글래스 경로)가 그 조합에서 사라진다. vnet 라운드 0-6의 교훈
(*"기본값이 어떤 경로의 트래픽도 바꾸지 않게 한다"*)이 그대로 적용되는 자리다.

### 0-9. Workload Identity는 스위치 두 개이고 기본값이 서로 다르다

> `* `oidc_issuer_enabled` - (Optional) Whether to enable the OIDC issuer feature. **Defaults to `true`.**`
> `* `workload_identity_enabled` - (Optional) Specifies whether Azure AD Workload Identity should be enabled for the Cluster. **Defaults to `false`.**`

출력: `* `oidc_issuer_url` - The OIDC issuer URL that is associated with the cluster.`

### 0-10. 아웃바운드 경로는 `vnet` 모듈의 NAT Gateway와 맞물린다

> `* `outbound_type` - (Optional) ... Possible values are `loadBalancer`, `userDefinedRouting`,
> `managedNATGateway`, `userAssignedNATGateway` and `none`. **Defaults to `loadBalancer`.**`

`modules/azure/vnet/main.tf`는 `nat_routed = true`인 그룹의 서브넷에
`azurerm_subnet_nat_gateway_association`으로 NAT를 붙인다. 즉 `vnet`이 이미 만든 NAT를 쓰려면
`outbound_type = "userAssignedNATGateway"`가 대응 값이다.

⚠️ **다만 이 조합의 완전한 요구사항을 확인하지 못했다 — 0-16을 본다.**

### 0-11. private 클러스터 + BYO private DNS zone은 role assignment 순서 의존을 만든다

provider 문서가 예제로 직접 못박은 내용 원문:

> *"If you use BYO DNS Zone, the AKS cluster should either use a User Assigned Identity or a service
> principal ... with the `Private DNS Zone Contributor` role and access to this Private DNS Zone.
> If `UserAssigned` identity is used - **to prevent improper resource order destruction** - the
> cluster should depend on the role assignment"* (예제가 `depends_on = [azurerm_role_assignment.example]`을 씀)

관련 인자(둘 다 ForceNew):

> `* `private_cluster_enabled` - ... Defaults to `false`. Changing this forces a new resource to be created.`
> `* `private_dns_zone_id` - ... Either the ID of Private DNS Zone ..., `System` to have AKS manage this or `None`. Changing this forces a new resource to be created.`

### 0-12. API 서버 접근 제한 인자

> `* `api_server_access_profile` - (Optional) An `api_server_access_profile` block as defined below.`

블록 원문(전체 3개 인자):

> `* `authorized_ip_ranges` - (Optional) Set of authorized IP ranges to allow access to API server`
> `* `subnet_id` - (Optional) The ID of the Subnet where the API server endpoint is delegated to.`
> `* `virtual_network_integration_enabled` - (Optional) Whether to enable virtual network integration for the API Server. Defaults to `false`.`

`modules/aws/eks-cluster`의 `endpoint_public_access`/`public_access_cidrs` 쌍과 대응하나 **형태가
다르다** — AKS는 public/private 토글이 `private_cluster_enabled`(ForceNew) 하나이고, EKS처럼
public·private를 독립적으로 켜고 끄지 않는다.

### 0-13. AKS에는 네이티브 삭제 보호 인자가 없다

`azurerm_kubernetes_cluster` **최상위 인자 58개**(문서의 Arguments Reference에서 첫 블록 정의
직전까지)를 전수 확인했고 삭제 보호에 해당하는 인자가 **없다**. 더 강한 판정으로,
문자열 `deletion_protection`은 **이 문서 전체에 0건**이다(대소문자 무시 검색).
`modules/aws/eks-cluster`가 쓴 AWS 네이티브 `deletion_protection`(`variables.tf:66`)의 대응물이
없으므로, `modules/azure/vnet`처럼 `lifecycle { prevent_destroy }`가 유일한 수단이다.

### 0-14. AKS의 "애드온"은 맵이 아니라 **개별 타입 블록**이다 — `addons.tf`의 문제 자체가 없다

`modules/aws/eks-cluster/addons.tf` 서두가 밝힌 그 파일의 존재 이유:

> *"이 파일이 푸는 문제는 하나다: **OpenTofu 변수 default는 전체 대체**라는 것. 소비자가 addon
> 하나를 추가하려고 맵을 넘기면 기본 addon이 통째로 사라지고, 누락분은 in-place 삭제된다."*

AKS에는 `map(object)` 형태의 addon 입력이 없다. 확인한 것만 나열하면 `azure_policy_enabled` ·
`key_vault_secrets_provider` · `oms_agent` · `ingress_application_gateway` · `web_app_routing` ·
`monitor_metrics` · `workload_autoscaler_profile` · `microsoft_defender` ·
`open_service_mesh_enabled` · `http_application_routing_enabled` · `aci_connector_linux` ·
`service_mesh_profile` · `storage_profile` · `image_cleaner_enabled` · `confidential_computing` ·
`ai_toolchain_operator_enabled` — **전부 개별 bool 또는 개별 블록**이다.

파생 결론 둘:
1. **"누락 = 삭제" 함정이 없다.** baseline merge 로직이 필요 없다.
2. **addon 버전 핀 개념이 없다.** `addons.tf`의 「버전 소유 경계」 절(`most_recent = false`,
   `addon_version`을 소비 루트가 소유)에 대응하는 축이 Azure에는 존재하지 않는다.

### 0-15. Node Auto Provisioning은 `node_provisioning_profile`이고, Karpenter의 Azure 대응이다

> `* `default_node_pools` - (Optional) Specifies whether default node pools should be provisioned automatically. Possible values are `Auto` and `None`. Defaults to `Auto`.`
> `* `mode` - (Optional) Specifies the provisioning mode for node pools created in this cluster. Possible values are `Auto` and `Manual`. **Defaults to `Manual`.** At least one of `mode` or `default_node_pools` must be specified.`

`modules/aws/eks-cluster`의 `enable_karpenter`(IAM 전제조건 생성)와 개념이 대응하나 **구현
위치가 다르다**: AWS는 별도 서브모듈 + IAM 리소스 뭉치이고, Azure는 클러스터 리소스의 블록 하나다.

### 0-16. ⚠️ 아래 세 가지는 **규정하지 않는다.** 구현 라운드에서 실측한 뒤 정한다

1. **`node_provisioning_profile`이 실제로 필수인지.** provider 문서가 **자기모순**이다 —
   최상위 인자 목록은 `(Required)`로 적었는데(76행), 같은 문서의 첫 예제는 이 블록을 **쓰지
   않고**(30~48행), 블록 정의(981행)는 두 인자가 **둘 다 Optional에 기본값이 있다**고 적었다.
   ⛔ 어느 쪽 읽기로도 설계하지 않는다. 구현 라운드에서 핀한 provider 버전으로 `tofu validate`를
   실제로 돌려 판정한다.
2. **flat(Pod Subnet) 모드에서 아웃바운드가 어떻게 성립하는지.** 두 가지를 확인하지 못했다.
   (a) `outbound_type = "userAssignedNATGateway"`가 서브넷 association 외에 무엇을 더 요구하는지 —
   provider 문서는 `nat_gateway_profile` 블록이 *"can only be specified when `load_balancer_sku`
   is set to `standard` and `outbound_type` is set to `managedNATGateway` or
   `userAssignedNATGateway`"* 라고만 적었고, 그 블록의 두 인자
   (`idle_timeout_in_minutes`·`managed_outbound_ip_count`)는 **관리형** 경로용으로 읽힌다.
   (b) **Pod 서브넷에도 `nat_routed = true`가 필요한지** — flat 모드에서는 Pod가 VNet IP를
   직접 갖는다(0-4·0-21). 노드 서브넷의 NAT association이 Pod 트래픽까지 덮는지, 아니면 Pod
   서브넷에 별도 association이 필요한지 확인하지 못했다.
   🔴 **(b)는 축 10의 산출물(어느 그룹에 무슨 플래그를 켜라고 안내할지)을 직접 바꾼다.**
3. ~~**`vnet_subnet_id`에 라우팅 테이블이 정말 필요한지.**~~ ✅ **v3에서 해소됐다 — 0-26을 본다.**
   UDR 요구는 **kubenet 전용**이고 Azure CNI에는 적용되지 않는다. 배포된 소비 repo root는 옳다.
   ⚠️ **이 항목이 v2의 "최대 판돈 미결"이었다.** Critic이 *"이미 Microsoft Learn을 조회했으면서
   이 항목만 안 봤다"* 고 지적했고 정확했다 — 확인 비용은 문서 한 번 조회였다.
   **교훈**: *"규정하지 않는다"* 는 확인 비용이 실제로 클 때만 정직하고, 싼 확인을 안 한 것을
   가리는 데 쓰면 P3의 오용이다.

### 0-17. ⚠️ 애드온 블록별 기본값·플랫폼 기본 활성 여부를 확인하지 않았다

0-14가 확인한 것은 *"애드온이 맵이 아니라 개별 블록이다"* 까지다. 각 블록을 켰을 때/껐을 때
AKS 플랫폼이 무엇을 기본 제공하는지(예: Disk/File CSI 드라이버가 `storage_profile` 없이도 도는지)는
**확인하지 않았다.** 축 7이 *"0.1.0은 애드온을 열지 않는다"* 로 가는 근거는 이 미확인 자체이지,
"플랫폼이 다 해준다"가 **아니다.**

### 0-18. ⚠️ AVM 모듈의 내용을 열어 보지 않았다

`mcp__opentofu__search-opentofu-registry` 실측: `azure/avm-res-containerservice-managedcluster`가
**존재하고 최신 버전은 `v0.8.2`** 다. 확인한 것은 존재와 버전뿐이다 — 변수·출력·리소스 구성은
열어 보지 않았다. 축 8의 판정은 **버전대(`0.y.z`)와 리소스 개수 구조**만 근거로 삼고,
"AVM이 무엇을 못 한다"는 종류의 주장은 하지 않는다.

### 0-19. CNI Overlay는 서브넷·VNet·RG 이름에 63자 상한을 얹는다

> *"If you're using your own subnet to deploy the cluster, the names of the subnet, the virtual
> network, and the resource group that contains the virtual network must be **63 characters or
> fewer**. These names are used as labels in AKS worker nodes."*

실측 대조: 소비 repo가 실제로 만드는 이름은 `vnet-demo-hub-krc-main`(22자) ·
`snet-demo-hub-krc-aks-node`(26자)이고(`env = hub`), RG는 주입값이다. **현행 포맷은 여유가 크다.**
⚠️ 이 제약은 **Overlay 절**에 실렸으나 이름 길이 논거 자체는 모드와 무관하다.

### 0-20. CAF 약어 실측

Microsoft CAF `resource-abbreviations` 원문 행:

| Resource | Resource provider namespace | Abbreviation |
|---|---|---|
| AKS cluster | `Microsoft.ContainerService/managedClusters` | `aks` |
| AKS system node pool | `Microsoft.ContainerService/managedClusters/agentPools` (mode: `System`) | `npsystem` |
| AKS user node pool | `Microsoft.ContainerService/managedClusters/agentPools` (mode: `User`) | `np` |
| Managed identity | `Microsoft.ManagedIdentity/userAssignedIdentities` | `id` |

🔴 **다만 `npsystem`·`np`는 이 카탈로그에 등재할 수 없다**(0-27 실증). CAF가 권장 약어를 준다는
것과 이 저장소의 검증기가 그것을 받아들인다는 것은 별개다. 축 1이 이 충돌을 처리한다.

⚠️ **`entapp`은 이 축의 연결점이 아니다.** `azure.md` 개정 이력이 밝힌 `entapp`의 등재 근거는
`azuread_application`(GitHub Actions **OIDC 배포 신원**)이다. AKS의 컨트롤 플레인·kubelet 신원은
`Microsoft.ManagedIdentity/userAssignedIdentities`이고 CAF 약어가 `id`로 따로 있다.
둘은 다른 리소스 타입이다 — 과제 질문 2의 *"`entapp` 등재 배경과의 연결"* 에 대한 답은
**"연결되지 않는다"** 이다.

### 0-24. `azurerm_kubernetes_cluster_node_pool` 전수조사 (v2가 안 읽어서 생긴 구멍)

| # | 사실 | 파급 |
|---|---|---|
| a | `temporary_name_for_rotation` — *"Specifies the name of the temporary node pool used to cycle the node pool when one of the relevant properties are updated."* **이것도 노드 풀 이름이라 0-1의 1-12자·하이픈 금지를 똑같이 받는다** | 축 1의 12자 예산을 **잠식한다.** v2의 validation(12자 전부 허용)은 이 이름이 들어갈 자리를 안 남겼다 |
| b | `vm_size` · `os_disk_size_gb` · `os_disk_type` · `max_pods` · `zones` · **`pod_subnet_id`** · `vnet_subnet_id` 등 변경 시 `temporary_name_for_rotation` **필수** | (a)의 수요가 실재한다 |
| c | 🔴 **`pod_subnet_id`는 클러스터 인자가 아니다** — `default_node_pool` 블록과 각 `azurerm_kubernetes_cluster_node_pool`의 **풀별 인자**다(최상위 인자 58개 목록에 없음, 0-13의 그 조사) | v2가 클러스터 단위 단일 입력처럼 썼다. **"모든 풀이 공유하는가 풀별로 다른가"** 를 계약이 정해야 한다 |
| d | 풀 순환은 *"it doesn't perform cordon and drain, and it will disrupt rescheduling pods currently running on the previous node pool"* | 서브넷 교체 = **cordon/drain 없는 순환**. ADR Consequences에 넣는다 |
| e | `os_type` — *"Possible values are `Linux` and `Windows`. Defaults to `Linux`."* · *"A Windows Node Pool cannot have a `name` longer than **6 characters**."* | 축 1이 12자(Linux)만 다뤘다. Windows 스코프를 명시해야 한다 |
| f | `mode` — *"Should this Node Pool be used for System or User resources? Possible values are `System` and `User`. Defaults to `User`."* | CAF의 `npsystem`/`np` 구분과 대응하는 실제 인자 |

### 0-25. `eks-reference-infra` 실물 대조 — v2의 축 3 정당화가 거짓이었다

v2는 *"이 저장소는 AWS 쪽에서 **이미 정확히 같은 구조**를 쓴다"* 고 적었다. **실물이 반증한다.**

| 실물 | 내용 |
|---|---|
| `modules/aws/eks-cluster/iam.tf` | `aws_iam_role` **2개** + `aws_iam_role_policy_attachment` **2개** + pod-identity 모듈 **4개**를 만든다(37·49·81·93·106·130·155·189행). **eks-cluster는 IAM을 실제로 만든다** |
| `modules/aws/eks-cluster/variables.tf` | 옵트인 IAM 토글 5개 중 **`enable_karpenter`의 default가 `true`**(376행). v2가 기각한 Option C 형태 그대로이며 심지어 기본 켬이다 |
| `eks-reference-infra/bootstrap/README.md` | 실행 Role 권한이 **`AdministratorAccess`** — hub·spoke 양쪽 다 |

🔑 **이것이 반론의 자기 반증이다**: AWS에서 모듈이 IAM을 만들어도 **권한 봉투가 안 넓어진다.**
실행 Role이 이미 Administrator라 더 넓힐 것이 없기 때문이다. 특권은 STS role-chaining으로
**입구 Role 뒤에 감춰져** 있다(입구 Role 권한은 `sts:AssumeRole` 하나뿐).

**Azure에는 그 완충층이 없다.** `aks-reference-infra/CLAUDE.md` 4절이 스스로 적었다:
*"Azure Entra ID에는 이 정확한 대응 개념이 없다"* — CI 신원이 특권 없는 얇은 신원이 아니라
**그 자체가 권한 보유자**이고, 6종 불변식이 방어 깊이를 대체한다.

⛔ **따라서 `cross-account-trust-role` 분리를 "권한 철학" 선례로 인용하면 안 된다.** 그 분리 사유는
**다른 계정에 리소스가 있다**는 소재 문제다. 축 3이 인용할 수 있는 것은 *"민감·저빈도와 일상·CI를
나눈다"* 는 **패턴의 형태**이지 *"AWS도 권한 때문에 그렇게 했다"* 가 아니다.

### 0-26. 🔴 라우팅 테이블 요구는 **kubenet 전용**이다 — 0-16-3 해소

Microsoft Learn `concepts-network-cni-overview`의 **기능 비교 표** 원문 행:

| Feature | Azure CNI Overlay | Azure CNI Pod Subnet | Azure CNI Node Subnet | Kubenet (legacy) |
|---|---|---|---|---|
| *"Deployment of a cluster in an existing or new virtual network"* | Supported | **Supported** | Supported | **Supported with manual user-defined routes (UDRs)** |

같은 문서의 **「AKS CNI networking prerequisites」** 목록을 전수 확인했고 **라우팅 테이블 요구
항목이 없다.** UDR은 kubenet 행에만 나타난다.

**판정**: provider 문서가 `vnet_subnet_id` 뒤에 조건 없이 붙인 *"A Route Table must be configured
on this Subnet."* 는 **kubenet 시대의 잔재**이며 Azure CNI에는 적용되지 않는다.
✅ **소비 repo의 `aks-node` 서브넷이 `route_table_enabled = false`인 것은 옳다. 고칠 필요 없다.**

같은 목록이 함께 확정한 것 넷:

| # | 원문 | 파급 |
|---|---|---|
| a | *"the cluster identity that the AKS cluster uses must have at least **Network Contributor** permissions on the subnet within your virtual network"* | 축 3의 bootstrap이 만들 role assignment가 **확정됐다**(추정이 아니다) |
| b | ⛔ 커스텀 역할로 좁히려면 그 역할에 **`Microsoft.Authorization/roleAssignments/write`** 가 *"Always when using a custom role"* 로 필요하다 | 🔴 **"Network Contributor가 넓으니 커스텀 역할로 좁히자"는 탈출구가 함정이다** — 커스텀 역할은 **클러스터 identity**에 그 권한을 쥐여 줘 subnet 스코프에서 스스로 역할을 부여할 수 있게 만든다(봉투가 내장 역할보다 넓어진다. CI 신원의 봉투는 어느 쪽이든 안 바뀐다 — role assignment는 bootstrap 소관이다). **내장 `Network Contributor`를 쓴다** |
| c | *"The subnet assigned to the AKS node pool **can't be a delegated subnet**."* | `vnet` 모듈 `subnet_groups`의 `delegations`를 AKS 서브넷에 **쓰면 안 된다** |
| d | 예약 CIDR **4종**(`169.254.0.0/16` · `192.0.2.0/24` · `172.30.0.0/16` · `172.31.0.0/16`)을 pod/service/VNet 대역에 쓸 수 없다 | 소비 repo의 `10.60.0.0/16`·`100.64.0.0/16`은 **저촉 없음**(실측 대조) |

> ℹ️ 같은 문서가 **Azure CNI Pod Subnet을 *"the recommended IPAM option for flat networking
> scenarios"*** 라고 적는다 — 0-21의 소비 repo 결정이 Microsoft 권고와도 일치한다.
> Windows 노드 풀도 Pod Subnet에서 **Supported**다(0-24-e의 스코프 질문이 유효한 이유).

### 0-27. Step 1이 검증기를 통과할 수 없었다 (실증)

`scripts/validate-abbreviations.py`를 읽어 확인한 규칙 셋:

| 행 | 규칙 |
|---|---|
| 83-84 | `len(abbr) > 7` → 에러 (등재 규칙 4) |
| 85-86 | 예시가 `^<약어>-` 로 시작하지 않으면 에러 |
| 127-129 | 개정 이력의 약어가 카탈로그 표에 없으면 에러(**우회 경로 차단**) |

**스크래치패드에서 v2 Step 1 사양대로 시뮬레이션한 결과**(저장소 무수정):

```
[ERROR] 117행 약어 `npsystem` — 길이 7자를 초과한다 (등재 규칙 4)
[ERROR] 117행 예시 `npsystem` 는 약어 `npsystem` 로 시작해야 한다
[ERROR] 118행 예시 `npapp` 는 약어 `np` 로 시작해야 한다
rc=1
```

두 번째·세 번째 에러가 **구조적**이다: 축 1의 판정 자체가 *"노드 풀 이름에 하이픈이 물리적으로
불가"* 인데(0-1), 검증기는 예시가 `<약어>-`로 시작할 것을 요구한다. **정직한 예시가 반드시
실패한다.** `st`(Storage Account)는 하이픈을 못 쓰지만 `st`가 **접두사**라 `st-...` 예시가
성립했다 — `npsystem`은 이름 **전체**라 그 탈출구가 없다.

**수정안(노드 풀을 카탈로그에서 빼고 `aks`·`id` 2종만 등재) 시뮬레이션**:

```
약어 카탈로그 SSOT 검사 통과 — 11개 · 5개 카테고리
rc=0
```

---

## 0-A. 소비 repo에서 이미 확정된 것 (실물 대조)

조회 대상: `/Users/a07326/born2k/ai/aks-reference-infra`(git repo, 이 세션이 직접 열어 확인).
⚠️ **팀 리드가 전달한 요약이 아니라 실물을 열어 대조했다**(P6). 아래는 그 파일의 원문이다.

### 0-21. 🔴 CNI 모드는 이미 확정됐다 — Azure CNI **Pod Subnet(flat)**, Overlay 미채택

출처: 커밋 `0100235`(2026-08-28) · `live/hub/networking/main.tf`의 `locals` 블록 주석 원문:

> *"CNI 모드는 Azure CNI **Pod Subnet(flat)** 을 기본으로 한다. Azure CNI **Overlay** 는
> 채택하지 않는다 — Overlay 는 성능은 flat 과 동급이지만(캡슐화 없음, MS 공식 문서 확인),
> 클러스터 밖으로 나가는 Pod 트래픽이 노드 IP로 SNAT 돼 NSG 플로우 로그·Network Watcher·
> 온프레미스 방화벽 로그에서 **Pod 단위 가시성이 사라진다.** AWS 원본이 VPC CNI(underlay,
> SNAT 없음)를 기본으로 하고 IP 고갈 시에도 이 가시성을 포기하지 않는(custom networking 으로
> 대응) 설계 철학과 어긋난다."*

🔑 **이 결정의 근거는 v1의 0-4가 이미 실측한 것과 정확히 같은 사실이다.** Microsoft 원문:
*"Communication with endpoints outside the cluster ... uses the node IP through network address
translation (NAT). Azure CNI translates the source IP (overlay IP of the pod) of the traffic to the
primary IP address of the node VM."* — v1은 이 문장을 **IP 계획**의 관점으로만 읽고
**관측성 손실**을 보지 못했다. 소비 repo의 판정이 더 정확하다.

### 0-22. 🔴 서브넷은 이미 배포됐고, Pod 서브넷만 의도적으로 비어 있다

같은 파일의 `subnet_groups`·`locals` 원문 실측:

| 항목 | 값 |
|---|---|
| VNet 주소 공간 | `["10.60.0.0/16", "100.64.0.0/16"]` — **secondary가 이미 붙어 있다** |
| `cidr_pod_dup` | `100.64.0.0/16`(RFC 6598). 주석: *"AWS 원본 cidr_dup 과 동일 대역 — Phase 2 AKS Pod Subnet 전용"* |
| `aks-node` 그룹 | `address_prefixes = ["10.60.16.0/20"]` · `nat_routed = true` · `nsg_enabled = true` |
| ⚠️ `aks-node`의 `route_table_enabled` | **설정하지 않음**(모듈 기본값 `false`) |
| Pod 전용 서브넷 | **없음** |
| 소싱 | `?ref=vnet-v0.2.0` |

Pod 서브넷을 아직 안 만든 이유가 주석에 명시돼 있다:

> *"⛔ 아직 하지 않은 것: Pod 전용 azurerm_subnet 자체는 만들지 않는다(Phase 2 AKS 모듈이
> 없어 소비자가 없다 — **소비자 없는 리소스를 미리 만들지 않는다**, .claude/rules/terraform.md).
> VNet 레벨 secondary CIDR **연결**만 지금 한다 — 이건 이 root(live/hub/networking) 가 소유한
> 리소스(azurerm_virtual_network)의 속성이라 Phase 2 를 기다릴 이유가 없다."*

같은 파일이 CIDR 계산의 소유권도 못박았다:

> *"CIDR (모듈 repo 규약: **계산의 소유는 모듈이 아니라 소비자 루트**)"*

✅ **`aks-node`의 `route_table_enabled = false`는 옳다** — v2는 이것을 "최대 판돈 미결"로
남겼으나 **v3에서 해소됐다**(0-26): UDR 요구는 kubenet 전용이다. **배포된 root를 고칠 필요가 없다.**

### 0-23. ⛔ 소비 repo의 CI 신원에 `roleAssignments/write`를 부여할 수 없다

출처: `aks-reference-infra/CLAUDE.md` 4절 원문:

> *"⛔ Phase 2에서 AKS 배포가 이 CI 신원에 `Microsoft.Authorization/roleAssignments/write`를
> 요구하게 되면, **자동으로 부여하지 않는다.** 그 권한이 부여되는 순간 CI 신원은 자기 자신에게
> 상위 역할을 부여할 수 있어 **이 설계 전체의 방어선이 무의미해진다.** 요구가 생기면 이 설계
> 자체를 재검토하는 트리거로 취급한다."*

같은 절이 밝힌 그 방어선의 실체:

> *"CI 신원(App Registration)의 권한을 리소스 그룹 하나로 좁히고 그 권한이 새어나가지 않는지
> **6종 불변식**(구독/디렉터리/Graph 권한·정적 자격증명·FIC 설정·그룹 멤버십이 전부 0건 또는
> 허용 목록과 완전 일치)으로 검증한다."*

🔴 **이것이 이 설계의 최상위 제약이다.** `azurerm_role_assignment`는 AKS에서 흔한 패턴
(kubelet identity의 ACR pull, BYO 서브넷의 `Network Contributor`, BYO private DNS zone의
`Private DNS Zone Contributor` — 0-6·0-7·0-11이 전부 이것을 부른다)이지만,
**이 모듈이 그 리소스를 하나라도 만들면 소비 repo의 CI 신원이 그 권한을 가져야 하고,
그 순간 6종 불변식이 무너진다.**

---

## 1. RALPLAN-DR 요약

### Principles

| # | 원칙 |
|---|---|
| **P1** | **Azure 리소스 모델에 맞춘다.** `eks-cluster` 인터페이스를 이식하지 않는다. 0-1·0-2·0-14가 이식이 물리적으로 불가능한 지점 셋이다 |
| **P2** | **문서는 소유자가 하나다.** 약어=`azure.md`, 포맷·태깅·핀=`conventions.md`, 연동=`module-catalog.md`, 기각=`decisions.md`, 입출력 상세=모듈 README |
| **P3** | **인용 없는 문장은 근거로 쓰지 않는다.** 확인 못 한 것은 **"규정하지 않는다"** 로 남긴다(0-16·0-17·0-18) |
| **P4** | **기본값이 소비자를 잠그지 않게 한다.** 0-8(브레이크글래스 소멸) · 0-5(ForceNew) 둘 다 잘못된 기본값의 대가가 비대칭인 자리다 |
| **P5** | **지금 요구를 채우는 가장 단순한 형태.** 단 kill switch·삭제 보호·교차변수 validation은 "추측 대비"가 아니라 재사용 자산의 현재 요구다(`.claude/rules/terraform.md`) |
| **P6** | **선례를 인용할 때는 실물을 열어 대조한다.** ⚠️ 특히 `vnet` ADR의 「AVM wrapper 기각」 근거(*"가장 안정된 계층이고 지식 밀도가 낮다"*)를 **AKS에 그대로 옮기지 않는다** — 축 8이 그 이유를 따로 세운다. 이 원칙을 **소비 repo 인용에도 적용했다**(0-A) |
| **P7** | **모듈이 소비 repo의 보안 불변식을 깨뜨릴 수 있다.** 재사용 모듈이 만드는 리소스는 소비자의 CI 신원이 **그 리소스를 만들 권한을 갖는다**는 뜻이다. 인터페이스뿐 아니라 **요구 권한**도 계약이다(0-23) |

### Decision Drivers (상위 3)

| # | 드라이버 | 왜 이것이 결정을 가르는가 |
|---|---|---|
| **D1** | 🔴 **소비 repo CI 신원의 권한 경계** | 0-23. 이 모듈이 `azurerm_role_assignment`를 하나라도 만들면 소비 repo의 **6종 불변식이 무너진다.** 0-6·0-7·0-11이 전부 role assignment를 부르는 자리라 이 드라이버가 축 3·2·6·11을 한꺼번에 가른다. **최상위 제약이다** |
| **D2** | **Azure가 강제하는 것과 이 저장소 규약이 충돌하는 지점** | 0-1(노드 풀 이름에 하이픈 불가)이 「이름은 모듈이 조합한다」 규약과 정면 충돌한다. 축 1이 전적으로 이 드라이버다 |
| **D3** | **틀린 기본값의 되돌리기 비용** | 0-5(`network_profile` ForceNew) · 0-8(브레이크글래스 소멸) · 0-11(ForceNew 2개). 축 4·5의 판정이 여기서 갈린다 |

> ⚠️ **v1의 D3(모듈/배포 루트 경계)는 사라진 것이 아니라 D1에 흡수됐다.** v1은 그것을
> *"경계가 맞는가"* 라는 설계 취향 문제로 다뤘는데, 0-23이 나온 뒤로는 **소비 repo의 검증된
> 보안 불변식을 깨는가**라는 훨씬 단단한 문제가 됐다. 같은 판정에 더 강한 근거가 붙었다.

### 실행 가능 옵션

> ℹ️ **축 번호는 v1의 것을 유지하고 신설 축(10·11)을 관련 축 옆에 끼워 넣었다** — 읽는 순서는
> 1·2·3·11·4·5·10·6·7·8·9다. 번호를 다시 매기면 v1을 읽은 사람의 인용이 전부 어긋난다.
> 축 11은 축 3과 드라이버가 같고(D1), 축 10은 축 5의 산출물을 직접 받는다.

#### 축 1: 노드 풀 이름을 어떻게 짓는가 (**0-1이 만든 축, D2**)

| | **Option A: 모듈이 `np`+그룹키로 조합, 길이 초과는 실패 (권고)** | Option B: 소비자가 이름 직접 지정 | Option C: 포맷 토큰을 붙이고 12자로 절단 |
|---|---|---|---|
| 동작 | 시스템 풀 = `npsystem` 고정, 사용자 풀 = `np<그룹키>`. `validation`이 `^[a-z][a-z0-9]{0,11}$`와 12자를 plan에서 판정 | `node_pools` 맵 키가 곧 이름. 모듈은 물리 제약만 검증 | `npdemoprdkrcsystem` → 앞 12자 |
| Pros | 「이름은 모듈이 조합한다」 규약을 **지킨다**. CAF 권장 약어(`npsystem`·`np`)와 정확히 일치(0-20). 잘림이 없다 | 가장 단순. 소비자가 기존 클러스터 이름과 맞출 수 있다 | 포맷을 형식적으로 유지 |
| Cons | 그룹 키가 10자를 넘으면 plan이 실패한다(**의도된 실패**) | ⛔ 규약 1번(*"소비자는 약어를 직접 쓰지 않는다"*)을 이 축에서 포기한다 | ⛔ **조용한 충돌**. 두 그룹 키가 절단 후 같아지면 이름이 겹치는데 plan이 안 잡는다. 배송 계약에 넣을 수 없다 |
| 판정 | **권고** | 기각 | **기각 — 조용한 실패** |

> **Option A의 원칙적 근거**(단순 우회가 아니다): 네이밍 포맷의 `workload`·`env`·`리전코드`
> 토큰은 **같은 스코프 안에서 이름을 구별하기 위한 것**이다. 0-1의 규칙표가 밝히듯
> `managedClusters/agentPools`의 스코프는 **managed cluster**이고, 클러스터 이름에 이미
> 그 세 토큰이 다 들어 있다(`aks-demo-prd-krc-main-01`). **노드 풀 이름에서 그 토큰들은 정보를
> 나르지 않는다.** Azure가 12자를 강제한 것과 그 토큰이 불필요한 것은 같은 사실의 두 얼굴이다.

##### 축 1b: 그 이름 계약을 **어디에 적는가** (🔴 v3 신설 — CRITICAL 해소)

축 1의 판정은 옳지만, v2는 그 산출물을 **약어 카탈로그**에 두라고 지시했고 **그 지시는 실행
불가능하다**(0-27 실증: rc=1, 에러 3건).

| | **Option A: 카탈로그에서 빼고 `conventions.md`가 소유 (권고)** | Option B: 검증기를 고쳐 예외를 판다 | Option C: 예시를 `npsystem-01`처럼 조작해 통과시킨다 |
|---|---|---|---|
| 동작 | 카탈로그에는 `aks`·`id` **2종만**. 노드 풀 이름 규칙은 `conventions.md`의 Azure 절이 산문으로 소유 | `validate-abbreviations.py`에 길이·예시 예외 분기 추가 | 표에 거짓 예시를 적는다 |
| Pros | ✅ **rc=0 실증됨**(0-27). **축 1의 논거와 정합한다** — *"부모 스코프가 이미 토큰을 나르므로 이 이름은 포맷의 대상이 아니다"* 면 **애초에 포맷 카탈로그의 항목이 아닌 것이 맞다.** Step 2가 이미 `conventions.md`를 열므로 **산출물 개수가 안 늘어난다** | 카탈로그에 CAF 약어가 다 실린다 | 검증기 무수정 |
| Cons | CAF가 주는 `npsystem`·`np`가 카탈로그에 없다(⚠️ `conventions.md`가 출처와 함께 적으므로 정보는 안 잃는다) | ⛔ **Must NOT Have 위반**(스크립트는 구현 라운드 스코프). ⛔ 검증기가 스스로 선언한 불변식을 약화시킨다 | ⛔ **거짓 문서다.** 실제 이름은 `npsystem`인데 표는 `npsystem-01`이라 적는다. 배송 계약에 둘 수 없다 |
| 판정 | **권고 — 실증 완료** | 기각 | **기각 — 거짓** |

> 🔑 **이 판정이 축 1을 약화시키지 않고 오히려 완성한다.** v2는 *"노드 풀 이름은 포맷의 예외"*
> 라고 판정해 놓고 그것을 **포맷 카탈로그에 등재**하려 했다 — 자기모순이었다. 검증기가 그
> 모순을 기계적으로 잡아낸 것이다.

##### 축 1c: 길이 예산과 Windows (v3 신설, 0-24-a·e)

| 항목 | 판정 |
|---|---|
| **사용자 풀 키 상한** | **8자 권고**(`np` + 8 = 10자). ⚠️ v2는 10자(총 12자)를 허용했는데, 그러면 `temporary_name_for_rotation`이 들어갈 자리가 **0자**다(0-24-a). 순환이 필요한 변경(`vm_size`·`os_disk_*`·`max_pods`·`zones`·서브넷 교체)에서 **apply가 막힌다** |
| **임시 풀 이름 규칙** | `<풀이름>t` 형태를 권고(10+1=11자 ≤ 12). 모듈이 조합할지 소비자가 넘길지는 **구현 라운드 판단** — 계약에는 **예산만** 못박는다 |
| **Windows 노드 풀** | ⛔ **`0.1.0` 스코프 밖.** 6자 한도(0-1)는 `np`+4자만 남겨 그룹 키가 사실상 무의미해지고, `os_type` 분기와 `windows_profile`·`outbound_nat_enabled`까지 딸려 온다(P5). ⚠️ **Azure CNI Pod Subnet에서 Windows는 Supported이므로**(0-26) 이것은 기술적 불가가 아니라 **의도적 스코프 결정**이다 |

🔴 **이 판정들은 `conventions.md`에 예외로 명시해야 한다.** 지금 그 문서는 포맷이 클라우드와
무관하게 같다고 단정한다(*"조합 방식과 구성 요소는 클라우드와 무관하게 같다"*, §2).
노드 풀은 그 단정의 **첫 반례**다. Step 2가 이 문장을 고치고 규칙을 함께 싣는다.

#### 축 2: 추가(user) 노드 풀을 이 모듈이 소유하는가

`default_node_pool`은 선택지가 없다(0-2 — 모듈이 소유한다). 판정 대상은 **추가 풀**이다.

| | **Option A: 이 모듈이 소유 (`azurerm_kubernetes_cluster_node_pool` for_each) (권고)** | Option B: 소비자/별도 모듈 |
|---|---|---|
| Pros | **소유 경계가 맞는다** — 그 리소스는 `kubernetes_cluster_id`를 요구하는데 그 ID는 이 모듈 소유다. `eks-cluster`의 `managed_node_groups`와 대칭 | 모듈이 얇아진다 |
| Cons | 변수 1개(맵) 증가 | ⛔ `vnet` 축 3에서 이미 같은 형태로 기각한 것이다 — association/자식 리소스가 모듈 소유 ID를 요구하면 소비자에게 떠넘길 때 경계가 어긋난다 |
| 판정 | **권고** | 기각 |

#### 축 3: 신원과 role assignment (**D1 — 확정된 결정, 게이트 아님**)

> 🔴 **이 축은 사용자와 논의해 확정됐다(2026-08-28).** 아래 표는 옵션 나열이 아니라
> **확정 결정과 그 대안의 기각 근거**다.

**결정**: **이 모듈은 `azurerm_user_assigned_identity`도 `azurerm_role_assignment`도 만들지
않는다.** 클러스터가 쓸 User-Assigned Managed Identity의 리소스 ID를 **입력 변수로만** 받는다
(`identity_id`, **필수 · `nullable = false`**). identity 생성과 그 identity에 필요한 role
assignment(BYO 서브넷의 `Network Contributor`, ACR 통합 시 `AcrPull` 등)는 이 모듈 스코프 밖이며,
소비 repo의 **`bootstrap/` 계층**(이미 사람이 수동 실행하는 IaC 밖 계층)이 처리한다.

| | **Option A: identity를 입력으로만 받는다 (확정)** | **Option E: `identity_name` + `data` 조회 (v3 신설)** | Option B: 모듈이 identity + role assignment 생성 | Option C: role assignment를 **옵트인 변수**로 분리 | Option D: system-assigned |
|---|---|---|---|---|---|
| 동작 | `identity_id`(리소스 ID) 필수 입력 | `identity_name`(+RG) 입력 → `data.azurerm_user_assigned_identity`로 조회 | 모듈이 만든다 | 만들되 기본 끔 | provider 기본값 |
| Pros | **CI 신원이 `roleAssignments/write`를 요구하는 질문 자체가 사라진다.** 순서 문제도 구조적으로 소멸 | 위와 같고 **추가로**: `conventions.md`:174의 **1순위 결합 방식**(*"결정적 네이밍 → `data` 조회"*)이다. 128자 ID를 안 나른다. **identity 부재가 plan에서 즉시 드러난다** | 소비자가 아무것도 미리 안 만들어도 된다 | 필요한 사람만 켠다 | 입력 0개 |
| Cons | ⚠️ identity가 없어도 **plan이 통과**한다(존재 검증 없음) | ⚠️ **kill switch와 충돌한다** — `cluster_enabled = false`인데 data 조회가 살아 있으면 파기가 막힌다(`eks-cluster/addons.tf`가 정확히 이 함정을 게이트로 처리한다). RG를 입력 하나 더 받아야 한다 | ⛔ **0-23의 6종 불변식이 무너진다** | ⛔ **미루기일 뿐이다** — 켠 소비자의 CI 신원은 결국 같은 권한이 필요하고, "켜면 보안 경계가 깨지는" 손잡이를 배송 계약에 넣게 된다 | ⛔ principal ID가 **생성 후에만** 알려져 사전 권한 부여가 구조적으로 불가능(0-6) |
| 판정 | **확정 (`0.1.0`)** | **기각하지 않음 — `v0.2.0` 후보**(아래) | 기각 | **기각** | **기각 — 구조적 불가** |

> **Option E 판정 근거**: 결론은 A와 같고(모듈이 identity를 안 만든다) **입력의 형태만** 다르다.
> 즉 A→E 전환은 **비파괴 확장**이다(입력 추가 + 기존 입력 optional화). 축 11이 이미 쓴 논리와
> 같다. `0.1.0`에서 A를 쓰는 이유는 **kill switch × data 조회 함정**을 이번 라운드에 설계·테스트할
> 근거가 없기 때문이고, 그 함정은 이 저장소가 이미 한 번 밟은 자리다.
> ⚠️ **E를 열면 `id` 약어가 실제로 값을 낸다** — 이름이 결정적이어야 조회가 성립하기 때문이다.
> 지금은 `id` 등재가 "소비 repo가 이름 지어 만든다"는 약한 근거에만 서 있다.

> **왜 이것이 회피가 아니라 설계인가** (🔴 v3에서 근거 문장 교체):
> **AWS와 Azure는 같은 철학을 공유하되 메커니즘이 다르다.** 철학은 *"인증하는 신원이 특권을 직접
> 갖지 않는다"* 이고, AWS는 STS role-chaining으로 특권을 **입구 Role 뒤에 감춘다**(입구 Role의
> 권한은 `sts:AssumeRole` 하나뿐, 실행 Role이 `AdministratorAccess`). Azure에는 그 대응 개념이
> 없어 **CI 신원이 권한을 직접 보유**하고, 6종 불변식이 방어 깊이를 대체한다(0-25).
> **그러므로 AWS에서 안전한 옵트인 IAM 토글이 Azure에서는 같은 안전성을 갖지 않는다.**
>
> ⛔ **v2의 문장은 거짓이었다**: *"AWS 쪽에서 이미 정확히 같은 구조를 쓴다."* `eks-cluster/iam.tf`는
> IAM role을 실제로 만들고, `enable_karpenter`는 기본값이 `true`인 옵트인 IAM 토글이다(0-25).
> `cross-account-trust-role` 분리의 실제 사유도 권한 철학이 아니라 **리소스가 다른 계정에 있다**는
> 소재 문제다. 이 축이 그 선례에서 빌려올 수 있는 것은 **"민감·저빈도와 일상·CI를 나눈다"는
> 패턴의 형태**뿐이다.
>
> **재검토가 열리는 조건**: Azure RBAC의 **ABAC role-assignment condition**으로
> `roleAssignments/write`를 *"이 특정 역할·이 특정 스코프에만"* 으로 좁힐 수 있음이 실측되면,
> Option C를 다시 검토한다. 그때는 "미루기"가 아니라 실제 봉투 축소가 되기 때문이다.

**파급**:
- `identity_id`는 **필수 · `nullable = false`**다(`.claude/rules/terraform.md`의 판정 기준:
  default가 없는 필수 변수).
- 모듈은 `identity { type = "UserAssigned", identity_ids = [var.identity_id] }`만 쓴다.
  ⚠️ 0-6 실측: *"Currently only one User Assigned Identity is supported."* — 리스트지만 1개다.
- **kubelet 신원은 `0.1.0`에서 입력으로 열지 않는다**(축 11에서 따로 판정).

**⚠️ 이 결정이 남기는 죽은 경로 — 정직하게 적는다** (v3 신설, `.claude/rules/terraform.md`의
*"죽은 경로를 남기지 않는다"* 가 이 축에 걸리는 지점):

`identity_id`는 받았는데 그 identity에 **서브넷의 `Network Contributor`가 없으면**(0-26-a가
필수로 확정) 클러스터는 서고 **노드가 서브넷에 붙지 못한다.** 모듈은 이것을 plan에서 잡을 수 없다 —
role assignment가 이 모듈 밖에 있기 때문이다.

| | 판정 |
|---|---|
| 선례 | AWS는 이 종류를 모듈이 막는다 — `enable_external_dns_iam` 없이 addon만 켜는 죽은 경로를 `eks-cluster`가 plan에서 거부한다(`variables.tf`의 교차변수 validation) |
| 왜 여기서는 못 막는가 | 그 선례가 성립한 이유는 **모듈이 양쪽을 다 소유**했기 때문이다. 이 축은 한쪽(role assignment)을 의도적으로 밖에 뒀으므로 **plan 시점 검증 수단이 원리적으로 없다** |
| `0.1.0`의 대응 | ⛔ **강제하지 않는다.** `module-catalog.md`가 **순서와 필요 권한을 명시**하고, ADR Consequences가 이 죽은 경로를 **결과로 기록**한다 |
| `v0.2.0` 후보 | Option E(`data` 조회)를 열면 **identity 존재**는 plan에서 잡힌다. ⚠️ 다만 **role assignment 유무는 여전히 못 잡는다** — data 조회는 존재만 확인하고 권한은 확인하지 않는다. 과대 약속하지 않는다 |

> ⚠️ **순서를 문서에 못박는다**(0-11이 실측한 순서 의존과 같은 종류):
> **① identity 생성 → ② 서브넷에 `Network Contributor` 부여 → ③ 클러스터 생성.**
> ②를 건너뛰면 ③이 성공하고 노드만 실패하므로 **실패가 조용하다.**
> ℹ️ Azure RBAC 전파 지연이 있어 ②와 ③ 사이에 간격이 필요할 수 있다 — 이 저장소가 실측하지
> 않았으므로 **지연 값을 규정하지 않는다.**

#### 축 11: kubelet 신원을 `0.1.0`에 넣는가 (**0-7 · D1**)

| | **Option A: `0.1.0` 제외, `v0.2.0`으로 명시 이월 (권고)** | Option B: 축 3과 같은 형태로 optional 입력 |
|---|---|---|
| 동작 | 주입하지 않는다. AKS가 노드 RG 안에 자동 생성한다(0-7). 모듈은 `kubelet_identity_object_id`를 **출력**한다 | `kubelet_identity_id` optional 입력(default `null`) |
| Pros | **실수요가 없다** — 소비 repo에 ACR이 아직 없다(`azure.md` 등재 약어가 `rg`·`st`·`entapp` 3종뿐이고 `cr`이 없다는 것이 그 방증). *"소비자 없는 리소스를 미리 만들지 않는다"* 는 소비 repo가 **Pod 서브넷에 방금 적용한 바로 그 원칙**이다(0-22) | ACR 시나리오가 한 번의 apply로 닫힌다 |
| Cons | ACR이 필요해지면 소비자가 출력 → role assignment → 재apply의 2단계를 돈다 | ⚠️ 노드 RG **밖**의 kubelet 신원은 컨트롤 플레인 신원에 `Managed Identity Operator` role을 **추가로** 요구한다(0-7) — bootstrap 부담이 늘고, 쓰지도 않을 입력을 배송 계약에 넣는다(P5) |
| 판정 | **권고** | 기각(**`v0.2.0` 후보**) |

> 🔑 **출력을 먼저 내 두는 것이 계약을 지킨다.** `kubelet_identity_object_id`를 `0.1.0`부터
> 출력하면, 나중에 optional **입력**을 추가해도 그것은 비파괴 변경이다. 지금 닫아 두는 비용이
> 나중에 여는 것을 막지 않는다.

#### 축 4: Entra ID / RBAC 기본값 (**0-8, D3**)

| | **Option A: Entra 통합 옵트인 · `local_account_disabled` 기본 `false` (권고)** | Option B: Entra 통합 기본 켬 + 로컬 계정 기본 끔 | Option C: Entra 통합을 노출하지 않음 |
|---|---|---|---|
| 동작 | `entra_admin_group_object_ids`가 비면 블록 자체를 만들지 않는다. 켜면 `azure_rbac_enabled = true` | 항상 켜고 로컬 계정도 끈다 | provider 기본(로컬 계정 전용) |
| Pros | **잠금이 기본 동작이 아니다.** 브레이크글래스(`kube_admin_config`)가 살아 있다. 켜는 것은 소비자 판단 | 가장 안전한 최종 상태 | 인터페이스가 가장 작다 |
| Cons | 안전한 상태로 가려면 소비자가 켜야 한다 | ⛔ **object ID 하나만 틀려도 클러스터 접근이 끊긴다**(0-8). 배송 계약에서 apply 성공과 접근 가능이 갈린다 | ⛔ 재사용 자산이 기업 신원 통합 경로를 아예 제공하지 않게 된다 |
| 판정 | **권고 — 착수 게이트 G2** | 기각 | 기각 |

> ⚠️ `role_based_access_control_enabled`는 **노출하지 않는다.** 기본 `true`이고 ForceNew이며,
> `false`로 갈 이유가 재사용 자산에 없다(0-8).
> 🔴 **G2로 두는 이유**: *"보안 기본값을 어디까지 강제하는가"* 는 가치 판단이고, `vnet` G2(NSG
> 기본 생성)와 같은 종류다. 그때처럼 계획이 권고만 하고 확인을 받는다.

#### 축 5: CNI 모드 (**0-3·0-4·0-5·0-21, D3**) — 🔴 **v1에서 권고가 뒤집혔다**

소비 repo가 **Azure CNI Pod Subnet(flat)** 을 확정했다(0-21). 남은 판정은
*"Overlay를 그래도 손잡이로 열어 둘 것인가"* 하나다.

| | **Option A: flat 고정, Overlay 미노출 (권고)** | Option B: flat 기본 + Overlay 옵트인 | Option C: Overlay 기본 (**v1의 권고 — 철회**) | Option D: kubenet 포함 |
|---|---|---|---|---|
| 동작 | `network_plugin = "azure"` 고정, `pod_subnet_id` **필수 입력** | `network_plugin_mode` 손잡이 + `pod_cidr` 분기 | overlay 기본 | provider 값 통과 |
| Pros | **분기 0개.** 지금 유일한 소비자가 명시적으로 거부한 모드를 계약에 넣지 않는다(P5). 0-21의 관측성 논거는 **고객사 취향이 아니라 이 저장소 전체의 설계 철학**(AWS 원본이 VPC CNI underlay를 쓰는 이유와 같다)이라 다른 소비자에게도 그대로 적용된다 | 다른 고객사가 IP 고갈로 Overlay를 요구하면 대응된다 | — | 제약 없음 |
| Cons | ⚠️ **Overlay가 필요해지면 클러스터 재생성이다**(0-5 ForceNew). 다만 그 수요는 IP 고갈 시나리오인데, 소비 repo는 이미 `100.64.0.0/16`(RFC 6598, 65,536 IP)을 **Pod 전용으로 떼 뒀다**(0-22) — AWS 원본이 IP 고갈에 custom networking으로 대응한 것과 같은 구조라 고갈 압력이 구조적으로 낮다 | 분기 2개 + `pod_cidr`/`pod_subnet_id` 상호배제 validation을 문서화·테스트해야 한다. **아직 아무도 요구하지 않았다** | ⛔ **0-21이 반증했다** — Pod 트래픽이 노드 IP로 SNAT돼 NSG 플로우 로그·Network Watcher에서 Pod 단위 가시성이 사라진다 | ⛔ **2028-03-31 은퇴**(0-3) |
| 판정 | **권고 — 착수 게이트 G-A** | 사용자 판단 대상 | **기각 — 철회됨** | **기각 — 은퇴 예정** |

> 🔴 **G-A로 두는 이유, 그리고 이 게이트가 왜 축 3과 비대칭인가**(v3에서 재작성):
> 이 저장소는 *"여러 실제 프로젝트에서 재사용"* 하는 자산이라(`CLAUDE.md`) **소비자 1명의 결정이
> 모든 소비자를 구속해도 되는가**는 계획이 일방적으로 닫을 문제가 아니다.
>
> ⚠️ **되돌리기 비용이 축 3과 정반대라는 것이 이 게이트를 남기는 진짜 이유다.**
>
> | | 나중에 여는 비용 |
> |---|---|
> | **Overlay(축 5)** | 🔴 **크다** — `network_profile`이 ForceNew라 기존 클러스터를 **재생성**해야 한다(0-5). 지금 안 열면 나중에 여는 것이 공짜가 아니다 |
> | **`identity_id` 완화(축 3 → Option E)** | **작다** — 입력 추가 + 기존 입력 optional화, **비파괴**다 |
>
> 그래서 축 3은 지금 좁게 닫아도 안전하지만 축 5는 그렇지 않다. 그럼에도 권고가 A(안 연다)인
> 이유는 *"요구가 생기면 그때 연다"*(`docs/decisions.md`의 internal ALB 선례)이고, **지금 열면
> 아무도 안 쓰는 분기 2개를 배송 계약이 영구히 진다**는 쪽이 더 무겁다고 판단했기 때문이다.
> **이 저울질 자체를 사용자에게 보인다.**
>
> ⚠️ **v1의 오독을 기록해 둔다.** v1은 0-4의 SNAT 문장을 **IP 계획**의 관점으로만 읽고
> **관측성 손실**을 보지 못해 Overlay를 기본으로 권고했다. 사실관계는 틀리지 않았고 **함의를
> 놓쳤다.** 이것은 `vnet` 라운드가 세 번 겪은 "검증 안 한 것을 근거로 씀"과는 다른 종류의
> 실패이지만, 결과는 같다 — **실측한 문장의 함의를 끝까지 따라가지 않으면 틀린 권고가 나온다.**

`network_plugin = "azure"` **고정**은 손잡이를 뺀 것이 아니라 은퇴 예정 값(`kubenet`)과 별도
제품 결정(`none` = BYO CNI)을 `0.1.0` 계약에 넣지 않는 것이다.
⚠️ 닫힌 열거를 **늘리는** 것이 아니라 **값을 고정**하는 쪽이라, `eks-cluster`의 `capacity_type`이
겪은 유지보수 부채와 성격이 다르다. 값이 늘어도 이 모듈은 안 늘린 상태로 계속 유효하다.

#### 축 10: Pod 전용 서브넷을 누가 만드는가 (**0-22 신설 축, D1**)

| | **Option A: `vnet` 모듈의 `subnet_groups`가 만들고, `aks-cluster`는 ID만 받는다 (권고)** | Option B: `aks-cluster`가 직접 만든다 |
|---|---|---|
| 동작 | 소비자가 `live/hub/networking`의 `subnet_groups`에 `aks-pod` 그룹을 추가. `aks-cluster`는 `node_subnet_id` · `pod_subnet_id` **둘 다 입력** | 모듈이 `azurerm_subnet`을 만든다 |
| Pros | **선례가 정확히 이것이다** — `vnet` 모듈은 예약 이름 서브넷조차 자기가 안 만들고 배포 루트에 미룬다(`docs/decisions.md`). **비용이 거의 0이다**: Pod CIDR(`100.64.0.0/16`)이 **이미** 그 root의 `address_space`에 붙어 있어(0-22) 그룹 한 항목만 추가하면 된다. **수명이 맞는다** — 서브넷은 네트워크 자산이라 클러스터보다 오래 산다 | 소비자가 서브넷을 미리 안 만들어도 된다. 모듈이 `max_pods` × 노드 수로 크기를 계산할 수 있다 |
| Cons | 소비자가 서브넷을 먼저 만든다(입력 1개 증가) | ⛔ **자기가 소유하지 않은 VNet 안에 서브넷을 만든다** — `vnet` 모듈이 RG를 안 만드는 것과 같은 경계 위반이다. ⛔ **CIDR 계산 소유권 규약과 정면 충돌**한다: 소비 repo가 *"계산의 소유는 모듈이 아니라 소비자 루트"* 라고 명시했다(0-22). ⛔ 클러스터를 파기하면 **Pod 서브넷도 함께 사라진다** — 재생성 시 대역이 흔들린다 |
| 판정 | **권고** | 기각 |

> **명시 답변**: Pod 서브넷 그룹 키는 `aks-pod`를 제안한다(기존 `aks-node`와 나란히 읽힌다).
> 서브넷 이름은 `vnet` 모듈이 `snet-<workload>-<env>-<리전>-aks-pod`로 조합한다.
> ⚠️ 그 그룹에 `nat_routed`가 필요한지는 **규정하지 않는다** — 0-16-2를 본다.

#### 축 6: 크로스 구독 확장을 이번 라운드에 넣는가

| | **Option A: 명시적으로 스코프 밖 (권고)** | Option B: 포함 |
|---|---|---|
| Pros | 🔴 **축 3이 이미 답을 강제했다.** 크로스 구독 신뢰는 **본질적으로 role assignment**다 — 이 모듈은 그것을 만들지 않기로 확정했으므로(D1·0-23), 이 축에는 애초에 만들 수 있는 리소스가 없다 | Azure 쪽도 패리티를 갖는다 |
| | ⛔ **설계 근거가 아직 없다.** AWS 쪽 크로스 계정은 `docs/architectures/eks-gitops-hub-spoke/choose-your-path.md` 질문 D라는 문서화된 결정을 구현한 것이다. Azure에는 대응 아키텍처 문서가 없다. 없는 요구를 발명하지 않는다 | |
| | **선례가 별도 모듈을 가리킨다** — AWS도 스포크 쪽은 `eks-cluster`가 아니라 `cross-account-trust-role`이라는 **별도 모듈**이 소유한다. 축 3의 "민감·저빈도 vs 일상·CI" 분리선과 **같은 선**이다 | |
| | **필요한 원시 재료는 이미 나간다** — `oidc_issuer_url` 출력 + `workload_identity_enabled`(0-9)가 향후 어떤 설계든 딛고 설 지점이다 | |
| Cons | Azure 쪽 허브-스포크가 필요해지면 별도 라운드가 필요하다 | ⛔ 아키텍처 결정 없이 IAM 경계를 설계하면 그 경계가 근거를 못 댄다. ⛔ **0-23의 불변식을 깬다** |
| 판정 | **권고** | 기각 |

> ℹ️ hub와 dev가 **별도 Azure 구독**으로 분리돼 있음을 확인했다. 그것이 크로스 구독 개념의
> 수요를 만들지만, **이 모듈이 그 수요를 채울 수 있는 리소스를 만들지 못한다**는 것이 위 판정의
> 핵심이다. 필요해지면 `cross-account-trust-role`의 Azure 대응물이 **별도 모듈**로 서고,
> 그 모듈은 bootstrap 계층처럼 CI가 아닌 경로로 apply된다.

#### 축 7: 애드온 (**0-14·0-17**)

| | **Option A: `addons.tf` 없음, 0.1.0은 애드온 블록을 열지 않는다 (권고)** | Option B: `eks-cluster` baseline 패턴 이식 | Option C: 블록 다수를 한 번에 노출 |
|---|---|---|---|
| Pros | **0-14가 밝힌 대로 풀 문제가 존재하지 않는다.** 실수요가 확인된 블록만 하나씩 연다(`decisions.md`의 *"요구가 생기면 그때 연다"* 패턴) | AWS와 인터페이스가 닮는다 | 기능이 많다 |
| Cons | 소비자가 애드온을 쓰려면 다음 마이너를 기다린다 | ⛔ **존재하지 않는 문제를 위한 코드**다. 맵도 없고 버전 핀도 없다(0-14) | ⛔ **각 블록의 기본 동작을 확인하지 않았다**(0-17). 검증 안 한 것을 배송 계약에 넣지 않는다(P3) |
| 판정 | **권고** | **기각 — 이식 대상 자체가 없다** | 기각 |

#### 축 8: facade(wrapper)인가 스크래치인가 (**P6**)

| | **Option A: 스크래치 얇은 모듈 (권고)** | Option B: AVM `avm-res-containerservice-managedcluster` wrapper |
|---|---|---|
| 근거 | **조립 대상이 없다.** AKS는 `azurerm_kubernetes_cluster` **1개** + 노드 풀 N개다. `terraform-aws-modules/eks/aws`가 값을 내는 이유는 클러스터·IAM role·정책·KMS·SG·addon·access entry를 **조립**하기 때문인데, 그 조립이 Azure에는 없다 | upstream이 AVM 인터페이스 규격을 따른다 |
| Cons | 직접 작성 | 정확 핀 관리 + upstream 변수 rename을 facade가 매번 번역해야 하는데, **번역해서 얻을 조립이 없다.** ⚠️ upstream이 `v0.8.2`(0-18 실측)라 그 번역 빈도가 높다 — 다만 이것은 **부차 논거다**(아래) |
| 판정 | **권고** | 기각 |

> 🔴 **`vnet` ADR의 AVM 기각 근거를 그대로 인용하지 말 것.** 거기 적힌 이유는 *"VNet·서브넷·NSG·NAT는
> Azure에서 가장 안정된 계층이고 지식 밀도가 낮다"* 인데, **AKS는 그 반대다** — provider 문서
> 스스로 *"Due to the fast-moving nature of AKS, we recommend using the latest version of the Azure
> Provider"* 라고 적는다. 안정성 논거는 여기서 성립하지 않는다. 이 축의 판정 근거는 **조립
> 대상의 부재와 upstream 버전대**이지 안정성이 아니다.
> ⚠️ 0-18대로 AVM 모듈의 **내용은 열어 보지 않았다.** 이 판정은 "AVM이 무엇을 못 한다"가 아니다.
>
> ⛔ **`0.y.z`를 주 근거로 쓰지 않는다**(v3 정정): 이 저장소는 **전 모듈이 `0.y.z`**이고
> *"버전 혼재는 결함이 아니라 정보"* 라고 스스로 선언했다(`CLAUDE.md`). 같은 기준을 upstream
> 기각 사유로 들면 자기 규약과 모순된다. 주 근거는 **조립 대상의 부재**이고, upstream 버전대는
> 그 위에 얹히는 **번역 빈도**의 서술로만 쓴다. `docs/decisions.md`에 실릴 기각표 행도 그렇게 쓴다.

#### 축 9: kill switch · 삭제 보호

| | **Option A: `cluster_enabled` + `deletion_protection`(`prevent_destroy`) (채택)** | Option B: 네이티브 삭제 보호 |
|---|---|---|
| 판정 | **채택** — `modules/azure/vnet`과 같은 형태. 교차변수 validation(`!(deletion_protection && !cluster_enabled)`)도 같다 | **기각 — 존재하지 않는다**(0-13) |

---

## 2. Guardrails

### Must Have

- **산출물은 문서뿐이다.** 범위: `docs/` **4개** + `.omc/` **2개**.
- 문서 전용이므로 **`main` 직접 커밋**. ⛔ PR을 쓰지 않는다(`CLAUDE.md` 브랜치·PR 규칙).
- `azure.md` 개정은 `scripts/validate-abbreviations.py`를 **무수정 통과**해야 한다.
  등재 시 **3곳을 함께 고친다**: ① 섹션 헤더 `(N)` ② 상단 총계 ③ 카운트 요약 표.
- ⚠️ `azure.md`는 400줄 예외이지 **em-dash 예외가 아니다**(`vnet` 라운드 0-15).
- **모든 사실 문장에 출처**(P3). 확인 못 한 것은 **"규정하지 않는다"**(0-16·0-17·0-18).
- **인수 조건은 범위를 먼저 잘라낸 뒤 판정한다.** 지시한 수정 건수와 인수 조건 건수를 맞춘다.
- ⚠️ **`★`를 `docs/` 산출물에 옮기지 않는다** — `scripts/validate-doc-conventions.py`가
  비표준 이모지로 rc=1을 낸다.
  🔑 **v2가 여기서 사실을 틀렸다**: `🔴`은 **허용 7종에 포함된다**(`validate-doc-conventions.py:23`
  `ALLOWED_EMOJI = {"✅","⏳","❌","⚠️","⛔","🔴","🔑"}` — 실측). v2는 `🔴`도 rc=1을 낸다고
  적었는데 거짓이고, 하필 **미판정 항목(0-16)에 저장소가 허용한 마커를 못 쓰게** 만드는
  자기 발등 찍기였다. P3를 계획 자신이 어긴 사례라 기록해 둔다.
  ⚠️ 다만 `docs/conventions.md` §5는 **산문 경고 등급을 `⚠️`·`⛔` 둘로** 제한한다 — 검증기가
  허용하는 집합(7종)과 문체 규약이 권하는 집합(2종)은 다르다. **산출물에는 2종만 쓴다.**
- **`docs/*.md`에 날짜·사건 서술을 쓰지 않는다.** 그것은 `.omc/notepad.md` 소관이다.

> ⚠️ **인수 조건의 성격을 세 가지로 구분해 적는다**(`vnet` 라운드 규율 그대로):
> ① **전환 가드**(기존 파일 대상) — 작업 전 실행해 **실패를 확인한 것만** 올린다.
> ② **회귀·존치 가드** — **작업 전 통과가 정상이다.** 표에 그 취지를 적는다.
> ③ **신규 대상** — 통과 방향을 원리적으로 관측할 수 없다. **산출물 생성 후 최초 실행 시 검증**한다.

### Must NOT Have

- ⛔ **`.tf` 생성 금지.** `modules/azure/aks-cluster/` 디렉터리도 만들지 않는다.
- ⛔ `.tflint.hcl` · `.githooks/*` · `verify.yml` 수정 금지(구현 라운드 스코프).
- ⛔ `docs/`에 새 문서 **종류** 신설 금지(P2). 기존 4개 문서에만 쓴다.
- ⛔ **`node_provisioning_profile`의 필수 여부를 어느 쪽으로도 단정 금지**(0-16-1).
- ⛔ **`entapp`을 AKS 신원의 연결점으로 서술 금지**(0-20). 다른 리소스 타입이다.
- ⛔ **`vnet` ADR의 AVM 기각 근거를 AKS에 재인용 금지**(축 8, P6).
- 🔴 ⛔ **이 모듈이 `azurerm_role_assignment` · `azurerm_user_assigned_identity`를 만든다고
  서술 금지**(축 3 확정, 0-23). **옵트인 변수 형태도 금지** — 켜는 순간 같은 문제가 재발한다.
- ⛔ **Overlay를 "권장 모드"로 서술 금지**(0-21). v1이 그렇게 적었고 철회됐다.
  ⚠️ **G-A가 뒤집히면 이 금지가 "Overlay를 기본값으로 서술 금지"로 좁혀진다**(게이트 분기표).
- ⛔ **Pod 서브넷을 이 모듈이 만든다고 서술 금지**(축 10).
- ⛔ **노드 풀 약어를 약어 카탈로그에 등재 금지**(축 1b, 0-27 실증). 검증기가 rc=1로 막는다.
- ⛔ **AKS 서브넷에 `delegations` 사용 금지**(0-26-c). *"can't be a delegated subnet"*.
- ⛔ **`Network Contributor`를 커스텀 역할로 대체 금지**(0-26-b) — 그 길이 **클러스터 identity**에
  `roleAssignments/write`를 쥐여 줘 subnet 스코프 권한 봉투를 내장 역할보다 넓힌다(CI 신원의
  봉투는 안 바뀐다 — 0-23이 금지하는 것은 CI 신원 대상이다).
- ⛔ **upstream 버전대(`0.y.z`)를 AVM 기각의 주 근거로 서술 금지** — 이 저장소 자신이 전 모듈
  `0.y.z`이고 *"버전 혼재는 결함이 아니라 정보"* 라고 선언했다. 주 근거는 **조립 대상의 부재**다.
- ⛔ **`eks-cluster`의 addon baseline 패턴을 "Azure에도 필요한데 아직 안 했다"로 서술 금지**
  — 대응 문제 자체가 없다(0-14).
- ⛔ 기존 약어 개명 금지. `modules/aws/*` · `modules/azure/vnet` 수정 금지.
- ⛔ `eks-reference-infra` · `aks-reference-infra` 수정 금지.

---

## 3. Task Flow

```
[확정 — 게이트 아님]
   축 3  신원·role assignment: 모듈이 만들지 않는다, 입력으로만 받는다 (2026-08-28 사용자 확정)
   축 5  CNI: Azure CNI Pod Subnet(flat) (소비 repo 커밋 0100235에서 확정)

[착수 게이트 — 사용자 확정 2건, 한 지점에서 함께 받는다]
   G-A  Overlay 를 손잡이로 열어 두는가            (권고: 열지 않는다)      -> Step 3·4
   G2   Entra 통합·로컬 계정 기본값                (권고: 옵트인/로컬 유지) -> Step 3·4
              |
              v
main 직접 커밋 (문서 전용, PR 없음)
  Step 1  azure.md — aks·id **2종만** 등재 (노드 풀 약어는 등재 불가, 0-27)
  Step 2  conventions.md — "클라우드와 무관하게 같다" 단정에 노드 풀 예외 신설
  Step 3  module-catalog.md — aks-cluster 연동 절 + vnet 연동 계약 + 소유 경계
  Step 4  decisions.md — 「Azure 컨테이너 (aks-cluster)」 ADR 등재
  Step 5  구현 라운드 착수 명세 + .omc/ 갱신
              |
              v
        [사용자 승인] -> 구현 라운드 (별도 승인 · 브랜치 -> PR)
```

> **v1의 G1이 사라졌다** — 축 3이 확정됐기 때문이다. 그 확정이 `id` 약어 등재도 함께 확정한다
> (배포 루트/bootstrap이 user-assigned identity를 **이름 지어** 만들어야 하므로).
> `rg`·`st`·`entapp`이 `aks-reference-infra` bootstrap을 위해 등재된 것과 **같은 선례**다.
> 두 게이트 모두 Step 3·4만 바꾸지만 **단일 커밋이라 한 지점에서 함께 받는다.**

#### 게이트 답이 뒤집히면 무엇이 바뀌는가 (v3 신설 — 게이트를 명목이 아니게 만든다)

⚠️ v2는 게이트를 선언해 놓고 **산출물 초안(기각표)에 이미 답을 확정 행으로 실었다.**
그러면 게이트가 형식이 된다. 분기를 명세한다.

| 게이트 | 권고대로면 | **뒤집히면** |
|---|---|---|
| **G-A** (Overlay) | Step 3 인터페이스 초안: `pod_subnet_id` **필수**. Step 4 기각표에 「CNI를 Overlay로」 행 존치 | Step 3: `network_plugin_mode` 손잡이 + `pod_cidr` 추가, `pod_subnet_id`를 **optional**로. Step 4: 그 기각표 행을 **삭제**하고 「Overlay를 기본값으로」만 기각으로 남긴다(기본은 여전히 flat). **Must NOT Have의 "Overlay 권장 모드 서술 금지"를 "Overlay를 기본값으로 서술 금지"로 좁힌다** |
| **G2** (Entra) | Step 3: `entra_admin_group_object_ids` optional, `local_account_disabled` 기본 `false`. Step 4 기각표에 「`local_account_disabled` 기본 `true`」 행 존치 | Step 3: `local_account_disabled` 기본 `true`로 뒤집고 **잠금 경고를 `⛔`로** 싣는다. Step 4: 그 기각표 행을 **삭제**하고 대신 「브레이크글래스를 남기는 기본값」을 기각으로 적는다 |

> 🔑 **기각표의 두 행에 `[G-A 확정 시]`·`[G2 확정 시]` 조건 표시를 달아 초안에 싣는다.**
> 게이트가 뒤집히면 그 행을 지우는 것으로 반영이 끝나게 만든다.

### 구현 라운드 착수 게이트 (범위 밖, 명세만)

| # | 항목 | 근거 |
|---|---|---|
| 1 | `.tflint.hcl`에 azurerm ruleset 정확 핀 (+ `pre-commit`에 `tflint --init`) | `vnet` 라운드에서 **명세만 하고 미실행**으로 남긴 항목이다. `.omc/plans/2026-08-26-azure-vnet-design.md`의 같은 표를 승계한다 |
| 2 | `.githooks/pre-commit`의 stale 태그 컴포넌트 목록에 `aks-cluster` 추가 | 없으면 미탐 |
| 3 | **`node_provisioning_profile` 필수 여부 실측** — 방법: 핀한 provider 버전으로 최소 설정을 `tofu validate` 실주행. ⚠️ 문서로는 판정 불가(0-16-1이 자기모순) | 0-16-1 |
| 4 | **flat 모드 아웃바운드 실측 (Pod 서브넷 NAT 포함)** — 방법: ① Learn `egress-outboundtype` 원문 확인 ② 그래도 불확실하면 dev 구독에 1회 apply. ⚠️ **`tofu validate`로는 판정 불가** — 런타임 도달성 문제라 plan이 원리적으로 못 잡는다 | 0-16-2. 축 10의 안내 문구를 바꾼다 |
| ~~5~~ | ~~`vnet_subnet_id`의 라우팅 테이블 요구 실측~~ ✅ **v3에서 해소** — UDR은 kubenet 전용 | **0-26** |
| 5 | **`temporary_name_for_rotation`을 모듈이 조합할지 소비자가 넘길지** — 방법: 순환이 실제로 도는 변경(`vm_size`)을 `tofu test`로 재현 | 0-24-a·b. 계약에는 **예산(8자)만** 못박았다 |
| 6 | **bootstrap 계층이 만들 identity·role assignment 목록 확정** | 축 3의 파급. ✅ **최소 집합은 0-26-a가 확정했다**(서브넷의 `Network Contributor`). ⛔ 커스텀 역할로 좁히지 않는다(0-26-b) |

---

## 4. Detailed TODOs

### Step 1 — `docs/naming/abbreviations/azure.md` 약어 등재

🔴 **v3에서 재작성됐다** — v2 사양은 검증기를 통과할 수 없었다(0-27 실증).

**대상**: `aks`(**A.5 Containers 신설**) · `id`(**A.4 Identity에 추가**) — **2종.**
⛔ **`npsystem`·`np`는 등재하지 않는다**(축 1b). 노드 풀 이름 계약은 **Step 2가 `conventions.md`에
싣는다.**

**정확한 산출물**(0-27의 통과 시나리오 그대로 — 이 형태로 rc=0을 실증했다):

| 위치 | 행 |
|---|---|
| A.5 Containers (1) 신설 | `\| Container \| AKS 클러스터 (`azurerm_kubernetes_cluster`) \| `aks` \| aks-demo-prd-krc-main-01 \|` |
| A.4 Identity (1→2) | `\| Managed Identity \| 사용자 할당 관리 ID (`azurerm_user_assigned_identity`) \| `id` \| id-demo-prd-krc-aks-01 \|` |
| 상단 총계 | `총 **9개**` → `총 **11개** 약어, 5개 카테고리` |
| 카운트 요약 표 | `A.4` 1→2 · `A.5 Containers 1` 행 추가 · 합계 `9`→`11` |
| 섹션 헤더 | `## A.4 Identity (1)` → `(2)` |

> **A.N 번호 모호성 해소**(Critic 지적): Containers는 **A.5**(뒤에 붙임)다. CAF 순서대로 삽입해
> Identity를 밀어내지 않는다 — 기존 섹션 번호를 바꾸면 다른 문서의 인용이 전부 깨진다.

**본문에 반드시 들어갈 것**:
- `id`는 **이 저장소의 모듈이 만들지 않는다** — 소비 repo의 bootstrap 계층이 만든다(축 3).
  등재 근거는 `rg`·`st`·`entapp`과 **같은 선례**(소비 repo가 이름 지어 만들 리소스)임을 밝힌다.
- 개정 이력 표에 날짜·근거 행 2개를 추가한다.
  ⚠️ 그 행에 **노드 풀 약어를 등재하지 않은 이유**를 한 줄로 남긴다(등재 규칙 4의 7자 한도와
  예시 형식 검사를 CAF의 `npsystem`이 동시에 위반한다 → `conventions.md`가 소유).
- ⛔ **`cr`(Container Registry)은 등재하지 않는다** — 축 11이 ACR을 `0.1.0` 스코프 밖으로 뺐고,
  `vnet` ADR의 *"약어는 실제로 만드는 리소스에 한정, 예측성 추가 금지"* 가 그대로 적용된다.
  ✅ 실측 근거: `aks-reference-infra`의 `.tf` 파일에서 `container_registry`·`acrpull` **0건**
  (히트 71건은 전부 `.terraform/` 벤더 CHANGELOG였다 — 축 11의 순환 논증을 실측으로 교체했다).

**인수 조건**

```bash
# [전환 가드] A1 — 작업 전 실패 확인 필요
/usr/bin/grep -c '`aks`' docs/naming/abbreviations/azure.md   # 작업 전 실측 0, 후 >=2 (표 + 이력)

# [전환 가드] A2 — 카운트 3곳 정합. 검증기가 세 값의 일치를 강제한다
# ✅ 이 정확한 산출물 형태로 스크래치패드에서 rc=0 실증 완료 (0-27)
python3 scripts/validate-abbreviations.py docs/naming/abbreviations/azure.md; echo "rc=$?"

# [전환 가드] A3 — id 가 등재됐다
/usr/bin/grep -c '`id`' docs/naming/abbreviations/azure.md      # 작업 전 실측 0, 후 >=2

# 🔴 [음성 가드] A3b 신설 — 노드 풀 약어가 카탈로그에 "들어가지 않았음"을 강제한다.
# 이것이 없으면 나중에 누군가 CAF 표를 보고 선의로 추가해 게이트를 깬다 (0-27).
/usr/bin/grep -c 'npsystem' docs/naming/abbreviations/azure.md  # 작업 전 0, 후에도 0

# [회귀 가드] A4 — 작업 전에도 통과가 정상. entapp 항목이 그대로다
/usr/bin/grep -c 'entapp' docs/naming/abbreviations/azure.md    # 작업 전 실측 2, 후 2 유지

# A5. 문서 게이트 4종 + em-dash 0건 (azure.md는 400줄 예외이나 em-dash 예외는 아니다)
python3 scripts/validate-doc-conventions.py; echo "rc=$?"
```

### Step 2 — `docs/conventions.md` — 노드 풀 예외 신설

**대상**: §2 「리소스 이름 포맷」의 단정 한 문장.

> 현재: *"조합 방식과 구성 요소는 클라우드와 무관하게 같다."*

0-1이 이 문장의 **첫 반례**다. 「Azure 강제 방식」 절에 항목을 신설해,
**스코프가 부모 리소스인 자식 리소스는 부모가 이미 나르는 토큰을 반복하지 않는다**는 규칙과
그 근거(Azure의 12자·하이픈 금지)를 적는다.

⚠️ **§2의 단정 문장은 "삭제"가 아니라 "한정"한다**(Critic 모호성 지적): *"클라우드와 무관하게
같다"* → *"리소스 그룹·구독 스코프 리소스에서는 클라우드와 무관하게 같다. 부모 리소스에 스코프된
자식 리소스는 예외이며 아래 provider 절이 소유한다."* 단정만 지우면 규칙이 사라진다.

🔴 **v3 추가 — 축 1b가 이 Step으로 넘긴 것**: 노드 풀 이름 계약 **전체**가 여기로 온다.
약어 카탈로그가 받을 수 없기 때문이다(0-27).

| 실을 것 | 내용 |
|---|---|
| 이름 형태 | 시스템 풀 `npsystem`, 사용자 풀 `np<그룹키>`. **하이픈 없음** |
| 물리 제약 | Azure: 1-12자(Linux) · 소문자+숫자 · 숫자로 시작 불가(출처 링크) |
| 길이 예산 | 그룹 키 **8자 이하** — `temporary_name_for_rotation`(순환용 임시 풀 이름)이 같은 한도를 쓰기 때문 |
| 출처 | CAF `npsystem`·`np` 권장 약어. ⚠️ **카탈로그에 등재하지 않은 이유**(7자 한도·예시 형식 검사)를 한 줄로 |
| Windows | ⛔ 6자 한도라 이 규칙이 성립하지 않는다. 지원 범위 밖임을 명시 |

**인수 조건**

```bash
# [전환 가드] E1 — 마크업 무관 판정. 단정이 한정된 형태로 바뀌었다
# ⚠️ v2는 "전 1, 후 0"(삭제)이었으나 한정으로 바뀌어 문자열이 남을 수 있다.
#    두 조건을 함께 본다: 무조건 단정이 사라지고, 예외를 가리키는 문장이 생겼다.
/usr/bin/grep -n '클라우드와 무관하게 같다' docs/conventions.md   # 작업 전 1건. 후: 한정어 동반 1건
/usr/bin/grep -c '스코프된\|부모 리소스에 스코프' docs/conventions.md  # 전 0, 후 >=1

# [전환 가드] E2 — Azure 강제 방식 절에 노드 풀 항목이 생겼다
/usr/bin/grep -c 'agentPools\|노드 풀' docs/conventions.md        # 작업 전 실측 0, 후 >=1

# [전환 가드] E2b 신설 — 길이 예산이 실렸다 (임시 풀 이름을 빠뜨리는 경로를 막는다)
/usr/bin/grep -c 'temporary_name_for_rotation' docs/conventions.md  # 전 0, 후 >=1

# [전환 가드] E2c 신설 — Windows 스코프 밖이 명시됐다
/usr/bin/grep -c 'Windows' docs/conventions.md                    # 전 0, 후 >=1

# [존치 가드] E3 — 작업 전에도 통과가 정상. Storage Account 하이픈 제약이 그대로다
/usr/bin/grep -c '하이픈' docs/conventions.md                     # 작업 전 실측 1, 감소하지 않는다

# E4. 400줄 이내 + 문서 게이트 4종 (작업 전 실측 291줄)
# 🔴 v3: 검증기 호출을 각 Step에 넣는다. v2는 A5(Step 1)에만 뒀는데,
#    그것은 Step 2~4 편집 이전 시점이라 이 Step의 산출물을 전혀 커버하지 않았다.
wc -l docs/conventions.md
python3 scripts/validate-doc-conventions.py; echo "rc=$?"
```

### Step 3 — `docs/module-catalog.md` — `aks-cluster` 연동 절

**대상**: `vnet` 절 뒤에 `aks-cluster` 절 신설.

**반드시 들어갈 것**(이 문서는 **모듈 간 연동만** 다룬다 — 입출력 상세는 README 소관):

| 항목 | 내용 |
|---|---|
| `vnet` → `aks-cluster` (노드) | `subnet_ids_by_group["aks-node"]` → `node_subnet_id` |
| `vnet` → `aks-cluster` (Pod) | `subnet_ids_by_group["aks-pod"]` → `pod_subnet_id`. **소비자가 `subnet_groups`에 그 그룹을 추가한다**(축 10). Pod 대역은 VNet의 secondary `address_space`에서 뗀다 |
| 아웃바운드 | `vnet`의 `nat_gateway_enabled` + `nat_routed = true` ↔ `outbound_type = "userAssignedNATGateway"`. ⚠️ 완전한 요구사항과 **Pod 서브넷의 `nat_routed` 필요 여부**는 **규정하지 않는다**(0-16-2) |
| 라우팅 테이블 | **불필요하다.** UDR 요구는 **kubenet 전용**이고 Azure CNI에는 적용되지 않는다(0-26). `vnet`의 `route_table_enabled`는 AKS 때문이 아니라 **운영 라우트(UDR 오버라이드)가 필요할 때만** 켠다 |
| ⛔ 서브넷 위임 | AKS 노드 풀 서브넷은 **위임된 서브넷일 수 없다**(0-26-c). `vnet`의 `subnet_groups`에서 그 그룹에 `delegations`를 쓰지 않는다 |
| NSG | `vnet`의 `nsg_enabled`로 만든 **빈 NSG는 안전하다** — AKS는 서브넷 NSG를 만들지도 수정하지도 않으며, 규칙을 얹을 때 **노드 CIDR 내부 트래픽 허용**을 보장하는 것이 소비자 책임이다(0-26) |
| 예약 CIDR | pod/service/VNet 대역에 `169.254.0.0/16` · `192.0.2.0/24` · `172.30.0.0/16` · `172.31.0.0/16`를 쓸 수 없다(0-26-d) |
| 신원 | **bootstrap 계층**이 user-assigned identity를 만들고 필요한 role assignment를 부여한 뒤, 그 리소스 ID를 `identity_id`(필수)로 넘긴다. **이 모듈은 둘 다 만들지 않는다**(축 3) |
| ⛔ 만들지 않는 것 | 리소스 그룹 · VNet · **모든 서브넷(Pod 서브넷 포함)** · **user-assigned identity** · **role assignment** · private DNS zone · 애드온 · 크로스 구독 신뢰 |
| `eks-cluster`와의 비대칭 | 별도 표 (아래) |

⚠️ **「만들지 않는 것」에 `role assignment`가 있는 이유를 한 줄로 적는다**: 재사용 모듈이 만드는
리소스는 소비자의 CI 신원이 그것을 만들 권한을 갖는다는 뜻이고, `roleAssignments/write`는
그 신원이 자기 자신에게 상위 역할을 부여할 수 있게 만든다.
⛔ 소비 repo 이름·불변식 개수 같은 **그쪽 내부 사정은 적지 않는다** — 이 문서의 독자는 모든
소비자다. 원리만 적는다.

🔴 **v3 신설 — 「인터페이스 초안」 서브섹션을 복원한다**(Critic M-1).

v2는 인터페이스를 13곳 확정해 놓고 그것이 실릴 자리를 어디에도 두지 않았다. Step 3이
*"이 문서는 모듈 간 연동만 다룬다"* 고 배제했고, Must NOT Have가 새 문서 종류를 금지했으며,
`.omc/plans/`는 `CLAUDE.md`가 요구하는 *"`docs/`에 승인된 설계"* 자리가 아니다
(`validate-doc-conventions.py:47`이 `.omc/`를 명시 제외한다 — 실측).

**선례가 정확히 이 형태다**: `vnet`도 `module-catalog.md`에 「인터페이스 초안」 서브섹션을 뒀다가
모듈 README가 생긴 뒤 제거했다. **README가 소유권을 넘겨받을 때까지의 임시 거처**다.

| 실을 것 | 값 |
|---|---|
| 필수 입력 | `naming` · `resource_group_name` · `location` · `identity_id` · `node_subnet_id` · `pod_subnet_id` |
| 선택 입력 | `purpose` · `serial` · `tags` · `cluster_enabled`(기본 `true`) · `deletion_protection`(기본 `false`) · `kubernetes_version` · `sku_tier` · `node_pools`(맵) · `entra_admin_group_object_ids` · `local_account_disabled`(기본 `false`) · `private_cluster_enabled` · `authorized_ip_ranges` · `service_cidr` · `dns_service_ip` · `workload_identity_enabled` |
| 출력 | `cluster_id` · `cluster_name` · `oidc_issuer_url` · `kubelet_identity_object_id` · `node_resource_group` · `fqdn`/`private_fqdn` (전부 null-safe) |
| ⚠️ 명시할 것 | **이 절은 모듈 README가 생기면 삭제한다** — 두 곳에 같은 계약을 두지 않는다(P2) |

⚠️ **`pod_subnet_id`는 풀별 인자다**(0-24-c). 계약을 명시한다:
**`0.1.0`은 전 노드 풀이 단일 Pod 서브넷을 공유한다**(모듈 최상위 입력 1개 → 모든 풀에 주입).
풀별 오버라이드는 **`v0.2.0` 이월** — 지금 열면 `node_pools` 맵 스키마가 서브넷 축까지 지고,
실수요가 없다(P5). ⚠️ 서브넷 교체는 순환을 부르므로(0-24-b) 나중에 여는 것도 비파괴다.

**`eks-cluster`와의 비대칭 표**(`vnet` 절의 「`vpc`와의 출력 비대칭」과 같은 형식):

| 축 | `modules/aws/eks-cluster` | `aks-cluster` | 사유 |
|---|---|---|---|
| 노드 풀 이름 | `eksn-<workload>-<env>-<리전>-<키>` | `np<키>` | 0-1: 하이픈 불가 · 12자 |
| 시스템 노드 풀 | 선택(`managed_node_groups = {}` 가능) | **필수** | 0-2 |
| 애드온 | baseline 맵 + merge + 버전 핀 | **없음** | 0-14 |
| 삭제 보호 | AWS 네이티브 | `prevent_destroy` | 0-13 |
| API 엔드포인트 | public·private 독립 토글 | `private_cluster_enabled` 하나(ForceNew) | 0-12 |
| 크로스 계정/구독 | 있음 | **없음(스코프 밖)** | 축 6 |
| IAM/role 리소스 | `iam.tf`가 role 2개·attachment 2개·pod-identity 모듈 4개를 만든다 | **하나도 만들지 않는다** | 축 3 (근거는 권한 봉투, 0-25) |
| Pod 네트워킹 | `pod_subnet_ids` 입력(custom networking) | `pod_subnet_id` 입력(**flat 고정**) | 축 5·10 |
| 노드 그룹 키 문자집합 | 제약 없음(`"system-01"` 등 하이픈 가능) | ⛔ **소문자+숫자만, 8자 이하, 숫자로 시작 불가** | 0-1·0-24-a |
| Windows 노드 | `ami_type`으로 지원 | ⛔ **`0.1.0` 스코프 밖**(6자 한도) | 축 1c |
| 서브넷 교체 | 노드그룹 롤링 교체 | **cordon/drain 없는 풀 순환** | 0-24-d |

**인수 조건**

```bash
# [전환 가드] C1 — 절 신설. 작업 전 0 확인함
/usr/bin/grep -c '^## `aks-cluster`' docs/module-catalog.md      # 전 0, 후 1

# 🔴 [존치 가드] C2 — v3에서 **방향을 뒤집었다**. 작업 전에도 통과가 정상이다.
# v2는 "Azure는 1개"를 "2개"로 고치라고 지시했는데 세 가지가 어긋난다:
#   ① Must NOT Have(modules/azure/aks-cluster/ 를 만들지 않는다)와 정면 충돌
#   ② vnet 선례는 이 자리를 존치 가드로 뒀고, 개수는 **릴리스 커밋**에서 바뀌었다
#   ③ 기존 5개 절이 전부 모듈 README 링크를 갖는데 aks-cluster 는 가리킬 README 가 없다
# 개수는 구현 라운드가 바꾼다. 이번 절에는 상태 한 줄("설계 확정 · 구현 미착수")을 적는다.
/usr/bin/grep -c 'Azure는 1개' docs/module-catalog.md            # 전 1, 후 1 유지

# [전환 가드] C2b 신설 — 새 절이 구현 미착수임을 명시한다 (README 링크 부재를 설명한다)
/usr/bin/grep -c '구현 미착수\|설계 확정' docs/module-catalog.md  # 전 0, 후 >=1

# [전환 가드] C3 — 미확인 항목이 "규정하지 않는다"로 적혀 있다 (추정으로 채우지 않았다)
# ⚠️ v3에서 0-16-3이 해소돼 미확인이 3건 -> 2건으로 줄었다.
/usr/bin/grep -c '규정하지 않는다' docs/module-catalog.md        # 후 >=1

# [전환 가드] C3b 신설 — 신원 순서와 필요 권한이 실렸다 (죽은 경로 안내)
/usr/bin/grep -c 'Network Contributor' docs/module-catalog.md    # 전 0, 후 >=1

# [전환 가드] C3c 신설 — 인터페이스 초안 서브섹션이 생겼다 (M-1)
/usr/bin/grep -c '인터페이스 초안' docs/module-catalog.md         # 전 0, 후 1

# [회귀 가드] C4 — 작업 전에도 통과가 정상. 하드코딩 semver를 늘리지 않는다.
# ⚠️ 작업 전 실측값이 0이 아니라 1이다 — 57행의 `eks-cluster-v0.8.0`(기존 문장, 이번 범위 밖).
# 기대값을 0으로 적으면 이 조건은 작업과 무관하게 실패해 검사 구실을 못 한다.
/usr/bin/grep -cE 'v[0-9]+\.[0-9]+\.[0-9]+' docs/module-catalog.md  # 전 1, 후 1 유지

# [존치 가드] C5 — 작업 전에도 통과가 정상. "배포 루트가 연결한다" 원칙 문장이 그대로다
/usr/bin/grep -c '배포 루트가 연결한다' docs/module-catalog.md    # 작업 전 실측 2, 감소하지 않는다

# C6. 400줄 이내 + 문서 게이트 4종 (작업 전 실측 160줄)
wc -l docs/module-catalog.md
python3 scripts/validate-doc-conventions.py; echo "rc=$?"
```

### Step 4 — `docs/decisions.md` — ADR 등재

**대상**: 「Azure 네트워킹 (vnet)」 절 **뒤**에 평면 `##` 절
「**Azure 컨테이너 (aks-cluster)**」 신설. 형식은 기존 절과 동일(기각 표 → 결정 → 파급 표).

**기각 표에 들어갈 안**(축별 기각안, 최소 12행):

| 하지 말 것 | 근거 절 |
|---|---|
| 노드 풀 이름을 포맷 토큰으로 조합하고 12자로 절단 | 축 1 Option C — 조용한 충돌 |
| 노드 풀 이름을 소비자가 직접 지정 | 축 1 Option B |
| 추가 노드 풀을 소비자에게 떠넘기기 | 축 2 Option B |
| **모듈이 user-assigned identity와 role assignment 생성** | 축 3 Option B — **소비자 CI 신원의 권한 경계를 깬다** |
| **role assignment 생성을 옵트인 변수로 분리** | 축 3 Option C — **미루기일 뿐 해소가 아니다.** 켜는 순간 같은 권한이 필요해지고, "켜면 보안 경계가 깨지는 손잡이"를 배송 계약에 넣게 된다 |
| system-assigned 컨트롤 플레인 신원 | 축 3 Option D — principal ID가 생성 후에만 알려져 **사전 권한 부여가 구조적으로 불가능** |
| identity 선택 입력(null이면 system-assigned) | 축 3 — `vnet` 축 2b와 동형 + 위 행과 같은 이유 |
| **[G2 확정 시]** `local_account_disabled` 기본 `true` | 축 4 Option B — 잠금 |
| `role_based_access_control_enabled` 노출 | 축 4 — ForceNew, 끌 이유 없음 |
| `kubenet` 노출 | 축 5 Option D — 2028-03-31 은퇴 |
| **[G-A 확정 시] CNI를 Overlay로 (기본이든 옵트인이든)** | 축 5 Option B·C — **Pod 트래픽이 노드 IP로 SNAT돼 Pod 단위 관측성이 사라진다.** AWS 원본이 VPC CNI underlay를 쓰는 설계 철학과 어긋난다 |
| **노드 풀 약어를 약어 카탈로그에 등재** | 축 1b — CAF의 `npsystem`이 등재 규칙 4(7자)와 예시 형식 검사를 **동시에** 위반한다. 검증기가 rc=1로 막는다 |
| 검증기에 노드 풀 예외 분기 추가 | 축 1b Option B — 검증기가 스스로 선언한 불변식을 약화시킨다 |
| 노드 풀 예시를 `npsystem-01`처럼 조작해 통과 | 축 1b Option C — **거짓 문서** |
| 그룹 키 상한을 12자로 | 축 1c — `temporary_name_for_rotation`이 들어갈 자리가 0자가 돼 순환이 필요한 변경에서 apply가 막힌다 |
| Windows 노드 풀 `0.1.0` 지원 | 축 1c — 6자 한도. **기술적 불가가 아니라 스코프 결정**이다 |
| `pod_subnet_id`를 풀별로 노출 | Step 3 — `0.1.0`은 전 풀 공유. 나중에 여는 것이 비파괴다 |
| 서브넷 `Network Contributor`를 **커스텀 역할로** 좁히기 | 0-26-b — 그 역할이 **클러스터 identity**에 `roleAssignments/write`를 쥐여 줘 봉투가 내장 역할보다 넓어진다(CI 신원 봉투는 안 바뀐다) |
| AKS 서브넷에 `delegations` 설정 | 0-26-c — *"can't be a delegated subnet"* |
| **`aks-cluster`가 Pod 서브넷 생성** | 축 10 Option B — 소유하지 않은 VNet에 서브넷을 만들고, CIDR 계산 소유권 규약과 충돌하며, 클러스터 파기 시 네트워크 자산이 함께 사라진다 |
| **kubelet identity 입력을 `0.1.0`에 포함** | 축 11 Option B — 실수요 없음. 노드 RG 밖 신원은 `Managed Identity Operator` role을 추가로 부른다 |
| 크로스 구독 확장 포함 | 축 6 Option B — **본질적으로 role assignment**라 이 모듈이 만들 수 없다 |
| `eks-cluster` addon baseline 패턴 이식 | 축 7 Option B — 대응 문제 부재 |
| AVM wrapper | 축 8 Option B — **조립 대상이 없다.** AKS는 클러스터 리소스 1개 + 노드 풀 N개이고, 커뮤니티 EKS 모듈이 값을 내는 이유인 다중 리소스 조립이 여기엔 없다. facade가 흡수할 upstream 번역 비용만 남는다 |
| AKS 네이티브 삭제 보호 사용 | 축 9 — 존재하지 않음 |

**「되살리면 안 되는 근거」 절에 추가할 행 2건**:

| 근거 | 무엇이 반증했나 |
|---|---|
| *"AVM 모듈은 안정된 계층이고 지식 밀도가 낮아서 기각했다"* | 그것은 **vnet의** 근거다. AKS는 provider 문서 스스로 *"fast-moving nature of AKS"* 라 적는 고속 churn 계층이다. AKS 축의 기각 근거는 **조립 대상의 부재**다 |
| *"`eks-cluster`가 IAM을 만드니 Azure 모듈도 role assignment를 만들어도 된다"* | AWS는 실행 Role이 **`AdministratorAccess`**이고 특권이 STS role-chaining으로 입구 Role 뒤에 감춰져 있어, 모듈이 IAM을 만들어도 **권한 봉투가 안 넓어진다.** Azure에는 그 완충층이 없어 CI 신원이 권한을 직접 보유한다. **같은 행위의 비용이 두 클라우드에서 다르다** |

⚠️ **축 8 기각 사유에서 upstream 버전번호를 빼는 이유도 함께 적는다**: 이 저장소 자신이
*"전 모듈 `0.y.z`, 버전 혼재는 결함이 아니라 정보"* 라고 선언했으므로(`CLAUDE.md`),
같은 기준을 upstream 기각 사유로 쓰면 **자기 규약과 모순된다.** 실질 근거는 조립 대상의
부재이고, `0.y.z`는 그 위에 얹히는 **번역 비용**의 서술일 뿐이다.

**인수 조건**

```bash
# [전환 가드] D1 — 평면 `##` 절이다 (`###`가 아니다). 작업 전 0 확인함
/usr/bin/grep -c '^## Azure 컨테이너' docs/decisions.md          # 전 0, 후 1

# 🔴 [전환 가드] D2 — v2의 awk 는 **항상 0을 낸다**(시작행이 종료 패턴에도 걸린다).
# 실증: 기존 절로 돌리면 v2 방식 0 vs 수정 방식 27. 즉 v2 조건은 통과 여부와 무관하게 무효였다.
awk '/^## Azure 컨테이너/{f=1;next} f&&/^## /{exit} f' docs/decisions.md \
  | /usr/bin/grep -c '^| '                                       # 후 >=18 (기각표 + 파급표)

# [전환 가드] D3 — 「되살리면 안 되는 근거」에 행이 2개 늘었다
# (구분자 행 `|---|`는 `| ` 로 시작하지 않아 세지 않는다 — 헤더 1 + 데이터 3 = 4가 작업 전 값)
awk '/^## 되살리면 안 되는 근거/,0' docs/decisions.md | /usr/bin/grep -c '^| '  # 작업 전 실측 4, 후 6

# 🔴 [존치 가드] D4 — 작업 전에도 통과가 정상. vnet 절의 AVM 기각 행을 손대지 않았다.
# ⚠️ v2가 기준값을 "1 유지"로 적었으나 **실측 2건**이다(decisions.md:75 기각행, :81 AzAPI 행의 참조).
# 잘못된 기준값은 작업과 무관하게 실패해 검사 구실을 못 한다.
/usr/bin/grep -c 'AVM 커뮤니티 모듈 wrapper' docs/decisions.md   # 작업 전 실측 2, 후 2 유지

# [전환 가드] D6 신설 — 축 8 기각 사유가 버전번호가 아니라 조립 대상 부재로 적혔다 (M-7)
awk '/^## Azure 컨테이너/{f=1;next} f&&/^## /{exit} f' docs/decisions.md \
  | /usr/bin/grep -c '조립'                                      # 후 >=1

# D5. 400줄 이내 + 문서 게이트 4종 (작업 전 실측 220줄)
wc -l docs/decisions.md
python3 scripts/validate-doc-conventions.py; echo "rc=$?"
```

### Step 5 — 구현 라운드 착수 명세 + `.omc/` 갱신

- 3절의 「구현 라운드 착수 게이트」 5건을 명세만 한다. **실행하지 않는다.**
- `.omc/notepad.md` Working Memory에 이 라운드 기록을 얹는다.
  ⚠️ Priority Context에는 **"Azure2(vnet·aks-cluster 설계 완료)"** 수준의 한 줄만 갱신한다
  (`notepad-sync` 규율 — Priority Context 비대화 전례가 있다).
- `.omc/plans/open-questions.md`에 이 계획 절을 append한다(아래 7절 내용).

**인수 조건**

```bash
# F1. notepad 갱신이 실렸다
git diff --cached --name-only | /usr/bin/grep -c '.omc/notepad.md'

# F2. 문서 전용 커밋이다 — .tf가 한 건도 없다
git diff --cached --name-only | /usr/bin/grep -cE '\.tf$'         # 0

# F3. modules/azure/aks-cluster/ 가 생기지 않았다
test ! -d modules/azure/aks-cluster && echo OK
```

---

## 5. Success Criteria

| # | 조건 | 판정 |
|---|---|---|
| 1 | `docs/` 4개 파일이 갱신되고 `.tf`가 0건 | Step 5의 F2·F3 |
| 2 | 🔴 `validate-abbreviations.py` 무수정 통과 — **`aks`·`id` 2종만 등재**했기 때문 | A2 (0-27에서 rc=0 실증) |
| 3 | **노드 풀 약어가 카탈로그에 들어가지 않았다**(음성 가드) | A3b |
| 4 | `validate-doc-conventions.py`가 **Step마다** 통과 | A5 · E4 · C6 · D5 |
| 5 | 400줄 규칙 위반 0건 | E4 · C6 · D5 |
| 6 | 미확인 **2건**(0-16-1·0-16-2)이 문서에 **"규정하지 않는다"** 로 남았다 | C3 |
| 7 | **인터페이스 초안이 `docs/`에 실렸다** — `.omc/plans/`는 승인된 설계의 자리가 아니다 | C3c |
| 8 | 신원 순서와 필요 권한(`Network Contributor`)이 실렸다 | C3b |
| 9 | 축 8의 판정이 `vnet` ADR 근거도 upstream 버전대도 주 근거로 쓰지 않는다 | D6 + 사람 판정 |
| 10 | 게이트 2건의 답이 뒤집혔을 때 바꿀 것이 명세돼 있다 | 3절 게이트 분기표 (사람 판정) |
| 11 | 문서 전용 `main` 직접 커밋 1개 | `git log` |
| 12 | `.omc/plans/open-questions.md`에 이 라운드 절이 append됐다 | Step 5 (⚠️ 기계 판정 아님 — 사람이 확인한다) |

---

## 6. ADR (`docs/decisions.md` 등재용 초안)

**Decision** — 두 번째 Azure 모듈 `aks-cluster`를 `modules/azure/aks-cluster/`에
**스크래치 얇은 모듈**로 설계한다. 시스템 노드 풀은 클러스터 리소스가 강제하므로 모듈이 소유하고,
추가 노드 풀도 같은 경계 논리로 모듈이 소유한다. 노드 풀 이름은 `np<그룹키>`로 조합하며
`workload`·`env`·`리전코드` 토큰을 쓰지 않는다.
**이 모듈은 신원도 role assignment도 만들지 않고 user-assigned identity의 ID를 필수 입력으로만
받는다.** 네트워킹은 **Azure CNI Pod Subnet(flat) 고정**이고 노드·Pod 서브넷을 둘 다 입력으로
받는다(둘 다 `vnet` 모듈이 만든다). Entra 통합은 옵트인이며 로컬 계정은 기본 유지한다.
애드온 블록 · kubelet 신원 입력 · 크로스 구독 확장은 `0.1.0`에서 제외한다. 버전은 `0.1.0`에서
시작한다.

**Drivers** — (1) **소비 repo CI 신원의 권한 경계** (2) Azure가 강제하는 것과 이 저장소 규약이
충돌하는 지점 (3) 틀린 기본값의 되돌리기 비용.
축 3·6·11은 D1이 갈랐고, 축 1·2는 Azure 리소스 모델이 답을 **강제**했으며, 축 4·5는 되돌리기
비용이, 축 7·8·10은 소유 경계와 "지금 요구를 채우는 가장 단순한 형태"가 갈랐다.

**Alternatives considered** — 4절 Step 4의 기각 표 25행.

**Why chosen** — 재사용 모듈이 만드는 리소스는 **소비자의 CI 신원이 그것을 만들 권한을 갖는다**는
뜻이다. `azurerm_role_assignment`를 만드는 모듈은 소비자에게 `roleAssignments/write`를 요구하고,
그 권한을 가진 신원은 자기 자신에게 상위 역할을 부여할 수 있다. AWS는 STS role-chaining으로
특권을 입구 Role 뒤에 감추지만 Azure에는 그 완충층이 없어 CI 신원이 권한을 직접 보유한다.
그래서 같은 행위(모듈이 권한 리소스를 만드는 것)의 비용이 두 클라우드에서 다르고, Azure에서는
identity 생성·권한 부여(민감·저빈도·수동)를 클러스터 생성(일상·CI)에서 **모듈 경계로 분리**했다.
`cross-account-trust-role`과 `eks-cluster`를 나눈 AWS 쪽 선례에서는 *"민감·저빈도와 일상·CI를
나눈다"* 는 **패턴의 형태**만 빌렸다 — 그 분리의 AWS측 사유(다른 계정 소재)와 이 분리의 사유
(CI 신원의 권한 봉투)는 다르다. 이 분리로 *"CI 신원이 그 권한을 가져야 하는가"* 라는 질문
자체가 사라진다.
네트워킹은 Pod 단위 관측성을 지키는 쪽(flat)을 골랐다 — Overlay는 성능이 동급이지만 Pod 트래픽을
노드 IP로 SNAT해 NSG 플로우 로그·Network Watcher에서 Pod를 식별할 수 없게 만든다.
노드 풀 이름은 물리 제약이 포맷을 배제했고, 절단은 조용한 충돌을 만들므로 스코프 논거로 토큰을
뺀 형태를 택했다.

**Consequences**
- `docs/conventions.md`의 *"조합 방식과 구성 요소는 클라우드와 무관하게 같다"* 단정이 깨진다.
  노드 풀이 그 첫 반례다.
- **`identity_id`가 필수 입력이다.** 소비자는 클러스터를 세우기 전에 identity와 그 role
  assignment를 별도 경로(수동/bootstrap)로 준비해야 한다. 이 모듈은 그것을 강제하지 못하고
  문서로만 안내한다. **system-assigned는 지원하지 않는다.**
- **Pod 전용 서브넷을 소비자가 먼저 만든다.** `vnet` 모듈의 `subnet_groups`에 그룹을 추가하는
  형태이며, Pod 대역은 VNet의 secondary `address_space`에서 뗀다.
- **Overlay가 필요해지면 클러스터를 재생성해야 한다**(`network_profile`이 ForceNew).
  `private_cluster_enabled` · `private_dns_zone_id`도 같다.
- ⚠️ **`identity_id`는 받았는데 그 identity에 서브넷 `Network Contributor`가 없으면 클러스터는
  서고 노드가 붙지 못한다.** role assignment가 모듈 밖이라 plan에서 잡을 수 없는 죽은 경로이며,
  문서가 순서(identity → role assignment → 클러스터)를 안내하는 것이 유일한 방어다.
- **노드 그룹 키가 소문자+숫자 8자 이하로 제한된다.** 다른 모듈의 그룹 키 관행(하이픈 포함)이
  여기서는 통하지 않는다. Windows 노드 풀은 `0.1.0` 지원 범위 밖이다.
- ⚠️ **서브넷·`vm_size`·`max_pods` 등을 바꾸면 노드 풀이 순환하는데, 그 순환은 cordon/drain을
  하지 않는다.** 실행 중 파드가 재스케줄로 중단된다. 임시 풀 이름이 12자 예산을 함께 쓴다.
- Entra 통합을 켜지 않은 클러스터는 로컬 계정 경로로 접근한다. 안전한 최종 상태로 가는 것은
  소비자 판단이다.
- 애드온과 kubelet 신원 입력이 필요해지면 다음 마이너를 기다린다.
- 두 가지(0-16-1 `node_provisioning_profile` 필수 여부 · 0-16-2 flat 모드 아웃바운드)를
  규정하지 않은 채 설계를 닫는다. 구현 라운드 착수 게이트 3·4가 그 부채다. 라우팅 테이블 요구는
  kubenet 전용임이 확인돼 배포된 소비 루트를 고칠 필요가 없다.

**Follow-ups** — 7절.

---

## 7. Follow-ups · `open-questions.md`에 실을 항목

`.omc/plans/open-questions.md`에 아래 절을 **append**한다(차단 범위를 반드시 명시).

```
## 2026-08-28-azure-aks-cluster-design - 2026-08-28

### 해소된 항목 (2026-08-28, 사용자·소비 repo 확정)

- ~~**G1. 컨트롤 플레인 신원을 user-assigned 주입으로 하는가**~~ **확정**: 모듈은 identity도
  role assignment도 만들지 않고 `identity_id`를 **필수 입력**으로만 받는다. system-assigned는
  원천 배제. 근거는 소비 repo CI 신원의 6종 불변식(0-23)과 AWS `cross-account-trust-role`
  분리 선례. `id` 약어 등재도 함께 확정
- ~~**CNI 모드**~~ **확정**(소비 repo 커밋 `0100235`): Azure CNI **Pod Subnet(flat)**.
  Overlay는 Pod 단위 관측성 상실을 이유로 미채택(0-21)

### 착수 게이트 (설계 라운드 Step 3·4를 막는다)

- [ ] **G-A. Overlay를 손잡이로 열어 두는가**
  차단 범위: **Step 3·4**. 권고는 **열지 않는다**(flat 고정). 이 저장소는 여러 프로젝트가
  재사용하는 자산이라 *"소비자 1명의 결정이 모든 소비자를 구속해도 되는가"* 가 실질 질문이다.
  열면 분기 2개를 영구히 지고, 안 열면 나중에 Overlay가 필요한 소비자는 클러스터를 재생성한다
- [ ] **G2. Entra 통합·로컬 계정 기본값**
  차단 범위: **Step 3·4**. 권고는 Entra 옵트인 + `local_account_disabled` 기본 `false`.
  더 강한 보안 기본값을 원하면 0-8의 잠금 위험을 수용하는 판단이 필요하다

### 해소된 항목 (2026-08-28 v3, 검토 반영 중 실측)

- ~~**`vnet_subnet_id`에 라우팅 테이블이 필요한지**~~ ✅ **해소**: UDR 요구는 **kubenet 전용**이다
  (0-26). 소비 repo의 `aks-node`(`route_table_enabled = false`)는 **옳고 고칠 필요 없다**.
  v2의 "최대 판돈 미결"이었고, 확인 비용은 Microsoft Learn 문서 **한 번 조회**였다

### 미결 (라운드를 막지 않음)

- [ ] **`node_provisioning_profile` 필수 여부** — 차단 범위: **구현 라운드**.
  provider 문서가 자기모순이다(0-16-1). `tofu validate` 실주행으로만 판정된다
- [ ] **flat 모드 아웃바운드: Pod 서브넷에도 `nat_routed`가 필요한지** — 차단 범위: **구현 라운드**.
  축 10의 안내 문구를 직접 바꾼다(0-16-2). ⚠️ `validate`로는 판정 불가(런타임 도달성)
- [ ] **`temporary_name_for_rotation`을 모듈이 조합할지 소비자가 넘길지** — 차단 범위:
  **구현 라운드**. 계약에는 예산(그룹 키 8자)만 못박았다(0-24-a)
- [ ] **Option E(`identity_name` + `data` 조회)로 전환할 것인가** — 차단 범위: **`v0.2.0`**.
  `conventions.md`:174의 1순위 결합 방식이고 identity 부재를 plan에서 잡는다. 다만 kill switch ×
  data 조회 함정을 설계·테스트해야 한다. **A→E는 비파괴 전환이라 지금 닫아도 손해가 없다**
- [ ] **`pod_subnet_id` 풀별 오버라이드** — 차단 범위: **`v0.2.0`**. `0.1.0`은 전 풀 공유(0-24-c)
- [ ] **Windows 노드 풀 지원** — 차단 범위: **`v0.2.0` 이후**. 6자 한도라 이름 규칙이 다시 갈린다.
  ⚠️ Azure CNI Pod Subnet에서 **기술적으로는 Supported**이므로(0-26) 스코프 결정이지 불가가 아니다
- [ ] **bootstrap 계층이 만들어야 할 identity·role assignment 목록 확정** — 차단 범위:
  **소비 repo Phase 2 착수**. ✅ 최소 집합은 확정됐다(서브넷의 내장 `Network Contributor`, 0-26-a).
  ⛔ 커스텀 역할로 좁히지 않는다 — 그 길이 `roleAssignments/write`를 부른다(0-26-b)
- [ ] **Azure RBAC ABAC condition으로 `roleAssignments/write`를 좁힐 수 있는가** — 차단 범위:
  **없음(조사 항목)**. 가능하다면 축 3 Option C 재검토가 열린다
- [ ] **kubelet 신원 입력을 열 것인가** — 차단 범위: **`v0.2.0` 이후**. ACR 실수요가 생기면
  연다(현재 소비 repo `.tf`에 ACR 참조 0건, 실측). 노드 RG 밖 신원은 `Managed Identity Operator`
  role을 추가로 부른다(0-7)
- [ ] **애드온 블록을 언제 무엇부터 여는가** — 차단 범위: **`v0.2.0` 이후**. 각 블록의 기본
  동작을 확인하지 않았다(0-17). 실수요가 확인된 것부터 하나씩, 확인 결과와 함께 연다
- [ ] **Azure 허브-스포크 GitOps 아키텍처 문서 신설 여부** — 차단 범위: **별도 라운드**.
  hub/dev가 별도 구독으로 분리돼 있어 수요는 존재하나, 축 6대로 이 모듈이 채울 수 없다.
  필요해지면 아키텍처 문서 → 별도 모듈 순서다
```

---

## 8. 이 계획이 스스로 지킨 규율 (검토자용 체크)

| # | 규율 | 이행 |
|---|---|---|
| 1 | 인용 없는 문장을 근거로 쓰지 않았다 | 0절 27개 항목 전부에 조회 경로·원문 |
| 2 | 확인 못 한 것을 추정으로 채우지 않았다 | 0-16(2건) · 0-17 · 0-18 |
| 3 | 선례를 실물로 대조했다 | `eks-cluster/main.tf:27`(노드그룹 이름) · `addons.tf` 서두 · `vnet/main.tf`(NAT association) · `vnet` ADR. **소비 repo도 요약이 아니라 실물을 열었다**(0-A: 커밋 `0100235` · `live/hub/networking/main.tf` · `CLAUDE.md` 4절) |
| 4 | 선례를 **잘못** 옮기는 경로를 막았다 | 축 8의 🔴 경고 · Must NOT Have 7건 |
| 5 | 옵션이 2개 이상이고 하나만 남은 축은 근거를 밝혔다 | 축 2·6·8·10·11은 2개, 나머지는 3~4개. 축 9는 Option B가 **존재하지 않음**을 0-13이 실측 |
| 6 | 사용자 판단이 필요한 것을 계획이 닫지 않았다 | G-A · G2 |
| 7 | **자기 오류를 숨기지 않았다** | v1의 Overlay 오독(축 5) · v2의 거짓 선례 인용(0-25) · v2의 🔴 이모지 사실 오류(Guardrails) · v2의 무효 인수 조건 3건(Step 4) 전부 본문에 기록 |
| 8 | **확정된 것과 미결인 것을 섞지 않았다** | 축 3·5는 「확정」으로 표시하고 게이트에서 뺐다. 게이트는 G-A·G2 둘뿐이고, **뒤집힐 때의 분기를 명세했다** |
| 9 | **인수 조건을 실제로 돌려 봤다** | Step 1은 스크래치패드에서 **양방향 실증**(v2 사양 rc=1 / 수정안 rc=0, 0-27). D2의 awk 버그도 기존 절로 실증(0 vs 27). 기준값 4개(C4·C5·D4·E3)를 실측으로 교체 |
| 10 | **"규정하지 않는다"를 남용하지 않았다** | v2의 최대 판돈 미결이 문서 한 번 조회로 해소됐다(0-26). **확인이 싼 것을 미판정으로 남기는 것은 P3의 오용**임을 0-16에 기록했다 |
| 11 | **AWS 소비 repo까지 열었다** | `eks-reference-infra`의 `bootstrap/README.md`가 v2 축 3 정당화를 반증했다(0-25). v2는 이 repo를 안 열어서 거짓 문장을 실었다 |
