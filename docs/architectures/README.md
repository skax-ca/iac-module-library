# 아키텍처

**읽는 사람**: 새 고객사 프로젝트의 아키텍처 패턴을 골라야 하는 사람.

이 저장소가 지원하는 아키텍처 패턴. 어떤 패턴이 필요한지 고른 뒤, 그 패턴의 하위 디렉터리로 들어간다.

| 패턴 | 무엇 | 결정 가이드 | 배포·운영 레퍼런스 |
|------|------|------------|------------------|
| [eks-gitops-hub-spoke/](eks-gitops-hub-spoke/overview.md) | EKS + self-managed ArgoCD, hub 계정이 spoke 계정들을 크로스 계정으로 관리 | [choose-your-path.md](eks-gitops-hub-spoke/choose-your-path.md) · [addon-rollout.md](eks-gitops-hub-spoke/addon-rollout.md) | `eks-reference-infra`(EKS GitOps 패턴 레퍼런스) |

패턴별 살아있는 배포(계정·클러스터명이 등장하는 세우기·걷어내기 절차)는 이 저장소가 아니라
그 패턴의 레퍼런스 배포 저장소가 소유한다. 이 저장소는 모듈 계약과 패턴을 고르는 결정
가이드까지만 소유한다(`CLAUDE.md` 「이 repo의 위치」).
