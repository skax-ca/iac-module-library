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

### 노드 배치: 시스템 풀에 taint를 두지 않는다

| | AWS 원본 | 이 패턴 |
|---|---|---|
| 고정 노드 taint | `workload-class=system:NoSchedule` | **없다** |
| 앱과 시스템 분리 | taint(밀어내기) + `nodeSelector`(끌어당기기) | 시스템 풀이 차면 NAP이 노드를 띄우는 것뿐이다 |
| 플랫폼 addon의 toleration | 6곳 전부 필요 | 필요 없다 |

Microsoft는 시스템 풀을 앱에서 격리하라고 권고하고, 집행 수단으로 `CriticalAddonsOnly=true:NoSchedule`
taint를 지목한다. 노드 풀이 하나뿐인 클러스터에 앱 파드를 올리는 것도 권장하지 않는다고 적는다.
**이 패턴은 그 권고를 알고 따르지 않는다.**

이유는 비용이 아니라 **부트스트랩 순서**다. 시스템 풀을 잠그면 seed 시점의 ArgoCD가 갈 곳이 없다 —
NAP 노드는 아직 없고(그 `NodePool` CR을 ArgoCD가 배포한다), 시스템 풀은 taint로 막혀 있다. 풀려면
ArgoCD에도 toleration을 줘야 하고, 그러면 AWS와 같은 모양이 된다. 격리를 얻는 대신 계층 2가 다시
스케줄링 세부를 알아야 한다.

⚠️ **도입 트리거는 하나다**: 시스템 노드에 `kube-system` 밖 파드가 쌓여 addon이 `Pending`이 되는 것.
확인 절차는 `aks-reference-infra`의 운영 문서가 갖는다.

도입하면 세 저장소가 함께 움직인다 — `aks-cluster` 모듈이 기본 풀 taint를 노출하고, 배포 루트가 값을
넣고, GitOps의 ArgoCD values가 toleration을 받는다. 한 저장소만 고치면 클러스터가 seed 단계에서 멈춘다.

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
