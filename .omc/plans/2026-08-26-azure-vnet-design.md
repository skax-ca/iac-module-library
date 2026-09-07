# Azure `vnet` 모듈 설계 (RALPLAN-DR / SHORT)

**상태**: **v5 — pending approval.** 4회차 Architect(조건부 승인)·Critic(ITERATE, 인라인 수정으로
해소 가능) 둘 다 **설계 재검토 불필요**로 판정. 두 검토의 승인 조건(합계 CRITICAL 0 · MAJOR 5 ·
MINOR 다수, 전부 문안·인수조건 교정)을 병합 반영했다. 축 1~5b 설계 판정은 v4 이후 변경 없음.
**설계 실행(Step 1~5)에는 아직 사용자 승인이 없다.**
**모드**: SHORT (신규 모듈 1개, 소비자 0명, 기존 계약 파괴 없음).
**스코프**: **설계 문서만.** `.tf` 파일과 `modules/azure/` 디렉터리를 만들지 않는다.

> 변경 로그는 8절. **v3에서 거짓으로 판명돼 철회한 논거 2건**(공용 LB 백엔드가 끊긴다 · Bastion 예시)과
> **AWS 선례를 정반대로 인용한 것 1건**(NAT precondition)이 v4에서 반영됐다. v5는 4회차 검토가
> 찾은 잔여 결함(예약 이름 목록 불완전 · NAT `StandardV2` preview 미기재 · AppGw 데이터 플레인
> 델타 누락 · 인수 조건 커버리지 구멍)을 반영한다.
>
> ⚠️ **v1~v3은 세 라운드 연속 같은 종류로 틀렸다**: 검증하지 않은 것을 근거로 썼다.
> v1은 추정(Policy)을, v2는 거짓 사실(빈 NSG = no-op)을, v3은 **검증 없이 뒤집은 사실**
> (빈 NSG가 공용 LB를 끊는다)을 썼다. v4의 0절은 **모든 사실 문장에 조회한 원문 인용**을 붙였고,
> 인용 없는 문장은 근거로 쓰지 않는다. **v4·v5의 잔여 결함은 같은 성격이 아니다** — 사실관계는
> 정확했고, 목록 완결성·인수조건 커버리지 같은 **범위** 문제였다(4회차 Architect·Critic 공통 진단).

---

## 0. 착수 전 실측 사항

### 0-1. 인라인 `subnet`과 `azurerm_subnet`은 상호 배타다

> *"At this time you cannot use a Virtual Network with **in-line Subnets** in conjunction with any
> Subnet resources. Doing so will cause a conflict of Subnet configurations and **will overwrite subnets**."*
> (`azurerm_virtual_network` · `azurerm_subnet` 양쪽 문서)

⚠️ **경고의 적용 범위가 "인라인 블록과 별도 리소스의 병용"으로 한정돼 있다.** 0-7이 이 범위를 쓴다.

### 0-2. NAT Gateway는 인라인 서브넷에 붙일 수 없다

인라인 `subnet` 블록의 지원 인자 전량(실측): `name` · `address_prefixes` · `security_group` ·
`default_outbound_access_enabled` · `delegation` · `private_endpoint_network_policies` ·
`private_link_service_network_policies_enabled` · `route_table_id` · `service_endpoint` ·
`service_endpoint_policy_ids`.

**`nat_gateway_id`가 없다.** 연결 경로는 `azurerm_subnet_nat_gateway_association` 하나뿐이고
그 리소스는 서브넷을 조작하므로 0-1의 경고 대상이다. 절충안이 없다.

### 0-3. Azure 서브넷은 존(zone)에 속하지 않는다

| `modules/aws/vpc` | `vnet`에서 | 소멸 사유 |
|---|---|---|
| `az_count` · `az_selection` | **삭제** | 서브넷에 존 축이 없다(리전 전체에 걸친다) |
| `subnet_groups[*].cidrs`(AZ 순서 리스트) | `address_prefixes`(그룹당 서브넷 1개) | 〃 |
| AZ별 라우팅 테이블 분기 | 없다 | 〃 |
| `single_nat_gateway` | **삭제.** 대응 손잡이는 `nat_gateway_sku_name`(0-10) | 이중화를 존이 아니라 **SKU**가 결정한다 |
| `eks_cluster_name`(서브넷 디스커버리 태그) | **삭제** | 서브넷이 `tags`를 지원하지 않는다(0-5) |

### 0-4. NSG Flow Log는 신규 생성이 막혔고 2027-09-30에 완전 은퇴한다

- provider: *"As of July 30, 2025, it is no longer possible to create new flow logs for Network Security Groups."*
- [NSG overview](https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview):
  *"NSG flow logs **retire on September 30, 2027**... it no longer supports new NSG flow logs creation."*

따라서 `target_resource_id`는 **VNet**이어야 하고 `storage_account_id`가 **필수**다.
⚠️ provider가 결함을 명시한다: *"creates a new storage lifecyle management rule that
**overwrites existing rules**"* ([#6935](https://github.com/hashicorp/terraform-provider-azurerm/issues/6935)).

### 0-5. Azure 서브넷은 태그를 지원하지 않는다

`azurerm_subnet`과 인라인 `subnet` 블록 **양쪽 다 `tags` 인자가 없다**(실측).
공통 규약 *"모든 리소스에 태그를 단다"* 가 서브넷에서 **구조적으로 달성 불가**다.

### 0-6. 🔴 빈 NSG의 실제 델타 — **막는 것은 Azure 컨트롤 플레인뿐이다** (v2·v3 양쪽 정정)

이 항목이 두 번 틀렸다. **v2**: *"빈 NSG는 no-op이다"*(거짓). **v3**: *"빈 NSG는 공용 LB 백엔드를
조용히 끊는다"*(**이것도 거짓**). 이번에는 두 출처를 모두 조회해 **델타를 항목별로** 적는다.

**출처 A** — [NSG overview](https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview),
「Default security rules」: *"Azure creates the following default rules in **each network security group
that you create**"* / *"**You can't remove the default rules**"*

| 방향 | 규칙 | 우선순위 | 원본 -> 대상 | 동작 |
|---|---|---:|---|---|
| In | `AllowVNetInBound` | 65000 | VirtualNetwork -> VirtualNetwork | Allow |
| In | `AllowAzureLoadBalancerInBound` | 65001 | AzureLoadBalancer -> 0.0.0.0/0 | Allow |
| In | `DenyAllInbound` | 65500 | 0.0.0.0/0 -> 0.0.0.0/0 | **Deny** |
| Out | `AllowVnetOutBound` / `AllowInternetOutBound` / `DenyAllOutBound` | 65000 / 65001 / 65500 | | Allow / Allow / Deny |

**출처 B** — [What is Azure Load Balancer?](https://learn.microsoft.com/en-us/azure/load-balancer/load-balancer-overview),
「Security features > Network access controls」:

> *"Standard load balancers and public IP addresses are **closed to inbound connections by default**.
> Network Security Groups (NSGs) must explicitly permit allowed traffic.
> **Traffic is blocked if no NSG exists on a subnet or NIC.**"*
> *"Basic Load Balancer is open to the internet by default and **was retired on September 30, 2025**."*

**두 출처를 합치면 델타는 이렇게 갈린다**:

| 경로 | NSG 미부착 | 빈 NSG 부착 | 델타 |
|---|---|---|---|
| 공용 **Standard** LB 백엔드 · NIC의 **Standard** 공용 IP | **차단**(출처 B, secure by default) | 차단(`DenyAllInbound`) | **없음** |
| VNet 내부·피어링 | 허용 | 허용(`AllowVNetInBound`) | **없음** |
| Azure LB 상태 프로브 | 허용 | 허용(`AllowAzureLoadBalancerInBound`) | **없음** |
| 아웃바운드(인터넷·VNet) | 허용 | 허용(`AllowInternetOutBound`·`AllowVnetOutBound`) | **없음** |
| **그 밖의 Azure 서비스 태그발 인바운드**(`GatewayManager` 등 컨트롤 플레인) | **허용** | **차단**(`DenyAllInbound`) | ⚠️ **있다 — 파괴 방향** |
| **네트워크 주입형 PaaS의 공용 리스너 클라이언트 트래픽**(AppGw 등, 아래 확인된 사례 참조) | **허용** | **차단**(NSG 미부착 시 필수 룰 개념 자체가 없다) | ⚠️ **있다 — 파괴 방향** |

⚠️ **첫 행은 Standard LB 백엔드·NIC 공용 IP에만 성립한다.** AppGw·App Service Environment·
HDInsight 같은 **서브넷 주입형 PaaS**는 이 행이 커버하지 않는다 — 아래 확인된 사례가 그 여섯째 경로다.

🔑 **결론 두 개, 둘 다 옵트인을 지지한다**:

1. **v3의 "공용 LB 백엔드가 끊긴다"는 성립하지 않는다.** Standard가 이미 차단 상태이고
   Basic은 은퇴했으므로 **이 주장이 성립하는 SKU가 하나도 없다.** 이 경로의 델타가 0이다.
2. **그러나 빈 NSG는 여전히 no-op이 아니다**(v2도 틀렸다). 델타가 있는 두 경로(컨트롤 플레인
   인바운드, 서브넷 주입형 PaaS 클라이언트 트래픽) **모두 파괴 방향이다.** 보안을 더하지 않는다.

**확인된 파괴 사례** — [Application Gateway infrastructure configuration](https://learn.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure),
「Network security groups > Required security rules > Inbound rules」:

> *"**Infrastructure ports**: Allow incoming requests from the source as the **GatewayManager** service tag
> and **Any** destination... **V2: Ports 65200-65535** / V1: Ports 65503-65534"*
> *"Allow incoming traffic from the expected clients... for the destination as your application gateway's
> entire subnet IP prefix and inbound access ports"* (**Client traffic** 룰 — 공용 리스너로 오는
> 실제 요청 트래픽. 컨트롤 플레인과 별개다)

NSG는 AppGw에 **선택**이지만(*"You can use NSGs for your Application Gateway subnet"*),
붙이는 순간 이 두 룰(GatewayManager 컨트롤 플레인 + 클라이언트 트래픽)이 **모두 필수**가 된다.
빈 NSG는 둘 다 허용하지 않으므로 AppGw의 **관리 평면과 공용 데이터 평면을 동시에** 끊는다.
같은 문서(출처 A)가 일반 경고도 남긴다: *"Instances of several Azure services, such as HDInsight,
Application Service Environments, and Virtual Machine Scale Sets, are deployed in virtual network
subnets... If you deny ports required by the service, the service doesn't function properly."*

> ⛔ **`decisions.md`의 Kyverno 유비를 이 계획에서 인용하지 않는다.** Kyverno 정책 0개는 진짜
> no-op이지만 빈 NSG는 컨트롤 플레인 트래픽을 실제로 막는다.
> ⚠️ **`decisions.md`의 그 기각 행 자체는 손대지 않는다** — 「GitOps와 ArgoCD」 절의 별개 ADR이고
> NSG와 무관하며 지금도 참이다.

### 0-7. 🔴 예약 이름 서브넷은 이 모듈이 만들 수 없다 (능력 한계)

일부 Azure 서비스는 **정확한 예약 이름**의 전용 서브넷을 요구한다. 확인한 것 셋:

| 서브넷 이름 | 요구 서비스 | 출처 |
|---|---|---|
| `AzureBastionSubnet` | Azure Bastion | [Bastion configuration settings](https://learn.microsoft.com/en-us/azure/bastion/configuration-settings): *"Bastion requires a dedicated subnet named **AzureBastionSubnet**"* / *"Subnet name must be *AzureBastionSubnet*"* / *"Subnet size must be /26 or larger"* |
| `GatewaySubnet` | VPN Gateway | [AppGw infrastructure configuration](https://learn.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure): *"The subnet named `GatewaySubnet` is **reserved for VPN gateways**"* |
| `AzureFirewallSubnet` | Azure Firewall | [Azure Firewall FAQ](https://learn.microsoft.com/en-us/azure/firewall/firewall-faq): 정확한 이 이름과 **/26 이상**의 서브넷 크기를 요구한다. *"Subnet-level NSGs aren't required on the AzureFirewallSubnet and are disabled to prevent service interruptions"* — Azure 플랫폼 자신이 이 서브넷에서 NSG를 비활성화한다(0-6의 컨트롤 플레인 논거를 뒷받침하는 별개 데이터 포인트) |

⚠️ **Azure에 이런 예약 이름이 더 있을 수 있으나 이 라운드에서 확인한 것은 위 셋이다.** 추정으로 늘리지 않는다.
**이 한정어는 이 계획 안에만 두지 않는다** — Step 3.2·ADR Consequences에 실리는 산출물 문안에도
*"확인한 것은 이 셋이며 더 있을 수 있다"* 를 그대로 넣는다(계획 전용 문서와 배송 문서를 분리해
한정어가 계획에만 살아 있던 v4의 결함을 반복하지 않는다).

**이 모듈의 네이밍 계약은 이 이름들을 만들 수 없다.** 서브넷 이름이
`snet-<workload>-<env>-<region>-<purpose>`로 조합되고 `subnet_groups`에 이름 오버라이드 인자가 없다.

**따라서 예약 이름 서브넷은 배포 루트가 같은 vnet에 `azurerm_subnet`으로 직접 만든다.**
0-1의 경고는 문면상 **인라인 블록과 별도 리소스의 병용**만 금지하고, 이 모듈은 인라인 블록을
쓰지 않으므로(0-9) 그 경고의 대상이 아니다.
⚠️ **다만 이것은 문서 문면의 범위 해석이고 `apply`로 검증하지 않았다.** 구현 라운드의 예제에서 확인한다.

> ★ **AppGw는 예약 이름이 없다**(*"a dedicated subnet is required"* 이지만 이름 제약은 없다).
> 그래서 0-6의 파괴 사례로 AppGw만 남았다 — **이 모듈이 실제로 만들 수 있는 서브넷**이기 때문이다.
> Bastion·Azure Firewall은 이 모듈이 만들 수 없으므로 애초에 예시가 될 수 없다.

### 0-8. Azure Policy가 NSG·라우팅 테이블을 강제하는 환경은 association으로 커버되지 않는다

`azurerm_subnet`에 write-only 인자가 **둘** 있고 주석 문면이 동일하다:

| 인자 | 문면 |
|---|---|
| `network_security_group_id_wo` | *"only meant for environments where **Azure Policy requires Network Security Groups to be specified during Subnet creation/update**. It is recommended to use the association resource instead."* |
| `route_table_id_wo` | *"only meant for environments where **Azure Policy requires Route Tables to be specified during Subnet creation/update**..."* |

> ⚠️ **이 항목이 무엇을 못 가르는지**: 0-8은 v1의 *"Policy가 강제하니 기본 켬"* 근거를 **무효화**하지만
> **옵트인과 기본생성을 가르지는 못한다**(켜지면 둘 다 association을 쓴다). 축 3의 근거는 **0-6이다.**

### 0-9. 인라인 `subnet`·`dns_servers`를 `[]`로 두면 별도 리소스가 삭제된다

> *"Since `subnet` can be configured both inline and via the separate `azurerm_subnet` resource,
> **we have to explicitly set it to empty slice (`[]`) to remove it**."* (`dns_servers`도 동일)

🔑 **`azurerm_virtual_network`에 두 인자를 아예 쓰지 않는다. 빈 값으로도 쓰지 않는다.**

### 0-10. NAT Gateway: 이중화는 `sku_name`이 결정하고, 그 변경은 아웃바운드 IP를 바꾼다

| 인자 | 문면 |
|---|---|
| `sku_name` | `Standard`(기본) · `StandardV2`. **Changing this forces a new resource to be created** |
| `zones` (Standard) | *"may be omitted for a no-zone deployment or set to **a single** Availability Zone"*. **ForceNew** |
| `zones` (StandardV2) | *"**must be omitted**. zone-redundant by default"* |

1. `Standard`는 무존이거나 단일 존이다. AWS의 *"AZ별 NAT"* 대응물은 **`StandardV2`** 다.
2. ⚠️ **둘 다 ForceNew** -> 공용 IP **재발급** -> **아웃바운드 IP 변경** -> 고객사 방화벽 allowlist 직결.
3. 🔴 **`StandardV2`는 preview다.** [NAT Gateway SKUs](https://learn.microsoft.com/en-us/azure/nat-gateway/nat-sku):
   *"Standard V2 SKU Azure NAT Gateway is currently in **PREVIEW**"*, 일부 리전 미지원(SLA 대상 아님).
   **GA 기준으로는 존 이중화 NAT 경로가 아예 없다** — `Standard`는 무존이거나 단일 존뿐이다.
   기본값(`Standard`)은 이 상태를 밟지 않으므로 착수를 막지는 않지만, 축 5b Option B 기각과
   ADR Consequences에 이 사실을 명시한다. koreacentral의 `StandardV2` 지원 여부는 미확인 —
   Follow-up으로 이관한다.

### 0-11. `default_outbound_access`: 소비자가 모듈 밖에서 설정할 수단이 없다

provider: `default_outbound_access_enabled` **"Defaults to `true`"**.
[Default outbound access](https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/default-outbound-access):

> *"In the API version released after **March 31, 2026**... **Earlier versions of ARM templates
> (or tools like Terraform that can specify older versions) will continue to set
> `defaultOutboundAccess` as null, which implicitly allows outbound access.**"*

⚠️ 그 날짜는 이미 지났고, provider가 `true`를 명시 설정하므로 이 모듈의 서브넷은 자동으로 private가
되지 않는다. **서브넷을 모듈이 소유하므로 소비자가 바꿀 방법이 없다.**
-> `subnet_groups`에 `default_outbound_access_enabled = optional(bool, true)` 노출(기본값은 provider와 동일).

### 0-12. 🔴 v3이 AWS NAT 선례를 **정반대로** 인용했다

`modules/aws/vpc/main.tf` 실물 대조:

```hcl
# 69행 주석: private 그룹이 없으면 NAT를 만들지 않는다 — 걸어줄 경로가 없고 유휴로도 과금된다.
# 70행
nat_enabled = local.enabled && var.enable_nat_gateway && local.nat_group != null
              && length(local.private_group_names) > 0        # <- 수요 0개면 조용히 스킵

# 149행 precondition
condition = !var.enable_nat_gateway || length(local.private_group_names) == 0
            || local.nat_group != null                        # <- 수요 0개는 명시적 면제
```

**선례의 구조는 둘로 나뉜다**: **수요 0개 -> 조용한 스킵**(70행), **수요는 있는데 호스트할 public
그룹이 없음 -> precondition**(149행). 149행의 `length(...) == 0`이 **수요 0개를 정확히 면제하는 조항**이다.

**v3은 정확히 그 면제 케이스에 precondition을 걸었다.** 게다가 v3의 기본값 조합
(`nat_gateway_enabled` 기본 `true` + `nat_routed` 기본 `false`)이 바로 그 케이스이므로,
**소비자가 최소 구성으로 apply하면 모듈 자기 기본값 때문에 plan이 깨진다.**

-> **선례 그대로 간다: `nat_routed = true` 그룹이 0개면 NAT를 만들지 않는다(조용한 스킵). precondition을 걸지 않는다.**
고아 NAT 방지 목적은 조용한 스킵만으로 달성된다 — 붙일 서브넷이 없으면 애초에 안 만든다.

### 0-13. 인수 조건이 **세 라운드 연속** 측정 불능이었다

| 라운드 | 조건 | 증상 |
|---|---|---|
| v1 | `E1` | 작업 전에도 통과(두 미결이 한 문장으로 묶여 있다) |
| v1 | `D1` | 헤더 한 줄만 출력(시작 줄이 종료 패턴에도 매치) |
| v2 | `C1` | `subnet_ids_by_group`이 소싱 예제에 이미 있어 표 없이 통과 |
| **v3** | **`E2` 커버리지 구멍** | ⚠️ Step 2(a)가 **네 곳** 수정을 지시하는데 조건은 **두 곳**만 본다(아래) |

**v3 `E2` 구멍 실측**:

```
awk '/^### 공통 강제 방식/{f=1} f&&/^### AWS 강제 방식/{exit} f' -> 14줄, 첫 줄 "### 공통 강제 방식"
  '태그 포맷' 포함 건수: 0     <- 절 제목(20행)은 39행부터 시작하는 범위 밖이다
  범위 안 Name 등장: 6행(공통 1번) · 12행(공통 4번)
  E2 패턴 'Name` 태그 assertion' 은 12행만 매치  <- 공통 1번을 안 본다
```

즉 **공통 4번만 고쳐도 E2·E2b가 통과한다.** -> `E2c`(공통 1번) · `E2d`(절 제목) 신설.

> 🔑 **반복 패턴 둘**: ① 파일 전역 `grep`은 "그 절에 있는가"를 판정하지 못한다
> ② **지시한 수정 건수와 인수 조건 건수가 어긋나면 그 차이만큼 검사되지 않는다.**

**v4 교체본 실행 기록** (전부 현재 트리에서 돌렸다):

| 조건 | 현재 트리(작업 전) | 양성 픽스처 | 판별력 |
|---|---|---|---|
| `C1`(표 범위 awk) | 표 추출 **0줄** -> 3건 실패 | 표 픽스처에서 3건 통과 | ✅ |
| `E1`(머리 문장 / 제약 표) | 둘 다 실패 | 볼드 전체·부분 감쌈 모두 통과 | ✅ 마크업 내성 |
| `E1`(남은 미결 불릿) | **통과** | | ✅ 존치 가드라 정상 |
| `E2`(공통 4번) · `E2b`(링크) | 둘 다 실패 | | ✅ |
| `D1`(절 본문 awk) | **0줄** 실패 | `##` **7줄 통과** / `###` **0줄 실패** | ✅ 절 레벨 판별 |
| `A6` · `E5` | 각각 **0** | | ✅ |

⚠️ **신규 파일 대상 조건**(`A1`~`A5`)은 `azure.md`가 없어 통과 방향을 관측할 수 없다.
**산출물 생성 후 최초 실행 시 검증**한다.

### 0-14. 게이트 준비 상태 — 구현 라운드 착수 게이트 4건

| 위치 | 현재 | `vnet` 릴리스 시 |
|---|---|---|
| `.tflint.hcl` | `aws` ruleset만 | azurerm **미등록** -> 게이트 ②가 Azure를 전혀 린트 못 한다 |
| `.githooks/pre-commit` | `tflint --recursive`만, **`--init` 없음** | ⚠️ ruleset 추가 커밋에서 훅이 죽는다 |
| `pre-commit` stale 태그 검사 | 목록에 `vnet` 없음 | **조용히 통과**(미탐) |
| `conventions.md` 「도구·provider 핀」 | **azurerm 행 없음** | ⚠️ 핀 SSOT 미갱신 -> *"CI와 로컬 훅을 일치시킨다"* 선언이 거짓이 된다 |

### 0-15. 문서 게이트가 실제로 검사하는 것

`validate-doc-conventions.py` 실측 — 기계 검사는 **4종**이다:
① `§` 인용 금지 ② 이모지 **7종만**(`✅⏳❌⚠️⛔🔴🔑`) ③ 400줄 ④ **em-dash(`—`) 금지**.

- ⚠️ `azure.md`는 ③의 예외이지 **④의 예외가 아니다.**
- ⚠️ *"날짜·'실측했다' 류 서술 금지"* 는 **기계 검사 대상이 아니다**(사람 규칙).
- 실측 줄수: `conventions.md` **272** · `module-catalog.md` **165** · `decisions.md` **146**.

---

## 1. RALPLAN-DR 요약

### Principles

| # | 원칙 |
|---|---|
| **P1** | **Azure 리소스 모델에 맞춘다.** `vpc` 인터페이스를 이식하지 않는다(0-3) |
| **P2** | **문서는 소유자가 하나다.** 약어=카탈로그, 포맷·태깅·핀=`conventions.md`, 배선=`module-catalog.md`, 기각=`decisions.md` |
| **P3** | **인용 없는 문장은 근거로 쓰지 않는다.** 이 계획이 **세 라운드 연속** 이 원칙을 어겼다(추정 -> 거짓 사실 -> **검증 없이 뒤집은 사실**). 0절의 모든 사실 문장에 조회한 원문을 붙인다 |
| **P4** | **게이트를 증명할 수 있을 때만 넣는다.** 구현 라운드에서 tflint azurerm 전제가 소멸한다 |
| **P5** | **지금 요구를 채우는 가장 단순한 형태.** ⚠️ 기본값이 소비자 워크로드를 바꾸지 않게 한다 |
| **P6** | **선례를 인용할 때는 실물을 열어 대조한다.** 0-12가 이 원칙의 실패 사례다 |

### Decision Drivers (상위 3)

| # | 드라이버 | 왜 이것이 결정을 가르는가 |
|---|---|---|
| **D1** | **서브넷 부속 리소스 지원 가능 여부** | 0-1·0-2가 축 1을 **기술적으로 강제**한다 |
| **D2** | **파괴의 폭발 반경** | RG 캐스케이드 삭제(축 2) · **컨트롤 플레인을 끊는 기본값**(0-6) · **자기 기본값으로 깨지는 plan**(0-12) |
| **D3** | **게이트가 있는 척하지 않을 것** | ruleset 미등록 · 핀 표 누락 · **지시 4곳 대 조건 2곳**(0-13)이 전부 같은 결함이다 |

### 실행 가능 옵션

#### 축 1: 서브넷 표현

| | **Option A: `azurerm_subnet` 별도 리소스 (채택)** | Option B: 인라인 `subnet` |
|---|---|---|
| Pros | NAT·NSG·RT 연결 전부 가능. `for_each`가 맵에 자연 대응 | 리소스 수가 적다 |
| Cons | 연결 리소스 3종 추가. 0-9의 `[]` 함정을 문서로 막아야 한다 | ⛔ **NAT를 붙일 수 없다**(0-2) |
| 판정 | **채택** | **기각 — 기술적 불가** |

#### 축 2: 리소스 그룹 소유권

| | **Option A: 주입 (채택)** | Option B: 모듈이 생성 |
|---|---|---|
| Pros | 파괴 반경이 모듈 자산으로 한정된다 | 소비자가 RG를 미리 안 만들어도 된다 |
| Cons | 배포 루트가 RG를 먼저 만든다 | ⛔ **RG 삭제는 내부 전체를 캐스케이드 삭제**한다 |
| 판정 | **채택** | 기각 |

#### 축 2b: `location`을 어떻게 얻는가

| | **Option A: 필수 입력 (채택)** | Option B: RG 데이터 소스에서 파생 | Option C: 선택 입력, null이면 파생 |
|---|---|---|---|
| Pros | 데이터 소스 의존 0. **배포 성공이 소비자 배선 형태에 좌우되지 않는다.** 다른 리전 배치를 막지 않는다 | 입력 1개 감소. 리전 불일치가 구조적으로 불가능 | 양쪽 가능 |
| Cons | 입력 1개 증가. 리전 불일치를 못 막는다 | ⚠️ read의 apply 연기는 **조건부 동작**이다(*"data 블록이 이번 plan에서 변경 예정인 관리 리소스에 직접 의존할 때"*). 리터럴을 넘기면 plan에서 실패하므로 **배포 성공이 소비자 배선에 좌우된다**. RG Reader 권한도 필요 | 분기 2개를 문서화·테스트해야 한다(P5) |
| 판정 | **채택** | 기각 | 기각 |

> **명시 답변**: 배포 루트는 **RG와 `vnet`을 한 apply에서 세울 수 있다.** 모듈이 RG를 읽지 않는다.

#### 축 3: NSG·라우팅 테이블 (**0-6 재확인으로 근거가 다시 교체됐다**)

| | **Option A: 둘 다 옵트인, 모듈이 소유 (권고)** | Option B: 둘 다 안 만든다 | Option C: NSG 기본 켬 |
|---|---|---|---|
| 동작 | `nsg_enabled` · `route_table_enabled` 기본 `false`. 켜면 모듈이 리소스 + association 소유 | 소비자가 생성·연결 | NSG 기본 `true`(룰 0개) |
| Pros | **소유 경계가 맞는다** — association이 `subnet_id`를 요구하는데 서브넷은 모듈 소유다. **그리고 기본값이 어떤 경로의 트래픽도 바꾸지 않는다** | 모듈이 가장 얇다 | 앵커가 항상 준비돼 있다(운영 편의) |
| Cons | 소비자가 켜는 것을 잊을 수 있다 | ⛔ association이 모듈 소유 서브넷 ID를 요구해 경계가 어긋난다 | ⛔ **컨트롤 플레인 인바운드와 서브넷 주입형 PaaS 클라이언트 트래픽을 끊는다**(0-6). 확인된 사례: **Application Gateway**(`GatewayManager` 65200-65535 컨트롤 플레인 + 클라이언트 트래픽 룰 둘 다 필수). ⛔ **보안 이득은 Standard LB·공용 IP 경로에 한해서만 없다**(그 경로는 NSG 없이도 이미 차단, 출처 B) — VNet 내부는 빈 NSG도 허용한다 |
| 판정 | **권고 — 착수 게이트 G2로 확인만 받는다** | 기각 | 기각 |

**권고 사유(0-6의 델타 표 기준)**:

1. **빈 NSG의 델타는 파괴 방향 두 곳뿐이다.** 공용 Standard LB·공용 IP·VNet 내부·LB 프로브·아웃바운드는
   **델타 0**이고, 컨트롤 플레인 인바운드와 서브넷 주입형 PaaS 클라이언트 트래픽만 **델타가 있다.**
   즉 기본 켬은 **보안을 더하지 않으면서 AppGw 같은 서브넷 주입형 서비스만 끊는다.**
2. **"NSG 부재 = 인터넷 노출"이 아님이 문서로 확인됐다**(출처 B: **Standard LB·공용 IP에 한해**
   *"closed to inbound connections by default"*, *"Traffic is blocked if no NSG exists"*).
   ⚠️ 이 사유는 **Standard LB·NIC 공용 IP 경로에만 적용된다** — 네트워크 주입형 PaaS(AppGw 등)에는
   적용되지 않는다(사유 1이 그 경로를 별도로 다룬다). v1~v3이 근거 없이 가정했던 것이 이제
   반증된 상태로 확정됐다.
3. **선례**: `modules/aws/vpc`는 보안 그룹을 만들지 않는다.

> 🔴 **G2는 이제 가치 판단이 아니라 확인 절차다.** v3은 이것을 *"보안 대 가용성"* 으로 적었으나,
> 0-6의 델타 표가 나온 뒤로는 **기본 켬 쪽에 남은 이득이 "앵커가 미리 있다"는 운영 편의뿐**이다.
> 그래도 게이트로 두는 이유는 **`open-questions.md`의 NSG 기본값 미결을 계획이 일방적으로 닫지 않기
> 위해서**다(v2가 그렇게 했다가 지적받았다). ⚠️ **사유 2는 이 판정의 필요조건이 아니다** — 사유 2가
> 무너지더라도(예: LB 문서가 갱신돼 secure-by-default가 바뀌더라도) 사유 1·3만으로 옵트인 판정은
> 유지된다.

#### 축 4: Flow Logs를 `0.1.0`에 넣는가

| | **Option A: 제외 (권고)** | Option B: 포함(스토리지 계정 주입) |
|---|---|---|
| Pros | ⚠️ **고객사의 기존 스토리지 lifecycle 규칙을 파괴할 위험을 지지 않는다**(#6935). 산출물이 고객사 배송 계약이라 남의 스토리지 정책을 조용히 덮어쓰는 경로를 첫 모듈에 넣을 수 없다. 부차적으로 전역 고유 이름 제약도 회피 | `vpc`와 관측성 패리티 |
| Cons | `vpc`에 있는 Flow Logs가 없다 | 주입 인자 3개 증가. plan 단계 검증뿐 |
| 판정 | **권고** — Follow-up 1로 `vnet-v0.2.0` 이관 | 사용자 판단 대상 |

> 🔴 **라운드 전체 착수 게이트(G1).** 뒤집히면 약어가 6종에서 늘어 Step 1 산출물 4곳이 전부 바뀌고,
> Step 2가 쓰라고 지시하는 문장도 거짓이 된다.

#### 축 5: facade인가 스크래치인가

| | **Option A: 스크래치 얇은 모듈 (채택)** | Option B: AVM wrapper |
|---|---|---|
| 근거 | 계층형 하이브리드 기준. VNet·서브넷·NSG·NAT는 Azure에서 가장 안정된 계층 | upstream이 존 배치·IPAM을 다룬다 |
| Cons | 직접 작성 | 변수 rename 흡수 + 정확 핀 관리. 안정 리소스에 낼 비용이 아니다 |
| 판정 | **채택** | 기각 |

#### 축 5b: NAT Gateway 손잡이

| | **Option A: `nat_gateway_sku_name` 노출, 기본 `"Standard"` (채택)** | Option B: `StandardV2` 고정 | Option C: 손잡이 없음 |
|---|---|---|---|
| Pros | 소비자가 비용과 가용성을 고른다. provider 기본값과 같아 놀라움이 없다 | 항상 존 이중화 | 인터페이스가 작다 |
| Cons | 인자 1개 증가 | 비용을 모듈이 강제한다. 🔴 **`StandardV2`는 preview다**(0-10) — SLA 대상 아님, 일부 리전 미지원. 배송 모듈의 기본값으로 preview를 강제할 수 없다 | ⛔ **존 이중화를 고를 수단이 없다**(0-10) |
| 판정 | **채택** | 기각 | 기각 |

---

## 2. Guardrails

### Must Have

- **산출물은 문서뿐이다.** 범위: `docs/` **5개** + `.omc/` **4개**.
- 문서 전용이므로 **`main` 직접 커밋**. ⛔ PR을 쓰지 않는다.
- `azure.md`는 `validate-abbreviations.py`를 무수정 통과해야 한다.
- ⚠️ **`azure.md`는 400줄 예외이지 em-dash 예외가 아니다**(0-15).
- 약어는 `vnet`이 실제로 만드는 리소스에 한정. 예측성 추가 금지.
- **모든 사실 문장에 출처 링크**(P3). **선례 인용은 실물을 열어 대조한다**(P6).
- **인수 조건은 범위를 먼저 잘라낸 뒤 판정한다**(0-13).
- ★ **지시한 수정 건수와 인수 조건 건수를 맞춘다.** 어긋나면 그 차이만큼 검사되지 않는다(0-13).
- ⚠️ **`★`는 이 계획 문서 전용 마커다.** `docs/`로 나가는 산출물 문안에 그대로 옮기지 않는다 —
  `validate-doc-conventions.py`가 비표준 이모지로 rc=1을 낸다(현재 `docs/` 전체에 `★` 0건).
  이 계획의 `★`가 붙은 지시 문장을 산출물에 반영할 때는 `★`를 뗀다.

> ⚠️ **인수 조건의 성격을 세 가지로 구분해 적는다**(v3 문면이 자기 조건과 충돌했다):
> ① **전환 가드**(기존 파일 대상) — 작업 전 실행해 **실패를 확인한 것만** 올린다.
> ② **회귀·존치 가드**(`C2`·`C3`·`C5`·`E1`의 미결 불릿) — **작업 전 통과가 정상이다.**
>    무언가가 사라지거나 되살아나지 않았음을 지키는 조건이므로 표에 그 취지를 적는다.
> ③ **신규 파일 대상**(`A1`~`A5`) — 통과 방향을 원리적으로 관측할 수 없다.
>    **산출물 생성 후 최초 실행 시 검증**한다. *"전부 실행 확인했다"* 고 쓰지 않는다.

### Must NOT Have

- ⛔ `.tf` 생성 금지. `modules/azure/` 디렉터리도 만들지 않는다.
- ⛔ `.tflint.hcl` · `.githooks/*` · `verify.yml` 수정 금지(구현 라운드 스코프).
- ⛔ `docs/designs/` 같은 새 문서 종류 신설 금지(P2).
- ⛔ Azure Policy 태그 상속 × OpenTofu state 상호작용을 추정으로 서술 금지(P3).
- ⛔ **"Policy가 NSG를 강제한다"를 축 3 근거로 사용 금지**(0-8).
- ⛔ **"빈 NSG는 아무것도 하지 않는다" 금지**(v2 오류) **그리고 "빈 NSG가 공용 LB를 끊는다" 금지**(v3 오류).
  0-6의 델타 표 밖으로 나가지 않는다.
- ⛔ **Bastion을 NSG 파괴 사례로 인용 금지** — 이 모듈이 만들 수 없는 서브넷이다(0-7).
- ⛔ **이 계획에서 Kyverno 유비 인용 금지.** 단 `decisions.md`의 그 기각 행 자체는 손대지 않는다.
- ⛔ 기존 AWS 약어 개명·태그 재발행 금지. `eks-reference-infra` 수정 금지.

---

## 3. Task Flow

```
[착수 게이트 — 사용자 확정 2건, 한 지점에서 함께 받는다]
   G1  Flow Logs 를 0.1.0 에 포함하는가     (권고: 제외)   -> Step 1·2·3·4 전부에 영향
   G2  NSG 를 그룹마다 기본 생성하는가       (권고: 옵트인) -> Step 3·4 만
              |
              v
main 직접 커밋 (문서 전용, PR 없음)
  Step 1  azure.md 신설 + docs/README.md 등재
  Step 2  conventions.md — 공통 절 중립화(4곳) + 항목 재배치 + 제약/리전코드
  Step 3  module-catalog.md — vnet 배선 + 인터페이스 초안
  Step 4  decisions.md — ADR 등재 (평면 `##` 절)
  Step 5  구현 라운드 착수 명세 + .omc/ 갱신
              |
              v
        [사용자 승인] -> 구현 라운드 (별도 승인 · 브랜치 -> PR)
```

> G1만 라운드 전체를 막는다. G2는 Step 3·4만 바꾸지만 **단일 커밋이라 한 지점에서 함께 받는다.**

### 구현 라운드 착수 게이트 (범위 밖, 명세만)

| # | 항목 | 근거 |
|---|---|---|
| 1 | `pre-commit`에 `tflint --init` 추가 | **선행 필수**(0-14). ⚠️ **rate limit** 대응으로 `GITHUB_TOKEN=$(gh auth token)` — `.claude/rules/terraform.md`가 이미 그 명령을 문서화했다 |
| 2 | `.tflint.hcl`에 azurerm ruleset 정확 핀 | P4 |
| 3 | `pre-commit` stale 태그 목록에 `vnet` | 없으면 미탐 |
| 4 | **`conventions.md` 핀 표에 azurerm provider 하한 + ruleset 핀** | 핀 SSOT. `versions.tf` 하한 정책도 이 표가 소유 |

---

## 4. Detailed TODOs

### Step 1 — `azure.md` 신설 + `docs/README.md` 등재

**하는 일**

1. `aws.md`와 같은 구조로 만든다.
2. ⚠️ **등재 규칙 1항은 복사할 수 없다.** Azure에는 물리 ID 접두사가 없다.
   **Microsoft CAF 권장 약어**를 권위 소스로 삼는다:
   [Abbreviation examples for Azure resources](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations).
   2~6항과 **"종속 객체는 부모 이름 상속"** 규약은 상속한다.
3. 등재 약어 **6종**:

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| Virtual Network | 가상 네트워크 (`azurerm_virtual_network`) | `vnet` | vnet-demo-prd-krc-main |
| Virtual Network | 서브넷 (`azurerm_subnet`) | `snet` | snet-demo-prd-krc-app |
| Network Security | 네트워크 보안 그룹 (`azurerm_network_security_group`) | `nsg` | nsg-demo-prd-krc-app |
| Routing | 라우팅 테이블 (`azurerm_route_table`) | `rt` | rt-demo-prd-krc-app |
| Outbound | NAT 게이트웨이 (`azurerm_nat_gateway`) | `ng` | ng-demo-prd-krc-main |
| Outbound | 공용 IP (`azurerm_public_ip`) | `pip` | pip-demo-prd-krc-main |

   - ⚠️ `pip`·`ng`·`vnet` 예시는 **`purpose` 토큰**을 쓴다(Step 3.4 계약과 일치).
     `snet`·`nsg`·`rt`는 **그룹 키**를 쓴다.
   - association 3종은 약어를 신설하지 않는다(`name` 인자 없는 종속 객체).
   - ⚠️ **`snet`은 `aws.md`에도 있다.** 클라우드 간 재사용은 허용되고 검증기는 고유성을
     **파일 안에서만** 판정한다. A2가 이것을 실물로 증명한다.
4. 검증기 형식: `## A.1 Network (6)` · 표 **4번째 열**이 `Name 예시`이고 값이 약어로 시작 ·
   `| A.1 | Network | 6 |` · `| | **합계** | **6** |` · `총 **6개** 약어`.
5. ⚠️ **em-dash를 쓰지 않는다**(0-15).
6. **`docs/README.md` 「데이터」 표에 `azure.md` 행 추가**(현재 18행에 `aws.md`만 있다).

**인수 조건**

```bash
# [전환 가드] 작업 전 0 확인함
command grep -c 'naming/abbreviations/azure\.md' docs/README.md   # A6: 작업 전 0 -> 작업 후 1 이상

# [신규 파일 대상] 산출물 생성 후 최초 실행 시 검증
# A1
python3 scripts/validate-abbreviations.py docs/naming/abbreviations/azure.md   # -> "6개 · 1개 카테고리", rc=0

# A2. ★ 두 카탈로그가 `snet` 을 공유해도 거짓 중복이 없다 (산문이 아니라 명령으로 판정)
out=$(python3 scripts/validate-abbreviations.py docs/naming/abbreviations/*.md 2>&1)
printf '%s\n' "$out" | command grep -q '약어 중복' && { echo "거짓 중복 발생"; exit 1; }
[ "$(printf '%s\n' "$out" | command grep -c 'SSOT 검사 통과')" -eq 2 ] || { echo "두 파일이 각각 통과 안 함"; exit 1; }

# A3. pre-commit 이 새 파일을 줍는다. ⚠️ index 를 원상복구한다
git add docs/naming/abbreviations/azure.md
out=$(.githooks/pre-commit 2>&1 || true)
git restore --staged docs/naming/abbreviations/azure.md
printf '%s\n' "$out" | command grep -q '약어 카탈로그 변경' || { echo "SSOT 검사가 안 돌았다"; exit 1; }

# A4. 문서 게이트 4종. A5 를 포함한다(A4 가 더 넓다)
python3 scripts/validate-doc-conventions.py docs/naming/abbreviations/azure.md   # -> rc=0

# A5. em-dash 0건. A4 의 부분집합이고 실패 원인을 즉시 알려는 용도다
command grep -c '—' docs/naming/abbreviations/azure.md   # -> 0
```

---

### Step 2 — `conventions.md` 중립화·재배치·채움

**하는 일**

**(a) 「공통 강제 방식」의 `Name` 전제를 provider 중립화한다 — 네 곳 전부.**
Step 2(c)가 *"Azure는 `Name` 태그를 달지 않는다"* 를 신설하므로, 공통 절이 그대로면 문서가
*"모든 리소스에 `Name` 태그 assertion"* 과 정면 충돌한다.

| # | 위치(실측) | 현재 | 조치 | 인수 조건 |
|---|---|---|---|---|
| ①-a | 20행 절 제목 ``### `Name` 태그 포맷`` | `Name` 태그 전제 | **「리소스 이름 포맷」** 류로 변경 | **E2d** |
| ①-b | 같은 절 본문 | 없음 | *"AWS는 `Name` 태그로, Azure는 `name` 인자로 실린다"* **문장을 추가**로 명시 | **E2e** (신설) |
| ② | 공통 1번 | *"**`Name`**은 모듈이 조합한다"* | *"**이름**은 모듈이 조합한다"* | **E2c** |
| ③ | 공통 2번 링크 | `aws.md` 한 곳 | **두 카탈로그 모두**(교체가 아니라 추가 — `aws.md`도 그대로 남긴다) | E2b |
| ④ | 공통 4번 | *"**`Name` 태그** assertion"* | *"**이름** assertion"* | E2 |

> ⚠️ ①은 두 개의 별개 요구(제목 변경 + 본문에 새 문장 추가)를 담고 있어 **행 하나에 조건 하나로는
> 부족하다** — 4회차 검토가 지적한 지점(v4의 E2d는 ①-a만 판정했다). ①-b를 E2e로 분리한다.
> ①은 `### 공통 강제 방식` 범위 **밖**(20행 vs 39행)이라 E2의 awk로 검사되지 않는다.
> ②는 E2의 grep 패턴에 매치되지 않는다. **그래서 조건을 세 개 신설한다**(0-13, Success Criteria 4를
> *"행 5개가 전부 검사된다"* 로 정정).

**(b) Azure 절 항목을 재배치한다.**

- **현재 4번 -> 5번**으로 밀고 머리 문장을 *"아래 **한 가지는** 규정하지 않는다"* 로.
  남는 불릿은 **Azure Policy `modify` × drift 하나뿐**이고 ⛔ **그 불릿 본문은 손대지 않는다**(P3).
- **새 4번(제약 리소스) 신설.** 출처:
  [Naming rules and restrictions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules).

  | 리소스 | 스코프 | 길이 |
  |---|---|---|
  | `virtualNetworks` | 리소스 그룹 | 2~64 |
  | `virtualNetworks/subnets` | 부모 vnet | 1~80 |
  | `networkSecurityGroups` · `routeTables` · `natGateways` · `publicIPAddresses` | 리소스 그룹 | 1~80 |

  ⚠️ **전역 고유 이름 제약은 이 집합에 나타나지 않는다**고 적고, 어디서 마주칠지
  (스토리지 계정 · Flow Logs를 여는 순간)를 적는다.

**(c) 새 항목: 조합한 이름은 `name` 인자에 넣고 `Name` 태그를 달지 않는다.**
⚠️ 거버넌스 태그는 별개이고 **여전히 리소스마다 `tags`로 배선한다.**

**(d) 리전코드에 `krc`(koreacentral) 추가.**

> `docs/naming/regions.md`로 옮기는 안도 있으나 **이번에는 옮기지 않는다** — AWS 리전코드가
> `conventions.md`에 살고 있어 이전은 **AWS 값 마이그레이션을 동반하는 별도 리팩터**다(Follow-up 6).

**인수 조건**

```bash
sec=$(awk '/^### Azure 강제 방식/{f=1} f&&/^---$/{exit} f' docs/conventions.md)
com=$(awk '/^### 공통 강제 방식/{f=1} f&&/^### AWS 강제 방식/{exit} f' docs/conventions.md)

# [전환 가드] E1 — 볼드 배치에 좌우되지 않도록 마크업을 지우고 판정
plain=$(printf '%s\n' "$sec" | sed 's/\*//g')
printf '%s\n' "$plain" | command grep -qE '한 가지는[[:space:]]*규정하지 않는다' || { echo "머리 문장 미갱신"; exit 1; }
printf '%s\n' "$plain" | command grep -q 'virtualNetworks' || { echo "제약 리소스 표 없음"; exit 1; }

# [존치 가드] 남은 미결 불릿 — 작업 전 통과가 정상이다. 'Azure Policy'는 절 안에 2회
# 등장(항목2 태그상속 설명 + 미결 불릿)해 불릿 삭제를 탐지 못한다 — 불릿 전용 어휘로 판정한다.
printf '%s\n' "$plain" | command grep -q 'drift' || { echo "남은 미결 불릿 소실"; exit 1; }

com_plain=$(printf '%s\n' "$com" | sed 's/\*//g')

# [전환 가드] E2 (④ 공통 4번), 마크업 무관 판정
printf '%s\n' "$com_plain" | command grep -q 'Name` 태그 assertion' && { echo "④ 미수정"; exit 1; }

# [전환 가드] E2b (③ 두 카탈로그 링크) — 추가인지 확인(aws.md 를 교체가 아니라 유지해야 한다)
printf '%s\n' "$com_plain" | command grep -q 'azure\.md' || { echo "③ azure.md 미기재"; exit 1; }
printf '%s\n' "$com_plain" | command grep -q 'aws\.md'   || { echo "③ aws.md 가 사라졌다(교체됨)"; exit 1; }

# [전환 가드] E2c (② 공통 1번), 마크업 무관 판정
printf '%s\n' "$com_plain" | command grep -q '`Name`은 모듈이 조합한다' && { echo "② 미수정"; exit 1; }

# [전환 가드] E2d (①-a 절 제목) — 제목 자체가 Name 태그 전제를 벗었는지 직접 판정
[ "$(command grep -c '^### `Name` 태그 포맷' docs/conventions.md)" -eq 0 ] || { echo "①-a 미수정"; exit 1; }

# [전환 가드] E2e 신설 (①-b 본문에 새 문장 추가) — 제목만 바꾸고 문장을 빠뜨리는 경로를 막는다
fmt=$(awk '/^### `?Name`? 태그 포맷|^### 리소스 이름 포맷/{f=1} f&&/^### 공통 강제 방식/{exit} f' docs/conventions.md)
printf '%s\n' "$fmt" | command grep -q 'name` 인자' || { echo "①-b 새 문장 누락"; exit 1; }

# [전환 가드] E3 — Azure 절에 name 인자 항목이 있다
printf '%s\n' "$sec" | command grep -q 'name` 인자' || { echo "name 인자 항목 없음"; exit 1; }

# E4. 400줄 이내 + 문서 게이트 4종 (현재 272줄)
python3 scripts/validate-doc-conventions.py docs/conventions.md   # -> rc=0

# [전환 가드] E5 — 작업 전 0 확인함
command grep -c 'koreacentral' docs/conventions.md   # 작업 전 0 -> 작업 후 1 이상
```

---

### Step 3 — `module-catalog.md` `vnet` 배선 절

**하는 일**

1. ⛔ **서두의 *"현재 등재된 것은 AWS 4개이고 Azure는 0개다"* 를 고치지 않는다.**
   `modules/azure/`가 아직 없으므로 현재 사실 그대로가 맞다. 구현 라운드에서 고친다.

2. `vnet` 절 신설 — **배선만**.
   - **만드는 것**: VNet · 서브넷(그룹당 1개) · NAT Gateway + 공용 IP · 옵트인 NSG · 옵트인 RT.
   - **만들지 않는 것**: 리소스 그룹(주입) · NSG 룰(소비자) · Flow Logs(`0.1.0` 미포함) ·
     예약 이름 서브넷.

   > **능력 한계를 명시한다**(0-7, 산출물 문안 — `★` 없이): *"Azure 예약 이름 서브넷
   > (`AzureBastionSubnet` · `GatewaySubnet` · `AzureFirewallSubnet`, 확인한 것은 이 셋이며
   > 더 있을 수 있다)은 이 모듈의 네이밍 계약과 충돌해 만들지 않는다. 배포 루트가 같은 vnet에
   > `azurerm_subnet`으로 직접 만든다."* 각 이름의 출처 링크를 단다.

3. ⚠️ **`vpc`와의 출력 비대칭 3건을 표로 명시한다.**

   | 출력 | `modules/aws/vpc` | `vnet` | 사유 |
   |---|---|---|---|
   | `subnet_ids_by_group` | `map(list(string))` | `map(string)` | 서브넷에 존 축이 없다(0-3) |
   | `route_table_ids_by_group` | `map(list(string))` | `map(string)` | 〃 |
   | NAT | `nat_gateway_ids` `list(string)` | `nat_gateway_id` `string` | vnet당 1개(0-10) |

4. **인터페이스 초안**:

```hcl
# ── 공통 규약 ──
variable "naming" {
  type = object({
    workload    = string
    env         = string
    region_code = string
  })
}
variable "purpose"             { type = string }        # 기본 "main"
variable "tags"                { type = map(string) }
variable "vnet_enabled"        { type = bool }
variable "deletion_protection" { type = bool }

# ── 배치 ──
variable "resource_group_name" { type = string }        # 필수 주입 (축 2)
variable "location"            { type = string }        # 필수 입력 (축 2b)

# ── 주소 공간 ──
variable "address_space" { type = list(string) }
# ⛔ dns_servers 는 노출하지 않는다 — 0-9 의 [] 함정.

# ── 서브넷 그룹 (키가 곧 이름 토큰) ──
variable "subnet_groups" {
  type = map(object({
    address_prefixes                = list(string)          # AZ 리스트가 아니다 (0-3)
    nat_routed                      = optional(bool, false)
    nsg_enabled                     = optional(bool, false) # 축 3 (G2 로 확정)
    route_table_enabled             = optional(bool, false)
    default_outbound_access_enabled = optional(bool, true)  # 0-11 — provider 기본과 동일
    service_endpoints               = optional(list(string), [])
    delegations = optional(list(object({
      name    = string
      actions = list(string)
    })), [])
    extra_tags = optional(map(string), {})                  # NSG·RT 에만 적용 (0-5)
  }))
}

# ── 아웃바운드 ──
variable "nat_gateway_enabled"  { type = bool }                       # 기본 true
variable "nat_gateway_sku_name" { type = string }                     # 기본 "Standard" (축 5b)
variable "nat_gateway_zones"    { type = list(string), default = null }
```

   **명시해야 할 계약 5건**:

   - ⚠️ **`extra_tags`는 서브넷에 적용되지 않는다**(0-5).
   - ⚠️ **`purpose`와 그룹 키의 역할 분담**: `purpose`는 **VNet · NAT Gateway · 공용 IP**의 토큰,
     **서브넷 · NSG · RT는 그룹 키**를 토큰으로 쓴다(`vpc`와 같은 분담).
   - ★ **NAT는 수요와 결합하고 `precondition`을 걸지 않는다**(0-12):
     *"`nat_routed = true`인 그룹이 0개면 NAT를 만들지 않는다(조용한 스킵)."*
     `modules/aws/vpc/main.tf:70`이 같은 형태이고, **149행 precondition은 `length(...) == 0`으로
     이 케이스를 명시적으로 면제한다.** ⛔ 여기에 precondition을 걸면
     **기본 구성(`nat_gateway_enabled` true + 전 그룹 `nat_routed` false)에서 plan이 깨진다.**
   - ⚠️ **`sku_name = "StandardV2"`이면 `zones`가 비어 있어야 한다**(0-10). `null`만 보면 부족하다:
     `var.nat_gateway_zones == null || length(var.nat_gateway_zones) == 0`.
   - ⚠️ **`sku_name`·`zones` 변경은 ForceNew라 아웃바운드 공용 IP가 바뀐다**(0-10).
     고객사 방화벽 allowlist에 직결되므로 `description`과 README에 경고로 싣는다.

5. 출력: `vnet_id` · `vnet_name` · `address_space` · `subnet_ids_by_group` · `nsg_ids_by_group` ·
   `route_table_ids_by_group` · `nat_gateway_id` · `nat_public_ip_address`. null-safe 규약은 `vpc`와 동일.

> **접미 규약**: `nat_gateway_enabled`(접미). 공통 규약이 `<component>_enabled`를 규정하고
> `vpc_enabled`·`flow_logs_enabled`도 접미형이라 `enable_nat_gateway`가 기존 예외다.

**인수 조건**

```bash
# [전환 가드] C1 — 비대칭 표 범위를 먼저 잘라낸다. 작업 전 표 추출 0줄 -> 3건 실패 확인함
tbl=$(awk '/^\| 출력 \|/{f=1} f&&/^$/{exit} f' docs/module-catalog.md)
for o in subnet_ids_by_group route_table_ids_by_group nat_gateway_id; do
  printf '%s\n' "$tbl" | command grep -q "$o" || { echo "$o 가 비대칭 표에 없다"; exit 1; }
done

# [전환 가드] C6 신설 — 예약 이름 서브넷 능력 한계가 세 이름 전부 적혀 있다
for n in AzureBastionSubnet GatewaySubnet AzureFirewallSubnet; do
  command grep -q "$n" docs/module-catalog.md || { echo "$n 능력 한계 미기재"; exit 1; }
done

# [회귀 가드] C2 — "유일한" 단정이 없다. 작업 전에도 통과가 정상이다
command grep -c '유일한 비대칭' docs/module-catalog.md   # -> 0

# [존치 가드] C3 — 서두 문장이 그대로다. 작업 전에도 통과가 정상이다
command grep -c 'Azure는 0개다' docs/module-catalog.md   # -> 1

# C4. 400줄 이내 + 문서 게이트 4종 (현재 165줄)
python3 scripts/validate-doc-conventions.py docs/module-catalog.md   # -> rc=0

# [회귀 가드] C5 — 하드코딩 semver 가 없다. 작업 전에도 통과가 정상이다
command grep -c 'ref=vnet-v[0-9]' docs/module-catalog.md   # -> 0
```

---

### Step 4 — `docs/decisions.md` ADR 등재

**하는 일**

⚠️ **절 레벨은 평면 `##`이다.** `decisions.md`의 기존 절이 전부 `##`이고
(10·25·38·65·74·99·113·129·138행 실측), `###`을 고르면 D1이 영구 실패한다.

`## 모듈 설계` **다음 형제 절**로 `## Azure 네트워킹 (vnet)`을 신설하고 7절 ADR을 옮긴다.

⛔ **「GitOps와 ArgoCD」 절의 Kyverno 기각 행(91행)은 손대지 않는다.** NSG와 무관한 별개 ADR이다.

**인수 조건**

```bash
# [전환 가드] D1 — 작업 전 0줄 실패 확인함. `##` 픽스처 7줄 통과 / `###` 픽스처 0줄 실패 확인함
sec=$(awk '/^## Azure 네트워킹/{f=1;print;next} f&&/^## /{exit} f' docs/decisions.md)
[ "$(printf '%s\n' "$sec" | wc -l)" -gt 5 ] || { echo "절 본문이 비었다(또는 ### 로 만들었다)"; exit 1; }

# [존치 가드] D2 신설 — Kyverno 기각 행이 그대로다
command grep -c 'Kyverno' docs/decisions.md   # -> 1 (작업 전과 동일)

# D3. 기각 표에 10개 안이 전부 있다  [사람 판정]
printf '%s\n' "$sec"

# D4. 400줄 이내 + 문서 게이트 4종 (현재 146줄)
python3 scripts/validate-doc-conventions.py docs/decisions.md   # -> rc=0
```

---

### Step 5 — 구현 라운드 착수 명세 + `.omc/` 갱신

1. `open-questions.md` 갱신: G1·G2를 착수 게이트로, `_wo`(NSG·RT 양쪽)를 미결로.
2. 직전 라운드 Follow-up 소화 표시(5번 해소 / 6번 부분 해소 / 2번·4번 승격).
3. `.omc/notepad.md` · `.omc/project-memory.json`을 같은 커밋에.

```bash
# F1. notepad 갱신이 실렸다
git diff --cached --name-only | command grep -q '^\.omc/notepad\.md$' || { echo "notepad 누락"; exit 1; }
# F2. 문서 전용 커밋이다
[ "$(git diff --cached --name-only | command grep -c '\.tf$')" -eq 0 ]
# F3. modules/azure/ 가 생기지 않았다
[ ! -d modules/azure ]
```

---

## 5. Success Criteria

1. `azure.md`가 검증기를 무수정 통과하고(A1) `snet` 공유에도 거짓 중복이 없다(A2, 명령 판정).
2. 등재 약어 6종뿐, 등재 규칙 1항이 CAF 출처로 대체됨, 예시가 `purpose`/그룹 키 계약과 일치.
3. `azure.md`에 em-dash 0건(A5). `docs/README.md`에 행 추가(A6).
4. **Step 2(a)의 행 5개(①-a·①-b·②·③·④)가 전부 검사된다**(E2·E2b·E2c·E2d·E2e) — 요구 단위로
   지시 건수와 조건 건수가 같다.
5. `conventions.md` Azure 절 미결이 2건 -> 1건이고 항목이 재배치됐다(E1).
6. `module-catalog.md`에 출력 비대칭 3건 표(C1)와 **예약 이름 서브넷 능력 한계**(C6)가 있다.
7. 서두의 *"Azure는 0개다"* 가 그대로다(C3).
8. `decisions.md` ADR이 평면 `##`이고 본문을 가지며(D1), **Kyverno 행은 무손상**(D2).
9. `.tf` 변경 0건 · `modules/azure/` 미생성(F2·F3).
10. 구현 라운드 착수 게이트 4건 기록.
11. **인수 조건이 성격별로 구분돼 있다**(전환 / 회귀·존치 / 신규 파일).
12. ★ **거짓 사실 문장이 없다** — 0-6의 델타 표가 NSG·LB·AppGw 세 원문과 일치하고,
    0-12의 NAT 서술이 `vpc/main.tf` 실물과 일치한다.

---

## 6. (예약)

---

## 7. ADR (`docs/decisions.md` 등재용 초안)

> 등재 위치: `## 모듈 설계` 다음 형제 절, 제목 `## Azure 네트워킹 (vnet)` (**평면 `##`**).

**Decision**: 첫 Azure 모듈 `vnet`을 `modules/azure/vnet/`에 **스크래치 얇은 모듈**로 설계한다.
서브넷은 `azurerm_subnet` **별도 리소스**, 리소스 그룹과 `location`은 **주입**,
NSG·라우팅 테이블은 **옵트인 앵커**, Flow Logs는 `0.1.0` 제외, NAT는 `sku_name` 손잡이를 노출하고
**수요와 결합**한다.

**Drivers**: (1) 서브넷 부속 리소스 지원 가능 여부 (2) 파괴의 폭발 반경 (3) 게이트가 있는 척하지 않을 것

**Alternatives considered**:

| 안 | 기각 이유 |
|---|---|
| 서브넷을 **인라인 `subnet` 블록**으로 | **기술적 불가.** 인라인에 `nat_gateway_id`가 없고, 연결 경로인 association은 provider가 인라인과의 병용을 *"will overwrite subnets"* 로 금지한다 |
| 모듈이 **리소스 그룹 생성** | RG 삭제는 내부 리소스를 **state 밖의 것까지** 캐스케이드 삭제한다 |
| **`location`을 RG 데이터 소스에서 파생** | read의 apply 연기는 *"data 블록이 이번 plan에서 변경 예정인 관리 리소스에 직접 의존할 때"* 성립하는 **조건부 동작**이다. 리터럴을 넘기면 plan에서 실패하므로 **배포 성공이 소비자 배선에 좌우된다** |
| **NSG를 기본 생성**(룰 0개) | 빈 NSG의 델타는 **컨트롤 플레인 인바운드 차단**과 **서브넷 주입형 PaaS의 클라이언트 트래픽 차단** 두 곳뿐이고 둘 다 파괴 방향이다. 확인된 사례가 Application Gateway이고(`GatewayManager` 컨트롤 플레인 65200-65535 + 클라이언트 트래픽 룰 둘 다 필수) 보안 이득은 없다. 단 이 무이득 논거는 **공용 Standard LB·공용 IP 경로에 한해서만** 성립한다(그 경로만 NSG 없이도 *"closed to inbound connections by default"*) — VNet 내부는 빈 NSG도 `AllowVNetInBound`로 허용한다 |
| NSG·RT를 **둘 다 만들지 않기** | association이 `subnet_id`를 요구하는데 서브넷은 모듈 소유다. 소비자에게 떠넘기면 경계가 어긋난다 |
| **AVM 커뮤니티 모듈 wrapper** | VNet·서브넷·NSG·NAT는 Azure에서 가장 안정된 계층이고 지식 밀도가 낮다 |
| Flow Logs를 `0.1.0`에 **포함** | provider가 *"storage lifecycle management rule을 덮어쓴다"* 는 결함(#6935)을 명시한다. 고객사 배송 계약이라 **남의 스토리지 정책을 조용히 파괴하는 경로**를 첫 모듈에 넣을 수 없다 |
| NAT에 **`sku_name` 손잡이 없음** | `Standard`는 무존이거나 단일 존이다. 존 이중화는 `StandardV2`가 제공하므로 손잡이가 없으면 고를 수단이 없다 |
| NAT `sku_name` 기본값을 **`StandardV2`로** | `StandardV2`는 preview다(SLA 대상 아님, 일부 리전 미지원). 배송 모듈이 기본값으로 preview 리소스를 고객사에 강제할 수 없다. 기본은 GA인 `Standard`를 유지한다 |
| **NAT 수요 0개에 `precondition`** | `modules/aws/vpc`의 선례는 수요 0개를 **조용히 스킵**하고(70행), precondition은 `length(...) == 0`으로 그 케이스를 **명시적으로 면제**한다(149행). precondition을 걸면 모듈 기본값 조합에서 plan이 깨진다 |
| `vpc`의 `az_count`·`az_selection`·`single_nat_gateway`·`eks_cluster_name` **이식** | Azure 서브넷은 존에 속하지 않고 태그도 지원하지 않는다 |

**Why chosen**: 축 1은 provider 제약이 답을 강제했고, 나머지는 **"모듈이 소유하는 것과 배포 루트가
소유하는 것의 경계"** 로 갈렸다. 서브넷 스코프 자원은 모듈이, 구독·리소스 그룹 스코프 자원은
배포 루트가 소유한다.

**Consequences**:

- **출력 타입 비대칭이 3건이다.** `module-catalog.md`가 표로 소유한다.
- **Azure 서브넷은 태그를 지원하지 않는다.** NSG·RT 태그가 그 자리를 대신한다.
- 조합한 이름은 `name` 인자에 들어가고 **`Name` 태그는 달지 않는다.** 이에 맞춰
  「공통 강제 방식」의 `Name` 전제를 네 곳에서 provider 중립으로 고쳤다.
- **배포 루트가 RG와 `vnet`을 한 apply에서 세울 수 있다.** 대신 리전 불일치를 모듈이 막지 않는다.
- ⛔ **`azurerm_virtual_network`에 `subnet`·`dns_servers`를 쓰지 않는다.** 빈 배열로도 쓰지 않는다.
- **Azure 예약 이름 서브넷(`AzureBastionSubnet` · `GatewaySubnet` · `AzureFirewallSubnet`,
  확인한 것은 이 셋이며 더 있을 수 있다)은 이 모듈이 만들지 않는다.**
  네이밍 계약이 정확한 예약 이름을 만들 수 없기 때문이다. 배포 루트가 같은 vnet에
  `azurerm_subnet`으로 직접 만든다. ⚠️ 이 병용은 문서 문면상 안전하나 `apply`로 검증하지 않았다.
- **Azure Policy가 서브넷 생성 시 NSG나 라우팅 테이블을 강제하는 환경은 지원하지 않는다.**
- **NAT는 `nat_routed = true` 그룹이 0개면 조용히 만들지 않는다.** precondition을 걸지 않는다.
- ⚠️ **NAT의 `sku_name`·`zones` 변경은 ForceNew라 아웃바운드 공용 IP가 바뀐다.**
- ⚠️ **`nat_gateway_sku_name`의 `StandardV2`는 preview다**(SLA 대상 아님, 일부 리전 미지원).
  기본값 `Standard`는 GA이고 이 상태를 밟지 않는다. GA 기준으로는 존 이중화 NAT 경로가 없다.
- **`default_outbound_access_enabled`를 노출한다.** 노출하지 않으면 소비자가 서브넷을 private로
  만들 수단이 없다.
- ⚠️ **`deletion_protection`은 vnet에만 걸린다.** Azure는 vnet 삭제가 서브넷을 함께 지우므로
  실질 보호 범위가 `vpc`와 다르다.
- 약어 6종이 고정된다. `snet`은 AWS에도 있으나 재사용은 허용된다.
- 구현 라운드는 착수 게이트 **4건**을 같은 PR에서 처리해야 한다.

---

## 8. 개정 이력 (v3 -> v4)

### 🔴 CRITICAL 1 — "공용 LB 백엔드가 조용히 끊긴다"가 거짓이었다

[Azure Load Balancer 문서](https://learn.microsoft.com/en-us/azure/load-balancer/load-balancer-overview)를
직접 조회해 확인:

> *"Standard load balancers and public IP addresses are **closed to inbound connections by default**...
> **Traffic is blocked if no NSG exists on a subnet or NIC.**"*
> *"Basic Load Balancer is open to the internet by default and **was retired on September 30, 2025**."*

**공용 Standard LB 백엔드는 NSG가 없어도 이미 차단이다. 델타가 0이다.** Basic이 은퇴했으므로
이 주장이 성립하는 SKU가 하나도 없다. 메커니즘 서술(DNAT · 원본 Internet · `DenyAllInbound` 적중)은
맞았으나 *"그것이 기본 켬 때문에 생기는 변화"* 라는 결론이 거짓이었다.

**반영** — 지적대로 **한 곳이 아니라 다섯 곳을 동시에** 고쳤다:

| 위치 | 조치 |
|---|---|
| 0-6 | **델타 표로 전면 재작성.** 다섯 경로를 항목별로 나눠 넷은 "델타 없음", 하나(컨트롤 플레인)만 "있다, 파괴 방향"으로 |
| 0-6 미부착 행 | *"필터 없음(상위 경로가 허용하는 것은 통과)"* 도 거짓이었다 -> 경로별로 분해 |
| 축 3 Cons 셀 | 공용 LB 예시 삭제, AppGw로 교체 + **"보안 이득이 없다"** 추가 |
| ADR 기각표 | 같은 방향으로 재작성 |
| `open-questions.md` G2 | 같은 방향으로 재작성 |

★ **지적대로 이 사실은 오히려 옵트인을 강화한다.** *"NSG 부재가 곧 인터넷 노출은 아니다"* 가
v1~v3 내내 근거 없는 가정이었는데 이제 **문서로 확정**됐다(권고 사유 2).

### 🔴 CRITICAL 2 — Bastion은 이 모듈이 만들 수 없는 리소스였다

[Bastion configuration settings](https://learn.microsoft.com/en-us/azure/bastion/configuration-settings) 조회:
*"Bastion requires a dedicated subnet named **AzureBastionSubnet**"* / *"Subnet name must be
*AzureBastionSubnet*"*. 네이밍 계약(`snet-<workload>-...`)이 이 이름을 만들 수 없다.

**반영**: Bastion 예시를 다섯 곳에서 삭제. **0-7 신설**(능력 한계)하고 `module-catalog.md`
「만들지 않는 것」과 ADR Consequences에 각 한 줄 + 인수 조건 **C6** 신설.

- 확인한 예약 이름은 **둘**(`AzureBastionSubnet` · `GatewaySubnet`)이다. `AzureFirewallSubnet`은
  **확인하지 못해 적지 않았다**(P3). *"더 있을 수 있다"* 로만 남겼다.
- **배포 루트 병용의 안전성**은 0-1 경고 문면이 *"in-line Subnets in conjunction with any Subnet
  resources"* 로 한정돼 있다는 **범위 해석**으로 적었고, ⚠️ **`apply`로 검증하지 않았음을 명시**했다
  (지시대로 검증 못 한 근거는 단정하지 않았다).
- **AppGw만 남았다.** 예약 이름이 없어 이 모듈이 만들 수 있고,
  [AppGw infrastructure configuration](https://learn.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure)이
  *"**Infrastructure ports**: ... **GatewayManager** service tag... **V2: Ports 65200-65535**"* 를
  NSG 필수 룰로 명시하므로 빈 NSG가 실제로 끊는다.

### 🔴 MAJOR — NAT precondition이 AWS 선례와 정반대였다

`modules/aws/vpc/main.tf` 실물 대조 결과 지적이 정확하다:
70행은 수요 0개면 **조용히 스킵**하고, 149행 precondition의 `length(local.private_group_names) == 0`이
**수요 0개를 명시적으로 면제**한다. v3은 정확히 그 면제 케이스에 precondition을 걸었고,
**모듈 기본값 조합(`nat_gateway_enabled` true + `nat_routed` false)이 바로 그 케이스**라
최소 구성 apply가 자기 기본값 때문에 깨졌다.

**반영**: **0-12 신설**(코드 인용 + 선례 구조 분해). Step 3.4 계약과 ADR Consequences를
*"조용한 스킵, precondition 없음"* 으로 통일하고, ADR 기각표에 **"NAT 수요 0개에 precondition"** 행 추가.
**P6 신설**(선례 인용 시 실물 대조).

### 🔴 MAJOR — Step 2(a)의 네 곳 중 두 곳이 검사되지 않았다

**실행해 확인**: `### 공통 강제 방식` awk 범위는 14줄이고 절 제목(20행)은 그 **밖**이다
(`'태그 포맷'` 포함 건수 0). 공통 1번은 범위 안이지만 E2 패턴(`Name` 태그 assertion`)에 매치되지 않는다.
**즉 공통 4번만 고쳐도 E2·E2b가 통과한다.**

**반영**: Step 2(a)를 **번호가 붙은 표**로 바꿔 각 행에 담당 인수 조건을 명시하고,
**E2c**(공통 1번) · **E2d**(절 제목을 파일 전역에서 직접 판정)를 신설. Success Criteria 4를
*"지시 건수와 조건 건수가 같다"* 로 재작성. 0-13에 **반복 패턴 ②**로 일반화해 기록.

### MINOR (4건 전부 반영)

| 지적 | 처리 |
|---|---|
| Kyverno 지시 모호 | *"**이 계획에서** 인용하지 않는다. `decisions.md`의 기각 행 **자체는 손대지 않는다**"* 로 명확화 + Step 4에 명시 + **존치 가드 D2** 신설 |
| Must Have 문면이 C2·C3·C5와 충돌 | 인수 조건 성격을 **셋**으로 구분(전환 / **회귀·존치** / 신규 파일). 각 조건 블록에 `[전환 가드]`·`[회귀 가드]`·`[존치 가드]` 라벨 부착 |
| G2 차단 범위 과장 | *"차단 범위: **Step 3·4**(Step 1·2는 막지 않는다). 다만 단일 커밋이라 G1과 한 지점에서 함께 받는다"* 로 정정(계획 3절 + `open-questions.md`) |
| 출처 링크 명시 | AppGw · LB · Bastion · NSG overview 네 링크를 0-6·0-7과 ADR 기각표에 직접 부착 |

### 미반영 (0건)

CRITICAL 2건은 **제가 v3에서 검증 없이 뒤집어 쓴 것**이고, MAJOR 2건도 실물·실행으로 재현됐다.
반박으로 남긴 항목이 없다.

---

## 8b. 개정 이력 (v4 -> v5)

4회차 검토(Architect 조건부 승인 · Critic ITERATE-인라인)가 **완전히 독립적으로** 아래를 찾았다.
둘 다 명시적으로 *"설계 재검토 불필요, 인라인 수정으로 충분"* 이라 판정했다 — v1~v3와 달리
채택된 옵션(축 1~5b)은 하나도 뒤집히지 않았다. team-lead가 두 보고를 병합해 직접 반영했다
(라운드 5회 없이, ralplan "개선사항 병합" 단계).

| 지적 | 반영 |
|---|---|
| **예약 이름 서브넷 목록에 `AzureFirewallSubnet` 누락**(둘 다 독립 발견) | 0-7 표에 3번째 행 추가(출처: Azure Firewall FAQ). **한정어("더 있을 수 있다")를 계획 전용이 아니라 산출물 문안(Step 3.2·ADR Consequences) 안에 직접 넣도록 수정** — v4는 한정어가 계획에만 있고 배송 문서엔 닫힌 목록처럼 나갔었다. C6도 세 이름 전부 검사하도록 확장 |
| **NAT `StandardV2`가 preview라는 사실 누락**(Critic MAJOR-1) | 0-10에 3번 항목 신설, 축 5b Option B Cons·ADR 기각표·ADR Consequences에 각각 반영. GA 기준 존 이중화 경로가 없다는 결론과 koreacentral 지원 미확인을 Follow-up 10으로 |
| **0-6 델타 표가 AppGw의 데이터 플레인(클라이언트 트래픽) 델타를 놓침**(Critic MAJOR-5) | 표 1행을 Standard LB·공용 IP로 좁히고 6행 신설(서브넷 주입형 PaaS). 결론·권고 사유 1·2, 축 3 Cons 셀, ADR 기각표, `open-questions.md` G2를 전부 "델타 있는 경로 둘"로 갱신. 판정(옵트인)은 불변 — 오히려 강화 |
| **G2가 사유 2(무이득 근거)에만 의존하는 것처럼 읽힘**(Architect steelman) | 사유 2가 무너져도 사유 1·3만으로 옵트인이 유지된다는 문장을 계획과 `open-questions.md` 양쪽에 명시 |
| **Step 2(a) ①이 두 요구(제목 변경+새 문장 추가)를 담는데 조건 하나(E2d)만 검사**(양쪽 독립 발견) | ①을 ①-a·①-b로 분리, **E2e 신설**(새 문장 존재를 별도 판정). Success Criteria 4를 "행 5개" 기준으로 정정 |
| **E1 존치 가드가 `grep 'Azure Policy'`라 절 안의 다른 문장(항목2)에도 매치돼 불릿 삭제를 탐지 못함**(Critic MAJOR-4) | 판정 어휘를 그 불릿에만 있는 `drift`로 교체 |
| **E2b가 `azure.md` 존재만 보고 `aws.md`가 지워졌는지(교체 vs 추가)는 안 봄**(Architect ㉮) | `aws.md` 잔존을 확인하는 양성 검사 추가 |
| **E2·E2b·E2c가 마크업(볼드) 변화에 취약**(Architect ㉰) | E1처럼 `sed 's/\*//g'`로 마크업을 지운 뒤 판정하도록 통일 |
| **`★`가 계획 전용 마커인데 산출물 지시문에 그대로 실려 문서 게이트(비표준 이모지)에 걸릴 위험**(Critic MINOR-1) | Guardrails에 한 줄 추가, Step 3.2 지시문에서 `★` 제거 |
| **0-13 "12줄" 표기가 실측(14줄)과 다름**(양쪽 독립 발견) | 두 곳 모두 14줄로 정정 |

**미반영**: 두 검토 모두 이 회차에서 CRITICAL을 내지 않았고, 반박으로 남긴 항목이 없다.
저평가·unscored로 분류된 항목(koreacentral preview 지원 여부·`_wo` 도입 여부 등)은
기존 Follow-up 구조로 이미 흡수돼 있어 추가 조치가 필요 없었다.

---

## 9. Follow-ups

1. **`vnet` Flow Logs**(`vnet-v0.2.0`) — VNet 대상. 스토리지 계정·Network Watcher는 주입.
   결함 #6935를 소비자 문서에 경고로 싣는다.
2. **Azure Policy `modify` × OpenTofu drift 규정** — 실측 수단이 생겼을 때.
3. **Policy Deny 환경 지원**(`network_security_group_id_wo` · `route_table_id_wo`) — 실수요 확인 시.
4. **데이터 소스 read 연기 동작 실측** — 측정되면 리전 불일치 가드 재검토.
5. **예약 이름 서브넷 목록 확장 + 배포 루트 병용 `apply` 검증** — 구현 라운드 예제에서 확인한다.
   확인한 예약 이름은 현재 셋뿐이다(0-7).
10. **koreacentral의 NAT Gateway `StandardV2`(preview) 지원 여부 확인** — 지원 안 하면 그 리전에서
    이 라운드가 신설하는 리전코드가 GA·preview 어느 경로로도 존 이중화 NAT를 못 쓴다는 뜻이므로,
    구현 라운드 전에 확인한다(0-10).
6. **리전 코드표를 `docs/naming/regions.md`로 이전** — AWS 값까지 함께 옮기는 별도 리팩터.
7. **`aks-cluster` 모듈** — facade 판정은 그 라운드 몫이다.
8. **NSG 룰 인터페이스와 `extra_tags` 무시/오류 규정** — 실사용 근거가 생기면.
9. **모듈 디렉터리명 provider 간 전역 고유성 검사**.
