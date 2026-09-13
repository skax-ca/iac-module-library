# 검토하고 기각한 것들

**읽는 사람**: *"왜 X 안 해요?"* 라고 묻고 싶은 사람. 또는 그 질문을 받은 사람.

여기 있는 것은 전부 **한 번 검토해서 값을 매겨 기각했거나, 실측으로 반증된** 안이다.
다시 제안하려면 **여기 적힌 이유가 더 이상 성립하지 않음을 먼저 보여야 한다.**

이 문서는 **저장소 전역** 결정만 갖는다. 아키텍처마다 갈리는 결정은 그 패턴 문서가, 모듈
하나에만 걸리는 이유는 그 모듈의 코드(`variables.tf` description·`main.tf` 주석 → README)가
갖는다.

| 어디 | 무엇 |
|---|---|
| [architectures/gitops-hub-spoke/gitops.md](architectures/gitops-hub-spoke/gitops.md) | 계층 2 운영(addon 배치·이름·전파), ArgoCD |
| [architectures/gitops-hub-spoke/aws/README.md](architectures/gitops-hub-spoke/aws/README.md) | EKS 구성, ArgoCD 형태, 실행 기반 |
| [architectures/gitops-hub-spoke/aws/network.md](architectures/gitops-hub-spoke/aws/network.md) | 허브 위치, Transit Gateway |
| [architectures/gitops-hub-spoke/azure/README.md](architectures/gitops-hub-spoke/azure/README.md) | AKS 구성 |
| 각 모듈 README | 그 모듈이 무엇을 만들지 않는지와 그 이유 |

정리 전 전문은 태그 `docs-archive-20260911`에 있다.

---

## 엔진과 provider

| 하지 말 것 | 이유 |
|---|---|
| Terraform과 OpenTofu **동시 지원** | 실측 비용 5건으로 기각. 교차변수 validation 확인 비용 · lock 커밋 포기 · 로컬↔CI 피드백 지연, 그리고 `required_version`이 **영구적으로 느린 엔진에 묶인다** |
| 전 모듈 **`1.0.0` 일괄 컷**, 또는 개발 중 태그 없이 GA에 일괄 발행 | 컴포넌트별 churn 속도가 다르다. 묶으면 소비자가 매 릴리스마다 *"뭐가 바뀌었지"* 를 확인해야 한다. 그리고 소비 경로가 태그 하나뿐이라, 태그가 없으면 소비자가 `ref=main`(움직이는 참조)을 써야 한다 |
| Azure 모듈을 **AzAPI provider로** 전환 | Azure Verified Modules 공식 규격은 AzAPI를 요구하지만, 우리가 검토한 축은 "AVM 완성 모듈을 wrapper로 쓸지"였지 provider 선택이 아니었다. azurerm은 AWS 쪽 `aws` provider와 대칭인 선택이고 문서·커뮤니티 친숙도가 높다. 근거가 쌓이면 별도로 재검토한다 |

> 라이선스는 OpenTofu 채택의 근거가 **아니다.** HashiCorp FAQ는 컨설턴트가 고객 프로덕션에서
> BSL 제품 사용을 돕는 것을 명시적으로 허용한다. 고객사 비용 장벽은 CLI가 아니라 **HCP/TFE 구독**이었고,
> GitHub Actions + S3로 이미 해소됐다. 실제 근거는 **리워크 0과 조달 마찰 제거**다.

---

## 모듈 경계

| 하지 말 것 | 이유 |
|---|---|
| 모듈이 **addon 버전 핀의 기본값**을 소유 | 선택지 4종을 비교해 기각. 핀 소유자는 소비 루트다 |
| `lifecycle { ignore_changes }` 로 drift 눈감기 | *"값이 어긋나도 눈감는다"* 이지 해결이 아니다 |
| `mock_resource`로 `null`을 강제해 테스트 통과 | assertion이 모듈이 아니라 **mock을 검증**하게 된다 |
| **커뮤니티 모듈 wrapper**(Azure Verified Modules 등)를 기본 전략으로 | 조립 대상이 있어야 wrapper에 값이 생긴다. `aks-cluster`는 클러스터 리소스 1개 + 노드 풀 N개라 조립할 것이 없고, `vnet`이 다루는 계층은 Azure에서 가장 안정돼 지식 밀도가 낮다. 같은 기각이라도 근거가 모듈마다 다르다 |
| 모듈이 **리소스 그룹**(또는 그에 준하는 상위 컨테이너) 생성 | 리소스 그룹 삭제는 내부 리소스를 state 밖의 것까지 캐스케이드 삭제한다. 상위 컨테이너는 배포 루트가 소유한다 |
| 모듈이 **신원과 권한 부여 리소스**(Azure user-assigned identity · role assignment) 생성 | 재사용 모듈이 만드는 리소스는 소비자 CI 신원이 그것을 만들 권한을 갖는다는 뜻이다. `roleAssignments/write`를 가진 신원은 자기 자신에게 상위 역할을 부여할 수 있다. AWS는 STS role-chaining으로 특권을 입구 Role 뒤에 감춰 같은 행위의 비용이 다르지만, Azure에는 그 완충층이 없다. 옵트인 변수로 분리하는 것도 미루기일 뿐이다 |

---

## 변수 계약 (nullable)

| 하지 말 것 | 이유 |
|---|---|
| **모든 변수**에 무차별 `nullable = false` | default가 `null` 자체인 변수는 그 `null`이 "값 없음"이 아니라 "이 옵션을 자연값/미지정 상태로 둔다"는 의도된 값이다. `nullable = false`는 호출자가 명시적 `null`을 넘겼을 때 default로 대체하는 기능인데, default 자체가 `null`이면 대체해도 결과가 다시 `null`이라 모순이거나 아무 효과가 없다 |
| `validation` 블록으로 `null` 거부를 손으로 재구현 | 언어가 이미 `nullable` 인자로 제공하는 기능을 중복 구현하는 것이고, 기본 에러 메시지보다 나을 게 없다 |

> **결정**: default가 **null이 아닌** 변수와 **필수(default 없음)** 변수에 `nullable = false`를
> 추가한다. `modules/aws/*`·`modules/azure/*` 전 모듈에 적용했다. 막는 실패는 구체적이다.
> 모든 모듈이 `merge(var.tags, {...})`를 쓰므로 소비자가 `tags = null`을 명시하면 거기서
> "argument must not be null"로 크래시한다. `nullable = false`면 크래시 대신 default로 대체되거나
> (선택 변수), 변수 선언부를 가리키는 명확한 경계 에러가 된다(필수 변수).
> 신규 변수의 판정 기준은 `.claude/rules/terraform.md`가 소유한다.

---

## 네이밍

| 하지 말 것 | 이유 |
|---|---|
| 기존 약어를 **물리 접두사로 일괄 이주**하거나 **계열 통일**(FSx `fs`/`fz`→`fx` 등) | 재명명은 전부 breaking인데 즉시 이득이 없다. 릴리스된 모듈이 실사용 중이고, 카탈로그는 섹션 컨텍스트로 소속이 드러나며, 신규 항목은 등재 규칙이 통제한다. 근거가 생기면 **개별 약어만** 재검토한다 |

---

## 관리형 기능 채택 기준

> **결정**: 관리형 기능은 **이 저장소의 다른 패턴과 충돌하지 않으면** 쓴다. 충돌하면 계층 1이
> 전제를 만들고 계층 2(GitOps, Helm)가 컨트롤러를 조립한다.
> 요금도 따지지만 요금만으로 기각하지 않는다. 관리형은 플랫폼이 설치·버전 갱신을 맡아 운영
> 부담을 줄이므로, 유료라도 그 비용과 견줘 쓰는 편이 나을 수 있다.
> 기준은 하나지만 두 클라우드의 제공 형태가 달라 답이 갈린다.

기준을 적용한 결과(기능별 판정)는
[gitops.md](architectures/gitops-hub-spoke/gitops.md)의 「관리형으로 받을 것과 조립할 것」이 갖는다.

---

## 운영과 프로세스

| 하지 말 것 | 이유 |
|---|---|
| 고객사 **IdP · 도메인 하드코딩** | 재사용 자산은 환경값을 갖지 않는다 |
| 로컬에서 파기하려고 **실행 Role 신뢰에 사용자 추가** | 파기가 승인 게이트를 우회하게 된다. 파기 경로는 신뢰 경계 **안에** 낸다(워크플로 `action=destroy`) |
| 잔존물을 **자동으로 지우는** 스크립트 | 만드는 스크립트는 멱등성이 안전망이지만 파기는 아니다. 공용 계정에서 한 번 잘못 돌면 끝이다. **삭제는 사람이, 검증은 기계가** |
| 문서를 **경로별로 복제** | 공통부가 두 벌이 되면 곧 drift다. 하나로 유지하고 갈림점만 표시한다 |
