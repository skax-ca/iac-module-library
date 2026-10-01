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

**AKS를 구축부터 철거까지 한 사이클 돌렸다**(aks-gitops #16~#20). 7개 루트를 재구축하고 재-plan 수렴(전부 `No changes`)까지 확인한 뒤 철거해 두 구독 잔존물 0건을 확인했다. 그 과정에서 문서 결함 셋을 고쳤다: spoke 부트스트랩의 `HUB_SUBSCRIPTION` 누락, hub 재구축 때 seed 전에 `argocd-values.yaml` client-id를 갱신해야 한다는 안내, 낡은 모듈 ref 이력 서술(aks-ref `51eaaaf`·`002a7bb`).

**철거를 EKS처럼 "파일을 두고 `environment` 라벨만 뗀다"로 바꿨고, hub addon도 같은 라벨 해제로 지운다**(aks-ref `51eaaaf`·`0c6433e`). hub·dev 라벨을 한 PR(#19)로 떼어 48초 만에 cascade가 끝나는 것을 실측했다. Kyverno를 지운 뒤 webhook 설정이 남는다는 점은 부분 삭제 절에 적었다(`4f16550`).

**wave 번호를 역할에서 정하고 AKS Kyverno를 시스템 풀에 고정했다**(설계 `a8382dd` → aks-gitops #18 → aks-ref `33fa36b`). azure-dmz의 배치를 참고했다. 앱이 없는 hub의 NAP 노드에는 Kyverno만 떠 있었다. 바꾼 뒤 같은 addon이 EKS와 같은 wave에 서고, NAP 노드가 0대로 consolidate되며, 해제 때 삭제 훅이 시스템 풀에서 Pending 없이 끝나는 것을 확인했다. 그 밖에 job 로그 API로 승인 대기 중인 plan을 읽는 법을 `CLAUDE.md`에 적고(`e73dac4`), EKS Kyverno values의 낡은 주석을 걷었다(eks-gitops #54).

## 다음 할 일

### 지금

- [ ] [eks-ref·eks-gitops] 발표 전 EKS 재구축: eks-ref `hub-lifecycle.md` 구축 절 → `spoke-lifecycle.md` 구축 절. dev 재등록은 14절의 새 방식(남겨 둔 파일에서 `server`·`caData` 교체 + `environment` 복원, 한 커밋)이 처음 도는 자리다. 데모에 쓰므로 hub 6절의 비밀번호 교체까지 한다 (09-30~)
- [ ] [aks-ref·aks-gitops] 발표 전 AKS 재구축: aks-ref `hub-lifecycle.md` 구축 절 → `spoke-lifecycle.md` 구축 절. dev 재등록이 14절 새 방식으로 처음 도는 자리라 상단 ⏳를 걷는다. 데모에 쓰므로 hub 7절의 비밀번호 교체까지 한다 (10-01~)
- [ ] [local] 두 클라우드 구축 뒤 발표 준비: `script.md` 데모 ⑤의 포털 화면(`Networking`의 `Azure CNI Overlay`·NAP 표시)을 실물과 대조하고 「발표 전 확인 · 전날」을 돈다. ArgoCD addon 구성의 CLI 대조는 끝났다 (09-30~)
- [ ] [전체] push 권한자가 이미 2명이다(`rajaelime`, 팀 경유 `maintain`). `CLAUDE.md` 「GitOps 저장소 공통」 ⛔ 재검토 트리거가 당겨진 것으로 볼지 사용자가 정한다 (09-23~)
- [ ] [eks-ref] `bootstrap.sh`의 `converge_bucket`이 `$(...)` 서브셸에서 돌아 버킷 변경이 `변경 N건`에 안 잡힌다(실측 8건 중 5건 보고). 셸이라 브랜치 → PR (09-29~)

### 조건이 오면

- [ ] [*-gitops·module] 이 저장소들에 `id-token: write` job이 생기면: 액션 SHA 핀을 넓힌다(지금은 배포 루트만 SHA 핀) (09-23~)
- [ ] [eks-ref·aks-ref] 재구축 뒤 Dependabot provider PR이 루트마다 따로 쌓이면: `groups`로 묶을지 정한다(`open-pull-requests-limit`은 디렉토리별) (09-23~)
- [ ] [local] context7이 rate limit에 걸리면: 키를 로컬 설정 `Authorization: Bearer`로 넣는다 (09-23~)
