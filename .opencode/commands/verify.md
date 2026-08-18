---
description: 증거 기반 완료 검증을 실행한다 — 실제 명령을 수행하고 결과 증거로 통과/실패를 판정
agent: verifier
subtask: true
---

다음 변경을 검증해라: $ARGUMENTS

실제 명령을 실행해 판정하라(변경 파일의 실제 출력 증거 필수):
1. `tofu fmt -recursive -check`
2. `tflint --recursive`
3. `trivy config .`
4. `modules/*.tf` 변경이 있으면 `tofu -chdir=modules/<name> test`

추측 판정 금지. 실패는 그대로 보고하고 "수정 완료로 간주"하지 않는다. 위반 주석(TODO 잔존·test.skip)이 있으면 완료로 인정하지 않는다.