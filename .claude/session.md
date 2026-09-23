# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | **hub·dev 철거 완료.** bootstrap(state 버킷·OIDC·Role)만 남았다. 네 루트의 `deletion_protection = false`가 main에 남아 있는 것은 재구축 사이클 동안의 의도다 |
| eks-platform-gitops | main = origin | **EKS 철거 상태.** `clusters/hub/`는 seed 입력으로 남겼고 `clusters/dev/`는 없다(재등록은 `spoke-lifecycle.md`) |
| aks-reference-infra | main = origin | **hub·dev 철거 완료.** state Storage Account만 남았다. vWAN `prevent_destroy`·VNet·AKS `deletion_protection`이 `false`인 것은 의도다. 로컬 `az` 기본 구독은 dev다 |
| aks-platform-gitops | main = origin | **AKS 철거 상태.** 부모 Application 구조는 ⏳ AKS 실측 전이다. `clusters/hub/`는 재구축용으로 남겼다 |

## 지난 세션 (2026-09-23)

**「재구축과 무관」 두 항목을 닫았다.** eks-ref 워크플로 3개에 apply 후 수렴 검증을 넣었다(#78 `b20dddf`). 두 gitops 저장소 `verify.yml`에 root App `include` 판정을 넣었다. ArgoCD와 같은 `gobwas/glob`을 같은 방식으로 부른다(eks-gitops #43 `5afa634`, aks-gitops #14 `d10a35a`, module `1fddfac`).

**세션 관리 구조를 재편했다.** 4절에 성격이 다른 항목 여섯 종류가 섞여 있었고, 기각 3건과 gotcha 9종이 덮어쓰는 이 파일에만 있었다. 기각은 `decisions.md`·`gitops.md`로(`1712bb4`), gotcha는 `CLAUDE.md`(`7222b7b`)·eks-ref `runbooks.md`(`7f9caf5`)·aks-ref `runbooks.md`(`a2eb208`)로, 태그 메시지 경고는 `conventions.md`로 옮겼다. `rules/session.md`는 4절을 트리거별 소절로 나누고 항목 형식·60일 재확인을 정했다(`c3bb706`). `~/archive/` 삭제. 옛 항목의 서술 원문은 `git log -p -- .claude/session.md`에 있다.

## 다음 할 일

EKS·AKS hub·dev 모두 철거된 상태다. 클라우드별 「구축·철거와 같이」 절은 다음 재구축 일정이 정해질 때 만든다. 그때 4절의 해당 재구축 소절을 통째로 옮긴다.

### 1. 재구축과 무관 — 아무 때나

- [ ] [전체] push 권한자가 이미 2명이다(`rajaelime`, 팀 경유 `maintain`). 「작업자 2인 이상」 트리거가 이미 당겨진 것으로 볼지 사용자가 판단한다. 당겨졌다면 아래 조직·권한 항목을 연다 (09-23~)

### 2. 조건이 오면 (지금 하지 않는다)

#### EKS 재구축

- [ ] [eks-ref] 첫 apply: `hub/eks`·`dev/eks`·`dev/networking`의 수렴 검증이 처음 돈다. `2`로 실패하면 그 루트의 영구 diff부터 본다 (09-23~)
- [ ] [eks-gitops] seed에서 CRD health 고착이 다시 나오면: `argocd app get <crd-app> --core`로 CRD별 health를 남긴다. 재현이 쌓이면 CRD만 `ignoreResourceUpdates`에서 빼는 안을 검토한다 (09-23~)
- [ ] [eks-ref] 철거하지 않고 남기기로 하면: 네 루트의 `deletion_protection`을 `true`로 되돌린다 (09-23~)

#### AKS 재구축

- [ ] [aks-gitops·aks-ref] seed·철거: EKS에서 실측한 wave 대기·라벨 해제·잔존물 0과 차이만 본다(Kyverno가 NodePool 뒤에 뜨는지, PreDelete 훅이 NAP 노드에서 도는지). 되면 `ordering.md` 4절 AKS 단서와 AKS `spoke-lifecycle.md` ⏳를 걷는다 (09-23~)
- [ ] [aks-ref] hub 철거: `environment` 라벨 제거로 addon 해제를 시험하고, 되면 AKS `hub-lifecycle.md` 철거 절을 EKS 11절 형태로 바꾼다 (09-23~)
- [ ] [aks-ref] hub 구축: `vwan`·`aks` 병렬 apply를 실측한다(`AnotherOperationInProgress` 여부, `rerun --failed` 복구). 근거 `docs/hub-lifecycle.md` (09-23~)
- [ ] [aks-ref] 재구축이 끝나면: vWAN `prevent_destroy`, VNet·AKS `deletion_protection`을 `true`로 되돌린다 (09-23~)

#### 버전·릴리스

- [ ] [eks-gitops] 새 AL2023 AMI: `amiAliasByTier.nonprd`에 먼저 올리고 dev에서 노드 기동을 본 뒤 prd에 올린다 (09-23~)
- [ ] [*-gitops] 차트 새 버전: `versions.<addon>.nonprd`를 먼저 올려 nonprd→prd 승격을 실측한다. 절차는 `CLAUDE.md` 「GitOps 저장소 공통」의 버전 핀·자기 관리 ArgoCD 행 (09-23~)
- [ ] [module] `workbench`·`aks-workbench` 기능 태그: 태그 메시지에 교체 예고를 싣는다(`conventions.md` 「부팅 템플릿이 바뀐 태그는 교체를 예고한다」) (09-23~)
- [ ] [module] `aks-cluster` 다음 기능 릴리스: 예시 SKU 변경(`4f4bb10`)을 싣는다 (09-23~)

#### 조직·권한

- [ ] [전체] 작업자가 2인 이상이 되면: ruleset 승인 수·`require_last_push_approval`·`dismiss_stale_reviews_on_push`, environment 두 번째 reviewer·`prevent_self_review`, 문서 직접 커밋과 admin bypass를 다시 본다 (09-23~)
- [ ] [*-gitops·module] 이 저장소들에 `id-token: write` job이 생기면: 액션 SHA 핀을 넓힌다 (09-23~)

#### 기타

- [ ] [aks-ref·eks-ref] apply가 실패하면: `gh run rerun --failed`가 승인된 plan을 그대로 쓰는지 확인한다 (09-23~)
- [ ] [aks-ref·eks-ref] 승인 게이트가 7일 넘게 방치된 run이 생기면: artifact 만료 뒤 apply가 어떻게 실패하는지 관찰한다. 일부러 만들지 않는다 (09-23~)
- [ ] [eks-ref·aks-ref] 재구축 뒤 Dependabot provider PR이 루트마다 따로 쌓이면: `groups`로 묶을지 정한다(`open-pull-requests-limit`은 디렉토리별) (09-23~)
- [ ] [aks-ref] AKS에 실 워크로드를 올리게 되면: 시스템 풀 2대(권고 3대 미부합을 알고 수락한 값)를 다시 판단한다 (09-23~)
- [ ] [local] context7이 rate limit에 걸리면: 키를 로컬 설정 `Authorization: Bearer`로 넣는다 (09-23~)
