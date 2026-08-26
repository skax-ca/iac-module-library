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

- 총 **6개** 약어, 1개 카테고리.
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
6. **개정 이력 표에 날짜와 근거를 남긴다.**

### 종속 객체는 약어를 새로 만들지 않고 부모 이름을 상속한다

독립 식별자가 아니라 **부모 리소스에 종속된 하위 객체**는 약어를 신설하지 않고
`<부모 이름>-<역할 접미사>` 형태로 명명한다. 접미사는 위 포맷 표의 **serial/suffix 축**이다.

| 종속 객체 | 명명 | 예시 |
|-----------|------|------|
| `azurerm_subnet_nat_gateway_association` | 별도 이름 없음(서브넷·NAT 이름으로 식별) | 해당 없음 |
| `azurerm_subnet_network_security_group_association` | 별도 이름 없음(서브넷·NSG 이름으로 식별) | 해당 없음 |
| `azurerm_subnet_route_table_association` | 별도 이름 없음(서브넷·라우팅 테이블 이름으로 식별) | 해당 없음 |

## A.1 Network (6)

| L0 | L2 리소스 | 약어 | Name 예시 |
|----|-----------|------|-----------|
| Virtual Network | 가상 네트워크 (`azurerm_virtual_network`) | `vnet` | vnet-demo-prd-krc-main |
| Virtual Network | 서브넷 (`azurerm_subnet`) | `snet` | snet-demo-prd-krc-app |
| Network Security | 네트워크 보안 그룹 (`azurerm_network_security_group`) | `nsg` | nsg-demo-prd-krc-app |
| Routing | 라우팅 테이블 (`azurerm_route_table`) | `rt` | rt-demo-prd-krc-app |
| Outbound | NAT 게이트웨이 (`azurerm_nat_gateway`) | `ng` | ng-demo-prd-krc-main |
| Outbound | 공용 IP (`azurerm_public_ip`) | `pip` | pip-demo-prd-krc-main |

⚠️ `pip`·`ng`·`vnet`은 `purpose` 토큰(예: `main`)을 쓴다. `snet`·`nsg`·`rt`는 서브넷 그룹 키를
`purpose` 자리에 쓴다(예: `app`). `snet`은 AWS 카탈로그에도 있으나, 약어 고유성은 파일 안에서만
판정하므로 클라우드 간 재사용은 허용된다.

## 카운트 요약

| # | 카테고리 | 개수 |
|---|---|---|
| A.1 | Network | 6 |
| | **합계** | **6** |

> ⚠️ **총계는 세 곳에 있다**: 상단 서술, 섹션 헤더 "(NN)", 이 표. 셋이 어긋나면 SSOT를
> 신뢰할 수 없으므로, **약어를 추가·삭제할 때는 ① 섹션 헤더 ② 상단 총계 ③ 이 표를 함께 고친다.**
> `scripts/validate-abbreviations.py`가 세 값의 일치를 강제한다.
