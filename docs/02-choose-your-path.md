# 02. 선택 가이드 — 새 프로젝트에서 무엇을 고르는가

**읽는 사람**: 새 고객사 프로젝트를 맡아 구성을 결정해야 하는 사람.

고를 것은 세 가지다. 순서대로 답하면 나머지가 따라온다.

```
질문 A. GitOps가 필요한가?            -> 프로파일 A / B
질문 B. (A라면) 어느 ArgoCD인가?      -> 관리형 / self-managed
질문 C. addon을 어디에 두는가?        -> 계층 1 / 계층 2
```

---

## 질문 A. GitOps가 필요한가 — 프로파일 A / B

역량 선언이 아니라 **판정 가능한 사실**로 정한다.

| # | 질문 | GitOps가 값을 주는 조건 |
|---|------|------------------------|
| 1 | 클러스터가 **2개 이상**인가 | 1개면 fleet 조망 가치가 성립하지 않는다 |
| 2 | 앱 배포 주체가 **앱팀**인가 | 인프라팀 하나면 Git 경유의 위임·감사 가치가 줄어든다 |
| 3 | 엔드포인트를 **private으로 유지**해야 하는가 | pull 모델이 필요한 진짜 이유다 |

**판정**: 1이 "예"거나 3이 "예"면 **프로파일 A(GitOps)**. 둘 다 아니면 **프로파일 B(직접 배포)**.
2는 경계 사례의 보조 신호다.

> **프로파일 B에는 ArgoCD가 없다.** 질문 B·C의 절반이 사라지고, addon은 전부 계층 1이 된다.

---

## 질문 B. 어느 ArgoCD인가 — 관리형 / self-managed

**기본은 관리형**(EKS Capability for Argo CD)이다. 아래 **탈출 조건 하나라도** 걸리면 self-managed다.

| # | 탈출 조건 | 확인 방법 |
|---|----------|----------|
| 1 | **IAM Identity Center 미보유·도입 불가** | 관리형은 IdC가 **유일 인증 경로**다. 우회로가 없다 |
| 2 | 미지원 기능 중 **필수인 것**이 있다 | 아래 목록과 대조한다 |
| 3 | **Application 수 기준 과금**이 수용 불가 | 예상 Application 수 x 단가를 **계산해서** 판정한다 |

**탈출 조건은 취향이 아니라 사실 세 개다.** 셋 다 아니면 관리형이다 —
*"직접 운영하는 게 편하다"* 는 조건이 아니다.

### 관리형 미지원 기능 (탈출 조건 2의 판정 근거)

Config Management Plugins · custom Lua health check · **Notifications controller** ·
**custom SSO**(IdC 전용) · UI extensions · `argocd-cm`/`argocd-params` 직접 접근 ·
sync timeout 120초 고정 · Application/ApplicationSet/AppProject는 **단일 네임스페이스 강제** ·
IdC identity 1,000개 한도.

CLI 제약도 함께 본다: `argocd login` 미지원(토큰만) · `argocd admin` 미지원 ·
`--grpc-web` 필수 · 앱 지정에 네임스페이스 접두 필요.

### 두 경로가 갈리는 축 여섯 개

| # | 갈림점 | 관리형 Capability | self-managed helm |
|---|--------|------------------|-------------------|
| 1 | **부트스트랩** | `awscc_eks_capability` — **IaC 산출물** | `helm install` — workbench에서 실행하는 **절차** |
| 2 | **인증·RBAC** | IdC 강제. `rbac_role_mappings` | 자유 — local / OIDC. `argocd-rbac-cm` 사용 |
| 3 | **cluster 등록** | Secret `server` = 클러스터 ARN. local도 **명시 등록 필요** | `https://kubernetes.default.svc`. 연결은 자동이나 **Secret은 여전히 만든다** |
| 4 | **namespace** | 단일 강제 + immutable | 자유 |
| 5 | **기능 표면** | 위 미지원 목록 | upstream 전체 |
| 6 | **저장소 접근** | **CodeConnections** — 장기 자격증명 없음 | **GitHub App** — 장기 private key가 생긴다 |

> 1과 3은 같은 뿌리다: **ArgoCD가 클러스터 안에 있는가.**
> self-managed는 내부 워크로드라 자기 apiserver에 ServiceAccount로 닿는다.
> 관리형은 클러스터 밖이라 Access Entry와 명시 등록이 둘 다 필요하다.

### 운영 특성이 갈리는 축 셋

| 축 | 관리형 | self-managed |
|---|---|---|
| **비용** | Application 수에 선형 | 기존 노드를 쓰면 한계비용 거의 0 |
| **업그레이드·HA·패치** | **AWS 소유** | **우리 소유** — 여기가 전담 인력을 요구한다 |
| **private 도달성** | AWS 소유 (peering 불필요) | 우리 설계 — workbench 경유 port-forward |

> 두 경로는 **같은 층에 있지 않다.** 관리형은 `.tf`를 낳고 self-managed는 helm 실행 절차를 낳는다.
> 문서 분량이 대칭이 아닌 것이 정상이다 — **self-managed ArgoCD는 이 저장소의 모듈이 아니다.**

### 단가 확인

가격은 문서에 적지 않는다. 리전·시점에 따라 달라지므로 **결정 시점에 조회한다**.

```bash
aws pricing get-products --region us-east-1 \
  --service-code AmazonEKS --filters 'Type=TERM_MATCH,Field=regionCode,Value=ap-northeast-2'
```

---

## 질문 C. addon을 어디에 두는가

| 분류 | 어디 | 예 |
|------|------|-----|
| **EKS managed addon** | 계층 1 (OpenTofu) | vpc-cni · coredns · kube-proxy · pod-identity-agent |
| **helm addon** | 계층 2 (GitOps) | ALBC · Karpenter · Cluster Autoscaler · Kyverno · KEDA |
| **설정 CR** | 계층 2 (GitOps) | NodePool · ClusterPolicy |

> **Karpenter와 Cluster Autoscaler는 동시에 켤 수 있다** — `eks-cluster` 모듈의
> `enable_karpenter`·`enable_cluster_autoscaler`는 상호 배제하지 않는다(서로 다른 리소스를
> 다룬다: Karpenter=EC2 직접 프로비저닝, CA=`managed_node_groups`의 ASG). 단, 워크로드를
> taint로 분리하지 않으면 같은 pending pod에 두 컨트롤러가 동시에 반응해 중복 프로비저닝이
> 일어날 수 있다(근거: karpenter.sh FAQ · `aws/karpenter-provider-aws#2543`). 검증된 taint
> 분리 패턴(「Karpenter + Cluster Autoscaler 동시 운영」)은 [`07-runbooks.md`](07-runbooks.md)를 참조한다.

### 네임스페이스 배치

**계층 2 addon은 전용 네임스페이스를 신설한다.** 예외는 셋이다.

| addon | 네임스페이스 | 이유 |
|-------|-------------|------|
| **Karpenter** | `kube-system` | APF FlowSchema가 이 네임스페이스를 전제한다 |
| **AWS Load Balancer Controller** | `kube-system` | 공식 문서 + Pod Identity association |
| **Cluster Autoscaler** | `kube-system` | ⚠️ **관례일 뿐, 아래 바를 충족하지 못한다** — 알면서 택했다(공식 요구사항도 official 문서 근거도 없음) |
| 그 밖에 전부 | 전용 ns | 격리 |

> 예외를 늘리려면 **위 두 근거(Karpenter·ALBC)에 준하는 것**을 대야 한다.
> *"차트 기본값이 `kube-system`이라서"* 는 근거가 아니다 — **Cluster Autoscaler는 정확히 이 바를
> 통과하지 못한 채로 예외에 들어갔다.** 근거가 약하다는 것을 알고도 관례를 택한 결정이라는 뜻이고,
> 그래서 여기 정직하게 적어둔다. 더 강한 근거 없이 이 전례를 들어 새 예외를 또 늘리지 않는다.

---

## 되돌릴 수 있는 선택 / 없는 선택

프로젝트 착수 전에 **반드시** 확인할 것.

| 선택 | 되돌릴 수 있나 | 바꾸려면 |
|------|:---:|---------|
| VPC CIDR | ❌ | VPC 재생성 = 전면 재구축 |
| 클러스터 이름 | ❌ | 클러스터 재생성 |
| EKS `authentication_mode` | ❌ | 되돌리는 방향의 전환이 막혀 있다 |
| 관리형 ArgoCD의 namespace | ❌ | `createOnly` — immutable |
| 리전 | ❌ | 전면 재구축 |
| 관리형 <-> self-managed 전환 | ⏳ | 가능하나 재설치 + 재등록. 무중단이 아니다 |
| 프로파일 A <-> B | ⏳ | A→B는 쉽고 B→A는 GitOps 저장소 신설이 필요 |
| addon 추가·제거 | ✅ | GitOps 저장소 커밋 |
| 노드 타입·크기 | ✅ | Karpenter NodePool 또는 노드그룹 변경 |

`❌` 행은 **착수 전에 고객사와 확정한다.** 나중에 바꾸면 재생성이고, 재생성은 재구축이다.

---

## 다음

- 골랐다 → [`03-new-project.md`](03-new-project.md)
- 걷어내야 한다 → [`04-teardown.md`](04-teardown.md)
- 왜 이 선택지만 있나 → [`08-decisions.md`](08-decisions.md)
