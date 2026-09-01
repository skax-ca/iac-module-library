---
name: notepad-sync
description: 이 프로젝트(iac-module-library)의 .omc/notepad.md·project-memory.json 관리 절차. 전역 session-start/session-end 스킬이 3단계(세션 태스크 확인/메모리 갱신)에서 이 스킬이 있으면 호출하도록 위임한다. OMC가 이 머신에서 비활성 상태(~/.claude/.omc-enabled 없음)면 조용히 건너뛴다.
---

# Notepad Sync (project-scoped)

이 프로젝트는 `eks-reference-infra`와 **동일한** OMC notepad 3단 구조(**Priority** 포인터·500자
이내 / **Working** 세션 서술·7일 자동 소멸 / **MANUAL** 영구 아카이브·자동 로드 안 됨)와
`project-memory.json`(구조화 영구 사실)을 쓴다(2026-08-19 전환 — 이전에는 이 repo만의 날짜별
prepend 방식을 썼으나, eks-reference-infra와 다른 메커니즘을 유지할 이유가 없어 통일했다).
세션 종료 시 "무엇을 어디에 저장할지" 판단은 **OMC가 이미 제공하는
`oh-my-claudecode:remember` 스킬에 위임**한다 — 그 판단 로직을 여기서 다시 만들지 않는다. 이 파일은
그 위임 전 가드와, `remember`가 모르는 이 repo 고유의 제약만 얹는다.

⚠️ **2026-08-30, MANUAL을 별도 파일로 분리** — `.omc/notepad-manual.md` 신설, `notepad.md`의
`## MANUAL` 섹션은 그 파일을 가리키는 포인터 한 줄만 남았다. 원인: MANUAL 아카이브 자체가
이미 200KB+로 커서 `notepad.md`가 pre-commit의 150KB 경고에 상시로 걸렸고, Working Memory를
MANUAL로 "이관"해도 같은 파일 안이라 총 바이트가 안 줄었다(2026-08-30 세션 실측). 이 시점부터
**`eks-reference-infra`와 구조가 갈렸다** — 그쪽은 아직 단일 파일이다, "동일한 구조"라는 위 문장을
MANUAL에는 그대로 적용하지 말 것. Priority·Working은 여전히 동일.

## 0. 가드 — OMC가 이 머신에서 꺼져 있으면 전부 건너뛴다

`~/.claude/.omc-enabled` 파일이 없으면 (또는 `oh-my-claudecode:remember` 스킬이 안 보이면)
아래 1~2 절 전부 건너뛰고 다음 한 줄만 안내한다: "이 머신은 OMC 비활성화 상태라 프로젝트 컨텍스트
확인/저장을 생략합니다(`touch ~/.claude/.omc-enabled`로 활성화 가능)." 에러로 취급하지 않는다 —
이 프로젝트가 OMC를 쓰기로 한 것과, 지금 이 머신에서 OMC를 켰는지는 별개다.

## ⛔ 2026-09-01, `mcp__t__notepad_*`/`mcp__t__project_memory_*` 도구 사용을 전면 중단

원인: 이 도구들은 "읽기"조차 내부적으로 프로젝트를 재스캔해 서술형 필드를 빈 스키마로 덮어쓰거나
(2026-08-30·2026-09-01 두 차례 재현), `add_note`가 20개 FIFO로 경고 없이 오래된 항목을 삭제하거나,
git merge/pull 직후 stale 캐시 기반으로 파일을 3중복 재작성하는 등 표준 Read/Edit 도구엔 없는
부수효과를 갖고 있다(전부 실측, 상세는 `.omc/project-memory.json`의 `mcp-tooling-bug` 카테고리
참조). 쓰기 6종만 막았던 이전 방어(PreToolUse 훅)로는 오늘 재발한 읽기 쪽 사고를 못 막았다.

대응: `.claude/settings.json`에 `permissions.deny`로 이 두 도구군(`notepad_*`·`project_memory_*`,
읽기·쓰기 전부)을 등록해 **Claude의 도구 목록에서 아예 제거**했다(호출을 막는 게 아니라 존재
자체를 안 보이게 하는 방식 — 훅보다 근본적이고, 훅 타임아웃으로 새는 경우도 없다). 그래서 이제
`.omc/notepad.md`·`.omc/notepad-manual.md`·`.omc/project-memory.json` 세 파일은 **읽기·쓰기 전부
Read/Edit 도구로 직접** 다룬다 — `CLAUDE.md`를 다루는 것과 완전히 같은 방식이다. 과거에 있던
"이 도구는 세션이 시작된 worktree에 고정된다"는 worktree 격리 캐비어트도, 도구 자체를 안 쓰니
더 이상 해당 없음.

이 결정은 이 저장소 한정이다 — `eks-reference-infra`·`aks-reference-infra`는 아직 같은 MCP
도구를 그대로 쓴다. 그쪽도 반영할지는 별도 판단(그쪽 세션에서 검토).

## 세션 시작 시 (session-start 3번에서 호출됨, 가드 통과 후)

1. `Read`로 `.omc/notepad.md`를 열어 `## Priority Context` 섹션을 사용자에게 보여준다.
2. `Read`로 `.omc/project-memory.json`을 열어 `customNotes`의 `open-items` 카테고리 중 최신
   항목들로 미결 사항을 확인한다.
3. 같은 `.omc/notepad.md`의 `## Working Memory` 섹션에 최근 7일 내 세션 서술이 있으면 함께
   보여준다.
4. Priority Context가 눈대중으로 500자를 넘어 보이면 — 정리하지 말고 사용자에게 먼저 알린다.

## 세션 종료 시 (session-end 2번에서, 커밋 전에 호출됨, 가드 통과 후)

1. **`oh-my-claudecode:remember` 스킬을 호출**해 이번 세션의 발견 사항을 분류·저장시킨다
   (project memory / notepad priority / notepad working / docs 중 어디로 갈지는 그 스킬이 판단한다).
2. `remember`가 모르는, 이 repo만의 제약을 그 판단에 추가로 적용한다:
   - **`.omc/notepad.md`(Priority·Working)·`.omc/notepad-manual.md`(MANUAL)·
     `.omc/project-memory.json` 세 파일 전부 `Edit`/`Read` 도구로 직접 다루는 것이 유일한
     경로다**(2026-09-01부터 MCP 도구는 `permissions.deny`로 아예 제거됨, 위 절 참조).
     Priority Context는 500자 이내 유지(전체 교체 방식 유지, append 아님). Working Memory는
     최신 항목을 `## Working Memory` 바로 아래(상단)에 추가. 쓴 뒤에는 반드시 `git diff`로
     의도한 변경만 있는지, 이 스킬 4번의 중복 검사(`awk` 정규화 검사)로 헤더 중복이 없는지
     확인한다 — 도구가 사라져 그 계열 버그는 구조적으로 불가능해졌지만, Edit 오사용(예: 실수로
     기존 블록 복제)은 여전히 사람이 낼 수 있는 실수라 이 확인은 유지한다.
   - **MANUAL은 별도 파일(2026-08-30 분리)**: `.omc/notepad-manual.md`에 직접 Edit. `notepad.md`
     안의 `## MANUAL`은 그 파일을 가리키는 포인터 한 줄만 유지하고 건드리지 않는다.
   - `docs/*.md`에는 날짜·사건 서술을 쓰지 않는다(`docs/writing-style.md` — 이 repo의
     docs는 설계·규약만 소유) — `remember`가 "docs"를 저장 후보로 제안해도 서술형 내용이면
     notepad로 돌린다.
   - `project-memory.json`은 `.gitignore` 화이트리스트로 git 커밋 대상이다(notepad.md와 함께
     크로스 머신 SSOT) — 이 머신에만 유효한 임시 정보는 넣지 않는다.
   - ⛔ **fork/서브에이전트(team 모드 포함)는 notepad에 직접 쓰지 않는다.** 결과를 텍스트로
     보고만 하고, notepad 기록은 **team-lead(메인 세션)가 세션당 한 번만** 통합해서 쓴다 —
     2026-08-26~28 세션들에서 fork가 각자(또는 컨텍스트 소진 후 team-lead가 재수습하며) notepad를
     따로 써서 Working Memory 헤더가 8회 중복·797KB까지 비대화된 실제 사고가 있었다
     (`.omc/notepad.md` 커밋 `7a2ea22` 정리, 원인 진단은 그 커밋 메시지 참조).
3. 이 단계가 끝난 뒤에만 session-end 3번(커밋)으로 넘어간다 — 위 변경분이 그 커밋에 함께 실려야 한다.
4. `.githooks/pre-commit`이 notepad.md staged 시 Working Memory 내 동일 헤더 중복을 자동 차단하고
   150KB 초과를 경고한다(커밋 `a329c26`, 위 사고 재발방지). 이 훅에 막히면 "왜 막혔는지 원인부터
   진단"하지 말고 — 위 fork 규율 위반 여부부터 의심할 것. `--no-verify` 우회는 정말 의도적인
   중복(드묾)일 때만, 사유를 커밋 메시지에 남기고 쓴다.
   - 이 검사는 `.omc/notepad.md`만 본다. `.omc/notepad-manual.md`(MANUAL 아카이브)는 대상이
     아니다 — 애초에 자동 로드 안 되는 파일이라 비대화가 같은 의미의 문제가 아니고, 헤더가
     H2/H3 섞여 있어 검사 자체가 안 맞는다. 이 파일이 계속 자라는 건 정상이다.
   - ⚠️ 2026-08-30 실측: 검사가 `## `(H2)만 보고 실제 항목 헤더 `### `(H3)를 놓쳐 106줄짜리
     중복이 안 잡히고 남아있었던 사고가 있었다(`.githooks/pre-commit` 커밋 `37e3d01`에서
     `#{2,3}` + 헤더 텍스트 정규화로 수정). 이 훅이 "있으니 안전하다"고 가정하지 말고,
     의심스러우면 `awk` 검사식을 백업본에 직접 돌려 역검증할 것.

## opencode 세션

`.opencode/plugins/notepad.ts`가 이 repo 안에서 같은 3단 구조 툴(`notepad_read`/
`notepad_write_priority`/`notepad_write_working`/`notepad_write_manual`)을 제공한다
(eks-reference-infra의 것과 로직이 동일 — 구조가 같아졌으므로 그대로 이식했다). 위 MCP
worktree 격리 문제가 없다 — 플러그인은 이 repo 프로세스 안에서 직접 파일을 다룬다.

⚠️ **미확인(2026-08-30 MANUAL 분리 이후 검증 안 됨)**: 이 플러그인의 `notepad_write_manual`/
`section="manual"` 읽기가 여전히 `notepad.md` 안의 `## MANUAL`만 보고 동작한다면, MCP 쪽과
같은 이유로 `.omc/notepad-manual.md`의 실제 아카이브를 모른다. opencode 세션에서 MANUAL을
다룰 일이 생기면 먼저 `.opencode/plugins/notepad.ts` 소스를 열어 이 분리를 반영해야 하는지
확인할 것 — 아직 이 플러그인 코드 자체는 갱신하지 않았다.
