# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `iac-module-library`). 형제 저장소에는
session.md를 두지 않는다. 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | **hub·dev 철거 상태(09-30, 구축·철거 한 사이클을 더 돌렸다), 발표(10-07) 전에 재구축한다.** 두 계정 잔존물 0건, 부트스트랩(state 버킷·OIDC·Role)만 남았다. 네 루트의 `deletion_protection = false`는 의도다 |
| eks-platform-gitops | main = origin | **EKS 철거 상태.** hub Secret은 `environment` 라벨을 되돌려 seed 입력이 준비돼 있다. dev Secret은 라벨 없이 파일로 남아 있고 `server`·`caData`는 철거된 클러스터 값이다 |
| aks-reference-infra | main = origin | **hub·dev 철거 상태(10-01, 구축·철거 한 사이클을 돌렸다), 발표 전에 재구축한다.** 두 구독 잔존물 0건, state Storage Account만 남았다. hub 구독은 다른 프로젝트(azure-dmz-hcp)와 공용이다. vWAN `prevent_destroy`·VNet·AKS `deletion_protection`이 `false`인 것은 의도다. 로컬 `az` 기본 구독은 hub다 |
| aks-platform-gitops | main = origin | **AKS 철거 상태.** hub Secret은 `environment` 라벨을 되돌려 seed 입력이 준비돼 있다. dev Secret은 라벨 없이 파일로 남아 있고 `server`·`caData`·`AZURE_CLIENT_ID`는 철거된 클러스터 값이다. `bootstrap/argocd-values.yaml`의 client-id도 철거된 hub UAMI 값이다 |

## 지난 세션 (2026-10-01)

**클러스터 인증을 클라우드 신원 하나로 좁혔다**(설계 `9a6ba21`). AKS hub는 Entra 통합 없이 돌아 workbench의 `Cluster User Role`이 관리자 kubeconfig를 내려주고 있었다. hub에 Entra 통합을 켜고 두 클러스터의 로컬 계정을 껐으며, hub workbench를 dev와 같은 kubelogin 경로로 맞췄다(aks-ref #80 `08dbc9f`). 모듈 태그는 그대로다.

**EKS는 인증 모드를 `API`로 고정하고 CI 실행 Role의 클러스터 관리자 Access Entry를 없앴다**(module #62 `623bb30` → 태그 `eks-cluster-v0.12.0` → eks-ref #81 `245b172`). upstream의 `enable_cluster_creator_admin_permissions`는 변수로 열지 않고 넘기지 않는다. 계약 테스트 둘을 더했고, `true`로 되돌리면 둘 다 실패한다. 전부 철거 상태에서 넣어 apply는 하지 않았다. 머지로 깨어난 push plan 6개는 조회 실패로 끝났고 게이트는 서지 않았다.

**그 밖**: eks-ref `bootstrap.sh`의 버킷 변경이 `변경 N건`에서 빠지던 것을 고쳤다(#80 `3282bff`). `AADSSHLoginForLinux` 확장이 dev workbench에만 있다는 aks-ref 문서 서술을 고쳤다(모듈의 `entra_ssh_login_enabled`가 양쪽에 만든다). 발표 `script.md` 예상 질문 표에 15장 두 행(사람의 클러스터 접근·접근 상실 복구)을 넣었다.

## 다음 할 일

### 지금

- [ ] [eks-ref·eks-gitops] 발표 전 EKS 재구축: eks-ref `hub-lifecycle.md` 구축 절 → `spoke-lifecycle.md` 구축 절. dev 재등록은 14절의 새 방식(남겨 둔 파일에서 `server`·`caData` 교체 + `environment` 복원, 한 커밋)이 처음 도는 자리다. 데모에 쓰므로 hub 6절의 비밀번호 교체까지 한다. 부트스트랩 재실행의 `변경 0건`과, 클러스터의 `accessConfig.authenticationMode`가 `API`이고 `list-access-entries`에 CI 실행 Role이 없는지도 본다(plan 테스트가 못 보는 값이다) (09-30~)
- [ ] [aks-ref·aks-gitops] 발표 전 AKS 재구축: aks-ref `hub-lifecycle.md` 구축 절 → `spoke-lifecycle.md` 구축 절. hub workbench가 kubelogin 경로로 처음 선다. `spoke-lifecycle.md` 상단과 `runbooks.md` 「클러스터에 접근하기」의 ⏳를 걷는다. 데모에 쓰므로 hub 7절의 비밀번호 교체까지 한다 (10-01~)
- [ ] [local] 두 클라우드 구축 뒤 발표 준비: `script.md` 데모 ⑤의 포털 화면(`Networking`의 `Azure CNI Overlay`·NAP 표시)과 예상 질문 표의 15장 두 행을 실물과 대조하고 「발표 전 확인 · 전날」을 돈다. ArgoCD addon 구성의 CLI 대조는 끝났다 (09-30~)
- [ ] [전체] push 권한자가 이미 2명이다(`rajaelime`, 팀 경유 `maintain`). `CLAUDE.md` 「GitOps 저장소 공통」 ⛔ 재검토 트리거가 당겨진 것으로 볼지 사용자가 정한다 (09-23~)
- [ ] [module] `aks-cluster` `variables.tf`의 `G2 확정` 표기 3곳은 가리키는 기록이 저장소에 없다. 지우거나 이유로 바꾼다. `.tf`라 브랜치 → PR (10-01~)

### 조건이 오면

- [ ] [*-gitops·module] 이 저장소들에 `id-token: write` job이 생기면: 액션 SHA 핀을 넓힌다(지금은 배포 루트만 SHA 핀) (09-23~)
- [ ] [eks-ref·aks-ref] 재구축 뒤 Dependabot provider PR이 루트마다 따로 쌓이면: `groups`로 묶을지 정한다(`open-pull-requests-limit`은 디렉토리별) (09-23~)
- [ ] [local] context7이 rate limit에 걸리면: 키를 로컬 설정 `Authorization: Bearer`로 넣는다 (09-23~)
