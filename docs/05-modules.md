# 05. 모듈 카탈로그

**읽는 사람**: 배포 루트에서 모듈을 호출하려는 사람.

핵심 세 모듈이 있고, 순서대로 의존한다. `vpc` -> `eks-cluster` -> `workbench`.
크로스 계정 시나리오에서만 쓰는 `cross-account-trust-role`은 이 체인과 독립적으로 존재하며
`eks-cluster`의 `access_entries`에 출력을 연결한다.

---

## 공통 규약

모든 모듈이 아래를 따른다.

| 입력 | 타입 | 뜻 |
|------|------|-----|
| `naming` | `{workload, env, region_code}` | `Name` 태그를 모듈이 조합한다. 소비자가 약어를 쓰지 않는다 |
| `purpose` | `string` | 이름의 용도 부분 (`main` · `web` · `worker`) |
| `tags` | `map(string)` | 거버넌스 태그는 provider `default_tags`로 넣는다. 여기엔 추가분만 |
| `<component>_enabled` | `bool` | kill switch. `false`면 아무것도 만들지 않는다 |

**이름 포맷**: `(리소스약어)-(workload)-(env)-(리전코드)-(purpose)-(일련번호)`
예: `vpc-demo-prd-an2-main` · `eks-demo-prd-an2-main-01`

리소스 약어는 [`aws-naming-abbreviations.md`](aws-naming-abbreviations.md)가 소유한다.
**없는 약어를 임의로 만들지 않는다** — 등재 후 쓴다.

---

## `vpc`

VPC · 서브넷 그룹 · NAT · 라우팅 · Flow Logs.

**최신 태그**: `vpc-v0.3.0` · **계약 테스트**: 13

### 핵심 입력

| 변수 | 설명 |
|------|------|
| `cidr_block` | ⛔ 되돌릴 수 없다. 착수 전 확정 |
| `secondary_cidr_blocks` | pod 전용 대역 등 (custom networking용) |
| `subnet_groups` | 그룹별 서브넷 정의. 이름·크기·public 여부 |
| `az_count` · `az_selection` | AZ 개수와 선택 방식 |
| `enable_nat_gateway` · `single_nat_gateway` | 비용 대 가용성. NAT는 트래픽 0이어도 과금된다 |
| `eks_cluster_name` | 주면 EKS 자동 발견용 서브넷 태그를 붙인다 |
| `flow_logs_*` | Flow Logs 활성화·보존·대상 |

### 출력

`vpc_id` · `vpc_cidr_block` · `secondary_cidr_blocks` · `subnet_ids_by_group` ·
`route_table_ids_by_group` · `nat_gateway_ids` · `flow_log_group_name`

> `subnet_ids_by_group`이 다음 모듈로 가는 주 연결선이다.

---

## `eks-cluster`

EKS 클러스터 · 노드그룹 · managed addon · IAM · Access Entry.
커뮤니티 모듈을 **wrapper로 감싼** 형태다 — upstream 변수 rename을 내부에서 흡수한다.

**최신 태그**: `eks-cluster-v0.8.0` · **계약 테스트**: 28

### 핵심 입력

| 변수 | 설명 |
|------|------|
| `kubernetes_version` | 마이너 **1단계씩만** 올린다 |
| `vpc_id` · `subnet_ids` | `vpc` 모듈 출력에서 온다 |
| `endpoint_public_access` · `endpoint_private_access` | private 유지가 workbench가 필요한 이유 |
| `public_access_cidrs` | public이 켜졌을 때만 의미가 있다 |
| `enable_custom_networking` · `pod_subnet_ids` | pod를 secondary CIDR에 둔다 |
| `managed_node_groups` | 노드그룹 정의. `ami_type`으로 graviton 선택 |
| `cluster_addons` | managed addon과 **버전 핀**. 핀은 소비 루트가 소유한다. `aws-ebs-csi-driver`·`aws-efs-csi-driver`는 opt-in — 명시해야 addon·IAM role이 생긴다 |
| `access_entries` | 클러스터 접근 주체 (workbench Role 포함). `principal_arn`은 `type = STANDARD`(기본값)라면 클러스터와 **다른 AWS 계정**의 IAM Role도 받는다 — 크로스 계정 연결에 이 변수 자체는 변경이 필요 없다 |
| `cluster_security_group_additional_rules` | workbench -> 클러스터 인바운드가 여기로 들어온다 |
| `enable_karpenter` · `enable_cluster_autoscaler` · `enable_alb_controller_iam` · `enable_external_dns_iam` | IAM만 만든다. 컨트롤러는 계층 2 |
| `deletion_protection` | 실수 삭제 방지 |

> **Karpenter와 Cluster Autoscaler는 동시에 켤 수 있다** — 상호 배제하지 않는다(서로 다른 리소스를
> 다룬다: Karpenter=EC2 직접 프로비저닝, CA=`managed_node_groups`의 ASG). 단, 워크로드를 taint로
> 분리하지 않으면 같은 pending pod에 두 컨트롤러가 동시에 반응해 중복 프로비저닝이 발생할 수
> 있다(근거: [karpenter.sh FAQ](https://karpenter.sh/docs/faq/) · `aws/karpenter-provider-aws#2543`).
> 검증된 분리 패턴(taint+nodeSelector 이중 관문, DaemonSet은 nodeSelector 금지)은
> [`07-runbooks.md`](07-runbooks.md)를 참조한다.

### 출력

**클러스터**: `cluster_name` · `cluster_arn` · `cluster_endpoint` · `cluster_version` ·
`cluster_certificate_authority_data` · `cluster_oidc_issuer_url` · `oidc_provider_arn`

**보안 그룹**: `cluster_security_group_id` · `node_security_group_id`

**Karpenter (계층 2로 간다)**: `karpenter_iam_role_arn` · `karpenter_node_iam_role_arn` ·
`karpenter_node_iam_role_name` · `karpenter_instance_profile_name` ·
`karpenter_sqs_queue_name` · `karpenter_discovery_tag`

**Cluster Autoscaler (계층 2로 간다)**: `cluster_autoscaler_iam_role_arn`
(namespace=`kube-system`, service_account=`cluster-autoscaler`로 고정 — 공식 요구사항이 아니라
관례다. Karpenter의 `kube-system`과 달리 APF FlowSchema 같은 근거가 없다)

**IAM (계층 2로 간다)**: `alb_controller_iam_role_arn` · `external_dns_iam_role_arn` ·
`ebs_csi_iam_role_arn` · `efs_csi_iam_role_arn`

> Karpenter와 IAM 출력이 **계층 1과 계층 2를 잇는 선**이다.
> 이 값들이 GitOps 저장소의 helm values로 들어간다.

### 크로스 계정 확장

허브 계정의 self-managed ArgoCD가 스포크 계정의 EKS에 접근하기 위한 입력·출력이다
(`docs/02-choose-your-path.md` 질문 D의 IAM 경계를 구현한다, `eks-cluster-v0.8.0`부터).
허브 계정에서만 켠다 — 스포크 쪽은 `cross-account-trust-role` 모듈이 소유한다.

| 변수 | 설명 |
|------|------|
| `enable_argocd_hub_pod_identity` | kill switch. 기본 `false` |
| `argocd_namespace` | ArgoCD가 설치된 네임스페이스. `scripts/argocd-seed.sh`의 `ARGOCD_NAMESPACE`와 반드시 일치해야 한다 — 하드코딩하지 않는다 |
| `argocd_hub_assumable_role_arns` | 이 허브가 `sts:AssumeRole`로 접근할 수 있는 스포크 신뢰 Role ARN 목록. 스포크가 늘 때마다 이 목록에 추가한다 |

**출력**: `argocd_hub_iam_role_arn`

> Pod Identity의 association 대상은 `argocd-server`가 아니라 **`argocd-application-controller`**다
> — 스포크 클러스터와 실제로 통신해 reconcile하는 컴포넌트가 이쪽이다.

⚠️ 이 변수들은 **IAM 경계만** 만든다. private-only 엔드포인트에서 허브가 스포크에 실제로
도달하려면 Transit Gateway 가 **별도로** 필요하다(VPC Peering 은 CIDR 3계층의 pod-dup 대역
재사용 설계와 구조적으로 충돌해 쓸 수 없다 — 아래 참조) —
`docs/02-choose-your-path.md`의 「네트워크 경로」 절 참조. 이 모듈은 그 리소스를 만들지
않는다(재사용 모듈로 두지 않기로 한 이유도 그 절에 있다).

---

## `workbench`

private 클러스터를 조작하는 운영 지점. **인바운드 규칙이 하나도 없다** —
SSM Agent가 아웃바운드로 연결을 맺고 세션이 그 연결을 역방향으로 흐른다.

**최신 태그**: `workbench-v0.6.0` · **계약 테스트**: 18

### 핵심 입력

| 변수 | 설명 |
|------|------|
| `vpc_id` · `subnet_id` | private 서브넷에 둔다. 공인 IP를 붙이지 않는다 |
| `instance_type` | 기본 `t4g.small`. 더 작으면 부팅 중 `dnf`가 OOM으로 죽는다 |
| `ami_id` | 미지정 시 AL2023 arm64 최신 |
| `eks_cluster_name` · `eks_cluster_arn` | 주면 부팅 시 kubeconfig를 만든다 |
| `kubectl_version` · `helm_version` · `argocd_version` · `eks_node_viewer_version` · `krew_version` | nullable 핀. **지정해야 설치된다** |
| `krew_plugins` | 설치할 krew 플러그인 목록 |
| `egress_cidr_blocks` | 아웃바운드 HTTPS 대상 |

### 출력

`workbench_instance_id` · `workbench_private_ip` · `workbench_security_group_id` ·
`workbench_iam_role_arn` · `workbench_iam_role_name`

> `workbench_security_group_id`와 `workbench_iam_role_arn`이 **경계의 실물**이다 (아래).

### 클러스터 접근 3층 — 누가 무엇을 소유하는가

| 층 | 무엇 | 소유 모듈 |
|:--:|------|----------|
| 1 | 주체 IAM (workbench Role) | **`workbench`** |
| 2 | EKS Access Entry | **`eks-cluster`** |
| 3 | cluster SG 인바운드 | **`eks-cluster`** |

`workbench`는 1층만 만들고 **자기 SG ID와 Role ARN을 출력**한다.
배포 루트가 그 둘을 `eks-cluster`의 `access_entries`와
`cluster_security_group_additional_rules`에 넘긴다.

> 모듈이 서로를 직접 참조하지 않는다. **배포 루트가 연결한다.**

### 부팅 후 상태

`eks_cluster_name`을 주면 `user_data`가 다음을 만든다:

- kubeconfig 정본 `0444` (읽기 전용) + `/etc/skel/.kube/config` 상속
- 새 사용자는 로그인 시 자기 `0600` 사본을 받는다
- 도구: kubectl · helm · argocd · eks-node-viewer · krew + 플러그인
- 로그인 프로파일: `alias k` · `nv` · kubectl completion · 리전 export

---

## `cross-account-trust-role`

스포크 계정이 소유하는 크로스 계정 IAM 신뢰 Role 하나만 만드는 얇은 모듈. 허브의 특정 IAM
Role만 `sts:AssumeRole`을 허용하고, 그 밖의 AWS 권한은 전혀 붙이지 않는다 — 실제 Kubernetes
권한은 `eks-cluster`의 `access_entries`가 매핑하는 `kubernetes_groups`(RBAC)가 전담한다.
`vpc`/`eks-cluster`/`workbench` 체인과는 독립적이며, 크로스 계정 시나리오
(`docs/02-choose-your-path.md` 질문 D에서 허브 분리를 택한 경우)에서만 쓴다.

**최신 태그**: `cross-account-trust-role-v0.1.0` · **계약 테스트**: 5

### 핵심 입력

| 변수 | 설명 |
|------|------|
| `trusted_principal_arns` | 신뢰할 IAM Role/User ARN 목록. **특정 ARN만** 허용 — 계정 `:root` 전체 위임이나 와일드카드는 plan 단계에서 거부한다 |
| `session_duration_seconds` | `max_session_duration`. 기본 `3600` |
| `enabled` | kill switch. 기본 `true` |

### 출력

`role_arn` · `role_name`

> `role_arn`이 스포크의 `eks-cluster` 모듈 `access_entries`로 들어가는 연결선이다.
> 모듈이 서로를 직접 참조하지 않는다 — 배포 루트가 연결한다(다른 모듈과 같은 원칙).

---

## 연결 예시

```hcl
module "vpc" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/vpc?ref=vpc-v0.3.0"

  naming           = local.naming
  cidr_block       = "10.50.0.0/24"
  eks_cluster_name = local.cluster_name    # 서브넷 태그용
}

module "eks" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/eks-cluster?ref=eks-cluster-v0.7.0"

  naming     = local.naming
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.subnet_ids_by_group["private"]

  access_entries = {
    workbench = { principal_arn = module.workbench.workbench_iam_role_arn, ... }
  }
  cluster_security_group_additional_rules = {
    workbench = { source_security_group_id = module.workbench.workbench_security_group_id, ... }
  }
}

module "workbench" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/workbench?ref=workbench-v0.6.0"

  naming           = local.naming
  vpc_id           = module.vpc.vpc_id
  subnet_id        = module.vpc.subnet_ids_by_group["private"][0]
  eks_cluster_name = module.eks.cluster_name
  eks_cluster_arn  = module.eks.cluster_arn
  kubectl_version  = "1.34.1"    # nullable 핀 — 지정해야 설치된다
}
```

> `ref=main`을 쓰지 않는다. 태그로 고정한다.

---

## 다음

- 이 값들을 어떻게 정하나 → [`03-new-project.md`](03-new-project.md)
- 네이밍·버전 규칙 → [`06-conventions.md`](06-conventions.md)
