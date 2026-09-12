# Azure(AKS)에서 이 패턴

**읽는 사람**: Azure에서 이 패턴을 세우려는 사람.

⏳ **작성 중이다.** hub·dev 두 클러스터가 실제로 서 있고 `aks-platform-gitops`가 계층 2를
맡고 있으나, 그 구조를 이 문서로 옮기는 작업은 아직 끝나지 않았다. 그때까지 구성·절차의
SSOT는 `aks-reference-infra`(계층 1)와 `aks-platform-gitops`(계층 2)다. 설계 근거는 두
저장소의 `.tf`·매니페스트 인라인 주석에 있다.

모듈 계약은 [`module-catalog.md`](../../../module-catalog.md)의 `vnet`·`aks-cluster`·
`aks-workbench` 절을 본다.

---

## 하지 않는 것

| 하지 말 것 | 이유 |
|---|---|
| Pod 대역을 플랫 모델(`pod_subnet`)로 두는 것을 기본값으로 | NAP(관리형 Karpenter)이 Azure CNI Pod Subnet을 지원하지 않고(karpenter-provider-azure#1352), Microsoft 공식 권고도 Overlay를 일반 기본으로 명시한다(plan-pod-networking · AKS baseline). `aks-cluster`의 `cni_mode` 기본값은 `overlay`다. 플랫 모델은 Pod 단위 관측성을 절대 포기할 수 없을 때만 고른다 |
| "NSG 규칙 0개 = 인바운드 0"이라고 가정 | Azure는 `AllowVNetInBound`가 이미 열려 있다. 인바운드를 막으려면 명시적 Deny(priority 4096)로 덮어야 성립한다. AWS 보안 그룹과 기본값이 정반대다 |
| Entra 통합을 "일단 켜 보고 아니면 되돌린다" | Azure가 통합 해제를 지원하지 않는다. 되돌리려면 클러스터를 재생성해야 한다(Azure RBAC만 끄는 것과는 다른 축이다) |
