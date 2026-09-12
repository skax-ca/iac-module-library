# Session — iac-module-library

## 지난 세션 (2026-09-12)
세션 메모리 구조를 전면 개편했다. `.omc/notepad.md`(3단 구조: Priority·Working·MANUAL)와
`project-memory.json`(JSON), 그리고 이를 위임받던 `notepad-sync` 스킬을 이 파일
(`.claude/session.md`) 하나로 대체했다. `session-start`/`session-end`가 직접 읽고
쓰며, 더 이상 위임하는 스킬이 없다. 과거 서술은 파일에 쌓지 않고 git log가 대신한다.
부수적으로 `dotfiles-claude` 루트에 남아있던 OMC 런타임 잔재(`.omc/state`)와
`.gitignore`의 관련 항목도 정리했고, `bootstrap.sh`의 고아 심볼릭 링크 정리 로직 버그
(dangling 심볼릭 링크가 `*/ ` glob에 안 걸리던 문제)도 고쳤다.
근거: `dotfiles-claude` 커밋 932e0fa.

이 저장소 자체의 `.tf`/문서 변경은 없었다(도구 레이어 작업).

## 다음 할 일
- [ ] 다음 세션부터 이 파일이 실제로 잘 작동하는지(덮어쓰기 유지되는지) 확인
- [ ] 발표자료(`.local/notion/v0.2/`) 13~25장 리뷰
- [ ] addon staged 전파 구현 (발표 전 필수)
- [ ] 3부 경로 참조 Notion 반영
