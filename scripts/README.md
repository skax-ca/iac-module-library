# scripts: 이 저장소의 거버넌스 도구

**읽는 사람**: 이 저장소의 문서·네이밍 규약을 검증하는 사람.

이 저장소 자신의 문서/네이밍 거버넌스 도구만 소유한다. 이 저장소는 배포하지 않으므로
배포 절차를 소유하지 않는다(`CLAUDE.md` 「이 repo의 위치」). 소비 프로젝트가 실행하는
운영 절차는 각 저장소가 갖는다: ArgoCD 부트스트랩(`argocd-seed.sh`)은
`<project>-platform-gitops`의 `bootstrap/`, 철수 검증(`teardown-verify.sh`)은 배포 루트.

| 스크립트 | 무엇 | 실행 주체 |
|---|---|---|
| `validate-abbreviations.py` | 약어 카탈로그(`docs/naming/abbreviations/*.md`) SSOT 일관성 검사 | `.githooks/pre-commit`(카탈로그 staged 시)와 CI가 실행 |
| `validate-doc-conventions.py` | 문서 구조 규칙(`writing-style.md` 1절) 중 기계로 판정 가능한 항목 검사 | `.githooks/pre-commit`(문서 staged 시)와 CI가 실행 |
| `validate-comment-conventions.py` | `modules/**` 의 `.tf`·`.tftest.hcl`과 훅 2개(`.githooks/pre-commit`·`pre-push`)의 주석·`description` 산문에서 외부 참조 2종(절 번호 인용 기호·결정 식별자)과 이력 서술 1종(날짜) 검사 | `.githooks/pre-commit`(해당 파일 staged 시)와 CI가 실행 |
| `build-deck-pptx.py` | 발표자료 HTML을 pptx로 굽는다 | 사람이 직접 실행 |
