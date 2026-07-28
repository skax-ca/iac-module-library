# 20 · EKS 모듈 (커뮤니티 wrapper) + Day 2 GitOps 경계

> **승계(미개정)**: `terraform-enterprise-poc` `docs/design/20-eks-module.md` @ `76285f7`(동결 커밋)
>
> ⚠️ **이 문서는 아직 정밀 개정되지 않았다.** PoC 전제(Terraform 1.15 + HCP Terraform,
> `workload=poc`, 상대경로 모듈 소싱, TFC 워크스페이스)와 **실증 서술이 그대로 남아 있다.**
>
> - 본문의 실증 날짜·run ID·"실증됨" 서술은 **이 repo에서 재현된 것이 아니다** —
>   정리본은 [`../reference/poc-findings.md`](../reference/poc-findings.md)를 본다.
> - 설계 판단(리소스 구성·경계·트레이드오프)은 대체로 유효하나, **실행 스택 종속부는 무효**다.
>
> **모듈 이식 시점(D-OSS-STACK §6-2)에 재검토하며 개정한다.** 그 전까지 이 문서를
> "이 repo의 확정 설계"로 인용하지 않는다.


> 공통 규약: [02-common-governance.md](../architecture/02-naming-tagging-and-pinning.md) · 결정 근거: [01-strategy-and-decisions.md](../architecture/01-module-strategy.md)

**전략 위치**: 고속 churn·지식밀도 높음·정확성 비직관적 → **커뮤니티 `terraform-aws-modules/eks` v21.24.0 + wrapper(facade)**. Karpenter는 IAM 전제조건만 Terraform, helm/NodePool은 GitOps.

> 개정 이력: 2026-07-16 VPC v2/D9(custom networking) 전제를 §2.5·§3·§4에 반영 완료
> (구계약 `private_subnet_ids` 참조 제거, pod_subnet_ids·Task 20.0 신설).
> 2026-07-18 addon 관리 개편(C′) — ralplan 합의(`.omc/plans/2026-07-18-eks-addon-interface-consensus.md`):
> §1 경계 규칙 개정(community add-on·예외 목록), §2.6 신설(baseline·재주입·EBS CSI IAM), §3.1 cluster_addons 교체, Task 20.9.
> 2026-07-18 hotfix: Karpenter 컨트롤러 정책 `enable_inline_policy = true` — 최초 apply에서
> managed policy 한도(6,144자, 조정 불가) 초과 실증(LimitExceeded). inline 한도는 10,240자(upstream #3563).
> 2026-07-18 ArgoCD 토폴로지 결정(D-ARGOCD) — 멀티어카운트 확장성 검토 결과 standalone
> per-cluster(`helm_release`) → **hub-spoke + EKS Capability for Argo CD(관리형)** 채택. 검증 3게이트
> 통과(서울 리전 가용 · 요금 $0.03/capability-hr · `awscc_eks_capability` v1.93.0 native·TFC 호환).
> §1 seam 행 개정 · §2.7 신설 · Task 20.7 재정의. 근거: AWS Containers Blog(EKS Capability for Argo CD,
> GA 2025-11-30) · EKS Blueprints hub-spoke 패턴 · terraform-provider-aws #45324(native 미지원 → awscc 경로).
> 2026-07-24 **§2.8 V2·V3 재판정(D-SEED-KUBECTL)** — bastion(40) 배포로 apiserver 도달 전제가 바뀌어
> root App seed 경로가 역전. ArgoCD API/CLI 후보 기각(인증이 UI 선행 요구 — JWT 토큰뿐),
> **bastion kubectl 런북 채택**(IAM만으로 인증, 신규 자격증명 없음). V3·1회성 kubernetes provider 종결.
> hub 등록 계약 누락 gap 기록. 근거: EKS User Guide(argocd-considerations·argocd-permissions·
> working-with-argocd) · AWS Containers Blog(deep-dive GitOps with EKS capability for Argo CD).
> 2026-07-24 **§2.7 IAM 권한 서술 정정** — "public Git/**CodeConnections**는 추가 정책 불필요"는 오류였다.
> CodeConnections는 `codeconnections:UseConnection`·`GetConnection` 가산이 **필수**(30 §1
> D-REPO-CODECONNECTIONS 채택으로 이 프로젝트에 실제 적용). §4 게이트 (a)·(f) 기록도 함께 정정.

---

## 1. 경계 (Day 0/1 Terraform ↔ Day 2 GitOps)

| 계층 | 도구 | 대상 |
|------|------|------|
| Day 0/1 인프라 | Terraform | 클러스터, managed node group, IAM(Pod Identity), OIDC |
| EKS Managed/Community Addons | Terraform `addons`(=aws_eks_addon) | core·storage·관측성·DNS 컨트롤러 — §2.6 표(vpc-cni, coredns, kube-proxy, eks-pod-identity-agent, aws-ebs-csi-driver, metrics-server, **fluent-bit, kube-state-metrics, prometheus-node-exporter, cert-manager, external-dns**) |
| Karpenter IAM 전제조건 | Terraform `//modules/karpenter` | 컨트롤러 Pod Identity 역할, 노드 IAM, instance profile, 중단 SQS |
| 부트스트랩 seam | Terraform(관리형 Capability) | **EKS Capability for Argo CD** 활성화 + Capability IAM role + private 접속(VPC endpoint) + spoke Access Entry (→ §2.7) |
| Day 2 GitOps | GitOps(ArgoCD) | **AWS Load Balancer Controller**(community addon 아님 → helm, IAM §2.6a), Karpenter helm/NodePool, **컨트롤러 설정(cert-manager Issuer/Certificate CR, external-dns 애노테이션)**, 앱 워크로드 |

> **한 줄 규칙(2026-07-20 재개정)**: `aws_eks_addon` API로 설치 가능한 것은 **Terraform이 기본**이다
> (community add-on 포함). `aws_eks_addon`은 AWS API지 helm/kubernetes provider가 **아니므로** push 안티패턴
> (§4.1)에 해당하지 않는다 — community addon도 Terraform이 기본인 이유. **컨트롤러(+CRD)는 Terraform addon,
> 그 addon이 소비하는 CR 인스턴스·애노테이션(cert-manager Issuer/Certificate, external-dns가 읽는 Ingress
> 애노테이션)은 GitOps**로 나눈다(설정은 앱·플랫폼팀이 Git에서 관리). **helm/manifest만 가능한 것**
> (ALBC — community addon 부재)**→ GitOps helm**. 목록 개정 이력은 §2.6.
>
> ⚠️ **community addon 지원 모델**(공식): AWS는 **버전 호환 검증 + 라이프사이클(install/update/remove)만**
> 지원하고 **기능은 미지원**(shared responsibility). prd 채택 전 이 트레이드오프를 인지한다.
>
> ArgoCD는 addon(`aws_eks_addon`)이 아니라 **EKS Capability**(관리형, 클러스터 밖 AWS 서비스에서 실행)다.
> 부트스트랩 seam의 구현체는 §2.7 참조 — 위 addon 한 줄 규칙과는 별개 경계다.
>
> **CR 소유 정밀화(D-CR-OWNERSHIP, [`30-gitops-repo.md §0.1`](30-gitops-repo.md))**: 이 §1 규칙은 컨트롤러↔
> CR을 가르지만, 그 CR을 **플랫폼(계층 2)이 갖나 앱팀(계층 3)이 갖나**는 별개 질문이다. 판별자는 (1) CR이
> IAM·비용·용량 같은 **인프라 정체성**을 인코딩하는가, (2) 규칙이 **제약하는 대상**이 소유자와 같은가이며,
> blast radius(cluster/namespace)는 보조 신호다(예외 실재) — Karpenter NodePool·Kyverno ClusterPolicy=계층 2,
> KEDA ScaledObject·Kyverno 네임스페이스 Policy=계층 3. "CR이면 앱팀"도 "namespaced면 앱팀"도 오판이다.

> **§1 경계 재개정 근거 (2026-07-20, D-ADDON-BOUNDARY)**: AWS Console 확인 결과 cert-manager·external-dns·
> fluent-bit·kube-state-metrics·prometheus-node-exporter가 모두 **EKS community addon**(`owner=community`,
> `aws_eks_addon` 설치)으로 제공됨. 기존 §1 예외(cert-manager·external-dns=GitOps)는 "helm-only"를 전제로
> 썼으나, addon 경로는 push 안티패턴이 아니므로 예외 명분이 소멸 → **컨트롤러는 Terraform addon, 설정만
> GitOps**로 정련. 관측성 3종은 미분류 공백이었고 §1 기본값대로 Terraform. ALBC만 community addon 부재로
> GitOps helm 유지(→ §2.6a eks-pod-identity 위임 범위는 ALBC로 축소).

## 2. facade 원칙 (핵심)
consumer는 `cluster_name`/`cluster_addons`/`kubernetes_version`을 쓰고, wrapper가 upstream `name`/`addons`/`kubernetes_version`으로 번역.
> v21 실제 변수명 확인됨: 루트는 `name`·`addons`(cluster_addons 아님). 이 변수들이 메이저마다 바뀌므로 facade가 유일한 번역 지점 → upstream rename이 앱팀에 새지 않음.

리소스 약어(카탈로그 A.1): 클러스터 `eks`, 노드그룹 `eksn`. 클러스터명은 `eks-<workload>-<env>-<region>-<purpose>-<serial>` 포맷 권장(예: `eks-poc-prd-an2-main-01`, dev는 `eks-poc-dev-an2-main-01`).

## 2.5 네트워킹 통합 — VPC D9 custom networking (2026-07-16 확정)

VPC 설계 [10-vpc-module.md D9](10-vpc-module.md)의 A안(custom networking)이 승인·배포됨에 따라
EKS는 다음 네트워크 전제로 설계한다:

| 항목 | 값 | 근거 |
|------|-----|------|
| 노드·컨트롤플레인 ENI 서브넷 | `subnet_ids_by_group["node-uniq"]` (uniq 10.1.6-7.0/24, 2AZ a·c) | D9 — node-SNAT 소스, 온프레미스 방화벽 오픈 단위 |
| Pod 서브넷 (ENIConfig) | `subnet_ids_by_group["pod-dup"]` (dup 100.64.0/64.0/18, 2AZ a·c) | D9 — 비라우팅 대량 소모 대역 |
| Pod ENI 보안그룹 | upstream `node_security_group_id` 재사용 | 노드와 동일 정책 — 별도 SG는 요구 발생 시 |
| SNAT | `AWS_VPC_K8S_CNI_EXTERNALSNAT=false`(기본) 유지 | Pod→온프레미스가 노드 uniq IP로 SNAT되는 D9 전제 |
| max-pods 감소 대응 | `ENABLE_PREFIX_DELEGATION=true` | custom networking 시 primary ENI 미사용 보상 |

**구성 방식 — 경계 규칙 준수**: custom networking은 **vpc-cni managed addon의
`configuration_values`로 선언**한다(env: `AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG`,
`ENI_CONFIG_LABEL_DEF=topology.kubernetes.io/zone` + `eniConfig` 블록으로 AZ별 ENIConfig 생성).
이 방식이면 ENIConfig가 Helm/manifest가 아닌 addon API 경계 안에 남는다(§1 규칙).
addon은 **노드그룹 생성 전 적용**(`before_compute`)이어야 초기 노드부터 Pod가 pod-dup에 배치된다.

> ✅ 리스크 게이트 해소(Task 20.1): vpc-cni addon configuration schema가 `eniConfig.create`를
> **지원함을 실물 확인**(`aws eks describe-addon-configuration`). ENIConfig가 addon
> `configuration_values` 경계 안에서 생성되므로, `kubernetes_manifest` fallback은 불필요(폐기).

**선행 절차 (Task 20.0)**: 클러스터명 확정(`eks-poc-dev-an2-main-01`) → networking-dev의
`eks_cluster_name` TFC 변수 주입 → 재plan/apply로 서브넷 EKS 태그(in-place) 부여.
Karpenter 서브넷 discovery는 node-uniq 그룹 `extra_tags`에 `karpenter.sh/discovery=<클러스터명>`을
같은 시점에 추가(열린 항목 4).

## 2.6 addon 관리 — baseline 보장 + 명시적 증분 (2026-07-18 확정, ralplan 합의 C′)

> **2026-07-22 개정 (D-ADDON-VERSION-PIN)**: baseline addon 버전을 **명시적으로 핀**한다(항목 6 신설).
> 배경 — 최초 구현은 `addon_version`을 미지정(null)으로 넘겼는데, upstream
> `terraform-aws-modules/eks` v21의 `addons` 스키마는 **`most_recent = optional(bool, true)`**
> (기본 true)라, 버전을 안 박으면 매 plan마다 `aws_eks_addon_version`으로 최신 호환 버전을 조회해
> AWS가 새 버전을 릴리스할 때마다 **리뷰 없는 in-place 업데이트**(예: kube-proxy)가 발생했다.
> AWS 공식(managing-add-ons)은 addon을 "원할 때(when desired) 업데이트"하는 신중한 모델을 권하며,
> AWS는 사용자 클러스터의 addon을 자동 업그레이드하지 않는다 — `most_recent=true`는 그 판단을
> Terraform이 매 apply마다 대신 내리게 해 이 모델을 우회했다. CLAUDE.md 버전 핀 철학과도 상충.

**문제**: Terraform 변수 default는 전체 대체라, 소비자가 addon 1개를 추가하려고 map을 넘기면
기본 addon이 통째로 대체되고 누락분은 **in-place 삭제**된다(coredns 삭제 = DNS 중단). 또한
IAM이 필요한 addon(EBS CSI)이 role 없이 설치되면 무용지물인데 facade에 IAM 연동 경로가 없었다.

**설계 (C′)**:
1. **baseline 6종은 모듈이 소유** (아래 표) — 소비자 입력과 `merge()`되므로 누락 ≠ 삭제.
2. **제거는 `enabled = false` 명시로만** — null 값 같은 암묵 규약 없음. **core 4종은
   validation으로 비활성화 차단**: vpc-cni·coredns·kube-proxy는 클러스터 기능 자체,
   `eks-pod-identity-agent`는 Karpenter·EBS CSI의 Pod Identity association 생존 전제
   (없으면 IAM엔 존재하나 Pod가 자격증명을 못 받는 조용한 파손).
3. **모듈 소유 필드는 merge 뒤 재주입** — Terraform `merge()`는 shallow라 소비자가 버전만
   override해도 엔트리가 통째로 교체된다. vpc-cni `configuration_values`(§2.5 합성)와
   aws-ebs-csi-driver `pod_identity_association`(아래 4)은 merge 결과 위에 모듈이 다시 덮어
   항상 승리한다(기존 §2.5 vpc-cni 패턴의 일반화).
4. **EBS CSI IAM은 모듈이 생성** (Karpenter와 동일한 "IAM 전제조건은 Terraform" 배치):
   role `iamr-{workload}-{env}-{region_code}-ebs-csi`(카탈로그 A.6 `iamr`), 신뢰
   `pods.eks.amazonaws.com`, 정책 `AmazonEBSCSIDriverPolicy`, association은 addon의
   `pod_identity_association`(SA `ebs-csi-controller-sa`)으로 연결. ebs-csi를
   `enabled=false`로 빼면 role도 미생성.
5. **기타 IAM 필요 addon**(예: aws-efs-csi-driver)은 소비자가 `pod_identity` 필드로
   role_arn·service_account 주입 — role 생성은 소비자(live/foundation) 소관.
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

**확장 community addon tier (Terraform, 2026-07-20 D-ADDON-BOUNDARY)**: §1 재개정으로 아래도 `aws_eks_addon`
(`owner=community`)으로 Terraform이 소유한다. baseline 6종과 동일한 merge·opt-out 메커니즘, 단 core 보호는
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

### 2.6a 컨트롤러 IAM 전제 — 설치 경로별 두 갈래 (2026-07-20 확정, D-ADDON-IAM; D-ADDON-BOUNDARY로 개정)

**원칙 (IAM 소유 = addon 분류, 정책은 위임)**: ① baseline 컨트롤러의 IAM 전제는 **Terraform(이 모듈)** 소관.
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
| **external-dns** | **Terraform addon** | **eks-pod-identity 위임**(standalone assoc) | `attach_external_dns_policy` + `external_dns_hosted_zone_arns` 스코핑 | 항상 Route53. ns/SA `external-dns` |
| **cert-manager** | **Terraform addon** | **없음**(HTTP01) / DNS01 시 별도 Route53 | — / 스코핑 Route53 | addon은 컨트롤러+CRD만(IAM 미연동). CR(Issuer)은 GitOps |
| **EBS CSI** | Terraform addon | addon `pod_identity_association` | AWS 관리형 `AmazonEBSCSIDriverPolicy` | 현행 §2.6-4 |
| 관측성(fluent-bit·KSM·node-exporter) | Terraform addon | 기본 없음(fluent-bit CloudWatch 출력 시 addon role) | — | §2.6 관측성 tier |

> **구현(2026-07-20, modules/eks-cluster)**: `module.alb_controller_pod_identity`·
> `module.external_dns_pod_identity`(eks-pod-identity `= 2.8.1`) + 토글 3종 + role ARN 출력 2종.
> tftest 2 run 추가(기본 off·opt-in on·카탈로그 네이밍). fmt·validate·tflint·trivy·test(10 passed) 통과.

> **정책 소싱 우선순위**: AWS 관리형(EBS CSI·external-dns) ≈ 커뮤니티 큐레이션(ALBC via eks-pod-identity) >
> hand-author(최후). 항상 **버전 핀 + 최소권한(zone ARN) 스코핑**. external-dns 관리형 정책은 광범위
> (`Route53FullAccess`)하므로 **zone ARN 축소가 prd 필수**.

## 2.7 ArgoCD 토폴로지 — hub-spoke + EKS Capability for Argo CD (2026-07-18 확정, D-ARGOCD)

**문제**: standalone per-cluster 방식(클러스터마다 ArgoCD `helm_release`)은 Control Tower/AFT
멀티어카운트에서 워크로드 계정이 늘 때마다 ArgoCD 설치·업그레이드·SSO·RBAC·백업을 N번 반복하고,
fleet 전체를 조망할 single pane of glass가 없다. ArgoCD 자체가 각 클러스터의 관리 대상이 되어
관리 표면이 계정 수만큼 증식한다.

**대안 비교**:

| | A. standalone | B. self-managed hub-spoke | C. EKS Capability(관리형) |
|---|---|---|---|
| ArgoCD 위치 | 모든 워크로드 클러스터 | 관리(hub) 클러스터 1개 | AWS 관리 서비스(클러스터 밖) |
| 설치 개수 | 계정 N개 | 1개(hub) | 0개 |
| spoke 등록 | — | hub argocd secret + cross-account IAM | EKS Access Entry(role 권한 부여) |
| cross-account 연결 | — | 직접 구성(peering/TGW·role chaining) | AWS 자동(private endpoint 포함) |
| 운영 부담 | 높음(N배) | 중간(hub SPOF·업그레이드) | 낮음(scaling·패치 AWS) |
| 성숙도 | 안정 | 안정(EKS Blueprints 공식) | 신규(GA 2025-11-30) |

**결정: 옵션 C (EKS Capability for Argo CD, 관리형)**. hub 클러스터 자체를 운영하지 않고
(AWS 관리 서비스 계정에서 실행), spoke는 EKS Access Entry로 등록한다. private endpoint·cross-account
연결을 AWS가 처리하므로 AFT 멀티어카운트·private 클러스터(§3.1 기본값) 전제와 정합한다. 새 워크로드
계정 추가 시 "ArgoCD 설치"가 아니라 "Access Entry 등록"만 늘어나 §문제의 반복 설치가 구조적으로 소거된다.

**검증 3게이트 (2026-07-18, 전부 통과)**:
1. **리전** — ap-northeast-2 지원(all commercial regions except GovCloud/China). GA 2025-11-30.
2. **요금** — `$0.03/capability-hr`(≈ $21.9/월) + `$0.0015/Application-hr`.
   **PoC(dev 단일)에선 순증 ~$22/월 + 앱당 소액** — 이 규모엔 상쇄할 hub 클러스터가 없다(in-cluster
   standalone ArgoCD는 기존 노드에서 한계비용 ≈ $0). "hub EC2 비용 소거로 상쇄"는 **fleet 확장 시**
   논거이지 PoC 논거가 아니다.
3. **Terraform** — `awscc_eks_capability`(hashicorp/awscc, PoC 동안 `~> 1.93.0` 패치 전용 핀)
   native·import 지원. hashicorp/aws에는 아직 native 리소스 없음(issue #45324) → **awscc 경로로
   TFC-native 원칙 유지**(커뮤니티 모듈 정확 핀 하이브리드 전략과 정합). awscc는 CloudFormation
   스키마 자동생성이라 마이너마다 리소스 스키마가 바뀔 수 있어 느슨한 핀(`~> 1.93`)을 피하고 패치
   핀 + `.terraform.lock.hcl` 커밋으로 drift를 막는다.

**리소스 (`awscc_eks_capability`, type=ARGOCD)** — providerDocID 12861162 실물 스키마:
- 필수: `cluster_name`, `capability_name`, `role_arn`, `type="ARGOCD"`,
  `delete_propagation_policy="RETAIN"`(유일 지원값).
- `configuration.argo_cd`: `namespace` · `aws_idc`(IAM Identity Center SSO 연동) ·
  `network_access.vpce_ids`(private 접속용 VPC endpoint) ·
  `rbac_role_mappings`(ADMIN/EDITOR/VIEWER ↔ SSO user/group).
- read-only: `server_url`(ArgoCD UI·API), `status`, `version`, `arn`.

**IAM 전제조건은 Terraform** (Karpenter·EBS CSI와 동일 배치 — §2.6): Capability가 쓸 role
`iamr-{workload}-{env}-{region_code}-argocd`(카탈로그 A.6 `iamr`). 신뢰 정책 실물 확인
(capability-role.html, 2026-07-18): **`Principal.Service = capabilities.eks.amazonaws.com`**,
`Action = [sts:AssumeRole, sts:TagSession]` (EBS CSI의 `pods.eks.amazonaws.com` Pod Identity와 다른
주체 — 혼동 주의). **role은 클러스터와 동일 계정**이어야 한다. 권한: **기본 ARGOCD(public Git)는
신뢰 정책 외 추가 정책 불필요**, 저장소 접근 방식에 따라 용도별 가산 — **CodeConnections**
`codeconnections:UseConnection` + `codeconnections:GetConnection`(⚠️ 아래 정정),
CodeCommit `codecommit:GitPull`, Secrets Manager `AWSSecretsManagerClientReadOnlyAccess`.

> **⚠️ 2026-07-24 정정 — CodeConnections는 "추가 정책 불필요"가 아니다**
>
> 이 문단과 §4 게이트 실증 (a)는 원래 "public Git/**CodeConnections**는 추가 정책 불필요"라고 적었다.
> **CodeConnections 부분이 틀렸다.** 공식 문서(integration-codeconnections)는 Capability role에
> `codeconnections:UseConnection`·`codeconnections:GetConnection`을 커넥션 ARN 리소스로 한정해
> 부여할 것을 요구한다. 추가 정책이 **불필요한 것은 인증 없는 public Git뿐**이다.
> 이 프로젝트는 GitHub private + CodeConnections를 채택했으므로(30 §1 D-REPO-CODECONNECTIONS)
> **정책 가산이 필수**다. `live/cicd/gitops-hub/main.tf`의 동일 취지 주석도 구현 시 함께 정정한다.
⚠️ **IAM 전파 race(2026-07-19 실증)**: role 생성 직후 capability를 생성하면 신뢰 정책 내용이
정확해도 EKS 검증이 400(InvalidRequest: "trust policy…invalid")으로 실패한다 — 같은 apply에서
생성하는 구조상 `time_sleep`(20s)으로 흡수한다(destroy→re-apply 루프 M-1마다 재발 방지).

**태깅·식별자 (H-1)**: `awscc` provider는 aws provider의 `default_tags`를 **지원하지 않는다**
(Cloud Control 기반, 리소스별 `tags = [{key,value}]` 자체 속성만). 따라서 거버넌스 태그(02 §1.4a의
`Environment`/`Workload`/`RegionCode`/`ManagedBy`/`Repository`)를 `awscc_eks_capability`에 **명시
주입**한다(aws provider default_tags와 동일 값을 locals로 공유). 같은 루트의 IAM role은 aws provider라
default_tags 정상 적용 — Capability만 명시 필요. `capability_name`은 카탈로그에 별도 약어가 없으므로
`"argocd"` 고정, 거버넌스는 위 `tags`로 부여(Name 태그 대신 capability_name이 클러스터 내 식별자).

**인증(SSO) 전제 (L-3, 2026-07-18 정정)**: 공식 문서상 **AWS Identity Center 구성이 필수**다
("local users are not supported"). awscc 스키마에서 `aws_idc`가 optional로 보여도 **관리형 ArgoCD의
유일 인증 경로가 IdC**이므로 실질 필수 전제조건이다. Control Tower 랜딩존이 IdC를 표준 구성하므로
인스턴스 존재를 가정하되, `idc_instance_arn`·`idc_region` 확정을 Task 20.7 전제로 둔다. IdC↔EKS 접근을
단일 정체성으로 묶으려면 IdC permission set 활용(문서 권장).

**hub-spoke 구성 (cross-account)**: 관리형 ArgoCD가 spoke 클러스터의 kube-apiserver에 접근하려면
spoke가 **EKS Access Entry로 Capability role에 권한을 부여**한다. VPC peering·IAM role chaining
불필요(AWS가 연결 처리). private 접속은 `network_access.vpce_ids`로 VPC endpoint를 연결한다.

**PoC 스코프**: dev 클러스터(`eks-poc-dev-an2-main-01`)에 Capability를 켜 메커니즘을 시연한다 —
dev가 첫 spoke(자기 자신 대상)이며 hub 클러스터를 별도로 만들지 않는다. "중앙 Capability 1개
(cross-account Access Entry) vs 계정별 Capability"의 fleet 확장 정책은 2번째 계정(stg) 도입 시점에
확정한다(열린 항목 9).

**⛔ HARD GATE — 엔드포인트 노출 (H-2)**: `network_access.vpce_ids`는 optional이고, **미지정 시
관리형 ArgoCD 서버 API/UI가 public 엔드포인트로 열린다**("By default, the Argo CD server is accessible
via a public endpoint"). private 클러스터(§3.1 기본값)에 public 컨트롤 엔드포인트가 붙는 모순을 막기
위해, **VPC endpoint 서비스명·SG 확정을 최초 apply의 차단 조건**으로 둔다(Task 20.7 게이트).

**H-2 해소 확정 (2026-07-19, `argocd-private-access.html` + an2 서비스 카탈로그 실물)**:
- **서비스명 `com.amazonaws.<region>.eks-capabilities`**(Interface형) — ap-northeast-2 카탈로그 실존 확인.
- **SG 요건**: vpce SG에 inbound HTTPS(443), 소스는 접속 클라이언트 대역(PoC는 VPC 전 대역).
  **eks-capabilities는 VPC endpoint policy 미지원** → SG가 유일한 네트워크 접근 제어 수단.
- **DNS 자동**: capability ACTIVE 후 AWS가 ArgoCD 서버 hostname을 vpce private IP로 해석되도록 DNS를
  자동 구성한다 — `private_dns_enabled` 불필요(기본 false 유지, 공식 예제 정합). Route53 작업 없음.
- **구현 결정**: vpce+SG는 **gitops-hub 루트 소유**(04 규약 — ArgoCD 전용 리소스는 소유 컴포넌트에,
  단일 apply로 vpce→capability 의존 해소). networking 데이터는 **네이밍 기반 data source 조회**
  (04 조회 1순위 — `vpc-…-main`, `snet-…-ep-uniq-*`; networking output 계약 확대·remote state sharing
  추가 불필요). 배치는 ep-uniq 그룹(/27×2AZ, 10-vpc §1.5). capability는 `aws_vpc_endpoint` ID를
  **직접 참조** — `argocd_vpce_ids` 변수와 check 경고를 제거해 게이트를 구조적으로 해소한다.
- **가역성**: `vpce_ids = []` update로 public 복귀 가능. vpce가 available 상태를 잃으면 서버 접속 불능
  (삭제 금지 — 재생성 시 capability update 필요).
- **운영 주의**: private화 이후 UI/API는 VPC 내부·연결망(VPN/DX)에서만 도달 — UI 로그인 검증 경로
  (SSM 포트포워딩 등)는 런북(Task 20.8) 소관.

**H-2 개정 — 노출 토글 (2026-07-19, 사용자 결정)**: PoC에서 집(공용 인터넷)에서의 UI 로그인
테스트가 필요해, **명시적 opt-in 방식의 public 노출을 허용**한다. H-2의 원 취지("모르고 public으로
여는 것 방지")는 변수 기본값과 경고로 유지한다:
- `argocd_endpoint_access = "private"(기본) | "public"` 변수 도입.
  - `private`(정석): vpce+SG 생성, capability가 vpce ID 직접 참조(위 구현 결정 그대로).
  - `public`(**테스트 전용 opt-in**): vpce/SG **미생성**(interface endpoint는 존재만으로 시간 과금),
    `network_access = null`, **check 경고 재도입**("테스트 전용 — 정식 환경 금지").
- 전환은 가역(update-capability, 위 가역성 항목) — 테스트 후 `private` 전환으로 정석 복귀.
- prd/실환경에서 `public`은 금지 — Sentinel/런북 게이트 소관(Task 20.8).

**소속 계정·경로 (2026-07-19 개정, 03 §3.1)**: 이 루트는 dev 환경 소속이 아니라 **GitOps hub**
(전 환경 공용)다 — CT 토폴로지에서 hub는 **CICD/shared-services 계정** 소속이 정석(management는
워크로드 금지). 경로를 `live/dev/eks-bootstrap` → **`live/cicd/gitops-hub`**로, TFC workspace를
`eks-bootstrap-dev` → **`gitops-hub-cicd`**로 개편. PoC는 workspace 변수(`workload_account_id`·
`eks_cluster_workspace`)로 **dev 계정에 바인딩해 테스트**한다(구조=목표 토폴로지, 바인딩=변수 —
03 §3.1). hub 이관 시 Capability는 재생성(IdC immutable·RETAIN, 열린 항목 9)이며 hub 계정에
hub용 EKS 클러스터가 전제된다.

**주의 — RETAIN teardown**: `delete_propagation_policy`는 RETAIN만 지원 → Capability destroy 시 관리
대상 k8s 리소스가 잔존한다. PoC는 gitops-hub destroy/re-apply 루프가 잦으므로, **최초 apply 전
1회 destroy→re-apply로 (a) 잔존 리소스 삭제 순서 (b) 동일 `capability_name` 재사용이 잔존물과
충돌하는지**를 실증하고 런북(Task 20.8)에 담는다. 또한 열린 항목 9에서 "중앙 Capability 1개"를
택하면 dev Capability를 management 계정으로 재구축해야 하는데, RETAIN 때문에 dev teardown이 orphan을
남겨 전환 비용이 커진다 — 두 결정의 상호작용을 열린 항목 9에 기록한다.

**exit / 가역성 (M-2)**: 관리형 이탈 시 대안 B(self-managed hub-spoke, EKS Blueprints 검증 패턴)로
회귀 가능하다. ArgoCD Application 트리는 GitOps 레포에 있어 provider 중립 → 전환 비용은
"self-managed ArgoCD 재설치 + Access Entry → cluster secret 재등록" 수준(파국적 lock-in 아님).

---

## 2.8 스포크 확장 등록 seam — 다중 클러스터/프로젝트 (2026-07-20 확정, D-SPOKE-SEAM)

> ralplan 합의(Planner→Architect→Critic, 2회차 APPROVE)로 확정. §2.7이 "Capability를 켜는" 방법이라면
> §2.8은 "그 허브에 스포크·프로젝트를 **확장 가능하게** 붙이는" 방법이다. 상세 GitOps 저장소 구조는
> [`30-gitops-repo.md`](30-gitops-repo.md)(D2), 열린 항목 10을 이 결정이 대체한다.
>
> **범위 경계(관심사 분리)**: 이 프로젝트는 계층 1(Terraform)·계층 2(플랫폼 GitOps)까지다. **app 워크로드
> GitOps(계층 3)는 범위 밖**(앱팀별 repo·CICD 소관) — 이 문서는 그 seam인 AppProject 가드레일까지만
> 정의한다. 3계층 소유 모델은 [`30-gitops-repo.md §0`](30-gitops-repo.md).

**문제**: §2.7 구현(`live/cicd/gitops-hub`)은 dev 단일 스포크를 전제로 `eks_cluster_workspace` **스칼라**
하나를 읽어 Capability를 켠다. stg/prd/신규 프로젝트가 늘 때 스포크 등록 경로(Access Entry + cluster
Secret)와 addon 팬아웃이 **부재**하다. 무엇을 어떻게 확장하는지 구조가 없으면 온보딩이 O(n) 복붙이 된다.

> **⭐ 2026-07-22 실측 보정 (구현 착수 전 게이트 — dev 클러스터 Access Entry 실물 조회)**
> `aws eks list-associated-access-policies`로 확인: **관리형 Capability가 hub 클러스터(=dev 자기 자신)에
> Access Entry + 배포 정책을 자동 완비**한다 — `iamr-poc-dev-an2-argocd`에 `AmazonEKSArgoCDClusterPolicy`
> (scope=cluster) + `AmazonEKSArgoCDPolicy`(scope=namespace `argocd`)가 Capability 생성 시 자동 부착됨.
> 이는 아래 원안(§2.8 D1)의 두 전제를 정정한다:
> - **① hub는 Terraform Access Entry에서 제외**: dev(=hub)에 `aws_eks_access_entry`를 또 만들면 auto
>   entry와 `ResourceInUseException` 충돌. Terraform은 **non-hub 스포크만** 관리(`managed_spokes` =
>   `spoke_clusters` 중 hub 클러스터 제외). PoC는 dev(hub) 하나뿐 → for_each **비어 있음**(메커니즘만
>   배치, 둘째 스포크부터 실효). §2.7 "dev 명시 등록" 및 line 698 주의("dev 자기 자신 포함 추가 구성 필요")는
>   이 실측으로 정정 — hub의 Access Entry·정책은 AWS 소유다.
> - **② 스포크 정책 = `AmazonEKSArgoCDClusterPolicy`**(원안 EditPolicy/ClusterAdmin 교체): AWS가 hub에
>   자동 적용하는 ArgoCD 전용 정책과 동일하게 스포크에도 적용(hub·스포크 일관성, ArgoCD 배포 목적 부합).
>   → 원안 D1의 EditPolicy 기본·ClusterAdmin opt-in·env≠dev validation은 **폐기**(ArgoCD 전용 정책은
>   범용 cluster-admin이 아니라 blast-radius 우려가 성격이 다름 — 최소권한은 정책 자체가 ArgoCD 스코프로 보장).
> - **③ `eks_cluster_workspace` 스칼라 존치**: hub cluster_name은 Capability(§2.7)가 tfe_outputs로 계속
>   읽는다(auto-managed hub의 정체성). spoke_clusters는 **대체가 아니라 non-hub 등록을 위한 가산**.
>   원안 "스칼라 대체"를 이 범위로 정정. cross-account 스포크의 provider aliasing은 stg 도입 시 follow-up.

> **⚠️ 2026-07-24 재확인 — 자동 부착 정책의 스코프가 `argocd` ns에 갇혀 있다 (addon 증분의 선결 과제)**
>
> 위 실측을 증분 B1 작성 시점에 재조회해 여전히 유효함을 확인했다(정책 2종, 2026-07-19 부착).
> 다만 **스코프를 다시 읽으면 다음 증분의 벽이 보인다**:
>
> | 정책 | 스코프 | 함의 |
> |---|---|---|
> | `AmazonEKSArgoCDClusterPolicy` | cluster | ArgoCD 전용 정책 — **이름과 달리 cluster-wide read-all이 아니다**(아래 실증) |
> | `AmazonEKSArgoCDPolicy` | **namespace `argocd` 한정** | **쓰기가 `argocd` ns 안에서만** 가능 |
>
> seed 3종(AppProject·cluster Secret·root Application)은 전부 `argocd` ns라 apply는 통과한다.
> `kubernetesGroups`는 **비어 있다**(2026-07-24 `describe-access-entry` 실측) — 이 principal의 RBAC은
> 전적으로 위 두 정책이 준다. 그런데 이 조합이 **부족하다는 게 seed 실행으로 실증됐다**(아래 정정).

> **⭐⭐ 2026-07-24 seed 실행 실증 — 예측 정정 + D-ARGOCD-CLUSTER-READ (열린 항목 신설)**
>
> bastion kubectl로 seed 3종을 실제 apply(sha256 바이트 동일 확인 후)하고 root App 상태를 조회한 결과,
> **위 "addon 증분에서 터진다"는 예측이 틀렸다.** 벽은 addon(쓰기)이 아니라 **cluster 등록 즉시(읽기)**
> 발현됐다:
>
> ```
> status.conditions[].type = ComparisonError / UnknownError
> clusterrolebindings.rbac.authorization.k8s.io is forbidden:
>   User ".../assumed-role/iamr-poc-dev-an2-argocd/{{SessionName}}"
>   cannot list resource "clusterrolebindings" ... at the cluster scope
> → sync.status = Unknown  (health = Healthy, revision = main)
> ```
>
> **원인**: ArgoCD는 등록된 클러스터의 live state를 **비교(compare)하기 위해 클러스터 전역의 모든 리소스
> 타입을 list**해야 한다(discovery·drift 탐지). `AmazonEKSArgoCDClusterPolicy`는 이름과 달리 이
> cluster-wide read-all(특히 `rbac.authorization.k8s.io/clusterrolebindings`)을 주지 않는다. 따라서
> **addon을 배포하기도 전에, 등록만으로 comparison이 실패**한다. 공식 문서
> ([argocd-register-clusters](https://docs.aws.amazon.com/eks/latest/userguide/argocd-register-clusters.html))가
> production setup에서 `argocd-read-all` ClusterRole(`apiGroups:['*'] resources:['*'] verbs:[get,list,watch]`)을
> **직접 만들라**고 한 것이 바로 이 공백을 전제한 것이다.
>
> **정정**: 위 "함의" 열의 "cluster 전역 읽기"는 실측으로 **거짓**이었다. `AmazonEKSArgoCDClusterPolicy`는
> ArgoCD가 배포·관리하는 리소스에 대한 정책이지 discovery용 read-all이 아니다.
>
> **✅ 이 실행으로 해소된 미실증 2건**: ① **쓰기** — 관리형 컨트롤플레인이 우리가 apply한 CR을 받아
> 저장(kubectl get으로 조회됨, §2.8·30 §4의 마지막 미실증). ② **CodeConnections repo pull** —
> `revision: main`으로 저장소를 실제로 읽음(커넥션 `AVAILABLE`이 이 저장소 접근으로 이어짐을 확인).
>
> **❌ 미완**: reconcile 루프(sync)는 cluster-wide read 부족으로 서지 못한다.
>
> > **⭐ D-ARGOCD-CLUSTER-READ (2026-07-24 확정)**: Capability role에
> > **`AmazonEKSAdminViewPolicy`(cluster 스코프) access policy association을 추가**한다.
> >
> > **후보 비교** — `kubernetesGroups: []`가 설계를 가른다(최소권한 ClusterRole을 만들어도 bind 대상
> > group이 없고 SessionName이 매 세션 랜덤이라 User로도 bind 불가):
> > | 안 | 방식 | 권한 | 평가 |
> > |---|---|---|---|
> > | A | `AmazonEKSClusterAdminPolicy` association | `* / * / *`(전권) | 간편하나 cluster-admin 과대권한 |
> > | B | Access Entry `kubernetesGroups` 추가 + `argocd-read-all` ClusterRole/Binding seed | read-all | ⚠️ auto-managed entry 수정→capability 되돌림 미검증, 복잡 |
> > | **✅ D** | **`AmazonEKSAdminViewPolicy` association** | **`* / * / get,list,watch`** | **최소권한 read-only + Terraform 1줄. group 불필요** |
> >
> > **채택 근거 (2026-07-24 문서 실측)**: `AmazonEKSAdminViewPolicy`의 RBAC rule은 정확히
> > `apiGroups:['*'] resources:['*'] verbs:[get,list,watch]` — AWS 공식 문서가 production setup에서
> > 만들라던 `argocd-read-all` ClusterRole과 **동일**하다. ArgoCD 권한 모델("cluster-wide **read** +
> > namespace-scoped **write**")에서 비어 있던 read 절반을 채운다. (A)의 간편함(association 1개)과
> > (B)의 최소권한(read-only)을 동시에 만족 — 3안을 실측으로 검토해 얻은 4번째 답이다.
> > `AmazonEKSViewPolicy`(표준 view)는 보안상 rbac 리소스를 제외해 `clusterrolebindings`를 못 읽으므로 부적합.
> >
> > **소유·구현**: `live/cicd/gitops-hub`에 `aws_eks_access_policy_association` 1개 추가
> > (principal=Capability role, cluster=hub, policy=AdminViewPolicy, scope=cluster). hub의 auto-managed
> > Access Entry는 그대로 두고 association만 얹는다 — Access Entry 자체를 Terraform이 만들지 않으므로
> > `ResourceInUseException` 무관(§2.8 hub 제외 원칙과 정합, association은 별개 리소스).
> >
> > **남는 층(별개 결정)**: ALBC를 `kube-system`에 배포하는 **쓰기**는 이 정책(read-only)이 못 채운다.
> > 그건 addon 증분에서 대상 ns 쓰기 정책을 별도 결정한다. 또한 30 §3 `clusterResourceWhitelist`(현재
> > `[]`)도 addon의 CRD/ClusterRole 배포 시 함께 열어야 한다 — read 권한과 project 화이트리스트는 별개 층.
> >
> > seed 3종은 무해하게 잔존(root App `Healthy`·`prune:false`) → 이 정책 apply 후 **selfHeal이 즉시
> > 재sync해 흡수 완료**된다.
> >
> > **✅ 2026-07-24 저녁 실증 완료** (`run-Ns8N5YrWoNwmuY7Q` applied, 1 to add):
> > association apply 후 에러가 `clusterrolebindings forbidden`(read) → `repository not found`(저장소)로
> > **넘어갔다** — cluster-wide read 벽이 해소되어 live state 비교를 통과했다는 직접 증거. 저장소 층까지
> > 뚫은 뒤 root App `Synced`/`Healthy`, `revision=1d1525b`. AdminViewPolicy 채택이 실물로 검증됐다.
> > **RBAC 전파 지연 주의**: association 생성(apply) 후 클러스터 authorizer 반영까지 시간차가 있어,
> > apply 직후 첫 reconcile은 여전히 forbidden일 수 있다. `kubectl annotate application <name>
> > argocd.argoproj.io/refresh=hard --overwrite`로 재비교를 강제할 수 있다(관리형이라 argocd CLI 없이 kubectl).
> >
> > **⚠️ 이 정책만으로는 부족한 층(저장소 접근)** — D-ARGOCD-CLUSTER-READ 해소 직후 드러난 다음 벽:
> > `repository not found: ProviderResourceNotFoundException`. CodeConnections 커넥션 `AVAILABLE`은
> > 계정↔GitHub 신뢰일 뿐 저장소 접근 보장이 아니다. **GitHub App(AWS Connector for GitHub)의 설치
> > 범위**에 대상 저장소를 사람이 추가해야 한다(github.com/settings/installations → Configure →
> > Repository access → 이 repo 추가/All). TFC VCS·ArgoCD JWT와 같은 수동 OAuth 게이트 계열 —
> > 30 §1 제약 1(콘솔 수동 승인)의 연장선이며 apply로 자동화 불가. 스포크 확장 시에도 각 저장소 접근은
> > 이 설치 범위가 개별 통제한다.

> **⭐ D-ARGOCD-CLUSTER-WRITE (2026-07-25 확정)** — ALBC 등 addon을 spoke(현 dev=hub 자기참조)의
> `kube-system`에 배포하는 **쓰기** 권한을 Capability role에 부여한다. read(D-ARGOCD-CLUSTER-READ)와
> **동일한 벽**을 만난다: hub의 Access Entry가 AWS auto-managed·`kubernetesGroups:[]`라 custom
> ClusterRole을 bind할 수 없어 **AWS 사전정의 access policy만** 얹을 수 있다.
>
> **결정: `AmazonEKSClusterAdminPolicy`(cluster 스코프) association 1개 추가** (A1).
>
> **근거 — 사전정의 정책의 스코프 한계**: ALBC helm은 cluster 스코프 리소스(CRD 2종
> `targetgroupbindings`·`ingressclassparams` · `ClusterRole`/`ClusterRoleBinding` ·
> `Validating`/`MutatingWebhookConfiguration`)를 만든다. 사전정의 정책 중 cluster 스코프 write를 주는
> 것은 `AmazonEKSClusterAdminPolicy`뿐이다 — `EKSEditPolicy`/`AdminPolicy`는 namespace 스코프라
> CRD·ClusterRole을 생성하지 못한다. read를 사전정의 `AdminViewPolicy`로 푼 것과 대칭이며, 같은
> auto-managed entry 제약(`kubernetesGroups:[]`)의 귀결이다.
>
> **후보 비교**:
> | 안 | 방식 | 스코프 | 평가 |
> |---|---|---|---|
> | **✅ A1** | `AmazonEKSClusterAdminPolicy` association | cluster | 사전정의 유일 커버·TF 1줄·GitOps 소유 온전. 과대권한(`*/*/*` write) |
> | A2 | `EKSEditPolicy`@kube-system + cluster 스코프 리소스는 Terraform/bastion 선설치(helm `rbac.create=false`) | ns | 최소권한이나 GitOps 소유 분절·CRD 버전 드리프트를 TF가 떠안음 |
>
> **A1 채택 사유(PoC)**: read 선례와 대칭이고 GitOps 소유를 분절하지 않는다. 과대권한은 PoC 수용.
>
> **⚠️ 과대권한의 정당한 해소는 "별도 TF-소유 spoke"다** (2026-07-25 hub-spoke 분리 논의): hub의
> auto-managed entry 제약이 A1을 강제하므로, 최소권한 write는 TF가 **직접 소유하는 spoke Access
> Entry**(`kubernetesGroups` + scoped ClusterRole)에서만 얻어진다. 워크로드 클러스터를 hub와 분리하는
> 트리거의 하나이며 §2.7 분리 트리거(열린 항목 9)에 연결한다. 그 전까지 self-spoke는 A1을 쓴다.
>
> **소유·구현**: `live/cicd/gitops-hub`에 `aws_eks_access_policy_association` 1개
> (principal=Capability role, cluster=hub, policy=ClusterAdminPolicy, scope=cluster). `hub_cluster_read`와
> 동일 패턴 — entry 미소유이므로 `ResourceInUseException` 무관.
>
> **함께 열어야 하는 별개 층 (30 §3)**: AppProject `platform`의 `clusterResourceWhitelist`(현 `[]`)에
> ALBC의 cluster 스코프 kind(CRD·ClusterRole·ClusterRoleBinding·webhook 2종)를 명시 추가한다. IAM→RBAC
> 쓰기(이 결정)와 ArgoCD project 가드레일은 **별개 층**이며 둘 다 열려야 한다.
>
> **검증 예정**: `AmazonEKSClusterAdminPolicy`가 CRD/ClusterRole create를 포함하는지 구현 직전 AWS
> 문서로 확정(AdminView를 문서 실측으로 확정한 절차와 동일). apply 후 RBAC 전파 지연 가능 → root App
> hard refresh(`kubectl annotate ... argocd.argoproj.io/refresh=hard`)로 재sync 실증.

### 핵심 원칙 (확장 축의 분해)
- **Capability는 fleet 싱글톤** — 클러스터가 늘어도 Capability는 늘지 않는다(hub-spoke의 존재 이유).
  늘어나는 것은 **스포크 등록 + 라벨**뿐이다. 새 허브는 분리 트리거(열린 항목 9) 충족 전까지 만들지 않는다.
- **확장 = O(1)** — 새 클러스터 = Access Entry 1 + 라벨 달린 cluster Secret 1 + `values/<c>.yaml` 1.
  addon ApplicationSet은 **불변**(cluster generator + matchLabels가 자동 팬아웃).
- **테넌시 = AppProject** — 관리형 ArgoCD는 Application이 **단일 namespace**(capability namespace)에만
  존재(OSS apps-in-any-namespace 미지원). 신규 프로젝트 격리는 네임스페이스가 아니라 **AppProject**
  (sourceRepos·destinations·roles)로 한다(열린 항목 9 Pattern 3 리서치 반영).

### ⭐ 결정: 등록 seam을 **도달성 경계로 분리** (D-SPOKE-SEAM)

**등록의 두 반쪽을 소유가 다른 두 곳에 둔다:**

| 아티팩트 | 소유 | 근거 |
|---|---|---|
| **Access Entry + access policy** (IAM grant) | **Terraform** (`live/cicd/gitops-hub`) | 순수 AWS 컨트롤플레인 — apiserver 불필요, TFC SaaS 러너에서 도달 가능. cross-account는 Access Entry만으로(신규 IAM trust 불필요, 공식). 최소권한·Sentinel 거버넌스의 올바른 위치 |
| **cluster Secret** (`argocd.argoproj.io/secret-type: cluster`, `server`=클러스터 **ARN**) | **GitOps 저장소** (ArgoCD가 reconcile) | reconcile되는 desired-state → pull 루프에 속함(self-healing). TF가 소유하면 드리프트를 다투고 self-heal 불가 |

**기각한 대안 — 등록 seam 전체를 TF에(kubernetes provider)**: **도달성 물리 제약으로 사실상 불가**.
TFC SaaS 러너는 public 인터넷, 클러스터는 `endpoint_public_access=false`(§3.1) → kubernetes provider가
**VPC 밖에서 private kube-apiserver에 도달 불가**(Cloud Agent 또는 public 노출 강제). 또한 §2.7이
**구조적으로 소거한** helm/kubernetes provider를 되살려 fleet-wide cluster Secret을 `for_each`로 관리 →
provider 격리가 "구조"에서 "규율"로 격하. 분리안이 오히려 pull 모델에 **더 정합**하다.

> **§2.7 provider 격리 문장 정정**: §2.7 M-2·구현 주석의 "provider 격리 고민 자체가 소거됨"은
> **Capability 활성화 경로에 한한다**. 부트스트랩 seed(아래)에 한해 **단 하나의 root Application**을 위한
> 제한적 provider 사용은 이 결정의 예외로 허용될 수 있으며, 이는 "ArgoCD 자체를 helm으로 관리"와
> 질적으로 다르다(범위: Secret 한 줌이 아니라 root App 1개). 최종 방식은 V1~V3로 확정한다.

### 잔여 부트스트랩(치킨-에그) — root Application 1개

cluster Secret이 GitOps 소유여도, **그 Secret들을 담은 저장소를 가리키는 최초 root Application**(App-of-Apps)을
누가 심느냐가 남는다. **구현 전 검증 게이트 V1~V3로 확정**한다(설계 승인 ≠ 코드 착수):

| 게이트 | 검증 대상 | 방법 | 결과에 따른 분기 |
|---|---|---|---|
| **V1** | `awscc_eks_capability`에 네이티브 bootstrap/root-repo 필드? | `get_provider_details` (providerDocID 12861162) | ✅ **완료(2026-07-20): NEGATIVE**. 스키마는 `aws_idc`·`namespace`·`network_access`·`rbac_role_mappings` 4개뿐 — 네이티브 seed 불가. 외부 행위자 필요 |
| **V2** | cluster Secret namespace 물리 위치·외부 도달성 | 실물(`server_url`에 ArgoCD API/CLI vs 허브 `argocd` ns kubectl) | ArgoCD **API/CLI(`argocd cluster add`·`app create`)는 `server_url`에 대고** 동작 — `server_url`은 public/vpce로 **도달 가능**(kube-apiserver와 다름). kubectl 경로만 apiserver 필요 |
| **V3** | TFC 러너 → 대상 도달성 | 네트워크 경로 | ArgoCD-API 경로 채택 시 V3 **우회 가능**(server_url 도달). kubectl 경로면 Cloud Agent 필요 |

**V1 NEGATIVE의 함의(2026-07-20)**: Capability 자가 seed는 없다. 남은 후보는 우선순위대로 —
(1) **ArgoCD API/CLI로 `server_url`에 root App·로컬 cluster Secret seed**(도달성 우위 — V3 우회, provider
재도입 없음), (2) **1회성 kubernetes provider가 root App 1개만**(Cloud Agent 전제, `lifecycle`
`ignore_changes`, `bootstrap=true` 게이트), (3) 수동 kubectl 런북. V2로 (1)의 실효성을 확정한다.

> **⭐ 2026-07-24 V2·V3 재판정 — 후보 (1) 기각, (3) 채택 (D-SEED-KUBECTL)**
>
> 위 우선순위는 **"apiserver에 도달할 수 없다"는 전제** 위에 세워졌다. 40-bastion(2026-07-23 배포)이
> 그 전제를 없앴다 — 전제가 바뀌었으므로 결론도 바뀐다. 순위가 **역전**된다.
>
> **V2 확정 — kubectl 경로가 정식 경로다**(공식 문서 근거):
> - `Working with Argo CD` **Prerequisites**에 `kubectl` configured to communicate with your cluster.
> - 클러스터 등록 = `argocd` 네임스페이스의 Secret을 **`kubectl apply -f cluster-secret.yaml`**.
> - AppProject·Application·ApplicationSet도 전부 **capability 네임스페이스(`argocd`)의 CR**이며,
>   관리형 컨트롤플레인이 이를 watch한다(단일 네임스페이스만 지원 — OSS의 apps-in-any-namespace 미지원).
>   즉 seed 대상 4종이 모두 kubectl로 apply 가능한 선언적 매니페스트다.
>
> **후보 (1)(ArgoCD API/CLI) 기각 — 인증이 UI에 종속**: 관리형 Capability의 CLI 인증은 `--sso`가 아니라
> **JWT 토큰**뿐이고, 발급 경로가 둘 다 UI를 선행 요구한다 — ① AppProject role JWT(UI Settings →
> Projects → Roles → JWT Tokens), ② admin account token(동시 5개·만료 12시간 권장). private 전환 후
> UI는 bastion 포트포워딩 없이 도달 불가(40 §9-3)이므로 **"UI를 보려면 seed가 필요한데 seed하려면
> UI가 필요한"** 새 치킨-에그가 생긴다. 게다가 토큰 발급은 자격증명 생성이라 승인 대상이다(40 §9-4).
>
> **채택 (3) 수동 kubectl 런북 — 다만 "수동"의 성격이 다르다**: bastion은 임시방편이 아니라 설계된
> 상시 관리 지점이고(40 §1), IAM(Access Entry)만으로 인증된다 — ArgoCD 자체 인증 체계(IdC→UI→JWT)를
> **통째로 우회**한다. 신규 자격증명이 생기지 않는 것이 이 경로의 가장 큰 이점이다.
>
> **V3 무의미화**: V3는 "TFC 러너 → 대상 도달성"을 묻는다. seed 수행자가 TFC 러너가 아니라
> **bastion(사람)** 으로 확정되었으므로 이 게이트는 성립하지 않는다. Cloud Agent 도입 검토도 함께 종결한다.
> 후보 (2)(1회성 kubernetes provider)는 §2.7 provider 격리를 되살려야 하는데, 그 예외를 허용할 이유가
> 사라졌으므로 **함께 기각**한다 — 위 "provider 격리 문장 정정"의 예외 조항은 발동되지 않는다.
>
> **seed의 자기소멸 원칙(중요)**: bastion이 손으로 apply하는 매니페스트는 **GitOps 저장소에 있는 것과
> 바이트 단위로 동일**해야 한다. 그래야 root App이 첫 sync에서 그것을 자기 소유로 흡수(adopt)하고
> 즉시 no-op이 된다. seed는 저장소 콘텐츠의 **사본**이지 별개 아티팩트가 아니다 — 이 원칙이 깨지면
> seed 산출물이 영구 드리프트로 남는다. 상세 절차는 [`30-gitops-repo.md §4`](30-gitops-repo.md).
>
> **⭐ 2026-07-24 실측 — 읽기 경로 확인(가정의 절반 실증)**: bastion kubectl로 hub `argocd` 네임스페이스를
> 조회한 결과 —
> - CRD 3종(`applications`·`applicationsets`·`appprojects`)이 **클러스터에 설치**되어 있다.
> - `default` AppProject가 **CR로 존재**한다(생성 시각 = capability 생성 시각).
> - 네임스페이스 `argocd`의 `managedFields`에 **`manager: eks-capability`** 가 찍혀 있다 —
>   **관리형 컨트롤플레인이 클러스터 밖에서 돌면서 클러스터 k8s API에 직접 쓴다**는 직접 증거다.
>   우리가 kubectl로 CR을 쓰는 것은 AWS가 이미 쓰고 있는 그 인터페이스에 얹는 것이다.
> - 파드는 0개(`get pods -n argocd` 비어 있음) — **제어는 밖, 상태는 안**이라는 관리형의 구조가 실물로 확인.
>
> **남은 미실증(쓰기)**: 우리가 apply한 CR을 컨트롤플레인이 실제로 reconcile하는지. 권한(ClusterAdmin)과
> 인터페이스 존재는 확인됐으므로 잔여 위험은 낮으나, 실제 seed 수행 전까지 "확인됨"으로 쓰지 않는다.

### 인터페이스 확장 (D1 — `live/cicd/gitops-hub`)
- **`spoke_clusters`** 변수: `map(object({ account_id, region, cluster_name, labels = map(string), access_policy, cluster_admin_optin = bool }))`.
  스칼라 `eks_cluster_workspace`를 대체. **dev = 자기 자신을 맵의 한 항목으로 명시 등록**(공식: 로컬
  클러스터도 명시 등록 필요 — §2.7 "dev 단일 cluster Secret 불필요"를 **PoC 범위에서 정정**, stg 이연 아님).
- **맵 population = 큐레이션 tfvars 맵**(O(1) HCL). 클러스터 ARN은 **네이밍 규약으로 합성**
  (04 §조회 "네이밍 우선" — 스포크마다 `tfe_outputs`+alias를 거는 O(n) 연동 회피).
- **`for_each aws_eks_access_entry`**: `principal_arn = aws_iam_role.argocd_capability.arn`
  (**허브 Capability role — ApplicationSet cluster generator가 스포크에 배포하는 인증 체인의 핵심**),
  `type = "STANDARD"`.
- **`for_each aws_eks_access_policy_association`**: 기본 **`AmazonEKSEditPolicy` namespace-scoped**(공식
  production setup). `AmazonEKSClusterAdminPolicy`(=system:masters)는 **`cluster_admin_optin=true` +
  `env=dev`일 때만** — `validation` 블록이 env≠dev의 cluster-admin을 **plan 시점 거부**한다.
  이 validation이 **구체 게이트**다(Sentinel은 미래 보강일 뿐, 현 완화책 아님 — Sentinel은 "예정" 상태).

> **⚠️ 2026-07-24 발견 — hub 등록 계약 누락(미구현 gap)**
>
> 실측 보정 ①로 hub는 `managed_spokes`에서 제외되는데, `outputs.tf`의 `spoke_registrations`가
> `managed_spokes`를 순회한다. 그 결과 **hub(dev)의 cluster Secret이 쓸 `server`(ARN)·`labels` 소스가
> 어디에도 없다**. 그런데 hub 클러스터도 cluster Secret은 필요하다 — 2026-07-23 실물 조회에서 등록된
> clusters **0건**으로 확인됐다(관리형 Capability가 자동 완비하는 것은 **Access Entry와 정책**이지
> cluster Secret이 아니다). 이대로면 dev cluster Secret의 라벨을 사람이 손으로 적게 되고, 이는
> pre-mortem 3(**라벨 표류 → addon 팬아웃 누락, 무증상 실패**)에 정확히 노출된다.
>
> **방향**: Access Entry는 계속 hub를 제외하되(중복 생성 시 `ResourceInUseException`), **등록 계약
> (server ARN + labels)은 hub도 내보낸다**. IAM grant와 등록 메타데이터는 애초에 다른 관심사이며,
> 이를 분리하는 것이 D-SPOKE-SEAM의 "도달성 경계로 분리"와 정합한다. 구현(output 확장)은 GitOps
> 저장소 콘텐츠 착수(증분 B1)와 함께 진행한다 — 소비자가 없는 상태에서 output만 먼저 만들지 않는다.

### 최소권한 근거 (Decision Driver 2 — blast radius)
공식 경고: `AmazonEKSClusterAdminPolicy`는 프로덕션 금지. 허브 Capability role이 전 계정 cluster-admin이면
**단일 role 유출 = fleet 전체 장악**. 완화는 "하나의 넓은 grant 공유"가 아니라 **스포크별 별도 Access
Entry**(`for_each`가 제공) + namespace/AppProject-scoped policy + (미래)Sentinel.

### Pre-mortem
1. **cluster-admin 은밀 확산** → scoped 기본 + dev-only validation(위).
2. **부트스트랩 교착** → 결정적 순서 `TF(Access Entry) → cluster Secret(GitOps) → root App` + V1~V3.
3. **라벨 표류 → addon 누락(무증상)** → 라벨은 TF 맵이 생성(수기 금지) + ApplicationSet 필수라벨 assertion.
4. **IdC 조직 인스턴스 전제** → 중앙 허브는 org IdC 필요(immutable). stg 온보딩 전 미완이면 fleet 확장
   차단(열린 항목 9). Capability 생성 후 IdC 바인딩 변경 불가.
5. **고아 Secret + Access Entry 제거 = 은밀한 스포크 단절** → 맵에서 스포크 제거 시 Entry는 삭제되나
   GitOps 소유 Secret은 잔존 → ArgoCD가 DISCONNECTED로 표시(무증상 성공 아님). 검증 5·teardown 런북.
6. **dev→중앙 허브 전환 시 RETAIN 고아 누적** → 전환 주기마다 orphan 누적(§2.7 M-1) → 확장 전 정리 런북.

### 확장 검증 (구현 단계 이관 — 문서 게이트 + 실증)
1. Access Entry principal = Capability role ARN (`aws eks list-access-entries`).
2. cluster Secret → 스포크 **CONNECTED**(≠UNKNOWN), 5분 게이트.
3. ApplicationSet 팬아웃: `matchLabels{env:dev}` → dev 앱 생성. 둘째 라벨 Secret 추가 → 앱 자동 생성.
4. AppProject 격리 부정 테스트: project-A → project-B namespace 배포 **DENIED**.
5. RETAIN + Access Entry 제거 부정 테스트: 맵에서 스포크 제거 → Entry 삭제·Secret 잔존·ArgoCD DISCONNECTED.
6. plan-time no-op: D1 추가 후 `terraform plan`(gitops-hub) = 기존 리소스 **0 변경**(dev 단일 항목 무변화).
7. 문서 정합: [`30-gitops-repo.md`](30-gitops-repo.md) addon 목록 == §1 경계 표(명시 diff).

**ADR 요약 (D-SPOKE-SEAM)** — Decision: 등록 seam을 도달성 경계로 분리(TF=IAM grant, GitOps=cluster
Secret). Drivers: 확장 O(1)·blast radius·부트스트랩 무결성. Alternatives: 전체 TF(도달성 불가·격리 격하,
기각) / 순수 GitOps+수동 seed(취약, V1~V3로 대체). Consequences: 새 클러스터=Access Entry+라벨 Secret+values,
provider 격리 보존, 로컬 등록 PoC 정정, root App seed는 V1~V3 의존. Follow-ups: V2·V3 실증 → 코드.

---

## 3. 인터페이스

### 3.1 variables
```hcl
variable "naming" { type = object({ workload = string, env = string, region_code = string }) }
variable "purpose"            { type = string default = "main" }
variable "serial"             { type = string default = "01" }
variable "kubernetes_version" { type = string default = "1.35" } # N-1 전략 (2026-07-18: 최신 1.36의 한 단계 아래)
variable "vpc_id"             { type = string }
variable "subnet_ids"         { type = list(string) }                # 노드·컨트롤플레인 ENI — node-uniq (§2.5)

variable "enable_custom_networking" { type = bool default = true }   # D9 전제 — vpc-cni custom networking
variable "pod_subnet_ids"     { type = list(string) default = [] }   # Pod ENIConfig 대상 — pod-dup (§2.5)
# AZ 매핑은 모듈 내부에서 data.aws_subnet으로 해석 (입력은 ID 리스트로 단순 유지)

variable "endpoint_public_access"  { type = bool default = false }   # GitOps(pull) 전제 → 기본 private
variable "endpoint_private_access" { type = bool default = true }
variable "public_access_cidrs"     { type = list(string) default = [] }

variable "managed_node_groups" {                                     # 시스템 계층 NG
  type = map(object({
    instance_types = list(string)
    min_size = number, max_size = number, desired_size = number
    capacity_type = optional(string, "ON_DEMAND")
    labels = optional(map(string), {})
    taints = optional(list(object({ key=string, value=string, effect=string })), [])
  }))
  default = {}
}
variable "cluster_addons" {                                          # aws_eks_addon 경계 — §2.6 C′
  type = map(object({                                                # baseline과 merge되는 증분/override
    enabled       = optional(bool, true)                             # 제거는 명시적으로만 (core 4종은 validation 차단)
    addon_version = optional(string)
    configuration = optional(string)
    pod_identity = optional(object({                                 # → upstream pod_identity_association 번역
      role_arn        = string
      service_account = string
    }))
  }))
  default = {}                                                       # 빈 map = baseline 6종 상속 (§2.6)
}
variable "access_entries"      { type = any  default = {} }          # aws-auth 대체
variable "enable_pod_identity" { type = bool default = true }
variable "enable_karpenter"    { type = bool default = true }
variable "tags"                { type = map(string) default = {} }
```
> `cluster_name`은 `naming`+`purpose`+`serial`로 모듈 내부 합성(`eks-${mid}-${purpose}-${serial}`). 직접 문자열 주입도 허용하려면 `cluster_name` 옵션 변수 추가 가능.

### 3.2 outputs (bootstrap/GitOps 소비)
```hcl
output "cluster_name" {}                         output "cluster_endpoint" {}
output "cluster_certificate_authority_data" {}   output "cluster_oidc_issuer_url" {}
output "oidc_provider_arn" {}                     output "cluster_security_group_id" {}
output "node_security_group_id" {}               output "cluster_version" {}
# Karpenter (GitOps가 cluster secret annotation으로 소비)
output "karpenter_iam_role_arn" {}               output "karpenter_node_iam_role_arn" {}
output "karpenter_node_iam_role_name" {}         output "karpenter_instance_profile_name" {}
output "karpenter_sqs_queue_name" {}             output "karpenter_discovery_tag" {}
```

---

## 4. 구현 계획

> REQUIRED SUB-SKILL: superpowers:executing-plans

### Task 20.0: 선행 — 클러스터명 확정 + networking 태그 주입 (§2.5)
- 클러스터명 `eks-poc-dev-an2-main-01` 확정 → TFC `networking-dev` workspace 변수
  `eks_cluster_name` 설정 → 재plan/apply (서브넷 태그 in-place 추가, 재생성 없음).
- 같은 시점에 node-uniq 그룹 `extra_tags`에 `karpenter.sh/discovery` 태그 추가 검토(열린 항목 4).

### Task 20.1: ⚠️ upstream 실물 확인 (리스크 게이트)
**(a) Karpenter 서브모듈 I/O** — `terraform-aws-modules/eks//modules/karpenter` 21.24.0의 **실제 출력명** 확정 후 코드 작성.
- Registry: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/21.24.0/submodules/karpenter
- 확인 대상: 컨트롤러 IAM role ARN, node IAM role ARN/name, instance profile name, SQS queue name
- 예상값(`iam_role_arn`, `node_iam_role_arn`, `node_iam_role_name`, `instance_profile_name`, `queue_name`) — **반드시 실물 대조**, 결과를 main.tf 상단 주석에 기록.

**(b) vpc-cni addon configuration schema** — custom networking(§2.5) 구성 경로 확정.
- `aws eks describe-addon-configuration --addon-name vpc-cni --addon-version <핀 버전>`으로
  `env.AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG`·`eniConfig`(create/subnets)·`ENABLE_PREFIX_DELEGATION` 지원 확인.
- `eniConfig` 미지원 시 §2.5의 fallback(bootstrap에서 ENIConfig + NG 롤링) 설계로 전환하고 이 문서를 개정.
- upstream eks 모듈의 addon `before_compute` 지원 여부도 함께 확인(get_module_details).

### Task 20.2: versions.tf + variables.tf (facade)
**Files:** Create `modules/eks-cluster/versions.tf`, `variables.tf` (§3.1)
- versions: `required_version >= 1.14.0`, `aws >= 6.0`
- Commit: `feat(eks-cluster): facade 인터페이스 정의`

### Task 20.3: main.tf — upstream 연동 + 네이밍 번역
**Files:** Create `modules/eks-cluster/main.tf`
```hcl
locals {
  name_mid     = "${var.naming.workload}-${var.naming.env}-${var.naming.region_code}"
  cluster_name = "eks-${local.name_mid}-${var.purpose}-${var.serial}"  # eks-poc-prd-an2-main-01
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.0"                          # 정확 핀

  name               = local.cluster_name      # facade: 내부 name으로 번역
  kubernetes_version = var.kubernetes_version
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids

  endpoint_public_access       = var.endpoint_public_access
  endpoint_private_access      = var.endpoint_private_access
  endpoint_public_access_cidrs = var.public_access_cidrs

  enable_cluster_creator_admin_permissions = true
  access_entries                           = var.access_entries

  # §2.5: enable_custom_networking이면 vpc-cni 항목에 configuration_values를 모듈이 합성·병합 —
  #   env(AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true, ENI_CONFIG_LABEL_DEF=topology.kubernetes.io/zone,
  #   ENABLE_PREFIX_DELEGATION=true) + eniConfig(AZ→var.pod_subnet_ids, SG=node SG), before_compute=true.
  #   정확한 스키마 키는 Task 20.1(b) 확인 결과를 따른다.
  addons = { for k, v in var.cluster_addons : k => {
    addon_version        = v.addon_version
    configuration_values = v.configuration
  }}
  eks_managed_node_groups = { for k, v in var.managed_node_groups : k => {
    instance_types = v.instance_types
    min_size = v.min_size, max_size = v.max_size, desired_size = v.desired_size
    capacity_type = v.capacity_type, labels = v.labels, taints = v.taints
  }}
  tags = var.tags
}

module "karpenter" {                            # IAM 전제조건만 (helm/NodePool은 GitOps)
  count   = var.enable_karpenter ? 1 : 0
  source  = "terraform-aws-modules/eks/aws//modules/karpenter" # ⚠ registry 주소는 provider(/aws) 필수
  version = "21.24.0"
  cluster_name                    = module.eks.cluster_name
  create_pod_identity_association = var.enable_pod_identity # v21엔 enable_pod_identity 변수 없음(Pod Identity 기본) — Task 20.1(a) 확인
  tags = var.tags
}
# 추가 확인(Task 20.1): NG taints는 upstream이 map(object) — facade list를 인덱스 키 map으로 변환
```
- 검증: `terraform -chdir=modules/eks-cluster fmt && init -backend=false && validate` → `Success!`
- Commit: `feat(eks-cluster): eks v21.24.0 + karpenter 연동(facade) + 네이밍`

### Task 20.4: outputs.tf (Task 20.1 확정 출력명 사용)
**Files:** Create `modules/eks-cluster/outputs.tf` (§3.2)
- karpenter_* 는 `try(module.karpenter[0].<확정명>, null)`
- `karpenter_discovery_tag = { "karpenter.sh/discovery" = local.cluster_name }`
- Commit: `feat(eks-cluster): cluster/karpenter 출력 계약`

### Task 20.5: native 테스트
**Files:** Create `modules/eks-cluster/tests/plan.tftest.hcl`
```hcl
mock_provider "aws" {}
variables {
  naming         = { workload = "poc", env = "prd", region_code = "an2" }
  vpc_id         = "vpc-000"
  subnet_ids     = ["subnet-node-a", "subnet-node-c"]        # node-uniq 2AZ (§2.5)
  pod_subnet_ids = ["subnet-pod-a", "subnet-pod-c"]          # pod-dup 2AZ
  managed_node_groups = { system = { instance_types=["m6i.large"], min_size=2, max_size=3, desired_size=2 } }
}
# 추가 assertion: enable_custom_networking=true면 addons["vpc-cni"].configuration_values에
# CUSTOM_NETWORK_CFG가 포함될 것 (Task 20.1(b) 스키마 확정 후 구체화)
run "facade_and_naming" {
  command = plan
  assert {
    condition     = module.eks.cluster_name == "eks-poc-prd-an2-main-01"
    error_message = "cluster_name이 포맷대로 upstream name에 전달되어야 한다"
  }
}
run "karpenter_default_on" {
  command = plan
  assert { condition = length(module.karpenter) == 1
           error_message = "enable_karpenter 기본 true면 karpenter 생성" }
}
```
- Run: `terraform -chdir=modules/eks-cluster test`
- Commit: `test(eks-cluster): facade/네이밍/karpenter plan 검증`

### Task 20.6: live/dev/eks-cluster 루트 (tfe_outputs로 networking 소비)
**Files:** Create `live/dev/eks-cluster/*` (TFC workspace `eks-cluster-dev`, Working Directory 바인딩)
```hcl
data "tfe_outputs" "networking" {
  organization = var.tfc_organization      # born2k
  workspace    = var.networking_workspace  # networking-dev
}
module "eks" {
  source  = "../../../modules/eks-cluster"
  naming  = { workload = var.workload, env = var.env, region_code = var.region_code }
  purpose = "main"

  vpc_id         = data.tfe_outputs.networking.values.vpc_id
  subnet_ids     = data.tfe_outputs.networking.values.subnet_ids_by_group["node-uniq"] # §2.5
  pod_subnet_ids = data.tfe_outputs.networking.values.subnet_ids_by_group["pod-dup"]   # §2.5

  managed_node_groups = { system = { instance_types=["m6i.large"], min_size=2, max_size=4, desired_size=2 } }
  enable_karpenter    = true
}
# providers.tf에 default_tags(02 §1.4a) / outputs.tf에 cluster_*·karpenter_* 재노출
```
- Commit: `feat(live): eks-cluster-dev 루트 + tfe_outputs 연동 (node-uniq/pod-dup 소비)`

### Task 20.7: live/cicd/gitops-hub 루트 (ArgoCD via EKS Capability) — §2.7
**Files:** Create `live/cicd/gitops-hub/*` (TFC workspace `gitops-hub-cicd`, Working Directory 바인딩)
> 경로·워크스페이스는 2026-07-19 개정(§2.7 "소속 계정·경로") — 최초 구현은 `live/dev/eks-bootstrap`
> (`eks-bootstrap-dev`)이었고 apply 전에 이동했다.
- eks-cluster 출력(`cluster_name`, `oidc_provider_arn`)을 `tfe_outputs`로 소비(§3.2).
- **provider**: `awscc`(`~> 1.93.0`, 패치 핀) 추가. **helm/kubernetes provider 불필요** — 관리형이라
  클러스터 내 ArgoCD 설치가 없다(D-ARGOCD로 provider 격리 고민 자체가 소거됨).
- 리소스:
  - Capability IAM role `iamr-poc-dev-an2-argocd`(EKS 서비스 프린시펄 신뢰 + 최소권한, §2.7).
  - `awscc_eks_capability`(type="ARGOCD", `cluster_name`, `role_arn`,
    `delete_propagation_policy="RETAIN"`, `configuration.argo_cd = { namespace,
    network_access.vpce_ids, (선택) aws_idc·rbac_role_mappings }`). **awscc는 default_tags 미지원 →
    거버넌스 태그 5종을 `tags` 리스트로 명시 주입**(§2.7 H-1). `capability_name = "argocd"` 고정.
  - private 접속용 VPC endpoint — `aws_vpc_endpoint`(Interface, `com.amazonaws.<region>.eks-capabilities`,
    ep-uniq 2AZ 배치) + 전용 SG(inbound 443, VPC 대역). capability가 vpce ID를 직접 참조(§2.7 H-2 해소 확정).
  - **rbac 매핑**: `aws_idc = { idc_instance_arn(변수), idc_region="us-east-1"(cross-region) }`,
    `rbac_role_mappings = [{ role="ADMIN", identities=[{ id=<그룹 ID>, type="SSO_GROUP" }] }]`.
    그룹 ID는 하드코딩하지 말고 **`data "aws_identitystore_group"`(display_name="argocd-admins")로
    조회**해 주입(개인·환경 고유 ID를 코드에 박지 않음). ※ IdC 사용자·그룹·멤버십은 팀테스트 계정에서
    사전 생성됨(2026-07-18, CLI 1회성) — 실환경 CT는 조직 IdC/SCIM 소관이라 이 단계 불필요.
- ✅ **(b) VPC endpoint 서비스명·SG 확정 — HARD GATE 해소(2026-07-19)**: 서비스명
  `com.amazonaws.<region>.eks-capabilities`·SG(443)·ep-uniq 배치 확정, vpce 직접 참조로 코드화
  (§2.7 "H-2 해소 확정" 블록 참조).
- ⚠️ 착수 전 확인(리스크 게이트):
  - (a) ARGOCD Capability role 최소권한 정책 실물(공식 문서/`aws eks`).
  - (c) `vpce` 약어 카탈로그(A.1) 등재 여부 — 미등재 시 거버넌스 리뷰 후 사용.
  - (d) **awscc provider가 TFC OIDC dynamic credentials로 인증되는지** 빈 plan 1회로 실증
    (02 §4 변수 세트는 aws용 — awscc 자동 커버 보장 없음, §2.7 M-3).
  - (e) **관리형 Capability가 ApplicationSet CR을 지원하는지** — spoke별 addon 버전·values 자유도의
    전제(§2.7 hub-spoke). ApplicationSet(cluster generator + 클러스터 라벨)이 있어야 spoke마다 다른
    버전/구성을 선언할 수 있다. 미지원이면 per-spoke 자유도 확보 방안을 재설계.
  - (f) **spoke 메타데이터 참조 경로** — 구모델(01 §4.3)의 cluster secret annotation seam이 관리형
    Capability에서 무엇으로 대체되는지 확인(열린 항목 10).

**게이트 실증 결과 (2026-07-18, 공식 문서 대조)** — 출처: EKS 사용자 가이드
`argocd-considerations.html` · `argocd-applicationsets.html` · `create-argocd-capability.html`
(docs.aws.amazon.com/eks/latest/userguide/):
- ✅ **(e) ApplicationSet 지원** — List·**Cluster**·Git·**Matrix**·Merge generator 전부 지원. cluster
  generator의 `matchLabels`/`matchExpressions` 필터 + Helm `parameters`/values로 **spoke마다 다른
  버전·구성 선언 가능**(앞서 논의한 per-spoke 자유도 확정). OSS ArgoCD 대비 문서화된 제약 없음.
- ✅ **(f) 메타데이터 seam = cluster Secret** — spoke 등록은 `argocd` 네임스페이스의 k8s Secret
  (`argocd.argoproj.io/secret-type: cluster`, `server` = **EKS 클러스터 ARN**, API URL 아님) + 대상
  클러스터의 Access Entry(capability role principal). ~~**PoC(dev 단일)에선 cluster Secret 불필요**
  (Capability 자기 클러스터가 기본 대상)~~ → **정정됨**: §2.8이 이미 "로컬도 명시 등록 필요"로 뒤집었고,
  **2026-07-24 실측으로 확정**(hub `argocd` ns에 cluster-type Secret **0건** — Capability가 자동 완비하는
  것은 Access Entry와 정책이지 cluster Secret이 아니다). fleet 단계 cluster Secret 생성 주체
  (kubernetes provider vs GitOps)는 **D-SPOKE-SEAM으로 확정**(GitOps 소유) → 열린 항목 10 종결.
- ✅ **(a) IAM role** — 기본(**인증 없는 public Git**)은 **신뢰 정책 외 추가 정책 불필요**.
  CodeCommit 사용 시 `codecommit:GitPull`, Secrets Manager 사용 시 관리형
  `AWSSecretsManagerClientReadOnlyAccess`. 최소권한 = 용도별 가산.
  ⚠️ **2026-07-24 정정**: 원문은 CodeConnections도 "추가 정책 불필요"에 포함했으나 **틀렸다** —
  `codeconnections:UseConnection`·`GetConnection`이 필요하다(§2.7 정정 블록).
- ✅ **(b) private** — 두 평면 구분: **Capability→대상 클러스터** 배포는 private 클러스터라도 **AWS가
  연결 자동 처리**(VPC peering 불필요). **ArgoCD 서버 UI/API**만 기본 public → private화하려면
  `network_access.vpce_ids` 필요(§2.7 H-2 HARD GATE 유효).
- ✅ **IdC 인스턴스 실물 확인**(aws-api `sso-admin list-instances`, 2026-07-18) — ACTIVE 인스턴스 존재.
  **IdC는 us-east-1, 클러스터는 ap-northeast-2 → cross-region**: `aws_idc.idc_region = "us-east-1"`로
  지정(클러스터 리전 아님 — 함정). `idc_instance_arn`은 변수/데이터소스로 주입(하드코딩 금지).
- ⛔ **IdC 필수 확정**(argocd-create-cli.html Prerequisites, 2026-07-18): "Argo CD requires AWS Identity
  Center for authentication. Local users are not supported." **지원되는 생성 방법은 IdC 필수이며 예외
  없음** — awscc `aws_idc`가 스키마상 optional이어도 실질 필수(생략 시 인증 경로 부재로 UI·RBAC 무력).
  공식 create-capability 예제도 전부 `awsIdc`+`rbacRoleMappings` 포함. **IdC 접근 불가 시 → §2.7 exit
  (옵션 B self-managed ArgoCD, 로컬/Dex/임의 OIDC 인증 지원)로 전환**이 유일한 대안.
- ✅ **IdC 연결 권한·인스턴스 유형 실증**(aws-api `identitystore`, 2026-07-18): user/group 열람 권한
  확인, rbac 매핑 대상(그룹 1 + 사용자 2 ENABLED) 존재. **단 이 IdC는 "계정 인스턴스"**(permission set
  미지원 = 단일 계정 앱 인증 전용). **EKS Capabilities는 계정 인스턴스 지원 확인**(awsapps-that-work-
  with-identity-center: EKS Capabilities = account instance Yes) → **PoC(dev 단일) 생성 가능**. rbac은
  개인 대신 **그룹 매핑** 권장(PII·운영성). ⚠️ **fleet 함의**: 계정 인스턴스는 다중 계정 미지원 →
  "중앙 Capability로 여러 계정 관리" 시 **조직 인스턴스 필요**(열린 항목 9). IdC 인스턴스는 Capability
  생성 후 **변경 불가**(immutable) — 최초 지정 신중.
- ✅ **(c) `vpce` 카탈로그 등재** — 확인됨(aws-naming-abbreviations.md: `vpce` 엔드포인트, `iamr` 역할).
- ✅ **(d) awscc TFC OIDC 실증 완료**(2026-07-19, run-kCS34XuG5ZbMzYap): push 후 TFC plan에서
  `data.awscc_eks_clusters.canary` Refresh 성공(1s) — awscc provider가 TFC OIDC dynamic credentials로
  plan-time Cloud Control API 호출 확인. canary data source는 목적 달성으로 제거.
- ℹ️ **Access Entry 주의** — Capability 생성 시 role에 baseline k8s 권한 Access Entry가 **자동** 생성되나
  이는 배포 권한이 아님. 대상 클러스터(dev 자기 자신 포함)에 배포하려면 **RBAC/Access Entry 추가 구성** 필요.

- 상세 GitOps 레포 구조(App-of-Apps/ApplicationSet, ingress/cert-manager 매니페스트)는 **별도 GitOps
  저장소** 소관([01 §8](../architecture/01-module-strategy.md), 열린 항목 1). 이 태스크는
  Capability 활성화 + spoke(dev 자기 자신) 등록까지.
- Commit: `feat(live): eks-bootstrap ArgoCD via EKS Capability(hub-spoke seam)`

### Task 20.8: TFC 런북
**Files:** Create `docs/runbooks/tfc-workspace-run-trigger-setup.md`
- 워크스페이스 3개 생성/working dir=`live/<name>`, run trigger 연동, 최초 순서 apply, OIDC 변수 세트 연결(02 §4).
- **ArgoCD Capability RETAIN teardown 절차(§2.7 M-1)**: destroy 시 잔존하는 k8s 리소스 목록·삭제
  순서(kubectl), 동일 `capability_name` 재사용 시 충돌 여부 실증 결과. 최초 apply 전 1회
  destroy→re-apply 검증 포함.
- Commit: `docs: TFC 워크스페이스/run trigger 런북`

### Task 20.9: addon 관리 개편 — §2.6 C′ 구현 (2026-07-18 합의)
**Files:** modify `modules/eks-cluster/{variables,main,outputs}.tf`, `tests/plan.tftest.hcl`, `live/dev/eks-cluster/main.tf`(주석)
- 리스크 게이트(완료 2026-07-18): (a) upstream `pod_identity_association` 스키마 실물 확정
  (role_arn·service_account, namespace 없음) (b) metrics-server an2/1.35 community addon 가용
  (`describe-addon-versions` → v0.9.0-eksbuild.2, owner community)
- variables: `cluster_addons` C′ 스키마(§3.1) + core 4종 enabled=false 금지 validation
- main: baseline 6종 locals → merge → 모듈 소유 필드 재주입(vpc-cni config, ebs-csi pod_identity)
  → enabled 필터. EBS CSI role(`iamr-*`, AmazonEBSCSIDriverPolicy, pods.eks.amazonaws.com) 생성
- outputs: `ebs_csi_iam_role_arn` 추가
- tests(AC): AC1 빈 map→6종 / AC2·2b core 비활성화→validation 실패 / AC3 ebs-csi 버전 override에도
  pod_identity 유지(shallow-merge 회귀, config-time) / AC4 metrics-server opt-out→5종 /
  AC5 ebs-csi opt-out→role 0개 / AC6 role name == `iamr-poc-prd-an2-ebs-csi`(특정 주소 타겟) /
  AC7 custom networking CUSTOM_NETWORK_CFG 유지
- plan diff 기대: 최초 apply 전=6종+role 전부 CREATE / 기존 apply본=metrics-server·role ADD + ebs-csi in-place
- live 주석 갱신("addon 5종 상속" → "baseline 6종 상속")
- Commit: `feat(eks-cluster): addon baseline merge + Pod Identity 연동(EBS CSI IAM 포함)`

---

## 5. 열린 항목 (이 문서 범위 밖)
1. GitOps 저장소 구조(App-of-Apps vs ApplicationSet), Karpenter NodePool/NodeClass·ingress·
   cert-manager 매니페스트. (ArgoCD **토폴로지**는 §2.7 D-ARGOCD로 확정 — 이 항목은 GitOps 레포의
   애플리케이션 트리 **내용** 소관이다.)
2. managed NG ↔ Karpenter 역할 분담 상세(어떤 워크로드가 어디로) — 원칙: 시스템·컨트롤러(Karpenter
   자신 포함, chart affinity `karpenter.sh/nodepool DoesNotExist`가 강제)는 managed NG, 앱·버스트는
   Karpenter 노드. taint/label로 가르는 배선은 **30 §2.5(B) NodePool 다양화**와 함께 진행(NodePool을
   values 리스트로 리팩터하며 taint·label 선언). taint 도입 시 시스템 addon toleration 선결.
3. Fargate 프로파일(`eksf`) 필요 여부
4. ~~**Karpenter 서브넷 discovery 태그**~~ **확정·확대(2026-07-27, Karpenter 배포 증분)** —
   NodeClass는 selector를 **둘** 쓴다: `subnetSelectorTerms`와 `securityGroupSelectorTerms`. 둘 다
   `karpenter.sh/discovery=<클러스터명>` 태그로 인프라를 찾는다.
   - **subnet 태그**: node-uniq 그룹 `extra_tags`로 부여 완료(networking, 실물 확인 — node-uniq-a/-c).
     Pod 서브넷(pod-dup)은 Karpenter 대상 아님(ENIConfig 소관).
   - **⚠️ SG 태그 갭(실물 확인 2026-07-27)**: 노드 SG에는 이 태그가 **없었다**(subnet만 다룬 최초 설계의
     누락). `securityGroupSelectorTerms`가 빈 결과면 Karpenter 프로비저닝 실패. → **`module.eks`의
     `node_security_group_tags`에 `karpenter.sh/discovery=<cluster_name>` 부여**하고 eks-cluster-dev
     재apply(in-place 태그, 노드 재생성 없음). subnet과 동일한 discovery 값·동일 selector 계약.
     (cluster primary SG가 아니라 **node SG**에 부여 — Karpenter 노드가 워크로드·노드 간 통신에 쓰는 SG.)
5. **managed NG max-pods** — custom networking + prefix delegation 조합의 노드별 max-pods 계산
   (EKS 권장 상한 110/250)과 kubelet 설정 반영 여부. 초기엔 기본값으로 시작, 밀도 문제 시 조정.
6. **컨트롤플레인 로깅** — trivy AVD-AWS-0038 검출(2026-07-16, upstream 경유). upstream
   `enabled_log_types`를 facade로 노출해 audit/api 등 활성화 가능 — CloudWatch 비용 발생하므로
   PoC 보류, 운영(prd) 전환 전 재평가 (VPC Flow Logs와 동일 취급). 게이트는 다운로드 모듈을
   스캔 제외하므로(.githooks) 이 항목이 유일한 추적 지점.
7. **EBS KMS 암호화 볼륨 권한** — KMS 고객 관리형 키로 볼륨 암호화 시 EBS CSI role에 KMS
   권한(GenerateDataKey 등) 추가 필요. 현재는 관리형 정책만 부착 — KMS 도입 시점에 §2.6 개정.
8. **Karpenter role 카탈로그 네이밍 전환** — prd 확산 단계에서 §2.6 이원화 결정 재평가
   (upstream override 변수 주입으로 가역 전환 가능).
9. **ArgoCD Capability fleet 확장 정책** (§2.7) — 중앙 Capability 1개(cross-account Access Entry로
   전 계정 관리) vs 계정별 Capability. 2번째 계정(stg) 도입 시점에 확정. dev PoC는 후자의 최소형
   (dev 단일 spoke)으로 시작. **RETAIN 상호작용(M-4)**: "중앙 Capability 1개" 채택 시 dev Capability를
   hub 계정(CICD)으로 재구축해야 하며, RETAIN 때문에 dev teardown이 orphan을 남겨 전환 비용이 커진다.
   **IdC 인스턴스 유형 제약(2026-07-18 실증)**: 현재 IdC는 계정 인스턴스라 단일 계정 전용 — "중앙
   Capability로 다중 계정 관리"를 택하면 **조직 인스턴스 IdC 전환**이 선행되어야 한다.

   **리서치 결론(2026-07-19, 공식 문서 대조 — 방향: 중앙 hub 1개 + AppProject 테넌시 권장)**:
   출처 `argocd-permissions.html` · `argocd-projects.html` · `argocd-register-clusters.html` ·
   EKS pricing. 최종 확정은 stg 도입 시점(원칙 유지)이나, 근거를 기록해 재조사를 방지한다.
   - **부서(팀)별 접근 제어 공식 지원 — 2단 권한 모델**: 글로벌 `rbacRoleMappings`(IdC 그룹 →
     ADMIN/EDITOR/VIEWER — ArgoCD 자체 권한, EDITOR/VIEWER는 기본적으로 Application 접근 불가) +
     **AppProject project roles**(IdC 그룹 **ID** → `p, proj:<proj>:<role>, applications, sync,
     <proj>/*, allow` 정책). sourceRepos(부서 레포 제한)·destinations(클러스터·네임스페이스 제한)·
     리소스 white/blacklist로 테넌시 경계 구성. **권장 패턴(AWS Pattern 3)**: 플랫폼팀=ADMIN,
     부서 리드=EDITOR(자기 프로젝트 role 셀프서비스), 개발자=VIEWER+project roles.
     → "플랫폼팀 전담 vs 부서별 인스턴스" 양자택일이 아니라 **위임된 테넌시**가 내장됨.
   - **중앙형 논거가 관리형에서 강화됨**: per-team 인스턴스의 전통적 논거 2개(업그레이드 자율,
     리소스 중복)가 관리형에선 소멸(AWS 운영·클러스터 내 컴포넌트 없음). cross-account spoke는
     대상 클러스터 Access Entry + cluster Secret만으로 등록(IAM 신뢰 체인·VPC peering 불필요,
     private 클러스터 연결 AWS 자동 처리) — CT OU별 계정 구조와 정합.
   - **비용 모델**: capability 기본 ~$0.028/h + **Application당** ~$0.0014/h(대상 클러스터별 카운트,
     us-east-1 2026-03 기준). 비용 동인은 인스턴스 수가 아니라 앱 수 — 분리해도 앱 비용 동일,
     기본요금×N과 운영 중복만 증가.
   - **관리형 고유 제약**: ① capability당 **1,000 identity 한도**(사용자+그룹 — 그룹 위주 매핑이면
     여유) ② Application/ApplicationSet은 **capability namespace 단일**(OSS apps-in-any-namespace
     미지원) — 테넌시는 네임스페이스가 아니라 AppProject로 ③ IdC 조직 인스턴스 필수(immutable이라
     hub 정식 구축 시점부터 조직 인스턴스로 시작).
   - **분리(제2 hub) 트리거 명문화**: ① prd 완전 격리 정책 확정(→ nonprd/prd 2-hub 하이브리드가
     첫 분기점) ② 특정 부서의 규제·감사상 완전 격리 요구 ③ 1,000 identity 한도 접근 ④ 단일 hub
     장애 blast radius 수용 불가. 트리거 전에는 분리하지 않는다.
   - **PoC 함의**: 현 `argocd-admins=ADMIN` 매핑은 데모용 — 실환경 전환 시 Pattern 3 재구성.
     클러스터 추가는 hub 수와 무관: Access Entry(Terraform) + cluster Secret·ApplicationSet
     cluster generator(GitOps 레포, 열린 항목 10)로 자동화.
10. ~~**fleet 단계 cluster Secret 생성 주체** — kubernetes provider vs GitOps 관리.~~
    **해소(2026-07-20, §2.8 D-SPOKE-SEAM)**: 도달성 경계로 분리 — Access Entry=Terraform, cluster
    Secret=GitOps(self-heal). "kubernetes provider 전체 소유" 안은 TFC SaaS→private apiserver 도달 불가로
    기각. 잔여 부트스트랩(root App 1개)은 V1~V3 게이트로 확정(V1 완료: 네이티브 seed 없음). 로컬(dev)
    클러스터도 명시 등록 필요 → PoC 범위에서 즉시 반영(stg 이연 아님). 상세: §2.8 · [`30-gitops-repo.md`](30-gitops-repo.md).
