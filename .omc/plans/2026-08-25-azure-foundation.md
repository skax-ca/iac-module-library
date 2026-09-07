# Azure 2nd-cloud 기반 구조 (RALPLAN-DR / DELIBERATE)

**상태**: **v4 (최종본)**. Architect · Critic **3회 독립 검토 완료 — 양측 APPROVE**.
**남은 것**: 사용자 승인 대기(pending approval) — open-questions 1번(스코프 이탈) · 2번(Step 5 착수 게이트).
**모드**: DELIBERATE (소비 repo가 쓰는 `source=` 경로를 깨는 변경).
**스코프**: 자리를 만드는 라운드. Azure 모듈 `.tf`와 AKS 아키텍처 문서는 후속 라운드.

> 변경 로그는 9절. v2에서 **철회한 주장 1건(0-4)**과, 검토 과정에서 발견한
> **기존 스크립트의 죽은 파서 2건(0-5)**이 있다.

---

## 0. 착수 전 정정 사항 (실측)

### 0-1. `scripts/validate-abbreviations.py:17`은 이미 하드코딩이 아니다

지시문은 17행 경로 하드코딩을 일반화 대상으로 지목했다. 실물은 이미 인자를 받는다:

```python
# scripts/validate-abbreviations.py:17
PATH = sys.argv[1] if len(sys.argv) > 1 else "docs/aws-naming-abbreviations.md"
```

실제 멀티 카탈로그 차단 지점은 셋이고 전부 다른 곳이다:

| 위치 | 내용 | 성격 |
|---|---|---|
| `scripts/validate-abbreviations.py:109` | `if len(section_rows) != 8` | 카테고리 수 8개 고정. **진짜 차단 지점** |
| `.github/workflows/verify.yml` docs-ssot job | 인자 없이 호출 | 카탈로그 1개만 검사 |
| `.githooks/pre-commit:10` | `grep -qx 'docs/aws-naming-abbreviations.md'` | 정확 일치. 새 경로는 게이트를 조용히 통과 |

109행은 스크립트가 4행에 선언한 원칙("문서가 스스로 선언한 불변식만 강제한다")과 어긋난다.
8은 문서가 선언한 값이 아니라 스크립트가 외운 값이다.

### 0-2. 디렉터리 이동의 파급이 지시문 스코프 목록보다 넓다 (게이트 5곳 추가)

| 파일 | 근거 위치 | 이동 시 증상 |
|---|---|---|
| `.github/workflows/verify.yml` | 게이트 4 `for m in modules/*/` | `modules/aws/`에 `tests` 없음, `exit 1` |
| 〃 | 게이트 5 `for e in modules/*/examples/*/` | 매칭 0건, `found=0`, `exit 1` |
| 〃 | 게이트 7 `for dir in modules/*/` | terraform-docs가 `modules/aws/`에서 실패 |
| `.githooks/pre-commit` | `^modules/[^/]+/[^/]+\.tf$` + `sed -E 's#^(modules/[^/]+)/.*#\1#'` | drift 검사가 **조용히 건너뛴다**(미탐) |
| `.githooks/pre-push` | `for m in modules/*/` | 루프 0회인데 **"테스트 통과 ✓"까지 출력**(미탐) |
| `.trivyignore.yaml` | `paths: - "modules/workbench/main.tf"` | 예외 미적용, AVD-AWS-0104 재발화, 게이트 3 red |
| `scripts/validate-doc-conventions.py:27` | `GENERATED_README = ^modules/[^/]+/README\.md$` | 생성 README가 프로즈로 재분류 |

마지막 항목의 건수(4개 모듈 전수): cross-account 3 · vpc 4 · workbench 13 · eks-cluster 18 =
**em-dash 위반 38건**이 docs-conventions job에서 즉시 터진다.

⚠️ 훅 2곳의 증상이 red가 아니라 **미탐**이라는 점이 이 변경의 가장 위험한 성질이다.
CI는 시끄럽게 죽지만 로컬 게이트는 조용히 사라진다. pre-push는 성공 메시지까지 출력하므로 더 나쁘다.

### 0-3. 모듈 간 상대경로 `source`는 이동에 안전하다 (단, 주석은 아니다)

`modules/eks-cluster/examples/enterprise/main.tf:29,129,171`이 형제 모듈을 상대경로로 소싱한다
(`../../../vpc` · `../../../workbench` · `../..`). 4개 모듈이 **함께** 내려가면 상대 깊이가 보존된다.

| 구분 | 건수 | 판정 |
|---|---|---|
| **기능적 수정**(`source` 인자·HCL 표현식) | **0건** | 상대 깊이 보존으로 무손상 |
| **주석 내 경로 참조** | **6건** | 갱신 필요 |

주석 6건: `modules/eks-cluster/addons.tf:65` · `tests/plan.tftest.hcl:18,36` ·
`eks-cluster/examples/enterprise/main.tf:4,5` · `vpc/examples/enterprise/main.tf:9`.
`tofu` 동작에는 영향이 없지만 통합 grep(C1)이 잡으므로 갱신해야 한다.

### 0-4. ⛔ **v2의 주장을 철회한다** — `--exclude-dir`는 정상 동작한다 (도구 오염이 원인)

v2의 0-4절은 *"`grep --exclude-dir=.omc`가 이 저장소에서 무력화된다"*고 **저장소 속성으로 오귀속**했고,
그 잘못된 근거로 Critic의 1차 F-2 권고를 기각했다. **원인은 저장소가 아니라 도구다.** 재현:

```
$ type grep
grep is a shell function from ~/.claude/shell-snapshots/snapshot-zsh-....sh
    ... exec -a ugrep "$_cc_bin" -G --ignore-files --hidden -I --exclude-dir=.git ... "$@"
```

Claude Code 세션의 `grep`은 순정 grep이 아니라 **ugrep shim**이고 `--ignore-files --hidden -I`가
강제로 붙는다. `--ignore-files`가 `.gitignore`를 존중하므로 `.omc/` 관련 무시·부활 규칙이
`--exclude-dir`보다 우선한 것처럼 보였다. 순정 grep에서는 정상이다:

```
$ command grep -rnE '...' --exclude-dir=.omc . | command grep -c '.omc/'
0      # 최상위 .omc/ 뿐 아니라 modules/vpc/.omc/·modules/eks-cluster/.omc/ 중첩까지 전부 제외
```

**따라서 Critic의 F-2 권고를 채택한다**: C1·A5 양쪽에 `--exclude-dir=.omc`를 쓴다.
v2가 채택했던 파이프 필터(`grep -v '^\(\./\)\?\.omc/'`)는 **중첩 경로를 못 잡는다** —
순정 grep 실측으로 `./modules/vpc/.omc/state/last-tool-error.json` 2건이 새어 **49건**이 된다.
`--exclude-dir=.omc`를 쓰면 **47건 / 18파일**로 맞는다.

또한 shim의 `-I`(바이너리 스킵) 때문에 A5가 `scripts/__pycache__/*.pyc` 매치를 놓치고 있었다.
순정 grep은 이것을 잡으므로 `--exclude-dir=__pycache__`가 필요하다.

> 🔑 **이 계획의 모든 grep 인수 조건은 `command grep`으로 판정한다.**
> 명시하지 않으면 실행자가 Claude Code 세션(shim)에서 green을 받고 CI(순정 grep)에서 red를 받는
> 경로가 열려 있다. Pre-mortem 시나리오 4가 이 경로를 다룬다.

### 0-5. ★ 죽은 파서가 **2곳**이다 (Step 1의 **선행 수정** 대상)

Critic이 v2의 Step 1.3 제안(`set(section_rows) != set(summary_claim)`)을 실행해 보고 찾았다.
그대로 적용하면 **현재 카탈로그에서 결정론적으로 rc=1**이 난다. `summary_claim`이 항상 비기 때문이다.
후속 검토에서 **같은 종류의 죽은 파서가 하나 더** 드러났다.

#### (a) 84행 — 카테고리 요약 표 파서

정규식이 **별표를 요구**한다:

```python
r"\|\s*(A\.\d)\s*\|\s*\*\*?(카테고리별|[\w\s,]*)\*?\s*\|\s*(\d+)\s*\|"
```

실제 표(`docs/aws-naming-abbreviations.md:439-446`)에는 별표가 없다: `| A.1 | Compute | 41 |`.

```
old regex matches: []                                    <- 8개를 하나도 못 잡는다
new regex matches: ['A.1','A.2',...,'A.8']               <- 대체식은 전부 잡는다
```

#### (b) 90행 — 상단 총계 파서 (M-1, 같은 커밋에서 함께 고친다)

정규식 `r"총 \*\*(\d+)\*\*개 약어"`는 **별표가 숫자만 감싼다**고 전제한다.
실제 문서는 `총 **311개** 약어` — 별표가 **"311개" 전체**를 감싼다.

```
old regex matches: []                                    <- total_declared 가 항상 None
new regex matches: ['311']                               <- r"총\s*\**\s*(\d+)개?\**\s*약어"
```

따라서 **112행(`total_declared != actual_total`)도 죽은 코드**다.

#### 파생 결함: 문서의 선언이 거짓이 된다

- 106행(`summary_claim[sec] != n`)과 112행(`total_declared != actual_total`) **둘 다 죽은 검사**다.
- 카탈로그 452행이 *"약어를 추가·삭제할 때는 ① 섹션 헤더 ② 상단 총계 ③ 이 표를 함께 고친다"*
  (스크립트가 강제한다는 취지)고 선언하는데, 실제로 강제되는 것은 **①뿐**이다. ②③은 강제되지 않는다.
  0-1이 지적한 것과 **정확히 같은 종류의 "선언 ≠ 코드" 위반**이고, 이 계획이 그것을 세 번째로 만난 것이다.

따라서 Step 1은 **두 단계로 나뉜다**: (a) 84·90행 정규식 선행 수정 → (b) 109행 검사 교체.
순서가 바뀌면 A1이 죽는다.

---

## 1. RALPLAN-DR 요약

### Principles

| # | 원칙 |
|---|---|
| P1 | **게이트 이중화 불변식**: 로컬 훅과 CI는 같은 명령이어야 한다. 다만 이는 현재 **주석 4줄로만 강제**되며 `.githooks/*`를 실행하는 CI job은 0개다. 이 계획은 그 격차를 B6·B6b로 메우고, 구조적 해소는 Follow-up 7번으로 넘긴다 |
| P2 | **문서는 소유자가 하나다**: 포맷=`conventions.md`, 약어=카탈로그, 배선=`module-catalog.md`, 기각=`decisions.md`. **스크립트가 문서 선언보다 넓거나 좁게 강제해서도 안 된다**(0-1·0-5가 이 위반의 실례다) |
| P3 | **소비자 계약은 태그가 고정한다**: 기존 태그는 과거 트리를 가리키므로 이동은 소급 파괴가 아니다 |
| P4 | **검증하지 않은 provider 동작은 규정하지 않는다** |
| P5 | **자리만 만든다**: Azure 콘텐츠를 만들지 않는다. **판단 기준은 "검증 대상이 0건인가"가 아니라 "게이트를 깨뜨리거나, 증명할 수 없는 상태를 게이트에 넣는가"다.** 이 기준으로 tflint azurerm 등록은 걸리고(훅이 죽는다 + 룰 동작을 증명할 수 없다), Step 2의 Azure 절 신설은 걸리지 않는다(문서는 게이트가 아니고 "규정하지 않는다"가 정직한 종착점이다) |

### Decision Drivers (상위 3)

| # | 드라이버 | 왜 이것이 결정을 가르는가 |
|---|---|---|
| D1 | **소비 repo 마이그레이션 비용과 타이밍** | `eks-reference-infra`의 `source=` 4개가 다음 태그 승급 시점에 동시에 깨진다 |
| D2 | **게이트가 조용히 축소되지 않을 것** | 0-2의 훅 2건은 red가 아니라 미탐이다 |
| D3 | **개명·이동의 원자성** | 카탈로그 개명은 스크립트 예외 목록과 같은 커밋이어야 한다 |

> **D2 해소 방향의 전환(Architect Synthesis 채택)**: v2는 D2를 "계수를 세서" 지키려 했다.
> v3는 **개수가 아니라 모양을 불변식으로 삼는다.** stray 검사가 *"`modules/` 아래는 반드시
> `<provider>/<name>/` 형태"*를 강제하면 게이트 글롭이 어긋날 여지가 구조적으로 사라진다.
> 그러면 계수 assertion은 "0건 매칭만 막으면 되는" 존재 확인(`-ge 1`)으로 값싸지고,
> 모듈이 늘 때마다 기대치를 고치는 편집 세금도 없어진다. Follow-up 1의 우선순위도 함께 내려간다.

### 실행 가능 옵션

#### 축 1: 경로 전환 전략

| | Option A: 클린 브레이크 (채택) | Option B: 호환 shim 유지 |
|---|---|---|
| Pros | 기능적 `.tf` 수정 0건(0-3). 게이트 수정 1회. 트리가 곧 진실 | 소비 repo가 태그 승급과 경로 수정을 분리 가능 |
| Cons | 다음 태그 승급 시 소비 repo 4곳이 동시에 깨짐 | 변수·출력 전량 중복. 게이트 4·7이 8개를 돌고 drift를 shim마다 관리 |
| 판정 | **채택**. P3에 따라 기존 태그가 살아 있으므로 승급 시점은 소비 repo가 고른다. shim이 사려는 것을 태그가 이미 제공한다 | 기각 |

#### 축 2: PR 구성

| | Option A: 단일 PR + 층별 커밋 2개 (채택) | Option B: 2단계 PR |
|---|---|---|
| Pros | `git revert <커밋>`으로 층 단위 되돌리기 유지. rebase 비용 0. `validate-doc-conventions.py` 27·28행 인접 충돌 없음 | 각 층이 독립적으로 CI green |
| Cons | **각 층이 독립적으로 green임을 증명하지 못한다**(인정) | rebase 비용, 27·28행 충돌, revert 시나리오 부재 |
| 판정 | **채택** | 기각 |

#### 축 3: 카탈로그 배치 (**v3에서 한 단계 세분화** — F-D 해소)

v2는 `docs/naming/{aws,azure}.md`를 채택하면서 근거로 *"`naming/`은 향후 리전 코드표 등 다른
네이밍 SSOT도 수용한다"*를 들었다. 그런데 Step 1이 `docs/naming/` **디렉터리 전체**를 약어 검증기
대상 + 400줄 예외로 지정했다. 리전 코드표를 그 아래 두는 순간 약어 검증기가 강제로 돌아 죽거나,
검토 없이 400줄 예외가 부여된다 — **채택 근거가 스스로를 무효화**한다.

| | Option A: `docs/naming/abbreviations/{aws,azure}.md` (채택) | Option B: `docs/naming/{aws,azure}.md` (v2안) |
|---|---|---|
| Pros | 디렉터리가 **카탈로그 종류**를 정확히 식별한다. `naming/`은 주제 디렉터리로 남아 확장성 근거가 살아 있고, 400줄 예외·검증기 대상은 `abbreviations/`로 정확히 한정된다 | 경로가 한 단계 짧다 |
| Cons | 경로 한 단계 추가 | 확장성 근거와 접두사 판정이 충돌(F-D) |
| 판정 | **채택** | 기각 |

> **Option C(파일 내용 기반 판정, `## A.N` 섹션 유무로 카탈로그 식별)도 검토해 기각했다.**
> 우아해 보이지만 "카탈로그가 아닌 파일은 조용히 건너뛴다"를 도입한다. 오타로 섹션 헤더가 깨진
> 진짜 카탈로그가 검사 대상에서 **조용히 빠지는** 경로가 생기고, 이는 D2가 막으려는 바로 그 미탐이다.
> 디렉터리 판정은 글롭이 정확히 열거하므로 이 문제가 없다.

> **`docs/naming-abbreviations/` 반론에 대한 반박(유지)**: `naming/`이 주제 디렉터리로 남으므로
> 향후 리전 코드표·env 어휘표는 `docs/naming/regions.md` 식으로 같은 주제 아래 들어간다.
> `naming-abbreviations/`는 그 순간 두 번째 최상위 디렉터리를 요구한다.

> 축 1의 Option C(AWS 최상위 유지, Azure만 `modules/azure/`)는 **사용자가 확정 결정 1로 배제**했다.

---

## 2. Guardrails

### Must Have

- 4개 AWS 모듈은 **같은 커밋에서 함께** 이동한다 (0-3의 상대경로 보존 조건).
- 이동은 `git mv`로 한다.
- 게이트 glob 수정은 **깊이를 고정**한다(`modules/*/*/`). `modules/**/`류는 D2 미탐을 만든다.
- **최상위 stray 파일 검사를 게이트 4 앞에 추가한다.** 이것이 v3의 핵심 불변식이다 —
  개수가 아니라 **모양**을 강제하므로 게이트 글롭이 어긋날 여지가 구조적으로 사라진다.

  ⚠️ **`-mindepth`/`-maxdepth`는 `-o` 절마다 재적용되지 않는 global option이다.** v2가 쓴
  단일 호출 형태는 실제로 `modules/orphan.tf`(depth 1)를 **놓친다**(픽스처로 재현 확인).
  괄호 그룹핑도 동일하게 실패한다. **두 번 분리 호출**해야 한다:

  ```bash
  stray=$( { find modules -mindepth 1 -maxdepth 1 -type f;
             find modules -mindepth 2 -maxdepth 2 -name '*.tf'; } )
  [ -z "$stray" ] || { echo "::error::modules/<provider>/<name>/ 형태가 아닌 항목: $stray"; exit 1; }
  ```

  `| head`는 붙이지 않는다 (GH Actions bash는 pipefail이라 SIGPIPE 위험).

- **게이트 4·5의 기존 `found` 가드를 그대로 유지한다** (신설하지 않는다).
  `verify.yml`에 이미 `found=0`/`found=1` + `[ "$found" = 1 ]`가 있다(게이트 4는 98·100행,
  게이트 5는 119·123행). 이것이 곧 존재 확인이므로 **추가 assertion은 불필요**하다.
  stray 검사가 모양을 강제하므로 글롭이 매칭하는 집합은 곧 유효 모듈 집합이고, 남은 위험은
  "글롭이 통째로 0건"뿐인데 그것을 기존 가드가 이미 막는다.
  기대 개수(`-eq 4`)를 박지 않으므로 모듈이 늘 때마다 고칠 필요도 없다.
  `-ge 1` 형태는 **B2·B3의 로컬 재현용**으로만 쓴다.
- `.githooks/*`와 `.github/workflows/verify.yml`을 같은 커밋에서 함께 고친다 (P1).
- 카탈로그 개명과 `scripts/validate-doc-conventions.py:28` 수정은 **같은 커밋**이다 (D3).
- **`validate-abbreviations.py:84` 선행 수정이 109행 교체보다 먼저다** (0-5).
- `docs/writing-style.md:18`의 400줄 예외 선언을 스크립트와 **같은 범위**(`docs/naming/abbreviations/`)로 맞춘다 (P2).
- **모든 grep 인수 조건은 `command grep`으로 판정한다** (0-4).
- `.tf`·`.github/workflows/` 변경이 포함되므로 **브랜치 -> PR**.
- `.omc/notepad.md` 갱신을 같은 브랜치에 싣는다. **Success Criteria 11번으로 판정한다.**

### Must NOT Have

- Azure 모듈 `.tf` 생성 금지. `modules/azure/` 디렉터리도 만들지 않는다.
- `docs/naming/abbreviations/azure.md` 생성 금지 (P5).
- **`.tflint.hcl` azurerm ruleset 등록 금지 (이번 라운드)** — 아래 고지 참조.
- azurerm 태그 상속 동작을 문서 확인 없이 서술 금지 (P4).
- 기존 태그 재발행·삭제 금지. 기존 약어 개명 금지.
- `eks-reference-infra` 수정 금지 (SSOT 경계).
- `--no-verify` 우회 금지.

> 🔴 **사용자 확정 스코프에서의 이탈 고지 (승인 필요)**
>
> 사용자 지시문 스코프 2번은 `.tflint.hcl`에 azurerm ruleset 추가를 **포함**으로 확정했다.
> Architect와 Critic이 독립적으로 이번 라운드 제외를 권고했고 근거는 셋이다:
> (a) `.githooks/pre-commit:62-63`에 `tflint --init`이 없다(CI `verify.yml:57-59`에는 있다).
>     azurerm을 추가하는 그 커밋에서 훅이 "plugin not installed"로 죽는다 — P1 위반이 실제 사고가 된다.
> (b) 검증 대상 Azure `.tf`가 0건이라 azurerm 룰 동작을 **증명할 수단이 없다**(P5).
> (c) GitHub 릴리스 rate limit 노출이 배가된다.
>
> **계획은 제외를 반영했다.** 스코프 축소는 사용자 결정 영역이므로 open-questions 1번에 승인 대기로
> 올렸다. 유지를 지시하면 (a)의 `--init` 누락 수정이 **선행 필수**다.

---

## 3. Task Flow

```
단일 PR (branch: feat/azure-foundation)
├─ 커밋 1 [문서·스크립트 층]
│   Step 1  요약표 파서 선행 수정 -> 카탈로그 분리 -> 검증기 일반화
│   Step 2  conventions.md 태깅 절 provider 중립화   <- 사전 조사 선행
│
└─ 커밋 2 [이동·게이트 층]
    Step 3  모듈 이동 + 게이트 5곳 + stray 검사 + 존재 확인
    Step 4  참조 전수 갱신 (문서 + 모듈 README + 예제 README + .tf 주석)
              |
              v  PR 머지 (CI 3 job green 확인)
    Step 5  태그 재컷 + 마이그레이션 안내 + ADR 확정   <- 착수 게이트 있음
```

> **게이트 1·2·3·6은 이동과 무관하다.** 저장소 전역 스캔이라(`tofu fmt -recursive` ·
> `tflint --recursive` · `trivy config .` · `find . -name '.terraform.lock.hcl'`) 경로 깊이에
> 의존하지 않는다. 깨지는 것은 **글롭으로 대상을 열거하는 게이트 4·5·7뿐**이다.

> **롤백 경로**: 머지 후 문제가 드러나면 `git revert <커밋2>`로 이동 층만 되돌린다.
> Step 5(태그 컷) 전이면 소비 repo 파급은 0이다. 태그를 이미 컷했다면 되돌리지 않고 다음 마이너로
> 전진 수정한다(태그 삭제는 Must NOT Have).

---

## 4. Detailed TODOs

### Step 1 — 파서 선행 수정, 카탈로그 분리, 검증기 일반화 (커밋 1)

**하는 일 (순서가 계약이다)**

1. **[선행] `scripts/validate-abbreviations.py`의 죽은 파서 2곳을 같은 커밋에서 수정** (0-5).
   별표 유무·별표 범위와 무관하게 매칭하도록:

   ```python
   # 84행 — 카테고리 요약 표
   r"\|\s*(A\.\d)\s*\|\s*\**([^|]*?)\**\s*\|\s*(\d+)\s*\|"

   # 90행 — 상단 총계 (M-1)
   r"총\s*\**\s*(\d+)개?\**\s*약어"
   ```

   이 수정으로 106행·112행의 죽은 검사가 **둘 다** 살아나고, 카탈로그 452행의 선언
   (①②③을 함께 고친다)이 비로소 전부 참이 된다.
   **이 단계 직후 A1을 돌려 현재 카탈로그가 무수정으로 rc=0인지 확인한다.**

2. `mkdir -p docs/naming/abbreviations`
   `git mv docs/aws-naming-abbreviations.md docs/naming/abbreviations/aws.md`
   ⚠️ `mkdir -p`를 빠뜨리면 `git mv`가 rc=128로 즉시 멈춘다.
3. 문서 제목·"읽는 사람" 줄을 클라우드 스코프가 드러나게 조정. 포맷은 `conventions.md`가
   소유한다는 위임 문장 유지 (P2).
4. **[선행 수정 이후] `validate-abbreviations.py:109`** 의 `if len(section_rows) != 8`을 교체:

   ```python
   if not section_rows:
       err("카탈로그 섹션(## A.N)이 하나도 없다")
   elif set(section_rows) != set(summary_claim):
       err(f"섹션 집합 불일치 — 카탈로그 {sorted(section_rows)} vs 요약표 {sorted(summary_claim)}")
   ```

   개수 비교(`len != len`)는 요약 표가 통째로 없을 때 `0 != 0`이 거짓이라 조용히 통과한다.
5. 17행 기본 경로를 `docs/naming/abbreviations/aws.md`로 바꾸고, `sys.argv[1:]` 전체를 순회하도록
   확장한다. 에러 접두사에 파일 경로를 붙인다.

   ⚠️ **상태 격리가 이 확장의 계약이다.** 파일마다
   `section_rows` · `section_header` · `summary_claim` · `seen` · `revision_abbrs` · `ERRORS`를
   **리셋**한다(현재는 모듈 전역 변수이므로 검사 본문을 함수로 감싸 스코프화한다).
   격리하지 않으면 `azure.md`가 생기는 순간 `vpc`가 양쪽 카탈로그에 있다는 이유로 **거짓 "약어 중복"
   에러**가 나고, 이는 ADR이 이미 결정한 *"클라우드 간 재사용 허용"* 을 코드가 뒤집는 것이다.
   **약어 고유성은 파일 내부에서만 판정한다.**
6. `scripts/validate-doc-conventions.py:28`: `LINE_LIMIT_EXCEPTIONS`를
   `docs/naming/abbreviations/` **접두사 판정**으로 교체.
7. `docs/writing-style.md:18`의 400줄 예외 문면을 같은 범위로 (P2, Must Have).
8. `.github/workflows/verify.yml` docs-ssot job:
   `python3 scripts/validate-abbreviations.py docs/naming/abbreviations/*.md`
9. `.githooks/pre-commit:10`을 접두사 매칭으로. ⚠️ 훅이 `set -euo pipefail`이므로
   **`|| true`가 없으면 카탈로그 무관 커밋마다 훅이 죽는다**:

   ```bash
   catalogs=$(printf '%s\n' "$changed" | grep -E '^docs/naming/abbreviations/.*\.md$' || true)
   if [ -n "$catalogs" ]; then
     echo "[pre-commit] 약어 카탈로그 변경 — SSOT 검사"
     # shellcheck disable=SC2086
     python3 scripts/validate-abbreviations.py $catalogs
   fi
   ```

10. 참조 갱신 전수:
    `docs/README.md` · `docs/conventions.md` · `docs/module-catalog.md` · `docs/writing-style.md:18` ·
    `scripts/README.md:12` · `.claude/rules/terraform.md:21` · `.opencode/agents/planner.md` ·
    `.opencode/agents/code-reviewer.md` · `.opencode/commands/review.md` ·
    `.omc/notepad.md` Priority Context · `.omc/project-memory.json` ·
    **`scripts/validate-abbreviations.py:2,9`(자기선언 주석)** ·
    **`scripts/validate-doc-conventions.py:9`(400줄 예외를 파일명으로 재선언하는 docstring)**

**인수 조건** (grep은 전부 `command grep`)

```bash
# A1. ★ 회귀 게이트 — 현재 카탈로그가 무수정 상태로 rc=0 을 유지한다
#     (0-5의 선행 수정 직후, 그리고 109행 교체 후 두 번 돌린다)
python3 scripts/validate-abbreviations.py docs/naming/abbreviations/aws.md
#   -> "311개 · 8개 카테고리", rc=0

# A2. 카테고리 8개 고정 해제 증명 (스크래치패드 픽스처, 커밋하지 않음)
#     (픽스처는 섹션 집합과 **일치하는** 카테고리 요약 표와 맞는 상단 총계를 포함해야 rc=0 이 된다
#      — 109행이 집합 비교이므로 요약 표 없는 픽스처는 A3b-b2 에 해당한다)
python3 scripts/validate-abbreviations.py "$SCRATCH/fixture-3cat.md"          # -> rc=0

# A2b. ★ 상태 격리 증명 (Step 1.5 의 계약) — 같은 약어를 가진 두 카탈로그를 한 번에 넘긴다
#      fixture-cloudA.md 와 fixture-cloudB.md 둘 다 약어 `vpc` 를 포함시킨다.
#      격리 안 되면 "약어 중복 `vpc`" 로 rc=1 이 난다 = ADR 의 "클라우드 간 재사용 허용" 위반.
python3 scripts/validate-abbreviations.py "$SCRATCH/fixture-cloudA.md" "$SCRATCH/fixture-cloudB.md"
#   -> rc=0, 두 파일의 결과가 각각 보고된다

# A3a. 기존 불변식 유지 (104-105행, 이번에 안 바뀌는 코드)
python3 scripts/validate-abbreviations.py "$SCRATCH/fixture-headercount.md"   # -> rc=1

# A3b. ★ 교체된 109행 + 되살린 106·112행의 음성 테스트 (5종)
#   b1) 섹션 3개인데 요약표 2행                -> rc=1 "섹션 집합 불일치"
#   b2) 요약표가 통째로 없는 문서               -> rc=1 (len 비교였다면 통과했을 케이스)
#   b3) 섹션이 하나도 없는 문서                 -> rc=1 "섹션이 하나도 없다"
#   b4) ★ 카테고리 요약표 **한 행의 숫자만** 틀린 문서 (합계 값과 섹션 헤더는 그대로 둔다)
#        -> rc=1. 106행이 되살아났음을 증명 = 카탈로그 452행의 "③" 이 실제로 강제된다
#   b5) ★ **상단 총계**만 틀린 문서 (요약표·섹션 헤더는 그대로 둔다)
#        -> rc=1. 112행이 되살아났음을 증명 = 카탈로그 452행의 "②" 가 실제로 강제된다
for f in b1 b2 b3 b4 b5; do python3 scripts/validate-abbreviations.py "$SCRATCH/fixture-$f.md"; done  # 전부 rc=1

# A4. 400줄 예외가 새 경로에 적용된다 (aws.md 는 468줄)
python3 scripts/validate-doc-conventions.py   # -> rc=0

# A5. ★ 구 파일명 참조 0건 — 순정 grep + exclude-dir 3종 (0-4)
command grep -rn 'aws-naming-abbreviations' \
  --exclude-dir=.git --exclude-dir=.omc --exclude-dir=.terraform --exclude-dir=__pycache__ .
#   -> 0건  (shim 은 -I 로 .pyc 를 놓쳤다. 순정 grep 은 잡으므로 __pycache__ 제외가 필요하다)

# A5b. ★ 필터 자가검증 — 라이브 트리가 아니라 합성 픽스처로 (F-E)
#      v2 는 ".omc 안에 잔여 참조가 몇 건인지"를 셌는데, Step 1.10 이 그것을 성실히 갱신하면
#      0 이 되어 자가검증이 스스로 실패하는 역설이었다.
printf '%s\n' './.omc/x.md:1:hit' '.omc/y.md:1:hit' './modules/vpc/.omc/z.json:1:hit' './docs/keep.md:1:hit' \
  | command grep -v '\(^\|/\)\.omc/'
#   -> './docs/keep.md:1:hit' 한 줄만 남아야 한다 (중첩 .omc 까지 걸러짐을 증명)

# A6. 훅과 CI가 같은 대상을 본다  [사람 판정]
command grep -n 'validate-abbreviations' .githooks/pre-commit .github/workflows/verify.yml

# A7. 문서 선언과 코드 범위가 일치한다  [사람 판정]
command grep -n '400줄' docs/writing-style.md
command grep -n 'LINE_LIMIT_EXCEPTIONS' scripts/validate-doc-conventions.py

# A8. 카탈로그 무관 커밋에서 훅이 죽지 않는다 (9번의 || true 검증)
git add README.md && .githooks/pre-commit                     # -> rc=0
```

### Step 2 — `conventions.md` 태깅 절 provider 중립화 (커밋 1)

**하는 일**

"강제 방식" 6개 항목 중 1번·6번이 AWS `default_tags`·`aws_ec2_tag`를 전제한다.
**공통 원칙**과 **provider별 강제 방식**으로 가른다. 절 제목을 셋으로 고정한다
(인수 조건이 절 경계를 이 제목으로 잡으므로 문면이 계약이다):

```
### 공통 강제 방식
### AWS 강제 방식
### Azure 강제 방식
```

- 공통: `Name` 포맷, "모듈이 조합한다", "약어는 등재 후 쓴다", "모든 리소스에 태그를 단다",
  "계약 테스트에 assertion", 재사용 자산 요건.
- AWS: `default_tags`, 묵시적 리소스 3단계 우선순위, 제약 리소스 목록(S3 전역 고유 · ALB/TG 32자 ·
  IAM/SG 이름=식별자).
- Azure: 조사 결과에 따라 메커니즘 + 근거 링크, 또는 "첫 Azure 모듈 라운드에서 규정한다" 한 문장 (P4).
  Azure 고유 제약(리소스 그룹 스코프 · 전역 고유 이름 · 종류별 길이/문자 제약)이 AWS와 다르다는
  사실은 열린 항목으로만 남기고 값을 채우지 않는다.

**사전 조사 (구현 전 선행)**: opentofu registry MCP 또는 provider 공식 문서로 (a) provider 블록 수준
기본 태그 기능의 존재 여부와 이름 (b) 리소스 수준 `tags`와의 병합 규칙 (c) Azure Policy 태그 상속과의 관계.

**인수 조건**

```bash
# E1. 공통 층에 provider 고유 식별자 0건 — 절 경계를 제목으로 특정
awk '/^### 공통 강제 방식/,/^### AWS 강제 방식/' docs/conventions.md \
  | command grep -n 'default_tags\|aws_ec2_tag\|aws_default_'          # -> 0건

# E2. 세 절이 실제로 존재한다
command grep -c '^### \(공통\|AWS\|Azure\) 강제 방식' docs/conventions.md   # -> 3

# E3. 400줄 이내 유지 (현재 241줄)
python3 scripts/validate-doc-conventions.py docs/conventions.md            # -> rc=0

# E4. Azure 절의 모든 사실 문장에 출처가 있거나 절이 "규정하지 않는다" 한 문장이다  [사람 판정]
awk '/^### Azure 강제 방식/,/^---/' docs/conventions.md
```

### Step 3 — 모듈 이동과 게이트 수정 (커밋 2)

**하는 일**

```bash
mkdir -p modules/aws
for m in vpc eks-cluster workbench cross-account-trust-role; do
  git mv "modules/$m" "modules/aws/$m"
done

# ⚠️ 깊이 3으로는 부족하다 — 예제의 .terraform 은 깊이 5다
find modules -name .terraform -type d -prune -exec rm -rf {} +
```

| 파일 | 수정 |
|---|---|
| `verify.yml` 게이트 4 | `for m in modules/*/` -> `modules/*/*/` |
| `verify.yml` 게이트 5 | `modules/*/examples/*/` -> `modules/*/*/examples/*/` |
| `verify.yml` 게이트 7 | `for dir in modules/*/` -> `modules/*/*/` |
| `verify.yml` 게이트 4 앞 | **stray 검사 신설** — 2절의 **두 번 분리 호출** 형태 |
| `verify.yml` 게이트 4·5 | **수정 없음.** 기존 `found` 가드(98·100 / 119·123행)가 이미 존재 확인이다 |
| `verify.yml:74-75`, `:79` | stale 주석 정정 — "5개 디렉토리(modules 3 + examples 2)"가 실제와 다르다(모듈 4개). 같은 헤더 영역을 손대므로 두 블록을 함께 고친다 |
| `.githooks/pre-commit` | 정규식 `^modules/[^/]+/[^/]+\.tf$` -> `^modules/[^/]+/[^/]+/[^/]+\.tf$`, sed도 한 단계 깊게 |
| `.githooks/pre-push` | `for m in modules/*/` -> `modules/*/*/` |
| `.trivyignore.yaml` | `modules/workbench/main.tf` -> `modules/aws/workbench/main.tf` |
| `validate-doc-conventions.py:27` | `^modules/[^/]+/README\.md$` -> `^modules/[^/]+/[^/]+/README\.md$` |

**인수 조건**

```bash
# B1. 이력 보존
git log --follow --oneline modules/aws/vpc/main.tf | wc -l   # -> 1보다 큼

# B2. 게이트 4 등가 (존재 확인 + 실제 4회 실행)
[ "$(ls -d modules/*/*/ 2>/dev/null | wc -l)" -ge 1 ] || { echo "글롭 0건"; exit 1; }
for m in modules/*/*/; do tofu -chdir="$m" init -backend=false -input=false -lockfile=readonly \
  && tofu -chdir="$m" validate && tofu -chdir="$m" test; done   # -> 4회 실행, 전부 rc=0

# B3. 게이트 5 등가
[ "$(ls -d modules/*/*/examples/*/ 2>/dev/null | wc -l)" -ge 1 ]

# B4. 게이트 3 예외가 새 경로에 붙었다
trivy config --quiet --exit-code 1 --severity MEDIUM,HIGH,CRITICAL \
  --skip-dirs '**/.terraform' --tf-exclude-downloaded-modules \
  --ignorefile .trivyignore.yaml .        # -> rc=0

# B5. 생성 README 재분류 방지 (0-2의 38건이 0건이어야 한다)
python3 scripts/validate-doc-conventions.py   # -> rc=0

# B6. pre-commit 미탐 방지 — 검사가 실제로 돌았다는 로그로 판정 (rc 만 보지 않는다)
#     ⚠️ 실행 시점 전제: HEAD 가 이동 커밋인 상태(경로가 modules/aws/ 로 존재).
#     ⚠️ pipefail 오탐을 피하려 파이프를 쓰지 않고 출력을 변수로 받는다.
git add modules/aws/vpc/main.tf
out=$(.githooks/pre-commit 2>&1 || true)
printf '%s\n' "$out" | command grep -q 'terraform-docs drift' || { echo "drift 검사가 안 돌았다"; exit 1; }

# B6b. ★ pre-push 미탐 방지. stdin 4필드 모사 — 일반 분기 형태.
#      ⚠️ 실행 시점 전제: HEAD 가 이동 커밋이고 HEAD~1 이 그 이전.
#      pre-push 는 루프 0회에도 "통과 ✓"를 출력하므로 rc·메시지로는 구별 불가.
out=$(printf 'refs/heads/x %s refs/heads/x %s\n' "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)" \
      | .githooks/pre-push 2>&1 || true)
[ "$(printf '%s\n' "$out" | command grep -c '^  test: modules/aws/')" -eq 4 ] \
  || { echo "pre-push 가 4개를 안 돌았다"; exit 1; }

# B7. ★ stray 검사 음성 테스트 — depth 1 과 depth 2 를 **각각** 확인한다
#     (v2 의 단일 find -o 형태는 depth 1 을 놓쳤다. 픽스처로 재현됨)
touch modules/orphan.tf        && <stray 검사>   # -> rc=1  (depth 1)
rm modules/orphan.tf
touch modules/aws/stray.tf     && <stray 검사>   # -> rc=1  (depth 2)
rm modules/aws/stray.tf
<stray 검사>                                      # -> rc=0  (정상 트리)

# B8. 기능적 source 무손상 (0-3)
#     ⚠️ --exclude-dir=.terraform 필수. 빼면 다운로드된 원격 모듈의 상대경로가 섞여
#        3건이어야 할 결과가 225건이 된다(현재 트리 실측).
command grep -rn 'source = "\.\.' --include='*.tf' --exclude-dir=.terraform \
  modules/aws/eks-cluster/examples/
#   -> ../../../vpc · ../../../workbench · ../.. 3건, 수정 없음
```

⚠️ B6·B6b·B7이 이 단계의 핵심이다. B2~B5는 실패하면 시끄럽지만 이 셋은 실패해도 조용하다.

### Step 4 — 참조 전수 갱신 (커밋 2)

통합 grep 실측(`command grep` + `--exclude-dir=.omc`) 기준 **47건 / 18파일**:

| 파일 | 건수 | 성격 |
|---|---|---|
| `modules/eks-cluster/examples/enterprise/README.md` | 9 | 손작성 프로즈 (78·79행 소싱 예제) |
| `docs/module-catalog.md` | 7 | 링크 4(`](../modules/...`) + 소싱 예제 3 |
| `modules/vpc/examples/enterprise/README.md` | 7 | **55·65행에 `ref=vpc-v0.3.0` 하드코딩** |
| `README.md` | 5 | 모듈 표 링크 4 + 소싱 예제 1 |
| `docs/architectures/eks-gitops-hub-spoke/overview.md` | 3 | 다이어그램 주석 |
| `modules/eks-cluster/tests/plan.tftest.hcl` | 2 | **주석** (18·36행) |
| `modules/eks-cluster/examples/enterprise/main.tf` | 2 | **주석** (4·5행) |
| `docs/naming/abbreviations/aws.md` | 2 | 산문 |
| `modules/{vpc,eks-cluster,workbench,cross-account-trust-role}/README.md` | 각 1 | **9행 Usage 블록. terraform-docs inject 블록 바깥이라 자동 재생성으로 안 고쳐진다** |
| `modules/vpc/examples/enterprise/main.tf` | 1 | **주석** (9행) |
| `modules/eks-cluster/addons.tf` | 1 | **주석** (65행) |
| `docs/decisions.md` | 1 | 42행 산문 (현재 상태 서술) |
| `docs/conventions.md` | 1 | 111행 소싱 예제 |
| `CLAUDE.md` | 1 | **37행 소싱 예제** |
| `.trivyignore.yaml` | 1 | Step 3에서 처리 |

**추가 작업**

1. `README.md`·`docs/module-catalog.md`를 클라우드 중립 서술로: 모듈 표에 provider 축을 넣고
   현재 AWS 4개 / Azure 0개임을 **현재 사실로** 적는다. "곧 추가된다"류 예고 금지.
2. **태그 순환 해소**: `modules/vpc/examples/enterprise/README.md:55,65`의 `ref=vpc-v0.3.0`
   하드코딩을 **`vX.Y.Z` 자리표시자로 교체**한다.
   - Step 5의 안내문이 구 태그를 인용해야 하는데 `.githooks/pre-commit:45`의 stale 태그 검사가
     그 문장을 막고, `--no-verify`는 Must NOT Have다.
   - 자리표시자는 훅의 검사 대상이 아니다(훅은 `ref=` 뒤 완전한 semver만 본다).
   - **선례가 있다**: `modules/eks-cluster/examples/enterprise/README.md:46,78,79`가 이미
     `vX.Y.Z`를 쓴다. 새 규약이 아니라 기존 규약으로의 정렬이다.

**인수 조건**

```bash
# C1. ★ 경로 문자열 기반 단일 정규식 + 순정 grep + exclude-dir 3종
command grep -rnE 'modules/(vpc|eks-cluster|workbench|cross-account-trust-role)([/)`"?[:space:]]|$)' \
  --exclude-dir=.git --exclude-dir=.omc --exclude-dir=.terraform --exclude-dir=__pycache__ .
#   -> 0건
#   ⚠️ shim(Claude Code 세션의 grep)으로 돌리면 gitignore 를 존중해 다른 수가 나온다.
#      파이프 필터(v2안)로는 중첩 .omc 2건이 새어 49건이 된다 — --exclude-dir 이 정답이다.

# C1b. 필터 자가검증 (합성 픽스처, A5b 와 같은 형태)

# C2. ★ SC1 판정 — 기능적 .tf 수정 0건 (주석 갱신과 구별한다)
git diff --cached -U0 -- '*.tf' '*.tftest.hcl' | command grep '^[+-]' \
  | command grep -v '^[+-][+-]' | command grep -vE '^[+-]\s*#'        # -> 0건

# C3. 자리표시자 정렬 — 하드코딩 semver 가 예제 README 에 남지 않았다
command grep -rn 'ref=[a-z-]*-v[0-9]' modules/ --exclude-dir=.terraform    # -> 0건

# C4. stale 태그 훅이 새 상태를 막지 않는다
git add modules/aws/vpc/examples/enterprise/README.md && .githooks/pre-commit   # -> rc=0
```

> 🔴 **v1의 Step 4.6·4.7(tflint azurerm 등록 + 버전 대장 추가)은 삭제 상태다.**
> 근거는 2절 고지. Follow-up 2번으로 이관, open-questions 1번에 승인 대기.
> `verify.yml:74-75`·`:79` 주석의 stale 정정만 Step 3에 남겼다.

### Step 5 — 태그 재컷과 마이그레이션 안내

> 🔑 **착수 게이트**: open-questions 2번(소비 repo 승급 시점)이 **확정되어야 시작한다.**
> Step 1~4는 이 미결에 막히지 않는다.

**하는 일**

1. 4개 모듈 태그를 새로 컷한다. `0.y.z` 정책상 파괴적 변경도 마이너다:

| 모듈 | 현재 | 신규 |
|---|---|---|
| `vpc` | `vpc-v0.3.0` | `vpc-v0.4.0` |
| `eks-cluster` | `eks-cluster-v0.9.0` | `eks-cluster-v0.10.0` |
| `workbench` | `workbench-v0.7.0` | `workbench-v0.8.0` |
| `cross-account-trust-role` | `cross-account-trust-role-v0.2.0` | `cross-account-trust-role-v0.3.0` |

2. `docs/decisions.md`에 ADR 등재 (**8절**).
3. `README.md`에 마이그레이션 한 문단. **명령형으로 쓴다**(시나리오 2 차단):
   *"이 태그 이상에서는 `source` 경로에 `/aws`가 들어간다. **태그와 경로를 같은 커밋에서, 4개를 한 번에**
   올린다. 기존 태그는 그대로 동작하므로 승급 시점은 소비 repo가 고른다."*
   구체 태그 번호는 쓰지 않고 `git tag -l`로 확인하도록 안내한다.
4. `.githooks/pre-commit:45`의 stale 태그 컴포넌트 목록은 그대로 둔다. Azure 모듈 라운드에서 확장.
5. `.omc/notepad.md` + `.omc/project-memory.json` 갱신.

**인수 조건**

```bash
# D1. 새 태그가 새 경로를 가리킨다
git ls-tree --name-only vpc-v0.4.0 modules/aws/          # -> vpc 등 존재

# D2. 기존 태그가 여전히 구 경로를 가리킨다 (P3 증명)
git ls-tree --name-only vpc-v0.3.0 modules/              # -> vpc 존재

# D3. 소비자 관점 실사용 검증 (문서 대조가 아니라 실제 init)
tmp=$(mktemp -d) && cat > "$tmp/main.tf" <<EOF
module "vpc" { source = "git::file://$PWD//modules/aws/vpc?ref=vpc-v0.4.0" }
EOF
tofu -chdir="$tmp" init -backend=false                   # -> rc=0

# D4. 안내문에 하드코딩 태그가 없다
git add README.md && .githooks/pre-commit                # -> rc=0
```

---

## 5. Pre-mortem (DELIBERATE)

### 시나리오 1 — 로컬 게이트가 조용히 사라진 채 몇 주가 지난다

`verify.yml` 3곳은 CI가 빨간불로 알려준다. 그러나 `.githooks/pre-commit`의 drift 검사와
`.githooks/pre-push`의 `tofu test`는 매칭이 0건이 되면 아무 일도 하지 않고 통과한다.
**pre-push는 "테스트 통과 ✓"까지 출력**하므로 개발자가 "훅이 통과했다"를 "검사했다"로 읽을 근거를
적극적으로 제공한다.

**확률**: 높음. **영향**: 중간(CI가 최종 방어선). 그러나 "로컬=CI" 계약이 깨진 것은 구조적 손실.
**차단**: B6 + B6b. rc나 성공 메시지가 아니라 *몇 개를 돌았는지 세는 것*만이 판정이다.

### 시나리오 2 — 소비 repo가 태그만 올리고 경로를 안 고쳐 죽는다

`ref=eks-cluster-v0.9.0` -> `v0.10.0`으로 올리면 init이 실패한다. 발견은 빠르다. 더 나쁜 변형은
**부분 승급**이다. `vpc`만 새 태그·새 경로로 올리고 `eks-cluster`는 구 태그로 두면 둘 다 init은 되지만
서로 다른 트리 세대가 한 루트에 공존하고, `naming` 객체나 출력 계약이 바뀌었다면 plan 단계에서야 어긋난다.

**확률**: 중간. **영향**: 높음(고객사 배포 루트).
**차단**: (a) Step 5.3 안내를 명령형으로 (b) 강제 수단이 없음을 안내문에 명시
(c) **Step 5 착수 게이트**로 승급 시점 사전 합의.

### 시나리오 3 — 카탈로그 개명이 400줄 게이트를 깨고, 그 대응이 SSOT를 쪼갠다

`aws.md`(468줄)가 `LINE_LIMIT_EXCEPTIONS` 갱신 없이 머지되면 docs-conventions job이 죽는다.
잘못된 대응이 유혹적이다: 카탈로그를 `aws-network.md`·`aws-compute.md`로 쪼개면 게이트는 통과하지만
고유성 검사가 파일 단위이므로 **AWS 내부에서 파일을 가로지르는 약어 중복을 못 잡게 된다.**

> **고유성 범위 명시(축 3 근거와의 양립)**: **약어 고유성은 "한 클라우드 안에서" 정의되고,
> 카탈로그 파일 1개가 곧 1개 클라우드다.** 하나의 리소스 이름 안에 두 클라우드가 공존하지 않으므로
> `vpc`가 AWS와 Azure에서 각각 다른 것을 가리켜도 모호해지지 않는다. **클라우드 간 재사용 허용,
> 클라우드 내 분할 금지.** 이 문장은 ADR(8절)이 소유한다.

**확률**: 낮음~중간. **영향**: 높음.
**차단**: (a) Step 1의 개명 + 예외 목록 수정 + 참조 갱신을 **단일 커밋**으로 (b) 예외를 파일명 집합이
아니라 `docs/naming/abbreviations/` 접두사 판정으로 (c) **A3b 4종**(교체된 109행 + 되살린 106행의 음성 테스트).

### 시나리오 4 — 실행자가 오염된 도구로 green을 받고, 그것을 잡을 CI가 없다

**전개**: 실행자가 Claude Code 세션에서 C1·A5를 돌린다. 세션의 `grep`은 ugrep shim이라
`--ignore-files`(gitignore 존중)·`-I`(바이너리 스킵)가 강제로 붙는다. 잔여 참조가 gitignore된 경로나
`.pyc`에 남아 있으면 **shim은 0건을 반환**한다. 실행자는 "C1 통과"로 판정하고 PR을 올린다.

⚠️ **여기서 CI는 구해 주지 않는다.** C1·A5에 해당하는 grep을 도는 CI job이 **없다**
(`verify.yml` 전문 확인: 게이트 7개 + docs-ssot + docs-conventions 어디에도 잔여 참조 스캔이 없다).
따라서 잘못된 green은 red로 교정되는 것이 아니라 **조용히 통과**한다. C1·A5는 CI가 아니라
**사람이 실행하는 인수 조건**이므로, 도구가 오염되면 그 검사는 그냥 없는 것과 같아진다.

**이것은 가정이 아니라 이미 일어난 일이다.** v2의 0-4절 전체가 이 오염의 산물이었고,
그 위에서 Critic의 옳은 권고를 잘못된 근거로 기각했다.

**확률**: 높음(계획 실행자가 이 세션과 같은 환경일 가능성이 크다).
**영향**: 높음(교정 장치가 없다. 잘못된 green이 그대로 최종 판정이 된다).
**차단**: (a) **모든 grep 인수 조건에 `command grep` 명시**(Must Have)
(b) `--exclude-dir` 3종(`.omc`·`.terraform`·`__pycache__`)을 명령에 박아 shim의 암묵 동작에 의존하지 않기
(c) A5b·C1b를 **라이브 트리가 아니라 합성 픽스처**로 — 도구가 무엇이든 같은 답이 나온다.

---

## 6. 확장 테스트 계획 (DELIBERATE)

| 계층 | 대응 | 명령 | 통과 기준 |
|---|---|---|---|
| **Unit** | 검증기 정오답 | A1(회귀) · A2 · A3a · **A3b(5종)** | A1·A2 rc=0, 고장 6종 전부 rc=1 |
| 〃 | 상태 격리 | **A2b**(같은 약어를 가진 카탈로그 2개 동시 검사) | rc=0 (거짓 중복 에러 없음) |
| 〃 | 훅 방어 동작 | A8(`\|\| true`) · **B7(stray 음성 3종)** | rc=0 / rc=1 / rc=1 / rc=0 |
| 〃 | 필터 자체 | **A5b · C1b(합성 픽스처)** | 중첩 `.omc`까지 걸러짐 |
| 〃 | 포맷·린트 | `tofu fmt -recursive -check -diff`, `tflint --recursive` | rc=0 |
| **Integration** | 모듈 계약 | B2(존재 확인 + 4회 init/validate/test) | 4회 전부 rc=0 |
| 〃 | 예제 배선 | B3 | rc=0 |
| 〃 | 생성물 drift | terraform-docs `--output-check` x4 | drift 0건 |
| **E2E** | PR CI 전체 | verify(게이트 7개 + stray + 존재확인) · docs-ssot · docs-conventions | 3 job green |
| 〃 | 로컬 훅 실주행 | **B6 + B6b** | 검사 실행 계수로 판정 |
| 〃 | 소비자 관점 | D3(`git::file://` 실제 init) | rc=0 |
| **Observability** | 잔여 참조 | **C1 · A5**(`command grep` + exclude-dir 3종) | 0건 |
| 〃 | 모양 불변식 | stray 검사가 CI에 상주 | `modules/` 아래는 항상 `<provider>/<name>/` |
| 〃 | 기능/주석 분리 | C2 | 0건 |
| 〃 | 이력 보존 | B1 | 이동 이전 커밋이 보인다 |
| 〃 | 태그 이중 검증 | D1 · D2 | 신규=새 경로, 기존=구 경로 |

> **사람 판정 항목**: **A6 · A7 · E4**. 이 셋은 명령이 근거를 *출력*할 뿐 통과/실패를 *판정*하지 않는다.
> 나머지는 rc 또는 계수로 판정한다.

---

## 7. Success Criteria

1. `modules/aws/` 아래 4개 모듈, **기능적 `.tf` 수정 0건**(C2), 주석 6건은 갱신됨.
2. PR에서 `verify.yml` 3개 job 전부 green.
3. **stray 검사가 CI에 상주하고 음성 테스트 3종을 통과한다**(B7) — 모양이 불변식이다.
4. 로컬 훅 2종이 새 경로에서 실제로 검사를 실행함을 **계수로** 확인 (B6 + B6b).
5. C1·A5가 `command grep` 기준 0건, 합성 픽스처 자가검증 통과 (C1b·A5b).
6. `conventions.md`에 3층 구조 존재, 공통 층에 provider 고유 식별자 0건 (E1·E2).
7. Azure 절의 모든 사실 문장에 출처가 있거나 절이 비어 있다 (E4).
8. **죽은 파서 2곳이 살아났고**(A1 회귀 + A3b-b4·b5), 카탈로그 452행이 선언한
   **①섹션 헤더 · ②상단 총계 · ③요약 표 세 값 전부**가 실제로 강제된다.
   (이번 라운드 전에는 ①만 강제되고 있었다.)
9. 4개 신규 태그 발행, 기존 태그 무손상, 소비자 관점 init 성공 (D1·D2·D3).
10. `docs/decisions.md`에 ADR 등재(고유성 범위 문단 포함).
11. `.omc/notepad.md`·`project-memory.json` 갱신이 같은 브랜치에 실렸다.
12. 문서 선언(`writing-style.md:18`)과 코드 범위(`validate-doc-conventions.py:28`)가 일치한다 (A7).

---

## 8. ADR (docs/decisions.md 등재용 초안)

**Decision**: `modules/` 아래에 provider 층을 신설하고 기존 AWS 모듈 4개를 `modules/aws/`로 이동한다.
호환 shim을 두지 않는 클린 브레이크로 하고, 전환은 태그가 흡수한다.

**Drivers**: (1) 소비 repo 마이그레이션 타이밍 제어권 (2) 게이트가 조용히 축소되지 않을 것
(3) 개명·이동의 원자성

**Alternatives considered**:

| 안 | 기각 이유 |
|---|---|
| 호환 shim 모듈 유지 | 변수·출력 전량 중복. 게이트 4·7이 8개를 돌고 drift를 shim마다 관리. shim이 제공하려는 무손상 전환 기간을 기존 태그가 이미 공짜로 제공 |
| AWS 최상위 유지 + Azure만 `modules/azure/` | **사용자가 확정 결정으로 배제한 안이다**(재검토 대상 아님). 별도의 기술적 근거도 있다: 비대칭 트리는 게이트 글롭이 두 깊이를 동시에 만족해야 해서 미탐 위험을 영구화한다 |
| 단일 카탈로그에 Azure 절 추가 | 468줄 + Azure = 800줄대로 400줄 규칙 위반. 고유성 검사가 클라우드를 가로질러 거짓 충돌 |
| `docs/naming/{aws,azure}.md`(한 단계 얕은 안) | 디렉터리 접두사로 검증기 대상·400줄 예외를 지정하면, `naming/`이 다른 SSOT도 수용한다는 확장성 근거가 스스로 무효화된다 |
| 파일 내용 기반 카탈로그 식별(`## A.N` 유무) | "카탈로그가 아닌 파일은 조용히 건너뛴다"를 도입한다. 헤더가 깨진 진짜 카탈로그가 검사에서 조용히 빠지는 경로가 생겨 D2가 막으려는 미탐과 같다 |
| 2단계 PR | D3는 "한 커밋"만 요구하고, revert 시나리오가 실질적으로 없으며, `validate-doc-conventions.py` 27·28행이 인접해 층 분리가 성립하지 않는다 |

**Why chosen**: 기존 태그가 과거 트리를 그대로 가리키므로 이동은 **소급 파괴가 아니다**.
깨지는 시점은 소비 repo가 승급을 결정하는 순간뿐이고, 그 시점은 소비 repo가 고른다.

**약어 고유성의 범위 (이 ADR이 소유한다)**:
> 약어 고유성은 **한 클라우드 안에서** 정의되고, 카탈로그 파일 1개가 곧 1개 클라우드다.
> 하나의 리소스 이름 안에 두 클라우드가 공존하지 않으므로 `vpc`가 AWS와 Azure에서 각각 다른 것을
> 가리켜도 이름이 모호해지지 않는다. 따라서 **클라우드 간 재사용은 허용하고, 한 클라우드의 카탈로그를
> 여러 파일로 분할하는 것은 금지한다.**

**Consequences**:
- `eks-reference-infra`는 다음 승급 시 `source` 4곳을 태그와 함께 고쳐야 한다. 강제 수단은 없다.
- 게이트 글롭이 한 단계 깊어진다. 향후 모듈은 반드시 `modules/<provider>/<name>/` 형태여야 하고,
  **이는 stray 검사가 CI에서 강제한다**(주석이나 관행이 아니다).
- **태그 네임스페이스는 평면으로 유지한다**(`vpc-vX.Y.Z`). 따라서 모듈 디렉터리명은 provider를
  가로질러 전역 고유해야 한다. 현재 충돌 없음(Azure는 `vnet`·`aks-cluster` 예정).
  이는 결정이지 미결이 아니다. 강제 장치는 Follow-up 3번.
- `docs/naming/`은 주제 디렉터리, `docs/naming/abbreviations/`는 약어 카탈로그 전용이다.
  향후 다른 네이밍 SSOT는 `docs/naming/` 바로 아래에 두고 약어 검증기 대상에서 자동으로 빠진다.

**Follow-ups**: 10절 참조.

---

## 9. 개정 이력

### v2 -> v3

#### 최우선 — 두 검토자가 독립적으로 일치한 3건

- **grep 도구 오염 (Architect N3 = Critic F-B)** — **0-4절 전면 재작성 + 주장 철회.**
  `type grep`으로 직접 재현: 세션의 `grep`은 `~/.claude/shell-snapshots/`의 zsh 함수이고
  ugrep을 `--ignore-files --hidden -I`로 감싼다. v2가 이를 "저장소의 알려진 함정"으로
  **오귀속**했고 그 근거로 Critic의 1차 F-2 권고를 잘못 기각했다.
  `command grep`에서 `--exclude-dir=.omc`는 **중첩 경로까지 정상 동작**함을 확인(0건).
  → **F-2 권고 채택**: C1·A5에 `--exclude-dir=.omc,.terraform,__pycache__` 사용.
  v2의 파이프 필터는 중첩 `.omc` 2건을 놓쳐 49건이 됨을 실측(`modules/vpc/.omc/state/...`).
  **모든 grep 인수 조건에 `command grep` 명시**(Must Have) + **Pre-mortem 시나리오 4 신설**.
- **F-A: 요약 표 파서가 죽어 있다 (Critic 단독, CRITICAL)** — **0-5절 신설.**
  파이썬으로 직접 대조: 현행 84행 정규식은 별표를 요구해 8개 중 **0개**를 잡고, 제안된 대체식은
  **8개 전부**를 잡는다. v2의 `set()` 비교를 그대로 넣었다면 A1이 **결정론적으로 rc=1**이었다.
  → Step 1에 **선행 수정(84행) → 후행 교체(109행)** 순서를 계약으로 명시. A1을 **회귀 게이트**로
  재정의. A3b에 **b4(요약표 숫자 오류 픽스처)** 추가 — 106행의 죽은 검사가 되살아나고 카탈로그
  452행의 선언이 비로소 참이 됨을 검증. 이 결함 자체가 0-1과 같은 종류의 "선언 ≠ 코드"임을 명시.
- **F-C: `find -o` 셸 의미론 버그 (Architect N4 = Critic F-C)** — 픽스처로 직접 재현:
  v2 형태는 `modules/orphan.tf`(depth 1)를 **놓친다**(`modules/aws/stray.tf`만 출력).
  두 번 분리 호출 형태는 둘 다 잡는다. → Must Have·Step 3 교체, `| head` 제거(pipefail SIGPIPE),
  **B7을 depth 1 / depth 2 / 정상 트리 3종 음성 테스트로 확장**.

#### Critic 단독 MAJOR

- **F-D: 축 3 근거와 접두사 판정의 충돌** — 축 3을 `docs/naming/abbreviations/{aws,azure}.md`로
  **한 단계 세분화**(제시안 (i) 채택). `naming/`은 주제 디렉터리로 남아 확장성 근거가 살고,
  검증기 대상·400줄 예외는 `abbreviations/`로 정확히 한정된다.
  제시안 (ii)(내용 기반 식별)는 **기각**하고 ADR에 기각 사유를 남겼다 — "카탈로그가 아닌 파일은
  조용히 건너뛴다"를 도입해 D2가 막으려는 미탐과 같은 구조가 된다.
- **F-E: 자가검증의 라이브 트리 의존** — A5b·C1b를 **합성 픽스처**로 교체.
  v2는 "`.omc/`에 잔여 참조가 몇 건인가"를 셌는데 Step 1.10이 그것을 갱신하면 0이 되어
  자가검증이 스스로 실패하는 역설이었다. 픽스처는 도구·트리 상태와 무관하게 같은 답을 낸다.

#### Architect·Critic 공통 Minor

- Step 1.10 참조 목록에 스크립트 **자기선언 주석** 추가: `validate-abbreviations.py:2,9`,
  `validate-doc-conventions.py:9`.
- **B6b 실행 시점 전제** 명시(HEAD가 이동 커밋, HEAD~1이 그 이전). B6에도 동일 문구 추가.
- **B6의 파이프 오탐 제거** — `out=$(... || true)` 후 분리 판정(pipefail 환경 대응).
- **C3에 `--exclude-dir=.terraform` 추가.**
- **계수 assertion → 존재 확인(`-ge 1`)** — Architect Synthesis 채택. stray 검사가 *모양*을
  강제하면 글롭 매칭 집합은 곧 유효 모듈 집합이므로 개수를 박을 이유가 없고, 모듈이 늘 때마다
  기대치를 고치는 편집 세금도 사라진다. 이 논리를 D2 해소 방향 전환으로 1절에 명시.
- **절 번호 인용 정정** — "11절" → **8절**(ADR) 2곳. 변경 로그를 12절 → **9절**로(번호 공백 제거).
- **`verify.yml:79`** 를 74-75행과 함께 stale 주석 정정 대상에 포함.
- **P5 경계 명확화** — 판단 기준을 "검증 대상 0건"이 아니라 **"게이트를 깨뜨리거나 증명할 수 없는
  상태를 게이트에 넣는가"**로 재서술. 이 기준이라야 tflint azurerm은 걸리고 Step 2의 Azure 절은
  안 걸린다(문서는 게이트가 아니고 "규정하지 않는다"가 정직한 종착점).
- **Follow-up 1 문면 정정** — "9곳 단일화"는 달성 불가(셸 소비자는 5곳뿐, `verify.yml`의 YAML 구조와
  `validate-doc-conventions.py`의 파이썬 정규식은 셸 스크립트로 못 묶는다).
  "셸 게이트 5곳 단일화 + 나머지는 stray 검사로 간접 보장"으로 고치고, **우선순위를 낮췄다** —
  F-C 수정으로 stray 검사가 제대로 동작하면 이 Follow-up의 실익이 실제로 줄어든다.

#### v3에서 유지한 v2의 판단

- 축 1(클린 브레이크) · 축 2(단일 PR + 층별 커밋 2개) · 태그 순환 해소(자리표시자 정렬) ·
  고유성 범위 ADR 명시 · Step 5 착수 게이트 · stray 검사 Must Have · SC11(notepad) ·
  `.tf` "기능 0건 / 주석 6건" 분리.

### v3 -> v4 (최종 반영)

Architect · Critic 양측 APPROVE. 재검토 없이 텍스트 수정만 반영했다.

- **M-1 (Critic)** — **`validate-abbreviations.py:90`도 죽은 파서였다.** 직접 대조 확인:
  `r"총 \*\*(\d+)\*\*개 약어"`는 별표가 숫자만 감싼다고 전제하는데 실제는 `총 **311개** 약어`라
  별표가 "311개" 전체를 감싼다. 매치 0건 → `total_declared`가 항상 None → **112행도 죽은 코드**.
  → 0-5를 (a)84행 / (b)90행 **2건 구조**로 재작성, Step 1.1에서 같은 커밋 수정,
  **A3b에 b5 신설**(상단 총계 오류 픽스처), **SC8을 "①②③ 세 값 전부"로 확장**.
  이번 라운드 전까지 실제로 강제되던 것은 **①뿐**이었다는 사실을 명시했다.
- **M-2 (Critic) / N1 (Architect)** — Step 1.5의 "`sys.argv[1:]` 순회" 모호성 해소.
  두 검토자가 서로 다른 해법을 냈고(Architect: Follow-up 이관 / Critic: 상태 격리 명시),
  **Critic 안을 채택**했다 — 이번 라운드 스코프를 줄이지 않으면서 결함만 막고, Architect도
  "유지한다면"의 대안으로 같은 해법을 인정했다. Step 1.5를 문단으로 확장해
  **파일별 상태 리셋 6개 변수를 명시**하고 "약어 고유성은 파일 내부에서만 판정한다"를 계약화했다.
  격리하지 않으면 `azure.md`의 `vpc`가 거짓 중복 에러를 내며 **ADR의 "클라우드 간 재사용 허용"을
  코드가 뒤집는다.** **A2b 신설**로 검증한다.
- **Minor 1 (Critic)** — Step 1.2에 `mkdir -p docs/naming/abbreviations` 추가.
  없으면 `git mv`가 rc=128로 즉시 멈춘다.
- **Minor 2 / M1 (양측 동일)** — **B8에 `--exclude-dir=.terraform` 추가.** 실측으로 심각도 확인:
  제외 없이 돌리면 3건이어야 할 결과가 **225건**이 된다(다운로드된 원격 모듈의 상대경로).
- **Minor 4 (Critic)** — **존재 확인 "신설"은 오판이었다.** `verify.yml`에 이미 `found` 가드가 있다
  (게이트 4: 98·100행 / 게이트 5: 119·123행). Must Have와 Step 3 표를 "기존 가드 유지, 신설 불필요"로
  정정하고 `-ge 1`은 B2·B3 로컬 재현용으로만 남겼다.
- **M2 (Architect)** — Pre-mortem 시나리오 4 문면 정정. "CI가 red를 준다"가 아니라
  **"C1·A5에 해당하는 grep을 도는 CI job이 없어 조용히 통과한다"**가 맞다(`verify.yml` 전문 확인).
  영향도를 중간~높음 → **높음**으로 올렸다 — 교정 장치가 없으므로 잘못된 green이 곧 최종 판정이다.
- **M3 (Architect)** — A2 픽스처 요건("섹션 집합과 일치하는 요약 표 + 맞는 상단 총계를 포함해야 rc=0")과
  b4 단서("합계 값·섹션 헤더는 그대로 둔다")를 괄호로 명시. b5에도 같은 형태의 단서를 달았다.

> Critic의 Minor 3·5·6과 What's Missing 항목(A8 자가검증 무효 · `command find` 미명시 ·
> 상대링크 미검증 · `.omc` 잔여참조 판정 부재 · 실행자 도구 버전 전제 목록)은 **반영하지 않았다.**
> Critic이 "없어도 실행 가능"으로 분류했고, 착수를 막지 않는다. 실행 중 걸리면 그때 처리한다.

---

## 10. Follow-ups (ADR 등재)

1. **셸 게이트 5곳의 글롭 단일 소스화** (우선순위 하향) — `verify.yml` 3곳·`pre-commit`·`pre-push`가
   셸 소비자다. `scripts/module-dirs.sh` 하나로 묶을 수 있다. 나머지 2곳(`.trivyignore.yaml` YAML
   경로, `validate-doc-conventions.py` 파이썬 정규식)은 셸로 못 묶으며 **stray 검사가 모양을
   강제하는 한 간접 보장된다**. stray 검사가 상주하면 이 작업의 실익이 줄어든다.
2. **`.tflint.hcl` azurerm ruleset 등록** — 첫 Azure 모듈과 함께.
   **선행 조건**: `.githooks/pre-commit`에 `tflint --init` 추가(현재 62-63행에 없어 CI와 비대칭).
3. 모듈 디렉터리명 provider 간 전역 고유성 검사(태그 네임스페이스가 평면).
4. `.githooks/pre-commit:45` stale 태그 컴포넌트 목록을 Azure 모듈 추가 시 확장.
5. `docs/naming/abbreviations/azure.md` 신설 (Azure 모듈 라운드).
6. Azure 태깅 강제 방식 규정 (Step 2에서 비워 둔 경우).
7. `.githooks/*`를 실행하는 CI job 신설 — P1을 주석이 아니라 구성으로 강제.
