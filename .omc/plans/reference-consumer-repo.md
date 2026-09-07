# 레퍼런스 소비 repo (`iac-reference-infra`) 설계 계획

> **상태**: `pending approval` — 사용자 승인 전에는 구현하지 않는다.
> **작성**: 2026-07-30 / **대상**: 신규 repo `skax-ca/iac-reference-infra` + 이 repo의 `docs/` 개정
> **선행 조건**: `vpc-v1.0.0` 릴리스 완료(`27cd26e`, 태그 원격 존재 확인됨)

---

## 1. 요구사항 요약

`vpc-v1.0.0`을 **git tag로 소싱**해 VPC 하나만으로 소비 경로를 끝까지(첫 `apply`까지) 통과시킨다.
실 고객사 repo보다 이것을 먼저 두는 이유는 아래 3건이 **전부 첫 apply에서 터지고**, 고객 앞에서
처음 부딪히는 것과 리허설에서 잡아 템플릿으로 복사해 주는 것이 완전히 다른 일이기 때문이다.

부수 목표: `vpc-v1.0.0`의 증거는 전부 `plan` 수준이다(`docs/design/10-vpc-module.md` §3).
이 repo의 첫 apply가 **apply 미검증 6항목을 판정**한다(§7).

---

## 2. 실측으로 확정된 사실 (2026-07-30)

추정이 아니라 실행해서 얻은 값이다. 설계가 이 값들에 의존한다.

| # | 사실 | 근거 |
|---|------|------|
| F1 | **private repo git tag 소싱은 로컬에서 이미 동작한다** | scratchpad에서 `tofu init` 성공. `credential.helper=osxkeychain`이 자격증명 공급 → **미해결 1번은 CI 전용 문제** |
| F2 | `//modules/vpc`는 **clone 후 경로 선택**이다 | 로그가 `git::...iac-module-library.git?ref=vpc-v1.0.0`(서브디렉토리 없음)을 받아 `.terraform/modules/vpc/modules/vpc`에 배치. CI는 **repo 전체**를 받는다 |
| F3 | org `skax-ca` = **310520211** | `gh api orgs/skax-ca` |
| F4 | `iac-module-library` = **1315873255**, 생성 `2026-07-29` | `gh api repos/...`. 신뢰 정책에 쓰는 것은 **소비 repo의 ID**이므로 생성 후 재조회한다 |
| F5 | `gh` 토큰은 **개인(silverte)** — scopes `gist,read:org,repo,workflow` | `gh auth status`. 팀 자산 CI 자격증명으로 부적절 확정 |
| F6 | AWS 계정 `533616270150`, 신원은 IAM **user** `silverte` | `aws sts get-caller-identity`. 부트스트랩 주체가 될 수 있는 유일한 신원 |
| F7 | `use_lockfile`은 OpenTofu s3 backend의 **실재 인자** | `internal/backend/remote-state/s3/backend.go:469` (`cty.Bool`, Optional) |
| F8 | ⚠️ **버저닝 버킷 + `use_lockfile=true` → lock 객체 버전 폭증** | `website/docs/.../s3.mdx:411-416`이 lifecycle로 버전 수 제한을 **권고** |
| F9 | **partial backend configuration** 지원 | `website/docs/language/settings/backends/configuration.mdx:93-139` — `backend "s3" {}`만 두고 `-backend-config`로 주입 |
| F10 | `actions/create-github-app-token` 최신 = **v3.2.0** (2026-05-12) | `gh api repos/.../releases/latest` |
| F11 | `aws-actions/configure-aws-credentials` 최신 = **v6.2.3** (2026-07-22) | 동일 |
| F12 | AWS는 **예측 불가능한 버킷명을 권장**한다 | S3 `bucketnamingrules.html` Best practices — *"We recommend that you create bucket names that aren't predictable."* |

---

## 3. 결정 (D20 ~ D29)

### D20 · CI git 소싱 인증 = GitHub App 토큰 + `insteadOf` — **사용자 승인**

org 소유 GitHub App으로 1시간 만료 토큰을 발급하고 `git config --global ... insteadOf`로 주입한다.

- **소싱 URL은 `git::https://` 하나로 유지한다.** 소비 코드는 인증 방식을 모른다 — facade 원칙과 같은 사고다.
- 개인 계정(F5) 종속이 사라진다. App 설치 범위를 `iac-module-library` **한 개로 한정**하고 권한은
  Repository → **Contents: Read-only** 하나만 준다.
- 기각: repo public 전환(모듈 코드·설계가 공개됨), deploy key(소싱 URL이 로컬/CI로 갈라짐).

### D21 · 부트스트랩 = AWS CLI 스크립트 (IaC 밖) — **사용자 승인 (권장안과 다름)**

`bootstrap/bootstrap.sh`가 aws CLI로 S3 버킷·OIDC provider·Role을 만든다. 닭-달걀이 성립하지 않는다.

> ⚠️ **이 선택으로 잃는 것을 명시한다**: ① drift 감지 불가 ② 변경 이력이 `git diff`로 안 보임
> ③ "IaC 자산 라이브러리"인데 가장 먼저 만드는 것이 IaC 밖에 있다. 권장안은
> `bootstrap/` 루트 + local state → S3 migrate였고, 사용자가 트레이드오프를 알고 CLI 안을 택했다.

**필수 완화책** (이것 없이는 D21이 성립하지 않는다):

| 완화책 | 내용 |
|--------|------|
| 멱등성 | 재실행이 안전해야 한다. 존재하면 생성 대신 갱신, 이미 원하는 상태면 no-op |
| 기대 상태 명문화 | `bootstrap/README.md`에 생성 결과(리소스·이름·정책)를 표로 남긴다. 이것이 `.tf`를 대체하는 SSOT다 |
| drift 감지 대체 | `bootstrap/verify.sh` (**read-only**)가 실제 상태 ↔ 기대 상태를 비교하고 불일치를 exit 1로 낸다 |
| IaC 승격 경로 | `bootstrap/README.md`에 `import` 블록 초안을 남긴다. 나중에 IaC로 올릴 때 처음부터 다시 설계하지 않게 |

### D22 · 디렉토리 = 목표 토폴로지 `live/dev/networking/` — **사용자 승인**

`docs/consumer/multi-environment.md` §3의 계정×컴포넌트 구조를 그대로 쓴다. dev 하나만 채우고
stg/prd·foundation 디렉토리는 만들지 않는다(YAGNI + 빈 디렉토리는 tflint 미사용 선언 문제와 무관하지만
검증할 것이 없는 자리다).

### D23 · `iamoidc` 약어 신설 — **사용자 승인**

`aws_iam_openid_connect_provider`의 카탈로그 약어를 **`iamoidc`**로 등재한다. 카탈로그 총계 311 → **312**.

- 근거: IAM 계열 프리픽스(`iamr`·`iamp`) 유지 + OIDC 명시. 향후 SAML은 `iamsaml`로 대칭 확장.
  카탈로그가 이미 6자(`ecrpri`·`fmsrs`·`abkpol`)를 허용하며, **L2 리소스 구분이 약어 길이보다 우선**한다.
- 기각: `iamo`(`o`가 OIDC임을 알 수 없고 `iams`가 Secret/Server-certificate로 오독됨),
  `iamidp`(OIDC와 SAML이 같은 약어를 공유해 L2 구분이 사라짐).
- ⚠️ `aws_iam_openid_connect_provider`의 **식별자는 URL**이다(`name` 인자 없음). 따라서 이 이름은
  `Name` **태그**로만 붙는다 — inline 정책(`name`=식별자)과 반대 경우다.

### D24 · workload code = `ref` — **사용자 승인**

3자로 짧아 32자 제한 리소스(ALB/TG)에 여유가 크고, 고객사 repo로 복사할 때 **바꿀 토큰이 명확**하다.
`examples/*`의 `acme`(가상값)와 이름이 겹치지 않아 실배포/예제 구분이 선다.

### D25 · state 버킷 = **partial backend configuration + GUID suffix** — **사용자 승인**

버킷명이 **git에 존재하지 않는다.**

```hcl
# live/dev/networking/backend.tf — 커밋된다
terraform {
  backend "s3" {}
}
```

주입 경로: CI는 GitHub repo 변수, 로컬은 **gitignore된** `backend.hcl`.
실제 버킷명은 `s3-ref-dev-an2-tfstate-<guid12>` (예: `s3-ref-dev-an2-tfstate-9f3c1a7b4e2d`).

**계정 ID를 배제한 근거** (사용자 지적 → 리서치로 확정):

| 근거 | 내용 |
|------|------|
| AWS 공식 Best practices | *"We recommend that you create bucket names that aren't predictable."* → 계정 ID는 이 권장에 **반한다** (F12) |
| AWS 공식 | *"Don't include sensitive information in the bucket name."* |
| 이 프로젝트 특유 | `backend.tf`는 **고객사에 복사해 줄 템플릿**이다 → "private 버킷이니 안 보인다"는 논리가 성립하지 않는다 |
| 커뮤니티 | 계정 ID로 **IAM principal 열거**가 가능하다(Plerion). AWS 공식은 "not sensitive"지만 defense-in-depth로 비밀 취급이 다수 의견 |

> ⚠️ **AWS 문서 내부의 충돌을 기록한다**: 같은 문서가 신기능 **account regional namespace**
> (`prefix-accountId-region-an`)를 *"only your account can ever own these bucket names"*로 권장하는데
> 이는 **계정 ID를 이름에 강제**한다. 두 권장의 목적이 다르다 — 전자는 스쿼팅 방지, 후자는 이름 소유권 보장.
> **우리 축은 전자다**: 부트스트랩이 1회 생성 후 영구 보유하므로 스쿼팅 위험이 없고 노출만 문제다.
> 재검토 조건: 버킷명 소유권 분쟁이 실제로 발생하면 `-an` 네임스페이스를 재평가한다.

> ⚠️ **감수하는 트레이드오프**: 어느 버킷을 가리키는지 **코드에서 안 보인다.** 이는
> `docs/consumer/multi-environment.md` §5가 TFC Working Directory에 대해 감수했던 것과 **같은 종류**의
> 트레이드오프다("리뷰·grep으로 안 보임"). 완화: `live/dev/networking/README.md`에 주입 경로와
> 변수명을 명시하고, `bootstrap/verify.sh`가 실제 버킷 존재를 확인한다.

### D26 · 설계 문서 소유권 분리 — **설계 판단**

미결 항목이던 "`docs/design/30`의 소유권"에 대한 부분 답이다.

| 대상 | 위치 | 이유 |
|------|------|------|
| **소비 규약** (모듈 소싱 인증·backend 규약·OIDC 체인 패턴·plan artifact 규칙) | **이 repo** `docs/consumer/*` (SSOT) | 모든 소비 repo가 따라야 하는 **계약**이다. 소비 repo마다 복제하면 곧 drift다 |
| **그 repo 고유의 배포 사실** (계정 ID·버킷 GUID·Role ARN·실측 `sub` 값) | 새 repo `docs/` | 재사용 자산이 아니라 인스턴스 값이다. 이 repo에 쓰면 05 §5.4(하드코딩 금지)를 위반한다 |

### D27 · 실행 Role = 기존 `AWSAFTExecution` 재사용 — **설계 판단**

새 Role을 만들지 않고 신뢰 정책만 교체한다.

- 이유: PoC 계정(F6)을 재사용하고, "코드를 AFT 구조에 미리 맞춘다"는 원래 의도가 유효하며,
  새 Role을 만들면 기존 것이 고아로 남는다.
- ⚠️ **알려진 문제**: 입구 Role(TFC용)이 삭제되어 `AWSAFTExecution`의 신뢰 정책 principal이
  **unique ID로 치환**되었다 → 현재 assume 불가. `bootstrap.sh`가 **신뢰 정책을 새 입구 Role로 교체**한다.
- 입구 Role은 신규: `iamr-ref-dev-an2-gha-entry-01`, 권한은 `AWSAFTExecution` assume 하나뿐.

### D28 · 신뢰 정책은 `sub` 패턴 3개를 가진다 — **설계 판단**

**plan job과 apply job의 `sub`가 다르다.** 이것이 놓치기 쉬운 지점이다.

| job | 트리거 | 예상 `sub` 형태 | ⚠️ |
|-----|--------|----------------|-----|
| PR plan | `pull_request` | `...:pull_request` | Phase 2에서 **실측** |
| main plan | `push` → main | `...:ref:refs/heads/main` | 동일 |
| apply | `environment: dev` 선언 시 | `...:environment:dev` | 동일 |

- **plan/apply 권한 분리는 하지 않는다** — `tofu plan`도 state lock을 잡아 S3 쓰기가 필요하므로
  "plan은 read-only"가 성립하지 않는다. 실행 Role 하나를 유지하고 **§8 열린 항목**으로 남긴다.
- immutable `sub` 형태(`repo:<org>@<org_id>/<repo>@<repo_id>:...`)는 **추정하지 않는다.**
  Phase 2가 실제 JWT claim을 출력해 확정한다.

### D29 · lock 객체 버전 폭증 방어 — **설계 판단**

버저닝은 state 보호에 필수인데 `use_lockfile=true`가 lock 객체 버전을 폭증시킨다(F8).
`bootstrap.sh`가 **lifecycle 규칙**을 함께 만든다: 비현행 버전 보관 기간을 짧게(예: 7일) 두고,
불완전 멀티파트 업로드를 정리한다. 공식 문서가 직접 권고한 대응이다.

---

## 4. 수용 기준 (테스트 가능)

> 📍 **아래 체크박스는 "수용 기준의 정의"이지 진행 상태가 아니다 — 채우지 말 것.**
> Phase 1 이후의 실제 진행은 `iac-reference-infra` 의 `.omc/notepad.md`가 SSOT다.
> (2026-07-30: 진행 상태를 양쪽에 두었다가 이 repo 쪽이 stale해진 사고가 있었다.)

### Phase 0 — 설계 문서화 (이 repo)
- [ ] `docs/design/50-reference-consumer-repo.md`가 존재하고 D20~D29를 근거와 함께 담는다
- [ ] `docs/reference/aws-naming-abbreviations.md`에 `iamoidc` 등재 + 개정 이력 1행 추가, **총계 311 → 312**
- [ ] `docs/README.md` 상태표에 `50`(✅) 추가, `docs/consumer/*` 상태를 "개정 예정"으로 표기
- [ ] 게이트: `tofu fmt -recursive -check` clean (문서만 변경이므로 no-op이어야 한다)

### Phase 1 — 새 repo 골격
- [ ] `skax-ca/iac-reference-infra` (private) 생성, Team `iac`에 `maintain`으로 소속
      (`gh api --method PUT orgs/skax-ca/teams/iac/repos/skax-ca/iac-reference-infra -f permission='maintain'`)
- [ ] `gh api repos/skax-ca/iac-reference-infra --jq .id`로 **repo 숫자 ID 확보**(D28 신뢰 정책 입력)
- [ ] GitHub App 생성: 권한 `Contents: Read-only`, 설치 범위 = `iac-module-library` **1개만**
- [ ] App private key → 소비 repo `secrets.MODULE_READER_KEY`, app-id → `vars.MODULE_READER_APP_ID`
- [ ] `AGENTS.md` + `.omc/` 초기화(deepinit), `.githooks` 활성화, `.tflint.hcl`·`.trivyignore` 승계
- [ ] 게이트: 빈 상태에서 `tflint --recursive` exit 0

### Phase 2 — `sub` claim 실측 (AWS 무관)
- [ ] throwaway 워크플로가 **3개 job**의 JWT claim을 출력한다: PR plan / main plan / `environment: dev`
- [ ] 각 job의 실제 `sub`·`aud` 값이 워크플로 로그에 남고 `docs/`에 기록된다
- [ ] `sub`가 `repo:skax-ca@310520211/iac-reference-infra@<repo_id>:...` 형태인지 **확인** —
      아니면 CLAUDE.md의 immutable sub 서술을 정정한다
- [ ] 실측 후 throwaway 워크플로 **삭제**(커밋으로)

### Phase 3 — 부트스트랩
- [ ] `bootstrap/bootstrap.sh` 실행 → 아래가 생성된다

| 리소스 | 이름 | 비고 |
|--------|------|------|
| S3 버킷 | `s3-ref-dev-an2-tfstate-<guid12>` | 버저닝 ON · SSE ON · 퍼블릭 차단 ON · **lifecycle**(D29) |
| OIDC provider | URL `token.actions.githubusercontent.com`, `Name` 태그 `iamoidc-ref-dev-an2-gha` | aud `sts.amazonaws.com` |
| 입구 Role | `iamr-ref-dev-an2-gha-entry-01` | 신뢰=OIDC(실측 `sub` 3패턴), 권한=**실행 Role** assume 하나 |
| 실행 Role | `iamr-ref-dev-an2-gha-exec-01` | **신설**(D27-1). 신뢰=입구 Role만, 권한=`AdministratorAccess` |

> ⚠️ **D27은 철회됐다**(2026-07-30, F13=공용 계정 실측). `AWSAFTExecution`은 **손대지 않는다** —
> `update-assume-role-policy`가 스크립트에 등장하면 수용 기준 위반이다.

- [ ] `bootstrap.sh`를 **두 번 연속 실행**해도 두 번째가 성공하고 변경 0건이다 (멱등성)
- [ ] `bootstrap/verify.sh`가 exit 0. 버킷을 수동으로 바꾼 뒤 실행하면 exit 1 (**음성 테스트**)
- [ ] `bootstrap/README.md`에 기대 상태 표 + `import` 블록 초안이 있다
- [ ] 버킷명이 **git 어디에도 없다**: `git grep -c "$BUCKET"` → 0 (D25 검증)

### Phase 4 — VPC 배포 (핵심)
- [ ] `live/dev/networking/`이 `git::https://...?ref=vpc-v1.0.0`으로 모듈을 소싱한다
- [ ] `deploy.yml`이 **한 run 안에서** plan → 승인 → apply를 한다 (§5)
- [ ] PR에서 plan이 통과하고 plan 파일이 artifact로 올라간다
- [ ] main 병합 후 apply job이 **Environment protection rules(required reviewers)**에 걸려 대기한다
- [ ] 승인 후 **artifact의 그 plan 파일로** apply 된다 (`tofu apply tfplan` — 재-plan 금지)
- [ ] `concurrency: {group: live-dev-networking, cancel-in-progress: false}` 존재
- [ ] apply 성공. `Name` 태그가 `vpc-ref-dev-an2-main` 형태로 실제 생성됨을 콘솔/CLI로 확인
- [ ] 두 번째 run이 **`No changes`**를 낸다 (멱등성 = 가짜 diff 없음, `ignore_tags` 필요 여부 판정)

### Phase 5 — 실측 반영
- [ ] apply 미검증 6항목(§7)에 **판정 결과**를 기록한다 — 통과/실패/미해당
- [ ] `docs/consumer/dynamic-credentials.md` 개정: TFC OIDC → GitHub Actions OIDC (실측값 반영)
- [ ] `docs/consumer/multi-environment.md` 개정: TFC workspace → 디렉토리 + backend key + Environment
- [ ] `docs/README.md` 상태표에서 `docs/consumer/*` 📦 → ✅
- [ ] 실패한 항목이 있으면 `modules/vpc` 수정 + `vpc-v1.0.1` 릴리스

---

## 5. 워크플로 설계 — "승인한 계획 = 적용된 계획"

CLAUDE.md 실행 기반 표의 요건을 **한 워크플로 두 job**으로 만족시킨다. 별도 워크플로로 쪼개면
artifact를 run 경계 밖에서 찾아야 하고 그 지점이 곧 "승인한 계획 ≠ 적용된 계획" 구멍이 된다.

```
deploy.yml
├─ on: pull_request  (paths: live/dev/networking/**)  → plan job 만
├─ on: push → main   (paths: 동일)                     → plan job → apply job
├─ concurrency: {group: live-dev-networking, cancel-in-progress: false}
│
├─ job: plan
│   permissions: {id-token: write, contents: read, pull-requests: write}
│   1. actions/create-github-app-token@v3.2.0   (owner: skax-ca, repositories: iac-module-library)
│   2. git config --global url."https://x-access-token:$TOKEN@github.com/".insteadOf "https://github.com/"
│   3. aws-actions/configure-aws-credentials@v6.2.3  (role-to-assume = 입구 Role)   ← OIDC 1단
│   4. tofu init -backend-config=... (partial, D25)
│   5. tofu plan -out=tfplan                                                        ← provider assume_role = 2단
│   6. actions/upload-artifact  (tfplan, retention-days: 1)
│
└─ job: apply     needs: plan · if: push to main · environment: dev  ← 승인 게이트
    1~4. plan job과 동일 (App 토큰·OIDC·init 재수행 — 자격증명은 job 간 이동 불가)
    5. actions/download-artifact  (같은 run의 tfplan)
    6. tofu apply tfplan          ← 재-plan 하지 않는다
```

- **2단 체인**: `configure-aws-credentials`가 입구 Role을 OIDC로 인증하고, provider의
  `assume_role`이 `AWSAFTExecution`을 체인 assume한다. 정적 키 없음.
- ⚠️ **plan artifact는 민감할 수 있다** — plan 파일에 리소스 속성이 평문으로 들어간다. repo read 권한자가
  받을 수 있으므로 `retention-days: 1`로 제한하고, 소비 규약 문서에 이 사실을 명시한다.
- ⚠️ **역할 체인 세션은 최대 1시간**(연장 불가). apply 승인이 1시간 넘게 지연되면 apply job이 다시
  인증하므로 문제없다 — 다만 **plan artifact는 유효**해야 한다. state가 그 사이 바뀌면 `apply`가
  거부한다(정상 동작, 재-plan 필요).

---

## 6. 위험과 완화

| # | 위험 | 완화 |
|---|------|------|
| R1 | 실측한 `sub`가 CLAUDE.md 서술과 다름 → 신뢰 정책이 처음부터 안 맞음 | **Phase 2를 Phase 3보다 먼저** 둔 이유가 이것이다. 실측 없이 정책을 쓰지 않는다 |
| R2 | `AWSAFTExecution` 신뢰 정책 교체 실패 (principal이 unique ID로 치환됨) | `bootstrap.sh`가 신뢰 정책을 **전체 교체**(put-role-policy 아닌 update-assume-role-policy). 실패 시 Role 재생성 경로를 README에 남긴다 |
| R3 | GitHub App 생성 권한이 없음 (org owner 아님) | Phase 1 착수 즉시 확인. 불가하면 org 소유 service account의 fine-grained PAT로 대체(D20 재검토) |
| R4 | CI `init`이 repo 전체를 clone해 느려짐 (F2) | 지금은 문제 아님(repo 작음). 태그·히스토리 증가 시 `?depth=1` 검토 — **열린 항목** |
| R5 | apply가 실제 리소스를 만든다 (비용·삭제 위험) | `single_nat_gateway = true`(NAT 1개), `deletion_protection = false`로 시작. 리허설 종료 후 `destroy` 절차를 문서화 |
| R6 | `bootstrap.sh`가 IaC 밖이라 drift가 조용히 쌓인다 (D21의 대가) | `verify.sh` + 기대 상태 표. **음성 테스트로 verify.sh가 실제로 잡는지 증명**한다(Phase 3) |
| R7 | 버킷명이 코드에 없어 잘못된 버킷을 가리킬 수 있다 (D25의 대가) | `verify.sh`가 버킷 존재를 확인. `live/dev/networking/README.md`에 주입 변수명 명시 |
| R8 | `default_tags` 가짜 diff (랜딩존 자동 태거) | Phase 4의 "두 번째 run = No changes" 기준이 이것을 잡는다. 걸리면 `ignore_tags`에 실제 키를 채운다 |
| R9 | plan artifact 유출 | `retention-days: 1` + 소비 규약 문서에 명시 |

---

## 7. 이 apply가 판정하는 `vpc-v1.0.0` 미검증 6항목

`docs/design/10-vpc-module.md` §3의 표. 이것이 레퍼런스 repo의 실질 산출물이다.

| # | 항목 | 판정 방법 |
|---|------|----------|
| 1 | secondary CIDR `depends_on` 순서 | secondary CIDR을 쓰는 2차 apply |
| 2 | primary/secondary 조합 제약 | 동일 |
| 3 | CIDR 겹침 | 겹치는 값으로 apply 시도 → 거부되는지 |
| 4 | Flow Logs 실제 배달 | apply 후 CloudWatch 로그 그룹에 이벤트가 도착하는지 |
| 5 | `prevent_destroy` 실동작 (D12) | `deletion_protection=true`로 바꾼 뒤 `destroy` 시도 → 차단되는지 |
| 6 | **`git tag` 소싱 경로** | Phase 4의 CI `init` 성공 자체가 판정 |

> ⚠️ 1~5는 **VPC 하나만 배포하는 Phase 4로는 다 안 된다.** Phase 4는 6번과 minimal 경로만 판정하고,
> 1~5는 **Phase 5의 후속 apply 시나리오**로 돌린다. 이 구분을 흐리면 "apply로 검증했다"는
> 과잉 주장이 된다 — `poc-findings.md`가 경계하는 바로 그 실수다.

---

## 8. 열린 항목

1. plan/apply 권한 분리 — `tofu plan`도 state lock을 잡아 read-only가 성립하지 않는다(D28). 별도 lock 전략이 필요한지
2. `?depth=1` 소싱 — repo가 커진 뒤 CI `init` 시간 실측 후 판단(R4)
3. `bootstrap`의 IaC 승격 시점 — `import` 경로는 남기되 언제 올릴지는 미정(D21)
4. stg/prd 확장 — 계정이 하나(F6)여서 지금은 표현 불가. 별도 계정 확보 후
5. `docs/design/30-gitops-repo.md` 소유권 — D26이 부분 답. GitOps hub는 이 결정 범위 밖
6. `docs/design/20-eks-module.md` 개정 — 이 계획 완료 후 다음 작업

---

## 9. Phase 순서와 의존성

**의존 순서가 중요하다** — 닭-달걀이 2차로 나타난다: 신뢰 정책은 `sub`를 알아야 하고,
`sub`는 repo가 있어야 나오고, repo에는 워크플로가 있어야 한다.

```
Phase 0  설계 문서화 (이 repo)                     ← 커밋 1
   │
Phase 1  새 repo 생성 + 골격 + GitHub App          ← repo 숫자 ID 확보
   │
Phase 2  sub claim 실측 (AWS 무관, throwaway)      ← 신뢰 정책 입력값 확정
   │
Phase 3  bootstrap.sh (S3 · OIDC · Role)           ← 실측한 sub 사용
   │
Phase 4  live/dev/networking + deploy.yml → apply  ← 소비 경로 통과
   │
Phase 5  실측 반영 (docs/consumer/* 개정 + §7 판정)
```

- **Phase 전환 시 사용자 확인**(CLAUDE.md 설계 품질 원칙).
- Phase 0은 이 repo 커밋, Phase 1~5는 새 repo 커밋 + Phase 5에서 이 repo에 재-커밋.
- 각 Phase 완료 시 `.omc/notepad.md`·`.omc/project-memory.json` 갱신(리드가 수행).

---

## 10. 검증 절차

### 이 repo (Phase 0, 5)
```
tofu fmt -recursive -check → tofu validate → tflint --recursive → trivy config . → tofu test
```
(`.githooks/pre-commit`·`pre-push`가 강제. `--no-verify` 미사용)

### 새 repo (Phase 1~4)
```
tofu fmt -recursive -check          # 로컬 + CI
tofu init -backend-config=backend.hcl   # partial (D25)
tofu validate
tflint --recursive
trivy config .
tofu plan                            # apply 전 마지막 게이트
bootstrap/verify.sh                  # 부트스트랩 drift (D21 완화책)
```

⚠️ `tofu test`는 새 repo에 없다 — 배포 루트는 모듈이 아니다. 계약 검증은 이 repo의
`modules/vpc/tests/plan.tftest.hcl`(12 passed)이 이미 담당한다.
