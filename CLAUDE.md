# CLAUDE.md — 프로젝트 규칙

Cloud Architect 팀이 **여러 실제 프로젝트에서 재사용**하는 IaC 모듈 자산 라이브러리.
고객사가 **구독 라이선스 없이 바로 착수**할 수 있어야 하는 것이 이 repo의 존재 이유다.

**스택**: GitHub Actions(OIDC) + S3 backend(`use_lockfile`) + OPA/Conftest — 전부 OSS

## ⚖️ 엔진 중립 (D-ENGINE-NEUTRAL, 2026-07-29)

**모듈 코드는 OpenTofu와 Terraform 양쪽에서 동작한다.** 엔진 선택은 이 repo가 아니라
**배포 루트(프로젝트 repo)의 결정**이다 — 모듈은 소비자의 엔진을 강제하지 않는다.

| 축 | 이 repo |
|---|---|
| 모듈 `.tf` | **두 엔진 교집합 문법만** (규칙 → `docs/architecture/04-engine-neutrality.md` §5) |
| 로컬 게이트(hook) | `tofu` — 더 제약이 빡빡한 타깃이라 1차 방어선 |
| CI | **2잡**(`tofu test` + `terraform test`) — 중립성을 실증한다 |
| `.terraform.lock.hcl` | **커밋하지 않는다** — 두 엔진의 신뢰 루트가 달라 공유 불가(04 §4) |

> 라이선스는 걸림돌이 아니다. HashiCorp FAQ는 *"고객이 자기 프로덕션에서 BSL 제품을 쓰는 것을
> 컨설턴트가 돕는 행위"* 를 명시적으로 허용한다. 고객 비용 장벽은 CLI가 아니라 **HCP/TFE 구독**에
> 있었고, GitHub Actions + S3로 이미 해소됐다(04 §1).

---

## 0. 이 repo의 위치 (반드시 먼저 읽을 것)

| repo | 역할 |
|------|------|
| **이 repo (`iac-module-library`)** | 모듈·설계의 **현행 SSOT**. 모든 개발은 여기서 |
| `terraform-enterprise-poc` | TFC 기반 **동결 스냅샷**(2026-07-28 졸업). TFE 제안서 레퍼런스 전용 — **고치지 않는다** |
| `<project>-infra` (향후 N개) | 프로젝트/고객별 배포 루트. 이 repo의 모듈을 **git tag로 소싱** |

- 결정 근거: `terraform-enterprise-poc/docs/architecture/05-oss-asset-repo-decision.md` (D-OSS-STACK)
  — ⚠️ 그중 **엔진 축은 `docs/architecture/04-engine-neutrality.md`(D-ENGINE-NEUTRAL)가 개정**했다.
  PoC repo는 동결이라 개정 표시가 그쪽에 없으므로, **04를 함께 읽지 않으면 낡은 결론을 인용하게 된다.**
- ⛔ **PoC repo에서 모듈·설계를 수정하지 않는다.** 양쪽 개발은 곧 drift이고, 6개월 뒤 어느 쪽이
  정답인지 판정 불가능해진다.

### 소비 방식 (프로젝트 repo에서)

```hcl
module "vpc" {
  source = "git::https://github.com/<org>/iac-module-library.git//modules/vpc?ref=vpc-v1.0.0"
  # ...
}
```

태그는 **컴포넌트별 semver**: `vpc-v1.0.0` · `eks-cluster-v1.0.0`.

---

## ⛔ 설계·검토 우선 규칙 (최우선, 필수 준수)

**구현하기 전에 반드시 설계 및 검토를 완료한 후 구현할 것.**

- 코드(`.tf`) 작성/변경 전에 관련 설계가 `docs/architecture/` 또는 `docs/design/`에 존재하고
  승인·검토되었는지 확인한다.
- 설계가 없거나 불완전하면 **구현을 멈추고** 먼저 설계 문서(설계 → 검토 → 승인)를 작성/보완한다.
- "간단해 보인다"는 이유로 이 단계를 건너뛰지 않는다. 새 모듈·아키텍처 변경·인터페이스 변경은 예외 없음.
- 순서: **설계 문서화 → 검토/승인 → 구현 → 검증(fmt/validate/test)**.

> ⚠️ **문서마다 개정 수준이 다르다.** `docs/README.md`의 상태표가 인용 가능 여부의 **판정 근거**다.
> ⚠️ 표시(미개정) 문서는 PoC 전제가 남아 있어 **확정 설계로 인용하지 않는다.**

---

## 🏷️ 리소스 네이밍 & 태깅 규칙 (필수 준수)

### `Name` 태그 포맷
```
(resourcetype)-(workloadcode)-(env)-(regioncode)-(purpose)-(serialnumber|suffix)
예) vpc-acme-prd-an2-main   ·   eks-acme-prd-an2-main-01   ·   sgr-acme-prd-an2-web-01
```

| 구성 요소 | 값 |
|-----------|-----|
| resourcetype | 리소스별 표준 약어 → `docs/reference/aws-naming-abbreviations.md` (**SSOT, 임의 생성 금지**) |
| workloadcode | **프로젝트별 입력 변수** — 이 repo는 특정 값을 고정하지 않는다 |
| env | `prd` / `stg` / `dev` (+ 역할 계정 토큰) |
| regioncode | `an2`(ap-northeast-2) / `ue1`(us-east-1) 등 사용 리전만 등재 |
| purpose | `web`/`db`/`main`/`worker` 등 (소문자·하이픈) |
| serial/suffix | `01` / `20260415` / `policy` (선택) |

### 강제 방식
1. **거버넌스 태그는 `default_tags`로 자동화** — 프로젝트 repo의 provider에 설정. 개별 리소스에 반복 금지.
2. **`Name`은 모듈이 약어를 조합** — 모듈은 `naming` 객체(`{workload, env, region_code}`)를 입력받아
   리소스 타입별 약어로 `Name`을 합성한다. 소비자가 약어를 직접 쓰지 않게 한다.
3. **리소스 타입 약어는 카탈로그에서만.** 없으면 임의 생성 말고 거버넌스 리뷰(약어 추가) 후 사용.
4. **제약 리소스 주의** — S3(전역 고유+DNS), ALB/TG(≤32자), IAM/SG(이름=식별자).
5. **`Name` 태그 assertion을 `*.tftest.hcl`에 포함** — plan 단계에서 네이밍 규약 위반을 잡는다.

> ⚠️ **재사용 자산의 요건**: workload code·계정 ID·리전을 **하드코딩하지 않는다.** PoC에서 승계할 때
> `workload = "poc"` 같은 고정값을 반드시 걷어낸다(05 §5.4).

---

## 아키텍처 & 모듈 규칙

- **모듈 전략**: 계층형 하이브리드. 안정·단순 리소스(VPC/S3/SG)는 스크래치 얇은 모듈, 고속 churn·
  지식밀도 높은 리소스(EKS)는 커뮤니티 모듈을 **wrapper(facade)**로 감싼다.
- **facade 원칙**: 소비자는 안정적 내부 인터페이스만 쓰고, upstream 변수 rename은 wrapper 내부에서만 번역한다.
- **semver 거버넌스 계약**: upstream 파괴적 변경을 인터페이스 유지로 흡수 = 내부 **마이너**(소비자 무영향),
  숨길 수 없으면 내부 **메이저**(의도적 마이그레이션). upstream cadence와 소비자 cadence를 분리한다.
- **버전 핀**: `required_version >= 1.9.0` — ⚠️ **상한을 OpenTofu 최신(1.12.x) 위로 올리지 않는다**
  (올리는 순간 tofu가 전부 배제되어 중립성이 깨진다). aws provider는 `>= 6.0`(모듈)/`~> 6.0`(예제·프로젝트 루트),
  커뮤니티 모듈은 정확 핀. provider source는 `hashicorp/aws` **짧은 주소만** — registry 호스트를 쓰지 않는다.
- **`.terraform.lock.hcl`은 커밋하지 않는다**(04 §4). 두 엔진의 GPG 신뢰 루트가 달라 해시가 갈리고,
  lock은 remote module을 추적하지 않아 **소비자에게 전달되지도 않는다**. 상한 방어는 예제의 `~> 6.0`이 맡는다.
- **워크스페이스 간 데이터**: **결정적 네이밍 → `data.aws_*` 조회** 순으로 느슨하게 결합.
  `terraform_remote_state`·원격 state 직접 참조는 지양한다.
- **SG rule은 별도 리소스**(`aws_vpc_security_group_ingress_rule`), inline 금지·혼용 금지.

---

## 실행 기반 (프로젝트 repo가 담당)

이 repo는 모듈만 소유한다. 실행은 프로젝트 repo의 GitHub Actions가 담당하며, 다음을 반드시 지킨다.

| 항목 | 규칙 |
|------|------|
| plan → apply | plan을 **artifact로 저장**해 승인 후 **그 파일을 apply**한다. 누락 시 "승인한 계획 ≠ 적용된 계획" 구멍 |
| 승인 게이트 | Environment protection rules(required reviewers). prd는 항상 수동 승인 |
| 동시 실행 | `concurrency: {group: <root>, cancel-in-progress: false}` — 누락 시 state 충돌 |
| 자격증명 | GitHub OIDC → 입구 Role → 실행 Role(2단 체인). 정적 키 금지 |
| state | S3 + `use_lockfile = true` (DynamoDB 불필요) |

> ⚠️ **GitHub immutable sub claim**: 2026-07-15 이후 생성된 repo의 OIDC `sub`는 이름이 아니라
> 숫자 org/repo ID를 쓴다 — `repo:<org>@<org_id>/<repo>@<repo_id>:environment:dev`.
> 신뢰 정책 작성 전 실제 토큰의 `sub`를 확인할 것.

---

## 검증

### 코드 작성 전
- **리소스 스키마**: 새 리소스/인자 사용 전 `mcp__terraform__*`로 확인(추정 금지). **2단계 호출**이다 —
  `search_providers`(`provider_name`·`provider_namespace`·`service_slug`·`provider_document_type` 필수)로
  `providerDocID`를 얻고, 그 값을 `get_provider_details`(`provider_doc_id` 필수)에 넘긴다.
  `get_provider_details`는 단독 호출이 불가능하다.
- **커뮤니티 모듈 wrapping**: `mcp__terraform__get_module_details`로 실제 upstream 변수/출력명 확인 후 작성.
- **MCP 미가용 시 대체 경로**: provider 저장소의 문서 원문을 직접 읽는다 —
  `https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/main/website/docs/r/<resource>.html.markdown`
  (registry 웹페이지는 SPA라 WebFetch로 읽히지 않는다). **추정으로 대체하지 않는다.**
- **스타일**: `.tf` 작성 시 `terraform-style-guide` 스킬 로드(HCL 컨벤션은 두 엔진에 동일 적용).
- **엔진 중립 규칙**: 신규 문법을 쓰기 전에 `docs/architecture/04-engine-neutrality.md` §5(N1~N7)를 확인한다.
  한쪽 엔진 전용 기능(state 암호화, `.tofu` 확장자, provider `for_each` 등)은 **모듈에 넣지 않는다**.

### 코드 변경 후 (로컬 CLI 게이트 — git hook으로 강제)
```
tofu fmt -recursive -check → tofu validate → tflint --recursive → trivy config . → tofu test(모듈)
```
- **로컬은 `tofu` 기준이다** — 두 엔진 중 제약이 빡빡한 쪽이라 1차 방어선으로 적합하다(04 §3.2).
  반대 방향 위반(OpenTofu 전용 기능 사용)은 **CI의 `terraform test` 잡**이 잡는다.
- **git hook 강제**: `.githooks/pre-commit`(fmt·tflint·trivy)와 `.githooks/pre-push`(modules 변경 시 `tofu test`).
  clone마다 1회 활성화: `git config core.hooksPath .githooks`
  우회(`--no-verify`)는 긴급 시에만 — 사유를 커밋 메시지에 명시한다.
- tflint: `.tflint.hcl`(terraform recommended preset + aws ruleset 정확 핀). 설치:
  `brew install trivy opentofu` + tflint는 GitHub 릴리스 바이너리, 이후 `GITHUB_TOKEN=$(gh auth token) tflint --init`.
- trivy 예외는 `.trivyignore`로만 — 항목마다 사유·백로그 링크 필수, 무단 추가 금지.
- **모듈 CI**: `.github/workflows/`가 **`gate-tofu` + `gate-terraform` 2잡**(각각 fmt·validate·test)과
  엔진 무관 `lint` 잡(tflint·trivy)을 돌린다. **두 엔진 잡 모두 required check**다 — 한쪽만 통과하면
  중립성이 깨진 것이다(04 §6). 이 repo는 배포하지 않으므로 apply 워크플로는 없다.
