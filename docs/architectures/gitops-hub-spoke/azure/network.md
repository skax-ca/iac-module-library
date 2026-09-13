# 허브-스포크 연결과 Pod 네트워킹 (Azure)

**읽는 사람**: 허브와 스포크를 실제로 잇고, Pod 대역을 정하는 사람.

AWS의 대응 문서는 [../aws/network.md](../aws/network.md)다. 허브를 어디에 둘지 판정하는 기준은
그 문서와 같고(워크로드가 여러 구독에 걸치는가·격리 요건·장애 반경), 여기서는 **연결 수단이
달라 생기는 차이**만 적는다.

---

## 1. 연결은 허브가 소유한다

AWS는 RAM으로 허브가 Transit Gateway를 공유하면 스포크가 자기 계정 권한으로 attachment를 직접
만든다. **Azure Virtual WAN에는 RAM의 대응물이 없다.** 연결 리소스는 허브 구독에 생기고, ARM은
그 연결을 만드는 호출자(허브 CI 신원)에게 **스포크 VNet에 대한 권한**을 요구한다.

반대 방향(스포크 CI가 연결을 소유)도 검토했으나 기각했다. 그러려면 스포크 CI가 허브의 공유 컨트롤
플레인에 쓰기 권한(`hubVirtualNetworkConnections/write`)을 가져야 해서, 허브가 스포크 VNet에
`peer/action`을 갖는 것보다 훨씬 위험하다.

**대가**: 스포크를 추가할 때마다 부트스트랩을 한 번 더 돌려 권한을 부여해야 한다. 자동으로
상속되지 않는다.

| 방향 | 역할 | 스코프 | 무엇을 할 수 있나 |
|---|---|---|---|
| 허브 → 스포크 | `spoke-peer` | 스포크 워크로드 리소스 그룹 | VNet `peer/action`과 read, 클러스터 read, role assignment read·write·delete |
| 스포크 → 허브 | `hub-peer` | 허브 워크로드 리소스 그룹 | **read 전용**. 스포크가 허브의 ArgoCD 신원을 조회한다 |

⚠️ **스코프가 VNet이 아니라 리소스 그룹이다.** 부트스트랩은 VNet apply보다 먼저 실행되므로 그
시점에 좁힐 대상 리소스가 아직 없다(닭과 달걀). 대가는 허브 신원이 그 리소스 그룹에 나중에 생길
리소스에도 같은 액션을 갖는다는 것이다.

⚠️ **role assignment 권한은 리소스 read와 별개 축이다.** 클러스터를 조회할 권한만으로는 그
클러스터 스코프에 role assignment를 만들지 못한다. plan은 통과하고 apply가 403으로 실패한다.

---

## 2. Virtual WAN 허브

| # | 요소 | 값 |
|---|------|-----|
| 1 | state | VNet 배포 루트와 **분리한다**. 허브를 먼저 세워 두면 하류가 이미 존재하는 실물을 참조한다. AWS에서 Transit Gateway를 `live/hub/tgw`로 떼어 둔 것과 같은 이유다 |
| 2 | 주소 공간 | **생성 후 변경 불가**(Microsoft 공식). 최소 `/24`, 권장 `/23`, 허브 안에 Azure Firewall을 두려면 `/22`가 필요하다. 사설 대역에서 `/22`와 `/23`의 비용 차이는 0이므로 선택지를 남기는 쪽으로 잡는다 |
| 3 | 스포크 연결 | 허브가 소유한다(1절). 스포크 VNet은 태그로 발견한다(3절) |

---

## 3. 값 발견: 태그 기반 `data` 조회

루트 간·구독 간 결합에 remote state를 쓰지 않는다. 같은 구독이면 이름·태그로 `data` 조회하고,
크로스 구독이면 **대상 구독을 향한 별칭 provider**로 같은 태그 조회를 한다.

`azurerm_resources`는 대상이 없으면 에러가 아니라 **빈 리스트**를 반환한다. 그래서 스포크가 아직
없어도 허브 apply는 연결 0개로 정상 종료하고, 스포크가 생긴 뒤 허브를 한 번 더 apply하면 자동으로
발견한다. AWS에서 허브가 복수형 데이터 소스로 attachment를 전부 나열하는 것과 같은 성질이다.

⛔ **CI 변수로 스포크 값을 주입하지 않는다.** 초기에는 스포크 VNet ID를 `workflow_dispatch` 입력으로
넣었는데, push로 도는 plan이나 입력을 빠뜨린 dispatch에서 그 값이 비어 **연결이 destroy로 잘못
계획되는** 위험이 있었다. 태그 조회로 바꿔 그 경로 자체를 없앴다. 필요한 것은 스포크 구독의
`virtualNetworks/read` 하나뿐이다.

---

## 4. Pod 네트워킹: Overlay

Pod IP는 **VNet 밖 오버레이 대역**에서 뜬다. VNet에 Pod 전용 secondary 주소 공간도, Pod 서브넷도
두지 않는다. 노드 서브넷만 있으면 된다.

| 항목 | 내용 |
|---|---|
| 클러스터 간 중복 | **허용된다.** 오버레이가 클러스터마다 독립이라 허브와 스포크가 같은 Pod CIDR을 써도 된다(Microsoft 공식). AWS에서 pod-dup 대역을 모든 VPC가 재사용하는 것과 목적이 같다 |
| 라우팅 노출 | 없다. Pod 트래픽은 클러스터 밖으로 나갈 때 노드 IP로 SNAT된다. 그래서 vWAN 라우팅에서 Pod 대역을 고려할 필요가 없다 |
| 대가 | 그 SNAT 때문에 NSG 플로우 로그에서 Pod를 식별할 수 없다. AKS 유료 기능(ACNS의 Container Network Observability, `--enable-acns`로 켜는 클러스터 기능)이 eBPF로 SNAT 이전 지점에서 잡아 다른 방식으로 메운다 |
| service CIDR | 지정하지 않으면 provider 기본값을 쓴다. 클러스터 로컬 값이라 중복이 무해하다. 다만 이 축도 ForceNew라 나중에 명시하려면 클러스터 재생성이다 |

⛔ **AWS의 Pod 대역 설계를 그대로 옮기지 않는다.** 이 저장소는 한때 Azure CNI Pod Subnet(플랫,
SNAT 없음)을 골라 VNet에 Pod 전용 secondary 대역을 예약했다. Pod 단위 NSG 플로우 로그 가시성을
지키려는 목적이었고, AWS custom networking과 모양을 맞춘 선택이기도 했다. NAP이 Pod Subnet을
지원하지 않는다는 것이 확정되면서 Overlay로 되돌렸다. 가시성 손실은 실재하지만 ACNS로 메울 수
있고, NAP 호환과 서브넷 IP 절약이 그 손실을 상쇄한다고 판단했다.

🔴 `cni_mode`·`pod_cidr`·`private_cluster_enabled`는 `network_profile` 블록 전체가 ForceNew다.
**첫 apply가 사실상 최종 선택이다.**

---

## 5. 스포크 API 서버에 도달하기

허브의 ArgoCD가 스포크 클러스터를 읽으려면 IAM 경계(1절의 role assignment)만으로는 부족하다.
**패킷이 닿아야 한다.** private 클러스터의 API 서버 주소는 private DNS zone이 풀어 주는데, 그
zone은 노드 VNet에만 링크돼 있어 허브에서는 이름이 풀리지 않는다.

두 가지 길이 있다.

| 방법 | 내용 |
|---|---|
| private DNS zone을 허브 VNet에도 링크 | zone 링크를 스포크마다 만들어야 한다 |
| **공개 FQDN을 켠다**(`private_cluster_public_fqdn_enabled`) | 공개 DNS가 **private IP를 그대로 반환**한다. 이름만 공개고 주소는 사설이라, 실제 도달은 vWAN 라우팅이 있는 쪽에서만 된다. zone 링크가 필요 없다 |

이 저장소는 두 번째를 쓴다. 공개 FQDN은 **이름 해석만 공개**이지 엔드포인트를 공개로 바꾸지
않는다. 클러스터를 재생성하면 FQDN의 무작위 접미사가 바뀌므로 등록 Secret을 갱신해야 한다.
