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

`~/.claude/.omc-enabled` 파일이 없으면 (또는 `oh-my-claudecode:remember`/`mcp__t__*` 툴이 안 보이면)
아래 1~2 절 전부 건너뛰고 다음 한 줄만 안내한다: "이 머신은 OMC 비활성화 상태라 프로젝트 컨텍스트
확인/저장을 생략합니다(`touch ~/.claude/.omc-enabled`로 활성화 가능)." 에러로 취급하지 않는다 —
이 프로젝트가 OMC를 쓰기로 한 것과, 지금 이 머신에서 OMC를 켰는지는 별개다.

## ⚠️ `mcp__t__notepad_*`/`mcp__t__project_memory_*`는 "이 repo가 세션 프로젝트 루트일 때만" 동작한다

OMC 소스(`dist/lib/worktree-paths.js` `validateWorkingDirectory`) 실측 확인: 이 툴들이 실제로
쓰는 대상은 `workingDirectory` 인자가 아니라 **세션이 시작된 시점의 git worktree**로 고정된다
(의도된 worktree 격리 — 버그 아님). 그래서 **eks-reference-infra를 프로젝트 루트로 연 세션
안에서는 이 repo를 대상으로 이 툴을 쓸 수 없다** — 다른 프로젝트를 세션 중간에 대상으로
지정해도 조용히 eks-reference-infra에 쓴다(2026-08-14/19 두 차례 실제 오사고 발생, 둘 다
`git checkout`으로 복구). **이 repo 작업은 iac-module-library를 프로젝트 루트로 하는 별도
Claude Code 세션에서 한다** — 그 세션 안에서는 이 절 전체가 eks-reference-infra와 완전히
동일하게 동작한다.

## 세션 시작 시 (session-start 3번에서 호출됨, 가드 통과 후)

1. `mcp__t__notepad_read(section="priority")`로 포인터를 읽어 사용자에게 보여준다.
2. `mcp__t__project_memory_read(section="notes")`의 `open-items` 카테고리로 미결 항목을 확인한다.
3. `mcp__t__notepad_read(section="working")`로 최근 7일 내 세션 서술이 있으면 함께 보여준다.
4. Priority Context가 눈대중으로 500자를 넘어 보이면 — 정리하지 말고 사용자에게 먼저 알린다.

## 세션 종료 시 (session-end 2번에서, 커밋 전에 호출됨, 가드 통과 후)

1. **`oh-my-claudecode:remember` 스킬을 호출**해 이번 세션의 발견 사항을 분류·저장시킨다
   (project memory / notepad priority / notepad working / docs 중 어디로 갈지는 그 스킬이 판단한다).
2. `remember`가 모르는, 이 repo만의 제약을 그 판단에 추가로 적용한다:
   - ⛔ Working/Priority에 쓸 때는 반드시 `mcp__t__notepad_write_working`/`notepad_write_priority`를
     통해서만 쓴다. `Edit`로 `.omc/notepad.md` 상단에 직접 prepend하지 않는다 — 이 repo에서
     2026-08-14 Priority Context 200KB 비대화의 직접 원인이 됐던 패턴이다.
   - Priority Context는 `notepad_write_priority`로 **전체 교체**한다(append 아님), 500자 이내 유지.
   - **MANUAL은 다르다(2026-08-30 분리 이후)**: `mcp__t__notepad_write_manual`은 `notepad.md`
     안의 포인터 한 줄만 건드릴 뿐 `.omc/notepad-manual.md`의 실제 아카이브는 모른다 — 이 MCP
     툴로 MANUAL을 쓰지 않는다. 아카이브에 추가할 내용은 **Edit 도구로
     `.omc/notepad-manual.md`를 직접 편집**한다(자주 안 쓰이는 파일인 데다, 아래 MCP 쓰기 도구의
     반복된 부수효과 버그를 감안하면 Edit 직접 사용이 오히려 더 안전하다).
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
