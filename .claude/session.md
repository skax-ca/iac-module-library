# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `iac-module-library`). 형제 저장소에는
session.md를 두지 않는다. 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | **hub·dev 구축 완료. 발표 데모에 쓰므로 발표가 끝날 때까지 철거하지 않는다.** hub 부트스트랩은 계정 관리자 정리 뒤 새로 만들었다(버킷명 변경). 네 루트의 `deletion_protection = false`는 철거를 위한 의도다. hub ArgoCD 초기 비밀번호는 철거 예정이라 교체하지 않았다 |
| eks-platform-gitops | main = origin | **hub·dev 등록, 전 Application `Synced`/`Healthy`**(hub 13 · dev 11). `clusters/dev/`가 다시 있다 |
| aks-reference-infra | main = origin | **hub·dev 철거 상태, 발표 전에 재구축한다.** state Storage Account만 남았다. vWAN `prevent_destroy`·VNet·AKS `deletion_protection`이 `false`인 것은 의도다. 로컬 `az` 기본 구독은 dev다 |
| aks-platform-gitops | main = origin | **AKS 철거 상태.** 부모 Application 구조는 ⏳ AKS 실측 전이다. `clusters/hub/`는 재구축용으로 남겼다 |

## 지난 세션 (2026-09-30)

**발표 스크립트를 20분 라이브 데모판으로 다시 썼다**(`.local/presentations/2026-09-iac-asset/script.md`, 33분판은 폐기). 파트마다 장표 뒤에 실물 데모를 하나씩 붙였다: GitHub org·태그, Actions 승인 run, 버전 표와 EKS ArgoCD, AWS 콘솔, Azure 포털과 AKS ArgoCD, `aks-cluster` 태그, 두 저장소의 `gateway.yaml`. 탭 12개 순서, 발표 30분 전 체크리스트, 밀릴 때 빼는 순서를 같이 적었다.

**데모를 실물과 대조하다가 10장이 낡은 것을 찾아 고쳤다.** 슬라이드와 article은 addon마다 ApplicationSet을 두고 tier별로 나눈 구조(`1.15.0`/`1.14.0`)였는데, 실물은 단일 ApplicationSet `platform` + 부모 차트 + `versions` 표(`1.14.1`/`1.14.1`)다. `slides.html` 10장과 `article.md` 2.2를 실물 기준으로 고쳤다. Notion 배포본 본문은 `article.md` 기준으로 부분 치환해 맞췄고(1.3·1.5·2.2·4.5·닫으며), 슬라이드 첨부는 사용자가 직접 다시 올려 확인했다.

허브 세션 alias 이름을 `claude-code`에서 `iac-module-library`로 바꿨다(`~/.zshrc`, `.local/claude-workspace.md`).

## 다음 할 일

### 1. AKS 구축·철거와 같이 (발표 전)

#### 구축 중

- [ ] [aks-ref] hub 구축: `vwan`·`aks` 병렬 apply를 실측한다(`AnotherOperationInProgress` 여부, `rerun --failed` 복구). 근거 `docs/hub-lifecycle.md` (09-23~)
- [ ] [aks-gitops·aks-ref] seed: EKS에서 실측한 wave 대기와 차이만 본다(Kyverno가 NodePool 뒤에 뜨는지). 되면 `ordering.md` 4절 AKS 단서와 AKS `spoke-lifecycle.md` ⏳ 중 seed 쪽을 걷는다 (09-23~)

#### 구축 후

- [ ] [local] 데모 ⑤를 실물과 대조한다: 포털 `Networking`의 `Azure CNI Overlay`·NAP 표시 위치, AKS ArgoCD addon 목록. 다르면 `script.md` 데모 ⑤ 문구를 고친다 (09-30~)
- [ ] [local] `script.md` 「발표 전 확인 · 전날」: 두 ArgoCD 전 앱 `Synced`, 데모 ② run 선택, 데모마다 캡처. ArgoCD 앱 수가 바뀌었으면 위 표의 hub 13 · dev 11도 고친다 (09-30~)

### 2. EKS 구축·철거와 같이

#### 철거 중 (발표가 끝난 뒤)

- [ ] [eks-gitops·eks-ref] dev 먼저 철거: `environment` 라벨 제거 PR → wave 역순 해제 확인 → `dev/eks`·`dev/networking` destroy → `teardown-verify.sh`(`AWS_PROFILE=asset`). 근거 eks-ref `spoke-lifecycle.md` 10~12절
- [ ] [eks-ref] dev만 걷힌 상태에서 hub networking `action=plan`으로 잔존 라우트(TGW static 1 + VPC 4)를 본다. 근거 `spoke-lifecycle.md` 13절
- [ ] [eks-gitops·eks-ref] hub 철거: 라벨 제거 PR → `hub/eks` → `hub/networking` → `hub/tgw` destroy → `teardown-verify.sh`. 근거 `hub-lifecycle.md` 11~13절
- [ ] [eks-ref] `hub/eks`·`dev/eks` destroy 뒤 `converge-check.sh --destroy` 경로가 처음 돈다. 실패하면 남은 diff부터 본다

#### 철거 후

- [ ] [eks-gitops] hub cluster Secret의 라벨 제거 커밋을 되돌린다(다음 seed 입력). dev Secret은 철거 중 10절 ⑥에서 파일째 지운다. 근거 `hub-lifecycle.md` 11절

### 3. 재구축과 무관 — 아무 때나

- [ ] [전체] push 권한자가 이미 2명이다(`rajaelime`, 팀 경유 `maintain`). 「작업자 2인 이상」 트리거가 이미 당겨진 것으로 볼지 사용자가 판단한다. 당겨졌다면 아래 조직·권한 항목을 연다 (09-23~)
- [ ] [eks-ref] `bootstrap.sh`의 `converge_bucket`이 `$(...)` 서브셸에서 돌아 버킷 변경이 `변경 N건`에 안 잡힌다(실측 8건 중 5건 보고). 셸이라 브랜치 → PR (09-29~)

### 4. 조건이 오면 (지금 하지 않는다)

#### EKS 재구축

- [ ] [eks-gitops] seed에서 CRD health 고착이 다시 나오면: `argocd app get <crd-app> --core`로 CRD별 health를 남긴다. 재현이 쌓이면 CRD만 `ignoreResourceUpdates`에서 빼는 안을 검토한다 (09-23~)
- [ ] [eks-ref] 철거하지 않고 남기기로 하면: 네 루트의 `deletion_protection`을 `true`로 되돌린다 (09-23~)
- [ ] [eks-ref] hub workbench가 다시 생기면(재구축·도구 핀 상향): `converge-check.sh`의 경고 통과 경로가 CI에서 처음 도는지 본다. 근거 `scripts/README.md` (09-29~)

#### AKS 철거

- [ ] [aks-gitops·aks-ref] 철거: EKS에서 실측한 라벨 해제·잔존물 0과 차이만 본다(PreDelete 훅이 NAP 노드에서 도는지). 되면 AKS `spoke-lifecycle.md` ⏳ 중 철거 쪽을 걷는다 (09-23~)
- [ ] [aks-ref] hub 철거: `environment` 라벨 제거로 addon 해제를 시험하고, 되면 AKS `hub-lifecycle.md` 철거 절을 EKS 11절 형태로 바꾼다 (09-23~)
- [ ] [aks-ref] 철거하지 않고 남기기로 하면: vWAN `prevent_destroy`, VNet·AKS `deletion_protection`을 `true`로 되돌린다 (09-23~)

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
