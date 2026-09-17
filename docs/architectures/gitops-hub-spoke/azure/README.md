# Azure(AKS)에서 이 패턴

**읽는 사람**: Azure에서 이 패턴을 세우려는 사람.

패턴 자체(3계층·저장소 구성·이 패턴이 맞는 환경)는 [../README.md](../README.md)가, 계층 2
운영은 [../gitops.md](../gitops.md)가, 허브-스포크 연결은 [network.md](network.md)가 소유한다.
AWS와 다른 지점만 여기 적는다.

세우기·걷어내기 절차와 실제 값(구독·CIDR·이름)은 `aks-reference-infra`(계층 1)와
`aks-platform-gitops`(계층 2)가 갖는다. 그 두 저장소는 설계 근거를 `.tf`·매니페스트
**인라인 주석**에 둔다.

---

## 1. 구성

```
Azure 구독 (hub)                          Azure 구독 (spoke)
  |                                         |
  +-- VNet · 서브넷 · NAT     <- vnet        +-- VNet · 서브넷 · NAT     <- vnet
  +-- Virtual WAN 허브        (raw 리소스)   +-- AKS 클러스터           <- aks-cluster
  +-- AKS 클러스터            <- aks-cluster +-- workbench VM          <- aks-workbench
  +-- workbench VM           <- aks-workbench
  +-- ArgoCD (self-managed)
        |
        +-- 플랫폼 addon (App Routing Gateway · Karpenter/NAP · Kyverno · KEDA)
              <- aks-platform-gitops 저장소를 pull
```

AKS API 엔드포인트는 **private**이다. 그래서 클러스터에 명령을 넣을 지점이 구독 안에 필요하고,
그것이 workbench VM이다. AWS의 `workbench`와 같은 자리지만 접속 수단이 다르다. Azure에는 SSM
Session Manager의 대응물이 없어 **SSH가 일상 경로, Run Command가 브레이크글래스**다.

ArgoCD 콘솔은 2단 터널로 연다. 로컬 `ssh -L` → workbench → `kubectl port-forward` →
`argocd-server`. AWS는 1단이 `aws ssm start-session`이고 나머지는 같다.

Virtual WAN 허브는 raw 리소스로 쓴다. 소비자가 허브 하나뿐이라 모듈화의 값
(재사용)이 없고, AWS 쪽 Transit Gateway도 같은 이유로 모듈이 아니다.

---

## 2. 어느 ArgoCD인가

**self-managed다.** AWS처럼 관리형과 고르는 갈림길이 아직 없다. Azure의 관리형 GitOps 확장은
Public Preview라 보류했다(`aks-platform-gitops`가 그 판단을 소유한다). 상태가 GA로 바뀌면 AWS의
「어느 ArgoCD인가」와 같은 형태의 판정이 필요해진다.

---

## 3. addon을 어디에 두나: AKS의 분류

계층 판정 원칙은 [../gitops.md](../gitops.md)가 소유한다. AKS에서 그 원칙을 적용한 분류는
AWS와 다르다. **AKS가 컨트롤러까지 관리형으로 가져가는 것이 많아, 계층 2에 CR만 남는 경우가
생긴다.**

| addon | 컨트롤러 | 계층 2가 갖는 것 |
|---|---|---|
| App Routing(Gateway API/Istio) | **AKS 관리형**. 계층 1이 클러스터의 `ingressProfile`을 켜면 컨트롤러·CRD·GatewayClass가 함께 나타난다 | `Gateway` CR 하나 |
| Karpenter(NAP) | **AKS 관리형**. `enable_karpenter` 하나로 켠다 | `NodePool`·`AKSNodeClass` CR |
| KEDA | **AKS 관리형 add-on**. `enable_keda` 하나로 켠다 | 없다. `ScaledObject`는 앱팀 몫이다 |
| Kyverno | Helm | 차트 + 정책 CR |

⚠️ **App Routing은 순서 의존이 GitOps 밖에 있다.** 다른 addon은 "컨트롤러 먼저, CR 나중"을
sync-wave로 GitOps 안에서 표현하지만, 여기서는 계층 1의 apply가 먼저 끝나야 CRD가 존재한다.
GitOps는 그 순서를 표현할 수단이 없다.

⚠️ App Routing을 켤 때 레거시 NGINX IngressClass 자동 생성을 끈다. 생략하면 provider
기본값이 적용돼 쓰지 않는 NGINX 컨트롤러가 함께 뜬다.

### 노드 배치: 시스템 풀을 CriticalAddonsOnly로 잠근다

| | AWS 원본 | 이 패턴 |
|---|---|---|
| 고정 노드 taint | `CriticalAddonsOnly=true:NoSchedule` | `CriticalAddonsOnly=true:NoSchedule` |
| taint 키를 고르는가 | **고른다.** 고를 수 있는데 같은 값을 골랐다 | **못 고른다.** AKS가 이 키 하나만 받고, azurerm은 `only_critical_addons_enabled` bool로만 노출한다 |
| 시스템 파드를 끌어당기는 것 | 노드그룹 `labels`로 우리가 만드는 `workload-class=system` | AKS가 시스템 풀 노드에 자동으로 붙이는 `kubernetes.azure.com/mode: system` 라벨 |
| 플랫폼 addon의 toleration | 차트 기본값이 없는 곳만(cert-manager·ALBC·CA·KEDA·Kyverno·ArgoCD) | **ArgoCD 한 곳** |
| taint를 바꾸면 노드가 어떻게 되나 | in-place. `UpdateNodegroupConfig`가 taint만 갱신한다 | **시스템 풀을 순환한다.** cordon·drain 없이 |

⚠️ **두 열의 taint 값이 같아진 근거는 서로 다르다.** AKS는 강제이고, AWS는 생태계 관례에 맞춰
플랫폼 컴포넌트의 차트 기본 toleration을 그대로 받으려는 선택이다. 값이 같다고 판단이 같은 것은
아니므로, 한쪽을 바꿀 때 다른 쪽을 따라 바꾸지 않는다. AWS 쪽이 치르는 대가(우리만 쓰는 키를
버려 밀어내기가 약해진다)는 `eks-reference-infra`의 운영 문서가 갖는다.

Microsoft는 시스템 풀을 앱에서 격리하라고 권고하고 이 taint를 집행 수단으로 지목한다. 막으려는 것은
자원 경합이 아니라 축출이다 — 잘못 설정된 앱 파드가 시스템 파드의 자리를 빼앗는 것. 노드 풀이 하나뿐인
클러스터에 앱 파드를 올리는 것도 권장하지 않는다고 적는다.

**toleration은 ArgoCD에만 준다.** 나머지 플랫폼 addon이 시스템 풀에서 밀려나 NAP 노드로 가는 것이
격리의 내용이다. 주지 않는 쪽이 기본이고 ArgoCD가 예외다.

ArgoCD가 예외인 이유는 부트스트랩 순서다. 시스템 풀을 잠그면 seed 시점의 ArgoCD가 갈 곳이 없다 —
NAP 노드는 아직 없고, 그 `NodePool` CR을 배포하는 것이 ArgoCD 자신이다. ArgoCD가 시스템 풀에 서야
순환이 끊긴다. 🔑 toleration은 허용이지 선호가 아니라서 ArgoCD는 taint를 건 뒤에도 시스템 풀에 남는다.
이 패턴이 얻는 격리는 "ArgoCD 외 전부"다.

**관리형 addon의 toleration은 AKS가 넣는다.** App Routing의 Istio 구현체는 이 taint를 견디고, 시스템
노드를 선호하는 node affinity까지 갖는다. 과거 toleration이 빠져 있던 Azure Policy는 Microsoft가
고쳤다. cluster extension은 계열이 다르다 — extension-manager와 Flux가 이 taint에서 스케줄되지 못한다는
보고가 남아 있다. 이 패턴은 extension을 쓰지 않으며, 들일 때는 그 파드의 toleration을 먼저 확인한다.

⚠️ KEDA addon은 확인되지 않았다. addon 계열이라 들어 있을 것으로 보지만 공개 문서가 답하지 않는다.
재구축 뒤 관리형 파드의 toleration을 한 번에 읽어 확인한다.

```bash
kubectl -n kube-system get pod -o custom-columns=NAME:.metadata.name,TOLERATIONS:.spec.tolerations[*].key
```

빠져 있는 addon은 NAP 노드로 가고, NAP 노드가 없는 구간에서 `Pending`으로 기다린다.

⚠️ 이 값을 바꾸면 AKS가 시스템 풀을 순환한다. 그 순환은 cordon·drain을 하지 않아 돌던 파드가 그대로
끊긴다. 클러스터가 철거된 상태에서 바꾼다.

세 저장소가 순서대로 움직인다. GitOps가 ArgoCD toleration을 먼저 갖고, `aks-cluster` 모듈이
`system_node_pool`에 `only_critical_addons_enabled`를 노출해 태그를 컷하고, 배포 루트가 그 태그를
참조해 값을 켠다. 순서를 뒤집으면 taint가 걸린 클러스터를 toleration 없는 ArgoCD로 seed하게 된다.

---

## 4. 클러스터 등록

| | hub | spoke |
|---|---|---|
| 성격 | ArgoCD가 도는 클러스터 | 원격 클러스터 |
| Secret | 라벨과 이름만. 연결은 in-cluster | 실제 `server`와 인증 설정이 필요 |
| 인증 | 불필요 | `execProviderConfig` + `argocd-k8s-auth azure`(Entra Workload Identity) |

**정적 토큰을 git에 두지 않는다.** spoke Secret의 `env` 값은 전부 식별자(client ID·tenant ID)이고,
토큰은 ArgoCD가 런타임에 발급받는다. AWS에서 스포크 계정이 신뢰 Role을 만들고 허브의 Pod Identity를 신뢰하는
것과 같은 자리다.

**스포크 클러스터에 대한 ArgoCD 권한은 스포크가 만든다.** 스포크 배포 루트가 허브 ArgoCD 신원을
태그로 찾아, 자기 클러스터 스코프의 role assignment를 자기 apply 안에서 만든다. 권한을 부여하는
쪽이 리소스를 소유한 쪽이므로, 스포크가 허브에서 받는 것은 그 신원을 찾는 read 권한뿐이다
([network.md](network.md)의 `hub-peer`).

⚠️ hub ArgoCD의 신원(UAMI)이 hub 클러스터와 같은 배포 루트에 있으면 hub를 재구축할 때마다 신원이
새로 발급된다. **모든 스포크**가 배포 루트를 다시 apply해 role assignment를 새 principal로 옮기고,
등록 Secret의 client ID도 갱신해야 한다.

---

## 5. 되돌릴 수 없는 선택 (Azure)

공통 항목은 [../README.md](../README.md)가 갖는다.

| 선택 | 되돌릴 수 있나 | 바꾸려면 |
|------|:---:|---------|
| VNet CIDR | ❌ | VNet 재생성(삭제 보호를 먼저 풀어야 한다) |
| `cni_mode` · `pod_cidr` | ❌ | `network_profile` 블록 전체가 ForceNew라 클러스터 재생성. **첫 apply가 최종 선택이다** |
| `private_cluster_enabled` | ❌ | 같은 이유로 클러스터 재생성 |
| Entra 통합 | ❌ | Azure가 통합 해제를 지원하지 않는다. Azure RBAC만 끄는 것과는 다른 축이다 |
| vHub 주소 공간 | ❌ | 생성 후 변경 불가([network.md](network.md)) |
| hub와 spoke를 같은 구독에 둘지 | ⏳ | 크로스 구독 연결 권한을 다시 설계해야 한다 |

---

## 6. 실행 기반

공통 규칙은 [../README.md](../README.md)에 있다. Azure에서만 정해지는 것은 셋이다.

| 항목 | 규칙 |
|------|------|
| state backend | Azure Storage Account + Blob Container. `use_azuread_auth = true`, `allowSharedKeyAccess = false`(계정 키로 RBAC를 우회하는 경로를 막는다). 계정 이름은 git에 두지 않는다 |
| state 분리 | 배포 루트마다 별도 state(`<env>/<component>.tfstate`). 루트 간 결합은 이름·태그 기반 `data` 조회로만 한다 |
| 자격증명 | GitHub OIDC → App Registration 하나. **AWS의 입구 Role → 실행 Role 같은 2단 체인이 Azure에는 없다** |
| 로컬에서 되는 것 | `init`과 `validate`까지다. 배포 루트가 `ci_run` 가드로 로컬 `apply`를 실패시킨다 |
| 실패한 apply 재시도 | **저장된 plan을 그대로 다시 적용한다.** 워크플로를 새로 실행하면 plan을 처음부터 다시 만들어, 승인한 계획과 다른 것이 적용된다 |

⛔ **CI 신원의 FIC(Federated Identity Credential) `subject`에 와일드카드를 넣지 않는다.** 이 신원은
구독 전체 Owner 등가이고(AWS 실행 Role의 `AdministratorAccess`와 대칭), Azure에는 2단 체인이 없어
**이 신원에 도달하는 경로를 하나로 좁히는 것이 유일한 방어선**이다. 경로가 넓어지면
(subject 완화·정적 자격증명 추가·그룹 편입) 설계를 재검토하는 트리거로 본다.

---

## 7. 하지 않는 것

| 하지 말 것 | 이유 |
|---|---|
| L7 인그레스로 **Application Gateway for Containers(AGFC)** | frontend가 공인 FQDN만 지원하고 private 옵션이 없다(Microsoft 공식: "Private IP addresses aren't currently supported"). "hub는 전부 private" 원칙과 부딪힌다 |
| **Cilium Gateway API** | AKS의 "Azure CNI Powered by Cilium"은 관리형이라 Cilium 자체의 Gateway API 기능을 노출하지 않는다(Azure/AKS#5444) |
| **Envoy Gateway를 자체 설치** | 동작은 하고 Terraform도 필요 없지만, 관리형이 GA로 있는 자리를 자체 설치로 채우게 된다. 「관리형 기능 채택 기준」([`decisions.md`](../../../decisions.md))의 기준을 App Routing이 이미 통과한다 |
| Pod 대역을 **플랫 모델(`pod_subnet`)** 로 두는 것을 기본값으로 | NAP이 Azure CNI Pod Subnet을 지원하지 않고(karpenter-provider-azure#1352), Microsoft 공식 권고도 Overlay를 일반 기본으로 명시한다. 플랫 모델은 Pod 단위 관측성을 포기할 수 없을 때만 고른다([network.md](network.md)) |
| "NSG 규칙 0개 = 인바운드 0"이라고 가정 | Azure는 `AllowVNetInBound`가 이미 열려 있다. 막으려면 명시적 Deny(priority 4096)로 덮어야 한다. AWS 보안 그룹과 기본값이 정반대다 |
| 허브가 스포크 클러스터를 발견해 **허브 쪽에서** ArgoCD role assignment를 만든다 | 허브 CI가 스포크 리소스 그룹에 `roleAssignments/write`를 가져야 한다. 그 권한이면 허브 CI가 그 리소스 그룹에서 자신에게 어떤 역할이든 부여할 수 있다. 「모듈 경계」([`decisions.md`](../../../decisions.md))가 모듈에 신원·권한 부여 리소스를 두지 않는 것과 같은 논리다 |
| Entra 통합을 "일단 켜 보고 아니면 되돌린다" | Azure가 통합 해제를 지원하지 않는다. 되돌리려면 클러스터 재생성이다 |
| CI 신원의 **권한 크기**를 방어선으로 삼기(리소스 그룹 스코프 커스텀 역할 + 불변식 검사) | 한 번 세웠다가 걷어냈다. 배포 루트는 리소스 그룹·역할 할당까지 만들어야 해서 좁힌 역할을 계속 넓히게 되고, 그 과정에서 검사 항목만 늘어난다. AWS 실행 Role도 `AdministratorAccess`라 대칭이 아니었다. **방어선은 그 신원에 도달하는 경로(FIC subject) 하나뿐이다** |
