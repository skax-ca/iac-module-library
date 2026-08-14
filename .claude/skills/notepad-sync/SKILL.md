---
name: notepad-sync
description: 이 프로젝트(iac-module-library)의 .omc/notepad.md·project-memory.json 관리 절차. 전역 session-start/session-end 스킬이 3단계(세션 태스크 확인/메모리 갱신)에서 이 스킬이 있으면 호출하도록 위임한다. OMC가 이 머신에서 비활성 상태(~/.claude/.omc-enabled 없음)면 조용히 건너뛴다.
---

# Notepad Sync (project-scoped)

이 프로젝트는 OMC의 notepad 3단 구조(**Priority** 포인터·500자 이내 / **Working** 세션 서술·7일 자동
소멸 / **MANUAL** 영구 아카이브·자동 로드 안 됨)와 `project-memory.json`(구조화 영구 사실)을 쓰기로
결정했다. 세션 종료 시 "무엇을 어디에 저장할지" 판단은 **OMC가 이미 제공하는
`oh-my-claudecode:remember` 스킬에 위임**한다 — 그 판단 로직을 여기서 다시 만들지 않는다. 이 파일은
그 위임 전 가드와, `remember`가 모르는 이 repo 고유의 제약만 얹는다.

## 0. 가드 — OMC가 이 머신에서 꺼져 있으면 전부 건너뛴다

`~/.claude/.omc-enabled` 파일이 없으면 (또는 `oh-my-claudecode:remember`/`mcp__t__*` 툴이 안 보이면)
아래 1~2 절 전부 건너뛰고 다음 한 줄만 안내한다: "이 머신은 OMC 비활성화 상태라 프로젝트 컨텍스트
확인/저장을 생략합니다(`touch ~/.claude/.omc-enabled`로 활성화 가능)." 에러로 취급하지 않는다 —
이 프로젝트가 OMC를 쓰기로 한 것과, 지금 이 머신에서 OMC를 켰는지는 별개다.

## 세션 시작 시 (session-start 3번에서 호출됨, 가드 통과 후)

1. `mcp__t__notepad_read(section="priority")`로 포인터를 읽어 사용자에게 보여준다.
2. `mcp__t__project_memory_read(section="notes")`의 `open-items` 카테고리로 미결 항목을 확인한다.
3. `mcp__t__notepad_read(section="working")`로 최근 7일 내 세션 서술이 있으면 함께 보여준다.
4. Priority Context가 눈대중으로 500자를 넘어 보이면 — 정리하지 말고 사용자에게 먼저 알린다.

## 세션 종료 시 (session-end 2번에서, 커밋 전에 호출됨, 가드 통과 후)

1. **`oh-my-claudecode:remember` 스킬을 호출**해 이번 세션의 발견 사항을 분류·저장시킨다
   (project memory / notepad priority / notepad working / docs 중 어디로 갈지는 그 스킬이 판단한다).
2. `remember`가 모르는, 이 repo만의 제약을 그 판단에 추가로 적용한다:
   - ⛔ notepad에 쓸 때는 반드시 `mcp__t__notepad_write_working`/`notepad_write_priority`/
     `notepad_write_manual`을 통해서만 쓴다. `Edit`로 `.omc/notepad.md` 상단에 직접 prepend하지
     않는다 — 이게 2026-08-14 Priority Context 200KB 비대화의 직접 원인이었다.
   - Priority Context는 `notepad_write_priority`로 **전체 교체**한다(append 아님), 500자 이내 유지.
   - `docs/*.md`에는 날짜·사건 서술을 쓰지 않는다(`docs/06-conventions.md` §8 P2·P7) — `remember`가
     "docs"를 저장 후보로 제안해도 이 repo에서는 서술형 내용이면 notepad로 돌린다.
   - `project-memory.json`은 `.gitignore` 화이트리스트로 git 커밋 대상이다(notepad.md와 함께 크로스
     머신 SSOT) — 이 머신에만 유효한 임시 정보는 넣지 않는다.
3. 이 단계가 끝난 뒤에만 session-end 3번(커밋)으로 넘어간다 — 위 변경분이 그 커밋에 함께 실려야 한다.
