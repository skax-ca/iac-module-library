# 선택 가이드: 새 프로젝트에서 무엇을 고르는가

**읽는 사람**: 새 고객사 프로젝트를 맡아 구성을 결정해야 하는 사람.

고를 것은 네 가지다. 순서대로 답하면 나머지가 따라온다.

```
질문 A. GitOps가 필요한가?            -> 프로파일 A / B
질문 B. (A라면) 어느 ArgoCD인가?      -> 관리형 / self-managed
질문 C. addon을 어디에 두는가?        -> 계층 1 / 계층 2
질문 D. (self-managed라면) 허브를 어디에 두는가? -> 같은 계정 / 분리된 허브 계정
```

---

## 질문 A. GitOps가 필요한가: 프로파일 A / B

두 프로파일의 차이는 **addon을 어떻게 클러스터에 반영하는가**다(앱 워크로드는 두 프로파일
모두 이 저장소의 범위 밖이다. [overview.md](overview.md)의 3계층 모델 참조).

| | 프로파일 A(GitOps) | 프로파일 B(직접 배포) |
|---|---|---|
| addon 반영 방식 | ArgoCD가 `eks-platform-gitops` 저장소를 **pull**해 반영 | ArgoCD 없이 배포 루트가 직접 설치한다. **이 저장소는 방법을 규정하지 않는다**(helm 직접 설치 등은 모듈 범위 밖) |
| 필요한 저장소 | `eks-platform-gitops`(계층 2) 추가로 필요 | 불필요 |
| 이 문서가 다루는 범위 | 이 디렉토리(`eks-gitops-hub-spoke/`) 전체가 이 프로파일이다 | 별도 가이드 없음. GitOps가 필요 없다고 판정되면 이 디렉토리의 질문 B·C·D는 적용하지 않는다 |

역량 선언이 아니라 **판정 가능한 사실**로 고른다.

| # | 질문 | GitOps가 값을 주는 조건 |
|---|------|------------------------|
| 1 | 클러스터가 **2개 이상**인가 | 1개면 fleet 조망 가치가 성립하지 않는다 |
| 2 | 앱 배포 주체가 **앱팀**인가 | 인프라팀 하나면 Git 경유의 위임·감사 가치가 줄어든다 |
| 3 | 엔드포인트를 **private으로 유지**해야 하는가 | pull 모델이 필요한 진짜 이유다 |

**판정**: 1이 "예"거나 3이 "예"면 **프로파일 A**. 둘 다 아니면 **프로파일 B**.
2는 경계 사례의 보조 신호다.

---

## 질문 B. 어느 ArgoCD인가: 관리형 / self-managed

**기본은 관리형**(EKS Capability for Argo CD)이다. 아래 **탈출 조건 하나라도** 걸리면 self-managed다.

| # | 탈출 조건 | 확인 방법 |
|---|----------|----------|
| 1 | **IAM Identity Center 미보유·도입 불가** | 관리형은 IdC가 **유일 인증 경로**다. 우회로가 없다 |
| 2 | 미지원 기능 중 **필수인 것**이 있다 | 아래 목록과 대조한다 |
| 3 | **Application 수 기준 과금**이 수용 불가 | 예상 Application 수 x 단가를 **계산해서** 판정한다 |

**탈출 조건은 취향이 아니라 사실 세 개다.** 셋 다 아니면 관리형이다.
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
| 1 | **부트스트랩** | `awscc_eks_capability`: **IaC 산출물** | `helm install`: workbench에서 실행하는 **절차** |
| 2 | **인증·RBAC** | IdC 강제. `rbac_role_mappings` | 자유(local / OIDC). `argocd-rbac-cm` 사용 |
| 3 | **cluster 등록** | Secret `server` = 클러스터 ARN. local도 **명시 등록 필요** | `https://kubernetes.default.svc`. 연결은 자동이나 **Secret은 여전히 만든다** |
| 4 | **namespace** | 단일 강제 + immutable | 자유 |
| 5 | **기능 표면** | 위 미지원 목록 | upstream 전체 |
| 6 | **저장소 접근** | **CodeConnections**: 장기 자격증명 없음 | **GitHub App**: 장기 private key가 생긴다 |

> 1과 3은 같은 뿌리다: **ArgoCD가 클러스터 안에 있는가.**
> self-managed는 내부 워크로드라 자기 apiserver에 ServiceAccount로 닿는다.
> 관리형은 클러스터 밖이라 Access Entry와 명시 등록이 둘 다 필요하다.

### 운영 특성이 갈리는 축 셋

| 축 | 관리형 | self-managed |
|---|---|---|
| **비용** | Application 수에 선형 | 기존 노드를 쓰면 한계비용 거의 0 |
| **업그레이드·HA·패치** | **AWS 소유** | **우리 소유**: 여기가 전담 인력을 요구한다 |
| **private 도달성** | AWS 소유 (peering 불필요) | 우리 설계: workbench 경유 port-forward |

> 두 경로는 **같은 층에 있지 않다.** 관리형은 `.tf`를 낳고 self-managed는 helm 실행 절차를 낳는다.
> 문서 분량이 대칭이 아닌 것이 정상이다. **self-managed ArgoCD는 이 저장소의 모듈이 아니다.**

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

> **Karpenter와 Cluster Autoscaler는 동시에 켤 수 있다**: `eks-cluster` 모듈의
> `enable_karpenter`·`enable_cluster_autoscaler`는 상호 배제하지 않는다(서로 다른 리소스를
> 다룬다: Karpenter=EC2 직접 프로비저닝, CA=`managed_node_groups`의 ASG). 단, 워크로드를
> taint로 분리하지 않으면 같은 pending pod에 두 컨트롤러가 동시에 반응해 중복 프로비저닝이
> 일어날 수 있다(근거: karpenter.sh FAQ · `aws/karpenter-provider-aws#2543`). 검증된 taint
> 분리 패턴(「Karpenter + Cluster Autoscaler 동시 운영」)은 `eks-reference-infra`의 운영 문서를 참조한다.

### 설정 CR이 계층 2인가 3인가: 판별 두 가지

위 표의 "설정 CR"은 계층 2로 단순 표기했지만, 실제로는 계층 2(플랫폼)와 계층 3(앱, 이
저장소 범위 밖)으로 갈릴 수 있다. *"cluster-scoped면 플랫폼, namespace-scoped면 앱"* 은
**성립하지 않는다**. 반례가 실재한다. 스코프가 아니라 아래 두 질문이 정한다.

**판별 1: 인프라 정체성을 담는가?**
IAM role · 비용 · 용량 · 발급 신뢰를 인코딩하면 **계층 2**다. 스코프와 무관하다.

**판별 2: 누군가를 제약하는 규칙인가?**
가드레일은 **제약받는 쪽이 소유하면 무의미**하다. 앱팀을 제약하는 정책은 **계층 2**다.

| CR | 스코프 | 계층 | 판별 |
|---|---|---|---|
| Karpenter NodePool · EC2NodeClass | cluster | 2 | 1: `spec.role`이 IAM을 인코딩 |
| Kyverno ClusterPolicy | cluster | 2 | 2: 앱팀을 제약하는 가드레일 |
| cert-manager Issuer | **namespace** | **2** | 1: 발급 신뢰는 인프라다 |
| KEDA ScaledObject | namespace | 3 | 특정 워크로드에 결합 |
| KEDA ClusterTriggerAuthentication | **cluster** | **2** | 앱 인증에 결합하나 공유 제공물 |

굵게 표시한 두 행이 *"스코프로 판정하면 틀린다"* 의 증거다.

### 네임스페이스 배치

**계층 2 addon은 전용 네임스페이스를 신설한다.** 예외는 셋이다.

| addon | 네임스페이스 | 이유 |
|-------|-------------|------|
| **Karpenter** | `kube-system` | APF FlowSchema(`kube-apiserver`의 API Priority and Fairness 요청 분류 규칙)가 이 네임스페이스를 전제한다 |
| **AWS Load Balancer Controller** | `kube-system` | 공식 문서 + Pod Identity association |
| **Cluster Autoscaler** | `kube-system` | ⚠️ **관례일 뿐, 아래 바를 충족하지 못한다**. 알면서 택했다(공식 요구사항도 official 문서 근거도 없음) |
| 그 밖에 전부 | 전용 ns | 격리 |

> 예외를 늘리려면 **위 두 근거(Karpenter·ALBC)에 준하는 것**을 대야 한다.
> *"차트 기본값이 `kube-system`이라서"* 는 근거가 아니다. **Cluster Autoscaler는 정확히 이 바를
> 통과하지 못한 채로 예외에 들어갔다.** 근거가 약하다는 것을 알고도 관례를 택한 결정이라는 뜻이고,
> 그래서 여기 정직하게 적어둔다. 더 강한 근거 없이 이 전례를 들어 새 예외를 또 늘리지 않는다.

### 리소스 이름: Application 이름과 Helm release 이름을 분리한다

ApplicationSet의 cluster generator(등록된 클러스터마다 Application을 자동 복제하는 제너레이터)는 Application 이름을 `{{name}}-<addon>`(예:
`eks-demo-hub-an2-main-01-aws-lbc`)으로 짓는다. 하나의 ArgoCD 인스턴스가 여러 클러스터를
관리하므로, 콘솔에서 어느 클러스터의 addon인지 구분하려면 이 접두사가 필요하다.

**release 이름을 따로 지정하지 않으면 이 접두사가 Kubernetes 리소스 이름까지 그대로
전파된다.** ArgoCD는 `spec.source.helm.releaseName`을 지정하지 않으면 release 이름을
Application 이름과 동일하게 쓰고([ArgoCD 공식 문서](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)),
대부분의 차트는 `{{ .Release.Name }}-{{ .Chart.Name }}` 형태로 리소스 이름을 만든다. 접두사가
두 번 겹친다.

⚠️ **가독성만의 문제가 아니다.** Kubernetes 객체 이름은 DNS-1123 규격상 63자 제한이 있다.
접두사가 길어질수록 서로 다른 리소스가 63자 지점에서 같은 이름으로 잘려 충돌할 위험이
커진다(실제로 발생한 사례는 [decisions.md](../../decisions.md) 「GitOps와 ArgoCD」 참조).

**결정**: release 이름이 리소스 이름에 그대로 쓰이는 addon은 `spec.source.helm.releaseName`을
짧게 명시한다. Application 이름은 그대로 둔다. 콘솔 식별(클러스터 구분)과 리소스 이름은
서로 다른 축이다. [Kubernetes 공식 문서](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)도
둘을 분리해서 다룬다: 클러스터·인스턴스 식별은 `app.kubernetes.io/instance` 라벨의 몫이고,
이름의 몫이 아니다.

| addon | Application 이름 | `helm.releaseName` |
|-------|------------------|---------------------|
| aws-lbc | `{{name}}-aws-lbc` | `aws-lbc` |
| karpenter | `{{name}}-karpenter` | `karpenter` |
| cluster-autoscaler | `{{name}}-cluster-autoscaler` | `cluster-autoscaler` |
| kyverno 계열(`kyverno`·`kyverno-policies`·`kyverno-custom-policies`) | 그대로 | **지정하지 않는다**. 이 차트들은 release 이름과 무관하게 컨트롤러 이름을 고정으로 렌더링해 애초에 접두사가 겹치지 않는다 |

release 이름은 addon마다 **클러스터 안에서만** 유일하면 된다. `destination.server`가
클러스터마다 다르므로, hub와 spoke가 같은 release 이름(`aws-lbc`)을 써도 서로 다른
클러스터에 있어 충돌하지 않는다. ArgoCD의 소유권 추적 라벨(`app.kubernetes.io/instance`)은
release 이름이 아니라 Application 이름을 기준으로 붙으므로(ArgoCD 공식 문서), release
이름을 바꿔도 클러스터·addon 단위 추적은 그대로 유지된다.

---

## 질문 D. 허브를 어디에 두는가: 같은 계정 / 분리된 허브 계정

**self-managed에서만 해당한다.** 관리형 Capability는 이미 클러스터 밖에서 도니 이 질문 자체가 없다
(질문 B 「두 경로가 갈리는 축 여섯 개」의 1·3번 갈림점 참조).

**기본은 "허브 = 첫 워크로드와 같은 계정"이다.** 아래 트리거 하나라도 걸리면 허브를 분리한다.

| # | 트리거 조건 | 확인 방법 |
|---|----------|----------|
| 1 | 워크로드가 **2개 이상의 AWS 계정**에 걸친다 | 계정 경계가 이미 있다면, 허브를 그중 하나에 얹는 순간 그 계정이 특권을 갖는다 |
| 2 | **계정 경계로 워크로드를 격리**해야 하는 조직·규제 요건이 있다 | 고객사 컴플라이언스팀에 확인 |
| 3 | 허브 장애가 **다른 워크로드에 번지면 안 된다** | 같은 계정이면 계정 단위 사고(서비스 한도·정책 변경)가 워크로드와 허브를 함께 덮친다 |

**셋 다 아니면 같은 계정이다.** *"나중에 커질 수도 있으니 미리 분리한다"* 는 트리거가 아니다.
필요해지면 그때 분리한다(아래 되돌릴 수 있는 선택 표 참조).

### 갈림점 일곱 개

| # | 갈림점 | 같은 계정 | 분리된 허브 계정 |
|---|--------|----------|-----------------|
| 1 | 배포 루트 | `<project>-infra`의 워크로드 환경이 허브를 겸한다 | `<project>-infra`에 `hub` 환경을 하나 추가한다. **저장소를 새로 만들지 않는다** |
| 2 | cluster 등록(`eks-platform-gitops`) | `server: https://kubernetes.default.svc` | 스포크의 실제 EKS API 엔드포인트 + 크로스 계정 인증 config |
| 3 | IAM 신뢰 | 불필요(같은 계정·같은 클러스터) | 스포크 계정이 신뢰 Role을 만들고 허브의 Pod Identity만 신뢰한다. **Role은 스포크가 소유**: 제약받는 쪽이 그 제약을 소유한다는 원칙(질문 C 「설정 CR이 계층 2인가 3인가」 판별 2)과 같다 |
| 4 | EKS Access Entry | 불필요 | 스포크 계정마다 필요: 허브의 IAM 주체를 그 클러스터 접근 권한에 매핑(access policy 또는 RBAC, [module-catalog.md](../../module-catalog.md)의 `cross-account-trust-role` 모듈 섹션 참조) |
| 5 | 장애 반경 | 허브 장애 = 그 계정 전체가 영향권 | 허브 장애 = pull만 멈춘다. desired state는 Git에 그대로 있고 워크로드 계정은 무관하다 |
| 6 | 네트워크 경로 | 불필요(같은 VPC) | 필요. 아래 「네트워크 경로」 절 |
| 7 | state·CI 분리 | 불필요(단일 state·단일 워크플로) | 필수. 계정마다 별도 state·별도 CI job. 하나로 합치지 않는 이유는 아래 「state를 계정 경계에서 나누는 이유」 절 |

> `eks-platform-gitops`의 cluster Secret 계약(값이 어떻게 채워지는지)은 그 저장소 소관이다.
> 이 표는 그 계약이 기대는 **IAM 경계**만 정의한다.

이 IAM 경계를 실제 모듈 변수·출력으로 구현하는 계약은 [`module-catalog.md`](../../module-catalog.md)의
`eks-cluster` 크로스 계정 확장·`cross-account-trust-role` 모듈 섹션이 소유한다.

### state를 계정 경계에서 나누는 이유: 멀티 provider 단일 설정을 쓰지 않는다

허브·스포크를 provider 2개로 한 Terraform 설정에 묶어 한 apply로 처리하지 않는다.
**계정마다 독립된 state·독립된 CI job을 쓴다.** 이유(락 경합·전송 비용·자격증명 동시
보유) → [decisions.md](../../decisions.md) 「크로스 계정 네트워킹」.

### 네트워크 경로: IAM 경계와 별개다

위 IAM 경계(신뢰 Role · Access Entry)는 "누가 인증되는가"만 답한다. **패킷이 실제로
도달하는가**는 다른 질문이고, 워크벤치 설계 문서가 정한 기본값(`endpoint_public_access =
false`, private-only)을 스포크에도 그대로 쓰면 **답은 기본적으로 "아니오"다**. 허브와
스포크는 서로 다른 계정의 서로 다른 VPC라 연결이 저절로 생기지 않는다. 실전에서 이 공백을
IAM 경계만 만들고 놓치기 쉽다(원인이 아니라 증상만 보인다, apply는 성공하는데 허브
ArgoCD가 `dial tcp … i/o timeout`으로 spoke를 못 읽는다).

**기본은 Transit Gateway다.** 스포크가 1개뿐이어도 VPC Peering은 **선택지가 아니다**
(아래 「VPC Peering이 안 되는 이유」).

### VPC Peering이 안 되는 이유: CIDR 3계층 규약과 구조적으로 충돌한다

AWS 공식 문서(`vpc/latest/peering/invalid-peering-configurations.html` 「Overlapping CIDR
blocks」)가 명시한다: **"CIDR 블록이 여러 개면, 실제로 라우팅할 대역이 겹치지 않아도
그중 하나라도 겹치면 peering 자체를 생성할 수 없다."**

`vpc` 모듈의 CIDR 3계층 규약은 **pod-dup 대역(`100.64.0.0/16`, RFC 6598)을 모든 VPC가
그대로 재사용**하도록 설계돼 있다. 비라우팅 대역이라 스포크마다 조율할 필요가 없게
하려는 의도다(그래서 "dup"다). 이 설계 의도 자체가 Peering과 양립하지 않는다: 실제
라우팅 대상은 uniq 대역(예: hub `10.53.0.0/16`·spoke `10.51.0.0/16`, 서로 겹치지 않는다)
뿐인데도, 양쪽 VPC가 공유하는 dup 대역 때문에 AWS가 peering 생성 자체를 거부한다.
스포크의 pod CIDR을 재배치해 피하는 것도 해법이 아니다(이유 → [decisions.md](../../decisions.md)
「크로스 계정 네트워킹」).

### Transit Gateway 설계

| # | 요소 | 값 |
|---|------|-----|
| 1 | 소유 계정 | **허브**: 허브가 유일한 공통 상대이므로 TGW도 허브가 영구 소유한다 |
| 2 | 공유 방식 | RAM(`aws_ram_resource_share`)으로 **스포크 계정 ID 단위** 공유. 조직 전체 공유가 아니라 정확한 계정만. IAM 신뢰(148행)와 같은 "정확한 대상만" 원칙 |
| 3 | 라우팅 | **자동 전파(propagation)를 쓰지 않는다.** 자동 전파는 VPC의 전 CIDR(uniq+dup)을 그대로 전파해 peering과 똑같은 dup 대역 충돌이 TGW 라우트테이블 안에서 재현된다. 대신 uniq 대역만 정적 라우트(`aws_ec2_transit_gateway_route`)로 명시한다 |
| 4 | attachment 수락 | `auto_accept_shared_attachments = "enable"`: RAM 공유가 이미 계정을 좁혔으므로 수락을 자동화해도 신뢰 경계가 넓어지지 않는다 |
| 5 | `allow_external_principals` | **`true`.** 조직 내부 공유(초대 없는 공유)는 조직 관리 계정 권한이 필요해 배포 계정(멤버 계정)에서는 쓸 수 없다. `true`로 두면 표준 계정 간 공유(초대)로 동작한다(이유 → [decisions.md](../../decisions.md) 「크로스 계정 네트워킹」). 스포크가 초대를 수락하는 단계가 하나 늘어난다(아래 「RAM 초대 수락」 절 참조, 리소스 표 4번) |
| 6 | 라우트테이블 소유 | **`default_route_table_association`/`_propagation` 모두 `disable`, `aws_ec2_transit_gateway_route_table`을 명시적으로 만들어 연결한다**(이유 → [conventions.md](../../conventions.md)의 「강제 방식」 6번). spoke의 attachment는 RAM으로 받은 쪽이라 `transit_gateway_default_route_table_association` 인자를 못 쓰므로(AWS 공식 문서: RAM 공유 TGW에는 이 인자가 안 먹는다) hub가 `aws_ec2_transit_gateway_route_table_association` + `replace_existing_association = true`로 끌어와야 한다 |
| 7 | 값 전달 | **repo 변수 수동 복사가 아니라 `data` 소스로 발견한다**: 아래 「값 발견」 절 |

TGW는 스포크가 늘어도 구조를 안 바꾼다(attachment만 추가). 그리고 Peering은 애초에 못
쓰므로 "스포크 1개일 때는 peering, 늘면 TGW로 전환"이라는 단계적 채택 자체가 성립하지
않는다. 스포크가 하나뿐이어도 TGW가 유일한 선택지다.

필요한 리소스는 소유가 두 갈래로 갈린다: TGW 자체와 그 라우트테이블은 **허브 소유**(TGW
owner만 자기 라우트테이블에 라우트를 넣을 수 있다는 AWS 제약), VPC 쪽 라우트테이블은
**각자 소유**(자기 VPC 라우트테이블은 자기가 고친다):

| # | 리소스 | 만드는 곳 |
|---|--------|----------|
| 1 | `aws_ec2_transit_gateway` | 허브 |
| 2 | `aws_ram_resource_share` + `aws_ram_resource_association`(TGW·허브 uniq 프리픽스 리스트 둘 다) + `aws_ram_principal_association`(스포크 계정 ID) | 허브 |
| 2b | `aws_ec2_managed_prefix_list`(허브 uniq CIDR 1개, 2번의 RAM 공유에 함께 실어 보낸다, 아래 「값 발견」 참조) | 허브 |
| 3 | `aws_ec2_transit_gateway_vpc_attachment`(허브 자신의 attachment) | 허브 |
| 4 | CI 단계(스포크 워크플로 plan job, `tofu init` 이전)가 pending 초대를 CLI로 수락 → `data.aws_ram_resource_share`(이름으로 조회, 5번보다 먼저 필요). **Terraform 리소스가 아니다**, 아래 「RAM 초대 수락」 절 참조 | 스포크 |
| 5 | `aws_ec2_transit_gateway_vpc_attachment`(스포크의 attachment, 초대 수락 후 생성 가능) | 스포크 |
| 6 | 허브의 트래픽 발생원이 있는 **모든** VPC 라우트테이블 그룹(node-uniq·vm-uniq 등, 하나라도 빠지면 그 그룹의 소스는 스포크에 못 닿는다)에 스포크 uniq CIDR(하드코딩, 아래 「값 발견」 참조) → 허브 소유 TGW(아래 「`for_each` key」 절 참조) | 허브 |
| 7 | 스포크 라우트테이블(node-uniq)에 허브 uniq CIDR(하드코딩) → 스포크 자신의 attachment | 스포크 |
| 8 | `data.aws_ec2_transit_gateway_vpc_attachments`(복수형, 허브 소유 TGW에 붙은 attachment 전부 발견) → 발견된 것마다 TGW 라우트테이블에 라우트(대상 CIDR은 `vpc_owner_id`로 아래 CIDR 지도에서 조회) | 허브(TGW owner만 가능) |
| 9 | 스포크 클러스터 SG에 허브발 443 인바운드(CIDR은 하드코딩) | 스포크 |

### `for_each` key는 attachment ID가 아니라 안정값으로: 6번의 함정

6번(VPC 쪽 라우트)의 `for_each` key에 8번처럼 attachment ID를 섞어 쓰면 안 된다.
6번의 실제 인자는 attachment ID와 무관하므로 key를 **`spoke_account_id`**(설정값,
불변)로 바꾸면 스포크를 몇 번 갈아엎어도 유지된다. **8번은 다르다**:
`transit_gateway_attachment_id` 자체가 attachment ID에 의존하므로 key도 attachment
ID가 맞다. 리소스의 실제 인자가 그 값에 의존하는지로 key를 고른다(이유 →
[decisions.md](../../decisions.md) 「크로스 계정 네트워킹」).

### RAM 초대 수락: Terraform 리소스가 아니라 CI 단계다

`aws_ram_resource_share_accepter`를 스포크 root의 평범한 Terraform 리소스로 두지
않는다(이유 → [decisions.md](../../decisions.md) 「크로스 계정 네트워킹」). 대신:

- 스포크 워크플로의 **plan job**(`tofu init` 이전)에 CLI 단계를 추가한다: 실행 Role을
  체인 assume → 대상 공유 이름의 PENDING 초대가 있으면
  `accept-resource-share-invitation` → 없으면 no-op(멱등). apply job에는 필요 없다.
  이 저장소는 "저장된 plan을 그대로 적용"하는 설계라(「승인한 계획 = 적용된 계획」
  원칙) apply 시점에는 data source를 다시 읽지 않는다.
- 스포크 root의 `aws_ram_resource_share_accepter`는 **`removed` 블록**(destroy = false)
  으로 전환한다. Terraform이 더는 이 리소스를 생성도 삭제도 하지 않으므로, teardown이
  hub 쪽 RAM 연결을 조용히 깨뜨리는 경로 자체가 사라진다. 기존에 이 리소스가 이미
  state에 있는 root만 이 블록이 필요하다. 신규 스포크는 애초에 이 리소스가 생긴 적이
  없으므로 CI 단계만으로 충분하다.

이 설계로 teardown·재배포·완전 신규 배포 셋 다 사람 개입(CLI 수동 수락) 없이 CI가
끝까지 처리한다. 자동화의 주체가 Terraform 리소스 그래프가 아니라 **CI 파이프라인의
한 단계**다.

### 값 발견: repo 변수 수동 복사 대신 `data` 소스, 단 CIDR 은 예외

TGW ID·attachment ID는 AWS 무작위 부여라 결정적 합성이 불가능하지만, **그 값을 담고 있는
리소스의 이름은 결정적**이다(`ram-<workload>-hub-<region>-tgw-share`처럼 이 저장소의
네이밍 규약 그대로 조합된다). 그래서 값 자체가 아니라 **이름으로 찾아 값을 읽는다**.
"하류가 다른 배포 루트라면 remote state 참조보다 Name 태그 data source 조회를 쓴다"는
계정 내부 원칙을 계정 경계 너머로 확장한 것이다.

⛔ **태그로는 값을 실어 나를 수 없다.** AWS 태그는 종류를 가리지 않고 계정 경계를
넘지 않는다(이유 → [decisions.md](../../decisions.md) 「크로스 계정 네트워킹」). RAM이
명시적으로 "공유"하는 대상(리소스 ARN 자체, `resource_arns`)과 EC2 API가 고유 속성으로
노출하는 값(`vpc_owner_id` 등)만 계정 경계를 넘는다.

| 필요한 값 | 발견 방법 |
|-----------|----------|
| 허브의 TGW ID | 스포크가 `data.aws_ram_resource_share`(이름, `resource_owner = "OTHER-ACCOUNTS"`)의 `resource_arns`에서 TGW ARN을 파싱: RAM 의 본래 목적이라 계정 경계를 넘는다 |
| 스포크의 attachment ID·개수 | 허브가 `data.aws_ec2_transit_gateway_vpc_attachments`(복수형)로 자기 TGW에 붙은 것 전부 나열: **스포크가 0개여도 에러가 아니라 빈 리스트**라 허브 apply는 스포크 존재 여부와 무관하게 항상 성공한다 |
| 어느 attachment 가 어느 스포크인가 | `data.aws_ec2_transit_gateway_vpc_attachment`(단수)의 `vpc_owner_id`: 태그가 아니라 EC2 API 고유 속성이라 계정 경계를 넘는다 |
| 허브→스포크 방향 CIDR(허브 자신의 uniq) | **관리형 접두사 목록(`aws_ec2_managed_prefix_list`)으로 발견한다.** 허브가 자기 uniq CIDR을 담은 프리픽스 리스트를 만들어 위 2번 RAM 공유에 함께 실어 보낸다. 스포크는 `data.aws_ram_resource_share`의 `resource_arns`에서 `:prefix-list/`를 포함한 ARN을 파싱해 **ID만** 얻고, `aws_route`의 `destination_prefix_list_id`·SG 규칙의 `prefix_list_ids`로 직접 참조한다. 근거: AWS RAM은 프리픽스 리스트 소유자만 공유할 수 있고, 공유받은 계정은 그 리스트를 자기 자원(라우트·SG)에서 직접 참조할 수 있다(AWS 공식: [Share customer-managed prefix lists](https://docs.aws.amazon.com/vpc/latest/userguide/sharing-managed-prefix-lists.html)) |
| 스포크→허브 방향 CIDR(스포크 자신의 uniq) | **여전히 하드코딩한다.** 스포크가 여럿이어도 허브는 `spoke_account_id`(위 2번, RAM 초대 대상)를 사람에게 안내받아야 하므로, 같은 자리에서 CIDR도 함께 받는다(새 수동 단계가 아니라 기존 단계의 확장). 프리픽스 리스트가 자연스러운 쪽은 **1:N 발행자가 자기 값을 공표하는 방향**뿐이다. N:1로 여러 스포크의 값을 허브가 모으는 이 방향은 발행자가 여럿이라 같은 구조가 성립하지 않는다 |

⚠️ **예외: 스포크 계정 ID(와 그 CIDR)는 여전히 사람이 알려줘야 한다.** RAM
`principal_association`은 공유 대상 계정을 알아야 초대를 보낼 수 있는데, 허브는 스포크가
존재하는지조차 모르는 상태에서 시작하므로 "발견"할 대상이 없다.

⚠️ **순서 제약은 여전히 하나 남는다**: 허브가 스포크보다 먼저 존재해야 한다(스포크가
이름으로 찾을 대상이 있어야 하므로). 단수형 `data.aws_ram_resource_share`는 대상이 없으면
**에러로 실패**하므로 이 순서를 거꾸로 하면 스포크 쪽에서 명확한 실패로 즉시 드러난다.

---

## 되돌릴 수 있는 선택 / 없는 선택

프로젝트 착수 전에 **반드시** 확인할 것.

| 선택 | 되돌릴 수 있나 | 바꾸려면 |
|------|:---:|---------|
| VPC CIDR | ❌ | VPC 재생성 = 전면 재구축 |
| 클러스터 이름 | ❌ | 클러스터 재생성 |
| EKS `authentication_mode` | ❌ | 되돌리는 방향의 전환이 막혀 있다 |
| 관리형 ArgoCD의 namespace | ❌ | `createOnly`: immutable |
| 리전 | ❌ | 전면 재구축 |
| 관리형 <-> self-managed 전환 | ⏳ | 가능하나 재설치 + 재등록. 무중단이 아니다 |
| 프로파일 A <-> B | ⏳ | A→B는 쉽고 B→A는 GitOps 저장소 신설이 필요 |
| 허브 같은 계정 <-> 분리 | ⏳ | 가능하나 스포크마다 크로스 계정 신뢰 Role·Access Entry를 새로 만들어야 한다. 무중단이 아니다 |
| addon 추가·제거 | ✅ | GitOps 저장소 커밋 |
| 노드 타입·크기 | ✅ | Karpenter NodePool 또는 노드그룹 변경 |

`❌` 행은 **착수 전에 고객사와 확정한다.** 나중에 바꾸면 재생성이고, 재생성은 재구축이다.
