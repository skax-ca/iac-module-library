# AKS 마이너 업그레이드의 설계

**읽는 사람**: Kubernetes 마이너 업그레이드 절차를 설계하거나 검토하는 사람.

따라 하는 절차는 레퍼런스 배포 저장소 `aks-reference-infra`의 `docs/upgrade.md`가 갖는다. 이 문서는 그
절차가 왜 그 순서인지를 갖는다. EKS의 같은 주제는 [../aws/upgrade.md](../aws/upgrade.md)가 갖는다.

> **검증 상태**: ⏳ 표시가 붙은 줄은 실환경에서 확인하지 않았다.

---

## 1. 순서

```
사전 점검 (올릴지를 여기서 정한다)
  → NAP disruption 차단          (GitOps)
  → 컨트롤플레인                 (배포 루트)
  → 관리형 addon 확인            (조회만)
  → 시스템 풀                    (배포 루트)
  → NAP disruption 차단 해제     (GitOps)
```

Microsoft가 적는 수동 업그레이드 순서는 컨트롤플레인, 시스템 풀, 사용자 풀이다
([AKS patch and upgrade guidance](https://learn.microsoft.com/en-us/azure/architecture/operator-guides/aks/aks-upgrade-practices)).
이 패턴은 사용자 풀 자리에 NAP 노드가 있고, 그 교체 시점을 disruption 차단으로 정한다.

---

## 2. 컨트롤플레인은 되돌릴 수 없다

Microsoft 문서가 적는 되돌리기는 노드 풀 하나다
([Roll back node pool versions](https://learn.microsoft.com/en-us/azure/aks/roll-back-node-pool-version)).
컨트롤플레인의 Kubernetes 버전을 내리는 수단은 없다.

| 대상 | 되돌리는 수단 | 조건 |
|------|---------------|------|
| 컨트롤플레인 | 없다 | 새 마이너에서 고치거나 옛 버전으로 클러스터를 다시 세운다 |
| 관리형 addon | 없다 | 버전이 컨트롤플레인의 Kubernetes 버전에 묶여 있다 |
| 시스템 풀 | `az aks nodepool rollback` | 업그레이드 완료 뒤 7일, 직전 버전 하나, 그 버전이 지원 중일 것 |
| NAP 노드 | 없다 | 컨트롤플레인의 버전을 따라간다. 노드 풀이 아니라 되돌리기 명령의 대상이 아니다 |

시스템 풀 되돌리기로 복구되는 실패는 한 종류다.

| 실패 | 시스템 풀 되돌리기로 복구되는가 |
|------|:---:|
| 없어진 API, 컨트롤플레인의 동작 변화 | ❌ |
| 관리형 addon의 버전(Cilium · CoreDNS · KEDA · App Routing) | ❌ |
| NAP 노드의 app 워크로드가 새 kubelet·런타임에서 깨진다 | ❌ |
| 시스템 풀의 플랫폼 컴포넌트가 새 kubelet·런타임·노드 이미지에서 깨진다 | ✅ |

그래서 올릴지는 컨트롤플레인 apply 앞에서 정한다. 그 뒤에는 되돌릴지를 정하는 단계가 없다.

- **nonprd 클러스터가 prd의 사전 검증이다.** nonprd를 끝까지 올려 확인한 것이 prd 컨트롤플레인을 올리기
  전에 가진 근거의 전부다.
- AKS는 컨트롤플레인의 마이너를 올릴 때 지난 12시간 안에 쓰인 deprecated API가 있으면 요청을 거부한다
  ([Stop cluster upgrades on API breaking changes](https://learn.microsoft.com/en-us/azure/aks/stop-cluster-upgrade-api-breaking-changes)).
  읽기 요청(`get`·`list`·`watch`)은 세지 않는다. 이 검사가 거부하면 우회하지 않고 사용처를 고친다.
- 시스템 풀 되돌리기는 절차의 단계가 아니라 증상이 났을 때 여는 대응이다. `az aks nodepool rollback`은
  azurerm에 없는 동작이라 사람이 로컬에서 실행하고, 바로 뒤에 시스템 풀의 버전을 올린 커밋을 revert해
  코드를 실제와 맞춘다.

---

## 3. 컨트롤플레인과 시스템 풀을 다른 apply로 나눈다

`aks-cluster` 모듈이 노드 풀마다 `kubernetes_version`을 받는다. 배포 루트가 클러스터와 시스템 풀에 값을
따로 적고, 커밋 둘로 올린다.

| 얻는 것 | 내용 |
|---------|------|
| 멈춰 볼 지점 | 컨트롤플레인만 올라간 상태에서 API와 관리형 addon을 확인하고 시스템 풀로 넘어간다 |
| 실패의 격리 | 시스템 풀이 drain에서 실패해도 컨트롤플레인 apply는 이미 끝난 run이다 |
| 코드가 실제와 같다 | 시스템 풀의 버전이 코드에 있어, 올린 사람과 시점이 커밋으로 남는다 |

AKS는 컨트롤플레인이 노드 풀보다 3 마이너까지 앞서는 것을 지원한다
([Supported Kubernetes versions](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions)).
컨트롤플레인만 올린 상태는 지원되는 구성이라, 확인이 길어져도 시스템 풀을 서둘러 올릴 이유가 없다.

- 클러스터와 시스템 풀에 같은 패치 버전(`1.36.4`)을 적는다. 마이너 별칭(`1.36`)은 apply 시점에 패치가
  정해져, 날짜가 다른 두 apply에서 값이 갈릴 수 있다.
- ⏳ 클러스터의 `kubernetes_version`만 바꾼 plan에는 시스템 풀이 뜨지 않는다.

---

## 4. NAP의 disruption을 차단했다가 푼다

NAP 노드의 Kubernetes 버전은 컨트롤플레인을 따라간다
([Overview of node auto-provisioning](https://learn.microsoft.com/en-us/azure/aks/node-auto-provisioning)).
컨트롤플레인이 올라가면 `NodePool`을 고치지 않아도 기존 노드가 교체 대상이 된다. budget을 적지 않은
`NodePool`은 기본값 `10%`로 바로 교체를 시작한다.

app 워크로드가 NAP 노드에 있다. 컨트롤플레인과 시스템 풀을 확인하기 전에 app 노드가 먼저 바뀌는 것을
막으려고, `NodePool`의 disruption budget에 `Drifted`와 `Underutilized`를 `nodes: "0"`으로 막는 줄을 티어별
스위치로 둔다.

| 막는 것 | 막지 못하는 것 |
|---------|----------------|
| drift 교체, consolidation | 스케일 아웃. ⏳ 이렇게 새로 뜨는 노드는 새 마이너다 |

`Underutilized`까지 막는 이유는 차단 중에 consolidation이 노드를 바꾸면 그 노드가 새 마이너로 뜨기
때문이다. `Empty`는 막지 않는다. 파드가 없는 노드라 워크로드가 움직이지 않는다.

🔑 NAP 노드는 되돌릴 수 없다. 차단을 풀기 전이 app 워크로드를 옛 마이너의 kubelet에 둘 수 있는 마지막
지점이다. 차단은 되돌릴 구간을 지키는 장치가 아니라 교체의 순서를 정하는 장치다.

- ⏳ NAP이 budget의 `reasons`를 받는다.
- 이 패턴의 `NodePool`은 `expireAfter: Never`다. 만료로 노드가 바뀌는 경로가 없다.

---

## 5. addon은 종류마다 할 일이 다르다

| 종류 | 무엇 | 자리 | 할 일 |
|------|------|------|-------|
| 관리형 addon | Cilium, CoreDNS, KEDA, App Routing, Gateway API CRD, NAP | AKS | 올릴 것이 없다. 컨트롤플레인 뒤에 **확인한다** |
| 플랫폼 addon | Kyverno 엔진과 정책 | GitOps 버전 표 | 클러스터보다 **먼저**. 지금 버전이 새 마이너를 지원하지 않을 때만 |
| ArgoCD | 차트 | GitOps bootstrap | 클러스터보다 **먼저**. 같은 조건 |
| workbench의 `kubectl` | 클라이언트 | 배포 루트 | 대상 마이너로 미리 핀한다 |

관리형 addon은 버전 핀이 없다. AKS가 마이너마다 정해 둔 버전으로 올린다. 마이너별 버전과 바뀌는 항목은
[Supported Kubernetes versions](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions)의
「AKS components breaking changes by version」 표가 갖는다. 사전 점검에서 이 표를 읽고, 컨트롤플레인을
올린 뒤 DNS 해석, 파드 간 통신, Gateway 경유 호출, KEDA의 스케일을 확인한다.

`kubectl`은 API 서버와 한 마이너 차이까지 지원된다. 대상 마이너로 핀해 두면 올리기 전과 뒤 양쪽에서
지원 범위 안이라, 업그레이드 도중에 workbench를 교체하지 않는다.

플랫폼 addon 승격은 Kubernetes 업그레이드와 다른 변경이다. 같은 구간에 섞으면 문제의 원인이 컨트롤러
버전인지 Kubernetes 마이너인지 가를 수 없다.

---

## 6. 티어 승격과 hub

nonprd 티어의 클러스터를 끝까지 올리고 확인한 뒤 prd 티어를 올린다. GitOps의 티어별 값(disruption 차단)이
이 승격을 클러스터 하나씩으로 가른다. 배포 루트는 클러스터마다 파일과 워크플로가 달라 PR 하나가 클러스터
하나만 건드린다.

- 승격 구간에는 티어로 가르지 않은 매니페스트가 두 마이너 모두에서 유효해야 한다. 새 마이너에만 있는
  API를 쓰는 변경은 마지막 클러스터까지 끝난 뒤에 넣는다.
- hub는 ArgoCD가 도는 클러스터다. ArgoCD가 시스템 풀에 있어 hub의 시스템 풀을 올리는 동안 노드와 함께
  옮겨진다. 그래서 ArgoCD를 HA 구성으로 두고 hub의 시스템 풀을 3대로 잡는다. `redis-ha`의 redis 3개와
  haproxy 3개가 각각 서로 다른 노드를 요구한다.
- 시스템 풀의 surge는 `10%`이고 2~3대에서는 1대다. 구독의 vCPU 쿼터에 노드 한 대분의 여유가 있어야 한다.

---

## 7. 하지 않는 것

| 하지 말 것 | 이유 |
|---|---|
| **자동 업그레이드 채널**(`automatic_upgrade_channel`) | Microsoft는 NAP 클러스터에 권장한다. 켜면 컨트롤플레인만 올리는 요청을 AKS가 받지 않고, 컨트롤플레인과 전 노드 풀이 함께 올라간다. 코드에 적은 버전과 실제가 갈린다. 재평가 트리거: 클러스터 수가 사람이 하나씩 올릴 수 없는 규모가 되면 |
| **Azure Kubernetes Fleet Manager**의 update run | 클러스터 버전이 OpenTofu 밖에서 바뀐다. 티어 승격은 배포 루트의 PR 순서로 이미 갈린다 |
| **blue-green 노드 풀 업그레이드** | preview이고 azurerm이 노출하지 않는다. 노드 용량이 두 배 필요하다. 재평가 트리거: GA가 되고 azurerm이 인자를 내면 |
| `upgrade_override`로 **검사를 건너뛰기** | deprecated API 검사와 PDB를 함께 건너뛴다. azurerm에서는 한 번 적은 블록을 지울 수 없다 |
| 컨트롤플레인과 시스템 풀을 **한 apply로** 올리기 | 멈춰 볼 지점이 없다. 되돌릴 수 없는 변경과 되돌릴 수 있는 변경이 한 승인에 묶인다 |
| disruption 차단을 **켠 채로 두기** | 낡은 노드 이미지의 노드가 남고 노드가 합쳐지지 않는다 |
| 시스템 풀 되돌리기를 **절차의 단계로** 두기 | 복구되는 실패가 2절의 한 줄이고, 그 실패는 nonprd의 시스템 풀을 올릴 때 먼저 드러난다 |
| 모듈이 `drain_timeout_in_minutes`·`undrainable_node_behavior`를 **지금 열기** | 한 번 적었다 빼면 azurerm이 리소스를 교체하는데, 시스템 풀에서는 그 대상이 클러스터다. 이 규모에서는 AKS 기본값(drain 30분)으로 충분하다. 재평가 트리거: 시스템 풀의 drain이 기본값으로 실패하면 |
