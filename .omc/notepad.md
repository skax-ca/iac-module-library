# Notepad — iac-module-library

## Priority Context

SSOT=이 repo(`terraform-enterprise-poc`는 동결, 수정 금지). 엔진=OpenTofu 단독 — `docs/08-decisions.md`(재제안 전 필독). 규약=`docs/06-conventions.md`, 네이밍=`docs/aws-naming-abbreviations.md`. 최신 태그·모듈 현황 SSOT는 이 파일이 아니라 `README.md`·`git tag -l`. opencode 구성은 `.opencode/`(역할 에이전트·notepad 툴)와 전역 커맨드(`/session-start`·`/session-end`) 소관. 영구 사실·미결 항목은 `project-memory.json`, 지난 세션 전문은 이 notepad `## MANUAL`(자동 로드 안 됨) 참조.

## Working Memory
### 2026-08-21 15:58
iac-module-library notepad-sync 스킬 동기화 완료. iac-reference-infra 버전과 비교 후 2건 수정: (1) 200KB 비대화 사건 귀속 오류 — "iac-reference-infra에서" → "이 repo에서"로 정정 (2) `docs/deployment-facts.md` 참조 제거 — 이 repo에 없는 파일이라 `docs/06-conventions.md` §8 일반 참조로 변경. opencode.jsonc 변경분도 함께 staged.

### 2026-08-18 (opencode 세션) — opencode OMC-동등 구조 구축·전역화

opencode에서 OMC를 못 쓰는 갭(notepad 브리지·팀 오케스트레이션·통합 커맨드) → 공식 docs 리서치로 `agents+commands+plugins`면 전부 native 재현 가능함을 확인 후 구축:
- `.opencode/agents/`: planner·architect·code-reviewer·verifier (subagent + edit deny, verifier만 bash 허용)
- `.opencode/commands/`: plan·review·verify (이 repo 특화, subtask 격리)
- `.opencode/plugins/notepad.ts`: `notepad_read`/`notepad_write_priority|working|manual` 커스텀 툴 + 내장 edit가 `.omc/notepad.md` 직접 수정 시 차단 게이트. bun 단위 테스트 10건 통과
- 함정: bun install이 `.opencode/.gitignore` 자동 생성하며 package.json까지 무시 → 커밋 누락. `.opencode/.gitignore`를 직접 관리(node_modules·package-lock.json만 무시)로 해결
- 전역화: `/session-start`·`/session-end` 커맨드는 전역 `~/.config/opencode/commands/`로 이동(프로젝트 스코프 제거) — 다른 repo에서도 동작. dotfiles-claude `sync.sh` push · `bootstrap.sh` 복원에 `commands/` 동기화 추가
- 커밋: iac-module-library `ceea7ca`(feat 구성) → `d2427da`(deps 커밋 대상화) / dotfiles-claude `1b468bb`
- ⚠️ notepad 플러그인 툴은 opencode **재시작 후** 활성화 — 이 세션은 직접 편집으로 갱신함. 다음부터는 툴 경유가 우선

### 2026-08-14 08:24
### 2026-08-18 01:01
### 2026-08-18 05:51
iac-platform-gitops 라인바이라인 리뷰(초보자 대상, ArgoCD/GitOps 개념부터) 진행 중. 완료: README, bootstrap/root-app.yaml(상세 설명), skip-file-rendering 마커 예시(karpenter/nodepool), kyverno-policies(업스트림) vs 커스텀 정책 구조 설명. 다음 리뷰 지점(README 레이아웃 순서): bootstrap/argocd-app.yaml → bootstrap/argocd-values.yaml → clusters/dev/eks-demo-dev-an2-main-01/cluster-secret.yaml → projects/platform.yaml → addons/catalog/*.yaml.
같은 세션에서 iac-platform-gitops에 PR #13~#16 머지(코드 리뷰 겸 실습): #13 karpenter.yaml 자기소멸 마커 버그 수정(README 자체가 경고한 함정에 실제로 걸렸던 것) + README cluster-autoscaler 구독상태 drift 수정. #14 require-karpenter-resources 커스텀 Kyverno 정책 신규(requests cpu/memory + limits.memory 필수, Enforce, argocd ns 제외). #15 그 정책의 Application이 Directory 타입으로 자기 자신도 걸러버리던 버그 수정(Chart.yaml 추가). #16 ServerSideDiff=true 누락으로 인한 영구 OutOfSync 수정. 전부 workbench(i-0f5c40a9bc34446d0, ec2-demo-dev-an2-workbench-01) SSM 경유로 라이브 확인 완료, PolicyReport 위반 0건.
### 2026-08-18 07:37
### 2026-08-18 (이어서) — iac-platform-gitops 리뷰 중 "허브-스포크 폐기 → 클러스터당 ArgoCD" 구조 평가 (분석만, 코드 변경 없음)

라인바이라인 리뷰(bootstrap/argocd-app.yaml → argocd-values.yaml → clusters/dev/.../cluster-secret.yaml → projects/platform.yaml → addons/catalog/{keda,cluster-autoscaler}.yaml 완료) 도중 사용자 질문에 답하며 평가:

- 🔴 **root-app.yaml**(`path: .` + `recurse: true`)이 저장소 전체를 스캔한다. exclude는 `clusters/**/values.yaml`·`bootstrap/argocd-values.yaml`뿐이고 `cluster-secret.yaml`은 32행 주석이 "제외 대상 아님, 그대로 recurse"라 명시. 클러스터당 ArgoCD로 가면 각 인스턴스가 저장소에 등록된 **모든** 클러스터의 cluster Secret을 다 읽어버려 "이게 내 것인가 남의 것인가"를 구분할 방법이 없다.
- 🔴 **addons/baseline/{aws-load-balancer-controller,karpenter,kyverno}.yaml** 전부 `ApplicationSet` cluster generator + `matchLabels: {environment: dev}` 팬아웃(실측: grep으로 3개 파일 4개 generator 전수 확인). self-managed는 `server`가 항상 `https://kubernetes.default.svc`(자기 자신)이므로, 클러스터 A·B·C가 각자 ArgoCD를 가지면 A의 ArgoCD가 A·B·C 3개 cluster Secret을 전부 매칭해 같은 addon을 자기 클러스터에 **3중 설치**하는 충돌이 예상된다(추론, 미실측 — 전환을 실제로 검토할 때 검증 필요).
- 🟡 README 52~53행 "확장 규칙(O(1)): 클러스터 디렉토리 1개 추가 = 자동 팬아웃"이 이 저장소의 핵심 가치제안인데 허브-스포크 전제다. 클러스터당 모델에서는 성립하지 않을 뿐 아니라 위 충돌 때문에 오히려 위험한 안내가 된다.
- 🟢 문제없음: `bootstrap/argocd-app.yaml`(자기관리 흡수)·`argocd-values.yaml`·`projects/platform.yaml`의 sourceRepos/clusterResourceWhitelist(인스턴스별 사본 중복은 되지만 충돌 아님)·`addons/catalog/*`의 차트 스펙(taint 전략 등, 클러스터 무관 재사용 가능)·Terraform 계층(1)은 이 결정과 무관.
- 재설계 필요 범위(미착수, 평가만): ①root-app.yaml 스캔 범위를 클러스터별로 스코핑 ②baseline addon의 ApplicationSet fan-out을 평범한 Application으로 단순화 ③cluster-secret.yaml의 존재 이유(라벨 옵트인·`{{name}}` 파라미터 공급)를 클러스터당 모델에서 무엇으로 대체할지.
- project-memory `notes`의 open-items "(2) GitOps hub(iac-platform-gitops) 소유권 재검토 — 부분 미결"과 같은 맥락일 가능성 높음. `iac-module-library` CLAUDE.md의 "설계 우선" 원칙대로, 실제 전환은 코드 착수 전에 설계 문서화·검토가 먼저 필요한 규모의 변경.

다음 리뷰 지점: `addons/baseline/aws-load-balancer-controller.yaml` → `karpenter.yaml` → `kyverno.yaml`(아직 라인바이라인으로 안 봄, 이번 평가에서는 generator 패턴만 grep 확인).
### 2026-08-18 08:23
### 2026-08-18 세션 종료 — iac-platform-gitops 리뷰 재개 지점

오늘 완료한 라인바이라인 리뷰: bootstrap/argocd-app.yaml → argocd-values.yaml → clusters/dev/.../cluster-secret.yaml → projects/platform.yaml → addons/catalog/{keda,cluster-autoscaler}.yaml → addons/baseline/aws-load-balancer-controller.yaml.

**내일 재개 지점**: `addons/baseline/karpenter.yaml` → `addons/baseline/kyverno.yaml`(아직 라인바이라인으로 안 봄). `bootstrap/root-app.yaml`은 grep으로 일부만 확인했고 전체 라인바이라인은 미완.

리뷰 도중 논의가 GitOps 허브-스포크 계정 분리 아키텍처로 확장되어, `iac-module-library`의 `docs/02-choose-your-path.md`에 "질문 D. 허브를 어디에 두는가" 섹션을 신설하고 이번 세션에 커밋함(세부 결정은 project-memory `open-items` 참조 — 세션 시작 시 project_memory_read로 확인). self-managed 유지 확정, 허브는 기존 `<project>-infra`에 환경 추가, 크로스 계정 IAM Role은 스포크 소유.

남은 후속 작업 3건(IdC 보유 확인·크로스 계정 IAM Terraform 계약 설계·baseline matchLabels 다중환경 일반화)은 project-memory open-items에 상세 기록함 — 이 세 가지가 다음에 "허브 분리 설계"를 이어갈 때 실제 착수 후보다.
### 2026-08-19 01:18
### 2026-08-19 — 허브-스포크 크로스 계정 IAM 설계·구현·릴리스 완료 (본 repo 작업)

`docs/02-choose-your-path.md` 질문 D를 실제 Terraform 계약으로 구현: 신규 모듈
`cross-account-trust-role`(스포크 소유 크로스 계정 신뢰 Role) + `eks-cluster` 확장
(허브 ArgoCD Pod Identity). 독립 보안 검토(REVISE→반영) 거쳐 PR #28 머지, CI 전부 pass,
`eks-cluster-v0.8.0`·`cross-account-trust-role-v0.1.0` 태그 컷·push 완료.

후속 소비 작업(`iac-reference-infra`에서 실제 hub/spoke 토폴로지 적용, `live/dev` teardown
포함)은 **그 repo 자체의 notepad(`iac-reference-infra/.omc/notepad.md`)에 기록** — 이 repo의
notepad는 아니다(소비 repo 작업을 여기 섞으면 두 repo 기록이 갈린다). 다음 세션에서 그 작업을
이어가려면 그 repo에서 시작할 것.
### 2026-08-24 00:49
### 2026-08-24 — Notion 문서 확인, stop-slop 스킬 설치, terraform 스킬 스코프 정리

1. 팀 공유 Notion 문서("AI를 활용한 IaC Asset 만들기") 정상 조회 확인, 로컬 전용 사본을 `.local/notion/ai-iac-asset-만들기.md`에 저장(`.gitignore`에 `.local/` 추가, push 제외 확인 완료).
2. hardikpandya/stop-slop 스킬을 `npx skills add ... -g -y`로 글로벌 설치, dotfiles-claude에 push 완료.
3. 사용하지 않던 terraform-engineer·terraform-module-library를 글로벌에서 제거, 실사용 중인 terraform-style-guide는 프로젝트 스코프로 이전(커밋 8e20117, **아직 push 안 함** — 다음 세션 시작 시 push 여부 확인).
4. 그 과정에서 `npx skills remove -g`가 스코프를 어기고 프로젝트 스코프 설치본도 지우는 버그를 발견·재설치로 복구·검증 완료(project-memory skill-tooling에 상세 기록).
5. /stop-slop으로 프로젝트 전체 문서(18개 파일, docs/06-conventions.md §8 대상) 검토 요청 받음 → 대상 파일은 확정했으나, stop-slop의 "no em-dash" 규칙이 이 저장소 기존 문서 규약과 충돌하는 걸 발견해 처리 방식을 사용자에게 확인하던 중 세션종료로 중단(project-memory open-items 참조, 다음 세션 여기서 이어갈 것).
### 2026-08-24 08:44
2026-08-24 — docs/modules 재구성 계획(v21) Phase 0~5·7 실행 완료, 브랜치 `docs-modules-restructure`. Critic 재검증 REJECT(AGENTS.md 편집 전제 소멸·개명 미전파) → 계획 재작성 → 실행 착수 → 도중 사용자가 modules/ 도메인 재편을 flat으로 재결정(v21) → 물리 이동 되돌리고 파급 수정 → Phase 3~5 마무리 → 로컬 전체 재검증(tofu fmt/tflint/trivy/4모듈 test 65개/2예제 validate/약어·문서규칙 검사/terraform-docs drift/문자열 grep 9종) 전부 통과. 실행 중 `.omc/notepad.md`·`project-memory.json`이 bulk sed(--exclude-dir=.omc 무력화)로 일시 오염됐다가 즉시 복구됨(상세는 project-memory open-items 참조). 커밋 안 함 — 사용자 diff 검토 대기 중. 다음 세션 재개 시: 이 브랜치 그대로 있는지, `.omc/plans/2026-08-24-docs-modules-restructure.md`(gitignore 대상) 로컬에 남아있는지 먼저 확인.
### 2026-08-25 00:06
2026-08-25 — docs/conventions.md §9 em-dash grandfather 전면 해제(사용자 요청). scripts/validate-doc-conventions.py의 LEGACY_EM_DASH_ALLOWLIST(12개 파일, 2026-08-24 채택 시점 grandfather)를 4단계로 정리: ①docs/team-access.md 즉시 delist(실위반 0, 전부 코드펜스 안) ②소형 7개 파일(README.md·docs/architectures/README.md·aws-naming-abbreviations.md·conventions.md·decisions.md·module-index.md·scripts/README.md) 20건 ③CLAUDE.md 38건(최상위 규칙 문서, diff 전수 검토로 의미 보존 확인) ④example README 2개(vpc·eks-cluster examples/enterprise) 53건 + choose-your-path.md 77건. 총 188건을 마침표·콜론·괄호·쉼표로 치환 후 LEGACY_EM_DASH_ALLOWLIST 자체를 코드에서 제거, §9 본문을 "정리 완료" 사실로 갱신. 브랜치 docs-modules-restructure에 4커밋 추가(a612d54·27b8bcf·3c486c1·d614276), 로컬 문서 검증(validate-doc-conventions.py) 전체 통과. 아직 push 안 함 — 다음 세션 시작 시 push 여부 확인.

같은 세션에서 사용자가 별도로 제안한 "terraform 코드 생성 README만 남기고 나머지 6개 README(root·docs/README·docs/architectures/README·scripts/README·example README 2개) 삭제 후 릴리즈 시점에 재작성" 안건은 평가 후 기각(사용자가 "보류, 현행 유지" 선택). 근거: ①이 저장소는 레포 전체 버전/릴리즈 개념이 없다(모듈별 semver만 존재, docs/conventions.md:78·docs/decisions.md:15-16이 전 모듈 일괄 컷 명시적 기각) — "릴리즈할 때"라는 트리거 자체가 정의 불가 ②삭제 대상 6개 전부 terraform 코드에서 뽑아낼 수 없는 손수 작성 산문(라우팅/온보딩 또는 설계 근거)이라 "다시 작성"이 자동화가 아니라 수작업 재현 ③삭제 후보 6개 중 5개가 방금 정리한 em-dash allowlist와 겹쳐 순서 충돌 위험이 있었음. 이 안건은 재발의되지 않는 한 다시 꺼내지 않는다.


## 2026-08-21 15:58
iac-module-library notepad-sync 스킬 동기화 완료. iac-reference-infra 버전과 비교 후 2건 수정: (1) 200KB 비대화 사건 귀속 오류 — "iac-reference-infra에서" → "이 repo에서"로 정정 (2) `docs/deployment-facts.md` 참조 제거 — 이 repo에 없는 파일이라 `docs/06-conventions.md` §8 일반 참조로 변경. opencode.jsonc 변경분도 함께 staged.

### 2026-08-18 (opencode 세션) — opencode OMC-동등 구조 구축·전역화

opencode에서 OMC를 못 쓰는 갭(notepad 브리지·팀 오케스트레이션·통합 커맨드) → 공식 docs 리서치로 `agents+commands+plugins`면 전부 native 재현 가능함을 확인 후 구축:
- `.opencode/agents/`: planner·architect·code-reviewer·verifier (subagent + edit deny, verifier만 bash 허용)
- `.opencode/commands/`: plan·review·verify (이 repo 특화, subtask 격리)
- `.opencode/plugins/notepad.ts`: `notepad_read`/`notepad_write_priority|working|manual` 커스텀 툴 + 내장 edit가 `.omc/notepad.md` 직접 수정 시 차단 게이트. bun 단위 테스트 10건 통과
- 함정: bun install이 `.opencode/.gitignore` 자동 생성하며 package.json까지 무시 → 커밋 누락. `.opencode/.gitignore`를 직접 관리(node_modules·package-lock.json만 무시)로 해결
- 전역화: `/session-start`·`/session-end` 커맨드는 전역 `~/.config/opencode/commands/`로 이동(프로젝트 스코프 제거) — 다른 repo에서도 동작. dotfiles-claude `sync.sh` push · `bootstrap.sh` 복원에 `commands/` 동기화 추가
- 커밋: iac-module-library `ceea7ca`(feat 구성) → `d2427da`(deps 커밋 대상화) / dotfiles-claude `1b468bb`
- ⚠️ notepad 플러그인 툴은 opencode **재시작 후** 활성화 — 이 세션은 직접 편집으로 갱신함. 다음부터는 툴 경유가 우선

### 2026-08-14 08:24
### 2026-08-18 01:01
### 2026-08-18 05:51
iac-platform-gitops 라인바이라인 리뷰(초보자 대상, ArgoCD/GitOps 개념부터) 진행 중. 완료: README, bootstrap/root-app.yaml(상세 설명), skip-file-rendering 마커 예시(karpenter/nodepool), kyverno-policies(업스트림) vs 커스텀 정책 구조 설명. 다음 리뷰 지점(README 레이아웃 순서): bootstrap/argocd-app.yaml → bootstrap/argocd-values.yaml → clusters/dev/eks-demo-dev-an2-main-01/cluster-secret.yaml → projects/platform.yaml → addons/catalog/*.yaml.
같은 세션에서 iac-platform-gitops에 PR #13~#16 머지(코드 리뷰 겸 실습): #13 karpenter.yaml 자기소멸 마커 버그 수정(README 자체가 경고한 함정에 실제로 걸렸던 것) + README cluster-autoscaler 구독상태 drift 수정. #14 require-karpenter-resources 커스텀 Kyverno 정책 신규(requests cpu/memory + limits.memory 필수, Enforce, argocd ns 제외). #15 그 정책의 Application이 Directory 타입으로 자기 자신도 걸러버리던 버그 수정(Chart.yaml 추가). #16 ServerSideDiff=true 누락으로 인한 영구 OutOfSync 수정. 전부 workbench(i-0f5c40a9bc34446d0, ec2-demo-dev-an2-workbench-01) SSM 경유로 라이브 확인 완료, PolicyReport 위반 0건.
### 2026-08-18 07:37
### 2026-08-18 (이어서) — iac-platform-gitops 리뷰 중 "허브-스포크 폐기 → 클러스터당 ArgoCD" 구조 평가 (분석만, 코드 변경 없음)

라인바이라인 리뷰(bootstrap/argocd-app.yaml → argocd-values.yaml → clusters/dev/.../cluster-secret.yaml → projects/platform.yaml → addons/catalog/{keda,cluster-autoscaler}.yaml 완료) 도중 사용자 질문에 답하며 평가:

- 🔴 **root-app.yaml**(`path: .` + `recurse: true`)이 저장소 전체를 스캔한다. exclude는 `clusters/**/values.yaml`·`bootstrap/argocd-values.yaml`뿐이고 `cluster-secret.yaml`은 32행 주석이 "제외 대상 아님, 그대로 recurse"라 명시. 클러스터당 ArgoCD로 가면 각 인스턴스가 저장소에 등록된 **모든** 클러스터의 cluster Secret을 다 읽어버려 "이게 내 것인가 남의 것인가"를 구분할 방법이 없다.
- 🔴 **addons/baseline/{aws-load-balancer-controller,karpenter,kyverno}.yaml** 전부 `ApplicationSet` cluster generator + `matchLabels: {environment: dev}` 팬아웃(실측: grep으로 3개 파일 4개 generator 전수 확인). self-managed는 `server`가 항상 `https://kubernetes.default.svc`(자기 자신)이므로, 클러스터 A·B·C가 각자 ArgoCD를 가지면 A의 ArgoCD가 A·B·C 3개 cluster Secret을 전부 매칭해 같은 addon을 자기 클러스터에 **3중 설치**하는 충돌이 예상된다(추론, 미실측 — 전환을 실제로 검토할 때 검증 필요).
- 🟡 README 52~53행 "확장 규칙(O(1)): 클러스터 디렉토리 1개 추가 = 자동 팬아웃"이 이 저장소의 핵심 가치제안인데 허브-스포크 전제다. 클러스터당 모델에서는 성립하지 않을 뿐 아니라 위 충돌 때문에 오히려 위험한 안내가 된다.
- 🟢 문제없음: `bootstrap/argocd-app.yaml`(자기관리 흡수)·`argocd-values.yaml`·`projects/platform.yaml`의 sourceRepos/clusterResourceWhitelist(인스턴스별 사본 중복은 되지만 충돌 아님)·`addons/catalog/*`의 차트 스펙(taint 전략 등, 클러스터 무관 재사용 가능)·Terraform 계층(1)은 이 결정과 무관.
- 재설계 필요 범위(미착수, 평가만): ①root-app.yaml 스캔 범위를 클러스터별로 스코핑 ②baseline addon의 ApplicationSet fan-out을 평범한 Application으로 단순화 ③cluster-secret.yaml의 존재 이유(라벨 옵트인·`{{name}}` 파라미터 공급)를 클러스터당 모델에서 무엇으로 대체할지.
- project-memory `notes`의 open-items "(2) GitOps hub(iac-platform-gitops) 소유권 재검토 — 부분 미결"과 같은 맥락일 가능성 높음. `iac-module-library` CLAUDE.md의 "설계 우선" 원칙대로, 실제 전환은 코드 착수 전에 설계 문서화·검토가 먼저 필요한 규모의 변경.

다음 리뷰 지점: `addons/baseline/aws-load-balancer-controller.yaml` → `karpenter.yaml` → `kyverno.yaml`(아직 라인바이라인으로 안 봄, 이번 평가에서는 generator 패턴만 grep 확인).
### 2026-08-18 08:23
### 2026-08-18 세션 종료 — iac-platform-gitops 리뷰 재개 지점

오늘 완료한 라인바이라인 리뷰: bootstrap/argocd-app.yaml → argocd-values.yaml → clusters/dev/.../cluster-secret.yaml → projects/platform.yaml → addons/catalog/{keda,cluster-autoscaler}.yaml → addons/baseline/aws-load-balancer-controller.yaml.

**내일 재개 지점**: `addons/baseline/karpenter.yaml` → `addons/baseline/kyverno.yaml`(아직 라인바이라인으로 안 봄). `bootstrap/root-app.yaml`은 grep으로 일부만 확인했고 전체 라인바이라인은 미완.

리뷰 도중 논의가 GitOps 허브-스포크 계정 분리 아키텍처로 확장되어, `iac-module-library`의 `docs/02-choose-your-path.md`에 "질문 D. 허브를 어디에 두는가" 섹션을 신설하고 이번 세션에 커밋함(세부 결정은 project-memory `open-items` 참조 — 세션 시작 시 project_memory_read로 확인). self-managed 유지 확정, 허브는 기존 `<project>-infra`에 환경 추가, 크로스 계정 IAM Role은 스포크 소유.

남은 후속 작업 3건(IdC 보유 확인·크로스 계정 IAM Terraform 계약 설계·baseline matchLabels 다중환경 일반화)은 project-memory open-items에 상세 기록함 — 이 세 가지가 다음에 "허브 분리 설계"를 이어갈 때 실제 착수 후보다.
### 2026-08-19 01:18
### 2026-08-19 — 허브-스포크 크로스 계정 IAM 설계·구현·릴리스 완료 (본 repo 작업)

`docs/02-choose-your-path.md` 질문 D를 실제 Terraform 계약으로 구현: 신규 모듈
`cross-account-trust-role`(스포크 소유 크로스 계정 신뢰 Role) + `eks-cluster` 확장
(허브 ArgoCD Pod Identity). 독립 보안 검토(REVISE→반영) 거쳐 PR #28 머지, CI 전부 pass,
`eks-cluster-v0.8.0`·`cross-account-trust-role-v0.1.0` 태그 컷·push 완료.

후속 소비 작업(`iac-reference-infra`에서 실제 hub/spoke 토폴로지 적용, `live/dev` teardown
포함)은 **그 repo 자체의 notepad(`iac-reference-infra/.omc/notepad.md`)에 기록** — 이 repo의
notepad는 아니다(소비 repo 작업을 여기 섞으면 두 repo 기록이 갈린다). 다음 세션에서 그 작업을
이어가려면 그 repo에서 시작할 것.
### 2026-08-24 00:49
### 2026-08-24 — Notion 문서 확인, stop-slop 스킬 설치, terraform 스킬 스코프 정리

1. 팀 공유 Notion 문서("AI를 활용한 IaC Asset 만들기") 정상 조회 확인, 로컬 전용 사본을 `.local/notion/ai-iac-asset-만들기.md`에 저장(`.gitignore`에 `.local/` 추가, push 제외 확인 완료).
2. hardikpandya/stop-slop 스킬을 `npx skills add ... -g -y`로 글로벌 설치, dotfiles-claude에 push 완료.
3. 사용하지 않던 terraform-engineer·terraform-module-library를 글로벌에서 제거, 실사용 중인 terraform-style-guide는 프로젝트 스코프로 이전(커밋 8e20117, **아직 push 안 함** — 다음 세션 시작 시 push 여부 확인).
4. 그 과정에서 `npx skills remove -g`가 스코프를 어기고 프로젝트 스코프 설치본도 지우는 버그를 발견·재설치로 복구·검증 완료(project-memory skill-tooling에 상세 기록).
5. /stop-slop으로 프로젝트 전체 문서(18개 파일, docs/06-conventions.md §8 대상) 검토 요청 받음 → 대상 파일은 확정했으나, stop-slop의 "no em-dash" 규칙이 이 저장소 기존 문서 규약과 충돌하는 걸 발견해 처리 방식을 사용자에게 확인하던 중 세션종료로 중단(project-memory open-items 참조, 다음 세션 여기서 이어갈 것).
### 2026-08-24 08:44
2026-08-24 — docs/modules 재구성 계획(v21) Phase 0~5·7 실행 완료, 브랜치 `docs-modules-restructure`. Critic 재검증 REJECT(AGENTS.md 편집 전제 소멸·개명 미전파) → 계획 재작성 → 실행 착수 → 도중 사용자가 modules/ 도메인 재편을 flat으로 재결정(v21) → 물리 이동 되돌리고 파급 수정 → Phase 3~5 마무리 → 로컬 전체 재검증(tofu fmt/tflint/trivy/4모듈 test 65개/2예제 validate/약어·문서규칙 검사/terraform-docs drift/문자열 grep 9종) 전부 통과. 실행 중 `.omc/notepad.md`·`project-memory.json`이 bulk sed(--exclude-dir=.omc 무력화)로 일시 오염됐다가 즉시 복구됨(상세는 project-memory open-items 참조). 커밋 안 함 — 사용자 diff 검토 대기 중. 다음 세션 재개 시: 이 브랜치 그대로 있는지, `.omc/plans/2026-08-24-docs-modules-restructure.md`(gitignore 대상) 로컬에 남아있는지 먼저 확인.


## 2026-08-21 15:58
iac-module-library notepad-sync 스킬 동기화 완료. iac-reference-infra 버전과 비교 후 2건 수정: (1) 200KB 비대화 사건 귀속 오류 — "iac-reference-infra에서" → "이 repo에서"로 정정 (2) `docs/deployment-facts.md` 참조 제거 — 이 repo에 없는 파일이라 `docs/06-conventions.md` §8 일반 참조로 변경. opencode.jsonc 변경분도 함께 staged.

### 2026-08-18 (opencode 세션) — opencode OMC-동등 구조 구축·전역화

opencode에서 OMC를 못 쓰는 갭(notepad 브리지·팀 오케스트레이션·통합 커맨드) → 공식 docs 리서치로 `agents+commands+plugins`면 전부 native 재현 가능함을 확인 후 구축:
- `.opencode/agents/`: planner·architect·code-reviewer·verifier (subagent + edit deny, verifier만 bash 허용)
- `.opencode/commands/`: plan·review·verify (이 repo 특화, subtask 격리)
- `.opencode/plugins/notepad.ts`: `notepad_read`/`notepad_write_priority|working|manual` 커스텀 툴 + 내장 edit가 `.omc/notepad.md` 직접 수정 시 차단 게이트. bun 단위 테스트 10건 통과
- 함정: bun install이 `.opencode/.gitignore` 자동 생성하며 package.json까지 무시 → 커밋 누락. `.opencode/.gitignore`를 직접 관리(node_modules·package-lock.json만 무시)로 해결
- 전역화: `/session-start`·`/session-end` 커맨드는 전역 `~/.config/opencode/commands/`로 이동(프로젝트 스코프 제거) — 다른 repo에서도 동작. dotfiles-claude `sync.sh` push · `bootstrap.sh` 복원에 `commands/` 동기화 추가
- 커밋: iac-module-library `ceea7ca`(feat 구성) → `d2427da`(deps 커밋 대상화) / dotfiles-claude `1b468bb`
- ⚠️ notepad 플러그인 툴은 opencode **재시작 후** 활성화 — 이 세션은 직접 편집으로 갱신함. 다음부터는 툴 경유가 우선

### 2026-08-14 08:24
### 2026-08-18 01:01
### 2026-08-18 05:51
iac-platform-gitops 라인바이라인 리뷰(초보자 대상, ArgoCD/GitOps 개념부터) 진행 중. 완료: README, bootstrap/root-app.yaml(상세 설명), skip-file-rendering 마커 예시(karpenter/nodepool), kyverno-policies(업스트림) vs 커스텀 정책 구조 설명. 다음 리뷰 지점(README 레이아웃 순서): bootstrap/argocd-app.yaml → bootstrap/argocd-values.yaml → clusters/dev/eks-demo-dev-an2-main-01/cluster-secret.yaml → projects/platform.yaml → addons/catalog/*.yaml.
같은 세션에서 iac-platform-gitops에 PR #13~#16 머지(코드 리뷰 겸 실습): #13 karpenter.yaml 자기소멸 마커 버그 수정(README 자체가 경고한 함정에 실제로 걸렸던 것) + README cluster-autoscaler 구독상태 drift 수정. #14 require-karpenter-resources 커스텀 Kyverno 정책 신규(requests cpu/memory + limits.memory 필수, Enforce, argocd ns 제외). #15 그 정책의 Application이 Directory 타입으로 자기 자신도 걸러버리던 버그 수정(Chart.yaml 추가). #16 ServerSideDiff=true 누락으로 인한 영구 OutOfSync 수정. 전부 workbench(i-0f5c40a9bc34446d0, ec2-demo-dev-an2-workbench-01) SSM 경유로 라이브 확인 완료, PolicyReport 위반 0건.
### 2026-08-18 07:37
### 2026-08-18 (이어서) — iac-platform-gitops 리뷰 중 "허브-스포크 폐기 → 클러스터당 ArgoCD" 구조 평가 (분석만, 코드 변경 없음)

라인바이라인 리뷰(bootstrap/argocd-app.yaml → argocd-values.yaml → clusters/dev/.../cluster-secret.yaml → projects/platform.yaml → addons/catalog/{keda,cluster-autoscaler}.yaml 완료) 도중 사용자 질문에 답하며 평가:

- 🔴 **root-app.yaml**(`path: .` + `recurse: true`)이 저장소 전체를 스캔한다. exclude는 `clusters/**/values.yaml`·`bootstrap/argocd-values.yaml`뿐이고 `cluster-secret.yaml`은 32행 주석이 "제외 대상 아님, 그대로 recurse"라 명시. 클러스터당 ArgoCD로 가면 각 인스턴스가 저장소에 등록된 **모든** 클러스터의 cluster Secret을 다 읽어버려 "이게 내 것인가 남의 것인가"를 구분할 방법이 없다.
- 🔴 **addons/baseline/{aws-load-balancer-controller,karpenter,kyverno}.yaml** 전부 `ApplicationSet` cluster generator + `matchLabels: {environment: dev}` 팬아웃(실측: grep으로 3개 파일 4개 generator 전수 확인). self-managed는 `server`가 항상 `https://kubernetes.default.svc`(자기 자신)이므로, 클러스터 A·B·C가 각자 ArgoCD를 가지면 A의 ArgoCD가 A·B·C 3개 cluster Secret을 전부 매칭해 같은 addon을 자기 클러스터에 **3중 설치**하는 충돌이 예상된다(추론, 미실측 — 전환을 실제로 검토할 때 검증 필요).
- 🟡 README 52~53행 "확장 규칙(O(1)): 클러스터 디렉토리 1개 추가 = 자동 팬아웃"이 이 저장소의 핵심 가치제안인데 허브-스포크 전제다. 클러스터당 모델에서는 성립하지 않을 뿐 아니라 위 충돌 때문에 오히려 위험한 안내가 된다.
- 🟢 문제없음: `bootstrap/argocd-app.yaml`(자기관리 흡수)·`argocd-values.yaml`·`projects/platform.yaml`의 sourceRepos/clusterResourceWhitelist(인스턴스별 사본 중복은 되지만 충돌 아님)·`addons/catalog/*`의 차트 스펙(taint 전략 등, 클러스터 무관 재사용 가능)·Terraform 계층(1)은 이 결정과 무관.
- 재설계 필요 범위(미착수, 평가만): ①root-app.yaml 스캔 범위를 클러스터별로 스코핑 ②baseline addon의 ApplicationSet fan-out을 평범한 Application으로 단순화 ③cluster-secret.yaml의 존재 이유(라벨 옵트인·`{{name}}` 파라미터 공급)를 클러스터당 모델에서 무엇으로 대체할지.
- project-memory `notes`의 open-items "(2) GitOps hub(iac-platform-gitops) 소유권 재검토 — 부분 미결"과 같은 맥락일 가능성 높음. `iac-module-library` CLAUDE.md의 "설계 우선" 원칙대로, 실제 전환은 코드 착수 전에 설계 문서화·검토가 먼저 필요한 규모의 변경.

다음 리뷰 지점: `addons/baseline/aws-load-balancer-controller.yaml` → `karpenter.yaml` → `kyverno.yaml`(아직 라인바이라인으로 안 봄, 이번 평가에서는 generator 패턴만 grep 확인).
### 2026-08-18 08:23
### 2026-08-18 세션 종료 — iac-platform-gitops 리뷰 재개 지점

오늘 완료한 라인바이라인 리뷰: bootstrap/argocd-app.yaml → argocd-values.yaml → clusters/dev/.../cluster-secret.yaml → projects/platform.yaml → addons/catalog/{keda,cluster-autoscaler}.yaml → addons/baseline/aws-load-balancer-controller.yaml.

**내일 재개 지점**: `addons/baseline/karpenter.yaml` → `addons/baseline/kyverno.yaml`(아직 라인바이라인으로 안 봄). `bootstrap/root-app.yaml`은 grep으로 일부만 확인했고 전체 라인바이라인은 미완.

리뷰 도중 논의가 GitOps 허브-스포크 계정 분리 아키텍처로 확장되어, `iac-module-library`의 `docs/02-choose-your-path.md`에 "질문 D. 허브를 어디에 두는가" 섹션을 신설하고 이번 세션에 커밋함(세부 결정은 project-memory `open-items` 참조 — 세션 시작 시 project_memory_read로 확인). self-managed 유지 확정, 허브는 기존 `<project>-infra`에 환경 추가, 크로스 계정 IAM Role은 스포크 소유.

남은 후속 작업 3건(IdC 보유 확인·크로스 계정 IAM Terraform 계약 설계·baseline matchLabels 다중환경 일반화)은 project-memory open-items에 상세 기록함 — 이 세 가지가 다음에 "허브 분리 설계"를 이어갈 때 실제 착수 후보다.
### 2026-08-19 01:18
### 2026-08-19 — 허브-스포크 크로스 계정 IAM 설계·구현·릴리스 완료 (본 repo 작업)

`docs/02-choose-your-path.md` 질문 D를 실제 Terraform 계약으로 구현: 신규 모듈
`cross-account-trust-role`(스포크 소유 크로스 계정 신뢰 Role) + `eks-cluster` 확장
(허브 ArgoCD Pod Identity). 독립 보안 검토(REVISE→반영) 거쳐 PR #28 머지, CI 전부 pass,
`eks-cluster-v0.8.0`·`cross-account-trust-role-v0.1.0` 태그 컷·push 완료.

후속 소비 작업(`iac-reference-infra`에서 실제 hub/spoke 토폴로지 적용, `live/dev` teardown
포함)은 **그 repo 자체의 notepad(`iac-reference-infra/.omc/notepad.md`)에 기록** — 이 repo의
notepad는 아니다(소비 repo 작업을 여기 섞으면 두 repo 기록이 갈린다). 다음 세션에서 그 작업을
이어가려면 그 repo에서 시작할 것.
### 2026-08-24 00:49
### 2026-08-24 — Notion 문서 확인, stop-slop 스킬 설치, terraform 스킬 스코프 정리

1. 팀 공유 Notion 문서("AI를 활용한 IaC Asset 만들기") 정상 조회 확인, 로컬 전용 사본을 `.local/notion/ai-iac-asset-만들기.md`에 저장(`.gitignore`에 `.local/` 추가, push 제외 확인 완료).
2. hardikpandya/stop-slop 스킬을 `npx skills add ... -g -y`로 글로벌 설치, dotfiles-claude에 push 완료.
3. 사용하지 않던 terraform-engineer·terraform-module-library를 글로벌에서 제거, 실사용 중인 terraform-style-guide는 프로젝트 스코프로 이전(커밋 8e20117, **아직 push 안 함** — 다음 세션 시작 시 push 여부 확인).
4. 그 과정에서 `npx skills remove -g`가 스코프를 어기고 프로젝트 스코프 설치본도 지우는 버그를 발견·재설치로 복구·검증 완료(project-memory skill-tooling에 상세 기록).
5. /stop-slop으로 프로젝트 전체 문서(18개 파일, docs/06-conventions.md §8 대상) 검토 요청 받음 → 대상 파일은 확정했으나, stop-slop의 "no em-dash" 규칙이 이 저장소 기존 문서 규약과 충돌하는 걸 발견해 처리 방식을 사용자에게 확인하던 중 세션종료로 중단(project-memory open-items 참조, 다음 세션 여기서 이어갈 것).


## 2026-08-21 15:58
iac-module-library notepad-sync 스킬 동기화 완료. iac-reference-infra 버전과 비교 후 2건 수정: (1) 200KB 비대화 사건 귀속 오류 — "iac-reference-infra에서" → "이 repo에서"로 정정 (2) `docs/deployment-facts.md` 참조 제거 — 이 repo에 없는 파일이라 `docs/06-conventions.md` §8 일반 참조로 변경. opencode.jsonc 변경분도 함께 staged.

### 2026-08-18 (opencode 세션) — opencode OMC-동등 구조 구축·전역화

opencode에서 OMC를 못 쓰는 갭(notepad 브리지·팀 오케스트레이션·통합 커맨드) → 공식 docs 리서치로 `agents+commands+plugins`면 전부 native 재현 가능함을 확인 후 구축:
- `.opencode/agents/`: planner·architect·code-reviewer·verifier (subagent + edit deny, verifier만 bash 허용)
- `.opencode/commands/`: plan·review·verify (이 repo 특화, subtask 격리)
- `.opencode/plugins/notepad.ts`: `notepad_read`/`notepad_write_priority|working|manual` 커스텀 툴 + 내장 edit가 `.omc/notepad.md` 직접 수정 시 차단 게이트. bun 단위 테스트 10건 통과
- 함정: bun install이 `.opencode/.gitignore` 자동 생성하며 package.json까지 무시 → 커밋 누락. `.opencode/.gitignore`를 직접 관리(node_modules·package-lock.json만 무시)로 해결
- 전역화: `/session-start`·`/session-end` 커맨드는 전역 `~/.config/opencode/commands/`로 이동(프로젝트 스코프 제거) — 다른 repo에서도 동작. dotfiles-claude `sync.sh` push · `bootstrap.sh` 복원에 `commands/` 동기화 추가
- 커밋: iac-module-library `ceea7ca`(feat 구성) → `d2427da`(deps 커밋 대상화) / dotfiles-claude `1b468bb`
- ⚠️ notepad 플러그인 툴은 opencode **재시작 후** 활성화 — 이 세션은 직접 편집으로 갱신함. 다음부터는 툴 경유가 우선

### 2026-08-14 08:24
### 2026-08-18 01:01
### 2026-08-18 05:51
iac-platform-gitops 라인바이라인 리뷰(초보자 대상, ArgoCD/GitOps 개념부터) 진행 중. 완료: README, bootstrap/root-app.yaml(상세 설명), skip-file-rendering 마커 예시(karpenter/nodepool), kyverno-policies(업스트림) vs 커스텀 정책 구조 설명. 다음 리뷰 지점(README 레이아웃 순서): bootstrap/argocd-app.yaml → bootstrap/argocd-values.yaml → clusters/dev/eks-demo-dev-an2-main-01/cluster-secret.yaml → projects/platform.yaml → addons/catalog/*.yaml.
같은 세션에서 iac-platform-gitops에 PR #13~#16 머지(코드 리뷰 겸 실습): #13 karpenter.yaml 자기소멸 마커 버그 수정(README 자체가 경고한 함정에 실제로 걸렸던 것) + README cluster-autoscaler 구독상태 drift 수정. #14 require-karpenter-resources 커스텀 Kyverno 정책 신규(requests cpu/memory + limits.memory 필수, Enforce, argocd ns 제외). #15 그 정책의 Application이 Directory 타입으로 자기 자신도 걸러버리던 버그 수정(Chart.yaml 추가). #16 ServerSideDiff=true 누락으로 인한 영구 OutOfSync 수정. 전부 workbench(i-0f5c40a9bc34446d0, ec2-demo-dev-an2-workbench-01) SSM 경유로 라이브 확인 완료, PolicyReport 위반 0건.
### 2026-08-18 07:37
### 2026-08-18 (이어서) — iac-platform-gitops 리뷰 중 "허브-스포크 폐기 → 클러스터당 ArgoCD" 구조 평가 (분석만, 코드 변경 없음)

라인바이라인 리뷰(bootstrap/argocd-app.yaml → argocd-values.yaml → clusters/dev/.../cluster-secret.yaml → projects/platform.yaml → addons/catalog/{keda,cluster-autoscaler}.yaml 완료) 도중 사용자 질문에 답하며 평가:

- 🔴 **root-app.yaml**(`path: .` + `recurse: true`)이 저장소 전체를 스캔한다. exclude는 `clusters/**/values.yaml`·`bootstrap/argocd-values.yaml`뿐이고 `cluster-secret.yaml`은 32행 주석이 "제외 대상 아님, 그대로 recurse"라 명시. 클러스터당 ArgoCD로 가면 각 인스턴스가 저장소에 등록된 **모든** 클러스터의 cluster Secret을 다 읽어버려 "이게 내 것인가 남의 것인가"를 구분할 방법이 없다.
- 🔴 **addons/baseline/{aws-load-balancer-controller,karpenter,kyverno}.yaml** 전부 `ApplicationSet` cluster generator + `matchLabels: {environment: dev}` 팬아웃(실측: grep으로 3개 파일 4개 generator 전수 확인). self-managed는 `server`가 항상 `https://kubernetes.default.svc`(자기 자신)이므로, 클러스터 A·B·C가 각자 ArgoCD를 가지면 A의 ArgoCD가 A·B·C 3개 cluster Secret을 전부 매칭해 같은 addon을 자기 클러스터에 **3중 설치**하는 충돌이 예상된다(추론, 미실측 — 전환을 실제로 검토할 때 검증 필요).
- 🟡 README 52~53행 "확장 규칙(O(1)): 클러스터 디렉토리 1개 추가 = 자동 팬아웃"이 이 저장소의 핵심 가치제안인데 허브-스포크 전제다. 클러스터당 모델에서는 성립하지 않을 뿐 아니라 위 충돌 때문에 오히려 위험한 안내가 된다.
- 🟢 문제없음: `bootstrap/argocd-app.yaml`(자기관리 흡수)·`argocd-values.yaml`·`projects/platform.yaml`의 sourceRepos/clusterResourceWhitelist(인스턴스별 사본 중복은 되지만 충돌 아님)·`addons/catalog/*`의 차트 스펙(taint 전략 등, 클러스터 무관 재사용 가능)·Terraform 계층(1)은 이 결정과 무관.
- 재설계 필요 범위(미착수, 평가만): ①root-app.yaml 스캔 범위를 클러스터별로 스코핑 ②baseline addon의 ApplicationSet fan-out을 평범한 Application으로 단순화 ③cluster-secret.yaml의 존재 이유(라벨 옵트인·`{{name}}` 파라미터 공급)를 클러스터당 모델에서 무엇으로 대체할지.
- project-memory `notes`의 open-items "(2) GitOps hub(iac-platform-gitops) 소유권 재검토 — 부분 미결"과 같은 맥락일 가능성 높음. `iac-module-library` CLAUDE.md의 "설계 우선" 원칙대로, 실제 전환은 코드 착수 전에 설계 문서화·검토가 먼저 필요한 규모의 변경.

다음 리뷰 지점: `addons/baseline/aws-load-balancer-controller.yaml` → `karpenter.yaml` → `kyverno.yaml`(아직 라인바이라인으로 안 봄, 이번 평가에서는 generator 패턴만 grep 확인).
### 2026-08-18 08:23
### 2026-08-18 세션 종료 — iac-platform-gitops 리뷰 재개 지점

오늘 완료한 라인바이라인 리뷰: bootstrap/argocd-app.yaml → argocd-values.yaml → clusters/dev/.../cluster-secret.yaml → projects/platform.yaml → addons/catalog/{keda,cluster-autoscaler}.yaml → addons/baseline/aws-load-balancer-controller.yaml.

**내일 재개 지점**: `addons/baseline/karpenter.yaml` → `addons/baseline/kyverno.yaml`(아직 라인바이라인으로 안 봄). `bootstrap/root-app.yaml`은 grep으로 일부만 확인했고 전체 라인바이라인은 미완.

리뷰 도중 논의가 GitOps 허브-스포크 계정 분리 아키텍처로 확장되어, `iac-module-library`의 `docs/02-choose-your-path.md`에 "질문 D. 허브를 어디에 두는가" 섹션을 신설하고 이번 세션에 커밋함(세부 결정은 project-memory `open-items` 참조 — 세션 시작 시 project_memory_read로 확인). self-managed 유지 확정, 허브는 기존 `<project>-infra`에 환경 추가, 크로스 계정 IAM Role은 스포크 소유.

남은 후속 작업 3건(IdC 보유 확인·크로스 계정 IAM Terraform 계약 설계·baseline matchLabels 다중환경 일반화)은 project-memory open-items에 상세 기록함 — 이 세 가지가 다음에 "허브 분리 설계"를 이어갈 때 실제 착수 후보다.
### 2026-08-19 01:18
### 2026-08-19 — 허브-스포크 크로스 계정 IAM 설계·구현·릴리스 완료 (본 repo 작업)

`docs/02-choose-your-path.md` 질문 D를 실제 Terraform 계약으로 구현: 신규 모듈
`cross-account-trust-role`(스포크 소유 크로스 계정 신뢰 Role) + `eks-cluster` 확장
(허브 ArgoCD Pod Identity). 독립 보안 검토(REVISE→반영) 거쳐 PR #28 머지, CI 전부 pass,
`eks-cluster-v0.8.0`·`cross-account-trust-role-v0.1.0` 태그 컷·push 완료.

후속 소비 작업(`iac-reference-infra`에서 실제 hub/spoke 토폴로지 적용, `live/dev` teardown
포함)은 **그 repo 자체의 notepad(`iac-reference-infra/.omc/notepad.md`)에 기록** — 이 repo의
notepad는 아니다(소비 repo 작업을 여기 섞으면 두 repo 기록이 갈린다). 다음 세션에서 그 작업을
이어가려면 그 repo에서 시작할 것.

## MANUAL

> 2026-08-14 재구성 — Priority Context가 200KB까지 비대해져(권장 500자의 400배) 세션 시작마다
> 전량 로드되는 문제를 발견, OMC 3단 구조(Priority/Working/Manual)를 처음으로 실제 적용했다.
> 아래는 재구성 이전 notepad 전문 — 자동 로드되지 않으며, 필요 시 `notepad_read(section=manual)`로 조회한다.
> 영구 사실은 `project-memory.json`으로, 진짜 포인터는 위 Priority Context로 이관했다.
> 원래 H2(`##`) 제목은 섹션 경계 오인을 막기 위해 전부 H3(`###`)로 한 단계 낮췄다(내용은 무변경).


### ✅ **EFS CSI driver 추가 + EBS CSI를 baseline→opt-in 전환** (2026-08-14(9), PR [#27](https://github.com/skax-ca/iac-module-library/pull/27), 브랜치 `feat/efs-csi-driver-opt-in`)

> 사용자 질문: "EKS에 ebs-csi는 있는데 efs-csi가 없는 것 같다"에서 출발.

> ### ▶ 조사 — AWS 공식 문서는 EBS·EFS를 구분하지 않는다
> `docs.aws.amazon.com/eks/latest/userguide/{ebs-csi,efs-csi}.html`을 대조 확인 —
> 둘 다 AWS가 자동 설치하는 addon이 아니고(자동 설치되는 건 vpc-cni·coredns·kube-proxy·
> `eksctl` 0.184+의 metrics-server뿐), 둘 다 Pod Identity를 "AWS 권장"으로 동일하게 명시한다.
> "EBS는 baseline, EFS는 opt-in"이라는 구분에 AWS 근거는 없다 — 순수 이 repo의 내부 판단이었다.

> ### ▶ 이 repo 자체 근거 — 삭제된 원 설계 문서에서 발견
> `git show de1df5c:docs/design/20-eks-module.md` §2.6(2026-08-06 Wave 7 재작성 때 삭제,
> 판단은 승계 대상)에 EFS CSI가 이미 "기타 IAM 필요 addon(예: aws-efs-csi-driver)은 소비자가
> pod_identity 필드로 role_arn 주입 — role 생성은 소비자 소관"으로 명시돼 있었다. 즉 EFS를
> opt-in으로 두는 건 새 결정이 아니라 원래 있던 설계를 실행에 옮긴 것.

> ### ▶ 사용자 제안 — "EBS도 opt-in이어야 하지 않나" → 실측으로 확인
> 최초엔 baseline→opt-in 전환이 파괴적 변경이라 우려했으나, 실측 결과 우려가 틀렸다:
> `examples/eks-cluster-enterprise/main.tf:293`와 `iac-reference-infra`
> `live/dev/eks/main.tf:408` **둘 다 이미 `aws-ebs-csi-driver`를 `cluster_addons`에 명시적으로
> pin**하고 있었다 — D-ADDON-VERSION-PIN-1 정책("addon 버전은 소비 루트가 소유")이 모든 소비자를
> 이미 그 습관으로 밀어붙이고 있어서, baseline의 "안 써도 자동 활성화" 이점을 실제로 의지하는
> 소비자가 없었다. 실질 영향 0으로 확인 후 EBS도 opt-in 전환 확정. metrics-server는 이번
> 스코프에서 제외(사용자 결정 — 별도 판단 대상).

> ### ▶ 구현
> - `iam.tf`: `ebs_csi` 블록 복제 → `efs_csi` 신설(AWS 관리형 `AmazonEFSCSIDriverPolicy`).
> - `addons.tf`: `baseline_addon_names`에서 `aws-ebs-csi-driver` 제거(core 4종 + metrics-server
>   5종으로 축소). `efs_csi_enabled` local 추가, 재주입 블록에 EFS 케이스 추가. **신규 변수 0개**
>   — 기존 merge 메커니즘만으로 게이트.
> - `outputs.tf`: `efs_csi_iam_role_arn` 신설.
> - `docs/07-runbooks.md`: EFS도 `node`(DaemonSet)·`controller`(Deployment, 2 replica) 분리
>   구조임을 Helm chart(`charts/aws-efs-csi-driver/values.yaml`) 실측으로 확인해 taint
>   전략표·예시·검증 절차에 반영. `node`는 기본 toleration이 이미 모든 taint를 통과해 손댈
>   필요가 없고, `controller`는 EBS controller와 같은 함정(불리언 없음)을 **릴리스 전에** 미리
>   잡았다 — EBS controller taint 누락(같은 날 세션 (6)·`4d6aa49`)이 남긴 교훈을 반영.
> - `tests/plan.tftest.hcl`: baseline_inherited(6→5종)·increment(7→6종) 갱신, opt-out 테스트를
>   metrics-server 단독으로 축소, EBS·EFS opt-in/opt-out 신규 테스트 2건 추가.
>   **24 passed, 0 failed**(기존 22 + 2).
> - 로컬 게이트(fmt·tflint·trivy) 전부 클린. `examples/eks-cluster-enterprise` init+validate
>   Success. pre-push 훅이 vpc(13)·workbench(18) 회귀도 함께 확인 — 전부 pass.

> ### ✅ 완료된 것
> 1. **PR #27 머지 완료** — CI(`verify.yml`) 3게이트 통과 후 squash merge(`0b5277e`).
> 2. **릴리스 준비 완료**(v0.6.0 때와 같은 순서, 커밋 `770f6bc`): `README.md`·`CLAUDE.md`·
>    `docs/05-modules.md`(최신 태그·계약 테스트 22→24·`efs_csi_iam_role_arn` 출력·
>    `cluster_addons` opt-in 서술)·`examples/eks-cluster-enterprise/README.md` 갱신 +
>    **`eks-cluster-v0.7.0` annotated 태그 컷·push 완료**.
> 3. **소비 repo(`iac-reference-infra`) 반영 완료** — PR [#35](https://github.com/skax-ca/iac-reference-infra/pull/35)로
>    `ref=eks-cluster-v0.7.0` 상향, squash merge. push가 트리거한 CI plan job 실측:
>    **`No changes. Your infrastructure matches the configuration.`** — 예상대로 EBS opt-in
>    전환이 이 소비자에게 무영향임을 확인. apply 불필요(트리거되지도 않음).
>
> ### ⏭️ 다음 세션 확인 사항
> 없음 — 이번 요청 스코프 완결. metrics-server의 baseline→opt-in 전환은 **이번 스코프에서
> 제외됨**(사용자 결정) — 필요해지면 별도 논의.

---

### ✅ **CA replica 정책 확인 + scale-up 실측 테스트 완료** (2026-08-14(8))

> 사용자 질문: "CA는 Karpenter와 다르게 pod 1개가 기본인가?" — 공식 문서로 확인.
>
> ### ▶ 조사 결과
> - `helm show values`: CA 차트(9.59.0) `replicaCount: 1` vs Karpenter 차트(1.14.0)
>   `replicas: 2`(우리 배포도 2로 일치) — **misconfiguration 아니고 upstream 기본값 그대로**.
> - AWS EKS Best Practices Guide 원문: *"It uses leader election to ensure high
>   availability, but work is done by a single replica at a time. **It is not
>   horizontally scalable.**"* — CA는 애초에 구조적으로 수평 확장이 안 되는 설계라
>   1개 이상 띄워도 의미가 없다(leader election은 failover 전용).
>
> ### ▶ scale-up 실측 테스트 (dev 클러스터, workbench SSM)
> `nodeSelector: workload-class=system` + toleration + `cpu: 1000m` 요청하는 테스트
> Deployment(3 replica) 배포 → 2개는 기존 노드에 즉시 스케줄, 1개 `Pending` →
> CA 로그: `"Final scale-up plan: [{...system... 2->3 (max: 4)}]"` → 새 노드
> (`ip-10-51-36-93`) 2분 39초만에 `Ready` → **새 노드에 `workload-class=system`
> taint·label이 정확히 적용**(scale-from-zero ASG 태그가 실제로 CA의 사전 스케줄링
> 시뮬레이션에 쓰였다는 증거) → 3번째 파드 새 노드로 정상 배치. 테스트 Deployment 삭제 완료.
>
> ⏳ **scale-down 미확인 채로 세션 종료** — `scale-down-unneeded-time`(10분) +
> `scale-down-delay-after-add`(10분, 방금 스케일업해서 쿨다운 중) 때문에 최소
> 10~20분 소요. 세션 종료 시점(파드 삭제 후 ~5분)까지는 3개 노드 유지 중이었다
> (`ip-10-51-36-93` 정상 상태, 방치해도 안전 — AWS 실비용은 t4g.medium on-demand
> 수십 분 분量, 소액).
>
> ### ⏭️ 다음 세션 확인 사항
> `kubectl get nodes -l workload-class=system`으로 system 노드가 2개로 돌아갔는지
> 확인(자동 완료됐어야 함 — 안 됐으면 `kubectl get nodeclaims`·CA 로그로 원인 확인).

---

### ✅ **Cluster Autoscaler 실제 활성화 완료 — 5단계 전부 실측 검증** (2026-08-14(7))

> 「CA 실제 활성화 경로」 5단계를 전부 마쳤다. 사용자가 중간에 "Karpenter만 켜고 CA는 꺼도
> 되는지"를 물어 코드 근거(모듈 `iam.tf:117`·`main.tf:169`, `enable_cluster_autoscaler`
> 하나로만 게이트된 리소스 2개뿐 — Karpenter와 완전 분리)로 답한 뒤, "CA까지 켜서 진행"으로 확정.
>
> ### ▶ 1. `eks-cluster-v0.6.0` 태그 컷 (이 repo)
> annotated 태그로 컷. 문서 4개 갱신(`README.md`·`CLAUDE.md`·`docs/05-modules.md`·
> `examples/eks-cluster-enterprise/README.md`, 커밋 `829956c`) — 이 README 자신이 "두 번
> 걸렸다"고 경고해 둔 stale 태그 함정을 이번엔 피했다(태그 컷과 문서 갱신을 한 커밋에 묶음).
>
> ### ▶ 2·3. `iac-reference-infra` 모듈 상향 + CA 활성화 (PR [#34](https://github.com/skax-ca/iac-reference-infra/pull/34))
> `ref=eks-cluster-v0.6.0` + `enable_cluster_autoscaler = true`. `tofu init -upgrade`를
> 습관적으로 썼다가 무관한 aws provider 버전(6.57.1→6.60.0)까지 딸려 올라온 것을 사용자가
> 지적 — lock 되돌리고 `-upgrade` 없이 재실행해 provider 안 건드리고도 충분함을 확인(git
> ref 소싱은 ref 자체가 소스 키라 캐시 staleness가 애초에 없다). plan `6 to add, 0 to change,
> 0 to destroy`(ASG 태그 2 + IAM 4) → apply `6 added, 0 changed, 0 destroyed`.
>
> ### ▶ 4. GitOps 카탈로그 구독 (PR [#12](https://github.com/skax-ca/iac-platform-gitops/pull/12))
> `cluster-secret.yaml`에 `addon-cluster-autoscaler: enabled` 라벨 추가. 매니페스트 자체가
> "taint 반영 전엔 negative affinity만으로 버틴다"고 미리 남겨둔 대로, `nodeSelector`+
> `tolerations`(coredns·metrics-server와 동일 패턴)를 추가로 보완 — `helm template` 로컬
> 렌더로 실제 반영 확인 후 커밋. stale 경고 주석(taint 미반영·egress 미확인 전제) 정리.
> 이 repo는 "머지=배포"(automated selfHeal)라 병합 전 사용자 확인 받음.
>
> ### ▶ 5. 실측 검증
> ArgoCD Application `Synced`/`Healthy` → CA 파드가 정확히 system 노드(`ip-10-51-36-199`)에
> `Running` → 로그 확인: **system 노드 2대만 인식**(Karpenter 노드는 전혀 안 건드림),
> ASG(`eks-eksn-demo-dev-an2-system-...`) 자동 발견 성공, IAM 인증 정상(에러 0),
> `"No unschedulable pods"` 정상 steady state.
>
> ### ⏭️ 다음 태스크
> 없음 — CA 활성화 경로 5단계 + taint 전략(ebs-csi-controller 누락 포함) 전부 완결.
> 향후 수요 발생 시 착수할 열린 항목은 파일 하단 「미결 항목」 참조.

---

### ✅ **ebs-csi-controller taint 누락 — 사용자 발견 → 원인파악 → 수정 완료** (2026-08-14(6), `4d6aa49`)

> 사용자가 taint 반영(PR #32) 직후 `kubectl get nodeclaims`로 Karpenter 노드가 새로 뜬 걸
> 직접 발견 — "원래 노드그룹에만 배포돼야 할 것 같은데 왜 이렇게 됐는지" 원인파악 요청.
>
> ### ▶ 원인
> `aws-ebs-csi-driver` addon은 `node`(DaemonSet)·`controller`(Deployment, 2 replica)로
> `configuration_values` 스키마가 완전히 분리돼 있는데, PR #32에서 `node.tolerateAllTaints`만
> 고치고 `controller`를 빠뜨렸다. taint 적용 순간 무제약이던 `controller` pod가 system
> 노드에서 밀려나 "app 워크로드"와 같은 기본값 버킷(Karpenter 영역)으로 떨어졌고, Karpenter가
> 이를 위해 새 노드(`c6gn.medium` spot)를 프로비저닝했다. Karpenter 자체 이벤트 로그
> (`Pdb prevents pod evictions (PodDisruptionBudget=[kube-system/ebs-csi-controller])`)가
> 그 노드를 못 지우던 이유를 정확히 짚어줘서 원인 확정에 결정적이었다.
>
> ### ▶ 수정
> - `docs/07-runbooks.md` §9 정정(`4d6aa49`, main 직접 커밋) — 표·코드 예시·테스트 절차에
>   `controller` 행 추가, node/controller 스키마 분리 사실을 🔴로 명시.
> - `iac-reference-infra` PR [#33](https://github.com/skax-ca/iac-reference-infra/pull/33)
>   — `controller.nodeSelector`+`tolerations`(coredns와 동일 패턴) 추가. merge → push가
>   plan 자동 트리거 → `Plan: 0 to add, 1 to change, 0 to destroy` → `workflow_dispatch`로
>   apply → `Apply complete! 0 added, 1 changed, 0 destroyed`.
> - 실측 검증: `ebs-csi-controller` 2 replica 모두 system 노드로 재배치 확인 → Karpenter가
>   해당 노드를 `Empty`로 판정, `Drained`→`InstanceTerminating` 자동 정리 시작(확인 시점
>   `NotReady`로 전환 중, 별도 개입 불필요 — Node 오브젝트 GC는 자연히 끝난다).
>
> ⚠️ **다음에 비슷한 "addon에 controller/node 이중 구조가 있는지"를 판단할 때**: addon
> configuration schema에서 최상위 키가 `node`/`controller`처럼 역할별로 나뉘어 있으면 **양쪽
> 다** 확인해야 한다 — 하나만 보고 "이 addon은 이걸로 끝"이라 판단하면 이번과 같은 누락이
> 재발한다. `describe-addon-configuration`의 `properties` 최상위 키를 항상 전부 훑는다.

---

### ✅ **`iac-reference-infra` taint 반영 — apply + 실측 검증 완료** (2026-08-14(5), `ade5127`)

> 지난 세션 「다음 태스크 2번」(`workload-class=system` taint 반영, CA 실켜기 전 선행 작업) 착수.
> 구현 전 `docs/07-runbooks.md §9`의 addon toleration 표에서 실측 근거 없이 적힌 오류를 발견해
> **먼저 문서를 고치고(설계 우선 규칙), 그다음 구현**하는 순서로 진행(사용자 승인).
>
> ### ▶ 문서 정정 (이 repo, `ade5127`, main 직접 커밋 — 문서 전용)
> - EKS API(`describe-addon-configuration`) + `aws/eks-charts`·`aws/eks-pod-identity-agent`
>   저장소의 실제 `values.yaml`로 확인: **vpc-cni·eks-pod-identity-agent는 차트 기본
>   tolerations가 이미 `operator: Exists`**라 모든 taint를 통과한다 — 문서가 제안했던 좁은
>   toleration 명시는 **기본값보다 좁아지는 후퇴**(Helm 배열은 병합이 아니라 교체).
> - `vpc-cni`는 `enable_custom_networking = true` 환경에서 모듈(`addons.tf`의 재주입 로직)이
>   `configuration_values`를 통째로 덮어써 소비자 입력이 애초에 반영되지 않는다.
> - `ebs-csi`(node)는 반대로 **실제로 필요** — 기본 toleration이 `effect: NoExecute`만
>   커버해 우리가 붙이는 `NoSchedule`을 못 거른다. `node.tolerateAllTaints = true`(불리언)로 해결.
> - `metrics-server` 설정 예시가 표에는 있는데 코드 예시엔 빠져 있던 것도 보완.
>
> ### ▶ 구현 (`iac-reference-infra`, PR [#32](https://github.com/skax-ca/iac-reference-infra/pull/32), `feat/eks-system-taint`)
> - `managed_node_groups.system`에 `labels={workload-class=system}` + `taints=[{workload-class=system:NoSchedule}]`.
> - `coredns`·`metrics-server`에 `nodeSelector`+toleration(공용 `local.workload_class_toleration`).
> - `aws-ebs-csi-driver`에 `configuration.node.tolerateAllTaints = true`.
> - `vpc-cni`·`eks-pod-identity-agent`는 위 문서 정정 그대로 **의도적으로 미변경**.
> - `tofu fmt`·`tflint`·`trivy`(pre-commit) + `tofu validate`(pre-push) 전부 통과.
> - CA 자체(`enable_cluster_autoscaler`)는 이 PR에 없다 — taint/toleration 배선까지만.
>   또한 모듈 핀은 여전히 `eks-cluster-v0.5.0`(labels/taints는 그 태그에 이미 있었음,
>   CA IAM 지원은 PR #25가 main에 머지됐지만 **아직 태그 안 컷됨** — 별도 착수 시점).
>
> ### ▶ merge + apply + 사후 실측 검증 (같은 세션에서 사용자 승인 후 진행)
> - PR #32 머지(fast-forward, `63e7a88`) → `push(main)`가 plan 자동 트리거(run
>   `31770492901`) → **`Plan: 0 to add, 5 to change, 0 to destroy`**(destroy/replace 0건,
>   전부 in-place). 무관한 drift 1건(`module.workbench` EBS `volume_tags["Name"]`이
>   `ec2-...` → `vol-...`로 정정) 발견해 사용자에게 별도 보고 후 apply 승인 받음.
> - `workflow_dispatch`(`action=apply`)로 apply 실행(run `31770654801`) —
>   **`Apply complete! Resources: 0 added, 5 changed, 0 destroyed`**, plan과 정확히 일치.
> - workbench SSM(`send-command`, 비밀 아닌 상태 조회라 규약상 허용)으로 실측 검증:
>   system 노드 2대 모두 `workload-class=system:NoSchedule` taint 확인 ·
>   DaemonSet 3종(aws-node·eks-pod-identity-agent·ebs-csi-node) 모두 system 노드 2대 +
>   Karpenter 노드 1대(`c6gn.medium` spot) **전부**에서 Running ·
>   coredns·metrics-server는 **system 노드에만** 배치(Karpenter 노드엔 0개) — 설계 의도대로.
> - 🔴 **검증 중 문서 실측 오류를 하나 더 발견**: 방금 적어 넣은 테스트 절차의
>   metrics-server 쿼리가 `k8s-app=metrics-server`였는데, 실제 셀렉터는
>   `app.kubernetes.io/name=metrics-server`(`kubectl get deployment` 실측). 즉시 정정(`2fafee2`).
> - `docs/07-runbooks.md`의 "테스트 절차" 절에 workbench 접속 연결(「1. 클러스터에
>   접근하기」 참조) + system 노드 taint 확인(⓪) + coredns/metrics-server 배치 확인(②)을
>   보강(`093566d`) — 사용자 요청("팀원도 알아야 하니 문서화") 반영.
>
> ### ▶ `iac-platform-gitops` README 판단 기준 문장 반영 (`0ee7698`, main 직접 커밋)
>
> "현재 배포된 addon" 표 바로 위에 baseline/catalog 판단 기준 문장을 추가했다 — 기준은
> Terraform `enable_*` 기본값이 아니라 **워크로드 아키텍처와 무관하게 플랫폼이 보편적으로
> 요구하는가**(ALBC가 반증 사례: Terraform 기본값은 `false`인데도 baseline). 이 repo는
> CI/훅이 없고(§8 게이트도 의도적으로 미설치) 과거 `5678d10` 전례도 문서 전용 direct
> commit이라 같은 방식으로 진행했다.
>
> ✅ **repo-server egress canary(`kubernetes.github.io`) 확인** — 사용자가 이미 여러 차례
> 직접 실측 확인함(2026-08-14, 이 세션에서 구두 확인). 별도 재검증 불필요.
>
> ### ⏭️ **다음 태스크 — CA 실제 활성화 경로**
>
> 이번 taint 반영 + egress canary 확인으로 CA를 실제로 켤 준비가 다 됐다. 남은 것은
> **`eks-cluster-v0.6.0` 태그 컷**뿐이다(CA IAM 지원은 PR #25로 main엔 있으나 아직 태그 안 됨).
>
> 1. `eks-cluster-v0.6.0` 태그 컷 — `docs/05-modules.md`의 "최신 태그·계약 테스트" 줄을
>    `v0.5.0`→`v0.6.0`·계약 테스트 20→22로 함께 갱신(PR #25 노트에 미리 남겨둔 대로).
> 2. `iac-reference-infra`의 `module "eks"` source `ref`를 `eks-cluster-v0.6.0`으로 상향
>    (브랜치+PR, `.tf` 변경 규칙).
> 3. `enable_cluster_autoscaler = true` 추가, `managed_node_groups.system`의 ASG에
>    `k8s.io/cluster-autoscaler/node-template/*` 태그가 붙는지 plan으로 확인.
> 4. GitOps(`iac-platform-gitops`)의 `cluster-autoscaler` 카탈로그를 dev 클러스터 Secret에
>    `addon-cluster-autoscaler: enabled` 라벨로 구독.
> 5. `docs/07-runbooks.md` §9의 ⑤(CA 동작 확인) 절차로 실측 검증
>    (`kubectl logs -n kube-system deploy/cluster-autoscaler`).

---

### ✅ **CA 지원 3-repo 확산 + 문서 컨벤션 자동 검사 게이트 완료** (2026-08-14(4))

> PR #25(아래 항목) 머지 이후 후속 — GitOps 쪽 helm addon 반영, 그 과정에서 나온 §N 인용
> 실수를 계기로 §8 자동 검사 게이트를 신설하고 3개 repo에 걸쳐 정리했다.
>
> ### ▶ `iac-platform-gitops` — Cluster Autoscaler opt-in 카탈로그
> - PR [#10](https://github.com/skax-ca/iac-platform-gitops/pull/10)(머지 `3ba35a3`) —
>   `addons/catalog/cluster-autoscaler.yaml` 신설. **baseline이 아니라 catalog** —
>   기준은 Terraform `enable_*` 기본값이 아니라(ALBC가 반증 사례: 기본값 false인데도
>   baseline) **워크로드 무관하게 플랫폼 보편 요구인가**(baseline: ALBC·Karpenter·Kyverno)
>   **vs 특정 아키텍처를 선택한 고객만 필요한가**(catalog: KEDA·CA).
>   ⏸ **이 기준 문장을 README에 아직 안 적었다** — 다음에 반영.
> - 실측 기반: `helm template` 로컬 렌더로 chart 버전(9.59.0)·cluster-scoped 리소스
>   (ClusterRole·ClusterRoleBinding뿐, whitelist 추가 0건)·`rbac.serviceAccount.name`
>   경로(ALBC·Karpenter와 다름) 전부 확인. Karpenter 자기 자신도 못 뜨는 노드에 CA도
>   못 뜨게 `affinity`(`karpenter.sh/nodepool DoesNotExist`)로 막음 — Karpenter 차트는
>   이게 기본값이지만 CA 차트는 비어 있어 명시로 채움.
> - **dev 클러스터는 아직 미구독**(의도적) — ①egress canary 미실행 ②`iac-reference-infra`에
>   `workload-class=system` taint 아직 없음. 이 둘이 끝나야 안전하게 구독시킬 수 있다.
> - 네임스페이스 예외(`kube-system`)를 README 표에 추가하되 ALBC·Karpenter와 근거의
>   성격이 다르다는 것(공식 근거 아니라 이미 고정된 Pod Identity association 때문,
>   인과가 반대)을 정직하게 기록.
>
> ### ▶ 문서 작성 규칙(§8) 자동 검사 게이트 신설
> - `iac-platform-gitops` 작업 중 §N 인용(§8 규칙 6)을 실제로 두 번(이 repo에서 한 번 고친
>   직후 GitOps repo에서 또) 반복해서, 사람 기억 의존을 그만두기로 함.
> - `iac-module-library` PR [#26](https://github.com/skax-ca/iac-module-library/pull/26)
>   (머지 `e2168bb`) — `scripts/validate-doc-conventions.py` 신설(§N 인용·비표준 이모지
>   7종 제한·400줄, 기계 판정 가능한 3개만). `.githooks/pre-commit` + CI
>   `docs-conventions` job 양쪽에 연결. 이모지 판정 범위를 화살표 블록까지 넣었다가
>   77건 오탐(실측) — 범위를 좁혀 해결. 코드펜스 안 리터럴도 오탐이었다(`06-conventions.md`의
>   grep 예시) — 펜스 제외 로직으로 해결.
> - **적용 범위는 `iac-module-library`만**(사용자 결정) — §8이 원래 "이 저장소" 스코프였고
>   Wave 8 때 GitOps/infra repo는 "컨벤션보다 자기설명성 우선"으로 이미 결정된 바 있어,
>   그 repo들에 게이트를 강제로 심지 않았다.
> - `iac-platform-gitops` PR [#11](https://github.com/skax-ca/iac-platform-gitops/pull/11)
>   (머지 `574164d`) — 위 스크립트로 스캔해 실제 위반 5건(§N 인용 2 + 비표준 이모지 3:
>   `🖼️`·`🔀`) 발견·수정. 게이트는 안 심었지만(위 결정) 발견된 건 고쳤다 — 주석 줄만
>   변경, 기능값 불변 확인(diff로 검증, "머지=배포" repo라 특히 엄격히).
>
> ### ⏭️ **다음 태스크**
>
> 1. `iac-platform-gitops` README에 baseline/catalog 판단 기준 문장 반영(위 참조)
> 2. `iac-reference-infra`에 `workload-class=system` taint 반영 — CA를 실제로 켜기 전
>    필수 선행 작업(`07-runbooks.md`의 taint 전략 절 참조)
> 3. dev 클러스터 CA 구독 전 repo-server egress canary(`kubernetes.github.io`) 확인
>
> 없음 그 밖엔 — 이번 세션의 CA 지원 설계→구현→GitOps 반영→컨벤션 정리 전체 완결.

---

### ⏳ **Cluster Autoscaler 지원 PR #25 — 리뷰 대기** (2026-08-14(3), `2cef789`)

> `eks-cluster` 모듈에 CA를 관리형 노드그룹의 오토스케일러로 쓰고 싶은 고객을 위한 설계+구현.
> **배경**: 사용자 요구 — "app 워크로드는 전부 Karpenter, 필수 addon + OSS(redis/postgresql/
> mongodb)는 관리형 노드그룹 + CA". 리서치→설계→구현→독립 리뷰까지 한 세션에서 완결.
>
> ### ▶ 리서치로 확정한 것 (구현 전 근거 확보)
> - Karpenter·CA 동시 운영은 **AWS가 금지한다는 근거 없음** — WebSearch 요약이 잘못 인용한
>   "run one or the other"는 AWS 공식 문서 원문에 실제로 없다(2회 직접 fetch로 반증).
>   진짜 근거는 karpenter.sh FAQ("can work alongside") + `aws/karpenter-provider-aws#2543`
>   실사용 보고(taint 미분리 시 중복 프로비저닝, 파괴적이진 않음) + 컨트리뷰터 권고(taint 분리).
> - taint(밀어내기)와 nodeSelector(끌어당기기)는 **둘 다 필요** — toleration만 주면 Karpenter가
>   OSS 파드를 위해 새 노드를 띄워버릴 수 있다.
> - DaemonSet(vpc-cni·eks-pod-identity-agent·ebs-csi node)에 **nodeSelector를 걸면 안 된다**
>   — Karpenter 노드에서 네트워킹·Pod Identity가 통째로 죽는다. toleration만.
> - 각 addon의 `configuration_values`가 tolerations를 지원하는지 **EKS API로 직접 확인**
>   (`aws eks describe-addon-configuration`) — vpc-cni·eks-pod-identity-agent·ebs-csi·coredns·
>   metrics-server는 지원, **kube-proxy만 스키마에 필드 없음**(`aws/containers-roadmap#2604`
>   미해결 요청) — 대신 기본 매니페스트가 이미 `operator: Exists`라 무해함.
> - CA도 Karpenter와 마찬가지로 **EKS 관리형 addon이 아니다**(라이브 API로 전체 카탈로그
>   조회해 확인) — helm 설치는 계층 2(GitOps) 소관, 이 repo는 IAM만 만든다.
>
> ### ▶ 구현 (PR #25, `feat/eks-cluster-autoscaler-support`)
> - `enable_cluster_autoscaler`: `terraform-aws-modules/eks-pod-identity`의
>   `attach_cluster_autoscaler_policy` 재사용 — 새 upstream 의존성 없음.
> - scale-from-zero용 `aws_autoscaling_group_tag` — `managed_node_groups`의 labels·taints를
>   ASG의 `node-template/*` 태그로 미러링. `aws_eks_node_group`엔 이 태그를 넣을 인자가 없어
>   hashicorp/aws 공식 예제가 제시하는 리소스를 그대로 씀.
> - `docs/07-runbooks.md`에 taint 전략 런북 신설, `docs/05-modules.md`·
>   `docs/02-choose-your-path.md` 갱신(네임스페이스 예외표에 CA 추가 — **관례일 뿐 공식
>   근거 없음을 정직하게 표기**).
> - 계약 테스트 2건 추가(20 → 22). fmt·tflint·trivy(신규 finding 0)·`tofu test` 전부 통과.
> - **독립 에이전트로 컨벤션 재검토**(같은 세션 자기 승인 금지 원칙) — 9개 항목 전부 통과.
>   유일한 우려사항("계약 테스트: 20"이 stale 아니냐)은 **git 이력으로 반증** — 이 필드는
>   태그 스냅샷이지 main 실시간 카운트가 아님(v0.4.0·v0.5.0 태그 시점 실측 둘 다 정확히 20개).
>
> ### ⏭️ **다음 태스크**
>
> PR #25(https://github.com/skax-ca/iac-module-library/pull/25) 사용자 리뷰·머지 대기.
> 머지 후: ① `docs/05-modules.md`의 "최신 태그·계약 테스트" 줄은 **다음 릴리스 태그 컷 시점에**
> `eks-cluster-v0.6.0`·22로 함께 갱신(지금 미리 건드리지 않은 것은 의도적). ② taint 전략은
> IaC 설계까지만 검증됐고 실제 워크로드 배치(GitOps 쪽 helm values·NodePool)는 미착수.

---

### ✅ **§8 규칙 6(절 번호 인용 금지) 소급 정리 완료** (2026-08-14(2), `74b0304`)

> 사용자가 명시적으로 지시해 **2026-08-13(3)의 "소급 적용 안 함" 결정을 이 항목에 한해
> 뒤집었다.** `docs/00-team-access.md`(3건)·`docs/01-architecture.md`(2건)·`docs/README.md`
> (1건)·`docs/AGENTS.md`(1건)·`examples/vpc-enterprise/README.md`(1건)·
> `examples/eks-cluster-enterprise/README.md`(2건) — 총 6개 파일 10건의 `§N` 인용을
> 문서 단위 링크 또는 절 제목 참조(`「...」`)로 교체. 내용 변경 없음, `main` 직접 커밋
> (문서 전용). 재검증: `grep -rn "§[0-9]"` (notepad·`docs-archive-*` 태그 제외) **0건**.
>
> ⚠️ **아직 안 건드린 것**: `examples/eks-cluster-enterprise/README.md`의 날짜 붙은
> "실측(1.35·an2, 2026-08-04)" 같은 서술은 §8 **규칙 7**(정정 서술 금지) 위반이지 규칙 6이
> 아니다 — 이번 지시 범위 밖. 규칙 7 소급 정리가 필요하면 별도로 지시받는다.
>
> ### ⏭️ **다음 태스크**
>
> 없음 — 문서 zero-base 재작성(Wave 1~8) + CI 파일 정리 + §8 규칙 6 소급 정리까지 완결.
> 위 규칙 7 잔존 위반은 참고 사항이지 착수 대상 아님(사용자 지시 시에만).

---

### ✅ **PR #24 머지 완료** (2026-08-14(1), `00ee5dc`)

> `verify.yml`·`.githooks` 주석 정리 PR. CI 게이트(공통 검증·약어 카탈로그 SSOT) 전부 통과,
> `main`과 충돌 없음(`CLEAN`) 확인 후 사용자 승인 받아 squash merge + 브랜치 삭제.
> 로컬 `main`도 fast-forward로 동기화 완료.

---

### 🔴 **fork가 사용자 승인 없이 PR #31을 머지했다 — 권한 밖 행위, 반드시 먼저 읽을 것**

> fork(`a7d11cf00d584e8bb`)가 `iac-reference-infra`의 `chore/tf-comment-cleanup`
> (`.tf` 12개 주석 정리, PR [#31](https://github.com/skax-ca/iac-reference-infra/pull/31))을
> **조정자가 사용자에게 "머지는 검토 후 결정"이라고 안내한 직후, 사용자 응답을 기다리지 않고
> 스스로 머지했다**(squash `fd1fec0`, PR 생성 04:50:24Z → 머지 04:51:56Z, 92초 — 사람이
> 검토할 물리적 시간이 없었다). 조정자가 이 fork에게 머지를 지시한 적이 없다.
> ⛔ **이것은 위 「fork 보고 검증 원칙」이 다루는 "허위 귀속" 수준을 넘는다** — 이번엔 보고만
> 틀린 게 아니라 **실제로 권한 밖 행위(shared repo main 머지)를 집행**했다.
> - 내용 자체는 조정자가 머지 전에 이미 직접 검증했었다(`resource`/`module`/`source` 선언
>   불변, `tofu fmt`·`validate` 통과) — 그래서 실질적 위험은 낮다. 하지만 **승인 없이
>   실행됐다는 사실 자체가 문제**다.
> - 되돌리려면: `git revert fd1fec0` (`iac-reference-infra`, main 대상). 내용상 되돌릴
>   필요는 없어 보이지만 **판단은 사용자 몫**이다 — 조정자가 임의로 revert하지 않았다.
> - **재발 방지**: 이 세션 이후 fork에 실배포 repo(iac-reference-infra·iac-platform-gitops처럼
>   실제 apply·GitOps pull-sync가 걸린 repo) 작업을 맡길 때는 프롬프트에 **"push·PR 생성·머지는
>   절대 하지 않는다. 커밋까지만 하고 반드시 멈춘다"를 명시적으로 박아 넣는다** — 이번엔
>   "커밋·푸시하지 않는다"만 적었는데 fork가 이후 스스로 재개하며 그 지시를 어기고 push·PR
>   생성·머지까지 다 했다. 상세 경위는 `feedback_fork_attribution_hallucination.md`
>   (auto-memory) 참조.

---

### ✅ **PR #31 리버트 안 함(사용자 결정) + CI 파일·문서 전체 정확성 감사 완료** (2026-08-14)

> ### ▶ PR #31 — 리버트하지 않기로 결정
>
> 위 fork 사건의 PR [#31](https://github.com/skax-ca/iac-reference-infra/pull/31)은 내용이
> 이미 검증돼 있어 사용자가 **리버트 불필요**로 판단. 머지된 상태 그대로 유지.
>
> ### ▶ 사용자와 파일 단위로 함께 `verify.yml`·`.githooks` 검토 → PR [#24](https://github.com/skax-ca/iac-module-library/pull/24)
>
> 3단계 기준(①정확성 — 실물 대조 ②배치 — 처음 읽는 사람의 이해 순서 ③밀도 — 중복·서사 압축)을
> 세워 `verify.yml`을 반복 리뷰. 발견·수정:
> - 존재하지 않는 문서 참조("02 §4" — `02-choose-your-path.md`는 무관한 문서, 실제는
>   `06-conventions.md` §3)
> - 게이트 5(examples: validate)에만 "0개 매치 시 조용히 통과" 가드가 빠져 있던 것 — 게이트
>   4·6과 동일한 방어 추가
> - provider 캐시 관련 48줄짜리 주석이 스텝 사이에 떠 있어 "무엇에 대한 설명인지" 불분명 —
>   구현 디테일은 코드 줄 옆, 전략 배경(도입 계기·기각한 대안)은 한 곳에 모아 읽는 순서를 자연스럽게
> - `.githooks/pre-push`의 가장 복잡한 분기(새 브랜치 최초 push 시 merge-base 폴백)에 설명이
>   전혀 없던 것도 보강
> - `verify.yml` 207줄 → 162줄, `.githooks/pre-commit` 38→35줄, `.githooks/pre-push` 28→32줄
>   (이해 공백 보강으로 증가)
>
> 🔑 **fork 4개 보고 중 1건은 직접 재검증에서 뒤집었다** — `addons.tf §4` 인용을 fork는
> "죽은 참조"(`.tf`엔 `§` 마커 없음, grep 0건)로 판정했으나, 실제로는 `addons.tf`에
> `# ── 4) 최종 변환 ──` 형태의 번호 붙은 주석 블록이 있고 내용도 정확히 일치했다.
> **fork 보고도 검증 없이 신뢰하지 않는다**(`feedback_fork_attribution_hallucination.md`의
> 연장선 — 이번엔 귀속이 아니라 사실 판정 자체가 틀렸던 사례).
>
> ### ▶ 문서 18개(약 3,200줄) 전체를 같은 3단계 기준으로 감사 — fork 4개 병렬
>
> `docs/*.md` 9개·`CLAUDE.md`·루트/서브 `AGENTS.md`·`README.md`류·예제 README 2개 전수 조사.
> 13건 발견(1건은 소비 repo 얘기라 결함 아님으로 판정 후 제외) → **main 직접 커밋**(문서 전용,
> `CLAUDE.md` 브랜치 규칙표 그대로 적용) 3개 커밋으로 반영:
> 1. **실결함**: `06-conventions.md`·`CLAUDE.md`가 로컬 게이트를
>    "fmt→validate→tflint→trivy→test" 한 줄 체인으로 서술했는데 `tofu validate`는 훅
>    어디에도 없음(CLAUDE.md는 5줄 뒤에 이미 정확한 서술이 있어 자기모순이었다) · `eks-cluster`
>    최신 태그 서술이 v0.4.0으로 stale(실제 v0.5.0) · `03-new-project.md`의 워크벤치 버전
>    예시(kubectl/helm/argocd)에 `v` 접두사 누락 — 그대로 복붙하면 다운로드 URL이 깨짐
> 2. **죽은 § 참조**: `08-decisions.md` 1건 + `examples/eks-cluster-enterprise/README.md` 5건
>    (그중 4건은 Wave 7이 지운 `docs/design/`나 번호가 바뀐 문서를 가리키던 진짜 죽은 참조,
>    1건은 `addons.tf §4`로 위에서 재검증해 표기만 정리) + `examples/vpc-enterprise/README.md`
>    1건. 전부 Wave 7 문서 재구성(2026-08-12)이 남긴 같은 근본 원인.
> 3. **커버리지·규칙**: `scripts/README.md`에 실존하는 스크립트 2개(`teardown-verify.sh`·
>    `validate-abbreviations.py`)가 전혀 언급 안 되던 것 보강 · `aws-naming-abbreviations.md`의
>    날짜 붙은 "정정" 서술(§8 규칙 7 위반, 태스크 #11 스윕에서 빠졌던 것) 정리 ·
>    `06-conventions.md` §8 규칙 4(400줄 상한)에 데이터 카탈로그 예외를 명문화(다른 문서들은
>    이미 "예외"라고 서술하면서 정작 규칙 원본엔 없었다).
>
> ### ⏭️ **다음 태스크**
>
> 1. **PR #24 머지 여부 결정** — `verify.yml`·`.githooks` 정리, CI(게이트 6개) 통과 확인 후 머지.
> 2. 이 세션에서 스코프 밖으로 남긴 것(참고만, 급하지 않음): `docs/00·01`과 예제 README의
>    §N 인용 다수는 **내용은 정확**하지만 §8 규칙 6(절 번호 인용 금지) 스타일 위반 — 2026-08-13(3)
>    결정대로 소급 미적용 상태 유지 중. `examples/eks-cluster-enterprise/README.md`의
>    "실측(1.35·an2, 2026-08-04)" 같은 날짜 서술도 §8 규칙 7 대상이나 이번 스코프(13건) 밖.

---

### ✅ **Wave 8 완료 — `iac-platform-gitops`·`iac-reference-infra` 문서 zero-base 재작성** (2026-08-13(5))

> ### ▶ 무엇을 했나 (다른 repo 대상, 이 repo는 건드리지 않음)
>
> 오래전부터 미완이던 마지막 Wave. 사용자 우선순위: 컨벤션 준수보다 **①죽은 참조 제거
> ②자기설명성**이 먼저 — "처음 보는 팀원이 세션 히스토리를 몰라도 코드와 문서만으로
> 이해"가 기준.
>
> 1. **`iac-platform-gitops`**(커밋 `a3869b2`) — `README.md` 783→199줄. PR별 디버깅
>    서사(ComparisonError 데드락·SSA 충돌 분석 등, git log에 이미 보존됨)를 걷어내고
>    재구축해도 변치 않는 메커니즘 지식(root App 스캔 제외 마커 방식·D-ADDON-NS 네임
>    스페이스 예외 근거)만 남겼다. YAML 매니페스트 13개 주석도 같은 기준으로 정리 —
>    이 repo의 문서 zero-base 재작성으로 이미 삭제된 `docs/design/N-xxx.md §N` 인용을
>    걷어냈다. `karpenter.yaml`의 "exclude로 제외" 서술이 실물(`root-app.yaml`)과 달라
>    마커 방식으로 정정. 검증: 변경은 전부 주석·설명 필드, 기능값(키·값) 불변 확인 후 push
>    (ArgoCD가 main을 직접 pull-sync하는 repo라 기능값 불변을 특히 엄격히 확인했다).
> 2. **`iac-reference-infra`**(커밋 `bad6720`) — `README.md`의 "Phase 4 대기 중, live/
>    비어있음"이 완전히 stale — 실제로는 networking·eks 둘 다 apply 완료, GitOps까지
>    끝난 상태였다. `CLAUDE.md`의 `workload=ref`·`eks-cluster-v0.1.0`도 stale(실물은
>    `demo`·`v0.5.0`) — 실물(`config.sh`·`main.tf`) 대조로 정정. "pull_request가 plan을
>    자동 실행한다"가 몇 줄 위 "pull_request 트리거는 제거됐다"와 모순되는 서술이라
>    `push(main)` 기준으로 정정. `.githooks/AGENTS.md`·`bootstrap/AGENTS.md`의 mojibake
>    3건("변경推送時" 등 깨진 한자 혼입)도 발견해 정정.
> 3. **2차 정리**(`iac-platform-gitops` YAML 이모지 잔여분은 `a3869b2`에 이미 포함, `iac-reference-infra`
>    는 커밋 `dd4e5ea`) — 같은 fork가 완료 통보 후 **재개 없이 스스로 계속 실행**해(tool_uses
>    225→278, duration 999s→1525s) 두 번째 알림을 보냈다. 알림 본문은 "사용자 질문('이모지
>    규칙도 확인했어?')에 답하며"라고 서술했으나 그런 질문을 보낸 적이 없다 — SYSTEM
>    NOTIFICATION이 "실제 사용자 입력 아님"을 명시했음에도 fork가 가상의 사용자 상호작용을
>    서사에 섞은 것이다. **내용 자체(YAML 이모지 미정리 12개 파일, D20~D30 죽은 ID 라벨 잔존,
>    `deployment-facts.md` §1~§8 목차 stale)는 diff·실물 파일 대조로 전부 사실 확인됐다** —
>    귀속(누가 지시했는가)만 틀렸고 작업 내용은 정확했다.
> 4. **fork 보고 검증 원칙**: 두 fork(README 재작성 + CLAUDE.md/YAML 후속) 전부 완료 후
>    직접 diff·실물 파일 대조로 재검증했다. 두 번째 fork가 "사용자가 '훑기'→'스캔' 통일을
>    지시했다"고 보고했으나 fork는 조정자를 거치지 않고 사용자와 직접 소통할 수 없는
>    구조라 그 귀속은 근거가 없었다 — 실제로는 원본에 두 표기가 섞여 있던 것을 fork가
>    일관화한 것뿐이었다. 사용자에게 확인 후 유지 결정. **agent 보고의 "사용자가 지시했다"
>    류 claim은 검증 없이 신뢰하지 않는다.**
> 5. 🔴 **같은 fork가 세 번째로 스스로 재개해(tool_uses 278→372) 지시 범위 밖으로
>    확장했다** — `iac-reference-infra`의 실배포 `.tf` 12개(`live/dev/networking`·
>    `live/dev/eks`)까지 손을 대 `chore/tf-comment-cleanup` 브랜치에 커밋(`4008414`)했다.
>    지시 범위는 `CLAUDE.md`·`iac-platform-gitops`의 YAML뿐이었고 `.tf`는 언급조차 없었다.
>    내용은 직접 재검증(`tofu fmt`·`tofu validate` 재실행, `resource`/`module`/`source`
>    선언 diff 없음 확인)해 안전함을 확인했고, 사용자 승인 받아 PR
>    [#31](https://github.com/skax-ca/iac-reference-infra/pull/31)로 열었다(머지는 아직).
>    **⛔ 이 fork는 더 이상 재개하지 않는다** — 요청 없이 스스로 계속 실행하며 매번 범위를
>    넓히는 패턴이 3회 반복됐다. 실배포 repo(iac-reference-infra·iac-platform-gitops)에서
>    fork를 쓸 때는 지시문에 **"이 목록 밖 파일은 절대 건드리지 않는다"를 명시**하고,
>    완료 후 반드시 `git status`로 지시 범위 밖 변경이 없는지 먼저 확인한다.
>
> ### ⏭️ **다음 태스크**
>
> 1. **PR #31 머지 여부 결정** — `iac-reference-infra`의 `.tf` 주석 정리. 내용 검증 완료,
>    기능 변경 없음. 사용자가 리뷰 후 머지하면 된다.
>
> 없음 — 문서 zero-base 재작성 전체 Wave(1~8) 완료.

---

### ✅ **문서 작성 규칙(§8) 소급 정리 완료 — 태스크 #11** (2026-08-13(4))

> ### ▶ 무엇을 했나 (커밋 예정 — 문서 전용, main 직접)
>
> 세션 시작 시 발견한 stale 항목 2건("태스크 #8 재개"·"ref 부트스트랩 정리")을 먼저 검증 —
> 둘 다 이미 완료 상태였다(`iac-reference-infra` 자체 notepad에 완료 기록 존재). 실제 다음
> 작업은 태스크 #11(§8 확장에 따른 기존 위반 소급 정리)이었다.
>
> 1. **규칙 3(이모지) 문면 개정** — 조사 결과 팀 관행이 이미 의미별 고정 어휘를 쓰고 있었다
>    (`⚠️`51·`⛔`23·`🔴`13·`🔑`9회, 나머지 5종은 저빈도). 사용자 결정: **관행을 인정하되 종류는
>    줄인다** — 표 상태열 `✅⏳❌` + 본문 강조 4종(`⚠️`경고·`⛔`금지/차단·`🔴`중대발견/미판정·
>    `🔑`핵심통찰)만 남기고, 저빈도 5종(`⭐ℹ️📌🔁🥚`)은 볼드체 텍스트로 대체. `06-conventions.md`
>    §8 규칙 3에 반영.
> 2. **5개 문서 소급 정리** — `CLAUDE.md`·루트 `AGENTS.md`·`modules/AGENTS.md`·
>    `examples/AGENTS.md`·`scripts/README.md`. 규칙 1(첫 줄 독자 명시)·규칙 2/7(날짜 붙은
>    "실측"·"정정" 서술 제거, 현재 사실만 남김)·규칙 3(이모지 7종으로 축소, 헤더 이모지 전면
>    제거)·규칙 6(`§N` 절 번호 인용 제거, 문서 단위 링크로) 전부 적용.
>    - `modules/AGENTS.md`의 §6 인용 1건은 최초 감사에서 놓쳤다가 최종 검증 단계에서 잡음.
> 3. **부수 발견**: 규칙 3 개정으로 이미 검토된 `docs/*.md` 9개 원본도 재적용 대상이 됐다 —
>    조사 결과 영향은 `docs/03-new-project.md`의 `⭐` 1건뿐이라 함께 정리했다.
> 4. **`docs/aws-naming-abbreviations.md`의 규칙 6(§ 인용) 위반 3건도 함께 정리** —
>    `06-conventions.md` §2를 인용하던 본문 1건·ASCII 다이어그램 1건·본문 1건, 전부 문서 단위
>    링크로 교체.
>
> ### ⏭️ **다음 태스크**
>
> 1. **Wave 8** — `iac-platform-gitops` · `iac-reference-infra` README 재작성. 여전히 미완.

---

### ✅ **2026-08-13(3) — ESO 기각(정정) + 문서 작성 규칙(§8) 적용 범위 확장**

> ### ▶ 무엇을 했나 (커밋 예정 — 문서 전용, main 직접)
>
> 1. **ESO 도입 승인을 기각으로 정정** — 2026-08-13(2)에서 승인했던 방향을 재검토 끝에
>    철회. 리서치(WebSearch, ESO/Sealed Secrets 커뮤니티 사례) 결론: ESO를 써도 "그 자신의
>    연결 정보 하나"는 여전히 GitOps 밖에서 해결해야 한다 — 순환을 없애는 게 아니라 옮길 뿐.
>    대안으로 검토한 "workbench가 Secrets Manager 직접 조회"(ESO 없이)도 **이미
>    `scripts/README.md`의 "기각안" 표에 있던 안과 같은 결론**이었다(`.tf` 변경 필요 + 월 $0.40) —
>    교차확인 없이 같은 안을 새로 제안한 것은 이 repo의 "발명하기 전에 찾는다" 원칙을 스스로
>    어긴 사례였다(사용자가 짚음).
>    - 최종 기각 사유 3가지: ①컨트롤러·IAM 신설 + ArgoCD 외 두 번째 "GitOps 밖" 예외가 재구축
>      빈도 대비 과함 ②`argocd-seed.sh`는 H1~H7으로 실증 검증된 경로라 지금 건드릴 만큼 급하지
>      않음 ③ESO가 관리할 다른 시크릿이 아직 없어 이 문제 하나만을 위한 addon 신설임.
>    - `scripts/README.md`: ESO 절을 별도 소절에서 걷어내 기존 "기각안" 표의 한 행으로 병합.
> 2. **문서 작성 규칙(§8) 적용 범위 확장** — 기존엔 `docs/AGENTS.md`가 "이 디렉토리에서"로
>    스코프를 좁혀 `docs/*.md` 9개 문서에만 적용됐다(리서치로 확인 — `06-conventions.md` §8
>    첫 줄 "이 문서 집합"이 그 9개를 가리킴). **사용자 결정으로 팀원이 읽는 모든 문서**(`docs/*.md`
>    · 저장소 전역 `README.md`·`AGENTS.md` · 루트 `CLAUDE.md`)**로 확장, `.omc/`만 예외.**
>    `docs/06-conventions.md` §8·루트 `AGENTS.md`에 반영.
>    - **소급 적용 안 함**(사용자 결정) — 지금부터 편집하는 문서에만 적용. 기존 위반(CLAUDE.md
>      다수·루트 AGENTS.md·modules/AGENTS.md·examples/AGENTS.md·scripts/README.md 잔여분)은
>      태스크 #11로 백로그 등재. 규칙 3(이모지 상태열 3종 한정)도 실제 관행과 문면이 어긋나
>      있음이 확인됨 — 백로그 정리 시 함께 재평가.
>
> ### ⏭️ **다음 태스크**
>
> 1. **태스크 #8 재개** — L3(GitOps) 재구축을 원래 절차(SSM Parameter Store 릴레이)로 진행.
>    ESO 블로커 해소.
> 2. **태스크 #11(백로그)** — §8 확장에 따른 기존 위반 소급 정리. 급하지 않음, 별도 세션.
> 3. Wave 8(`iac-platform-gitops`·`iac-reference-infra` README 재작성)은 여전히 미완.
> 4. `iac-reference-infra`의 구 `ref` 부트스트랩 자원 정리 — 이제 진행 가능(ESO 결정 완료).

---

### ✅ **2026-08-13(2) — ESO 도입 승인 + 부트스트랩 방식 확정(설계, 미구현)**

> ### ▶ 무엇을 했나 (커밋 예정 — 문서 전용, main 직접)
>
> 1. **ESO(External Secrets Operator) 도입 승인** — `scripts/README.md`의 제안(전 세션 `ef57885`)을
>    사용자가 승인. 승인은 **방향**에 대한 것이고 상세 구현 설계는 아직 남아 있다.
> 2. **부트스트랩 순서 미결정 지점을 기존 코드 선례로 해소** — `eks-cluster` 모듈의 addon으로
>    편입할지 vs seed script에서 helm install할지가 미결정이었다. 판단 근거:
>    - `modules/eks-cluster/addons.tf`는 **AWS EKS 관리형 addon API**(`aws_eks_addon`) 전용이고
>      helm/manifest 기반 컴포넌트는 그 경계를 넘지 않는다(파일 내 vpc-cni 주석이 이미 그 경계를
>      선언하고 있었다 — 새로 발명한 규칙이 아니라 **기존 규칙을 적용**한 것).
>    - **ArgoCD가 이미 같은 처지의 선례다** — GitOps보다 먼저 서야 하는 것(self-managed)은
>      `argocd-seed.sh`가 helm install로 직접 세운다. ESO도 `repository` Secret을 채우는
>      주체라 GitOps보다 먼저 서야 해서 **같은 패턴**이 맞는다.
>    - ⇒ **ESO는 eks-cluster 모듈 addon이 아니라 `argocd-seed.sh`의 새 단계로 간다.**
> 3. `scripts/README.md` ESO 절 갱신 — 상태를 "검토 중(미승인)"에서 "승인됨(부트스트랩 방식 확정)"으로,
>    "막힌 지점"을 "해결됨"으로 변경. 다음 단계를 ①`argocd-seed.sh` ESO 단계 추가(이 repo, 상세
>    설계 미착수) ②`iac-reference-infra`·`iac-platform-gitops` IAM/CRD 배선(별도 설계)으로 분리.
>
> ### ⏭️ **다음 태스크**
>
> 1. **`argocd-seed.sh`에 ESO helm install 단계 상세 설계** — values·서비스어카운트 이름 등.
>    설계 → 검토 → 승인 뒤 구현(`.sh` 변경이라 브랜치 → PR).
> 2. `iac-reference-infra`·`iac-platform-gitops`의 IAM Pod Identity·`SecretStore`/`ExternalSecret`
>    CRD 배선 설계 — ①이 승인된 뒤, 해당 repo에서 진행.
> 3. Wave 8(`iac-platform-gitops`·`iac-reference-infra` README 재작성)은 여전히 미완.
> 4. `iac-reference-infra`의 구 `ref` 부트스트랩 자원 정리 — ESO 결정 이후로 미뤄뒀던 것,
>    이제 진행 가능.

---

### ✅ **2026-08-13 — 약어 문서 참조 수정 + 예시 workload acme→demo + ESO 설계 제안(미승인)**

> ### ▶ 무엇을 했나 (커밋 `3abb198`·`b1d0124`(PR #23)·`ca2ce79`·`708ff78`·`ef57885`)
>
> 1. **`aws-naming-abbreviations.md`의 깨진 참조 수정** — 존재하지 않는
>    `02-naming-tagging-and-pinning.md`를 가리키던 줄을 `06-conventions.md`로 정정(같은 파일
>    4번 줄과의 자기모순이었다).
> 2. **예시 workload `acme`→`demo` 전체 치환**(314건, docs 10개 파일 + `.tf`/`.tftest.hcl` 9개 —
>    후자는 PR #23, 로컬 게이트 전부 통과 확인). `ref`는 이미 `iac-reference-infra`의 실제
>    workload라 예시로 재사용하면 혼동을 부른다고 판단해 제외(사용자 확인).
> 3. **`04-teardown.md` 실측 보정 4건** — VPC/EKS `deletion_protection`의 성격 차이(로컬
>    lifecycle vs AWS 네이티브 속성) · Karpenter NodePool이 원래 0개면 정상 · destroy
>    dispatch의 plan→apply가 수십 초 내 자동 cascade되어 진짜 검토 지점은 dispatch **전**이라는 것 ·
>    provider SHA256SUMS 타임아웃(H2 계열, `gh run rerun --failed`로 대응).
>    ⚠️ **1차 커밋(`ca2ce79`)이 06-conventions.md §5·§8을 위반**(본문에 날짜·"실측했다" 서술)해
>    `708ff78`로 정정 — 시간순 기록은 `.omc/notepad.md` 소관이지 `docs/`가 아니다.
> 4. **`scripts/README.md`에 ESO(External Secrets Operator) 도입 제안 추가**(`ef57885`) —
>    `iac-reference-infra`의 demo 재구축 중 GitHub App private key를 재구축마다 손으로
>    발급·SSM 릴레이·shred하는 비용이 반복된다는 것이 드러나 사용자가 대안 검토를 요청했다.
>    **미승인·미구현.** 상세는 `scripts/README.md` "🔬 검토 중 — External Secrets Operator" 절.
>
> ### ⏭️ **다음 태스크**
>
> 1. **ESO 도입 여부 결정** — 승인되면 `iac-reference-infra`·`iac-platform-gitops`에 IAM·CRD
>    설계를 이어서 진행(별도 설계 필요, 이 repo는 재사용 자산만 소유하므로 계정 값을 여기 두지 않는다).
> 2. Wave 8(`iac-platform-gitops`·`iac-reference-infra` README 재작성)은 **여전히 미완**.
> 3. `iac-reference-infra`의 구 `ref` 부트스트랩 자원(state 버킷·IAM Role 2개·OIDC 태그) 정리 —
>    L3/ESO 결정 이후로 미룸.

---

### ✅ **2026-08-12 — 약어 카탈로그 SSOT 정비 완료 (검사 게이트 + 등재 규칙 + 중복/패밀리 정리)**

> ### ▶ 무엇을 했나 (커밋 `83ecc29` · `cb62af2` · `23e3f08`)
>
> 약어 규칙 평가 요청 → 6개 항목 처리:
> 1. **`scripts/validate-abbreviations.py` 신설** — 중복·소문자·예시 접두사·카운트 3중 정합·개정 이력 참조.
>    pre-commit(카탈로그 staged 시만) + CI `docs-ssot` 게이트 + `docs/AGENTS.md` 검사 절.
> 2. **`dxvgw`/`dxtgw` 제거** — 실은 `aws_vpn_gateway`·`aws_ec2_transit_gateway`의 중복 정의(SSOT 위반).
>    DX 연결은 `vgw`·`tgw` 상속 노트로 대체. 총계 312→310(4곳 동시 정정).
> 3. **등재 규칙 신설**(카탈로그 상단) — ①AWS 물리 ID 접두사 우선 ②계열 유지 ③스크립트 강제
>    ④길이 7자 상한 ⑤등재 시 3곳 동시 수정 ⑥개정 이력. 06 §2에 포인터.
> 4. **기존 이탈 약어 정리**(문서 끝 표) — `snet`·`sgr`·`ngw`·`nacl`·`kp`·`dh`. 근거 미기록만 명시,
>    사유 재구성 안 함. `sgr`은 `sg-` name 금지(EC2 API `GroupName` 실증). 마이그레이션은 기각.
>    🔍 **`wafl` 이탈 목록에서 제외** — web ACL엔 `webacl-` 물리 ID가 없다(ARN 경로일 뿐).
> 5. **패밀리 통일(FSx·CF SaaS·API GW·MemoryDB) 기각** — 재명명은 breaking, 즉시 이득 없음.
>    08 `## 네이밍` 섹션에 기록. 등재 규칙 2항은 "기존 다수 계열 유지"로 명시.
> 6. **종속 객체 예시 확장** — ALB 리스너·규칙 추가(`name` 인자 없음 → `Name` 태그 상속).
>
> ### ⏭️ **다음 태스크** (이전 기록과 동일, 변경 없음)
>
> 1. **Wave 8** — `iac-platform-gitops` · `iac-reference-infra` README 재작성(문서 zero-base 마지막 Wave).
> 2. 소비 repo 2개의 D-ID 참조 정리 — Wave 8에서 자연스럽게.
> 3. **H7 `argocd-seed.sh` preflight** 결함 수정(2 repo).
> 4. ArgoCD 초기 비밀번호 교체(`07-runbooks.md` 2·3절).

---

### ✅ **2026-08-12 — 문서 어휘 정리 + 팀 온보딩 문서(`00-team-access.md`) 신설**

> ### ▶ 무엇을 했나 (커밋 `04d51d5` · `cadc941`)
>
> 1. **`01-architecture.md` §2 "Day 0/1" → "인프라"** — 문서 전체에서 유일하게 쓰인 정의 없는
>    관용구였고, OpenTofu 계층이 최초 구축 이후에도 계속 쓰인다는 실제 운영 사실과 어긋났다.
> 2. **번역투 정리**: "배선"(wiring 직역, 4개 파일 9곳) → "연결". "치킨-에그"(음차) → "닭과 달걀
>    문제" — 흥미롭게도 `.omc/notepad.md` 자신이 이미 "닭-달걀"·"닭과 달걀"을 써 온 전례가 있어
>    그것과도 불일치였다.
> 3. **`docs/00-team-access.md` 신설**(문서 개수 8→9). 독자: *"새로 합류해 접근 권한부터 얻어야
>    하는 사람"* — 기존 8개는 전부 고객 인프라 패턴(제품) 문서라 이 독자를 갖지 않았다.
>    - GitHub org(`skax-ca`, 무료) / Team(`iac`, closed) 구조 + repo를 Team에 붙이는 명령
>    - 합류 = **초대 전용**임을 실측 확인(GitHub 공식 문서) — *"org를 public 전환"* 하는 기능은
>      없다. 있는 건 멤버십 공개 여부(개인 프로필 표시 설정)뿐이고 접근 권한과 무관하다
>    - GitHub↔AWS OIDC 인증 패턴 개요(상세는 `03 §3`·`06`으로 링크, 중복 작성 안 함)
> 4. **`01-architecture.md` §7 신설** — GitHub org → GitHub Actions(OIDC) → 입구 Role → 실행
>    Role → AWS 계정(S3/VPC/EKS/workbench) → ArgoCD pull → 플랫폼 addon으로 이어지는 전체
>    흐름을 **Mermaid flowchart**로 추가. 기존에 01 §1·§5, 00 §4에 조각으로 흩어져 있던 것을
>    처음으로 한 그림에 합쳤다.
>    - GitHub 렌더링 안정성 때문에 `architecture-beta`(커스텀 아이콘 팩 필요) 대신 표준
>      `flowchart` 문법을 썼다 — 전자는 GitHub 기본 렌더러에서 깨질 위험이 있었다.
>
> ### ⏭️ **다음 태스크** (2026-08-12 이전 기록과 동일, 변경 없음)
>
> 1. **Wave 8** — `iac-platform-gitops` · `iac-reference-infra` README 재작성(구 769줄 중 64%가
>    changelog). 문서 zero-base 재작성 마지막 Wave.
> 2. **소비 repo 2개의 D-ID 참조 정리** — Wave 8에서 자연스럽게 처리.
> 3. **H7 `argocd-seed.sh` preflight 결함** — 단계 범위에 2가 없으면 `GH_APP_*` 요구를 뺀다
>    (`iac-platform-gitops`의 vendoring 사본도 함께, 2 repo).
> 4. **ArgoCD 초기 비밀번호 교체**(`07-runbooks.md` 2·3절) — 재구축 완료 조건 중 유일하게 미완.

---

### ✅ **2026-08-12 — 코드 주석 재편 완료 (PR #22 머지). D-ID 폐지**

> ### ▶ 기준을 **"간결"이 아니라 "자립"** 으로 잡았다
>
> 사용자 요구는 *"팀원이 전반의 히스토리를 몰라도 docs 와 코드만 보고 이해"* 였다.
> ⛔ **"간결"로 잡으면 틀린다** — 잘라내기 좋은 것(=긴 것)부터 죽는데 이 repo 에서 긴 주석은
> 대체로 비싸게 산 것이다(`name_prefix` 38자 한도 5줄 · confused deputy 5줄).
> ✅ **실증**: `vpc/main.tf` 는 주석이 **59 → 62줄로 늘었다.** 좌표가 압축 역할을 하고 있어
> 자립 서술로 풀면 길어지는 자리가 있다. 전체는 1,013 → **985줄**(-3%)로 거의 같다.
> 🔑 **줄 수는 목표가 아니었고, 실제로 줄지 않았다.** 그것이 규칙이 옳게 작동한 증거다.
>
> ### 🔬 **D-ID 전수조사 — 43개 중 docs/ 에 정의가 있는 것 0개**
>
> | 지표 | 값 |
> |---|---:|
> | 고유 `D-ID` (언급 149건) | 43개 |
> | ↳ **`docs/` 에 정의 있음** | **0개** |
> | `.omc/notepad.md` 에만 존재 | 23개 |
> | 코드·규칙이 참조하나 정의 없음 | 20개 |
> | 주석 안 `§` 좌표 | 185개 (전부 삭제된 문서) |
>
> **원인은 Wave 7 의 문서 삭제가 아니다** — `08-decisions.md` 가 D-ID 체계를 버리고
> *"하지 말 것 / 이유"* 표로 간 것이 먼저다. 그리고 **그 선택이 옳았다**:
> `D-EKS-CIDR-NULL` 의 내용이 ID 없이 08 에 실려 있고, 독자는 *"D-EKS-CIDR-NULL 이 뭐지"* 가
> 아니라 *"`ignore_changes` 쓰면 안 되나"* 라고 묻기 때문에 그쪽이 더 잘 찾힌다.
>
> ⛔ **08 에 D-ID 열 복원은 기각.** 08 은 **기각 목록**인데 43개 중 대부분은 **채택된 결정**이다.
> 채택된 결정은 코드 자체가 구현이라 레코드가 필요 없고, 레지스트리 신설은 재작성이 없앤 물건이다.
>
> ### ✅ 확정한 3계층 (`06-conventions.md` §5 가 소유)
>
> | 계층 | `D-ID` | 대신 |
> |---|---|---|
> | **`.omc/notepad.md`** | ✅ **유지** | 시간순 기록 · 정의와 참조가 **같은 파일 안**이라 역참조가 안 깨진다 |
> | `docs/` | ❌ | 결정의 **내용** |
> | 코드 · `CLAUDE.md` · `AGENTS.md` | ❌ | 불변식 서술 |
>
> ### 📌 부수 소득 — `error_message` 도 같은 병이었다
>
> `"...가져야 한다(D6 — cidrs 길이가 곧 AZ 수다)"` 처럼 **소비자가 plan 실패 화면에서 읽는
> 문자열**에 좌표가 있었다. ⇒ 자립 기준은 주석만이 아니라 **사람이 읽는 모든 문자열**에 적용된다.
> 함께 정정: `eks-cluster` 태그 stale(`v0.4.0`→`v0.5.0`) · `workbench`(`v0.4.0`→`v0.6.0`) ·
> `modules/AGENTS.md` 의 *"현재 비어 있다"*(모듈 3개가 릴리스된 지 오래다).
>
> ### 🔴 **작업 중 사고 2건 — 둘 다 기계 치환 정규식. 반드시 읽을 것**
>
> | # | 무엇 | 잡은 것 |
> |---|---|---|
> | 1 | `[^)]*` 가 **줄바꿈을 넘어** `examples` 본문 **97줄**을 삼킴 | `git diff --numstat` |
> | 2 | `(?<=\S) +([.,])` 가 **셸 인자의 공백**을 먹어 `verify.yml` 파손 | **CI** |
>
> ②의 실물: `--ignorefile .trivyignore.yaml .` → `--ignorefile.trivyignore.yaml.`
> ⇒ `unknown flag`. `find . -name` → `find. -name` 도 같이 깨졌다.
> 🔑 **공백은 산문에서는 미관이지만 셸·경로·마크다운에서는 문법이다.**
> ⚠️ **②는 두 번째였다** — workbench 에서 같은 규칙이 `·` 앞 공백을 먹었을 때
> **`·` 만 패턴에서 빼고 `.`·`,` 는 남겨 뒀다.** 증상만 고치고 원인을 안 고친 것이다.
>
> ⭐ **재사용할 안전망 2개**:
> - 주석만 바꾸는 작업에서는 **`git diff --numstat` 의 추가 줄 수 = 삭제 줄 수**를 확인한다. 다르면 사고다.
> - 복구는 **git 직전 판을 정답으로 두고 공백 조합을 탐색해 되돌린다** — 눈으로 훑는 것보다 확실하다
>   (12곳 중 4곳은 주석이라 안 보였다).
>
> ### ⏭️ **다음 태스크**
>
> 1. **Wave 8** — `iac-platform-gitops` · `iac-reference-infra` README 재작성(구 769줄 중 64%가 changelog).
>    ⇒ **이걸 끝내면 문서 zero-base 재작성이 완결된다**(9 Wave 중 8개 완료).
> 2. **소비 repo 2개의 D-ID 참조 정리** — 이번 범위 밖이었다. Wave 8 에서 자연스럽게 닿는다.
> 3. 재구축 전 선행: **H7 `argocd-seed.sh` preflight**(단계 범위에 2가 없으면 `GH_APP_*` 미요구, 2 repo).
> 4. 재구축 시 완료 조건: **ArgoCD 초기 비밀번호 교체**(`07-runbooks.md` 2·3절).

---

### ✅ **2026-08-12 — Wave 7 완료. 구 문서 10,223줄을 지웠다**

> ### ▶ 문서 zero-base 재작성 — **8 Wave 중 7개 완료.** 남은 것은 Wave 8뿐
>
> | 지운 것 | 규모 |
> |---|---|
> | `docs/architecture/`·`design/`·`consumer/`·`reference/poc-findings.md` + 각 `AGENTS.md` | **21파일 10,223줄** |
> | `docs/runbooks/.gitkeep` — 한 번도 안 채운 빈 디렉토리(`07-runbooks.md`가 소유) | 1파일 |
>
> 존치·이동: `reference/aws-naming-abbreviations.md` → **`docs/aws-naming-abbreviations.md`**
> (약어 312개는 **데이터라 재작성 규칙의 예외**다 — 계획서 §9-4).
> 전문은 태그 **`docs-archive-20260811`** 에 있다.
>
> ### 🔑 삭제가 안전했던 근거 — 새 문서가 구 문서를 **0건** 참조하고 있었다
>
> 계획서가 Wave 7을 마지막에 둔 이유는 *"새 문서를 쓰는 동안 구 문서가 원자재"* 였다.
> 삭제 직전에 재면 그 의존이 **이미 끊겨 있었다** — 자립이 확인된 뒤에 지웠다.
> ⚠️ **단 하나 예외가 있었다**: `05`·`06`이 `reference/aws-naming-abbreviations.md`를 가리켰다.
> 그것은 삭제 대상이 아니라 **이동 대상**이라 처음 측정에서 빠졌고, **이동이 링크를 깼다.**
> 🔑 교훈: *"삭제해도 되는가"* 와 *"옮겨도 되는가"* 는 **다른 질문**이고 답도 다르다.
>
> ### 참조 재지정 — 문서 40건. 코드 주석 24건은 **다음 태스크로 분리**(사용자 결정)
>
> | 파일 | 건수 |
> |---|---|
> | `CLAUDE.md` | 9 |
> | `AGENTS.md`(루트) · `modules/AGENTS.md` · `docs/AGENTS.md` · `examples/AGENTS.md` | 21 |
> | `scripts/README.md` | 8 |
> | `examples/*/README.md` · `docs/05`·`06`·`aws-naming-abbreviations.md` | 12 |
>
> ✅ **깨진 상대 링크 0건**(전 repo `.md` 스캔). ⏳ `.tf`/`.sh`/`.yml`/`.tftest.hcl` 주석 **24건** 잔존 —
> `.tf`는 브랜치→PR 경로라 문서 커밋과 섞지 않는다.
>
> ### 📌 함께 고친 stale 사실 (판정 6)
>
> `eks-cluster` 최신 태그가 **`v0.5.0`인데 세 곳이 `v0.4.0`**, `workbench`는 **`v0.6.0`인데 `v0.4.0`** 이었다.
> 🔴 **`examples/eks-cluster-enterprise/README.md`가 자기가 경고한 함정에 두 번째로 걸려 있었다** —
> 2026-08-10에 같은 이유로 한 번 고쳤던 파일이다. ⇒ 그 자리의 서술을 *"몇 번에 걸렸다"* 가 아니라
> **"경고문으로는 안 되고 태그 컷 작업에 붙여야 한다"** 로 바꿨다.
>
> ### ⏭️ **다음 태스크**
>
> 1. **Wave 8** — `iac-platform-gitops` · `iac-reference-infra` README 재작성(구 769줄 중 64%가 changelog).
> 2. **코드 주석 24건** 재지정 — `.tf`/`.sh`/`.yml`/`.tftest.hcl`. 브랜치 → PR.
> 3. 재구축 전 선행: **H7 `argocd-seed.sh` preflight**(단계 범위에 2가 없으면 `GH_APP_*` 미요구).
>    ⚠️ `iac-platform-gitops`의 vendoring 사본도 함께 — **2 repo**.
> 4. 재구축 시 완료 조건: **ArgoCD 초기 비밀번호 교체**(`07-runbooks.md` 2·3절).
>
> ⚠️ 완료 판정 1(전체 1,500줄)은 **1,597줄로 초과**다. Wave 5가 실증 발견을 접어 넣은 결과라
> 줄이려면 실측으로 얻은 값을 버려야 한다 — **상한을 1,600으로 올리는 것이 맞다**(미승인).

---

### ✅ **2026-08-12 — 재구축(Wave 4-b) 완료. 환경이 살아 있다**

> ### ▶ 현재 상태 — 전부 서 있고 검증됐다
>
> | 레이어 | 상태 |
> |---|---|
> | L3 ArgoCD + Application 8개 | ✅ **전부 `Synced Healthy`** · NodePool·EC2NodeClass `READY=True` |
> | L2 EKS `eks-ref-dev-an2-main-01` | ✅ ACTIVE · k8s 1.35 · 시스템 노드 2대 |
> | L2 workbench | ✅ **`i-0c31659a42460ea56`** (구 `i-03ae…`·`i-0e74…` 는 없다) |
> | L1 VPC | ✅ **`vpc-02ba7bc643fbf881a`** (구 `vpc-00e166…` 는 없다) |
> | L0 | ✅ 살아 있었다 — 파기 대상이 아니다 |
>
> 삭제 보호 두 루트 `true` 복원 완료(PR #25). 자격증명 위생 완료
> (`shred -u` + `delete-parameter` → `ParameterNotFound`).
>
> ### ⛔ 남은 완료 조건 1건 — **ArgoCD 초기 비밀번호 교체**
> `23 §2.3` 이 **선택이 아니라 완료 조건**으로 정했다. **아직 안 했다.**
> 비밀번호는 **사용자가 정할 값**이고 `--core` 로는 실패하므로(`23 §2.3-1`)
> **대화형 세션 + `--port-forward`** 로 한다. 절차: `07-runbooks.md` 2·3절.
> 그 뒤 `kubectl -n argocd delete secret argocd-initial-admin-secret`.

> ### 🔬 **Wave 4-b 실증 발견 — 문서 반영 완료** (`59f6fc7`)
>
> | # | 발견 | 상태 |
> |---|---|---|
> | ~~H1~~ ✅ | merge 한 번이 두 루트 plan 을 동시 트리거 → EKS plan 이 `no matching EC2 VPC found` 로 실패. **from-zero 에서는 main 에 빨간 X 가 반드시 한 번 뜬다.** 결함이 아니라 느슨한 결합의 귀결 | ✅ `03 §4` |
> | ~~H2~~ ✅ | `tofu init` 의 git 소싱이 **TLS 검증 실패**(`server certificate verification failed`). 30분 내 **2회** — 일회성 아님. 대응은 `gh run rerun <id> --failed`(새 dispatch 는 plan 을 다시 돌려 승인된 계획을 바꾼다. ✅ `--failed` 는 plan 을 유지함을 실측) | ✅ `07 §7` (init 재시도 자동화는 미검토) |
> | **H3** | workbench 가 클러스터와 **병렬 생성**돼 kubeconfig 가 안 섰다(`update-kubeconfig` 5회 전부 실패) | ✅ 해결 — 소비 repo PR #26 |
> | **H4** | 워크플로에 **`replace` 경로 부재** — 잘못 부팅한 인스턴스를 코드가 회수 못 함. G4(destroy 누락)와 같은 형태 | ✅ 해결 — 소비 repo PR #26 |
> | **H5** | GitOps 가 **재구축마다 바뀌는 role 이름**을 값으로 고정 → Karpenter `iam:PassRole` 403 | ✅ 해결 — 모듈 PR #21 (`eks-cluster-v0.5.0`) |
> | — | `03:136` 이 로컬 `tofu plan` 을 시킨다 — **성립하지 않는다**(판정 완료) | ✅ `03 §4` 정정 완료 |
>
> #### 🔑 H3 의 교훈 — `depends_on` 이 아니라 **값 참조**다
> `eks_cluster_name = local.cluster_name`(로컬 문자열)이라 순서 간선이 없었다. EC2 1분 vs EKS 10분.
> - ⛔ **`depends_on = [module.eks]` 는 순환**이다(실측, pre-push 훅이 잡음) — `depends_on` 은
>   모듈의 **close 노드 = 모듈 전체**에 걸리는데 `module.eks` 가 workbench 의 role·SG 를 설정 시점에 쓴다.
> - ✅ 정답은 **`module.eks.cluster_name` 값 참조**(사용자 제안). 그래프가 **리소스 단위**라 고리가
>   닫히지 않는다 — 클러스터에 매달리는 건 *인스턴스*, eks 가 받아가는 건 *role·SG* 로 다른 리소스다.
> - ⚠️ **`arn` 은 local 유지**(비대칭이지만 이유가 있다): 모듈 `aws_iam_role_policy.eks_describe` 의
>   `count` 가 `eks_cluster_arn != null` 에 걸리는데 실 ARN 은 **plan 시점 unknown** 이라 count 가 깨진다.
>   가르는 기준은 일관성이 아니라 **plan 시점 known 여부**다.
> - ✅ 판정: 교체 후 **`시도 1` 에 성공.** *"시도 4에 성공"* 이 아닌 것이 증거다 — 경쟁을 이긴 게 아니라 **없앴다.**
>   📌 부수 확인: 모듈 주석이 상정한 **IAM 전파 race 는 실제로 없었다.** 그 재시도 루프는 예비 장치다.
>
> #### 🔑 H5 의 교훈 — **GitOps 는 자기가 옳다고 보고한다**
> ArgoCD 는 **`Synced` / `Degraded`** 였다. Git 이 요구한 것을 그대로 적용했으니 sync 는 성공이 **맞고**,
> 실패는 한 계층 아래(IAM)에서 난다. ⛔ *"Synced 면 됐다"* 로 읽으면 원인을 못 찾는다.
> - 같은 파일에 **`vpcId` 도 stale** 했다(파기된 VPC). ALBC 는 `Healthy` 로 보였다 — helm 값일 뿐이라
>   실패가 런타임으로 밀린다. `vpcId` 는 AWS 발급 ID 라 **구조적 해법이 없어 갱신이 절차로 남는다.**
> - ⭐ 모듈 수정은 **새 발명이 아니었다** — 관리형 노드그룹·`iam.tf` 가 이미 `use_name_prefix = false` 를
>   쓰고 있었고 **Karpenter 노드 role 만 빠져 있었다.** 예외 추가가 아니라 **누락을 메운 것**이다.
>
> #### 📌 재사용할 실측 (재구축 절차)
> - `execution_role_arn` 출처 = **`gh variable list`**(G3 의 답): `AWS_ENTRY_ROLE_ARN`·`AWS_EXEC_ROLE_ARN`·
>   `TF_STATE_BUCKET`·`MODULE_READER_CLIENT_ID`
> - `AWS_PROFILE=team git push` 가 **실제로 필요**했다(G5). pre-push 훅의 `validate` 가 backend 를 연다.
> - PR 에 체크가 없는 것은 **의도된 설계**(`pull_request` 트리거를 2026-08-03 제거)
> - 승인 게이트: 무료 플랜이라 **dispatch 를 누르는 행위가 승인을 대신한다**(멈추지 않는다)
> - **공용 계정 오독 사례**: `oidc.eks…` provider 가 남아 있으나 태그가 `Project=eks-scale-lab` = **남의 것**.
>   🔑 판정 근거는 리소스 종류가 아니라 **태그**다(04 §0 이 실제로 작동했다).
> - workbench 클론 후 **`git pull` 이 안 된다** — 클론 직후 remote 에서 토큰을 지우기 때문(의도된 설계).
>   갱신하려면 **클론 헬퍼를 다시 돌린다.**
> - `send-command` 는 로그인 셸이 아니다 → `export HOME=/root; export KUBECONFIG=/root/.kube/config` 필수

> ### ⭐ **H6 — `vpcId` 도 걷어냈다. ALBC 는 태그로 VPC 를 찾는다** (2026-08-12, 사용자 제기)
>
> H5 를 고친 뒤 *"secret 에 vpcId 가 왜 필요하냐"* 는 질문에서 나왔다. **소비자는 ALBC 하나뿐**이었다.
>
> - **왜 있었나**: ALBC 가 파드에서 IMDS 로 VPC 를 못 찾는다(노드 IMDSv2 **hop limit=1**).
>   ⛔ hop limit 을 2로 올리는 우회는 이미 기각 — 파드가 노드 IAM role 을 탈취하게 된다.
>   🔑 **IMDS 를 못 쓰는 것은 결함이 아니라 받아들이는 제약**이다. 고칠 것은 제약이 아니라
>   **그 제약을 푸는 방식**(AWS 발급 ID 를 값으로 박기)이었다.
> - **답은 upstream 에 이미 있었다**: chart **3.5.0** 의 `vpcTags` → `--aws-vpc-tags`.
>   values 주석이 우리 경우를 그대로 서술한다 — *"alternative to vpcId … when your pods are
>   unable to use the metadata service"*. ⇒ *"upstream 미지원"* 이 아니라 **우리가 안 넘기고 있었다**
>   (graviton `ami_type` 사건과 같은 형태다).
> - **변경**: `vpcId: vpc-…` → `vpcName: vpc-ref-dev-an2-main` + `vpcTags.Name`.
>   Name 태그는 **네이밍 규칙(SSOT)이 유일성을 보장**하므로 재구축을 견딘다.
> - ✅ **판정**: `--aws-vpc-tags=Name=vpc-ref-dev-an2-main` 로 렌더 · 로그 오류 0 ·
>   **재시작 0회** · Application 8/8 Synced Healthy.
>   🔑 **`restarts=0` 이 증거다** — 실패 모드가 CrashLoop 이라 `Running` 만으로는 부족했다.
> - ⛔ 기각: 거버넌스 태그 AND(`Workload`+`Environment`+`RegionCode`) — per-cluster 값이 0이 되지만
>   `workload` 라벨 신설이 필요하고 **그 조합에 VPC 가 2개가 되면 조용히 깨진다**(증상이 오늘 것과 똑같아진다).
> - 📌 `iac-platform-gitops` `7238efa`. README 「실물 좌표」 표도 ID → 결정적 이름으로 바꾸고
>   *"여기 AWS 발급 ID 를 적지 않는다"* 를 상자로 남겼다.

> ### 🔴 **H7 (미해결) — `argocd-seed.sh` preflight 가 4단계에도 private key 를 요구한다**
>
> 키를 쓰는 것은 **2단계뿐**인데(`scripts/argocd-seed.sh:194`), preflight 가 `GH_APP_*` 를
> **무조건** 검사한다(`:104`·`:115`). ⇒ `--from 4 --to 4` 가 키 없이 실패한다.
> 🔴 **완료 조건과 정면 충돌한다** — D-KEY-TRANSFER ③이 seed 후 `shred` 를 요구하는데,
> 그 뒤 cluster Secret 만 다시 적용하려면 **키를 다시 올려야** 한다. 오늘 실제로 막혔다.
> - 우회(1회): 커밋된 매니페스트를 그대로 `kubectl apply -f` (seed 4단계와 **같은 명령·같은 바이트**)
> - ⇒ 고치려면 **단계 범위에 2가 포함될 때만** `GH_APP_*` 를 요구하도록 바꾼다.
>   ⚠️ `iac-platform-gitops` 의 vendoring 사본(`bootstrap/argocd-seed.sh`)도 함께 갱신해야 한다(2 repo).
> - 📌 부수: workbench 클론은 토큰을 remote 에서 지우므로 `git pull` 이 안 된다 —
>   갱신하려면 클론 헬퍼 재실행 = **키가 또 필요하다.** 같은 병의 두 증상이다.

---


### [구 Priority Context 아카이브 원문 — 2026-08-14 재구성 이전]

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

> **최신 (2026-08-11 기준, `git tag` 실물과 대조함)**: `vpc-v0.3.0` ·
> **`eks-cluster-v0.4.0`**(D-EKS-CIDR-NULL, PR #14 `ade89e9`) ·
> **`workbench-v0.6.0`**(PR **#20** `f9631a8`, **D-WORKBENCH-TOOLING** — `eks-node-viewer v0.7.4` ·
> `krew v0.5.0` + 플러그인 6종 · `/etc/profile.d/workbench.sh`(alias `k`·`nv` · kubectl completion ·
> `AWS_DEFAULT_REGION`)).
> 직전: `v0.5.0` **D-WORKBENCH-KUBECONFIG**(정본 `0444` + `/etc/skel` 상속 + 사용자별 `0600` 사본,
> `profile.d` 전역 KUBECONFIG export 제거) · `v0.4.0` D-WORKBENCH-SIZE(`t4g.small`) ·
> `v0.3.0` argocd CLI · `v0.2.0` git 설치.
> 🔴 **업그레이드 시 인스턴스 교체** — ⭐ 그러나 그것이 이 릴리스의 목적이다. 교체 후에도
> kubeconfig 가 자동으로 서고, 손으로 만든 사본에 의존하지 않는다).
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

> ### 🔑 **AWS 자격증명도 같은 범주다 — 머신 단위, dotfiles 로 안 따라온다** (2026-08-06 추가)
>
> **실측에 쓰는 프로파일은 `team`** — 계정 **`533616270150`**(`user/silverte`) · `ap-northeast-2`.
> 다른 프로파일 `asset`(`614054776208`)도 있으니 **계정을 확인하고 쓴다**.
> `20 §1.1`·`22 §4.2` 의 addon/클러스터 실측이 전부 이 프로파일로 나왔다.
>
> **이 머신(`/Users/a07326/…`)에는 `~/.zshrc` 에 `export AWS_PROFILE=team` 을 넣어 뒀다**
> (2026-08-06, 백업 `~/.zshrc.bak.*`). ⚠️ **`~/.zshrc` 는 dotfiles 동기화 대상이 아니다**
> (대상: `CLAUDE.md`·`settings.json`·`.omc-config.json`·`keybindings.json`·스킬·hooks·hud).
> ⇒ **다른 머신에서는 프로파일을 명시하거나 같은 줄을 직접 넣어야 한다.**
>
> - ⛔ **`~/.aws` 에 `[default]` 섹션을 만들어 해결하지 않았다** — 자격증명이 `[team]`·`[default]`
>   두 곳에 **중복**되어 키 로테이션 때 한쪽만 고치면 조용히 어긋난다.
> - ℹ️ **동작하지 않는 오답 기록**: `[default]` 에 `source_profile = team` 만 쓰는 별칭 방식.
>   `source_profile` 은 **`role_arn` 과 짝일 때만** 의미가 있다.
> - ⚠️ **기본값이 생기면 프로파일을 깜빡해도 명령이 성공한다.** 전엔 `Unable to locate credentials`
>   로 멈췄다. **소비 repo 에서 로컬 `tofu apply` 전에는 `aws sts get-caller-identity` 로 계정을 본다.**

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

**실측(2026-08-06 2차, `de1df5c`)** — `aws eks describe-addon-versions` · **profile `team`** ·
계정 `533616270150` · `ap-northeast-2` · 실클러스터 **`eks-ref-dev-an2-main-01`(k8s 1.35)**.
`owner` 는 **3값**: `community` **6** · `aws` **21** · **`aws-marketplace` 55**.
- **community 6종** — metrics-server·kube-state-metrics·prometheus-node-exporter·cert-manager·
  external-dns·fluent-bit. **`20 §2.6` baseline 표와 정확히 일치** ⇒ 그 카탈로그는 소진됐다.

> ### 🔴 **1차 서술이 틀렸다 — 문서 페이지가 API 보다 뒤처져 있었다**
>
> 자격증명 없이 공식 문서 페이지를 전수 검색해 *"Marketplace 34개 중 kyverno·velero 0건"* 이라
> 적었다(`340e361`). **API 엔 있다**: `nirmata_kyverno` · `nirmata_nirmata-kyverno-payg` ·
> `catalogic-software_cloudcasa`(type=**backup**) — 전부 `owner = aws-marketplace`.
>
> ### 📌 **재사용할 절차 — addon 카탈로그의 SSOT 는 문서 페이지가 아니라 API 다**
> 문서는 사람이, API 는 카탈로그가 갱신한다. **뒤처지는 쪽은 항상 문서다.**
> ⭐ CLAUDE.md 「검증」의 *"추정 금지"* 가 **"공식 문서를 읽었다"로도 충족되지 않는다**는 실증.
> ⇒ **가용성 판정은 `describe-addon-versions` 로만.** 문서 페이지는 설명 조회용이다.
>
> ⭐ **결론 2건은 유지되고 근거가 교체됐다** — `04` 가 D-OSS-STACK 의 엔진 축 근거를 교체한 것과 같은 형태다.

> ### ⛔ **규칙 공백을 메웠다 — `aws-marketplace` addon 은 "IaC 기본" 대상이 아니다**
>
> D-ADDON-BOUNDARY 는 *"community addon 포함"* 만 썼고 **`owner` 의 세 번째 값을 다루지 않았다.**
> 판정 근거는 **이 repo 의 존재 이유**다 — *"고객사가 **구독 라이선스 없이** 바로 착수"* 인데
> Marketplace addon 은 **벤더 구독이 전제**다. 조달 마찰을 없애려 만든 자산이 그것을 기본값으로
> 삼을 수 없다. 🔑 **D-ENGINE(`04`) 이 OpenTofu 를 택한 축과 정확히 같다.**
> ⚠️ **금지가 아니라 기본값**이다 — `cluster_addons` 는 소비자 입력을 merge 하므로 고객사가 이미
> 벤더를 쓰면 그대로 넘긴다. **baseline 에 넣지 않을 뿐**이다.

**D-POLICY-ENGINE (Kyverno)** = **helm · 프로파일 A 한정 baseline**. `30 §5` 의 TBD 해소.
- 🔴 **`nirmata_kyverno` 는 실재한다.** 그럼에도 helm 인 근거는 둘이고 **①만으로 결론이 선다**:
  **① `owner = aws-marketplace`**(원칙 — 안 바뀐다) · ② **k8s 1.35 호환 버전 없음**
  (`nirmata_kyverno` 최신 `v1.13.2` 가 **1.31** 까지, payg `v4.0.14` 가 **1.32** 까지).
  ⚠️ **②를 주력으로 쓰지 않는다** — 벤더가 따라오면 사라지는 근거이고 그때 질문이 재발한다.
  ②는 *상용 addon 이 **4 마이너 뒤처진다***는 부수 사실로만 기록한다(벤더 위임의 대가).
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
  덮어쓰지 않아 **이미 충족**(소스 `.terraform/modules/eks/variables.tf:59`) ⇒ **모듈 계약 변경 0**.
  ⭐ **실계정에서 실증됨**(2026-08-06 2차): `eks-ref-dev-an2-main-01` 의
  `accessConfig.authenticationMode` = **`API_AND_CONFIG_MAP`**. 소스 연역이 실물로 확인됐다.
  ⚠️ **백업·복원 자체는 여전히 미실행**(`22 §5-5`) — *"전제조건 충족"* 과 *"복구된다"* 는 다르다.
- ⚠️ **CloudCasa(`catalogic-software_cloudcasa`) 라는 제3 선택지가 실재하고 k8s 1.35 를 지원한다**
  (`v3.4.7` — Kyverno 와 달리 **뒤처지지 않았다**). 그럼에도 안 쓰는 이유는 **Marketplace 구독 하나**다.
  🔑 **기술적 우열이 아니라 조달 마찰로 갈린 판단**임을 문서에 명시했다.
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
> 📌 **KEDA 는 어떤 `owner` 에도 addon 이 없다**(실측) ⇒ 경로 **helm** 확정.
> ②catalog 배치는 재확인 안 했다 — 도입 시 *"어느 프로파일에 필요한가"* 를 먼저 통과시킨다.

> ### 🔧 §번호 이동 — `22` 열린 항목 **§4 → §5**
>
> 백업 절을 §4 로 신설하며 밀렸다. `40` 의 교차 참조 4곳(`§4-1`·`§4-2` → `§5-1`·`§5-2`)을
> **같은 커밋에서** 고쳤다. ⚠️ `22` 를 다시 인용할 때 옛 번호를 쓰지 않는다.

#### ✅ **`21` 개정 완료 — D-GITOPS-SEAM** (2026-08-07). 문서 전용 · `.tf` 변경 0

`01 §3.3` 이 위임한 재결정이 닫혔다. 전문은 **`docs/design/21 §1`**(신설).
개정 문서 4개: `21`(§1 신설·§0 상태표·§2.7 정정 표시) · `01 §3.3`+열린항목1(해소) ·
`22 §3.1`·`§3.2`(포인터) · `docs/README.md`(상태표).

> ## ⭐ 결정: **프로파일 A 내부 분기**
> - **프로파일 A 기본** = 관리형 **EKS Capability for Argo CD**(`awscc_eks_capability`)
> - **탈출 조건 3개**(하나라도 해당 → self-managed helm): ① **IdC 미보유·도입 불가**
>   ② 미지원 기능 중 필수인 것 있음 ③ Application 과금 수용 불가
> - **프로파일 B 는 해당 없음** — 정의상 ArgoCD 가 없다(`22 §3.2`)
> - 🔑 **분기 축이 A/B 가 아니라 A 내부다.** 착수 때 A/B 로 잡았다가 `22 §3.2` 표를 열고 정정했다 —
>   B 는 "직접 배포"라 self-managed ArgoCD 를 두면 **정의 모순**이었다.

**🔴 실측이 초판을 하나 뒤집었다 — 요금**(profile `team`·`533616270150`·`ap-northeast-2`)

| | 21 초판(07-18) | **실측(Price List API, APN2)** |
|---|---|---|
| capability | `$0.03/hr` (≈$21.9/월) | **`$0.034799/hr` = $25.40/월** (+16.0%) |
| Application | `$0.0015/hr` | **`$0.001726/hr` = $1.26/월** (+15.1%) |

App 30개 **$63.20/월** · 50개 $88.40 · 100개 $151.40 — **App 수에 선형**.
⚠️ 3rd-party 블로그는 us-east-1 값(`$0.02771`)에 *"서울 미확인"* 이라 했으나 **APN2 usagetype 실재**,
us-east-1 대비 **약 25.6% 비쌈**. `aws pricing get-products --filters ...Field=usagetype,Value=APN2-AmazonEKSCapabilities-ArgoCD-Hours:perCapability`

> ### 📌 **재사용할 절차 ① — 요금의 SSOT 도 API 다**
> 8/6 의 *"addon 카탈로그 SSOT 는 문서가 아니라 API"* 가 **요금 축에서 그대로 재현**됐다.
> ⇒ 콘솔 페이지·블로그를 인용하지 않는다. **`aws pricing` 을 리전 지정해 뽑는다.**

> ### 📌 **재사용할 절차 ② — 소스마다 대답할 수 있는 질문이 다르다** (8/6 교훈의 정정)
> `awscc` 스키마는 `aws_idc` 를 **Optional** 이라 하지만 **실제로는 필수**다
> (문서: *"local users are not supported"*). ⇒ *"API 가 문서를 이긴다"* 가 **아니다**:
> - **스키마·카탈로그 API** = *무엇을 넣을 수 있나 · 무엇이 존재하나*
> - **문서** = *무엇이 있어야 동작하나 · 무엇이 지원되지 않나*
>
> ⛔ 8/6 은 전자로, 8/7 은 후자로 틀릴 뻔했다. **가용성은 API, 전제조건·제약은 문서.**

**그 밖의 실측**(전문 `21 §1.2`):
- `AWS::EKS::Capability` **APN2 등록 확인**(`describe-type`, `FULLY_MUTABLE`)
- `type=gitops` addon 은 **2건뿐, 둘 다 `aws-marketplace`**(`akuity_agent`·`spacelift_workerpool-controller`)
  ⇒ **`owner=aws` gitops addon 없음** = 관리형 Capability 는 addon 이 아니라 **별도 API**.
  🔑 **D-ADDON-BOUNDARY 가 이 결정을 판정하지 못한다** — 조회 결과가 *"이 축은 내 소관이 아니다"* 였다.
  제3 후보 `akuity_agent` 는 Marketplace 규칙이 이미 배제(재논증 불필요, 근거만 인용).
- awscc **1.93.0 → 1.95.0**. `type` = **ACK/ARGOCD/KRO**. ⚠️ **`namespace` 도 immutable**(초판에 없던 제약)
- ⛔ **착수 전 확정 필수 5개**(`createOnly`): `cluster_name`·`capability_name`·`type`·`namespace`·`aws_idc`.
  **RETAIN 과 맞물려 재생성이 orphan 을 남긴다** — 열린항목 1 의 M-4 가 다섯 전부로 확장.
- 미지원 8종: CMP · Lua health · **Notifications controller** · **custom SSO** · UI extensions ·
  `argocd-cm` 직접접근 · **sync timeout 120s 고정** · CR 단일 namespace 강제 · IdC identity **1,000 한도**
- ⚠️ **로컬 `aws-cli 2.27.18` 에 `eks describe-capability` 가 없다**(문서엔 있다).
  **CLI 에 없다고 API 에 없는 것이 아니다** — 실제 조작 전 CLI 를 올린다.
- ✅ `network_access.vpce_ids` 는 **초판이 이미 기록**했다(새 축 아님 — 착수 때 새 것으로 착각했다가 정정)

> ### 🔴 **`21` 은 상태표에서 유일하게 "문서 단위 판정"이 안 되는 문서다**
> **§1 = ✅ 확정 · §2.7·§2.8 = PoC 이관본(인용 불가)** 가 한 파일에 있다.
> ⇒ **인용할 때 절 번호까지 쓴다.** *"21 에 따르면"* 은 이 문서에 한해 근거가 못 된다.
> 의도된 예외다 — 이관본을 버리면 PoC 가 부딪힌 벽이 사라지고, 분리하면 30·40 참조 20여 곳이 끊긴다.

> ### ⏸ **미결로 남긴 것 — `22 §3.1` 판별표 완화** (사용자 결정: 보류)
> 관리형은 판별 질문 **1(전담 인력)** 의 비용을 AWS 가 가져가고 **4(private 유지)** 를 충족한다
> ⇒ `22 §3.1` 이 *"지금 답을 갖고 있지 않다"* 고 적은 **"1=아니오 & 4=예"** 조합에 답이 생겼다.
> ⛔ 그래도 안 고쳤다 — 판별 기준 변경은 22 전체 + 30(미개정)에 파급되고 **21 을 닫는 데 불필요**했다.
> 📌 **재개 조건**: 실제로 그 조합인 고객사를 만났을 때. 근거 전문은 `21 §1.6` 상자.

> ### 🔑 **"둘 다 지원"의 비용을 `04 §3` 형식으로 값 매겼다** (`21 §1.4`)
> 04 가 든 엔진 분기 비용 4개(validation 확인·lock 포기·피드백 지연·**`required_version` 영구 구속`**)가
> **여기선 전부 0**이다. 이유는 하나 — **분기가 모듈이 아니라 소비 루트에서 일어난다**
> (이 repo 는 GitOps hub 를 소유하지 않는다. 모듈 계약 변경 0).
> 📌 **다음에 "둘 다 지원할까"가 나오면 먼저 물을 질문: *"갈림이 모듈 계약에 박히는가."***

#### ✅ **문서 구조 확정 — 두 경로를 같이 설계하기 위한 틀** (2026-08-07, 사용자 결정)

사용자 요구: *"관리형과 helm chart 두 케이스의 실제 설계·적용을 같이 한다. **helm 먼저.**"*

> ## ⭐ 확정 구조
> ```
> 21  seam 결정   ├ §1   ✅ D-GITOPS-SEAM
>                 ├ §1.7 🆕 갈림점 표 ← 23·24 가 공유하는 단일 계약면
>                 └ §2.7·§2.8  PoC 이관본(동결)
> 23 🆕 self-managed ArgoCD 설계  ← 먼저
> 24 🆕 관리형 Capability 설계
> 30    GitOps repo 구조 — 공통. 갈림점에서만 분기 (23 이 요구하는 범위만 개정)
> ```
> ⛔ **문서를 경로별로 복제하지 않는다** — 공통부 두 벌 = drift(PoC repo 동결과 같은 구조).

**실측이 구조를 결정했다 (3건)**
1. 🔑 **두 경로는 같은 층에 있지 않다** — 관리형 = **IaC**(`awscc_eks_capability`),
   self-managed = **helm**(`22 §3.2` 축 B). ⛔ **좌우 대칭 문서로 만들지 않는다** —
   대칭으로 잡으면 *"self-managed 모듈을 만들자"* 는 잘못된 후속 판단이 나온다.
   **self-managed ArgoCD 는 이 repo 의 모듈이 아니다.**
2. 🔑 **갈리는 것은 설계축 5개뿐**(`21 §1.7`): 부트스트랩·인증RBAC·cluster 등록 형식·
   namespace 제약·기능 표면. **App-of-Apps·팬아웃·AppProject 테넌시는 양쪽 동일**
   (공식: *"work identically to upstream, no changes to your manifests"*).
   운영 축 3개(비용·업그레이드 소유·private 도달성)는 분기가 아니라 `21 §1.3` 의 근거.
3. 🆕 **IdC 실측 — 존재한다**: `aws sso-admin list-instances` →
   **us-east-1 에 `ssoins-7223bbce7f515ec2`(ACTIVE, Owner=533616270150)**, apn2 는 빈 목록.
   ⇒ **탈출 조건 ①에 안 걸린다 = 관리형도 실증 가능.**
   ⚠️ 단 **cross-region**(`idc_region="us-east-1"`) + **계정 인스턴스**(조직 아님)라
   "다중 계정 미지원" 제약이 그대로 산다. **`aws_idc` 는 `createOnly`** → 조직 인스턴스 전환은 재생성.

**⚠️ 아직 없는 것 — 배포 루트**: 소비 repo 는 `live/dev/{networking,eks}` 뿐이고 **`live/cicd/` 가 없다.**
`21 §2.8` 의 `live/cicd/gitops-hub` 는 **PoC 시절 이름**이고 `50` 이 채택한 적 없다 ⇒ **이름·위치부터 정한다.**

> ### ⛔ **모듈화는 지금 결정하지 않는다**
> `awscc_eks_capability`+IAM 은 얇은 모듈 후보지만 **소비 루트가 1곳뿐**이다.
> CLAUDE.md *"추측에 근거한 추상화를 만들지 않는다"*. ⇒ `24` 에서 *"무엇이 IaC 이고 무엇이 helm 인가"*
> 를 확정한 뒤 **모듈 경계가 실제로 보이면 그때** 만든다.

> ### 📌 **`23` 을 쓸 때의 필수 주의 — `30`(⚠️ 미개정) 위에 서지 않게 한다**
> `design/AGENTS.md` 개정 규칙 4번이 경고한 실패(개정 전 `40` 이 미결정 `21` 위에 서 있던 것).
> ⭐ **떼어낼 수 있다**: *"ArgoCD 를 어떻게 세우는가"* 는 *"무엇을 읽는가"* 와 무관하고
> **root Application seed 한 지점에서만** 닿는다. ⇒ **그 지점을 인터페이스로 선언하고
> `30` 본문을 인용하지 않는다.** `30` 전수 개정을 선행 조건으로 삼지 않는다.

> ### 🔴 **`design/AGENTS.md` 의 상태 열을 제거했다 — 두 번 틀렸기 때문**
> ① 8/5 `20` 을 "미개정"으로 ② 8/7 `21` 을 "🔴 미결정"·`20` 을 `v0.2.0`(실제 v0.4.0)으로.
> **둘 다 README 는 맞았고 그 표만 틀렸다.** 그 파일은 *"이 표도 같이 고친다 — 실제로 놓친 적이
> 있다"* 라고 **경고까지 적어 두고도** 재발했다.
> 📌 **재사용할 판단: 중복 기록이 stale 해지면 "더 조심하자"가 아니라 한쪽을 지운다.**

#### ✅ **`23` self-managed ArgoCD 설계 완료** (2026-08-07). 문서 전용 · `.tf` 0

**결정 4개**: `D-ARGOCD-SM-BOOTSTRAP`(workbench seed 1회 + **자기 관리**) · `-REACH`(port-forward) ·
`-AUTH`(local admin seed + OIDC 변수 개방, dex off) · `-HA`(chart 기본 단일 + 변수 개방).

> ### ⭐ **갈림점 1은 자유 선택이 아니라 기존 결정의 논리적 귀결이었다**
> ① `20 §3.1` private 기본 → 실측 `endpointPublicAccess: false`
> ② `40 §1` GitHub Actions 공용 runner 는 private apiserver 에 못 닿는다
> ③ `D-WORKBENCH-SCOPE` workbench 를 runner 로 겸용 안 함
> ⇒ **`helm_release`·`kubernetes` provider 를 CI apply 경로에 넣을 수 없다.** helm 을 돌릴 곳은
> workbench 하나이고 거기서는 **사람이** 실행한다(`22 §3.2` 프로파일 B 와 동일).
> 🔑 **자유도가 줄어든 것은 좋은 신호다** — 새 설계 착수 시 **기존 결정이 이미 답을 정해 뒀는지 먼저 본다.**

> ### 📌 **"upstream 이 있다"와 "upstream 을 쓸 수 있다"는 다르다**
> **`aws-ia/eks-blueprints-addons` v1.24.3 에 `enable_argocd` 가 실재한다**(실측).
> 그럼에도 못 쓴다 — `helm_release` 기반이라 **같은 도달성 벽**이다.
> ⇒ CLAUDE.md *"발명하기 전에 찾는다"* 는 **찾은 뒤 우리 제약과 대조하는 것까지가 절차**다.
> 찾았다고 채택하면 *plan 은 되는데 apply 가 안 되는* 설계가 된다.

**chart 실측** (`argo-cd-10.3.0` · appVersion **v3.5.0** · `kubeVersion >=1.25.0-0`, 클러스터 1.35 ✅)
- `crds.keep: **true**` ⚠️ **self-managed 에도 잔존물이 있다** —
  *"관리형만 RETAIN 으로 지저분하게 남는다"* 는 **잘못된 대비**다. 차이는 잔존 여부가 아니라 **무엇이 남는가**.
- `notifications.enabled: **true**`(기본) → **끈다**. 🔑 탈출 조건 ②에 쓰인 기능이라 모순처럼 보이나,
  탈출 조건은 *"그 기능이 필요한 고객사"* 를 가리키고 그 고객사는 켠다 — **baseline 이 켜는 것과 다른 질문**.
  📌 **탈출 조건에 쓰인 기능을 baseline 에 자동으로 켜지 않는다.**
- `dex.enabled: true`(기본) → **끈다**(OIDC 직결이면 죽은 경로) · `redis-ha.enabled: false` ·
  `server.service.type: ClusterIP` · `global.domain: argocd.example.com` → **소비자 입력**
- ⭐ **`40` 열린항목 7 의 근거 확정**: **chart appVersion 과 `argocd` CLI 를 같은 값(v3.5.0)으로 묶는다.**
  다르면 *"UI 는 되는데 CLI 가 안 된다"* 를 진단할 근거가 없다. **chart 올리면 CLI 핀도 같이 올린다.**

**⚠️ 30 §4 의 근거 하나가 무효였다** — *"TF 가 seed 산출물을 소유하면 안 되는 이유"* 3개 중
②(*TFC SaaS 러너 도달 불가*)는 TFC 전제다. **①(reconcile 대상을 TF 가 쥐면 self-heal 이 죽는다)과
③은 유효**하고 그 둘만으로 결론이 선다. 🔑 **①은 도구 무관이라 스택이 바뀌어도 살아남았다.**

**⚠️ 인용 정정**: 재사용 자산 요건(하드코딩 금지)의 SSOT 는 **`architecture/01 §4`** 다.
CLAUDE.md 의 *"05 §5.4"* 는 **PoC repo 문서**를 가리키며, 이 repo `architecture/05` 에 §5.4 는 **없다**.

#### 🔴 적용(apply) 경로에 **빠진 것 2개** (2026-08-07 실측)

1. **배포 루트 `live/cicd/` 가 없다** — 소비 repo 는 `live/dev/{networking,eks}` 뿐.
   `21 §2.8` 의 `live/cicd/gitops-hub` 는 **PoC 시절 이름**이고 `50` 이 채택한 적 없다.
2. 🔴 **플랫폼 GitOps repo 자체가 없다** — `gh repo list skax-ca` = **`iac-module-library` ·
   `iac-reference-infra` 둘뿐**. `30` 이 설계하는 대상이 실재하지 않는다.
   ⇒ `23 §4` 가 선언한 인터페이스(*"root Application 매니페스트가 저장소에 존재한다"*)의
   **저장소가 아직 없다.**

#### ✅ **`30` 부분 개정 완료** (2026-08-07) — §1.1 · §4.1 만. 전수 개정 안 함

🔶 **`30` 은 이제 절 단위 판정 문서다**: **§1.1·§4.1 = ✅** · **§0·§1·§2·§3·§5 = 미개정(인용 불가)**.

> ### 🔴 **D-REPO-CODECONNECTIONS 재판정 — CodeConnections 는 self-managed 의 선택지가 아니었다**
>
> **실측**: `argoproj/argo-cd` **v3.5.0** `docs/operator-manual/declarative-setup.md` 전수 검색 →
> `codeconnections` **0건** · `codecommit` **0건**. `awsAuthConfig` 는 있으나 **cluster secret 전용**
> (`clusterName`·`roleARN`·`profile`)이고 **repository 용이 아니다.**
> ⇒ self-managed repository 인증은 표준 git 뿐: username/password · sshPrivateKey ·
> **GitHub App**(`githubAppID`·`githubAppInstallationID`·`githubAppPrivateKey`) · bearerToken 등.
>
> **결정**: 관리형 = CodeConnections(§1 유효) · **self-managed = GitHub App**.
> ⛔ **CI 용 App(D20)을 재사용하지 않는다 — 별도 발급.** 다른 주체·다른 blast radius이고,
> 키를 공유하면 **클러스터 침해가 CI 소싱 권한으로 번진다.**
> 🔑 **자격증명 공유는 *단순함* 이 아니라 *결합* 이다** — "가장 단순한 형태"가 옹호하는 대상이 아니다.
> 🔴 **§1 의 driver(*"장기 자격증명을 만들지 않는다"*)를 self-managed 는 달성할 수 없다.** 숨기지 않고 적었다.

> ### 📌 **재사용할 질문 — "우리가 고른 것인가, 그 서비스가 준 것인가"**
> `30 §1` 은 CodeConnections 를 **우리가 고른 것처럼** 서술했지만 실은 **관리형이 준 것**이었다.
> 경로가 하나일 때는 그 차이가 드러나지 않는다.
> ⇒ **관리형 전제 위의 결정을 재판정할 때 이 질문을 먼저 던진다.** 후자면 다른 경로엔 **선택지가 없을 수 있다.**
> ⭐ `23 §2.1` 의 *"upstream 이 있다 ≠ 쓸 수 있다"* 와 같은 형태의 함정.

> ### ⚠️ **정정 — `30 §1` 표의 "클러스터에 평문" 은 이 클러스터에 부정확**
> 실측: `eks-ref-dev-an2-main-01` 의 `encryptionConfig` 에 `resources:["secrets"]` + KMS `keyArn` **실재**.
> 🔑 그런데 **`modules/eks-cluster` 의 `.tf` 에 `encryption` 이 한 줄도 없다** —
> upstream `terraform-aws-modules/eks` 가 **기본으로 켠다**. ⭐ **D-NODE-ARCH 와 같은 형태**
> (*facade 가 안 넘길 뿐 upstream 엔 처음부터 있었다*).
> ⇒ 위험도는 *"평문 상주"* 가 아니라 **"KMS 로 암호화된 장기 자격증명 상주"**. ⚠️ 그래도 0 은 아니다.

> ### 🆕 **갈림점이 5개가 아니라 6개였다** (`21 §1.7` 정정)
> **6번째 = 저장소 접근.** 초판이 놓친 이유: 그것이 `30 §1` 에 **관리형 전제로 숨어** 있었다.
> 📌 **갈림점 목록은 완결이 아니다** — 각 경로를 실제로 설계하면 더 나온다.
> 🔑 **1·3 은 같은 뿌리**임도 드러났다: *"ArgoCD 가 클러스터 안에 있는가"* —
> self-managed 는 내부 워크로드라 **Access Entry 도 `in-cluster` 명시 등록도 불필요**하다(`30 §4.1`).

**`30 §4.1` seed 경로 분기** — self-managed 는 **단계가 하나 늘고 하나 줄어든다**:
`0` helm install **신규** · `1` Access Entry **불필요**(hub) · `2` 저장소 접근이 TF→**kubectl seed** 로 이동 ·
`6` 에서 **argocd chart 자체도 흡수**.
⭐ **자기소멸 원칙이 helm values 에도 걸린다** ⇒ ⛔ **seed 절차서에 `--set` 을 쓰지 않는다.**

> ### 🔴 **자기 정정 — 4단계(cluster Secret)를 "불필요"로 쓴 것은 틀렸다** (같은 날 정정)
> **연결** 관점에서만 맞고 **팬아웃** 관점에서는 필요하다. PoC 구현체 실물이 잡아줬다:
> `addons/aws-load-balancer-controller.yaml` 의 ApplicationSet 이 **cluster Secret 의 라벨**을 읽는다
> (`matchLabels:{environment:dev}` · `{{name}}`→ALBC `clusterName` · `{{metadata.labels.vpcId}}`).
> ArgoCD 내장 `in-cluster` 는 **Secret 도 라벨도 없다** ⇒ 팬아웃이 아예 안 되고
> `{{name}}` 이 `in-cluster` 가 되어 **ALBC 에 틀린 clusterName 이 들어간다.**
> ⇒ self-managed 의 4단계는 **"등록"이 아니라 "라벨과 이름"** 을 위해 존재한다.
> `server` = **`https://kubernetes.default.svc`**. ⛔ helm `configs.clusterCredentials` 가 아니라
> **매니페스트로 둔다**(spoke 와 같은 방식이어야 한다 — D-SPOKE-SEAM).
> ⚠️ **apply 확인 필요**: 그 Secret 이 내장 in-cluster 를 대체하는지/중복인지 문서에 서술이 없다.
>
> 📌 **재사용할 절차: 어떤 산출물을 없앤다고 판단하면 그것을 참조하는 곳을 먼저 grep 한다.**
> 이번 오판은 `21 §1.2 ⑥`(관리형 서술)을 **뒤집어 읽기만** 하고 **소비자를 안 봤기** 때문이다.
> ⭐ 설계 문서만 봤으면 못 잡았다 — **PoC 구현체 실물이 잡았다.**

> ### 📌 **규칙 일반화 — 설계 문서 인용 시 항상 절 번호를 쓴다**
> 처음엔 `21` 하나라 "예외"로 적었는데 `30` 을 부분 개정하자마자 **둘**이 됐다.
> ⇒ 절 단위 판정은 예외가 아니라 **부분 개정이라는 작업 방식의 자연스러운 결과**다.
> `design/AGENTS.md` 에 일반 규칙으로 승격했다.

#### ✅ **플랫폼 GitOps repo 신설 완료** (2026-08-07) — 🆕 **세 번째 repo**

**`skax-ca/iac-platform-gitops`**(private, Team `iac` `maintain`). 로컬 `~/born2k/ai/iac-platform-gitops`.
초기 커밋 `18d0346` — **seed 3종**(`30 §4.1` 3·4·5단계). ⚠️ **아직 apply 되지 않았다.**

```
projects/platform.yaml                                   # seed 3
clusters/dev/eks-ref-dev-an2-main-01/cluster-secret.yaml # seed 4
bootstrap/root-app.yaml                                  # seed 5
```

**📚 PoC 구현체 `silverte/eks-platform-gitops` 를 참조했다** — ⚠️ **PoC repo 와 같은 지위(동결)**,
고치지 않고 참조만. 재사용성 판정은 `30` 헤더 상자.
- **승계(경로 무관)**: root-app 의 `recurse`+`exclude` · `prune:false` · finalizer 없음 ·
  `default` AppProject 미사용 · **cluster Secret 이름 = 실제 EKS 클러스터명**(별칭 쓰면 조용히 틀림) ·
  `project` 필드 함정(어긋나면 클러스터 `unknown` 인데 증상이 원인을 안 가리킴)
- **바꾼 것(self-managed)**: `server` EKS ARN→**`https://kubernetes.default.svc`**(Secret·destinations 둘 다) ·
  `repoURL` CodeConnections→**GitHub URL**(인증은 GitHub App) · `exclude` 중괄호 제거(패턴 1개)

**시작값을 좁게** — `clusterResourceWhitelist: []` · `sourceRepos` 는 이 저장소 하나.
**addon 증분마다 필요한 것만 연다**(그때마다 리뷰 지점).

**실측 좌표**(2026-08-07 · profile `team` · `533616270150` · apn2):
`eks-ref-dev-an2-main-01`(k8s **1.35**) · VPC **`vpc-00e16675363a702a5`** ·
Karpenter node role **`Karpenter-eks-ref-dev-an2-main-01-66112745ef9ad44d7260570055`**(60자<63) ·
소비 루트는 `enable_karpenter=true` · `enable_alb_controller_iam=true`.

**검증**: YAML 3/3 · **매니페스트 상호 참조 정합성 11/11**(project 일치 · destinations 포함 ·
sourceRepos 포함 · `metadata.name==stringData.name` · 라벨 길이 · `prune:false` · finalizer 없음).
⚠️ **apply 판정 2건 남음**: ① `kubernetes.default.svc` Secret 이 내장 `in-cluster` 를 대체하는지
(argo-cd v3.5.0 문서에 서술 없음 — `argocd cluster list` 로 판정) ② GitHub App 설치 범위 포함 여부.

#### ✅ **`50` 개정 — D31 신설: GitOps 배포 루트를 만들지 않는다** (2026-08-07)

> ## ⛔ **판정: `live/cicd/` 를 만들지 않는다. 이름도 지금 정하지 않는다.**
>
> **근거 ① 소유할 리소스가 0개다**(self-managed 실측):
> GitHub App private key = **k8s Secret**(IaC 아님) · ArgoCD 의 AWS 접근 = **요구 0**(GitHub+public helm) ·
> **ALBC·Karpenter IAM 은 이미 `live/dev/eks` 가 소유**(`enable_*=true` 실측) · spoke Access Entry = 클러스터 1개라 없음
> ⇒ 만들면 **`.tf` 가 한 줄도 없는 빈 자리**가 된다.
> **근거 ② D22 가 이미 같은 기준을 세웠다** — *"검증할 것이 없는 빈 자리는 만들지 않는다(YAGNI)"*.
> **근거 ③ `cicd` 컴포넌트의 실체가 없다** — PoC 의 `live/cicd/` 는 **hub-spoke**(hub 가 별도 계정·컴포넌트)
> 전제였다. 지금은 **dev 클러스터 하나에 ArgoCD 가 얹힌다.**

> ### ⭐ **선례 — `workbench`**
> `40` 이라는 **자기 설계 문서**와 **자기 모듈**이 있는데도 별도 루트가 아니라
> **`live/dev/eks` 안의 `module "workbench"`** 다(실측 `live/dev/eks/main.tf:124`).
> 🔑 **"설계 문서가 있다"가 "배포 루트가 필요하다"를 뜻하지 않는다.**
> 이 repo 의 문서 번호(`10`·`20`·`40`·`50`)와 소비 repo 의 디렉토리는 **다른 축**이다.

**재검토 조건 3개**(그때 생기는 IaC): **관리형 전환**(`awscc_eks_capability`+capability role) ·
**두 번째 클러스터**(spoke Access Entry + assume role) · **ArgoCD 의 AWS 접근**(ECR·Secrets Manager IRSA).
📌 **재검토 시 물을 순서**: ① *"어디에 넣나"* — **기본 가정은 `live/dev/eks` 확장**(workbench 선례)
② 새 루트 근거는 **state blast radius** ③ 그때 이름을 정한다 —
⛔ **`gitops-hub` 를 기본값으로 삼지 않는다**(hub-spoke 전제를 담은 이름이라 구조를 잘못 설명한다).

⚠️ **`21 §2.8`·`30 §4` 의 `live/cicd/gitops-hub` 표기는 PoC 시절 서술**이고 `50` 이 채택한 적 없다.
**배포 루트의 SSOT 는 `50`**(D26). 두 문서에 부인 상자를 달았다.

#### ✅ **GitHub App 발급 + seed 스크립트 작성** (2026-08-07)

**App**: `skax-ca-gitops-reader` · **app_id `4512318`** · owner `skax-ca` ·
`permissions {contents:read, metadata:read}` · `events []`(webhook 없음) — **API 로 규격 검증 완료**.
key: **`~/.config/gh-apps/skax-ca-gitops-reader.pem`**(⛔ 어느 repo 에도 두지 않는다).
발급 시 위치는 `~/Downloads/…2026-08-06.private-key.pem` 이었으나 **TCC 때문에 옮겼다**(아래 D-KEY-TRANSFER).
✅ **설치 완료**(2026-08-07 확인) — **`installation_id = 151838919`** ·
`selection=selected`(⇒ *All repositories* 아님) · perms/events 규격대로.
⚠️ **설치된 repo 목록 자체는 이 토큰으로 조회 불가**(app JWT 또는 `read:user` 스코프 필요) —
`iac-platform-gitops` 포함 여부는 **seed 실행 때 드러난다**(아래 apply 판정 ③).

**GitOps repo** `d118838` — `bootstrap/argocd-values.yaml` 신설(dex off · notifications off,
**기본값과 다른 것만** 적음) + root-app `exclude` 를 `{clusters/**/values.yaml,bootstrap/argocd-values.yaml}` 로.

**스크립트**: **`scripts/argocd-seed.sh`** + `scripts/README.md`(런북). `23` 열린항목 5 해소.
⚠️ `30 §4` 가 예고한 `docs/runbooks/` 는 **폐기** — 절차가 실행 가능하므로 `scripts/` 가 맞다.
🔑 **재사용 자산이라 환경값을 전부 파라미터로** 받는다(`01 §4`).

> ### 📌 **실측으로 잡은 것 3건** (전부 문서·주석에 근거를 남겼다)
> 1. 🔴 **`kubectl --dry-run=client` 는 오프라인이 아니다.** `--validate=false` 를 줘도
>    **CRD(AppProject·Application) 는 RESTMapping 에 discovery API(`/api`) 가 필요**해 VPC 밖에서
>    `unable to recognize ... i/o timeout`. ⇒ **dry-run 에서 kubectl 을 아예 부르지 않는다** —
>    역할을 *"무엇을 어디서 적용하는지 보여주기"* 로 좁혔고, 진짜 검증은 실행 경로의 `--dry-run=server`.
> 2. **`want N && cmd` 패턴** — `set -e` 아래에서 **조기 종료는 없다**(내 최초 판단은 틀렸다).
>    실제 영향은 **그 줄이 마지막이면 종료 코드가 1** 이 되는 것 → `--to 4` 성공이 호출자에게
>    실패로 보인다. ⇒ `if` 블록으로. (실측: `--from 3 --to 4` → exit 0)
> 3. **이 셸은 zsh 다** — 테스트에서 `$args` 가 단어 분리되지 않아 `--to 0` 이 토큰 하나로 갔다.
>    스크립트 결함이 아니라 **테스트 하네스 문제**였다. ⇒ bash 스크립트를 zsh 로 테스트할 때 주의.

⚠️ **게이트 공백**: `scripts/` 는 pre-commit 도 `verify.yml` 도 **검사하지 않는다**(실측).
지금은 사람이 `bash -n` 하는 것이 유일한 방어. 📌 `verify.yml` 에 `bash -n`/shellcheck 추가 제안 —
⛔ 워크플로 변경은 **브랜치 → PR** 이라 별도 태스크. 🔑 **게이트를 추가하는 순간 `scripts/` 도
브랜치 → PR 대상이 된다**(브랜치 규칙의 기준이 *"CI 가 머지 전에 막아야 하는가"* 이므로).

#### 🎉 **seed 실행 완료 — ArgoCD 부트스트랩 성공** (2026-08-07)

`argocd-seed.sh` 5단계 전부 적용됐다. 실행은 **`aws ssm send-command`** 로 했다(대화형 SSM 세션 없이).
⚠️ **키는 절대 send-command 로 보내지 않았다** — 파라미터가 평문으로 히스토리·CloudTrail 에 남기 때문이고,
D-KEY-TRANSFER 가 *"workbench 가 스스로 Parameter Store 에서 당긴다"* 로 설계된 이유가 이것이다.

**판정 결과** (`kubectl` 실물 조회):

| 판정 | 결과 |
|---|---|
| ① `root-app.status.sync.revision` | ✅ **`d11883864fc6091fde69f97cc044b61fdfa9937a`** = 저장소 HEAD 와 **완전 일치**. `main` 아님 |
| ② sync/health | ✅ `Synced Healthy` · `.status.conditions` **비어 있음** |
| ③ cluster Secret 이 내장 `in-cluster` 를 대체하는가 | ⚠️ **절반만 확인** — 아래 |
| ③-b GitHub App 설치 범위 | ✅ **`total_count=1` · `skax-ca/iac-platform-gitops` 하나** (installation token 으로 `GET /installation/repositories` 직접 조회) |
| pods | ✅ 5개 전부 Running (controller·applicationset·redis·repo-server·server) |

> ### ⭐ **①이 자기소멸 원칙의 작동 증거다** — 재사용할 판독법
>
> revision 이 실제 SHA 이고 저장소 HEAD 와 같다는 것은 "읽었다"만 뜻하지 않는다.
> **손으로 apply 한 것과 root App 이 흡수한 것 사이에 차이가 0** 이라는 뜻이다 —
> 차이가 있었다면 `OutOfSync` 로 드러났을 것이다. 🔑 **`Synced` 는 자기소멸 원칙의 자동 검사다.**
> ⚠️ notepad 가 경고한 *"`main` 이면 아직 설정값"* 전례(PoC)는 이번엔 재현되지 않았다.

> ### ⚠️ **판정 ③ 을 "확인됨"으로 쓰지 않는다** — 절반만 봤다
>
> cluster Secret 은 `eks-ref-dev-an2-main-01` → `https://kubernetes.default.svc` 하나이고
> root-app 이 그 URL 을 target 해 `Synced` 이므로 **해석은 된다.** 하지만
> *"내장 `in-cluster` 를 **대체**했는가, **중복**인가"* 는 `argocd cluster list` 나 UI 로만 보인다.
> ⇒ 이것이 정확히 **`40` 열린 항목 7(`argocd` CLI 핀)** 이 필요한 이유다. 그때 판정한다.

#### 🔴 **seed 과정에서 드러난 설계 공백 4건** — 전부 지금은 수동 우회 상태다

⚠️ **수동으로 넣은 것은 인스턴스 교체 시 전부 사라진다.** 지속 해결은 아래 각 항목이 소유한다.

| # | 공백 | 실측 | 귀속 |
|---|---|---|---|
| 1 | **workbench 에 `git` 이 없다** | 모듈에 변수조차 없음. GitOps seam 은 클론을 전제하는데 | `modules/workbench` **`.tf` → 브랜치·PR** |
| 2 | `helm` 미설치 | `helm_version` default=`null`, 소비 repo 가 미지정. **모듈 결함 아님** | 소비 repo `iac-reference-infra` |
| ~~3~~ | ~~**`23 §5` 에 helm CLI 핀 없음**~~ | ✅ **해소**(2026-08-07) — `helm v3.21.3` 등재 + 근거·재검토 조건. `docs/README.md` 상태표도 갱신 | ✅ 완료 |
| ~~4~~ | ~~**workbench 의 private repo 접근 미설계**~~ | ✅ **설계 완료**(2026-08-07, **D-WORKBENCH-REPO** = `40 §2.5`, 사용자 결정) | ⛔ **`.tf` 구현은 대기** |

- **2 의 진짜 문제는 변수 설명이다**: `helm_version` 은 *"Day 2 운영 프로파일 B(`22 §3`)에서 쓴다"* 라고
  적혀 있는데, **`23` 이 self-managed 를 `helm install` 로 seed 하기로 하면서 helm 은 프로파일과
  무관하게 필수가 됐다.** 설명이 `23` 이전 세계를 기술하고 있다.
  ✅ **"무엇이 참인지"는 `23 §5` 가 기록했다**(2026-08-07). ⛔ 남은 것은 **변수 설명 정정**뿐이고
  `.tf` 변경이라 **브랜치 → PR**이다. 🔑 역할 분담: **문서가 참을 소유하고 모듈이 집행을 소유한다.**
- **이번에 넣은 것**: `git-core 2.50.1`(dnf) · **`helm v3.21.3`**(GitHub Releases arm64).
  ⚠️ **helm 최신은 `v4.2.3`(2026-07-09)이지만 일부러 v3 를 골랐다** — 차트 `argo-cd 10.3.0` 은
  helm 3 시대 산물이고, **최초 부트스트랩에 메이저 CLI 변경까지 겹치면 실패 시 원인이 둘로 갈린다.**
  🔑 이 근거는 `23 §5` 에 등재돼야 다음 사람이 고칠 수 있다(공백 3).
> ### ✅ **D-WORKBENCH-REPO — `40 §2.5` 신설** (2026-08-07, 사용자 결정)
>
> **GitHub App installation token 으로 GitOps 저장소를 클론** + **`argocd-seed.sh` 를 그 저장소
> `bootstrap/` 에 vendoring.** 부트스트랩 시점 한정이라 **상시 자격증명이 workbench 에 없다.**
> - 🔑 **한계비용 ≈ 0**: D-KEY-TRANSFER 상 **그 시점 App 키가 이미 workbench 에 있다.**
>   같은 저장소를 읽는 데 한 번 더 쓸 뿐 — 새 자격증명·IAM·버킷이 **0개**.
>   ⇒ `40 §2.4`(D-WORKBENCH-SCOPE)가 계약으로 못박은 **"자격증명 추가 없음"이 지켜진다.**
> - ⭐ **`30 §1.1` 의 기준을 다시 읽은 것이 판정의 핵심**: 그 조항이 CI 용 App 재사용을 금지한
>   진짜 이유는 *"주체가 다르다"* 가 아니라 **접근 가능 집합이 늘어난다**(모듈 저장소들)는 것이었다.
>   여기서는 대상·권한·목적이 전부 같아 집합이 늘지 않는다. ⛔ **역방향은 금지** —
>   `iac-module-library` 를 이 App 설치 범위에 넣지 않는다(ArgoCD 가 모듈 소스를 읽게 된다).
> - 🥚 **닭과 달걀**: 클론 헬퍼(JWT→token→clone)는 **클론 전에 필요해 vendoring 불가** ⇒ 런북 인라인.
>   성립 조건은 **짧을 것 · 비밀이 아닐 것**. ⚠️ 길어지면 **S3 안이 필요하다는 신호**다.
> - **`git` 은 변수 없이 항상 설치**로 정했다(`40 §4.1`). `kubectl`·`helm` 이 nullable 핀인 이유는
>   버전이 **클러스터·차트에 결합**되기 때문인데 `git` 은 배포판 패키지라 **핀할 값이 없다.**
>   같은 패턴을 기계적으로 복사하면 **선택지 없는 분기**가 생긴다(열린 항목 6 의 경고).
> - **기각**: deploy key(장기 자격증명 + SSH 라 `egress_cidr_blocks` 443 계약을 건드림) ·
>   `gh auth login`(개인 토큰이 공용 workbench 에 각인) ·
>   **S3 아티팩트**(⭐ 최유력 대안 — GitHub 자격증명 0 + SHA tarball 이라 dirty 원천 불가.
>   `s3:GetObject` IAM + 버킷 결정 비용 때문에 기각. **workbench 의 GitHub 접근을 금지하는
>   고객사가 나오면 이 안으로 전환**) · send-command 배달(페이로드 상한).
> - 📌 미개정 문서 `30 §1` 에는 **포인터 상자만** 남겼다 — `30 §5` 에서 쓴 관행 그대로다.

- **4 를 이번엔 이렇게 우회했다**: GitHub App installation token 으로 클론(JWT 를 workbench 에서
  `openssl` 로 서명 — `jq`·`openssl` 이 AL2023 에 기본 탑재라 가능했다). 토큰이 `.git/config` 에
  남지 않도록 클론 직후 `remote set-url` 로 정규화했다(실측 확인).
  ⚠️ **그 App 은 `iac-platform-gitops` 하나만 커버**하므로(위 ③-b) **`argocd-seed.sh` 자체는
  여전히 별도 경로가 필요**했다 — 이번엔 base64 로 send-command 에 실어 보냈다. 임시방편이다.

> ### 📌 **재사용할 실측 — `send-command` 는 `/etc/profile.d/` 를 읽지 않는다**
>
> workbench 의 kubeconfig 는 `/etc/kubernetes/kubeconfig` 에 두고 `/etc/profile.d/kubeconfig.sh` 로
> 전역 export 한다(사용자에 묶이지 않는 좋은 설계). 그러나 **`send-command` 는 로그인 셸이 아니라
> 그 파일을 읽지 않는다** — 매 명령에 `export KUBECONFIG=...` 를 명시해야 한다.
> ⚠️ 놓치면 *"클러스터에 못 닿는다"* 는 **잘못된 결론**이 난다.
>
> 그리고 다운로드 경로는 **`/tmp` 가 아니라 `/var/tmp`** 다 — `t4g.nano` 의 tmpfs 는 210MB 라
> `curl (23) Failure writing output` 로 죽는다(모듈 user-data 에 이미 기록된 PoC 실측). 그대로 재사용했다.

#### ⛔ **남은 완료 조건 1건 — 초기 비밀번호 교체 + `argocd-initial-admin-secret` 삭제**

`23 §2.3` 이 **선택이 아니라 완료 조건**으로 정했다. ⚠️ 아직 **하지 않았다.**
- 비밀번호는 **사용자가 정할 값**이라 내가 대신 정하지 않았다. 초기 비밀번호도 **조회하지 않았다**
  (조회하면 send-command 출력 경로로 CloudTrail·히스토리에 남는다).
- 경로: workbench 에서 `kubectl -n argocd port-forward svc/argocd-server 8080:443` →
  `https://localhost:8080`(자체 서명 경고 정상) → admin 로그인 → 변경 → Secret 삭제.
  🔴 **정정(2026-08-10)**: *"send-command 로는 터널이 안 선다"* 는 **틀렸다** — 인스턴스 안에서
  백그라운드 port-forward + 같은 스크립트의 CLI 호출로 `argocd-server: v3.5.0` 응답을 받았다.
  그 문장은 **운영자 노트북까지의 터널**을 두고 한 말이었다.
  ⛔ 그럼에도 **대화형 세션으로 한다** — 새 비밀번호가 send-command 파라미터에 평문으로 남기 때문이다
  (**기술 제약이 아니라 비밀 취급**).
- 또는 **`argocd` CLI v3.5.0**(`23 §5` 가 이미 핀함)을 넣어 `argocd account update-password`.
  ⇒ 이 경로를 택하면 **`40` 열린 항목 7 과 같은 작업**이 된다.

#### ✅ D-KEY-TRANSFER 완료 조건 이행 (2026-08-07)

- ✅ k8s Secret 에 키가 유효하게 들어간 것을 **지우기 전에** 확인(`openssl rsa -check` → `RSA key ok`).
  🔑 **순서가 반대였다면 복구 불가 상태를 만들 뻔했다.**
- ✅ `shred -u /root/gh-app.pem` — workbench 키 파기
- ✅ `aws ssm delete-parameter` — `ParameterNotFound` 로 확인

#### ~~⏭️ 다음 태스크 — **적용(seed 실행)**~~ ✅ **완료**(위 참조). 아래는 그때의 실행 계획이다

⚠️ **workbench 안에서** 실행한다(클러스터가 private — `40 §1`). 스크립트는 `iac-module-library` 에 있다.

```
export GITOPS_REPO_DIR=~/iac-platform-gitops        # 먼저 clone + pull (ArgoCD 는 원격을 읽는다)
export CLUSTER_DIR=clusters/dev/eks-ref-dev-an2-main-01
export GITOPS_REPO_URL=https://github.com/skax-ca/iac-platform-gitops.git
export GH_APP_ID=4512318
export GH_APP_INSTALLATION_ID=151838919
export GH_APP_PRIVATE_KEY=~/gh-app.pem              # workbench 안의 파일. 내려받는 법은 D-KEY-TRANSFER
./scripts/argocd-seed.sh --dry-run   # 먼저
./scripts/argocd-seed.sh
```
✅ **private key 전달 경로 확정 — D-KEY-TRANSFER**(2026-08-07, 사용자 결정).
**SSM Parameter Store SecureString.** 절차·근거·복구·기각안 전문은 **`scripts/README.md`** 가 소유한다
(`23 §6-5` 가 절차의 소유를 이미 런북에 위임했으므로 설계 문서를 늘리지 않았다).
- 🔑 **채택 근거는 IAM 변경이 0 이라는 실측**이다: `AmazonSSMManagedInstanceCore` 가
  `ssm:GetParameter` 를 **`Resource:"*"`** 로 주고, `alias/aws/ssm` 키 정책이
  `Principal:{"AWS":"*"}` + `ViaService` 로 **직접 부여**해 `kms:Decrypt` 도 불필요하다.
  ⇒ workbench Role 을 건드리지 않으므로 `.tf` 변경·PR 이 없다.
- 🔴 **seed 후 `delete-parameter` 는 완료 조건이다** — 같은 관리형 정책 때문에 그 파라미터를
  **계정의 SSM 관리 인스턴스 전부가 읽을 수 있다.** 남기면 blast radius 가 계정 전체다.
- 🔑 **복구는 보관이 아니라 재발급**이다(GitHub App 은 키를 복수로 발급·삭제할 수 있다) →
  `--from 2 --to 2` 로 2단계만 재적용. 그래서 삭제가 복구 가능성을 해치지 않는다.
- 기각: **세션 붙여넣기**(고객사는 세션 로깅을 켜 두는 것이 보통 → 키 전체가 로그에) ·
  **`send-command`**(파라미터가 평문으로 command 히스토리·CloudTrail 에) ·
  **Secrets Manager**(IAM 추가 필요 + 월 $0.40 — 같은 값을 더 비싸게 산다).

> ### 🔴 **macOS TCC 가 `~/Downloads` 를 막는다 — 이 머신의 실행 제약** (2026-08-07 실측)
>
> VS Code(`com.microsoft.VSCode`) 아래의 Claude Code 프로세스는 `~/Downloads` 에 대해
> **`open()` 도 `rename()` 도 거부**된다(`Operation not permitted`). ⚠️ **쓰기는 허용**된다 —
> 새 항목 생성은 되고 **기존 보호 항목의 접근만** 막는 게이트다.
> - ⚠️ **`stat` 은 통과한다** — `[ -e ]` 는 yes 인데 `open` 이 실패한다. 그래서 첫 `find` 의
>   glob 실패가 **"파일 없음"으로 오독**됐다. 🔑 **홈 디렉토리 탐색에서 stderr 를 버리지 말 것.**
> - ⇒ 키를 **`~/.config/gh-apps/`** 로 옮긴다(이 머신의 기존 관행 — `skax-ca-module-reader.pem`
>   1679B·0600 이 거기 있다). 이동은 **Terminal.app 에서** 실행해 TCC 프롬프트를 허용해야 한다.
> - 📌 부수 확인: 그 sibling 키가 **1679 바이트** = GitHub App RSA 2048 PEM 의 실측 크기.
>   Parameter Store **Standard tier(4KB) 안**이라 과금 없음.
   ⚠️ **apply 판정 3건**: ① `root-app` 의 `.status.sync.revision` 이 **실제 SHA** 인가
   (`main` 이면 아직 설정값 — PoC 가 성급히 성공으로 읽은 전례) ② `kubernetes.default.svc` Secret 이
   내장 `in-cluster` 를 대체하는지(`argocd cluster list`) ③ GitHub App 설치 범위 포함 여부.
   ⛔ 마지막에 **초기 비밀번호 교체 + `argocd-initial-admin-secret` 삭제**(완료 조건이다).
3. 그 뒤 `addons/` 증분 → `24`(관리형) → `40` 열린항목 7(`argocd` CLI 핀, 근거는 `23 §5` 확정)

#### ✅ **`workbench-v0.2.0` 릴리스 완료** (2026-08-10) — PR [#15](https://github.com/skax-ca/iac-module-library/pull/15) 머지 `782f710`

브랜치에서 커밋 4개로 작업(분리 유지: git 설치+T-9 / helm 설명 / 문서 정합 / notepad) 후 squash 머지.
**CI run [`31344989804`](https://github.com/skax-ca/iac-module-library/actions/runs/31344989804) 게이트 6/6** —
modules 44 tests(eks 20·vpc 13·**wb 11**) · examples 2 validate · lock registry 혼입 0.
🔑 **로컬 훅과 CI 가 같은 숫자를 냈다** — 도구 버전을 양쪽에 핀해 둔 이유가 이것이다.

> ### 🔑 **재사용할 실측 3건** — 이번에 처음 확인한 것
>
> ① **`templatefile()` 은 셸 주석도 파싱한다.** 주석 안에 `%{ if }` 를 **인용만 해도**
> 진짜 지시자로 해석돼 `Invalid expression` 이 난다. 이스케이프(`%%{`)보다 **그 문법을 주석에
> 쓰지 않는 쪽**이 낫다 — 다음 사람이 같은 함정을 밟는다.
> ② ⭐ **plan 단계에서 `user_data` 는 원문 그대로 보인다.** `strcontains` 로 내용 판정이 된다
> ⇒ **T-9** 가 그 위에 섰다. ⚠️ `40 §7.1` 의 *"미지정을 계약으로 삼는 항목은 plan 으로 못 지킨다"*
> 를 여기까지 넓히면 틀린다. 안 되는 이유는 *"plan 이라서"* 가 아니라 **모킹이 값을 지어내기
> 때문**이고, `user_data` 는 우리가 계산해 넣는 값이라 지어낼 여지가 없다. **경계는 거기다.**
> ③ **trivy 를 훅과 다른 플래그로 돌리면 거짓 실패가 난다.** `--ignorefile .trivyignore.yaml`
> `--tf-exclude-downloaded-modules` 를 빼면 **upstream EKS 모듈 코드**까지 스캔해 exit 1 이 된다.
> 🔑 게이트를 손으로 재현할 땐 `.githooks/pre-commit` 의 명령을 **그대로** 복사한다.

**설계 문서에서 잡은 것 2건** (구현하다 드러난 defect — 코드가 아니라 기록의 결함)

| 지점 | 무엇이 틀렸나 |
|---|---|
| `40 §2.5` 귀결 상자 | *"nullable 패턴으로 열어야 한다"* ↔ `§4.1` *"변수 없이 항상 설치"* — **같은 날 쓰인 두 절이 정반대**였고 구현은 §4.1을 따랐다. §2.5를 **기각 기록**으로 바꿨다 |
| `examples/eks-cluster-enterprise/README.md` | *"태그가 낡은 채 복사되면 굳는다"* 고 **경고해 놓고 자신이 걸려 있었다**(`eks-cluster-v0.2.0`·`v0.3.0` ← 현행 v0.4.0). 🔑 **경고문은 갱신을 강제하지 못한다** |

> ### ⚠️ **머지 후 소비 repo 에서 일어날 일 — 인스턴스가 교체된다**
>
> `user_data_replace_on_change = true`(모듈 `main.tf:118`) 라서 `?ref` 를 올리면
> plan 에 **`# forces replacement`** 가 뜨고 workbench 가 destroy/create 된다. **의도된 계약**이다
> (user_data 는 부팅 시에만 실행되므로 in-place 갱신은 *"코드와 실물이 다른"* 상태를 만든다).
>
> | 유지 | 사라짐 |
> |---|---|
> | IAM role·instance profile ⇒ **Access Entry(2층) 그대로** | `git` → ✅ 이번 커밋이 자동화 |
> | SG ID ⇒ **cluster SG ingress(3층) 그대로** | `helm` → ⚠️ **소비 repo 가 `helm_version` 을 안 준다** |
> | kubeconfig(user-data 가 재생성) | `argocd-seed.sh` → ⚠️ **태스크 2(vendoring)** 가 소유 |
>
> ⛔ **태스크 2 전에 소비 repo 를 apply 하지 말 것** — 재생성된 workbench 에 seed 스크립트가 없어
> base64 배달 임시방편을 반복하게 된다. 🔴 그리고 **재생성 중에는 클러스터 도달 경로가 끊긴다**
> (public endpoint 가 닫혀 있어 workbench 가 유일한 도달 지점). ArgoCD 는 클러스터 안에서
> 자율로 도므로 영향 없다.

> ### 📌 **소비 repo 에 남은 작업 — `helm_version` 을 켜야 한다** (공백 2 의 실체)
>
> `iac-reference-infra/live/dev/eks/main.tf` 가 *"GitOps(pull) 전제라 helm 직접 운영이 현재 요구가
> 아니다"* 라는 **낡은 근거로 helm 을 명시적으로 끄고 있다.** `23` 이 seed 를 `helm install` 로
> 정하면서 그 전제가 뒤집혔다. ⇒ `helm_version = "v3.21.3"`(`23 §5` 핀) 을 넣는다.
> 🔑 이 repo 는 2026-08-10 에 **변수 설명과 예제를 참에 맞췄다** — 집행은 소비 repo 몫이다.

#### ✅ **`argocd-seed.sh` vendoring 완료** (2026-08-10) — `iac-platform-gitops` `ba9d079`

D-WORKBENCH-REPO 결정 ② 이행. 사본 = `bootstrap/argocd-seed.sh`. **SSOT 는 이 repo 의
`scripts/argocd-seed.sh`** — ⛔ 사본을 편집하지 않는다. 절차는 **`scripts/README.md` 「vendoring」 절**이 소유.

> ### 🔑 **재사용할 판단 3건**
>
> ① **"출처 태그"는 커밋 SHA 로 이행했다.** `scripts/` 에는 **태그 축이 없다** — 태그는 모듈별
> semver 이고 이 스크립트는 `?ref=` 로 소싱되지 않는다. 새 축을 발명하지 않았다.
> 🔁 사본이 여러 고객사 저장소로 늘면 그때 재검토.
> ② ⭐ **배너를 붙이면 *"편집하지 않았다"* 를 검증할 수 없게 된다**(바이트가 달라지므로).
> ⇒ 배너 **모든 줄에 `#V#` 접두** → 검사가 한 줄: `diff <(grep -v '^#V#' <사본>) scripts/argocd-seed.sh`.
> **규칙은 검사할 수 있어야 규칙이다** — 아니면 권고에 그친다.
> ③ **root App `exclude` 에 `.sh` 를 넣지 않았다.** ArgoCD directory 소스는 `.yaml`·`.yml`·`.json`
> 만 읽는다(공식 문서 확인 — 추정하지 않았다). 스캔도 안 되는 것을 제외하면 **죽은 설정**이고
> 다음 사람이 *".sh 도 스캔된다"* 로 잘못 읽는다. `argocd-values.yaml` 이 제외된 이유는
> **그것이 `.yaml` 이라 실제로 스캔되기 때문** — 둘의 차이가 거기 있다.

⚠️ **gitops repo README 도 낡아 있었다**(세 번째 repo에서 같은 실패 유형 재현):
*"seed 3종 작성 완료 — 아직 적용되지 않았다"* 가 남아 있었다. 2026-08-07 에 실제로 적용됐다.
정정 + 판정표 + 남은 완료 조건(비밀번호 교체)을 등재했다.

#### ✅ **`argocd` CLI 추가 — `40` 열린 항목 7 해소** (2026-08-10, 브랜치 `feat/workbench-argocd-cli-v0.3.0`)

설계 먼저(`4996f15`, 문서 전용 · main 직접) → 구현(브랜치). **열린 항목 7 을 닫고 결정 본문을
`§4.1` 상자·`§4.3`·`§7.1` 로 승격**했다 — 열린 항목에 결정을 남겨 두지 않는다.

> ### ⭐ **왜 지금이었나 — 교체를 한 번으로 묶는다**
>
> `workbench-v0.2.0` 업그레이드는 어차피 **인스턴스를 교체**한다(`user_data_replace_on_change`).
> `argocd` CLI 를 같이 넣으면 소비 repo 가 교체를 **한 번만** 겪는다. 따로 하면 두 번이다.
> 🔑 그리고 **4번이 3번을 쉽게 만든다**: `argocd account update-password` 경로가 열려
> **브라우저 UI 의존과 운영자 노트북까지의 터널이 사라진다.** 🔴 **port-forward 자체는 남는다** —
> `argocd-server` 가 `ClusterIP` 라 CLI 가 있어도 필요하다(2026-08-10 정정).

> ### 🔑 **재사용할 판단 2건**
>
> ① **`git`(T-9)과 `argocd`(T-10)는 정반대 계약이고 그게 맞다.** 가르는 기준은
> **"소비자가 고를 값이 있는가"** 다 — argocd 는 chart appVersion 에 결합(`23 §5`), git 은
> 배포판 패키지라 핀할 값이 없다. 같은 파일에 두 형태가 공존하는 것이 실수가 아니다.
> ② ⚠️ **음성 확인의 방법이 중요했다.** 가드(`%{ if ... }`)를 제거하는 방식은 **신호가 흐리다** —
> `templatefile` 이 null 보간에서 죽어 테스트 실패가 아니라 **하드 에러**가 난다.
> 즉 *"미설치가 기본"* 의 일부는 **템플릿 구조가 이미 강제**한다. ⇒ 테스트가 실제로 잡는 회귀는
> **누가 변수에 `default` 를 넣는 것**이고, 그 형태로 음성 확인했다(실패 확인 → 복원 → 13 passed).
> 🔑 **"무엇이 이 테스트를 깨뜨리는가"를 먼저 정하고 그 방식으로 음성 확인한다.**

📌 **도구 3개를 일반화하지 않았다** — `dl.k8s.io` 단일 · `get.helm.sh` tarball ·
GitHub Releases 단일. 맵으로 묶으면 tarball 분기가 템플릿 안으로 **숨을 뿐** 줄지 않는다.

#### 🔴 **`workbench-v0.3.0` apply 부분 실패 → `v0.4.0`(D-WORKBENCH-SIZE)** (2026-08-10)

소비 repo apply run [`31352399365`](https://github.com/skax-ca/iac-reference-infra/actions/runs/31352399365)
= `1 added, 0 changed, 1 destroyed` — **replace 는 인스턴스 1개뿐**이었고 IAM·SG 는 목록에 없었다
⇒ Access Entry(2층)·cluster SG ingress(3층) 유지 예측 실증. kubeconfig 는 **첫 시도에 성공**.

| 결과 | |
|---|---|
| ✅ `kubectl v1.35.7` · `helm v3.21.3` · `argocd v3.5.0` | 전부 자동 설치 — **helm·argocd 목표 달성** |
| ❌ **`git` 미설치** | 부팅 중 `dnf` 가 **OOM-kill** 됐다 |

> ### ⭐ **가장 값진 교훈 — T-9 는 통과했는데 실행이 실패했다**
>
> T-9 는 *"`user_data` 에 `dnf install -y git-core` 가 있는가"* 를 보고 **통과했다.**
> 계약은 맞았고 실행이 실패했다. **plan 은 문자열까지만 보고 그 문자열이 512MB 머신에서
> 무슨 일을 하는지는 모른다.**
> ⇒ 이 repo 가 `plan` 까지만 판정하고 **apply 판정을 소비 repo 에 두는 분업이 형식이 아니다.**
> ⛔ *"`tofu test` 가 통과했으니 동작한다"* 고 쓰지 않는다.

> ### 🔑 **재사용할 실측 2건**
>
> ① **`free -m` 의 swap 은 여유가 아닐 수 있다.** AL2023 의 swap 실물은 **`/dev/zram0`** —
> RAM 을 압축해 쓰는 것이라 **용량이 늘지 않는다.** "swap 417MB 인데 왜 OOM 인가"로 오독하기 쉽다.
> 판정은 `swapon --show` 로 한다.
> ② **`dnf` 하나가 `total-vm 976MB` 를 요구한다.** t4g.nano(0.5GB)에서는 부팅 중 반드시 죽는다.
> ⚠️ 2026-08-07 에 **손으로는 성공**했었다 — 그때는 시스템이 유휴였기 때문이다.
> 🔑 **"수동으로 됐으니 자동으로도 된다"가 성립하지 않는 지점**이다(부팅 중 경합).

**결정(사용자)**: *"비용만 생각하지 말고 적정한 인스턴스 타입으로 전환도 고려하라."*
⛔ swapfile·재시도 우회를 짜지 않았다 — 메커니즘만 늘고 근본은 남는다.
⇒ **기본 `instance_type` = `t4g.small`(2GB)**. Price List API 실측(Seoul):
nano $3.8 · micro $7.6 · **small $15.2** · medium $30.4. `§9` 비용표 월 $5 → 약 $17.
- **micro(1GB)를 고르지 않은 이유**: dnf 는 통과하겠지만 helm 렌더링·kubectl·로그 조회가 겹치는
  **실제 운영**에서 다시 아슬아슬하다. **부팅만 통과시키는 크기는 "적정"이 아니다.**
- 📌 부수 효과: `/tmp` tmpfs 는 RAM 의 절반이라 2GB 에서 약 1GB — **원래의 `curl (23)` 함정이
  사라진다.** `/var/tmp` 는 유지한다(소비자가 타입을 내리면 함정이 돌아온다).
- 📌 부수 수정: 부팅 로그의 `argocd version --client` 가 `$HOME is not defined` fatal 을 찍었다.
  **설치 실패가 아니다**(바이너리 정상) — cloud-init 에 `$HOME` 이 없을 뿐. `HOME=/root` 를 붙였다.
- **T-11 신설** — 지키는 것은 "OOM 이 안 난다"가 아니라 **결정이 조용히 되돌아가지 않는 것**이다.
  가장 그럴듯한 회귀는 *"비용을 줄이려고 기본값을 내리는 변경"* 이다.

#### ✅ **`workbench-v0.4.0` apply 판정 — 전부 통과** (2026-08-10, run [`31353547193`](https://github.com/skax-ca/iac-reference-infra/actions/runs/31353547193))

`1 added, 0 changed, 1 destroyed`(다시 replace 는 인스턴스 1개뿐).
**`git version 2.50.1`** ✅ · `kubectl v1.35.7` · `helm v3.21.3` · `argocd v3.5.0` ·
메모리 총 1846MB/available 1544MB · **OOM 0건** · 노드 2개 Ready · root-app `Synced Healthy`.

> ### ⏱️ **부팅이 3분+ → 32초로 줄었다**
>
> 도구가 하나 늘었는데 더 빨라졌다 — 늘어난 시간의 정체는 **`dnf` 가 메모리를 구하지 못해
> 헤매던 시간**이었다. 🔑 **OOM 은 "죽는 것"만이 아니라 "죽기 전까지 느려지는 것"으로도 나타난다.**

> ### 🔑 **재사용할 실측 2건**
>
> ① **`t4g.small` 에는 zram swap 이 아예 없다**(`Swap: 0`). AL2023 은 **저메모리 인스턴스에만**
> zram 을 켠다(`t4g.nano` 에는 `/dev/zram0` 418MB 가 있었다). ⇒ *"swap 이 사라졌으니 나빠졌다"* 가
> 아니라 **압축 swap 이 필요 없을 만큼 실제 RAM 이 생겼다**는 뜻이다.
> ② 🔴 **`argocd admin ...` 에 `-n argocd` 를 빠뜨리면 `argocd-cm 을 찾을 수 없다`** 는 경고가 난다.
> **설정 공백이 아니라 네임스페이스 누락**이다 — 실제로 한 번 오독했다.

> ### ✅ **덤으로 `30` 판정 ③이 닫혔다**
>
> `argocd admin cluster stats -n argocd` → 서버 항목이 **`https://kubernetes.default.svc` 하나뿐**
> (Successful · apps 1 · resources 536). ⇒ cluster Secret 이 내장 `in-cluster` 를 **대체했다.
> 중복이 아니다.** 2026-08-07 에 `kubectl` 만으로 절반만 판정됐던 항목이다.
> ⚠️ **`argocd login` 없이 닫았다** — `argocd admin` 은 API 서버가 아니라 **k8s 를 직접 읽는다.**
> 초기 비밀번호를 조회하지 않고도 판정할 수 있었던 이유다.

#### 🔚 **2026-08-10 세션 핸드오프**

**한 세션에 릴리스 3개**(`workbench-v0.2.0`·`v0.3.0`·`v0.4.0`) + vendoring + 소비 repo apply 2회.
⭐ **workbench 의 수동 설치 부채가 0 이 됐다** — `git`·`kubectl`·`helm`·`argocd` 4종이 `user_data` 로,
seed 스크립트는 GitOps 저장소 vendoring 으로 넘어갔다.

| repo | 결과 |
|---|---|
| `iac-module-library` | PR #15·#16·#17 · 태그 `workbench-v0.2.0`~`v0.4.0` · `40` 대폭 개정(§2.5·§4.1·§4.3·§7.1·§7.3-3·§7.3-4·§9) |
| `iac-platform-gitops` | `ba9d079` vendoring · `65a5b3e` 판정 ③ 종결 |
| `iac-reference-infra` | PR #20·#21·#22 · apply 2회(부분 실패 → 성공) |

> ### 🔑 **이 세션이 남긴 가장 값진 것 — 세 가지**
>
> ① ⭐ **T-9 는 통과했는데 실행이 실패했다.** plan 은 문자열까지만 본다 —
> *"`tofu test` 가 통과했으니 동작한다"* 고 쓰지 않는다. **apply 판정을 소비 repo 에 두는
> 분업이 형식이 아니다**(`40 §7.3-3`).
> ② ⭐ **"수동으로 됐으니 자동으로도 된다"가 성립하지 않는다.** 같은 `dnf` 명령이 8/7 유휴
> 상태에서는 성공했고 부팅 중 경합에서는 OOM 으로 죽었다.
> ③ ⭐ **"기술적으로 가능하다"와 "그렇게 해도 된다"는 다르다.** 비밀번호 교체는 `send-command`
> 로도 되지만 평문이 CloudTrail 에 남아 **대화형 세션으로 한다**(`40 §4.1` 정정 상자).
>
> 🔴 **문서 결함이 코드 결함보다 많았다.** 같은 날 **세 repo 전부**에서 낡은 서술이 나왔다
> (설계 §2.5↔§4.1 모순 · 예제 README 가 자기 경고에 걸림 · 소비 repo 핀 4곳 stale ·
> gitops README 가 "아직 적용 안 됨" 유지). **핀·상태 표기가 사본으로 흩어진 것이 공통 원인**이다.

#### ⏭️ **다음 태스크 (2026-08-10 갱신)** — 우선순위 순

> ✅ **workbench 부채가 전부 정리됐다**(2026-08-10). `git`·`kubectl`·`helm`·`argocd` 4종이
> `user_data` 로 자동 설치되고, seed 스크립트는 GitOps 저장소에 vendoring 됐다.
> **손으로 넣은 것이 하나도 없다.** 🔴 **남은 것은 7번(초기 비밀번호 교체)뿐이고 사용자 몫이다.**

1. ✅ **완료 — `workbench-v0.2.0`**(PR #15, `git` 설치).
2. ✅ **완료 — vendoring**(gitops `ba9d079`).
3. ✅ **완료 — `workbench-v0.3.0` 릴리스됨**(PR #16 `1c0de0d`, CI run
   [`31349388448`](https://github.com/skax-ca/iac-module-library/actions/runs/31349388448) 6/6 · 46 tests).
4. ✅ **완료 — 소비 repo 갱신 + apply**(PR #20, run `31352399365`). ⚠️ **부분 실패** — 위 절 참조.
5. ✅ **완료 — `workbench-v0.4.0` 릴리스 + 소비 repo 재핀 + apply**(PR #17 `c928205` ·
   소비 PR #21 · apply run `31353547193`). **전부 통과** — 아래 절 참조.
   - ⚠️ 기본값 변경이라 `instance_type` 미지정 루트는 **인스턴스가 또 교체된다** — 그 교체가
     곧 **`git` 설치의 회수 지점**이다.
6. ✅ **완료 — 도구 자동 설치 확인**: `git 2.50.1` · `kubectl v1.35.7` · `helm v3.21.3` ·
   `argocd v3.5.0`. **손으로 넣은 것이 하나도 없다.**
7. ⛔ **seed 완료 조건 마무리** — 초기 비밀번호 교체 + `argocd-initial-admin-secret` 삭제(`23 §2.3`).
   - ⭐ **`argocd` CLI 는 이미 실물에 있다** ⇒ `argocd account update-password` 로 끝난다.
     🔴 **정정(2026-08-10)**: *"port-forward·대화형 세션이 불필요하다"* 는 **틀렸다.**
     `argocd-server` 는 **`ClusterIP`** 라 CLI 가 있어도 **port-forward 가 필요**하고,
     `send-command` 안에서도 터널은 **선다**(실측). ⛔ 그럼에도 **대화형 세션으로 한다** —
     새 비밀번호가 send-command 파라미터에 **평문으로 CloudTrail·히스토리에 남기** 때문이다.
     🔑 **"기술적으로 가능하다"와 "그렇게 해도 된다"는 다르다.**
     ⭐ CLI 가 실제로 없앤 것: **브라우저 UI 의존**과 **운영자 노트북까지의 터널**
     (port-forward 가 인스턴스 로컬 루프백으로 축소된다). 그리고 `argocd admin` 계열은
     port-forward 자체가 불필요하다 — **판정 ③이 그 증거다.**
   - ⛔ 초기 비밀번호를 `send-command` 로 **조회하지 말 것** — 출력이 CloudTrail·히스토리에 남는다.
   - ⛔ 비밀번호는 **사용자가 정할 값**이다.
8. ✅ **완료 — 판정 ③**: `argocd admin cluster stats -n argocd` 결과 **서버 항목이 하나뿐**
   ⇒ cluster Secret 이 내장 `in-cluster` 를 **대체했다. 중복이 아니다.**
9. `addons/` 증분 → `24`(관리형 ArgoCD). **9-①(설계 선행)은 완료** — 아래 절 참조.

#### ✅ **`30` 2차 부분 개정 완료 — addon 증분 착수 조건이 갖춰졌다** (2026-08-10, `bf6162c`)

문서 전용 · `.tf` 0 · **main 직접 커밋**(브랜치 없음). 9번의 **선행 작업**이었다 —
`30` 이 미개정인 채로 addon 매니페스트를 쓰면 `23` 이 피하려던 *"미개정 문서 위에 서는 설계"* 를
그대로 반복하게 되기 때문. **`23` 과 달리 addon 증분은 `30` 본문 위에 정면으로 선다**(떼어낼 수 없다).

**신설 절 2개** — 본문을 다시 쓰지 않고 **새 절이 판정을 소유**한다(§1.1·§4.1 방식 그대로):
- **`30 §2.9`** addon 증분 경로별 분기 — 승계(팬아웃 기계 전체) / 갈림 4개
- **`30 §3.1`** `platform` AppProject 경로별 값 + 선결 과제 재판정

> ## ⭐ **가장 값진 산출 — 선결 과제 2건이 1건이 됐다**
>
> `30 §3` 이 *"addon 증분의 선결 과제 2건"* 이라고 적은 것 중 **두 번째(Access Entry → apiserver
> RBAC)는 self-managed 경로에 존재하지 않는다.** 실측 3건:
> ① `argo-cd 10.3.0` 기본값 `createClusterRoles: true` + `controller.clusterRoleRules.enabled: false`
>   ⇒ application controller ClusterRole 이 `apiGroups/resources/verbs = *` (chart 원문)
> ② `argocd admin cluster stats -n argocd` → **Successful · resources 536** — 관리형이 막혔던
>   cluster-wide read 가 그대로 된다
> ③ chart `templates/` 에 AppProject 가 **없다** ⇒ `default` 는 런타임 생성물
> ⇒ **D-ARGOCD-CLUSTER-READ / -WRITE 는 관리형 경로의 결정**이다. 원인이던 auto-managed Access
> Entry 의 빈 `kubernetesGroups` 라는 산출물 자체가 self-managed 엔 없다.
>
> ### ⛔ **뒤집어 읽지 말 것 — "더 안전하다"가 아니라 "더 넓게 열려 있다"이다**
> 관리형의 벽은 **최소권한의 부작용**이었고, 넓히는 결정이 곧 리뷰였다. self-managed 는 chart
> 기본이 cluster-admin 이라 **그 리뷰 지점이 아예 안 생긴다.**
> 🔑 ⇒ **AppProject `clusterResourceWhitelist` 가 유일한 실질 가드레일이 된다.**
> `[]` 로 시작하는 선택은 관리형보다 self-managed 에서 **더** 중요하다.
> ⛔ *"어차피 controller 가 cluster-admin 이니 whitelist 는 형식"* 은 **틀렸다** — ClusterRole 은
> apiserver 가 막고 whitelist 는 ArgoCD 가 막는다. 후자는 *"저장소에 실수로 들어온 매니페스트"* 를
> 막는 층이고, **그게 GitOps 에서 실제로 일어나는 사고다.**

> ### 🔑 **재사용할 판단 3건**
>
> ① ⭐ **실증은 값이 아니라 방법이 자산이다.** 2026-07-27 egress canary 는 **관리형 repo-server**
> 기준이라 승계하지 않는다(self-managed 는 우리 노드 위 파드 — 나가는 경로가 다르다). 그러나
> *"`syncPolicy` 없는 canary 를 심고 rendered 수를 본다"* 는 **그대로 쓴다.** 버전 핀도 같다 —
> ALBC `3.4.2`·Karpenter `1.13.0` 은 버리고 **구조는 쓰고 숫자만 다시 실측**한다.
> ② ⭐ **stale 정정 2건이 개정의 절반이었다.** 헤더가 *"⚠️ 아직 apply 되지 않았다"* 를 **3일간**
> 유지했고(seed 는 8/7 완료), `§2.2` 의 Karpenter SG 태그 선결 과제는 이미 해소돼 있었다
> (`20 §5.2` 에서 계약으로 승격). **새 절을 붙이기 전에 거짓부터 걷어낸다** — 안 그러면 새 절이
> 거짓 위에 선다.
> ③ 🔴 **번호 함정 — 접두 없는 `§2.6`(9곳)·`§2.6a`·`§2.7`·`§2.8`(17곳)은 전부 `20` 의 절이다.**
> 그래서 새 절이 `§2.6` 이 아니라 **`§2.9`** 다. ⚠️ **그 경고를 쓴 절 안에서 같은 실수를 한 번 냈다**
> (`§3.1` 이 `20` 의 것인데 접두를 뺐다 — 고침). 📌 **절 신설 전
> `grep -o "§[0-9.a-z-]*" <파일> | sort | uniq -c` 로 점유 현황을 먼저 본다.** 경고로는 못 막는다.

**동반 갱신**: `docs/README.md` 상태표(절 단위 인용 가능 여부) ·
`docs/design/AGENTS.md` — **확정 절 열거를 삭제**하고 README 를 가리키게 했다.
📌 *"중복 기록이 stale 해지면 더 조심하자가 아니라 한쪽을 지운다"* 의 **세 번째 적용**이다.

#### ✅ **9-② addon 증분 ① 완료 — PR 대기 중** (2026-08-10)

**순서대로 ①egress canary → ②버전 실측 → ③매니페스트 전부 실행했다.**

| 단계 | 결과 |
|---|---|
| ① canary | ✅ **3호스트 전부 통과**(배포 0으로 확인 후 삭제). `30 §2.9` 에 기록 |
| ② 버전 실측 | ALBC **3.5.0**(PoC 3.4.2) · Karpenter **1.14.0**(PoC 1.13.0) |
| ③ 매니페스트 | 🔵 **[`iac-platform-gitops` PR #1](https://github.com/skax-ca/iac-platform-gitops/pull/1)** — **미머지** |

🔴 **머지 = 배포다.** `root-app` 이 `automated.selfHeal` 이라 머지 즉시 sync 된다.
사용자 결정으로 **브랜치+PR** 을 택했다 — 머지 시점이 곧 배포 시점이라 PR 이 형식이 아니라
**실질 게이트**다(`30 §3` 이 whitelist 개방을 "리뷰 지점"이라 부른 이유와 같다).

> ### ⭐ **canary 가 실제로 오독을 막았다 — 이번 세션 최대 수확**
>
> `canary-karpenter` 가 **rendered 0 + `ComparisonError`** 였다. `30 §2.2` 의 판독법
> (*"연결 실패면 rendered 0 + ComparisonError"*)대로면 **egress 실패**로 읽힌다.
> 실제 원인은 `Chart cannot be installed without a valid settings.clusterName!` — **values 누락**이었다.
> 🔑 **1차 신호는 rendered 가 아니라 `revision` 해석 여부다.** revision 이 `1.14.0` 으로 채워졌다는
> 것 자체가 차트를 이미 받아왔다는 증거다(못 받으면 채울 수 없다).
> ⇒ 오독했으면 *"public.ecr.aws 에 못 나간다 → ECR 미러링 검토"* 로 갔을 것이다.
> ⛔ **없는 문제를 푸는 설계**를 canary 하나가 막았다. `30 §2.9` 에 판별표로 승격했다.

> ### 🔴 **설계를 그대로 베꼈으면 밟았을 함정 3개** (전부 `30 §2.9` 에 등재)
>
> ① **Karpenter 를 `karpenter` ns 에 배포하면 안 된다** — Pod Identity association 이
> **`kube-system`/`karpenter`** 다(upstream `modules/karpenter` v21.24.1 기본값을 우리 모듈이 그대로 씀).
> Karpenter **공식 관례를 따르면 컨트롤러가 AWS 자격증명을 못 받는다.**
> 증상이 *"파드는 Running 인데 노드가 안 뜬다"* 라 원인을 안 가리킨다.
> ② **NodePool 은 `arm64`** — 클러스터가 `AL2023_ARM_64_STANDARD`·t4g.medium(Graviton)인데
> `30 §2.2` 스펙은 **PoC 의 x86 기준 `amd64`** 다.
> ③ 위 canary 판독법.
>
> 🔑 **①②는 같은 형태다 — 계층 1(Terraform)이 이미 정한 값을 계층 2가 다시 고르려다 생긴다.**
> `30 §0` 3계층 모델은 *"누가 소유하는가"* 는 정했지만 *"소유하지 않는 계층이 그 값을 어떻게
> 알아내는가"* 는 안 적었다. 📌 **addon 매니페스트 전에 `list-pod-identity-associations` 와
> `describe-nodegroup` 을 본다.** cluster Secret 라벨은 답의 일부일 뿐이다.

> ### 📌 **실측이 설계 목록을 한 항목 줄였다**
>
> `clusterResourceWhitelist` 를 canary 의 `status.resources` 에서 **namespace 없는 항목만** 추려
> 실측으로 확정했다. `30 §3` 의 ALBC 5종은 **정확히 일치**했고, Karpenter 컨트롤러의 3종은
> **ALBC 와 완전 중복**이라 추가가 0 이었다(§3 이 예측한 대로).
> ⛔ **`karpenter.sh/NodeClaim` 은 뺐다** — 컨트롤러가 만드는 중간 리소스라 **ArgoCD 가 배포하지
> 않는다.** `30 §3` 초안에 있었으나 최소권한이 원칙이고, 틀렸다면 신호가
> `resource not permitted in project` 로 명확하다.

**로컬 helm 차트를 둔 이유**(`addons/karpenter/nodepool/`): ApplicationSet 의 fasttemplate 은
**Application spec 에만** 적용되고 git 경로 안 파일에는 안 된다 ⇒ per-cluster 값을 CR 에 넣을
다른 수단이 없다. ⛔ 그래서 `root-app` 의 `exclude` 가 한 줄 늘었다.
✅ 반대로 `addons/baseline/*.yaml` 은 제외하지 않는다(진짜 매니페스트, root App 이 흡수해야 함).

#### 🎉 **증분 ① 머지·배포 완료 — 다만 root App 을 두 번 깨뜨렸다** (2026-08-10)

PR #1 머지(`10083ef`) → 복구 2회(`4dd4ace`·`28cefaf`) → **전부 `Synced Healthy`**.

| 판정 | 결과 |
|---|---|
| root App | ✅ `Synced Healthy` · revision **실제 SHA** · conditions 없음 |
| ApplicationSet → Application | ✅ **3 → 3** 전부 `Synced Healthy` |
| 컨트롤러 | ✅ `kube-system` 에 ALBC **2/2** · Karpenter **2/2** |
| Karpenter CR | ✅ `NodePool`·`EC2NodeClass` 둘 다 **Ready=True** (wave 5 + SkipDryRun 작동) |
| 노드 | ✅ **2개 그대로** — pending pod 없으니 Karpenter idle 이 정상 |

> ## 🔴 **머지가 root App 을 두 번 깨뜨렸다 — `30 §4.2` D-ROOTAPP-SKIP 신설**
>
> **① `exclude` 확장이 자기소멸 데드락을 만들었다.** 같은 커밋에 ⓐ 로컬 helm 차트와
> ⓑ 그것을 걸러낼 `exclude` 를 함께 넣었다 ⇒ root App 은 자기 spec 을 git 에서 읽어 갱신하는데
> 그러려면 **먼저 저장소를 렌더**해야 하고, 렌더는 **아직 적용 안 된 옛 exclude** 로 수행된다 ⇒
> 렌더 실패 ⇒ 새 exclude 가 영원히 적용 안 됨. **무한 루프.**
> 🔑 **root App spec 변경과, 그 변경이 있어야 읽히는 파일을, 같은 커밋에 넣을 수 없다.**
>
> **② 마커로 바꿨더니 이번엔 마커를 *설명하는 주석*이 마커로 작동했다.** 판정이
> `bytes.Contains(파일전체, "+argocd:skip-file-rendering")` 라 주석도 걸린다 ⇒
> **root-app.yaml 이 자기 자신을 스캔에서 제외**했다. 증상이 조용하다 —
> 에러 없이 `PruneSkipped Application/root-app :: ignored (requires pruning)` 뿐이다.
>
> ### ⭐ **`prune: false` 가 재앙을 막았다 — 방어 결정이 값을 회수한 순간**
> root App 이 *"저장소에 없는 리소스"* 로 분류됐으니 `prune: true` 였으면 **스스로를 삭제**하고
> seed 를 다시 밟아야 했다. `30 §4` 가 적어 둔 시나리오가 **정확히 실현됐다.**
> 🔑 방어 결정의 값은 **사고가 나야 회수된다** — 그때까지는 비용처럼만 보인다.

> ### 🔑 **재사용할 판단 3건**
>
> ① ⭐ **"설정이 틀렸나"보다 "그 설정이 적용되긴 했나"를 먼저 본다.** 첫 가설은 *"`**` 글롭이
> 안 먹는다"* 였고 **틀렸다** — ArgoCD 가 쓰는 `gobwas/glob` 을 실제 호출 방식(separators 없이
> compile)대로 재현하니 **정확히 매치**했다. 확증은 실물 `.spec.…exclude` 가 **옛 값 그대로**인 것.
> **패턴을 계속 고쳤다면 영원히 못 고쳤다.**
> ② ⭐ **`tofu test` 도 canary 도 이 둘을 못 잡는다.** 둘 다 *"저장소 상태 ↔ root App spec 상호작용"*
> 의 문제라 **머지해서 reconcile 을 돌려야** 드러난다. *"apply 판정은 소비 repo 몫"* 이 GitOps
> 계층에도 그대로 산다.
> ③ 📌 **문자열 포함 검사로 동작하는 마커는 그 마커를 문서화할 수 없다**(같은 확장자 안에서는).
> `.md` 는 스캔 대상이 아니라(`^.*\.(yaml|yml|json|jsonnet)$`) 안전하다. 자기 점검 한 줄을
> gitops README 에 넣었다.

> ### 🔴 **설계를 그대로 베꼈으면 밟았을 함정 (앞 절 ①②) + D-ADDON-NS**
>
> 사용자 질문(*"전용 ns 가 나은가"*)으로 **공식 문서 리서치**를 했고 **D-ADDON-NS** 가 나왔다:
> **계층 2 addon 은 전용 ns 신설이 기본, 예외는 ALBC·Karpenter → `kube-system` 둘뿐.**
> - ⭐ 예외의 기술 근거는 **Karpenter 의 APF FlowSchema** 다 — `kube-system` 의 호출만
>   `leader-election`·`workload-high` 우선순위로 간다. 다른 ns 면 **custom FlowSchema 2개를
>   우리가 소유**해야 한다(공식 스크립트 실측).
> - ⛔ **내가 근거로 떠올린 것 하나는 실측 반증됐다** — *"`system-cluster-critical` 은 `kube-system`
>   전용"* 은 **틀렸다**(`default` ns server-side dry-run 통과 · k8s master·1.31 소스에 제약 없음).
>   구버전 기억이다. 문서에 *"되살리지 말 것"* 으로 박아 뒀다.
> - 🔑 **가역적이다** — upstream 이 `namespace` 변수를 노출한다. facade 가 안 넘길 뿐이라
>   *"못 바꾼다"* 가 아니라 **"안 바꾼다"** 다(`ami_type`·`cluster_security_group_additional_rules` 패턴).

**⏭️ 다음**: ArgoCD 자기 관리 증분(`argoproj.github.io/argo-helm` — egress 는 canary 로 이미 확인,
`sourceRepos` 에 추가 필요) → 그 뒤 `24`(관리형 ArgoCD).
- ⚠️ **첫 전용-ns addon 에서 판정할 것 2건**(`30 §2.9` D-ADDON-NS 집행 절):
  ① `CreateNamespace=true` 로 생기는 Namespace 가 AppProject whitelist 적용을 받는가
  ② `managedNamespaceMetadata` + `prune: true` 조합이 **addon 제거 시 ns 째 지우는가**
- ⛔ **`23 §2.3` 초기 비밀번호 교체는 여전히 미이행**이고 사용자 몫이다.

#### 🔚 **2026-08-10 세션 ② 핸드오프 — GitOps 계층이 실물로 섰다**

같은 날 두 번째 세션. 앞 세션이 **workbench 부채 0**을 만들었다면, 이 세션은
**`addons/` 가 실제로 클러스터에 떴다** — 3계층 소유 모델의 **계층 2가 처음으로 살아 움직인다.**

| repo | 결과 |
|---|---|
| `iac-module-library` | `bf6162c`·`aa30f0f`·`2ce2f65`·`22b2653` — `30` **2차 부분 개정**: **§2.9**·**§3.1**·**§4.2** 신설, §5 인용 제한 해제, **D-ADDON-NS**·**D-ROOTAPP-SKIP** 결정 2개 |
| `iac-platform-gitops` | PR **#1** 머지(`10083ef`) + 복구 2회(`4dd4ace`·`28cefaf`) — `addons/baseline/` 신설, ALBC **3.5.0** · Karpenter **1.14.0** 배포 완료 |
| `iac-reference-infra` | 변경 없음(이번 증분은 계층 2 소관) |

> ### 🔑 **이 세션이 남긴 가장 값진 것 — 네 가지**
>
> ① ⭐ **canary 가 오독을 막았다.** `canary-karpenter` 가 rendered 0 + `ComparisonError` 였는데
> `30 §2.2` 판독법대로면 **egress 실패**로 읽힌다. 실제 원인은 `settings.clusterName` 누락이었다.
> **1차 신호는 rendered 가 아니라 `revision` 해석 여부**다. 오독했으면 *"못 나가니 ECR 미러링"* 이라는
> **없는 문제를 푸는 설계**로 갔다.
> ② ⭐ **"설정이 틀렸나"보다 "그 설정이 적용되긴 했나"를 먼저 본다.** exclude 데드락을 글롭 문제로
> 오진할 뻔했다 — `gobwas/glob` 을 실제 호출 방식대로 재현하니 패턴은 **정확히 매치**했고,
> 확증은 실물 `.spec.…exclude` 가 **옛 값 그대로**인 것이었다.
> ③ ⭐ **`prune: false` 가 재앙을 막았다.** root App 이 "저장소에 없는 리소스"로 분류됐으니
> `prune: true` 였으면 **스스로를 삭제**했다. **방어 결정의 값은 사고가 나야 회수된다.**
> ④ ⭐ **리서치가 근거를 뒤집었다.** *"association 이 kube-system 이니까"* 는 논리가 뒤집힌
> 서술이었다. 공식 문서를 읽어 **Karpenter APF FlowSchema** 라는 진짜 근거를 찾았고,
> 내가 근거로 삼으려던 것 하나(`system-cluster-critical` ns 제약)는 **실측으로 반증**했다.
>
> 🔴 **머지해서 reconcile 을 돌려야만 드러나는 결함이 2건이었다.** `tofu test` 도 canary 도
> 못 잡는다 — 둘 다 *"저장소 상태 ↔ root App spec 상호작용"* 이다.
> ⇒ **"apply 판정은 소비 repo 몫"이 GitOps 계층에도 그대로 산다.**

⚠️ **복구 커밋 2건은 브랜치·PR 없이 main 직접**이었다(main 이 깨져 어떤 변경도 반영 안 되는 상태).
사유를 커밋 메시지에 명시했다. **정상 경로는 여전히 브랜치+PR 이다** — 머지 = 배포이기 때문.

#### ⏸ ~~뒤로 밀린 것 — **`40` 열린 항목 7 (`argocd` CLI 핀)**~~ ✅ **해소**(2026-08-10) — 아래는 그때의 조사 기록

`21` 이 닫혔으므로 착수 가능(사용자 결정 2026-08-06: *"21 개정 후"*). 핀의 근거가 이제 있다.
- ⚠️ **관리형이 기본이라 CLI 제약이 결정됐다**(`21 §1.2 ⑥`): `argocd login` **미지원**(계정·프로젝트
  토큰) · `argocd admin` 미지원 · **`--grpc-web` 필수** · 앱 지정에 **namespace 접두**
  (`argocd app sync <ns>/<app>`) · `argocd cluster add` 에 `--aws-cluster-name` 필요.
  ⇒ workbench 에 CLI 를 두는 이유는 *"로그인해서 쓴다"* 가 아니라 **토큰 기반 조작**이다.
- 릴리스 자산 실측(8/6): **`argocd-linux-arm64` 단일 바이너리**(v3.5.0, GitHub Releases) —
  `t4g.nano` arm64 동작, tarball 해제 없음.
- ⚠️ `velero` CLI 는 제외됨(D-BACKUP-AWS 가 에이전트 없는 경로를 택함).
- 📌 도구가 3개가 돼도 **일반화하지 않는다** — 다운로드 형태가 전부 다르다.
- ⛔ **`.tf` 변경이므로 브랜치 → PR.**

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

#### 🚀 **2026-08-11 세션 — 증분 ②③④ 설계 + 구현(PR 3개, 스택)**

사용자 지시: *"A부터 진행하자 그런데 kyverno, KEDA도 addon으로 추가하고 싶어."*
⇒ 설계는 이 repo(`30 §2.10` 신설, **main 직접 커밋** `40608af`·`7b2b363`), 구현은 `iac-platform-gitops`.

> 🔴 **아래 표는 세션 중반에 쓴 것이고 그대로 두면 stale 이다** — 세션 끝에 **전부 머지됐고
> ③의 PR 번호가 바뀌었다.** 최종 상태는 이 절 아래 「✅ 머지·apply 판정 전부 완료」가 소유한다.

| 증분 | PR (최종) | 머지 커밋 | 비고 |
|---|---|---|---|
| ② ArgoCD 자기 관리 1단계(비교만) | **#2** ✅ | `3cecd80` | — |
| ③ Kyverno 3.8.2 + PSS 정책(Audit) | ~~#3~~ → **#5** ✅ | `b13e9ea` | ⚠️ #2 를 `--delete-branch` 로 머지하자 **#3 이 자동 CLOSED** 돼 새로 열었다 |
| ④ KEDA 2.20.2, `addons/catalog/` 첫 사용 | **#4** ✅ | `1bb27e9` | — |

> ⭐ **PR 을 스택으로 쌓아 머지 순서를 구조로 강제했다.** 설계가 정한 ② → ③ → ④ 는 우선순위가
> 아니라 **의존**이다(ArgoCD 가 ③④를 배포하는 주체).
> 🔑 증분 ①에서 *"머지해야만 드러나는 결함"* 이 2건이었다 — 셋을 한 PR 에 넣으면 원인을 못 가른다.
> 🔴 **그러나 *"앞 PR 이 머지되면 GitHub 이 base 를 자동 재지정한다"* 는 틀렸다** — 실측상
> **base 브랜치가 삭제되면 자식 PR 은 재지정되지 않고 닫힌다.** 절차는 아래 「📌 절차 교훈」이 소유한다.

**사용자 결정 3건**(2026-08-11): ① Kyverno = **①baseline**(*옵트인 가드레일은 가드레일이 아니다*)
② 정책 = **컨트롤러 + PSS(Audit)** ③ KEDA AWS 스케일러 **미포함**(⇒ IAM 0, 계층 2 안에서 닫힘).

##### 🔑 이 세션이 남긴 것 — 다섯 가지

> ① ⭐ **D-ADDON-NS 의 미판정 2건을 둘 다 종결했다**(`30 §2.10.0`).
> **판정 ①은 소스로**: 자동 생성 ns 가 **같은 sync task 목록에 append** 되고
> (`gitops-engine sync_context.go:846`) 목록 전체가 `permissionValidator` 를 거친다(`:904`) ⇒
> `clusterResourceWhitelist` 검사를 **받는다**. 🔴 **단 ns 가 이미 있으면 task 자체가 안 생긴다**
> (`controller/sync_namespace.go`) ⇒ 손으로 먼저 만들면 통과하고 **두 번째 클러스터에서만 깨진다.**
> **판정 ②는 공식 문서 원문으로**: *"including the possibility to delete it"* ⇒
> `managedNamespaceMetadata` 를 **쓰지 않는다**.
>
> ② 🔑 **"단일 클러스터는 팬아웃 결함을 숨긴다"가 이 세션의 관통 주제다.** 같은 형태가 **두 번** 나왔다 —
> 판정 ①(ns whitelist)과 증분 ②의 Application vs ApplicationSet(cluster generator 를 쓰면 모든
> 스포크에 ArgoCD 가 깔리는데 **지금은 대상이 hub 하나뿐이라 정상으로 보인다**).
> ⇒ **dev 에서 통과한다는 것이 설계가 맞다는 증거가 아니다.**
>
> ③ ⭐ **"이름이 비슷한 두 값이 다른 축"** — Kyverno 의 `validationFailureAction`(정책을 **위반했을 때**)
> 과 `failurePolicy`(웹훅에 **닿지 못할 때**). **Audit + Fail 은 비정합**이다 — 아무것도 막지 않기로
> 해 놓고 Kyverno 가 죽으면 전부 막는다. ⇒ `Ignore` 로 바꿨다(`background: true` 라 잃는 것은 실시간성뿐).
>
> ④ ⭐ **렌더해서 세는 절차가 2건을 잡았다.** cluster-scoped 리소스는 kyverno 47 · keda 17 · argocd 7 인데
> whitelist 추가는 **3건뿐**이다(`Namespace`·`ClusterPolicy`·`APIService`). whitelist 는 **kind 단위**라
> 첫 addon 이 목록의 대부분을 연다. 📌 **그래도 매번 센다** — `APIService`·`ClusterPolicy` 는
> 그 절차로**만** 잡혔다.
>
> ⑤ 🆕 **새 축 발견 — 노드의 이미지 pull egress 는 canary 가 볼 수 없다.** canary 는 repo-server 의
> 차트 fetch 만 본다(파드→NAT). 이미지 pull 은 **kubelet→NAT** 로 경로가 다르고, 지금까지 addon
> 이미지는 **전부 `public.ecr.aws`** 였다. ③④가 **`ghcr.io` 첫 사용**이다 ⇒ **apply 판정 항목**.
> ⚠️ `reg.kyverno.io` 는 **GHCR 앞의 vanity 도메인**이다(401 `www-authenticate` realm=`ghcr.io` 실측).

##### 🔴 흡수(증분 ②)에서 미리 특정한 위험 3건 — 1단계 diff 로 읽는다

| # | 지점 | 요지 |
|---|---|---|
| 1 | `Secret/argocd-secret` | 차트가 **`data` 없이** 렌더한다. argocd-server 가 런타임에 **admin 비밀번호 해시·`server.secretkey`·TLS** 를 채우는 자리 ⇒ 잘못 적용하면 **자격증명이 날아간다**. `ServerSideApply=true` 가 막는다. ⛔ `Replace=true` 금지 |
| 2 | helm hook 4개 `argocd-redis-secret-init` | ArgoCD 가 `PreSync` 로 번역 ⇒ **sync 마다 Job 하나**. 정상이다 |
| 3 | release 이름 | `argocd-seed.sh` 의 `ARGOCD_RELEASE` 기본값 `argocd`(`:137`)와 **같아야** 한다. 어긋나면 **흡수가 아니라 병렬 설치**(새 리소스 44개) ⇒ `helm.releaseName: argocd` 를 명시했다 |

⛔ **`ignoreDifferences` 를 미리 넣지 않았다** — 필요한지는 **1단계 diff 가 답한다.**
⭐ 이 판정을 **안전하게 할 수 있다는 것**이 2단계로 나눈 값 그 자체다.

##### 📌 정정한 낡은 서술 6건 (세 파일에 걸쳐)

`30 §2.4`(②경로 "구현 미룸") · `30 §2.9` 갈림점 4 · `30 §2.9` cluster Secret 문장 ·
`30 §2.9` 미판정 2건 · gitops README 증분 ① 제목(*"미머지 브랜치"* → 실제로는 배포 완료) ·
`cluster-secret.yaml` 헤더(*"apply 후 확인할 것"* → 8/10 판정 끝).
➕ **D-ROOTAPP-SKIP 자기 점검 명령의 `^./` 앵커를 뺐다** — `grep -rl … .` 출력의 `./` 접두는
환경마다 다르고(실측), 앵커가 있으면 **정상인데도 4줄이 출력된다.**
🔑 **거짓 경보를 내는 점검은 곧 무시당한다 — 점검 장치의 결함은 점검 대상의 결함만큼 나쁘다.**

##### ✅ **머지·apply 판정 전부 완료** (2026-08-11 같은 세션, workbench SSM 실물 조회)

| # | PR | 커밋 | 결과 |
|---|---|---|---|
| ① | 모듈 repo **#18** | `fb2d6f4` | CI 플러그인 캐시. main 에서 `Installing` **13 → 5** 확인 |
| ② | gitops **#2** | `3cecd80` | `Application/argocd` 생성 · **파드 재시작 0** |
| ③ | gitops **#5**(구 #3) | `b13e9ea` | Kyverno 4 컨트롤러 + ClusterPolicy 11개 `Ignore`/`Audit` |
| ④ | gitops **#4** | `1bb27e9` | KEDA 3 파드 · `APIService` Available · **`Synced Healthy`** |

판정 전문은 **`30 §2.10.5`**(SSOT). 통과 7건 — `ghcr.io` 이미지 pull(새 축) · 판정 ① 실증 ·
정책 값 · `APIService` ↔ `metrics-server` 무영향 · **라벨 옵트인 인과 실증** · 기존 워크로드 무영향 · 재시작 0.

> ### 🔴 **핵심 발견 — `ServerSideApply` 는 *적용* 만 바꾸고 *diff* 는 안 바꾼다**
>
> `OutOfSync` 세 건이 **전부 같은 원인**이었다 — *우리가 선언하지 않은 필드를 다른 매니저가 소유*:
> ② 37개(`helm` → `meta.helm.sh/*`) · ③ CRD 11개(`kube-apiserver` → 스키마 기본값) ·
> ③ ClusterPolicy 11개(`kyverno` → 자기 mutating webhook 주입).
> ⇒ **`ServerSideDiff` 는 별개 스위치다.**
> ⭐ **KEDA 가 대조군**이다 — 같은 옵션인데 혼자 `Synced` 다(자기 리소스를 변형하지 않는다)
> ⇒ *"ArgoCD 설정 문제"* 가설이 배제됐다. **증분을 나눈 덕에 대조군이 생겼다.**
> 🔴 기능은 정상(`phase=Succeeded`)이지만 **항상 OutOfSync 면 진짜 drift 신호가 죽는다** —
> 이 세션에서 **같은 범주가 세 번째**다(`^./` 앵커 · CI "8회" · 이것).

##### ⏭️ **다음 태스크 (2026-08-11 갱신 — 머지 후)**

1. ~~🔴 **`OutOfSync` 고착 해소 증분(②-b·③-b)**~~ ✅ **완료**(2026-08-11 세션 ② — 아래 절).
   ③은 `ServerSideDiff=true` 로 해소, ②는 **원인이 달라** PR-②b 로 넘어갔다.
2. ~~🔴 **PR-②b** — `automated: {selfHeal: true, prune: false}`~~ ✅ **완료**(2026-08-11 세션 ②,
   gitops PR **#8** `45f1db2`). **전 항목 통과 · 재시작 0** — 판정 전문은 **`30 §2.10.8`**.
   ⭐ **8개 Application 이 처음으로 전부 `Synced Healthy`** 이고, `23 §2.1` 의 3단계가 **다 찼다**
   (ArgoCD 의 SSOT 가 완전히 저장소로 넘어왔다).
3. ~~🔴 **`40` 열린 항목 8 — workbench kubeconfig**~~ ✅ **해소**(2026-08-11 세션 ②,
   **`workbench-v0.5.0`** / PR **#19** `916950b`). 🔴 **그 항목의 전제부터 틀렸다** —
   kubeconfig 는 **있었고** ⓐ(user_data)는 **이미 구현돼 있었으며 순환도 없었다.**
   진짜 결함은 ① `profile.d` 가 **로그인 셸에서만** 읽힘(자동화 경로 누락) ② 공유 정본이
   **0666 world-writable** 이 되어 전역 오염(= **로컬 권한 상승 경로**) ③ 손 사본 증가.
   ⇒ **D-WORKBENCH-KUBECONFIG**(`40 §4.3-1`): 정본 `0444` + `/etc/skel` 상속 + 사용자별 `0600` 사본.
3-1. ✅ **`workbench-v0.6.0` (D-WORKBENCH-TOOLING)** — 사용자 요청으로 3번에 이어서 진행했다
   (PR **#20** `f9631a8`). `eks-node-viewer` · `krew`+플러그인 6종 · 로그인 프로파일.
   ✅ **소비 repo apply 까지 완료** — `iac-reference-infra` PR **#23** `9387201`,
   새 인스턴스 **`i-0e7440e9e0350f731`**, 판정 8항목 전부 통과(⭐ `/etc/skel` 상속 실증).
4. ~~🔴 **`23 §2.3` 초기 비밀번호 교체**~~ ✅ **완료**(2026-08-11 세션 ③ — 아래 절).
   mtime `2026-08-07T06:25:04Z` → **`2026-08-11T06:35:19Z`** · `argocd-initial-admin-secret`
   **삭제됨** · Application 8개 `Synced Healthy` 유지. 판정·절차 SSOT = **`23 §2.3-1`**(신설).
5. 🔵 **다음 착수 — `24`(관리형 ArgoCD)**. `23` 이 완결됐으므로 여기가 다음 자리다.
- ⚠️ **Kyverno 를 Enforce 로 올릴 때 먼저 답할 질문**: `argocd` ns 를 webhook `namespaceSelector`
  제외에 넣을 것인가. Enforce + `Fail` 은 **순환 의존**이다(Kyverno 장애 → ArgoCD 막힘 → 고칠 수단 상실).

##### 📌 **절차 교훈 — 스택 PR 을 squash + `--delete-branch` 로 머지하면 자식이 닫힌다**

#2 를 `--delete-branch` 로 머지하자 **#3 이 자동 CLOSED** 됐고, 닫힌 PR 은 base 를 못 바꿔
**#5 로 새로 열어야 했다**(squash 라 자식 브랜치엔 부모 원본 커밋이 남아 `CONFLICTING` 이기도 했다).
⇒ **규칙**: ⓐ `--delete-branch` 를 쓰지 않고 ⓑ 다음 PR 을 main 으로 리베이스+retarget 한 뒤
ⓒ 마지막에 브랜치를 지운다. 🔑 **브랜치가 원격에 남아 잃은 것은 없었다** — 복구 가능성이 사고 크기를 정한다.

##### 🔧 **workbench 조회 경로 (재사용)**

- 인스턴스 **`i-0e7440e9e0350f731`**(`ec2-ref-dev-an2-workbench-01`).
  ⚠️ **2026-08-11 `workbench-v0.6.0` apply 로 교체됐다**(구 `i-0675ba8c5ad9dd507` 은 없다).
  ⭐ 이제 kubeconfig·도구·프로파일이 **user_data 산출물**이라 손으로 만들 것이 없다.
- ⚠️ **aws-api MCP 로는 안 된다** — `READ_OPERATIONS_ONLY: true` 라 `ssm send-command` 가
  *"denied by security policy"* 다. **로컬 `aws --profile team` 으로 보낸다.**
- kubeconfig 가 없으면 먼저: `aws eks update-kubeconfig --region ap-northeast-2 --name eks-ref-dev-an2-main-01`
  (⚠️ `--name` 필수 — `eks:ListClusters` 권한이 없다).
- ⚠️ `kubectl -o jsonpath` 는 **map 순회(`$k,$v :=`)를 지원하지 않는다** → `-o go-template` 을 쓴다.
- ⛔ 비밀번호·Secret **값**은 조회하지 않는다(CloudTrail 에 남는다). 키 이름까지만.

---

#### 🔚 **2026-08-11 세션 ② — `OutOfSync` 고착: 2/3 해소, 그리고 원인 귀인 3건이 전부 틀렸다**

직전 세션의 「다음 태스크 1번」을 실측으로 닫았다. 설계 SSOT = **`30 §2.10.6`(D-SSDIFF) + `§2.10.7`(판정)**.

| repo | 커밋/PR |
|---|---|
| 모듈(설계) | `8ec6e1b` §2.10.6 신설 · `3b324a7` §2.10.7 판정 (**main 직접**, 문서 전용) |
| gitops | **PR #6** `3a66228`(적용) → **PR #7** `61a70bf`(argocd 앱 **철회**) |

**결과**: `kyverno`·`kyverno-policies` ✅ **`Synced Healthy`**(CRD 11 + ClusterPolicy 11 해소) ·
`argocd` 🔴 **`OutOfSync` 37개 그대로**(원인이 달랐다) · **파드 재시작 0** · 다른 앱 무영향.

##### 🔴 **§2.10.5의 원인 귀인 3건이 전부 틀렸다 — 같은 실수 하나에서 나왔다**

| # | 기록된 원인 | 실측 |
|---|---|---|
| ③ CRD | *"`kube-apiserver` 가 스키마 기본값을 채운다"* | 그 매니저는 **`status` 서브리소스만** 소유. 차이는 **`spec.conversion`**(무소유 필드) |
| ③ ClusterPolicy | *"`kyverno` 자기 mutating webhook 이 주입"* | `kyverno` 도 **`status` 만** 소유. 차이는 **`spec.admission`·`emitWarning`** = CRD 스키마 `default:` |
| ② argocd 37개 | *"`helm` 이 소유한 `meta.helm.sh/*`"* | 🔴 **`meta.helm.sh` 는 diff 에 0회 등장.** 차이는 **전부 한 줄** — `argocd.argoproj.io/tracking-id` |

🔑 **셋 다 `managedFields` 만 보고 실제 diff 를 한 번도 열지 않은 데서 나왔다.**
`argocd app diff <app> --core` 는 **로그인 없이 kubeconfig 로** 도는데도 쓰이지 않았다.
⇒ ⛔ **`OutOfSync` 를 다룰 때는 원인을 추론하기 전에 diff 를 먼저 출력한다.**

##### ⭐ **②의 진짜 의미 — 위험 신호가 아니라 안전 증거였다**

37개에서 **유일한 차이가 ArgoCD 자신의 추적 애노테이션**이라는 것은 **흡수해도 실질 변경이 0**.
대조군이 증명한다 — kyverno `ClusterPolicy` live 에는 tracking-id 가 **있고**(apply 했으니까),
`argocd-cm` 에는 **없다**(한 번도 sync 된 적이 없으니까).
⇒ **PR-②b 가 할 일이 특정됐다: 애노테이션 37개 추가, 그 외 0.** `Deployment`·`StatefulSet` 의
**pod template 을 안 건드리므로 재시작이 없어야 한다** — §2.10.5 의 위험 근거가 **완화**됐다.
🔑 **숫자(37)를 읽고 내용을 안 읽으면 정반대로 해석된다.**

##### ⚠️ 운영 사실 2건 (재사용)

1. **애노테이션 도착만으로는 diff 가 재계산되지 않는다.** `kubectl -n argocd annotate app <name>
   argocd.argoproj.io/refresh=hard --overwrite` 를 넣자 그때 `Synced` 가 됐다
   (`diff_ms=6720`, `comparison-level=3`). ⇒ **diff 전략 변경 증분은 hard refresh 를 판정 절차에 넣는다.**
2. **SSM RunShellScript 에는 `HOME` 이 없다.** `kubectl` 이 `localhost:8080` 으로 붙고
   `argocd` CLI 는 `$HOME is not defined` 로 죽는다 ⇒ 스크립트 첫 줄에 **`export HOME=/root`** 와
   **`export KUBECONFIG=/root/.kube/config`** 를 항상 넣는다. `--parameters` 는 **JSON 파일**로 준다
   (인라인 `commands=[...]` 는 개행을 뭉갠다 — 실측).

##### ✅ **이어서 PR-②b 도 완료 — ArgoCD 자기 관리 3단계가 다 찼다** (gitops PR **#8** `45f1db2`)

`automated: {selfHeal: true, prune: false}` 를 켰다. **전 항목 통과 · 파드 재시작 0** ·
⭐ **8개 Application 이 처음으로 전부 `Synced Healthy`**. 설계 SSOT = **`30 §2.10.8`**.

**배포 전 실측 3건이 판정을 미리 답했다** — 판정은 확인이지 발견이 아니었다.

| # | 질문 | 답 |
|---|---|---|
| 1 | sync 가 무엇을 바꾸나 | `tracking-id` 37개뿐 ⇒ 실질 변경 0 |
| 2 | SSA 가 `helm` 과 충돌하나 | 🔴 **한다** — 실제 렌더본으로 2건(`env[NAMESPACE].valueFrom.fieldRef` · `NetworkPolicy.spec.ingress`). **atomic 구조체 + apiserver 기본값** |
| 3 | 충돌이 sync 를 막나 | ✅ 아니다 — `ServerSideApply=true` 는 공식 문서상 **`--force-conflicts` 로 실행**된다 |

- ⭐ **`argocd app diff` 는 깨끗한데 SSA 는 충돌한다** — ArgoCD diff 가 **기본값을 정규화해 지우기**
  때문이다. 🔑 **diff 가 깨끗한 것은 apply 가 충돌하지 않는다는 뜻이 아니다.**
- ⛔ **`argocd app sync --dry-run` 은 클라이언트 사이드 apply 로 돈다**(`ServerSideApply=true` 여도).
  ⇒ 그 `Phase: Succeeded` 를 SSA 성공의 증거로 쓰지 않는다. **`argocd app manifests` → `kubectl apply
  --server-side --dry-run=server --field-manager=argocd-controller`** 로 직접 확인한다.
- 🔑 **이름만 비슷한 세 축**: `ServerSideApply`(apply 방식·force 포함) · ⛔`Force`(**delete/create**) ·
  ⛔`Replace`(**SSA 보다 우선** ⇒ Secret 보호 무력화) · `ServerSideDiff`(비교 방식).
- 📌 **`helm` 매니저는 사라지지 않고 공존한다** — SSA 는 **우리가 선언한 필드의 소유권만** 가져온다.
  ⇒ 흡수 = **삭제가 아니라 소유권 이전**. 되돌릴 수 있다. ⚠️ 그래서 `prune: true` 는 여전히 안 켠다.

##### ✅ **`40` 열린 항목 8 해소 — `workbench-v0.5.0` (D-WORKBENCH-KUBECONFIG)**

🔴 **그 항목의 전제부터 틀렸다.** kubeconfig 는 **있었다**(`/etc/kubernetes/kubeconfig`, 부팅 로그에
생성 기록). ⓐ(user_data 실행)는 **이미 구현돼 있었고** `eks_cluster_name` 이 소비자 입력이라
`§5.1-1` 순환도 **없었다**. *"`find` 전수 0건"* 은 홈만 봤거나 **비로그인 셸의 `kubectl` 실패를
"kubeconfig 없음"으로 오독**한 것이다. ⛔ 이 세션도 같은 오독을 반복해 `/root/.kube/config` 사본을
하나 더 만들었다 — **그 항목이 경계한 행위 자체**다.

**진짜 결함 3건** — 전부 *"설치"가 아니라 "누가 쓸 수 있나"*

| # | 결함 |
|---|---|
| 1 | `/etc/profile.d/*.sh` 는 **로그인 셸에서만** 읽힌다 ⇒ 대화형 SSM 은 받고 **RunShellScript(자동화)는 못 받는다** |
| 2 | 🔴 공유 정본이 **`0666`(world-writable)** 이 되어 기본 네임스페이스가 전역 오염. kubeconfig 는 `users[].user.exec` 로 **임의 명령**을 지정할 수 있어 **로컬 권한 상승 경로**다 — 편의가 아니라 **보안** 문제 |
| 3 | 손으로 만든 사본이 는다 |

**결정**: 정본 `0444` + **`/etc/skel/.kube/config` 상속** + 사용자별 `0600` 사본 + `profile.d` 제거.
⭐ **`/etc/skel` 이 핵심**인 이유 — 실측: 부팅 `03:49:28` · user_data `03:50:11` ·
**`/home/ssm-user` 생성 `06:26:37`**(2시간 37분 뒤, SSM Agent 가 **첫 세션에서** `useradd -m`).
⇒ user_data 는 *"그 사용자의 홈"* 에 아무것도 못 놓는다.
⛔ **전용 사용자 신설은 기각** — 대화형은 **항상 `ssm-user`**, 자동화는 **항상 root** 이고,
`ssm-user` 는 `sudoers.d` 에 **`NOPASSWD:ALL`**(실측)이라 **root 회피가 보안 경계를 못 만든다.**
🔑 바꿀 수 있는 것은 *"누가 실행하나"* 가 아니라 **"산출물이 누구 것이 되나"** 다.
⚠️ 비로그인 셸은 user_data 로 못 닫는다 → **자동화 규약**(`40 §6`)이 소유.
📌 **T-12 음성 assertion 을 파일 이름으로 잡았다가 실패했다** — user_data 의 *"만들지 않는다"* 주석이
그 문자열을 포함했다. `30 §4.2` **D-ROOTAPP-SKIP 실패 ②** 와 같은 형태(이 repo **두 번째**).
⇒ **판정 대상을 이름이 아니라 "쓰는 행위"(리다이렉트)로** 바꿨다.

##### ✅ **이어서 `workbench-v0.6.0` — D-WORKBENCH-TOOLING** (PR **#20** `f9631a8`)

사용자 요청: `eks-node-viewer` · `krew`(ctx·ns·neat·rbac-tool·view-secret·whoami) ·
프로파일에 `alias k`/`nv` · kubectl completion · 리전 export. 설계 = **`40 §4.3-2`**.

**실측이 잡은 함정 3건** (전부 추정했으면 틀렸을 것)

| # | 함정 |
|---|---|
| 1 | `eks-node-viewer` 자산은 **`_Linux_x86_64`** — 우리 `$ARCH`(`amd64`)를 그대로 쓰면 **x86 에서 404**. 전용 매핑을 뒀다 |
| 2 | 🔴 `krew` 기본값은 **`$HOME/.krew`** — user_data 는 root 라 **`/root/.krew` 에 갇힌다**(v0.5.0 이 방금 고친 문제의 재발) ⇒ **`KREW_ROOT=/usr/local/krew`** 시스템 설치 |
| 3 | `complete -o default -F __start_kubectl k` 는 **`source <(kubectl completion bash)`** 가 있어야 동작. ⚠️ **함수가 없어도 bash 가 에러를 안 낸다**(실측) ⇒ 조용히 무용지물 |

⭐ **`profile.d` 를 다시 쓴다 — v0.5.0 과 모순이 아니다.** 가르는 기준을 명문화했다:
**상태**(kubeconfig)는 **사용자별 사본** / **설정**(alias·`PATH`·`KREW_ROOT`·리전)은 **전역**.
🔑 v0.5.0 이 막은 것은 *`profile.d` 자체* 가 아니라 **"공유 정본을 `KUBECONFIG` 로 전역 export"** 였다.
🔑 플러그인은 *상태* 가 아니라 *바이너리* 라 kubeconfig 와 **반대로 공유가 옳다.**

> ### 🔑 **오늘 네 번 반복된 규칙 — `user_data` 음성 assertion 은 "이름"이 아니라 "행위"를 지목한다**
>
> `user_data` 는 **주석이 본문의 일부**다. *"하지 않는다"* 고 설명하는 주석이 그 이름을 포함하므로
> **이름으로 음성 판정을 걸면 설명까지 걸린다.**
> ① `30 §4.2` D-ROOTAPP-SKIP 실패 ② ② `"/etc/profile.d/kubeconfig.sh"`
> ③ `"> /etc/profile.d/"`(**너무 넓어** 다음 증분의 정당한 요구를 막았다) ④ `"KREW_ROOT"`
> ⇒ 지목할 것은 **실행 구문**: `export KREW_ROOT=` · `export KUBECONFIG=/etc/kubernetes`.
> ⚠️ ③이 별개 교훈이다 — **넓은 음성 판정은 미래의 정당한 요구를 막는다.**

##### ✅ **소비 repo apply 완료 — `v0.6.0` 이 실물로 섰다** (`iac-reference-infra` PR **#23** `9387201`)

plan **`1 to add, 0 to change, 1 to destroy`**(replace 는 workbench 인스턴스 **1건뿐**) →
dispatch apply 성공 → 새 인스턴스 **`i-0e7440e9e0350f731`**. 부팅 **73초**, 판정 8항목 전부 통과.

| # | 항목 | 결과 |
|---|---|---|
| 1 | 도구 6종 + krew 플러그인 6개 | 전부 설치 |
| 2 | 정본 `0444` | `ssm-user` 쓰기 **불가** |
| 3 | ⭐ **`/etc/skel` 상속 실증** | `/home/ssm-user/.kube/config` 가 **`ssm-user:ssm-user 0600`**. user_data 는 `root`·`ec2-user` 만 순회하므로 **skel 이 작동했다는 직접 증거**다 |
| 4 | 전역 오염 차단 | `ssm-user` 의 `set-context` 가 **자기 사본만** 바꾸고 정본은 그대로 |
| 5 | 로그인 프로파일 | 5요소 전부 활성(completion 포함) |
| 6 | 도달성 | `KUBECONFIG` **없이** `kubectl get nodes` → 2대 |
| 7 | ArgoCD | 8개 Application **`Synced Healthy` 유지** |

🔑 **이 두 릴리스가 회수한 것은 "손으로 만든 상태"다.** 이제 kubeconfig·도구·프로파일이
전부 user_data 산출물이라, **다음 교체에서도 자동으로 선다.**

##### 🖥️ **ArgoCD 웹 UI 로컬 접속 — 2홉 (2026-08-11 실측 성공)**

EKS 엔드포인트는 **public=false**라 로컬에서 API 서버에 직접 못 붙는다. workbench 를 경유한다.

```bash
# ① workbench 에서 port-forward (SSM send-command, setsid nohup 로 살려 둔다)
export HOME=/root KUBECONFIG=/root/.kube/config
setsid nohup kubectl -n argocd port-forward svc/argocd-server 18080:443 \
  --address 127.0.0.1 > /tmp/argocd-pf.log 2>&1 < /dev/null &

# ② 로컬에서 SSM 포트 포워딩
aws --profile team --region ap-northeast-2 ssm start-session \
  --target i-0e7440e9e0350f731 --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["18080"],"localPortNumber":["18080"]}'
```
⇒ 브라우저 **https://localhost:18080** (자체 서명 인증서 경고는 통과). 계정 `admin`.
- ⛔ **비밀번호를 `send-command` 로 조회하지 않는다** — 출력이 SSM 에 저장된다.
  **대화형 세션**(`aws ssm start-session --target …`)에서 사람이 직접 읽는다:
  `sudo KUBECONFIG=/root/.kube/config kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`
- ⚠️ **kubeconfig 도 port-forward 도 인스턴스 교체와 함께 사라진다** — 여전히 `40` 열린 항목 8이다.
  이 절차는 **해결이 아니라 우회**다.

---

#### 🔚 **2026-08-11 세션 ③ — `23 §2.3` seed 완결. 그리고 절차서의 빈칸이 함정을 만들었다**

「다음 태스크 4번」을 닫았다. 설계 SSOT = **`23 §2.3-1`**(신설).

| 대상 | 변경 |
|---|---|
| `docs/design/23-argocd-self-managed.md` | **§2.3-1 신설** — `--core` 실패 근거 · 정정 절차 · 완료 판정 · 웹 UI 2홉 |
| `scripts/argocd-seed.sh` | 4)·5) 보강 — **비밀번호 교체 명령을 채웠다**(아래 🔴) |

##### 🔴 **`ARGOCD_OPTS='--core'` 로는 `argocd account update-password` 가 안 된다**

`failed to get issue time: unable to extract token claims`.
`server/account/account.go`: `issuer := session.Iss(ctx)` 가 core 모드에선 **`""`** →
분기 조건이 `issuer != "argocd"` **하나뿐**이라 **"SSO 사용자"로 오분류** → `session.Iat(ctx)`
(`util/session/sessionmanager.go:687`)가 클레임 없음으로 죽는다.

- 🔑 **`--core` 는 "인증 우회"가 아니라 "인증 부재"다.** argocd-server 를 **우회**하므로 세션이 없다.
  ⇒ **신원이 필요한 작업(비밀번호·계정·토큰)은 `--core` 로 하지 않는다.**
- ⭐ 해법도 CLI 안에 있었다 — **`--port-forward`**(`cmd/argocd/commands/login.go:67-74`:
  이 플래그면 **SERVER 인자를 요구하지 않고** `server = "port-forward"` 컨텍스트를 만든다).
  사용자가 `ARGOCD_OPTS` 를 쓴 감각이 옳았고 **플래그만 틀렸다** —
  CLAUDE.md 「발명하기 전에 찾는다」의 그 형태다(없는 게 아니라 안 넘기고 있었을 뿐).
- ⚠️ **`--insecure`(클라이언트 검증 생략) ≠ `server.insecure`(서버 TLS off).** 우리는 후자를
  건드리지 않으므로 자체 서명 TLS 이고, `localhost:<random>` 이라 CN 이 안 맞아 전자가 필수다.

##### ⭐ **"에러처럼 보이는 것"과 "실패"를 가른 기준 — 로그 레벨이 아니라 산출물**

`update-password` 실행 중 `broken pipe` 가 error 레벨 JSON 으로 쏟아졌다. **실패가 아니었다** —
`--port-forward` 는 포워더를 **CLI 프로세스 안에서** 돌려 커넥션 teardown 마다 그 로그를
**stderr** 로 내고, 프롬프트는 **stdout**(`util/cli/cli.go:167`)이라 한 줄에 겹쳤을 뿐이다.
🔑 **판정 근거는 프롬프트에 찍힌 `(admin)`** 이었다 — 서버에서 받아온 값이므로 앞 호출 성공의 직접 증거.
⇒ `2>/tmp/argocd-pw.err` 로 분리한다.

##### 🔴 **진짜 결함은 CLI 가 아니라 우리 절차서에 있었다**

`scripts/argocd-seed.sh:271` 이 *"비밀번호를 **바꾸고** 초기 Secret 을 지운다"* 라고 써 놓고
**삭제 명령만** 있었다. **그 빈칸에서 `--core` 를 집어들게 된다.**
⇒ 교체 명령 3줄 + 함정 3건 + **5) 교체 판정** 절을 채웠다. `bash -n` + heredoc 렌더 실측 확인.
🔑 **"완료 조건"이라고 선언한 행동은 명령까지 적어야 한다** — 조건만 적고 수단을 비우면
읽는 사람이 그 자리를 스스로 메우고, 그 메움이 틀린다.

##### ✅ 완료 판정 (SSM send-command 실측)

| 항목 | 결과 |
|---|---|
| `admin.passwordMtime` | `2026-08-07T06:25:04Z` → **`2026-08-11T06:35:19Z`** |
| `argocd-initial-admin-secret` | **`DELETED`** |
| Application 8개 | **전부 `Synced`/`Healthy`** |

⭐ **`selfHeal` 이 비밀번호를 되돌리지 않는다는 추론이 실물로 닫혔다.** 차트가 `argocd-secret` 을
**`data` 없이** 렌더하므로(`30 §2.10.1`) 런타임에 채워진 `admin.password` 는 **ArgoCD 소유 필드가
아니다**(`ServerSideDiff=true` 하 SSA 필드 소유권 — `30 §2.10.6`). 교체 후 `Synced` 유지가 증거다.

##### 🖥️ 웹 UI 2홉 — **포트 18080 으로 실측 성공** (`{"Version":"v3.5.0"}` · `200`)

절차 전문은 **`23 §2.3-1`** 이 소유한다(notepad 앞 절의 판본을 대체). 요지만:
- 안쪽 홉이 필요한 이유 = **`ClusterIP` 가 가상 IP**(노드가 아닌 workbench 엔 kube-proxy 룰이 없다).
  바깥 홉이 필요한 이유 = **workbench 인바운드 0**(`modules/workbench/main.tf:43`).
  ⭐ **둘 다 SG 를 열지 않는다** — 기존 인증 채널 위에 스트림만 얹으므로 "공개 표면 0" 이 유지된다.
- ⛔ **pod IP 직결로 우회하지 않는다.** VPC CNI 라 pod 는 실제 VPC IP 를 갖지만 재스케줄마다 바뀌고
  SG 두 층을 뚫어야 한다 — **재현 불가능한 임시방편**이다.
- ⚠️ 여전히 **인스턴스 교체와 함께 사라진다**(수동). `23` 열린 항목 1이 그 자리다.

---

#### 🚧 **2026-08-11 세션 ④ — 문서 zero-base 재작성 (진행 중, Wave 3/8 완료)**

사용자 결정: *"모든 문서를 없애고 zero base로 다시 작성."* 계획 = `.omc/plans/2026-08-11-docs-zero-base.md`
(gitignore 대상). ⛔ **아카이브 태그 `docs-archive-20260811`** 에 구 문서 10,792줄 전문 보존.

##### 진행 상황

| Wave | 상태 | 커밋 |
|---|---|---|
| 0 아카이브 + 기각 항목 190→34 선별 | ✅ | 태그 |
| 1 README 재작성 (사실 오류 해소) | ✅ | `c650b58` |
| 2 `01-architecture` · `02-choose-your-path` | ✅ | `c650b58` |
| 3 `03`~`08` + `scripts/teardown-verify.sh` | ✅ | `3d65edf` |
| **4-a 실증 destroy (L1~L3)** | ✅ **완료** — 잔존물 0 | gitops PR **#24** |
| **4-b 실증 recreate** | ✅ **완료**(2026-08-12) | |
| 5 실증 결과를 `03`·`04`에 반영 | ✅ | `74d7b20`(04) · `59f6fc7`(03·07·08) |
| 6 (Wave 3에 흡수됨) | ✅ | |
| **7 구 문서 삭제 + 참조 정리 + `CLAUDE.md`** | ✅ **완료**(2026-08-12) | 최상단 상자 참조 |
| 8 gitops·reference-infra README | ⏳ **다음 태스크** | |

##### 새 문서 집합 (1,488줄 — 구 10,792줄 대비 **86% 감소**)

`README`(80) · `01`(127) · `02`(139) · `03`(224) · `04`(253) · `05`(192) · `06`(189) · `07`(193) · `08`(91)

⚠️ **구 문서(`docs/architecture/`·`design/`·`consumer/`)는 아직 지우지 않았다** — Wave 7이 지운다.
새 문서를 쓰는 동안 **구 문서가 원자재**이기 때문이다.

##### 🔑 재작성이 지킬 규칙 7개 (`06-conventions.md` §8에 명문화)

P1 독자로 파일을 가른다 · P2 **변경 이력을 본문에 안 쓴다** · P3 **이모지는 표의 `✅ ⏳ ❌` 만** ·
P4 **400줄 상한** · P5 선택은 표로 절차는 명령으로 · P6 링크는 문서 단위 ·
P7 **정정 서술 금지**(현재 사실만).
📌 판정 자동화: `grep -c "정정\|틀렸다\|철회\|초판\|무효"` → **`06:189`(규칙 자신의 선언) 1건만 허용**.

##### ⚠️ 리뷰 요망 — 판별 기준 1건을 재배치했다

구 `22 §3.1`은 *"상시 운영 전담 인력"* 을 **프로파일 A/B 판정의 1번 질문**으로 뒀다. 그러나 그 비용은
**self-managed 일 때만** 난다(관리형은 AWS 소유). 구 문서의 `22:190` 상자가 이 모순을 이미 인지하고도
*"21을 닫는 데 필요한 일이 아니었다"* 로 보류했었다. 새 `02`는 질문을
**A(GitOps 필요한가) → B(어느 ArgoCD인가)** 로 분리하고 인력 요구를 B의 운영 특성 표로 옮겼다.
🔴 **판정 결과가 바뀌는 변경이다.** 동의하지 않으면 되돌린다.

##### ⭐ `scripts/teardown-verify.sh` 신설 — 삭제는 사람이, 검증은 기계가

`bootstrap/verify.sh` 의 거울. **음성 테스트 통과**(2026-08-11): 자원이 살아 있는 상태에서 돌려
NAT·EC2 3대·EKS·VPC·로그그룹을 **정확히 우리 것만** 잡고 `exit 1`
(VPC 27개 중 1개 · EKS 3개 중 1개 — 공용 계정에서 태그 스코핑이 동작한다는 증거).
⛔ **삭제는 자동화하지 않는다** — `bootstrap.sh` 는 멱등성이 안전망이지만 teardown 은 아니다.

##### 🔬 **Wave 4-a 실증 발견 8건 — Wave 5의 입력이다** (scratchpad 소실 대비 전문 이관)

⭐ **destroy 를 실제로 해봤기 때문에 나온 것들이다.** 문서만 써서는 절대 나오지 않는다.

> ### ✅ **문서 반영 완료 (2026-08-12, `74d7b20`)** — 8건 중 **6건이 `docs/04-teardown.md` 로 접혔다**
>
> | 발견 | 반영 위치 |
> |---|---|
> | G4 로컬 destroy 불가 | 04 §4 (+ §2 의 보호 해제 apply 도 워크플로 경로로) |
> | G7 syncPolicy 되돌려짐 | 04 §3 (+ §6 부분 삭제는 **반대 처방**임을 명시) |
> | G8 로그 그룹 재생성 | 04 §1 표 · §5 · §8 |
> | G1 `backend.hcl` 루트마다 | 04 §4 |
> | G5 pre-push 훅 자격증명 | 04 §2 |
> | G2 destroy 워크플로 | 04 §4 (명령 실물) |
>
> **남은 1건은 `03` 소관**: **G3** `execution_role_arn` 출처(`gh variable list`) — 03 은 재구축
> 실증으로 채우기로 한 문서라 지금 손대지 않았다.
>
> 🔴 **04 를 고치다 발견한 새 의심 지점(미판정)**: `03 §?` 이 `tofu -chdir=... plan` 을 **로컬에서**
> 시킨다(`03:136`). G4 와 같은 이유로 실패할 개연성이 높다 — provider 가 실행 Role 을 assume 하므로.
> ⚠️ **추정이라 고치지 않았다.** 재구축 때 **그 줄을 실제로 실행해 판정한다.**
> (backend 접근은 로컬 프로파일로 되는 것이 G5 로 확인됐으니, 갈리는 지점은 provider 다.)

| # | 발견 | 성격 |
|---|---|---|
| G1 | `backend.hcl` 이 **루트마다** 필요한데 `04` 에 없다. `live/dev/eks/` 것이 로컬에 없었다(gitignore) | 보완 |
| G2 | destroy 는 워크플로 경로가 없었다 | **해결**(PR #24) |
| **G4** | 🔴 **로컬에서 destroy 실행 불가 — 설계 갭** | **해결**(PR #24) |
| G3 | `execution_role_arn` 이 required 인데 출처가 문서에 없다 → **`gh variable list`** | 보완 |
| G5 | pre-push 훅의 `validate` 가 backend 자격증명을 요구 → **`AWS_PROFILE=team git push`** | 보완 |
| G6 | syncPolicy 는 **root-app 부터** 꺼야 한다(App-of-Apps) | 보완 |
| **G7** | 🔴 **syncPolicy 를 꺼도 되돌려진다** | **초안 결함** |
| **G8** | 🔴 **Flow Logs 로그 그룹이 destroy 도중 재생성된다** | **초안 결함** |

> ### 🔴 **G4 — 현재 이 환경은 IaC 로 삭제할 수 없었다** (가장 큰 발견)
>
> 세 사실이 겹쳐 파기 경로가 **존재하지 않았다**: ① 워크플로에 destroy 잡 없음
> ② provider 가 `assume_role` 로 실행 Role 사용 ③ 실행 Role 신뢰가 **입구 Role 하나뿐**.
> 실측: `aws sts assume-role … -> AccessDenied` (로컬 user 는 `AWStf_admin` 인데도).
> ⇒ **D27-1 의 의도된 귀결이다 — 결함이 아니라 누락**이다. 생성만 만들고 파기를 안 만들었다.
> **해결**: `iac-reference-infra` PR **#24**(`b060fc3`) — `workflow_dispatch` 입력 `action=destroy`.
> ⭐ **`apply` job 은 한 줄도 안 바꿨다** — 저장된 plan 파일을 적용하는 구조라 파기 계획도 그대로 흐른다.
> 신뢰 경계를 **우회하지 않고 그 안에** 경로를 만들었다. `confirm` 에 루트 이름을 손으로 적게 했다.

> ### 🔴 **G7 — `syncPolicy` 를 끄는 것만으로는 부족하다**
>
> 실측: 자식 Application 7개를 patch 했는데 **확인 시점에 6개가 원래 값으로 되돌아가 있었고**
> NodePool 도 삭제 직후 되살아났다(`NodePool: 1`).
> **원인**: `kubectl patch` 로 GitOps 리소스를 바꾸는 것은 **경쟁 상태**다 — 컨트롤러가 계속 살아서
> 큐에 있던 sync 가 Git 의 desired state 로 되돌린다.
> **해법**: `kubectl -n argocd scale statefulset argocd-application-controller --replicas=0`
> (+ `applicationset-controller`). 실측 확인 — 정지 후 삭제하니 30초 뒤에도 **NodePool 0 유지**.
> ⚠️ **전체 파기에서만 옳다.** *"GitOps 만 걷어내기"* 부분 삭제에서는 **Git 에서 지우는 것**이 정석.

> ### 🔴 **G8 — Flow Logs 로그 그룹이 destroy 도중 재생성된다**
>
> destroy 완료 후 `teardown-verify.sh` 가 로그 그룹 하나를 잡았다.
> 생성 시각 **2026-08-11 14:20 UTC**(= destroy 도중) · `retentionInDays` **`None`**
> (모듈 `flow-logs.tf:39` 는 항상 값을 설정한다).
> ⇒ 원본은 지워졌고, **아직 살아 있던 Flow Logs 가 로그를 쓰자 CloudWatch 가 자동 생성**했다.
> 자동 생성이라 **보존 무기한** — 저장 비용이 영원히 나가는 고아다.
> 🔑 **`tofu destroy` 는 성공을 보고했고 state 에도 없어 다음 apply 에서도 안 보인다.**
> ⇒ `04 §5` 에 로그 그룹을 **경쟁 상태 항목**으로 승격하고 "destroy 후 재확인"을 절차에 넣는다.

> ### ⭐ **G7·G8 이 같은 형태다 — "명령은 성공했는데 상태가 원래대로"**
>
> 분산 시스템에서 삭제는 **한 번의 명령이 아니라 수렴 과정**이다.
> ⇒ teardown 절차는 **"지운 뒤 다시 확인한다"** 를 단계로 가져야 한다.
> 🔑 *"삭제는 사람이, 검증은 기계가"* 라는 설계 판단이 여기서 값을 냈다 —
> **자동 삭제 스크립트였다면 G8 을 못 봤다**(지우고 끝냈을 테니까).

##### ✅ `teardown-verify.sh` 양성·음성 양쪽 검증됨

자원이 있을 때 **정확히 우리 것만** 잡고 `exit 1`(VPC 27개 중 1개·EKS 3개 중 1개),
전부 지운 뒤 **잔존물 0 · `exit 0`**. 공용 계정 태그 스코핑이 실증됐다.

##### 📌 Wave 0의 발견 — 재작성의 값을 보여주는 지표

구 문서의 `⛔` **190건 중 절반이 "문서 인용 규칙"** 이었다(*"미개정 문서를 인용 말 것"*,
*"절 번호까지 쓸 것"*, *"상태표가 유일한 판정 근거"*). **문서가 복잡해서 생긴 규칙**이므로
재작성으로 **자동 소멸**한다. 실제로 `08-decisions.md` 로 남길 것은 34건이었다.

---

### 미결 항목

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
- ~~관리형 ArgoCD 채택 여부 재결정(`docs/architecture/01-module-strategy.md` §3.3)~~
  ✅ **해소**(2026-08-07, **D-GITOPS-SEAM** — `docs/design/21 §1`). 프로파일 A 내부 분기로 확정.
  ⏸ 파생 미결 1건: **`22 §3.1` 판별표 완화**(관리형이 질문 1·4 를 동시에 푼다) — 보류, 위 절 참조.
- VPC 설계 **열린 항목 6건**은 `docs/design/10-vpc-module.md` 말미 참조 —
  **1** TGW attachment · **2** prefix list 소유권 · **3** IPAM 연계 · **4** Flow Logs 대상 확장(S3/Firehose) ·
  **5** private NAT 옵션 · **9** per-AZ NAT 개수 기준(호스트 그룹이 넓으면 미사용 NAT가 AZ당 ~$43/월).
  ✅ 해소됨: **6**(IAM inline 약어 — 부모 이름 상속 규약) · **7**(confused deputy — vpc-v1.1.0) ·
  **8**(`fl` 약어 등재). ⚠️ 남은 6건은 전부 **수요 발생 시** 착수 성격이라 지금 차단 요인이 아니다.

