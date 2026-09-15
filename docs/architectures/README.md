# 아키텍처

**읽는 사람**: 새 고객사 프로젝트의 아키텍처 패턴을 골라야 하는 사람.

이 저장소가 지원하는 아키텍처 패턴. 어떤 패턴이 필요한지 고른 뒤, 그 패턴의 하위 디렉터리로 들어간다.

| 패턴 | 무엇 | 클라우드별 | 배포·운영 레퍼런스 |
|------|------|------------|------------------|
| [gitops-hub-spoke/](gitops-hub-spoke/README.md) | 허브 하나에 ArgoCD를 두고 스포크를 등록해 플랫폼 addon을 팬아웃한다. 계층 2 운영은 [gitops.md](gitops-hub-spoke/gitops.md) | ✅ [aws/](gitops-hub-spoke/aws/README.md) · ✅ [azure/](gitops-hub-spoke/azure/README.md) | `eks-reference-infra`(AWS) · `aks-reference-infra`(Azure) |

패턴별 살아있는 배포(계정·클러스터명이 등장하는 세우기·걷어내기 절차)는 그 패턴의 레퍼런스
배포 저장소가 소유한다. 이 저장소는 모듈 계약과 패턴을 고르는 결정 가이드까지만
소유한다(`CLAUDE.md` 「이 repo의 위치」).
