# examples/vpc-enterprise — 엔터프라이즈 프리셋

설계 D6~D9의 판단을 **그대로 옮긴 9그룹 구성**이다. `examples/vpc`(minimal)가 계약의 형태를 보인다면,
이 예제는 **고객사 착수 템플릿**이다 — 온프레미스 연동, 용도별 대역 분리, EKS custom networking,
TGW attachment 전용 서브넷까지 들어 있다.

> ⚠️ **역할이 재정의됐다**(2026-07-30). 설계 §1.5(b)가 처음 이 예제를 요구한 근거는 "minimal로는
> isolated 라우팅·secondary CIDR·AZ 커버리지 precondition이 실행되지 않는다"였다. 그 검증은 이제
> `modules/vpc/tests/plan.tftest.hcl`이 담당한다. 따라서 이 예제의 존재 이유는 **검증이 아니라
> 착수 템플릿**이고, 그래서 프로덕션 구성을 흉내 내는 것이 허용된다
> (`examples/AGENTS.md`의 "최소로 유지" 원칙에 대한 **의도된 예외**다).

## CIDR 3계층

primary를 소형으로 최소화하고 워크로드는 secondary에 배치한다.

| CIDR | 성격 | 배치 그룹 |
|------|------|-----------|
| `10.0.0.0/24` (primary) | uniq 소형 — 인프라 전용 | `ep-uniq` · `tgw-uniq` |
| `10.1.0.0/16` (secondary) | uniq — 라우팅 가능(온프레미스 도달) | `pub` · `elb` · `vm` · `node` · `db` · `data` |
| `100.64.0.0/16` (secondary) | dup 허용 — 비라우팅(RFC 6598) | `pod-dup` |

> primary가 `10.0.0.0/15` 범위 안이면 `10.0.0.0/16` 대역 secondary는 연결 불가하므로 uniq는 `10.1.0.0/16`이다.

## 서브넷 그룹 (`az_count = 3`, `az_selection = ["a", "c", "b"]`)

| 그룹 키 | type | AZ | 크기 | eks_role | 비고 |
|---------|------|----|------|----------|------|
| `pub-uniq` | public | 2 (a·c) | /24×2 | `elb` | IGW·NAT 호스팅, 인터넷 대면 LB |
| `elb-uniq` | isolated | 2 (a·c) | /24×2 | `internal-elb` | 온프레미스 방화벽 오픈 단위 |
| `vm-uniq` | private | 2 (a·c) | /20×2 | — | VM 워크로드 |
| `node-uniq` | private | 2 (a·c) | /24×2 | — | **EKS 노드**(D9) — node-SNAT 소스 |
| `pod-dup` | isolated | 2 (a·c) | /18×2 | — | **EKS Pod 전용**(D9, ENIConfig) |
| `db-uniq` | isolated | 2 (a·c) | /26×2 | — | RDS 등 관계형 |
| `data-uniq` | isolated | **3 (a·c·b)** | /24×3 | — | MSK·OpenSearch·Redis (3AZ quorum, D8) |
| `ep-uniq` | isolated | 2 (a·c) | /27×2 | — | VPC interface endpoint ENI |
| `tgw-uniq` | isolated | **3 (a·c·b)** | /28×3 | — | TGW attachment 전용(D6 커버리지) |

- 2AZ 그룹이 모두 a·c에 몰리는 것은 **의도된 결과**다 — b존은 3AZ 그룹(`data`·`tgw`) 전용이다.
- CIDR는 전부 `cidrsubnet()` 파생이다(`main.tf`의 locals). 계산의 소유가 **모듈이 아니라 소비자**이므로
  (D2) 소비 프로젝트는 이 locals를 복사해 자기 대역에 맞게 고친다.

## 이 구성이 만들지 **않는** 것

| 없는 것 | 왜 | 어디 소관 |
|---------|-----|-----------|
| TGW·attachment | 공유 리소스 | foundation(`03 §4`) — 서브넷 그룹만 수용한다 |
| 온프레미스 대역 라우트 | 운영 라우트는 churn이 크다 | 소비 프로젝트가 `outputs.tf`의 앵커에 `aws_route`로 얹는다(D3) |
| prefix list | 공유 리소스 | foundation — 네이밍으로 data source 조회 |
| KMS 키 | 보안 거버넌스 대상 | foundation. `flow_logs_kms_key_id`로 ARN 주입 |

## 실행

```bash
tofu -chdir=examples/vpc-enterprise init -backend=false
tofu -chdir=examples/vpc-enterprise validate
```

> ⚠️ `validate`는 계약 위반을 잡지 못한다(`plan`에서만 평가된다). 계약 검증은
> `tofu -chdir=modules/vpc test`가 담당한다.
> 그리고 **CIDR 겹침과 primary/secondary 조합 제약은 apply 시 AWS API가 검출**하므로
> 이 예제로도 검증되지 않는다 — 실계정 apply까지 남은 미검증 리스크다.
