# 10 · VPC 모듈 (스크래치, EKS-aware)

> **승계**: `terraform-enterprise-poc` `docs/design/10-vpc-module.md` @ `76285f7`(동결 커밋)
> **개정**(2026-07-29, D-OSS-STACK §6-2):
> - **실행 스택 종속부 제거** — Terraform/HCP Terraform → **OpenTofu**, `tfe_outputs` 참조 → data source(`03 §3.1`),
>   TFC 워크스페이스 전제 폐기.
> - **PoC 진화 서사 제거** — v1→v2 전환 서술, `877f1d9` 등 PoC 커밋 참조, 승인 날짜, "networking-dev 미적용" 상태 서술.
>   설계 결정 **D1–D9는 판단 내용만 승계**하고 결정 ID를 보존한다(PoC 문서와의 상호 참조 유지).
> - **배포 루트 소유권 이전** — 구 `§1.5 live/dev/networking` 프리셋을 **`examples/`**로 이전.
>   이 repo는 배포 루트를 소유하지 않는다(`03 §4` 각주).
> - **재사용 요건 5종 적용**(`01 §4`) — **D10(kill switch)** 신설, 파라미터화(`poc` 하드코딩 제거),
>   환경 프로파일, 예제 2종, 출력 계약 안정성 규약.
> - **D11(VPC Flow Logs) 신설** — 구 "열린 항목 1"의 보류를 해소해 v1.0.0 스코프에 포함.
> - **D12(삭제 보호) 신설**(2026-07-29 2차 개정) — OpenTofu 1.12 동적 `prevent_destroy` 채택.
>   `required_version`을 **`>= 1.12.0`으로 상향**한다(`02 §2`). D-ENGINE(단일 엔진) 확정으로 가능해진 선택이다.
>
> 이후 **이 문서가 SSOT**다. 원본은 이력 조회용으로만 본다.

> 공통 규약: [02 · 네이밍·태깅·버전 핀](../architecture/02-naming-tagging-and-pinning.md) ·
> 전략 근거: [01 · 모듈 전략](../architecture/01-module-strategy.md) ·
> 의존성 원칙: [03 · 의존성 & 공유 리소스](../architecture/03-dependencies.md)

**전략 위치**: 안정·단순·지식밀도 낮음 → **스크래치 얇은 모듈**(`01 §2.2`).
커뮤니티 VPC 모듈 대신 스크래치를 택한 이유는 EKS 서브넷 태깅 로직을 명시적으로 소유하기 위함이다
(커뮤니티 모듈의 EKS 태그 옵션은 복잡 — `01 §5`).

**릴리스 스코프**: 이 문서의 §1이 `vpc-v1.0.0`의 계약이다. 계약 확장은 마이너, 계약 변경은 메이저(`02 §3`).

---

## 1. 설계

### 1.0 이 모듈이 충족해야 할 요구

엔터프라이즈 네트워크 요구(온프레미스·멀티클라우드 연동, 용도별 대역 관리)를 모듈 계약으로 환원한 것:

| # | 요구 | v1.0.0 |
|---|------|--------|
| G1 | Secondary CIDR — 온프레미스/멀티클라우드 연동 시 unique(RFC1918)/비라우팅(100.64/10, RFC 6598) 대역 분리, CIDR 증설 | ✅ `secondary_cidr_blocks` |
| G2 | 용도별 서브넷 분리 — app(컨테이너/VM)·elb(온프레미스 방화벽 오픈 단위)·db(소형 CIDR)·endpoint 등 | ✅ `subnet_groups` |
| G3 | TGW attachment 전용 `/28` 서브넷 (AWS 공식 모범사례) | ✅ 계약으로 수용(`isolated` 그룹). TGW·attachment 자체는 범위 밖 |
| G4 | 그룹별 라우팅 차등 — NAT/isolated(무 인터넷 경로)/TGW + **운영 중 라우트 추가/변경이 빈번** | ✅ D3(구조/운영 라우트 분리) |
| G5 | 명시적 CIDR 할당 | ✅ D2. **IPAM 연계는 범위 밖**(열린 항목 3) |
| G6 | 트래픽 감사 근거 확보 | ✅ D11(Flow Logs) |

### 1.1 설계 결정

**D1. 서브넷 계층을 `subnet_groups` map으로 일반화 (G2)**
public/private 하드코딩을 두지 않고, 용도별 그룹의 map을 입력 계약으로 삼는다.
그룹의 `type`(public/private/isolated)이 라우팅 동작을 결정한다.

**D2. CIDR는 명시적 입력 (G5)**
엔터프라이즈에서 대역은 IPAM/네트워크 팀이 할당하고 IaC는 이를 기록하는 쪽이다.
모듈 계약은 그룹별 명시적 `cidrs` 리스트로 단순화하고, **`cidrsubnet()` 파생은 소비자 루트의 locals가 소유**한다
(계산의 소유가 모듈 → 소비자로 이동할 뿐 폐기가 아님 — 파생이 필요한 소비자는 예제의 locals를 복사한다).
그룹 간 중첩은 AWS API가 subnet 생성 시 거부하므로 모듈 내 중복 검증은 두지 않는다(입력 **형식** 검증만 `validation`).

**D3. 구조 라우트 / 운영 라우트 분리 (G4) — 핵심 결정. prefix list는 권장 옵션**
운영에서 라우트 추가/변경이 빈번하다는 현실을 모듈 경계 설계에 반영한다.

| 구분 | 정의 | 소유 | 변경 빈도 |
|------|------|------|-----------|
| **구조 라우트** | 토폴로지가 결정: public→IGW, private→NAT, isolated→local only | **모듈** | 낮음 (토폴로지 변경 시만) |
| **운영 라우트** | 연동이 결정: 온프레미스 대역→TGW/VGW, 타 VPC, 검사 어플라이언스 등 | **소비 프로젝트 루트/foundation** | 높음 |

- **핵심은 분리 그 자체다**: 모듈은 구조 라우트만 소유하고, `route_table_ids_by_group` 출력으로
  운영 라우트의 앵커를 제공한다. 앵커에 무엇을 거는지는 모듈이 제약하지 않는다 —
  운영 라우트는 표준 `aws_route`이므로 **목적지·타깃 조합이 자유롭다**:

  | 축 | 선택지 |
  |----|--------|
  | 목적지 | CIDR 직접 지정(`destination_cidr_block`) · **prefix list**(`destination_prefix_list_id`) · IPv6 CIDR |
  | 타깃 | TGW · VGW · VPC peering · NAT GW · ENI(어플라이언스) · egress-only IGW · Core Network 등 |

- 그중 **prefix list는 "목적지 대역 집합이 자주 바뀌는" 운영 라우트의 권장 기본값**이다
  (필수 아님 — 고정 단일 대역이면 CIDR 직접 지정이 더 단순).
  대역 추가 시 **prefix list 엔트리만 갱신**하면 이를 참조하는 모든 라우트/SG rule에
  일괄 반영된다 — 라우트 리소스 자체는 불변.
- **근거**: ① 라우트 churn이 모듈 인터페이스 churn이 되면 태그 기반 승격 체계(`02 §3`)와 충돌한다 —
  대역 추가마다 모듈 릴리스가 필요해진다. ② prefix list는 공유 리소스이므로 foundation 소유 +
  네이밍 기반 data source 조회가 [03 · 의존성](../architecture/03-dependencies.md) 원칙과 일치
  (멀티어카운트 확장 시 네트워크 계정에서 RAM 공유). ③ SG rule(`prefix_list_id`)에도 동일 prefix list를
  참조해 방화벽 정책과 라우팅의 대역 SSOT를 하나로 유지.
- **prefix list 공식 제약** (설계에 영향): region 단위 리소스 · `max_entries`는 생성 시 지정
  (버전 관리·롤백 지원) · **참조하는 리소스의 쿼터를 max_entries만큼 소모**
  (RT 라우트 쿼터 기본 50, SG rule 쿼터 60) → max_entries는 여유분 포함 신중히 산정.
- 약어: `pl` (카탈로그 등재 확인 — "VPC | 관리형 접두사 목록").

운영 라우트 확장 규약 (**소비 프로젝트 루트**의 코드 — 이 repo의 소유가 아니다):
```hcl
data "aws_ec2_managed_prefix_list" "onprem" {
  name = "pl-acme-dev-an2-onprem" # foundation 소유, 네이밍 조회(03 §3.2)
}
resource "aws_route" "app_to_onprem" {
  count                      = length(module.vpc.route_table_ids_by_group["app-uniq"])
  route_table_id             = module.vpc.route_table_ids_by_group["app-uniq"][count.index]
  destination_prefix_list_id = data.aws_ec2_managed_prefix_list.onprem.id
  transit_gateway_id         = data.aws_ec2_transit_gateway.this.id
}
```

**D4. EKS 태그의 그룹별 이관**
public 전체에 `role/elb`, private 전체에 `role/internal-elb`를 일괄 부착하지 않고,
그룹별 `eks_role` 필드(`"elb"` / `"internal-elb"` / null)로 명시한다 —
온프레미스 방화벽 오픈 대역(elb 그룹)과 EKS 노드 대역(app 그룹)의 분리 목적과 일치한다.
`kubernetes.io/cluster/<name>=shared` 태그는 `eks_role`이 지정된 그룹에만 부착한다.

**D5. 출력 계약은 그룹 map (D1의 필연적 귀결)**
`private_subnet_ids`/`public_subnet_ids` 같은 **타입 고정 리스트 출력을 두지 않는다.**
`subnet_groups`가 임의 그룹을 허용하는 이상 고정 리스트는 표현력이 부족하고, 그룹이 추가될 때마다
출력이 늘어 계약이 불안정해진다. 출력은 **그룹 키를 그대로 쓰는 map**이다(§1.4).

**D6. 그룹별 AZ 차등 — AZ 수 = `length(cidrs)` 파생**
3AZ가 필요한 quorum 계열(MSK·OpenSearch — 공식 3AZ 권장)만 3AZ로, 나머지는 2AZ로
줄여 IP·비용을 절감한다. 별도 필드 없이 **그룹의 `cidrs` 리스트 길이가 곧 그 그룹의 AZ 수**다
(잘못된 상태를 표현할 수 없는 인터페이스). `az_count`는 "최대 AZ 슬라이스"로 정의한다.
- precondition: `2 <= length(cidrs) <= az_count` (전 그룹)
- **AZ 커버리지 제약 2건**: ① TGW attachment 그룹은 워크로드가 존재하는 모든 AZ를 커버해야 한다
  (공식: "attachment 없는 AZ의 리소스는 TGW 도달 불가") → 최대 AZ 그룹과 동일 폭.
  ② per-AZ NAT 모드(`single_nat_gateway = false`)에서는 NAT 호스트(public) 그룹의 AZ 수 ≥
  private 그룹 최대 AZ 수 (precondition으로 강제).
- EKS는 최소 2AZ(공식) — 컨트롤플레인 HA는 AWS 관리이므로 노드 2AZ로 충분하다.
  in-cluster quorum 워크로드를 돌리게 되면 3AZ 재평가.

**D7. AZ 선택 우선순위 — `az_selection`**
기본 AZ를 a·c로 하고 3AZ 그룹만 b를 추가로 쓴다(서울 리전 관례).
`az_selection`(suffix 우선순위 리스트, 예: `["a", "c", "b"]`)을 두어,
그룹은 이 목록의 **앞에서부터 `length(cidrs)`개** AZ에 배치된다.
null이면 리전 AZ 목록의 앞 `az_count`개를 그대로 쓴다. suffix→AZ 이름 해석은
data source 기반이므로 리전 이식성을 유지한다.

**D8. 데이터 서비스 전용 `data` 그룹**
MSK·OpenSearch·Redis는 `db`(관계형)와 분리한 **isolated 3AZ 그룹**에 배치한다.
- 분리 근거: ① AZ 수 요구가 다름(RDS 2 vs MSK/OS 3 — 통합 시 db까지 3AZ 강제)
  ② IP 소모 프로파일(db는 소수 고정 ENI, data는 브로커/노드/캐시노드 다수·스케일아웃 가변)
  ③ 온프레미스 방화벽 오픈 대역 단위 분리(Kafka 9092-9098 등).
  라우팅은 db와 동일(isolated)이므로 라우팅은 분리 근거가 아니다.
- per-service 분리(msk/es/redis 각각)는 비권장 — 서비스 간 격리는 SG가 주 방어선(`03 §4`),
  AWS도 subnet group(서브넷 목록) 개념으로 공유 서브넷을 상정한다.
- ⚠️ 이 결정은 **프리셋 권고**이지 모듈 계약이 아니다. 모듈은 그룹 이름·개수를 강제하지 않는다.

**D9. dup 대역(100.64/16)의 온프레미스 통신 — custom networking 채택, private NAT는 전환 조건 명시**

배경: dup(비라우팅) 대역에 놓인 노드·Pod는 정의상 온프레미스로 라우팅되지 않는다. 해법 3안:

| | **A. custom networking (채택)** | B. private NAT gateway | C. 중앙 NAT VPC |
|---|---|---|---|
| 구조 | **노드는 uniq(`node` 그룹), Pod만 dup**(ENIConfig) | 노드·Pod 모두 dup 유지 + uniq 대역에 private NAT | Shared Services VPC에 NAT 집중 |
| Pod→온프레미스 | VPC CNI 기본 SNAT(`AWS_VPC_K8S_CNI_EXTERNALSNAT=false`)가 노드의 uniq IP로 변환 | private NAT IP로 변환 (dup RT: 온프레미스 대역→NAT, NAT 서브넷 RT: →TGW) | 중앙 NAT에서 변환 (Pod IP를 TGW 너머까지 유지 — EXTERNALSNAT=true 필요) |
| 온프레미스→Pod | 3안 공통: elb 그룹 내부 LB 경유 (NAT는 "VPC 내부 개시 연결만" — egress 전용, 공식 제약) | 〃 | 〃 |
| 추가 고정비 | **$0** | +$43/월/AZ + $0.059/GB | VPC+NAT+TGW 비용 |
| 방화벽 오픈 단위 | 노드 서브넷 CIDR | private NAT IP (소수 고정 IP — allow-list 요구가 엄격하면 유리) | 중앙 NAT 대역 |
| 운영 | ENIConfig(AZ별)·max-pods 감소(prefix delegation으로 완화) | EKS 무변경(가장 단순) | 멀티클러스터급 복잡도 |

**A 채택 근거**: ① EKS 공식 모범사례가 온프레미스 연결의 권장 패턴으로 기술 ② 추가 고정비 0
③ **클러스터 생성 전에 적용해야 무비용** — 생성 후 전환은 전 노드 drain(파괴적)
④ 방화벽 오픈이 노드 서브넷 대역 단위로 명확.

**B로 전환하는 조건** (이때 모듈에 private NAT 옵션 추가 — 라우트는 D3 운영 라우트 규약대로 prefix list→NAT):
① 노드 수 폭증으로 노드 IP조차 uniq에 못 둘 때 ② **EKS 외 워크로드(VM 등)를 dup 대역에 배치할 때**
(node-SNAT는 VPC CNI 기능이라 EKS에만 적용 — 이 경우 B 외 대안 없음) ③ 온프레미스가 소수 고정 IP allow-list를 요구할 때.

**C로 전환하는 조건**: 멀티클러스터·멀티계정 확산 단계에서 dup 대역을 온프레미스에 광고하지 않으면서
계정 간 NAT를 집중할 때 (AWS Containers 블로그 패턴).

**프리셋 반영**: 노드용 uniq 그룹(private — node-SNAT의 소스이자 NAT 아웃바운드 경로)과
Pod 전용 dup 그룹(**isolated**)을 분리한다. Pod의 VPC 외부 egress는 노드 primary ENI로
SNAT되어 노드 그룹 RT를 타므로 Pod 서브넷엔 기본 경로가 불필요하다.
⚠️ 단 C안 전환(EXTERNALSNAT=true) 시엔 Pod 서브넷 RT에 경로가 필요해지므로 재설계 대상.

**D10. kill switch `vpc_enabled` (신설 — `01 §4` 재사용 요건)**

`vpc_enabled = false`면 모듈이 만드는 **전 리소스와 data source의 `count`가 0**이 된다.

- **왜 data source까지인가**: 참조 대상이 사라진 뒤에도 plan이 통과해야 teardown이 성립한다
  ([`poc-findings.md` §6](../reference/poc-findings.md) 참조 — **이 repo에서 재현하지 않았다**).
- **이 모듈의 실제 위험도**: 모듈의 유일한 data source는 `aws_availability_zones`(리전 단위 조회)로,
  파기되는 리소스에 의존하지 않으므로 그 자체로는 위 위험이 없다. 그럼에도 `count`를 거는 이유는
  **규약 일관성**과 비활성 시 불필요한 API 호출 제거다. 규칙을 모듈마다 다르게 적용하면
  릴리스 게이트(`modules/AGENTS.md`)가 판정 불가능해진다.
- **출력은 null-safe여야 한다**: 비활성 시 `vpc_id`는 `null`, map 출력은 `{}`를 반환한다.
  **실제 §6 위험은 소비자 쪽에 있다** — 소비자가 `data.aws_vpc`로 이름 조회를 하고 있으면
  VPC 파기 후 그쪽 plan이 깨진다. 이는 소비 프로젝트가 자기 kill switch로 다뤄야 할 문제이며,
  모듈은 "출력이 에러 대신 null을 준다"까지를 보장한다.
- 테스트 의무: `vpc_enabled = false`에서 plan이 통과하고 리소스 수가 0인지 검증한다(§2 Task 10.6).

**D12. 삭제 보호 `deletion_protection` (신설 — OpenTofu 1.12 동적 `prevent_destroy`)**

D10은 **파괴 방향** 장치다. 반대 방향, 즉 prd VPC를 실수로 지우지 못하게 하는 수단이 모듈에 없었다.
재사용 모듈이 `prevent_destroy`를 쓰지 못해온 이유는 그 인자가 **리터럴만** 받아 소비자가 제어할 수
없었기 때문이다. **OpenTofu 1.12부터 입력 변수를 참조할 수 있다** —
*"The `prevent_destroy` argument in a resource's lifecycle block can now refer to other symbols
within the same module, such as input variables."*([OpenTofu 1.12 릴리스 노트](https://opentofu.org/docs/intro/whats-new/))

**결정**

| 항목 | 내용 |
|------|------|
| 변수 | `deletion_protection`(bool, **기본 `false`**) |
| 적용 대상 | **`aws_vpc` 하나뿐** — VPC가 막히면 전체가 막힌다. 하위 리소스까지 걸면 오류 지점만 늘어난다 |
| 구현 | `lifecycle { prevent_destroy = var.deletion_protection }` |
| `required_version` | **`>= 1.12.0`으로 상향**. 이 기능이 하한을 올리는 근거다(`02 §2` — "실제로 쓰는 기능 기준") |

**기본값이 `false`인 이유**: D10의 teardown 보장이 **기본 동작**이어야 한다. 보호는 opt-in이다.
기본을 `true`로 두면 모든 소비자가 파기 전에 우회 절차를 배워야 하고, 릴리스 게이트의
"kill switch로 plan이 통과한다"는 판정이 기본 구성에서 깨진다.

**D10과의 상충 — 실측으로 확인했다** (OpenTofu 1.12.5, 2026-07-29, 이 repo에서 재현):

| 조합 | 실측 결과 |
|------|----------|
| `vpc_enabled = false` + `deletion_protection = true` | ❌ **plan 차단** — `Error: Resource instance cannot be destroyed` |
| `vpc_enabled = false` + `deletion_protection = false` | ✅ plan 통과 |

즉 **두 변수는 실제로 충돌한다.** 처리 방식:

1. **`validation`으로 조기 차단**(교차변수 참조) — `deletion_protection && !vpc_enabled` 조합을 거부하고,
   *"파기하려면 `deletion_protection = false`로 먼저 apply하라"*는 **도메인 언어의 메시지**를 준다.
   엔진 기본 메시지도 명확하지만 우리 변수 이름으로 해법을 알려주지는 않는다.
2. `prevent_destroy`는 **최종 방어선**으로 남는다 — validation을 우회해도 파괴는 막힌다.

**결과적으로 teardown은 2단계가 된다**(보호를 켠 경우에 한해): `deletion_protection = false` apply →
`vpc_enabled = false` apply. 이는 결함이 아니라 **보호의 정의**다.

> ⚠️ **교차변수 `validation`은 `validate`가 아니라 `plan` 시점에 평가된다**(2026-07-29 실측).
> 잘못된 조합으로 모듈을 호출해도 `tofu validate`는 **Success로 통과**했고, `tofu plan`에서만
> 우리 메시지와 함께 차단됐다. 따라서 이 계약은 **`*.tftest.hcl`(plan 기반)이 유일한 검출 지점**이다 —
> `examples/*`를 `validate`까지만 도는 규약(`examples/AGENTS.md`)으로는 잡히지 않는다.
> `az_selection` 길이 검증(§1.2)도 같은 성질이므로 Task 10.6에서 함께 다룬다.

> ⚠️ **Terraform 비호환 지점**(`04 §5`가 요구하는 사유 기록). 이 문법은 OpenTofu 1.12 전용이다.
> 채택 사유: **재사용 모듈이 소비자에게 삭제 보호를 위임할 수 있는 유일한 수단**이며,
> 이것이 OpenTofu 채택으로 얻는 첫 번째 기능적 이득이다(`04 §4.1`).

**D11. VPC Flow Logs를 v1.0.0 스코프에 포함 (신설 — 구 "열린 항목 1" 해소)**

PoC는 Flow Logs를 보류하고 trivy 예외로 처리했다. 이 repo는 **재사용 자산이므로 보안 기본값을 켠 채 배포한다**
(`flow_logs_enabled` 기본 `true`).

**측정 근거** — 이 repo에서 직접 실행(trivy 0.72.0, 2026-07-29). 각 구성을 `trivy config`로 스캔한 결과:

| 구성 | 검출 |
|------|------|
| VPC만 (Flow Logs 없음) | `AVD-AWS-0178` **MEDIUM** 1건 — "VPC does not have VPC Flow Logs enabled" |
| + Flow Logs → CloudWatch Logs (`kms_key_id` 미지정, 리터럴) | `AVD-AWS-0017` **LOW** 1건 — "Log group is not encrypted" |
| + `kms_key_id` 리터럴 지정 | **0건** |
| + `kms_key_id = var.…` (기본 `null`) | **0건** |

→ 두 가지가 설계에 반영된다:
1. Flow Logs를 켜면 MEDIUM이 사라지지만 **LOW가 새로 생긴다.** 로그 그룹 암호화를 옵션으로 열어야
   게이트를 완전히 clean하게 유지할 수 있다.
2. `kms_key_id`를 **변수 참조**로 두면 trivy가 값을 확정할 수 없어 검출하지 않는다. 즉 모듈은
   `.trivyignore` 등재 없이 게이트를 통과한다 — 이 repo의 "예외 0건" 상태를 유지한다.
   ⚠️ 다만 예제가 모듈에 리터럴/기본값을 넘기는 형태에 따라 판정이 달라질 수 있으므로,
   예제 작성 후 `trivy config .`를 재실행해 확인한다(§2 Task 10.7).

**소유권**: KMS 키는 계정 전역 공유·보안 거버넌스 대상이므로 **모듈이 생성하지 않는다**
(`03 §4` 소유 판별 규칙 — "2개 이상 공유 or 보안 거버넌스 대상 → foundation"). `flow_logs_kms_key_id`로
ARN을 주입받고, `null`이면 CloudWatch 기본 암호화(AWS 관리 키)로 동작한다.

**대상은 CloudWatch Logs**로 고정한다. S3·Firehose 대상은 버킷/스트림 소유권이 모듈 밖이라
얇은 모듈 원칙(`01 §2.2`)을 깨뜨린다 — 필요해지면 `flow_logs_destination_type` 확장으로 마이너 릴리스한다.

**리소스 구성** (provider 문서 확인 — `aws_flow_log`는 `vpc_id` 지정 시 `traffic_type` 필수,
`log_destination_type` 기본 `cloud-watch-logs`, CloudWatch 대상은 `iam_role_arn` 필요):

| 리소스 | 역할 |
|--------|------|
| `aws_cloudwatch_log_group` | 로그 대상. `retention_in_days`·`kms_key_id` 파라미터화 |
| `aws_iam_role` | `vpc-flow-logs.amazonaws.com`이 assume. 컴포넌트 전용이므로 **모듈 소유**(`03 §4`) |
| `aws_iam_role_policy` | `logs:CreateLogStream`·`PutLogEvents`·`DescribeLogStreams` 등 (inline) |
| `aws_flow_log` | `vpc_id` + `traffic_type` + `log_destination` |

### 1.2 인터페이스 (variables)

```hcl
# ── 공통 규약 ──────────────────────────────────────────────
variable "naming" {                                  # 02 §1.4(b) — 소비자가 약어를 타이핑하지 않게 한다
  type = object({ workload = string, env = string, region_code = string })
}
variable "purpose" { type = string  default = "main" }
variable "tags"    { type = map(string)  default = {} }   # 거버넌스 태그는 default_tags 소관(02 §1.1)

variable "vpc_enabled" { type = bool  default = true }    # D10 — kill switch(파괴 방향)
variable "deletion_protection" {                          # D12 — 보호 방향. OpenTofu 1.12 전용
  type    = bool
  default = false                                         # 기본 false — D10 teardown 보장이 기본 동작
  # validation: deletion_protection && !vpc_enabled 조합 거부(D12)
}

# ── 주소 공간 ──────────────────────────────────────────────
variable "cidr_block" { type = string }              # primary CIDR
variable "secondary_cidr_blocks" {                   # G1 — 예: Pod용 ["100.64.0.0/16"]
  type    = list(string)
  default = []
}

variable "az_count" { type = number  default = 3 }   # 최대 AZ 슬라이스 (그룹별 실제 AZ 수는 length(cidrs) — D6)

variable "az_selection" {                            # D7 — AZ suffix 우선순위. null=리전 앞 az_count개
  type    = list(string)                             # 예: ["a", "c", "b"] — 2AZ 그룹은 a·c, 3AZ 그룹은 a·c·b
  default = null
  # validation: 지정 시 length == az_count
}

variable "subnet_groups" {                           # G2/G4 — 키 = purpose 토큰 (Name에 사용)
  type = map(object({
    type       = string                              # "public" | "private" | "isolated"
    cidrs      = list(string)                        # AZ 순서 명시적 CIDR — 길이 = 그룹 AZ 수 (2..az_count, D6)
    eks_role   = optional(string)                    # "elb" | "internal-elb" | null (D4)
    extra_tags = optional(map(string), {})
  }))
  # validation: type enum, eks_role enum. 2 <= length(cidrs) <= az_count는 precondition으로
}

# ── 환경 프로파일 (01 §4 — 소비자가 조건 분기를 짜지 않게 한다) ──
variable "enable_nat_gateway" { type = bool  default = true }   # private 그룹에만 적용
variable "single_nat_gateway" { type = bool  default = false }  # dev: true(비용) / prd: false(HA)
variable "eks_cluster_name"   { type = string  default = null }

# ── Flow Logs (D11) ────────────────────────────────────────
variable "flow_logs_enabled"        { type = bool    default = true }
variable "flow_logs_retention_days" { type = number  default = 30 }
  # 유효값: 0(무기한),1,3,5,7,14,30,60,90,120,150,180,365,400,545,731,1096,1827,2192,2557,2922,3288,3653
variable "flow_logs_traffic_type"   { type = string  default = "ALL" }   # ACCEPT | REJECT | ALL
variable "flow_logs_kms_key_id"     { type = string  default = null }    # foundation 소유 CMK ARN. null=AWS 관리 키
```

라우팅·리소스 매트릭스 (`type`이 결정 — D1/D3):

| type | 0.0.0.0/0 경로 | RT 구성 | 용도 예시 |
|------|---------------|---------|-----------|
| `public` | IGW | 그룹당 1개 공유 | elb, nat 호스팅 |
| `private` | NAT (`single_nat_gateway` 분기) | **AZ별** (NAT 경로 분기) | app, node |
| `isolated` | 없음 (local 라우트만 — secondary 연결 시 자동 추가됨) | 그룹당 1개 공유 | db, endpoint, tgw, pod |

- NAT Gateway는 `type == "public"`인 **첫 번째 그룹**(map 키 정렬 기준)의 서브넷에 배치한다.
  public 그룹이 없으면 `enable_nat_gateway = true`는 검증 오류.
- per-AZ NAT(`single_nat_gateway = false`) 시 NAT 호스트 그룹의 AZ 수가 private 그룹
  최대 AZ 수 이상이어야 한다(D6 precondition) — 아니면 커버되지 않는 AZ의 NAT 경로가 없다.
- ⚠️ **secondary CIDR 함정**: 서브넷 CIDR가 secondary 대역이면
  `aws_vpc_ipv4_cidr_block_association`이 먼저 `associated` 상태여야 하는데 OpenTofu가
  참조 관계로 추론하지 못한다 → `aws_subnet`에 `depends_on = [aws_vpc_ipv4_cidr_block_association.this]` 필수.
- ⚠️ **primary/secondary 조합 제약**: primary가 `10.0.0.0/15` 범위 안이면 `10.0.0.0/16` 대역의 secondary는
  연결 불가(공식 제약표). 이 제약은 **plan이 아니라 apply 시 API가 검출**하므로 `tofu test`로 잡히지 않는다 —
  예제/프리셋에서 대역을 고를 때 주의한다.

#### 1.2-1 구현 제약 (2026-07-30 보강 — Task 10.2 착수 중 확정)

§1.2의 **계약(변수·출력)은 바뀌지 않았다.** 아래는 계약을 그 형태로만 구현할 수 있게 만드는 제약과,
설계가 침묵했던 지점의 결정이다. 근거를 남기지 않으면 이후 세션이 되돌릴 위험이 있는 것들만 적는다.

| # | 항목 | 결정과 근거 |
|---|------|------------|
| C1 | **구조 라우트는 별도 `aws_route`** — `aws_route_table`의 inline `route` 블록 금지 | provider 문서: inline `route`와 `aws_route`는 **혼용 불가**("will cause a conflict of rule settings and will **overwrite** rules"). D3는 소비자가 모듈의 RT에 `aws_route`로 운영 라우트를 얹는 구조이므로, 모듈이 inline을 쓰면 **소비자의 운영 라우트가 덮어써진다** — D3 앵커 계약이 성립하지 않는다. `CLAUDE.md`의 SG rule 규칙(inline 금지·혼용 금지)과 동일 원리 |
| C2 | **VPC DNS 속성은 `true` 하드코딩** (`enable_dns_support`·`enable_dns_hostnames`) | 사용자 승인(2026-07-30). EKS 프라이빗 엔드포인트·VPC 엔드포인트 프라이빗 DNS가 둘 다 요구한다. `aws_vpc` 기본값은 `hostnames = false`라 명시하지 않으면 동작하지 않는다. **변수화하지 않은 이유**: 얇은 모듈의 계약 표면을 늘리지 않는다 — 끌 수요가 생기면 `02 §3`대로 **계약 확장 = 마이너** |
| C3 | **IGW는 `public` 그룹이 1개 이상일 때만 생성** | public 그룹이 없으면 IGW를 걸 RT가 없다. 무조건 생성하면 고아 IGW가 남는다 |
| C4 | **public 서브넷에 `map_public_ip_on_launch`를 설정하지 않는다**(기본 `false`) | public 그룹의 용도는 **ELB·NAT 호스팅**이고 둘 다 자동 공개 IP가 불필요하다(ALB는 자체 주소, NAT는 EIP). ⚠️ **EKS 노드를 public 서브넷에 두려면 auto-assign이 필수**(공식) — 그 구성은 이 모듈의 프리셋 범위 밖이다(노드는 `private` 그룹) |
| C5 | **NAT는 `private` 그룹이 존재할 때만 생성** | `enable_nat_gateway`는 "private 그룹에 NAT 경로를 구성할지"다(§1.2). private 그룹이 없으면 구성할 경로가 없고, NAT는 유휴로도 과금된다 |
| C6 | **precondition 5건** — 설계가 명시한 3건(D6 2건 + NAT/public) + **평가 안전 2건**(리전 AZ 수 ≥ `az_count`, `az_selection` suffix가 리전에 존재) | 후자 2건이 없으면 잘못된 입력이 **locals의 index 오류**로 먼저 죽어 `tofu test`의 `expect_failures`가 잡을 수 없다 — `expect_failures`는 **선언된 check 객체만** 대상으로 한다. 같은 이유로 locals는 `min()`/`slice()`로 범위를 잘라 **precondition이 먼저 말하게** 한다 |
| C7 | **`extra_tags`는 서브넷에만 부착** | §1.2가 "그룹 단위 추가 태그"라고만 정의한다. RT는 그룹당 1개(또는 AZ별)로 서브넷과 1:1이 아니므로 보수적으로 서브넷에 한정한다. RT 태그가 필요해지면 계약 확장(마이너) |
| C8 | ⚠️ **`kubernetes.io/cluster/<name> = shared`는 레거시 태그다** | [공식 문서](https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html) 확인(2026-07-30): *"When you create a new Kubernetes cluster now, Amazon EKS doesn't add the tag to your subnets"* — **AWS Load Balancer Controller 2.1.1 이하만** 요구하고 최신 버전은 제거해도 무중단이다. D4대로 구현하되(기본 `eks_cluster_name = null`이라 opt-in), **필수 요구로 오해하지 말 것**. 현행 필수는 `kubernetes.io/role/{elb,internal-elb} = 1` 뿐이다 |

### 1.3 네이밍 (`02 §1.2` 포맷 · 카탈로그 A.2 정합)

그룹 키가 Name의 purpose 토큰이 된다. **그룹 키는 `<용도 축약>-<uniq|dup>` 형식을 권고**한다 —
이름만으로 용도와 온프레미스 라우팅 가능 여부를 판별할 수 있게 하기 위함이다.
(⚠️ 권고이지 모듈의 강제 사항이 아니다. 모듈은 키를 그대로 Name 토큰으로 쓴다.)
serial은 동일 용도·대역 조합이 복수일 때만 붙인다.

`local.name_mid = "${naming.workload}-${naming.env}-${naming.region_code}"` (`02 §1.4(b)`).

| 리소스 | 약어 | Name 패턴 | 예시 |
|--------|------|-----------|------|
| `aws_vpc` | `vpc` | `vpc-<mid>-<purpose>` | vpc-acme-dev-an2-main |
| `aws_subnet` | `snet` | `snet-<mid>-<group>-<az>` | snet-acme-dev-an2-pod-dup-a |
| `aws_route_table` (private) | `rtb` | `rtb-<mid>-<group>-<az>` | rtb-acme-dev-an2-node-uniq-a |
| `aws_route_table` (public/isolated) | `rtb` | `rtb-<mid>-<group>` | rtb-acme-dev-an2-db-uniq |
| `aws_internet_gateway` | `igw` | `igw-<mid>-<purpose>` | igw-acme-dev-an2-main |
| `aws_nat_gateway` | `ngw` | `ngw-<mid>-<nat그룹>-<az>` | ngw-acme-dev-an2-pub-uniq-a |
| `aws_eip` (NAT) | `eip` | `eip-<mid>-nat-<az>` | eip-acme-dev-an2-nat-a |
| `aws_cloudwatch_log_group` (D11) | `cwlg` | `cwlg-<mid>-<purpose>-flowlog` | cwlg-acme-dev-an2-main-flowlog |
| `aws_iam_role` (D11) | `iamr` | `iamr-<mid>-<purpose>-flowlog` | iamr-acme-dev-an2-main-flowlog |
| `aws_flow_log` (D11) | `fl` | `fl-<mid>-<purpose>` | fl-acme-dev-an2-main |

- 약어는 전부 [카탈로그](../reference/aws-naming-abbreviations.md)에 등재된 것이다(임의 생성 없음).
- ✅ **`fl`은 2026-07-30에 카탈로그에 신규 등재했다**(Task 10.3에서 필요해짐). 약어가 없을 때의
  올바른 처리는 **생략도 임의 생성도 아니라 "확정 후 카탈로그에 추가"** 다 — `Name` 없이 배포하면
  나중에 태그를 붙일 때 재적용이 필요하고, 릴리스 게이트의 `Name` assertion을 통과할 수 없다.
- **`aws_iam_role_policy`(inline)는 카탈로그의 "종속 객체" 규약을 따른다**(2026-07-30 명문화) —
  독립 식별자가 아니라 role에 종속된 하위 객체이므로 **role 이름 + suffix**
  (`iamr-<mid>-<purpose>-flowlog-policy`)로 명명하고 새 약어를 만들지 않는다.
  ⚠️ 관리형 정책(`aws_iam_policy`)은 독립 자원이라 별도 약어 **`iamp`** 가 있다(같은 날 등재).
  ⚠️ inline 정책은 `tags`를 지원하지 않으므로 이 이름은 `Name` 태그가 아니라 **`name` 인자 = 식별자**다.
- `aws_cloudwatch_log_group`의 `name`은 Name 태그와 별개로 CloudWatch 경로 관례(`/aws/vpc/flow-log/…`)를
  따를 수 있다 — **경로형 이름과 `Name` 태그는 다른 축**이다(`02 §1.5` 제약 리소스와 같은 취급).

### 1.4 출력 계약 (outputs)

```hcl
output "vpc_id"                   {}   # string      — vpc_enabled=false면 null (D10)
output "vpc_cidr_block"           {}   # string      — primary
output "secondary_cidr_blocks"    {}   # list(string) — 연결 완료된 secondary 목록
output "subnet_ids_by_group"      {}   # map(list(string)) — AZ 순서
output "route_table_ids_by_group" {}   # map(list(string)) — 운영 라우트 앵커(D3)
output "nat_gateway_ids"          {}   # list(string)
output "flow_log_group_name"      {}   # string      — D11. 비활성 시 null
```

**계약 규약** (`01 §4` · `02 §3`):
- 출력 이름은 **메이저 버전 내에서 안정**하다. rename·삭제는 메이저(`vpc-v2.0.0`), 추가는 마이너.
- map 출력의 **키는 소비자가 넘긴 `subnet_groups` 키 그대로**다. 모듈이 키를 변형하지 않는다 —
  소비자 입장에서 자기가 준 키로 되받는 것이 가장 예측 가능하다.
- `vpc_enabled = false`일 때 스칼라 출력은 `null`, map/list 출력은 빈 값이다(D10).

**하류(eks-cluster)의 소비 방식**: `tfe_outputs`나 `terraform_remote_state`를 쓰지 않는다.
[`03 §3.1`](../architecture/03-dependencies.md) 선호 순서에 따라 **① 결정적 네이밍 → ② `data.aws_*` 조회**로
푼다. 같은 루트에서 호출하면 이 출력을 직접 넘기고, 루트가 다르면 `data.aws_vpc`/`data.aws_subnets`를
`Name` 태그 필터로 조회한다 — §1.3 네이밍이 결정적이기 때문에 성립하는 방식이다.

### 1.5 예제 (`examples/` — 이 repo가 소유하는 유일한 호출 지점)

> ⚠️ 이 절은 **배포 루트가 아니다.** 이 repo는 배포 루트를 소유하지 않는다(`03 §4` 각주).
> 아래는 `tofu test`가 실행되는 검증 대상이자 소비자에게 보여줄 사용 예시다.
> 디렉토리 명명은 `examples/AGENTS.md`의 `<module>-<scenario>/` 규약을 따른다.

#### (a) `examples/vpc/` — minimal

모듈 계약의 **핵심 경로**를 최소 비용으로 검증한다. 소비자의 복사 시작점이기도 하다.

| 그룹 키 | type | AZ | 크기 | eks_role | 목적 |
|---------|------|----|----|----------|------|
| `pub-uniq` | public | 2 | /24×2 | `elb` | IGW·NAT 호스팅 |
| `app-uniq` | private | 2 | /24×2 | — | NAT 아웃바운드 |

```hcl
module "vpc" {
  source = "../../modules/vpc"          # repo 내부 검증은 상대경로(examples/AGENTS.md)

  naming     = { workload = "acme", env = "dev", region_code = "an2" }
  purpose    = "main"
  cidr_block = "10.0.0.0/16"

  az_count = 2
  subnet_groups = {
    "pub-uniq" = { type = "public", cidrs = ["10.0.0.0/24", "10.0.1.0/24"], eks_role = "elb" }
    "app-uniq" = { type = "private", cidrs = ["10.0.10.0/24", "10.0.11.0/24"] }
  }
  single_nat_gateway = true             # 예제는 비용 최소 구성
}
```

검증 대상: `Name` 태그 포맷 · public→IGW / private→NAT 구조 라우트 · `eks_role` 태그 부착 ·
`vpc_enabled = false`에서 plan 통과(D10) · Flow Logs 리소스 생성(D11).

#### (b) `examples/vpc-enterprise/` — 엔터프라이즈 프리셋

D6~D9의 설계 판단이 **실제로 plan되는지** 증명한다. minimal로는 isolated 라우팅·secondary CIDR
`depends_on`·AZ 커버리지 precondition이 전혀 실행되지 않기 때문에 별도 예제가 필요하다.

**CIDR 3계층** — primary는 소형으로 최소화하고 워크로드는 secondary에 배치:

| CIDR | 성격 | 배치 그룹 |
|------|------|-----------|
| `10.0.0.0/24` (primary) | **uniq 소형** — 인프라 전용 | ep-uniq, tgw-uniq |
| `10.1.0.0/16` (secondary) | **uniq** — 라우팅 가능(온프레미스 도달) | pub, elb, vm, node, db, data |
| `100.64.0.0/16` (secondary) | **dup 허용** — 비라우팅(RFC 6598) | pod-dup |

> primary가 `10.0.0.0/15` 범위 안이면 `10.0.0.0/16` secondary는 연결 불가(§1.2) → uniq secondary는 `10.1.0.0/16`.

**서브넷 그룹** (`az_count = 3`, `az_selection = ["a", "c", "b"]` — 기본 a·c, 3AZ만 b 추가):

| 그룹 키 | type | AZ | 대역 | 크기 | eks_role | 비고 |
|---------|------|----|-----|------|----------|------|
| `pub-uniq` | public | 2 (a·c) | uniq secondary | /24×2 | `elb` | IGW·NAT 호스팅, 인터넷 대면 LB (ALB 최소 2AZ 충족) |
| `elb-uniq` | isolated | 2 (a·c) | uniq secondary | /24×2 | `internal-elb` | 온프레미스 연동 방화벽 오픈 단위 — 온프레미스 경로는 운영 라우트(D3)로 추가 |
| `vm-uniq` | private | 2 (a·c) | uniq secondary | /20×2 | — | VM 워크로드 (NAT 아웃바운드) |
| `node-uniq` | private | 2 (a·c) | uniq secondary | /24×2 | — | **EKS 노드**(D9) — node-SNAT 소스, 방화벽 오픈 단위 |
| `pod-dup` | **isolated** | 2 (a·c) | **dup secondary** | /18×2 | — | **EKS Pod 전용**(D9, ENIConfig) — egress는 node ENI로 SNAT |
| `db-uniq` | isolated | 2 (a·c) | uniq secondary | /26×2 | — | RDS 등 관계형 (Multi-AZ=2), 소형 CIDR |
| `data-uniq` | isolated | **3 (a·c·b)** | uniq secondary | /24×3 | — | **MSK·OpenSearch·Redis** — 3AZ 공식 권장(quorum), ENI 다수 (D8) |
| `ep-uniq` | isolated | 2 (a·c) | primary | /27×2 | — | VPC interface endpoint ENI 전용 — b존 호출은 cross-AZ 폴백 |
| `tgw-uniq` | isolated | **3 (a·c·b)** | primary | /28×3 | — | TGW attachment 전용 — **워크로드 존재 AZ 전체 커버 필수**(D6) |

```hcl
module "vpc" {
  source = "../../modules/vpc"

  naming     = { workload = "acme", env = "dev", region_code = "an2" }
  purpose    = "main"
  cidr_block = "10.0.0.0/24"                              # uniq 소형
  secondary_cidr_blocks = ["10.1.0.0/16", "100.64.0.0/16"]

  az_count     = 3
  az_selection = ["a", "c", "b"]                          # D7

  subnet_groups = {
    "pub-uniq"  = { type = "public", cidrs = local.pub_cidrs, eks_role = "elb" }
    "elb-uniq"  = { type = "isolated", cidrs = local.elb_cidrs, eks_role = "internal-elb" }
    "vm-uniq"   = { type = "private", cidrs = local.vm_cidrs }
    "node-uniq" = { type = "private", cidrs = local.node_cidrs }   # D9
    "pod-dup"   = { type = "isolated", cidrs = local.pod_cidrs }   # D9: Pod 전용
    "db-uniq"   = { type = "isolated", cidrs = local.db_cidrs }
    "data-uniq" = { type = "isolated", cidrs = local.data_cidrs }
    "ep-uniq"   = { type = "isolated", cidrs = local.ep_cidrs }
    "tgw-uniq"  = { type = "isolated", cidrs = local.tgw_cidrs }
  }
  eks_cluster_name   = "eks-acme-dev-an2-main"
  single_nat_gateway = true
}
```

- `local.*_cidrs`는 **예제의 locals**가 `cidrsubnet()`으로 파생한다 — D2에 따라 계산의 소유가 모듈 밖이며,
  소비자가 그대로 복사해 쓸 수 있는 형태를 보여주는 것이 예제의 역할이다.
- `elb-uniq`를 isolated로 둔 이유: 내부 LB ENI는 아웃바운드 개시가 없어 기본 경로가 불필요하다.
  온프레미스 왕복 경로는 TGW 운영 라우트가 추가될 때 생긴다(D3 — 의도된 순서).
- `pod-dup`에 EKS 태그를 붙이지 않은 이유: role 태그는 LB 배치용(elb/public 그룹 소관)이고,
  cluster shared 태그는 EKS 모듈이 서브넷 ID를 명시 전달하므로 필수가 아니다. 필요 시 `extra_tags`로 부착.
- 2AZ 그룹이 모두 a·c에 몰리는 것은 의도된 결과다 — b존은 3AZ 그룹(data/tgw) 전용.

### 1.6 근거 소스

- [VPC CIDR blocks](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-cidr-blocks.html) — secondary CIDR 규칙: /16~/28, RFC1918 교차 연결 제약, **100.64.0.0/10은 모든 primary와 조합 허용**, DX gateway 연결 VPC 간 중첩 금지
- [Managed prefix lists](https://docs.aws.amazon.com/vpc/latest/userguide/managed-prefix-lists.html) — RT/SG에서 집합 참조, 엔트리 갱신 일괄 반영, 버전·롤백, RAM 공유, max_entries 쿼터 소모 규칙 (D3)
- [Transit Gateway design best practices](https://docs.aws.amazon.com/vpc/latest/tgw/tgw-best-design-practices.html) — attachment 전용 서브넷 + `/28` 권장 (G3)
- [TGW VPC attachments](https://docs.aws.amazon.com/vpc/latest/tgw/tgw-vpc-attachments.html) — "attachment 없는 AZ의 리소스는 TGW 도달 불가" (D6 커버리지 근거)
- [EKS Best Practices — Custom Networking](https://docs.aws.amazon.com/eks/latest/best-practices/custom-networking.html) — Pod 대역은 100.64.0.0/10 권장, 노드/ELB는 라우팅 가능 대역 (D9)
- [EKS network requirements](https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html) — 클러스터 최소 2AZ 서브넷 (D6)
- [MSK Best practices](https://docs.aws.amazon.com/msk/latest/developerguide/bestpractices.html) — "Set up a three-AZ cluster" (D6/D8)
- [OpenSearch Multi-AZ](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/managedomains-multiaz.html) — 프로덕션은 Multi-AZ with Standby(3AZ) 권장 (D6/D8)
- [ElastiCache subnet groups](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/SubnetGroups.html) — subnet group 개념, Multi-AZ 2AZ+ (D8)
- [NAT gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html) — private 연결 유형: EIP 불가·인터넷 불가·VPC 내부 개시 연결만 (D9)
- [NAT gateway use cases](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-scenarios.html) — allow-listed range·overlapping networks 시나리오의 라우팅 표 (D9-B안)
- [EKS VPC routable IP conservation (AWS Containers Blog)](https://aws.amazon.com/blogs/containers/eks-vpc-routable-ip-address-conservation/) — 중앙 NAT 패턴 (D9-C안)
- [`aws_flow_log` (provider 문서)](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) — `vpc_id` 지정 시 `traffic_type` 필수, `log_destination_type` 기본 `cloud-watch-logs`, CloudWatch 대상 IAM role 예시 (D11)
- [`aws_cloudwatch_log_group` (provider 문서)](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) — `retention_in_days` 유효값 목록, `kms_key_id` (D11)

---

## 2. 구현 계획 (vpc-v1.0.0)

> ⚠️ **Task 번호는 이 문서 안에서만 유효하다.** 결정 ID(D1–D11)는 PoC 문서와 상호 참조되도록 보존했지만,
> 구현 태스크는 이 repo의 신규 계획이므로 PoC 문서의 동일 번호와 **의미가 다르다**.
>
> 선행: 이 문서 §1 검토·승인. 코드 작성 전 `terraform-style-guide` 스킬 로드(`CLAUDE.md` 검증 절).
> 각 태스크 후 로컬 게이트: `tofu fmt -recursive -check` → `tofu validate` → `tflint --recursive` → `trivy config .`
> (pre-commit hook이 강제한다).

### Task 10.1: 모듈 골격 — `versions.tf` + `variables.tf`
**Files:** `modules/vpc/{versions.tf,variables.tf}`
- `required_version >= 1.12.0`(**D12 동적 `prevent_destroy`가 근거** — `02 §2`),
  `required_providers.aws >= 6.0`(모듈은 하한만)
- §1.2 계약 전체. `validation`: `type`/`eks_role`/`flow_logs_traffic_type` enum,
  `az_selection` 길이, `flow_logs_retention_days` 유효값,
  **`deletion_protection && !vpc_enabled` 조합 거부**(D12)
- Commit: `feat(vpc): 모듈 인터페이스 정의 (설계 §1.2)`

### Task 10.2: 코어 리소스 — `main.tf`
**Files:** `modules/vpc/main.tf`
- `locals.name_mid`(§1.3) + `data.aws_availability_zones`(D7 suffix 해석, **`count`는 D10 게이트**)
- `aws_vpc` — **`lifecycle { prevent_destroy = var.deletion_protection }`**(D12. `aws_vpc`에만 건다)
- `aws_vpc_ipv4_cidr_block_association`(for_each secondary)
- subnet/RT/association을 그룹×AZ `for_each`로 구성 (키: `"<group>-<az suffix>"`)
  → ⚠️ 모든 `aws_subnet`에 `depends_on = [aws_vpc_ipv4_cidr_block_association.this]`(§1.2)
- 라우팅 매트릭스(§1.2): public 공유 RT+IGW / private AZ별 RT+NAT / isolated 공유 RT(경로 없음)
- NAT 배치: 첫 public 그룹, `single_nat_gateway` 분기. D6 precondition 2건
- EKS 태그: D4(`eks_role` 기반) + `kubernetes.io/cluster/<name>=shared`
- Commit: `feat(vpc): subnet_groups·secondary CIDR·isolated 라우팅 구현`

### Task 10.3: Flow Logs — `flow-logs.tf`
**Files:** `modules/vpc/flow-logs.tf`
- §1.1 D11 리소스 4종. 게이트: `vpc_enabled && flow_logs_enabled`
- IAM role trust: `vpc-flow-logs.amazonaws.com`. inline policy 이름은 role 이름 + `-policy`(§1.3)
- 검증: `trivy config .`에 `AVD-AWS-0178`·`AVD-AWS-0017` 모두 없음을 확인
- Commit: `feat(vpc): VPC Flow Logs 옵션 추가 (설계 D11)`

### Task 10.4: 출력 계약 — `outputs.tf`
**Files:** `modules/vpc/outputs.tf`
- §1.4대로. **null-safe**: `vpc_enabled = false`에서 스칼라 null / map·list 빈 값(D10)
- Commit: `feat(vpc): 출력 계약 정의 (설계 §1.4)`

### Task 10.5: 예제 2종
**Files:** `examples/vpc/{main,variables,outputs}.tf` + `README.md`,
`examples/vpc-enterprise/{main,variables,outputs}.tf` + `README.md`
- §1.5(a)/(b). enterprise는 `cidrsubnet()` 파생 locals 포함(D2)
- `outputs.tf`에서 모듈 출력을 실제로 소비해 계약이 동작함을 보인다(`examples/AGENTS.md`)
- 인자 없이 `tofu validate`가 도는 상태로 둔다(`examples/AGENTS.md`)
- 검증: `tofu -chdir=examples/<dir> init -backend=false && validate`
- Commit: `docs(examples): vpc minimal·enterprise 예제 추가`

### Task 10.6: 테스트
**Files:** `modules/vpc/tests/plan.tftest.hcl`
> pre-push hook이 `modules/*/tests` 존재 시 `tofu -chdir=modules/vpc test`를 자동 실행한다.

assertions:
- **`Name` 태그 패턴**(§1.3) — 필수(`modules/AGENTS.md` 릴리스 게이트)
- 그룹×AZ 서브넷 수 = `length(cidrs)` 합
- isolated 그룹 RT에 `0.0.0.0/0` **부재**, public RT에 IGW 경로, private RT에 NAT 경로
- secondary CIDR association 생성 수
- `eks_role` 지정 그룹에만 EKS 태그 부착 / 미지정 그룹엔 미부착(D4)
- **`vpc_enabled = false` → 리소스 0개, plan 통과**(D10) — ⚠️ `deletion_protection` 기본값 `false`에 의존한다
- `deletion_protection = true` + `vpc_enabled = false` → `expect_failures`(D12 validation)
- `flow_logs_enabled = false` → Flow Logs 리소스 0개(D11)
- public 그룹 없이 `enable_nat_gateway = true` → `expect_failures`
- `length(cidrs) > az_count` → `expect_failures`(D6)
- Commit: `test(vpc): 계약(그룹/isolated/secondary/네이밍/kill switch) plan 검증`

**구현 시 확인된 제약 (2026-07-30, OpenTofu 1.12.5 실측)** — 이걸 모르면 테스트를 쓸 수 없다:

| # | 제약 | 대응 |
|---|------|------|
| T1 | **`command = plan`도 data source를 실제 조회한다.** 이 repo는 배포하지 않아 CI에 자격증명이 없으므로 모킹 없이는 plan이 죽는다 | `mock_provider "aws"` + `mock_data "aws_availability_zones"`로 AZ 목록을 고정 주입. 덕분에 **D7의 suffix→AZ 해석까지 검증 대상**이 된다 |
| T2 | **모킹은 computed 속성에 임의 문자열을 채우는데 aws provider가 plan 시점에 ARN 형식을 검증한다** — `aws_flow_log`의 `log_destination`·`iam_role_arn`이 `invalid ARN: arn: invalid prefix`로 실패 | `mock_resource "aws_cloudwatch_log_group"`·`"aws_iam_role"`의 `defaults.arn`에 형식이 맞는 값을 준다. **모듈 결함이 아니다** |
| T3 | 모킹에서 `id`·`arn`은 plan 시점 unknown이다 | assertion은 **설정값**(tags·cidr_block·availability_zone·name)과 **인스턴스 개수·키 집합**만 본다 |
| T4 | **HCL `==`는 타입까지 비교한다** — `output.subnet_ids_by_group`(map of tuple) `== {}`(object)는 둘 다 비어도 실패 | 빈 컬렉션은 `length(...) == 0`으로 검증. 스칼라 `== null`은 정상 동작 |
| T5 | HCL 표현식은 괄호·대괄호 안이 아니면 **줄을 넘길 수 없다**(`&&`로 끝나는 줄은 파싱 오류) | 여러 조건은 `alltrue([...])`로 묶는다 |
| T6 | ⚠️ **`.githooks/pre-push`는 테스트가 0건이어도 "테스트 통과 ✓"를 출력한다** — `tofu test`가 테스트 없이 성공 종료하기 때문 | 이 파일이 생긴 이후로는 실제 검증이 돈다. 신규 모듈에서는 **테스트 파일 부재 자체를 의심**할 것 |

### Task 10.7: 릴리스 게이트 + 태그
- `02 §4` 체크리스트 전 항목 통과 확인
- `.terraform.lock.hcl` 커밋 — ⚠️ registry 주소가 `registry.opentofu.org`인지 확인(`02 §2`)
- `trivy config .` **예외 0건 유지 확인** — 필요 시 D11 판정 재실행
- `docs/README.md` 상태표에서 10번 문서를 ✅로 갱신 (이 개정으로 이미 반영)
- 태그: `vpc-v1.0.0`

---

## 3. 릴리스 기록 — `vpc-v1.0.0` (2026-07-30)

`02 §4` 게이트 실측 결과. **OpenTofu 1.12.5 · aws provider 6.57.1** 기준이다.

| # | 게이트 항목 | 결과 |
|---|------------|------|
| 1 | `tofu fmt -recursive -check` | exit 0 |
| 2 | `modules/vpc`: `validate` + `test` | Success · **12 passed, 0 failed** |
| 3 | `examples/*`: `validate` | `vpc`·`vpc-enterprise` 양쪽 Success |
| 4 | `.terraform.lock.hcl` 커밋 + registry | 3개 루트 전부 `registry.opentofu.org/hashicorp/aws` |
| 5 | `Name` 태그 §1.2 포맷 + 카탈로그 약어 | `naming_contract` run이 11종 검증 |
| 6 | 커뮤니티 모듈 정확 핀 | N/A — 스크래치 모듈이다(`01 §2.2`) |
| 7 | `<component>_enabled` kill switch | `vpc_enabled`(D10) |
| 8 | `tflint --recursive` · `trivy config` | 0건 · 0건 |

**provider 버전을 정렬한 이유**: `tofu test`는 `modules/vpc`를 루트로 실행하므로 그곳 lock이 테스트
버전을 결정한다. 예제만 6.57.1이고 모듈이 6.56.0이면 **"테스트한 버전 ≠ 예제가 검증한 버전"** 상태가
태그에 굳는다. 릴리스 전에 `init -upgrade`로 하나로 맞췄다.

### v1.0.0이 보장하지 **않는** 것 (apply 미검증 항목)

이 릴리스의 증거는 전부 `plan` 수준이다. 아래는 **실계정 apply에서만 드러나며 아직 검증되지 않았다** —
소비 프로젝트의 첫 apply에서 확인해야 한다.

| 항목 | 왜 plan으로 안 잡히나 |
|------|---------------------|
| secondary CIDR `depends_on` 순서 | association이 `associated` 상태가 되는 타이밍은 apply 시점 문제다 |
| primary/secondary CIDR 조합 제약 | AWS API가 apply 시 거부한다(§1.2) |
| CIDR 겹침 | 〃 — `examples/vpc-enterprise`의 파생값은 `tofu console`로 산술만 검증했다 |
| Flow Logs 배달 | IAM 권한이 부족해도 plan은 통과한다. 로그가 실제로 쌓이는지 봐야 한다 |
| `prevent_destroy` 실제 차단 | plan 차단은 실측했으나(D12) apply 후 상태에서의 동작은 미확인 |
| **`git tag` 소싱 경로** | 예제는 상대경로로 소싱한다 — 태그 소싱은 소비 repo에서 처음 돈다 |

---

## 열린 항목

1. **Phase 3 — TGW attachment 리소스**: 서브넷 그룹(`tgw-uniq`)은 v1.0.0이 수용하나
   TGW·attachment 자체는 foundation 소유(`03 §4`)로 범위 밖이다. 운영 라우트는 D3 prefix list 규약 적용.
2. **prefix list 소유권** — 단일 계정에선 생성 주체 미정(온프레미스 연동 시 결정):
   foundation 루트 신설 vs networking 루트 겸임. 멀티어카운트 전환 시엔 네트워크 계정 + RAM 공유가 정답.
3. **IPAM 연계 (G5 확장)**: 그룹 `cidrs`를 IPAM pool 할당으로 대체(멀티어카운트 확산 단계).
   현 계약(명시적 `cidrs`)은 IPAM 도입 시에도 **소비자 루트에서 흡수 가능**하므로 모듈 변경이 없을 것으로 본다 — 확인 필요.
4. **Flow Logs 대상 확장**: S3/Firehose 대상은 D11에서 범위 밖으로 두었다.
   수요 발생 시 `flow_logs_destination_type` 추가 — **계약 확장이므로 마이너**(`02 §3`).
5. **private NAT 옵션**: D9-B 전환 조건이 충족되면 모듈에 옵션 추가. 계약 확장이므로 마이너.
6. ~~**IAM inline policy 약어**~~ ✅ **해소**(2026-07-30): 카탈로그에 **"종속 객체는 부모 이름을 상속한다"**
   규약을 명문화했다 — inline 정책은 약어를 신설하지 않고 `<role 이름>-policy`를 쓴다.
   관리형 정책용 약어 **`iamp`** 는 같은 날 별도 등재했다(독립 자원이므로).
7. **Flow Logs 역할의 confused deputy 방어 (2026-07-30 신설)**: AWS는 신뢰 정책에
   `aws:SourceAccount`·`aws:SourceArn` 조건을 **권고**한다([공식](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-iam-role.html)).
   v1.0.0은 **공식 최소 신뢰 정책만** 구현했다 — 조건을 넣으려면 `data.aws_caller_identity`·
   `data.aws_partition`·`data.aws_region` 3개를 추가(각각 D10 게이트 필요)해야 하고, ARN 조건이
   틀리면 **배달이 조용히 실패**하는데 이 실패는 plan으로 검출되지 않는다. 실계정 apply로 검증할 수
   있는 시점에 도입한다. 계약 변경이 아니므로 **패치/마이너**로 처리 가능.
8. ~~**`aws_flow_log` Name 태그 약어 부재**~~ ✅ **해소**(2026-07-30): 카탈로그에 `fl`을 신규 등재하고
   `Name = fl-<mid>-<purpose>`를 부착했다(§1.3). AWS 실제 리소스 ID 접두사(`fl-`)를 따랐다.
   ⚠️ `cwfm`(CloudWatch Network Flow Monitor)·`brfl`(Bedrock Flows)은 **다른 서비스**라 재사용 불가.
9. **per-AZ NAT의 개수 기준 (2026-07-30 확인)**: §1.2를 문자 그대로 구현해 NAT를 **NAT 호스트 그룹의
   AZ마다** 만든다. 호스트 그룹이 private 그룹보다 넓으면 쓰이지 않는 NAT가 생기고 AZ당 약 $43/월이
   과금된다. 프리셋은 pub 2AZ이므로 현재는 무해하나, "private가 실제로 필요한 AZ만" 기준으로 좁힐지는
   재검토 여지가 있다.
