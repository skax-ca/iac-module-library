# 아키텍처 패턴: GitOps 허브-스포크

**읽는 사람**: 새 프로젝트에서 이 패턴을 쓸지 정하고, 전체 구조를 알아야 하는 사람.

허브 클러스터 하나에 ArgoCD를 두고 스포크 클러스터를 등록해, 플랫폼 addon을 등록된
클러스터들에 팬아웃한다. AWS(EKS)와 Azure(AKS) 양쪽에서 쓴다.

---

## 1. 이 패턴이 맞는 환경

**판정 가능한 사실**로 고른다.

| # | 질문 | GitOps가 값을 주는 조건 |
|---|------|------------------------|
| 1 | 클러스터가 **2개 이상**인가 | 1개면 `fleet` 조망 가치가 성립하지 않는다 |
| 2 | 앱 배포 주체가 **앱팀**인가 | 인프라팀 하나면 Git 경유의 위임·감사 가치가 줄어든다 |
| 3 | 엔드포인트를 **private으로 유지**해야 하는가 | pull 모델이 필요한 이유다 |

**판정**: 1이 "예"거나 3이 "예"면 이 패턴을 쓴다. 둘 다 아니면 쓰지 않는다(배포 루트가 addon을
직접 설치한다. 이 저장소는 그 방법을 규정하지 않는다). 2는 경계 사례의 보조 신호다.

두 경로의 차이는 **addon을 어떻게 클러스터에 반영하는가**다. 앱 워크로드는 어느 쪽이든 이
저장소의 범위 밖이다(아래 3계층 모델).

---

## 2. 되돌릴 수 없는 선택

프로젝트 착수 전에 확인할 것. 클라우드별 항목은 [aws/README.md](aws/README.md)·
[azure/README.md](azure/README.md)가 각각 갖는다.

| 선택 | 되돌릴 수 있나 | 바꾸려면 |
|------|:---:|---------|
| 클러스터 이름 | ❌ | 클러스터 재생성 |
| 리전 | ❌ | 전면 재구축 |
| 이 패턴을 쓸지(질문 1) | ⏳ | 그만두기는 쉽고, 나중에 도입하려면 GitOps 저장소 신설이 필요하다 |
| addon 추가·제거 | ✅ | GitOps 저장소 커밋 |
| 노드 타입·크기 | ✅ | NodePool 또는 노드 풀 변경 |

`❌` 행은 **착수 전에 고객사와 확정한다.** 나중에 바꾸면 재생성이고, 재생성은 재구축이다.

---

## 3. GitOps란

서버가 클러스터에 직접 접속해 변경을 적용(push)하는 대신, 클러스터 안의 컨트롤러(ArgoCD)가
Git 저장소의 내용을 주기적으로 **읽어와(pull)** 그 상태로 맞추는 운영 방식이다. Git 커밋이 곧
배포 이력이 되고, 클러스터 엔드포인트가 private이어도 컨트롤러가 안에서 밖으로 나가 읽어오기만
하면 되므로 인바운드 접근이 필요 없다.

---

## 4. 3계층 소유 모델

**소유자·변경주기·영향범위가 다른 3계층**으로 가르되, **ArgoCD 허브는 하나로 공유**한다.
"인프라 대 앱" 두 덩어리로 다루지 않는다.

| 계층 | 무엇 | 소유자 | 어디에 | 도구 | 범위 |
|------|------|--------|--------|------|:---:|
| **1. 인프라** | 클러스터 · baseline addon · 네트워크 · 권한 | 플랫폼팀 | `<cloud>-reference-infra` | OpenTofu | ✅ |
| **2. 플랫폼 GitOps** | helm addon · 설정 CR · 클러스터 등록 · AppProject | 플랫폼팀 | `<cloud>-platform-gitops` | ArgoCD | ✅ |
| **3. 앱 GitOps** | 비즈니스 워크로드 | **각 앱팀** | 앱팀별 저장소 N개 | ArgoCD | ❌ |

**가르는 이유**: 플랫폼 addon 업그레이드는 전 클러스터에 영향을 주고, 앱 배포는 한 팀에만 영향을
준다. 다른 저장소 · 다른 리뷰어 · 다른 릴리스 주기여야 **실수 하나가 `fleet` 전체를 흔들지 않는다**.

**계층 3은 이 자산의 범위 밖이다.** 앱팀이 생기면 그때 각 팀 저장소로 떼어낸다.
그 분리를 안전하게 만드는 장치가 계층 2가 소유하는 **AppProject**다.
`sourceRepos`와 `destinations`가 *"각 앱팀은 자기 저장소에서 자기 네임스페이스로만"* 을 강제한다.

### 계층 1과 2의 경계

컨트롤러 자체는 계층 1(OpenTofu)이 만들고, 그 컨트롤러가 읽는 설정 CR은 계층 2(GitOps)가
만든다. 컨트롤러는 **클러스터 생성 시점**에 있어야 하고(닭과 달걀 문제), 설정은 **운영 중 자주
바뀐다.** 변경 주기가 다르면 소유 도구도 달라야 한다.

어떤 addon·CR이 어느 계층으로 가는지 판정하는 방법은 [gitops.md](gitops.md)가 소유한다.

---

## 5. 저장소 구성

```
iac-module-library         모듈(.tf) + 패턴 문서.        어느 계층도 "실행"하지 않는다
        |                  배포하지 않는다
        |  git tag
        v
<cloud>-reference-infra    계층 1을 실행한다.            state는 원격 backend, 실행은 GitHub Actions
        |  클러스터 + ArgoCD seed
        v
<cloud>-platform-gitops    계층 2의 매니페스트.          ArgoCD가 pull로 reconcile
                           .tf가 없다
```

| 클라우드 | 계층 1 | 계층 2 |
|---|---|---|
| AWS | `eks-reference-infra` | `eks-platform-gitops` |
| Azure | `aks-reference-infra` | `aks-platform-gitops` |

**이 저장소는 배포하지 않는다.** 그래서 여기서 "동작한다"의 기준은 `tofu test` + 예제
`validate`까지이고, `apply` 판정은 배포 루트의 몫이다.

`.yaml` 매니페스트를 이 저장소에 두지 않는다. ArgoCD Application · AppProject · cluster Secret은
전부 계층 2 저장소 소관이다.

---

## 6. 실행 기반

배포 루트가 담당한다. 이 저장소는 규약만 소유한다. 자격증명 체인과 state backend는 클라우드마다
달라 각 클라우드 문서가 갖는다.

| 항목 | 규칙 |
|------|------|
| plan → apply | plan을 **artifact로 저장**해 승인 후 **그 파일을 apply**한다. 누락 시 "승인한 계획 ≠ 적용된 계획" 구멍 |
| 승인 게이트 | prd는 항상 수동 승인 |
| 동시 실행 | `concurrency: {group: <root>, cancel-in-progress: false}`. 누락 시 state 충돌 |

> ⚠️ **GitHub immutable sub claim**: 2026-07-15 이후 생성된 repo의 OIDC `sub`는 이름이 아니라
> 숫자 org/repo ID를 쓴다: `repo:<org>@<org_id>/<repo>@<repo_id>:environment:dev`.
> 신뢰 정책 작성 전 실제 토큰의 `sub`를 확인할 것.

---

## 7. 문서 지도

| 문서 | 무엇 | 상태 |
|------|------|:---:|
| [gitops.md](gitops.md) | 계층 2 전부: addon 배치 · 이름 · 전파 정책 · L7 진입 | ✅ |
| [ordering.md](ordering.md) | addon 설치·해제 순서: 부모 Application의 sync-wave | ⏳ 전체 해제 순서 실측 전 |
| [aws/README.md](aws/README.md) | EKS 구성, ArgoCD 형태 선택, addon wave, 실행 기반 | ✅ |
| [aws/network.md](aws/network.md) | 허브 위치와 크로스 계정 네트워크(Transit Gateway) | ✅ |
| [azure/README.md](azure/README.md) | AKS 구성, addon 분류, 클러스터 등록, 실행 기반 | ✅ |
| [azure/network.md](azure/network.md) | 허브-스포크 연결(Virtual WAN)과 Pod 네트워킹 | ✅ |

패턴별 살아있는 배포(계정·클러스터명이 등장하는 세우기·걷어내기 절차)는 그 패턴의 레퍼런스
배포 저장소가 소유한다.
