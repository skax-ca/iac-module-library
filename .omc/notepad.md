# Notepad — iac-module-library

## Priority Context

**OSS IaC 모듈 자산 SSOT** — 2026-07-29 신설. 원격: `skax-ca/iac-module-library`(**private**, 무료 org).
`origin`=`https://github.com/skax-ca/iac-module-library.git`, `main` 추적. push 정상.
- **org/팀 구조**: org `skax-ca`(무료) → Team **`iac`**(slug=`iac`, id=18738969, privacy=closed)에
  이 repo가 `maintain` 권한으로 소속. 향후 IaC repo는 `iac-` 프리픽스 + 아래 명령으로 팀에 붙인다:
  `gh api --method PUT orgs/skax-ca/teams/iac/repos/skax-ca/<repo> -f permission='maintain'`.
  ⚠️ **GitHub엔 org>프로젝트>repo 중첩이 없다** — "프로젝트 묶음"의 실체는 Team + 네이밍 프리픽스다.
- ⚠️ `gh` 토큰(silverte)에 **`workflow` 스코프 추가 완료** — `.github/workflows/` push에 필수.

- **배경**: `terraform-enterprise-poc`가 2026-07-28 **동결(졸업)**. 결정 전문은 그 repo의
  `docs/architecture/05-oss-asset-repo-decision.md`(D-OSS-STACK).
  ⛔ **PoC repo의 모듈·설계를 고치지 않는다** — 양쪽 개발은 곧 drift다.
- **스택**: OpenTofu **1.12.5** + GitHub Actions(OIDC) + S3 backend(`use_lockfile`) + OPA/Conftest.
  명령은 `terraform`이 아니라 **`tofu`**. hook 활성화됨(`git config core.hooksPath .githooks`).
- **⚙️ 엔진 결정 확정**(2026-07-29, `docs/architecture/04-engine-decision.md` = **D-ENGINE**):
  **OpenTofu 단독.** D-OSS-STACK(PoC repo `05`)의 엔진 축 **근거를 교체**했다 — 결론은 같고 이유가 다르다.
  - ⛔ **라이선스는 채택 근거가 아니다.** HashiCorp FAQ가 컨설팅 사용을 **명시적 허용**한다.
    비용 장벽은 CLI가 아니라 **HCP/TFE 구독**이었고 축 B(Actions+S3)로 이미 해소됐다.
    실제 근거는 **리워크 0 + OSI 조달 마찰 제거**다.
  - ⛔ **"두 엔진 지원" 재제안 금지 — 이미 값을 매겨 기각했다**(04 §3). Task 10.1 구현 중 실측:
    교차변수 validation 지원 확인 비용 · sentinel 우회 · lock 커밋 포기 · 로컬↔CI 피드백 지연 ·
    그리고 **`required_version`이 영구적으로 느린 엔진에 묶임**. 재검토는 **사건 발생 시에만**(04 §7-1).
  - Terraform 호환성은 **계약이 아니라 부산물** — 보장 안 하되 이유 없이 깨지 않는다(04 §5).
    OpenTofu 고유 기능(`encryption`·`.tofu` 확장자·`language {}`)을 쓸 때만 설계 문서에 이유를 남긴다. CI 없음.
    ⚠️ **`tofu {}` 블록은 존재하지 않는다**(04 §5 정정). 최상위는 `terraform {}`이고, 네이티브 대안은 1.12 `language {}`.
  - `.terraform.lock.hcl` **커밋 대상**(기존 규약 유지, `registry.opentofu.org` 확인).
  - `required_version`은 **모듈마다 다르다**(`02 §2` 하한 대장). 기준선 `>= 1.9.0`(교차변수 validation),
    **`vpc`는 `>= 1.12.0`**(D12 동적 `prevent_destroy`). 근거 없는 상향은 소비자만 배제한다.
- **D12 신설**(`design/10`): `deletion_protection`(기본 `false`) → `aws_vpc`에 동적 `prevent_destroy`.
  **OpenTofu 채택으로 얻는 첫 기능적 이득** — Terraform은 리터럴만 받아 모듈이 소비자에게 위임 불가.
  - 실측(1.12.5): `vpc_enabled=false` + `deletion_protection=true` → **plan 차단**. `false`면 통과.
  - ⚠️ **교차변수 validation은 `validate`가 아니라 `plan`에서 평가된다**(실측). `validate`는 Success로
    통과했다 → **`*.tftest.hcl`이 유일한 검출 지점**. `examples`의 `validate`로는 안 잡힌다.
- **완료**: §6-0 골격 + deepinit · §6-1 설계 승계 · §6-2 VPC 설계·구현·릴리스(**`vpc-v1.1.0`**) ·
  MCP 설정 · **엔진 결정 ADR 04** · 모듈 CI(`verify.yml` 게이트 6개) · D-CONSUME(`design/50`) Phase 5.
  커밋 `95e41dd` → `a6146ca` → `5abcb84` → `22ff67a` → `f5080f2` → `0754aa6` → `860da79`
  → `30ea306`(중립안 — **정정됨**) → `86cc91a`(D-ENGINE 확정) → `e89742d`(D12) → `1bd6641`(MCP 교체)

### 🔢 현행 릴리스 (2026-08-05 D-VERSION 이후)

> **최신 (2026-08-06 기준, `git tag` 실물과 대조함)**: `vpc-v0.3.0` ·
> **`eks-cluster-v0.4.0`**(D-EKS-CIDR-NULL, PR #14 `ade89e9`) · **`workbench-v0.1.0`**.
> ⚠️ **`bastion-v0.1.0` 은 존재하지 않는다** — 2026-08-06 개명 때 `workbench-v0.1.0` 으로
> 대체·삭제됐다(D-WORKBENCH-RENAME). 아래 8/5 서술에 남은 이름은 **그때의 사실 기록**이다.
> ⚙️ **`required_version` 은 전 모듈 `>= 1.12.0` 통일**(D-TOFU-FLOOR, 2026-08-05) —
> 모듈별 하한 대장은 **폐지**됐다. *"근거로만 올린다"* 는 이제 **1.13 이상에만** 적용된다.

전 모듈이 **`0.y.z`(개발 단계)**다.
구 `1.x` 태그 4개는 **같은 커밋의 `0.x` 로 재매핑된 뒤 삭제**됐다(원격 포함).
- ⛔ 아래 본문에 남은 `vpc-v1.x`·`eks-cluster-v1.0.0` 표기는 **그때의 사실 기록**이다.
  현행 태그로 읽지 말 것. 매핑: `v1.0.0/1.1.0/1.2.0` → `v0.1.0/v0.2.0/v0.3.0` · `eks v1.0.0` → `v0.1.0`.
- **마이너/메이저 판정을 하지 않는다** — `0.y.z` 에서는 전부 마이너다(`docs/architecture/05`).
- 상세는 아래 「🔢 D-VERSION」 절.

### 🔴 세션 시작 시 가장 먼저 볼 것 (최종 갱신 2026-08-05)

0. ⚠️ **이 파일이 stale해진 전례가 세 번 있다.** ① 2026-07-30 크로스-repo(소비 repo Phase 진행을
   여기 중복 기록) ② 2026-07-31 **같은 repo 안에서** — 열린 항목 7 구현·종결·6/6 판정 3커밋이
   PR 브랜치로 나갔는데 notepad 갱신이 거기 실리지 않아, 8/3 세션 시작 시 **이미 끝난 일을 다음
   태스크로 안내**했다. 🔑 **feature 브랜치에서 작업하면 notepad 갱신도 그 브랜치에 실어라.**
   ③ 2026-08-04 — **머지 뒤 notepad 커밋을 아예 안 냈다**(D-NODE-ARCH `74bbf51` + 작업 원칙
   `401b920`). ②의 교훈("브랜치에 실어라")으로는 **못 막는 유형**이다.
   🔑 그래서 **세션 시작 때 이 파일을 읽되 믿지는 않는다** — 판정 근거는 `git log` · `git tag` ·
   설계 문서 실물이다. 실제로 8/4 세션이 그렇게 교차 검증해서 "다음 태스크"가 이미 끝난 일임을 잡았다.

1. ✅ **`modules/vpc/` 커밋 완료**(2026-07-30) — `versions`·`variables`·`main`·`flow-logs`·`outputs.tf`.
   Task 10.1~10.4 종료. 게이트 전부 통과(fmt·validate·tflint·trivy 0건). **재작성하지 말 것.**
2. ✅ **MCP `opentofu` 승인·동작 확인**(2026-07-30). `get-resource-docs`는 **단독 호출**
   (`namespace`/`name`/`resource` 3인자). ⚠️ **`aws-docs`의 `search_documentation`은 SSL 인증서
   오류로 실패**한다(사내 프록시 추정) — `read_documentation`은 정상이므로 **URL을 알면 그걸 쓴다.**
3. ✅ **원격 repo 생성·push 완료**(2026-07-29): `skax-ca/iac-module-library`(private).
   `gh` 토큰에 **`workflow` 스코프 추가됨**(`.github/workflows/` 파일 push에 필수).

### ✅ §6-2 2단계 완료 — `vpc-v1.0.0` 릴리스됨 (2026-07-30) → **현행 `vpc-v1.2.0`**(08-03)

Task 10.1~10.7 **전부 종료**. 태그가 원격에 있다. 게이트 실측은 `docs/design/10-vpc-module.md` **§3 릴리스 기록**에 있다.

| Task | 커밋 |
|------|------|
| 10.1·10.2·10.3 | `65d2283` (+ `7114239` 네이밍) — `{versions,variables,main,flow-logs}.tf` |
| 10.4 | `8346672` — `outputs.tf` |
| 10.5 | `5129429` — `examples/vpc` + `examples/vpc-enterprise` |
| 10.6 | `7d753a8` — `tests/plan.tftest.hcl` **12 passed** |
| 10.7 | `27cd26e` + **태그 `vpc-v1.0.0`** |

- 검증 기준: **OpenTofu 1.12.5 · aws 6.57.1**(3개 루트 lock 정렬 완료).
- ✅ **apply 미검증 6항목은 2026-07-31에 전부 판정됐다**(아래 Phase 5 절 참조). v1.0.0 시점의
  *"증거가 전부 plan 수준"* 서술은 **더 이상 유효하지 않다** — 판정표 SSOT는 `design/10` §3이고,
  **✅가 찍힌 것만 실증했다고 쓴다**(특히 `prevent_destroy`는 validation 가드만 판정).
- **현재 릴리스는 `vpc-v1.2.0`**(2026-08-03, D13 `SubnetGroup` 태그). 소비 시 `?ref=vpc-v1.2.0`.
  직전 `vpc-v1.1.0`(07-31, Flow Logs confused deputy 방어)도 유효하다 — 1.2.0은 태그 추가뿐이라 재생성 없음.
- **`examples/vpc-enterprise`의 목적이 재정의됐다**: 검증 자산이 아니라 **고객사 착수 템플릿**이다
  (설계가 든 근거는 10.6 테스트가 이미 커버). `examples/AGENTS.md`의 "최소로 유지" 원칙에 대한 **의도된 예외**.

### ✅ 레퍼런스 소비 repo — **설계 완료(Phase 0)**. 이후 진행은 소비 repo 소관 (2026-07-30)

설계 SSOT는 **`docs/design/50-reference-consumer-repo.md` = D-CONSUME**(✅). 커밋 `96dcfab`.
실행 계획(Phase·수용 기준·위험표)은 **`.omc/plans/reference-consumer-repo.md`**(gitignore).
⛔ **D20~D29를 재논의하지 말 것** — 실측 근거와 기각 이유가 50에 다 있다.

**미해결 3건의 현재 상태** (2건 실측 종결, 1건은 방식 확정 + 구현 대기)

| # | 지점 | 상태 |
|---|------|------|
| 1 | private repo `git tag` 소싱 인증 | ✅ **종결**. 로컬은 `osxkeychain`으로 이미 동작 → CI는 **GitHub App 토큰 + `insteadOf`**(D20)로 **실측 검증 완료**(소비 repo `efe1776`). 소싱 URL은 `git::https://` 하나로 유지 |
| 2 | 부트스트랩 닭-달걀 | ⏳ 방식 확정 = **AWS CLI 스크립트(IaC 밖)**(D21, 사용자 선택), **구현은 소비 repo Phase 3**. ⚠️ 완화책 4종(멱등성·기대상태표·`verify.sh`·`import` 초안)이 **수용 기준**이다 |
| 3 | OIDC `sub` claim | ✅ **종결**. 3패턴 실측 완료(소비 repo `0cc0ec0`+`a2416d9`, 값은 그쪽 `docs/deployment-facts.md` §3). **plan/apply의 sub가 다르다**(D28)가 실측으로 확인됨 |

#### 📍 Phase 1 이후 진행 상태는 **여기서 추적하지 않는다**

진행 SSOT = `/Users/a07326/born2k/ai/iac-reference-infra` 의 `.omc/notepad.md`.
⛔ **Phase 체크박스를 이 파일에 중복 기록하지 말 것.** 양쪽에 두면 곧 drift다 —
2026-07-30 실제로 발생했다: 소비 repo는 Phase 2까지 끝냈는데 여기엔 "Phase 1 잔여 ⏸(GitHub App
생성)"이 남아 있어, 세션 시작 시 이미 해소된 일을 다음 태스크로 잘못 안내했다.
`CLAUDE.md`가 경고하는 *"양쪽 개발은 곧 drift"* 와 같은 구조의 사고이며, 코드가 아니라 **상태 기록**에서 났다.

**이 repo가 다시 관여하는 시점 = 소비 repo Phase 5** — **`docs/design/50` 개정**.
D26에 따라 **소싱 인증·backend 규약·OIDC 체인·plan artifact 계약의 SSOT는 이 repo**다.
⚠️ **개정 대상이 `docs/consumer/*`에서 `design/50`으로 바뀌었다**(D26-1) — 아래 참조.
개정은 **첫 apply 이후**에 한다(실측값 없이 쓰면 또 미검증 문서가 된다). 그때 반영할 실측 사실:
- OIDC `sub`는 **immutable이 맞다**: `repo:skax-ca@310520211/iac-reference-infra@1316830050:{pull_request | ref:refs/heads/main | environment:dev}`
- ⚠️ **`environment`가 `ref`를 덮어쓴다** → apply job의 브랜치 제한을 `sub`로 걸 수 없다(설계 미예상 제약)

**이 repo의 규약에 영향을 준 결정 — `D25`를 계정 식별 정보 일반으로 확장**: 계정 ID·Role ARN도
git에 두지 않고 repo 변수에 둔다. 소비 repo `docs/deployment-facts.md`는 **값이 아니라 포인터**를
기록한다 — D26의 "배포 사실은 소비 repo docs/에"를 그대로 적용하면 `backend.tf`에서 뺀 정보가
docs/로 새어 D25가 무의미해진다.

### ✅ 모듈 CI 구현 완료 (2026-07-30, 커밋 `47e133e`)

⚠️ **그 전까지 `CLAUDE.md`의 "모듈 CI가 검증한다"는 서술은 사실이 아니었다** — `.github/workflows/`에
`.gitkeep`만 있었고 게이트는 로컬 훅뿐이었다. Phase 2에서 Actions를 진단하다 발견해 실물을 맞췄다.

`verify.yml` 게이트 6개 — run [`30525585145`](https://github.com/skax-ca/iac-module-library/actions/runs/30525585145) 전부 통과 실측:
① fmt ② tflint ③ trivy ④ modules `init -lockfile=readonly`+`validate`+**`test` 12 passed**
⑤ examples(2개 루트, `Initializing modules...` 확인) ⑥ lock registry 검사(3개, 음성 테스트로 검증)

- 🔑 **CI와 로컬 훅의 도구 버전·플래그를 일치시킨다.** 어긋나면 사람이 CI를 신뢰하지 않게 된다.
  기준: OpenTofu **1.12.5** · tflint **0.63.1** · trivy **0.72.0** · aws ruleset **0.48.0**.
  ⚠️ `setup-tflint`가 "0.64.0이 나왔다"고 경고하는데 **의도적으로 0.63.1**이다. 올릴 땐 **양쪽 같이**.
- trivy는 `trivy-action`이 아니라 **바이너리 설치** — 액션은 플래그를 자기 입력으로 번역해
  pre-commit과 결과가 갈릴 수 있다. 파리티가 이 CI의 핵심 요건이다.
- `-lockfile=readonly`로 "lock 커밋됨"을 강제한다. tests 없는 모듈은 **실패**시킨다(02 §4).

### ⛔ D27 철회 → **D27-1**(실행 Role 신설) + **D27-2**(공용 계정 운영 규칙) — 커밋 `7df9edf`

**최초 D27**(`AWSAFTExecution`의 신뢰 정책을 `update-assume-role-policy`로 **전체 교체**)는
**철회됐다. 이 서술을 되살리지 말 것.**
- 철회 근거 = **F13(공용 개발 계정)**. `update-assume-role-policy`는 병합이 아니라 **덮어쓰기**라
  그 Role을 쓰는 다른 주체를 **말없이 끊는다**. `AWSAFTExecution`은 AFT 표준 이름이라 우리 PoC
  말고도 용도가 있을 수 있고, 공용 계정에서는 그 주체를 우리가 알 수 없다.
  "고아 Role이 남는다"는 원래 근거는 **비용이 아니라 미관**이었다.
- **D27-1(확정)**: 실행 Role을 **신설**한다 — `iamr-ref-dev-an2-gha-exec-01`(`AdministratorAccess`,
  신뢰는 입구 Role `iamr-ref-dev-an2-gha-entry-01` **하나만**). `AWSAFTExecution`은 **읽지도 쓰지도
  않는다** — 소비 repo 실측으로 principal이 **깨진 채 그대로**임을 확인했다(값은 적지 않는다 —
  남의 자산 식별자이고 notepad 는 커밋된다).
- ⚠️ **"`AWSAFTExecution` assume 불가"는 이제 해결 대상이 아니라 무관한 문제다.** 깨진 채로 둔다 —
  고치는 것도 남의 자산 변경이다.
- **D27-2**: 공용 계정 운영 규칙(PoC `05` §7.1 승계) — apply 승인 전 **destroy/replace 목록을 사람이
  읽는다**(예외 없음) · 우리 자산은 **`Workload=ref` 태그로만** 판별 · apply는 Environment 승인 게이트
  필수 · `prevent_destroy`(D12) 유지. `AdministratorAccess`를 **자동 트리거**에 연결한 것이 PoC와의
  실질적 차이라 규칙이 필요하다.
- 권한 축소는 **열린 항목**(50 §5-7). VPC 하나에 맞춰 최소권한을 뽑으면 EKS에서 다시 해야 한다.

### ⏭️ 이 repo의 다음 관여 지점

#### ✅ Phase 5 완료 (2026-07-31) — `design/50`·`design/10` 개정 끝

PR [#1](https://github.com/skax-ca/iac-module-library/pull/1)(`dec37a9`) · [#2](https://github.com/skax-ca/iac-module-library/pull/2)(`f19049a`, 계정 정보 정리).

- **🆕 D30 신설** — backend도 실행 Role을 체인 assume한다. D-CONSUME 범위가 **D20~D30**.
- **F16~F19** 추가 · **D27-2에 "승인 게이트는 GitHub Team 이상 요구" 전제** 등재.
- ✅ **apply 미검증 6항목 전부 판정 완료**(`694708f` — 판정표 SSOT는 `design/10` §3).
  5개는 소비 repo가 enterprise 형상을 택한 첫 apply로 판정됐고(판정 범위는 **형상 의존** — 50 §4),
  마지막 `prevent_destroy`(5번)는 별도 검증 PR로 닫았다.
  ⚠️ **판정된 것은 D12의 교차변수 validation 가드**다. `prevent_destroy` **lifecycle 메타 인자**
  (`destroy`·replace 차단)는 라이브 destroy-plan을 **실행하지 않았다**(자산 유지 결정, deploy.yml에
  destroy 경로 없음). 두 가드를 뭉뚱그려 "파기 검증 완료"라고 쓰지 말 것.

#### ✅ 열린 항목 7 (Flow Logs confused deputy) 종결 — **`vpc-v1.1.0`** (2026-07-31)

PR [#3](https://github.com/skax-ca/iac-module-library/pull/3)(`57912fb` 구현) ·
[#4](https://github.com/skax-ca/iac-module-library/pull/4)(`04910ce` 문서 종결) · 태그 **`vpc-v1.1.0`**(`4b9bacd`, 원격 push 완료).

`vpc-flow-logs.amazonaws.com`은 전 세계 공용 서비스 principal이라 v1.0.0의 조건 없는 신뢰 정책은
남이 우리 Role ARN을 자기 flow log에 걸면 **우리 로그 그룹에 남의 트래픽 + 우리에게 ingestion 청구**
(피해 방향이 직관과 반대)였다. `aws:SourceAccount` + `aws:SourceArn`(`ArnLike`) 조건을 추가했다.

- **계약 불변 + 동작 변경 → 마이너**. 변수 추가 없음. `data.aws_caller_identity`·`aws_partition`·
  `aws_region` 3개를 D10 게이트(`flow_logs_enabled`)와 함께 추가했다.
- ⚠️ **`aws:SourceArn`의 flow log ID 구간은 와일드카드가 불가피**하다 — ID를 넣으면 Role ↔ flow log
  순환 참조로 plan이 실패한다. AWS 공식이 허용한다. 계정·리전·서비스 구간이 남아 차단은 성립한다.
- ⚠️ **provider 6.x에서 `aws_region`의 `name`·`id`는 deprecated** — `region` 속성을 쓴다(실측).
- ✅ **판정 = 실계정 로그 도착 재확인**(`tofu test` 통과가 아니었다). 소비 repo PR #8 merge → apply
  `0 added, 1 changed, 0 destroyed`(IAM 신뢰 정책 **in-place**) 후
  `aws logs filter-log-events --start-time <apply epoch ms>`가 apply **이후** 타임스탬프의 `ACCEPT OK`를
  돌려줬다 = 서비스가 새 조건 하에서 assume 성공. **음성 근거를 확보한 양성 판정**이다.
  🔑 이 실패 모드의 정의가 "**조용히 실패**"라 `apply` 성공은 증거가 아니었다 — 이 구분을 유지할 것.
- ⛔ 기각안: opt-in 변수로 두는 안 — 보안 기본값을 끄는 스위치를 계약에 남기게 된다.

#### ✅ EKS 설계 개정 완료 (2026-08-03) — `design/20` ✅ · `design/21` 신설

커밋 `7183f7f`(브랜치 `docs/eks-design-revision`). `docs/README.md` 상태표: **20 ✅**(= `eks-cluster-v1.0.0`
계약 SSOT) · **21 ⚠️ 미결정**.

- **21은 "미개정"이 아니라 "미결정"이다** — 구 20 §2.7·§2.8(ArgoCD seam, 446줄)을 분리했다.
  `01 §3.3`이 *"이 repo는 아직 이 선택을 승계하지 않았다"* 고 명시한 **재결정 대상**이고,
  구현체가 `live/cicd/gitops-hub`라 `03 §4`상 이 repo 소유가 아니다.
  ⚠️ **절 번호 §2.7·§2.8을 이관본에서 그대로 유지**했다 — 30·40이 "20 §2.7"로 20곳 넘게 참조하는데
  둘 다 미개정이라 번호를 바꾸면 링크가 전부 끊긴다. 30·40 개정 시 `21 §2.7`로 함께 정리한다.
- ⛔ **승계 시 걷어낸 치명 결함**: PoC의 `required_version >= 1.14.0`은 **Terraform 버전**이었다
  (OpenTofu 최신 1.12.x) — 그대로 두면 **어떤 OpenTofu로도 init 불가**. 승계 문서에서 버전 문자열은
  항상 어느 엔진의 것인지 확인한다.
- **신설 결정**: **D-EKS-ENABLED**(kill switch, VPC D10 대응) · **D-EKS-PROTECT**(삭제 보호, VPC D12 대응).
  ⚠️ **D-EKS-PROTECT는 아직 미확정이다** — VPC는 `aws_vpc`를 직접 선언해 `lifecycle`을 붙였지만
  **EKS 클러스터는 upstream 모듈 내부 리소스**라 wrapper가 `lifecycle`을 못 붙인다. 구현 경로는
  **Task 20.1(e)**에서 확정하며, 그 결과가 `required_version` 하한(`>= 1.12.0` vs `>= 1.9.0`)을 좌우한다.
  → **`02 §2` 하한 대장 등재는 그때** 한다(지금 등재하면 근거 없는 상향이 된다).
- **열린 항목 2건을 계약으로 승격**: Karpenter **SG** discovery 태그(PoC의 실제 사고 — subnet만 달고
  node SG를 빠뜨려 프로비저닝 실패) · 컨트롤플레인 로깅(`enabled_log_types`).
  🔑 재사용 자산에서 **"보류"는 곧 모든 고객사의 기본값**이 된다 — PoC의 보류를 그대로 승계하지 않는다.

**실측 확인(2026-08-03)**: `terraform-aws-modules/eks` OpenTofu registry 최신 **21.24.1**(PoC 핀 21.24.0,
메이저 churn 없음) · `eks-pod-identity` **2.8.2**(PoC 2.8.1) · EKS k8s standard support **1.36/1.35/1.34/1.33**
(N-1 기본값 `1.35` 유효) · 약어 `eks`·`eksn`·`eksf`·`iamr`·`vpce` 전부 등재됨(신규 불필요).

#### ✅ Task 20.1 (a)(b)(c)(e) 완료 (2026-08-03) — ⏸ (d)만 AWS 계정 대기

upstream 소스 직독(`v21.24.1`·`v2.8.2`)으로 확인. **설계를 바꾼 발견 2건**:

1. **⭐ `aws_eks_cluster`에 네이티브 `deletion_protection`이 있다** → D-EKS-PROTECT를
   `prevent_destroy` 없이 구현. **`required_version` 하한이 `>= 1.12.0` → `>= 1.9.0`으로 내려갔다.**
   🔑 **"VPC가 이렇게 했으니 EKS도"는 위험한 대칭**이었다 — VPC가 `prevent_destroy`를 쓴 건 VPC에
   네이티브 보호가 **없어서**지 그 방식이 우월해서가 아니다. **리소스마다 provider가 주는 것을 먼저 본다.**
   ⚠️ 이 보호가 `prevent_destroy`보다 **강하다**(AWS API 차원 = 콘솔에서도 못 지움 > IaC 차원).
2. **⭐ upstream 3개 모듈 전부 `create` 토글 보유** + **자체 data source까지 `local.create`로 게이트**
   → D-EKS-ENABLED를 `count`가 아니라 `create` 위임으로 구현. `module.eks[0]` 인덱싱이 사라진다.

기타: `enable_pod_identity` v21에 **없음** 확인(facade 삭제 근거) · karpenter 출력 5종 예상과 **일치** ·
`iam_role_name` 등 override 실재(§2.6 가역성 근거) · `eks-pod-identity` 핀 **2.8.2**.
⚠️ **함정**: upstream 출력 fallback이 불일치 — 대부분 `try(…,null)`인데 **`cluster_name`·`cluster_id`만 `""`**.
facade가 `null`로 정규화한다(안 하면 upstream 구현 디테일이 우리 계약으로 샌다).

#### ✅ Task 20.2~20.7 완료 (2026-08-03) — ✅ **main 머지됨** (PR #6, `069a87b`)

PR [#6](https://github.com/skax-ca/iac-module-library/pull/6) 머지 커밋 `069a87b`. 브랜치 삭제됨. 커밋 4개:
`9aa4cb5`(20.2~20.4 모듈 본체) · `52ee220`(20.5 출력 + 20.6 예제 2종) ·
`bea58aa`(20.7 tests 16 run + 설계 §2.5 정정) · `4f44dd8`(**vpc D13** + design/20 §2.5-1 신설).

**게이트 실측**: vpc test **13 passed** · eks-cluster test **16 passed** · examples 4개 validate ·
tflint 0 · trivy 0 · lock `registry.opentofu.org`.
✅ **CI 재확인**: PR run [`30786603865`](https://github.com/skax-ca/iac-module-library/actions/runs/30786603865) 6/6 pass ·
머지 후 main run [`30786772334`](https://github.com/skax-ca/iac-module-library/actions/runs/30786772334) 6/6 pass.

**🔑 구현이 발견한 것 (설계에 없던 것)**
1. **테스트가 실제 결함을 잡았다** — upstream이 `iam_role_use_name_prefix` 기본 true로
   `<NG이름>-eks-node-group-`(40자)을 만드는데 **한도가 38자**라 plan이 죽었다. facade가
   `iam_role_name`을 카탈로그 이름으로 직접 지정해 해결. **`validate`로는 안 잡힌다.**
2. **⚠️ `override_module`은 facade 모듈에 쓸 수 없다** — override는 모듈 **실행만** 대체하고
   **입력 표현식은 그대로 평가**한다. `module.eks`를 덮으면 그 안의 `eks_managed_node_group`이
   사라진 부모 리소스(`time_sleep.this[0]`)를 참조하다 죽는다. 중첩까지 덮어도 같다.
   → mock_provider 8종 + **기본 시나리오에서 NG 비움**. ⚠️ **잃은 것: NG 경로 회귀 가드**(위 1번 결함의
   재발을 막는 테스트가 없다). NG 형상은 라이브 apply가 판정한다.
3. **§2.5 "Pod ENI SG = node SG 재사용"은 구현 불가**였다 — `module.eks.node_security_group_id`를
   같은 모듈의 입력(`addons`)에 넣으면 순환. → ENIConfig에서 `securityGroups` **생략**하면
   vpc-cni가 primary ENI SG를 상속해 **의도가 그대로 달성**된다. 설계 정정 완료.
4. **`effective_addon_names` 출력 신설** — facade는 계산 결과를 하위 모듈 **입력**으로 넘겨
   `tofu test`가 볼 수 없다. addon merge를 config-time에 검증할 유일한 관측점.

**🆕 D13 (vpc 마이너 — ✅ **`vpc-v1.2.0` 발행 완료**, `069a87b`)**: `aws_subnet`에 **`SubnetGroup = <그룹 키>`**.
소비 프로젝트의 eks 루트가 `data.aws_subnets`로 그룹 조회를 하려면 v1.1.0까지는 **`Name` 와일드카드
문자열 매칭**뿐이었다. 실패 방식이 나쁘다 — 규약이 바뀌면 에러가 아니라 **빈 결과**다.
🔑 `03 §3.1`이 태그 조회를 2순위로 둔 것은 *"이름이 아니라 태그로 조회하라"*인데 **그 태그를 우리가
제공하지 않고 있었다**. `Name`(사람용)과 조회 키(기계용)를 분리한다.
- **`design/20 §2.5-1` 신설** — "소비 프로젝트에서 VPC를 참조하는 법"(원칙은 03에 있었으나 EKS 적용 서술이
  없었다). ⛔ `terraform_remote_state` 금지 · 배포 순서 networking → eks-cluster.
- 예제 README 2종에 *"예제가 VPC를 함께 만드는 것은 **예제라서**"*(01 §4 self-contained 요건)를 명시.
  ⚠️ 안 적으면 고객사가 두 루트를 합치고 **apply가 성공하기 때문에 아무도 지적하지 않은 채 굳는다.**

#### ✅ 릴리스 — **`vpc-v1.2.0` 발행 완료 (2026-08-03)** · ⏸ `eks-cluster-v1.0.0` 대기

**현행 vpc 릴리스는 `vpc-v1.2.0`**(annotated tag → `069a87b`, 원격 push 완료). 소비 시 `?ref=vpc-v1.2.0`.

⚠️ **한 브랜치에 모듈 둘이 섞여 있었고, 태그는 각각 나간다** — 그래서 **`vpc-v1.2.0`이 가리키는
트리에는 아직 릴리스되지 않은 `modules/eks-cluster`가 들어 있다.** 소비자는 `//modules/vpc`
서브디렉터리만 소싱하므로 실해는 없지만, *"태그 = 그 컴포넌트의 릴리스 지점"* 이라는 의미는
그만큼 흐려졌다(태그 메시지에 명시해 뒀다). 🔑 **다음부터는 컴포넌트별로 브랜치를 가른다.**

⛔ **`eks-cluster-v1.0.0` 차단 = Task 20.1(d) addon 핀 소싱**(AWS 계정 대기).
`aws eks describe-addon-versions`로 실측 버전을 박아야 하고, 핀 없는 baseline은
**D-ADDON-VERSION-PIN 위반**이다. 지금 `addons.tf`의 `addon_version_pins`는 **전부 null**이며
그 자리에 ⏸ 주석이 있다. **코드는 main에 있으나 릴리스는 안 됐다** — 이 상태를 "EKS 완료"로 읽지 말 것.

#### 🔁 릴리스 때마다 할 일 — ① **예제의 소싱 태그** ② **`docs/README.md` 상태표**

> ### ② `docs/README.md` 상태표 갱신 (2026-08-06 추가 — **3번째 재발이라 규칙으로 승격**)
>
> **태그를 발행하면 그 모듈의 설계 문서 상태표 줄도 같은 커밋에서 올린다.**
> 상태표는 장식이 아니라 *"확정 설계로 인용해도 되는가"* 의 **판정 근거**라, 뒤처진 줄은
> 곧 **잘못된 인용 허가**다. ①(예제 소싱 태그)과 실패 구조가 같다 — 낡아도 아무것도 깨지지 않는다.
> - 확인 방법: `git tag --sort=-creatordate` 의 최신값과 상태표 각 줄의 태그·§번호를 대조
> - 실측 3회: 2026-08-03(20) · 2026-08-06(20 §4.4 = `eks-cluster-v0.4.0`) ·
>   같은 날 **40**(D-WORKBENCH-RENAME + §7.3 판정이 8/5 표기에 멈춰 있었다, `bfc9cbb` 에서 정정)
> - ⛔ **"그때의 사실" 기록은 최신화 대상이 아니다** — 발행 기록·판정 경로·당시 로그.
>   상태표 줄(현행 계약)과 본문 기록(과거 사실)은 성격이 다르다.

##### ① 예제의 소싱 태그 갱신 (2026-08-03 실제로 놓쳤다)

PR [#7](https://github.com/skax-ca/iac-module-library/pull/7)(`4bb9e8c`). `examples/vpc`가 소비 안내로 **`?ref=vpc-v1.0.0`** 을 적고 있었다 —
그 사이 **v1.1.0은 보안 수정**(Flow Logs confused deputy)이었다. 고객사가 복사하면 방어가 빠진 채로도
**`apply`는 성공한다** = D13이 지적한 *"apply가 성공하기 때문에 굳는다"* 와 **같은 실패 구조**.

- 🔑 **태그를 발행하면 예제의 소싱 주석·비교표도 같이 올린다.** 숫자만 올리면 다음 릴리스에 또 낡으므로
  **확인 방법**(`git tag -l 'vpc-v*'`)을 문서에 함께 적어 뒀다.
- 태그 문자열은 **모듈당 한 곳**에만 둔다 — `vpc-enterprise`는 `examples/vpc/README.md`로 위임한다.
- ⛔ **최신화하면 안 되는 것**: `design/50 §F2`(당시 clone 로그) · `design/10 §764`(v1.1.0 판정 경로) —
  안내가 아니라 **사실 기록**이다. 형식 예시 4곳(`README`·`CLAUDE.md`·`modules/AGENTS.md`·`02 §`)은
  `<org>` 플레이스홀더라 템플릿임이 명확해 **의도적으로 제외**했다(사용자 판단).
- ⚠️ **`vpc-v1.2.0` 태그가 가리키는 트리에는 이 수정이 없다**(태그 발행 후 고쳤다). 발행된 태그는
  옮기지 않는다 — 소비 경로는 `//modules/vpc`라 무영향이고, 움직이는 태그가 훨씬 나쁘다.

#### ❓ 확인 완료 — **eks 예제의 `module.vpc.*` 직접 참조는 정상이다** (바꾸지 말 것)

`examples/eks-cluster*/main.tf`가 `module.vpc.subnet_ids_by_group["node-uniq"]`를 쓰는 것은
D13 이전 방식이 남은 게 **아니다**. `01 §4` self-contained 요건상 예제는 같은 루트에서 VPC를 만든다:
- 같은 apply에서 만드는 서브넷을 `data.aws_subnets`로 읽으면 **plan 시점에 빈 결과**다
- `depends_on`을 붙이면 read가 apply로 밀려 **unknown이 EKS 전체로 번진다** → 예제가 보여줄 형상이 사라짐

소비 프로젝트용 태그 조회 경로는 **README 비교표 2종 + `design/20 §2.5-1`** 이 담당한다.
🔑 이 repo는 **코드로 못 보여주는 것을 README 비교표로 보상**하는 구조다 — "예제를 실사용에 맞추자"는
제안이 또 나오면 여기를 먼저 읽는다.

#### ✅ Task 20.1(d) 완료 + ⛔ **D-ADDON-VERSION-PIN → `-1` 개정** (2026-08-03, PR #8 `f2a5c0d`)

**AWS 계정은 이미 있었다** — `aws configure list-profiles`에 `team`(533616270150) · `asset`
(614054776208). `describe-addon-versions`는 **클러스터 없이 되는 카탈로그 조회**라 선행 조건은
처음부터 해소돼 있었다. 🔑 "계정 대기"라고 적힌 차단은 **확인해 보니 차단이 아니었다.**

**⛔ 모듈은 addon 버전을 갖지 않는다.** 모듈이 소유하는 건 `most_recent = false` 하나이고,
버전 **값**은 소비 루트가 `cluster_addons`의 `addon_version`으로 소유한다.

- **철회 근거 ① 경계(사용자 지적, 결정적)** — addon 상향은 워크로드 운영 주기에 속한다. 공통
  모듈이 값을 들면 **고객사 A의 kube-proxy 상향이 모듈 릴리스를 요구하고 그 릴리스가 B·C에게도
  배송된다.** CLAUDE.md의 *"upstream cadence와 소비자 cadence를 분리한다"* 를 모듈이 스스로 깨는
  구조이며, D26에 비추면 버전 값은 **배포 사실** 쪽이다.
- **철회 근거 ② 정의역(실측)** — addon 버전은 `f(kubernetes_version, region)`이고 두 인자 모두
  소비자가 정한다. 두 축 모두 실제 파손 확인: k8s(1.35 핀을 1.34/1.33에 → `coredns`·`kube-proxy`·
  `metrics-server` 버전 없음, 11종 중 **3종만** k8s 의존) · 리전(`cert-manager` an2 `eksbuild.3` /
  ue1·ew1 `eksbuild.2`).
- 🔑 **두 결함은 한 뿌리의 두 증상이었다.** 리전 최소공통분모를 찾던 최초 대응은 증상 하나를
  눌러 담은 것이었지 원인을 건드린 게 아니었다.
- ⚠️ **막으려던 사고는 그대로 막힌다** — 원인은 upstream `most_recent = optional(bool, true)`였고
  끄는 주체는 여전히 모듈이다. 값 미지정 시 upstream이 `data.aws_eks_addon_version(most_recent=
  false)`로 그 클러스터의 k8s·리전에 맞는 AWS 기본 버전을 해석한다(**upstream `main.tf:759-778` 실측**).
- ⛔ **기각안**: 모듈이 k8s 버전별 핀 표를 소유하는 안 — 정의역은 풀리나 **경계는 그대로**.
- **(d) 나머지도 닫힘**: 11종 가용성 ✅ · vpc-cni 스키마 6키 ✅ ·
  ⭐ `EniConfig.subnets.securityGroups`가 **optional**임을 확인해 Task 20.7의 §2.5 정정을
  **추론에서 스키마 확증으로** 승격 · ⚠️ `metrics-server`의 AWS `owner`는 **community**다
  (우리 분류는 모듈소유/opt-in 축이라 무관 — **맞추려 하지 말 것**).

#### ✅ minimal 예제 2종 폐기 (2026-08-03, PR #9 `a530b74` — 사용자 결정)

`examples/vpc` · `examples/eks-cluster` 삭제. 남은 건 `*-enterprise` 2개. 사유는 **관리 비용**.

- `01 §4`의 실제 요건은 *"예제 **없이** 릴리스하지 않는다"* 이지 **개수가 아니다**(line 123).
- 🔑 **minimal이 "검증 자산"으로 보인 건 착시였다** — `validate`는 교차변수 `validation`·
  `precondition`을 평가하지 못한다(plan 전용). 판정은 처음부터 `modules/*/tests`가 하고 있었다.
- ⚠️ **폐기 전 이관이 실제 작업량이었다**: `vpc-enterprise`엔 "소비 프로젝트와 다른 점" 비교표가
  **아예 없었고** minimal README로 위임하고 있었다. 그냥 지웠으면 PR #7의 소싱 태그 안내가 통째로 사라졌다.
- `examples/AGENTS.md`의 **"최소로 유지"가 반대로 뒤집혔다** → **"모듈당 예제를 늘리지 않는다"** 로 교체.
- ⚠️ `-enterprise` 접미사는 폐기된 짝 때문에 남은 이름이라 실제와 어긋난다(개명 보류, AGENTS.md에 기록).

#### ✅ D30-1 — PR plan 제거 + apply는 `workflow_dispatch`로만 (2026-08-03)

소비 repo PR [#12](https://github.com/skax-ca/iac-reference-infra/pull/12)(**머지 대기**) + 이 repo `design/50` 개정 `70ad46d`.
⚠️ **plan/apply 파이프라인은 이 repo에 없다** — `verify.yml`엔 plan이 없고 대상은 소비 repo `deploy.yml`이다.

- **계기는 속도**(사용자): PR plan + merge plan→apply로 같은 계산을 두 번 했다.
- ⚠️ **실측이 요청의 전제를 바꿨다**: `dev` environment의 `protection_rules`는 `branch_policy`
  뿐이고 org plan은 **free** → private repo에 required reviewers를 걸 수 없다.
  **승인 게이트가 아직 없었고**, PR plan 댓글이 사람이 계획을 보는 유일한 지점이었다.
  그것만 빼면 무검토 계획이 `AdministratorAccess`로 공용 계정에 적용 = **D27-2 "예외 없음" 위반**.
- → **apply를 dispatch 전용으로.** 누르는 행위가 무료 플랜에서 승인을 대신한다.
  ⭐ `design/50`이 *"❌ 상실: 읽어야 진행된다는 강제력"* 이라 적은 것을 **되찾았다**.
  ⚠️ 단 **merge 권한자와 apply 실행자 분리는 여전히 없다**(required reviewers만이 준다).
- ✅ **IAM 수정 불요를 확인**: 신뢰 정책에 `ref:refs/heads/main` 패턴이 있어 dispatch run이 커버된다.
  안 봤으면 "merge는 됐는데 dispatch가 인증 실패"를 실행 시점에 만났을 것이다.
- **열린 항목**: sub 패턴 ①(`:pull_request`) 미사용 → 최소권한상 제거 대상(라이브 IAM이라 별건) ·
  소비 repo에 **PR CI가 없어졌다**(깨진 HCL은 merge 후 main plan에서 시끄럽게 실패).

#### ✅ D-NODE-ARCH — `ami_type` 노출 (2026-08-04, PR #10 `b1241c6` → `74bbf51`)

facade 가 `ami_type` 을 통과시키지 않아 graviton 이 막혀 있었다. **upstream v21.24.1 엔 처음부터
있었다** — "upstream 미지원"이 아니라 wrapper 가 가리고 있었을 뿐이다(CLAUDE.md 작업 원칙의 실측 사례).
- 닫힌 열거 validation 을 `ami_type` 에만 걸었다(오타 대가가 비대칭: 클러스터 생성 후 실패 vs 몇 초).
  ⚠️ 그 대가로 유지보수 부채가 늘었다 → `design/20 §5.1-9` 로 등재.
- 예제 addon 버전 핀도 같은 PR 에 실렸다.
- 🏷️ **태그 `eks-cluster-v1.0.0` 을 `74bbf51` 로 옮겼다.** 당시 소비 repo 는 plan 만 돌아
  **소비자 0** 이었다 — CLAUDE.md 가 인정하는 유일한 예외. **아래 apply 로 그 예외는 닫혔다.**

#### ✅ CLAUDE.md 작업 원칙 4종 채택 (2026-08-04, `401b920`)

발명 전 확인 · 죽은 경로 · 단순함 · 레이어. 대부분 실천하던 것의 규칙 승격이고,
**이 repo 에서 뜻이 달라지는 것만 번역**해 뒀다(산출물이 고객사 계약이라 일반 앱 규칙이 안 맞는다).

#### 🎉 EKS **apply 완료** (2026-08-04, 소비 repo `iac-reference-infra` `live/dev/eks`)

dispatch 2회. 클러스터 `eks-ref-dev-an2-main-01` ACTIVE · graviton NG `t4g.medium`×2 running ·
addon 8종 등록 · `deletion_protection` 콘솔에서도 삭제 불가 확인. 비용 ~$165/월(networking 포함).
- ⛔ **이 순간부터 `eks-cluster-v1.0.0` 태그는 고정이다.** 다음 변경은 **마이너를 컷한다.**
- 🔴 **`external_dns_iam` 이 실패했다 → D-EXTDNS-ZONE.** `external_dns_hosted_zone_arns = []` 면
  upstream 이 `Resource="*"` 정책을 만들고 AWS 가 **400 MalformedPolicyDocument** 로 거부한다
  (`route53:ChangeResourceRecordSets` 는 리소스 수준 권한). 소비 repo 는 `c33c87a` 로 일시 중단.
  ⚠️ **설계 문서가 반대로 적고 있었다** — *"비워 두면 전체 zone(`*`)이 **허용**된다, prd 필수"*.
  실제는 허용이 아니라 **거부**이고 dev·prd 를 가리지 않는 **차단 조건**이다. `§2.6a` 정정 완료.
- 🔑 **첫 apply 가 실패해도 클러스터는 이미 생성된다**(부분 적용). "실패 = 아무 일 없음"이 아니다 —
  비용은 그 시점부터 난다.

#### ✅ Task 20.8 문서 산출물 완료 (2026-08-04) — **태그가 문서를 앞서 있던 상태를 해소**

태그는 08-04 에 이미 나가 있었는데 설계가 요구한 산출물 3건이 비어 있었다. 전부 채웠다:
- `design/20 §4.1 릴리스 기록` **신설** — 게이트 8행 실측(OpenTofu 1.12.5 · aws 6.57.1 ·
  **`tofu test` 17 passed**) + **apply 판정 표**(✅8 / ❌1 / ⏸2, 판정 형상 명시).
- `02 §2` 하한 대장에 **`eks-cluster` `>= 1.9.0`** 행 — "확인했더니 기준선"과 "확인 안 함"은 다르다.
- ⚠️ **`trivy` 는 게이트 명령 그대로 돌려야 한다.** `--skip-dirs '**/.terraform'
  --tf-exclude-downloaded-modules` 를 빼면 upstream 소스가 스캔돼 `AVD-AWS-0104` 로 exit 1 이 난다.
  플래그 빠뜨린 측정은 **게이트 실패가 아니라 잘못 잰 것**이다(이 세션에서 실제로 한 번 헛짚었다).
- 설계↔실물 대조에서 나온 정정: `effective_addon_names` **계약 등재**(구현은 처음부터 있었고
  §3.2 표에만 없었다) · tftest **16→17 run** · `taints.value` `optional` · `docs/README` 상태표
  (`vpc-v1.1.0`→**`v1.2.0`**, 20 문서 개정일).

#### ⏭️ 다음 = **D-EXTDNS-ZONE 교차변수 validation → `eks-cluster-v0.2.0`**

`design/20 §5.1-8` 에 전문이 있다. **`.tf` 변경이므로 브랜치 → PR**(문서와 경로가 다르다).
⚠️ **버전이 `v1.1.0` 이 아니라 `v0.2.0` 이다** — 2026-08-05 D-VERSION 전환(아래 절).
⭐ 그리고 **마이너/메이저 판정을 하지 않는다** — `0.y.z` 에서는 전부 마이너다. 아래 "마이너인 이유"
문단은 이제 불필요하며 `design/20 §5.1-8` 에서 이미 제거했다.
- 넣을 것: `!(var.enable_external_dns_iam && length(var.external_dns_hosted_zone_arns) == 0)`
  — D-EKS-PROTECT 가드와 **완전히 같은 형태**다. + `variables.tf` 의 틀린 주석 정정 + tftest 1 run.
- **마이너인 이유**: 이 조합은 이미 apply 에서 죽는다. 새로 막는 것은 **성공하던 경로가 아니라
  이미 깨져 있던 경로의 plan** 뿐이다.
- ⛔ **upstream fix 를 기다리지 않는다** — upstream 버그가 아니라 **AWS IAM 제약**이고,
  조합을 막는 것은 facade 의 일이다.
- ⚠️ 태그는 **옮기지 않는다**(apply 됐다). `eks-cluster-v0.2.0` 을 새로 컷한다.

#### ✅ D-DAY2-PROFILE — `design/22-day2-operations.md` 신설 (2026-08-04)

발단: *"플랫폼팀 없는 고객사를 위해 helm·eksctl·bash 업그레이드 경로를 따로 주자"*(사용자).
**검토 결과 그 갈래가 서로 다른 두 축을 묶고 있었다** — 축을 나눴다.

- **축 A 버전 업그레이드 = 프로파일 무관 IaC 단일 경로.** 손잡이 셋
  (`kubernetes_version`·`ami_release_version`·`addon_version`)은 이미 소비 루트에 있다.
  ⭐ **없던 것은 도구가 아니라 런북**이었다. ArgoCD 도 클러스터 버전은 안 올려준다.
- **축 B Day 2 워크로드 배포 = 여기만 프로파일이 갈린다**(판별 4문항).
- ⛔ **eksctl 기각** — 자체 CloudFormation 스택이라 한 클러스터를 두 IaC 가 나눠 갖는다.
  게다가 `Name` 태그·카탈로그·tftest 계약이 그 경로엔 **하나도 안 걸린다**.
  bash `update-addon` 도 기각 — `most_recent=false`+핀 때문에 **다음 plan 이 되돌린다**(의도된 동작).
  04 §3(두 엔진 기각)과 같은 구조다.
- 🔴 **AWS 공식 순서 확인이 설계를 바꿨다**(`update-cluster.html`): 컨트롤플레인 → 노드 → **addon(마지막)**,
  **마이너 1단계씩**, 그리고 **올리기 전에 노드 kubelet 이 컨트롤플레인과 같아야** 한다.
  → **한 커밋에 셋을 다 바꾸면 안 된다. apply 3개로 나눈다.** 이 모듈은 vpc-cni 에
  `before_compute=true` 를 소유해 순서가 이미 심겨 있는데, 그건 **최초 생성** 기준이지 업그레이드가 아니다.
- ⭐ **§3.3 매핑표가 이 문서의 실질** — 모듈 출력 → helm/manifest 입력. **양쪽 프로파일이 같은 값**을
  쓰므로 미결정에 의존하지 않는다. upstream v21.24.1 소스 + 실제 GitOps 매니페스트로 실측:
  - Karpenter SA/ns 는 **자유값이 아니다**(`karpenter`/`kube-system`) — 모듈이 그 이름으로
    Pod Identity association 을 이미 만든다(`create_pod_identity_association` 기본 true).
    바꾸면 IAM 은 있는데 자격증명을 못 받는 **조용한 파손**.
  - EC2NodeClass `spec.role` 은 **파생 불가**(`node_iam_role_use_name_prefix` 기본 true → hash 접미사)
    → 출력 `karpenter_node_iam_role_name` 을 **반드시** 쓴다.
- ⭐ 부수 발견: **프로파일 B 의 helm 대상은 ALBC·Karpenter 둘뿐이다.** D-ADDON-BOUNDARY 가
  community addon 을 IaC 로 당겨 놓은 결정이 **GitOps 미보유 고객사의 진입 장벽을 부수적으로 낮췄다.**
- ⏸ **도달성(누가 클러스터 API 에 닿나)은 확정하지 않았다** — 21(미결정)·40(미개정) 소관.
  미결정 위에 확정을 쌓지 않는다. 나머지(런북·판별·매핑표)는 도달성과 무관하게 성립한다.
- ⚠️ **§2 런북은 연역이지 실측이 아니다.** 1.35→1.36 업그레이드를 아직 아무도 안 해봤다.
  첫 수행(소비 repo)에서 §2.4 표를 갱신한다.

#### 🧭 도달성 방향 확정 + **다음 세션 로드맵** (2026-08-04, 사용자 결정)

**도달 지점을 bastion 하나로 통일한다.** 22 §3.4 의 미결정이 방향까지 정해졌다(실행은 `40` 개정).

- 🔑 **bastion 은 프로파일 B 용 타협이 아니다 — `40` 이 이미 GitOps 의 전제였다.**
  그 문서가 bastion 을 **"GitOps seed 수행 지점"**(D-SEED-KUBECTL)으로 확정했고,
  `argocd_endpoint_access = private` 을 넘기려면 VPC 내부 조작 지점이 필요하다고 적었다.
  게다가 `40` 은 **SSM 기반**이라 SSH 키·인바운드 SG·public IP 가 없다 — 관리 표면이 원래 작다.
- **의존 순서(선택이 아니라 의존)**: `40` → `21` → `22 §3.4` 갱신.
  ⭐ **`40` 하나만 끝나도 값이 난다** — 소비 repo 가 *"bastion 이 없어 private-only 면 kubectl
  도달 지점이 없다"* 는 주석과 함께 **public 엔드포인트를 열어 둔 상태**다. 그걸 닫을 수 있다.
- ⚠️ **`21` 개정은 번역이 아니라 재결정이다**(01 §3.3). 관리형 Capability vs self-managed ArgoCD 를
  먼저 가른다. self-managed 를 택해도 helm 실행 지점이 필요해서 **어느 쪽이든 `40` 이 먼저**다.
  - ✅ **provider 리스크 없음**: `awscc` 가 registry.opentofu.org 에 있다(실측, 188개 버전).
    ⚠️ `awscc_eks_capability` **리소스 스키마는 착수 시 재조회**(21 이 v1.93.0 기준).
- ⚠️ **`40` 개정 때 "bastion 역할 범위"를 함께 정한다** — self-hosted runner 겸용 여부(22 §4-2).
  나중에 붙이면 인스턴스 타입·SG·IAM 이 전부 바뀐다.

#### 🔢 D-VERSION — **전 모듈 `0.y.z` 전환 완료** (2026-08-05, 사용자 결정)

**현행 태그는 `vpc-v0.3.0` · `eks-cluster-v0.1.0` 이다.** 구 `1.x` 4개는 **원격까지 삭제**됐다.
SSOT = `docs/architecture/05-versioning-policy.md`. 커밋 `b30b12b`(ADR) · `2d21dd1`(문서 40곳) ·
`34796eb`(게이트 실측). 소비 repo `81d6349`.

- **재매핑(같은 커밋, 내용 무변경)**: `vpc-v1.0.0/1.1.0/1.2.0` → `v0.1.0/v0.2.0/v0.3.0` ·
  `eks-cluster-v1.0.0` → `v0.1.0`.
- **발단**: 사용자 지적 — *"개발 단계인데 왜 버전이 계속 오르나."* 전제(*"1.0.0 미출시"*)는
  사실이 아니었지만(태그 4개 발행 + apply 완료) **직관은 옳았다.** 근거 2건이 repo 안에 있었다:
  ① `eks-cluster-v1.0.0` 태그를 옮겨야 했다(semver 가 금지하는 것 — **예외를 발명해야 했다는 것
  자체가 신호**) ② D-EXTDNS-ZONE 하나로 마이너/메이저를 문단으로 논증해야 했다.
- ⛔ **"개발 완료 후 전 모듈 1.0.0 일괄" 은 기각했다**(05 §4). 소비 경로가 태그뿐이라 태그를 안 달면
  `ref=main`(움직이는 참조)을 강요하고, 일괄 컷은 컴포넌트별 cadence 분리를 깬다.
- **`1.0.0` 컷 기준 5개를 05 §2 에 체크리스트로 박았다**(사용자 선택 = 모듈별 계약 안정 선언).
  ⭐ 기준 2가 이 repo 고유: **apply 판정표에 `❌`·`⏸` 가 없을 것** — `tofu test` 로 대체 불가.
  ⚠️ **`vpc` 가 첫 1.0.0 후보다**(05 §5-3) — 열린 항목 6건의 계약 영향 판정만 남았다.
- **신규 모듈은 `0.1.0` 시작**(D-VER-NEW). 다음 적용 = `bastion`.
- ⚠️ **버전 혼재는 결함이 아니라 정보다** — *"보기 안 좋으니 맞추자"* 제안이 나오면 05 §4를 읽는다.
- 🔑 **사실 기록은 번호를 유지하고 각주만 달았다.** `design/10 §3`·`20 §4.1`·`50 F2` 등은
  *"어느 릴리스에서 무엇이 판정됐는가"* 의 추적점이라 덮어쓰면 증거 연결이 끊긴다.
  안내(복사되면 굳는 것)만 갱신했다 — **40곳을 일괄 치환하지 않았다.**

**✅ 게이트 = 소비 repo CI plan 실측**: run [`30961419570`](https://github.com/skax-ca/iac-reference-infra/actions/runs/30961419570)(networking) ·
[`30961419575`](https://github.com/skax-ca/iac-reference-infra/actions/runs/30961419575)(eks) 둘 다 **`No changes.`**
- 🔑 **워크플로 `success` 가 아니라 로그 본문으로 판정했다** — 변경이 있어도 plan job 은 성공한다.
- 🔑 **D30-1(push=plan, apply=dispatch)이 이 게이트를 안전하게 돌릴 수 있게 했다.** push 가 apply 를
  트리거하는 구조였다면 핀 커밋 하나가 라이브 인프라를 건드렸을 것이다.
- 근거 보강: 모듈 **서브트리 SHA 동일**(`vpc` `753790d7…` · `eks-cluster` `761b0a62…`) +
  모듈 source 문자열은 **state 에 저장되지 않는다** → diff 가 생길 경로 자체가 없었다.

#### ✅ 이 머신(`/Users/born2k/…`) 게이트 도구 파리티 완료 (2026-08-05) — 새 머신마다 확인할 것

notepad 이 *"hook 활성화됨"* 이라고 적고 있었지만 **이 머신에서는 거짓이었다.** 경로도 다르다
(notepad: `/Users/a07326/…`). `brew` 설치와 `git config` 는 **clone·머신 단위**라 dotfiles 동기화로
따라오지 않는다. 소비 repo 경로도 다르다: **`/Users/born2k/silverte/ai/iac-reference-infra`**.

**현재 상태 — CI(`verify.yml`)와 완전 일치**:
OpenTofu **1.12.5** · tflint **0.63.1** · trivy **0.72.0** · aws ruleset **0.48.0** ·
`git config core.hooksPath .githooks` (양쪽 repo 설정 완료)

- 🔑 **`brew` 로는 파리티를 맞출 수 없다 — 정확 핀 도구는 릴리스 바이너리로 받는다.**
  실측(2026-08-05): brew 최신 trivy 는 **0.73.0** 이라 `brew upgrade` 했으면 기준(0.72.0)에서
  **더 멀어졌다.** brew 는 "항상 최신" 모델이고 이 repo 요건은 "**같음**"이다.
  ```
  brew uninstall trivy   # Cellar 심볼릭 링크 제거 후 아래 바이너리로 교체
  curl -sSL .../trivy/releases/download/v0.72.0/trivy_0.72.0_macOS-ARM64.tar.gz
  curl -sSL .../tflint/releases/download/v0.63.1/tflint_darwin_arm64.zip
  install -m 0755 <bin> /opt/homebrew/bin/<name>
  ```
- ⚠️ **tflint 는 다운그레이드였다**(0.64.0 → 0.63.1). `setup-tflint` 와 `tflint --version` 둘 다
  *"out of date"* 경고를 내지만 **의도된 핀**이다. 올릴 땐 CI 와 **양쪽 같이**.
- ✅ **교체 후 게이트 전량 실측 통과**: `fmt` · `tflint --recursive` · `trivy config` **0건** ·
  `vpc` **13 passed** · `eks-cluster` **17 passed** (전부 exit 0).
- ⚠️ trivy 리포트에 `terraform-aws-modules/eks/aws/*.tf` **행이 보이는 것은 정상**이다(0건).
  `--tf-exclude-downloaded-modules` 는 평가에서 빼는 것이지 리포트 행을 지우지 않는다.
  게이트 실패 신호는 **행의 존재가 아니라 종료 코드**다.
- ✅ **AWS 프로파일도 머신별 상태다.** 이 머신은 `team`(2026-08-05 사용자가 설정, 동작 확인) ·
  `born2k` · `default` 뿐이다 — 아래 §Task 20.1(d)의 *"`team` · `asset` 둘 다 있다"* 는 **다른 머신의
  2026-08-03 기록**이라 여기엔 **`asset` 이 없다**. `describe-addon-versions` 류 조회는 `--profile team`.
- ⚠️ **삭제된 태그도 clone 단위로 남는다** (2026-08-06, `/Users/a07326/…` 머신에서 실측).
  D-VERSION 이 원격에서 지운 구 `1.x` 태그 4 개가 **로컬에만 살아 있어** `git tag` 가 12 개를 냈다.
  **`git fetch --tags` 는 삭제를 따라오지 않는다** — `git fetch --prune --prune-tags origin` 이라야 한다.
  🔑 위 「세션 시작 시 가장 먼저 볼 것」이 *"판정 근거는 `git tag` 실물"* 이라고 적고 있으므로,
  **그 실물 자체가 머신별로 틀릴 수 있다**는 뜻이다. 새 머신에서 한 번 prune 한다.
  ⛔ 지우기 전에 **구 태그의 커밋이 현행 태그에 살아 있는지 대조**한다(4/4 동일 확인 후 삭제했다).

#### ✅ D-EXTDNS-ZONE 종결 → **`eks-cluster-v0.2.0` 발행 완료** (2026-08-05)

PR [#11](https://github.com/skax-ca/iac-module-library/pull/11) 머지 `91cd7f9`(구현 `e2c2c73`) ·
**태그 `eks-cluster-v0.2.0` 원격 push 완료**. 전문은 `design/20 §4.2`(릴리스 기록 신설).
✅ CI PR run [`30967422884`](https://github.com/skax-ca/iac-module-library/actions/runs/30967422884) **6/6 pass** —
로그 본문도 확인(eks 20 passed · vpc 13 passed · examples 2개 Success).

> 🔒 **`eks-cluster-v0.2.0` 은 이미 소비자가 있다 — 태그를 옮길 수 없다.**
> 소비 repo 가 같은 날 핀을 올리고 **apply 까지 마쳤다**. CLAUDE.md 가 인정하는 유일한 예외
> (*"소비자가 0일 때"*)는 **닫혔다** — 다음 변경은 `v0.3.0` 을 컷한다.
> ⭐ **핀 상향의 plan diff 가 0이었다**(`0 add / 0 change / 1 destroy`, destroy 는 addon 제거분).
> validation 만 추가한 릴리스는 리소스에 영향이 없어야 하고, 그것이 실측으로 확인됐다 —
> **`0.y.z` 구간에서 태그를 올릴 때마다 확인할 가치가 있는 지점**이다.
> ⛔ 소비 repo 의 Phase·진행 상태는 여기서 추적하지 않는다(위 §"Phase 1 이후" 규칙).
> 위 두 줄은 진행 기록이 아니라 **모듈 계약의 상태**(태그 고정 여부)라서 적는다.

- **가드**: `!(var.enable_external_dns_iam && var.cluster_enabled) || length(var.external_dns_hosted_zone_arns) > 0`
  — ⭐ **`&& var.cluster_enabled` 는 설계 §5.1-8 조건식에 없던 것**이다. 같은 "토글 × 리스트" 구조인
  `pod_subnet_ids` 선례를 먼저 찾아 붙였다. 없으면 **파기 경로 plan 이 거부**되어 반쪽 kill switch 가 된다.
  🔑 **설계 조건식을 그대로 옮기지 않은 것이 차이를 만들었다.**
- **test 17 → 20**(양성 1 + 음성 2). ⚠️ **기존 `controller_iam_opt_in_creates_roles` 가 apply 불가능한
  형상을 통과시키고 있었다** — zone ARN 없이 `enable_external_dns_iam = true`. 가드가 그걸 먼저 깼다.
  → §4.1 의 *"이 결함은 `tofu test` 로 잡을 수 없었다"* 는 **판정 대상을 바꾸면 뒤집힌다**:
  "AWS 가 이 정책을 받는가"(불가) → "이 조합이 우리 계약에 있는가"(가능).
- **예제가 Route53 private zone 을 직접 만든다**(사용자 결정). 약어 `hz` 는 카탈로그 기존 등재.
  ⛔ **더미 ARN 기각** — 복사해 apply 하면 존재하지 않는 zone 을 가리키는 IAM 이 **조용히** 생긴다.
  `force_destroy = true` 는 **예제에서만**(external-dns 가 IaC 밖에서 쓴 레코드가 teardown 을 막는다).
- **소비 프로젝트 기본값 = `enable_external_dns_iam = false`** + addon 미탑재(사용자 결정).
  되켤 땐 `data.aws_route53_zone` 으로 조회만 — zone 은 워크로드보다 오래 산다. 안내는 예제 README.
- ✅ **실측**: `[aws_route53_zone.internal.arn]` 처럼 **요소가 unknown 이어도 `length()` 는 확정적**이다
  (격리 재현). 이 확인이 없었다면 예제가 **CI `validate` 를 통과하고 고객사 plan 에서 죽었을 것**이다.
- 🔁 **eks 예제에 소싱 태그 확인 방법이 없었다** — PR #7 이 `examples/vpc/README.md` 에 둔 장치가
  PR #9(minimal 폐기) 때 eks 쪽으로 승계되지 않았다. 이번에 보완(`git tag -l 'eks-cluster-v*'`).

#### ✅ `40` 개정 + `modules/bastion` 구현 완료 (2026-08-05) — 브랜치 `feat/bastion-module`

**설계 개정은 main 에 있다**(`b323fa5`, push 완료). 구현은 브랜치 → PR.

- **40 이 21 과의 의존을 끊었다.** 개정 전 제목이 *"ArgoCD private 전환의 선결 과제"* 라
  **미결정(21) 위에 서 있었다.** *"엔드포인트를 닫은 클러스터에 누가 닿는가"* 로 일반화하니
  21 이 뒤집혀도 40 은 흔들리지 않는다. 🔑 **미개정 문서 개정은 번역이 아니다 — 의존 방향을 먼저 본다**
  (이 교훈을 `docs/design/AGENTS.md` 개정 절차에 박았다).
- **사용자 결정 3건**: D-BASTION-MODULE(⛔ 인라인 철회) · D-BASTION-SCOPE(runner 겸용 안 함,
  22 §4-2 종결) · D-BASTION-SEAM(EKS 접근 3층을 **주체/대상**으로 분할).
- **22 §3.4 도달성 미결정 종결.** 원문은 `<details>` 로 보존(후보 비교 논증이 40 §1.1 의 입력).

**구현 커밋 3개**(전부 게이트 통과 — fmt·tflint·trivy 0건·bastion 10 passed·eks 20 passed):
- `fae555c` **D-TOFU-FLOOR** — `required_version` 전 모듈 `>= 1.12.0` 통일(아래 절)
- `c4c8447` `modules/bastion` 신설
- `e7237d8` eks 계약 확장 + 예제 3층 배선

**구현 중 발견 4건 — 전부 설계에 반영했다**:
1. ⭐ **모듈 간 순환**(40 §5.1-1 신설): bastion↔eks 가 서로의 ARN 을 참조한다.
   해법은 **03 §3.1 1순위**(결정적 네이밍) — 루트가 `local.cluster_arn` 을 합성해 단방향으로 만든다.
   🔑 **03 의 조회 우선순위는 순환 해소 장치이기도 하다** — SG rule 분리(§2.2)의 값 층위 대응.
2. 🔴 **하드닝 2종은 plan 테스트로 지킬 수 없다**: `key_name`·`associate_public_ip_address` 는
   **미지정 자체가 계약**인데 optional+computed 라 mock 이 임의 값을 채운다(실측 `"Wb0Vk"`).
   ⛔ mock_resource 로 null 을 강제해 통과시키지 않았다 — **assertion 이 자기 모킹 설정을 검증**하게 된다.
   🔑 일반화: *"미지정"을 계약으로 삼는 항목은 plan 테스트로 지킬 수 없다.*
3. **facade 가 upstream 을 가린 사례 또 발견**: upstream v21 에 `security_group_additional_rules` 가
   처음부터 있었다(ami_type/D-NODE-ARCH 와 같은 형태). → `cluster_security_group_additional_rules` 신설.
   ⚠️ 함께 정정: `cluster_security_group_id` 출력 설명이 **값과 다른 SG**(EKS 자동 생성분)를 가리키고 있었다.
4. **예제를 신설하지 않았다**(설계 §7.2 정정): `examples/eks-cluster-enterprise` 가 이미
   `endpoint_public_access = false` 인데 **조작 지점이 없는 상태**였다 — 거기에 넣는 것이 그 미해결을 닫는다.
   신설하면 90% 중복 → drift. 또한 **40.4 를 별도 PR 로 쪼개지 않았다**(예제가 선행 의존) —
   분리해야 할 축은 PR 이 아니라 **태그**였다.

**⚠️ trivy 첫 예외**(사용자 승인): `AVD-AWS-0104`(무제한 egress). **경로 한정**(`.trivyignore.yaml`)으로
`modules/bastion/main.tf` 에서만 끈다 — 평면 `.trivyignore` 에 ID 를 적으면 **repo 전체에서** 그 룰이 꺼진다.
- ⚠️ **trivy 0.72 는 `.trivyignore.yaml` 을 자동 탐지하지 않는다**(실측). `--ignorefile` 을
  pre-commit 과 verify.yml **양쪽**에 넣었다. 평면 `.trivyignore` 는 삭제(죽은 경로).

**✅ 완결**: PR [#12](https://github.com/skax-ca/iac-module-library/pull/12) 머지 `417154b` ·
CI run [`30981984588`](https://github.com/skax-ca/iac-module-library/actions/runs/30981984588) **6/6 pass**
(로그 본문 확인 — bastion **10** · eks **20** · vpc **13 passed**, validate 5건, lock 5개 전부
`registry.opentofu.org`) · 태그 **2개 원격 push 완료**.
⛔ `eks-cluster-v0.2.0` 은 소비자가 apply 완료라 **옮기지 않았다** — v0.3.0 은 새 마이너다.

> ### 🔧 재발 방지 — **`git tag -m` 에 백틱을 쓰지 않는다. `-F <파일>` 을 쓴다.**
>
> 2026-08-05 실제 사고: 태그 메시지의 `` `bastion_enabled` ``·`` `ami_id` `` 가 **셸 명령 치환으로
> 해석**되어 (`command not found` 후 빈 문자열로) **그 자리가 통째로 사라진 채 발행**됐다.
> 커밋 메시지는 `-F -` + quoted heredoc(`<<'EOF'`)이라 멀쩡했는데 태그만 `-m` 을 썼다.
> - **소비자 0인 시점이라 같은 커밋에 메시지만 고쳐 재발행**했다(CLAUDE.md 가 인정하는 유일한 예외).
>   `git rev-list -n1 <tag>` 로 **전후 대상 커밋이 같음을 확인**한 뒤 `--force` push 했다.
> - 🔑 **릴리스 메시지는 장식이 아니다** — 예제 README 가 소싱 태그를 고를 때 `git show <tag>` 를
>   읽으라고 안내한다. 그것이 깨지면 계약 문서가 깨진 것이다.
>
> ### ℹ️ IDE(terraform-ls)의 "Unexpected attribute" 는 **오탐**이다
>
> 로컬 모듈에 변수를 추가하면 언어 서버가 **옛 스키마 캐시로 호출자를 검사**해 빨간 줄이 뜬다
> (실측: `cluster_security_group_additional_rules`). **판정 근거는 `tofu validate` 와 CI 다** —
> IDE 진단은 이 repo 게이트 정의에 없다. 해소: `Terraform: Restart Language Server`.

#### ✅ `design/20` 이 `v0.3.0` 을 따라잡았다 (2026-08-06) — **태그가 문서를 앞선 상태 재발**

세션 시작 교차 검증에서 발견. `docs/README.md` 1줄만 stale 인 줄 알았는데 **릴리스 기록 전체가 빠져
있었다**. `20 §4.3` 신설 + §3.1 변수 등재 + §5.1-9 종결 + 헤더 3곳 갱신(main 직접 커밋, 문서 전용).

- 🔑 **같은 유형이 2026-08-04(Task 20.8)에 이어 두 번째다.** 원인이 같다 — **릴리스 PR 이 모듈 코드와
  설계 문서를 함께 싣지 않는다.** 40(bastion 설계)은 구현 PR 에 실렸는데 **20(eks 설계)은 안 실렸다**.
  ⇒ **파급받는 모듈의 설계 문서도 그 PR 에 넣는다.** 태그를 다는 모듈 수만큼 §4.x 릴리스 기록이 필요하다.
- ⚠️ **실질적 결함은 §3.1 누락이었다** — *"§1~§3 이 현행 계약"* 이라고 선언한 문서에
  `cluster_security_group_additional_rules` 가 없는데 **예제는 그걸 쓰고 있었다.**
  소비자가 계약을 읽는 지점이 §3 이라 여기 없으면 없는 기능이다.
- 🔑 **출력 "설명"이 틀린 결함은 계약 표에서 안 보인다**(§3.2 상자로 승격).
  `cluster_security_group_id` 는 이름·값이 맞고 **설명만 다른 SG 를 가리켰다.**

#### ✅ **bastion → workbench 개명 완결** (2026-08-06, D-WORKBENCH-RENAME)

사용자 제안. **이름이 실물과 어긋나 있었다** — `bastion host` 의 정의는 *인바운드를 받아 안쪽으로
전달*(SSH/RDP 점프)인데 이 모듈은 그 특성을 **하나도 갖지 않는다**: 인바운드 규칙 **0개** ·
private 서브넷 · SSM 전용(22번 없음) · kubectl 을 user_data 로 설치 · 상태 없음(수시 파기 정상).
요새가 아니라 **도구가 갖춰진 작업대**다. 근거 전문은 `docs/design/40-workbench.md §2.0`.

- PR [#13](https://github.com/skax-ca/iac-module-library/pull/13) 머지 `a5d8e2f` ·
  CI [`31057983935`](https://github.com/skax-ca/iac-module-library/actions/runs/31057983935) **6/6 pass**
  (로그 본문: workbench **10** · eks **20** · vpc **13 passed**).
- 태그: **`workbench-v0.1.0` 발행 + `bastion-v0.1.0` 원격 삭제.** apply 0회라 CLAUDE.md 의
  *"소비자 0일 때만"* 예외에 해당. ⛔ `eks-cluster` 는 **계약 무변경이라 재발행하지 않았다**
  (`access_entries`·`cluster_security_group_additional_rules` 는 중립적 이름 — 주석만 갱신).
- 소비 repo PR [#16](https://github.com/skax-ca/iac-reference-infra/pull/16) 머지 · plan
  [`31058277158`](https://github.com/skax-ca/iac-reference-infra/actions/runs/31058277158)
  **`10 to add, 0 to change, 0 to destroy`** — 개명 전 plan 과 **숫자가 같다 = 개명이 공짜였다.**

> ### ⏱️ 왜 "지금" 이 유일하게 싼 창이었나 — 재사용할 판단
>
> `var.purpose` 가 태그가 아니라 **식별자**로 흘러간다: `aws_iam_role.name` ·
> `aws_iam_instance_profile.name` · `aws_security_group.name`.
> **apply 후였다면** 그 셋이 replace 되고 Access Entry(principal ARN 변경)와 cluster SG rule
> (source SG 변경)까지 **연쇄 replace** 됐다.
> 🔑 일반화: *"purpose·naming 토큰을 바꾸는 개명은 apply 전에만 공짜다."*

> ### ⛔ 기계 치환이 **역사적 사실 3곳을 위조했다** — 되돌린 것이 이 작업의 핵심
>
> `sed` 는 "지금의 이름"과 "그때의 사실"을 구분하지 못한다. 다음 개명 때 같은 곳을 본다:
> 1. **릴리스 기록** — `docs/README.md` · `20 §4.3` 의 2026-08-05 발행분은 `bastion-v0.1.0` 이다.
>    원복 + *"2026-08-06 에 대체·삭제됐다"* 를 **덧붙였다**(고치는 게 아니라 덧붙인다).
> 2. **승계 출처** — `terraform-enterprise-poc .../40-bastion.md`. 그 repo 는 **동결**이라 구 이름이다.
> 3. **철회된 PoC ID 3개** — `D-BASTION-INLINE`·`D-BASTION-K8S`·`D-BASTION-SUBNET`. 개명하면
>    동결 repo 에서 찾을 수 없어 추적이 끊긴다. **구 이름 유지.**
>    살아 있는 ID 8개만 `D-WORKBENCH-*` 로 바꾸고 **대응표를 `40 §2.0`** 에 남겼다.

> ### ⚠️ 경로 한정 trivy 예외가 **조용히 깨졌다** (실측)
>
> `.trivyignore.yaml` 의 `paths: modules/bastion/main.tf` 가 디렉터리 이동으로 매치되지 않아
> trivy 가 exit 1. 경로 한정(평면 `.trivyignore` 대신 YAML 을 쓰는 이유)의 대가다 —
> 🔑 **모듈 디렉터리를 옮길 때 `.trivyignore.yaml` 을 함께 본다.**
> ⚠️ 로컬에서 `--tf-exclude-downloaded-modules` 를 빠뜨리면 upstream 모듈 지적이 섞여 나온다.
> **훅(`.githooks/pre-commit`)의 플래그를 그대로 복사해 쓴다.**

#### ✅ **workbench-v0.1.0 첫 apply 판정 완료** (2026-08-06) — `40 §7.3-1` 에 기록

소비 repo apply run [`31059712680`](https://github.com/skax-ca/iac-reference-infra/actions/runs/31059712680)
= `Apply complete! Resources: 10 added, 0 changed, 0 destroyed.` 인스턴스 `i-04ac14a6f5891492c`.

⛔ **이 repo 가 apply 한 것이 아니다.** 판정 주체는 소비 repo 이고 여기는 **받아 적는 쪽**이다
(그것이 2026-08-06 `aws-api` MCP 를 추가한 근거이기도 하다). "동작한다"의 기준은 그대로
`tofu test` + 예제 `validate` 다.

**⭐ `§5.1` 이 "`tofu test` 로 지킬 수 없다"고 적은 항목이 처음 실증됐다** — *"미지정 자체가 계약"*
인 항목은 plan 에서 `(known after apply)` 라 assertion 을 걸 수 없었다:
`PublicIpAddress: null` · `KeyName: null` · SG `IpPermissions` **0개** · t4g.nano↔arm64 AMI 정합.

**도달 3층 전부 성립**: SSM `Online` → `cloud-init done` → kubeconfig 생성(1층) →
`kubectl get nodes` 노드 2개 Ready(2·3층). kubectl `v1.35.7` 로 클러스터 마이너와 일치.
🔑 **`get nodes` 가 반환된 것 자체가 3층 전부의 증거다** — 실패했다면 층별로 다른 에러가 났다
(1층 없음 → kubeconfig 미생성 / 2층 → 401 / 3층 → i/o timeout).

⚠️ 판정은 `ssm send-command` 로 했다(자동화에 TTY 없음). 같은 채널·IAM·SG 라 도달성으로는 동등하고,
사람은 `aws ssm start-session --profile team --region ap-northeast-2 --target i-04ac14a6f5891492c`.

#### ✅ **eks-cluster-v0.4.0 — 영구 가짜 diff 해소** (2026-08-06, D-EKS-CIDR-NULL)

PR [#14](https://github.com/skax-ca/iac-module-library/pull/14) 머지 `ade89e9` · CI 6/6 ·
태그 발행 완료. 소비 repo 핀 상향 후 plan
[`31080181294`](https://github.com/skax-ca/iac-reference-infra/actions/runs/31080181294)
= **`No changes.`** 근거 전문은 `docs/design/20 §4.4`.

**고친 것**: `endpoint_public_access = false` 인데 `public_access_cidrs` diff 가 매 plan 마다 나고
apply 해도 안 사라졌다. 소비 루트가 인자를 지웠는데도 그랬다 — 모듈 기본값 `[]` 가 그대로 갔다.

> ### 🔑 **빈 컬렉션은 "없음"이 아니라 "있음"이다** — 재사용할 판단
>
> provider 문서 원문: *"Terraform will only perform drift detection of its value
> **when present in a configuration**."* ⇒ `null` 만 "없음"이고 `[]` 는 "설정에 있음"이다.
> 여기에 **AWS 가 public 꺼진 상태에서 그 값 변경을 반영하지 않는다**(실측)가 겹쳐 영구 diff.
> ⇒ **`default = []` 를 upstream 으로 흘리는 다른 지점도 같은 함정인지 본다.**
>
> ⛔ 해법에서 `length(...) > 0` 을 조건에 넣지 **않았다** — 그러면 *public 이 켜졌는데 리스트가 빈*
> 경우까지 null 이 되어 **EKS 의 0.0.0.0/0 전면 개방을 더는 감지하지 못한다.**
> 안전망을 diff 편의와 바꾸지 않는다. `lifecycle ignore_changes` 도 쓰지 않았다 —
> *"어긋나도 눈감는다"* 와 *"애초에 관리하지 않는다"* 는 다르다.

> ### ⭐ 판단 정정 — `(known after apply)` diff 는 **그 자체가 원인이 아닐 수 있다**
>
> 착수 때 OIDC `thumbprint_list` diff 를 *"원인 계층이 다르니 별개 항목"* 으로 분리했는데
> **그 분리가 틀렸다.** 클러스터 diff 가 사라지자 **연쇄로 함께 사라졌다** —
> `known after apply` 는 다른 리소스 변경에 의존할 때 뜨기 때문이다.
> ⇒ **의존하는 리소스의 diff 를 먼저 닫고 다시 본다.** 별개로 조사하기 전에.

**그다음 태스크**:

#### 🎉 **완결** — private-only 전환까지 끝났다 (`40 §7.3-2` 에 판정 기록)

소비 repo apply run [`31062408357`](https://github.com/skax-ca/iac-reference-infra/actions/runs/31062408357)
= `0 added, 2 changed, 0 destroyed`. 실물 `endpointPublicAccess: false`.

⭐ **음성 대조군이 판정의 핵심이었다** — workbench 에서 kubectl 이 되는 것만으로는
*"private 경로로 닿았다"* 가 증명되지 않는다(public 을 통했을 수 있다). VPC 밖에서 DNS 가
**private IP 만** 반환하고 `curl` 이 **timeout** 인 것을 함께 봐야 배제된다.
🔑 이 repo 가 GitHub App 실험에서 쓴 *"먼저 실패를 확인한다"* 와 같은 형태다 — **재사용할 절차**다.

**소비 루트가 알아야 할 실측 2건**(모듈 결함 아님, `40 §7.3-2` 상자):
`publicAccessCidrs` 는 인자를 지워도 API 응답에 남는다 · 공용 계정 자동화가 EBS `volume_tags` 를
덮어 apply 마다 drift 가 반복된다.

⏭️ **다음은 2순위(`21` 개정)다.** workbench 축은 닫혔다.

#### ✅ **D-POLICY-ENGINE · D-BACKUP-AWS** — Kyverno·백업 계층 확정 (2026-08-06, `340e361`)

착수 질문은 *"Kyverno·Velero 를 EKS addon 에 추가할까"* 였다. **문서 전용 개정 · `.tf` 변경 0.**
근거 전문은 **`docs/design/20 §1.1`**(신설). 운영 절차는 **`22 §4`**(신설).

> ### 🔑 **D-ADDON-BOUNDARY 는 판정 *함수*다** — 재사용할 절차
>
> 입력이 *"`aws_eks_addon` 으로 설치되는가"* 하나뿐이라, 새 컴포넌트의 계층은
> **토론이 아니라 조회로 정해진다.** 이번 결론 대부분이 검토가 아니라 실측에서 나왔다.
> ⇒ *"어느 계층에 넣을까"* 라는 질문을 받으면 **먼저 카탈로그를 조회한다.**

**실측(2026-08-06, 공식 문서 원문)** — ⚠️ AWS 자격증명이 없어 `describe-addon-versions` 는 못 돌렸다:
- **community addon 전체 = 6종** — metrics-server·kube-state-metrics·prometheus-node-exporter·
  cert-manager·external-dns·fluent-bit. **`20 §2.6` baseline 표와 정확히 일치**.
- **Marketplace vendor addon 34개 전수** — `kyverno`·`velero`·`nirmata` **0건**.
- ⭐ **카탈로그가 이미 소진됐다** ⇒ **앞으로 오는 컴포넌트는 기본이 GitOps helm 이다.**
  IaC 로 오려면 AWS 가 카탈로그를 늘려야 한다.

**D-POLICY-ENGINE (Kyverno)** = **helm · 프로파일 A 한정 baseline**. `30 §5` 의 TBD 해소.
- `30 §5` 가 예정한 *①baseline(전 클러스터)* 을 **A 한정으로 좁혔다** — 프로파일 B 엔 위임할
  앱팀이 없어 **제약할 대상이 없다**. 주면 `22 §1` 이 ArgoCD 에 지적한 *"관리 표면만 증가"* 다.
- 🔑 **그래서 `22 §3.2` 의 *"프로파일 B 의 helm 대상은 둘뿐"* 이 깨지지 않는다. 순서가 반대다** —
  그 문장이 성립하는 이유가 곧 범위를 좁힐 근거였다. **같은 사실의 두 표현**이다.
- 📌 **다음 helm 후보에 물을 질문**: *"프로파일 B 에도 필요한가"* 를 **먼저** 묻는다.

**D-BACKUP-AWS (백업)** = **AWS Backup for EKS(IaC, 소비 루트)**. Velero 는 **예외 경로**.
- ⭐ CLAUDE.md *"발명하기 전에 찾는다"* 가 정확히 발동했다 — Velero 배치를 정하기 전에
  **AWS 가 같은 문제를 이미 푸는지** 봤고, 풀고 있었다.
- 원문 FAQ: *"Do I need to have an agent or Amazon EKS Add-on installed? — **No.**"*
- 전제조건 `authentication_mode` 는 **upstream v21 기본값 `API_AND_CONFIG_MAP`** 이고 facade 가
  덮어쓰지 않아 **이미 충족**(실측 `.terraform/modules/eks/variables.tf:59`) ⇒ **모듈 계약 변경 0**.
- Velero 를 넣었다면 helm 대상 + S3 버킷 + IAM role 셋을 새로 소유하고 **백업이 축 A→축 B 로
  넘어갔을 것**이다(프로파일마다 갈리는 것이 하나 는다).
- ⛔ **기각이 아니다** — 전환 신호는 `22 §4.5`(CSI migration·in-tree·ACK 볼륨 · FSx · S3 prefix ·
  크로스계정 EFS · 클러스터 간 마이그레이션). 🔑 **이식 비용은 미리 값 매겨 뒀다: 싸다** —
  upstream `eks-pod-identity` 2.8.2 에 **`attach_velero_policy` 가 이미 있다**(실측 `velero.tf`).
  `enable_velero_iam` 변수 1 + 블록 1. **단 요구가 나오면 그때 연다.**

> ### ⚠️ **미개정 문서(`30`)에 현행 결정을 적지 않았다** — 재사용할 판단
>
> `30 §5` 는 스스로 *"20 §1 승계 — 정합 필수"* 라고 적은 **파생 표**라, 원본만 고치면 TBD 가
> 남아 다음 사람이 잘못 읽는다. 그렇다고 본문에 결정을 쓰면 **어디까지가 PoC 전제인지 판정
> 불가능**해진다. ⇒ **결정은 원본(`20`)이 소유하고 `30` 에는 포인터 상자만** 남겼다.
> 📌 **KEDA 도 같은 실측으로 경로(helm)만 답이 나왔다. ②catalog 배치는 재확인 안 했다.**

> ### 🔧 §번호 이동 — `22` 열린 항목 **§4 → §5**
>
> 백업 절을 §4 로 신설하며 밀렸다. `40` 의 교차 참조 4곳(`§4-1`·`§4-2` → `§5-1`·`§5-2`)을
> **같은 커밋에서** 고쳤다. ⚠️ `22` 를 다시 인용할 때 옛 번호를 쓰지 않는다.

#### ⏭️ 2순위 — **`21` 개정** (다음 태스크)

40 이 닫혀 착수 가능. ⚠️ 번역이 아니라 **재결정**이다(01 §3.3): 관리형 Capability vs self-managed ArgoCD.
`awscc_eks_capability` 스키마는 착수 시 재조회(21 이 v1.93.0 기준).

**⭐ `21` 이 닫히면 곧바로 이어지는 것 — `40` 열린 항목 7 (`argocd` CLI)**
- 사용자 결정(2026-08-06): **`21` 개정 후 착수.** nullable 핀이라 비용은 0 이지만,
  *"어떤 버전을 무슨 용도로 핀하는가"* 의 **근거가 `21` 의 결정에서 나온다**. 근거 없는 핀은
  다음 사람이 못 고친다.
- 릴리스 자산 실측: **`argocd-linux-arm64` 단일 바이너리**(v3.5.0, GitHub Releases) —
  `t4g.nano` arm64 에서 동작하고 tarball 해제가 없어 `helm` 보다 절차가 짧다.
- ⚠️ **`velero` CLI 는 제외됐다** — D-BACKUP-AWS 가 에이전트 없는 경로를 택해
  **클러스터 안에서 실행할 CLI 가 없어졌다.**
- 📌 **도구가 3개가 되어도 일반화하지 않는다** — 다운로드 형태가 전부 다르다(`dl.k8s.io` 단일 ·
  `get.helm.sh` tarball · GitHub Releases 단일). 맵 추상화는 URL 조립 분기를 **오히려 늘린다**.
- ⛔ **`.tf` 변경이므로 브랜치 → PR**(문서 전용이었던 이번 커밋과 다르다).

### 🔑 state 버킷 = partial backend (D25) — 잊으면 init이 안 된다

`backend.tf`는 **`terraform { backend "s3" {} }` 뿐**이다. 버킷명이 **git에 없다**(계정 ID 노출 방지).
- CI: GitHub repo 변수 / 로컬: **gitignore된 `backend.hcl`**
- `tofu init -backend-config="bucket=..." -backend-config="key=..." -backend-config="use_lockfile=true"`
- 버킷명: `s3-ref-dev-an2-tfstate-<guid12>` · workload code = **`ref`**(D24)
- ⚠️ 버저닝+`use_lockfile` → lock 객체 버전 폭증(공식 경고) → **lifecycle 필수**(D29)

### ✅ 커밋 단위 제약 — 해소됨 (2026-07-30)

**tflint `terraform_unused_declarations`가 미사용 변수를 exit 2로 잡는다**는 제약 때문에
10.1+10.2+10.3을 한 커밋(`65d2283`)으로 묶었다. 변수 15개가 전부 소비되어 게이트를 통과했다.
→ 이후 태스크는 설계 §2대로 **태스크당 1커밋**으로 진행한다. `--no-verify`는 쓰지 않았다.

### 🏷️ 네이밍 규칙 (2026-07-30 갱신 — 사용자 지침)

**약어가 카탈로그에 없을 때 `Name`을 생략하거나 "열린 항목"으로 미루지 않는다.**
→ **사용자에게 물어 확정 → 카탈로그 등재 → 구현** 순서다. 임의 생성도 금지(둘 다 틀린 처리).
- 등재: **`fl`**(VPC Flow Log — AWS 실제 ID 접두사) · **`iamp`**(IAM 관리형 정책) — 커밋 `7114239`.
- 등재: **`iamoidc`**(`aws_iam_openid_connect_provider`, D23) — 커밋 `96dcfab`.
  기각안도 문서에 남겼다: `iamo`(`o`가 OIDC임을 알 수 없고 짝 `iams`가 오독됨) · `iamidp`(OIDC/SAML 미구분).
  ⚠️ 이 리소스는 **식별자가 URL**이라 `name` 인자가 없다 → `Name` **태그로만** 붙는다(inline 정책과 반대).
- 카탈로그 총계 **312**(Network 73, Security 18, DevTools 31).
  ⚠️ **약어 추가 시 3곳을 함께 고친다**: ① 섹션 헤더 ② 상단 총계(27행) ③ 끝 카테고리 카운트 요약표.
  요약표가 308로 stale했던 것을 `96dcfab`에서 실측 재카운트로 정정했다 — 같은 실수를 반복하지 말 것.
- 신설 규약: **"종속 객체는 약어를 새로 만들지 않고 부모 이름을 상속한다"** —
  `aws_iam_role_policy`(inline)는 `<role 이름>-policy`. ⚠️ inline 정책은 **`tags` 미지원**이라
  이 이름은 `Name` 태그가 아니라 **`name` 인자 = 식별자**다.

- **착수 전 확인**: 사용자가 설계 §1을 승인했는지. 특히 D10(kill switch 경계),
  D11(Flow Logs 대상 CloudWatch 고정), §1.3(IAM inline policy 약어 미생성).
  ※ D12(삭제 보호)와 D-ENGINE(OpenTofu 단독)은 **2026-07-29 승인 완료** — 재확인 불필요.
- 코드 작성 전 `terraform-style-guide` 스킬 로드. 로컬 게이트는 pre-commit이 강제.
- **스키마 확인 완료**(aws 6.56.0): `aws_cloudwatch_log_group.retention_in_days` 유효값 23종 ·
  `aws_flow_log.traffic_type`(ACCEPT/REJECT/ALL, `vpc_id` 지정 시 **필수**) — 설계와 일치.
  ⚠️ 구 doc ID(12942950 등)는 **교체된 MCP에서 무효**다. 신규 서버는
  `get-resource-docs(namespace="hashicorp", name="aws", resource="subnet")` 형태로 **단독 호출**한다.
- **10.2에서 스키마 확인이 필요한 리소스**: `aws_vpc`(확인 완료 — 8054자) · `aws_subnet` ·
  `aws_vpc_ipv4_cidr_block_association` · `aws_route_table` · `aws_route` ·
  `aws_route_table_association` · `aws_internet_gateway` · `aws_nat_gateway` · `aws_eip` ·
  `data.aws_availability_zones`. **추정 금지**(`CLAUDE.md` 검증 절).

### 문서 인용 규칙 (`docs/README.md` 상태표가 판정 근거)

- `docs/architecture/*` ✅ (**04-engine-decision.md 신규**) · **`docs/design/10-vpc-module.md` ✅ (2026-07-29 개정)**
- **`docs/design/20-eks-module.md` ✅ (2026-08-03 개정 = `eks-cluster-v1.0.0` 계약)**
- **`docs/design/50-reference-consumer-repo.md` ✅ (2026-07-30 신규 = D-CONSUME)** — 소비 경로 규약의 SSOT
- **`docs/design/22-day2-operations.md` ✅ (2026-08-04 신규 = D-DAY2-PROFILE)** — 업그레이드 런북 + 운영 프로파일
- `docs/design/{30,40}-*.md` ⚠️ **미개정** — 확정 설계로 인용 금지
- `docs/design/21-gitops-bootstrap-seam.md` ⚠️ **미결정**(미개정과 다르다) — 판단 자체가 이 repo 것이 아니다.
  ✅ 살아 있는 것은 **AWS 서비스 동작 실측**(auto-managed Access Entry의 `kubernetesGroups`가 비어 custom
  ClusterRole bind 불가 · `AmazonEKSArgoCDClusterPolicy`가 cluster-wide read를 주지 않음 · IdC 계정
  인스턴스는 다중 계정 미지원 · RETAIN 유일값). ⚠️ 무효는 **TFC 러너 전제의 도달성 논증**(V1~V3).
- `docs/reference/poc-findings.md`는 **외부 스냅샷** — 참조만, 복사·갱신 금지
- `docs/consumer/*` 🗄️ **TFC 시절 잔재 — 보관 전용**(D26-1, 2026-07-30 사용자 결정).
  ⛔ **확정 규약으로 인용 금지 · 개정하지 않음 · 이관하지 않음 · 삭제하지 않음** — 네 가지 다 결정됐다.
  - **소비 규약의 SSOT는 `docs/design/50`(D-CONSUME) 하나**다. 최초 D26은 "`consumer/*`를 개정해
    SSOT로 삼는다"였으나 **철회했다** — GitHub Actions 규약의 SSOT가 TFC 절차서일 수는 없고,
    경쟁 SSOT는 그 자체로 drift다.
  - 유효 범위: `multi-environment.md` §3·§4·§6·§8(**도구 무관**, D22가 인용) / `dynamic-credentials.md`는
    **2단 체인 구조만**. 절차 전체 무효(발급자·`aud`·신뢰 정책이 전부 TFC 기준).
  - ⚠️ `dynamic-credentials.md`에 **PoC 계정 ID 12곳** — private인 동안의 유예이지 해소가 아니다.
    public 전환의 선결 과제로 D20 기각안에 등재돼 있다.

### MCP (`.mcp.json` project 스코프 — 2026-07-29 **`terraform` → `opentofu` 교체**)

- **`opentofu`**([공식](https://github.com/opentofu/opentofu-mcp-server), `npx -y @opentofu/opentofu-mcp-server`) + `aws-docs`.
  ⏸ 교체 후 **`claude` 재시작 + 승인 필요**.
- 교체 이유: ① `get-resource-docs`가 **단독 호출** — 기존 `terraform-mcp-server`의 2단계 제약 소멸
  ② **`registry.opentofu.org`**(우리가 실제로 쓰는 registry)를 조회 ③ `go install` 불필요.
- ⚠️ **로컬 npx 판은 0.1.x / 툴 5종**, hosted(`mcp.opentofu.org`)는 **1.0.1 / 7종**(실측).
  로컬에는 `get-provider-versions`가 **없다** → 버전 존재 확인은 표준 API로:
  `curl -s https://registry.opentofu.org/v1/providers/<ns>/<name>/versions` (실측 동작 확인).
- ⛔ **TFE/HCP 연동 서버는 여전히 제외한다** — D-ENGINE(OpenTofu 단독)이 그 축을 닫았다. 되살리지 말 것.
- **➕ `aws-api` 추가 (2026-08-06 사용자 지시)** — 실계정 **조회 전용**(`awslabs.aws-api-mcp-server`).
  ⏸ 적용은 **`claude` 재시작 후**, 첫 사용 시 승인 프롬프트.
  - 🔒 **`READ_OPERATIONS_ONLY=true`** — 공용 계정에서 MCP 를 통한 우발적 변경 원천 차단.
    우리의 실제 변경은 전부 IaC→CI(OIDC→Role) 경로다. MCP 는 조회 전용이다.
  - 🔒 **`AWS_API_MCP_PROFILE_NAME=team`** — 빼면 boto3 가 ambient 자격증명으로 **조용히 다른 계정**을 친다.
  - **CA 번들 env 는 넣지 않는다**(aws-docs 와 다른 점) — `aws` CLI 가 `AWS_CA_BUNDLE` 없이 동작한다 =
    AWS 엔드포인트는 MITM 대상이 아니다. 사내 CA 만 담긴 번들을 걸면 오히려 public AWS TLS 가 깨진다.
  - ⚠️ 고객사 복사 시 `AWS_API_MCP_PROFILE_NAME` 은 그들의 프로파일로 바꾼다(버킷명·CA 와 동급).

  > ### 🔄 2026-07-31 의 "제외" 결정을 왜 뒤집었나 — 전제가 바뀌었다
  >
  > 당시 근거는 *"aws-api 는 **배포 검증 도구**라 소싱만 하는 모듈 repo 엔 불필요하다"* 였고
  > **그때는 옳았다.** 바뀐 것은 이 repo 의 역할이다 — `40 §5.1` 이 *"`tofu test` 로 지킬 수 없는
  > 항목(`key_name`·`associate_public_ip_address` 미지정)은 소비 repo 의 첫 apply 에서 실증되고,
  > **판정이 나면 `40` 에 기록한다**"* 고 정했다. 즉 이 repo 는 이제 **실계정 판정을 받아 적는 쪽**이다.
  >
  > ⚠️ **여전히 이 repo 는 배포하지 않는다.** aws-api 가 생겼다고 *"apply 로 검증했다"* 고 쓰지 않는다 —
  > "동작한다"의 기준은 `tofu test` + 예제 `validate` 까지이고, apply 판정은 소비 repo 몫이다.
  > 조회는 **설계 문서에 사실을 적기 위한 것**이지 게이트가 아니다.
  > 🔑 **소비 repo `.mcp.json` 과 이제 동일하다.** 다르게 만들 이유가 없어졌으므로 parity 를 유지한다.
- 구 `terraform-mcp-server` v1.1.0 바이너리는 `~/go/bin/`에 남아 있다(미사용, 삭제해도 무방).

## 미결 항목

- ~~원격 repo 미생성~~ ✅ **해결**: `skax-ca/iac-module-library`(private) 생성·push 완료(2026-07-29).
  ⚠️ **immutable sub claim 주의**: 이 repo는 2026-07-15 이후 생성 → OIDC `sub`가 숫자 org/repo ID다.
  소비자 repo 신뢰 정책 작성 전 실제 토큰 `sub` 확인 필수(`repo:<org>@<org_id>/<repo>@<repo_id>:...`).
- ✅ **TFE_TOKEN 유지 결정**(2026-07-30) — 폐기·재발급하지 않는다. 2026-07-28 세션 중 노출됐으나
  사용자가 유지를 선택. ⚠️ 잔여 리스크: 노출된 토큰이 유효한 상태로 남으므로, 향후 TFE/HCP를
  안 쓰기로 굳어지면(D-ENGINE=OpenTofu 단독) 그때 폐기 재검토 여지.
- ~~보존한 `AWSAFTExecution`이 assume 불가 → 부트스트랩 시 신뢰 정책 교체 필요~~
  ✅ **미결 아님**(2026-07-30, D27-1). 실행 Role을 신설했으므로 그 Role을 **쓰지 않는다** —
  해결된 게 아니라 **무관해졌다**. 깨진 상태로 방치하는 것이 의도된 결정이다(남의 자산).
- **실행 Role 권한 축소**(`iamr-ref-dev-an2-gha-exec-01` = `AdministratorAccess`) — 50 §5-7.
  판단 시점은 **모듈 집합이 안정된 뒤**(최소 EKS 이식 후). 그때까지 완화책은 D27-2 운영 규칙
- `docs/design/30-gitops-repo.md`의 소유권 재검토 — **D26이 부분 답**(규약/사실 분리). GitOps hub 자체는 미결
- plan/apply 권한 분리 — `tofu plan`도 state lock을 잡아 "plan은 read-only"가 성립하지 않는다(D28 열린 항목)
- CI `init`이 모듈 repo **전체를 clone**한다(실측 F2). 태그·히스토리 증가 시 `?depth=1` 검토
- plan artifact 암호화 — `retention-days: 1`은 완화이지 해결이 아니다(50 §5)
- 관리형 ArgoCD 채택 여부 재결정(`docs/architecture/01-module-strategy.md` §3.3)
- VPC 설계 **열린 항목 6건**은 `docs/design/10-vpc-module.md` 말미 참조 —
  **1** TGW attachment · **2** prefix list 소유권 · **3** IPAM 연계 · **4** Flow Logs 대상 확장(S3/Firehose) ·
  **5** private NAT 옵션 · **9** per-AZ NAT 개수 기준(호스트 그룹이 넓으면 미사용 NAT가 AZ당 ~$43/월).
  ✅ 해소됨: **6**(IAM inline 약어 — 부모 이름 상속 규약) · **7**(confused deputy — vpc-v1.1.0) ·
  **8**(`fl` 약어 등재). ⚠️ 남은 6건은 전부 **수요 발생 시** 착수 성격이라 지금 차단 요인이 아니다.
