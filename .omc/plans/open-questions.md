# 미결 항목

계획 실행 중 사용자 판단이 필요하거나, 실행 전에 확정해야 하는 항목을 모은다.
계획별로 절을 나눈다. 해결되면 항목을 지우고 결정을 해당 문서(주로 `docs/decisions.md`)로 옮긴다.

각 항목에 **차단 범위**를 명시한다. 범위를 안 적으면 전부 착수 블로커처럼 읽혀 계획 전체가 불필요하게 막힌다.

---

## 2026-08-26-azure-vnet-design - 2026-08-26

### 해소된 항목 (2026-08-26, 사용자 확정)

- ~~**G1. Flow Logs를 `vnet-v0.1.0`에 포함하는가**~~ 사용자 확정: **제외**(계획 권고대로).
  Follow-up 1(`vnet-v0.2.0`)로 이관. Step 1~4에 그대로 실행 완료
- ~~**G2. NSG를 서브넷 그룹마다 기본 생성하는가**~~ 사용자 확정: **옵트인, 기본 `false`**
  (계획 권고대로). Step 3·4에 그대로 실행 완료

### 미결 (라운드를 막지 않음)

- [ ] **Azure Policy가 서브넷 생성 시 NSG·라우팅 테이블을 강제하는 환경을 지원할 것인가**
  차단 범위: **구현 라운드**(설계 라운드는 막지 않는다). `azurerm_subnet`의 write-only 인자
  **두 개**(`network_security_group_id_wo` · `route_table_id_wo`)가 그 환경 전용으로 존재하지만,
  provider 자신이 *"association을 권장한다"* 고 적었다. 실수요가 확인되기 전에는 열지 않는다

### 해소된 항목 (2026-08-26 v3 개정)

- ~~`module-catalog.md`의 "Azure는 0개다" 문장을 이번에 고칠지~~ — 미결이 아니라 **결정**이다.
  구현 라운드까지 **그대로 둔다**. `modules/azure/`가 아직 없으므로 현재 사실 그대로가 맞고,
  *"설계 완료·곧 추가"* 류는 이 저장소가 금지하는 예고성 서술이다. 인수 조건 C3이 잔존을 강제한다
- ~~라우팅 테이블 기본값~~ — 미결이 아니라 **결정**이다. 기본 `false`. Azure 시스템 라우트가
  vnet 내부·인터넷 경로를 이미 처리하므로 라우팅 테이블은 UDR 오버라이드 전용이고,
  쓰지 않는 라우팅 테이블은 죽은 자원이다. G2와 달리 가치 판단이 걸리지 않는다

---

## 2026-08-25-azure-foundation - 2026-08-25

- [ ] **소비 repo(`eks-reference-infra`) 승급 시점 합의** — 차단 범위: **Step 5 착수 게이트**
  (Step 1~4는 막지 않는다). Pre-mortem 시나리오 2(부분 승급으로 모듈 세대가 섞여 plan 단계까지
  지연 발견)의 유일한 실질 차단책이다. 이 repo는 강제할 수단이 없으므로 합의만이 방법이다.
  태그 컷 직후 안내만 할지, 승급 날짜를 먼저 잡을지 결정 필요

---

### 해소된 항목 (2026-08-27 개정)

- ~~**azurerm provider의 태그 상속 메커니즘 확인**~~ — 해소됨. `docs/conventions.md`의
  「Azure 강제 방식」 2번이 이미 공식 문서(*"Resources don't inherit the tags you apply to
  a resource group or a subscription"*, 상속은 Azure Policy `Inherit a tag from the resource
  group`이 별도로 제공)를 인용해 답하고 있었다 — 이 항목이 그 사실을 모르고 미결로 남아있던
  stale 항목이었을 뿐, 별도 조사가 필요했던 게 아니다.

### 해소된 항목 (2026-08-25 개정)

- ~~`.tflint.hcl` azurerm ruleset 등록을 이번 라운드에서 뺄지~~ — 사용자 확정: **이번 라운드에서 제외**.
  Step 4.6·4.7 삭제, Follow-up 2번(첫 Azure 모듈 라운드, `pre-commit`에 `tflint --init` 선행 추가)으로
  이관. Architect·Critic 독립 권고와 일치
- ~~`docs/naming/` 배치명 확정~~ — 축 3 판정을 **확정**으로 유지(계획 1절). 초판은 계획이 "채택"이라
  적고 이 파일이 "미결"이라 적어 정면 모순이었고, 그대로면 Step 1의 첫 명령(`git mv`)이 착수 불가였다
  (Critic F-1). **v3에서 한 단계 세분화**: `docs/naming/abbreviations/{aws,azure}.md`.
  `naming/`을 디렉터리 전체로 검증기 대상·400줄 예외에 걸면, "향후 리전 코드표도 수용한다"는
  확장성 근거가 스스로 무효화되기 때문이다(Critic F-D). 이제 `naming/`은 주제 디렉터리,
  `abbreviations/`는 약어 카탈로그 전용이다
- ~~`.tflint.hcl` azurerm ruleset 버전 핀 값~~ — 위 1번(스코프 제외)이 만든 파생 미결이라 함께 소멸.
  Follow-up 2번으로 이관 (Critic F-8)
- ~~모듈 디렉터리명 provider 간 전역 고유성~~ — 미결이 아니라 **결정**이다. 태그 네임스페이스는
  평면으로 유지하고, 따라서 디렉터리명은 provider를 가로질러 전역 고유해야 한다. ADR Consequences에
  명시했다. 강제 장치만 Follow-up 3번 (Architect 질문 4)
- ~~최상위 `modules/*/`에 파일이 놓이는 것을 막을지~~ — 미결이 아니라 **Must Have**로 승격했다.
  차단 비용(게이트 4 앞 3줄)이 follow-up 관리 비용보다 싸다. 음성 테스트는 인수 조건 B7 (Architect 질문 3)

### Follow-up 소화 현황 (2026-08-26, `2026-08-26-azure-vnet-design` 라운드에서)

- **5번**(`docs/naming/abbreviations/azure.md` 신설) — **해소.** Step 1에서 생성, 검증기 통과
- **6번**(Azure 태깅 강제 방식 규정, Step 2에서 비워 둔 경우) — **부분 해소.** `conventions.md`
  Azure 강제 방식에 제약 리소스(네이밍 길이·스코프) 항목을 신설해 채웠다. Azure Policy `modify`
  × OpenTofu drift 상호작용은 실측 수단이 없어 여전히 비워 둔다(위 「미결」 절 참조)
- **2번**(`.tflint.hcl` azurerm ruleset 등록, 선행조건 `tflint --init`)과
  **4번**(`pre-commit` stale 태그 목록에 Azure 모듈 추가 시 확장) — **구현 라운드 착수 게이트로
  승격.** `2026-08-26-azure-vnet-design.md`의 「구현 라운드 착수 게이트」 4건에 명세만 하고
  실행은 하지 않았다(이번 라운드 Must NOT Have — 문서 전용 스코프)

## 2026-08-28-azure-aks-cluster-design - 2026-08-28

### 해소된 항목 (2026-08-28, 사용자·소비 repo 확정)

- ~~**G1. 컨트롤 플레인 신원을 user-assigned 주입으로 하는가**~~ **확정**: 모듈은 identity도
  role assignment도 만들지 않고 `identity_id`를 **필수 입력**으로만 받는다. system-assigned는
  원천 배제. 근거는 소비 repo CI 신원의 6종 불변식(0-23)과 AWS `cross-account-trust-role`
  분리 선례. `id` 약어 등재도 함께 확정
- ~~**CNI 모드**~~ **확정**(소비 repo 커밋 `0100235`): Azure CNI **Pod Subnet(flat)**.
  Overlay는 Pod 단위 관측성 상실을 이유로 미채택(0-21)
- ~~**`vnet_subnet_id`에 라우팅 테이블이 필요한지**~~ **해소**: UDR 요구는 **kubenet 전용**이다
  (0-26). 소비 repo의 `aks-node`(`route_table_enabled = false`)는 **옳고 고칠 필요 없다**
- ~~**G-A. Overlay를 손잡이로 열어 두는가**~~ **확정(2026-08-28, 사용자 승인)**: 권고안 채택,
  **열지 않는다**(flat 고정). Step 3·4를 그대로 실행했다
- ~~**G2. Entra 통합·로컬 계정 기본값**~~ **확정(2026-08-28, 사용자 승인)**: 권고안 채택,
  Entra **옵트인** + `local_account_disabled` 기본 `false`(로컬 계정 유지). Step 3·4를
  그대로 실행했다

### 실행 완료 (2026-08-28)

Step 1~5 전부 완료, `main` 직접 커밋 예정(문서 전용): `docs/naming/abbreviations/azure.md`
(`aks`·`id` 2종 등재) · `docs/conventions.md`(노드 풀 예외 신설) · `docs/module-catalog.md`
(`aks-cluster` 연동 절 + 인터페이스 초안) · `docs/decisions.md`(「Azure 컨테이너
(aks-cluster)」ADR). `modules/azure/aks-cluster/`는 아직 없다(설계 확정, 구현 미착수).

### 미결 (라운드를 막지 않음)

- [ ] **`node_provisioning_profile` 필수 여부** — 차단 범위: **구현 라운드**.
  provider 문서가 자기모순이다(0-16-1). `tofu validate` 실주행으로만 판정된다
- [ ] **flat 모드 아웃바운드: Pod 서브넷에도 `nat_routed`가 필요한지** — 차단 범위: **구현 라운드**.
  축 10의 안내 문구를 직접 바꾼다(0-16-2). ⚠️ `validate`로는 판정 불가(런타임 도달성)
- [ ] **`temporary_name_for_rotation`을 모듈이 조합할지 소비자가 넘길지** — 차단 범위:
  **구현 라운드**. 계약에는 예산(그룹 키 8자)만 못박았다(0-24-a)
- [ ] **Option E(`identity_name` + `data` 조회)로 전환할 것인가** — 차단 범위: **`v0.2.0`**.
  `conventions.md`:174의 1순위 결합 방식이고 identity 부재를 plan에서 잡는다. 다만 kill switch ×
  data 조회 함정을 설계·테스트해야 한다. **A→E는 비파괴 전환이라 지금 닫아도 손해가 없다**
- [ ] **`pod_subnet_id` 풀별 오버라이드** — 차단 범위: **`v0.2.0`**. `0.1.0`은 전 풀 공유(0-24-c)
- [ ] **Windows 노드 풀 지원** — 차단 범위: **`v0.2.0` 이후**. 6자 한도라 이름 규칙이 다시 갈린다.
  ⚠️ Azure CNI Pod Subnet에서 **기술적으로는 Supported**이므로(0-26) 스코프 결정이지 불가가 아니다
- [ ] **bootstrap 계층이 만들어야 할 identity·role assignment 목록 확정** — 차단 범위:
  **소비 repo Phase 2 착수**. ✅ 최소 집합은 확정됐다(서브넷의 내장 `Network Contributor`, 0-26-a).
  ⛔ 커스텀 역할로 좁히지 않는다. 그 길이 `roleAssignments/write`를 부른다(0-26-b)
- [ ] **Azure RBAC ABAC condition으로 `roleAssignments/write`를 좁힐 수 있는가** — 차단 범위:
  **없음(조사 항목)**. 가능하다면 축 3 Option C 재검토가 열린다
- [ ] **kubelet 신원 입력을 열 것인가** — 차단 범위: **`v0.2.0` 이후**. ACR 실수요가 생기면
  연다(현재 소비 repo `.tf`에 ACR 참조 0건, 실측). 노드 RG 밖 신원은 `Managed Identity Operator`
  role을 추가로 부른다(0-7)
- [ ] **애드온 블록을 언제 무엇부터 여는가** — 차단 범위: **`v0.2.0` 이후**. 각 블록의 기본
  동작을 확인하지 않았다(0-17). 실수요가 확인된 것부터 하나씩, 확인 결과와 함께 연다
- [ ] **Azure 허브-스포크 GitOps 아키텍처 문서 신설 여부** — 차단 범위: **별도 라운드**.
  hub/dev가 별도 구독으로 분리돼 있어 수요는 존재하나, 축 6대로 이 모듈이 채울 수 없다.
  필요해지면 아키텍처 문서 → 별도 모듈 순서다
