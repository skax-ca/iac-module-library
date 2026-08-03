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
>   파라미터화, 환경 프로파일, 예제 2종, 출력 계약 안정성.
> - **Task 20.1(a)(b)(c)(e) 실물 확인 반영**(2026-08-03, 같은 날 2차) — upstream 소스 직독으로
>   **D-EKS-PROTECT를 네이티브 `deletion_protection`으로 확정**(→ 하한 `>= 1.12.0`에서 **`>= 1.9.0`**으로
>   하향) · **D-EKS-ENABLED를 upstream `create` 토글에 위임** · `eks-pod-identity` 핀 `2.8.2` ·
>   출력 fallback 불일치 함정 기록. ⏸ **(d) addon 핀 소싱만 미완**(AWS 계정 필요).
>
> 이후 **이 문서가 SSOT**다. 원본은 이력 조회용으로만 본다.

> 공통 규약: [02 · 네이밍·태깅·버전 핀](../architecture/02-naming-tagging-and-pinning.md) ·
> 전략 근거: [01 · 모듈 전략](../architecture/01-module-strategy.md) ·
> 의존성 원칙: [03 · 의존성 & 공유 리소스](../architecture/03-dependencies.md)

**전략 위치**: 고속 churn·지식밀도 높음·정확성 비직관적 → **커뮤니티 `terraform-aws-modules/eks` +
wrapper(facade)**(`01 §2.2`). Karpenter는 **IAM 전제조건만 IaC**, helm/NodePool은 GitOps.

**릴리스 스코프**: 이 문서의 §1~§3이 `eks-cluster-v1.0.0`의 계약이다.
계약 확장은 마이너, 계약 변경은 메이저(`02 §3`).

> **승계한 PoC 결정 요약** (판단은 유효, 실증 서술은 findings 소관):
> **D9 custom networking** 전제(§2.5) · **addon 관리 C′**(§2.6, baseline merge·재주입·EBS CSI IAM) ·
> **D-ADDON-VERSION-PIN**(§2.6-6, addon 버전 명시 핀) · **D-NODE-AMI-PIN**(§2.6, NG AMI 핀) ·
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
| Pod ENI 보안그룹 | upstream `node_security_group_id` 재사용 | 노드와 동일 정책 — 별도 SG는 요구 발생 시 |
| SNAT | `AWS_VPC_K8S_CNI_EXTERNALSNAT=false`(기본) 유지 | Pod→온프레미스가 노드 uniq IP로 SNAT되는 D9 전제 |
| max-pods 감소 대응 | `ENABLE_PREFIX_DELEGATION=true` | custom networking 시 primary ENI 미사용 보상 |

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
> `local.cluster_name`을 한 번 정의해 두 모듈에 넘긴다 — 예제(`examples/eks-cluster/`)가 이 패턴을 보인다.

## 2.6 addon 관리 — baseline 보장 + 명시적 증분 (C′)

> **D-ADDON-VERSION-PIN**: baseline addon 버전을 **명시적으로 핀**한다(항목 6 신설).
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
6. **addon 버전은 명시적 핀** (2026-07-22 D-ADDON-VERSION-PIN) — baseline addon마다 버전을
   모듈이 고정하고 `most_recent = false`를 넘긴다(upstream 기본 true를 명시적으로 끔).
   - **핀 소싱**: 버전 문자열은 임의값이 아니라 `aws eks describe-addon-versions
     --kubernetes-version <k8s> --addon-name <name>`으로 **해당 k8s 버전의 실측 최신 호환**을 박는다.
     클러스터 실물과 일치시켜 도입 시 drift 0(핀 적용 plan은 no-op이어야 한다).
   - **업그레이드 = 핀 bump**: 버전 상향은 이 모듈에서 문자열을 바꾸는 **명시적 커밋**으로만 일어나고,
     plan diff로 리뷰된다. AWS의 "when desired" 판단을 사람이 회수한다.
   - **소비자 override 유지**: `cluster_addons`로 특정 addon의 `addon_version`을 넘기면 그 값이
     이긴다(§2.6-3 재주입 원칙과 동일). 소비자가 버전을 안 주면 baseline 핀을 상속.
   - **k8s 버전 승격 시**: `kubernetes_version` bump PR에서 baseline 핀도 새 k8s의 호환 버전으로
     함께 갱신한다(런북 체크리스트 대상). 핀 누락 addon이 없도록 baseline 표를 SSOT로 유지.
   - **community tier addon**(아래 확장 표)도 동일 정책 — 버전 핀 + `most_recent=false`.

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
> hand-author(최후). 항상 **버전 핀 + 최소권한(zone ARN) 스코핑**. external-dns 관리형 정책은 광범위
> (`Route53FullAccess`)하므로 **zone ARN 축소가 prd 필수**.

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


## 3. 인터페이스 — `eks-cluster-v1.0.0` 계약

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
variable "public_access_cidrs"     { type = list(string), default = [] }
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
    ami_release_version  = optional(string)      # D-NODE-AMI-PIN. null이면 최신 해석(하위호환)
    labels               = optional(map(string), {})
    taints               = optional(list(object({ key = string, value = string, effect = string })), [])
  }))
  default = {}
}

# ── addon (§2.6 C′ — baseline과 merge되는 증분/override) ──────────────
variable "cluster_addons" {
  type = map(object({
    enabled       = optional(bool, true)   # 제거는 명시적으로만. core 4종은 validation 차단
    addon_version = optional(string)       # 미지정이면 baseline 핀 상속(D-ADDON-VERSION-PIN)
    configuration = optional(string)
    pod_identity  = optional(object({ role_arn = string, service_account = string }))
  }))
  default = {}                             # 빈 map = baseline 6종 상속
}

# ── IAM ──────────────────────────────────────────────────────────────
variable "access_entries"   { type = any,  default = {} }   # aws-auth 대체
variable "enable_karpenter" { type = bool, default = true }
variable "enable_alb_controller_iam" { type = bool, default = false }  # §2.6a opt-in
variable "enable_external_dns_iam"   { type = bool, default = false }  # §2.6a opt-in
variable "external_dns_hosted_zone_arns" { type = list(string), default = [] }  # zone 스코핑(prd 필수)
```

**PoC 대비 변경점**:
- ➕ `cluster_enabled`·`deletion_protection` (재사용 요건 — 위 D-EKS-ENABLED/PROTECT)
- ➕ `enabled_log_types` — **구 열린 항목 6을 계약으로 승격**. PoC는 trivy `AVD-AWS-0038`을 알고도
  비용 때문에 보류했는데, 재사용 자산에서는 **보류가 곧 모든 고객사에 대한 기본값**이 된다.
  기본 `[]`로 PoC 동작을 유지하되 **소비자가 켤 수 있게** 노출하는 것이 옳은 처리다(VPC Flow Logs와 동일 취급).
- ➕ `managed_node_groups.ami_release_version` — D-NODE-AMI-PIN을 계약에 명시
- ➕ `enable_alb_controller_iam`·`enable_external_dns_iam`·`external_dns_hosted_zone_arns` (§2.6a)
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

> ⚠️ **함정 — upstream 출력의 fallback 값이 일관되지 않다**(2026-08-03 Task 20.1 확인).
> `create = false`일 때 upstream `outputs.tf`는 대부분 `try(…, null)`이지만
> **`cluster_name`과 `cluster_id`만 `try(…, "")`(빈 문자열)** 이다.
> → facade가 **`null`로 정규화**한다. 그러지 않으면 소비자가 `X == null` 대신 `X == ""`를 알아야 하고,
> 그건 **upstream 구현 디테일이 우리 계약으로 새는 것**이다 — facade가 막으라고 있는 바로 그 종류다.
> tftest AC3(kill switch)에서 **빈 문자열이 아니라 `null`인지**를 assert한다.

### 3.3 `required_version` 하한

**`>= 1.9.0`** (기준선) — 근거는 **교차변수 `validation`**(D-EKS-PROTECT의 파기 차단 가드)이다.

> ✅ **2026-08-03 확정**: 초안은 `>= 1.12.0`이었다. D-EKS-PROTECT를 VPC D12처럼 **동적 `prevent_destroy`**로
> 구현할 것이라 보았기 때문이다. Task 20.1(e)에서 `aws_eks_cluster`에 **네이티브 `deletion_protection`이
> 있음**을 확인해 그 필요가 사라졌고, **하한을 두 마이너 내렸다.**
>
> 🔑 이 방향이 옳다. 하한은 **실제로 쓰는 기능이 정하고**(`02 §2`), 근거 없는 상향은 **소비자만 배제**한다.
> `vpc`가 `>= 1.12.0`인 것은 그 모듈이 실제로 1.12 기능을 쓰기 때문이지 **repo 표준이 아니다** —
> 모듈마다 하한이 갈리는 것이 `<module>-vX.Y.Z` 컴포넌트별 태그를 쓰는 이유이기도 하다.
>
> ⛔ PoC 문서의 `>= 1.14.0`은 **Terraform 버전**이었다. OpenTofu에는 존재하지 않는 버전이라
> 그대로 두면 **어떤 OpenTofu로도 `init`이 되지 않는다** — 승계 시 반드시 걷어내야 하는 종류의 값이다.

`02 §2` 하한 대장 등재는 **릴리스(Task 20.8) 시점**에 한다. 기준선과 같은 값이지만, "확인한 결과
기준선이었다"와 "확인하지 않았다"는 다르므로 근거(`교차변수 validation`)와 함께 명시적으로 적는다.

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
> **⏸ (d)만 미완**(AWS 계정 필요).

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

**⏸ (d) addon 스키마·가용성** — `aws eks describe-addon-versions` / `describe-addon-configuration`
- baseline 6종 + community tier 5종이 **대상 리전·`kubernetes_version`에서 가용한지**와 `owner` 값.
- vpc-cni의 `eniConfig.create`·`AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG`·`ENABLE_PREFIX_DELEGATION` 지원(§2.5).
- 각 addon의 **호환 최신 버전 문자열**(D-ADDON-VERSION-PIN의 핀 소싱).
- ⛔ **AWS 계정 접근이 필요하다.** 계정 없이는 baseline 핀을 확정할 수 없고,
  **핀 없는 baseline은 D-ADDON-VERSION-PIN 위반**이라 릴리스(Task 20.8)할 수 없다.
  ⚠️ 다만 **20.2~20.7 구현은 (d)에 막히지 않는다** — 핀 값만 비어 있을 뿐 구조는 결정됐다.

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

### Task 20.6: 예제 2종 (`examples/`)

`01 §4` "모듈은 예제 없이 릴리스하지 않는다". VPC의 선례를 따른다:
- **`examples/eks-cluster/`** — 최소 형상. 클러스터 + 시스템 NG 1개 + baseline addon 상속.
- **`examples/eks-cluster-enterprise/`** — **고객사 착수 템플릿**(검증 자산이 아니다 — VPC에서
  `examples/vpc-enterprise`의 목적이 재정의된 것과 같은 위치). custom networking + Karpenter +
  컨트롤러 IAM opt-in + 로깅 활성.
- ⚠️ 두 예제 모두 **VPC 모듈과의 결선**을 보여야 한다 — 특히 `local.cluster_name`을 한 번 정의해
  VPC의 `eks_cluster_name`과 EKS 모듈에 **같이 넘기는** 패턴(§2.5).
- `aws ~> 6.0`, `.terraform.lock.hcl` 커밋(⚠️ `registry.opentofu.org` 확인).
- Commit: `feat(examples): eks-cluster 예제 2종`

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
