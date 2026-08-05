# 21 · GitOps 부트스트랩 seam (ArgoCD) — ⚠️ **미결정**

> **분리**(2026-08-03): [`20-eks-module.md`](20-eks-module.md)의 **§2.7·§2.8을 그대로 옮겼다.**
> 20을 개정해 EKS 모듈 계약의 SSOT로 만드는 과정에서, 이 두 절이 **20의 개정 대상이 아님**이
> 드러났기 때문이다. 근거는 두 겹이다:
>
> 1. ⛔ **이 repo는 아직 이 선택을 승계하지 않았다.**
>    [`01 §3.3`](../architecture/01-module-strategy.md)이 명시한다 — *"관리형 Capability는 IdC 필수·
>    cross-region 계정 인스턴스·RETAIN 삭제 정책 등 제약이 크고 (…) 대안(self-managed ArgoCD 포함)과
>    함께 다시 결정한다."* 즉 **개정 대상이 아니라 재결정 대상**이다.
> 2. **이 repo는 배포 루트를 소유하지 않는다**([`03 §4`](../architecture/03-dependencies.md) 각주).
>    아래 설계의 구현체는 전부 `live/cicd/gitops-hub` — 소비 프로젝트의 배포 루트다.
>
> ⚠️ **확정 설계로 인용하지 않는다.** [`docs/README.md`](../README.md) 상태표가 판정 근거다.

## 0. 이 문서의 지위 — 무엇이 살아 있고 무엇이 무효인가

**이 문서는 "PoC가 실제로 부딪혀 본 벽의 기록"이다.** 결론(관리형 Capability 채택)은 미승계지만,
그 과정에서 **실물로 확인된 제약**은 어느 방식을 택하든 다시 만나게 되므로 버리지 않는다.

| 구분 | 항목 | 재결정 시 취급 |
|------|------|--------------|
| ✅ **살아 있는 실측** | `AmazonEKSArgoCDClusterPolicy`가 cluster-wide read-all을 **주지 않는다**(D-ARGOCD-CLUSTER-READ) · auto-managed Access Entry의 `kubernetesGroups`가 **비어 있어** custom ClusterRole을 bind할 수 없다 · IdC **계정 인스턴스는 다중 계정 미지원** · `delete_propagation_policy=RETAIN`이 유일값 · Capability의 IdC 바인딩은 **immutable** | **그대로 유효.** AWS 서비스 동작이라 실행 엔진과 무관하다 |
| ✅ 살아 있는 판단 | 등록 seam을 **도달성 경계로 분리**(D-SPOKE-SEAM: IAM grant=IaC, cluster Secret=GitOps) · seed의 **자기소멸 원칙**(seed 산출물은 저장소 콘텐츠의 바이트 동일 사본) | 도구 무관한 원칙 — 재결정에서도 출발점으로 쓴다 |
| ⚠️ **전제가 바뀐 것** | `tfe_outputs`로 hub cluster_name 조회 · TFC workspace(`gitops-hub-cicd`) · TFC 러너 도달성(V3) · Sentinel 게이트 | **무효.** [`03 §3.1`](../architecture/03-dependencies.md)의 네이밍/data source 조회와 GitHub Actions로 재설계해야 한다 |
| ⚠️ 재확인 필요 | `awscc` provider 인증(TFC OIDC로 실증한 것) · 요금(2026-03 기준) · `awscc_eks_capability` 스키마(v1.93.0 기준) | GitHub Actions OIDC 기준으로 재실증. 스키마는 재조회 |
| ❌ 미승계 결론 | **관리형 Capability를 쓸 것인가** 자체 | `01 §3.3`·`01` 열린 항목 1에서 self-managed 대안과 함께 재결정 |

### 절 번호를 §2.7·§2.8로 유지하는 이유

[`30-gitops-repo.md`](30-gitops-repo.md)와 [`40-workbench.md`](40-workbench.md)가 이 내용을
**"20 §2.7"·"20 §2.8"로 20곳 넘게 참조**한다. 두 문서 모두 ⚠️ 미개정이라 이번 개정에서 손대지 않으므로,
번호를 바꾸면 그 참조가 전부 끊긴다. **번호는 구 20 문서의 것을 보존**하고, 20에는 이 문서를 가리키는
포인터만 남겼다. 30·40을 개정할 때 참조를 `21 §2.7` 형태로 함께 정리한다.

> ⚠️ 아래 본문은 **원문 그대로**다(PoC 시점 서술·날짜·run ID 포함). 정리본이 아니라 **이관본**이므로,
> 본문 안의 "확정"·"실증됨"은 **PoC 스택에서의 것**이며 이 repo가 재현한 것이 아니다.
> 정리된 실측 요약은 [`../reference/poc-findings.md`](../reference/poc-findings.md)를 본다.

---

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
> workbench kubectl로 seed 3종을 실제 apply(sha256 바이트 동일 확인 후)하고 root App 상태를 조회한 결과,
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
> | A2 | `EKSEditPolicy`@kube-system + cluster 스코프 리소스는 Terraform/workbench 선설치(helm `rbac.create=false`) | ns | 최소권한이나 GitOps 소유 분절·CRD 버전 드리프트를 TF가 떠안음 |
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
> 위 우선순위는 **"apiserver에 도달할 수 없다"는 전제** 위에 세워졌다. 40-workbench(2026-07-23 배포)이
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
> UI는 workbench 포트포워딩 없이 도달 불가(40 §9-3)이므로 **"UI를 보려면 seed가 필요한데 seed하려면
> UI가 필요한"** 새 치킨-에그가 생긴다. 게다가 토큰 발급은 자격증명 생성이라 승인 대상이다(40 §9-4).
>
> **채택 (3) 수동 kubectl 런북 — 다만 "수동"의 성격이 다르다**: workbench는 임시방편이 아니라 설계된
> 상시 관리 지점이고(40 §1), IAM(Access Entry)만으로 인증된다 — ArgoCD 자체 인증 체계(IdC→UI→JWT)를
> **통째로 우회**한다. 신규 자격증명이 생기지 않는 것이 이 경로의 가장 큰 이점이다.
>
> **V3 무의미화**: V3는 "TFC 러너 → 대상 도달성"을 묻는다. seed 수행자가 TFC 러너가 아니라
> **workbench(사람)** 으로 확정되었으므로 이 게이트는 성립하지 않는다. Cloud Agent 도입 검토도 함께 종결한다.
> 후보 (2)(1회성 kubernetes provider)는 §2.7 provider 격리를 되살려야 하는데, 그 예외를 허용할 이유가
> 사라졌으므로 **함께 기각**한다 — 위 "provider 격리 문장 정정"의 예외 조항은 발동되지 않는다.
>
> **seed의 자기소멸 원칙(중요)**: workbench가 손으로 apply하는 매니페스트는 **GitOps 저장소에 있는 것과
> 바이트 단위로 동일**해야 한다. 그래야 root App이 첫 sync에서 그것을 자기 소유로 흡수(adopt)하고
> 즉시 no-op이 된다. seed는 저장소 콘텐츠의 **사본**이지 별개 아티팩트가 아니다 — 이 원칙이 깨지면
> seed 산출물이 영구 드리프트로 남는다. 상세 절차는 [`30-gitops-repo.md §4`](30-gitops-repo.md).
>
> **⭐ 2026-07-24 실측 — 읽기 경로 확인(가정의 절반 실증)**: workbench kubectl로 hub `argocd` 네임스페이스를
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

---

## 열린 항목 (이 문서 소관)

> 구 [`20-eks-module.md`](20-eks-module.md) 열린 항목 9를 **근거째** 이관한 것이다.
> **재결정([`01 §3.3`](../architecture/01-module-strategy.md))에서 이 리서치를 다시 하지 않도록** 남긴다 —
> 관리형 Capability를 채택하지 않더라도 *"허브를 몇 개 둘 것인가 · 테넌시를 무엇으로 가를 것인가"*는
> self-managed ArgoCD에서도 그대로 물어야 하는 질문이다.

1. **ArgoCD Capability fleet 확장 정책** (§2.7) — 중앙 Capability 1개(cross-account Access Entry로
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
     cluster generator(GitOps 레포)로 자동화.

2. **부트스트랩 seam 자체의 재결정** — [`01 §3.3`](../architecture/01-module-strategy.md)이 지정한
   상위 질문이다. 관리형 Capability(이 문서) vs self-managed ArgoCD(hub-spoke) vs 제3안.
   위 §0의 "살아 있는 실측"이 **어느 안을 택하든 입력값**이다.
   ⚠️ 재결정은 **GitHub Actions + S3 backend 전제**로 다시 계산해야 한다 — 이 문서의 도달성 논증
   (V1~V3)은 **TFC SaaS 러너**를 전제로 세워졌고 **그 전제는 이미 사라졌다.** 러너가 바뀌면
   "VPC 밖에서 private apiserver에 도달 불가"라는 제약의 해법도 달라진다(self-hosted runner 등).
3. **`awscc` provider 재평가** — 관리형 Capability를 유지할 경우에 한한다. PoC는 aws provider에
   native 리소스가 없어(`terraform-provider-aws` #45324) awscc 경로를 택했다. 재결정 시점에
   native 지원 여부를 재확인한다 — 생겼다면 provider 하나를 통째로 덜어낼 수 있다.
