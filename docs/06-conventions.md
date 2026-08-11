# 06. 규약

**읽는 사람**: 이 저장소에 코드를 쓰거나, 모듈을 소비하는 사람.

---

## 1. 엔진

명령은 `terraform`이 아니라 **`tofu`**다. 로컬 · CI · 문서 · lock 전부 하나로 일원화한다.

Terraform 호환성은 **계약이 아니라 부산물**이다. 보장하지 않지만 이유 없이 깨뜨리지도 않는다.
OpenTofu 고유 기능(`encryption` 블록 · `.tofu` 확장자 · `language {}`)을 쓸 때는 설계에 이유를 남긴다.

왜 OpenTofu인가는 [`08-decisions.md`](08-decisions.md)가 소유한다.

---

## 2. 네이밍과 태깅

### `Name` 태그 포맷

```
(리소스약어)-(workload)-(env)-(리전코드)-(purpose)-(일련번호)

vpc-acme-prd-an2-main
eks-acme-prd-an2-main-01
sgr-acme-prd-an2-web-01
```

| 구성 요소 | 값 |
|-----------|-----|
| 리소스 약어 | [`reference/aws-naming-abbreviations.md`](reference/aws-naming-abbreviations.md) — **SSOT** |
| workload | 프로젝트별 입력 변수. 이 저장소가 고정하지 않는다 |
| env | `prd` / `stg` / `dev` |
| 리전코드 | `an2`(ap-northeast-2) · `ue1`(us-east-1) |
| purpose | `web` · `db` · `main` · `worker` (소문자·하이픈) |
| 일련번호 | `01` · `20260415` · `policy` (선택) |

### 강제 방식

1. **거버넌스 태그는 `default_tags`로.** 배포 루트의 provider에 설정한다. 개별 리소스에 반복하지 않는다.
2. **`Name`은 모듈이 조합한다.** 소비자는 `naming` 객체만 넘긴다. 약어를 직접 쓰지 않는다.
3. **약어가 없으면 만들지 말고 등재한다.** 거버넌스 리뷰 후 카탈로그에 추가하고 쓴다.
4. **제약 리소스 주의**: S3(전역 고유 + DNS) · ALB/TG(32자 이하) · IAM/SG(이름이 곧 식별자).
5. **`Name` 태그 assertion을 계약 테스트에 넣는다.** plan 단계에서 규약 위반을 잡는다.

### 재사용 자산의 요건

workload code · 계정 ID · 리전을 **하드코딩하지 않는다.** 고객사 고유값이 모듈에 남으면 재사용이 아니다.

---

## 3. 버전

### 모듈 버전

**모든 모듈이 개발 단계(`0.y.z`)다.** 이 구간에서는 파괴적 변경도 마이너로 흡수하고,
소비자에게 계약 안정을 약속하지 않는다.

- *"이 변경이 마이너인가 메이저인가"* 를 **판정하지 않는다.** 전부 마이너다.
- `1.0.0`은 **모듈별로** 컷한다. 전 모듈 일괄 컷은 하지 않는다.
- 신규 모듈은 `0.1.0`에서 시작한다.
- 버전 혼재(`vpc-v0.3.0` + `workbench-v0.6.0`)는 결함이 아니라 **정보**다.

### 릴리스된 태그를 옮기지 않는다

예외는 **소비자가 0일 때뿐**이다. 한 번이라도 apply된 뒤에는 다음 마이너를 낸다.

### 도구·provider 핀

| 대상 | 값 | 어디서 |
|------|-----|--------|
| OpenTofu (모듈) | `>= 1.12.0` | `versions.tf` |
| OpenTofu (실행) | `1.12.5` | CI · 로컬 |
| aws provider (모듈) | `>= 6.0` — **하한만** | `versions.tf` |
| aws provider (루트) | `~> 6.0` — 상한은 루트가 통제 | `examples/` · 배포 루트 |
| tflint | `v0.63.1` + aws ruleset `0.48.0` | `.tflint.hcl` |
| trivy | `v0.72.0` | CI · 훅 |
| 커뮤니티 모듈 | **정확 핀** | `main.tf` |

**CI와 로컬 훅의 도구 버전을 일치시킨다.** 어긋나면 *"로컬은 통과했는데 CI가 막는다"* 가 생기고,
그러면 사람이 CI를 신뢰하지 않게 된다. **한쪽을 바꾸면 다른 쪽도 바꾼다.**

### lock 파일

`.terraform.lock.hcl`을 커밋한다. registry 주소가 **`registry.opentofu.org`** 인지 확인한다.
`registry.terraform.io`가 섞이면 CI 게이트 6이 막는다.

---

## 4. 모듈 소싱

```hcl
source = "git::https://github.com/skax-ca/iac-module-library.git//modules/vpc?ref=vpc-v0.3.0"
```

**`ref=main`을 쓰지 않는다** — 움직이는 참조다. 태그로 고정한다.

---

## 5. 코드 규약

| 규칙 | 이유 |
|------|------|
| SG rule은 **별도 리소스**(`aws_vpc_security_group_ingress_rule`) | inline은 순환과 전체 교체를 부른다. 혼용도 금지 |
| 워크스페이스 간 데이터는 **결정적 네이밍 -> `data` 조회** | `terraform_remote_state`는 state 전체 접근이다 |
| 커뮤니티 모듈은 **wrapper(facade)로 감싼다** | upstream 변수 rename을 내부에서 흡수한다 |
| 새 리소스·인자는 **문서로 확인하고 쓴다** | 추정하지 않는다 |

### facade에서 자주 틀리는 것

*"upstream이 그 기능을 지원하지 않는다"* 로 단정하기 전에, **wrapper가 그 인자를 안 넘기고 있는 것은 아닌지**
확인한다. `.terraform/modules/`의 실물 소스를 여는 것이 문서보다 빠르고 정확할 때가 많다.

---

## 6. 검증 게이트

### 코드 변경 후 (로컬)

```
tofu fmt -recursive -check -> tofu validate -> tflint --recursive -> trivy config . -> tofu test
```

git hook으로 강제한다. clone마다 1회 활성화:

```bash
git config core.hooksPath .githooks
```

`--no-verify` 우회는 긴급 시에만 쓰고 **사유를 커밋 메시지에 남긴다.**

> `tflint`의 `terraform_unused_declarations`는 선언만 하고 쓰지 않은 변수를 잡는다.
> 따라서 `variables.tf`만 있고 소비하는 `main.tf`가 없는 상태는 **커밋할 수 없다** —
> 실제 커밋 단위는 "변수가 전부 소비되는 시점"이다.

### CI (`.github/workflows/verify.yml`)

게이트 6개를 돈다:

| # | 게이트 |
|---|--------|
| 1 | `tofu fmt` |
| 2 | `tflint --recursive` |
| 3 | `trivy config` |
| 4 | modules: `init -lockfile=readonly` + `validate` + `test` — **테스트 없는 모듈은 실패** |
| 5 | examples: `init -lockfile=readonly` + `validate` |
| 6 | lock registry 검사 |

**계약 테스트가 없는 모듈은 릴리스하지 않는다.** 게이트 4가 강제한다.

이 저장소는 배포하지 않으므로 **apply 워크플로가 없다.** 누락이 아니라 설계다.

> CI는 읽기 전용이라 `cancel-in-progress: true`다.
> **배포 루트의 apply는 반대여야 한다** — apply 중단은 state 잠금과 부분 적용을 남긴다.

### trivy 예외

`.trivyignore`로만 처리한다. 항목마다 사유와 백로그 링크를 남긴다.

---

## 7. 브랜치와 PR

| 변경 대상 | 경로 |
|-----------|------|
| `.tf` · `.github/workflows/` | **브랜치 -> PR** |
| 문서 | **`main` 직접 커밋** |

기준은 *"CI가 머지 전에 막아야 하는가"* 하나다. 문서에는 main을 깨뜨릴 산출물이 없다.

**문서 전용 변경에 PR을 쓰지 않는다.** 사실상 1인 작업이라 리뷰가 형식이 되고,
커밋 메시지를 길게 쓰는 문화라 PR 본문도 중복이다.

---

## 8. 문서 작성 규칙

이 문서 집합이 다시 부풀지 않게 하는 장치다.

| # | 규칙 |
|---|------|
| 1 | **독자로 파일을 가른다.** 각 문서 첫 줄에 "읽는 사람"을 쓴다 |
| 2 | **변경 이력을 본문에 쓰지 않는다.** 이력은 `CHANGELOG.md`와 git이 소유한다 |
| 3 | **이모지는 표의 상태 열 3종만** (`✅ ⏳ ❌`). 본문에 쓰지 않는다 |
| 4 | **한 문서는 400줄을 넘지 않는다.** 넘으면 독자가 갈린 것이다 |
| 5 | **선택은 표로, 절차는 명령으로.** 산문으로 고르게 하지 않는다 |
| 6 | **문서 간 링크는 문서 단위.** 절 번호를 인용해야 하는 문서를 만들지 않는다 |
| 7 | **정정 서술을 남기지 않는다.** 문서는 현재 사실만 진술한다 |
