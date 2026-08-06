# 20 · EKS 모듈 (커뮤니티 wrapper)

> **승계**: `terraform-enterprise-poc` `docs/design/20-eks-module.md` @ `76285f7`(동결 커밋)
> **개정**(2026-08-03, D-OSS-STACK §6-2 — 모듈 이식 시점):
> - **실행 스택 종속부 제거** — Terraform/HCP Terraform → **OpenTofu**, `tfe_outputs` 참조 →
>   data source(`03 §3.1`), TFC 워크스페이스·런북·Sentinel 폐기.
> - **GitOps 부트스트랩 seam 분리** — 구 §2.7(D-ARGOCD)·§2.8(D-SPOKE-SEAM)을
>   [`21-gitops-bootstrap-seam.md`](21-gitops-bootstrap-seam.md)로 이관했다. `01 §3.3`이 **재결정 대상**으로
>   지정한 영역이고 구현체가 배포 루트라 이 repo 소유가 아니다. **이 문서는 EKS 모듈 계약만 다룬다.**
> - **배포 루트 소유권 이전** — 구 Task 20.0·20.6·20.7·20.8(live 루트·TFC 런북)을 제거.
>   프리셋은 **`examples/`**로, 소비 경로 규약은 [`50-reference-consumer-repo.md`](50-reference-consumer-repo.md)로.
> - **PoC 진화 서사 제거** — 실증 날짜·run ID·`workload=poc` 하드코딩. 실측 정리본은
>   [`../reference/poc-findings.md`](../reference/poc-findings.md). 설계 결정은 **판단 내용만 승계하고
>   `D-*` ID를 보존**한다(PoC 문서와의 상호 참조 유지).
> - **재사용 요건 5종 적용**(`01 §4`) — **D-EKS-ENABLED**(kill switch)·**D-EKS-PROTECT**(삭제 보호) 신설,
>   파라미터화, 환경 프로파일, **예제**(~~2종~~ → 1종, 2026-08-03 Task 20.6), 출력 계약 안정성.
> - **Task 20.1(a)(b)(c)(e) 실물 확인 반영**(2026-08-03, 같은 날 2차) — upstream 소스 직독으로
>   **D-EKS-PROTECT를 네이티브 `deletion_protection`으로 확정**(→ 하한 `>= 1.12.0`에서 **`>= 1.9.0`**으로
>   하향) · **D-EKS-ENABLED를 upstream `create` 토글에 위임** · `eks-pod-identity` 핀 `2.8.2` ·
>   출력 fallback 불일치 함정 기록.
> - **✅ Task 20.1(d) 완료 + ⛔ D-ADDON-VERSION-PIN 개정**(2026-08-03, 3차) — AWS 계정 실측 결과가
>   *"모듈이 addon 버전을 소유하면 안 된다"* 를 보여, **D-ADDON-VERSION-PIN-1**으로 핀의 소유
>   주체를 **소비 루트**로 옮겼다(§2.6-6). 모듈은 `most_recent = false`만 소유한다.
> - **✅ D-EXTDNS-ZONE 해소**(2026-08-05 = **`eks-cluster-v0.2.0`**, §4.2) — 2026-08-04 apply가
>   발견한 조합(`enable_external_dns_iam = true` + zone ARN 비움)을 **교차변수 validation**으로
>   plan에서 배제했다. §5.1-8 종결. 예제는 Route53 private zone을 직접 만들어 실효 형상이 됐다.
> - **✅ D-WORKBENCH-SEAM 3층 + D-TOFU-FLOOR**(2026-08-05 = **`eks-cluster-v0.3.0`**, §4.3) —
>   `cluster_security_group_additional_rules` 신설(§3.1)로 *"클러스터가 누구를 네트워크로
>   받아들이는가"* 의 소유 지점을 이 모듈에 뒀다. §5.1-9 종결. `required_version` 하한도 함께
>   `>= 1.9.0` → **`>= 1.12.0`** 으로 통일됐다(§3.3).
>
> 이후 **이 문서가 SSOT**다. 원본은 이력 조회용으로만 본다.

> 공통 규약: [02 · 네이밍·태깅·버전 핀](../architecture/02-naming-tagging-and-pinning.md) ·
> 전략 근거: [01 · 모듈 전략](../architecture/01-module-strategy.md) ·
> 의존성 원칙: [03 · 의존성 & 공유 리소스](../architecture/03-dependencies.md)

**전략 위치**: 고속 churn·지식밀도 높음·정확성 비직관적 → **커뮤니티 `terraform-aws-modules/eks` +
wrapper(facade)**(`01 §2.2`). Karpenter는 **IAM 전제조건만 IaC**, helm/NodePool은 GitOps.

**릴리스 스코프**: 이 문서의 §1~§3이 현행 **`eks-cluster-v0.3.0`** 의 계약이다.

> ⚠️ **2026-08-05 D-VERSION 재매핑** — `eks-cluster-v1.0.0`은 **같은 커밋(`74bbf51`)의**
> `eks-cluster-v0.1.0`으로 바뀌었고 구 태그는 삭제됐다
> ([`architecture/05`](../architecture/05-versioning-policy.md)).
> **§4.1 릴리스 기록과 §5 열린 항목의 번호는 그때의 사실 기록이라 그대로 둔다.**
>
> **`0.y.z` 구간이므로 계약 변경도 마이너**다(05 §1) — 이 문서에서 *"이것이 마이너인가 메이저인가"*
> 를 판정하던 서술은 더 이상 필요 없다. 메이저는 `1.0.0` 이후에 의미를 갖는다(판정 기준 05 §2).

> **승계한 PoC 결정 요약** (판단은 유효, 실증 서술은 findings 소관):
> **D9 custom networking** 전제(§2.5) · **addon 관리 C′**(§2.6, baseline merge·재주입·EBS CSI IAM) ·
> **D-ADDON-VERSION-PIN**(§2.6-6 — ⛔ **2026-08-03 `-1`로 개정됨**, 소유 주체 이전) ·
> **D-NODE-AMI-PIN**(§2.6, NG AMI 핀) ·
> **D-ADDON-BOUNDARY**(§1, community addon은 IaC) · **D-ADDON-IAM**(§2.6a, 컨트롤러 IAM 두 갈래).
> Karpenter 컨트롤러 정책의 `enable_inline_policy = true`는 **관리형 정책 한도(6,144자) 초과 실측**에서
> 나온 hotfix이며 그대로 승계한다(inline 한도 10,240자, upstream #3563).

---

## 1. 경계 (Day 0/1 IaC ↔ Day 2 GitOps)

| 계층 | 도구 | 대상 | 이 모듈? |
|------|------|------|---------|
| Day 0/1 인프라 | **IaC(OpenTofu)** | 클러스터, managed node group, IAM(Pod Identity), OIDC | ✅ |
| EKS Managed/Community Addons | **IaC** `addons`(=aws_eks_addon) | core·storage·관측성·DNS 컨트롤러 — §2.6 표(vpc-cni, coredns, kube-proxy, eks-pod-identity-agent, aws-ebs-csi-driver, metrics-server, **fluent-bit, kube-state-metrics, prometheus-node-exporter, cert-manager, external-dns**) | ✅ |
| Karpenter IAM 전제조건 | **IaC** `//modules/karpenter` | 컨트롤러 Pod Identity 역할, 노드 IAM, instance profile, 중단 SQS | ✅ |
| 컨트롤러 IAM(ALBC·external-dns) | **IaC** `eks-pod-identity` | role + 정책 + standalone Pod Identity association (§2.6a) | ✅ opt-in |
| 부트스트랩 seam | **미결정** | ArgoCD 설치·등록 경로 → [`21`](21-gitops-bootstrap-seam.md) (`01 §3.3` 재결정 대상) | ❌ 배포 루트 |
| Day 2 GitOps | GitOps | **AWS Load Balancer Controller**(community addon 아님 → helm, IAM은 §2.6a로 IaC), Karpenter helm/NodePool, **컨트롤러 설정(cert-manager Issuer/Certificate CR, external-dns 애노테이션)**, 앱 워크로드 | ❌ |

> **한 줄 규칙(D-ADDON-BOUNDARY)**: `aws_eks_addon` API로 설치 가능한 것은 **IaC가 기본**이다
> (community add-on 포함). `aws_eks_addon`은 AWS API지 helm/kubernetes provider가 **아니므로** push 안티패턴
> (`01 §3.1`)에 해당하지 않는다 — community addon도 IaC가 기본인 이유. **컨트롤러(+CRD)는 IaC addon,
> 그 addon이 소비하는 CR 인스턴스·애노테이션(cert-manager Issuer/Certificate, external-dns가 읽는 Ingress
> 애노테이션)은 GitOps**로 나눈다(설정은 앱·플랫폼팀이 Git에서 관리). **helm/manifest만 가능한 것**
> (ALBC — community addon 부재)**→ GitOps helm**. 목록 개정 이력은 §2.6.
>
> ⚠️ **community addon 지원 모델**(공식): AWS는 **버전 호환 검증 + 라이프사이클(install/update/remove)만**
> 지원하고 **기능은 미지원**(shared responsibility). prd 채택 전 이 트레이드오프를 인지한다.
>
> 🔑 **경계표의 마지막 두 행은 이 모듈 밖이다.** 모듈이 그쪽에 지는 의무는 **출력 계약**(§3.2)뿐이며,
> 부트스트랩 seam이 무엇으로 재결정되든(관리형 Capability / self-managed ArgoCD / 제3안) 바뀌지 않는다.
>
> ⭐ **"Day 2 GitOps" 행은 고객사마다 갈린다**([`22`](22-day2-operations.md) **D-DAY2-PROFILE**).
> 플랫폼 엔지니어링 팀이 없는 고객사는 이 행을 GitOps 없이 수행하며, 그때 helm 대상은
> **ALBC·Karpenter 둘뿐**이다 — D-ADDON-BOUNDARY가 나머지를 IaC로 당겨 놨기 때문이다.
> **양쪽 프로파일이 쓰는 출력→설치 입력 매핑표는 [`22 §3.3`](22-day2-operations.md)에 있다.**
> ⚠️ **버전 업그레이드는 프로파일과 무관하다** — 클러스터·노드·addon 세 손잡이의 갱신 순서는
> [`22 §2`](22-day2-operations.md) 런북이 소유한다(AWS 권장 순서상 **3개의 apply로 나뉜다**).
>
> **CR 소유 정밀화(D-CR-OWNERSHIP, [`30-gitops-repo.md §0.1`](30-gitops-repo.md))**: 이 §1 규칙은 컨트롤러↔
> CR을 가르지만, 그 CR을 **플랫폼(계층 2)이 갖나 앱팀(계층 3)이 갖나**는 별개 질문이다. 판별자는 (1) CR이
> IAM·비용·용량 같은 **인프라 정체성**을 인코딩하는가, (2) 규칙이 **제약하는 대상**이 소유자와 같은가이며,
> blast radius(cluster/namespace)는 보조 신호다(예외 실재) — Karpenter NodePool·Kyverno ClusterPolicy=계층 2,
> KEDA ScaledObject·Kyverno 네임스페이스 Policy=계층 3. "CR이면 앱팀"도 "namespaced면 앱팀"도 오판이다.

> **§1 경계 재개정 근거 (D-ADDON-BOUNDARY)**: cert-manager·external-dns·fluent-bit·kube-state-metrics·
> prometheus-node-exporter가 모두 **EKS community addon**(`owner=community`, `aws_eks_addon` 설치)으로
> 제공됨을 확인했다. 기존 예외(cert-manager·external-dns=GitOps)는 "helm-only"를 전제로 썼으나,
> addon 경로는 push 안티패턴이 아니므로 예외 명분이 소멸 → **컨트롤러는 IaC addon, 설정만 GitOps**로 정련.
> 관측성 3종은 미분류 공백이었고 기본값대로 IaC. ALBC만 community addon 부재로 GitOps helm 유지
> (→ §2.6a eks-pod-identity 위임 범위는 ALBC로 축소).
> ⚠️ **addon 카탈로그는 AWS가 바꾼다.** 구현 착수 시 `aws eks describe-addon-versions`로 대상 리전·k8s
> 버전에서의 가용성과 `owner`를 재확인한다(Task 20.1). 위 목록은 확인 시점의 스냅샷이다.

## 2. facade 원칙 (핵심)

소비자는 `cluster_name`·`cluster_addons`·`kubernetes_version`을 쓰고, wrapper가 upstream
`name`·`addons`·`kubernetes_version`으로 번역한다.

> v21 실제 변수명 확인됨: 루트는 **`name`·`addons`**(`cluster_addons`가 아니다). 이 변수들이 메이저마다
> 바뀌므로 facade가 **유일한 번역 지점**이며, upstream rename이 소비 프로젝트로 새지 않는다(`01 §2.3`).
> 이것이 `02 §3`의 semver 계약이 성립하는 근거다 — upstream 파괴적 변경을 인터페이스 유지로 흡수하면
> 내부 **마이너**, 숨길 수 없으면 내부 **메이저**.

리소스 약어(카탈로그): 클러스터 `eks`, 노드그룹 `eksn`, Fargate 프로파일 `eksf`, IAM 역할 `iamr`.
클러스터명은 모듈이 합성한다 — `eks-<workload>-<env>-<regioncode>-<purpose>-<serial>`
(예: `eks-acme-prd-an2-main-01`). ⚠️ **workload code는 소비자가 `naming` 객체로 주입**하며 이 repo는
값을 고정하지 않는다(`01 §4` 파라미터화, `05 §5.4`).

## 2.5 네트워킹 통합 — VPC D9 custom networking

VPC 설계 [`10-vpc-module.md` D9](10-vpc-module.md)의 A안(custom networking)을 전제로 설계한다.

> ✅ **이 전제는 `vpc-v1.1.0`에서 실물로 성립한다** — VPC 모듈이 `eks_cluster_name`(D4 디스커버리 태그)·
> `subnet_groups[*].extra_tags`(Karpenter discovery 태그)·`subnet_ids_by_group` 출력을 모두 제공한다.
> 두 모듈은 **네이밍/출력 계약으로만** 결합하며, 서로의 state를 참조하지 않는다(`03 §3.1`).

| 항목 | 값 | 근거 |
|------|-----|------|
| 노드·컨트롤플레인 ENI 서브넷 | `subnet_ids_by_group["node-uniq"]` (unique 대역) | D9 — node-SNAT 소스, 온프레미스 방화벽 오픈 단위 |
| Pod 서브넷 (ENIConfig) | `subnet_ids_by_group["pod-dup"]` (100.64.0.0/10 비라우팅 대역) | D9 — 비라우팅 대량 소모 대역 |
| Pod ENI 보안그룹 | **ENIConfig에 지정하지 않는다**(primary ENI SG 상속) | 노드와 동일 정책 — 아래 정정 참조 |
| SNAT | `AWS_VPC_K8S_CNI_EXTERNALSNAT=false`(기본) 유지 | Pod→온프레미스가 노드 uniq IP로 SNAT되는 D9 전제 |
| max-pods 감소 대응 | `ENABLE_PREFIX_DELEGATION=true` | custom networking 시 primary ENI 미사용 보상 |

> **⭐ 정정(2026-08-03, 구현이 발견) — Pod ENI SG를 ENIConfig에 지정하지 않는다.**
> 원 서술은 *"upstream `node_security_group_id` 재사용"* 이었으나 **구현 불가**다:
> `module.eks.node_security_group_id`를 같은 `module.eks`의 입력(`addons`)에 넣으면 **순환 참조**다.
> → ENIConfig에서 `securityGroups`를 **생략**한다. 지정하지 않으면 vpc-cni가 **primary ENI의 SG를
> 상속**하는데 그게 곧 노드 SG이므로, **원 설계의 의도가 생략으로 그대로 달성**된다.
> 별도 Pod SG 요구가 생기면 그때 변수를 연다(계약 확장이므로 마이너).

> ⚠️ **그룹 키(`node-uniq`·`pod-dup`)는 VPC 모듈이 강제하지 않는다** — `subnet_groups`의 키는 소비자가
> 정한다(10 §1.3: *"권고하나 모듈이 강제하지는 않는다"*). 따라서 EKS 모듈은 **키 이름을 가정하지 않고**
> `subnet_ids`·`pod_subnet_ids`를 **ID 리스트로 받는다**(§3.1). 키 매핑은 소비자 루트의 책임이다 —
> 모듈이 남의 모듈의 관용 키에 결합하면 그 관용이 바뀔 때 조용히 깨진다.

**구성 방식 — 경계 규칙 준수**: custom networking은 **vpc-cni managed addon의
`configuration_values`로 선언**한다(env: `AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG`,
`ENI_CONFIG_LABEL_DEF=topology.kubernetes.io/zone` + `eniConfig` 블록으로 AZ별 ENIConfig 생성).
이 방식이면 ENIConfig가 Helm/manifest가 아닌 addon API 경계 안에 남는다(§1 규칙).
addon은 **노드그룹 생성 전 적용**(`before_compute`)이어야 초기 노드부터 Pod가 pod-dup에 배치된다.

> ✅ PoC 실측: vpc-cni addon configuration schema가 `eniConfig.create`를 **지원함을 확인**
> (`aws eks describe-addon-configuration`). ENIConfig가 addon `configuration_values` 경계 안에서
> 생성되므로 `kubernetes_manifest` fallback은 불필요(폐기). ⚠️ **스키마는 addon 버전마다 다르다** —
> 핀 버전 기준으로 Task 20.1에서 재확인한다.

**선행 순서 — 소비자 루트의 책임** (구 Task 20.0을 이 repo 밖으로 옮긴 것):
클러스터명은 **VPC보다 먼저 결정**되어야 한다. 소비자는 EKS 모듈이 합성할 이름과 **같은 값**을
VPC 모듈의 `eks_cluster_name`에 넘겨 서브넷 디스커버리 태그를 부여하고, Karpenter discovery는
node 그룹 `extra_tags`에 `karpenter.sh/discovery=<클러스터명>`으로 넣는다.

> 🔑 **왜 모듈이 이걸 자동화하지 않는가**: 자동화하려면 EKS 모듈이 VPC 모듈의 리소스를 수정해야 하고,
> 그건 두 모듈 사이에 **양방향 의존**을 만든다(EKS→VPC 태그 쓰기 + VPC→EKS 서브넷 읽기 = 순환).
> `03 §3.1`의 1순위(**결정적 네이밍으로 값 구성**)를 쓰면 순환 없이 풀린다 — 양쪽이 같은 규칙으로
> 같은 문자열을 **각자 유도**하면 되기 때문이다. 이름 규약이 의존성을 지운다는 `03`의 핵심 시너지가
> 여기서 실제로 쓰인다.
>
> ⚠️ 대신 **소비자가 두 곳에 같은 값을 넣는다**는 부담이 남는다. 이를 줄이려면 소비자 루트에서
> `local.cluster_name`을 한 번 정의해 두 모듈에 넘긴다 — 예제(`examples/eks-cluster-enterprise/`)가 이 패턴을 보인다.

### 2.5-1 소비 프로젝트에서 VPC를 참조하는 법 (2026-08-03 신설)

⚠️ **`examples/`는 이 형태가 아니다.** 예제는 한 루트에서 VPC와 EKS를 함께 만든다 — `01 §4`가
"예제가 곧 `tofu test` 대상"이라 self-contained해야 `validate`가 돌기 때문이고, CI 게이트 ⑤도 그걸
요구한다. **소비 프로젝트는 다르다**: networking과 eks-cluster는 **별도 배포 루트**다(`03 §4`).
이 차이를 적어 두지 않으면 고객사가 예제를 복사해 두 루트를 한 곳에 합치고, **apply가 성공하기 때문에
아무도 지적하지 않은 채 굳는다.**

**참조 방식은 `03 §3.1`의 2순위 — `data.aws_*` 태그 조회**다.
⛔ `terraform_remote_state`는 쓰지 않는다(state 전체 접근 — `03 §3.1`이 ❌로 판정).

```hcl
# live/dev/eks-cluster/main.tf — networking 루트가 이미 apply되어 있다는 전제
data "aws_vpc" "main" {
  filter { name = "tag:Name", values = ["vpc-${local.name_mid}-main"] }
}

data "aws_subnets" "node" {
  filter { name = "vpc-id", values = [data.aws_vpc.main.id] }
  # ⭐ VPC 모듈 D13이 부여하는 그룹 태그. Name 와일드카드 파싱이 아니다.
  filter { name = "tag:SubnetGroup", values = ["node-uniq"] }
}

data "aws_subnets" "pod" {
  filter { name = "vpc-id", values = [data.aws_vpc.main.id] }
  filter { name = "tag:SubnetGroup", values = ["pod-dup"] }
}

module "eks" {
  source = "git::https://github.com/<org>/iac-module-library.git//modules/eks-cluster?ref=eks-cluster-v0.1.0"

  vpc_id         = data.aws_vpc.main.id
  subnet_ids     = data.aws_subnets.node.ids
  pod_subnet_ids = data.aws_subnets.pod.ids
  # ...
}
```

**모듈 계약은 이 방식을 이미 지원한다** — `vpc_id`·`subnet_ids`를 **ID 리스트로** 받으므로 값의
출처가 무엇이든 무관하다(§3.1). 모듈에 조회 로직을 넣지 않은 것은 의도된 것이다: 조회 키(태그 이름·
그룹 키)는 **소비자의 명명 정책**이라 모듈이 고정하면 그 정책을 강제하게 된다.

⚠️ **`data.aws_subnets`의 `ids`는 정렬 순서가 보장되지 않는다.** AZ 순서에 의존하는 로직을 소비자
루트에 두지 않는다 — 이 모듈은 AZ 매핑을 내부에서 `data.aws_subnet`으로 해석하므로(§3.1) 영향이 없다.

⚠️ **networking이 아직 apply되지 않았으면 조회가 빈 결과를 낸다.** 배포 순서(networking → eks-cluster)는
소비 repo의 워크플로가 강제한다([`50`](50-reference-consumer-repo.md)). 조회 실패를 명시적으로 잡으려면
`precondition`으로 `length(data.aws_subnets.node.ids) > 0`을 확인한다(`03 §6` 열린 항목 4).

## 2.6 addon 관리 — baseline 보장 + 명시적 증분 (C′)

> **D-ADDON-VERSION-PIN** (2026-07-22, ⛔ **2026-08-03 `-1`로 개정 — 아래 항목 6의 상자를 먼저 읽을 것**):
> baseline addon 버전을 **명시적으로 핀**한다(항목 6 신설).
> ⚠️ **결론(“모듈이 값을 고정한다”)은 철회됐고 이 배경 서술은 유효하다** — 원인은 `most_recent = true`였고
> 그것을 끄는 주체는 지금도 모듈이다. 배경과 결론을 함께 되살리지 말 것.
> 배경 — 최초 구현은 `addon_version`을 미지정(null)으로 넘겼는데, upstream
> `terraform-aws-modules/eks` v21의 `addons` 스키마는 **`most_recent = optional(bool, true)`**
> (기본 true)라, 버전을 안 박으면 매 plan마다 `aws_eks_addon_version`으로 최신 호환 버전을 조회해
> AWS가 새 버전을 릴리스할 때마다 **리뷰 없는 in-place 업데이트**(예: kube-proxy)가 발생했다.
> AWS 공식(managing-add-ons)은 addon을 "원할 때(when desired) 업데이트"하는 신중한 모델을 권하며,
> AWS는 사용자 클러스터의 addon을 자동 업그레이드하지 않는다 — `most_recent=true`는 그 판단을
> OpenTofu가 매 apply마다 대신 내리게 해 이 모델을 우회했다. CLAUDE.md 버전 핀 철학과도 상충.

**문제**: OpenTofu 변수 default는 전체 대체라, 소비자가 addon 1개를 추가하려고 map을 넘기면
기본 addon이 통째로 대체되고 누락분은 **in-place 삭제**된다(coredns 삭제 = DNS 중단). 또한
IAM이 필요한 addon(EBS CSI)이 role 없이 설치되면 무용지물인데 facade에 IAM 연동 경로가 없었다.

**설계 (C′)**:
1. **baseline 6종은 모듈이 소유** (아래 표) — 소비자 입력과 `merge()`되므로 누락 ≠ 삭제.
2. **제거는 `enabled = false` 명시로만** — null 값 같은 암묵 규약 없음. **core 4종은
   validation으로 비활성화 차단**: vpc-cni·coredns·kube-proxy는 클러스터 기능 자체,
   `eks-pod-identity-agent`는 Karpenter·EBS CSI의 Pod Identity association 생존 전제
   (없으면 IAM엔 존재하나 Pod가 자격증명을 못 받는 조용한 파손).
3. **모듈 소유 필드는 merge 뒤 재주입** — OpenTofu의 `merge()`는 shallow라 소비자가 버전만
   override해도 엔트리가 통째로 교체된다. vpc-cni `configuration_values`(§2.5 합성)와
   aws-ebs-csi-driver `pod_identity_association`(아래 4)은 merge 결과 위에 모듈이 다시 덮어
   항상 승리한다(기존 §2.5 vpc-cni 패턴의 일반화).
4. **EBS CSI IAM은 모듈이 생성** (Karpenter와 동일한 "IAM 전제조건은 IaC" 배치):
   role `iamr-{workload}-{env}-{region_code}-ebs-csi`(카탈로그 A.6 `iamr`), 신뢰
   `pods.eks.amazonaws.com`, 정책 `AmazonEBSCSIDriverPolicy`, association은 addon의
   `pod_identity_association`(SA `ebs-csi-controller-sa`)으로 연결. ebs-csi를
   `enabled=false`로 빼면 role도 미생성.
5. **기타 IAM 필요 addon**(예: aws-efs-csi-driver)은 소비자가 `pod_identity` 필드로
   role_arn·service_account 주입 — role 생성은 **소비자 소관**(공유 IAM은 foundation 계층 — `03 §4`).
   upstream 스키마 실물 확인(2026-07-18): `pod_identity_association = list(object({
   role_arn, service_account }))` — **namespace 필드 없음**(addon 네임스페이스로 암묵 결정).
6. **addon 버전은 명시적 핀 — 단 핀의 소유자는 소비 루트다**
   (2026-07-22 D-ADDON-VERSION-PIN → **2026-08-03 D-ADDON-VERSION-PIN-1로 개정**, 아래 상자)
   - **모듈이 소유**: `most_recent = false`. upstream 기본값 `true`를 끄는 것은 **구조적 결정**이라
     모듈의 몫이다 — 이 한 줄이 "매 plan이 최신을 재해석"하는 동작을 없앤다.
   - **소비 루트가 소유**: `addon_version` **값**. `cluster_addons`로 addon별로 넘긴다.
   - **소비자가 값을 안 주면**: upstream이 `data.aws_eks_addon_version(most_recent = false)`로
     **그 클러스터의 k8s 버전·리전에 맞는 AWS 기본 버전**을 해석한다(upstream `main.tf:759-778` 실측).
     안전한 기본값이며, 모듈이 값을 들고 있을 때와 달리 **어떤 k8s·리전 조합에서도 유효**하다.
   - **업그레이드 = 소비 루트의 커밋**: 버전 상향은 그 워크로드 repo의 명시적 커밋으로만 일어나고
     plan diff로 리뷰된다. AWS의 "when desired" 판단을 **그 클러스터를 운영하는 사람**이 회수한다.
   - **community tier addon**(아래 확장 표)도 동일 정책.

> **⛔ D-ADDON-VERSION-PIN-1 (2026-08-03) — 핀의 소유 주체를 모듈에서 소비 루트로 옮긴다.**
> 구 결정은 *"baseline addon마다 버전을 **모듈이** 고정한다"* 였다. 그 서술을 되살리지 말 것.
>
> **철회 근거 ① 경계** — addon 버전은 워크로드 운영 주기에 속하는 값이다. 공통 모듈이 들면
> **고객사 A의 kube-proxy 상향이 모듈 릴리스를 요구하고, 그 릴리스는 B·C에게도 배송된다.**
> 반대로 A는 B가 준비될 때까지 못 올린다. CLAUDE.md의 *"upstream cadence와 소비자 cadence를
> 분리한다"* 를 모듈이 스스로 깨는 구조이며, **D26**(규약 SSOT는 모듈 repo / 배포 사실은 소비 repo)
> 에 비추면 버전 값은 명백히 **배포 사실** 쪽이다.
>
> **철회 근거 ② 정의역** — addon 버전은 상수가 아니라 **`f(kubernetes_version, region)`** 이고,
> 두 인자 모두 소비자가 정한다. 모듈이 결과값을 상수로 들면 인자가 바뀌는 모든 축에서 깨진다.
> 2026-08-03 실측으로 두 축 모두 실제 파손이 확인됐다(Task 20.1(d) 참조):
> - k8s 축: 1.35 기준 핀을 1.34/1.33에 쓰면 `coredns`·`kube-proxy`·`metrics-server`가 **버전 없음**
> - 리전 축: `cert-manager`가 an2에는 `eksbuild.3`, us-east-1·eu-west-1에는 `eksbuild.2`만 존재
>
> ⚠️ **원래 막으려던 사고는 그대로 막힌다.** 구 결정의 배경(위 상자)은 `most_recent = true`가
> 원인이었고 그것을 끄는 주체는 여전히 모듈이다. **핀을 폐기한 것이 아니라 소유자를 옮겼다** —
> 완전 결정적 고정을 원하는 소비자는 `cluster_addons`로 값을 박으면 되고, 그 경로는 이미 있다.
>
> ⛔ **"모듈이 안전한 기본값을 주는 게 낫지 않나"는 이미 값을 매겨 기각했다**(선택지 4종 비교).
> 모듈이 k8s 버전별 핀 표를 소유하는 안은 정의역 문제는 풀지만 **경계 문제는 그대로**다.

> **2026-07-27 확장 (D-NODE-AMI-PIN)**: 같은 "리뷰 없는 자동 업데이트 금지" 철학을 **managed 노드그룹
> AMI**에도 적용한다. facade `managed_node_groups.ami_release_version`(optional)을 신설하고 소비자
> (live)가 concrete 버전을 핀한다. **배경**: 핀 없이는 upstream이 매 plan마다 최신 AMI release version을
> 해석해(예: `1.35.6-20260714 → 1.35.6-20260724`) apply 시 **노드 롤링 교체**를 유발한다(2026-07-27 실측
> — SG 태그 apply에 편승하려다 발견). addon과 동일하게 업그레이드는 이 값 bump하는 명시적 커밋으로만
> 일어나고 plan diff로 리뷰된다. `use_latest_ami_release_version`은 켜지 않는다. k8s 버전 승격 시 새 AMI
> 버전으로 함께 갱신(런북 대상). null 유지 시 기존(최신 해석) 동작 — 하위호환.
> **⚠️ 함정(2026-07-27 실측)**: upstream eks-managed-node-group 서브모듈은
> `use_latest_ami_release_version` **기본 true**라 `release_version = use_latest ? SSM최신 : ami_release_version`
> — `ami_release_version`만 주면 **무시된다**(addon `most_recent=true` 함정의 판박이). facade가
> `use_latest_ami_release_version = (ami_release_version == null)`로 파생해 핀이 있으면 최신 조회를 끈다.

> **2026-08-04 신설 (D-NODE-ARCH)**: facade `managed_node_groups.ami_type`(optional, 기본
> `AL2023_x86_64_STANDARD`)을 노출한다. **배경**: 소비 루트가 graviton 노드를 요구했는데 계약에
> 아키텍처 결정 지점이 없었다 — `instance_types`만 arm(t4g·m7g)으로 바꾸면 AMI 는 x86 그대로라
> **노드가 부팅되지 않는다.** upstream 서브모듈의 `ami_type`은 `nullable = false`(기본 x86)이고 루트가
> `each.value.ami_type`을 그대로 넘기므로(v21.24.1 실측), facade 는 optional 기본값으로 **항상 non-null
> 문자열**을 보장한다 — null 을 흘리면 하위 모듈에서 죽는다.
> **⚠️ 아키텍처 짝은 소비자 책임이다.** `ami_type` × `instance_types` 불일치는 **plan 에서 잡히지 않고**
> (AWS 도 노드그룹 생성 시점에야 거부한다) `ami_release_version` 값도 **아키텍처별로 다르다**(arm SSM 경로).
> 모듈이 대신 판정하지 않는 이유: 인스턴스 타입 → 아키텍처 매핑을 모듈이 소유하면 신형 인스턴스가
> 나올 때마다 모듈 릴리스가 필요해진다(D-ADDON-VERSION-PIN-1의 "경계" 논리와 동형).
> **닫힌 검증은 `ami_type` 값 자체에만 건다** — 오타(`AL2023_ARM64_STANDARD`)의 대가가 비대칭이기
> 때문이다(클러스터 생성 후 실패 vs 몇 초). 목록 출처는 EKS API Reference `Nodegroup.amiType`
> (2026-08-04). ⚠️ 이 목록은 낡는다 — 실제로 기존 `capacity_type` 검증은 AWS 가 나중에 추가한
> `CAPACITY_BLOCK`을 아직 담고 있지 않다(**열린 항목**: 닫힌 검증의 유지보수 부채).

| baseline addon | 분류 | 보호 | IAM |
|---------------|------|------|-----|
| vpc-cni | core | enabled=false 금지 | — (§2.5 configuration은 모듈 소유) |
| coredns | core | enabled=false 금지 | — |
| kube-proxy | core | enabled=false 금지 | — |
| eks-pod-identity-agent | core | enabled=false 금지 | — (association 인프라) |
| aws-ebs-csi-driver | optional | opt-out 허용(role 동반 제거) | 모듈 생성(위 4) |
| metrics-server | optional (community, an2/1.35 가용 확인) | opt-out 허용 | 불필요 |

**확장 community addon tier (IaC — D-ADDON-BOUNDARY)**: §1 재개정으로 아래도 `aws_eks_addon`
(`owner=community`)으로 IaC가 소유한다. baseline 6종과 동일한 merge·opt-out 메커니즘, 단 core 보호는
없음(전부 opt-in/opt-out 자유). 컨트롤러가 소비하는 CR·애노테이션은 GitOps(§1).

| community addon | tier | IAM | 비고 |
|-----------------|------|-----|------|
| fluent-bit | 관측성 | 기본 없음(CloudWatch 출력 시 addon role) | 로그 → CloudWatch/S3/Firehose |
| kube-state-metrics | 관측성 | 없음 | ns `kube-state-metrics`. ⚠️ kube-prometheus-stack 채택 시 중복 주의(열린 항목) |
| prometheus-node-exporter | 관측성 | 없음 | ns `prometheus-node-exporter`. 〃 |
| cert-manager | DNS/인증서 | 없음(HTTP01) | 컨트롤러+CRD. Issuer/Certificate CR은 GitOps. DNS01 시 §2.6a |
| external-dns | DNS | addon `pod_identity_association`(§2.6a) | 관리형 Route53 → zone 축소. 애노테이션은 GitOps |

> **관측성 스택 열린 항목**: KSM·node-exporter는 `kube-prometheus-stack`(GitOps helm)에 번들되는 경우가
> 많다. AMP(Amazon Managed Prometheus) 직결(addon 개별) vs self-managed 스택(GitOps) 중 관측성 아키텍처가
> 정해지면 이 tier에서 뺄 수 있다(중복 배포 방지). 현재는 addon 개별 분류로 시작.

**IAM 네이밍 이원화 (의식적 결정)**: 모듈이 **직접 저작**하는 role은 카탈로그 준수(`iamr-*`).
Karpenter **서브모듈 위임** role은 upstream 기본 네이밍(`KarpenterController-*`,
`Karpenter-<cluster>-*`)을 수용한다 — v21.24.0이 `iam_role_name`·`node_iam_role_name`·
`queue_name` override를 노출하므로 강제가 아닌 선택이며, prd 확산 단계에서 fork 없이 변수
주입만으로 카탈로그 준수 전환 가능(가역). **네이밍 tftest는 EBS role을 특정 리소스 주소로
직접 assert**하고 전체 IAM 순회를 하지 않는다(위임 role 2종 false-fail 방지).

### 2.6a 컨트롤러 IAM 전제 — 설치 경로별 두 갈래 (D-ADDON-IAM, D-ADDON-BOUNDARY로 개정)

**원칙 (IAM 소유 = addon 분류, 정책은 위임)**: ① baseline 컨트롤러의 IAM 전제는 **IaC(이 모듈)** 소관.
**② 카탈로그 / ③ team-scoped는 이 모듈 밖**(category 5 소비자 또는 별도 경로) — grab-bag 방지. **정책은
hand-author 금지** — self-authored·churn이므로 **AWS 관리형 또는 커뮤니티 큐레이션에 위임**(Karpenter
위임의 일반화, CLAUDE.md 하이브리드 전략 정합).

**IAM 구현 두 갈래** (custom 정책 필요 여부로 구분 — 2026-07-20 구현 확정):
- **custom 정책 컨트롤러(ALBC·external-dns)** → **`terraform-aws-modules/eks-pod-identity`(정확 핀
  `= 2.8.1`)에 위임** — role+정책+**standalone Pod Identity association**을 함께 생성. `name` +
  `use_name_prefix=false`로 카탈로그 `iamr-*` 준수. 정책은 `attach_aws_lb_controller_policy` /
  `attach_external_dns_policy`(+`external_dns_hosted_zone_arns` 스코핑), 커뮤니티 유지보수. 실물 확인
  (get_module_details v2.8.1). 토글 `enable_alb_controller_iam`·`enable_external_dns_iam`(기본 false —
  소비자 opt-in, 유휴 role·live diff 방지). 컨트롤러 설치 경로(ALBC=helm, external-dns=addon)와 무관하게
  IAM 메커니즘은 동일(standalone association이 SA에 바인딩).
- **AWS 관리형 정책 컨트롤러(EBS CSI)** → **addon의 `pod_identity_association`** 필드(현행 §2.6-4, 저churn).

| 컨트롤러 | 설치 | IAM 전제 | 정책 | 비고 |
|----------|------|---------|------|------|
| **ALBC** | GitOps **helm** | **eks-pod-identity 위임**(standalone assoc) | `attach_aws_lb_controller_policy` | community addon 부재 → helm. ingress-nginx(EOL) 대체 |
| **external-dns** | **IaC addon** | **eks-pod-identity 위임**(standalone assoc) | `attach_external_dns_policy` + `external_dns_hosted_zone_arns` 스코핑 | 항상 Route53. ns/SA `external-dns` |
| **cert-manager** | **IaC addon** | **없음**(HTTP01) / DNS01 시 별도 Route53 | — / 스코핑 Route53 | addon은 컨트롤러+CRD만(IAM 미연동). CR(Issuer)은 GitOps |
| **EBS CSI** | IaC addon | addon `pod_identity_association` | AWS 관리형 `AmazonEBSCSIDriverPolicy` | 현행 §2.6-4 |
| 관측성(fluent-bit·KSM·node-exporter) | IaC addon | 기본 없음(fluent-bit CloudWatch 출력 시 addon role) | — | §2.6 관측성 tier |

> **구현 형태**(PoC에서 검증된 배치를 승계): `module.alb_controller_pod_identity`·
> `module.external_dns_pod_identity`(`terraform-aws-modules/eks-pod-identity`, 정확 핀) + 토글 + role ARN 출력.
> ✅ **핀은 `= 2.8.2`**(2026-08-03 Task 20.1(c) 확인 — PoC는 2.8.1). `attach_aws_lb_controller_policy`·
> `attach_external_dns_policy`·`external_dns_hosted_zone_arns`·`name`·`use_name_prefix`·`create` 실재 확인.

> **정책 소싱 우선순위**: AWS 관리형(EBS CSI·external-dns) ≈ 커뮤니티 큐레이션(ALBC via eks-pod-identity) >
> hand-author(최후). 항상 **버전 핀 + 최소권한(zone ARN) 스코핑**.

> **⛔ 정정 (2026-08-04, apply 실측) — `external_dns_hosted_zone_arns`는 "prd 권고"가 아니라
> `enable_external_dns_iam = true`의 필수 입력이다.**
>
> 이 문서는 *"external-dns 관리형 정책은 광범위(`Route53FullAccess`)하므로 zone ARN 축소가 **prd
> 필수**"* 라고 적었다. 그 서술은 **빈 값이면 넓게 열린다**를 전제하는데, 실물은 그렇지 않다 —
> zone ARN이 비면 upstream이 `Resource = "*"` 정책을 만들고 **AWS가 400으로 거부해 apply가 죽는다**
> (`route53:ChangeResourceRecordSets`는 리소스 수준 권한을 요구한다). 실패는 dev·prd를 가리지 않는다.
>
> 🔑 **틀린 방향이 나빴다.** "넓게 열려서 위험하다"는 서술은 소비자에게 *"급하면 비워 두고 나중에
> 좁혀라"* 로 읽힌다. 실제로는 **비워 두면 아예 뜨지 않는다** — 위험 경고가 아니라 **차단 조건**이다.
>
> ✅ **모듈 측 가드는 `eks-cluster-v0.2.0`이 넣었다**(2026-08-05, §4.2). 이제 이 조합은 apply가
> 아니라 **plan에서** 거부된다. 판정 근거는 §4.1의 D-EXTDNS-ZONE 상자(apply 실측)에 있고,
> §5.1-8은 종결됐다.

## 2.7 · 2.8 GitOps 부트스트랩 seam → **[`21-gitops-bootstrap-seam.md`](21-gitops-bootstrap-seam.md)로 이관**

ArgoCD 토폴로지(§2.7, D-ARGOCD)와 스포크 확장 등록 seam(§2.8, D-SPOKE-SEAM)은
**2026-08-03 개정에서 이 문서 밖으로 분리**했다. 절 번호는 30·40 문서의 참조를 보존하려고
이관본에서 그대로 유지한다 — `20 §2.7`을 찾아 온 링크는 여기서 21로 이어진다.

**분리 근거** (상세는 21 §0):
1. [`01 §3.3`](../architecture/01-module-strategy.md)이 *"이 repo는 아직 이 선택을 승계하지 않았다 —
   대안(self-managed ArgoCD 포함)과 함께 다시 결정한다"* 고 명시한다. **개정 대상이 아니라 재결정 대상**이다.
2. 구현체가 `live/cicd/gitops-hub`(배포 루트)라 [`03 §4`](../architecture/03-dependencies.md)상
   이 repo 소유가 아니다.

⛔ **이 분리로 `eks-cluster` 모듈의 계약이 줄어들지는 않는다.** §1 경계표의 "부트스트랩 seam" 행은
클러스터 **밖**의 관심사이고, 모듈이 제공해야 하는 것은 그 seam이 무엇으로 결정되든 동일하다 —
`cluster_name`·`oidc_provider_arn`·`cluster_endpoint` 같은 **출력 계약**(§3.2)뿐이다.
seam 재결정이 모듈 인터페이스를 바꾸지 않는다는 것이, 두 관심사를 분리할 수 있는 근거이기도 하다.

---


## 3. 인터페이스 — `eks-cluster-v0.3.0` 계약

### 3.0 재사용 자산 요건 5종의 이행 (`01 §4`)

PoC 모듈에 없었고 이 repo가 반드시 추가하는 것들이다. **이 표가 개정의 실질**이다 —
아래 §3.1의 변수 중 다섯 그룹이 여기서 나왔다.

| 요건 | 이 모듈의 이행 | 결정 |
|------|--------------|------|
| **파라미터화** | workload code·계정 ID·리전 하드코딩 없음. `naming` 객체 주입, 클러스터명은 모듈이 합성 | — |
| **kill switch** | `cluster_enabled = false` → 전 리소스 파기. **data source까지** 꺼져야 한다 | **D-EKS-ENABLED** |
| **환경 프로파일** | 엔드포인트 노출·NG 크기/capacity·컨트롤플레인 로깅·addon 핀을 변수로 흡수 | §3.1 프로파일 축 |
| **예제 + 테스트** | `examples/eks-cluster/`(최소) + `examples/eks-cluster-enterprise/`(고객 착수 템플릿) | Task 20.6 |
| **출력 계약** | §3.2 출력은 **메이저 내 안정**. kill switch 시 `null` 반환(에러 아님) | §3.2 규약 |

여기에 VPC(D12)와 대칭인 **삭제 보호**를 더한다.

> **⭐ D-EKS-ENABLED (kill switch)** — `cluster_enabled`(기본 `true`). `false`면 모듈이 만드는 모든
> 리소스가 파기된다. ⚠️ **핵심은 게이트가 리소스뿐 아니라 `data` 블록에도 걸려야 한다는 것**이다
> (`01 §4`, findings §6.2): 참조 대상이 사라진 뒤 data source가 살아 있으면 **plan 자체가 실패**해
> kill switch가 "끌 수는 있으나 끈 상태를 유지할 수 없는" 반쪽이 된다.
>
> ✅ **구현은 `count`가 아니라 upstream `create` 토글에 위임한다**(2026-08-03 Task 20.1 확인):
> `terraform-aws-modules/eks` v21.24.1 · `//modules/karpenter` · `eks-pod-identity` v2.8.2가 **셋 다
> `create` 변수를 노출**하고, upstream이 **자체 data source까지 `local.create`로 게이트**한다
> (`data.aws_partition`·`aws_caller_identity`·`aws_iam_session_context`·`aws_iam_policy_document`는
> `count = local.create ? 1 : 0`, `data.aws_eks_addon_version`은 `for_each`에 `local.create` 조건).
> 즉 **`01 §4`의 data source 요건을 upstream이 이미 충족**한다.
> - 이득: `module.eks[0]` 인덱싱이 사라져 출력이 `module.eks.cluster_name`으로 단순해진다.
> - ⚠️ 모듈이 **직접 선언**하는 리소스·data source(EBS CSI role 등)는 여전히 우리가 `count`로 게이트한다.
>   위임되는 것은 upstream 내부뿐이다.
>
> **⭐ D-EKS-PROTECT (삭제 보호)** — `deletion_protection`(기본 `false`).
>
> ✅ **VPC D12와 메커니즘이 다르다**(2026-08-03 Task 20.1(e)로 확정). `aws_eks_cluster`에는
> **`deletion_protection` 인자가 있고**(provider 공식: *"When enabled, the cluster cannot be deleted
> unless deletion protection is first disabled"*), upstream이 `var.deletion_protection`으로 그대로
> 노출한다. 따라서 facade는 **값을 통과시키기만** 하면 된다.
> - 🔑 **이것이 VPC D12보다 강한 보호다.** `prevent_destroy`는 **IaC 차원**이라 state 밖(콘솔·CLI)의
>   삭제를 막지 못한다. `deletion_protection`은 **AWS API 차원**이라 어느 경로로도 막는다.
>   VPC가 `prevent_destroy`를 쓴 것은 VPC에 이런 네이티브 보호가 **없어서**였지, 그 방식이 더 나아서가 아니다.
> - 교차변수 `validation`은 그대로 둔다 — `deletion_protection = true`인 상태의 `cluster_enabled = false`를
>   **plan 시점에 거부**해 "보호를 켠 채 kill switch로 지우는" 경로를 막는다(VPC D12에서 실측된 가드).
>   ⚠️ 교차변수 validation은 `validate`가 아니라 **`plan`에서 평가**되므로 **`*.tftest.hcl`이 유일한
>   검출 지점**이다. `examples`의 `validate`로는 잡히지 않는다.
>
> ✅ **그 결과 `required_version` 하한이 기준선 `>= 1.9.0`으로 내려간다**(§3.3) — 동적 `prevent_destroy`가
> 필요 없어졌기 때문이다. **하한이 낮을수록 소비자를 덜 배제한다**(`02 §2`).

### 3.1 variables

```hcl
# ── 정체성 (파라미터화) ───────────────────────────────────────────────
variable "naming"  { type = object({ workload = string, env = string, region_code = string }) }
variable "purpose" { type = string, default = "main" }
variable "serial"  { type = string, default = "01" }
variable "tags"    { type = map(string), default = {} }
# cluster_name = "eks-${workload}-${env}-${region_code}-${purpose}-${serial}" 를 모듈이 합성한다.
# ⚠️ 소비자는 같은 값을 VPC 모듈의 eks_cluster_name 에도 넘겨야 한다(§2.5 선행 순서).

# ── kill switch · 삭제 보호 (D-EKS-ENABLED / D-EKS-PROTECT) ───────────
variable "cluster_enabled"     { type = bool, default = true }
variable "deletion_protection" { type = bool, default = false }

# ── 클러스터 ─────────────────────────────────────────────────────────
variable "kubernetes_version" { type = string, default = "1.35" }  # N-1. standard support = 1.36/1.35/1.34/1.33
variable "vpc_id"             { type = string }
variable "subnet_ids"         { type = list(string) }              # 노드·컨트롤플레인 ENI (§2.5)

# ── 환경 프로파일 축 (소비자가 조건 분기를 짜지 않게 한다) ─────────────
variable "endpoint_public_access"  { type = bool, default = false }  # GitOps(pull) 전제 → 기본 private
variable "endpoint_private_access" { type = bool, default = true }
variable "public_access_cidrs"     { type = list(string), default = [] }  # ⚠️ 전달 방식은 D-EKS-CIDR-NULL (§4.4)
variable "enabled_log_types"       { type = list(string), default = [] }  # 구 열린 항목 6 — 아래 참조

# ── custom networking (§2.5) ─────────────────────────────────────────
variable "enable_custom_networking" { type = bool, default = true }
variable "pod_subnet_ids"           { type = list(string), default = [] }
# AZ 매핑은 모듈 내부에서 data.aws_subnet 으로 해석한다(입력은 ID 리스트로 단순 유지).

# ── 노드 (시스템 계층 NG — 앱·버스트는 Karpenter) ─────────────────────
variable "managed_node_groups" {
  type = map(object({
    instance_types       = list(string)
    min_size             = number
    max_size             = number
    desired_size         = number
    capacity_type        = optional(string, "ON_DEMAND")
    ami_type             = optional(string, "AL2023_x86_64_STANDARD") # D-NODE-ARCH. arm은 AL2023_ARM_64_STANDARD
    ami_release_version  = optional(string)      # D-NODE-AMI-PIN. null이면 최신 해석(하위호환)
    labels               = optional(map(string), {})
    # value는 optional이다 — k8s의 NoValue taint(값 없는 key:effect)가 유효한 형태이기 때문이다.
    taints               = optional(list(object({ key = string, value = optional(string), effect = string })), [])
  }))
  default = {}
}

# ── addon (§2.6 C′ — baseline과 merge되는 증분/override) ──────────────
variable "cluster_addons" {
  type = map(object({
    enabled       = optional(bool, true)   # 제거는 명시적으로만. core 4종은 validation 차단
    addon_version = optional(string)       # ⭐ 핀의 소유 지점(D-ADDON-VERSION-PIN-1). 미지정이면 AWS 기본 버전
    configuration = optional(string)
    pod_identity  = optional(object({ role_arn = string, service_account = string }))
  }))
  default = {}                             # 빈 map = baseline 6종 상속
}

# ── 네트워크 도달 (D-WORKBENCH-SEAM 3층 / 설계 40 §5) ────────────────────
# "클러스터가 누구를 네트워크로 받아들이는가" = 클러스터 쪽 결정 → 이 모듈이 소유한다(03 §2.3).
variable "cluster_security_group_additional_rules" { type = any, default = {} }

# ── IAM ──────────────────────────────────────────────────────────────
variable "access_entries"   { type = any,  default = {} }   # aws-auth 대체
variable "enable_karpenter" { type = bool, default = true }
variable "enable_alb_controller_iam" { type = bool, default = false }  # §2.6a opt-in
variable "enable_external_dns_iam"   { type = bool, default = false }  # §2.6a opt-in
variable "external_dns_hosted_zone_arns" { type = list(string), default = [] }  # ⛔ IAM on이면 비울 수 없다(D-EXTDNS-ZONE)
```

**PoC 대비 변경점**:
- ➕ `cluster_enabled`·`deletion_protection` (재사용 요건 — 위 D-EKS-ENABLED/PROTECT)
- ➕ `enabled_log_types` — **구 열린 항목 6을 계약으로 승격**. PoC는 trivy `AVD-AWS-0038`을 알고도
  비용 때문에 보류했는데, 재사용 자산에서는 **보류가 곧 모든 고객사에 대한 기본값**이 된다.
  기본 `[]`로 PoC 동작을 유지하되 **소비자가 켤 수 있게** 노출하는 것이 옳은 처리다(VPC Flow Logs와 동일 취급).
- ➕ `managed_node_groups.ami_release_version` — D-NODE-AMI-PIN을 계약에 명시
- ➕ `managed_node_groups.ami_type` — **D-NODE-ARCH**(2026-08-04). graviton 등 아키텍처 선택 지점.
  없으면 arm 인스턴스를 넣어도 AMI가 x86이라 노드가 부팅되지 않는다(계약에 결정 지점이 없던 빈틈)
- ➕ `enable_alb_controller_iam`·`enable_external_dns_iam`·`external_dns_hosted_zone_arns` (§2.6a)
- ➕ `cluster_security_group_additional_rules` — **D-WORKBENCH-SEAM**(2026-08-05, `v0.3.0`).
  upstream v21의 `security_group_additional_rules`를 통과시킨다. **`cluster_` 접두는 의도적**이다 —
  node SG 쪽(`node_security_group_additional_rules`)과 이름으로 구분되지 않으면 규칙을 엉뚱한 SG에 붙인다.
  - 🔑 **또 하나의 "facade가 upstream을 가린" 사례**였다(→ `ami_type`/D-NODE-ARCH와 같은 형태).
    upstream엔 **처음부터 있었고** wrapper가 안 넘기고 있었을 뿐이다.
  - ⛔ **이 변수에는 `tofu test`를 만들지 않았다.** facade 한계로 하위 모듈에 넘어간 값을 볼 수 없어
    억지 assertion은 **자기 모킹 설정을 검증**하게 된다. 회귀 방지는 **예제가 실제로 소비하고
    CI 게이트 ⑤(examples validate)가 도는 것**이다(같은 기준을 `workbench` tests 헤더에도 적었다).
- ➖ `enable_pod_identity` — **삭제**. upstream v21은 Pod Identity가 기본이고 이 변수가 없다.
  facade에 남기면 소비자에게 **끌 수 있다는 거짓 계약**을 노출한다(Task 20.1에서 실물 재확인).

### 3.2 outputs

```hcl
# 클러스터 정체성 — 소비자·GitOps seam이 공통으로 쓰는 최소 집합
output "cluster_name" {}                        output "cluster_arn" {}
output "cluster_endpoint" {}                    output "cluster_version" {}
output "cluster_certificate_authority_data" {}  output "cluster_oidc_issuer_url" {}
output "oidc_provider_arn" {}
output "cluster_security_group_id" {}           output "node_security_group_id" {}

# Karpenter (GitOps가 소비)
output "karpenter_iam_role_arn" {}              output "karpenter_node_iam_role_arn" {}
output "karpenter_node_iam_role_name" {}        output "karpenter_instance_profile_name" {}
output "karpenter_sqs_queue_name" {}            output "karpenter_discovery_tag" {}

# addon (§2.6) — merge 결과의 관측점
output "effective_addon_names" {}

# 컨트롤러 IAM (§2.6 / §2.6a)
output "ebs_csi_iam_role_arn" {}                output "alb_controller_iam_role_arn" {}
output "external_dns_iam_role_arn" {}
```

**출력 계약 규약**(`01 §4`):
- 소비자가 의존하는 출력 이름은 **메이저 버전 내에서 안정**하다. 이름 변경은 메이저.
- **kill switch·opt-out 시 `null`을 반환한다**(에러가 아니라). `cluster_enabled = false`인 루트에서도
  `tofu output`이 성립해야 소비자가 조건 분기를 짜지 않는다.
- ➕ `cluster_arn` 추가: GitOps 쪽 클러스터 등록이 **API URL이 아니라 ARN**을 요구한다(21 §2.8 실측).
  seam 방식이 재결정되어도 ARN은 어느 경로든 필요하므로 계약에 둔다.
- ➕ `effective_addon_names` (**2026-08-04 계약 등재** — 구현은 Task 20.7 때부터 있었다):
  baseline merge + `enabled` 필터를 거친 **최종 addon 이름 목록**(정렬). kill switch 시 `[]`.
  - **소비자에게 주는 값**: merge 규약(**누락 ≠ 삭제**, §2.6-1)은 코드를 읽지 않으면 결과를 예측하기
    어렵다. *"내가 넘긴 `cluster_addons`가 baseline과 어떻게 합쳐졌는가"* 를 `tofu output`으로 본다.
  - **모듈에게 주는 값**: facade는 계산 결과를 **하위 모듈의 입력**으로 넘기는데 `tofu test`는 하위
    모듈에 들어간 값을 볼 수 없다. 노출하지 않으면 baseline 상속·opt-out을 config-time에 검증할
    방법이 자체가 없다 — AC5·AC8이 이 출력에 의존한다.
  - ⚠️ 계약에 늦게 올린 것이지 **새로 만든 것이 아니다.** 출력은 릴리스 시점부터 존재했고, 계약표에만
    빠져 있었다. `01 §4`상 소비자가 의존할 수 있는 출력은 전부 §3.2에 있어야 한다.

> ⚠️ **`cluster_security_group_id`의 설명이 값과 다른 SG를 가리키고 있었다**(2026-08-05 `v0.3.0`에서 정정).
> 이 출력의 값은 **upstream 모듈이 만든 SG**이고(`vpc_config.security_group_ids`로 붙어 apiserver ENI에
> 적용된다 = `cluster_security_group_additional_rules`의 대상), **EKS 서비스가 자동 생성하는 primary
> cluster SG는 다른 것**이다(upstream `cluster_primary_security_group_id`, 이 모듈은 노출하지 않는다).
> 🔑 **이름이 아니라 설명이 틀린 결함이라 계약 표에서는 보이지 않았다** — workbench 규칙을 어디에 붙일지
> 판단하는 순간에야 드러났다. 출력 **설명도 계약의 일부**임을 보여주는 사례다(`01 §4` 출력 계약 안정성).

> ⚠️ **함정 — upstream 출력의 fallback 값이 일관되지 않다**(2026-08-03 Task 20.1 확인).
> `create = false`일 때 upstream `outputs.tf`는 대부분 `try(…, null)`이지만
> **`cluster_name`과 `cluster_id`만 `try(…, "")`(빈 문자열)** 이다.
> → facade가 **`null`로 정규화**한다. 그러지 않으면 소비자가 `X == null` 대신 `X == ""`를 알아야 하고,
> 그건 **upstream 구현 디테일이 우리 계약으로 새는 것**이다 — facade가 막으라고 있는 바로 그 종류다.
> tftest AC3(kill switch)에서 **빈 문자열이 아니라 `null`인지**를 assert한다.

### 3.3 `required_version` 하한

> ⛔ **현행 값은 `>= 1.12.0`이다** — 2026-08-05 **D-TOFU-FLOOR**(전 모듈 통일,
> [`../architecture/02 §2`](../architecture/02-naming-tagging-and-pinning.md))로 **상향**됐다.
> ✅ **`eks-cluster-v0.3.0`으로 발행 완료**(§4.3).
>
> ⚠️ **아래 본문은 그때의 사실 기록이다.** 이 모듈이 *"1.12 기능을 쓰지 않는다"* 는 판정은
> **여전히 사실**이며, 상향은 그 판정이 뒤집혀서가 아니라 **하한을 모듈별 근거로 정하는 방식 자체를
> 그만뒀기** 때문이다. 두 문장은 모순이 아니다 — 지우면 *"어느 시점에 무엇이 하한을 정했는가"* 의
> 추적점이 끊긴다.
>
> 🔑 **여기 적힌 "두 마이너 인하"가 D-TOFU-FLOOR의 대가를 실증한다** — 통일 이후에는 이런 인하가
> 다시 일어날 수 없다(근거를 따지지 않으므로). 02가 그것을 대가로 명시했다.

**`>= 1.9.0`** (기준선) — 근거는 **교차변수 `validation`**(D-EKS-PROTECT의 파기 차단 가드)이다.

> ✅ **2026-08-03 확정**: 초안은 `>= 1.12.0`이었다. D-EKS-PROTECT를 VPC D12처럼 **동적 `prevent_destroy`**로
> 구현할 것이라 보았기 때문이다. Task 20.1(e)에서 `aws_eks_cluster`에 **네이티브 `deletion_protection`이
> 있음**을 확인해 그 필요가 사라졌고, **하한을 두 마이너 내렸다.**
>
> 🔑 이 방향이 옳다. 하한은 **실제로 쓰는 기능이 정하고**(`02 §2`), 근거 없는 상향은 **소비자만 배제**한다.
> `vpc`가 `>= 1.12.0`인 것은 그 모듈이 실제로 1.12 기능을 쓰기 때문이지 **repo 표준이 아니다** —
> 모듈마다 하한이 갈리는 것이 `<module>-vX.Y.Z` 컴포넌트별 태그를 쓰는 이유이기도 하다.
>
> ⛔ **위 마지막 문단은 2026-08-05 D-TOFU-FLOOR가 뒤집었다.** 실측이 그 전제를 깼기 때문이다 —
> **실행 지점(예제·소비 루트)이 이미 전부 `1.12.0`이라 하한 분기가 소비자를 배제한 적이 없었다.**
> 배제 효과가 0이면 남는 것은 읽는 비용뿐이고, 그 비용은 실제로 발생했다(02 §2 근거 2).
> ⚠️ *"근거 없는 상향은 소비자만 배제한다"* 는 원칙 자체는 살아 있다 — **1.13 이상**에 적용된다.
>
> ⛔ PoC 문서의 `>= 1.14.0`은 **Terraform 버전**이었다. OpenTofu에는 존재하지 않는 버전이라
> 그대로 두면 **어떤 OpenTofu로도 `init`이 되지 않는다** — 승계 시 반드시 걷어내야 하는 종류의 값이다.

`02 §2` 하한 대장 등재는 **릴리스(Task 20.8) 시점**에 한다. 기준선과 같은 값이지만, "확인한 결과
기준선이었다"와 "확인하지 않았다"는 다르므로 근거(`교차변수 validation`)와 함께 명시적으로 적는다.

> ⛔ **그 "하한 대장"은 2026-08-05 D-TOFU-FLOOR로 폐지됐다**(02 §2). 위 문단은 당시 절차 기록이다.
> 지금은 등재할 대장이 없다 — 전 모듈이 같은 값이므로 **모듈별 근거를 적을 자리 자체가 사라졌다.**

---

## 4. 구현 계획

> 순서는 **설계 → 검토/승인 → 구현 → 검증**(CLAUDE.md). 이 문서 §1~§3의 승인이 착수 조건이다.
>
> ⚠️ **커밋 단위 제약**: tflint `terraform_unused_declarations`가 **선언만 하고 쓰지 않는 변수를
> exit 2로 잡는다.** 따라서 "`variables.tf`만 있고 소비하는 `main.tf`가 없는 상태"는 **커밋할 수 없다.**
> 아래 태스크마다 Commit 줄을 두지만 **실제 커밋 경계는 "변수가 전부 소비되는 시점"**이다 —
> VPC에서 10.1+10.2+10.3을 한 커밋(`65d2283`)으로 묶은 것이 이 제약 때문이었다.
> `--no-verify`로 우회하지 않는다.
>
> 검증 게이트(매 커밋): `tofu fmt -recursive -check` → `tofu validate` → `tflint --recursive`
> → `trivy config .` → `tofu test`. 로컬은 `.githooks`가, 원격은 `verify.yml` 게이트 6개가 강제한다.

### Task 20.1: ⚠️ upstream 실물 확인 (리스크 게이트 — 코드 작성 전)

**추정 금지**(CLAUDE.md 검증 절). 확인 결과를 `main.tf` 상단 주석에 기록한다.

> **✅ (a)(b)(c)(e) 완료 (2026-08-03)** — GitHub 태그 소스 직독(`v21.24.1`·`v2.8.2`) + provider 문서.
> **✅ (d) 완료 (2026-08-03)** — AWS 계정 실측(`describe-addon-versions`·`describe-addon-configuration`).

**✅ (a) `terraform-aws-modules/eks` v21.24.1 루트 I/O** — 변수 104개 중 facade가 쓰는 것 전부 실재 확인:
`create` · `name` · `kubernetes_version` · `vpc_id` · `subnet_ids` · `addons` · `eks_managed_node_groups` ·
`endpoint_private_access` · `endpoint_public_access` · `endpoint_public_access_cidrs` · `access_entries` ·
`enable_cluster_creator_admin_permissions` · `enabled_log_types` · `node_security_group_tags` ·
`deletion_protection` · `tags`.
- ✅ **`enable_pod_identity`는 존재하지 않는다** → §3.1에서 facade 변수를 삭제한 근거가 실물로 확인됐다.
- ⚠️ 출력 fallback이 일관되지 않다: 대부분 `try(…, null)`인데 **`cluster_name`·`cluster_id`만 `""`** (§3.2 함정).

**✅ (b) `//modules/karpenter` 실제 출력명** — 설계의 예상값과 **전부 일치**:
`iam_role_arn` · `node_iam_role_arn` · `node_iam_role_name` · `instance_profile_name` · `queue_name`
(그 외 `iam_role_name`·`queue_arn`·`queue_url`·`instance_profile_arn`·`node_access_entry_arn`·
`namespace`·`service_account` 등 17개).
- ✅ `enable_inline_policy` 존재 → 관리형 정책 6,144자 한도 회피 hotfix 승계 가능.
- ✅ `iam_role_name`·`node_iam_role_name`·`queue_name` + `*_use_name_prefix` override 존재
  → **§2.6 IAM 네이밍 이원화의 "가역 전환" 근거가 실물로 성립**한다(열린 항목 5.1-6).
- ✅ `create`·`create_pod_identity_association` 존재.

**✅ (c) `eks-pod-identity` v2.8.2** — `create` · `name` · `use_name_prefix` ·
`attach_aws_lb_controller_policy` · `attach_external_dns_policy` · `external_dns_hosted_zone_arns` ·
`associations` · `association_defaults` 전부 실재. PoC 핀 2.8.1 → **2.8.2로 올린다**(패치).

**✅ (e) D-EKS-PROTECT 구현 경로 — 확정: upstream `deletion_protection` 통과**
- `aws_eks_cluster`에 **네이티브 `deletion_protection` 인자**가 있다(provider 문서:
  *"the cluster cannot be deleted unless deletion protection is first disabled"*, 기본 `false`).
  upstream `main.tf`가 `deletion_protection = var.deletion_protection`으로 그대로 노출한다.
- → 후보 ①②③ 중 **②로 확정**. `lifecycle`을 붙일 수 없다는 제약이 **무의미해졌다** — 애초에 필요 없다.
- → **§3.3 하한이 `>= 1.12.0` → `>= 1.9.0`으로 내려갔다.**
- 🔑 부수 확인: **upstream이 자체 data source까지 `local.create`로 게이트**한다
  (`data.aws_eks_addon_version`은 `for_each` 조건에 포함) → `01 §4`의 kill switch data source 요건을
  **upstream이 이미 충족**하므로, D-EKS-ENABLED를 `count`가 아닌 `create` 위임으로 구현한다(§3.0).

**✅ (d) addon 스키마·가용성 (2026-08-03 실측 완료)** — 계정 `asset` · `describe-addon-versions`
/ `describe-addon-configuration`. 이 실측이 **D-ADDON-VERSION-PIN-1 개정의 근거**가 됐다.

- **가용성 ✅** — baseline 6종 + community tier 5종 **11종 전부** ap-northeast-2 · us-east-1 ·
  eu-west-1 × k8s 1.33/1.34/1.35/1.36 카탈로그에 존재. `owner`는 aws 5종(`vpc-cni`·`coredns`·
  `kube-proxy`·`eks-pod-identity-agent`·`aws-ebs-csi-driver`) / community 6종.
  ⚠️ `metrics-server`의 `owner`가 **community**다 — 우리 분류의 "baseline vs community tier"는
  **모듈 소유 vs 소비자 opt-in**을 가르는 축이고 AWS `owner` 필드와 무관하다. 맞추려 하지 말 것.
- **vpc-cni 구성 스키마 ✅** — 핀 후보(`v1.22.4-eksbuild.3`)의 `configurationSchema`를 `$ref`/
  `definitions` 해석해 대조. `env.AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG` · `env.ENI_CONFIG_LABEL_DEF` ·
  `env.ENABLE_PREFIX_DELEGATION` · `eniConfig.{create,region,subnets}` **6개 전부 실재**.
  - ⭐ `EniConfig.subnets.additionalProperties`에서 **`securityGroups`가 optional**임을 확인 —
    §2.5 정정(“ENIConfig에서 `securityGroups` 생략 시 primary ENI SG 상속”)의 **스키마 근거**다.
    Task 20.7에서는 추론이었고 여기서 실물로 확증됐다.
  - ⚠️ `subnets`에 **`minProperties: 1`** — `enable_custom_networking`인데 `pod_subnet_ids`가
    비면 무효 구성이 된다. `variables.tf`의 기존 교차변수 validation이 이미 막고 있다(재확인).
- **⛔ 버전 문자열 — 핀 소싱은 폐기됐다.** 실측이 오히려 *"모듈이 값을 들면 안 된다"* 를 증명했다:
  | 축 | 실측 |
  |---|---|
  | k8s | 1.35 기준 값을 1.34/1.33에 쓰면 `coredns`·`kube-proxy`·`metrics-server` **버전 없음**. 11종 중 3종만 k8s 의존 |
  | 리전 | `cert-manager`가 an2 `v1.21.0-eksbuild.3` / us-east-1·eu-west-1 `eksbuild.2` |
  → **D-ADDON-VERSION-PIN-1**(§2.6-6): 값의 소유자를 소비 루트로 옮긴다. 모듈은 `most_recent = false`만 소유.
- ✅ **Task 20.8의 (d) 차단이 해소됐다** — 모듈이 핀을 갖지 않는 것이 이제 위반이 아니라 **결정**이다.
  ⚠️ upstream 해석 경로도 실측했다(`main.tf:759-778`): `data.aws_eks_addon_version`에
  `kubernetes_version`이 그대로 흘러가므로, 값 미지정 시 **k8s·리전 정합이 자동으로 성립**한다.

### Task 20.2~20.4: 모듈 본체 (`modules/eks-cluster/`)

**Files:** `versions.tf` · `variables.tf` · `main.tf` · `addons.tf` · `iam.tf`

- **20.2 `versions.tf` + `variables.tf`** — §3.1 전체. `required_version`은 Task 20.1(e) 결과를 따른다.
  `aws >= 6.0`. core 4종 `enabled = false` 차단 validation + D-EKS-PROTECT 교차변수 validation.
- **20.3 `main.tf`** — facade 번역 + 네이밍 합성 + **kill switch 게이트**.
  ```hcl
  locals {
    enabled      = var.cluster_enabled
    name_mid     = "${var.naming.workload}-${var.naming.env}-${var.naming.region_code}"
    cluster_name = "eks-${local.name_mid}-${var.purpose}-${var.serial}"
  }

  module "eks" {
    source  = "terraform-aws-modules/eks/aws"
    version = "21.24.1"                    # 정확 핀 — Task 20.1(a) 확인

    create = local.enabled                 # D-EKS-ENABLED — upstream이 data source까지 게이트한다

    name               = local.cluster_name   # facade: upstream `name`으로 번역
    kubernetes_version = var.kubernetes_version
    vpc_id             = var.vpc_id
    subnet_ids         = var.subnet_ids
    enabled_log_types  = var.enabled_log_types

    deletion_protection = var.deletion_protection   # D-EKS-PROTECT — AWS 네이티브 보호

    endpoint_public_access       = var.endpoint_public_access
    endpoint_private_access      = var.endpoint_private_access
    endpoint_public_access_cidrs = var.public_access_cidrs

    enable_cluster_creator_admin_permissions = true
    access_entries                           = var.access_entries

    # Karpenter discovery 태그는 subnet(소비자 소관)과 node SG(여기) **둘 다** 필요하다.
    # SG 쪽 누락이 PoC에서 실제 사고였다(구 열린 항목 4) — 계약으로 고정한다.
    node_security_group_tags = var.enable_karpenter ? {
      "karpenter.sh/discovery" = local.cluster_name
    } : {}

    addons                  = local.addons_final        # §2.6 — addons.tf
    eks_managed_node_groups = local.managed_node_groups # ami_release_version 파생 포함
    tags                    = var.tags
  }

  module "karpenter" {
    source  = "terraform-aws-modules/eks/aws//modules/karpenter"  # ⚠ registry 주소에 /aws 필수
    version = "21.24.1"

    create               = local.enabled && var.enable_karpenter
    cluster_name         = module.eks.cluster_name   # 인덱스 없음 — create 위임의 이득
    enable_inline_policy = true      # 관리형 정책 6,144자 한도 초과 실측
    tags                 = var.tags
  }
  ```
  ⚠️ **`create = false`여도 모듈 블록은 평가된다** — 입력 표현식이 유효해야 한다. 이는 `count = 0`도
  마찬가지이므로 손해가 아니지만, `module.eks.cluster_name`을 참조하는 쪽(위 karpenter)이
  **빈 문자열을 받는다**는 점은 다르다(§3.2 함정). 참조가 이름을 *쓰기* 전에 꺼지는지 확인한다.
  ⚠️ **`ami_release_version` 함정**: upstream `eks-managed-node-group`은 `use_latest_ami_release_version`
  **기본 true**라 `ami_release_version`만 주면 **무시된다**. facade가
  `use_latest_ami_release_version = (ami_release_version == null)`로 파생해야 핀이 실효한다(§2.6).
- **20.4 `addons.tf` + `iam.tf`** — §2.6 C′(baseline locals → `merge()` → 모듈 소유 필드 **재주입** →
  `enabled` 필터) · EBS CSI role(`iamr-<mid>-ebs-csi`) · §2.6a eks-pod-identity 위임 2종(opt-in).
  ⚠️ `merge()`는 shallow다 — vpc-cni `configuration_values`와 ebs-csi `pod_identity_association`은
  merge **뒤에** 다시 덮어써야 소비자의 버전 override가 모듈 소유 필드를 지우지 않는다.
- Commit: `feat(eks-cluster): facade + addon baseline + Karpenter/컨트롤러 IAM`
  (위 커밋 단위 제약 때문에 20.2~20.4는 **한 커밋**이 될 가능성이 높다)

### Task 20.5: `outputs.tf`

§3.2 전체. `try(module.karpenter[0].<확정명>, null)` 패턴으로 kill switch·opt-out 시 `null`.
`karpenter_discovery_tag = { "karpenter.sh/discovery" = local.cluster_name }`.
- Commit: `feat(eks-cluster): 출력 계약`

### Task 20.6: 예제 (~~2종~~ → **1종**, 2026-08-03)

`01 §4` "모듈은 예제 없이 릴리스하지 않는다" — 요건은 **예제의 존재**이지 개수가 아니다.
- **`examples/eks-cluster-enterprise/`** — **고객사 착수 템플릿**(검증 자산이 아니다).
  custom networking + Karpenter + 컨트롤러 IAM opt-in + 로깅 활성.
- ⛔ **`examples/eks-cluster/`(최소 형상)는 2026-08-03에 폐기됐다** — VPC와 같은 판단이다
  (`design/10 §1.5(a)` 상자). 모듈당 예제 2벌의 유지 비용이 minimal이 주는 값보다 컸고,
  계약 판정은 애초에 Task 20.7의 `tofu test`가 내리고 있었다. **다시 늘리지 않는다.**
- ⚠️ 예제는 **VPC 모듈과의 결선**을 보여야 한다 — 특히 `local.cluster_name`을 한 번 정의해
  VPC의 `eks_cluster_name`과 EKS 모듈에 **같이 넘기는** 패턴(§2.5).
- ⚠️ 예제는 self-contained라 VPC를 같은 루트에서 만든다. **소비 프로젝트는 별도 루트**이며
  그 차이를 README **"소비 프로젝트와 다른 점" 비교표**가 담당한다(§2.5-1). 이 표는 필수다 —
  코드로 보일 수 없는 것을 문서가 보상하는 지점이다.
- `aws ~> 6.0`, `.terraform.lock.hcl` 커밋(⚠️ `registry.opentofu.org` 확인).
- Commit: `feat(examples): eks-cluster 착수 템플릿`

### Task 20.7: `tests/plan.tftest.hcl`

`mock_provider "aws" {}`. **tests 없는 모듈은 CI가 실패시킨다**(`02 §4`).

| AC | 검증 |
|----|------|
| AC1 | 네이밍 — `cluster_name == "eks-<workload>-<env>-<rc>-<purpose>-<serial>"` |
| AC2 | **`Name` 태그 assertion**(CLAUDE.md 필수) — NG·IAM role 등 태그 가능 리소스 |
| AC3 | kill switch — `cluster_enabled = false` → 리소스 0개 **+ 출력이 `null`**(빈 문자열이 아니라 — §3.2 함정) |
| AC4 | D-EKS-PROTECT — `deletion_protection = true` + `cluster_enabled = false` → **plan 거부** |
| AC4b | `deletion_protection = true` → `aws_eks_cluster`에 그 값이 **실제로 전달**되는지(통과 확인) |
| AC5 | addon 빈 map → baseline 6종 |
| AC6 | core 4종 `enabled = false` → validation 실패 |
| AC7 | shallow-merge 회귀 — ebs-csi `addon_version` override에도 `pod_identity_association` 유지 |
| AC8 | ebs-csi opt-out → role 0개 / metrics-server opt-out → 5종 |
| AC9 | custom networking on → vpc-cni `configuration_values`에 `CUSTOM_NETWORK_CFG` 포함 |
| AC10 | Karpenter on → node SG에 `karpenter.sh/discovery` 태그 |
| AC11 | §2.6a 토글 기본 off / opt-in on + role 이름이 카탈로그 준수 |

> **✅ 구현 완료(2026-08-03) — 현행 17 run 전부 pass.** 최초 16 run이었고, D-NODE-ARCH가
> `invalid_ami_type_is_rejected`를 더해 17이 됐다(2026-08-04). 실제 구성은 위 표와 다소 다르다:
> `effective_addon_names` 출력을 신설해 addon merge를 관측 가능하게 만들었고(facade는 계산 결과를
> 하위 모듈 입력으로 넘겨 `tofu test`가 볼 수 없다), NG 형상 검증은 아래 제약으로 빠졌다.
>
> **🔑 테스트가 실제 결함을 잡았다** — upstream이 `iam_role_use_name_prefix` 기본 true로
> `<NG이름>-eks-node-group-`(40자)을 name_prefix로 만드는데 **한도가 38자**라 plan이 죽었다.
> facade가 `iam_role_name`을 카탈로그 이름으로 직접 지정해 해결했다. **`validate`로는 안 잡힌다.**
>
> ⚠️ **`override_module`은 이 모듈에 쓸 수 없다**(실측): override는 모듈 **실행**만 대체하고
> **입력 표현식은 그대로 평가**한다. `module.eks`를 덮으면 그 안의 `eks_managed_node_group`이
> 사라진 부모 리소스(`time_sleep.this[0]`)를 참조하다 죽는다. 중첩 모듈을 함께 덮어도 같다.
> → mock_provider로 가되 **기본 시나리오에서 NG를 비운다**(NG가 있으면 중첩 모듈이 깨어나 upstream
> 내부 computed 속성을 전부 모킹해야 한다). **잃은 것: NG 경로의 plan-time 회귀 가드** —
> 위 name_prefix 결함의 재발을 막는 테스트는 없다. NG 형상은 라이브 apply가 판정한다(Task 20.8 표).

⚠️ **AC4는 `tofu test`에서만 잡힌다** — 교차변수 validation은 `plan` 시점 평가라 `validate`나
`examples`의 검증으로는 검출되지 않는다(VPC 실측).
⚠️ 네이밍 assertion은 **특정 리소스 주소를 직접 타겟**한다. 전체 IAM 순회는 upstream 위임 role
2종(`KarpenterController-*` 등)을 false-fail로 잡는다(§2.6 IAM 네이밍 이원화).
- Commit: `test(eks-cluster): 계약 검증 <N> AC`

### Task 20.8: 릴리스 `eks-cluster-v1.0.0`

- 게이트 6개 통과 실측을 이 문서 **§4.1 릴리스 기록**에 남긴다(VPC `design/10` §3의 형식).
- `02 §2` 하한 대장에 `eks-cluster` 행 추가.
- ⚠️ **apply 미검증 항목을 표로 명시한다.** v1.0.0의 증거는 `plan` 수준이며, 실계정 판정은
  소비 repo(`iac-reference-infra`)의 첫 apply에서 이뤄진다. VPC에서 이 표가 6항목을 추적했고
  전부 판정되기까지 별도 세션이 필요했다 — **"plan 통과 = 검증됨"으로 쓰지 않는다.**
- Commit: `release(eks-cluster): v1.0.0` + 태그 `eks-cluster-v1.0.0`

### 4.1 릴리스 기록 — `eks-cluster-v1.0.0` (2026-08-04) → 현 **`eks-cluster-v0.1.0`**

`02 §4` 게이트 실측 결과. **OpenTofu 1.12.5 · aws provider 6.57.1** 기준이다
(모듈 lock과 예제 lock이 같은 버전이다 — `design/10 §3`이 정렬한 이유와 같다).

| # | 게이트 항목 | 결과 |
|---|------------|------|
| 1 | `tofu fmt -recursive -check` | exit 0 |
| 2 | `modules/eks-cluster`: `validate` + `test` | Success · **17 passed, 0 failed** |
| 3 | `examples/*`: `validate` | `eks-cluster-enterprise`·`vpc-enterprise` 양쪽 Success |
| 4 | `.terraform.lock.hcl` 커밋 + registry | 전부 `registry.opentofu.org/hashicorp/aws` |
| 5 | `Name` 태그 §1.2 포맷 + 카탈로그 약어 | `naming_and_name_tag` run이 클러스터·NG·IAM role 검증 |
| 6 | 커뮤니티 모듈 정확 핀 | `eks` **21.24.1** · `//modules/karpenter` **21.24.1** · `eks-pod-identity` **2.8.2** |
| 7 | `<component>_enabled` kill switch | `cluster_enabled`(D-EKS-ENABLED — upstream `create` 위임) |
| 8 | `tflint --recursive` · `trivy config` | 0건 · 0건 |

> ⚠️ **`trivy`는 게이트 명령 그대로 돌려야 의미가 있다.** `--skip-dirs '**/.terraform'
> --tf-exclude-downloaded-modules`를 빼면 `.terraform/modules/` 안의 **upstream 소스**가 스캔되어
> `AVD-AWS-0104`(node SG egress `0.0.0.0/0`)가 잡히고 exit 1이 된다. 우리가 고칠 수 없는 코드이며,
> 그래서 훅과 CI가 둘 다 같은 두 플래그를 단다(`.githooks/pre-commit` · `verify.yml` 게이트 3/6).
> 이 플래그를 뺀 측정은 게이트 실패가 아니라 **잘못 잰 것**이다.

> ⚠️ **이 태그는 한 번 옮겨졌다** — 컷 직후 D-NODE-ARCH(`ami_type`)를 흡수하며 `74bbf51`로 이동했다.
> 당시 소비 repo는 `plan`만 돌던 상태라 **소비자가 0이었고**, 그것이 CLAUDE.md가 인정하는 유일한
> 예외였다. **2026-08-04 apply로 그 예외는 닫혔다** — 이후 변경은 마이너를 컷한다.

#### v1.0.0의 apply 판정 (2026-08-04, `iac-reference-infra` `live/dev/eks`)

VPC와 달리 이 표는 **릴리스와 같은 날 채워졌다.** 소비 repo가 `deploy-eks.yml` dispatch 2회로
apply했기 때문이다. 판정 형상은 다음과 같다 — **표의 유효 범위가 곧 이 형상의 범위**다.

| 축 | 값 |
|---|---|
| custom networking | on (`pod-dup` 서브넷, prefix delegation) |
| 노드그룹 | `t4g.medium` × 2 = **graviton**, `ami_type = AL2023_ARM_64_STANDARD`, `ami_release_version` 핀 |
| addon | 8종 = baseline 6 + community tier 2(`cert-manager`·`external-dns`), 버전 전부 소비 루트가 핀 |
| 보호·노출 | `deletion_protection = true` · public 엔드포인트(단일 CIDR) · 로깅 3종 |
| IAM | Karpenter on · ALBC IAM on · **external-dns IAM off**(아래 ❌) |

| 항목 | 왜 `plan`으로 안 잡히나 | 판정 |
|------|---------------------|------|
| 클러스터·NG 네이밍 합성 | 이름 충돌·길이 초과는 AWS API가 생성 시점에 거부한다 | ✅ `eks-ref-dev-an2-main-01` · `eksn-ref-dev-an2-system` ACTIVE |
| NG IAM role name_prefix 38자 한도 | `validate`로는 안 잡히고, facade가 `iam_role_name`을 직접 지정해 푼 경로다 | ✅ NG role 생성됨 |
| **`ami_type` × `instance_types` 아키텍처 짝** | plan은 통과한다 — AWS도 **노드그룹 생성 시점에야** 거부한다(D-NODE-ARCH) | ✅ arm 노드 2대 running |
| `ami_release_version` 핀 실효 | `use_latest_ami_release_version` 파생이 실제로 그 AMI를 쓰는지는 apply가 판정한다 | ✅ 핀한 `1.35.6-20260728`로 기동 |
| Karpenter inline 정책 6,144자 한도 | 관리형 정책이면 `LimitExceeded`가 apply에서 난다(PoC 실측) | ✅ `enable_inline_policy = true`로 통과 |
| addon 버전 `f(k8s, region)` 해석 | 존재하지 않는 조합은 apply에서 죽는다(D-ADDON-VERSION-PIN-1의 근거) | ✅ 8종 전부 등록 |
| §2.6 재주입(merge 뒤 모듈 소유 필드) | 소비자가 8종 전부 `addon_version`을 override한 형상이다 | ✅ vpc-cni 구성·ebs-csi association 생존 |
| **`deletion_protection` 실제 차단** | AWS API 차원 보호는 리소스가 존재해야 확인된다 | ✅ **콘솔에서도 삭제 불가** |
| **external-dns IAM (zone ARN 미지정)** | upstream이 `Resource="*"` 정책을 만들고 AWS가 **400**으로 거부한다 | ❌ **실패 — 아래 상자** |
| kill switch(`cluster_enabled = false`) | — | ⏸ 미판정(라이브 teardown 미실행) |
| teardown 2단계 완주 | — | ⏸ 미판정(〃) |

> **❌ D-EXTDNS-ZONE — `enable_external_dns_iam = true` + `external_dns_hosted_zone_arns = []`는
> apply가 실패한다**(2026-08-04 실측, run `30877358485`).
>
> `route53:ChangeResourceRecordSets`는 **리소스 수준 권한을 요구**하는 액션이라 `Resource = "*"`
> 정책을 IAM이 받지 않는다(`400 MalformedPolicyDocument`). upstream `eks-pod-identity` v2.8.2는
> `external_dns_hosted_zone_arns`가 비면 정확히 그 정책을 만든다.
>
> ⛔ **§2.6a와 `variables.tf`의 서술이 실물과 다르다.** 양쪽 다 *"비워 두면 전체 zone(`*`)이
> **허용**된다 — prd에서는 반드시 좁힌다"* 라고 적었다. 실제로는 허용이 아니라 **거부**이고,
> 따라서 이것은 "prd 권고"가 아니라 **모든 환경의 apply 차단 조건**이다.
> → **§2.6a 정정은 이 개정에 포함**했다. `variables.tf`의 같은 서술과 **plan 시점에 막는
> 교차변수 validation**은 `.tf` 변경이라 §5.1-8 열린 항목에서 함께 처리한다
> (브랜치 → PR + 마이너 릴리스 판단이 필요하다 — CLAUDE.md 브랜치 규칙).
>
> 🔑 **이 결함은 `tofu test`로 잡을 수 없었다.** mock provider는 IAM 정책 문서를 AWS에 제출하지
> 않기 때문이다 — 정책의 **문법**이 아니라 **AWS의 수용 여부**가 쟁점인 항목은 apply만이 판정한다.
> 이 표를 릴리스마다 유지하는 이유가 정확히 이것이다.
>
> ✅ **해소: `eks-cluster-v0.2.0`**(2026-08-05, §4.2). 위 서술은 **v0.1.0 시점의 사실 기록**이라
> 그대로 둔다. ⭐ 다만 결론 하나는 뒤집혔다 — *"`tofu test`로 잡을 수 없다"* 는 **AWS의 수용 여부를
> 물었을 때**의 이야기이고, **조합 자체를 계약에서 배제하면 `tofu test`가 잡는다.**
> 판정 대상을 "이 정책을 AWS가 받는가"에서 "이 조합이 우리 계약에 있는가"로 바꾼 것이 해법이었다.

> **🔑 실측 — 첫 apply가 실패해도 클러스터는 이미 생성된다.**
> 첫 dispatch는 external-dns IAM에서 죽었지만, 그 **전에** 클러스터·노드그룹·addon이 state에
> 기록됐다. 두 번째 dispatch는 `0 add / 0 change / 2 destroy`(external-dns IAM 2개 파기)였다.
> `tofu apply`는 원자적이지 않다 — 부분 적용 상태가 정상적으로 남는다.
> ⚠️ 그래서 **apply 실패를 "아무 일도 없었다"로 읽으면 안 된다.** 비용은 그 시점부터 발생한다.

> **증거와 run ID는 여기 적지 않는다.** 인스턴스의 배포 사실은 소비 repo
> `docs/deployment-facts.md`가 소유한다([`design/50` D26](50-reference-consumer-repo.md)).
> 이 표는 **모듈 계약이 어디까지 증명됐는가**만 기록한다.

### 4.2 릴리스 기록 — `eks-cluster-v0.2.0` (2026-08-05, D-EXTDNS-ZONE)

§5.1-8을 닫는 릴리스다. **변수 추가 없음** — `external_dns_hosted_zone_arns`에 교차변수
`validation`을 붙여 2026-08-04 apply를 죽인 조합을 plan에서 배제했다.

```hcl
condition = !(var.enable_external_dns_iam && var.cluster_enabled) || length(var.external_dns_hosted_zone_arns) > 0
```

> ⭐ **`&& var.cluster_enabled` 게이트는 설계 §5.1-8의 조건식에 없던 것이다.** 구현 중
> `pod_subnet_ids`(같은 "토글 × 리스트" 구조)의 선례를 확인하며 추가했다 — 게이트가 없으면
> **파기 경로의 plan이 거부**되어 D-EKS-ENABLED가 경고한 *"끌 수는 있으나 끈 상태를 유지할 수
> 없는 반쪽 kill switch"* 가 된다. `iam.tf`의 `create = local.enabled && var.enable_external_dns_iam`
> 때문에 kill switch가 꺼진 상태에서는 문제의 IAM 정책이 **애초에 만들어지지 않으므로** 막을 이유도 없다.
> 🔑 **설계가 제시한 조건식을 그대로 옮기지 않고 같은 형태의 선례를 먼저 찾은 것이 이 차이를 만들었다.**

| # | 게이트 항목 | 결과 |
|---|------------|------|
| 1 | `tofu fmt -recursive -check` | exit 0 |
| 2 | `modules/eks-cluster`: `validate` + `test` | Success · **20 passed, 0 failed**(17 → +3) |
| 3 | `examples/*`: `validate` | 양쪽 Success |
| 4 | `tflint --recursive` · `trivy config` | exit 0 · exit 0 |

**추가된 test 3종** — 양성 1 + 음성 2다.

| run | 검증 |
|-----|------|
| `external_dns_iam_requires_hosted_zone_arns` | 문제의 조합을 plan이 거부한다(`expect_failures`) |
| `external_dns_iam_allowed_with_hosted_zone_arns` | 거부가 과하게 넓지 않다 |
| `external_dns_zone_guard_does_not_block_kill_switch` | **파기 경로를 막지 않는다**(위 게이트의 회귀 가드) |

> 🔑 **기존 test가 apply 불가능한 형상을 통과시키고 있었다.** `controller_iam_opt_in_creates_roles`는
> `enable_external_dns_iam = true`만 켜고 zone ARN은 기본값 `[]`로 두었다 — 정확히 apply를 죽인
> 조합이다. 가드를 넣자 **이 기존 test가 먼저 깨졌고**, 실효 형상으로 고쳤다.
> §4.1이 *"이 결함은 `tofu test`로 잡을 수 없었다"* 고 적은 항목이, 가드와 함께
> **test가 잡는 항목으로 바뀐 것**을 보여주는 증거다.

**예제도 함께 바뀌었다** — `examples/eks-cluster-enterprise`가 Route53 **private hosted zone**을
직접 만들고(`hz-<workload>-<env>-<region>-internal`, 약어 `hz`는 카탈로그 기존 등재) 그 ARN을 넘긴다.

- ⛔ **더미 ARN은 기각했다.** 고객사가 복사해 apply하면 **존재하지 않는 zone을 가리키는 IAM role이
  조용히 만들어진다** — apply가 성공하기 때문에 아무도 지적하지 않은 채 굳는다(D13과 같은 실패 구조).
- private zone인 이유: 예제 VPC 안에서만 해석되면 되므로 도메인 소유·위임이 불필요하다.
  public zone은 소유 검증 없이 만들어지지만 실제 위임이 없어 허공에 뜨고 과금만 남는다.
- `force_destroy = true`는 **예제에서만**이다. external-dns가 IaC 밖에서 쓴 레코드가 남으면
  zone 삭제가 실패해 teardown이 막힌다. 실제 프로젝트에서는 켜지 않는다(README에 명시).
- **소비 프로젝트의 기본값은 `enable_external_dns_iam = false`**(+ addon 미탑재)다. zone은 워크로드
  수명주기보다 오래 살므로 클러스터 루트가 소유하지 않는다 — 되켤 때는 `data.aws_route53_zone`으로
  **조회만** 한다(`03 §3.1` 원칙). 안내는 예제 README의 **"external-dns"** 절이 소유한다.

> ✅ **실측 — 예제의 unknown ARN은 가드를 통과한다.** `[aws_route53_zone.internal.arn]`은 plan
> 시점에 **요소 값이 unknown**이라 `length(...) > 0`이 unknown으로 전파될 위험이 있었다.
> 격리 재현(mock provider + 하위 모듈)으로 **리스트 리터럴의 길이는 확정적(1)** 임을 확인했다.
> ⚠️ 이 확인이 없었다면 예제는 **CI `validate`를 통과하고 고객사 plan에서 죽었을 것이다** —
> `validate`는 교차변수 validation을 평가하지 않기 때문이다(이 문서가 반복해 경고하는 지점).

### 4.3 릴리스 기록 — `eks-cluster-v0.3.0` (2026-08-05, D-WORKBENCH-SEAM + D-TOFU-FLOOR)

§5.1-9를 닫는 릴리스다. **`bastion-v0.1.0`(→ 2026-08-06 `workbench-v0.1.0`으로 대체, D-WORKBENCH-RENAME)과
같은 PR([#12](https://github.com/skax-ca/iac-module-library/pull/12),
머지 `417154b`)에서 나왔지만 태그는 따로 달았다** — 컴포넌트별 cadence 분리
([`../architecture/05 §4`](../architecture/05-versioning-policy.md))를 지키기 위해서다.
설계 SSOT는 [`40 §5`](40-workbench.md)이고, 이 절은 **eks-cluster 계약이 어떻게 늘었는가**만 기록한다.

**계약 변경 3건**

| 구분 | 내용 |
|------|------|
| ➕ 변수 | `cluster_security_group_additional_rules`(§3.1) — upstream `security_group_additional_rules` 통과 |
| 🔧 정정 | `cluster_security_group_id` **출력 설명**이 값과 다른 SG를 가리키고 있었다(§3.2) |
| ⬆️ 하한 | `required_version` `>= 1.9.0` → **`>= 1.12.0`**(D-TOFU-FLOOR, §3.3). 커밋 `fae555c` |

> ⭐ **소비자 영향은 하한 상향에도 없다** — 소비 루트가 이미 `>= 1.12.0`이었다.
> `0.y.z` 구간이라 판정 자체가 불필요하지만([`../architecture/05 §1`](../architecture/05-versioning-policy.md)),
> **실제로 무엇이 깨지는가**는 릴리스마다 확인한다.

**⛔ 이 릴리스는 test를 늘리지 않았다 — 그것이 의도다(20 passed 유지).**

facade가 하위 모듈에 넘긴 값은 plan 테스트로 볼 수 없다. `mock_resource`로 값을 강제해 assert하면
**테스트가 자기 모킹 설정을 검증**하게 되므로 만들지 않았고, 대신 **한계를 `tests/plan.tftest.hcl`
헤더에 적었다**(같은 판단을 `workbench` 하드닝 2종에서도 했다 — [`40 §5.1`](40-workbench.md)).
회귀 방지는 **예제가 실제로 이 변수를 소비하고 CI 게이트 ⑤(examples `validate`)가 도는 것**이다.

| # | 게이트 항목 | 결과 |
|---|------------|------|
| 1 | `tofu fmt -recursive -check` | exit 0 |
| 2 | `modules/eks-cluster`: `validate` + `test` | Success · **20 passed, 0 failed** |
| 3 | `modules/workbench`: `validate` + `test` | Success · **10 passed, 0 failed** |
| 4 | `modules/vpc`: `test`(회귀) | **13 passed, 0 failed** |
| 5 | `examples/*`: `validate` | 전부 Success |
| 6 | `tflint --recursive` · `trivy config` | exit 0 · exit 0 |

✅ CI run [`30981984588`](https://github.com/skax-ca/iac-module-library/actions/runs/30981984588) **6/6 pass**
— **로그 본문까지 확인**했다(lock 5개 전부 `registry.opentofu.org`).

**예제가 이 릴리스의 실질적 검증 지점이다** — `examples/eks-cluster-enterprise`는
`endpoint_public_access = false`이면서 **조작 지점이 없는 상태**였다. 이 릴리스가 그 미해결을 닫는다.

> ⭐ **모듈 간 순환을 발견하고 결정적 네이밍으로 끊었다**([`40 §5.1-1`](40-workbench.md) 신설).
> 소유를 3층으로 가르면 참조가 양방향이 된다 — workbench는 클러스터 ARN을, eks는 workbench role ARN을
> (`access_entries`) 원한다. 해법은 [`03 §3.1`](../architecture/03-dependencies.md) **1순위**:
> 루트가 `local.cluster_arn`을 직접 합성해 **단방향**으로 만든다.
> 🔑 **`03`의 조회 우선순위는 "느슨한 결합"만이 아니라 순환 해소 장치이기도 하다** —
> SG rule을 별도 리소스로 분리해 순환을 푸는 `03 §2.2`와 같은 역할을 **값 층위**에서 한다.
> ⚠️ 예제 README가 *"`local.cluster_arn`을 `module.eks.cluster_arn`으로 바꾸면 plan이 순환으로 죽는다"* 를
> 명시한다 — 이 예제에서 가장 만지기 쉬운 함정이다.

> 🔒 **`v0.2.0` 태그는 옮기지 않았다** — 소비 repo가 같은 날 핀을 올려 **apply까지 마쳤다.**
> CLAUDE.md가 인정하는 유일한 예외(*"소비자가 0일 때"*)는 그 시점에 이미 닫혔다.

### 4.4 릴리스 기록 — `eks-cluster-v0.4.0` (2026-08-06, **D-EKS-CIDR-NULL**)

**소비 repo의 영구 가짜 diff를 닫는 릴리스.** 계약(변수·출력)은 **바뀌지 않는다** — 바뀌는 것은
`public_access_cidrs`를 upstream에 **어떻게 전달하는가** 하나다. 소비자 무영향이라 **마이너**다.

#### 문제 — apply해도 사라지지 않는 diff

`iac-reference-infra`가 private-only로 전환한 뒤(2026-08-06) 매 plan이 이렇게 났다:

```
# module.eks.module.eks.aws_eks_cluster.this[0] will be updated in-place
  ~ vpc_config {
      ~ public_access_cidrs = [ - "<운영자 IP>/32" ]
    }
Plan: 0 to add, 1 to change, 0 to destroy.   ← apply해도 다음 plan에 또 난다
```

소비 루트는 `public_access_cidrs` 인자를 **지웠는데도** 그렇다. 이 모듈의 기본값이 `[]`이고
그것을 그대로 upstream에 넘기기 때문이다.

#### 원인 — **빈 리스트는 "없음"이 아니라 "있음"이다**

provider 문서 원문(`aws_eks_cluster` `vpc_config.public_access_cidrs`):

> *"Terraform will only perform drift detection of its value **when present in a configuration**."*

⇒ **`null`이면 drift 감지를 하지 않고, `[]`는 "설정에 있음"으로 취급된다.**
한편 AWS는 **public이 꺼진 상태에서 `publicAccessCidrs` 변경을 반영하지 않는다**(실측: apply가
성공했는데 `describe-cluster`의 값이 그대로였다). ⇒ tofu는 계속 지우려 하고 AWS는 안 지운다 =
**영구 diff**.

🔑 **일반화**: *"Optional 인자에 빈 컬렉션을 넘기는 것과 넘기지 않는 것은 다르다."*
이 모듈이 다른 곳에서도 `default = []`를 upstream으로 흘리고 있다면 같은 함정이 있는지 본다.

#### 결정 — D-EKS-CIDR-NULL

**`endpoint_public_access = false`면 `endpoint_public_access_cidrs`를 `null`로 넘긴다.**

```hcl
endpoint_public_access_cidrs = var.endpoint_public_access ? var.public_access_cidrs : null
```

- public이 **꺼져 있으면** 그 값은 애초에 **의미가 없다**(§3.1 변수 설명이 이미 그렇게 적고 있다).
  의미 없는 값을 관리 대상으로 선언해 두는 것이 diff의 원인이었다.
- ⛔ **`length(...) > 0`을 조건에 넣지 않았다.** 그러면 *public이 켜졌는데 리스트가 빈* 경우까지
  `null`이 되어 **EKS가 `0.0.0.0/0`으로 여는 것을 tofu가 더는 감지하지 못한다.** 지금은 그 조합이
  drift로 드러나는데, 그 안전망을 diff 편의와 바꾸지 않는다.
- ⛔ `lifecycle { ignore_changes }`를 쓰지 않았다. 그것은 "값이 어긋나도 눈감는다"이고,
  여기 필요한 것은 **"public이 꺼졌으니 이 값을 애초에 관리하지 않는다"** 이다. 둘은 다르다.

| `endpoint_public_access` | `public_access_cidrs` | upstream에 가는 값 | drift 감지 |
|---|---|---|---|
| `true` | `["1.2.3.4/32"]` | 그대로 | ✅ (변경 없음) |
| `true` | `[]` | `[]` | ✅ **유지** — EKS의 `0.0.0.0/0` 전면 개방이 diff로 드러난다 |
| **`false`** | 무엇이든 | **`null`** | ⛔ **안 함** ← 이 릴리스가 바꾸는 칸 |

#### 계약·테스트

- 변수·출력 **불변**. 소비자는 **핀만 올리면 된다**.
- ⚠️ `tofu test`(plan 단계)로는 이 결정을 지킬 수 없다 — 검증 대상이 *"AWS가 값을 반영하지 않는다"*
  라는 **런타임 사실**이기 때문이다. §5.1의 *"미지정 자체가 계약"* 항목들과 같은 부류다.
  ⇒ 판정은 소비 repo의 **다음 plan이 `No changes`인지**다(§7.3-3에 기록).

> ### ⚠️ 함께 드러난 것 — OIDC `thumbprint_list` (이 릴리스 범위 밖)
>
> 같은 plan에 `aws_iam_openid_connect_provider.thumbprint_list`가
> `[...] -> (known after apply)`로 매번 뜬다. apply하면 값이 같아 **no-op**이 된다.
> **원인 계층이 다르다**(upstream/provider 동작이지 이 facade의 전달 방식이 아니다) —
> 이 릴리스에 끼워 넣지 않고 열린 항목으로 둔다.

## 5. 열린 항목

### 5.1 이 모듈 소관 — 구현·릴리스와 함께 판단한다

1. ~~**D-EKS-PROTECT의 구현 경로**~~ ✅ **해소(2026-08-03, Task 20.1(e))** — `aws_eks_cluster`에
   **네이티브 `deletion_protection` 인자**가 있어 후보 ②로 확정됐다. *"wrapper가 upstream 내부
   리소스에 `lifecycle`을 붙일 수 없다"*는 제약은 **풀린 게 아니라 무의미해졌다** — 붙일 필요가 없다.
   결과로 `required_version` 하한이 **`>= 1.12.0` → `>= 1.9.0`**으로 내려갔다(§3.3).
   🔑 교훈: **"VPC가 이렇게 했으니 EKS도"는 위험한 대칭**이다. VPC가 `prevent_destroy`를 쓴 것은
   VPC에 네이티브 보호가 **없어서**지 그 방식이 우월해서가 아니었다. 리소스마다 provider가 주는 것을
   먼저 확인하는 것이 순서다.
2. **managed NG ↔ Karpenter 역할 분담 상세** — 원칙: 시스템·컨트롤러(Karpenter 자신 포함, chart affinity
   `karpenter.sh/nodepool DoesNotExist`가 강제)는 managed NG, 앱·버스트는 Karpenter 노드.
   taint/label 배선은 NodePool 다양화와 함께 진행한다. **taint 도입 시 시스템 addon toleration이 선결**이다.
3. **Fargate 프로파일**(`eksf`) 필요 여부 — 계약 확장이므로 수요 발생 시 마이너.
4. **managed NG max-pods** — custom networking + prefix delegation 조합의 노드별 max-pods 계산
   (EKS 권장 상한 110/250)과 kubelet 설정 반영 여부. 기본값으로 시작, 밀도 문제 시 조정.
5. **EBS KMS 암호화 볼륨 권한** — 고객 관리형 KMS 키로 볼륨을 암호화하면 EBS CSI role에 KMS 권한
   (`GenerateDataKey` 등)이 추가로 필요하다. 현재는 AWS 관리형 정책만 부착 — KMS 도입 시점에 §2.6 개정.
6. **Karpenter role 카탈로그 네이밍 전환** — §2.6 IAM 네이밍 이원화의 재평가. upstream이
   `iam_role_name`·`node_iam_role_name`·`queue_name` override를 노출하므로 **변수 주입만으로 가역**이다.
   prd 확산 단계에서 판단한다.
7. **관측성 스택 중복** — kube-state-metrics·prometheus-node-exporter는 `kube-prometheus-stack`
   (GitOps helm)에 번들되는 경우가 많다. AMP 직결 vs self-managed 스택이 정해지면 community tier에서 뺀다.
8. ~~🔴 **D-EXTDNS-ZONE — 교차변수 validation**~~ ✅ **해소(2026-08-05, `eks-cluster-v0.2.0`)** —
   §4.2 릴리스 기록 참조. 2026-08-04 apply가 발견한 결함(§4.1 ❌ 상자)을 plan 가드로 닫았다.
   - ⛔ **upstream 수정을 기다리지 않았다.** upstream의 버그가 아니라 **AWS IAM의 제약**이고
     (`route53:ChangeResourceRecordSets`는 리소스 수준 권한), upstream은 "zone을 안 주면 `*`"라는
     합리적 기본값을 낸 것뿐이다. 조합을 막는 것은 **facade의 일**이다.
   - ⭐ **`0.y.z` 전환의 첫 실익을 여기서 회수했다.** 원래 이 항목에는 *"깨지는 것은 이미 깨져 있던
     경로뿐이므로 마이너"* 라는 논증이 붙어 있었다. D-VERSION 이후에는 **판정 자체가 불필요**하다
     ([`architecture/05 §1`](../architecture/05-versioning-policy.md)) — 그 논증을 세워야 했다는 것이
     `1.x`가 이르다는 신호였고(05 §0-②), 이 항목이 D-VERSION의 직접적 계기였다.
   - ✅ **재개 조건도 함께 해소됐다**: 소비 repo가 dev hosted zone을 bootstrap해 `enable_external_dns_iam`을
     되켤 때, 이 validation이 **되켜는 사람을 보호한다** — zone ARN을 빠뜨리면 같은 apply 실패를
     반복하는데 이제는 plan에서 몇 초 만에 잡힌다.
9. ~~🔴 **cluster SG 추가 규칙 통과 변수 — `D-WORKBENCH-SEAM`이 낸 요구**~~
   ✅ **해소(2026-08-05, `eks-cluster-v0.3.0`, §4.3)** — 아래는 그때의 판단 기록이다
   (설계 근거는 [`40 §5.2`](40-workbench.md)).
   - **왜 이 모듈인가**: workbench → apiserver 443은 **클러스터가 누구를 받아들이는가**의 문제이고,
     [`03 §2.3`](../architecture/03-dependencies.md)이 *"소유 모듈이 허용 소스 목록을 변수로
     파라미터화해 owner가 rule을 생성한다"* 고 이미 정했다. workbench 모듈이 남의 SG에 rule을 붙이면
     소유자가 쪼개진다.
   - 🔑 **또 하나의 "facade가 upstream을 가린" 사례다.** upstream v21에 `security_group_additional_rules`가
     **처음부터 있다**(`source_security_group_id` 지원). 우리 wrapper가 안 넘기고 있을 뿐 —
     `ami_type`(D-NODE-ARCH)과 같은 형태다. **단정하고 우회를 짜지 않은 것이 이번에도 맞았다.**
   - facade 이름은 **`cluster_` 접두를 붙여** node SG 쪽(`node_security_group_additional_rules`)과 구분한다.
   - ⚠️ **함께 고칠 결함**: `outputs.tf`의 `cluster_security_group_id` 설명이 *"EKS가 만든 클러스터
     보안 그룹"* 이라고 적혀 있으나 값은 **upstream 모듈이 만든 SG**다(EKS 자동 생성분은
     `cluster_primary_security_group_id`이며 노출하지 않는다). **설명과 값이 다른 SG를 가리킨다** —
     규칙을 어디에 붙일지 판단할 때 정확히 오도하는 지점이다.
   - ✅ 경로 성립 확인: upstream은 자신이 만든 SG를 `vpc_config.security_group_ids`에 넣으므로
     **apiserver ENI에 적용**된다. ⚠️ 단 그 규칙을 **구형 `aws_security_group_rule`** 로 만든다 —
     `03 §2.1`이 신규 코드에서 금지한 리소스이나 **upstream 내부라 통제 밖**이다([`40 §10-4`](40-workbench.md)).
   - ⛔ **`v0.2.0` 태그를 옮기지 않는다** — 이미 소비자가 apply까지 마쳤다.
   - 🔗 **`v0.3.0`에 함께 실리는 것**: `required_version` 하한 `>= 1.9.0` → **`>= 1.12.0`**
     (D-TOFU-FLOOR, §3.3 상자). 소비 루트가 이미 `>= 1.12.0`이라 **소비자 영향은 없다**.
10. **닫힌 열거(`validation`)의 유지보수 부채** — `ami_type`(D-NODE-ARCH)·`capacity_type`·
   `enabled_log_types`·taint `effect`는 값 목록을 모듈이 소유한다. **AWS가 값을 추가하면 그때까지
   신형 값이 막힌다.** 실증: `capacity_type`이 AWS가 나중에 추가한 `CAPACITY_BLOCK`을 아직 담지 못한다.
   ⚠️ 이건 "고쳐야 할 결함"이 아니라 **의식적으로 낸 값**이다(오타의 대가가 비대칭이라 넣었다).
   정책 판단이 필요한 지점은 *"어느 열거를 계속 닫아 둘 것인가"* 이고, 소비자가 신형 값에 막히는
   사건이 실제로 발생하면 그 변수부터 연다.

### 5.2 ✅ 해소 — 2026-08-03 개정에서 **계약으로 승격**

열린 항목으로 두는 것과 계약에 넣는 것의 차이가 재사용 자산에서는 크다. **보류는 곧 모든 고객사에
대한 기본값**이 되기 때문이다. 아래 둘은 그래서 §3.1로 올렸다.

- ~~**Karpenter subnet/SG discovery 태그**~~ → **§3.1 + Task 20.3**. NodeClass는 selector를 **둘**
  쓴다(`subnetSelectorTerms`·`securityGroupSelectorTerms`). subnet 쪽은 소비자가 VPC 모듈
  `extra_tags`로, **SG 쪽은 이 모듈이 `node_security_group_tags`로** 부여한다.
  ⚠️ **PoC에서 SG 태그 누락이 실제 사고였다**(subnet만 다룬 최초 설계의 공백 → `securityGroupSelectorTerms`가
  빈 결과 → Karpenter 프로비저닝 실패). 계약으로 고정해 재발을 막는다. cluster primary SG가 아니라
  **node SG**에 붙인다.
- ~~**컨트롤플레인 로깅**~~ → **`enabled_log_types` 변수**(§3.1). trivy `AVD-AWS-0038`이 지적한 항목이며,
  PoC는 CloudWatch 비용을 이유로 보류했다. 재사용 자산에서는 **기본 `[]`로 PoC 동작을 유지하되 소비자가
  켤 수 있게 노출**하는 것이 옳은 처리다(VPC Flow Logs와 동일 취급).
  ⚠️ 게이트(`.githooks`)는 다운로드된 upstream 모듈을 스캔에서 제외하므로, 이 항목의 추적 지점은
  **여전히 이 문서뿐**이다 — trivy가 다시 잡아주지 않는다.

### 5.3 이 문서 밖 — 이관·재결정

| 항목 | 이관처 | 비고 |
|------|--------|------|
| **부트스트랩 seam 재결정**(관리형 Capability vs self-managed) | [`01 §3.3`](../architecture/01-module-strategy.md) 열린 항목 1 · [`21`](21-gitops-bootstrap-seam.md) | ⛔ **이 repo가 아직 승계하지 않은 결정.** 모듈 계약(§3.2 출력)은 어느 쪽이든 불변 |
| **ArgoCD Capability fleet 확장 정책** (구 열린 항목 9) | [`21` §열린 항목](21-gitops-bootstrap-seam.md) | 리서치 결론(중앙 hub 1개 + AppProject 테넌시)을 근거째 이관 |
| ~~cluster Secret 생성 주체~~ (구 열린 항목 10) | [`21` §2.8](21-gitops-bootstrap-seam.md) | D-SPOKE-SEAM으로 해소됨 — 이관본에 기록 |
| **GitOps 저장소 구조**(App-of-Apps vs ApplicationSet, NodePool·ingress·cert-manager 매니페스트) | [`30-gitops-repo.md`](30-gitops-repo.md) ⚠️ 미개정 | 애플리케이션 트리 **내용**은 GitOps 레포 소관 |
