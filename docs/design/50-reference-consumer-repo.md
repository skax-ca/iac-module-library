# 50 · 레퍼런스 소비 repo (`iac-reference-infra`) 설계

> **신규 작성** (승계 문서 아님). 2026-07-30. 이 문서가 **D-CONSUME**이다.
> **선행 조건**: `vpc-v1.0.0` 릴리스 완료([`design/10` §3](10-vpc-module.md)).
> **범위**: 소비 경로 규약(모듈 소싱 인증 · state backend · OIDC 체인 · plan artifact)의 결정과 근거.
> 실행 계획(Phase·태스크·수용 기준)은 `.omc/plans/reference-consumer-repo.md`에 있다.

> 공통 규약: [02-naming-tagging-and-pinning.md](../architecture/02-naming-tagging-and-pinning.md) ·
> 엔진: [04-engine-decision.md](../architecture/04-engine-decision.md) ·
> 의존성: [03-dependencies.md](../architecture/03-dependencies.md)

---

## 0. 왜 실 고객사 repo보다 이것을 먼저 만드는가

`vpc-v1.0.0`의 증거는 **전부 `plan` 수준**이다([`design/10` §3](10-vpc-module.md)). 소비 경로에는
아직 한 번도 통과하지 않은 구간이 셋 있고, 셋 다 **첫 `apply`에서 터진다**:

1. private repo의 `git tag` 소싱 인증
2. state 버킷·OIDC Role의 부트스트랩 순서(닭-달걀)
3. OIDC `sub` claim 형태

고객 앞에서 처음 부딪히는 것과, 리허설에서 잡아 **템플릿으로 복사해 주는** 것은 완전히 다른 일이다.
그래서 `vpc` 하나만 배포하는 최소 소비 repo를 먼저 세운다.

> ⚠️ 이 repo는 **모듈만 소유**한다. 배포 루트는 소유하지 않는다. 이 문서가 정의하는 것은
> "소비 repo가 지켜야 할 계약"이고, 그 계약을 처음 이행하는 인스턴스가 `iac-reference-infra`다.

---

## 1. 실측으로 확정된 사실 (2026-07-30)

이 문서의 결정은 아래 값들에 의존한다. **추정이 아니라 실행해서 얻었다.**

| # | 사실 | 근거 |
|---|------|------|
| F1 | **private repo git tag 소싱은 로컬에서 이미 동작한다** | scratchpad에서 `tofu init` 성공. `credential.helper=osxkeychain`이 자격증명 공급 → **미해결은 CI 전용 문제로 축소** |
| F2 | `//modules/vpc`는 **clone 후 경로 선택**이다 | 로그가 `git::...iac-module-library.git?ref=vpc-v1.0.0`(서브디렉토리 없음)을 받아 `.terraform/modules/vpc/modules/vpc`에 배치 → CI는 **repo 전체**를 받는다 |
| F3 | org `skax-ca` 숫자 ID = **310520211** | `gh api orgs/skax-ca` |
| F4 | `iac-module-library` = **1315873255** (생성 2026-07-29) | `gh api repos/...`. ⚠️ 신뢰 정책이 쓰는 것은 **소비 repo의 ID**다 |
| F5 | `gh` 토큰은 **개인(silverte)** — `gist,read:org,repo,workflow` | `gh auth status` |
| F6 | AWS 계정 `533616270150`, 신원은 IAM **user** `silverte` (프로파일 **`team`**) | `aws sts get-caller-identity --profile team` |
| **F13** | ⚠️ **이 계정은 PoC 전용이 아니라 여러 사람이 쓰는 공용 개발 계정이다** | 실측(2026-07-30): VPC **23개**(`yg-` `jsh-` `pizza-` `cjh220-` `bae-` `lshdev-` `hj-` 등 12명 이상) · tfstate 버킷 **7개**(`kgkang-` `lsh-` `lyg-` `platform-…-koo` `ym-`). PoC repo `05` §7.1이 "최우선 주의"로 이미 등재했으나 **이 repo로 승계되지 않았었다** |
| **F14** | `AWSAFTExecution`은 `AdministratorAccess`이고, 신뢰 정책 principal이 **unique ID `AROAXYPQCDNDOM5Y4T6V3`로 치환**돼 현재 assume 불가 | `aws iam get-role --role-name AWSAFTExecution` · `list-attached-role-policies` |
| **F15** | GitHub Actions용 OIDC provider가 **없다**(EKS용 하나뿐, TFC용은 이미 삭제됨) | `aws iam list-open-id-connect-providers` |
| F7 | `use_lockfile`은 s3 backend의 **실재 인자**(`cty.Bool`, Optional) | OpenTofu v1.12 `internal/backend/remote-state/s3/backend.go:469` |
| F8 | ⚠️ **버저닝 버킷 + `use_lockfile=true` → lock 객체 버전 폭증** | `website/docs/.../s3.mdx:411-416`이 lifecycle로 버전 수 제한을 **권고** |
| F9 | **partial backend configuration** 지원 | `website/docs/language/settings/backends/configuration.mdx:93-139` |
| F10 | `actions/create-github-app-token` 최신 = **v3.2.0** (2026-05-12) | `gh api repos/.../releases/latest` |
| F11 | `aws-actions/configure-aws-credentials` 최신 = **v6.2.3** (2026-07-22) | 동일 |
| F12 | AWS는 **예측 불가능한 버킷명을 권장**한다 | S3 `bucketnamingrules.html` Best practices |

---

## 2. 결정

### D20 · CI git 소싱 인증 = GitHub App 토큰 + `insteadOf`

org 소유 GitHub App으로 1시간 만료 토큰을 발급하고, `git config --global ... insteadOf`로 주입한다.

```hcl
# 소비 repo 코드 — 인증 방식을 모른다
module "vpc" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/vpc?ref=vpc-v1.0.0"
}
```

```yaml
# CI에서만 주입
- uses: actions/create-github-app-token@v3.2.0     # F10
  id: app-token
  with:
    app-id: ${{ vars.MODULE_READER_APP_ID }}
    private-key: ${{ secrets.MODULE_READER_KEY }}
    owner: skax-ca
    repositories: iac-module-library
- run: |
    git config --global \
      url."https://x-access-token:${{ steps.app-token.outputs.token }}@github.com/".insteadOf \
      "https://github.com/"
- run: tofu init ...
```

**핵심 원칙: 소싱 URL은 `git::https://` 하나로 유지한다.** 소비 코드가 인증 방식을 모르게 하는 것이
[01 §2.1](../architecture/01-module-strategy.md)의 facade 원칙과 같은 사고다 — 인증 방식이 바뀌어도
`source` 한 줄은 그대로다.

- App 권한은 Repository → **Contents: Read-only** 하나. 설치 범위는 `iac-module-library` **1개로 한정**.
- 개인 계정 종속(F5)이 사라진다. 토큰은 1시간 만료라 유출 창이 좁다.

**기각안**

| 안 | 기각 이유 |
|----|----------|
| 모듈 repo public 전환 | 모듈 코드·설계 문서가 공개된다. `docs/consumer/*`에 PoC 계정 ID가 다수 남아 있어 선결 과제가 생긴다 |
| deploy key (SSH) | 소싱 URL이 로컬(HTTPS)과 CI(SSH)로 갈라진다. `insteadOf`로 흡수해도 결국 갈래가 하나 늘고, 키 로테이션이 수동이다 |

### D21 · 부트스트랩 = AWS CLI 스크립트 (IaC 밖)

`bootstrap/bootstrap.sh`가 aws CLI로 S3 버킷·OIDC provider·Role을 만든다. 닭-달걀이 성립하지 않는다.

> ⚠️ **이 선택으로 잃는 것** (사용자가 트레이드오프를 알고 선택했다):
> ① drift 감지 불가 ② 변경 이력이 `git diff`로 안 보임
> ③ "IaC 자산 라이브러리"인데 **가장 먼저 만드는 것이 IaC 밖에 있다.**
>
> 검토했던 대안은 `bootstrap/` 루트 + local state → 생성된 S3로 `init -migrate-state`였다.
> 자기 state를 든 버킷을 관리하는 순환은 `prevent_destroy`로 막을 수 있었다.

**필수 완화책** — 이것이 없으면 D21은 성립하지 않는다.

| 완화책 | 내용 | 왜 |
|--------|------|-----|
| **멱등성** | 재실행이 안전해야 한다. 존재하면 생성 대신 갱신, 이미 원하는 상태면 no-op | `apply`의 수렴 성질을 스크립트가 대신 제공해야 한다 |
| **기대 상태 명문화** | `bootstrap/README.md`에 생성 결과(리소스·이름·정책)를 표로 남긴다 | 이것이 `.tf`를 대체하는 SSOT다. 없으면 실제 상태가 유일한 진실이 된다 |
| **drift 감지 대체** | `bootstrap/verify.sh` (**read-only**)가 실제 ↔ 기대를 비교해 불일치를 exit 1로 낸다 | `plan`의 역할을 대신한다. ⚠️ **음성 테스트로 실제로 잡는지 증명**해야 한다 — 그렇지 않으면 완화책이 있다는 착각만 남는다 |
| **IaC 승격 경로** | `bootstrap/README.md`에 `import` 블록 초안 | 나중에 IaC로 올릴 때 처음부터 다시 설계하지 않게 |

### D22 · 디렉토리 = 목표 토폴로지 `live/dev/networking/`

[`consumer/multi-environment.md` §3](../consumer/multi-environment.md)의 계정×컴포넌트 구조를 그대로 쓴다.

```
iac-reference-infra/
├── bootstrap/                    # D21 — IaC 밖
│   ├── bootstrap.sh
│   ├── verify.sh
│   └── README.md                 # 기대 상태 + import 초안
├── live/dev/networking/          # VPC 하나
│   ├── main.tf                   # git tag 소싱 (D20)
│   ├── providers.tf              # default_tags + assume_role (2단 체인)
│   ├── versions.tf               # required_version >= 1.12.0 (vpc 하한)
│   ├── backend.tf                # backend "s3" {} — partial (D25)
│   ├── variables.tf / outputs.tf
│   └── .terraform.lock.hcl       # 커밋
└── .github/workflows/deploy.yml   # plan → 승인 → apply (§3)
```

dev 하나만 채운다. stg/prd·foundation 디렉토리는 만들지 않는다 — 계정이 하나(F6)여서 지금은
표현할 수 없고, 검증할 것이 없는 빈 자리다(YAGNI).

### D23 · `iamoidc` 약어 신설

`aws_iam_openid_connect_provider` → **`iamoidc`**. 카탈로그 311 → **312**
([`reference/aws-naming-abbreviations.md`](../reference/aws-naming-abbreviations.md) 개정 이력).

- IAM 계열 프리픽스(`iamr`·`iamp`) 유지 + OIDC 명시 → 향후 SAML은 `iamsaml`로 대칭 확장.
- 카탈로그가 이미 6자(`ecrpri`·`fmsrs`·`abkpol`)를 허용하므로 **L2 리소스 구분을 약어 길이보다 우선**했다.
- ⚠️ 이 리소스는 **식별자가 URL**이라 `name` 인자가 없다 → 이 이름은 `Name` **태그로만** 붙는다.
  inline 정책(`name`=식별자)과 정확히 반대 경우다.

### D24 · workload code = `ref`

3자로 짧아 32자 제한 리소스(ALB/TG)에 여유가 크고, 고객사 repo로 복사할 때 **바꿀 토큰이 명확**하다.
`examples/*`의 `acme`(가상값)와 겹치지 않아 실배포/예제 구분이 선다.

```
vpc-ref-dev-an2-main
snet-ref-dev-an2-app-uniq-a
iamr-ref-dev-an2-gha-entry-01
iamoidc-ref-dev-an2-gha
```

⚠️ 이 repo는 workload code를 고정하지 않는다(05 §5.4). `ref`는 **레퍼런스 인스턴스의 값**이고
모듈·규약에 들어가지 않는다.

### D25 · state 버킷 = partial backend configuration + GUID suffix

**버킷명이 git에 존재하지 않는다.**

```hcl
# live/dev/networking/backend.tf — 커밋된다
terraform {
  backend "s3" {}
}
```

주입 경로: CI는 GitHub repo 변수, 로컬은 **gitignore된** `backend.hcl`.

```bash
tofu init \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="key=dev/networking.tfstate" \
  -backend-config="region=ap-northeast-2" \
  -backend-config="use_lockfile=true"          # F7
```

실제 버킷명: `s3-ref-dev-an2-tfstate-<guid12>` (예: `s3-ref-dev-an2-tfstate-9f3c1a7b4e2d`).

**계정 ID를 배제한 근거**

| 근거 | 내용 |
|------|------|
| AWS 공식 Best practices | *"We recommend that you create bucket names that aren't predictable."* → 계정 ID는 이 권장에 **반한다** (F12) |
| AWS 공식 | *"Don't include sensitive information in the bucket name. The bucket name is visible in the URLs that point to the objects in the bucket."* |
| **이 프로젝트 특유** | `backend.tf`는 **고객사에 복사해 줄 템플릿**이다 → "private 버킷이니 이름이 안 보인다"는 논리가 성립하지 않는다 |
| 커뮤니티 | 계정 ID로 **IAM principal 열거**가 가능하다. AWS 공식은 "not sensitive"지만 defense-in-depth로 비밀 취급이 다수 의견 |

> ⚠️ **AWS 문서 내부의 충돌을 기록한다.** 같은 문서가 신기능 **account regional namespace**
> (`prefix-accountId-region-an`)를 *"only your account can ever own these bucket names"*를 근거로
> 권장하는데, 이는 **계정 ID를 이름에 강제**한다. 두 권장의 목적이 다르다 —
> 전자는 **스쿼팅 방지**, 후자는 **이름 소유권 보장**.
> **우리 축은 전자다**: 부트스트랩이 1회 생성 후 영구 보유하므로 스쿼팅 위험이 없고 노출만 문제다.
> **재검토 조건**: 버킷명 소유권 분쟁이 실제로 발생하면 `-an` 네임스페이스를 재평가한다.

> ⚠️ **감수하는 트레이드오프**: 어느 버킷을 가리키는지 **코드에서 안 보인다.** 이는
> [`consumer/multi-environment.md` §5](../consumer/multi-environment.md)가 TFC Working Directory에 대해
> 감수했던 것과 **같은 종류**다("리뷰·grep으로 안 보임"). 완화: `live/dev/networking/README.md`에
> 주입 변수명을 명시하고 `verify.sh`가 버킷 존재를 확인한다.

기각: 결정적 해시 suffix — 계정 ID 공간이 10^12뿐이라 노트북으로도 전수 해싱이 가능하다.
**해시가 보호가 되지 않는다.**

### D26 · 설계 문서 소유권 분리

미결 항목이던 "`design/30`의 소유권"에 대한 **부분 답**이다.

| 대상 | 위치 | 이유 |
|------|------|------|
| **소비 규약** — 모듈 소싱 인증 · backend 규약 · OIDC 체인 패턴 · plan artifact 규칙 | **이 repo** — 현행 SSOT는 **이 문서(`design/50`)** | 모든 소비 repo가 따라야 하는 **계약**이다. 소비 repo마다 복제하면 곧 drift다 |
| **그 repo 고유의 배포 사실** — 계정 ID · 버킷 GUID · Role ARN · 실측 `sub` 값 | 새 repo `docs/` | 재사용 자산이 아니라 인스턴스 값이다. 이 repo에 쓰면 05 §5.4(하드코딩 금지)를 위반한다 |
| **TFC 시절 잔재** — `docs/consumer/multi-environment.md` · `dynamic-credentials.md` | **이 repo** `docs/consumer/` (**보관**) | 아래 D26-1 참조. 규약의 SSOT가 **아니다** |

#### D26-1 · `docs/consumer/*`는 SSOT가 아니라 TFC 잔재다 (2026-07-30 정정, 사용자 결정)

**최초 D26은 "`docs/consumer/*`를 개정해 소비 규약의 SSOT로 삼는다"였다. 그 배정을 철회한다.**

- **사실과 맞지 않았다.** 두 문서는 `terraform-enterprise-poc` @ `76285f7`에서 온 **TFC 전제**다
  (`app.terraform.io` · `TFC_AWS_RUN_ROLE_ARN` · 워크스페이스 구조 등 32곳). GitHub Actions 기반
  소비 규약의 SSOT가 TFC 절차서일 수는 없다. 규약은 **이 문서가 D20~D29로 이미 소유**하고 있었다.
- **경쟁 SSOT는 그 자체로 drift다.** D26이 막으려던 것과 같은 종류의 위험을, 개정 예정 문서를
  SSOT로 선언함으로써 스스로 만들고 있었다.
- **삭제하지 않는다**(사용자 결정). `multi-environment.md`의 논증(디렉토리 구조 · divergence 3단 ·
  승격 게이트 · 안티패턴 근거)은 **도구 무관이라 여전히 유효**하고, 위 **D22**가 §3을 실제로 인용한다.
  `dynamic-credentials.md`는 대체물이 이미 실측 기반으로 존재하지만(소비 repo `CLAUDE.md` §4 ·
  `docs/deployment-facts.md` §3) **PoC 절차 기록으로 남긴다**.
- ⚠️ **잔재를 근거로 새 구현을 하지 않는다.** 인용해야 한다면 그 규칙이 도구 무관인지 먼저 확인한다.
- ⚠️ **`dynamic-credentials.md`에 PoC 계정 ID가 12곳 남아 있다.** 위 **D20 기각안**의
  "모듈 repo public 전환" 항목이 이것을 선결 과제로 등재하고 있다 — private인 동안의 **유예**이지
  해소가 아니다.

### ~~D27 · 실행 Role = 기존 `AWSAFTExecution` 재사용~~ → **철회 (D27-1로 대체)**

> **최초 D27**: 새 Role을 만들지 않고 `AWSAFTExecution`의 신뢰 정책을 `update-assume-role-policy`로
> **전체 교체**한다. 근거는 "새 Role을 만들면 기존 것이 고아로 남는다" + AFT 구조 선반영이었다.
> **F13(공용 계정) 실측으로 철회한다** — 아래.

### D27-1 · 실행 Role을 **신설**한다. `AWSAFTExecution`은 건드리지 않는다 (2026-07-30, 사용자 결정)

| | 최초 D27 | **D27-1 (확정)** |
|---|---|---|
| `AWSAFTExecution` | 신뢰 정책 **전체 교체** | **손대지 않는다** (읽지도 쓰지도 않음) |
| 실행 Role | 위를 재사용 | **신설** `iamr-ref-dev-an2-gha-exec-01` |
| 입구 Role | `iamr-ref-dev-an2-gha-entry-01` (신규) | **동일** |

**철회 근거 — F13이 전제를 무너뜨린다**

- `update-assume-role-policy`는 **전체 교체**다. 병합이 아니라 덮어쓰기이므로, `AWSAFTExecution`을
  쓰는 다른 주체가 있으면 **말없이 끊는다.** 공용 계정에서는 그 주체를 우리가 알 수 없다.
  `AWSAFTExecution`은 **AFT 표준 이름**이라 우리 PoC 말고도 용도가 있을 수 있다.
- 되돌리기 어렵다: 교체 전 정책을 백업해도, 그 사이 끊긴 다른 파이프라인은 이미 실패한 뒤다.
- "고아로 남는다"는 원래 근거는 **비용이 아니라 미관**이다. 공용 계정에서 남의 Role을 갈아엎는
  리스크와 교환할 만한 것이 아니다.
- ⚠️ **F14의 "assume 불가" 문제는 이로써 해결 대상이 아니라 무관해진다.** 우리는 그 Role을
  쓰지 않는다. `AWSAFTExecution`은 **깨진 채로 그대로 둔다** — 고치는 것도 남의 자산 변경이다.

**신설 Role 사양**

| 항목 | 값 |
|------|-----|
| 이름 | `iamr-ref-dev-an2-gha-exec-01` (`Name` 태그 동일) |
| 신뢰 | 입구 Role `iamr-ref-dev-an2-gha-entry-01` **하나만** (계정 루트 아님 — 넓히면 계정 내 누구나 assume) |
| 권한 | `AdministratorAccess` (아래 단서) |

- ⚠️ **권한 축소는 하지 않되 열린 항목으로 등재한다**([§5](#5-열린-항목)). VPC 하나에 맞춰 최소권한을
  도출하면 EKS 단계에서 다시 해야 하고, 그 비용을 지금 치를 이유가 없다. **대신 신뢰 경계를 좁혔다** —
  AFT 구조 선반영이라는 원래 의도는 **이름 규약**(`AWSAFT*`와 무관한 우리 네임스페이스)으로 대체한다.
- **공용 계정 운영 규칙은 D27-2가 정한다.**

### D27-2 · 공용 계정(F13) 운영 규칙 — PoC `05` §7.1 승계

`AdministratorAccess`를 **자동 트리거**에 연결한다는 것이 PoC와의 실질적 차이다.
PoC에서는 사람이 TFC workspace에서 돌렸다. 이제 `pull_request`가 `plan`을 자동 실행한다.

| 규칙 | 내용 |
|------|------|
| **삭제 대상 사람 검토** | apply 승인 전 plan의 **destroy/replace 목록을 사람이 읽는다.** 공용 계정이므로 예외 없음(`05` §7.1 원문) |
| **대상 판별은 태그로** | 우리 자산은 `Workload=ref` 태그로 식별한다. 이름만 보고 판단하지 않는다 |
| **apply는 승인 게이트 필수** | Environment protection rules. 이것이 §7.1의 "사람이 검토"를 이행하는 지점이다 |
| **plan은 자동이어도 된다** | 리소스를 만들지 않는다. ⚠️ 단 state lock을 잡고 read 권한이 Administrator다([§5](#5-열린-항목) D28 열린 항목과 같은 지점) |
| **`prevent_destroy` 유지** | VPC 모듈 D12. 공용 계정에서 실수 삭제의 마지막 방어선이다 |

⚠️ **다른 사람의 리소스는 plan에도 나타나지 않는다** — 우리 state에 없기 때문이다. 위험은
"plan에 잡히는 것"이 아니라 **`AdministratorAccess`가 손댈 수 있는 범위 전체**다. 규칙이 필요한 이유다.

### D28 · 신뢰 정책은 `sub` 패턴 3개를 가진다

**plan job과 apply job의 `sub`가 다르다.** 놓치기 쉬운 지점이다 — `environment:`를 선언한 job만
`:environment:<name>`을 받는다.

| job | 트리거 | 예상 `sub` | 상태 |
|-----|--------|-----------|------|
| PR plan | `pull_request` | `...:pull_request` | ⚠️ **실측 예정** |
| main plan | `push` → `main` | `...:ref:refs/heads/main` | ⚠️ 동일 |
| apply | `environment: dev` | `...:environment:dev` | ⚠️ 동일 |

- **immutable `sub` 형태를 추정하지 않는다.** repo가 2026-07-15 이후 생성되면 `sub`가 이름이 아니라
  숫자 org/repo ID를 쓴다고 알려져 있으나(`repo:<org>@<org_id>/<repo>@<repo_id>:...`),
  **실제 JWT claim을 출력해 확정한 뒤** 신뢰 정책을 쓴다. org ID는 확정됐다(F3=`310520211`);
  repo ID는 소비 repo 생성 후 조회한다.
- **plan/apply 권한을 분리하지 않는다** — `tofu plan`도 state lock을 잡아 S3 쓰기가 필요하므로
  "plan은 read-only"가 성립하지 않는다. 실행 Role 하나를 유지하고 §5 열린 항목으로 남긴다.

### D29 · lock 객체 버전 폭증 방어

버저닝은 state 보호에 필수인데 `use_lockfile=true`가 lock 객체 버전을 폭증시킨다(F8).
`bootstrap.sh`가 **lifecycle 규칙**을 함께 만든다 — 비현행 버전 보관 기간을 짧게(예: 7일) 두고
불완전 멀티파트 업로드를 정리한다. **공식 문서가 직접 권고한 대응이다.**

---

## 3. 워크플로 — "승인한 계획 = 적용된 계획"

[`CLAUDE.md` 실행 기반](../../CLAUDE.md) 요건을 **한 워크플로 두 job**으로 만족시킨다.
별도 워크플로로 쪼개면 artifact를 run 경계 밖에서 찾아야 하고, **그 조회 지점이 곧 구멍**이다.

```
deploy.yml
├─ on: pull_request  (paths: live/dev/networking/**)  → plan job 만
├─ on: push → main   (paths: 동일)                     → plan job → apply job
├─ concurrency: {group: live-dev-networking, cancel-in-progress: false}
│
├─ job: plan     permissions: {id-token: write, contents: read, pull-requests: write}
│   1. create-github-app-token@v3.2.0        (D20)
│   2. git config insteadOf                  (D20)
│   3. configure-aws-credentials@v6.2.3      → 입구 Role      ← OIDC 1단
│   4. tofu init -backend-config=...         (D25)
│   5. tofu plan -out=tfplan                 → provider assume_role  ← 체인 2단
│   6. upload-artifact (tfplan, retention-days: 1)
│
└─ job: apply    needs: plan · if: push→main · environment: dev   ← 승인 게이트
    1~4. plan job과 동일 (자격증명은 job 간 이동 불가하므로 재수행)
    5. download-artifact (같은 run의 tfplan)
    6. tofu apply tfplan                     ← 재-plan 하지 않는다
```

- **2단 체인**: `configure-aws-credentials`가 입구 Role(`iamr-ref-dev-an2-gha-entry-01`)을 OIDC로
  인증 → provider의 `assume_role`이 실행 Role(`iamr-ref-dev-an2-gha-exec-01`)을 체인 assume.
  정적 키 없음. ⚠️ **`AWSAFTExecution`이 아니다** — D27-1로 실행 Role이 신설로 바뀌었다.
- ⚠️ **apply 승인 시 destroy/replace 목록을 사람이 읽는다**(D27-2). 공용 계정(F13)이라 예외 없음.
- ⚠️ **plan artifact는 민감할 수 있다** — plan 파일에 리소스 속성이 평문으로 들어간다.
  repo read 권한자가 받을 수 있으므로 `retention-days: 1`로 제한하고 소비 규약에 명시한다.
- ⚠️ **역할 체인 세션은 최대 1시간**(연장 불가). apply job이 다시 인증하므로 승인 지연 자체는
  문제없다. 다만 그 사이 state가 바뀌면 `apply`가 거부한다 — **정상 동작**이고 재-plan이 필요하다.

---

## 4. 이 설계가 판정하는 `vpc-v1.0.0` 미검증 항목

[`design/10` §3](10-vpc-module.md)의 apply 미검증 6항목.

| # | 항목 | 판정 시점 |
|---|------|----------|
| 1 | secondary CIDR `depends_on` 순서 | 후속 apply 시나리오 |
| 2 | primary/secondary 조합 제약 | 후속 apply 시나리오 |
| 3 | CIDR 겹침 | 후속 apply 시나리오 |
| 4 | Flow Logs 실제 배달 | 후속 apply 시나리오 |
| 5 | `prevent_destroy` 실동작 (D12) | 후속 apply 시나리오 |
| 6 | **`git tag` 소싱 경로** | **첫 CI `init` 성공 자체** |

> ⚠️ **VPC 하나를 minimal 구성으로 apply하는 것만으로는 1~5가 판정되지 않는다.**
> 첫 apply는 6번과 minimal 경로만 판정한다. 이 구분을 흐리면 "apply로 검증했다"는 과잉 주장이 되고,
> 그것이 [`reference/poc-findings.md`](../reference/poc-findings.md)가 경계하는 실수다.

---

## 5. 열린 항목

1. **plan/apply 권한 분리** — `tofu plan`도 state lock을 잡아 read-only가 성립하지 않는다(D28).
   별도 lock 전략이 필요한지
2. **`?depth=1` 소싱** — CI `init`이 repo 전체를 clone한다(F2). 지금은 문제 아니지만
   태그·히스토리 증가 시 실측 후 판단
3. **`bootstrap`의 IaC 승격 시점** — `import` 경로는 남기되 언제 올릴지 미정(D21)
4. **stg/prd 확장** — 계정이 하나(F6)라 지금은 표현 불가. 별도 계정 확보 후
5. **[`design/30-gitops-repo.md`](30-gitops-repo.md) 소유권** — D26이 부분 답.
   GitOps hub는 이 결정 범위 밖이다
6. **plan artifact 암호화** — `retention-days: 1`은 완화이지 해결이 아니다
7. **실행 Role 권한 축소** — `iamr-ref-dev-an2-gha-exec-01`이 `AdministratorAccess`다(D27-1).
   공용 계정(F13)이라 축소 이득이 크지만, VPC 하나에 맞춰 도출하면 EKS 단계에서 다시 해야 한다.
   **판단 시점 = 모듈 집합이 안정된 뒤**(최소 EKS 모듈 이식 후). 그때까지는 D27-2의 운영 규칙이 완화책이다
8. **`AWSAFTExecution`의 깨진 신뢰 정책** — principal이 unique ID로 치환된 상태로 방치된다(F14).
   우리가 안 쓰기로 했으므로(D27-1) **우리 문제가 아니다.** 계정 소유자가 판단할 사안이라 여기 남긴다

---

## 6. 참고 자료

- [S3 general purpose bucket naming rules (Best practices · GUID)](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html)
- [OpenTofu — Backend Partial Configuration](https://opentofu.org/docs/language/settings/backends/configuration/)
- [OpenTofu — S3 backend (`use_lockfile`)](https://opentofu.org/docs/language/settings/backends/s3/)
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- [My AWS Account ID Got Leaked — Should I Panic? (AWS re:Post)](https://repost.aws/articles/ARZTqjdG30SwCuMwApp4stlQ/my-aws-account-id-got-leaked-should-i-panic)
- [Plerion — The Final Answer: AWS Account IDs Are Secrets](https://www.plerion.com/blog/the-final-answer-aws-account-ids-are-secrets)
