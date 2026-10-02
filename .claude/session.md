# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `iac-module-library`). 형제 저장소에는
session.md를 두지 않는다. 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | **hub·dev 철거 상태(10-02, 구축·철거 한 사이클을 더 돌렸다), 발표(10-07) 전에 재구축한다.** 두 계정 잔존물 0건, 부트스트랩(state 버킷·OIDC·Role)만 남았다. 네 루트의 `deletion_protection = false`는 의도다 |
| eks-platform-gitops | main = origin | **EKS 철거 상태.** hub Secret은 `environment` 라벨을 되돌려 seed 입력이 준비돼 있다. dev Secret은 라벨 없이 파일로 남아 있고 `server`·`caData`는 철거된 클러스터 값이다 |
| aks-reference-infra | main = origin | **hub·dev 구축 상태(10-02 재구축), 발표(10-07)에 쓴다.** 7개 루트 재-plan이 `No changes`다. hub 완료 판정 7항목이 닫혔다. hub 구독은 다른 프로젝트(azure-dmz-hcp)와 공용이다. vWAN `prevent_destroy`·VNet·AKS `deletion_protection`이 `false`인 것은 의도다. 로컬 `az` 기본 구독은 hub다 |
| aks-platform-gitops | main = origin | **AKS 구축 상태.** hub·dev의 Application 14개가 전부 `Synced`/`Healthy`다(10-02). hub·dev Secret 모두 `environment` 라벨이 있고 접속 값은 지금 클러스터의 것이다 |

## 지난 세션 (2026-10-02)

**AKS hub·dev를 재구축했다.** networking(hub·dev 동시) → vwan·hub aks·dev aks → workbench 순으로 8개 run을 승인했고, aks-gitops #26(hub UAMI client-id)을 머지한 뒤 seed, #27(dev 재등록)로 dev를 붙였다. 완료 판정 7항목을 닫았다(부트스트랩 drift 없음, 7개 루트 `No changes`, `argocd app diff` exit 0, 초기 비밀번호 교체 후 `argocd-initial-admin-secret` 삭제).

**health Lua의 `Synced` 조건을 AKS에서 확인했다.** 부모가 wave 1(`kyverno`)과 wave 2 사이에서 hub 2분 54초, dev 2분 14초를 기다렸고 양쪽 다 멈추지 않고 `Healthy`로 수렴했다. dev에서 `kyverno`가 `OutOfSync` + `Healthy`인 동안, hub에서 `Synced` + `Healthy`인데 operation이 `Running`인 동안 부모가 넘어가지 않는 것을 5초 간격 기록으로 봤다.

**발표 대본의 AKS 쪽 주장을 CLI로 대조했다.** 데모 ⑤(`azure` + `overlay`, Pod CIDR `10.244.0.0/16`, NAP `Auto`, addon 구성)와 15장 두 행(Entra 통합·Azure RBAC 켜짐, 로컬 계정 꺼짐, CI 역할의 `dataActions` 없음)이 실물과 맞는다.

**`spoke-lifecycle.md` 5절에 dev aks를 hub aks apply 뒤에 거는 순서를 적었다**(aks-ref `7e5b1dc`). dev aks를 hub aks와 동시에 걸었더니 plan에 hub ArgoCD UAMI의 role assignment가 빠져 재apply가 필요했다. 걸기 전 확인 명령과 plan에서 볼 항목을 넣고, 겹치던 문단을 합쳐 400줄 한도에 맞췄다.

## 다음 할 일

### 지금

- [ ] [eks-ref·eks-gitops] 발표 전 EKS 재구축: eks-ref `hub-lifecycle.md` 구축 절 → `spoke-lifecycle.md` 구축 절. 데모에 쓰므로 hub 6절의 비밀번호 교체까지 한다 (09-30~)
- [ ] [local] EKS 구축 뒤 발표 준비: `script.md` 데모 ⑤의 포털 화면 표기(`Settings` › `Networking`, Node autoprovisioning 항목)를 눈으로 보고 캡처를 뜬 뒤 「발표 전 확인 · 전날」을 돈다. AKS 쪽 CLI 대조와 ArgoCD addon 구성 대조는 끝났다 (09-30~)
- [ ] [eks-gitops] EKS 재구축 때 health Lua의 `Synced` 조건을 확인한다: 부모가 wave 사이에서 기다리는지(addon Application 생성 시각 간격)와 전 addon이 `Synced`로 수렴해 부모가 멈추지 않는지. AKS는 확인했다. 근거: `docs/architectures/gitops-hub-spoke/ordering.md` 2절·4절 (10-02~)
- [ ] [eks-ref·aks-ref] Dependabot provider PR이 루트마다 쌓여 있다(eks-ref #71~#75 aws 6.65.0, aks-ref #72~#78 azurerm 5.6.0). `groups`로 묶을지와 발표 전에 올릴지를 사용자가 정한다(`open-pull-requests-limit`은 디렉토리별) (09-23~)
- [ ] [eks-gitops] dev 등록 직후 `gateway-api-crds` 자식이 3분쯤 `Degraded`로 남는 원인을 판다. 재구축의 dev 등록 직후 `Degraded`인 동안 `argocd app get <dev 부모>-gateway-api-crds --core -o json`의 `status.resources[].health`와 dev의 `gateway.networking.k8s.io` CRD `status.conditions`를 같은 시각에 떠 맞댄다(실물이 `Established`면 ArgoCD 갱신 지연, 아니면 클러스터 쪽). AKS에는 이 addon이 없다. 근거: `addons/cluster-addons/templates/gateway-api-crds.yaml` (10-02~)
- [ ] [eks-ref] `spoke-lifecycle.md`에 dev eks를 hub eks 뒤에 걸어야 하는 같은 의존이 있는지 EKS 재구축 때 본다. 있으면 aks-ref `spoke-lifecycle.md` 5절처럼 순서를 적는다 (10-02~)
- [ ] [aks-ref] `docs/runbooks.md`가 399줄, `docs/spoke-lifecycle.md`가 400줄이다. 다음에 내용을 더하기 전에 나눈다(`docs/writing-style.md` 1절 4번) (10-02~)
- [ ] [전체] push 권한자가 이미 2명이다(`rajaelime`, 팀 경유 `maintain`). `CLAUDE.md` 「GitOps 저장소 공통」 ⛔ 재검토 트리거가 당겨진 것으로 볼지 사용자가 정한다 (09-23~)

### 조건이 오면

- [ ] [*-gitops·module] 이 저장소들에 `id-token: write` job이 생기면: 액션 SHA 핀을 넓힌다(지금은 배포 루트만 SHA 핀) (09-23~)
- [ ] [local] context7이 rate limit에 걸리면: 키를 로컬 설정 `Authorization: Bearer`로 넣는다 (09-23~)
