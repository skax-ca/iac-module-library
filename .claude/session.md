# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `iac-module-library`). 형제 저장소에는
session.md를 두지 않는다. 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | **hub·dev 철거 상태(09-30, 구축·철거 한 사이클을 더 돌렸다), 발표(10-07) 전에 재구축한다.** 두 계정 잔존물 0건, 부트스트랩(state 버킷·OIDC·Role)만 남았다. 네 루트의 `deletion_protection = false`는 의도다 |
| eks-platform-gitops | main = origin | **EKS 철거 상태.** hub Secret은 `environment` 라벨을 되돌려 seed 입력이 준비돼 있다. dev Secret은 라벨 없이 파일로 남아 있고 `server`·`caData`는 철거된 클러스터 값이다 |
| aks-reference-infra | main = origin | **hub·dev 철거 상태, 발표 전에 재구축한다.** state Storage Account만 남았다. vWAN `prevent_destroy`·VNet·AKS `deletion_protection`이 `false`인 것은 의도다. 로컬 `az` 기본 구독은 dev다 |
| aks-platform-gitops | main = origin | **AKS 철거 상태.** 부모 Application 구조는 ⏳ AKS 실측 전이다. `clusters/hub/`는 재구축용으로 남겼다 |

## 지난 세션 (2026-09-30, 오후)

**할 일에는 문서가 모르는 것만 두도록 세션 규칙을 줄였다**(`64179ea`). 28개 중 약 3분의 2가 lifecycle 절차·⏳·`CLAUDE.md`의 사본이었다. 판정을 "지워도 문서를 따라가면 같은 일이 일어나는가" 하나로 바꾸고 소절을 `지금`·`조건이 오면` 둘로 줄였다. 작업자 2인 트리거의 점검 항목은 `CLAUDE.md` 재검토 행으로, CRD health 고착 대응은 eks-ref runbooks로 옮겼다.

**부모 생성 사슬의 이름을 바꿨다.** ApplicationSet `platform` → `cluster-addons`, 부모 `<cluster>-platform` → `<cluster>-addons`, 차트 `addons/platform/` → `addons/cluster-addons/`, 라벨 `platform.*` → `addon.name`·`addon.cluster`·`addon.wave`. AppProject `platform`은 유지했다. 설계 `5cbe0a5` → eks-gitops #49 · aks-gitops #15 → 배포 루트 문서 → 발표 `article.md`·`script.md`와 Notion 배포본.

**EKS를 두 번 철거하고 한 번 재구축했다**(eks-gitops #45~#53). 첫 철거로 `converge-check.sh --destroy`를, 재구축으로 태거 diff 경고 경로와 새 이름(구축·해제 wave 순서)을 처음 실측했다. dev 등록 파일은 지우지 않고 라벨만 떼는 방식으로 바꿔 두 번째 철거에서 실측했다(eks-ref `40ead8b`). 엔드포인트를 DNS·PrivateLink로 고정하는 안은 조사 뒤 「하지 않는 것」에 뒀다(`d13c787`).

## 다음 할 일

### 지금

- [ ] [eks-ref·eks-gitops] 발표 전 EKS 재구축: eks-ref `hub-lifecycle.md` 구축 절 → `spoke-lifecycle.md` 구축 절. dev 재등록은 14절의 새 방식(남겨 둔 파일에서 `server`·`caData` 교체 + `environment` 복원, 한 커밋)이 처음 도는 자리다. 데모에 쓰므로 hub 6절의 비밀번호 교체까지 한다 (09-30~)
- [ ] [aks-ref·aks-gitops] 발표 전 AKS 재구축: aks-ref `hub-lifecycle.md` 구축 절 → `spoke-lifecycle.md` 구축 절. 이번에 실측한 ⏳를 걷는다(`grep -rn '⏳' docs/ ../iac-module-library/docs/architectures/gitops-hub-spoke`) (09-23~)
- [ ] [local] AKS 구축 뒤 발표 준비: `script.md` 데모 ⑤를 실물과 대조하고(포털 `Networking`의 `Azure CNI Overlay`·NAP 표시, AKS ArgoCD addon 목록) 「발표 전 확인 · 전날」을 돈다. ArgoCD 앱 수가 바뀌면 위 표의 hub 13 · dev 11도 고친다 (09-30~)
- [ ] [전체] push 권한자가 이미 2명이다(`rajaelime`, 팀 경유 `maintain`). `CLAUDE.md` 「GitOps 저장소 공통」 ⛔ 재검토 트리거가 당겨진 것으로 볼지 사용자가 정한다 (09-23~)
- [ ] [eks-ref] `bootstrap.sh`의 `converge_bucket`이 `$(...)` 서브셸에서 돌아 버킷 변경이 `변경 N건`에 안 잡힌다(실측 8건 중 5건 보고). 셸이라 브랜치 → PR (09-29~)

### 조건이 오면

- [ ] [aks-ref·aks-gitops] AKS를 걷어낼 때: 철거 절을 따르고 ⏳를 걷는다. spoke 등록 파일은 EKS처럼 지우지 않고 라벨만 떼는 방식으로 바꾼다(eks-ref `spoke-lifecycle.md` 10절 ⑥·14절, aks-ref `spoke-lifecycle.md` 10절). hub는 `environment` 라벨 제거로 addon 해제를 시험해, 되면 aks-ref `hub-lifecycle.md` 12절을 eks-ref `hub-lifecycle.md` 11절 형태로 바꾼다 (09-23~)
- [ ] [*-gitops·module] 이 저장소들에 `id-token: write` job이 생기면: 액션 SHA 핀을 넓힌다(지금은 배포 루트만 SHA 핀) (09-23~)
- [ ] [eks-ref·aks-ref] 재구축 뒤 Dependabot provider PR이 루트마다 따로 쌓이면: `groups`로 묶을지 정한다(`open-pull-requests-limit`은 디렉토리별) (09-23~)
- [ ] [local] context7이 rate limit에 걸리면: 키를 로컬 설정 `Authorization: Bearer`로 넣는다 (09-23~)
