# CLAUDE.md — 프로젝트 규칙

Cloud Architect 팀이 **여러 실제 프로젝트에서 재사용**하는 IaC 모듈 자산 라이브러리.
고객사가 **구독 라이선스 없이 바로 착수**할 수 있어야 하는 것이 이 repo의 존재 이유다.

**스택**: **OpenTofu**(MPL-2.0) + GitHub Actions(OIDC) + S3 backend(`use_lockfile`) + OPA/Conftest

## ⚙️ 엔진: OpenTofu 단독 (D-ENGINE, 2026-07-29)

명령은 `terraform`이 아니라 **`tofu`**다. 로컬·CI·문서·lock 전부 하나로 일원화한다.

- **라이선스는 채택 근거가 아니다.** HashiCorp FAQ는 *"고객이 자기 프로덕션에서 BSL 제품을 쓰는 것을
  컨설턴트가 돕는 행위"* 를 **명시적으로 허용**한다. 고객 비용 장벽은 CLI가 아니라 **HCP/TFE 구독**에
  있었고 GitHub Actions + S3로 이미 해소됐다. 채택 근거는 **리워크 0 + 조달 마찰 제거**다
  (`docs/architecture/04-engine-decision.md` §4).
- **두 엔진 동시 지원은 검토 후 기각했다**(04 §3, 실측 비용 기록). *"둘 다 지원하면 되지 않나"* 라는
  질문이 나오면 **04 §3을 먼저 읽는다** — 이미 값을 매겨 기각한 안이다. 재검토 조건은 04 §7-1.
- **Terraform 호환성은 계약이 아니라 부산물**이다. 보장하지 않지만 이유 없이 깨뜨리지도 않는다:
  **OpenTofu 고유 기능(`encryption` 블록·`.tofu` 확장자·`language {}` 블록 등)을 쓸 때는 이유를 설계 문서에 남긴다.**
  강제 장치는 없다 — 얇은 모듈에는 애초에 등장할 이유가 없는 것들이다(04 §5).

---

## 0. 이 repo의 위치 (반드시 먼저 읽을 것)

| repo | 역할 |
|------|------|
| **이 repo (`iac-module-library`)** | 모듈·설계의 **현행 SSOT**. 모든 개발은 여기서 |
| `terraform-enterprise-poc` | TFC 기반 **동결 스냅샷**(2026-07-28 졸업). TFE 제안서 레퍼런스 전용 — **고치지 않는다** |
| `<project>-infra` (향후 N개) | 프로젝트/고객별 배포 루트. 이 repo의 모듈을 **git tag로 소싱** |

- 결정 근거: `terraform-enterprise-poc/docs/architecture/05-oss-asset-repo-decision.md` (D-OSS-STACK)
  — ⚠️ 그중 **엔진 축의 근거는 `docs/architecture/04-engine-decision.md`(D-ENGINE)가 교체**했다.
  결론(OpenTofu)은 같지만 **이유가 다르다** — 05는 라이선스를, 04는 조달 마찰·운영 비용을 든다.
  PoC repo는 동결이라 그쪽에 개정 표시가 없으므로 **04를 함께 읽는다.**
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
- **버전 핀**: OpenTofu `>= 1.9.0`(실행은 최신 1.12.x — 하한은 **실제로 쓰는 기능을 근거로만** 올린다.
  현재 하한 1.9의 근거는 교차변수 `validation`이다), aws `~> 6.0`(예제·프로젝트 루트)/`>= 6.0`(모듈),
  커뮤니티 모듈은 정확 핀. `.terraform.lock.hcl` 커밋 필수 —
  ⚠️ registry 주소가 `registry.opentofu.org/...`인지 확인(PoC의 lock을 복사하면 안 된다).
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
- **리소스 스키마**: 새 리소스/인자 사용 전 `mcp__opentofu__get-resource-docs`로 확인(추정 금지).
  인자는 `namespace`·`name`·`resource` 3개이고 **단독 호출된다**(예: `hashicorp`/`aws`/`vpc`).
  data source는 `get-datasource-docs`(`dataSource` 인자). 이름을 모르면 `search-opentofu-registry` 먼저.
- **커뮤니티 모듈 wrapping**: `mcp__opentofu__get_module_details`(`namespace`·`name`·`target`)로
  실제 upstream 변수/출력명 확인 후 작성.
- **버전 존재 확인**: 핀을 걸기 전에 **`tofu`가 실제로 조회하는 registry**에 그 버전이 있는지 본다.
  로컬 npx 판(0.1.x)에는 버전 조회 툴이 없으므로 표준 registry API를 쓴다 — 실측으로 동작 확인:
  `curl -s https://registry.opentofu.org/v1/providers/<ns>/<name>/versions`
  (모듈은 `.../v1/modules/<ns>/<name>/<target>/versions`)
- **MCP 미가용 시 대체 경로**: provider 저장소의 문서 원문을 직접 읽는다 —
  `https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/main/website/docs/r/<resource>.html.markdown`
  (registry 웹페이지는 SPA라 WebFetch로 읽히지 않는다). **추정으로 대체하지 않는다.**
- **스타일**: `.tf` 작성 시 `terraform-style-guide` 스킬 로드(HCL 컨벤션은 OpenTofu에도 동일 적용).

### 코드 변경 후 (로컬 CLI 게이트 — git hook으로 강제)
```
tofu fmt -recursive -check → tofu validate → tflint --recursive → trivy config . → tofu test(모듈)
```
- ⚠️ **tflint의 `terraform_unused_declarations`는 선언만 하고 쓰지 않은 변수를 exit 2로 잡는다.**
  따라서 `variables.tf`만 있고 이를 소비하는 `main.tf`가 없는 상태는 **커밋할 수 없다** —
  설계 문서가 태스크마다 Commit 라인을 두더라도 실제 커밋 단위는 "변수가 전부 소비되는 시점"이다.
- **git hook 강제**: `.githooks/pre-commit`(fmt·tflint·trivy)와 `.githooks/pre-push`(modules 변경 시 `tofu test`).
  clone마다 1회 활성화: `git config core.hooksPath .githooks`
  우회(`--no-verify`)는 긴급 시에만 — 사유를 커밋 메시지에 명시한다.
- tflint: `.tflint.hcl`(terraform recommended preset + aws ruleset 정확 핀). 설치:
  `brew install trivy opentofu` + tflint는 GitHub 릴리스 바이너리, 이후 `GITHUB_TOKEN=$(gh auth token) tflint --init`.
- trivy 예외는 `.trivyignore`로만 — 항목마다 사유·백로그 링크 필수, 무단 추가 금지.
- **모듈 CI**: `.github/workflows/`가 fmt·validate·tflint·trivy·`tofu test`를 검증한다
  (프로젝트 repo와 달리 이 repo는 배포하지 않으므로 apply 워크플로가 없다).
