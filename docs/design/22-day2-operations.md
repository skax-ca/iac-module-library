# 22 · Day 2 운영 — 업그레이드 런북 + 운영 프로파일 (D-DAY2-PROFILE)

> **상태**: ✅ 신규 (2026-08-04) · **개정 (2026-08-06)** — **§4 백업·복구 신설**(D-BACKUP-AWS 수용),
> §3.2에 Kyverno 행 추가(D-POLICY-ENGINE). ⚠️ **구 §4 열린 항목은 §5로 이동**했다
> ([`40`](40-workbench.md)의 `§4-1`·`§4-2` 참조도 함께 갱신). 두 결정의 **근거 전문은
> [`20 §1.1`](20-eks-module.md)** 에 있다 — 이 문서는 운영 절차만 소유한다.
> [`docs/README.md`](../README.md) 상태표가 인용 가능 여부의 판정 근거다.
>
> **이 문서가 소유하는 것**: ① 클러스터·노드·addon **버전 업그레이드 절차**(고객사 유형 무관 공통)
> ② 고객사 역량에 따른 **Day 2 운영 프로파일 선택 기준**과 각 프로파일의 책임 경계
> ③ 모듈 출력 → 컨트롤러 설치 입력 **매핑표** ④ **백업·복구 운영 절차**(§4)
>
> **이 문서가 소유하지 않는 것**: 모듈 계약(→ [`20`](20-eks-module.md)) · 소비 repo 배포 경로
> (→ [`50`](50-reference-consumer-repo.md)) · GitOps 부트스트랩 seam(→ [`21`](21-gitops-bootstrap-seam.md) **미결정**) ·
> workbench/도달성(→ [`40`](40-workbench.md) — **2026-08-05 개정 완료, §3.4가 그 결론을 반영**).
>
> ⛔ **이 문서는 `eks-cluster` 모듈의 계약을 바꾸지 않는다.** `.tf` 변경이 없다 —
> [`20 §1`](20-eks-module.md)이 *"seam이 무엇으로 재결정되든 모듈이 지는 의무는 출력 계약뿐"*
> 이라고 못 박은 것을 그대로 따른다.

---

## 0. 왜 이 문서가 필요한가

모듈은 2026-08-04에 실계정 apply까지 판정됐다([`20 §4.1`](20-eks-module.md)). 그러나 **인도 이후**를
다루는 문서가 없었다. 재사용 자산의 수명은 apply가 아니라 **고객사가 스스로 운영하는 기간**이 정한다.

빠져 있던 것은 둘이다.

1. **업그레이드 절차** — 모듈 계약에 손잡이 세 개(`kubernetes_version`·`ami_release_version`·
   `addon_version`)가 있다는 건 [`20 §3.1`](20-eks-module.md)을 읽으면 안다. 하지만 **셋을 어떤
   순서로 움직여야 하는지**는 계약 어디에도 없다. 그리고 아래 §2가 보이듯 **한 커밋에 셋을 다
   바꾸면 AWS 권장 순서가 깨진다.**
2. **고객사 역량 편차의 흡수** — 플랫폼 엔지니어링 팀이 없는 고객사에 ArgoCD hub-spoke를 인도하면
   **ArgoCD 자체가 관리 대상**(업그레이드·SSO·RBAC·백업)이 되어 인수인계 직후 방치된다.
   이 repo의 존재 이유가 *"고객사가 구독 라이선스 없이 바로 착수"* 인 이상, 이 편차는 자산이 흡수해야 한다.

---

## 1. ⭐ D-DAY2-PROFILE — 두 축을 분리한다

**최초 제안은 *"GitOps를 쓰는 고객사 / helm·eksctl·bash를 쓰는 고객사"* 로 경로를 둘로 나누는
것이었다.** 검토 결과 그 갈래는 **서로 다른 두 축을 하나로 묶고 있었다.** 나누면 이렇게 된다.

| | **축 A — 버전 업그레이드** | **축 B — Day 2 워크로드·설정 배포** |
|---|---|---|
| 대상 | 클러스터 · 노드 · addon **버전** | ALBC helm, Karpenter NodePool, CR·애노테이션, 앱 |
| 소유 도구 | **IaC(OpenTofu) 단일 경로** | **프로파일에 따라 갈린다** |
| 플랫폼팀 유무 | **무관** | **결정적** |
| 지금 없던 것 | **런북**(§2) | **선택 기준**(§3) |

🔑 **축 A에는 선택지가 필요 없다.** 이미 경로가 하나 있고 그게 옳은 경로다 — 세 값은 전부
[D-ADDON-VERSION-PIN-1](20-eks-module.md)·[D-NODE-AMI-PIN](20-eks-module.md)이 **소비 루트에
놓아 둔 손잡이**이며, 업그레이드는 *"그 값을 올리는 명시적 커밋"* 으로 정의돼 있다.
**ArgoCD는 클러스터 버전을 올려주지 않는다** — 그래서 이 런북은 플랫폼팀이 있는 고객사에도 똑같이 필요하다.

### 1.1 ⛔ eksctl은 채택하지 않는다

| 도구 | 왜 안 되는가 |
|------|-------------|
| **eksctl** | **자체 CloudFormation 스택**으로 리소스를 관리한다. OpenTofu가 만든 클러스터에 eksctl로 노드그룹을 붙이면 한 클러스터를 **두 IaC가 나눠 갖는다.** 더 중요한 것은 이 repo의 계약 — `Name` 태그 포맷([`02 §1.2`](../architecture/02-naming-tagging-and-pinning.md)) · 카탈로그 약어 · `tftest` assertion — 이 **그 경로에는 하나도 걸리지 않는다**는 점이다. 재사용 자산의 보증이 거기서만 사라진다 |
| **bash `aws eks update-addon`** | 모듈이 `most_recent = false`를 소유하고 소비 루트가 `addon_version`을 핀하므로 **다음 `tofu plan`이 정확히 그 값으로 되돌린다.** 버그가 아니라 D-ADDON-VERSION-PIN-1의 **의도된 동작**이다 |

⚠️ **조회·디버깅 용도의 CLI 사용까지 막는 것이 아니다.** `aws eks describe-*`·`kubectl`은 오히려
§2가 요구한다. 금지 대상은 **상태를 바꾸는 경로를 둘로 만드는 것**이다.

> 🔑 이 판단은 [`04 §3`](../architecture/04-engine-decision.md)이 **두 엔진 동시 지원을 값을 매겨
> 기각한 논리**와 구조가 같다. 그리고 CLAUDE.md 작업 원칙 두 개 — *"임시방편으로 넘기지 않는다"*,
> *"죽은 경로를 남기지 않는다"* — 와 직접 부딪힌다.

---

## 2. 축 A — 업그레이드 런북 (프로파일 무관 공통)

### 2.1 AWS 공식 순서

출처: [Update existing cluster to new Kubernetes version](https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html)
(2026-08-04 확인).

1. **준비 상태 확인** — EKS **Upgrade Insights**로 deprecated API 사용을 스캔한다
2. **컨트롤플레인** 업그레이드
3. **노드(데이터플레인)** 를 컨트롤플레인에 맞춘다
4. 앱 업그레이드
5. **addon 업그레이드** ← ⚠️ **마지막이다**
6. 클라이언트(`kubectl` 등) 업그레이드

**두 개의 하드 제약**:

- ⛔ **마이너는 1단계씩만.** `1.35 → 1.37` 직행이 불가하다. `1.35 → 1.36 → 1.37`로 **두 번** 돈다.
  (EKS는 고가용 컨트롤플레인을 rolling update하므로 한 번에 한 마이너만 지원한다.)
- ⛔ **컨트롤플레인을 올리기 *전에* 노드 kubelet이 이미 컨트롤플레인과 같은 마이너여야 한다.**
  AWS 원문: *"make sure that the Kubernetes minor version of both the managed nodes … are the same
  as your control plane's version."*
  ⚠️ skew 정책상 kubelet은 apiserver보다 **3 마이너**까지 낮아도 되지만(1.28+), AWS는 **같게 맞추는
  것을 best practice로 명시**한다. 이 런북은 AWS 권장을 따른다.

ℹ️ 업그레이드 후 **7일 이내 rollback**이 가능하다(`rollback-cluster.html`). 이것은 안전망이지
계획의 대체물이 아니다.

### 2.2 IaC 계약으로의 번역 — **3개의 apply로 나눈다**

| 단계 | 바꾸는 값 | 무엇이 일어나나 |
|------|----------|---------------|
| **사전** | (없음) | Upgrade Insights 확인 + 현재 노드 kubelet == 컨트롤플레인 확인 |
| **apply 1** | `kubernetes_version` **+1 마이너만** | 컨트롤플레인만 올라간다 |
| **apply 2** | `managed_node_groups[*].ami_release_version` | 노드가 새 k8s로 롤링 교체된다 |
| **apply 3** | `cluster_addons[*].addon_version` **전부** | addon이 새 k8s 기준으로 올라간다 |

> ### ⚠️ 왜 한 커밋에 몰면 안 되는가
>
> 셋을 한 PR에 넣으면 **순서가 OpenTofu의 의존성 그래프에 맡겨진다.** 그리고 이 모듈은
> vpc-cni에 **`before_compute = true`** 를 소유하고 있어([`20 §2.6`](20-eks-module.md)),
> addon과 노드그룹 사이에 **모듈이 심어 둔 순서**가 이미 존재한다. 그 순서는 **최초 생성**에서
> 옳도록 설계된 것이지(초기 노드부터 Pod를 pod 서브넷에 배치), **업그레이드에서 AWS 권장 순서와
> 일치하도록 설계된 것이 아니다.**
>
> 🔑 **plan 리뷰의 관점에서도 나뉘는 편이 낫다.** 컨트롤플레인 업그레이드는 되돌리기 어렵고
> (7일 rollback 창), 노드 교체는 워크로드 중단을 동반한다. 한 plan에 섞이면 **승인자가 무엇을
> 승인하는지 분간할 수 없다** — [`50` D30-1](50-reference-consumer-repo.md)이 dispatch를 승인
> 게이트로 삼은 이유가 *"누르는 행위가 읽었다는 뜻"* 이었는데, 한 번에 셋을 누르면 그 의미가 희석된다.

### 2.3 값을 어디서 얻는가

⛔ **세 값 모두 추정하지 않는다.** 실제 조회 경로가 있다.

**① `kubernetes_version`** — 대상 마이너가 EKS standard support 안인지 확인한다.

```bash
aws eks describe-cluster --name <cluster> --query 'cluster.version'   # 현재
```

**② `ami_release_version`** — ⚠️ **아키텍처별로 값이 다르다.** graviton(arm64) 노드는 arm 경로에서 얻는다.

```bash
# arm64 (AL2023_ARM_64_STANDARD)
aws ssm get-parameter --region <region> \
  --name /aws/service/eks/optimized-ami/<k8s>/amazon-linux-2023/arm64/standard/recommended/release_version
# x86_64 (AL2023_x86_64_STANDARD) — 경로의 arm64 를 x86_64 로 바꾼다
```

**③ `addon_version`** — ⚠️ **`f(kubernetes_version, region)`이다.** 두 인자가 모두 바뀔 수 있으므로
k8s를 올릴 때마다 **전 addon을 재조회**한다.

```bash
aws eks describe-addon-versions --region <region> \
  --kubernetes-version <k8s> --addon-name <name> \
  --query 'addons[].addonVersions[].addonVersion'
```

> 🔑 **이것이 D-ADDON-VERSION-PIN-1이 값의 소유자를 소비 루트로 옮긴 이유다.** 모듈이 상수를 들면
> 이 재조회가 **모듈 릴리스**를 요구하고, 그 릴리스가 다른 고객사에게도 배송된다.
> 2026-08-03 실측으로 두 축 모두 실제 파손이 확인됐다([`20 §4 Task 20.1(d)`](20-eks-module.md)):
> k8s 축(1.35 기준 핀을 1.34에 쓰면 3종이 버전 없음) · 리전 축(`cert-manager`가 리전마다 eksbuild 상이).

### 2.4 업그레이드 중 자주 틀리는 것

| 함정 | 왜 생기나 | 대응 |
|------|----------|------|
| **`kubernetes_version`만 올리고 addon을 방치** | apply가 성공하기 때문에 굳는다 | `kube-proxy`는 정의상 k8s 마이너를 따라간다. apply 3을 **같은 업그레이드 사이클 안에서** 끝낸다 |
| **arm 노드에 x86 AMI 버전을 핀** | SSM 경로를 아키텍처별로 안 나눔 | §2.3 ②. 이 조합은 **plan에서 안 잡힌다**(D-NODE-ARCH) |
| **마이너 2단계 점프** | 계약상 문자열이라 `1.37`을 그냥 넣을 수 있다 | 모듈은 이것을 막지 않는다 — **AWS API가 apply에서 거부**한다 |
| **노드가 뒤처진 채 컨트롤플레인 상향** | 선결 조건을 모름 | §2.1의 두 번째 하드 제약 |

⚠️ **이 표의 항목 중 무엇도 `tofu test`가 잡지 못한다.** 전부 **버전 값의 정합성** 문제이고
mock provider는 AWS 카탈로그를 모른다. 런북이 유일한 방어선이다.

---

## 3. 축 B — Day 2 운영 프로파일

### 3.1 판별 기준

고객사가 어느 프로파일인지는 **역량 선언이 아니라 아래 네 질문**으로 정한다.
*"플랫폼팀이 있느냐"* 하나로 묻지 않는 이유는, 팀의 존재보다 **아래 조건들이 실제 운영 부담을
만들기 때문**이다.

| # | 질문 | GitOps(A)가 값을 주는 조건 |
|---|------|--------------------------|
| 1 | 클러스터를 **상시 운영할 전담 인력**이 있는가 | ArgoCD 자체가 업그레이드·SSO·RBAC·백업 대상이 된다. 없으면 **관리 표면만 늘어난다** |
| 2 | 클러스터가 **2개 이상**인가 | 1개면 hub-spoke의 fleet 조망 가치가 성립하지 않는다([`21 §2.7`](21-gitops-bootstrap-seam.md)의 대안 비교표) |
| 3 | 앱 배포 주체가 **앱팀**인가 | 배포 주체가 인프라팀 하나면 Git 경유가 주는 위임·감사 가치가 줄어든다 |
| 4 | 엔드포인트를 **private으로 유지**해야 하는가 | pull 모델이 필요한 **진짜 이유**다([`01 §3.1`](../architecture/01-module-strategy.md)) |

**판정**: 1·2가 모두 "예"면 **프로파일 A**. 1이 "아니오"면 **프로파일 B**를 기본으로 본다.
3·4는 경계 사례의 보조 신호다.

⚠️ **4가 "예"인데 1이 "아니오"인 경우가 가장 어렵다** — private 유지는 pull을 부르지만 운영 인력이
없다. 이 조합은 §3.4의 도달성 결정이 선행해야 하므로 **지금 답을 갖고 있지 않다.**

> ### ⏸ **2026-08-07 — 그 조합에 답이 생겼을 수 있다. 단 판별표는 아직 고치지 않았다**
>
> **D-GITOPS-SEAM**([`21 §1`](21-gitops-bootstrap-seam.md))이 프로파일 A의 기본을 **관리형 EKS
> Capability**로 확정했다. 관리형은 위 두 축을 동시에 건드린다:
> - **질문 1** — 이 표가 매긴 비용(*"ArgoCD 자체가 업그레이드·SSO·RBAC·백업 대상이 된다"*)을
>   **AWS가 가져간다**(클러스터 안에 설치물이 없다).
> - **질문 4** — AWS가 hub↔private spoke 연결을 소유하므로 **VPC peering 없이 충족**된다.
>
> ⛔ **그럼에도 이번 개정에서 질문 1을 완화하지 않았다**(2026-08-07 사용자 결정).
> 판별 기준을 바꾸는 것은 *"어느 고객사가 프로파일 A인가"* 를 바꾸는 일이라 이 문서 전체와
> [`30`](30-gitops-repo.md)(⚠️ 미개정)에 파급되고, **21을 닫는 데 필요한 일이 아니었다.**
> 📌 **재개 조건**: 실제로 *"1=아니오 & 4=예"* 인 고객사를 만났을 때.
> 근거 전문은 [`21 §1.6`](21-gitops-bootstrap-seam.md)의 상자가 소유한다.

### 3.2 두 프로파일이 공유하는 것과 갈리는 것

| | **프로파일 A — GitOps** | **프로파일 B — 직접 배포** |
|---|---|---|
| 축 A 업그레이드(§2) | **동일** | **동일** |
| 모듈 계약·`.tf` | **동일**(무변경) | **동일**(무변경) |
| **GitOps seam(ArgoCD) 자체** | **관리형 EKS Capability**(기본) / self-managed helm(탈출 조건 시) — [`21 §1`](21-gitops-bootstrap-seam.md) | ⛔ **없음** |
| baseline·community **addon** | **IaC** (양쪽 같다 — D-ADDON-BOUNDARY) | **IaC** |
| 컨트롤러 IAM | **IaC** (`enable_karpenter`·`enable_alb_controller_iam`) | **IaC** |
| ALBC · Karpenter **helm** | ArgoCD Application | helm CLI |
| **Kyverno helm + ClusterPolicy** | ArgoCD Application (**baseline**) | ⛔ **설치하지 않는다** — D-POLICY-ENGINE |
| **백업·복구** | **IaC**(AWS Backup) — 양쪽 같다 | **IaC**(AWS Backup) — §4 |
| NodePool · CR · 애노테이션 | Git | 직접 apply |
| 도달성(누가 클러스터 API에 닿나) | pull — private 유지 | ⏸ **미결정**(§3.4) |

> ### ⭐ 프로파일 B의 helm 대상은 **두 개뿐이다**
>
> [D-ADDON-BOUNDARY](20-eks-module.md)가 cert-manager·external-dns·관측성 3종까지 **community
> addon으로 IaC에 가져왔기 때문에**, GitOps 없이 직접 다뤄야 하는 helm 대상은
> **AWS Load Balancer Controller**와 **Karpenter 컨트롤러** 둘로 줄어 있다.
> (ALBC는 community addon이 부재하고, Karpenter는 helm chart로만 배포된다.)
>
> 🔑 **이것이 프로파일 B를 현실적으로 만든다.** 경계를 그을 때 의도한 효과는 아니었지만,
> `aws_eks_addon`으로 가능한 것을 전부 IaC로 당긴 결정이 **GitOps 미보유 고객사의 진입 장벽을
> 부수적으로 낮췄다.** 프로파일 B는 "GitOps의 열등한 대체재"가 아니라 **표면이 작은 형상**이다.
>
> ⚠️ **2026-08-06 — Kyverno가 등장했는데도 이 "둘뿐"이 유지된다.** Kyverno는 community addon이
> 아니라 helm이지만([`20 §1.1`](20-eks-module.md) 실측), **프로파일 A 한정**이라 B의 목록에 들어오지
> 않는다. 🔑 **범위를 좁힌 덕에 문장이 살아남은 것이 아니다 — 순서가 반대다.** 이 문장이 성립하는
> 이유(*프로파일 B에는 위임할 앱팀이 없다*)가 곧 **가드레일을 줄 이유가 없다는 근거**였다.
> 같은 사실이 두 곳에 나타난 것이며, 그래서 D-POLICY-ENGINE은 이 절과 충돌하지 않는다.
>
> 📌 **다음에 helm 후보가 또 나오면 물을 질문**: *"프로파일 B에도 필요한가"* 를 **먼저** 묻는다.
> `20 §1.1`이 보였듯 community addon 카탈로그 6종은 이미 소진됐으므로, **앞으로 오는 컴포넌트는
> 기본이 helm**이다. 범위를 묻지 않고 baseline에 넣으면 이 절이 그때 진짜로 깨진다.
>
> ⚠️ **2026-08-07 — ArgoCD가 확정됐는데도 "둘뿐"이 유지된다**([`21 §1`](21-gitops-bootstrap-seam.md) D-GITOPS-SEAM).
> 근거는 Kyverno 때(*"프로파일 A 한정"*)와 **다르다**: ArgoCD는 애초에 프로파일 A 전용이고,
> 게다가 **기본안인 관리형은 클러스터 안에 아무것도 설치하지 않는다** — helm 대상이
> **A에도 0개 는다.** 🔑 **위 질문(*"B에도 필요한가"*)이 두 번 연속 이 절을 지켜냈다.**
> ⛔ 단 **탈출 조건으로 self-managed를 택한 고객사는 A의 helm 대상이 하나 는다**(ArgoCD 자체).
> 그것이 D-GITOPS-SEAM이 관리형을 기본으로 둔 근거 ②다 — B의 목록은 어느 쪽이든 영향이 없다.

### 3.3 모듈 출력 → 컨트롤러 설치 입력 매핑

⭐ **이 절이 이 문서의 실질이다.** 프로파일 A·B **양쪽이 같은 값을 쓴다**(ArgoCD도 같은 값을
파라미터로 받는다). 따라서 §3.4의 미결정에 의존하지 않으며 **지금 확정된다.**

아래 값은 전부 **upstream v21.24.1 소스와 실제 GitOps 매니페스트로 확인**했다(2026-08-04).

#### Karpenter 컨트롤러 (helm `oci://public.ecr.aws/karpenter/karpenter`)

| helm 값 | 무엇을 넣나 | 파생 가능? |
|---------|-----------|-----------|
| `settings.clusterName` | 출력 **`cluster_name`** | ✅ 소비 루트가 이미 아는 값 |
| `settings.interruptionQueue` | 출력 **`karpenter_sqs_queue_name`** | ⚠️ upstream이 `Karpenter-<cluster>`로 만들지만 **출력을 쓴다** — 문자열 파생은 upstream 기본값에 결합하는 것이다 |
| `serviceAccount.name` | `karpenter` (upstream 기본) | ⛔ **바꾸면 IAM이 끊긴다** — 아래 상자 |
| namespace | `kube-system` (upstream 기본) | ⛔ 〃 |
| IRSA 애노테이션 | **불필요** | 모듈이 **Pod Identity association을 이미 만든다**(`create_pod_identity_association` 기본 `true`) |

> ⚠️ **SA 이름·네임스페이스는 자유값이 아니다.** upstream karpenter 서브모듈이
> `namespace = "kube-system"` · `service_account = "karpenter"` 기본값으로 **Pod Identity
> association을 이미 생성**해 뒀다(실측: `main.tf:112-121`). helm 쪽에서 다른 이름을 쓰면
> **association이 가리키는 SA와 실제 SA가 어긋나** 컨트롤러가 자격증명을 못 받는다 —
> IAM에는 role이 있는데 동작하지 않는 **조용한 파손**이다.

#### Karpenter EC2NodeClass / NodePool (manifest)

| 필드 | 무엇을 넣나 | 파생 가능? |
|------|-----------|-----------|
| `spec.role` | 출력 **`karpenter_node_iam_role_name`** (ARN 아니라 **이름**) | ❌ **파생 불가.** `node_iam_role_use_name_prefix` 기본이 `true`라 이름에 **hash 접미사**가 붙는다 |
| `subnetSelectorTerms` / `securityGroupSelectorTerms` | 출력 **`karpenter_discovery_tag`** | ✅ `{"karpenter.sh/discovery" = <cluster_name>}` |

> ⚠️ **discovery 태그는 양쪽에 다 붙어야 한다.** SG 쪽은 이 모듈이 붙이지만
> **subnet 쪽은 VPC 모듈 소관**(`subnet_groups[*].extra_tags`)이다. 한쪽만 붙으면 selector가 빈
> 결과를 내고 프로비저닝이 조용히 실패한다 — **PoC에서 실제 사고였다**([`20 §5.2`](20-eks-module.md)).

#### AWS Load Balancer Controller (helm `https://aws.github.io/eks-charts`)

| helm 값 | 무엇을 넣나 |
|---------|-----------|
| `clusterName` | 출력 **`cluster_name`** |
| `vpcId` | 소비 루트의 VPC ID (**모듈 입력**이지 출력이 아니다) |
| `region` | 소비 루트 |
| `serviceAccount.name` | **`aws-load-balancer-controller`** — ⛔ 모듈 `iam.tf`가 이 SA로 association을 건다. 바꾸면 끊긴다 |
| `serviceAccount.create` | `true` (모듈은 IAM만 만들고 SA는 만들지 않는다) |
| IRSA 애노테이션 | **불필요** — `enable_alb_controller_iam = true`가 Pod Identity association을 만든다 |

⚠️ ALBC는 `enable_alb_controller_iam = true`가 **선행**이다. 기본값이 `false`이므로 프로파일과
무관하게 소비 루트가 켜야 한다.

#### 그 밖의 출력

| 출력 | 쓰이는 곳 |
|------|----------|
| `cluster_arn` | GitOps 클러스터 등록이 API URL이 아니라 **ARN**을 요구한다([`21 §2.8`](21-gitops-bootstrap-seam.md) 실측) |
| `cluster_endpoint` · `cluster_certificate_authority_data` | kubeconfig 합성 (프로파일 B의 `kubectl`·`helm` 접근) |
| `effective_addon_names` | *"내 `cluster_addons`가 baseline과 어떻게 합쳐졌나"* 확인 |
| `oidc_provider_arn` | IRSA 방식 role의 신뢰 정책 (Pod Identity를 쓰면 불필요) |
| `ebs_csi_iam_role_arn` · `external_dns_iam_role_arn` | 해당 addon이 IaC 소관이므로 **보통 소비자가 쓸 일이 없다** — 진단용 |

### 3.4 ✅ 도달성 — **`40` 개정으로 확정됨** (2026-08-05)

> **결론: workbench(SSM 기반) 하나로 통일한다.** 설계 실물은 [`40-workbench.md`](40-workbench.md)이며
> **상태표가 ✅ 개정 완료**로 바뀌었다([`../README.md`](../README.md)) — 이제 확정 설계로 인용할 수 있다.
>
> - **프로파일 B**: workbench에서 helm/kubectl을 **사람이** 실행한다(`D-WORKBENCH-SCOPE`).
> - **프로파일 A**: workbench에서 seed를 1회 수행한 뒤 pull로 넘어간다 — 단 **seed의 형태는 여전히
>   [`21`](21-gitops-bootstrap-seam.md) 소관**이다(미결정).
> - ⭐ **40은 21과 무관하게 완결됐다.** 개정이 40에서 ArgoCD 종속부를 걷어냈기 때문이다(40 §0).
>   21이 self-managed ArgoCD로 뒤집혀도 helm 실행 지점은 여전히 필요하므로 40은 흔들리지 않는다.
>
> ⚠️ **아래 §3.4 원문은 결정 당시의 기록으로 남긴다** — 후보 3개와 그 대가를 비교한 논증이
> `40 §1.1`의 입력이었다. 지운 것은 없고, **판정만 확정으로 바뀌었다.**

<details>
<summary>결정 전 기록 (2026-08-04) — 후보 비교와 방향 결정</summary>

#### ⏸ 여기서 확정하지 않는 것 — 도달성

**프로파일 B의 진짜 비용은 helm이 아니라 "누가 클러스터 API에 닿는가"다.**

GitOps(pull)를 택하는 이유 자체가 *"엔드포인트 private 유지"* 였다([`01 §3.1`](../architecture/01-module-strategy.md)).
프로파일 B에서 helm/kubectl을 돌리려면 **push 주체가 API에 도달**해야 하고, private endpoint면
GitHub Actions의 공용 runner는 닿지 못한다. 후보는 self-hosted runner · workbench · public
endpoint + CIDR 제한이며, 각각 비용과 노출이 다르다.

⛔ **이 결정을 이 문서가 내리지 않는다.** [`21`](21-gitops-bootstrap-seam.md)은 **미결정**,
[`40`](40-workbench.md)은 **미개정**이다. 미결정 위에 확정을 쌓으면 CLAUDE.md의
*"미개정 문서를 확정 설계로 인용 금지"* 를 이 문서가 스스로 어긴다.

> ### 🧭 방향은 정해졌다 — **workbench** (2026-08-04, 사용자 결정). 실행은 `40` 개정에서.
>
> **도달 지점을 workbench 하나로 통일한다.** 프로파일 B는 workbench에서 helm/kubectl을 실행하고,
> 프로파일 A는 workbench에서 seed를 1회 수행한 뒤 pull로 넘어간다.
>
> 🔑 **이건 프로파일 B를 위한 타협이 아니다 — `40`이 이미 GitOps의 전제였다.**
> 그 문서는 workbench를 **"GitOps seed 수행 지점"**(D-SEED-KUBECTL)으로 확정했고,
> [`20 §2.7`](20-eks-module.md)의 `argocd_endpoint_access`를 `private`으로 넘기려면
> **VPC 내부에 조작 지점이 있어야 한다**고 적었다. 그리고 `40`은 **SSM 기반**이라
> SSH 키·인바운드 SG·public IP가 필요 없다 — workbench의 관리 표면이 설계 단계에서 이미 작다.
>
> **그래서 의존 순서는 `40` → `21`이다**(이 순서는 선택이 아니라 의존이다):
> ```
> 40 (workbench) ──┬─→ 프로파일 B 완성
>                └─→ 21 (seed 수행 지점) ─→ 프로파일 A 완성
> ```
> ⭐ **`40` 하나만 끝나도 독립적으로 값이 난다.** 소비 repo가 지금 *"workbench가 아직 없어
> private-only면 kubectl 도달 지점이 없다 — 그래서 public을 켠다"* 라는 주석과 함께
> **public 엔드포인트를 열어 두고 있다.** workbench가 생기면 그 이유가 사라지고 닫을 수 있다.
>
> ⚠️ **여전히 `40` 개정 전까지 확정 설계가 아니다.** 위는 방향이고, 리소스 구성·역할 범위·
> 네이밍은 개정에서 정한다. 특히 **§4-2(자동화 수준)를 그때 함께 결정한다** — 나중에 붙이면
> 인스턴스 타입·SG·IAM이 전부 바뀐다.

🔑 **대신 지금 확정할 수 있는 것을 전부 확정했다** — §2 런북(양쪽 공통) · §3.1 판별 기준 ·
§3.3 매핑표(양쪽 공통). 도달성이 어떻게 결정되든 **이 셋은 바뀌지 않는다.**

</details>

> ⚠️ `eks-platform-gitops` 저장소는 **PoC 스택 기준**으로 만들어졌고 설계 SSOT를 동결된
> `terraform-enterprise-poc`로 가리킨다. 프로파일 A의 실물로 참조하되 **확정 규약으로 인용하지 않는다**
> — 승계 여부는 [`21`](21-gitops-bootstrap-seam.md)의 재결정에 포함된다.

---

## 4. 백업·복구 (D-BACKUP-AWS 수용)

**결정 근거 전문은 [`20 §1.1`](20-eks-module.md)** 에 있다. 이 절은 그 결정의 **운영 절차**만 소유한다.

### 4.1 축 분류 — 백업은 축 A 쪽이다

§1은 두 축(버전 업그레이드 / Day 2 워크로드 배포)을 나눴는데 **백업은 어느 쪽도 아니다.**
성질을 보면 **축 A와 같다**: 경로가 IaC 하나뿐이고, **프로파일 A·B가 완전히 동일**하다.

🔑 **그것이 이 결정의 핵심 효과다.** Velero를 택했다면 백업이 축 B로 넘어가 *"프로파일에 따라
갈리는 것"* 이 하나 늘었을 것이다. AWS Backup은 **에이전트가 없어서** 클러스터 안에 아무것도
설치하지 않고, 따라서 갈릴 지점 자체가 생기지 않는다.

### 4.2 전제조건 — 이미 충족돼 있다

| 항목 | 요구 | 현행 |
|---|---|---|
| 클러스터 인증 모드 | `API` 또는 `API_AND_CONFIG_MAP` | ✅ **실계정 실증**(2026-08-06) — `eks-ref-dev-an2-main-01`의 `accessConfig.authenticationMode` = `API_AND_CONFIG_MAP`. upstream v21 기본값이고 facade가 덮어쓰지 않는다 |
| 클러스터 접근 | AWS Backup이 **Access Entry를 스스로 만든다** | ✅ 소비 루트가 만들 것이 없다 |
| 에이전트·addon | **불필요**(원문 FAQ) | ✅ helm 대상 증가 없음 |
| IAM | 관리형 `AWSBackupServiceRolePolicyForBackup` | 소비 루트가 서비스 역할에 부착 |
| PV가 S3인 경우 | `AWSBackupServiceRolePolicyForS3Backup` + S3 백업 사전요건 | 소비 루트 |

⚠️ **암호화 키는 Backup Vault가 정한다** — EKS 자식 recovery point는 대상 볼트의 KMS 키로 암호화된다.
PV(EBS·EFS·S3)는 각 스토리지 클래스의 기존 암호화 지원을 따른다. **두 층이 다르다는 것을 인지한다.**

### 4.3 소유 경계

| 리소스 | 소유 | 이유 |
|---|---|---|
| `aws_backup_vault` · `aws_backup_plan` · `aws_backup_selection` | **소비 루트** | 보존 기간·볼트·KMS 키는 고객사 **정책**이지 모듈 계약이 아니다. `addon_version`을 소비 루트에 둔 D-ADDON-VERSION-PIN-1과 같은 판단이다 |
| `eks-cluster` 모듈 | **아무것도 소유하지 않는다** | 전제조건이 이미 충족돼 넘겨줄 값이 없다. 출력 `cluster_arn`이 selection의 대상이 되지만 그것은 **기존 출력 계약**이다 |

### 4.4 백업에 포함되지 않는 것 (원문)

- **컨테이너 이미지**(ECR·Docker) — 별도 보존 정책이 필요하다
- **EKS 인프라 구성요소**(VPC·서브넷 등) — ⭐ **이건 결함이 아니다.** 그 계층은 이 repo의 모듈이
  코드로 소유하므로 **재생성이 곧 복구**다. 백업 도구가 IaC 영역을 중복 소유하면 안 된다
- 자동 생성 리소스(노드·auto-generated pod·event·lease·job)

⚠️ **`Completed with issues` 는 실패가 아니다.** metrics-server addon이 일시적으로 503이면
`metrics.k8s.io` 계열 객체가 건너뛰어지고 이 상태가 된다. **SNS 이벤트 알림을 켜지 않으면 조용히
지나간다** — 소비 루트가 알림을 구성한다.

### 4.5 ⛔ Velero로 전환해야 하는 신호

AWS Backup의 한계에 걸리는 형상이다. 아래 중 하나라도 해당하면 [`20 §1.1`](20-eks-module.md)의
예외 경로(`enable_velero_iam` + helm)를 연다.

- PV가 **CSI migration·in-tree 스토리지 플러그인·ACK 컨트롤러** 경유다
  ⚠️ `volume.kubernetes.io/storage-provisioner` 애노테이션은 **판별자가 아니다**(원문 명시).
  실제 프로비저너는 **storageClass가 정한다** — 애노테이션만 보고 "CSI다"라고 판정하지 않는다
- **FSx** CSI 볼륨을 쓴다 · S3 **prefix 단위** 백업이 필요하다 · **크로스 계정 EFS** 백업이 필요하다
- **클러스터 간 마이그레이션**이나 온프렘/멀티클라우드 복원이 요구된다
- **네임스페이스 단위 세밀 복원**이 상시 운영 요구다

---

## 5. 열린 항목

1. ~~**도달성 결정**~~ ✅ **해소(2026-08-05)** — [`40`](40-workbench.md) 개정 완료. workbench(SSM)으로 확정되고
   모듈 계약·소유 경계까지 정해졌다(§3.4). **남은 것은 `21`뿐이며, 그것은 도달성이 아니라 seed의 형태다.**
   ⚠️ **`21`의 개정은 번역이 아니라 재결정이다.** [`01 §3.3`](../architecture/01-module-strategy.md)이
   *"관리형 Capability는 IdC 필수·cross-region 계정 인스턴스·RETAIN 등 제약이 크고 **대안
   (self-managed ArgoCD 포함)과 함께 다시 결정**한다"* 고 명시했다. TFC→OpenTofu 치환으로 끝나지 않는다.
   - ✅ **provider 리스크는 없다**: `awscc`가 `registry.opentofu.org`에 게시돼 있다(2026-08-04 실측, 188개 버전).
     단 `awscc_eks_capability` **리소스 스키마는 착수 시 재조회**한다(`21`이 v1.93.0 기준이라 적어 뒀다).
   - 재결정의 입력은 `21`의 살아 있는 실측 4종(IdC 계정 인스턴스 다중계정 미지원 · Access Entry
     `kubernetesGroups` 공백 · `AmazonEKSArgoCDClusterPolicy`의 read 범위 · RETAIN 유일값)이다.
   - ⚠️ self-managed ArgoCD를 택해도 **helm을 돌릴 지점이 필요**하다 → 역시 workbench. 어느 쪽이든 `40`이 먼저다.
2. ~~**프로파일 B의 배포 자동화 수준**~~ ✅ **해소(2026-08-05, `D-WORKBENCH-SCOPE`)** — 후보 (b) 채택.
   **helm은 사람이 workbench에서 실행한다.** self-hosted runner 겸용은 기각했다([`40 §2.4`](40-workbench.md)에
   축별 대가 비교표).
   - 🔴 **그 대가를 여기 명시한다**: 프로파일 B의 helm 경로에는 [`50`](50-reference-consumer-repo.md)의
     plan artifact 규약(*"승인한 계획을 그대로 apply한다"*)에 **대응하는 장치가 없다.**
     ⚠️ 이것은 못 본 구멍이 아니라 **의식적으로 낸 값**이다 — 프로파일 B는 애초에 플랫폼 팀이 없는
     고객사를 위한 경로이고(§3.1), 그런 조직에 CI 승인 게이트를 강제하면 운영이 멈춘다.
   - 🔁 **재검토 조건**: 프로파일 B 고객사가 **환경 3개 이상**으로 늘어 helm 실행이 반복 작업이 되면
     그때 자동화의 값이 자격증명 1개의 대가를 넘어선다.
3. **프로파일 전환 경로** — B로 시작한 고객사가 클러스터가 늘어 A로 가는 경우. 지금은
   *"컨트롤러 설치 주체만 바뀌고 IAM·addon은 그대로"* 로 보이지만(§3.2 표) 실측한 적 없다.
4. **런북의 검증 방법**(§2) — 이 repo는 배포하지 않으므로 apply 판정을 못 한다. 실제 마이너
   업그레이드는 소비 repo `iac-reference-infra`가 처음 수행하며, 그때 §2.4 표를 갱신한다.
   ⚠️ **1.35 → 1.36 업그레이드가 아직 한 번도 실행되지 않았다** — §2는 AWS 공식 문서와 모듈
   계약에서 **연역한 절차**이지 실측이 아니다. 첫 수행 후 이 절에 실측 기록을 남긴다.
5. **백업의 복구 판정**(§4) — §4도 4번과 **같은 성격**이다. AWS 공식 문서에서 연역했을 뿐
   백업·복원을 실행한 적이 없다. ⛔ **"백업이 돌았다"는 복구의 증거가 아니다** — 소비 repo
   `iac-reference-infra`가 **복원까지** 수행한 뒤 이 절에 실측을 남긴다.
   ⭐ 판정에는 [`40 §7.3-2`](40-workbench.md)가 쓴 **음성 대조군** 형태가 필요하다 —
   *"복원된 것처럼 보이는 상태"* 와 *"실제로 데이터가 돌아온 상태"* 는 다르다.
6. **백업 대상 선정 기준**(§4.3) — 어떤 클러스터를 어떤 주기·보존으로 담을지는 고객사 정책이라
   소비 루트에 뒀다. 다만 **레퍼런스 값이 하나도 없으면 소비자가 처음부터 설계해야 한다.**
   첫 고객사 형상이 정해지면 `examples/` 또는 [`50`](50-reference-consumer-repo.md)에 예시를 남길지 판단한다.
