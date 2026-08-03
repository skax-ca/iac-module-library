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

### 🔴 세션 시작 시 가장 먼저 볼 것 (최종 갱신 2026-08-03)

0. ⚠️ **이 파일이 stale해진 전례가 두 번 있다.** ① 2026-07-30 크로스-repo(소비 repo Phase 진행을
   여기 중복 기록) ② 2026-07-31 **같은 repo 안에서** — 열린 항목 7 구현·종결·6/6 판정 3커밋이
   PR 브랜치로 나갔는데 notepad 갱신이 거기 실리지 않아, 8/3 세션 시작 시 **이미 끝난 일을 다음
   태스크로 안내**했다. 🔑 **feature 브랜치에서 작업하면 notepad 갱신도 그 브랜치에 실어라.**

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

#### ⏭️ 다음 = **Task 20.1(d) → 20.8** (AWS 계정 확보가 선행 조건)

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
- ⛔ TFE/HCP 연동 서버·`aws-api`는 의도적으로 제외했다 — 되살리지 말 것.
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
