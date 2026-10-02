# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `iac-module-library`). 형제 저장소에는
session.md를 두지 않는다. 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | **hub·dev 철거 상태(10-02, 구축·철거 한 사이클을 더 돌렸다), 발표(10-07) 전에 재구축한다.** 두 계정 잔존물 0건, 부트스트랩(state 버킷·OIDC·Role)만 남았다. 네 루트의 `deletion_protection = false`는 의도다 |
| eks-platform-gitops | main = origin | **EKS 철거 상태.** hub Secret은 `environment` 라벨을 되돌려 seed 입력이 준비돼 있다. dev Secret은 라벨 없이 파일로 남아 있고 `server`·`caData`는 철거된 클러스터 값이다 |
| aks-reference-infra | main = origin | **hub·dev 철거 상태(10-02, 구축·철거 한 사이클을 더 돌렸다), 발표 전에 재구축한다.** 두 구독 잔존물 0건, state Storage Account만 남았다. hub 구독은 다른 프로젝트(azure-dmz-hcp)와 공용이다. vWAN `prevent_destroy`·VNet·AKS `deletion_protection`이 `false`인 것은 의도다. 로컬 `az` 기본 구독은 hub다 |
| aks-platform-gitops | main = origin | **AKS 철거 상태.** hub Secret은 `environment` 라벨을 되돌려 seed 입력이 준비돼 있다. dev Secret은 라벨 없이 파일로 남아 있고 `server`·`caData`·`AZURE_CLIENT_ID`는 철거된 클러스터 값이다. `bootstrap/argocd-values.yaml`의 client-id도 철거된 hub UAMI 값이다 |

## 지난 세션 (2026-10-02)

**`aks-cluster` 변수 설명의 끊긴 결정 식별자를 이유로 바꿨다**(`bcc40a0`, main 직접, `verify` 통과). 식별자는 설계 라운드의 사용자 확인 게이트 번호였고 근거 계획서는 저장소에 없어, 코드에서 확인되는 이유를 적었다: Entra 통합은 켠 뒤 되돌릴 수 없다, 기본값에서는 로컬 계정이 유일한 인증 경로다. 패턴 문서가 기각한 "브레이크글래스" 표현과 모듈에 없는 `kube_admin_config` 언급도 뺐다. 동작 변경이 없어 태그는 컷하지 않았다.

**`gateway-api-crds`의 `Degraded` 원인을 파기로 정하고 철거 상태에서 후보를 좁혔다.** upstream `config/crd/standard`(`v1.6.2`)는 CRD 10개와 `ValidatingAdmissionPolicy`·Binding이고, ArgoCD `v3.5.3`은 VAP에 health 판정이 없어 원인은 CRD 쪽이다. CRD가 `Degraded`가 되는 길은 `resource_customizations/apiextensions.k8s.io/CustomResourceDefinition/health.lua`의 세 가지(`NamesAccepted=False`·`NonStructuralSchema=True`·`Established=True` 없음)다. 확정은 재구축 때 한다.

**addon Application의 health Lua에 `Synced` 조건을 더했다**(설계 `d1b7ab3`, eks-gitops #58, aks-gitops #25). 같은 Lua를 쓰던 다른 프로젝트에서 막 만들어진 Application이 `OutOfSync` + `Healthy`라 부모가 기다리지 않는 것이 실측됐고, 우리도 Lua·ArgoCD 계열·부모-자식 구조가 같다. `addon.name` 라벨이 있는 Application은 `Synced`이고 sync가 돌고 있지 않을 때만 `Healthy`다. Lua 판정은 아홉 가지 상태로 실행해 확인했고, 클러스터에서의 대기는 아직 재지 않았다. 마지막 wave 뒤의 표식과 시각 비교는 `ordering.md` 「하지 않는 것」에 기각으로 적었다.

## 다음 할 일

### 지금

- [ ] [eks-ref·eks-gitops] 발표 전 EKS 재구축: eks-ref `hub-lifecycle.md` 구축 절 → `spoke-lifecycle.md` 구축 절. 데모에 쓰므로 hub 6절의 비밀번호 교체까지 한다 (09-30~)
- [ ] [aks-ref·aks-gitops] 발표 전 AKS 재구축: aks-ref `hub-lifecycle.md` 구축 절 → `spoke-lifecycle.md` 구축 절. 데모에 쓰므로 hub 7절의 비밀번호 교체까지 한다 (10-01~)
- [ ] [local] 두 클라우드 구축 뒤 발표 준비: `script.md` 데모 ⑤의 포털 화면(`Networking`의 `Azure CNI Overlay`·NAP 표시)과 예상 질문 표의 15장 두 행을 실물과 대조하고 「발표 전 확인 · 전날」을 돈다. ArgoCD addon 구성의 CLI 대조는 끝났다 (09-30~)
- [ ] [eks-gitops·aks-gitops] 재구축 때 health Lua의 `Synced` 조건을 확인한다: 부모가 wave 사이에서 기다리는지(addon Application 생성 시각 간격)와 전 addon이 `Synced`로 수렴해 부모가 멈추지 않는지. 근거: `docs/architectures/gitops-hub-spoke/ordering.md` 2절·4절 (10-02~)
- [ ] [eks-ref·aks-ref] Dependabot provider PR이 루트마다 쌓여 있다(eks-ref #71~#75 aws 6.65.0, aks-ref #72~#78 azurerm 5.6.0). `groups`로 묶을지와 발표 전에 올릴지를 사용자가 정한다(`open-pull-requests-limit`은 디렉토리별) (09-23~)
- [ ] [eks-gitops] dev 등록 직후 `gateway-api-crds` 자식이 3분쯤 `Degraded`로 남는 원인을 판다. 재구축의 dev 등록 직후 `Degraded`인 동안 `argocd app get <dev 부모>-gateway-api-crds --core -o json`의 `status.resources[].health`와 dev의 `gateway.networking.k8s.io` CRD `status.conditions`를 같은 시각에 떠 맞댄다(실물이 `Established`면 ArgoCD 갱신 지연, 아니면 클러스터 쪽). 근거: `addons/cluster-addons/templates/gateway-api-crds.yaml` (10-02~)
- [ ] [aks-ref] `docs/runbooks.md`가 399줄이다. 다음에 내용을 더하기 전에 나눈다(`docs/writing-style.md` 1절 4번) (10-02~)
- [ ] [전체] push 권한자가 이미 2명이다(`rajaelime`, 팀 경유 `maintain`). `CLAUDE.md` 「GitOps 저장소 공통」 ⛔ 재검토 트리거가 당겨진 것으로 볼지 사용자가 정한다 (09-23~)

### 조건이 오면

- [ ] [*-gitops·module] 이 저장소들에 `id-token: write` job이 생기면: 액션 SHA 핀을 넓힌다(지금은 배포 루트만 SHA 핀) (09-23~)
- [ ] [local] context7이 rate limit에 걸리면: 키를 로컬 설정 `Authorization: Bearer`로 넣는다 (09-23~)
