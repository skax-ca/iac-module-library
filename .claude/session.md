# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `iac-module-library`). 형제 저장소에는
session.md를 두지 않는다. 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | **hub·dev 철거 상태(10-13).** 5개 루트를 전부 destroy했고 `teardown-verify.sh`가 두 계정에서 exit 0이다. bootstrap 소유물(state 버킷·OIDC provider·입구/실행 Role)은 남아 있다. 다음 구축은 Kubernetes 1.36으로 선다. 네 루트의 `deletion_protection = false`는 의도다. hub 계정에는 새 EBS 볼륨의 `Name` 태그를 덮어쓰는 Lambda(`ResourceTaggingFunction`)가 돈다 |
| eks-platform-gitops | main = origin | **EKS 철거 상태.** hub Secret은 `environment` 라벨이 있다(다음 seed의 입력). dev Secret은 `environment` 라벨이 없고 접속 값은 파기된 클러스터의 것이다. hub ArgoCD는 HA 구성이라 seed가 Ready인 system 노드 3대를 요구한다. Karpenter 노드가 있는 상태의 철거는 확인하지 않았다 |
| aks-reference-infra | main = origin | **hub·dev 철거 상태(10-07).** 7개 루트를 전부 destroy했고 `teardown-verify.sh`가 두 구독에서 exit 0이다. bootstrap 소유물(state Storage Account·App Registration·RG)은 남아 있다. hub 구독은 다른 프로젝트(azure-dmz-hcp)와 공용이다. vWAN `prevent_destroy`·VNet·AKS `deletion_protection`이 `false`인 것은 의도다. 로컬 `az` 기본 구독은 hub다 |
| aks-platform-gitops | main = origin | **AKS 철거 상태.** hub Secret은 `environment` 라벨이 있다(다음 seed의 입력). dev Secret은 `environment` 라벨이 없고 접속 값은 파기된 클러스터의 것이다 |

## 지난 세션 (2026-10-12 ~ 10-13)

**EKS hub·dev를 1.35로 세워 1.36으로 올리고 철거했다.** 컨트롤플레인과 노드그룹을 다른 apply로 나누려고 노드그룹별 `kubernetes_version`을 모듈에 넣었다(module #65, `eks-cluster-v0.15.0`). dev는 올렸다가 1.35로 되돌린 뒤 다시 올렸고, hub는 다시 쓴 절차서만 보고 따라 올렸다. 두 클러스터의 전 구간에서 복제본 2개에 PDB를 건 측정용 워크로드의 호출 실패가 0건이었다.

**절차를 세 문서로 갈랐다.** 따라 하는 절차는 eks-ref `docs/upgrade.md`(`9b0af19`·`f5ed1dd`), 되돌리기는 `docs/upgrade-rollback.md`(`3785d08`·`fb03d80`), 순서의 근거와 기각한 안은 module `docs/architectures/gitops-hub-spoke/aws/upgrade.md`(`81f6e16`)다. 되돌리기에서 system 노드그룹의 버전 하향이 in-place로 받아들여지는 것과, 새 마이너로 뜬 Karpenter 노드가 있으면 `--force`가 필요한 것을 확인했다.

**GitOps에 티어별 스위치를 넣었다.** hub ArgoCD를 HA로 바꾸고(eks-gitops #72), NodePool 차트에 `capacityTypesByTier`·`disruptionByTier`·`disruptionBlockByTier`를 두었다(#78·#81·#89). cluster-autoscaler는 이미지 태그를 티어별로 승격한다(#74). prd 티어를 실제로 켠 PR에서 격리 검사가 틀리는 것을 고쳤다(#86).

**hub 계정의 태깅 자동화가 plan에 drift 한 줄을 남기는 것을 찾았다.** hub의 완료 판정에서 드리프트 plan이 `No changes`가 아니어서 CloudTrail로 원인을 확인했다. eks-ref `docs/upgrade.md` 「hub를 올릴 때 다른 점」에 적었다.

## 다음 할 일

### 지금

- [ ] [eks-ref·module] hub 계정의 Lambda가 workbench 볼륨의 `Name`을 덮어써 hub `eks` 루트의 plan에 `volume_tags` 한 줄이 남는다. workbench 모듈이 볼륨 이름을 인스턴스 이름에 맞출지, 변경을 무시할지, Lambda를 고칠지 사용자가 정한다(eks-ref `docs/upgrade.md` 「hub를 올릴 때 다른 점」) (10-13~)
- [ ] [eks-gitops] ArgoCD 컴포넌트에 requests가 없다. application-controller가 545~685Mi를 썼다. 값을 정해 `bootstrap/argocd-values.yaml`에 넣는다(철거 상태인 지금이 넣을 때다) (10-13~)
- [ ] [eks-ref·aks-ref] Dependabot PR이 쌓여 있다(eks-ref 6건, aks-ref 8건). `groups`로 묶을지와 언제 올릴지를 사용자가 정한다(`open-pull-requests-limit`은 디렉토리별) (09-23~)
- [ ] [eks-ref·aks-ref] eks-ref `docs/upgrade.md`가 400줄, aks-ref `docs/runbooks.md`가 399줄·`docs/spoke-lifecycle.md`가 400줄이다. 다음에 내용을 더하기 전에 나눈다(`docs/writing-style.md` 1절 4번) (10-02~)
- [ ] [전체] push 권한자가 이미 2명이다(`rajaelime`, 팀 경유 `maintain`). `CLAUDE.md` 「GitOps 저장소 공통」 ⛔ 재검토 트리거가 당겨진 것으로 볼지 사용자가 정한다 (09-23~)

### 조건이 오면

- [ ] [eks-ref] EKS를 다시 세워 마이너를 올리게 되면: `docs/upgrade.md`·`docs/upgrade-rollback.md`의 ⏳를 걷는다 (10-13~)
- [ ] [eks-gitops] EKS를 다시 세우면: nonprd의 `disruptionByTier`에 Karpenter `Balanced` consolidation을 시험한다(`addons/karpenter/nodepool/values.yaml`) (10-13~)
- [ ] [aks-ref·aks-gitops] AKS의 마이너 업그레이드를 하게 되면: EKS의 세 문서와 같은 구성으로 절차를 세운다(module `docs/architectures/gitops-hub-spoke/aws/upgrade.md`) (10-13~)
- [ ] [*-gitops·module] 이 저장소들에 `id-token: write` job이 생기면: 액션 SHA 핀을 넓힌다(지금은 배포 루트만 SHA 핀) (09-23~)
- [ ] [local] context7이 rate limit에 걸리면: 키를 로컬 설정 `Authorization: Bearer`로 넣는다 (09-23~)
