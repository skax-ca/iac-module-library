---
description: 코드 리뷰를 실행한다 — repo 계약·네이밍·보안을 지적하는 read-only 리뷰
agent: code-reviewer
subtask: true
---

다음 범위를 코드 리뷰해라: $ARGUMENTS

이 repo 규칙(`docs/module-catalog.md`·`docs/conventions.md`, 네이밍 SSOT `docs/naming/abbreviations/aws.md`)을 기준으로:
- repo 계약·패턴 준수, 네이밍 SSOT 일치, kill switch 누락, 커뮤니티 모듈 정확 핀 준수
- 보안(시크릿·와일드카드 IAM·공개 SG·암호화)
- tflint `terraform_unused_declarations`·`tofu fmt`·`trivy config` 게이트를 통과하는 커밋 단위인지
- 심각도(Major/Minor/Nit)와 파일:줄 단위로 지적하고, 수정은 하지 않는다