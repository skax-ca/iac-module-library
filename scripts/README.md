# scripts: 이 저장소의 거버넌스 도구

**읽는 사람**: 이 저장소의 문서·네이밍 규약을 검증하는 사람.

이 저장소 자신의 문서/네이밍 거버넌스 도구만 소유한다. ArgoCD 부트스트랩 등
소비 프로젝트가 실행하는 운영 절차(`argocd-seed.sh` · `teardown-verify.sh`)는
`eks-reference-infra`(EKS GitOps 패턴 레퍼런스 레포)로 이관됐다. 이 저장소는
배포하지 않으므로 배포 절차를 소유하지 않는다(`CLAUDE.md` 「이 repo의 위치」).

| 스크립트 | 무엇 | 실행 주체 |
|---|---|---|
| `validate-abbreviations.py` | 약어 카탈로그(`aws-naming-abbreviations.md`) SSOT 일관성 검사 | `.githooks/pre-commit`(카탈로그 staged 시)와 CI가 실행 |
| `validate-doc-conventions.py` | 문서 작성 규칙·문체 규칙(`writing-style.md`) 중 기계로 판정 가능한 항목 검사 | `.githooks/pre-commit`(문서 staged 시)와 CI가 실행 |
