# 03 · 멀티 환경(dev/stg/prd) 전략

> 🗄️ **TFC 시절 잔재 — 보관 문서다. 이 repo의 규칙도, 소비 규약의 SSOT도 아니다.**
>
> **출처**: `terraform-enterprise-poc` @ `76285f7`(동결 커밋) / **개정 안 됨**
> **성격 확정**: [`design/50` D26-1](../design/50-reference-consumer-repo.md)(2026-07-30, 사용자 결정)
>
> - **이관하지 않는다.** 소비 repo(`iac-reference-infra`)로 옮기지 않고 여기 보관한다.
>   ⚠️ 2026-07-29판 헤더는 "첫 프로젝트 repo로 옮기며 개정한다"였다 — **D26이 그 다음날 이관을
>   기각**했고 이 헤더가 뒤늦게 따라온 것이다. 이관 여부를 다시 묻지 말 것.
> - **소비 규약의 SSOT는 [`design/50`(D-CONSUME)](../design/50-reference-consumer-repo.md)이다.**
>   D20~D29가 소싱 인증·backend·OIDC 체인·plan artifact를 소유한다. 이 문서가 아니다.
> - **왜 버리지 않는가**: §3 디렉토리 · §4 divergence 3단 규칙 · §6 승격 플로우 · §8 안티패턴 근거는
>   **도구 무관이라 그대로 유효**하고, `design/50` **D22**가 §3을 직접 인용한다.
> - ⚠️ **TFC 종속부(§5 워크스페이스 구조·`tfe_outputs`·실행 주체 서술)는 무효다.**
>   이 문서를 근거로 새 구현을 하지 않는다 — 인용 전에 그 규칙이 도구 무관인지 먼저 확인한다.


> 공통 규약: [02-common-governance.md](../architecture/02-naming-tagging-and-pinning.md) · 결정 근거: [01-strategy-and-decisions.md](../architecture/01-module-strategy.md)

**전제**: 환경별 **별도 AWS 계정**(AFT 표준). dev/stg/prd는 리소스·네트워크 **구조가 실제로 다르다**(비용상 dev는 축소 구성). 실행은 TFC(`born2k`).

---

## 1. 핵심 제약과 그로부터의 결론

가장 중요한 사실: **환경별 구조가 다르다.** 이 한 가지가 도구 선택을 결정한다.

- 구조가 다르면 **환경마다 config 자체가 달라야** 한다 → 단일 config 방식(CLI workspace)은 부적합.
- 별도 계정이므로 **계정 = 격리 경계**(state, 자격증명, 비용) → 환경 분리가 자연스럽다.

> ⚠️ 용어: **CLI workspace**(`terraform workspace`, 단일 config·다중 state)와 **TFC workspace**(config+state+변수+자격증명 바인딩)는 다르다. 이 설계는 **CLI workspace를 쓰지 않고**, TFC workspace를 환경×컴포넌트 단위로 만든다.

---

## 2. Git 전략 — 단일 repo + 환경별 디렉토리 (branch/repo 분리 금지)

### 결정
**단일 repo, trunk 기반(모두 `main`), 환경별 디렉토리.**

### 왜 branch-per-env / repo-per-env가 아닌가 (리서치 근거)
| 안티패턴 | 문제 |
|----------|------|
| **branch-per-env** | backend 설정이 브랜치 간 복사 → **prod state에 실수로 apply** 위험, merge 충돌, tfvars 스케일 문제 |
| **repo-per-env** | 모듈 중복, 환경 간 drift, 승격(promotion) 복잡, 리뷰 파편화 |
| **CLI workspace** | 단일 config 강제 → **구조가 다른 환경을 표현 못 함**, 환경 간 drift 은폐, backend 접근제어 공유 |

→ 세 가지 모두 배제. 단일 repo + 디렉토리 분리가 격리·DRY·승격을 모두 만족.

---

## 3. 디렉토리 구조

```
terraform-enterprise-poc/   (단일 repo, trunk)
├── modules/                        # 공통 로직 (버전 핀, DRY의 원천)
│   ├── vpc/  eks-cluster/  ...
└── live/                           # 계정 단위 루트 = 계정별 config (2026-07-19 개정 — §3.1)
    ├── dev/                        # 환경(워크로드) 계정
    │   ├── networking/    # dev: single NAT, 좁은 CIDR
    │   └── eks-cluster/   # dev: Karpenter off, spot, 작은 노드
    ├── stg/  { networking/  eks-cluster/ }
    ├── prd/  { networking/  eks-cluster/ }  # prd: 3-AZ, NAT×3, on-demand
    └── cicd/                       # 역할(공용) 계정 — CT의 shared-services/CICD
        └── gitops-hub/    # ArgoCD Capability(hub-spoke) — 구 live/dev/eks-bootstrap
```

- **공통은 `modules/`**, **차이는 `live/<account>/`**가 표현. 단일 config에 `count`/조건 남발 회피.
- 각 `live/<account>/<component>/`는 자기 backend(TFC workspace)에 바인딩된다(§5).

### 3.1 1계층 = 계정 단위 (2026-07-19 개정)

`live/` 1계층은 "환경"이 아니라 **계정 단위**다 — 환경 계정(`dev`/`stg`/`prd`)에 더해
**역할 계정**(`cicd` 등 CT 공용 계정)을 나란히 둔다. GitOps hub(ArgoCD Capability)처럼
전 환경을 관장하는 공용 컴포넌트는 특정 환경 소속이 아니므로 역할 계정 디렉토리에 배치한다
(management 계정은 CT 모범 사례상 워크로드 금지 → hub는 CICD/shared-services 소속이 정석).

- **구조는 목표 토폴로지, 바인딩은 변수**: 계정 바인딩은 전적으로 TFC workspace 변수
  (`workload_account_id` 등)가 담당하므로, PoC처럼 단일 계정에서 테스트할 때도 디렉토리는
  목표 구조를 유지하고 **바인딩만 테스트 계정으로** 둔다.
- **리소스 네이밍 env 토큰**: 역할 계정 전용 env 값(예: `cicd`)은 02 §1.3 카탈로그에 미등재 —
  실제 이관 시 거버넌스 리뷰로 추가한다. PoC(dev 계정 바인딩) 동안은 `env=dev`를 사용해
  이름이 실제 소속 계정을 정직하게 표기하게 한다(이관 = 재생성이므로 이름 변경 부담 없음).

---

## 4. 환경 divergence 처리 3단 규칙 (핵심)

| 차이 유형 | 처리 | 예 |
|-----------|------|-----|
| **값만** 다름 | 같은 모듈 + env 루트 `variables`/`tfvars` | 노드 크기, desired_size, CIDR 범위 |
| **구조**가 다름 | env 루트에서 **모듈 조합 다르게** / feature 플래그 | dev `enable_karpenter=false`, NAT 1개 vs prd 3개 |
| **완전히** 다름 | env 루트에 해당 리소스 미포함/별도 구성 | dev엔 WAF/Shield 없음, prd만 존재 |

> 모듈은 divergence를 **옵션(변수)으로 흡수**하도록 설계(예: `single_nat_gateway`, `enable_karpenter`, `az_count`). 값으로 못 흡수하는 큰 구조 차이는 env 루트가 모듈을 다르게 조립.

---

## 5. TFC 조직 구조 (별도 계정 기준)

```
TFC Org: born2k
└── Project: terraform-enterprise-poc         # Projects로 그룹핑
    ├── networking-dev    (dir: live/dev/networking)   → dev 계정 OIDC role
    ├── networking-stg    (dir: live/stg/networking)   → stg 계정 OIDC role
    ├── networking-prd    (dir: live/prd/networking)   → prd 계정 OIDC role
    ├── eks-cluster-dev / -stg / -prd
    └── gitops-hub-cicd   (dir: live/cicd/gitops-hub)  → hub 계정 (PoC는 dev 계정 바인딩)
```

**공식 권장 공식**: `configurations × environments = workspaces`. workspace 이름에 **컴포넌트+환경** 포함.
역할 계정 컴포넌트는 환경 대신 계정을 붙인다: `<component>-<account>`(예: `gitops-hub-cicd`).

### 워크스페이스 바인딩 방식 — VCS Working Directory (확정)

"이 디렉토리(`live/<env>/<component>`) ↔ 이 TFC workspace(`<component>-<env>`)" 매핑을 **TFC workspace 설정**에 둔다. 코드(`cloud{}` 블록)에는 매핑을 두지 않는다.

- **바인딩 위치**: 각 workspace 설정에 VCS repo 연결 + **Working Directory** = `live/<env>/<component>` + **Trigger patterns**(해당 경로 변경 시에만 run 큐잉).
- **live 루트 코드**: `cloud{}` 블록을 **두지 않는다**. state backend·자격증명·변수는 전적으로 TFC workspace 설정(OIDC 변수 세트 등)이 담당.
- **자동 실행**: `git push` → TFC가 변경 경로를 Working Directory·Trigger patterns와 대조 → 해당 컴포넌트×환경 workspace만 자동 plan.

**이 방식을 택한 이유**
- 모노레포 다중 루트에 대한 HashiCorp 권장 패턴이고, workspace 이름을 코드에 하드코딩하지 않아 **코드 이식성**이 높다(이름 규칙 변경이 TFC 설정에만 국한).
- 매핑이 코드 밖(TFC)에 있는 트레이드오프(리뷰·grep으로 안 보임, 로컬 CLI 실행 번거로움)는 감수한다. 로컬 검증은 `terraform validate`(backend=false)로 커버한다(§6 검증 게이트).

> 대안이던 `cloud{}` per-root(코드에 workspace 이름 명시)는 배제. VCS 자동 실행을 쓰는 한 어차피 Working Directory 설정이 필요해 정보가 중복되기 때문.

### 별도 계정이라 자연스러워지는 것들
- **OIDC**: 각 workspace가 **자기 환경 계정**의 IAM role을 assume → 자격증명이 계정 단위로 격리. dev workspace가 prd에 손댈 수 없음.
- **비용**: 계정 = 비용 경계 → 환경별 비용 가시성/한도 자동. dev 축소 구성의 절감이 계정 청구서에 그대로.
- **State/blast radius**: workspace마다 독립 state. 한 환경 사고가 다른 환경에 전파 안 됨.
- **접근제어**: TFC 팀 권한을 workspace(=환경) 단위로 부여. prd는 승인자 제한.

### 변수 관리
| 범위 | 방법 |
|------|------|
| 조직/전 환경 공통 | **Variable Set**(예: 공통 태그 기본값, TFC 설정) |
| 환경 공통(계정 무관) | Variable Set(env별) |
| 환경 고유값 | workspace 변수(계정ID, CIDR, 노드 스펙) |
| 민감정보 | workspace 변수(sensitive) 또는 OIDC로 정적키 제거 |

### 워크스페이스 내 연동 (환경 내부)
[02-common §4](../architecture/02-naming-tagging-and-pinning.md)의 연동(데이터=`tfe_outputs` 필수, run trigger=선택)은 **각 환경 내부에서만** 구성된다(예: `eks-cluster-prd`가 `networking-prd`의 output을 읽음). **환경 간에는 어떤 연결도 걸지 않는다**(§6 승격 참조).

- 기존 단일 환경 연동과 달라지는 점: **메커니즘은 동일**하고 **환경마다 복제 + 크로스 환경 금지**만 추가된다.
- `tfe_outputs`의 대상 workspace는 자기 환경으로 파라미터화한다 — 예: prd 루트는 `workspace = "networking-prd"`, dev 루트는 `"networking-dev"`.

### 환경별 apply 정책 (중요)
run trigger는 downstream **plan을 큐잉**할 뿐, apply는 환경 정책을 따른다.

| 환경 | plan 큐잉 | apply |
|------|-----------|-------|
| dev | 자동 | **auto-apply 허용** (빠른 반복) |
| stg | 자동(선택) | **수동 승인** |
| prd | 자동(선택) | **항상 수동 승인 + 승인자 제한** |

> "최초만 수동, 이후 자동 배포"는 **dev에만 해당**한다. **prd는 매 배포가 승인 게이트**를 거친다(무인 apply 금지).
> "최초 수동 apply"의 이유는 승인 정책이 아니라 부트스트랩 **순서 제약**(upstream output 선행 필요)이다.

---

## 6. 승격(Promotion) 플로우 — 환경 간

환경 간 변경 전파는 **run trigger 자동화가 아니라 버전 승격**으로 한다.

```
modules/eks-cluster 변경 → v1.3.0 태그
   │
   ├─▶ dev: eks-cluster 루트 핀 ~> 1.3 → plan/apply → 검증
   ├─▶ stg: 핀 상향 → plan/apply → 검증        (수동 게이트)
   └─▶ prd: 핀 상향 → plan/apply → 승인자 승인   (수동 게이트, 자동 승격 금지)
```

- 각 env 루트가 모듈을 `~> x.y`로 핀 → dev에서 검증 후 stg/prd 핀을 **올려** 승격.
- **prd는 반드시 수동 승인 게이트**. 환경 간 run trigger 자동 apply 금지(사고 전파 방지).
- config 구조 차이는 각 env 루트에서 개별 관리(§4).

---

## 7. 기존 문서/구성과의 관계 (전환 시 반영)

- **현재 POC**: 루트에 단일 `cloud{ workspaces{ name = "terraform-enterprise-poc" }}` + 루트 `main.tf`. 이는 단일 워크스페이스 전제.
- **전환**: 루트 config를 `live/<env>/<component>/`로 이동, 각 루트가 자기 TFC workspace에 바인딩. 바인딩은 **VCS Working Directory 방식**으로 확정(§5 "워크스페이스 바인딩 방식" 참조) — live 루트에 `cloud{}` 블록을 두지 않고 TFC workspace 설정(Working Directory + Trigger patterns)이 매핑을 담당. REQUIREMENTS §4의 단일 워크스페이스 항목은 이 문서로 확장됨.
- **구현 순서**: [구현 계획]은 먼저 `modules/`와 **단일 환경(예: dev)** live 루트로 검증 후, stg/prd 루트를 복제·조정하며 확장한다.

---

## 8. 안티패턴 체크리스트 (하지 말 것)
- [ ] branch-per-environment (backend 복사/오배포 위험)
- [ ] repo-per-environment (모듈 중복/drift)
- [ ] CLI `terraform workspace`로 장수 환경 분리 (구조 divergence 표현 불가)
- [ ] 환경 간 run trigger / 크로스 환경 연결 (prd 사고 전파)
- [ ] 안정적 기반(VPC 등)에 불필요한 run trigger (사소한 변경마다 하위 전체 replan, 과결합)
- [ ] 모든 의존을 run trigger로 자동화 (tfe_outputs로 충분한 걸 과도하게 cascade)
- [ ] prd auto-apply (매 배포는 수동 승인 게이트)
- [ ] 단일 config에 환경 분기 `count`/조건 남발 (가독성·리스크)

## 9. 열린 항목
1. 환경별 CIDR/AZ/노드 스펙 구체값 표준(dev/stg/prd 프로파일)
2. TFC Project vs 여러 Project 분리 기준(앱 증가 시)
3. Variable Set 구성 상세(공통 태그·리전 등)
4. 승격 자동화 수준(CI에서 stg 핀 PR 자동 생성 등)

## 10. 참고 자료
- [HashiCorp — Recommended Practices Part 1 (workspace = config × env)](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices/part1)
- [HCP Terraform — Workspace Best Practices](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/best-practices)
- [Spacelift — Manage Multiple Terraform Environments (branch-per-env 안티패턴)](https://spacelift.io/blog/terraform-environments)
- [Xebia — Environment-based TFC Workspaces](https://xebia.com/blog/using-environment-based-terraform-workspaces-for-development-with-terraform-cloud/)
