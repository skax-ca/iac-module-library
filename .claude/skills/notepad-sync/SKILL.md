---
name: notepad-sync
description: 이 프로젝트(iac-module-library)의 .omc/notepad.md·project-memory.json 관리 절차. 전역 session-start/session-end 스킬이 3단계(세션 태스크 확인/메모리 갱신)에서 이 스킬이 있으면 호출하도록 위임한다. "세션시작"·"세션종료" 처리 중 이 스킬이 이미 로드돼 있으면 재호출하지 않는다.
---

# Notepad Sync (project-scoped)

`.omc/notepad.md`는 이 프로젝트에서 **Priority(포인터, 500자 이내) / Working(세션 서술, 7일 자동 소멸) /
MANUAL(영구 아카이브, 자동 로드 안 됨)** 3단 구조를 쓴다. `.omc/project-memory.json`은 구조화된 영구
사실(directives·conventions·structure·notes)을 담는다. 2026-08-14 재구성 배경은
`notepad-sync` 자체가 아니라 `.omc/notepad.md`의 MANUAL 아카이브에 있다.

## 세션 시작 시 (session-start 3번에서 호출됨)

1. `mcp__t__notepad_read(section="priority")`로 포인터를 읽어 사용자에게 보여준다.
2. `mcp__t__project_memory_read(section="notes")`의 `open-items` 카테고리로 미결 항목을 확인한다.
3. `mcp__t__notepad_read(section="working")`로 최근 7일 내 세션 서술이 있으면 함께 보여준다
   (지난 세션에서 마무리 못 한 확인 사항이 여기 있을 수 있다).
4. Priority Context가 눈대중으로 500자를 넘어 보이면 — 정리하지 말고 사용자에게 먼저 알린다
   (임의로 줄이면 아직 유효한 포인터를 지울 수 있다).

## 세션 종료 시 (session-end 2번에서, 커밋 전에 호출됨)

1. 이번 세션에서 있었던 일을 **`mcp__t__notepad_write_working`**으로 기록한다.
   ⛔ **`Edit`로 `.omc/notepad.md` 상단에 직접 prepend하지 않는다** — 이게 2026-08-14 Priority Context
   200KB 비대화의 직접 원인이었다. 반드시 이 툴을 통해서만 쓴다.
2. 이번 세션에서 알게 된 사실 중 **다음 세션에도 계속 유효한 것**(repo 경계·컨벤션·재발 가능한 운영
   함정 등)이 있으면 `mcp__t__project_memory_add_directive`(강제 규칙) 또는
   `mcp__t__project_memory_add_note`(참고 지식, category 지정)로 옮긴다. 세션 서술(Working)에만
   남기고 여기 안 옮기면 7일 뒤 사라진다.
3. Priority Context를 바꿔야 하는 변화(SSOT 위치 이동, 새 repo 경계 등)가 있으면
   `mcp__t__notepad_write_priority`로 **전체 교체**한다(append 아님). 500자를 넘기지 않는다.
4. 미결 항목이 새로 생기거나 닫히면 `project-memory.json`의 `open-items` 노트를 갱신한다
   (`project_memory_add_note`로 새로 추가 — 기존 항목 수정이 필요하면 `project_memory_write`로
   전체 갱신).
5. 이 단계가 끝난 뒤에만 session-end 3번(커밋)으로 넘어간다 — `.omc/notepad.md`와
   `.omc/project-memory.json` 변경분이 그 커밋에 함께 실려야 한다.

## 왜 project-memory.json이 git에 커밋되는가

`.gitignore`가 `/.omc/notepad.md`와 `/.omc/project-memory.json` 둘 다 화이트리스트해 뒀다
(2026-08-14) — 회사/집 Mac 크로스머신 핸드오프 SSOT가 이 둘이다. 다른 `.omc/**` 파일(state·plans 등)은
여전히 gitignore 대상이니 그쪽엔 영구 정보를 두지 않는다.

## 하지 않는 것

- `docs/*.md`에 날짜·사건 서술을 쓰지 않는다 — 그건 이 repo의 별도 규칙(`docs/06-conventions.md`
  §8 P2·P7)이고 CLAUDE.md/project-memory의 `conventions`가 이미 소유한다. 이 스킬은 notepad·
  project-memory 관리 절차만 다룬다.
- `notepad_prune`을 매 세션 강제 호출하지 않는다 — Working Memory가 실제로 쌓이기 시작한 뒤,
  세션 시작 시 항목이 여러 개 보이면 그때 호출한다.
