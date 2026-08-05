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
  source = "git::https://github.com/<org>/iac-module-library.git//modules/vpc?ref=vpc-v0.3.0"
  # ...
}
```

태그는 **컴포넌트별 semver**: `vpc-v0.3.0` · `eks-cluster-v0.1.0`.

## 🔢 버전 정책: 전 모듈 `0.y.z` (D-VERSION, 2026-08-05)

번호 체계의 SSOT는 **`docs/architecture/05-versioning-policy.md`**다.

- **모든 모듈이 개발 단계(`0.y.z`)다.** 이 구간에서는 **파괴적 변경도 마이너로 흡수**하고
  소비자에게 계약 안정을 약속하지 않는다 — semver가 `0.y.z`에 부여한 뜻 그대로다.
  ⭐ 그래서 *"이 변경이 마이너인가 메이저인가"* 를 **판정하지 않는다.** 전부 마이너다.
- **`1.0.0`은 모듈별로** 컷한다(05 §2의 기준 5개 충족 시). ⛔ **전 모듈 일괄 컷은 05 §4가 기각했다** —
  `vpc`와 `eks-cluster`는 churn 속도가 달라 묶으면 소비자가 매번 "뭐가 바뀌었지"를 확인해야 한다.
- **신규 모듈은 `0.1.0`에서 시작**한다(다음 적용: `workbench`). `1.0.0`으로 시작하지 않는다.
- ⚠️ 버전 혼재(`vpc-v0.3.0` + `workbench-v0.1.0` + 훗날 `vpc-v1.0.0`)는 **결함이 아니라 정보**다.

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
- **버전 핀**: OpenTofu **`>= 1.12.0` 전 모듈 통일**(D-TOFU-FLOOR, 2026-08-05 — 실행도 1.12.x).
  ⚠️ 모듈별 하한 대장은 **폐지**됐다. *"근거로만 올린다"* 는 이제 **1.13 이상에만** 적용된다 —
  근거는 `02 §2`(실행 지점이 이미 전부 1.12라 분기가 소비자를 배제한 적이 없었다).
  aws `~> 6.0`(예제·프로젝트 루트)/`>= 6.0`(모듈),
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
- **모듈 CI**: `.github/workflows/verify.yml`이 **게이트 6개**를 검증한다(2026-07-30 구현 —
  그 전까지 이 줄은 사실이 아니었다. `.github/workflows/`에 `.gitkeep`만 있었다).
  ① `tofu fmt` ② `tflint --recursive` ③ `trivy config` ④ modules: `init -lockfile=readonly`
  + `validate` + `test`(tests 없는 모듈은 **실패**) ⑤ examples: `init -lockfile=readonly` + `validate`
  ⑥ **lock registry 검사**(`registry.terraform.io` 섞이면 실패 — 02 §4).
  - ⚠️ **CI와 로컬 훅의 도구 버전·플래그를 일치시킨다.** 어긋나면 "로컬은 통과했는데 CI가 막는다"가
    생기고, 그러면 사람이 CI를 신뢰하지 않게 된다. 기준(2026-07-30): OpenTofu 1.12.5 ·
    tflint 0.63.1 · trivy 0.72.0 · aws ruleset 0.48.0. **한쪽을 바꾸면 다른 쪽도 바꾼다.**
    특히 trivy는 액션 대신 **바이너리를 설치해 pre-commit과 같은 명령을 그대로** 실행한다.
  - 프로젝트 repo와 달리 이 repo는 배포하지 않으므로 **apply 워크플로가 없다**(누락이 아니라 설계).
  - CI는 읽기 전용이라 `cancel-in-progress: true`다. ⚠️ 소비 repo의 **apply**는 반대여야 한다 —
    apply 중단은 state 잠금·부분 적용을 남긴다. 이 블록을 그대로 복사하지 말 것.

### 브랜치·PR 규칙 (2026-08-03 확정)

| 변경 대상 | 경로 |
|-----------|------|
| **`.tf` · `.github/workflows/`** | **브랜치 → PR** |
| **문서 · `.omc/notepad.md` 전용** | **`main` 직접 커밋** |

- 기준은 *"CI가 **머지 전에** 막아야 하는가"* 하나다. `verify.yml`은 **`push: branches: [main]`에도 돌므로**
  "PR이어야 CI가 돈다"는 성립하지 않는다 — 차이는 **깨진 것이 main에 들어가기 전에 걸리느냐**뿐이다.
  문서에는 main을 깨뜨릴 산출물이 없다.
- ⛔ **문서 전용 변경에 PR을 쓰지 않는다.** 이 repo는 사실상 1인 작업이라 리뷰는 self-merge = 형식이고,
  커밋 메시지를 길게 쓰는 문화라 PR 본문도 중복이다. 형식만 남은 절차는 비용만 낸다.
- ⚠️ **브랜치 작업 시 `.omc/notepad.md` 갱신을 같은 브랜치에 싣는다.** 2026-07-31에 실제로 이것이
  누락되어 다음 세션이 **이미 끝난 일을 다음 태스크로 안내**했다(`3005b60`에서 정정).
  브랜치가 늘 때마다 "무엇을 어디에 실을지"를 판단해야 하고, 그 판단은 실제로 어긋난 적이 있다.

---

## 작업 원칙 (2026-08-04 채택)

대부분 이미 실천하던 것을 규칙으로 승격한 것이다. **이 repo에서 뜻이 달라지는 것은 번역해 뒀다** —
이 repo의 산출물은 **고객사에 배송되는 계약**이라, 일반 애플리케이션 규칙이 그대로 맞지 않는다.

> ℹ️ *"관심사를 분리한다"·"검증된 라이브러리를 쓴다"* 는 여기 다시 적지 않는다.
> 위 **「아키텍처 & 모듈 규칙」**(facade 원칙·계층형 하이브리드·semver 거버넌스)이 이미 소유한다.

### 발명하기 전에 찾는다 — "그 기능은 없다"고 단정하지 않는다

- 해결책을 짜기 전에 **upstream 모듈·provider·AWS 공식이 그 문제를 이미 어떻게 푸는지** 본다.
  위 「검증」의 MCP 확인 절차가 이 원칙의 이행 장치다.
- 🔑 **facade 에서 특히 자주 틀리는 형태**: "upstream이 지원하지 않는다"가 아니라
  **wrapper 가 그 인자를 안 넘기고 있을 뿐**인 경우다.
  실측(2026-08-04, D-NODE-ARCH): graviton 이 막힌 원인은 upstream 미지원이 아니라 facade 가
  `ami_type` 을 통과시키지 않아서였다 — upstream v21.24.1 엔 처음부터 있었다.
  단정하고 우회(launch template 등)를 짰다면 **facade 가 upstream 을 가리는 부채**가 됐을 것이다.
  → `.terraform/modules/` 실물 소스를 연다. 문서보다 소스가 빠르고 정확할 때가 많다.

### 죽은 경로를 남기지 않는다 — 단, 계약 파괴는 semver 로 드러낸다

- 쓰이지 않게 된 코드·변수·분기는 **삭제한다.** 호환 레이어를 덧대 두 경로를 유지하지 않는다.
  실측: D27 철회 때 `update-assume-role-policy` 를 남기지 않았고, D30-1 이 PR plan 을 지울 때
  댓글 step 도 함께 지웠다.
- 🔴 **"하위 호환을 유지하지 마라"를 모듈 계약에 그대로 적용하지 않는다.** 이 repo의 출력은
  고객사가 **정확 태그로 핀해서 쓰는 계약**이다. 계약 변경은 숨기는 것이 아니라
  **semver 로 드러내는 것**이 규약이다(위 semver 거버넌스). *호환 레이어는 덧대지 않되,
  깨는 변경은 메이저로 표시한다* — 둘은 모순이 아니다.
- 🔴 **릴리스된 태그를 덮어쓰지 않는다.** 예외는 **소비자가 0일 때뿐**이다.
  실측(2026-08-04): `eks-cluster-v1.0.0` 은 컷 직후 apply 된 인프라가 하나도 없어(소비 repo 는
  plan 만) 태그를 옮겼다. **한 번이라도 apply 된 뒤에는 마이너를 컷한다.**
  - ⚠️ **번호는 당시 기록이다** — 그 태그는 2026-08-05 D-VERSION 재매핑으로 **`eks-cluster-v0.1.0`** 이 됐다.
  - 🔑 **D-VERSION 이 이 사건을 다시 읽었다**(05 §0): *"예외를 발명해야 했다"* 는 것 자체가
    **1.0.0 이 이른 약속이었다**는 신호였다. `0.x` 에서는 태그를 옮길 이유가 애초에 없다 —
    다음 마이너를 내면 된다. 규칙은 유효하되, **규칙을 자주 시험하게 만드는 번호 체계를 고친 것**이다.

### 지금 요구를 채우는 가장 단순한 형태로 만든다

- 추측에 근거한 변수·추상화·간접 계층을 만들지 않는다. **필요해지면 그때 연다.**
  실측: `addons.tf` 가 vpc-cni 의 SG 를 변수로 열지 않고 *"별도 SG 요구가 생기면 그때 변수를 연다"* 로
  남겼다(게다가 그 변수는 순환 참조를 만들었을 것이다).
- ⚠️ **kill switch·삭제 보호·교차변수 validation 은 "추측 대비"가 아니다.** 재사용 자산의
  **현재 요구사항**이다(D-EKS-ENABLED·D-EKS-PROTECT·D12). 단순화의 이름으로 걷어내지 않는다.
- ⚠️ **닫힌 열거(validation) 는 값이 늘 때마다 부채가 된다.** 넣을 때 유지보수 비용을 함께 계산한다.
  실증: `capacity_type` 검증이 AWS 가 나중에 추가한 `CAPACITY_BLOCK` 을 아직 담지 못하고 있다.

### 레이어로 키운다

- 엔드투엔드로 **동작하는 최소**에서 시작해 그 위에 하나씩 얹는다. 동작하는 코드를
  미완성 복잡도와 맞바꾸지 않는다.
- ⚠️ **이 repo에서 "동작한다"의 기준은 `tofu test` + 예제 `validate` 까지다.** 배포하지 않으므로
  `apply` 판정은 소비 repo 몫이다 — 그 경계를 넘어 "검증했다"고 쓰지 않는다(`docs/reference/poc-findings.md`).
- ⛔ 계약 테스트가 없는 모듈은 릴리스하지 않는다(02 §4, CI 게이트 ④가 강제).

### 임시방편으로 넘기지 않는다

지금만 넘기고 나중에 교체할 우회를 받아들이지 않는다.
위 **「⛔ 설계·검토 우선 규칙」**(설계 → 검토 → 구현)이 이 원칙의 이행 장치다.
