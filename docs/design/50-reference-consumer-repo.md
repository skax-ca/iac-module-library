# 50 · 레퍼런스 소비 repo (`iac-reference-infra`) 설계

> **신규 작성** (승계 문서 아님). 2026-07-30. 이 문서가 **D-CONSUME**이다.
> **선행 조건**: `vpc-v1.0.0` 릴리스 완료([`design/10` §3](10-vpc-module.md)).
> **범위**: 소비 경로 규약(모듈 소싱 인증 · state backend · OIDC 체인 · plan artifact)의 결정과 근거.
> 실행 계획(Phase·태스크·수용 기준)은 `.omc/plans/reference-consumer-repo.md`에 있다.

> ⚠️ **2026-08-05 D-VERSION 재매핑** — `vpc-v1.0.0`·`v1.1.0`·`v1.2.0` → **같은 커밋의**
> `v0.1.0`·`v0.2.0`·`v0.3.0`, `eks-cluster-v1.0.0` → `v0.1.0`. 구 태그는 삭제됐다
> ([`architecture/05`](../architecture/05-versioning-policy.md)).
> **이 문서의 §1 배경·F계열 실측 로그·§4 판정 대상에 남은 `v1.x` 번호는 그때의 사실 기록이라
> 그대로 둔다** — 특히 `F2`는 당시 `init` 로그 원문이고, `§4`는 *"어느 릴리스의 미검증 항목을
> 판정했는가"* 를 기록한다. 번호를 덮어쓰면 그 추적이 끊긴다.

> ### 🔄 2026-07-31 개정 — 첫 이행 인스턴스가 **apply까지 통과했다**
>
> `skax-ca/iac-reference-infra`가 §3의 파이프라인으로 실제 계정에 apply를 완료했다
> (`66 added` → 두 번째 apply `No changes`). **이 문서의 규약이 처음으로 실행 증거를 얻었다.**
>
> 그 과정에서 **설계에 없던 것 4건**(F16~F19)과 **설계의 빈틈 1건**이 드러났다:
>
> | 무엇 | 어디 |
> |------|------|
> | 🔴 **§3의 2단 체인 그림에 backend 경로가 빠져 있었다** — 첫 CI plan이 여기서 죽었다 | **D30**(신설) · §3 |
> | ⚠️ D27-2의 승인 게이트는 **GitHub Team 이상을 전제**한다. Free private repo에서는 이행 불가 | D27-2 전제 조건 |
> | ⚠️ 실계정에는 **자동 태거**가 있다 → `ignore_tags`가 선택이 아니다 | F16 |
> | ⚠️ repo 변수는 CI 로그에 **평문**으로 남는다 | F19 · §5 |
> | §4의 "첫 apply는 minimal 경로만 판정한다"는 **형상 의존**이었다 | §4 |
>
> **인스턴스의 값과 로그는 여기 적지 않는다**(D26) — 소비 repo `docs/deployment-facts.md`가 소유한다.

> 공통 규약: [02-naming-tagging-and-pinning.md](../architecture/02-naming-tagging-and-pinning.md) ·
> 엔진: [04-engine-decision.md](../architecture/04-engine-decision.md) ·
> 의존성: [03-dependencies.md](../architecture/03-dependencies.md)

---

## 0. 왜 실 고객사 repo보다 이것을 먼저 만드는가

`vpc-v1.0.0`의 증거는 **전부 `plan` 수준**이었다([`design/10` §3](10-vpc-module.md)). 소비 경로에는
한 번도 통과하지 않은 구간이 셋 있었고, 셋 다 **첫 `apply`에서 터진다**:

1. private repo의 `git tag` 소싱 인증
2. state 버킷·OIDC Role의 부트스트랩 순서(닭-달걀)
3. OIDC `sub` claim 형태

고객 앞에서 처음 부딪히는 것과, 리허설에서 잡아 **템플릿으로 복사해 주는** 것은 완전히 다른 일이다.
그래서 `vpc` 하나만 배포하는 최소 소비 repo를 먼저 세운다.

> ### ✅ 셋 다 통과했다 (2026-07-31) — 그리고 **넷째가 있었다**
>
> 1·2·3은 첫 이행 인스턴스에서 전부 실측으로 종결됐다. 그런데 **설계가 예상하지 못한 구간이
> 하나 더 있었다**: **backend의 자격증명 경로**(F17 → **D30**). `tofu init`은 provider보다 먼저
> backend로 state를 읽는데, 그 경로에는 provider 설정이 적용되지 않는다.
>
> **이 문단이 이 repo를 먼저 만든 이유를 스스로 증명한다.** 셋을 예상했고 넷째에 걸렸다 —
> 고객 앞이 아니라 리허설에서 걸렸다는 것이 정확히 §0이 노린 값이다.

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
| F6 | **AWS 계정이 하나뿐이다.** 신원은 IAM **role**이 아니라 **user**다 | `aws sts get-caller-identity`. ⛔ **계정 ID는 여기 적지 않는다** — 값은 소비 repo `docs/deployment-facts.md` §2가 소유한다(D26 · D25 연장) |
| **F13** | ⚠️ **이 계정은 PoC 전용이 아니라 여러 사람이 쓰는 공용 개발 계정이다** | 실측(2026-07-30): VPC **23개** · tfstate 버킷 **7개**가 다른 사람들 것이고 소유자는 **12명 이상**이다. PoC repo `05` §7.1이 "최우선 주의"로 이미 등재했으나 **이 repo로 승계되지 않았었다** |
| **F14** | `AWSAFTExecution`은 `AdministratorAccess`이고, 신뢰 정책 principal이 **삭제된 주체의 unique ID로 치환**돼 현재 assume 불가 | `aws iam get-role --role-name AWSAFTExecution` · `list-attached-role-policies` |

> ⛔ **이 표에 인스턴스 값을 적지 않는다** (2026-07-31 정정). 여기는 **규약 SSOT**라 고객사에
> 인용된다. 초판은 계정 ID·동료들의 리소스 prefix·남의 Role의 unique principal ID를 적어 두었는데,
> 세 결정(F6→D22 · F13→D27-1/D27-2 · F14→D27-1) 중 **어느 것도 그 값을 필요로 하지 않는다.**
> F13이 뒷받침하는 것은 *"공용이다"* 이고 그 근거는 **개수**이지 누구인지가 아니다.
| **F15** | GitHub Actions용 OIDC provider가 **없다**(EKS용 하나뿐, TFC용은 이미 삭제됨) | `aws iam list-open-id-connect-providers` |
| F7 | `use_lockfile`은 s3 backend의 **실재 인자**(`cty.Bool`, Optional) | OpenTofu v1.12 `internal/backend/remote-state/s3/backend.go:469` |
| F8 | ⚠️ **버저닝 버킷 + `use_lockfile=true` → lock 객체 버전 폭증** | `website/docs/.../s3.mdx:411-416`이 lifecycle로 버전 수 제한을 **권고** |
| F9 | **partial backend configuration** 지원 | `website/docs/language/settings/backends/configuration.mdx:93-139` |
| F10 | `actions/create-github-app-token` 최신 = **v3.2.0** (2026-05-12) | `gh api repos/.../releases/latest` |
| F11 | `aws-actions/configure-aws-credentials` 최신 = **v6.2.3** (2026-07-22) | 동일 |
| F12 | AWS는 **예측 불가능한 버킷명을 권장**한다 | S3 `bucketnamingrules.html` Best practices |

### 첫 apply에서 추가된 실측 (2026-07-31)

| # | 사실 | 근거 | 어느 결정을 바꾸나 |
|---|------|------|------------------|
| **F16** | ⚠️ **실계정에는 자동 태거가 돈다.** 생성 주체(CloudFormation·Terraform·콘솔)와 **무관하게** 동일 키가 붙는다 | 대상 계정 전수 조회: VPC **22/23** · Subnet **78/82** · IGW **16/17**에 7개 키(`CreationTime`·`Creator`·`cz-*`). 우리가 만든 VPC에도 apply 직후 붙었다 | `ignore_tags`가 **선택이 아니다**. [02 §1.4(a-2)](../architecture/02-naming-tagging-and-pinning.md)의 경고가 실증됐다 |
| **F17** | 🔴 **S3 backend는 provider와 독립적으로 자격증명을 해결한다.** provider의 `assume_role`이 backend에 적용되지 않는다 | OpenTofu 공식 s3 backend 문서 + 실패 실측(`init`이 `HeadObject 403`) | **D30 신설** — §3의 체인 그림에 backend 경로가 없었다 |
| **F18** | ⚠️ **GitHub Free + private repo는 Environment protection rules를 쓸 수 없다.** required reviewers·wait timer 모두 `422 billing`. **deployment branch policy만** 걸린다 | 규칙별로 하나씩 PUT 시도해 경계를 확정 | **D27-2의 전제 조건** — 승인 게이트는 Team 이상을 요구한다 |
| **F19** | ⚠️ **repo 변수(`vars.*`)는 CI 로그에 평문으로 남는다.** GitHub은 **secret만** 마스킹한다 | 워크플로 로그에 `-backend-config="bucket=…"`이 그대로 출력됨 | D25의 "🙈 비노출"이 **git 밖에서는 보장되지 않는다** → [§5](#5-열린-항목) |

> ℹ️ **F17은 `-backend-config` 주입 방식까지 바꾼다.** `-backend-config=KEY=VALUE` 플래그는
> **문자열 값만** 받는데 `assume_role`은 객체다 → **HCL 파일이 유일한 경로**다(D30).

---

## 2. 결정

### D20 · CI git 소싱 인증 = GitHub App 토큰 + `insteadOf`

org 소유 GitHub App으로 1시간 만료 토큰을 발급하고, `git config --global ... insteadOf`로 주입한다.

```hcl
# 소비 repo 코드 — 인증 방식을 모른다
module "vpc" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/vpc?ref=vpc-v0.3.0"
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
| 모듈 repo public 전환 | 모듈 코드·설계 문서가 공개된다. ✅ **선결 과제이던 "PoC 계정 ID 다수"는 해소됐다**(2026-07-31 — `docs/consumer/*` 12곳 치환 · 이 문서 F6/F13/F14 정리). 남은 기각 근거는 **설계 문서 공개 자체**다 |
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

`AdministratorAccess`를 **자동 트리거**에 연결한다는 것이 PoC와의 실질적 차이였다.
PoC에서는 사람이 TFC workspace에서 돌렸다.
⚠️ **2026-08-03(D30-1) 이후 이 차이가 줄었다** — apply 가 `workflow_dispatch` 전용이 되어
**적용 자체는 다시 사람의 행위**가 됐다. 자동인 것은 plan 까지다. 다만 실행 Role 이 여전히
`AdministratorAccess`이므로 아래 규칙은 그대로 유효하다.

| 규칙 | 내용 |
|------|------|
| **삭제 대상 사람 검토** | apply 승인 전 plan의 **destroy/replace 목록을 사람이 읽는다.** 공용 계정이므로 예외 없음(`05` §7.1 원문) |
| **대상 판별은 태그로** | 우리 자산은 `Workload=<code>` 태그로 식별한다. 이름만 보고 판단하지 않는다 |
| **apply는 승인 게이트 필수** | Environment protection rules. 이것이 §7.1의 "사람이 검토"를 이행하는 지점이다. ⚠️ **전제 조건이 있다 — 아래** |
| **plan은 자동이어도 된다** | 리소스를 만들지 않는다. ⚠️ 단 state lock을 잡고 read 권한이 Administrator다([§5](#5-열린-항목) D28 열린 항목과 같은 지점) |
| **`prevent_destroy` 유지** | VPC 모듈 D12. 공용 계정에서 실수 삭제의 마지막 방어선이다 |

#### ⚠️ D27-2의 전제 조건 — 승인 게이트는 **GitHub Team 이상**을 요구한다 (2026-07-31, F18)

**"apply는 승인 게이트 필수"는 플랜에 따라 이행할 수 없다.** 첫 이행 인스턴스에서 실측했다:

| protection rule | Free + private repo |
|-----------------|--------------------|
| required reviewers | ❌ `422 … billing plan supports the required reviewers protection rule` |
| wait timer | ❌ `422 … wait timer protection rule` |
| **deployment branch policy** | ✅ 적용됨 |

**소비 repo를 세울 때 가장 먼저 확인할 항목이다.** 실 고객사는 대부분 Team/Enterprise이므로
정상 경로가 성립하지만, **리허설·PoC·개인 org에서는 성립하지 않는다.**

**Free에서의 대체 운영 형태 — ⛔ 구 형태(2026-08-03 D30-1로 교체됨, 되살리지 말 것)**

```
PR 생성 → plan 자동 실행 → PR 댓글에 destroy/replace 목록 + plan 전문
       → 사람이 읽고 merge          ← 검토 지점 (강제력 없음)
       → push:main → plan → apply   ← 대기 없이 진행
```

- ✅ 유지: `environment:` 선언(→ `sub` 패턴 ③ 일치) · deployment branch policy
- ❌ 상실: **"읽어야 진행된다"는 강제력.** merge 권한자와 apply 승인자가 분리되지 않는다
- 완화: plan job이 `will be destroyed`·`must be replaced`를 **전문 위로 끌어올려** PR 댓글에 남긴다.
  ⚠️ *"읽을 수 있게 한다"* 이지 *"읽어야 진행된다"* 가 아니다 — 이 구분을 흐리지 않는다.

> ### 🆕 D30-1 (2026-08-03) · PR plan 제거 + apply 는 `workflow_dispatch` 로만
>
> **계기는 속도였다** — PR 에서 plan, merge 에서 다시 plan→apply 로 같은 계산을 두 번 하고
> 그만큼 배포가 느렸다. 사용자 결정으로 `pull_request` 트리거를 제거했다.
>
> ⚠️ **그런데 PR plan 만 빼면 위 형태에서 마지막 남은 검토 지점까지 사라진다.** 그 지점은
> 강제력이 없었을 뿐 *"사람이 계획을 보는 유일한 자리"* 였다. 없애면 아무도 읽지 않은 계획이
> `AdministratorAccess`(D27-1)로 공용 계정(F13)에 적용된다 = **D27-2 "예외 없음" 정면 위반.**
> → apply 를 `workflow_dispatch` 전용으로 바꿔 **사람의 실행 행위를 승인으로 삼는다.**
>
> ```
> merge → push:main → plan 만 실행 (요약이 run Summary 에)
>       → 사람이 읽는다
>       → Run workflow → 같은 run 안에서 plan → apply     ← 누르지 않으면 적용되지 않는다
> ```
>
> **⭐ 위 구 형태가 "❌ 상실"로 적은 것을 되찾았다.** 무료 플랜에서도 **"읽어야 진행된다"** 가
> 성립한다 — dispatch 를 누르지 않으면 apply 는 일어나지 않기 때문이다. 열화를 감수한 형태가
> 아니라 **더 강한 형태**이며, 유료 승인 게이트가 없는 것을 사람의 행위로 대체한 구조다.
> ⚠️ 다만 **merge 권한자와 apply 실행자는 여전히 분리되지 않는다** — 그건 required reviewers 만이 준다.
>
> **⚠️ 잔여 간극**: 사람이 읽는 plan(push run)과 적용되는 plan(dispatch run)이 **다른 run** 에서
> 만들어진다. 그 사이 state 가 바뀌면 갈라질 수 있다. run 경계를 넘어 artifact 를 가져오는 쪽이
> 더 나쁘므로(§3 "그 조회 지점이 곧 구멍") 이 구조를 택했다.
> 🔑 **상위 요금제 구독 시 이 간극이 사라진다** — required reviewers 는 승인을 **같은 run 안**으로
> 들여오므로, `apply` 의 `if:` 를 `(push || workflow_dispatch)` 로 되돌리면 된다.
>
> **부수 효과**: 소비 repo 에 `deploy.yml` 외 워크플로가 없어 **PR 에 CI 가 없어졌다.**
> 깨진 HCL 은 merge 후 main push 의 plan 에서 실패한다 — 시끄럽고 복구 가능하지만 사전 차단은 없다.
> **열린 항목**: 입구 Role 신뢰 정책의 `sub` 패턴 ①(`...:pull_request`)이 미사용이 됐다.
> 트리거가 없어 토큰이 발급되지 않으니 무해하나 최소권한 관점에선 제거 대상이다(라이브 IAM 변경).

> ℹ️ **걸린 하나가 D28의 미해결 제약을 메운다.** `environment`가 `sub`의 `ref`를 덮어써
> **apply job의 브랜치 제한을 `sub`로 걸 수 없는데**(D28 실측), deployment branch policy가
> 그 자리를 맡는다. IAM에서 표현 불가능한 조건을 GitHub 레이어가 대신 거는 구조다.

⚠️ **다른 사람의 리소스는 plan에도 나타나지 않는다** — 우리 state에 없기 때문이다. 위험은
"plan에 잡히는 것"이 아니라 **`AdministratorAccess`가 손댈 수 있는 범위 전체**다. 규칙이 필요한 이유다.

### D28 · 신뢰 정책은 `sub` 패턴 3개를 가진다

**plan job과 apply job의 `sub`가 다르다.** 놓치기 쉬운 지점이다 — `environment:`를 선언한 job만
`:environment:<name>`을 받는다.

| job | 트리거 | 예상 `sub` | 상태 |
|-----|--------|-----------|------|
| ~~PR plan~~ | ~~`pull_request`~~ | `...:pull_request` | ⛔ **미사용**(D30-1, 2026-08-03) — 신뢰 정책엔 남아 있다 |
| main plan | `push` → `main` | `...:ref:refs/heads/main` | ⚠️ 동일 |
| dispatch plan | `workflow_dispatch` → `main` | `...:ref:refs/heads/main` | ✅ **패턴 ②가 커버**(신뢰 정책 실물 확인) — 값 자체는 첫 dispatch run 에서 확인 |
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

### D30 · backend도 실행 Role을 체인 assume한다 (2026-07-31 신설 — 첫 apply가 강제한 결정)

**D28까지의 체인 그림에는 backend가 없었다.** 그 누락이 첫 CI `plan`을 죽였다.

```
Successfully configured the backend "s3"!
Error: Error refreshing state
  operation error S3: HeadObject, https response error StatusCode: 403
```

**원인 — 두 개의 자격증명 경로가 있다(F17).**

| 무엇이 AWS를 호출하나 | 자격증명 출처 | 결과 |
|---------------------|-------------|------|
| `aws` **provider** | provider 블록의 `assume_role` | ✅ 실행 Role |
| **backend**(state 읽기·lock) | **환경 자격증명** — provider 설정과 무관 | ❌ **입구 Role 그대로** |

입구 Role의 권한은 D27-1이 의도적으로 `sts:AssumeRole` **하나로** 좁혀 두었다. 그래서
backend가 S3를 읽을 수 없다. ⚠️ **설계를 어겨서가 아니라 설계대로 만들어서 실패한다** —
모든 소비 repo가 첫 CI run에서 똑같이 부딪힌다.

**결정: `backend.hcl`에 `assume_role`을 넣어 backend도 같은 실행 Role을 체인 assume한다.**

```hcl
# CI 가 repo 변수로 조립한다. 파일명이 .gitignore 대상이라 커밋될 수 없다(D25 와 같은 방어).
bucket       = "<repo 변수>"
key          = "<env>/<component>.tfstate"
region       = "<region>"
use_lockfile = true

assume_role = {
  role_arn     = "<실행 Role ARN — repo 변수>"
  session_name = "tofu-backend-<run_id>"
}
```

- ⚠️ **`-backend-config=KEY=VALUE` 플래그로는 불가능하다.** 문자열 값만 받는데 `assume_role`은
  객체다(F17) → **파일이 유일한 경로**다. 부수 효과로 CI와 로컬이 같은 명령
  (`tofu init -backend-config=backend.hcl`)을 쓰게 된다.
- ⚠️ **plan job과 apply job 양쪽에 필요하다.** 자격증명과 `.terraform/`은 job 경계를 넘지 못해
  apply job이 `init`을 새로 한다 — 거기 빠지면 apply가 같은 403으로 죽는다.
- ℹ️ 로컬은 `assume_role`을 **넣지 않는다.** 개인 자격증명이 실행 Role을 assume할 수 없고
  (신뢰가 입구 Role 하나뿐, D27-1) 버킷 자체는 그 권한으로 읽힌다.

**기각안**

| 안 | 기각 이유 |
|----|----------|
| **입구 Role에 state 버킷 접근 권한을 추가** | *"입구 Role의 권한은 실행 Role assume 하나뿐"* 이라는 **D27-1의 신뢰 경계가 깨진다.** 입구 Role은 OIDC로 직접 도달 가능한 지점이라, 거기에 권한을 얹으면 2단 체인이 만든 격리가 그만큼 줄어든다 |
| `configure-aws-credentials`의 role chaining으로 **환경 자격증명 자체를 실행 Role로** | backend·provider가 한 번에 해결되지만, 워크플로가 실행 Role을 **직접** 들게 된다. 입구 Role이 "OIDC가 도달하는 유일한 지점"이라는 성질이 흐려진다. 재검토 여지는 있다 → [§5](#5-열린-항목) |

> ⚠️ **이 결정은 "state를 읽는 주체 = 리소스를 만드는 주체"를 명시한다.** 둘이 갈리면
> 권한 분석이 두 배가 된다. D28이 plan/apply 권한을 분리하지 않은 것과 같은 사고다.

---

## 3. 워크플로 — "승인한 계획 = 적용된 계획"

[`CLAUDE.md` 실행 기반](../../CLAUDE.md) 요건을 **한 워크플로 두 job**으로 만족시킨다.
별도 워크플로로 쪼개면 artifact를 run 경계 밖에서 찾아야 하고, **그 조회 지점이 곧 구멍**이다.

> ⛔ **2026-08-03 개정(D30-1)** — 아래 도식의 `pull_request` 줄과 `apply if: push→main`은
> **더 이상 유효하지 않다.** 개정 후 형태는 이 절 뒤의 D30-1 상자에 있다. 도식은 이력으로 남긴다.

```
deploy.yml
├─ on: pull_request  (paths: live/dev/networking/**)  → plan job 만     ← ⛔ 제거됨(D30-1)
├─ on: push → main   (paths: 동일)                     → plan job → apply job
├─ concurrency: {group: live-dev-networking, cancel-in-progress: false}
│
├─ job: plan     permissions: {id-token: write, contents: read, pull-requests: write}
│   1. create-github-app-token@v3.2.0        (D20)
│   2. git config insteadOf                  (D20)
│   3. configure-aws-credentials@v6.2.3      → 입구 Role      ← OIDC 1단
│   4. backend.hcl 조립 (repo 변수 → 파일)   (D25 + D30)
│        · bucket/key/region/use_lockfile
│        · assume_role = { role_arn = 실행 Role }   ← 체인 2단 ⓐ backend
│   5. tofu init -backend-config=backend.hcl
│   6. tofu plan -out=tfplan                 → provider assume_role ← 체인 2단 ⓑ provider
│   7. plan 요약 → PR 댓글 (destroy/replace를 위로) (D27-2)
│   8. upload-artifact (tfplan, retention-days: 1)
│
└─ job: apply    needs: plan · if: push→main · environment: <env>  ← 승인 게이트
    1~5. plan job과 동일 (자격증명·.terraform 은 job 간 이동 불가하므로 재수행)
    6. download-artifact (같은 run의 tfplan)
    7. tofu apply tfplan                     ← 재-plan 하지 않는다
```

- **2단 체인**: `configure-aws-credentials`가 **입구 Role**을 OIDC로 인증 → 실행 Role을 체인 assume.
  정적 키 없음. ⚠️ **`AWSAFTExecution`이 아니다** — D27-1로 실행 Role이 신설로 바뀌었다.
- 🔴 **2단째가 둘이다**(D30). `assume_role`을 **provider와 backend 양쪽에** 걸어야 한다 —
  backend는 provider 설정을 쓰지 않고 환경 자격증명(=입구 Role)으로 S3에 붙기 때문이다(F17).
  **한쪽만 걸면 `init`이 `HeadObject 403`으로 죽는다.** 첫 이행 인스턴스가 실제로 그렇게 실패했다.
- ⚠️ **apply 승인 시 destroy/replace 목록을 사람이 읽는다**(D27-2). 공용 계정(F13)이라 예외 없음.
- ⚠️ **plan artifact는 민감할 수 있다** — plan 파일에 리소스 속성이 평문으로 들어간다.
  repo read 권한자가 받을 수 있으므로 `retention-days: 1`로 제한하고 소비 규약에 명시한다.
- ⚠️ **역할 체인 세션은 최대 1시간**(연장 불가). apply job이 다시 인증하므로 승인 지연 자체는
  문제없다. 다만 그 사이 state가 바뀌면 `apply`가 거부한다 — **정상 동작**이고 재-plan이 필요하다.

---

## 4. 이 설계가 판정하는 `vpc-v1.0.0` 미검증 항목

[`design/10` §3](10-vpc-module.md)의 apply 미검증 6항목.

### ⚠️ 판정 범위는 **배포 형상에 의존한다** (2026-07-31 정정)

초판은 *"첫 apply는 6번과 minimal 경로만 판정한다"* 고 썼다. **그 문장은 minimal 형상을 전제한
것이었다.** 소비 repo가 무엇을 배포하느냐에 따라 판정되는 항목이 달라진다:

| 항목 | minimal(`examples/vpc`) | enterprise(`examples/vpc-enterprise`) |
|------|------------------------|--------------------------------------|
| 1 secondary CIDR `depends_on` 순서 | ❌ secondary를 안 쓴다 | ✅ 2개를 연결한다 |
| 2 primary/secondary 조합 제약 | ❌ 〃 | ✅ |
| 3 CIDR 겹침 | ⚠️ 서브넷 4개뿐이라 약하다 | ✅ `cidrsubnet()` 파생 20개 |
| 4 Flow Logs 실제 배달 | 형상 무관 — **apply 후 로그 그룹을 직접 확인**해야 한다 | 〃 |
| 5 `prevent_destroy` 실동작 | 형상 무관 — **파기를 시도해야** 판정된다 | 〃 |
| 6 `git tag` 소싱 경로 | ✅ 첫 CI `init` | ✅ |

**첫 이행 인스턴스는 enterprise를 택해 6항목 중 5개를 판정했다.** 판정 결과와 증거는
소비 repo `docs/deployment-facts.md` §6이 소유한다(D26 — 값은 인스턴스, 규약은 여기).

> ⚠️ **"apply했다"와 "판정했다"는 다르다.** 4번은 apply가 성공해도 **로그가 실제로 도착했는지**를
> 따로 봐야 하고, 5번은 **파기를 시도해야** 판정된다. 이 구분을 흐리면 "apply로 검증했다"는
> 과잉 주장이 되고, 그것이 [`reference/poc-findings.md`](../reference/poc-findings.md)가 경계하는 실수다.

> ℹ️ **소비 repo에 무엇을 배포할지 정할 때 이 표를 본다.** 리허설 성격의 repo라면 enterprise가
> 판정 범위를 크게 넓힌다. 실 고객사 배포는 판정이 아니라 요구사항이 형상을 정한다.

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
7. **실행 Role 권한 축소** — 실행 Role이 `AdministratorAccess`다(D27-1).
   공용 계정(F13)이라 축소 이득이 크지만, VPC 하나에 맞춰 도출하면 EKS 단계에서 다시 해야 한다.
   **판단 시점 = 모듈 집합이 안정된 뒤**(최소 EKS 모듈 이식 후). 그때까지는 D27-2의 운영 규칙이 완화책이다
8. **`AWSAFTExecution`의 깨진 신뢰 정책** — principal이 unique ID로 치환된 상태로 방치된다(F14).
   우리가 안 쓰기로 했으므로(D27-1) **우리 문제가 아니다.** 계정 소유자가 판단할 사안이라 여기 남긴다
9. **repo 변수가 CI 로그에 평문으로 남는다 (2026-07-31 신설, F19)** — GitHub은 secret만 마스킹한다.
   D25의 "🙈 비노출"은 **git 안에서만** 보장되고 워크플로 로그에서는 보이지 않는다.
   완화 후보: 첫 스텝의 `::add-mask::`(⚠️ 그 스텝 자신의 명령·env echo에는 찍혀 완전하지 않다) ·
   값을 secret으로 이관(⚠️ 이식성이 준다 — D25 §2의 🔁 분류와 상충).
   **항목 6과 같은 성격**이다 — private repo라는 전제에 기대고 있고, 그 전제가 완화이지 해결이 아니다
10. **승인 게이트의 플랜 종속 (2026-07-31 신설, F18)** — D27-2가 GitHub Team 이상을 전제한다.
    Free private repo에서 쓸 수 있는 강제 게이트가 **없다**(branch policy는 브랜치만 제한한다).
    대체 형태(PR merge)는 merge 권한자와 apply 승인자를 분리하지 못한다.
    **소비 repo를 세울 때 가장 먼저 확인할 항목**이라 여기 남긴다
11. **backend 자격증명 경로의 대안 (2026-07-31 신설, D30 기각안)** — `configure-aws-credentials`의
    role chaining으로 **환경 자격증명 자체를 실행 Role로** 만들면 backend·provider가 한 번에 해결된다.
    지금은 "입구 Role이 OIDC가 도달하는 유일한 지점"을 지키려고 기각했으나, `assume_role`을
    두 곳에 중복 선언하는 비용과 견줄 여지가 있다. **재검토 조건**: 배포 루트가 늘어 중복이
    누락 사고를 내기 시작하면
12. ~~**이 문서의 F6·F13이 계정 ID를 노출한다**~~ ✅ **해소**(2026-07-31 등재 · 같은 날 처리).
    D25의 연장(*"계정 식별 정보를 git에 두지 않는다"*)과 D26(*"인스턴스 값은 소비 repo가 소유한다"*)
    **둘 다와 어긋나 있었다.** 규약 SSOT는 고객사에 인용되므로 더 무겁게 봤다.
    - 처리: **값 → 서술·포인터**. 세 결정 중 **어느 것도 값을 필요로 하지 않았다** —
      F6→D22(*"계정이 **하나**"*) · F13→D27-1/D27-2(*"**공용**이다"*, 근거는 **개수**) ·
      F14→D27-1(*"신뢰 정책이 깨져 있다"*).
    - **동료들의 리소스 prefix와 남의 Role의 unique principal ID도 함께 지웠다.** 계정 ID보다
      오히려 **개인 식별 정보**에 가깝고, 규약 문서에 이름 목록이 있을 이유가 없다.
    - `docs/consumer/dynamic-credentials.md`의 **12곳은 `<poc-account-id>`로 치환**했다.
      절차 기록의 가치는 ARN의 *형태*(2단 체인 구조)이지 *값*이 아니다.
      → **D20 기각안의 "모듈 repo public 전환" 선결 과제가 해소됐다**(기각 근거 자체는 유효하다 —
      남은 것은 설계 문서 공개 자체다).

---

## 6. 참고 자료

- [S3 general purpose bucket naming rules (Best practices · GUID)](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html)
- [OpenTofu — Backend Partial Configuration](https://opentofu.org/docs/language/settings/backends/configuration/)
- [OpenTofu — S3 backend (`use_lockfile`)](https://opentofu.org/docs/language/settings/backends/s3/)
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- [My AWS Account ID Got Leaked — Should I Panic? (AWS re:Post)](https://repost.aws/articles/ARZTqjdG30SwCuMwApp4stlQ/my-aws-account-id-got-leaked-should-i-panic)
- [Plerion — The Final Answer: AWS Account IDs Are Secrets](https://www.plerion.com/blog/the-final-answer-aws-account-ids-are-secrets)
