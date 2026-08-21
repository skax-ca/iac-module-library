---
description: 세션 종료 절차를 수행한다 — 변경사항 확인, 커밋/푸시, 다음 태스크 핸드오프
---

세션 종료 절차를 수행해라.

1. **변경 확인**: 프로젝트 + `~/dotfiles-claude`의 `git status --short`를 실행해 변경사항을 파악한다.
2. **프로젝트 메모리 갱신**: 프로젝트에 `notepad-sync` 스킬이 있으면 **커밋 전에** 호출해 세션 요약·메모리 갱신을 위임한다.
   - `notepad_write_working`으로 이번 세션 요약을 기록한다.
   - 없으면 이 단계를 건너뛴다.
3. **커밋 & 푸시**: 변경사항이 있는 모든 저장소에 커밋 후 `git push`한다.
   - ⛔ `.omc/notepad.md`와 `.omc/project-memory.json` 변경분도 반드시 `git add` 후 같은 커밋에 포함한다 — 이것이 2번에서 만든 변경분이다.
   - `.env`, credentials 등 민감 파일 커밋 금지.
   - dotfiles 변경 시: `cd ~/dotfiles-claude && bash sync.sh push` 후 커밋 + push.
4. **다음 태스크 표시**: push 완료 후 다음 세션에 할 태스크 목록을 사용자에게 보여준다.

- 2번을 3번보다 먼저 실행해야 위임된 절차가 만든 변경분이 같은 커밋에 실린다.
- 프로젝트별 추가 절차(Notion 동기화 등)는 별도 스킬에서 정의한다.
