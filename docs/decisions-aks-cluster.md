# 결정 이력: Azure 컨테이너 (aks-cluster)

`docs/decisions.md`가 400줄 상한을 넘어 이 모듈 하나의 결정 이력만 분리했다
(`writing-style.md` 규칙 4, "넘으면 독자가 갈린 것이다"). 이 문서는
`modules/azure/aks-cluster/`를 만들거나 바꾸려는 사람이 읽는다. 그 밖의 결정은
`docs/decisions.md`가 그대로 소유한다.

| 하지 말 것 | 이유 |
|---|---|
| 노드 풀 이름을 포맷 토큰으로 조합하고 12자로 절단 | 조용한 충돌이다. 절단 후 두 그룹 키가 같아지면 이름이 겹치는데 plan이 잡지 못한다 |
| 노드 풀 이름을 소비자가 직접 지정 | "소비자는 약어를 직접 쓰지 않는다"는 공통 강제 방식 위반이다 |
| 추가 노드 풀을 소비자에게 떠넘기기 | 그 리소스는 클러스터 ID를 요구하는데 그 ID는 이 모듈 소유다. 소비자에게 떠넘기면 경계가 어긋난다 |
| 모듈이 user-assigned identity와 role assignment 생성 | 소비자 CI 신원의 권한 경계를 깬다. 그 권한을 가진 신원은 자기 자신에게 상위 역할을 부여할 수 있게 된다 |
| role assignment 생성을 옵트인 변수로 분리 | 미루기일 뿐 해소가 아니다. 켜는 순간 같은 권한이 필요해지고, 켜면 보안 경계가 깨지는 손잡이를 배송 계약에 넣게 된다 |
| system-assigned 컨트롤 플레인 신원 | principal ID가 생성 후에만 알려져 사전 권한 부여가 구조적으로 불가능하다 |
| identity 선택 입력(null이면 system-assigned로 대체) | 위 행과 같은 이유로 기각한다 |
| `local_account_disabled` 기본 `true` | object ID 하나만 틀려도 클러스터 접근이 끊기는 잠금 위험이 있다(브레이크글래스 소멸) |
| `role_based_access_control_enabled` 노출 | 기본값이 `true`이고 변경 시 재생성이라, 끌 이유가 재사용 자산에 없다 |
| `kubenet` 노출 | 2028-03-31에 지원이 끝난다 |
| 노드 풀 약어를 약어 카탈로그에 등재 | CAF 권장 약어가 이 카탈로그의 등재 규칙(길이 상한)과 예시 형식 검사를 동시에 위반해 검증기가 막는다 |
| 검증기에 노드 풀 예외 분기 추가 | 검증기가 스스로 선언한 불변식을 약화시킨다 |
| 노드 풀 예시를 조작해 통과 | 거짓 문서가 된다 |
| 그룹 키 상한을 12자로 | 순환용 임시 노드 풀 이름이 들어갈 자리가 0자가 돼, 순환이 필요한 변경에서 apply가 막힌다 |
| Windows 노드 풀 `0.1.0` 지원 | 이름 한도가 6자다. 기술적 불가가 아니라 스코프 결정이다 |
| `pod_subnet_id`를 풀별로 노출 | `0.1.0`은 전 풀 공유가 맞다. 나중에 여는 것도 비파괴 변경이다 |
| 서브넷 `Network Contributor`를 커스텀 역할로 좁히기 | 그 역할이 클러스터 identity에 `roleAssignments/write`를 쥐여 줘, subnet 스코프 권한 봉투가 내장 역할보다 오히려 넓어진다 |
| AKS 서브넷에 `delegations` 설정 | 위임된 서브넷일 수 없다 |
| `aks-cluster`가 Pod 서브넷 생성 | 소유하지 않은 VNet에 서브넷을 만들고, "CIDR 계산은 소비자 루트가 소유한다"는 규약과 충돌하며, 클러스터를 파기하면 네트워크 자산도 함께 사라진다 |
| kubelet identity 입력을 `0.1.0`에 포함 | 실수요가 없다. 노드 리소스 그룹 밖의 신원은 role을 추가로 부른다 |
| 크로스 구독 확장 포함 | 본질적으로 role assignment이므로 이 모듈이 만들 수 없다 |
| `eks-cluster`의 addon baseline 패턴 이식 | AKS는 애드온이 맵이 아니라 개별 블록이라, 이식할 대응 문제 자체가 없다 |
| AVM 커뮤니티 모듈 wrapper | 조립 대상이 없다. AKS는 클러스터 리소스 1개 + 노드 풀 N개이고, 다중 리소스를 조립해 값을 내는 계층이 여기엔 없다 |
| AKS 네이티브 삭제 보호 사용 | 존재하지 않는다 |

> **결정**: 두 번째 Azure 모듈 `aks-cluster`를 `modules/azure/aks-cluster/`에 스크래치 얇은
> 모듈로 설계한다. 시스템 노드 풀은 클러스터 리소스가 강제하므로 모듈이 소유하고, 추가
> 노드 풀도 같은 경계 논리로 모듈이 소유한다. 노드 풀 이름은 `np<그룹키>`로 조합하며
> `workload`·`env`·`리전코드` 토큰을 쓰지 않는다. **이 모듈은 신원도 role assignment도
> 만들지 않고 user-assigned identity의 리소스 ID를 필수 입력으로만 받는다.** 네트워킹은
> `cni_mode`(0.2.0부터, 아래 참조)로 선택한다. 기본값은 0.1.0~0.2.0 동안 Azure CNI Pod
> Subnet(flat)이었다가 0.3.0부터 Azure CNI Overlay로 바뀌었다(아래 「CNI 모드 확장(0.2.0)과
> 기본값 재검토(0.3.0)」 절 참조).
> 노드·Pod 서브넷을 둘 다 입력으로 받는다(둘 다 `vnet` 모듈이 만든다). Entra 통합은 옵트인이며
> 로컬 계정은 기본 유지한다. 애드온 블록·kubelet 신원 입력·크로스 구독 확장은 스코프 밖이다.
>
> 드라이버는 (1) 소비 repo CI 신원의 권한 경계 (2) Azure가 강제하는 것과 이 저장소 규약이
> 충돌하는 지점(노드 풀 이름) (3) 틀린 기본값의 되돌리기 비용(CNI·Entra RBAC)이다.

> **왜 이 결정인가**: 재사용 모듈이 만드는 리소스는 소비자의 CI 신원이 그것을 만들 권한을
> 갖는다는 뜻이다. `azurerm_role_assignment`를 만드는 모듈은 소비자에게
> `roleAssignments/write`를 요구하고, 그 권한을 가진 신원은 자기 자신에게 상위 역할을
> 부여할 수 있다. AWS는 STS role-chaining으로 특권을 입구 Role 뒤에 감추지만 Azure에는 그
> 완충층이 없어 CI 신원이 권한을 직접 보유한다. 같은 행위(모듈이 권한 리소스를 만드는
> 것)의 비용이 두 클라우드에서 다르고, Azure에서는 identity 생성·권한 부여(민감·저빈도·
> 수동)를 클러스터 생성(일상·CI)에서 모듈 경계로 분리했다. `cross-account-trust-role`과
> `eks-cluster`를 나눈 AWS 쪽 선례에서는 "민감·저빈도와 일상·CI를 나눈다"는 패턴의 형태만
> 빌렸다. 그 분리의 AWS측 사유(다른 계정 소재)와 이 분리의 사유(CI 신원의 권한 봉투)는
> 다르다.
> 네트워킹은 Pod 단위 관측성을 지키는 쪽(flat)을 골랐다. Overlay는 성능이 동급이지만 Pod
> 트래픽을 노드 IP로 SNAT해 NSG 플로우 로그·Network Watcher에서 Pod를 식별할 수 없게
> 만든다.

### CNI 모드 확장(0.2.0)과 기본값 재검토(0.3.0): `cni_mode`로 3모드 선택형, 기본값은 `"overlay"`

`0.1.0`은 위 문단대로 Azure CNI Pod Subnet(flat)을 유일한 선택지로 **고정**했다(축5). 이후
두 단계에 걸쳐 이 축을 다시 열었다.

**0.2.0: 모드를 선택형으로 확장한 계기는 NAP 비호환 확정이었다.**
`aks-reference-infra`의 `live/hub/aks` 설계 라운드에서 `enable_karpenter = true`(당시
기본값)와 고정 CNI가 실제로 함께 못 쓰인다는 것이 확정됐다. karpenter-provider-azure
메인테이너가 공식 이슈에서 직접 명시: "Currently Karpenter on Azure does not support
Azure CNI Pod Subnet (either dynamic IP allocation or static block allocation)"
([github.com/Azure/karpenter-provider-azure#1352](https://github.com/Azure/karpenter-provider-azure/issues/1352),
2026-01-15 오픈, 아직 미해결). `0.1.0`의 `enable_karpenter` 변수 설명이 "미검증"이라
적어뒀던 바로 그 리스크가 확정으로 바뀐 것이다. 공식 문서
([node-auto-provisioning-networking](https://learn.microsoft.com/en-us/azure/aks/node-auto-provisioning-networking))
확인 결과 NAP이 지원하는 네트워킹은 정확히 3가지뿐이다: Azure CNI Overlay · Azure CNI
Overlay Powered by Cilium · Azure CNI(Legacy/Node Subnet). Pod Subnet(dynamic·static
block 모두)은 지원 목록에 없다. `cni_mode` 변수(`"pod_subnet"`·`"node_subnet"`·`"overlay"`)를
신설했고, 이 시점엔 기본값을 `"pod_subnet"`으로 유지해 위 관측성 우선순위를 그대로
보존했다. `enable_karpenter` 기본값도 `true`→`false`로 내려 "기본값끼리 조합하면 plan이
깨지는" 상태를 피했다.

**0.3.0: Microsoft 공식 문서를 정면으로 재검토해 기본값을 `"overlay"`로 뒤집었다.**
두 공식 문서가 AWS 대칭성과 무관하게 Overlay를 일반 기본값으로 명시한다:
[plan-pod-networking](https://learn.microsoft.com/en-us/azure/aks/plan-pod-networking)
("Our general recommendation is to use Azure CNI Overlay")와
[AKS baseline 참조 아키텍처](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/containers/aks/baseline-aks)
("we recommend it for most deployments"). 두 문서 모두 flat 모델(`pod_subnet`·
`node_subnet`)은 "밖에서 Pod로 직접 접근해야 하는 명확한 요구가 있을 때"만 쓰라고
명시한다. 이 저장소의 하위 호환 유지 우선순위(AWS 원본과 IP 모델을 맞춘다)가 아니라
Azure 자체의 권고 축으로 재판정한 결과다.

`0.1.0`이 Overlay를 기각한 유일한 사유(SNAT로 인한 Pod 단위 관측성 손실)에 대해서도
Azure가 별도 답을 갖고 있음을 확인했다: 유료 애드온 Advanced Container Networking
Services(ACNS)의 Container Network Observability가 eBPF로 SNAT 이전 지점에서 Pod
identity를 캡처한다("works across both Cilium and non-Cilium data planes"). NSG 플로우
로그의 완전한 대체재는 아니다(저장 로그 모드는 Cilium 데이터플레인 전용이고, 기본 집계는
개별 Pod IP 대신 워크로드 단위로 뭉친다). 그래도 "CNI를 바꾸지 않고 관측성을 지킨다"가
아니라 "관측성을 다른 계층에서 회복한다"는 선택지가 있다는 것 자체가 `0.1.0`·`0.2.0`
시점엔 없던 근거다.

**결정**: `cni_mode` 기본값을 `"pod_subnet"`→`"overlay"`로 바꾼다. `enable_karpenter`
기본값(`false`)은 그대로 유지한다. NAP은 여전히 GitOps `NodePool`·`AKSNodeClass` 준비가
갖춰져야 의미 있는 옵트인 기능이지, 호환성 문제가 아니기 때문이다. `"pod_subnet"`은
`0.1.0`~`0.2.0`의 기본값이었던 선택지로 남기고(관측성을 절대 포기 못 하는 소비자를 위해),
`"node_subnet"`도 그대로 유지한다.

`network_profile` 블록 전체가 provider에 의해 ForceNew라 `cni_mode`를 `"overlay"`로 오가는
전환은 클러스터 재생성을 부른다. `"pod_subnet"` ↔ `"node_subnet"`만은 예외로, `pod_subnet_id`가
`network_profile`이 아니라 `default_node_pool`에 있어 `temporary_name_for_rotation`을 통한
노드 풀 순환으로 처리된다(azurerm_kubernetes_cluster 공식 문서 확인).

**0.4.0: `"overlay"`의 `network_policy` 배선 버그를 실배포 라운드에서 발견해 정정.**
`0.3.0`은 `network_data_plane = "cilium"`만 조건부로 켰고 `network_policy`는 항상
`"azure"`로 고정해 뒀다. 이 문서의 0.2.0 절 코드 주석에 "cilium은 network_policy도
cilium으로 맞춰야 하는데 이 라운드 스코프가 아니다"라고 그 갭을 스스로 기록해 뒀지만
반영하지 않은 채 넘어갔다. `aks-reference-infra`의 `live/hub/aks` 배포 계획 라운드
(2026-09-03)에서 Architect 검토가 실제 apply를 앞두고 이 조합을 지목했고, provider
공식 문서("When network_data_plane is set to cilium, the network_policy field must
be set to cilium")와 ARM 실제 에러 사례(hashicorp/terraform-provider-azurerm#23339,
"Cilium dataplane requires network policy cilium.")로 확정했다. 즉 `0.2.0`~`0.3.0`의
`cni_mode = "overlay"`(0.3.0 기본값) 경로는 **한 번도 성립한 적이 없었다**. `tofu
test`가 `mock_provider`로 ARM을 모킹해 이 정합성 오류를 구조적으로 못 잡는다는 사실도
같이 확인됐다(`variables.tf`가 스스로 "스키마 수준만 보장한다"고 이미 표시해 뒀던
바로 그 한계다).

**결정**: `network_policy`를 `cni_mode == "overlay" ? "cilium" : "azure"`로 조건부화한다
(`main.tf`). `tests/plan.tftest.hcl`의 overlay·pod_subnet·node_subnet 세 run 모두에
`network_policy` assertion을 추가해 이 조합이 다시 깨져도 최소 스키마 레벨에서는 잡히게
한다. ARM 레벨 정합성까지는 여전히 mock으로 못 잡는다는 한계는 남는다(소비 repo의 실제
apply가 최종 검증선이라는 원칙, 이 절 서두 문단 참고).

| 항목 | 내용 |
|---|---|
| `identity_id` | 필수 입력(`nullable = false`). 클러스터 생성 전에 identity와 그 role assignment를 별도 경로(수동/bootstrap)로 준비해야 한다. system-assigned는 지원하지 않는다 |
| 신원 순서 의존 | identity 생성 → 서브넷 `Network Contributor` 부여 → 클러스터 생성. 순서를 어기면 클러스터는 서고 노드만 조용히 실패한다. role assignment가 모듈 밖이라 plan에서 잡을 수 없는 죽은 경로다 |
| Pod 서브넷 | 소비자가 `vnet` 모듈의 `subnet_groups`에 그룹을 먼저 추가한다. Pod 대역은 VNet의 secondary `address_space`에서 뗀다 |
| Overlay 전환 비용 | `network_profile`이 ForceNew라 필요해지면 클러스터를 재생성해야 한다. `private_cluster_enabled`·`private_dns_zone_id`도 같다 |
| 노드 그룹 키 | 소문자+숫자 8자 이하로 제한된다. 다른 모듈의 그룹 키 관행(하이픈 포함)이 여기서는 통하지 않는다. Windows 노드 풀은 `0.1.0` 지원 범위 밖이다 |
| 노드 풀 순환 | 서브넷·`vm_size`·`max_pods` 등을 바꾸면 노드 풀이 순환하는데, cordon/drain을 하지 않는다. 실행 중 파드가 재스케줄로 중단된다 |
| Entra 미통합 | 로컬 계정 경로로 접근한다. 안전한 최종 상태로 가는 것은 소비자 판단이다 |
| 애드온·kubelet 신원 | `0.1.0`에서 제외한다. 필요해지면 다음 마이너를 기다린다 |
| 미확정 2건 | `identity_name`+`data` 조회(Option E)로의 전환 여부, `pod_subnet_id` 풀별 오버라이드 필요 여부. 실수요가 확인되기 전까지 각각 필수 입력(Option A)·전 풀 공유를 유지한다 |

### 0.5.0: `upgrade_settings` 미선언으로 인한 perpetual diff 정정

`default_node_pool`·`azurerm_kubernetes_cluster_node_pool` 둘 다 `upgrade_settings`
블록을 선언하지 않았다. Azure는 노드 풀 생성 시 이 블록을 `max_surge = "10%"`
기본값으로 채워 반환하는데, HCL에 선언이 없으면 OpenTofu가 이를 "제거 대상"으로
매 plan마다 표시한다. apply해도 Azure가 다음 조회에서 같은 기본값을 다시 채워
넣어 **수렴하지 않는 perpetual diff**가 된다. `aks-reference-infra`의
`live/hub/aks` 첫 실배포에서 독립된 plan 3회 연속 같은 diff로 실측 확인했다.
`azurerm_kubernetes_cluster.default_node_pool.upgrade_settings.max_surge`는
스키마상 **Required**라 블록을 선언하는 이상 값을 생략할 수 없다(provider 스키마
직접 확인, `azurerm_kubernetes_cluster_node_pool` 쪽은 Optional).

**결정**: 두 리소스 모두 `upgrade_settings { max_surge = "10%" }`를 명시한다.
Azure의 실제 기본값을 그대로 선언해 diff를 없앤다. 옵트인 변수로 노출하지
않는다(0.5.0 스코프 밖, 실수요 없이 축을 여는 것은 P5 위반). 필요해지면 다음
마이너에서 변수화한다. `tests/plan.tftest.hcl`의 `system_node_pool_required_and_
wired`·`additional_node_pools_named_and_wired`에 `upgrade_settings.max_surge`
assertion을 추가해 회귀를 방지한다.

### 0.8.0: `entra_integration_enabled` 신설(admin 그룹 없이 Entra 통합을 켜는 독립 토글)

0.1.0(G2)은 admin 그룹이 비면 AAD RBAC 블록을 안 만들도록 설계했으나, 크로스 구독
GitOps 등록 설계(비-사람 principal에게 role assignment로 접근 부여)에서 admin
그룹 없이 Entra RBAC만 켜는 경로가 막혀 있다는 게 드러났다. azurerm 스키마 확인
결과 `admin_group_object_ids`와 `azure_rbac_enabled`는 독립된 Optional 필드라
이 결합은 Azure 제약이 아니라 모듈의 설계 결정이었다.

**결정**: `entra_integration_enabled`(bool, 기본 `false`) 신설, `local.enable_aad`를
admin 그룹 존재 또는 이 토글로 확장한다. `azure_rbac_enabled = true` 하드코딩은
유지(두 경로 모두 블록 생성 시 값이 항상 같아 변수화하면 죽은 분기만 는다).
변수 이름을 provider 필드명과 다르게 지어 admin 그룹 경로에서도 값이 어긋나지
않게 한다. `local_account_disabled` 교차검증도 이 경로를 인정하도록 완화한다
(강화가 아니라 완화다. 이 조합이 이 토글의 목표 상태다).

⚠️ Entra 통합은 켠 뒤 되돌릴 수 없다(Azure가 통합 해제 자체를 미지원, Azure
RBAC만 끄는 것과는 다른 축). 되돌리려면 클러스터 재생성이 필요하다.
