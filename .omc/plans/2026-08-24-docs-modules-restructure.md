# iac-module-library docs/·modules/·examples/·scripts/ 전면 재구성 계획

**상태**: Phase 0~5·7 실행 완료, 로컬 전체 재검증 통과(2026-08-24). Phase 6(em-dash 레거시 정리)은 범위 밖으로 남음. 커밋은 사용자 diff 검토 후 별도 지시 대기 중
**작성일**: 2026-08-24

## RALPLAN-DR 요약

### Principles
1. 문서 구조는 독자·성격(패턴 무관 Reference/Explanation vs 패턴별 How-to)으로 가르고, 아키텍처 패턴이 늘어도 파일 개수가 발산하지 않게 한다.
2. ⚠️ **v21 반영 — `modules/`는 도메인 중첩 없이 flat을 유지한다**(폐기: "도메인으로 재편"). 소비자가 `source`에
   직접 쓰는 경로라 중첩은 그 경로만 길어질 뿐 이득이 없고, flat이 확장(새 모듈 추가)에도 더 직관적이라는
   사용자 판단(2026-08-24, 실행 도중 재확인). 컴포넌트 태그명(`<component>-vX.Y.Z`)은 원래도 전역 유일성을
   유지하므로 이 결정과 무관하게 그대로다. docs/는 이 결정의 대상이 아니다 — `docs/architectures/` 패턴별
   디렉토리는 그대로 유지한다(사용자가 범위를 명시적으로 modules/만으로 한정).
3. 모듈 계약 문서는 코드 옆(`README.md`)에서 자동 생성되어 문서-코드 drift가 구조적으로 불가능해야 한다.
4. 문체 규칙(stop-slop)은 **규칙 자체는 지금 예외 없이 전면 채택**하되, 기존 위반 493건의 **정리는 구조 변경과 분리된 저위험 후속 작업**으로 돌린다.
5. 물리 경로 변경(모듈·문서·예제·스크립트)은 이번에 전부 끝내고 하위호환 계층을 남기지 않는다 — 사용자가 기존 배포 워크로드 전량 destroy를 명시적으로 승인했다. 파괴적 변경은 **기계적으로 검증 가능한 것**에 한정한다.
6. **패턴별 배포·운영 절차는 이 repo가 아니라 그 패턴의 레퍼런스 배포 repo가 소유한다.** 이 repo는 "재사용 가능한 모듈 계약"과 "패턴을 고르는 결정 가이드"까지만 소유하고, "고른 패턴을 실제로 어떻게 세우고·운영하고·걷어내는가"(살아있는 계정·리소스명이 등장하는 절차)는 소유하지 않는다 — `CLAUDE.md` 「이 repo의 위치」 표(이 repo=SSOT, `<project>-infra`=배포 루트)가 이미 그은 경계를 문서 배치에도 그대로 적용한 것뿐이다.

### Decision Drivers (top 3)
1. 저장소 이름("iac-module-library")과 실제 IA(EKS-GitOps-hub/spoke 단일 패턴 종속, 게다가 그 패턴의 운영 절차까지 포함)의 불일치 해소.
2. 문서·예제 비대화·drift 방지 — 모듈 카탈로그 단일 파일과 top-level `examples/`가 늘어나는 모듈/패턴 수만큼 커지는 구조적 결함 제거.
3. 기존 배포 워크로드를 전량 파괴할 예정인 지금이 하위호환 비용 없이 재설계할 수 있는 유일한 저비용 시점.

### Viable Options — v5 갱신분

v1~v4에서 검증된 A~D(모듈 평평 유지/번호 유지/입출력 표 유지/stop-slop 부분 채택 기각)에 더해, 이번 사용자 피드백으로 **3개 신규 결정**이 추가됐다. 각각 독립적 근거로 채택했다.

| 결정 | 대안이었던 것 | 대안을 택하지 않은 이유 |
|---|---|---|
| E. hub-lifecycle·spoke-lifecycle·runbooks.md를 `eks-reference-infra`로 이관 | 이 repo `docs/architectures/eks-gitops-hub-spoke/`에 그대로 유지 | 이 세 문서는 살아있는 배포(hub/spoke 계정, 실제 클러스터명)의 운영 지식이지 모듈 계약이 아니다. `CLAUDE.md`가 이미 "배포 루트는 `<project>-infra`" 경계를 그어뒀는데, 그 경계를 문서에는 적용하지 않을 이유가 없다. `eks-reference-infra`가 "EKS GitOps 패턴 레퍼런스 레포"로 역할이 명확해지는 시점과도 맞는다 |
| F. `examples/`를 top-level에서 폐지하고 각 예제를 "주인공 모듈"의 `examples/`로 흡수 | top-level `examples/`를 `modules/`와 1:1 도메인 트리로 미러링(v1~v4 설계) | 미러링은 파일 트리가 두 벌(`modules/`·`examples/`) 생기는 반복이고, 실제 Terraform 레지스트리 모듈(예: `terraform-aws-modules/eks`)도 통합 예제를 "주인공 모듈" 자신의 `examples/`에 두는 관행이 흔하다. 흡수하면 트리가 하나로 줄고 모듈-예제 동시 탐색이 쉬워진다 |
| G. `scripts/argocd-seed.sh`·`teardown-verify.sh`를 `eks-reference-infra`로 이관 | 이 repo `scripts/`에 유지 | E의 직접 귀결 — 두 스크립트는 hub/spoke 배포를 세우고 검증하는 자동화라 E와 같은 경계 논리가 그대로 적용된다. `validate-abbreviations.py`·`validate-doc-conventions.py`는 이 repo 자신의 문서/네이밍 거버넌스 도구라 남는다 |

## 선행 조사 결과 (실측, v1~v4에서 확정된 것은 재기재하지 않음 — 아래는 v5 신규 조사)

- `examples/eks-cluster-enterprise`는 vpc·eks-cluster·workbench 3개 모듈을 합성한 통합 예제다("주인공"은 README 제목·목적 서술상 eks-cluster). 흡수 시 `modules/eks-cluster/examples/enterprise/main.tf`에서 vpc·workbench를 상대경로로 참조한다(아래 Phase 1 참조). v21(flat 유지) 결정으로 이 경로는 3단계 상위(`../../../vpc`)로 끝난다 — v1~v20이 우려하던 4단계 깊이 문제는 발생하지 않는다.
- `examples/vpc-enterprise`는 vpc 단일 모듈 예제라 `modules/vpc/examples/enterprise/`로 흡수하면 `source = "../.."` 자기참조 하나로 끝난다 — 깨끗한 케이스.
- `examples/AGENTS.md`는 top-level `examples/` 디렉토리 자체에 대한 컨벤션 문서였는데, 그 디렉토리가 폐지되므로 내용을 `modules/AGENTS.md`로 병합해야 한다.
- `scripts/README.md`가 `argocd-seed.sh`·`teardown-verify.sh`를 각각 `02-choose-your-path.md`·`03-hub-lifecycle.md`·`04-spoke-lifecycle.md`에 링크하고 있다(이관 대상 문서들과 이미 강하게 결합돼 있었다는 뜻 — E와 G가 별개 결정이 아니라 애초에 하나였다는 근거).

## 목표 구조

```
docs/
  README.md                       # 유지 (독자 라우팅표 갱신)
  team-access.md
  module-index.md
  conventions.md                  # + §9 stop-slop
  decisions.md
  aws-naming-abbreviations.md
  # AGENTS.md(docs/·루트·examples/·modules/ 4개 전부)는 v20에서 폐지 확정 — 재생성하지 않는다

  architectures/
    README.md                     # "어떤 아키텍처 패턴이 필요한가" 라우팅표 — 패턴별 레퍼런스 레포 링크 포함
    eks-gitops-hub-spoke/
      overview.md                 # 구 01-architecture.md (3계층 소유 모델 — 개념 설명, 유지)
      choose-your-path.md         # 구 02-choose-your-path.md (질문 A~D — 결정 가이드, 유지)
      # hub-lifecycle.md · spoke-lifecycle.md · runbooks.md는 eks-reference-infra로 이관, 이 repo에서 제거

modules/
  vpc/
    README.md                     # terraform-docs 자동 생성
    examples/enterprise/          # 구 examples/vpc-enterprise
  eks-cluster/
    README.md
    examples/enterprise/          # 구 examples/eks-cluster-enterprise (vpc·workbench도 상대경로로 참조)
  workbench/
    README.md
  cross-account-trust-role/
    README.md
  # v21 — 도메인 중첩(networking/·compute/·security/) 없이 flat 유지(폐기: v1~v20의 도메인 재편안)
  # data/ 는 첫 데이터 모듈 추가 시 생성(그때도 flat: modules/<name>/)
  # modules/AGENTS.md는 v20에서 폐지 확정(examples/AGENTS.md도 이미 삭제되어 병합 대상 자체가 없다)

scripts/
  validate-abbreviations.py       # 유지 (이 repo 자신의 거버넌스 도구)
  validate-doc-conventions.py     # 유지
  README.md                       # argocd-seed.sh·teardown-verify.sh 항목 제거
  # argocd-seed.sh · teardown-verify.sh는 eks-reference-infra로 이관, 이 repo에서 제거

# top-level examples/ 디렉토리는 폐지
```

## 구현 단계 — **이번 브랜치/PR 범위: Phase 0~7** (Phase 6은 별도 후속 작업)

### Phase 0 — 준비 + **cross-repo 선행조건 확인**
- `brew install terraform-docs`, 버전 고정값 결정
- ⚠️ **v20 반영(Critic Minor) — `scripts/__pycache__/`가 untracked·미ignore 상태로 이 브랜치에 남아 있다.** `.gitignore`에 `__pycache__/` 추가(애초에 untracked라 `git rm --cached` 불필요)
- ⚠️ **선행조건**: hub-lifecycle.md·spoke-lifecycle.md·runbooks.md·argocd-seed.sh·teardown-verify.sh를 이 repo에서 `git rm`하기 **전에**, 그 내용이 `eks-reference-infra`로 실제 이관됐는지 확인하는 것이 이상적이다. 다만 이 repo의 관례("죽은 경로를 남기지 않는다 — git blame·커밋 메시지가 기록을 답한다")를 따라 **이번 PR에서 바로 git rm하고, 이관은 `eks-reference-infra`의 별도 세션에서 이 삭제 커밋 해시를 참조해 진행**한다(git 히스토리가 안전망). repo 경계 원칙상 이 계획은 그 이관 자체를 수행하지 않는다 — `eks-reference-infra`·`eks-platform-gitops` 소관.

### Phase 1 — `modules/`·예제 물리 이동 (git mv, 내용 무변경)
```
mkdir -p modules/vpc/examples modules/eks-cluster/examples
git mv examples/vpc-enterprise modules/vpc/examples/enterprise
git mv examples/eks-cluster-enterprise modules/eks-cluster/examples/enterprise
```
- ⚠️ **v21 반영 — `modules/vpc`·`modules/eks-cluster`·`modules/workbench`·`modules/cross-account-trust-role` 자체는 flat 유지로 이동하지 않는다**(폐기: v1~v20의 도메인 재편 `git mv modules/<name> modules/<domain>/<name>` 4줄). 물리적으로 움직이는 것은 top-level `examples/`를 각 모듈의 `examples/`로 흡수하는 것뿐이다
- ⚠️ **v20 사용자 결정 반영 — `AGENTS.md` 4개(루트·`docs/`·`examples/`·`modules/`) 전면 폐지.** 이 계획 범위 밖에서 이미 확정됐다(2026-08-24) — deepinit이 생성한 이 문서군을 더 이상 유지하지 않는다. 4개 파일 전부 이미 삭제된 상태로 이 브랜치에 들어왔으므로 `git rm`도 재생성도 하지 않는다. v18까지 Phase 1~3에 있던 "편집·병합" 계열 지시는 아래에서 전부 대체된다
- `modules/vpc/examples/enterprise/main.tf`: `source = "../../modules/..."` → **`source = "../.."`**(자기참조, vpc 모듈 자신)
- `modules/eks-cluster/examples/enterprise/main.tf`:
  - eks-cluster 자기참조: `source = "../.."`
  - vpc 참조: `source = "../../../vpc"`(enterprise→examples→eks-cluster→**modules**, 3단계 상위가 top-level `modules/`. v21 — flat 유지 결정으로 v1~v20의 4단계에서 1단계 얕아짐)
  - workbench 참조: `source = "../../../workbench"`
  - ⚠️ v21 반영 — flat 유지로 이 경로 깊이 문제 자체가 사실상 해소됐다(3모듈 합성 예제도 3단계 상위로 끝난다). v1~v20이 "알려진 비용"으로 감수하려던 4단계 깊이는 더 이상 발생하지 않는다
- 이동 직후 즉시 `tofu -chdir=modules/vpc/examples/enterprise validate`·`tofu -chdir=modules/eks-cluster/examples/enterprise validate` 실행해 경로 오류 조기 발견
- ⚠️ **v17 Architect 리뷰 발견 반영, v20에서 AGENTS.md 부분 갱신 — 이동되는 파일 자신의 내부 자기참조도 함께 고친다**(실측: `examples/vpc-enterprise/README.md`·`examples/eks-cluster-enterprise/README.md`·`main.tf`·`variables.tf`·`outputs.tf`가 전부 자기 옛 경로를 인용): 제목(`# examples/vpc-enterprise — ...`)·`tofu -chdir=examples/vpc-enterprise ...` 예시 명령을 새 위치 기준으로 갱신. **`examples/AGENTS.md` 인용 9곳은 병합 목적지로 교체하지 않고 그냥 제거한다**(v20 — AGENTS.md 자체가 폐지됐다): `examples/eks-cluster-enterprise/{outputs.tf:1, main.tf:4, variables.tf:1, README.md:4·52·154}` · `examples/vpc-enterprise/{outputs.tf:1, README.md:10, variables.tf:1}`. `eks-cluster-enterprise/README.md:52`는 `[examples/AGENTS.md](../AGENTS.md)` 실제 링크라 링크째 삭제하고 그 문장을 산문으로 다시 쓴다. 이걸 놓치면 파일은 옮겨졌는데 내용은 옛 자리·존재하지 않는 문서를 계속 말하는 상태가 된다

### Phase 2 — `docs/` 이동·개명 + **패턴별 운영 문서 제거**
```
git mv docs/00-team-access.md docs/team-access.md
git mv docs/05-modules.md docs/module-index.md
git mv docs/06-conventions.md docs/conventions.md
git mv docs/08-decisions.md docs/decisions.md
mkdir -p docs/architectures/eks-gitops-hub-spoke
git mv docs/01-architecture.md docs/architectures/eks-gitops-hub-spoke/overview.md
git mv docs/02-choose-your-path.md docs/architectures/eks-gitops-hub-spoke/choose-your-path.md
git rm docs/03-hub-lifecycle.md docs/04-spoke-lifecycle.md docs/07-runbooks.md
git rm scripts/argocd-seed.sh scripts/teardown-verify.sh
```
- ⚠️ **v5 Architect 리뷰 발견 반영**: `scripts/argocd-seed.sh`는 단순 이관 대상이 아니라 **이미 확립된 vendoring SSOT 관계**를 갖고 있다 — `scripts/README.md`가 "이 파일이 SSOT다. 사본이 `skax-ca/eks-platform-gitops`의 `bootstrap/argocd-seed.sh`에 있다"고 명시하고, `SRC=scripts/argocd-seed.sh`(이 repo 경로 고정)를 전제로 한 재-vendoring 절차를 담고 있다. `eks-platform-gitops`는 `CLAUDE.md`에 이미 등재된 확립된 계층 2 repo로, `eks-reference-infra`와 별개다. `git rm`만 하면 이 vendoring 절차가 존재하지 않는 경로를 가리키는 죽은 문서로 남는다 — **`scripts/README.md`의 vendoring SSOT 절(현재 SRC 경로를 명시한 절 전체)을 이번 Phase 2에서 함께 제거하거나 "SSOT가 `eks-reference-infra`로 이관 예정" 안내로 교체한다.** 새 SSOT 확정과 `eks-platform-gitops` 쪽 문서 갱신은 이 repo 범위 밖(Risks·ADR Follow-ups 참조)
- 신규 작성: `docs/architectures/README.md`(라우팅표) — "이 패턴의 배포·운영은 `eks-reference-infra`(EKS GitOps 패턴 레퍼런스)를 참조" 안내를 포함
- `overview.md`(구 01) 내용 중 "세 저장소가 계층을 어떻게 나눠 갖는가" 절이 `eks-reference-infra` 개명·역할 변경을 반영해야 하는지는 이번 계획 범위 밖(내용 편집은 후속 작업) — 통째 이동만
- ⚠️ **v15 Critic 리뷰 발견 반영(C1·M3), v20에서 AGENTS.md 부분 삭제 — `docs/README.md`는 "라우팅표 갱신" 정도로 끝나지 않는다. 전면 재작성이 필요하다:**
  - `docs/README.md`: 현재 표가 `00-team-access.md`~`08-decisions.md` 9행을 **디렉토리 접두사 없는 상대 링크**(`[00-team-access.md](00-team-access.md)`)로 나열한다. 새 파일명·`architectures/` 하위 구조를 반영해 표를 다시 쓴다. 서두의 "아홉 개이고" 같은 **개수를 프로즈에 못 박지 않는다** — 표 자체가 개수를 보여주므로, 숫자가 바뀔 때마다 프로즈를 따로 맞출 필요가 없게 한다("이 저장소의 설계·규약 문서, 읽는 사람으로 갈랐다"처럼 개수 없이 서술)
  - ⚠️ **v20 반영 — `docs/AGENTS.md`·루트 `AGENTS.md`·`modules/AGENTS.md` 편집/병합 지시(v15·v17 발견분)는 전부 철회한다.** 3개 파일 모두(`examples/AGENTS.md` 포함 총 4개) 이 계획 범위 밖에서 이미 삭제됐다. 편집 대상 자체가 없으므로 "완료"가 아니라 "대상 소멸"로 처리 — Acceptance Criteria도 그에 맞춰 조정됨(아래 참조)

### Phase 3 — 링크 전수 갱신 + 레포 개명 전파
⚠️ **v9 Architect 리뷰 발견 반영 — 검증을 확장자 한정 grep에서 확장자 무관 grep으로 전환한다.** v6~v8에서 `.md`/`.tf`만 보다가 `.yaml`을 놓쳐 `.trivyignore.yaml`의 경로 한정 예외가 깨질 뻔했고(아래 참조), 직접 재실측한 결과 이 저장소의 파일 헤더 컨벤션(`docs/06-conventions.md` §8 "파일 헤더는 3~6줄... 계약: docs/05-modules.md") 때문에 **`modules/**/*.tf` 전부**(개별 파일을 여기 다 나열하지 않는다 — 4개 모듈의 `main.tf`·`variables.tf`·`outputs.tf`·`iam.tf`·`addons.tf`·`flow-logs.tf` 등 전체)와 `modules/eks-cluster/tests/plan.tftest.hcl`도 옛 경로를 인용하고 있음을 확인했다(예: `modules/eks-cluster/addons.tf:65`가 `examples/eks-cluster-enterprise/README.md`를 인용). 확장자를 미리 짐작해 나열하는 방식 자체가 반복적으로 뚫렸으므로, 이후 검증은 확장자를 지정하지 않고 **디렉토리만 제외**(`.git`·`.terraform`·`.omc`)하는 방식으로 통일한다.

대상(예시 — 실제 갱신은 아래 grep이 걸리는 모든 파일): `README.md`·`CLAUDE.md`·`docs/README.md`·`docs/aws-naming-abbreviations.md`·이동된 `docs/*` 상호링크·`modules/**/*.tf`·`modules/**/tests/*.tftest.hcl`(헤더의 `docs/05-modules.md`→`docs/module-index.md`, 인라인 주석의 `examples/*-enterprise`→새 경로)·`.trivyignore.yaml`(아래 Phase 4 참조)·`scripts/README.md`(이관된 두 스크립트 항목 제거 + 아래 v20 레포명 치환)·`.opencode/agents/{architect,code-reviewer,planner}.md`·`.opencode/commands/{review,plan}.md`·`.claude/skills/notepad-sync/SKILL.md`(§8 인용을 절 제목 참조로 교체 + 아래 v20 레포명 치환). ⚠️ **v20 반영 — `AGENTS.md`·`docs/AGENTS.md`·`modules/AGENTS.md`는 대상에서 제외한다(4개 전부 이미 삭제, 재생성하지 않음).**
- ⚠️ **v20 반영 — sibling repo 개명(`iac-reference-infra`→`eks-reference-infra`, `iac-platform-gitops`→`eks-platform-gitops`) 전파.** v19는 이 계획 문서 본문만 치환했고 저장소 실물은 손대지 않았다 — Critic이 34곳 잔존을 실측했다: `README.md`(18·29·33·36행) · `CLAUDE.md`(34·37행) · `docs/01-architecture.md`(23·39·94·97·105·133·134·172행, 8곳 — Phase 2 이동 후 `docs/architectures/eks-gitops-hub-spoke/overview.md` 기준으로 적용) · `docs/02-choose-your-path.md`(10곳, 이동된 `choose-your-path.md` 기준) · `docs/05-modules.md`(231행, 이동된 `module-index.md` 기준) · `docs/06-conventions.md`(51행, 이동된 `conventions.md` 기준) · `scripts/README.md`(165·168·170·228행) · `.github/workflows/verify.yml`(4행, 주석) · `.claude/skills/notepad-sync/SKILL.md`(6곳). 단순 문자열 치환이다 — `overview.md`의 "세 저장소가 계층을 어떻게 나눠 갖는가" 절 자체를 다시 쓰는 편집(위 Phase 2, "내용 편집은 후속 작업"으로 범위 밖 처리한 것)과는 별개다
- 검증(v20): `grep -rln 'iac-reference-infra\|iac-platform-gitops' . --exclude-dir=.git --exclude-dir=.terraform | grep -v '^\(\./\)\?\.omc/'` → 0건 기대(`.omc/notepad.md`는 역사적 기록이라 예외, v10과 동일 근거)
- ⚠️ **v20 반영 — §8 "적용 범위" 서술·스캐너가 존재하지 않는 `AGENTS.md`를 계속 가리킨다.** `docs/conventions.md`(구 06, 261행) "저장소 전역의 `README.md`·`AGENTS.md`"에서 `·AGENTS.md` 제거. `.githooks/pre-commit`(16행 주석 및 `docs_staged` grep 패턴)에서 `AGENTS.md` 언급·`|(^|/)AGENTS\.md$` 알터네이션 제거. `scripts/validate-doc-conventions.py`(§8 인용 주석 및 `default_targets()`의 `targets |= set(glob.glob("**/AGENTS.md", recursive=True))` 줄) 제거 — 매칭 대상이 영구히 없는 죽은 경로다(이 저장소 관례 "죽은 경로를 남기지 않는다")
- ⚠️ **v16 Architect 리뷰 발견 반영 — `modules/eks-cluster/tests/plan.tftest.hcl:19`의 `examples/workbench-enterprise` 인용은 정정한다(v15까지 "범위 밖, 손대지 않음"이었던 판단을 철회).** 존재한 적 없는 경로를 인용하는 기존 오기이지만, 아래 Phase 3·7에 추가한 C1 catch-all(`(^|[^/])examples/` 패턴)이 이 줄도 정확히 잡아내는데 "손대지 않는다"로 두면 AC가 원리적으로 통과 불가능해진다(Architect 발견 — v11이 `decisions.md`에서 이미 겪은 것과 같은 유형의 자기모순). 문자열 인용 없이 서술로 교체한다(예: "이 변수의 회귀 방지는 workbench 통합 예제가 실제로 소비하고 CI 게이트가 검증한다"처럼 구체 경로 없이) — 어차피 존재하지 않는 경로를 고치는 것이라 순손실이 없다
- ⚠️ **v10 Architect 리뷰 발견 반영 — `--exclude-dir=.omc`는 이 저장소에서 실제로 동작하지 않는다.** `.gitignore`의 `!/.omc/notepad.md` 부활 규칙 때문에 `.omc/notepad.md`·`project-memory.json`은 git 추적 대상이고, 이 환경의 grep이 `.gitignore` 인식 래퍼라 `--exclude-dir=.omc`가 무시된다(3회 재현 확인). `.omc/notepad.md`는 이 저장소 관례상 세션 기록(git blame과 같은 성격의 역사적 서술) — 옛 경로 인용을 소급 수정하지 않는다(`docs-no-dated-narrative` 원칙). 대신 v1~v8이 원래 쓰던 방식대로 **디렉토리 순회 제외가 아니라 출력 후 파이프 필터**(`| grep -v '^\(\./\)\?\.omc/'`)로 되돌린다 — 이건 문자열 후처리라 gitignore 인식 여부와 무관하게 항상 동작한다. `--exclude-dir=.git`·`--exclude-dir=.terraform`은 (gitignore 부활 규칙이 없어) 그대로 둔다.
- 검증(v10): `grep -rln "docs/0[0-9]-" . --exclude-dir=.git --exclude-dir=.terraform | grep -v '^\(\./\)\?\.omc/'` → 0건
- ⚠️ **v21 반영 — v10의 "구 모듈 경로 문자열" 검증(`modules/vpc\|modules/eks-cluster\|...` → 0건 기대)은 폐기한다.** flat 유지 결정으로 `modules/vpc`·`modules/eks-cluster`·`modules/workbench`·`modules/cross-account-trust-role`은 도메인 재편 전과 **동일한 현재 경로**다 — "구 경로"가 아니므로 이 문자열이 저장소 전역에 남아 있는 것이 정상이고, 이 grep을 그대로 돌리면 수백 곳의 정당한 참조가 전부 거짓양성으로 잡힌다. 모듈 자체의 경로 변경은 없으므로 이 항목이 검증할 대상 자체가 없어졌다
- 검증(v10): 구 `examples/` top-level 경로 문자열 — `grep -rln 'examples/vpc-enterprise\|examples/eks-cluster-enterprise' . --exclude-dir=.git --exclude-dir=.terraform | grep -v '^\(\./\)\?\.omc/'` → 0건
- 검증(v10, v11에서 예외 조항 제거 — 아래 참조): 이관된 문서·스크립트 경로 인용 잔존 — `grep -rln 'docs/0[34]-\|docs/07-runbooks\|scripts/argocd-seed\|scripts/teardown-verify' . --exclude-dir=.git --exclude-dir=.terraform | grep -v '^\(\./\)\?\.omc/'` → **0건, 예외 없음**(v11 Architect 리뷰 발견 — `docs/decisions.md`의 이관 기록에 옛 번호 파일명을 인용하지 않도록 Phase 5에서 지시하므로, "decisions.md만 예외"라는 특례 자체가 필요 없어졌다. Phase 7 AC도 동일)
- ⚠️ **v15 Critic 리뷰 발견 반영(C1) — 위 grep들은 전부 `docs/0X-`처럼 디렉토리 접두사가 붙은 형태만 잡는다.** `docs/README.md`·`docs/AGENTS.md`가 그 디렉토리 **안에서** 쓰는 상대 링크(`[00-team-access.md](00-team-access.md)`, `` `03-hub-lifecycle.md` ``)와 `AGENTS.md`·`modules/AGENTS.md`의 `../examples/<module>/` 같은 상대경로는 이 패턴에 전혀 안 걸려 "0건"이 거짓 통과한다(실측 확인 — 두 파일 합쳐 19곳). **접두사 비의존 catch-all을 추가한다**:
- 검증(v15): `grep -rlnE '0[0-8]-(team-access|architecture|choose-your-path|hub-lifecycle|spoke-lifecycle|modules|conventions|runbooks|decisions)' . --exclude-dir=.git --exclude-dir=.terraform | grep -v '^\(\./\)\?\.omc/'` → 0건(디렉토리 접두사 유무 무관하게 옛 번호 파일명 자체를 잡는다)
- ⚠️ **v17 Architect 리뷰 발견 반영 — 완벽한 정규식으로 "0건"을 노리는 시도를 3번(v9·v11·v16과 동일 계열) 반복하다 그만둔다.** 실측(직접 실행) 결과, 이 패턴은 다음 **5곳**의 정당한 일반 서술도 함께 잡는다 — 전부 "top-level `examples/` 디렉토리"가 아니라 "예제라는 개념"을 가리키는 문장이라 이동 후에도 참이다: `docs/conventions.md`(구 06, "aws provider (루트) ... `examples/` · 배포 루트" 행), `modules/{vpc,eks-cluster,workbench,cross-account-trust-role}/versions.tf`("루트(examples/·소비 프로젝트)가 lock과 함께 통제한다" 주석, 4개 모듈 전부 동일 문구 — v21에서 flat 경로로 조정). 이 5곳을 **알려진 예외로 명시 등재**하고, 그 외 전부에서 0건을 요구한다 — "0건, 예외 없음"이 아니라 "0건 + 이 5곳 제외"가 이 패턴의 정직한 최종 형태다
- 검증(v17, v21에서 flat 경로로 조정): `grep -rlnE '\.\./examples/|(^|[^/])examples/' . --exclude-dir=.git --exclude-dir=.terraform | grep -v '^\(\./\)\?\.omc/' | grep -vE '^(\./)?(docs/conventions\.md|modules/(vpc|eks-cluster|workbench|cross-account-trust-role)/versions\.tf)$'` → 0건

### Phase 4 — `terraform-docs` 도입, `module-index.md` 축소
(v4와 동일, glob 경로만 조정)
- ⚠️ **v15 Critic 리뷰 발견 반영(M2) — 4개 모듈에는 아직 `README.md`가 없다**(`ls modules/*/README.md` → 0건, 실측). "마커 삽입"이 아니라 **먼저 마커만 담은 빈 `README.md`를 4개 생성**한 뒤 terraform-docs로 채운다.
- 실행 전 description 누락 확인(awk 스크립트, v4와 동일)
- `for dir in modules/*/; do terraform-docs markdown table --output-file README.md --output-mode inject "$dir"; done` 실행(v21 — flat 유지로 1단계 와일드카드, `examples/` 하위는 `modules/<name>/examples/`로 2단계 더 깊어 매칭되지 않음)
- `docs/module-index.md`를 표 한 장으로 재작성
- `.githooks/pre-commit`에 terraform-docs drift 검사(`--output-check`) + `# terraform-docs version: vX.Y.Z` 리터럴 주석
- `.github/workflows/verify.yml`에 신규 스텝 `"게이트 7/7 — terraform-docs drift 검사"` 추가 + 동일 리터럴 주석.
- ⚠️ **v13 Architect 리뷰 발견 반영 — 게이트 개수 "6→7" 표기가 흩어진 5곳을 전부 갱신한다**(실측):
  - `.github/workflows/verify.yml`(46·53·61·94·115·132행) — 기존 스텝명 `"게이트 1/6"`~`"게이트 6/6"` **6개 전부**의 분모를 `/6`→`/7`로 변경(번호 자체는 유지, 분모만). 신규 스텝은 `"게이트 7/7"`
  - `README.md:77` "같은 6개 게이트를 돈다" → "7개"
  - `CLAUDE.md:184` "게이트 6개를 검증한다" → "7개"
  - `docs/conventions.md`(구 06, 221행) "게이트 6개를 돈다" → "7개"
  - `scripts/README.md:272` "6개 게이트도" → "7개"
  - ⛔ **`docs/conventions.md`(구 06, 104행) "CI 게이트 6이 막는다"는 건드리지 않는다** — 이건 총 개수가 아니라 lock registry 검사가 여전히 **여섯 번째** 게이트라는 서수 지칭이고, terraform-docs는 그 뒤에 일곱 번째로 추가되므로 이 문장은 그대로 참이다. "6"이 보인다고 전부 고치면 오히려 틀린 수정이 된다
- ⚠️ **v14 Architect 리뷰 발견 반영 — 숫자만 6→7로 바꾸는 걸로는 부족하다. 개수 옆에는 항상 게이트를 나열한 목록·표·원문자(①~⑥)가 붙어 있고, 그 나열에 7번째 항목을 추가하는 지시가 v13까지 빠져 있었다**(실측 — 전체 저장소의 원문자 ①~⑥ 사용처를 훑어 이 세 곳만 실제 CI 게이트 목록이고 나머지는 전혀 다른 주제의 무관한 번호 매김임을 확인):
  - `docs/conventions.md`(구 06, 게이트 표): `| 6 | lock registry 검사 |` 다음 행에 `| 7 | terraform-docs drift 검사 |` 추가
  - `README.md:78`: `` `tofu fmt` · `tflint` · `trivy config` · 모듈 `validate`+`test` · 예제 `validate` · lock registry 검사. `` 뒤에 `· terraform-docs drift 검사` 추가
  - `CLAUDE.md:184-187`: `① ... ⑥ **lock registry 검사**(...)` 나열 뒤에 `⑦ **terraform-docs drift 검사**` 추가
  - (확인 완료) `modules/eks-cluster/tests/plan.tftest.hcl:19`의 "CI 게이트 ⑤" 부분 — 게이트 5(examples validate)는 이번 변경으로 서수가 안 바뀌므로 그대로 정확하다(v20 — `examples/AGENTS.md`는 이미 삭제돼 이 항목에서 제외, 병합 대상 자체가 없다). 단, `plan.tftest.hcl:19`는 같은 줄의 `examples/workbench-enterprise` 인용 때문에 위 Phase 3의 v16 항목대로 어차피 편집된다 — "게이트 ⑤" 부분까지 지우라는 뜻은 아니다
  - (확인 완료, 무관) `.github/workflows/verify.yml:88`의 "전체 스캔 게이트(1·2·3·6)" — terraform-docs는 OpenTofu plugin cache를 쓰지 않으므로 이 목록에 속하지 않는다. `docs/03·04·07`·`scripts/*`·`modules/*`의 나머지 ①②③ 전부는 완전히 다른 주제(teardown 절차·addon 번역 계층 등)라 무관 확인 — `docs/03·04·07`은 Phase 2에서 어차피 제거된다
- ⚠️ **v21 반영 — v6·v8·v9의 게이트 4·pre-push·`.trivyignore.yaml` 글롭/경로 "수정"은 전부 폐기(moot)한다.** 세 가지 전부 도메인 재편(`modules/<domain>/<name>`)이 만드는 문제였는데, flat 유지 결정으로 그 전제 자체가 사라졌다:
  - **게이트 4(modules: validate+test)**: `for m in modules/*/; do ...; done`(원본 그대로) — `modules/vpc/`·`modules/eks-cluster/`·`modules/workbench/`·`modules/cross-account-trust-role/` 4건이 정확히 매칭된다. **변경 불필요.**
  - **`.githooks/pre-push`(25행)**: 같은 이유로 `modules/*/` 원본 그대로 4건 전부 발견한다. **변경 불필요.**
  - **`.trivyignore.yaml`**: `paths: ["modules/workbench/main.tf"]`는 애초에 옮겨진 적 없는 현재 경로 그대로다. **변경 불필요.**
  - **게이트 5(examples: validate)만 실제로 바뀐다** — 물리적으로 옮겨진 것은 top-level `examples/`가 각 모듈의 `examples/`로 흡수된 것뿐이라서다: 현재 `for e in examples/*/; do ...; done`(top-level `examples/*/`)를 **`examples/*/`→`modules/*/examples/*/`로 변경**(모듈명 1단계 + `examples/` 고정 + 예제명 1단계 — 정확히 `modules/vpc/examples/enterprise/`·`modules/eks-cluster/examples/enterprise/` 2건만 매칭). 같은 스텝의 에러 메시지(`verify.yml:130` `"examples/ 에 검증할 .tf 가 하나도 없다"`)도 새 경로 기준 문구로 함께 고친다
- ⚠️ **`scripts/validate-doc-conventions.py`의 `default_targets()`**(v20 — 라인번호 대신 심볼로 지시: 편집이 누적되며 실제 줄 번호가 밀려 있었다): `glob.glob("docs/*.md")`가 **비재귀**다. `overview.md`·`choose-your-path.md`가 `docs/architectures/eks-gitops-hub-spoke/`로 이동하면 이 두 파일이 이모지 어휘·400줄 제한·(Phase 5에서 추가되는) em-dash 검사 전부에서 영구히 빠진다. `.githooks/pre-commit`은 staged 경로를 인자로 직접 넘겨(우연히) 이 버그를 피하지만 **CI(`verify.yml`의 `docs-conventions` job, 인자 없이 호출)에서만 조용히 커버리지가 빠지는** 형태라 발견하기 어렵다. **`glob.glob("docs/*.md")`를 `glob.glob("docs/**/*.md", recursive=True)`로 변경**(Phase 5에서 같은 파일을 이미 수정하므로 그 자리에 포함) — 이 항목은 docs/ 이동에서 비롯된 것이라 v21(modules/ flat 유지)과 무관하게 그대로 유효하다
- `docs/conventions.md` 도구 핀 표에 terraform-docs 버전 추가

### Phase 5 — `stop-slop` 규칙 전면 채택(집행은 신규/변경분만, 기존 위반은 grandfather)
(v4와 동일)
- `docs/conventions.md`에 §9 "문체 규칙" append(기존 §8 뒤, 삽입 아님)
- `scripts/validate-doc-conventions.py`에 em-dash 검사 + `LEGACY_EM_DASH_ALLOWLIST`(이동 전 19개 파일의 신규 경로 등재, Phase 2에서 제거된 3개 파일은 애초에 목록에 넣지 않음)
- ⚠️ **v15 Critic 리뷰 발견 반영(C3·M1) — Phase 4에서 생성되는 `modules/**/README.md`가 이 게이트와 충돌한다.** `default_targets()`의 `**/README.md`(재귀, 이미 존재하던 패턴)가 이 4개 파일도 자동으로 스캔 대상에 넣는데, 이 파일들은 `variable`/`output`의 `description`을 terraform-docs가 그대로 주입한 **생성물**이다. 실측: `modules/eks-cluster/variables.tf`·`modules/vpc/variables.tf`의 description 다수가 이미 em-dash를 쓰고 있어(`modules/eks-cluster/variables.tf:54,66,70,135,137,150,203` 등), 생성된 README가 곧바로 em-dash 게이트에 걸린다. 신규 파일이라 `LEGACY_EM_DASH_ALLOWLIST`(이동 전 19개 한정) 대상도 아니다. **`modules/**/README.md`를 em-dash 검사와 400줄 제한(`LINE_LIMIT_EXCEPTIONS`) 양쪽에서 예외 처리한다** — 이유: 사람이 쓰는 프로즈가 아니라 `.tf`의 `description`을 그대로 반영하는 생성물이므로, 문체 규칙의 대상인 "팀원이 쓰는 문서"에 해당하지 않는다(`docs/aws-naming-abbreviations.md`가 "데이터 카탈로그"로 400줄 예외를 받는 것과 같은 논리). `.tf`의 `description` 자체에서 em-dash를 제거할지는 이번 계획 범위 밖(원하면 후속 작업)
- 같은 파일의 `default_targets()`: `glob.glob("docs/*.md")`를 `glob.glob("docs/**/*.md", recursive=True)`로 변경(위 Phase 4 v8 항목 참조 — 이동된 `overview.md`·`choose-your-path.md`가 스캔 대상에서 영구히 빠지는 걸 막는다)
- `docs/decisions.md`에 "stop-slop 전면 채택, 기존 위반은 allowlist로 단계적 정리" + "hub/spoke-lifecycle·runbooks·관련 스크립트를 eks-reference-infra로 이관" 기록 — ⚠️ **v11 Architect 리뷰 발견 반영**: 이 기록에 `docs/03-hub-lifecycle.md`처럼 **옛 번호 파일명을 문자 그대로 인용하지 않는다**("hub/spoke 생애주기 문서"처럼 서술로만 지칭). 그래야 Phase 7의 "이관 문서 인용 잔존 0건" grep과 이 기록이 서로 모순되지 않는다(아래 Phase 7·AC 참조)

### Phase 6 — **[범위 밖] 후속 작업**: em-dash 레거시 정리 (v4와 동일, 변경 없음)

### Phase 7 — 검증
```
tofu fmt -recursive -check -diff
tofu -chdir=modules/vpc test
tofu -chdir=modules/eks-cluster test
tofu -chdir=modules/workbench test
tofu -chdir=modules/cross-account-trust-role test
tofu -chdir=modules/vpc/examples/enterprise validate
tofu -chdir=modules/eks-cluster/examples/enterprise validate
tflint --recursive
trivy config --quiet --exit-code 1 --severity MEDIUM,HIGH,CRITICAL \
  --skip-dirs '**/.terraform' --tf-exclude-downloaded-modules \
  --ignorefile .trivyignore.yaml .
python3 scripts/validate-abbreviations.py
python3 scripts/validate-doc-conventions.py
for dir in modules/*/; do terraform-docs markdown table --output-mode inject --output-check --output-file README.md "$dir"; done
grep -rln "docs/0[0-9]-" . --exclude-dir=.git --exclude-dir=.terraform | grep -v '^\(\./\)\?\.omc/'
grep -rln 'examples/vpc-enterprise\|examples/eks-cluster-enterprise' . --exclude-dir=.git --exclude-dir=.terraform | grep -v '^\(\./\)\?\.omc/'
grep -rln 'docs/0[34]-\|docs/07-runbooks\|scripts/argocd-seed\|scripts/teardown-verify' . --exclude-dir=.git --exclude-dir=.terraform | grep -v '^\(\./\)\?\.omc/'   # 0건 기대(Phase 5 decisions.md 기록이 옛 번호 파일명을 인용하지 않았다면 자동으로 0건)
grep -rln 'iac-reference-infra\|iac-platform-gitops' . --exclude-dir=.git --exclude-dir=.terraform | grep -v '^\(\./\)\?\.omc/'   # v20 신규, 0건 기대(sibling repo 개명 전파 확인)
find . -name AGENTS.md -not -path './.terraform/*'   # v20 신규, 0건 기대(4개 전부 부재)
grep -rlnE '0[0-8]-(team-access|architecture|choose-your-path|hub-lifecycle|spoke-lifecycle|modules|conventions|runbooks|decisions)' . --exclude-dir=.git --exclude-dir=.terraform | grep -v '^\(\./\)\?\.omc/'   # C1 catch-all, 0건 기대(접두사 없는 상대 링크까지 포함)
grep -rlnE '\.\./examples/|(^|[^/])examples/' . --exclude-dir=.git --exclude-dir=.terraform | grep -v '^\(\./\)\?\.omc/' | grep -vE '^(\./)?(docs/conventions\.md|modules/(vpc|eks-cluster|workbench|cross-account-trust-role)/versions\.tf)$'   # C1 catch-all, 0건 기대(알려진 예외 5곳 제외 — v17 참조, v21에서 flat 경로로 조정)
A="$(grep -m1 '# terraform-docs version:' .githooks/pre-commit | sed 's/^[[:space:]]*//')"; B="$(grep -m1 '# terraform-docs version:' .github/workflows/verify.yml | sed 's/^[[:space:]]*//')"; [ -n "$A" ] && [ "$A" = "$B" ] && echo "일치" || (echo "불일치 또는 주석 누락"; exit 1)   # v21 반영 — YAML run 블록의 들여쓰기 때문에 원본 라인 그대로 비교하면 항상 불일치하므로 앞 공백을 제거하고 비교한다
test ! -d examples   # top-level examples/ 폐지 확인
for m in modules/*/; do [ -d "${m}tests" ] && echo "$m"; done | wc -l   # pre-push 재현, 4 기대(v21 — flat 유지로 1단계 와일드카드)
grep -c '게이트 [0-9]/7' .github/workflows/verify.yml   # 7 기대(1/7~7/7 전부, 게이트 6도 분모만 /7로 바뀌고 번호는 유지)
grep -c '게이트 [0-9]/6' .github/workflows/verify.yml   # 0 기대(분모 6 잔존 없음)
sed -n '/^| # | 게이트 |/,/^$/p' docs/conventions.md | grep -c '^| [0-9] |'   # 7 기대 — v15 Critic 리뷰 발견(C2): 파일 전체를 세면 §8의 "문서 작성 규칙" 표(별도 1~7행)까지 같이 잡혀 실측 13~14가 나온다(전체 grep은 영구히 통과 불가능한 체크였다). 게이트 표만 sed로 잘라서 센다
grep -c '⑦' CLAUDE.md   # 1 기대
grep -c 'terraform-docs drift 검사' README.md   # 1 기대(나열에 7번째 항목 추가됐는지)
# 위 4개는 개별 실행 권장 — grep -c가 0건일 때 exit 1을 내므로 set -e 스크립트에 그대로 묶으면 조기 종료된다
grep -rln '6개 게이트\|게이트 6개' . --exclude-dir=.git --exclude-dir=.terraform | grep -v '^\(\./\)\?\.omc/'   # 0건 기대(docs/conventions.md 104행의 "게이트 6이 막는다"는 이 패턴과 무관해 걸리지 않음)
python3 -c "import glob; print(len(glob.glob('docs/**/*.md', recursive=True)))"   # 비재귀 대비 증가 확인(architectures/ 하위 2건 포함)
```

## 브랜치 전략
(v4와 동일) 단일 브랜치+단일 PR — `.github/workflows/verify.yml`·`.githooks/pre-commit` 변경이 걸려 있어 브랜치 대상. Phase 6은 별도 main 직접 커밋.

## Acceptance Criteria — Phase 0~5·7 (이번 PR)

- [ ] `modules/{vpc,eks-cluster,workbench,cross-account-trust-role}/` flat 구조로 존재(v21 — 도메인 중첩 없음)
- [ ] `modules/vpc/examples/enterprise/`·`modules/eks-cluster/examples/enterprise/` 존재, `tofu validate` 통과, top-level `examples/` 디렉토리 부재(`test ! -d examples`)
- [ ] `docs/{team-access,module-index,conventions,decisions}.md` 존재, `docs/0[0-9]-*.md` 부재
- [ ] `docs/architectures/eks-gitops-hub-spoke/{overview,choose-your-path}.md`만 존재(`hub-lifecycle`·`spoke-lifecycle`·`runbooks` 부재), `docs/architectures/README.md` 존재
- [ ] `scripts/`에 `validate-abbreviations.py`·`validate-doc-conventions.py`·`README.md`만 존재(`argocd-seed.sh`·`teardown-verify.sh` 부재)
- [ ] `AGENTS.md` 4개(루트·`docs/`·`examples/`·`modules/`) 전부 부재 확인(`find . -name AGENTS.md -not -path './.terraform/*'` → 0건), 예제 9곳의 `examples/AGENTS.md` 참조도 제거됨(위 Phase 1 v20 참조)
- [ ] `docs/conventions.md`·`.githooks/pre-commit`·`scripts/validate-doc-conventions.py`에서 §8 적용 범위 서술·grep 패턴·glob 대상 전부에서 `AGENTS.md` 언급 제거(위 Phase 3 v20 참조)
- [ ] `grep -rln 'iac-reference-infra\|iac-platform-gitops' . --exclude-dir=.git --exclude-dir=.terraform | grep -v '^\(\./\)\?\.omc/'` → 0건(sibling repo 개명 34곳 전파 확인)
- [ ] `.gitignore`에 `__pycache__/` 등재, `scripts/__pycache__/` 부재
- [ ] 위 Phase 7의 문자열 잔존 grep 전부(구 docs 번호·구 examples 경로·이관 문서/스크립트 인용·C1 catch-all 2종·구 레포명·AGENTS.md 부재·terraform-docs 버전) 0건 또는 성공 종료(v21 — "구 모듈 경로" grep은 flat 유지로 대상 자체가 없어져 폐기)
- [ ] CI 게이트 4(`modules/*/`, v21 — flat 유지로 원본 그대로)·게이트 5(`modules/*/examples/*/`)가 각각 정확히 4건·2건을 discover(로컬 재현: `for m in modules/*/; do echo "$m"; done | wc -l`→4, `for e in modules/*/examples/*/; do echo "$e"; done | wc -l`→2)
- [ ] `.githooks/pre-push`의 `modules/*/`(v21 — 원본 그대로) 로컬 재현이 `tests/` 있는 4건 전부 발견(`for m in modules/*/; do [ -d "${m}tests" ] && echo "$m"; done | wc -l`→4)
- [ ] `python3 -c "import glob; print(len(glob.glob('docs/**/*.md', recursive=True)))"`가 `docs/architectures/eks-gitops-hub-spoke/{overview,choose-your-path}.md` 2건을 포함한 전체 개수를 반환(비재귀 대비 최소 +2)
- [ ] `.trivyignore.yaml`의 `paths`가 `modules/workbench/main.tf`를 가리키고(v21 — flat 유지로 애초에 경로 변경 없음), `trivy config`가 AVD-AWS-0104에서 실패하지 않음
- [ ] `modules/**/*.tf`·`modules/**/tests/*.tftest.hcl`에 옛 문서/예제 경로 잔존 없음(위 Phase 3·7의 확장자 무관 grep 4종이 전부 0건)
- [ ] `.github/workflows/verify.yml`의 게이트 스텝명이 `1/7`~`7/7` 전부(6개 아님), `README.md`·`CLAUDE.md`·`docs/conventions.md`·`scripts/README.md`의 "6개 게이트" 서술이 "7개"로 갱신(단 `docs/conventions.md` 104행의 "게이트 6이 막는다"는 서수 지칭이라 그대로 유지)
- [ ] 개수 표기뿐 아니라 **나열 자체**에도 7번째 항목이 추가됨: `docs/conventions.md` 게이트 표 7행, `README.md`의 점 나열에 terraform-docs 추가, `CLAUDE.md`의 ①~⑥ 뒤 ⑦ 추가(위 grep들로 확인)
- [ ] `docs/README.md`의 문서 개수 자연어 서술("아홉 개" 등)이 제거되고 표 자체로만 개수가 드러남(위 C1 catch-all grep 2종 0건으로 확인). `docs/AGENTS.md`·루트 `AGENTS.md`·`modules/AGENTS.md`는 v20에서 이미 삭제돼 이 AC 대상에서 제외
- [ ] 4개 모듈 `README.md`에 terraform-docs 마커, `--output-check` 통과, 생성 전 4개 모두 부재였음을 확인했던 것과 대칭으로 생성 후 4개 모두 존재
- [ ] `docs/module-index.md` 400줄 미만, `modules/**/README.md`(생성물)는 400줄 제한과 em-dash 검사 양쪽에서 명시적 예외 처리됨(`scripts/validate-doc-conventions.py`의 `LINE_LIMIT_EXCEPTIONS`·em-dash 예외 목록에 `modules/**/README.md` 패턴 등재)
- [ ] `python3 scripts/validate-doc-conventions.py`(allowlist 반영판)가 신규 작성 파일 전부에서 em-dash 0 violation
- [ ] 4개 모듈 `tofu test` 전부 pass, `tofu fmt -recursive -check -diff` 통과

## Acceptance Criteria — Phase 6 (후속 작업) — v4와 동일, 변경 없음

## Risks and Mitigations (v4 표에 추가되는 v5 신규 항목만 기재, 기존 7건은 유지)

| 위험 | 완화 |
|---|---|
| hub-lifecycle·spoke-lifecycle·runbooks·스크립트 2개를 `git rm`한 뒤 `eks-reference-infra`로의 실제 이관이 누락되면 지식이 유실된 것처럼 보임 | git 히스토리에 원본이 보존됨(이 repo 관례). `docs/decisions.md`에 이관 사실과 삭제 커밋을 남겨 추적 가능하게 함. 실제 이관은 `eks-reference-infra` 세션의 후속 작업으로 명시(repo 경계) |
| ⚠️ **v21 반영 — `eks-cluster-enterprise` 예제 상대경로 4단계 깊이 위험(v1~v20)은 소멸했다.** flat 유지로 3단계(`../../../vpc`)에서 끝난다 | 해당 없음(폐기) |
| ⚠️ **v21 반영 — CI 게이트 4(v6 Critic 발견)·`.githooks/pre-push`(v8 Critic 발견)의 `modules/*/`→`modules/*/*/` glob 변경 필요성은 소멸했다.** 둘 다 도메인 재편이 만드는 문제였는데 flat 유지로 원본 glob이 그대로 정확하다 | 해당 없음(폐기) — Phase 4·pre-push 변경 불필요, 원본 유지로 충분함을 확인 |
| CI 게이트 5(examples validate)의 glob 변경(실측 원본은 `examples/*/`이지 v5에서 잘못 적은 `examples/*/*/`가 아님 — v21에서 `modules/*/examples/*/`로 조정)을 빠뜨리면 예제가 CI에서 조용히 검증 안 됨 | Phase 4에 명시적 변경 항목으로 포함, Phase 7에서 두 예제 모두 `tofu validate` 직접 실행으로 이중 확인 |
| Phase 3/7의 잔존 경로 grep이 따옴표를 anchor로 삼아 `tofu -chdir=examples/vpc-enterprise validate` 같은 따옴표 없는 셸 명령 예시(README의 사용 예)를 놓쳐 "0건"이 거짓양성이 될 위험(v6 Critic 발견) | grep 패턴을 인용부호 비의존 단순 부분 문자열로 교체(위 Phase 3·7 참조) |
| `scripts/validate-doc-conventions.py`의 `default_targets()`가 `docs/*.md`(비재귀) glob이라 `docs/architectures/`로 이동한 두 파일이 CI 문서 규칙 검사에서 영구히 빠짐(v8 Critic 발견) | Phase 5에서 `docs/**/*.md`(recursive=True)로 변경 — v21과 무관하게 유효(docs/ 이동에서 비롯됨) |
| ⚠️ **v21 반영 — `.trivyignore.yaml` 경로 갱신 필요성(v9 Architect 발견)은 소멸했다.** flat 유지로 `modules/workbench/main.tf` 경로 자체가 바뀌지 않는다 | 해당 없음(폐기) — 원본 그대로 유효함을 확인 |
| 확장자를 미리 짐작한 grep(`--include="*.md" --include="*.tf"` 등)이 `.yaml`·`modules/**/*.tf` 헤더·`.tftest.hcl`처럼 예상 못 한 파일 유형을 반복적으로 놓침(v6~v9에서 4차례 반복된 패턴) | Phase 3·7 검증을 확장자 무관 방식으로 전환 |
| **게이트 총 개수 "6→7" 표기가 `verify.yml` 스텝명 6곳 + 산문 4곳(README/CLAUDE.md/conventions.md/scripts/README.md)에 흩어져 있어 일부만 갱신하고 지나칠 위험**(v13 Architect 발견) | Phase 4에 5곳 전부 명시, `docs/conventions.md` 104행의 서수 지칭("게이트 6이 막는다")은 의도적으로 미변경 — 감별 기준까지 명시. Phase 7·AC에 카운트 검증 추가 |
| **개수 숫자만 6→7로 바꾸고 그 옆의 실제 나열(표·점 목록·원문자)에는 7번째 항목을 안 넣는 결함**(v14 Architect 발견 — v13 자신이 고친 것과 동일 유형이 같은 자리에서 재발) | `docs/conventions.md` 게이트 표에 7행, `README.md` 점 나열에 항목 추가, `CLAUDE.md`의 ①~⑥ 뒤 ⑦ 추가 — 저장소 전체 원문자 사용처를 전수 스캔해 이 3곳 외에는 전부 무관한 주제임을 확인 후 범위 확정 |
| **`--exclude-dir=.omc`가 이 환경에서 무력화됨**(v10 Architect 발견) — `.gitignore`의 `!/.omc/notepad.md` 부활 규칙 때문에 그 파일이 git 추적 대상인데, gitignore 인식 grep 래퍼가 디렉토리 제외 자체를 건너뛴다(3회 재현). 디렉토리 순회 제외에 의존하는 모든 검증이 "0건"에 영영 도달 못 하고 육안 판정으로 후퇴할 위험 | `--exclude-dir=.omc`를 출력 후 파이프 필터 `\| grep -v '^\(\./\)\?\.omc/'`로 교체(v1~v8이 원래 쓰던 방식 — 문자열 후처리라 gitignore 인식 여부와 무관). `.omc/notepad.md`의 옛 경로 인용 자체는 역사적 기록이라 의도적으로 손대지 않는다(`docs-no-dated-narrative` 원칙) |
| `argocd-seed.sh`가 `eks-platform-gitops`와 맺고 있던 vendoring SSOT 관계(재-vendoring 절차가 `SRC=scripts/argocd-seed.sh` 고정 경로를 전제)가 `git rm` 후 죽은 문서로 남을 위험(v5 Architect 리뷰 발견) | Phase 2에서 `scripts/README.md`의 vendoring SSOT 절을 함께 제거/교체(위 참조). 새 SSOT 위치 확정과 `eks-platform-gitops` 쪽 갱신은 이 repo 범위 밖 — ADR Follow-ups에 명시 |

## ADR

- **Decision**: (v4 결정에 추가) hub-lifecycle·spoke-lifecycle·runbooks.md와 그 운영 스크립트(argocd-seed.sh·teardown-verify.sh)는 `eks-reference-infra`(EKS GitOps 패턴 레퍼런스 레포로 역할 명확화 예정)로 이관하고 이 repo에서 제거한다. top-level `examples/`는 폐지하고 각 예제를 주인공 모듈의 `examples/`로 흡수한다.
- **Drivers**: (v4 Drivers에 추가) 저장소 이름과 실제 구조의 불일치가 "패턴의 운영 절차까지 포함"하는 데까지 번져 있었다는 사용자 관찰.
- **Alternatives considered**: 위 A~D(v1~v4) + E~G(v5) 표 참조.
- **Why chosen**: 사용자가 `CLAUDE.md`의 기존 repo 경계 원칙(모듈 라이브러리=SSOT, `<project>-infra`=배포 루트)을 문서 배치에도 일관 적용해야 한다고 지적했고, 독립적으로 재확인한 근거(scripts/README.md가 이미 이관 대상 문서들과 강결합돼 있었음)가 이를 뒷받침한다.
- **Consequences**: (v4 Consequences에 추가) `eks-reference-infra` 쪽에서 별도로 이 세 문서·두 스크립트를 실제로 받아 정착시키는 작업이 필요하다(이 계획 범위 밖). `examples/eks-cluster-enterprise`의 상대경로가 깊어진다.
- **Follow-ups**: (v4 Follow-ups에 추가) `eks-reference-infra`에서 이관 콘텐츠 수용 + 레포 개명·역할 변경 자체(이 repo가 관여하지 않는 별도 작업). `argocd-seed.sh`의 새 vendoring SSOT 위치를 `eks-reference-infra`로 확정하고 `eks-platform-gitops`의 재-vendoring 절차 문서를 그 새 경로로 갱신(v5 Architect 리뷰 발견 — 이 repo 범위 밖, 두 sibling repo 쪽 후속 작업).

## 개정 이력

v1~v14는 Architect·Critic 반복 검증으로 실제 결함을 계속 찾아냈다(자세한 서술은 git 이력 — 이 파일 자체가 매 버전 커밋되지 않았다면 `.omc/notepad.md`에 남길 세션 요약 참고). 요지만 표로 남긴다.

| 버전 | 검증자 | 발견 | 반영 |
|---|---|---|---|
| v1 | Planner | 최초안 | 3단계 구조(foundations/architectures, 도메인 modules, terraform-docs) |
| v2 | Architect·Critic | Phase 6(em-dash 정리) 구조변경과 동일 PR 혼재, 링크 인벤토리 누락 | Phase 6 분리, 인벤토리 보강 |
| v3~v4 | Architect·Critic | terraform-docs 버전 판정이 육안 대조·빈 문자열 거짓 통과 | `[ -n && = ]` 종료 코드 판정으로 자동화 (4회차 APPROVE) |
| v5 | 사용자 피드백 | hub/spoke-lifecycle·runbooks·examples/·scripts 소유권 재검토 요청 | E~G 결정(iac-reference-infra 이관, examples 흡수), Principle 6 신설 |
| v6 | Architect | `argocd-seed.sh`가 `iac-platform-gitops`와 vendoring SSOT 관계 | 그 절 제거/교체 지시 추가 |
| v7~v8 | Critic | CI 게이트 4·`pre-push`의 `modules/*/` glob이 2단계 경로에서 파손(하나는 무음 무력화), `validate-doc-conventions.py` 비재귀 glob | glob 전부 `*/*/`로, `docs/**/*.md`로 재귀화 |
| v9 | Architect(네이티브 등록 후) | `.trivyignore.yaml` 경로 예외 파손, `modules/**/*.tf` 헤더도 옛 경로 인용 | 경로 갱신, 검증을 확장자 무관으로 구조 전환 |
| v10~v11 | Architect | `--exclude-dir=.omc` 무력화(gitignore 부활 규칙), 이어서 대체 필터도 `./` 접두사 가정이 틀려 no-op | 파이프 필터를 접두사 유무 무관 패턴으로 교체, 실측 재현 |
| v12~v14 | Architect | `decisions.md` 이관 기록과 grep 판정 기준 모순, 게이트 개수 "6→7" 표기가 산문 5곳+나열 3곳에 흩어짐(숫자만 바꾸고 나열은 누락) | 인용 지침 통일, 표·점 목록·원문자 나열까지 전수 갱신 |
| v15 | Critic(전체 재평가) | (a) `docs/README.md`·`docs/AGENTS.md`의 접두사 없는 상대 링크·자연어 개수 서술이 모든 grep을 회피 (b) 게이트 표 카운트 체크가 다른 표까지 잡혀 영구 실패 (c) 생성되는 모듈 `README.md`가 em-dash·400줄 게이트와 충돌 (d) 모듈 `README.md`는 아직 존재하지 않아 "마커 삽입"이 아니라 "생성"이 먼저 (e) 개정 이력 비대화로 가독성 저하 | C1 catch-all grep 2종 추가, 개수 서술 자체를 제거(표가 곧 근거), 게이트 카운트 체크를 표 범위로 anchor, 생성 README를 두 게이트에서 예외 처리, "생성 후 채움" 순서 명시, 이 표로 이력 압축 |
| v16 | Architect | v15의 C1 catch-all #2(`examples/` 패턴)가, v9~v15에 걸쳐 "범위 밖·손대지 않음"으로 명시했던 `plan.tftest.hcl:19`의 `examples/workbench-enterprise`(존재한 적 없는 경로 인용 오기)를 그대로 잡아 AC가 원리적으로 통과 불가능해짐 — v11의 `decisions.md` 자기모순과 같은 유형의 재발 | "손대지 않는다" 판단을 철회하고 그 줄을 서술로 교체(경로 문자열 인용 제거) — 어차피 존재하지 않는 경로라 순손실 없음 |
| v17 | Architect | v16 수정 후에도 같은 catch-all #2가 **정당한 일반 서술 5곳**(`docs/conventions.md`의 provider 상한 표, 4개 모듈 `versions.tf`의 동일 주석 — "루트/examples/가 상한을 통제한다"는 이동 후에도 참)까지 잡아 AC가 여전히 통과 불가능. v9·v11·v16에 이어 "완벽한 정규식 하나로 0건" 시도가 4번째로 뚫림. 부수적으로 `AGENTS.md`의 `examples/` 행(대상 디렉토리 자체가 없어짐)과 이동되는 예제 파일들 자신의 내부 자기참조(제목·`tofu -chdir` 예시·`examples/AGENTS.md` 링크)가 계획에서 빠져 있었음도 발견 | 정규식으로 완벽을 노리는 대신 **5곳을 알려진 예외로 명시 등재**하고 그 외 0건으로 전환(정직한 최종 형태). `AGENTS.md` 행 삭제 지시, Phase 1에 예제 파일 자기참조 갱신 지시, `verify.yml:130` 에러 메시지 문구 수정 추가 |

| v18 | Architect | **APPROVE.** exclude 정규식 하나가 `./` 접두사를 처리 안 해 5개 예외가 실제로는 제외되지 않는 사소한 anchoring 버그 1건만 지적(막힐 수준 아님, 구현 중 즉시 드러남) | `^(docs/...)$`를 `^(\./)?(docs/...)$`로 수정(두 곳) |
| v19 | 사용자 피드백 | sibling repo 개명 확정 — `iac-reference-infra`→`eks-reference-infra`, `iac-platform-gitops`→`eks-platform-gitops`(둘 다 이미 완료된 사실). 이 계획이 신규 작성하는 실제 파일 내용(`scripts/README.md` vendoring SSOT 안내, `docs/architectures/README.md` 라우팅 안내, `docs/decisions.md` ADR 기록)에 구 레포명이 하드코딩돼 있어 실행 시 그대로 stale 텍스트가 커밋될 위험 확인 | 본문(1~272행, 개정 이력 표 제외) 전체 치환. v18 Architect APPROVE 판정 자체는 이 치환과 무관해 유지 |
| v20 | Critic(재검증) | **REJECT.** (1) `AGENTS.md` 4개(루트·`docs/`·`examples/`·`modules/`)가 계획 범위 밖에서 이미 삭제된 채 브랜치에 들어왔는데, 계획은 여전히 이 파일들을 편집·병합한다고 전제 — AC가 원리적으로 통과 불가능 (2) 예제 9곳의 `examples/AGENTS.md` 인용이 병합 목적지를 잃음 (3) v19의 레포 개명 치환이 계획 문서 본문에만 반영되고 저장소 실물 34곳은 지시가 없음 (4) Minor 4건(라인번호 밀림·Phase 7 grep 개수 표기 오차·`__pycache__` 미ignore·`docs/README.md`의 이미 삭제된 문서 링크 — 이 마지막 항목은 Phase 2 재작성으로 자동 해소되어 별도 조치 불필요) | 사용자 확정(2026-08-24): AGENTS.md 4개 폐지를 유지하고 계획을 그에 맞춰 전면 재작성(목표 구조·Phase 1~3·AC). 레포 개명 34곳을 Phase 3 명시 항목 + Phase 7 grep으로 등재. §8 적용 범위 서술 3곳(`conventions.md`·`pre-commit`·`validate-doc-conventions.py`)에서 AGENTS.md 언급 제거 지시 추가. Minor 전부 반영(`__pycache__` gitignore는 Phase 0, 라인번호는 심볼 참조로). 추가 Critic 재검증은 사용자 판단으로 생략 |

| v21 | 사용자 피드백(실행 도중) | Phase 0~1 실행 중 `modules/` 도메인 재편(v1~v20, `networking/`·`compute/`·`security/` 중첩)을 사용자가 재검토 — 소비자가 `source`에 직접 쓰는 경로라 flat이 더 직관적이고 확장(신규 모듈 추가)에도 유리하다고 판단. docs/architectures/ 쪽 패턴별 디렉토리는 이 결정에서 제외(사용자가 modules/로 범위 한정) | `modules/{vpc,eks-cluster,workbench,cross-account-trust-role}/` flat으로 물리 이동 되돌림(git mv). 파급효과 확인: eks-cluster-enterprise 예제의 cross-module 참조가 4단계→3단계로 얕아져 v1~v20이 감수하려던 "경로 깊어짐" 비용이 소멸. CI 게이트 4·`pre-push`·`.trivyignore.yaml`은 도메인 재편이 만들던 문제였으므로 원본 그대로 유효(변경 불필요로 되돌림) — 게이트 5(examples validate)만 `modules/*/examples/*/`로 실질 변경 유지. Phase 3의 "구 모듈 경로" grep(v10)은 대상 소멸로 폐기. 소비자 `source` 예시(README·module-index·conventions·CLAUDE.md)는 이미 릴리스된 태그(`vpc-v0.3.0` 등)가 구조 변경 이전 커밋을 가리켜 여전히 유효하다는 점을 발견 — 사용자 결정으로 태그 재컷은 이번 PR 범위 밖, 예시만 새 경로+`vX.Y.Z` 자리표시자로 갱신 |

**다음 단계**: v21 반영 완료. Phase 3(링크 전수 갱신) 계속 진행 중.
