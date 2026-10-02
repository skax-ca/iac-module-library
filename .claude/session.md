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

**지난 세션의 인증 변경을 EKS·AKS 구축 → 검증 → 철거 한 사이클로 실환경 검증했다.** EKS hub·dev는 `authenticationMode`가 `API`이고 Access Entry에 CI 실행 Role이 없으며 workbench가 자기 Role로 들어간다. AKS hub·dev는 로컬 계정이 꺼져 `get-credentials --admin`이 거부되고, workbench kubeconfig는 `kubelogin --login msi`뿐이다(hub workbench가 이 경로로 처음 섰다). 남긴 Secret을 고쳐 되살리는 dev 재등록도 양쪽에서 처음 돌아 통과했다(eks-gitops #55, aks-gitops #21·#22). 철거는 라벨 제거(#56, #23) → destroy → 잔존물 검증 exit 0 → hub 라벨 복원(#57, #24)까지 했다. ArgoCD 비밀번호 교체는 바로 철거할 사이클이라 건너뛰었다.

**aks-ref 문서에 실측을 옮겼다**(`c3cab24`·`48fa3c5`). `runbooks.md`: `command invoke`는 호출자 신원에 클러스터 스코프 `RBAC Cluster Admin`이 있어야 하고(구독 `Owner`로는 `Forbidden`), 명령 파드가 NAP 노드를 필요로 해 NodePool이 없으면 통하지 않는다. 접근 상실 복구 절차(역할 부여 → 호출 → 삭제)도 통했다. `hub-lifecycle.md`: vwan과 aks의 apply를 동시에 건다, seed 직후 `argocd app diff`는 흡수 sync 뒤에 본다. `spoke-lifecycle.md`: 재등록 ⏳를 걷었다.

## 다음 할 일

### 지금

- [ ] [eks-ref·eks-gitops] 발표 전 EKS 재구축: eks-ref `hub-lifecycle.md` 구축 절 → `spoke-lifecycle.md` 구축 절. 데모에 쓰므로 hub 6절의 비밀번호 교체까지 한다 (09-30~)
- [ ] [aks-ref·aks-gitops] 발표 전 AKS 재구축: aks-ref `hub-lifecycle.md` 구축 절 → `spoke-lifecycle.md` 구축 절. 데모에 쓰므로 hub 7절의 비밀번호 교체까지 한다 (10-01~)
- [ ] [local] 두 클라우드 구축 뒤 발표 준비: `script.md` 데모 ⑤의 포털 화면(`Networking`의 `Azure CNI Overlay`·NAP 표시)과 예상 질문 표의 15장 두 행을 실물과 대조하고 「발표 전 확인 · 전날」을 돈다. ArgoCD addon 구성의 CLI 대조는 끝났다 (09-30~)
- [ ] [eks-ref·aks-ref] Dependabot provider PR이 루트마다 쌓여 있다(eks-ref #71~#75 aws 6.65.0, aks-ref #72~#78 azurerm 5.6.0). `groups`로 묶을지와 발표 전에 올릴지를 사용자가 정한다(`open-pull-requests-limit`은 디렉토리별) (09-23~)
- [ ] [eks-gitops] dev 등록 직후 `gateway-api-crds` 자식이 sync 성공 뒤에도 3분쯤 `Degraded`로 남아 부모 sync가 5회 재시도했다(전체 수렴 약 14분, 스스로 회복). 원인을 팔지 사용자가 정한다. 데모에서 dev 등록을 보여 주면 걸린다 (10-02~)
- [ ] [aks-ref] `docs/runbooks.md`가 399줄이다. 다음에 내용을 더하기 전에 나눈다(`docs/writing-style.md` 1절 4번) (10-02~)
- [ ] [전체] push 권한자가 이미 2명이다(`rajaelime`, 팀 경유 `maintain`). `CLAUDE.md` 「GitOps 저장소 공통」 ⛔ 재검토 트리거가 당겨진 것으로 볼지 사용자가 정한다 (09-23~)
- [ ] [module] `aks-cluster` `variables.tf`의 `G2 확정` 표기 3곳은 가리키는 기록이 저장소에 없다. 지우거나 이유로 바꾼다. `.tf`라 브랜치 → PR (10-01~)

### 조건이 오면

- [ ] [*-gitops·module] 이 저장소들에 `id-token: write` job이 생기면: 액션 SHA 핀을 넓힌다(지금은 배포 루트만 SHA 핀) (09-23~)
- [ ] [local] context7이 rate limit에 걸리면: 키를 로컬 설정 `Authorization: Bearer`로 넣는다 (09-23~)
