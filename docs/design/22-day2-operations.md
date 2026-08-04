# 22 · Day 2 운영 — 업그레이드 런북 + 운영 프로파일 (D-DAY2-PROFILE)

> **상태**: ✅ 신규 (2026-08-04). [`docs/README.md`](../README.md) 상태표가 인용 가능 여부의 판정 근거다.
>
> **이 문서가 소유하는 것**: ① 클러스터·노드·addon **버전 업그레이드 절차**(고객사 유형 무관 공통)
> ② 고객사 역량에 따른 **Day 2 운영 프로파일 선택 기준**과 각 프로파일의 책임 경계
> ③ 모듈 출력 → 컨트롤러 설치 입력 **매핑표**
>
> **이 문서가 소유하지 않는 것**: 모듈 계약(→ [`20`](20-eks-module.md)) · 소비 repo 배포 경로
> (→ [`50`](50-reference-consumer-repo.md)) · GitOps 부트스트랩 seam(→ [`21`](21-gitops-bootstrap-seam.md) **미결정**) ·
> bastion/도달성(→ [`40`](40-bastion.md) **미개정**).
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

### 3.2 두 프로파일이 공유하는 것과 갈리는 것

| | **프로파일 A — GitOps** | **프로파일 B — 직접 배포** |
|---|---|---|
| 축 A 업그레이드(§2) | **동일** | **동일** |
| 모듈 계약·`.tf` | **동일**(무변경) | **동일**(무변경) |
| baseline·community **addon** | **IaC** (양쪽 같다 — D-ADDON-BOUNDARY) | **IaC** |
| 컨트롤러 IAM | **IaC** (`enable_karpenter`·`enable_alb_controller_iam`) | **IaC** |
| ALBC · Karpenter **helm** | ArgoCD Application | helm CLI |
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

### 3.4 ⏸ 여기서 확정하지 않는 것 — 도달성

**프로파일 B의 진짜 비용은 helm이 아니라 "누가 클러스터 API에 닿는가"다.**

GitOps(pull)를 택하는 이유 자체가 *"엔드포인트 private 유지"* 였다([`01 §3.1`](../architecture/01-module-strategy.md)).
프로파일 B에서 helm/kubectl을 돌리려면 **push 주체가 API에 도달**해야 하고, private endpoint면
GitHub Actions의 공용 runner는 닿지 못한다. 후보는 self-hosted runner · bastion · public
endpoint + CIDR 제한이며, 각각 비용과 노출이 다르다.

⛔ **이 결정을 이 문서가 내리지 않는다.** [`21`](21-gitops-bootstrap-seam.md)은 **미결정**,
[`40`](40-bastion.md)은 **미개정**이다. 미결정 위에 확정을 쌓으면 CLAUDE.md의
*"미개정 문서를 확정 설계로 인용 금지"* 를 이 문서가 스스로 어긴다.

🔑 **대신 지금 확정할 수 있는 것을 전부 확정했다** — §2 런북(양쪽 공통) · §3.1 판별 기준 ·
§3.3 매핑표(양쪽 공통). 도달성이 어떻게 결정되든 **이 셋은 바뀌지 않는다.**

> ⚠️ `eks-platform-gitops` 저장소는 **PoC 스택 기준**으로 만들어졌고 설계 SSOT를 동결된
> `terraform-enterprise-poc`로 가리킨다. 프로파일 A의 실물로 참조하되 **확정 규약으로 인용하지 않는다**
> — 승계 여부는 §3.4의 재결정에 포함된다.

---

## 4. 열린 항목

1. **도달성 결정**(§3.4) — 프로파일 B의 helm 실행 위치. `21`·`40` 재결정과 함께.
2. **프로파일 B의 배포 자동화 수준** — helm CLI를 사람이 치는가, CI가 치는가. 후자면
   *"승인한 계획 ≠ 적용된 계획"* 구멍을 어떻게 막는지가 [`50`](50-reference-consumer-repo.md)의
   plan artifact 규약과 대칭이 되어야 한다.
3. **프로파일 전환 경로** — B로 시작한 고객사가 클러스터가 늘어 A로 가는 경우. 지금은
   *"컨트롤러 설치 주체만 바뀌고 IAM·addon은 그대로"* 로 보이지만(§3.2 표) 실측한 적 없다.
4. **런북의 검증 방법**(§2) — 이 repo는 배포하지 않으므로 apply 판정을 못 한다. 실제 마이너
   업그레이드는 소비 repo `iac-reference-infra`가 처음 수행하며, 그때 §2.4 표를 갱신한다.
   ⚠️ **1.35 → 1.36 업그레이드가 아직 한 번도 실행되지 않았다** — §2는 AWS 공식 문서와 모듈
   계약에서 **연역한 절차**이지 실측이 아니다. 첫 수행 후 이 절에 실측 기록을 남긴다.
