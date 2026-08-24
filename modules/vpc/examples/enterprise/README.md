# modules/vpc/examples/enterprise — 엔터프라이즈 프리셋

서브넷 그룹 설계를 **그대로 옮긴 9그룹 구성**이다. 최소 예제가 계약의 형태를 보인다면,
이 예제는 **고객사 착수 템플릿**이다 — 온프레미스 연동, 용도별 대역 분리, EKS custom networking,
TGW attachment 전용 서브넷까지 들어 있다.

> ⚠️ **이 예제의 존재 이유는 검증이 아니라 착수 템플릿이다.** isolated 라우팅·secondary CIDR·
> AZ 커버리지 precondition 검증은 `modules/vpc/tests/plan.tftest.hcl`이 담당한다. 이 예제는
> 프로덕션 구성을 흉내 내는 것이 허용된 자리이고
> ("최소로 유지" 원칙에 대한 **의도된 예외**다).

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
| `node-uniq` | private | 2 (a·c) | /24×2 | — | **EKS 노드** — node-SNAT 소스 |
| `pod-dup` | isolated | 2 (a·c) | /18×2 | — | **EKS Pod 전용** |
| `db-uniq` | isolated | 2 (a·c) | /26×2 | — | RDS 등 관계형 |
| `data-uniq` | isolated | **3 (a·c·b)** | /24×3 | — | MSK·OpenSearch·Redis (3AZ quorum) |
| `ep-uniq` | isolated | 2 (a·c) | /27×2 | — | VPC interface endpoint ENI |
| `tgw-uniq` | isolated | **3 (a·c·b)** | /28×3 | — | TGW attachment 전용 |

- 2AZ 그룹이 모두 a·c에 몰리는 것은 **의도된 결과**다 — b존은 3AZ 그룹(`data`·`tgw`) 전용이다.
- CIDR는 전부 `cidrsubnet()` 파생이다(`main.tf`의 locals). 계산의 소유가 **모듈이 아니라 소비자**이므로
   소비 프로젝트는 이 locals를 복사해 자기 대역에 맞게 고친다.

## 이 구성이 만들지 **않는** 것

| 없는 것 | 왜 | 어디 소관 |
|---------|-----|-----------|
| TGW·attachment | 공유 리소스 | foundation — 서브넷 그룹만 수용한다 |
| 온프레미스 대역 라우트 | 운영 라우트는 churn이 크다 | 소비 프로젝트가 `outputs.tf`의 앵커에 `aws_route`로 얹는다 |
| prefix list | 공유 리소스 | foundation — 네이밍으로 data source 조회 |
| KMS 키 | 보안 거버넌스 대상 | foundation. `flow_logs_kms_key_id`로 ARN 주입 |

## 소비 프로젝트와 다른 점

| | 이 예제 | 소비 프로젝트(`<project>-infra`) |
|---|---|---|
| 소싱 | 상대경로 `../../modules/vpc` | git tag `?ref=vpc-v0.3.0` (**현행 릴리스**) |
| backend | 없음(`-backend=false`) | S3 + `use_lockfile = true` |
| 자격증명 | 없음(plan/apply 안 함) | GitHub OIDC → 입구 Role → 실행 Role |
| 워크로드 코드 | 가상값 `demo` | 실제 프로젝트 코드 |
| `ignore_tags` | 비어 있음 | 랜딩존 자동 태거 키를 채운다 |

**소싱이 다른 이유**: 이 예제는 **현재 코드**를 검증해야 하므로 상대경로를 쓴다. 소비 프로젝트는
릴리스된 태그를 핀한다 — 두 방식을 혼동하지 않는다.

```hcl
source = "git::https://github.com/skax-ca/iac-module-library.git//modules/vpc?ref=vpc-v0.3.0"
```

⚠️ **핀은 착수 시점의 현행 릴리스로 건다** — `git tag -l 'vpc-v*'`로 확인한다. 위 표의 태그가
낡은 채 복사되면 그대로 굳는데, 실패 방식이 나쁘다: `vpc-v0.2.0`은 Flow Logs confused deputy
방어(보안 수정)라 **그것이 빠진 채로도 `apply`는 성공한다.** 릴리스 이력은 각 태그의 annotated
메시지(`git show vpc-v0.3.0`)와 [`docs/module-index.md`](../../../../docs/module-index.md)에 있다.

⚠️ **`0.y.z`는 개발 단계를 뜻한다**([`docs/conventions.md`](../../../../docs/conventions.md)) —
이 구간에서는 **마이너 업그레이드도 계약을 바꿀 수 있다.** 태그를 올릴 때 릴리스 메시지를 읽는다.
(2026-08-05 이전에 발행된 `vpc-v1.x` 태그는 같은 커밋의 `v0.x`로 재매핑됐고 **더 이상 존재하지 않는다**.)

## 실행

```bash
tofu -chdir=modules/vpc/examples/enterprise init -backend=false
tofu -chdir=modules/vpc/examples/enterprise validate
```

> ⚠️ `validate`는 계약 위반을 잡지 못한다(`plan`에서만 평가된다). 계약 검증은
> `tofu -chdir=modules/vpc test`가 담당한다.
> 그리고 **CIDR 겹침과 primary/secondary 조합 제약은 apply 시 AWS API가 검출**하므로
> 이 예제로도 검증되지 않는다 — 실계정 apply까지 남은 미검증 리스크다.
