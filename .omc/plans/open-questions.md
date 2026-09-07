# 미결 항목

계획 실행 중 사용자 판단이 필요하거나, 실행 전에 확정해야 하는 항목을 모은다.
각 항목에 **차단 범위**를 명시한다. 범위를 안 적으면 전부 착수 블로커처럼 읽혀 계획 전체가 불필요하게 막힌다.

해결되면 항목을 지우고 결정을 해당 문서(주로 `docs/decisions.md`)로 옮긴다.

2026-09-07 감사에서 해소된 항목 다수(node_provisioning_profile·flat 아웃바운드·
temporary_name_for_rotation 소유·ABAC condition 조사·bootstrap identity 최소집합·
eks-reference-infra 승급 합의)를 걷어내고 아래 5건만 남겼다. 해소 근거는 각 모듈
코드·테스트·`docs/decisions.md`·`.omc/project-memory.json`의 `azure-cross-subscription-trust`
노트 참조.

---

## vnet

- [ ] **Azure Policy가 서브넷 생성 시 NSG·라우팅 테이블을 강제하는 환경을 지원할 것인가**
  차단 범위: **구현 라운드**(설계 라운드는 막지 않는다). `azurerm_subnet`의 write-only 인자
  두 개(`network_security_group_id_wo`·`route_table_id_wo`)가 그 환경 전용으로 존재하지만,
  provider 자신이 "association을 권장한다"고 적었다. 실수요가 확인되기 전에는 열지 않는다.

## aks-cluster

- [ ] **Option E(`identity_name` + `data` 조회)로 전환할 것인가** — 현재는 Option A
  (`identity_id` 필수 입력)를 그대로 유지 중, v0.5.0까지 재검토 없음. `data` 조회가
  identity 부재를 plan에서 잡아주는 장점이 있으나, kill switch × data 조회 함정을
  설계·테스트해야 한다. A→E는 비파괴 전환이라 급하지 않다.
- [ ] **`pod_subnet_id` 풀별 오버라이드** — 현재 전 풀 공유. 실수요 확인 전 보류.
- [ ] **Windows 노드 풀 지원** — 노드 이름 6자 한도라 이름 규칙이 다시 갈린다. Azure CNI
  Pod Subnet에서 기술적으로는 지원되므로 불가가 아니라 스코프 결정이다.
- [ ] **애드온 블록을 언제 무엇부터 여는가** — 각 블록의 기본 동작을 확인하지 않았다.
  실수요가 확인된 것부터 하나씩, 확인 결과와 함께 연다.
