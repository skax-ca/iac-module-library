# 계획: 허브-스포크 크로스 계정 IAM 신뢰 Role · EKS Access Entry Terraform 계약

**상태**: pending approval
**작성**: 2026-08-19
**배경**: `docs/02-choose-your-path.md` 질문 D(2026-08-18 확정)가 IAM 경계 원칙만 정의했고,
project-memory `open-items`의 후속 (b) "크로스 계정 신뢰 Role·EKS Access Entry의 실제 Terraform
계약(모듈 변수/출력) 미설계 — 05-modules.md급 설계 필요"를 이 계획이 채운다.

이 단계는 **설계만** 한다. `.tf` 코드는 작성하지 않는다(`CLAUDE.md` 설계 우선 규칙).

---

## 확정된 사실 (이번 세션에 검증, 추정 없음)

| # | 사실 | 근거 |
|---|------|------|
| 1 | EKS Access Entry(`STANDARD` 타입)는 클러스터와 **다른 계정**의 IAM principal ARN을 허용한다 | AWS 공식 문서 `creating-access-entries.html` |
| 2 | `eks-cluster` 모듈의 `access_entries` 변수는 이미 `type = any`(upstream 스키마 그대로 통과) | `modules/eks-cluster/variables.tf:309-318` |
| 3 | → **eks-cluster는 크로스 계정 access entry를 받기 위해 변경이 필요 없다** | 사실 1+2의 직접 결론 |
| 4 | `argocd-seed.sh`에는 IAM 관련 코드가 전혀 없다 — 허브 ArgoCD 자체의 Pod Identity Role이 아직 미설계 | `scripts/argocd-seed.sh` grep 결과 |
| 5 | `eks-cluster`는 이미 "addon IAM만 만든다" 패턴을 가짐(ALBC·external-dns·cluster-autoscaler) — `terraform-aws-modules/eks-pod-identity` v2.8.2 서브모듈 호출 | `modules/eks-cluster/iam.tf:106-181` |
| 6 | 그 서브모듈은 `attach_custom_policy` + `policy_statements`로 **임의 커스텀 IAM 정책**을 지원한다(AWS 관리형 정책이 없는 경우용) | `terraform-aws-eks-pod-identity` v2.8.2 `variables.tf:153-190` (raw GitHub 확인) |
| 7 | ArgoCD 네임스페이스는 스크립트에서 `${ARGOCD_NAMESPACE:-argocd}`로 **변수화**되어 있다 — 하드코딩된 `kube-system`류 관례가 아니다 | `scripts/argocd-seed.sh:108` |

**결론**: 새로운 리소스 하나(스포크가 소유하는 크로스 계정 신뢰 Role)만 있으면 되고, 그 소유 위치는
기존 두 패턴(`eks-cluster`의 addon-IAM 패턴, `workbench`류 얇은 모듈 패턴) 중 어디에도 정확히
맞지 않는 **제3의 얇은 모듈**이 필요하다 — 아래 설계 참조.

---

## 설계

### 액터와 흐름

```
[허브 계정]                                    [스포크 계정]
EKS 클러스터 (self-managed ArgoCD)              EKS 클러스터
  └─ argocd-application-controller pod            └─ 신뢰 Role (신규 모듈이 생성)
       │ Pod Identity                                   ▲ trust policy: Principal = 허브 Role ARN
       ▼                                                │
  허브 Role (eks-cluster 신규 addon-IAM)  ──sts:AssumeRole─┘
  policy_statements = [sts:AssumeRole → 스포크 Role ARN 목록]
                                                          │
                                                          ▼
                                                    EKS Access Entry
                                                    (eks-cluster 기존 access_entries, 변경 없음)
                                                    principal_arn = 스포크 신뢰 Role ARN
                                                    kubernetes_groups = [...]
```

### A. 허브 측 — `eks-cluster` 모듈 확장

기존 `alb_controller_pod_identity`/`external_dns_pod_identity`(`iam.tf:106-153`)와 **완전히 같은 패턴**.
새 addon 토글 하나를 그 옆에 추가한다.

**신규 입력 변수**
| 변수 | 타입 | 뜻 |
|------|------|-----|
| `enable_argocd_hub_pod_identity` | `bool` (기본 `false`) | kill switch. 기존 `enable_alb_controller_iam`류와 동일 관례 |
| `argocd_namespace` | `string` (기본 `"argocd"`) | `argocd-seed.sh`의 `ARGOCD_NAMESPACE`와 **반드시 일치**해야 한다 — 하드코딩 금지(사실 7) |
| `argocd_hub_assumable_role_arns` | `list(string)` (기본 `[]`) | 이 허브가 assume할 수 있는 스포크 신뢰 Role ARN 목록. 스포크가 늘 때마다 이 목록에 추가된다 |

**교차변수 validation**: `enable_argocd_hub_pod_identity = true`인데 `argocd_hub_assumable_role_arns`가
빈 리스트면 정책이 `Resource = []`가 되어 AWS가 거부한다 — `external_dns_hosted_zone_arns`와 같은
선례(`iam.tf:140-142` 주석)를 그대로 따라 plan 단계에서 막는다.

**신규 리소스** (`iam.tf`에 기존 블록들과 나란히)
```hcl
module "argocd_hub_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.8.2"   # 기존 서브모듈들과 정확 핀 일치

  create = local.enabled && var.enable_argocd_hub_pod_identity

  name            = "iamr-${local.name_mid}-argocd-hub"
  use_name_prefix = false

  attach_custom_policy = true
  policy_statements = [{
    sid       = "AssumeSpokeTrustRoles"
    actions   = ["sts:AssumeRole"]
    resources = var.argocd_hub_assumable_role_arns
  }]

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = var.argocd_namespace
      service_account = "argocd-application-controller"   # 스포크와 통신하는 실제 컴포넌트
    }
  }

  tags = var.tags
}
```

> `argocd-server`가 아니라 **`argocd-application-controller`**다 — 스포크 클러스터와 실제로
> 통신해 reconcile하는 컴포넌트는 application-controller StatefulSet이다(ArgoCD 아키텍처 공식 문서).

**신규 출력**: `argocd_hub_iam_role_arn`

### B. 스포크 측 — 신규 얇은 모듈 `modules/cross-account-trust-role`

기존 3모듈(`vpc`/`eks-cluster`/`workbench`) 중 어디도 "다른 계정의 특정 IAM Role만 신뢰하는
Role"을 만드는 책임을 지지 않는다. `workbench`의 IAM Role은 `ec2.amazonaws.com` service
principal 전용으로 하드코딩되어 있어 재사용 불가(`workbench/iam.tf:24`). VPC/S3/SG급으로
**안정적이고 단순한 리소스**이므로 스크래치 얇은 모듈 전략(`CLAUDE.md` 「아키텍처 & 모듈 규칙」)을
따른다.

**입력 변수**
| 변수 | 타입 | 뜻 |
|------|------|-----|
| `naming` | `{workload, env, region_code}` | 공통 규약. `Name` 태그 합성 |
| `purpose` | `string` | 이름의 용도 부분(예: `argocd-hub`) |
| `enabled` | `bool` (기본 `true`) | kill switch |
| `trusted_principal_arns` | `list(string)` | trust policy의 `Principal`. **정확히 이 ARN만** — 계정 전체(`root`)나 와일드카드 금지(아래 validation) |
| `session_duration_seconds` | `number` (기본 `3600`) | `max_session_duration` |
| `tags` | `map(string)` | 추가 태그 |

**교차변수 validation**
- `trusted_principal_arns`의 각 원소가 아래 정규식과 **정확히** 일치해야 한다(부분 와일드카드나
  `:root` 계정 전체 위임을 명시적으로 차단 — 정규식 자체가 방어선이므로 느슨하게 두지 않는다):
  ```hcl
  condition = alltrue([
    for arn in var.trusted_principal_arns :
    can(regex("^arn:aws:iam::[0-9]{12}:(role|user)/[\\w+=,.@-]+$", arn))
  ])
  error_message = "trusted_principal_arns는 특정 IAM Role/User ARN이어야 한다. 계정 root(':root')·와일드카드('*')는 허용하지 않는다."
  ```
- 빈 리스트 금지(`enabled = true`인데 아무도 못 믿는 Role은 무의미).

> 독립 검토(2026-08-19)에서 지적: 정규식이 방어의 실제 구현체이므로 "IAM Role/User ARN
> 정규식과 일치"처럼 느슨하게 서술하면 구현 단계에서 와일드카드 허용 실수가 재발할 수 있다 —
> 그래서 정확한 패턴을 이 설계 문서에 못박는다.

**리소스**: `aws_iam_role` 1개(`workbench/iam.tf`와 동일한 형태, `Principal`만 externally-owned
role ARN 리스트로 교체). **IAM 정책은 붙이지 않는다** — 이 Role의 AWS 권한은 오직
"assume 가능"뿐이고, 실제 K8s 권한은 스포크의 `eks-cluster.access_entries`가 매핑하는
`kubernetes_groups`(→ RBAC)가 전담한다. IAM 정책과 K8s RBAC 두 층을 분리하는 것이
최소 권한 설계다.

**출력**: `role_arn` · `role_name`

**이름 카탈로그**: 기존 `iamr` 약어 재사용(`docs/aws-naming-abbreviations.md` 변경 불필요).

### C. 연결 (배포 루트가 담당 — `05-modules.md` "모듈이 서로를 직접 참조하지 않는다" 원칙 그대로)

```hcl
# 스포크 계정 배포 루트
module "argocd_trust" {
  source = ".../cross-account-trust-role?ref=cross-account-trust-role-v0.1.0"

  naming                 = local.naming
  purpose                = "argocd-hub"
  trusted_principal_arns = ["arn:aws:iam::<허브계정ID>:role/iamr-<hub-workload>-argocd-hub"]
}

module "eks" {
  source = ".../eks-cluster?ref=eks-cluster-v0.8.0"
  # ...
  access_entries = {
    argocd_hub = {
      principal_arn     = module.argocd_trust.role_arn
      kubernetes_groups = ["argocd-hub"]   # ClusterRoleBinding은 iac-platform-gitops 소관
    }
  }
}
```

```hcl
# 허브 계정 배포 루트
module "eks" {
  source = ".../eks-cluster?ref=eks-cluster-v0.8.0"
  # ...
  enable_argocd_hub_pod_identity  = true
  argocd_namespace                = "argocd"   # argocd-seed.sh와 반드시 일치
  argocd_hub_assumable_role_arns  = [
    "arn:aws:iam::<스포크1-계정ID>:role/iamr-<spoke1-workload>-argocd-hub",
    # 스포크 추가마다 여기 한 줄 추가 — 결정적 네이밍이므로 계정ID+workload만 알면 예측 가능
  ]
}
```

### D. 전제 조건 — `authentication_mode`

EKS Access Entry는 클러스터의 `authentication_mode`가 `API` 또는 `API_AND_CONFIG_MAP`일 때만
동작한다. `CONFIG_MAP` 단독 모드의 스포크 클러스터에 이 설계를 적용하면 **access entry가 조용히
무시된다**(에러가 아니라 무동작 — 발견이 늦어지는 실패 모드). `docs/02-choose-your-path.md`가
`authentication_mode`를 이미 "되돌릴 수 없는 선택"(165행)으로 다루고 있으므로 새 정책은 아니지만,
이 설계 문서가 그 전제에 **의존**한다는 사실을 명시해 둔다.

> 독립 검토(2026-08-19) 지적: 이 전제가 문서화되지 않으면 구현 시점에 스포크 클러스터의
> `authentication_mode`를 확인하지 않고 진행할 위험이 있다.

**수용 기준에 반영**: 구현 단계 착수 전 체크리스트에 "대상 스포크 클러스터의
`authentication_mode`가 `API` 또는 `API_AND_CONFIG_MAP`인지 확인"을 추가한다(아래 참조).

---

## 명시적으로 다루지 않는 것 (스코프 밖)

- **`kubernetes_groups`가 매핑하는 실제 RBAC(ClusterRole/ClusterRoleBinding)**: `iac-platform-gitops`
  소관(이 저장소는 `.yaml`을 두지 않는다 — `CLAUDE.md` 0절).
- **ArgoCD의 cluster Secret 등록(`server` 필드에 크로스 계정 엔드포인트를 어떻게 채우는지)**:
  `01-architecture.md`가 이미 명시한 대로 `iac-platform-gitops` 소관, 이 계획은 그 계약이 기대는
  IAM 경계만 만든다(질문 D 표의 각주와 동일한 경계).
  ⚠️ **주의**: `iac-platform-gitops`의 `root-app.yaml`(전체 저장소 recurse) 문제가 project-memory에
  open-item으로 남아 있다 — 허브-스포크를 실제로 켜기 전에 그 repo 쪽 설계도 함께 필요하다(이
  계획의 범위 밖, 별도 후속).
- **`kubectl`/`aws eks get-token` 클라이언트 측 자격증명 체인**(ArgoCD가 어떻게 assume-role
  세션을 갱신하는지): AWS SDK 표준 동작이며 모듈 계약과 무관.

## 후속 미결(이 계획 완료 후에도 남는 것)

1. `argocd_hub_assumable_role_arns`가 스포크 추가마다 **허브 쪽에서 수동 갱신**해야 하는 리스트다 —
   스포크 수가 늘면 이 필드 자체가 운영 부담이 된다. 지금은 트리거가 없으므로(질문 D가 "필요해지면
   그때 분리") 이 계획은 이 갱신을 수동으로 둔다. 자동화(예: 스포크가 자기 Role ARN을 어딘가에
   등록)는 스포크가 실제로 2개 이상이 될 때 재검토.
2. `iac-platform-gitops`의 root-app.yaml 스캔 범위·baseline addon fan-out은 이 계획이 만들지
   않는다(위 스코프 밖 참조) — 별도 설계 필요.

---

## 수용 기준 (검증 가능)

- [ ] `docs/05-modules.md`에 `cross-account-trust-role` 모듈 섹션이 추가되고, 기존 3모듈과 같은
      포맷(핵심 입력/출력 표)을 따른다.
- [ ] `eks-cluster` 섹션에 `enable_argocd_hub_pod_identity`·`argocd_namespace`·
      `argocd_hub_assumable_role_arns` 입력과 `argocd_hub_iam_role_arn` 출력이 추가된다.
- [ ] `docs/02-choose-your-path.md` 질문 D 표(142~154행)에 "이 IAM 경계가 실제로 어느 모듈
      변수로 구현되는지" 참조 링크가 추가된다(문서 간 정합성).
- [ ] project-memory `open-items`의 (b) 항목이 "설계 완료, 구현 대기"로 갱신된다.
- [ ] 이 단계에서 `.tf` 파일은 **변경되지 않는다**(설계 문서만).

## 검증 방법

- `docs/06-conventions.md` §8 문서 작성 규칙(날짜·사건 서술 금지 등) 준수 여부 육안 확인.
- 위 표의 "확정된 사실" 7건이 실제로 인용 가능한 근거를 갖는지(이 문서 자체가 그 근거를 이미 포함).
- 사용자 승인 후 구현 단계에서(독립 검토 반영, 2026-08-19):
  - `tofu validate` + 신규 모듈 `tests/*.tftest.hcl` 최소 1건
    (`Name` 태그 assertion 포함, `CLAUDE.md` 네이밍 규칙).
  - **보안 테스트 케이스 최소 2건**: (1) `trusted_principal_arns`에 `arn:aws:iam::123456789012:root`
    입력 시 `expect_failures`로 plan 실패 검증, (2) 와일드카드 포함 ARN(`.../role/*`) 입력 시
    동일하게 plan 실패 검증.
  - 대상 스포크 클러스터의 `authentication_mode`가 `API` 또는 `API_AND_CONFIG_MAP`인지
    구현 착수 전 확인(위 "D. 전제 조건" 참조) — `CONFIG_MAP` 단독이면 이 설계 적용 불가.

---

## ADR

**Decision**: 크로스 계정 신뢰 Role은 신규 얇은 모듈(`cross-account-trust-role`)로 스포크가
소유하고, 허브의 ArgoCD Pod Identity Role은 기존 `eks-cluster`의 addon-IAM 패턴을 확장해
만든다. `eks-cluster`의 `access_entries` 변수는 변경하지 않는다.

**Drivers**:
1. 질문 D가 이미 "신뢰 Role은 스포크 소유"를 확정했다 — 이 계획은 그 결정을 뒤집지 않고 구현한다.
2. `access_entries`가 이미 `type = any`라 크로스 계정 principal을 그대로 받는다(사실 2, 3) —
   불필요한 변경을 만들지 않는다("지금 요구를 채우는 가장 단순한 형태").
3. 허브의 ArgoCD IAM 필요는 기존 addon-IAM 패턴과 구조적으로 동일하다(`create` toggle +
   Pod Identity association + 커스텀 정책) — 새 패턴을 발명하지 않는다("발명하기 전에 찾는다").

**Alternatives considered**:
- **A. eks-cluster의 `access_entries` 자체를 확장해 크로스 계정 로직을 내장** — 기각. `access_entries`는
  의도적으로 upstream 스키마를 얇게 통과시키는 `type = any` 변수다(주석: "구조를 복제하면 upstream
  변경마다 문지기가 된다"). 크로스 계정 트러스트 Role 생성은 access entry와 무관한 별도 책임이라
  섞으면 그 원칙을 어긴다.
- **B. 신뢰 Role을 스포크의 `eks-cluster` 모듈 안에 내장(eks-cluster가 직접 생성)** — 기각.
  `eks-cluster`는 "클러스터·addon IAM"을 소유하지, "클러스터와 무관한 범용 크로스 계정 신뢰
  경계"를 소유할 이유가 없다. 재사용성도 떨어진다(추후 EKS 외 다른 크로스 계정 신뢰가 필요해도
  `eks-cluster`에 갇힌다).
- **C. 배포 루트에서 `aws_iam_role`을 모듈 없이 직접 작성** — 기각. `naming`/`tags`/`Name` 태그
  합성 규약(`CLAUDE.md` 네이밍 강제 방식 2번)을 배포 루트가 매번 재구현해야 하고, 계약 테스트
  대상에서 빠진다("계약 테스트 없는 모듈은 릴리스하지 않는다"는 원칙이 지금은 "모듈조차 없다"로
  더 나쁘게 우회된다).

**Why chosen**: 기존 3모듈의 소유 경계(vpc/eks-cluster/workbench가 "모듈이 서로를 직접
참조하지 않는다"는 원칙으로 배포 루트에서만 연결됨, `05-modules.md:146`)를 그대로 유지하면서,
정확히 새로 생긴 책임(스포크의 크로스 계정 신뢰)만 새 모듈로 분리한다. 허브 측은 기존 패턴
재사용으로 신규 코드 표면을 최소화한다.

**Consequences**:
- 새 모듈 태그(`cross-account-trust-role-v0.1.0`)가 하나 늘어 버전 혼재가 심화된다 — 이미
  "결함이 아니라 정보"로 문서화된 정책이라 신규 리스크 아님(`CLAUDE.md` 버전 정책).
- `eks-cluster`는 마이너 버전업(`v0.8.0`) — 인터페이스 확장(하위 호환, 기본값 `false`)이라
  기존 소비자에게 영향 없음.
- 허브 쪽 `argocd_hub_assumable_role_arns` 수동 갱신 부담이 남는다(후속 미결 1) — 스포크 규모가
  작을 때는 감내 가능한 수준으로 판단.

**Follow-ups**: 위 "후속 미결" 절 참조(허브측 목록 자동화, `iac-platform-gitops` root-app.yaml
스코핑).
