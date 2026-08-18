---
description: 설계 우선 플로우를 실행한다 — 관련 설계가 docs/에 있는지 확인하고 계획을 세운다
agent: planner
subtask: true
---

다음 작업에 대한 설계·계획 단계를 수행해라: $ARGUMENTS

이 repo(iac-module-library)의 "설계 우선" 규칙을 지켜라.
1. 관련 설계가 `docs/`(모듈 계약 `05-modules.md`, 규약 `06-conventions.md`, 기각 사유 `08-decisions.md`)에 있는지 먼저 확인한다.
2. 없으면 설계/계획부터 세우고, 있으면 그 설계가 계획의 근거가 된다.
3. 계획엔 변경 대상 파일·모듈 계약 변화·검증 게이트 명령까지 포함한다.
4. 코드를 작성하지 않는다 — 계획만 반환하고 사용자 승인을 받는다.