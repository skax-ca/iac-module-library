# PoC 실증 기록 (외부 출처 — 재현되지 않음)

> **출처**: `terraform-enterprise-poc` @ `76285f7`(동결 커밋), 2026-07-14 ~ 07-28 실행분.
>
> ⛔ **이 repo에서 재현한 것이 아니다.** 별도 repo·별도 스택(**Terraform 1.15 + HCP Terraform**)에서
> 얻은 관찰이며, 이 repo의 스택(**OpenTofu + GitHub Actions**)에서 재확인되지 않았다.
> 설계 문서는 이 파일을 **참조**하되, 본문에 실증 날짜·run ID를 옮겨 적지 않는다 —
> 그렇게 하면 이 repo가 하지 않은 실증을 했다고 주장하게 된다.
>
> **표기**: ✅ 도구 무관(AWS 사실 — 그대로 유효) · ⚠️ 재확인 필요(스택 전환 영향) · 🔒 TFC 전용(참고만)

---

## 1. EKS 클러스터·노드

| # | 관찰 | 유효성 |
|---|------|--------|
| 1.1 | **`use_latest_ami_release_version` 기본값이 `true`** — 핀하지 않으면 매 apply가 최신 AMI로 **노드 롤링 교체**를 유발한다(리뷰 없는 자동 업데이트). `ami_release_version`을 명시 핀하고 업그레이드는 그 값 bump로만 한다 | ✅ |
| 1.2 | upstream `eks-managed-node-group` 서브모듈의 동작이 문서와 어긋나는 지점이 있어, **변수 의미를 registry에서 직접 확인**해야 한다(추정 금지) | ✅ |
| 1.3 | **IAM managed policy는 6,144자 한도**(조정 불가)에 걸린다 — 실제로 `LimitExceeded` 발생. inline은 10,240자 | ✅ |
| 1.4 | addon 버전은 `describe-addon-versions --kubernetes-version <k8s>`로 **해당 k8s 버전의 실측 최신 호환**을 조회해 핀한다 | ✅ |
| 1.5 | EKS community addon은 AWS가 **버전 호환·라이프사이클만 지원**(기능 지원 아님) | ✅ |
| 1.6 | Karpenter spot 프로비저닝 동작 확인. 단 **OCI egress 경로**가 열려 있어야 helm chart를 당긴다 | ✅ |

## 2. IAM · OIDC

| # | 관찰 | 유효성 |
|---|------|--------|
| 2.1 | **IAM 전파 race** — role 생성 직후 이를 참조하는 리소스를 만들면 신뢰 정책이 아직 안 보여 `invalid trust policy` 400이 난다. `time_sleep`(20s) 같은 대기로 흡수 | ✅ |
| 2.2 | **OIDC `sub` 클레임이 바뀌면 즉시 전 provider가 403**(`AssumeRoleWithWebIdentity`). PoC에선 워크스페이스 rename이 원인이었다 → **일반화**: 신뢰 정책의 `sub` 조건은 발급자 측 식별자 변경에 취약하므로, 변경 시 **조건을 먼저 추가하고 나중에 제거**한다 | ✅ (GitHub OIDC에도 동일) |
| 2.3 | 2단 역할 체인(입구 Role → 실행 Role)의 세션 최대 유효기간은 **1시간, 연장 불가**. 일반 run에는 충분 | ✅ |
| 2.4 | **입구 Role을 삭제하면 실행 Role의 신뢰 정책 principal이 unique ID(`AROA…`)로 치환**되어 아무도 assume할 수 없게 된다. Role 교체 시 신뢰 정책을 먼저 갱신할 것 | ✅ |

## 3. 관리형 ArgoCD (EKS Capability) — 채택 시에만 유효

> 이 repo가 관리형 ArgoCD를 다시 채택할지는 미결정이다. 채택한다면 아래가 출발점이 된다.

| # | 관찰 | 유효성 |
|---|------|--------|
| 3.1 | **조작 경로 = 클러스터 내 CR**. 제어는 클러스터 밖, 상태는 안. `kubectl`이 공식 경로(IAM만으로 인증)이며 `argocd` CLI는 UI 선행 로그인을 요구해 사실상 불가 | ⚠️ |
| 3.2 | `AmazonEKSArgoCDClusterPolicy`는 **이름과 달리 cluster-wide read-all이 아니다.** 이것만으론 sync가 `Unknown`에 머문다. `kubernetesGroups`는 비어 있어 RBAC은 전적으로 access policy가 준다 | ⚠️ |
| 3.3 | **multi-source(`$values` + `valueFiles`) 지원 확인** — per-cluster 경로는 `{{name}}`, `ignoreMissingValueFiles` 필요. no-op 판별은 `AGE` 유지로 | ⚠️ |
| 3.4 | `delete_propagation_policy = "RETAIN"`이 **유일 지원값** — capability destroy 시 k8s 리소스가 잔존한다 | ⚠️ |
| 3.5 | **default AppProject는 완전 개방** 상태다(테넌시 경계를 직접 세워야 함) | ⚠️ |
| 3.6 | IdC(Identity Center) **필수** — local users 미지원. 계정 인스턴스는 **us-east-1**이라 cross-region 조회가 된다 | ⚠️ |
| 3.7 | App-of-Apps root가 로컬 helm 차트를 recurse 대상에 포함하면 **데드락** — 로컬 차트 경로는 exclude 필수 | ⚠️ |

## 4. 네트워크·접근

| # | 관찰 | 유효성 |
|---|------|--------|
| 4.1 | **`private_dns_enabled=false`인 vpce로도** ArgoCD serverUrl이 vpce **사설 IP로 자동 해석**된다. 격리는 "사설 IP 라우팅 불가"로 성립 | ⚠️ |
| 4.2 | vpce 서비스명 `com.amazonaws.<region>.eks-capabilities`(Interface). **endpoint policy 미지원 → SG가 유일한 ACL** | ⚠️ |
| 4.3 | **SSM 포트포워딩의 로컬 포트는 443이어야 한다.** 8443 등으로 두면 envoy `:authority` 라우팅 때문에 404 | ✅ |
| 4.4 | bastion user_data에서 도구를 `/tmp`에 받으면 **tmpfs 고갈**로 실패 — `/var/tmp`를 쓰고 설치 후 원본 삭제 | ✅ |
| 4.5 | private endpoint 클러스터는 **bastion(SSM) 경유가 유일한 접근 경로**. 비대화형 작업은 `ssm send-command` 패턴으로 | ✅ |

## 5. 도구·환경

| # | 관찰 | 유효성 |
|---|------|--------|
| 5.1 | **수동 OAuth 게이트는 자동화 불가** — VCS 연결·ArgoCD JWT·CodeConnections는 사람이 브라우저에서 승인해야 한다. **`apply` 성공 ≠ 사용 가능** | ✅ |
| 5.2 | 사내망 TLS 검사 때문에 로컬 MCP가 SSL 실패하는 두 유형이 있다 — self-signed(CA 주입으로 해결) vs `basicConstraints` malformed(Python이 거부 → WebFetch로 우회) | ✅ |
| 5.3 | `aws-api` MCP는 워크로드 계정과 **다른 계정**을 볼 수 있다. 워크로드 계정 조회는 프로파일을 명시할 것 | ✅ |
| 5.4 | **MCP `create_run`으로는 destroy를 만들 수 없다**(run type이 아니라 run 속성) | 🔒 |
| 5.5 | 하류 plan의 `tfe_outputs` 데이터 없음/권한 오류 = remote state sharing 미등록 | 🔒 |

## 6. Teardown (2026-07-28)

| # | 관찰 | 유효성 |
|---|------|--------|
| 6.1 | **destroy 순서는 "런타임 의존"이 아니라 "코드 참조 의존"을 따른다.** bastion이 클러스터를 `data source`로 참조하면, 클러스터 삭제 후에는 destroy plan이 `couldn't find resource`로 **차단**된다(삭제 불가가 아니라 계획 불가) | ✅ |
| 6.2 | 위 상황의 우회로는 **`<component>_enabled = false` kill switch** — data source의 `count`까지 0이 되어 조회를 건너뛰면서 전 리소스를 파기한다. **모듈에 kill switch를 두면 teardown이 쉬워진다**(설계 지침으로 채택 권장) | ✅ |
| 6.3 | ArgoCD **App-of-Apps root에 finalizer가 없으면** root 삭제 시 자식이 cascade되지 않는다 → 자동 복구(`selfHeal`)만 끊고 자식을 **원하는 순서로** 지울 수 있다. 반대로 자식에 `resources-finalizer.argocd.argoproj.io`가 없으면 **Application만 사라지고 AWS 자원은 잔존**한다 | ✅ |
| 6.4 | 컨트롤러가 만든 클러스터 **밖** 자원(Karpenter EC2·ALBC의 ALB·external-dns 레코드·EBS PV)은 state 밖이다. GitOps 계층을 먼저 해체하지 않으면 고아로 남고, **ENI를 쥔 자원이 남으면 VPC destroy가 실패**한다 | ✅ |
| 6.5 | `default_tags` 거버넌스 덕에 **공용 계정에서도 태그 하나(`Workload`)로 자산을 정확히 분리**할 수 있었다. 네이밍·태깅 규약의 실질 이득 | ✅ |

---

## 이 repo에서 재확인이 필요한 항목

⚠️ 표시 항목은 스택 전환(OpenTofu·GitHub Actions)이나 아키텍처 재선택(관리형 ArgoCD 채택 여부)에
따라 달라질 수 있다. 해당 모듈을 이식·구현할 때 **재실증하고 그 결과를 이 repo의 설계 문서에 기록**한다
— 이 파일은 갱신하지 않는다(외부 출처의 스냅샷이므로).
