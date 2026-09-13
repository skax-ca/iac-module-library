# 모듈 카탈로그

**읽는 사람**: 배포 루트에서 모듈을 호출하려는 사람.

모듈은 `modules/<provider>/<모듈명>/`에 둔다. 현재 등재된 것은 AWS 4개이고 Azure는 2개다.

핵심 세 모듈이 있고, 순서대로 의존한다. `vpc` -> `eks-cluster` -> `workbench`.
크로스 계정 시나리오에서만 쓰는 `cross-account-trust-role`은 이 체인과 독립적으로 존재하며
`eks-cluster`의 `access_entries`에 출력을 연결한다.

각 모듈의 입력·출력·리소스 전체 목록은 그 모듈의 README(terraform-docs 자동 생성, CI가 drift를
검사한다)가 소유한다. 이 문서는 **모듈 간 연동**만 다룬다: 어느 모듈이 무엇을 만들고, 어느
출력이 어느 모듈의 입력으로 들어가는지.

---

## 공통 규약

모든 모듈이 아래를 따른다.

| 입력 | 타입 | 뜻 |
|------|------|-----|
| `naming` | `{workload, env, region_code}` | `Name` 태그를 모듈이 조합한다. 소비자가 약어를 쓰지 않는다 |
| `purpose` | `string` | 이름의 용도 부분 (`main` · `web` · `worker`) |
| `tags` | `map(string)` | 거버넌스 태그는 provider `default_tags`로 넣는다. 여기엔 추가분만 |
| `<component>_enabled` | `bool` | kill switch. `false`면 아무것도 만들지 않는다 |

**이름 포맷**: `(리소스약어)-(workload)-(env)-(리전코드)-(purpose)-(일련번호)`
예: `vpc-demo-prd-an2-main` · `eks-demo-prd-an2-main-01`

리소스 약어는 [`naming/abbreviations/aws.md`](naming/abbreviations/aws.md)가 소유한다.
**없는 약어를 임의로 만들지 않는다.** 등재 후 쓴다.

---

## `vpc`

VPC · 서브넷 그룹 · NAT · 라우팅 · Flow Logs.

전체 계약(입력·출력·리소스) → [`modules/aws/vpc/README.md`](../modules/aws/vpc/README.md)

---

## `eks-cluster`

EKS 클러스터 · 노드그룹 · managed addon · IAM · Access Entry.
커뮤니티 모듈을 **wrapper로 감싼** 형태다. upstream 변수 rename을 내부에서 흡수한다.

전체 계약(입력·출력·리소스) → [`modules/aws/eks-cluster/README.md`](../modules/aws/eks-cluster/README.md)

> Karpenter·IAM 관련 출력이 **계층 1과 계층 2를 잇는 선**이다.
> 이 값들이 GitOps 저장소의 helm values로 들어간다.

### 크로스 계정 확장

허브 계정의 self-managed ArgoCD가 스포크 계정의 EKS에 접근하기 위한 입력·출력이다
([network.md](architectures/gitops-hub-spoke/aws/network.md)의 「허브를 어디에 두는가」가 정의한 IAM 경계를 구현한다, `eks-cluster-v0.8.0`부터).
허브 계정에서만 켠다. 스포크 쪽은 `cross-account-trust-role` 모듈이 소유한다.
변수·출력 전체는 위 README 링크를 본다.

⚠️ 이 변수들은 **IAM 경계만** 만든다. private-only 엔드포인트에서 허브가 스포크에 실제로
도달하려면 Transit Gateway가 **별도로** 필요하다(VPC Peering은 CIDR 3계층의 pod-dup 대역
재사용 설계와 구조적으로 충돌해 쓸 수 없다).
[network.md](architectures/gitops-hub-spoke/aws/network.md)의 「네트워크 경로」 절 참조.
이 모듈은 그 리소스를 만들지 않는다(재사용 모듈로 두지 않기로 한 이유도 그 절에 있다).

---

## `workbench`

private 클러스터를 조작하는 운영 지점. **인바운드 규칙이 하나도 없다.**
SSM Agent가 아웃바운드로 연결을 맺고 세션이 그 연결을 역방향으로 흐른다.

전체 계약(입력·출력·리소스·부여되는 IAM 권한·부팅 후 상태) → [`modules/aws/workbench/README.md`](../modules/aws/workbench/README.md)

### 클러스터 접근 3층: 누가 무엇을 소유하는가

| 층 | 무엇 | 소유 모듈 |
|:--:|------|----------|
| 1 | 주체 IAM (workbench Role) | **`workbench`** |
| 2 | EKS Access Entry | **`eks-cluster`** |
| 3 | cluster SG 인바운드 | **`eks-cluster`** |

`workbench`는 1층만 만들고 **자기 SG ID와 Role ARN을 출력**한다.
배포 루트가 그 둘을 `eks-cluster`의 `access_entries`와
`cluster_security_group_additional_rules`에 넘긴다.

> 모듈이 서로를 직접 참조하지 않는다. **배포 루트가 연결한다.**

---

## `cross-account-trust-role`

스포크 계정이 소유하는 크로스 계정 IAM 신뢰 Role 하나만 만드는 얇은 모듈. 허브의 특정 IAM
Role만 `sts:AssumeRole`을 허용하고, 그 밖의 AWS 권한은 전혀 붙이지 않는다. 실제 Kubernetes
권한은 스포크의 `eks-cluster` 모듈 `access_entries`가 결정한다(아래 「K8s 권한 부여 방식」
참조). `vpc`/`eks-cluster`/`workbench` 체인과는 독립적이며, 크로스 계정 시나리오
([network.md](architectures/gitops-hub-spoke/aws/network.md)에서 허브 분리를 택한 경우)에서만 쓴다.

전체 계약(입력·출력) → [`modules/aws/cross-account-trust-role/README.md`](../modules/aws/cross-account-trust-role/README.md)

> `role_arn`이 스포크의 `eks-cluster` 모듈 `access_entries`로 들어가는 연결선이다.
> 모듈이 서로를 직접 참조하지 않는다. 배포 루트가 연결한다(다른 모듈과 같은 원칙).

### K8s 권한 부여 방식: access policy 우선, RBAC는 세밀한 제어가 필요할 때만

`eks-cluster`의 `access_entries`는 이 Role에 K8s 권한을 주는 방식을 두 가지 제공한다. 선택
기준은 AWS 공식 문서(EKS 사용 설명서 "Associate access policies with access entries")를 그대로
따른다: **AWS 관리형 access policy로 요구가 충족되면 그것을 쓰고, 더 세밀한 범위 제어가
필요할 때만 RBAC로 내려간다.**

| 방식 | `access_entries` 필드 | 쓰는 경우 |
|------|----------------------|----------|
| 관리형 access policy | `policy_associations` | AWS가 제공하는 4개 정책(`AmazonEKSClusterAdminPolicy`·`AmazonEKSAdminPolicy`·`AmazonEKSEditPolicy`·`AmazonEKSViewPolicy`)으로 충분한 권한. GitOps 컨트롤러가 애드온·CRD 등 클러스터 스코프 리소스 전반을 다뤄야 하는 크로스 계정 ArgoCD 접근이 여기 해당한다. `workbench` access entry와 같은 패턴이다 |
| `kubernetes_groups` + K8s RBAC | `kubernetes_groups` | 네 정책 어느 것도 못 주는 세밀한 범위(특정 네임스페이스 조합·커스텀 verb 등)가 필요한 경우만. `ClusterRole`/`ClusterRoleBinding`은 이 모듈도 `eks-cluster`도 만들지 않는다. GitOps 저장소(`eks-platform-gitops`)가 소유한다 |

⚠️ access policy로 준 권한은 `kubectl auth can-i --list`에 나타나지 않는다. AWS 전용 API
(`aws eks list-associated-access-policies`)로만 조회된다. K8s 네이티브 도구로 권한을 감사해야
하는 클러스터라면 이 제약을 감안해 `kubernetes_groups`를 택한다.

---

## `vnet`

Azure 가상 네트워크 · 서브넷 그룹 · NAT · 옵트인 NSG · 옵트인 라우팅 테이블.
`modules/azure/vnet/`에 스크래치 얇은 모듈로 둔다. 리소스 그룹과 리전은 배포 루트가 주입한다.

전체 계약(입력·출력·리소스) → [`modules/azure/vnet/README.md`](../modules/azure/vnet/README.md)

**만들지 않는 것**: 리소스 그룹(주입) · NSG 룰(소비자가 얹는다) · Flow Logs(`0.1.0` 미포함) ·
예약 이름 서브넷.

Azure 예약 이름 서브넷(`AzureBastionSubnet` · `GatewaySubnet` · `AzureFirewallSubnet`,
확인한 것은 이 셋이며 더 있을 수 있다)은 이 모듈의 네이밍 계약과 충돌해 만들지 않는다.
배포 루트가 같은 vnet에 `azurerm_subnet`으로 직접 만든다.

### `vpc`와의 출력 비대칭

Azure 서브넷은 존(zone)에 속하지 않고 vnet당 NAT Gateway가 하나다. 이 차이가 출력 타입에
그대로 반영된다.

| 출력 | `modules/aws/vpc` | `vnet` | 사유 |
|---|---|---|---|
| `subnet_ids_by_group` | `map(list(string))` | `map(string)` | 서브넷에 존 축이 없다 |
| `route_table_ids_by_group` | `map(list(string))` | `map(string)` | 〃 |
| NAT | `nat_gateway_ids` `list(string)` | `nat_gateway_id` `string` | vnet당 1개 |

---

## `aks-cluster`

Azure Kubernetes 클러스터(AKS). 시스템 노드 풀(필수) · 추가 노드 풀(옵트인) · Karpenter(Node
Auto Provisioning, 옵트인, 기본 꺼짐). `modules/azure/aks-cluster/`에 둔다.

전체 계약(입력·출력·리소스) → [`modules/azure/aks-cluster/README.md`](../modules/azure/aks-cluster/README.md)

### `vnet`과의 연동

| 항목 | 내용 |
|---|---|
| 노드 서브넷 | `vnet`의 `subnet_ids_by_group["aks-node"]` → `node_subnet_id` |
| Pod 서브넷 | `cni_mode`에 따라 완전히 달라진다. 상세는 아래 「Pod 네트워킹, `cni_mode`별 VNet 구조」 절 참조 |
| 아웃바운드 | `vnet`의 `nat_gateway_enabled` + `nat_routed = true` ↔ `outbound_type = "userAssignedNATGateway"`. ⚠️ 완전한 요구사항과 Pod 서브넷에도 `nat_routed`가 필요한지는 규정하지 않는다(구현 라운드에서 실측) |
| 라우팅 테이블 | 불필요하다. UDR 요구는 kubenet 전용이고 Azure CNI에는 적용되지 않는다. `vnet`의 `route_table_enabled`는 AKS 때문이 아니라 운영 라우트(UDR 오버라이드)가 별도로 필요할 때만 켠다 |
| 서브넷 위임 | ⛔ AKS 노드 풀 서브넷은 위임된 서브넷일 수 없다. `vnet`의 `subnet_groups`에서 그 그룹에 `delegations`를 쓰지 않는다 |
| NSG | `vnet`의 `nsg_enabled`로 만드는 빈 NSG는 안전하다. AKS는 서브넷 NSG를 만들지도 수정하지도 않으며, 규칙을 얹을 때 노드 CIDR 내부 트래픽 허용을 보장하는 것은 소비자 책임이다 |
| 예약 CIDR | pod/service/VNet 대역에 `169.254.0.0/16` · `192.0.2.0/24` · `172.30.0.0/16` · `172.31.0.0/16`를 쓸 수 없다 |
| 신원 | bootstrap 계층이 user-assigned identity를 만들고 서브넷의 `Network Contributor` 등 필요한 role assignment를 부여한 뒤, 그 리소스 ID를 `identity_id`(필수)로 넘긴다. **이 모듈은 identity도 role assignment도 만들지 않는다** |

⚠️ 「신원」 행에서 role assignment를 이 모듈이 만들지 않는 이유: 재사용 모듈이 만드는
리소스는 소비자의 CI 신원이 그것을 만들 권한을 갖는다는 뜻이고, `roleAssignments/write`는
그 신원이 자기 자신에게 상위 역할을 부여할 수 있게 만든다.

⚠️ 순서 의존이 있다: identity 생성 → 서브넷에 `Network Contributor` 부여 → 클러스터 생성.
②를 건너뛰면 ③은 성공하고 노드만 조용히 실패한다. role assignment가 모듈 밖에 있어 plan
시점에 이 실패를 잡을 수 없다.

ℹ️ `identity_id`가 받는 권한은 이 `Network Contributor`(소비자가 명시적으로 부여) 외에
하나 더 있다(노드 리소스 그룹 `Contributor`, ingress Load Balancer·CSI 드라이버 등 관리
용도). 이 권한은 클러스터 생성 시 Azure가 자동으로 부여해 별도 조치가 필요 없다. 두 권한의 스코프·
용도 비교는 [`modules/azure/aks-cluster/README.md`](../modules/azure/aks-cluster/README.md)
「`identity_id`가 받는 권한은 두 종류다」 절을 본다.

**만들지 않는 것**: 리소스 그룹 · VNet · 모든 서브넷(Pod 서브넷 포함) · user-assigned
identity · role assignment · private DNS zone · 애드온 · 크로스 구독 신뢰.

### Pod 네트워킹, `cni_mode`별 VNet 구조

`aks-cluster`의 `cni_mode`(`pod_subnet`·`node_subnet`·`overlay`)는 클러스터 리소스의 필드
하나가 아니라, 그 값을 소비하는 `vnet` 루트의 **주소 공간 설계 자체**를 바꾼다. 세 모드가
요구하는 VNet 구조는 다음과 같이 서로 다르다.

| `cni_mode` | VNet `address_space` | `subnet_groups` | `aks-node` 사이징 |
|---|---|---|---|
| `"overlay"`(기본, 0.3.0부터) | primary 1개면 충분, secondary 불필요 | `aks-node`만 필요. Pod CIDR은 `aks-cluster`의 `pod_cidr` 변수로 직접 넘긴다(VNet 주소 공간과 무관) | 노드 수만 고려 |
| `"pod_subnet"`(0.1.0~0.2.0의 기본값) | primary + **secondary**(Pod 전용, RFC 6598 권장) 2개 필요 | `aks-node` + `aks-pod` 둘 다 필요 | 노드 수만 고려 |
| `"node_subnet"` | primary 1개면 충분, secondary 불필요 | `aks-node` 하나로 노드+Pod를 겸한다 | 노드 수 + Pod 수까지 고려(아래 계산식) |

**`node_subnet` 사이징 공식**(공식 문서,
[concepts-network-ip-address-planning](https://learn.microsoft.com/en-us/azure/aks/concepts-network-ip-address-planning)):
`(노드수+서지)+(노드수+서지)×max_pods`. 노드에서 Pod IP까지 함께 뜨므로 `pod_subnet` 모드보다
`aks-node` 서브넷을 크게 잡아야 한다.

**hub·dev(spoke) 간 값 공유 가능 여부는 모드마다 다르다.** `pod_subnet`은 Azure CNI Pod
Subnet이 크로스 VNet 트래픽에도 SNAT를 하지 않아 겹치는 순간 응답 라우팅이 깨진다. 그래서
`aks-reference-infra`의 hub(`100.64.0.0/16`)·dev(`100.65.0.0/16`)가 서로 다른 값을 쓴다.
`overlay`는 반대다. 클러스터 밖으로 나가는 Pod 트래픽을 전부 노드 IP로 SNAT하므로(공식 문서
확인) hub·dev가 **같은 pod CIDR을 재사용해도 된다**(공식 문서: "You can use the same pod CIDR
space on multiple independent AKS clusters"). `node_subnet`은 애초에 별도 Pod CIDR이 없어
이 질문 자체가 성립하지 않는다.

**관측성**: `pod_subnet`·`node_subnet`은 SNAT가 없어 NSG 플로우 로그·Network Watcher에서
Pod 단위 가시성이 유지된다. `overlay`는 Pod CIDR 밖으로 나가는 트래픽만 노드 IP로 SNAT돼
그 구간의 NSG 기반 가시성을 잃는다. 대신 AKS 유료 기능인 Advanced Container Networking
Services(ACNS, add-on이 아니라 `--enable-acns`로 켜는 클러스터 기능, 노드·시간당 과금)의 Container Network Observability가 eBPF로 Pod
identity를 SNAT 이전 지점에서 캡처해 이 손실을 다른 방식으로 메운다(NSG 플로우 로그의
완전한 대체재는 아니다, 저장 로그 모드는 Cilium 데이터플레인 전용이고, 기본 집계에서는
개별 Pod IP 대신 워크로드·네임스페이스 단위로 뭉친다). 전체 근거는
`modules/azure/aks-cluster/README.md`「네트워킹」절을 본다.

⚠️ **이 표는 소비자 root(`aks-reference-infra`)의 설계 문제이지 `vnet` 모듈의 계약 문제가
아니다.** `vnet`의 `address_space`(`list(string)`)·`subnet_groups`(`map(object)`)는 CNI를
전혀 모르고 개수·키 이름에 아무 제약이 없다(모듈 소스에 관련 `validation` 블록 자체가 없음,
실측 확인). 즉 `cni_mode`를 바꾸는 작업은 **소비 root(`live/hub/networking`·
`live/dev/networking`·`live/hub/aks`)만 고치면 된다**. `iac-module-library`의 `vnet` 모듈
자체는 태그를 새로 낼 이유가 없다.

⚠️ **`aks-reference-infra`의 hub·dev는 아직 옛 기본값(`pod_subnet`) 전제로 배선돼 있다.**
`live/hub/networking`·`live/dev/networking`이 이미 secondary `address_space`(hub
`100.64.0.0/16`, dev `100.65.0.0/16`)를 VNet에 붙여둔 상태다(`aks-pod` 서브넷 자체는
아직 안 만듦). `cni_mode` 기본값이 `"overlay"`로 바뀐 지금 이 secondary CIDR은 죽은
대역이 된다(지우지 않아도 안전하다, 아무 서브넷도 참조 안 함). 새로 `live/hub/aks`를
설계할 때 굳이 `cni_mode = "pod_subnet"`으로 명시해서 이 CIDR을 쓸 이유가 없다면 기본값
(`"overlay"`)을 그대로 두고 이 secondary CIDR 자체를 정리(제거)할지 남겨둘지(향후 Pod
Subnet 재검토 대비)는 그 repo 세션에서 판단할 문제다.

### `eks-cluster`와의 비대칭

| 축 | `modules/aws/eks-cluster` | `aks-cluster` | 사유 |
|---|---|---|---|
| 노드 풀 이름 | `eksn-<workload>-<env>-<리전>-<키>` | `np<키>` | Azure는 하이픈 불가 · 12자 한도 |
| 시스템 노드 풀 | 선택(비워 둘 수 있다) | 필수 | `default_node_pool`이 클러스터 리소스의 필수 구성요소다 |
| 애드온 | baseline 맵 + merge + 버전 핀 | 없음 | AKS는 애드온이 맵이 아니라 개별 블록이라 대응 문제 자체가 없다 |
| 삭제 보호 | AWS 네이티브 | `prevent_destroy` | AKS에는 네이티브 삭제 보호 인자가 없다 |
| API 엔드포인트 | public·private 독립 토글 | `private_cluster_enabled` 하나(변경 시 재생성) | AKS는 공개·비공개를 값 하나로 토글한다 |
| 크로스 계정/구독 | 있음 | 없음(스코프 밖) | 본질적으로 role assignment라 이 모듈이 만들 수 없다 |
| IAM/role 리소스 | 실제로 만든다(role·attachment·pod-identity) | 하나도 만들지 않는다 | 위 「신원」 행과 같은 이유(권한 봉투) |
| Pod 네트워킹 | `pod_subnet_ids` 입력(custom networking) | `cni_mode`로 선택(`overlay`·`pod_subnet`·`node_subnet`, 기본 `overlay`) | Microsoft 공식 권고가 Overlay를 일반 기본으로 명시한다(plan-pod-networking·AKS baseline). `pod_subnet`은 NAP 자체가 미지원(karpenter-provider-azure#1352)이라 기본에서 제외했다 |
| 노드 그룹 키 문자집합 | 제약 없음 | 소문자+숫자만, 8자 이하, 숫자로 시작 불가 | 노드 풀 이름 물리 제약 |
| Windows 노드 | 지원 | `0.1.0` 스코프 밖 | 이름 한도 6자 |
| 서브넷 교체 | 노드그룹 롤링 교체 | cordon/drain 없는 풀 순환 | AKS 노드 풀 순환의 동작 |

---

## `aks-workbench`

private AKS 클러스터의 운영 지점(kubectl·helm·argocd·az CLI·kubelogin이 설치된 지속적
작업대). AWS `workbench`의 Azure 대응 모듈이다. `modules/azure/aks-workbench/`에 둔다.

전체 계약(입력·출력·리소스) → [`modules/azure/aks-workbench/README.md`](../modules/azure/aks-workbench/README.md)

### `vnet`·`aks-cluster`와의 연동

| 항목 | 내용 |
|---|---|
| 배치 서브넷 | `vnet`의 `subnet_ids_by_group["<그룹키>"]` → `subnet_id` |
| 신원 | bootstrap 계층이 user-assigned identity를 만들고 `identity_id`(필수)·`identity_client_id`(조건부 필수)로 넘긴다. **이 모듈은 identity도 role assignment도 만들지 않는다**(`aks-cluster`와 같은 경계 원칙) |
| AKS 연동 | `aks_cluster_name`·`aks_resource_group_name`이 채워지면 kubeconfig를 부트스트랩한다. Entra RBAC를 쓰는 클러스터(`aks-cluster`의 `entra_admin_group_object_ids` 옵트인)면 `aks_entra_rbac_enabled = true` + `identity_client_id`가 함께 필요하다 |
| private DNS 해석 | workbench가 대상 AKS 노드와 다른 VNet(스포크)에 있으면 별도 `azurerm_private_dns_zone_virtual_network_link`가 필요하다(`aks-cluster`의 private DNS zone은 노드 VNet에만 링크된다). 상세는 모듈 README「아웃바운드」절 참조 |

**만들지 않는 것**: 리소스 그룹 · VNet · 서브넷 · user-assigned identity · role assignment ·
private DNS zone link · AKS 클러스터 자체.

### `workbench`(AWS)와의 비대칭

| 축 | `modules/aws/workbench` | `aks-workbench` | 사유 |
|---|---|---|---|
| 일상 운영 경로 | SSM Session Manager(대화형 + 인바운드 0 동시 성립) | SSH(`ssh_ingress_cidrs`) | Azure에는 SSM과 같은 조합을 주는 서비스가 없다(README「접속 모델」절) |
| "인바운드 0"의 성립 근거 | SG 기본이 전부 거부라 규칙 0개로 성립 | NSG 기본이 `AllowVNetInBound`로 이미 열려 있어, 명시적 Deny(priority 4096)로 별도로 만들어야 성립 | 두 플랫폼의 방화벽 기본값이 정반대다 |
| 인증 자료 | AMI가 이미 SSM Agent를 담고 있으면 키페어 자체가 불필요 | 로컬 계정에 SSH 키 또는 비밀번호 중 하나가 항상 강제(플랫폼 요구) + Entra ID SSH를 별도로 얹음(선택) | Azure VM 생성 자체의 제약 |
| 신원 종류 | IAM Role 하나(instance profile) | dual identity(System+User-assigned) | Entra SSH 확장이 system-assigned를 강제하고, `aks-cluster`와의 일관성을 위해 user-assigned도 쓴다 |
| 브레이크글래스 진단 | 해당 없음(SSM이 이미 유일 경로) | Run Command(4,096B/90분/비대화형/취소불가) | SSH 경로 자체가 없을 때만 쓰는 보조 수단 |

---

## 연동 예시

`vpc` -> `eks-cluster` -> `workbench` 체인의 실제 output -> input 연동(태그 문법·소싱 방식
포함)은 CI가 매 커밋 `tofu validate`로 검증하는 예제가 SSOT다. 이 문서에 손으로 사본을
유지하지 않는다. 모듈이 늘 때마다 여기도 고쳐야 하는데다, 손으로 쓴 코드는 CI가 걸러주지
않아 조용히 실물과 벌어질 수 있다.

→ [`modules/aws/eks-cluster/examples/enterprise/`](../modules/aws/eks-cluster/examples/enterprise/)

배포 CI/CD 규칙(plan/apply·승인 게이트·자격증명)은 이 저장소가 아니라
[gitops-hub-spoke/README.md](architectures/gitops-hub-spoke/README.md)의 「실행 기반」 절이 소유한다
(클라우드별 자격증명·state는 그 아래 클라우드 문서가 갖는다).
