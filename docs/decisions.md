# 검토하고 기각한 것들

**읽는 사람**: *"왜 X 안 해요?"* 라고 묻고 싶은 사람. 또는 그 질문을 받은 사람.

여기 있는 것은 전부 **한 번 검토해서 값을 매겨 기각했거나, 실측으로 반증된** 안이다.
다시 제안하려면 **여기 적힌 이유가 더 이상 성립하지 않음을 먼저 보여야 한다.**

---

## 엔진과 버전

| 하지 말 것 | 이유 |
|---|---|
| Terraform과 OpenTofu **동시 지원** | 실측 비용 5건으로 기각. 교차변수 validation 확인 비용 · lock 커밋 포기 · 로컬↔CI 피드백 지연, 그리고 `required_version`이 **영구적으로 느린 엔진에 묶인다** |
| 전 모듈 **`1.0.0` 일괄 컷** | 컴포넌트별 churn 속도가 다르다. 묶으면 소비자가 매 릴리스마다 *"뭐가 바뀌었지"* 를 확인해야 한다 |
| 개발 중 태그 없이 GA에 `1.0.0` **일괄 발행** | 소비 경로가 태그 하나뿐이다. 태그가 없으면 소비자가 `ref=main`(움직이는 참조)을 써야 한다 |
| 모듈별 OpenTofu **하한 대장** 유지 | 실행 지점이 전부 1.12라 분기가 소비자를 배제한 적이 없었다. 하한을 통일했다 |

> 라이선스는 OpenTofu 채택의 근거가 **아니다.** HashiCorp FAQ는 컨설턴트가 고객 프로덕션에서
> BSL 제품 사용을 돕는 것을 명시적으로 허용한다. 고객사 비용 장벽은 CLI가 아니라 **HCP/TFE 구독**이었고,
> GitHub Actions + S3로 이미 해소됐다. 실제 근거는 **리워크 0과 조달 마찰 제거**다.

---

## 모듈 설계

| 하지 말 것 | 이유 |
|---|---|
| 모듈이 **addon 버전 핀의 기본값**을 소유 | 선택지 4종을 비교해 기각. 핀 소유자는 소비 루트다 |
| **더미 ARN** 기본값 | 고객사가 복사해 apply하면 **존재하지 않는 zone을 가리키는 IAM role**이 선다 |
| `lifecycle { ignore_changes }` 로 drift 눈감기 | *"값이 어긋나도 눈감는다"* 이지 해결이 아니다 |
| `workbench`가 클러스터 이름에서 **ARN을 합성** | 모듈이 계정 ID와 파티션을 알아야 해진다. 배포 루트가 연결한다 |
| `mock_resource`로 `null`을 강제해 테스트 통과 | assertion이 모듈이 아니라 **mock을 검증**하게 된다 |
| 예제를 **minimal + enterprise 2벌**로 | 유지 비용만 늘고 어느 쪽이 정답인지 판정이 갈린다 |

---

## 변수 계약 (nullable)

| 하지 말 것 | 이유 |
|---|---|
| **모든 변수**에 무차별 `nullable = false` | default가 `null` 자체인 변수(`az_selection`·`eks_cluster_name`·`flow_logs_kms_key_id`·`nat_gateway_zones`)는 그 `null`이 "값 없음"이 아니라 "이 옵션을 자연값/미지정 상태로 둔다"는 의도된 값이다. `nullable = false`는 호출자가 명시적 `null`을 넘겼을 때 default로 대체하는 기능인데, default 자체가 `null`이면 대체해도 결과가 다시 `null`이라 모순이거나 아무 효과가 없다 |
| `validation` 블록으로 `null` 거부를 손으로 재구현 | 언어가 이미 `nullable` 인자로 제공하는 기능을 중복 구현하는 것이고, 기본 에러 메시지(*"value must not be null"*)보다 나을 게 없다 |
| `subnet_groups` 내부 `optional()` 필드까지 이번 크로스컷 대상에 포함 | 이건 변수 블록의 `nullable`과 다른 메커니즘(object type의 `optional()` 속성 기본값)이다. 스코프를 top-level `variable` 블록에 한정한다 |

> **결정**: default가 **null이 아닌** 변수와 **필수(default 없음)** 변수에 `nullable = false`를 추가한다.
> `modules/aws/vpc`·`modules/azure/vnet` 양쪽에 적용했다(vpc 17개 중 14개, vnet 12개 중 9개).
> 근거는 실측: 양쪽 모듈 모두 `merge(var.tags, {...})`가 다수 있어(vpc 7곳·vnet 2곳), 소비자가
> `tags = null`을 명시하면 현재는 거기서 "argument must not be null"로 크래시한다.
> `az_count`(`min()` 인자)·`deletion_protection`(`prevent_destroy` 메타 인자)도 같은 위험군이다.
> `nullable = false`면 이런 경우 크래시 대신 default로 조용히 대체되거나(선택 변수), 변수
> 선언부 이름을 가리키는 명확한 경계 에러가 된다(필수 변수). 근거 문서:
> [OpenTofu Input Variables](https://opentofu.org/docs/language/values/variables/)·
> [AWS 팀 Terraform 표준](https://aws-ia.github.io/standards-terraform/).
>
> **파급**: 순수하게 준수하는 소비자(명시적 `null`을 넘기지 않는 소비자)에게는 동작 변화가 없다.
> 명시적으로 `null`을 넘기던 소비자만 영향받는다(크래시 → default 대체, 또는 더 명확한 에러
> 메시지). 이 저장소의 버전 정책(`docs/conventions.md`)상 파괴 여부와 무관하게 마이너를 컷한다.
> 판정 기준(default가 `null` 자체인지 여부)은 `.claude/rules/terraform.md`에 codify해 신규
> 변수 작성 시에도 같은 기준이 적용되게 한다.

---

## Azure 네트워킹 (vnet)

| 하지 말 것 | 이유 |
|---|---|
| 서브넷을 **인라인 `subnet` 블록**으로 | 기술적 불가. 인라인에 `nat_gateway_id`가 없고, 연결 경로인 association은 provider가 인라인과의 병용을 "will overwrite subnets"로 금지한다 |
| 모듈이 **리소스 그룹 생성** | RG 삭제는 내부 리소스를 state 밖의 것까지 캐스케이드 삭제한다 |
| **`location`을 RG 데이터 소스에서 파생** | read의 apply 연기는 "data 블록이 이번 plan에서 변경 예정인 관리 리소스에 직접 의존할 때" 성립하는 조건부 동작이다. 리터럴을 넘기면 plan에서 실패하므로 배포 성공이 소비자 배선에 좌우된다 |
| **NSG를 기본 생성**(룰 0개) | 빈 NSG의 델타는 컨트롤 플레인 인바운드 차단과 서브넷 주입형 PaaS의 클라이언트 트래픽 차단 두 곳뿐이고 둘 다 파괴 방향이다. 확인된 사례가 Application Gateway이고(`GatewayManager` 컨트롤 플레인 65200-65535와 클라이언트 트래픽 룰 둘 다 필수) 보안 이득은 없다. 단 이 무이득 논거는 공용 Standard LB·공용 IP 경로에 한해서만 성립한다(그 경로만 NSG 없이도 "closed to inbound connections by default"). VNet 내부는 빈 NSG도 `AllowVNetInBound`로 허용한다 |
| NSG·RT를 **둘 다 만들지 않기** | association이 `subnet_id`를 요구하는데 서브넷은 모듈 소유다. 소비자에게 떠넘기면 경계가 어긋난다 |
| **AVM 커뮤니티 모듈 wrapper** | VNet·서브넷·NSG·NAT는 Azure에서 가장 안정된 계층이고 지식 밀도가 낮다 |
| Flow Logs를 `0.1.0`에 **포함** | provider가 "storage lifecycle management rule을 덮어쓴다"는 결함(#6935)을 명시한다. 고객사 배송 계약이라 남의 스토리지 정책을 조용히 파괴하는 경로를 첫 모듈에 넣을 수 없다 |
| NAT에 **`sku_name` 손잡이 없음** | `Standard`는 무존이거나 단일 존이다. 존 이중화는 `StandardV2`가 제공하므로 손잡이가 없으면 고를 수단이 없다 |
| NAT `sku_name` 기본값을 **`StandardV2`로** | `StandardV2`는 preview다(SLA 대상 아님, 일부 리전 미지원). 배송 모듈이 기본값으로 preview 리소스를 고객사에 강제할 수 없다. 기본은 GA인 `Standard`를 유지한다 |
| **NAT 수요 0개에 `precondition`** | `modules/aws/vpc`의 선례는 수요 0개를 조용히 스킵하고(`main.tf:70`), precondition은 `length(...) == 0`으로 그 케이스를 명시적으로 면제한다(`main.tf:149`). precondition을 걸면 모듈 기본값 조합에서 plan이 깨진다 |
| `vpc`의 `az_count`·`az_selection`·`single_nat_gateway`·`eks_cluster_name` **이식** | Azure 서브넷은 존에 속하지 않고 태그도 지원하지 않는다 |
| **AzAPI provider로 전환** | Azure Verified Modules(AVM) 공식 규격은 AzAPI를 요구하지만, 이 축에서 검토한 것은 "AVM 완성 모듈을 wrapper로 쓸지"(위 「AVM 커뮤니티 모듈 wrapper」 행)였지 provider 선택이 아니었다. azurerm은 AWS 쪽 `aws` provider와 대칭인 선택이고 문서·커뮤니티 친숙도가 높다. 전환은 근거가 쌓이면 별도로 재검토한다 |
| **AVM 8종 인터페이스**(diagnostic_settings·role_assignments·lock·private_endpoints·managed_identities·customer_managed_key 등) **전부 채택** | 스크래치 얇은 모듈은 최소 계약만 갖고 나머지는 배포 루트가 배선한다는 이 저장소의 기존 경계(`module-catalog.md`의 "모듈이 서로를 직접 참조하지 않는다, 배포 루트가 연결한다")와 같은 원칙이다. 채택한 것은 `tags`뿐이다 |

> **결정**: 첫 Azure 모듈 `vnet`을 `modules/azure/vnet/`에 스크래치 얇은 모듈로 설계했다.
> 서브넷은 `azurerm_subnet` 별도 리소스, 리소스 그룹과 `location`은 주입, NSG·라우팅 테이블은
> 옵트인 앵커, Flow Logs는 `0.1.0` 제외, NAT는 `sku_name` 손잡이를 노출하고 수요와 결합한다.
> 드라이버는 (1) 서브넷 부속 리소스 지원 가능 여부 (2) 파괴의 폭발 반경 (3) 게이트가 있는
> 척하지 않을 것이다. 축 1은 provider 제약이 답을 강제했고, 나머지는 "모듈이 소유하는 것과
> 배포 루트가 소유하는 것의 경계"로 갈렸다. 서브넷 스코프 자원은 모듈이, 구독·리소스 그룹
> 스코프 자원은 배포 루트가 소유한다.
>
> **파급**: 출력 타입 비대칭이 3건이다(`module-catalog.md`가 표로 소유). Azure 서브넷은 태그를
> 지원하지 않아 NSG·RT 태그가 그 자리를 대신한다. 조합한 이름은 `name` 인자에 들어가고 `Name`
> 태그는 달지 않는다. 이에 맞춰 「공통 강제 방식」의 `Name` 전제를 provider 중립으로 고쳤다.
> 배포 루트가 RG와 `vnet`을 한 apply에서 세울 수 있다. 대신 리전 불일치를 모듈이 막지 않는다.
> `azurerm_virtual_network`에 `subnet`·`dns_servers`를 쓰지 않는다(빈 배열로도 쓰지 않는다).
> Azure 예약 이름 서브넷(`AzureBastionSubnet`·`GatewaySubnet`·`AzureFirewallSubnet`, 확인한 것은
> 이 셋이며 더 있을 수 있다)은 이 모듈이 만들지 않는다. 네이밍 계약이 정확한 예약 이름을 만들
> 수 없기 때문이다. 배포 루트가 같은 vnet에 `azurerm_subnet`으로 직접 만든다. 이 병용은 문서
> 문면상 안전하나 `apply`로 검증하지 않았다. Azure Policy가 서브넷 생성 시 NSG나 라우팅 테이블을
> 강제하는 환경은 지원하지 않는다. NAT는 `nat_routed = true` 그룹이 0개면 조용히 만들지 않는다
> (precondition을 걸지 않는다). NAT의 `sku_name`·`zones` 변경은 리소스 재생성을 강제해 아웃바운드
> 공용 IP가 바뀐다. `nat_gateway_sku_name`의 `StandardV2`는 preview다(SLA 대상 아님, 일부 리전
> 미지원). 기본값 `Standard`는 GA이고 이 상태를 밟지 않는다. GA 기준으로는 존 이중화 NAT 경로가
> 없다. `default_outbound_access_enabled`를 노출한다(노출하지 않으면 소비자가 서브넷을 private로
> 만들 수단이 없다). `deletion_protection`은 vnet에만 걸린다. Azure는 vnet 삭제가 서브넷을 함께
> 지우므로 실질 보호 범위가 `vpc`와 다르다. 약어 6종이 고정된다(`snet`은 AWS에도 있으나 재사용은
> 허용된다). 구현 라운드는 착수 게이트 4건을 같은 PR에서 처리해야 한다.

---

## 모듈 구조 (provider 계층)

| 하지 말 것 | 이유 |
|---|---|
| 호환 shim 모듈 유지 | 변수·출력 전량 중복. 게이트 4·7이 8개를 돌고 drift를 shim마다 관리해야 한다. shim이 제공하려는 무손상 전환 기간을 기존 태그가 이미 공짜로 제공한다 |
| AWS 최상위 유지 + Azure만 `modules/azure/`로 분리(비대칭 트리) | 게이트 글롭이 두 깊이를 동시에 만족해야 해서 미탐 위험을 영구화한다 |
| 단일 카탈로그에 Azure 절 추가 | 468줄 + Azure로 400줄 규칙을 위반한다. 고유성 검사도 클라우드를 가로질러 거짓 충돌을 낸다 |
| `docs/naming/{aws,azure}.md`(한 단계 얕은 분리) | 디렉터리 접두사로 검증기 대상과 400줄 예외를 지정하면, `naming/`이 다른 SSOT도 수용한다는 확장성 근거가 스스로 무효화된다 |
| 파일 내용 기반으로 카탈로그 여부 판정(`## A.N` 헤더 유무) | "카탈로그가 아닌 파일은 조용히 건너뛴다"를 도입하게 돼, 헤더가 깨진 진짜 카탈로그가 검사에서 조용히 빠지는 미탐 경로가 생긴다 |
| 구조 이동과 참조 갱신을 별도 PR 2단계로 분리 | 필요한 조건은 "한 커밋"뿐이고, revert 시나리오가 실질적으로 없다 |

> **결정**: `modules/` 아래 provider 층을 신설하고 기존 AWS 모듈 4개를 `modules/aws/`로 이동했다.
> 호환 shim 없는 클린 브레이크로 하고, 전환은 태그가 흡수한다. 기존 태그가 과거 트리를 그대로
> 가리키므로 이동은 소급 파괴가 아니다. 깨지는 시점은 소비 repo가 승급을 결정하는 순간뿐이고,
> 그 시점은 소비 repo가 고른다.
>
> 약어 고유성은 한 클라우드 안에서 정의되고, 카탈로그 파일 1개가 곧 1개 클라우드다. 하나의
> 리소스 이름 안에 두 클라우드가 공존하지 않으므로 `vpc`가 AWS와 Azure에서 각각 다른 것을
> 가리켜도 이름이 모호해지지 않는다. 클라우드 간 재사용은 허용하고, 한 클라우드의 카탈로그를
> 여러 파일로 분할하는 것은 금지한다.
>
> 파급: `eks-reference-infra`는 다음 승급 시 `source` 4곳을 태그와 함께 고쳐야 한다(강제 수단
> 없음). 태그 네임스페이스는 평면으로 유지한다. 모듈 디렉터리명은 provider를 가로질러 전역
> 고유해야 한다(현재 충돌 없음).

---

## 네이밍

| 하지 말 것 | 이유 |
|---|---|
| 기존 약어를 **AWS 물리 접두사로 일괄 이주** | `snet`·`sgr`·`ngw`·`nacl`·`kp`·`dh`는 AWS 물리 ID 접두사(`subnet-`·`sg-`…)와 다르다. 근거가 기록에 없고(`sgr`은 `sg-` name 금지로 설명 가능), 릴리스된 `modules/aws/vpc`가 실사용 중이라 이주는 이름 변경 = breaking이다. 근거가 생기면 **개별 약어만** 재검토한다 |
| 기존 약어의 **프리픽스 계열 통일**(FSx `fs`/`fz`→`fx` · CloudFront SaaS `mtd`/`dtnt`→`cf*` · API GW `agw*`/`ag*` · MemoryDB `mdb`/`md*`) | 재명명은 전부 breaking이고 이 repo 릴리스 모듈 어디에도 쓰이지 않아 즉시 이득이 없다. 카탈로그는 섹션 컨텍스트로 소속이 드러나고, 신규 항목은 등재 규칙 2항(계열 유지)이 통제한다 |

---

## GitOps와 ArgoCD

| 하지 말 것 | 이유 |
|---|---|
| `iac-module-library`를 ArgoCD App **설치 범위에 추가** | ArgoCD가 **모듈 소스까지 reconcile**하게 된다 |
| **cluster generator**(등록된 클러스터마다 Application을 자동 복제하는 ApplicationSet 제너레이터)로 ArgoCD 자체를 팬아웃 | 등록된 모든 스포크에 ArgoCD가 설치된다. ArgoCD는 **hub에만** 산다 |
| `Replace=true` · `Force=true` | 객체를 통째로 교체하거나 `delete+create`로 동기화한다. `ServerSideApply`(kubectl 대신 API 서버가 patch를 계산하는 적용 방식)보다 우선해 무력화한다 |
| `ignoreDifferences` · `managedFieldsManagers` · **전역 스위치**로 `OutOfSync`(배포된 상태가 Git과 어긋났다는 ArgoCD 신호) 해소 | 정답은 **앱별 `ServerSideDiff=true`**(서버가 계산한 diff로 동기화 여부를 판정하는 옵션). 전역 적용은 *"`OutOfSync` = 문제"* 라는 신호를 죽인다 |
| root App(전체 매니페스트를 훑는 최상위 Application) 훑기 제외를 **`exclude`** 로 | **자기소멸 데드락**: root App이 자기 자신을 지운다. 마커(`+argocd:skip-file-rendering`)를 쓴다 |
| `argocd app sync --dry-run`의 `Phase: Succeeded`를 **SSA 성공 증거로** | dry-run은 그것을 증명하지 않는다 |
| seed에 `helm --set` · **인라인 heredoc 매니페스트** | 저장소 커밋본과 바이트가 달라져 **영구 드리프트**가 된다 |
| self-managed에서 **CodeConnections** | argo-cd에 지원이 없다. 관리형 Capability의 direct integration 기능이다 |
| 관리형에서 **`argocd-rbac-cm`** | 관리형은 IdC 강제 + `rbac_role_mappings`다. local user를 지원하지 않는다 |
| CI용 GitHub App **재사용** · 설치 범위를 **All repositories**로 | 권한 경계가 무너진다. GitOps용을 별도로 만들고 저장소 1개로 한정한다 |
| 매니페스트에 **AWS가 발급한 ID**(VPC ID · 해시 붙은 role 이름) 적기 | 환경을 다시 세우면 값이 바뀌어 없는 자원을 가리킨다. 계층 1이 **이름을 결정적으로** 만들고 계층 2는 이름을 참조한다 |
| ALBC를 위해 노드 **IMDS hop limit을 2로** | 그 노드의 모든 파드가 노드 IAM role을 탈취할 수 있다. VPC는 `--aws-vpc-tags`로 찾는다 |
| addon 증분 **여러 개를 한 PR에** | 실패 원인 귀인이 불가능해진다. 하나씩 넣는다 |
| **Kyverno를 정책 0개로** 설치 | 아무것도 하지 않는 **죽은 경로**다. Audit 모드는 위험 없이 값을 낸다 |
| **internal ALB + Ingress**를 지금 만들기 | ACM 인증서 · Route53 · `global.domain` · SG가 새로 필요하고 **고객사마다 다르다**. 요구가 생기면 그때 연다 |
| ArgoCD Application 이름 접두사를 그대로 Helm **release 이름**으로 흘려보내기 | Kubernetes 객체 이름은 DNS-1123 규격상 63자 제한이 있다. 접두사가 길어질수록 리소스 이름이 잘려 충돌한다(`cluster-autoscaler`에서 실제로 발생). `spec.source.helm.releaseName`을 짧게 명시하고 Application 이름과 분리한다 |
| `argocd --core`로 **비밀번호 변경** | core는 argocd-server를 우회해 **세션 토큰이 없다**. `--port-forward`를 쓴다 |
| **pod IP 직결**로 ArgoCD 접속 | VPC CNI라 도달은 되지만 주소가 **재스케줄마다 바뀌고** SG 두 층을 뚫어야 한다 |

---

## 크로스 계정 네트워킹 (허브-스포크 TGW)

| 하지 말 것 | 이유 |
|---|---|
| 허브·스포크를 provider 2개로 **한 Terraform 설정에 묶어 한 번에 apply** | 세 가지 비용 때문에 기각. ① **락 경합**: state lock 범위가 파일 하나라, 스포크 하나를 고치는 동안 허브와 다른 모든 스포크가 함께 잠긴다 ② **전송 비용**: S3 backend는 state 전체를 매번 통째로 주고받아 계정 수만큼 커진다 ③ **자격증명 동시 보유**: 한 CI job이 허브·스포크 양쪽 실행 Role을 동시에 들고 있어야 해, 그 job이 침해되면 허브까지 노출된다 |
| 허브-스포크 연결에 **VPC Peering** | CIDR 3계층 규약의 pod-dup 대역(`100.64.0.0/16`) 재사용이 AWS의 "CIDR이 여러 개면 하나라도 겹치면 peering 생성 자체를 거부한다" 제약과 구조적으로 충돌한다(AWS 공식 문서). 스포크의 pod CIDR을 재배치해 피하는 것도 해법이 아니다(스포크가 늘 때마다 재조율해야 해, dup 대역을 쓰는 이유 자체가 무너진다). **Transit Gateway를 쓴다** |
| TGW RAM 공유에서 **조직 내부 공유**(`enable-sharing-with-aws-organization`) 사용 | 이 기능은 조직 **관리 계정**에서만 켤 수 있는데, 배포 계정은 멤버 계정이라 그 권한이 없다. `allow_external_principals = true`로 두고 **표준 계정 간 공유(초대)**로 대체한다 |
| TGW 라우트 `for_each`의 key에 **attachment ID**(AWS가 발급하는 값) 사용 | 스포크 재배포마다 새로 발급돼, key가 바뀔 때마다 그 리소스가 destroy+create로 강제 교체된다(Terraform 공식 문서가 피하라는 패턴). 실제로 이 destroy가 API 응답 지연으로 삭제 타임아웃에 걸려 apply가 실패했고, 재시도가 "변경 없음"으로 잘못 판단해 라우트가 며칠간 빠진 채 hub-spoke가 단절된 적이 있다. 리소스의 실제 인자가 그 값에 의존하지 않으면 **불변인 설정값**(예: `spoke_account_id`)을 key로 쓴다 |
| `aws_ram_resource_share_accepter`를 스포크 root의 **평범한 Terraform 리소스**로 두기 | 두 가지가 구조적으로 성립하지 않는다. ① 그 리소스의 delete가 `DisassociateResourceShare`를 직접 호출해, 스포크를 파기할 때마다 허브의 RAM 연결이 허브 state 모르게 실물에서 풀린다 ② 재배포 시 조회용 데이터소스는 초대가 ACCEPTED여야 찾아지는데 이 리소스는 초대가 PENDING이어야 생성(수락)돼, 서로가 서로를 막는 순환이 된다. **수락은 Terraform 리소스가 아니라 CI 파이프라인의 한 단계로 둔다**(스포크 plan job이 CLI로 수락). 기존에 이 리소스가 이미 state에 있는 root만 `removed` 블록(destroy = false)으로 전환한다 |
| 계정 간 값 전달에 **AWS 태그** 사용(예: CIDR을 커스텀 태그에 담기) | AWS 태그는 종류를 가리지 않고 계정 경계를 넘지 않는다(`describe-tags`·`DescribeTransitGatewayVpcAttachments`·RAM 데이터소스의 `tags` 전부 실측: 빈 값 또는 `null`). RAM이 명시적으로 공유하는 리소스 ARN 자체와 EC2 API가 고유 속성으로 노출하는 값(`vpc_owner_id` 등)만 계정 경계를 넘는다. CIDR처럼 태그로 넘기려던 값은 **관리형 접두사 목록**(`aws_ec2_managed_prefix_list`)으로 대체한다 |
| TGW ID·CIDR 같은 값을 **repo 변수로 수동 복사** | "하류가 다른 배포 루트라면 remote state 대신 Name 태그 `data` 소스로 조회한다"는 계정 내부 원칙을 계정 경계 너머로 그대로 확장한다: 값 자체가 아니라 그 값을 담은 리소스의 **결정적 이름**으로 찾아 `data` 소스로 읽는다 |

---

## 운영

| 하지 말 것 | 이유 |
|---|---|
| **eksctl** 도입 | IaC 소유 경계를 깬다 |
| EKS 마이너 **2단계 점프** (`1.35 -> 1.37`) | 불가능하다. 한 단계씩 두 번 돈다 |
| workbench OOM에 **swapfile · 재시도** 우회 | 원인은 인스턴스 크기다. 우회는 임시방편이다 |
| workbench에 **전용 사용자 신설** | `ssm-user`가 이미 `NOPASSWD:ALL`이다 |
| 비밀번호를 **`ssm send-command`** 로 조회 | 출력이 SSM에 저장되고 CloudTrail에 남는다. 대화형 세션에서만 읽는다 |
| `argocd-initial-admin-secret` **남겨두기** | 평문에 가까운 관리자 자격증명이 클러스터에 상주한다 |
| 고객사 **IdP · 도메인 하드코딩** | 재사용 자산은 환경값을 갖지 않는다 |
| 로컬에서 파기하려고 **실행 Role 신뢰에 사용자 추가** | 파기가 승인 게이트를 우회하게 된다. 파기 경로는 신뢰 경계 **안에** 낸다(워크플로 `action=destroy`, hub/spoke 파기 절차는 `eks-reference-infra` 소관) |
| 잔존물을 **자동으로 지우는** 스크립트 | 만드는 스크립트는 멱등성이 안전망이지만 파기는 아니다. 공용 계정에서 한 번 잘못 돌면 끝이다. **삭제는 사람이, 검증은 기계가** |

---

## 프로세스

| 하지 말 것 | 이유 |
|---|---|
| `terraform-enterprise-poc`에서 모듈·설계 수정 | 그 저장소는 동결됐다. 양쪽 개발은 곧 drift이고, 6개월 뒤 어느 쪽이 정답인지 판정할 수 없게 된다 |
| 문서를 **GitOps 경로별로 복제** | 공통부가 두 벌이 되면 곧 drift다. 하나로 유지하고 갈림점만 표시한다 |

---

## 되살리면 안 되는 근거

아래는 한때 근거로 쓰였다가 **실측으로 반증된** 것이다. 논거로 다시 꺼내지 않는다.

| 근거 | 무엇이 반증했나 |
|---|---|
| *"`system-cluster-critical` 때문에 `kube-system`에 두어야 한다"* | 네임스페이스 제약이 아니다. Karpenter가 `kube-system`인 진짜 이유는 **APF FlowSchema**(`kube-apiserver`의 API Priority and Fairness 요청 분류 규칙)다 |
| *"`kube-apiserver`와 `kyverno`가 스키마 기본값을 채워 `OutOfSync`가 난다"* | 두 매니저는 `status` 서브리소스만 소유했다. 진짜 원인은 **CRD 스키마 defaulting**이다 |
| *"in-cluster는 자동 등록되니 cluster Secret이 불필요하다"* | 연결은 자동이지만 **ApplicationSet 팬아웃이 Secret의 라벨과 이름을 읽는다** |
