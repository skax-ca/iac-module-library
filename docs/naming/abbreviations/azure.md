# Azure 리소스 네이밍 약어 카탈로그 (권위 참조)

**읽는 사람**: **Azure** 리소스 이름에 쓸 약어를 찾거나, 새 약어 등재를 검토하는 사람.

> 이 문서는 Azure 리소스 이름 조합에 사용하는 **Azure 리소스 타입 표준 약어**의 단일 진실 공급원(SSOT)이다.
> 약어 카탈로그는 `docs/naming/abbreviations/` 아래에 **클라우드마다 한 파일**이고, 이 파일이 Azure를 소유한다.
> 네이밍 **포맷·어휘·강제 방식**은 [conventions.md](../../conventions.md)가 소유한다.
> Azure는 `Name` 태그가 아니라 `name` 인자에 이 조합을 담는다(`conventions.md`의
> 「네이밍과 태깅」 절 참조).

## 네이밍 포맷 (요약)

```
(resourcetype)-(workloadcode)-(env)-(regioncode)-(purpose)-(serialnumber|suffix)
     └ 이 문서가 정의        └─────────── conventions.md 정의 ───────────┘
```

| 구성 요소 | 설명 | 예시 |
|-----------|------|------|
| resourcetype | 자원별 표준 약어 (이 문서) | `vnet`, `nsg`, `pip` |
| workloadcode | 프로젝트/서비스 코드: **소비 프로젝트가 정의**(이 repo는 고정하지 않음) | `demo`, `shop` |
| env | 운영 환경 코드 | `prd`, `stg`, `dev` |
| regioncode | 리전 식별자 | `krc`(koreacentral) |
| purpose | 자원의 상세 용도 | `main`, `app`, `web` |
| serial/suffix | 일련번호 또는 식별 접미사 | `01`, `20260415`, `policy` |

- 총 **15개** 약어, 6개 카테고리.
- 약어는 **소문자**, 리소스 타입 고유. 신규 약어 추가는 거버넌스 리뷰를 거친다.

### 신규 약어 등재 규칙 (거버넌스 리뷰 체크리스트)

새 약어는 아래 순서로 결정한다.

1. **Microsoft CAF(Cloud Adoption Framework) 권장 약어를 권위 소스로 삼는다.**
   [Abbreviation examples for Azure resources](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)
   에서 그 리소스 타입의 권장 약어를 확인하고 그대로 쓴다.
   ⚠️ AWS 카탈로그의 등재 규칙 1항(물리 ID 접두사 확인)은 여기 적용되지 않는다. Azure 리소스는
   물리 ID 접두사 개념이 없고, 리소스 ID는 경로(`/subscriptions/.../resourceGroups/.../providers/...`)다.
2. **같은 서비스의 프리픽스 계열을 유지한다.** 기존 항목의 패턴을 따른다.
3. **중복·형식은 스크립트가 강제한다.** `scripts/validate-abbreviations.py`: 고유(파일 안에서만) ·
   소문자 · 카운트 정합.
4. **길이**: 2~5자 권장, L2 리소스 구분에 필요하면 6자까지, **7자 초과는 등재하지 않는다.**
5. **등재 시 3곳을 함께 고친다**: ① 섹션 헤더 ② 상단 총계 ③ 카운트 요약 표 (스크립트가 검증).
6. **등재 근거 표에 왜 이 약어인지 남긴다.** 기각한 후보가 있으면 함께 적는다.

### 종속 객체는 약어를 새로 만들지 않고 부모 이름을 상속한다

독립 식별자가 아니라 **부모 리소스에 종속된 하위 객체**는 약어를 신설하지 않고
`<부모 이름>-<역할 접미사>` 형태로 명명한다. 접미사는 위 포맷 표의 **serial/suffix 축**이다.

| 종속 객체 | 명명 | 예시 |
|-----------|------|------|
| `azurerm_subnet_nat_gateway_association` | 별도 이름 없음(서브넷·NAT 이름으로 식별) | 해당 없음 |
| `azurerm_subnet_network_security_group_association` | 별도 이름 없음(서브넷·NSG 이름으로 식별) | 해당 없음 |
| `azurerm_subnet_route_table_association` | 별도 이름 없음(서브넷·라우팅 테이블 이름으로 식별) | 해당 없음 |

### 등재 근거

`aws.md`와 같은 형식이다. 여기 없는 약어는 카탈로그 표에만 있다.

| 약어 | 리소스 | 근거 |
|------|--------|------|
| `rg` | 리소스 그룹 (`azurerm_resource_group`, `Microsoft.Resources/resourceGroups`) | CAF 표의 `rg`를 그대로 쓴다 |
| `st` | Storage Account (`azurerm_storage_account`, `Microsoft.Storage/storageAccounts`) | CAF 표의 `st`를 그대로 쓴다. ⚠️ Storage Account 이름은 하이픈을 쓸 수 없다(3~24자, 소문자+숫자만). A.3 표의 "Name 예시"는 토큰 순서만 보여주는 것이고, 실제 이름은 하이픈 없이 이어붙인다 |
| `entapp` | 앱 등록 (`azuread_application`, Microsoft Entra ID/Graph 객체) | **CAF 리소스 약어표에 이 항목이 없다.** 그 표는 `Microsoft.*` ARM provider namespace가 있는 리소스만 다루는데, App Registration은 Microsoft Graph 객체라 대상이 아니다. 이 카탈로그의 첫 non-ARM 등재다. "Entra + Application"을 줄인 `entapp`(6자, 등재 규칙 4 한도 이내)을 쓴다. 기각: `app`(Azure Web App/`Microsoft.Web/sites`이 CAF에서 이미 쓰고 있어 향후 충돌) · `aadapp`(Microsoft가 Azure AD를 Entra ID로 통일했다). Service Principal은 `az ad sp create --id <appId>`가 App Registration의 displayName을 물려받아 별도 이름 인자가 없으므로 「종속 객체」 규약대로 새 약어를 만들지 않는다 |
| `aks` | AKS 클러스터 (`azurerm_kubernetes_cluster`, `Microsoft.ContainerService/managedClusters`) | CAF 표의 `aks`를 그대로 쓴다. ⚠️ 노드 풀(`Microsoft.ContainerService/managedClusters/agentPools`)은 등재하지 않는다. CAF 권장 약어(시스템 노드 풀 8자·사용자 노드 풀 `np`)가 하이픈 금지와 길이 초과로 등재 규칙 4(7자 상한)와 예시 형식 검사(`^<약어>-`)를 동시에 위반해 `scripts/validate-abbreviations.py`가 막는다. 노드 풀 이름 계약은 `docs/conventions.md`가 소유한다 |
| `id` | 사용자 할당 관리 ID (`azurerm_user_assigned_identity`, `Microsoft.ManagedIdentity/userAssignedIdentities`) | 모듈은 identity·role assignment를 만들지 않으므로(`docs/decisions.md`의 「모듈 경계」) 소비 repo의 bootstrap 계층이 이 리소스를 이름 지어 만든다. `rg`·`st`·`entapp`과 같은 이유로 등재한다 |
| `vwan` | Virtual WAN (`azurerm_virtual_wan`, `Microsoft.Network/virtualWans`) | CAF 표의 `vwan`을 그대로 쓴다. 이 저장소는 vWAN 모듈을 만들지 않는다. 소비 repo가 raw 리소스로 쓴다 |
| `vhub` | Virtual WAN Hub (`azurerm_virtual_hub`, `Microsoft.Network/virtualHubs`) | CAF 표의 `vhub`를 그대로 쓴다. ⚠️ 허브에 붙는 연결(`azurerm_virtual_hub_connection`)과 정적 라우트(`azurerm_virtual_hub_route_table_route`)는 vHub에 종속된 하위 객체라 등재하지 않는다(「종속 객체」 규약. CAF 표에도 독립 항목이 없다) |
| `nic` | 네트워크 인터페이스 (`azurerm_network_interface`, `Microsoft.Network/networkInterfaces`) | CAF 표의 `nic`을 그대로 쓴다 |
| `vm` | Linux 가상 머신 (`azurerm_linux_virtual_machine`, `Microsoft.Compute/virtualMachines`) | CAF 표의 `vm`을 그대로 쓴다. ⚠️ Network·Management/governance·Storage·Identity·Containers 어디에도 맞지 않아 **A.6 Compute**에 둔다 |

## A.1 Network (9)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| Virtual Network | 가상 네트워크 (`azurerm_virtual_network`) | `vnet` | vnet-demo-prd-krc-main |
| Virtual Network | 서브넷 (`azurerm_subnet`) | `snet` | snet-demo-prd-krc-app |
| Network Security | 네트워크 보안 그룹 (`azurerm_network_security_group`) | `nsg` | nsg-demo-prd-krc-app |
| Routing | 라우팅 테이블 (`azurerm_route_table`) | `rt` | rt-demo-prd-krc-app |
| Outbound | NAT 게이트웨이 (`azurerm_nat_gateway`) | `ng` | ng-demo-prd-krc-main |
| Outbound | 공용 IP (`azurerm_public_ip`) | `pip` | pip-demo-prd-krc-main |
| Virtual WAN | Virtual WAN (`azurerm_virtual_wan`) | `vwan` | vwan-demo-prd-krc-main |
| Virtual WAN | Virtual WAN Hub (`azurerm_virtual_hub`) | `vhub` | vhub-demo-prd-krc-main |
| Network Interface | 네트워크 인터페이스 (`azurerm_network_interface`) | `nic` | nic-demo-prd-krc-workbench-01 |

⚠️ `pip`·`ng`·`vnet`·`vwan`·`vhub`·`nic`은 `purpose` 토큰(예: `main`)을 쓴다. `snet`·`rt`는
서브넷 그룹 키를 `purpose` 자리에 쓴다(예: `app`). `snet`은 AWS 카탈로그에도 있으나, 약어
고유성은 파일 안에서만 판정하므로 클라우드 간 재사용은 허용된다.

⚠️ **`nsg`의 `purpose` 의미론은 두 갈래다**: 서브넷 레벨 NSG(`vnet`
모듈이 `subnet_groups`로 만드는 것)는 위 규칙대로 서브넷 그룹 키를 쓴다(예: `app`). NIC
레벨 NSG(예: `aks-workbench`처럼 VM 하나에 직접 붙는 것)는 애초에 서브넷 그룹 키가 없다.
이 경우 `nsg`는 **그 모듈 자신의 purpose 토큰**을 그대로 쓴다(다른 리소스와 동일 규칙으로
되돌아간다). 두 형태 모두 같은 약어 `nsg`를 공유하며, 어느 쪽인지는 그 NSG가 스코프된
대상(서브넷 vs NIC)으로 판별한다(별도 약어를 새로 만들지 않는다).

## A.2 Management and governance (1)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| Resource Manager | 리소스 그룹 (`azurerm_resource_group`) | `rg` | rg-demo-prd-krc-workload-01 |

## A.3 Storage (1)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| Storage | Storage Account (`azurerm_storage_account`) | `st` | st-demo-prd-krc-main-01 |

⚠️ Storage Account 이름은 3~24자, **소문자+숫자만, 하이픈 불가**한 Azure 물리 제약이 있다.
위 "Name 예시"는 토큰 순서(`resourcetype`-`workload`-`env`-`region`-`purpose`-`serial`)만
보여주는 것이고, 실제 이름은 `stdemoprdkrcmain01`처럼 하이픈 없이 이어붙인 뒤 24자 한도에
맞춰 축약한다.

## A.4 Identity (2)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| Microsoft Entra ID | 앱 등록 (`azuread_application`) | `entapp` | entapp-demo-prd-krc-gha-01 |
| Managed Identity | 사용자 할당 관리 ID (`azurerm_user_assigned_identity`) | `id` | id-demo-prd-krc-aks-01 |

⚠️ `entapp`은 **CAF 리소스 약어표에 없다.** 이 카탈로그에서 CAF를 그대로 못 따른 유일한
약어이고, 그 이유와 기각한 후보는 위 「등재 근거」 표가 갖는다. Service Principal은 App
Registration의 `displayName`을 그대로 물려받는 종속 객체라 별도 약어가 없다(위 「종속 객체」 규약).

⚠️ `id`는 이 저장소의 모듈이 만들지 않는다. `aks-cluster` 모듈은 identity도 role
assignment도 만들지 않고 리소스 ID를 입력으로만 받는다(`docs/decisions.md`의 「모듈 경계」와
`modules/azure/aks-cluster/README.md`). 소비 repo의 bootstrap 계층이 이름 지어 만든다.

## A.5 Containers (1)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| Containers | AKS 클러스터 (`azurerm_kubernetes_cluster`) | `aks` | aks-demo-prd-krc-main-01 |

⚠️ 노드 풀(`Microsoft.ContainerService/managedClusters/agentPools`)은 이 카탈로그에
등재하지 않는다. CAF가 권장하는 시스템 노드 풀 약어(8자)와 사용자 노드 풀 약어(`np`)가
이 저장소의 등재 규칙 4(7자 초과 금지)와 예시 형식 검사(예시는 `<약어>-`로 시작)를 동시에
위반해 `scripts/validate-abbreviations.py`가 rc=1로 막는다(실증). 노드 풀 이름 계약(형태·
길이 예산)은 `docs/conventions.md`의 「Azure 강제 방식」이 소유한다.

## A.6 Compute (1)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| Virtual Machines | Linux 가상 머신 (`azurerm_linux_virtual_machine`) | `vm` | vm-demo-prd-krc-workbench-01 |

## 카운트 요약

| # | 카테고리 | 개수 |
|---|---|---|
| A.1 | Network | 9 |
| A.2 | Management and governance | 1 |
| A.3 | Storage | 1 |
| A.4 | Identity | 2 |
| A.5 | Containers | 1 |
| A.6 | Compute | 1 |
| | **합계** | **15** |

> ⚠️ **총계는 세 곳에 있다**: 상단 서술, 섹션 헤더 "(NN)", 이 표. 셋이 어긋나면 SSOT를
> 신뢰할 수 없으므로, **약어를 추가·삭제할 때는 ① 섹션 헤더 ② 상단 총계 ③ 이 표를 함께 고친다.**
> `scripts/validate-abbreviations.py`가 세 값의 일치를 강제한다.
