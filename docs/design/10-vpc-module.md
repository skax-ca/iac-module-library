# 10 · VPC 모듈 (스크래치, EKS-aware)

> **승계(미개정)**: `terraform-enterprise-poc` `docs/design/10-vpc-module.md` @ `76285f7`(동결 커밋)
>
> ⚠️ **이 문서는 아직 정밀 개정되지 않았다.** PoC 전제(Terraform 1.15 + HCP Terraform,
> `workload=poc`, 상대경로 모듈 소싱, TFC 워크스페이스)와 **실증 서술이 그대로 남아 있다.**
>
> - 본문의 실증 날짜·run ID·"실증됨" 서술은 **이 repo에서 재현된 것이 아니다** —
>   정리본은 [`../reference/poc-findings.md`](../reference/poc-findings.md)를 본다.
> - 설계 판단(리소스 구성·경계·트레이드오프)은 대체로 유효하나, **실행 스택 종속부는 무효**다.
>
> **모듈 이식 시점(D-OSS-STACK §6-2)에 재검토하며 개정한다.** 그 전까지 이 문서를
> "이 repo의 확정 설계"로 인용하지 않는다.


> 공통 규약: [02-common-governance.md](../architecture/02-naming-tagging-and-pinning.md) · 결정 근거: [01-strategy-and-decisions.md](../architecture/01-module-strategy.md)

**전략 위치**: 안정·단순·지식밀도 낮음 → **스크래치 얇은 모듈**. 커뮤니티 VPC 모듈 대신 스크래치를 택한 이유는 EKS 서브넷 태깅 로직을 명시적으로 소유하기 위함(커뮤니티 모듈의 EKS 태그 옵션은 복잡).

**개정 이력**
| 버전 | 일자 | 내용 |
|------|------|------|
| v1 | 2026-07-15 | public/private 2계층 + `cidrsubnet()` 파생. 설계·구현 완료(Task 10.1~10.6). 전문은 git 이력(`877f1d9` 이전) 참조 |
| **v2 (현행)** | 2026-07-15 | 엔터프라이즈 확장 — `subnet_groups`·secondary CIDR·구조/운영 라우트 분리. **승인 완료** |

> v1→v2 전환: networking-dev는 **미적용 상태**(plan 후 discard)이므로 state 마이그레이션 없이
> 모듈 코드를 v2 계약으로 교체한다(현재 코드는 v1 — §2 구현 계획으로 개편).

---

## 1. 설계 (v2 — 승인 2026-07-15)

### 1.0 배경 — v1의 간극

엔터프라이즈 네트워크 요구(온프레미스·멀티클라우드 연동, 용도별 대역 관리)와 v1의 간극:

| # | 엔터프라이즈 요구 | v1 현황 | Phase |
|---|------------------|---------|-------|
| G1 | Secondary CIDR — 온프레미스/멀티클라우드 연동 시 unique(RFC1918)/비라우팅(100.64/10, RFC 6598) 대역 분리, CIDR 증설 | `cidr_block` 단일 값 | **1** |
| G2 | 용도별 서브넷 분리 — app(컨테이너/VM)·elb(온프레미스 방화벽 오픈 단위)·db(소형 CIDR)·endpoint 등 | public/private 2계층 하드코딩 | **1** |
| G3 | TGW attachment 전용 `/28` 서브넷 (AWS 공식 모범사례) | 없음 | 3 |
| G4 | 그룹별 라우팅 차등 — NAT/isolated(무 인터넷 경로)/TGW + **운영 중 라우트 추가/변경이 빈번** → prefix list 활용 | private 전체 NAT 단일 경로, 라우트가 모듈에 고정 | **1** |
| G5 | IPAM 연계·명시적 CIDR 할당 | `cidrsubnet()` 규칙 파생만 | 1(명시적 입력) / 3(IPAM) |

### 1.1 설계 결정

**D1. 서브넷 계층을 `subnet_groups` map으로 일반화 (G2)**
public/private 하드코딩을 폐기하고, 용도별 그룹의 map을 입력 계약으로 승격한다.
그룹의 `type`(public/private/isolated)이 라우팅 동작을 결정한다.

**D2. CIDR는 명시적 입력으로 격상 (G5)**
엔터프라이즈에서 대역은 IPAM/네트워크 팀이 할당하고 Terraform은 이를 기록하는 쪽이다.
모듈 계약은 그룹별 명시적 `cidrs` 리스트로 단순화하고, v1의 `cidrsubnet()` 파생 로직은
**live 루트 locals로 이동**한다(dev 편의 유지 — 계산의 소유가 모듈→루트로 이동할 뿐 폐기 아님).
그룹 간 중첩은 AWS API가 subnet 생성 시 거부하므로 모듈 내 중복 검증은 두지 않는다
(입력 형식 검증만 `validation` 블록으로).

**D3. 구조 라우트 / 운영 라우트 분리 (G4) — 핵심 결정. prefix list는 권장 옵션**
운영에서 라우트 추가/변경이 빈번하다는 현실을 모듈 경계 설계에 반영한다.

| 구분 | 정의 | 소유 | 변경 빈도 |
|------|------|------|-----------|
| **구조 라우트** | 토폴로지가 결정: public→IGW, private→NAT, isolated→local only | **모듈** | 낮음 (토폴로지 변경 시만) |
| **운영 라우트** | 연동이 결정: 온프레미스 대역→TGW/VGW, 타 VPC, 검사 어플라이언스 등 | **live 루트/foundation** | 높음 |

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
- **근거**: ① 라우트 churn이 모듈 인터페이스 churn이 되면 모듈 버전 승격 체계
  ([03-multi-environment](../consumer/multi-environment.md))와 충돌 — 대역 추가마다 모듈
  릴리스가 필요해진다. ② prefix list는 공유 리소스이므로 foundation 소유 + 네이밍 기반
  data source 조회가 [04-dependencies](../architecture/03-dependencies.md) 원칙과
  일치(멀티어카운트 확장 시 네트워크 계정에서 RAM 공유). ③ SG rule(`prefix_list_id`)에도 동일
  prefix list를 참조해 방화벽 정책과 라우팅의 대역 SSOT를 하나로 유지.
- **prefix list 공식 제약** (설계에 영향): region 단위 리소스 · `max_entries`는 생성 시 지정
  (버전 관리·롤백 지원) · **참조하는 리소스의 쿼터를 max_entries만큼 소모**
  (RT 라우트 쿼터 기본 50, SG rule 쿼터 60) → max_entries는 여유분 포함 신중히 산정.
- 약어: `pl` (카탈로그 등재 확인 — "VPC | 관리형 접두사 목록").

운영 라우트 확장 규약 (live 루트 예시 — Phase 1에선 규약만, 온프레미스 연동 시 적용):
```hcl
data "aws_ec2_managed_prefix_list" "onprem" {
  name = "pl-poc-dev-an2-onprem" # foundation 소유, 네이밍 조회(04 원칙)
}
resource "aws_route" "app_to_onprem" {
  count                      = length(module.vpc.route_table_ids_by_group["app"])
  route_table_id             = module.vpc.route_table_ids_by_group["app"][count.index]
  destination_prefix_list_id = data.aws_ec2_managed_prefix_list.onprem.id
  transit_gateway_id         = data.aws_ec2_transit_gateway.this.id # Phase 3
}
```

**D4. EKS 태그의 그룹별 이관**
v1은 public 전체에 `role/elb`, private 전체에 `role/internal-elb`를 일괄 부착했다.
v2는 그룹별 `eks_role` 필드(`"elb"` / `"internal-elb"` / null)로 명시한다 —
온프레미스 방화벽 오픈 대역(elb 그룹)과 EKS 노드 대역(app 그룹)의 분리 목적과 일치.
`kubernetes.io/cluster/<name>=shared` 태그는 `eks_role`이 지정된 그룹에만 부착.

**D5. 출력 계약을 그룹 map으로 전환**
v1의 `private_subnet_ids`/`public_subnet_ids` 리스트 출력을 **제거**하고 map으로 대체한다.
하류(eks-cluster) 미구현 + networking-dev 미적용이므로 파괴 변경 비용이 없는 마지막 시점.

**D6. 그룹별 AZ 차등 — AZ 수 = `length(cidrs)` 파생 (2026-07-16 추가)**
3AZ가 필요한 quorum 계열(MSK·OpenSearch — 공식 3AZ 권장)만 3AZ로, 나머지는 2AZ로
줄여 IP·비용을 절감한다. 별도 필드 없이 **그룹의 `cidrs` 리스트 길이가 곧 그 그룹의 AZ 수**다
(잘못된 상태를 표현할 수 없는 인터페이스). `az_count`는 "최대 AZ 슬라이스"로 재정의.
- precondition: `2 <= length(cidrs) <= az_count` (전 그룹)
- **AZ 커버리지 제약 2건**: ① `tgw` 그룹은 워크로드가 존재하는 모든 AZ를 커버해야 한다
  (공식: "attachment 없는 AZ의 리소스는 TGW 도달 불가") → 최대 AZ 그룹과 동일 폭.
  ② per-AZ NAT 모드(`single_nat_gateway=false`)에서는 NAT 호스트(public) 그룹의 AZ 수 ≥
  private 그룹 최대 AZ 수 (precondition으로 강제).
- EKS는 최소 2AZ(공식) — 컨트롤플레인 HA는 AWS 관리이므로 dev 노드 2AZ로 충분.
  in-cluster quorum 워크로드를 돌리게 되면 3AZ 재평가.

**D7. AZ 선택 우선순위 — `az_selection` (2026-07-16 추가)**
기본 AZ를 a·c로 하고 3AZ 그룹만 b를 추가로 쓴다(사용자 결정 — 서울 리전 관례).
모듈에 `az_selection`(suffix 우선순위 리스트, 예: `["a", "c", "b"]`)을 추가:
그룹은 이 목록의 **앞에서부터 `length(cidrs)`개** AZ에 배치된다.
null이면 기존처럼 리전 AZ 목록의 앞 `az_count`개(하위 호환). suffix→AZ 이름 해석은
data source 기반이므로 리전 이식성 유지.

**D8. 데이터 서비스 전용 `data` 그룹 (2026-07-16 추가)**
MSK·OpenSearch·Redis는 `db`(관계형)와 분리한 **`data` 그룹(isolated, 3AZ)**에 배치한다.
- 분리 근거: ① AZ 수 요구가 다름(RDS 2 vs MSK/OS 3 — 통합 시 db까지 3AZ 강제)
  ② IP 소모 프로파일(db는 소수 고정 ENI, data는 브로커/노드/캐시노드 다수·스케일아웃 가변)
  ③ 온프레미스 방화벽 오픈 대역 단위 분리(Kafka 9092-9098 등).
  라우팅은 db와 동일(isolated)이므로 라우팅 근거가 아님.
- per-service 분리(msk/es/redis 각각)는 비권장 — 서비스 간 격리는 SG가 주 방어선(04 원칙),
  AWS도 subnet group(서브넷 목록) 개념으로 공유 서브넷을 상정.

**D9. dup 대역(100.64/16)의 온프레미스 통신 — custom networking 채택, private NAT는 전환 조건 명시 (2026-07-16 승인)**

배경: VPC 배포 후 EKS 설계 검토 중 확인 — `app-container`(노드+Pod)가 dup 대역이라
온프레미스로 라우팅되지 않는다. 해법 3안을 비교·검토했다:

| | **A. custom networking (채택)** | B. private NAT gateway | C. 중앙 NAT VPC |
|---|---|---|---|
| 구조 | **노드는 uniq(`node` 그룹 신설), Pod만 dup**(`app-container`를 Pod 전용으로 재정의, ENIConfig) | 노드·Pod 모두 dup 유지 + uniq 대역에 private NAT | Shared Services VPC에 NAT 집중 |
| Pod→온프레미스 | VPC CNI 기본 SNAT(`AWS_VPC_K8S_CNI_EXTERNALSNAT=false`)가 노드의 uniq IP로 변환 | private NAT IP로 변환 (dup RT: 온프레미스 대역→NAT, NAT 서브넷 RT: →TGW) | 중앙 NAT에서 변환 (Pod IP를 TGW 너머까지 유지 — EXTERNALSNAT=true 필요) |
| 온프레미스→Pod | 3안 공통: `elb` 그룹 내부 LB 경유 (NAT는 "VPC 내부 개시 연결만" — egress 전용, 공식 제약) | 〃 | 〃 |
| 추가 고정비 | **$0** | +$43/월/AZ + $0.059/GB | VPC+NAT+TGW 비용 |
| 방화벽 오픈 단위 | 노드 서브넷 CIDR | private NAT IP (소수 고정 IP — allow-list 요구가 엄격하면 유리) | 중앙 NAT 대역 |
| 운영 | ENIConfig(AZ별)·max-pods 감소(prefix delegation으로 완화) | EKS 무변경(가장 단순) | 멀티클러스터급 복잡도 |

**A 채택 근거**: ① EKS 공식 모범사례가 온프레미스 연결의 권장 패턴으로 기술 ② 추가 고정비 0
③ 클러스터 생성 전(현시점)이라 무비용 적용 — 생성 후 전환은 전 노드 drain(파괴적)
④ 방화벽 오픈이 노드 서브넷 대역 단위로 명확.

**B로 전환하는 조건** (이때 모듈에 private NAT 옵션 추가 — 라우트는 D3 운영 라우트 규약대로 prefix list→NAT):
① 노드 수 폭증으로 노드 IP조차 uniq에 못 둘 때 ② **EKS 외 워크로드(VM 등)를 dup 대역에 배치할 때**
(node-SNAT는 VPC CNI 기능이라 EKS에만 적용 — 이 경우 B 외 대안 없음) ③ 온프레미스가 소수 고정 IP allow-list를 요구할 때.

**C로 전환하는 조건**: 멀티클러스터·멀티계정 확산 단계에서 dup 대역을 온프레미스에 광고하지 않으면서
계정 간 NAT를 집중할 때 (Phase 3+, AWS Containers 블로그 패턴).

**설계 반영**: `node` 그룹 신설(uniq /24×2, private — node-SNAT의 소스이자 NAT 아웃바운드 경로),
`app-container`는 Pod 전용·**isolated로 변경** — Pod의 VPC 외부 egress는 노드 primary ENI로
SNAT되어 node 그룹 RT를 타므로 Pod 서브넷엔 기본 경로가 불필요하다.
⚠️ 단 C안 전환(EXTERNALSNAT=true) 시엔 Pod 서브넷 RT에 경로가 필요해지므로 재설계 대상.

### 1.2 인터페이스 (variables)

```hcl
variable "naming"  { type = object({ workload = string, env = string, region_code = string }) }
variable "purpose" { type = string  default = "main" }

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

variable "enable_nat_gateway" { type = bool  default = true }   # private 그룹에만 적용
variable "single_nat_gateway" { type = bool  default = false }
variable "eks_cluster_name"   { type = string  default = null }
variable "tags"               { type = map(string)  default = {} }
```

라우팅·리소스 매트릭스 (`type`이 결정 — D1/D3):

| type | 0.0.0.0/0 경로 | RT 구성 | 용도 예시 |
|------|---------------|---------|-----------|
| `public` | IGW | 그룹당 1개 공유 | elb, nat 호스팅 |
| `private` | NAT (`single_nat_gateway` 분기 유지) | **AZ별** (NAT 경로 분기) | app, pod |
| `isolated` | 없음 (local 라우트만 — secondary 연결 시 자동 추가됨) | 그룹당 1개 공유 | db, endpoint, tgw |

- NAT Gateway는 `type == "public"`인 **첫 번째 그룹**(map 키 정렬 기준)의 서브넷에 배치한다.
  public 그룹이 없으면 `enable_nat_gateway = true`는 검증 오류.
- per-AZ NAT(`single_nat_gateway = false`) 시 NAT 호스트 그룹의 AZ 수가 private 그룹
  최대 AZ 수 이상이어야 한다(D6 precondition) — 아니면 커버되지 않는 AZ의 NAT 경로가 없다.
- **secondary CIDR 함정**: 서브넷 CIDR가 secondary 대역이면
  `aws_vpc_ipv4_cidr_block_association`이 먼저 `associated` 상태여야 하는데 Terraform이
  참조 관계로 추론하지 못한다 → `aws_subnet`에 `depends_on = [aws_vpc_ipv4_cidr_block_association.this]` 필수.

### 1.3 네이밍 (카탈로그 A.2 정합)

그룹 키가 Name의 purpose 토큰이 된다. 카탈로그 예시(`snet-poc-prd-an2-pub-dup1-a`,
`ngw-poc-prd-an2-pub-uniq1-a`)에 따라 **그룹 키는 `<용도 축약>-<uniq|dup>` 형식**을 표준으로
한다(2026-07-16 확정) — 이름만으로 용도와 온프레미스 라우팅 가능 여부를 판별할 수 있게 한다.
serial은 동일 용도·대역 조합이 복수일 때만 붙인다(§1.4b — 단일이면 생략).
NAT Gateway Name에는 호스트 그룹 토큰을 포함한다(`ngw-<mid>-<nat그룹>-<az>` — 카탈로그 예시 정합).

| 리소스 | 약어 | Name 패턴 | 예시 |
|--------|------|-----------|------|
| `aws_vpc` | `vpc` | `vpc-<mid>-<purpose>` | vpc-poc-dev-an2-main |
| `aws_subnet` | `snet` | `snet-<mid>-<group>-<az>` | snet-poc-dev-an2-pod-dup-a |
| `aws_route_table` (private) | `rtb` | `rtb-<mid>-<group>-<az>` | rtb-poc-dev-an2-node-uniq-a |
| `aws_route_table` (public/isolated) | `rtb` | `rtb-<mid>-<group>` | rtb-poc-dev-an2-db-uniq |
| `aws_internet_gateway` | `igw` | `igw-<mid>-<purpose>` | igw-poc-dev-an2-main |
| `aws_nat_gateway` | `ngw` | `ngw-<mid>-<nat그룹>-<az>` | ngw-poc-dev-an2-pub-uniq-a |
| `aws_eip` (NAT) | `eip` | `eip-<mid>-nat-<az>` | eip-poc-dev-an2-nat-a |

### 1.4 출력 (outputs) — downstream(eks-cluster)이 tfe_outputs로 소비

```hcl
output "vpc_id"                   {}
output "vpc_cidr_block"           {}                 # primary
output "secondary_cidr_blocks"    {}                 # 연결 완료된 secondary 목록
output "subnet_ids_by_group"      {}                 # map(list(string)) — AZ 순서
output "route_table_ids_by_group" {}                 # map(list(string)) — 운영 라우트 앵커(D3)
output "nat_gateway_ids"          {}
```
⚠️ rename/삭제는 인터페이스 변경 — 하류 워크스페이스 영향 확인 후 진행.

### 1.5 live/dev/networking — dev 프리셋 (개정 2026-07-16: 엔터프라이즈 7그룹)

> 초기 프리셋은 2그룹(elb/app)이었으나, 엔터프라이즈 표준 패턴 시연을 위해
> **소형 primary + 다중 secondary + 용도별 7그룹**으로 개정(사용자 결정).

**CIDR 3계층 구성** — primary는 소형으로 최소화하고 워크로드는 secondary에 배치:

| CIDR | 성격 | 배치 그룹 |
|------|------|-----------|
| `vpc_cidr` = 10.0.0.0/24 (primary) | **uniq 소형** — 인프라 전용 | endpoint, tgw |
| `vpc_cidr_uniq` = 10.1.0.0/16 (secondary) | **uniq** — 라우팅 가능(온프레미스 도달) | public, elb, app-vm, db |
| `vpc_cidr_dup` = 100.64.0.0/16 (secondary) | **dup 허용** — 비라우팅(RFC 6598) | app-container |

⚠️ **연결 제약**: primary가 10.0.0.0/15 범위 안이면 10.0.0.0/16 대역의 secondary는 연결 불가
(공식 제약표) → uniq secondary는 10.1.0.0/16 선택. 이 제약은 plan이 아닌 **apply 시 API가 검출**한다.

**서브넷 그룹 프리셋** (az_count = 3, `az_selection = ["a", "c", "b"]` — 기본 a·c, 3AZ만 b 추가.
파생은 루트 locals 소유 — D2. AZ 차등 근거는 D6/D8):

| 그룹 키 (= Name 토큰, §1.3) | type | AZ | 대역(출처) | 크기 | eks_role | 비고 |
|------|------|----|-----------|------|----------|------|
| `pub-uniq` | public | 2 (a·c) | uniq secondary | /24×2 | `elb` | IGW·NAT 호스팅, 인터넷 대면 LB (ALB 최소 2AZ 충족) |
| `elb-uniq` | isolated | 2 (a·c) | uniq secondary | /24×2 | `internal-elb` | 온프레미스 연동 방화벽 오픈 단위 — 기본 경로 불필요, 온프레미스 경로는 운영 라우트(D3)로 추가 |
| `vm-uniq` | private | 2 (a·c) | uniq secondary | /20×2 | — | VM 워크로드 (NAT 아웃바운드) |
| `node-uniq` | private | 2 (a·c) | uniq secondary | /24×2 | — | **EKS 노드**(D9) — node-SNAT 소스, 온프레미스 방화벽 오픈 단위 |
| `pod-dup` | **isolated** | 2 (a·c) | **dup secondary** | /18×2 | — | **EKS Pod 전용**(D9, ENIConfig) — egress는 node ENI로 SNAT되므로 기본 경로 불필요 |
| `db-uniq` | isolated | 2 (a·c) | uniq secondary | /26×2 | — | RDS 등 관계형 (Multi-AZ=2), 소형 CIDR |
| `data-uniq` | isolated | **3 (a·c·b)** | uniq secondary | /24×3 | — | **MSK·OpenSearch·Redis** — 3AZ 공식 권장(quorum), ENI 다수 소모 대비 /24 (D8) |
| `ep-uniq` | isolated | 2 (a·c) | primary | /27×2 | — | VPC interface endpoint ENI 전용 — b존 호출은 cross-AZ 폴백(비용 절감 우세) |
| `tgw-uniq` | isolated | **3 (a·c·b)** | primary | /28×3 | — | TGW attachment 전용 — **워크로드 존재 AZ 전체 커버 필수**(공식 제약, D6) |

> 그룹 키 개정(2026-07-16): 초기 키(public/elb/app-vm/node/app-container/db/data/endpoint/tgw)를
> §1.3 표준(`<용도 축약>-<uniq|dup>`)으로 일괄 개정. 키 변경은 for_each 주소 변경이라 서브넷
> 재생성을 동반하나, 워크로드 미배치 상태(EKS 착수 전)라 무비용 — 이후에는 키가 하류 소비
> 계약(`subnet_ids_by_group` 키)이므로 변경 금지.

```hcl
module "vpc" {
  source  = "../../../modules/vpc"
  naming  = { workload = var.workload, env = var.env, region_code = var.region_code }
  purpose = "main"

  cidr_block            = var.vpc_cidr                          # 10.0.0.0/24 (uniq 소형)
  secondary_cidr_blocks = [var.vpc_cidr_uniq, var.vpc_cidr_dup] # 10.1.0.0/16 + 100.64.0.0/16

  az_count     = 3
  az_selection = ["a", "c", "b"] # 기본 a·c, 3AZ 그룹만 b 추가 (D7)

  subnet_groups = {
    "pub-uniq"  = { type = "public", cidrs = local.pub_cidrs, eks_role = "elb" }
    "elb-uniq"  = { type = "isolated", cidrs = local.elb_cidrs, eks_role = "internal-elb" }
    "vm-uniq"   = { type = "private", cidrs = local.vm_cidrs }
    "node-uniq" = { type = "private", cidrs = local.node_cidrs }  # D9
    "pod-dup"   = { type = "isolated", cidrs = local.pod_cidrs }  # D9: Pod 전용
    "db-uniq"   = { type = "isolated", cidrs = local.db_cidrs }
    "data-uniq" = { type = "isolated", cidrs = local.data_cidrs }
    "ep-uniq"   = { type = "isolated", cidrs = local.ep_cidrs }
    "tgw-uniq"  = { type = "isolated", cidrs = local.tgw_cidrs }
  }
  eks_cluster_name   = var.eks_cluster_name
  single_nat_gateway = true # dev 축소 구성 유지
}
```

- `elb`를 isolated로 둔 이유: 내부 LB ENI는 아웃바운드 개시가 없어 기본 경로가 불필요하다.
  온프레미스 왕복 경로는 TGW 운영 라우트가 elb RT에 추가될 때 생긴다(D3 — 의도된 순서).
- `app-container`에 EKS 태그를 붙이지 않은 이유: role 태그는 LB 배치용(elb/public 그룹 소관)이고,
  cluster shared 태그는 EKS 모듈이 서브넷 ID를 명시 전달하므로 필수가 아니다. 필요 시 `extra_tags`로 부착.
- 2AZ 그룹이 모두 a·c에 몰리는 것은 의도된 결과다 — b존은 3AZ 그룹(data/tgw) 전용.

### 1.6 근거 소스

- [VPC CIDR blocks](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-cidr-blocks.html) — secondary CIDR 규칙: /16~/28, RFC1918 교차 연결 제약, **100.64.0.0/10은 모든 primary와 조합 허용**, DX gateway 연결 VPC 간 중첩 금지
- [Managed prefix lists](https://docs.aws.amazon.com/vpc/latest/userguide/managed-prefix-lists.html) — RT/SG에서 집합 참조, 엔트리 갱신 일괄 반영, 버전·롤백, RAM 공유, max_entries 쿼터 소모 규칙
- [Transit Gateway design best practices](https://docs.aws.amazon.com/vpc/latest/tgw/tgw-best-design-practices.html) — attachment 전용 서브넷 + `/28` 권장 (Phase 3 근거)
- [EKS Best Practices — Custom Networking](https://docs.aws.amazon.com/eks/latest/best-practices/custom-networking.html) — Pod 대역은 100.64.0.0/10 권장, 노드/ELB는 라우팅 가능 대역 (Phase 2 근거)
- [EKS network requirements](https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html) — 클러스터 최소 2AZ 서브넷 (D6 근거)
- [MSK Best practices](https://docs.aws.amazon.com/msk/latest/developerguide/bestpractices.html) — "Set up a three-AZ cluster" (D6/D8 근거)
- [OpenSearch Multi-AZ](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/managedomains-multiaz.html) — 프로덕션은 Multi-AZ with Standby(3AZ) 권장 (D6/D8 근거)
- [TGW VPC attachments](https://docs.aws.amazon.com/vpc/latest/tgw/tgw-vpc-attachments.html) — "attachment 없는 AZ의 리소스는 TGW 도달 불가" (D6 tgw 커버리지 근거)
- [ElastiCache subnet groups](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/SubnetGroups.html) — subnet group 개념, Multi-AZ 2AZ+ (D8 근거)
- [NAT gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html) — private 연결 유형: EIP 불가·인터넷 불가·VPC 내부 개시 연결만 (D9 근거)
- [NAT gateway use cases](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-scenarios.html) — allow-listed range·overlapping networks 시나리오의 라우팅 표 (D9-B안 근거)
- [EKS VPC routable IP conservation (AWS Containers Blog)](https://aws.amazon.com/blogs/containers/eks-vpc-routable-ip-address-conservation/) — 중앙 NAT 패턴 (D9-C안 근거)

---

## 2. 구현 계획 (v2)

> REQUIRED SUB-SKILL: superpowers:executing-plans
> 선행: §1 설계 승인 완료(2026-07-15). networking-dev 미적용 상태 확인(state 마이그레이션 불필요).
> v1 구현 계획(Task 10.1~10.6)은 완료 — git 이력(`877f1d9` 이전) 참조.

### Task 10.7: variables v2
**Files:** `modules/vpc/variables.tf`
- §1.2 계약으로 교체. `validation`: `type`/`eks_role` enum. `az_count`↔`length(cidrs)` 일치는 main.tf precondition.
- Commit: `feat(vpc)!: subnet_groups 계약으로 인터페이스 개편 (v2 설계 §1.2)`

### Task 10.8: main.tf 개편
**Files:** `modules/vpc/main.tf`
- `aws_vpc_ipv4_cidr_block_association` (for_each secondary) + 모든 `aws_subnet`에 `depends_on`
- subnet/RT/association을 그룹×AZ `for_each`로 재구성 (키: `"<group>-<az suffix>"`)
- 라우팅 매트릭스(§1.2) 구현: public 공유 RT / private AZ별 RT+NAT / isolated 공유 RT(경로 없음)
- NAT 배치: 첫 public 그룹, `single_nat_gateway` 분기 유지
- EKS 태그: D4 (`eks_role` 기반)
- 검증: fmt → validate → tflint → trivy
- Commit: `feat(vpc): subnet_groups·secondary CIDR·isolated 라우팅 구현`

### Task 10.9: outputs v2
**Files:** `modules/vpc/outputs.tf` — §1.4로 교체 (v1 리스트 출력 제거, D5)
- Commit: `feat(vpc)!: 출력 계약을 그룹 map으로 전환`

### Task 10.10: 테스트 갱신
**Files:** `modules/vpc/tests/plan.tftest.hcl`
- assertions: 그룹×AZ 서브넷 수 / isolated 그룹 RT에 0.0.0.0/0 부재 / secondary CIDR association /
  `eks_role` 태그 부착·미부착 / Name 패턴(§1.3) / public 그룹 부재 + NAT 요청 시 실패(expect_failures)
- Run: `terraform -chdir=modules/vpc test`
- Commit: `test(vpc): v2 계약(그룹/isolated/secondary/네이밍) plan 검증`

### Task 10.11: live/dev/networking v2
**Files:** `live/dev/networking/{main,outputs}.tf` — §1.5 프리셋 적용, outputs 재노출 갱신
- 검증: validate + TFC plan(리소스 수·Name 확인 후 apply는 사용자 승인)
- Commit: `feat(live): networking-dev를 v2 subnet_groups 계약으로 전환`

---

## 열린 항목
1. **VPC Flow Logs** — trivy `AVD-AWS-0178`(MEDIUM) 검출(2026-07-15). PoC 단계 의도적 보류(`.trivyignore` 등재).
   운영(prd) 전환 전 재평가: `aws_flow_log` + CloudWatch Logs/S3 대상 + IAM role을 모듈 옵션(`enable_flow_logs`)으로 설계.
2. **Phase 2 — Pod 전용 비라우팅 대역** (EKS 모듈 착수 시 결정): `pod` 그룹을
   secondary CIDR `100.64.0.0/16`(RFC 6598)에 배치 + EKS custom networking(`ENIConfig`) 연계 여부.
   v2 계약(`secondary_cidr_blocks` + `subnet_groups`)으로 모듈 변경 없이 수용 가능.
3. **Phase 3 — TGW attachment 전용 그룹**: `tgw = { type = "isolated", cidrs = [/28 × AZ] }` +
   TGW/attachment는 foundation 소유(04 원칙). 운영 라우트는 §1.1 D3 prefix list 규약 적용.
4. **Phase 3 — IPAM 연계**: 그룹 `cidrs`를 IPAM pool 할당으로 대체(멀티어카운트 확산 단계).
5. **prefix list 소유권** — PoC 단일 계정에선 생성 주체 미정(온프레미스 연동 시 결정):
   foundation 워크스페이스 신설 vs networking 루트 겸임. 멀티어카운트 전환 시엔 네트워크 계정 + RAM 공유가 정답.
