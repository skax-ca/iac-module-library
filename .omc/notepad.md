# Notepad — iac-module-library

## Priority Context
SSOT=이 repo. 엔진=OpenTofu(decisions.md 재제안 전 필독). 규약=conventions.md(이름포맷 AWS=Name태그/Azure=name인자, 노드풀명은 conventions §2-6 소유). 네이밍=docs/naming/abbreviations/{aws,azure}.md(Azure 13개·5카테고리). 모듈경로=modules/<provider>/<name>/. .tf규칙=.claude/rules/terraform.md. AWS4+Azure2 전 6모듈 릴리스 완료(vnet-v0.2.0·aks-cluster-v0.1.0 포함, PR #38 merge 완료). 다음 Azure 모듈 착수 여부는 사용자 판단. 영구사실=project-memory.json.

## Working Memory
### 2026-08-30 (세션2) — 글로벌 CLAUDE.md 트리밍 + notepad.md 2차 중복 발견·제거 + pre-commit 훅 레벨 버그 수정

사용자 요청으로 `~/.claude/CLAUDE.md`의 "OMC 플러그인 disabled" 트러블슈팅 절(위 세션1이 그날 작성)을
63줄→8줄로 정리. 근본원인 절의 날짜·사건 서술을 걷어내고 확인·해결 명령 두 줄만 남김. bootstrap.sh의
`enabledPlugins` 병합 로직이 실제로 존재하고 현재 플러그인도 `enabled: true`임을 실측 확인 후 진행.
dotfiles push(`eea8feb`)로 반영.

이어서 "notepad 문제 없는지 확인"을 요청받아 점검하던 중 **2026-08-28 사고와 별개의 신규 중복 사고**를
발견: 335~441줄(106줄)이 58~163줄과 완전히 동일한 블록으로 중복 삽입돼 있었다(diff로 바이트 단위
동일 확인). git blame으로 근본원인 추적: PR #38 squash-merge 커밋(`4fc6a488`, 17:40)이 브랜치에
쌓여있던 304줄을 main에 얹었는데, 4분 뒤 세션5가 자신의 요약을 기록한 커밋(`8297c8ba`, 17:44)이
**merge로 막 갱신된 디스크 최신본이 아니라 merge 이전 stale 캐시를 기준으로 파일을 재구성**하며
방금 들어온 내용 상당수를 "새 내용"인 양 다시 덧붙였다 — project-memory의 `mcp-tooling-bug`
카테고리가 기록한 "stale 캐시 기반 전체 재작성" 패턴이 git merge 직후 시점에 재현된 것.

**왜 방어 훅이 못 막았는지도 규명**: `.githooks/pre-commit`의 중복 검사가 `/^## /`(H2)만 보는데
실제 세션 항목 헤더는 전부 `### `(H3)라 애초에 이 클래스의 중복을 구조적으로 탐지 불가능한
상태였다(이 사고 자체는 2026-08-28로 훅 신설(2026-08-30) 이전이라 어차피 안 잡혔겠지만, 훅의
레벨 버그는 지금도 살아있어 같은 사고가 재발해도 여전히 못 잡는 상태였다). `.githooks/pre-commit`의
정규식을 `/^#{2,3} /`로 확장해 H2·H3 모두 검사하도록 수정 — 백업본(중복 있던 원본)에 새 정규식을
적용해 18개 헤더가 정확히 잡힘을, 수정된 현재 파일엔 0건임을 각각 실측 검증.

부수 발견: Priority Context와 Working Memory 사이에 깨진 잔여 줄 2개("## MANUAL(자동 로드 안 됨)
참조."/"## MANUAL`(자동 로드 안 됨) 참조.", 커밋 `0e17b01d`·`7b07a9ad`로 하루 간격을 두고 각각
추가된 것 — 이 역시 같은 계열의 소규모 중복 삽입 사고로 추정)를 발견해 제거.

결과: notepad.md 3803줄/356KB → 3696줄/337KB(중복 106줄 + 잔여 4줄 제거). 백업은 `/tmp/notepad.md.bak`.

**교훈**: 이 프로젝트의 stale-캐시 재작성 버그는 "MCP 쓰기 도구 호출 시"뿐 아니라 "git 상태가
방금 바뀐 직후(merge/pull 등)의 다음 쓰기"에서도 같은 증상으로 재현된다 — 트리거가 도구 종류가
아니라 "디스크 상태와 세션이 들고 있는 캐시가 어긋난 타이밍"이라는 뜻. 방어 훅은 만든 뒤에도
정규식이 실제 데이터 형태(H2 vs H3)와 맞는지 반드시 백업본으로 역검증할 것 — 이번처럼 "훅이
있으니 안전하다"는 가정 자체가 거짓일 수 있다.

**(이어서)** 사용자 요청으로 "150KB 넘는 오래된 세션을 MANUAL로 이관"까지 진행. 점검 중 헤더
레벨만 다른 중복(`## 2026-08-21 15:58` vs `### 2026-08-21 15:58`, 커밋 히스토리상 서로 다른 시점에
독립적으로 삽입된 것)을 추가 발견 — `uniq -d`는 문자열 완전 일치만 잡아서 훅이 놓치는 사각지대였다.
orphan(`##` 버전)을 삭제하고, 훅 정규식에 `gsub(/^#+ /,"")`로 헤더 텍스트 정규화를 추가해 이 클래스도
잡히게 함(백업본 역검증으로 확인). 이관 자체는 Working Memory(6~48줄, 2026-08-30 두 항목만 남김)의
과거 완료 스레드(2026-08-14~08-28, Azure 기반구조·vnet·aks-cluster·iac-platform-gitops 리뷰 등
전부 완료·미결 없음)를 `## MANUAL` 최상단(기존 아카이브보다 최신이라 그 위)에 이관. ⚠️ **중요한 한계**:
이 이동은 파일 총 바이트를 줄이지 않는다(MANUAL도 같은 파일 안이라 pre-commit의 150KB 총량 경고는
그대로 유지) — MANUAL 자체가 이미 옛 아카이브(2026-07-29~08-14, ~270KB)로 커서 그게 총량의
대부분을 차지한다. 실질 효과는 **세션 시작마다 notepad-sync가 읽는 Working Memory 크기**를
65KB→6KB로 줄인 것(MANUAL은 자동 로드 안 됨, 필요 시에만 조회). 150KB 총량 경고 자체를 없애려면
MANUAL 자체를 별도 파일로 분리하거나 더 오래된 부분을 쳐내는 별도 작업이 필요 — 오늘은 미착수,
다음에 필요성 판단.

**(다시 이어서)** 사용자가 곧바로 "MANUAL도 별도 파일로 분리해줘"를 요청해 실행. `## MANUAL`
섹션 본문 전체(3684줄)를 `.omc/notepad-manual.md`로 옮기고, `notepad.md` 쪽엔 그 파일을
가리키는 포인터 한 줄만 남겼다 — 결과: `notepad.md` 337KB→8KB(150KB 경고 완전 해소),
`notepad-manual.md`는 334KB(자동 로드 안 되니 무관). `.gitignore`에 새 파일 화이트리스트 추가,
내용 손실은 백업 대비 정렬-비교로 무손실 확인. `notepad-sync` 스킬 문서도 갱신: (1) MANUAL만
`eks-reference-infra`와 구조가 갈렸다는 점 명시 (2) `notepad_write_manual` MCP 툴이 이제
포인터만 건드리고 실제 아카이브는 모른다는 것, 이후 MANUAL 편집은 Edit으로 `.omc/notepad-manual.md`를
직접 쓸 것 (3) pre-commit 훅은 `notepad.md`만 검사하고 `notepad-manual.md`는 대상 밖(정상)
(4) `.opencode/plugins/notepad.ts`가 이 분리를 아는지는 미확인 — 다음에 opencode 세션에서
MANUAL을 다룰 때 먼저 소스 확인 필요.

### 2026-08-30 — 세션 요약: dotfiles OMC 플러그인 disabled 해결 + project-memory 도구 부수효과 버그 발견·복구

세션 시작 시 dotfiles `sync.sh pull`이 "oh-my-claudecode@omc(user scope)가 플러그인 등록부에서 disabled" 경고를 출력. `claude plugin list --json`으로 실측 확인 후 `claude plugin enable oh-my-claudecode@omc` 실행으로 해결. 이번 세션은 이미 로드된 상태를 쓰고 있어 무영향이었지만, 재시작 시 OMC 스킬·MCP 도구가 전부 안 보일 뻔했다. `~/dotfiles-claude/claude/CLAUDE.md`의 "머신별 OMC 활성화" 절에 이 별개 레이어(dotfiles opt-in 플래그 vs Claude Code 자체 플러그인 등록부) 관련 증상·확인법·해결법을 하위 항목으로 추가(커밋 `3ac1be2`, sync.sh의 auto-commit/push로 이미 원격 반영됨).

세션종료 절차 중 `git status`로 `.omc/project-memory.json`이 수정된 것을 발견 — 이번 세션에서 `mcp__t__project_memory_read`를 호출한 것 외엔 손댄 적이 없는데도, techStack/build/conventions/structure 4개 필드가 유효한 서술형 문자열에서 빈 자동스캔 스키마로 통째로 대체돼 있었다(customNotes 20개·userDirectives는 손실 없음). git show HEAD로 4개 필드를 복원. 이어서 `project_memory_add_directive`/`add_note`로 이 발견을 기록하려다 **두 번째 버그**를 발견: `add_note`가 20개 고정 상한 FIFO로 동작해, 새 노트 추가 시 가장 오래된 노트(azure-vnet 최초 구현 완료 기록, 다음 노트가 직접 참조하던 항목)를 경고 없이 삭제했다. git show HEAD로 삭제된 노트를 timestamp 순서에 맞춰 재삽입해 복구(21개로 정정). 이어서 이 항목 자체를 `notepad_write_working`으로 기록하려다 **세 번째 버그**를 재현: 2026-08-28 세션4와 동일하게 stale 캐시 기반 전체 재작성으로 다수 헤더가 3배 중복 삽입됨(322줄 증가, 헤더 다수 3중복 실측) — 즉시 `git checkout -- .omc/notepad.md`로 원복 후 이 항목은 Edit으로 직접 삽입.

**교훈**: 이 프로젝트에서 `mcp__t__project_memory_*`/`notepad_*` 계열 도구는 읽기·쓰기 가리지 않고 부수효과(재스캔에 의한 필드 손실, 20개 상한 FIFO 삭제, stale 캐시 기반 전체 재작성에 의한 3중복)를 낸다 — 이번 세션 한 세션 안에서만 3가지 서로 다른 유형을 실측했다. 매 호출 후 반드시 `git diff`/개수 대조로 검증하고, 손상 시 `git show HEAD` 또는 `git checkout --`로 즉시 복구할 것. 이 시점부터는 이 두 파일에 한해 MCP 쓰기 도구보다 Edit 직접 사용을 기본값으로 삼는 편이 안전하다. 상세는 `.omc/project-memory.json`의 `mcp-tooling-bug` 카테고리 노트 2건, critical directive 1건 참조.


## MANUAL

`.omc/notepad-manual.md` 참조 — 별도 파일로 분리됨(2026-08-30), 자동 로드 안 됨.
