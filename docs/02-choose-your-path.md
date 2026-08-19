# 02. 선택 가이드 — 새 프로젝트에서 무엇을 고르는가

**읽는 사람**: 새 고객사 프로젝트를 맡아 구성을 결정해야 하는 사람.

고를 것은 네 가지다. 순서대로 답하면 나머지가 따라온다.

```
질문 A. GitOps가 필요한가?            -> 프로파일 A / B
질문 B. (A라면) 어느 ArgoCD인가?      -> 관리형 / self-managed
질문 C. addon을 어디에 두는가?        -> 계층 1 / 계층 2
질문 D. (self-managed라면) 허브를 어디에 두는가? -> 같은 계정 / 분리된 허브 계정
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

## 질문 D. 허브를 어디에 두는가 — 같은 계정 / 분리된 허브 계정

**self-managed에서만 해당한다.** 관리형 Capability는 이미 클러스터 밖에서 도니 이 질문 자체가 없다
(질문 B 66~68행 참조).

**기본은 "허브 = 첫 워크로드와 같은 계정"이다.** 아래 트리거 하나라도 걸리면 허브를 분리한다.

| # | 트리거 조건 | 확인 방법 |
|---|----------|----------|
| 1 | 워크로드가 **2개 이상의 AWS 계정**에 걸친다 | 계정 경계가 이미 있다면, 허브를 그중 하나에 얹는 순간 그 계정이 특권을 갖는다 |
| 2 | **계정 경계로 워크로드를 격리**해야 하는 조직·규제 요건이 있다 | 고객사 컴플라이언스팀에 확인 |
| 3 | 허브 장애가 **다른 워크로드에 번지면 안 된다** | 같은 계정이면 계정 단위 사고(서비스 한도·정책 변경)가 워크로드와 허브를 함께 덮친다 |

**셋 다 아니면 같은 계정이다.** *"나중에 커질 수도 있으니 미리 분리한다"* 는 트리거가 아니다 —
필요해지면 그때 분리한다(아래 되돌릴 수 있는 선택 표 참조).

### 갈림점 여섯 개

| # | 갈림점 | 같은 계정 | 분리된 허브 계정 |
|---|--------|----------|-----------------|
| 1 | 배포 루트 | `<project>-infra`의 워크로드 환경이 허브를 겸한다 | `<project>-infra`에 `hub` 환경을 하나 추가한다. **저장소를 새로 만들지 않는다** |
| 2 | cluster 등록(`iac-platform-gitops`) | `server: https://kubernetes.default.svc` | 스포크의 실제 EKS API 엔드포인트 + 크로스 계정 인증 config |
| 3 | IAM 신뢰 | 불필요 — 같은 계정·같은 클러스터 | 스포크 계정이 신뢰 Role을 만들고 허브의 Pod Identity만 신뢰한다. **Role은 스포크가 소유** — 제약받는 쪽이 그 제약을 소유한다는 원칙(`01-architecture.md` 4절 판별 2)과 같다 |
| 4 | EKS Access Entry | 불필요 | 스포크 계정마다 필요 — 허브의 IAM 주체를 그 클러스터 RBAC로 매핑 |
| 5 | 장애 반경 | 허브 장애 = 그 계정 전체가 영향권 | 허브 장애 = pull만 멈춘다. desired state는 Git에 그대로 있고 워크로드 계정은 무관하다 |
| 6 | 네트워크 경로 | 불필요 — 같은 VPC | 필요 — 아래 「네트워크 경로」 절 |

> `iac-platform-gitops`의 cluster Secret 계약(값이 어떻게 채워지는지)은 그 저장소 소관이다.
> 이 표는 그 계약이 기대는 **IAM 경계**만 정의한다.

이 IAM 경계를 실제 모듈 변수·출력으로 구현하는 계약은 [`05-modules.md`](05-modules.md)의
`eks-cluster` 크로스 계정 확장·`cross-account-trust-role` 모듈 섹션이 소유한다.

### 네트워크 경로 — IAM 경계와 별개다

위 IAM 경계(신뢰 Role · Access Entry)는 "누가 인증되는가"만 답한다. **패킷이 실제로
도달하는가**는 다른 질문이고, 워크벤치 설계 문서가 정한 기본값(`endpoint_public_access =
false`, private-only)을 스포크에도 그대로 쓰면 **답은 기본적으로 "아니오"다** — 허브와
스포크는 서로 다른 계정의 서로 다른 VPC라 연결이 저절로 생기지 않는다. 실전에서 이 공백을
IAM 경계만 만들고 놓치기 쉽다(원인이 아니라 증상만 보인다 — apply는 성공하는데 허브
ArgoCD가 `dial tcp … i/o timeout`으로 spoke를 못 읽는다).

**기본은 VPC Peering이다.** 아래 트리거가 걸리면 Transit Gateway로 대체한다.

| # | 트리거 조건 | 이유 |
|---|----------|------|
| 1 | 스포크가 **2개 이상**이거나 그럴 계획이 확정됐다 | peering은 관계마다 별도 연결이라 스포크가 늘수록(N개) 필요한 연결 수가 늘어난다 — 허브가 유일한 공통 상대라 완전 그래프까지는 아니지만, 스포크마다 관리 대상이 하나씩 늘어난다 |
| 2 | 스포크끼리도 서로 통신해야 한다 | peering은 점대점이라 전이(transitive)가 안 된다 — 스포크 A↔B가 필요하면 peering을 스포크 개수만큼 따로 맺어야 한다 |

**둘 다 아니면 peering이다.** *"나중에 스포크가 늘 수도 있으니"* 는 트리거가 아니다 —
질문 D의 허브 분리 판단과 같은 원칙(139~140행)이다. 필요해지면 그때 Transit Gateway로
옮긴다 — 무중단은 아니다(아래 「되돌릴 수 있는 선택」 표 참조).

**전제조건 — CIDR 비중첩.** VPC Peering은 두 VPC의 CIDR이 겹치면 AWS API가 거부한다
(peering 생성 시점에 걸린다 — plan으로는 안 잡히고 apply에서야 드러난다). 허브·스포크의
CIDR을 신규로 배치할 때 이미 겹치지 않게 고르는 것이 이 요건의 이행이다(`vpc` 모듈의
CIDR 3계층 절 참조) — peering을 도입하고 나서 되돌리려면 VPC 재생성이 필요하다(❌, 되돌릴
수 없는 선택).

**소유 — 이 계약은 "제약받는 쪽이 소유"(148행 IAM 신뢰와 같은 원칙) 축이 아니다.**
Peering Connection은 AWS 리소스 모델 자체가 요청자(requester)·수락자(accepter) 양쪽을
요구해 한쪽이 전담할 수 없다 — IAM 신뢰처럼 스포크 하나가 "제약받는 쪽"으로 정해지지
않는다. 그래서 재사용 모듈을 두지 않는다: 정확히 2개 VPC 사이의 1:1 관계라 스포크가 늘 때마다
"어느 배포 루트가 무엇을 소유하는가"만 반복되고 추상화할 공통 로직이 없다(워크벤치·
eks-cluster급 재사용 모듈과 다르다) — **배포 루트가 vanilla 리소스로 직접 연결한다.**

필요한 리소스는 세 종류다. 어느 배포 루트가 만드는지까지 명시한다(양쪽 다 관여하는
리소스가 있으므로 "허브가 다 한다"로 오인하지 않는다):

| # | 리소스 | 만드는 곳 |
|---|--------|----------|
| 1 | `aws_vpc_peering_connection`(요청) + `aws_vpc_peering_connection_accepter`(수락) | 요청은 한쪽 루트, 수락은 반대쪽 계정의 provider로 — **두 배포 루트가 함께 관여한다** |
| 2 | 상대 CIDR로 가는 라우트 | **양쪽 다** — 허브의 ArgoCD가 도는 서브넷 라우트테이블 + 스포크의 EKS 서브넷(control plane ENI가 있는) 라우트테이블 |
| 3 | 스포크 클러스터 SG에 허브발 443 인바운드 | **스포크만** — IAM 신뢰와 같은 이유("제약받는 쪽이 규칙을 연다"), 워크벤치 kubectl 인바운드와 같은 패턴(`eks-cluster`의 `cluster_security_group_additional_rules`) |

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
| 허브 같은 계정 <-> 분리 | ⏳ | 가능하나 스포크마다 크로스 계정 신뢰 Role·Access Entry를 새로 만들어야 한다. 무중단이 아니다 |
| VPC Peering -> Transit Gateway | ⏳ | 가능하나 라우트테이블을 TGW attachment 경로로 다시 걸어야 한다. 무중단이 아니다 |
| addon 추가·제거 | ✅ | GitOps 저장소 커밋 |
| 노드 타입·크기 | ✅ | Karpenter NodePool 또는 노드그룹 변경 |

`❌` 행은 **착수 전에 고객사와 확정한다.** 나중에 바꾸면 재생성이고, 재생성은 재구축이다.

---

## 다음

- 골랐다 → [`03-new-project.md`](03-new-project.md)
- 걷어내야 한다 → [`04-teardown.md`](04-teardown.md)
- 왜 이 선택지만 있나 → [`08-decisions.md`](08-decisions.md)
