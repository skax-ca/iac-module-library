# 모듈 카탈로그

**읽는 사람**: 배포 루트에서 모듈을 호출하려는 사람.

모듈은 `modules/<provider>/<모듈명>/`에 둔다. 현재 등재된 것은 AWS 4개이고 Azure는 1개다.

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
([choose-your-path.md](architectures/eks-gitops-hub-spoke/choose-your-path.md) 질문 D의 IAM 경계를 구현한다, `eks-cluster-v0.8.0`부터).
허브 계정에서만 켠다. 스포크 쪽은 `cross-account-trust-role` 모듈이 소유한다.
변수·출력 전체는 위 README 링크를 본다.

⚠️ 이 변수들은 **IAM 경계만** 만든다. private-only 엔드포인트에서 허브가 스포크에 실제로
도달하려면 Transit Gateway가 **별도로** 필요하다(VPC Peering은 CIDR 3계층의 pod-dup 대역
재사용 설계와 구조적으로 충돌해 쓸 수 없다).
[choose-your-path.md](architectures/eks-gitops-hub-spoke/choose-your-path.md)의 「네트워크 경로」 절 참조.
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
([choose-your-path.md](architectures/eks-gitops-hub-spoke/choose-your-path.md) 질문 D에서 허브 분리를 택한 경우)에서만 쓴다.

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

Azure Kubernetes 클러스터(AKS). **설계 확정 · 구현 미착수**(`modules/azure/aks-cluster/`
디렉터리와 코드는 아직 없다). 이 절은 승인된 설계(`docs/decisions.md`「Azure 컨테이너
(aks-cluster)」ADR)의 확정 사항을 옮긴 것이고, 구현 후에는 아래 서브섹션을 모듈 README로
대체한다.

### `vnet`과의 연동

| 항목 | 내용 |
|---|---|
| 노드 서브넷 | `vnet`의 `subnet_ids_by_group["aks-node"]` → `node_subnet_id` |
| Pod 서브넷 | `vnet`의 `subnet_ids_by_group["aks-pod"]` → `pod_subnet_id`. 소비자가 `vnet`의 `subnet_groups`에 이 그룹을 먼저 추가한다. Pod 대역은 VNet의 secondary `address_space`에서 뗀다 |
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

### 인터페이스 초안

⚠️ **이 절은 모듈 README가 생기면 삭제한다**(두 곳에 같은 계약을 두지 않는다).

| 구분 | 값 |
|---|---|
| 필수 입력 | `naming` · `resource_group_name` · `location` · `identity_id` · `node_subnet_id` · `pod_subnet_id` |
| 선택 입력 | `purpose` · `serial` · `tags` · `cluster_enabled`(기본 `true`) · `deletion_protection`(기본 `false`) · `kubernetes_version` · `sku_tier` · `node_pools`(맵) · `entra_admin_group_object_ids` · `local_account_disabled`(기본 `false`) · `private_cluster_enabled` · `authorized_ip_ranges` · `service_cidr` · `dns_service_ip` · `workload_identity_enabled` |
| 출력 | `cluster_id` · `cluster_name` · `oidc_issuer_url` · `kubelet_identity_object_id` · `node_resource_group` · `fqdn`/`private_fqdn`(전부 null-safe) |

⚠️ `pod_subnet_id`는 노드 풀별 인자이지만, 첫 버전은 전 노드 풀이 이 값 하나를 공유한다.
풀별 오버라이드는 이후 버전 후보로 미뤘다(서브넷 교체는 순환을 부르므로 나중에 여는 것도
비파괴 변경이다).

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
| Pod 네트워킹 | `pod_subnet_ids` 입력(custom networking) | `pod_subnet_id` 입력(Azure CNI Pod Subnet 고정) | Overlay는 노출하지 않는다 |
| 노드 그룹 키 문자집합 | 제약 없음 | 소문자+숫자만, 8자 이하, 숫자로 시작 불가 | 노드 풀 이름 물리 제약 |
| Windows 노드 | 지원 | `0.1.0` 스코프 밖 | 이름 한도 6자 |
| 서브넷 교체 | 노드그룹 롤링 교체 | cordon/drain 없는 풀 순환 | AKS 노드 풀 순환의 동작 |

---

## 연동 예시

`vpc` -> `eks-cluster` -> `workbench` 체인의 실제 output -> input 연동(태그 문법·소싱 방식
포함)은 CI가 매 커밋 `tofu validate`로 검증하는 예제가 SSOT다. 이 문서에 손으로 사본을
유지하지 않는다. 모듈이 늘 때마다 여기도 고쳐야 하는데다, 손으로 쓴 코드는 CI가 걸러주지
않아 조용히 실물과 벌어질 수 있다.

→ [`modules/aws/eks-cluster/examples/enterprise/`](../modules/aws/eks-cluster/examples/enterprise/)

배포 CI/CD 규칙(plan/apply·승인 게이트·자격증명)은 이 저장소가 아니라
[overview.md](architectures/eks-gitops-hub-spoke/overview.md)의 「실행 기반」 절이 소유한다.
