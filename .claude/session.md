# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `iac-module-library`). 형제 저장소에는
session.md를 두지 않는다. 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | **hub·dev 철거 상태(10-13).** 5개 루트를 전부 destroy했고 `teardown-verify.sh`가 두 계정에서 exit 0이다. bootstrap 소유물(state 버킷·OIDC provider·입구/실행 Role)은 남아 있다. 다음 구축은 Kubernetes 1.36으로 선다. 네 루트의 `deletion_protection = false`는 의도다. hub 계정에는 새 EBS 볼륨의 `Name` 태그를 덮어쓰는 Lambda(`ResourceTaggingFunction`)가 돈다 |
| eks-platform-gitops | main = origin | **EKS 철거 상태.** hub Secret은 `environment` 라벨이 있다(다음 seed의 입력). dev Secret은 `environment` 라벨이 없고 접속 값은 파기된 클러스터의 것이다. hub ArgoCD는 HA 구성이라 seed가 Ready인 system 노드 3대를 요구한다. Karpenter 노드가 있는 상태의 철거는 확인하지 않았다 |
| aks-reference-infra | main = origin | **hub·dev 철거 상태(10-14).** 7개 루트를 전부 destroy했고 `teardown-verify.sh`가 두 구독에서 exit 0이다. bootstrap 소유물(state Storage Account·App Registration·RG)은 남아 있다. 다음 구축은 컨트롤플레인·시스템 풀 모두 Kubernetes 1.36.4로 서고 hub 시스템 풀은 3대다. hub 구독은 다른 프로젝트(azure-dmz-hcp)와 공용이다. vWAN `prevent_destroy`·VNet·AKS `deletion_protection`이 `false`인 것은 의도다. 로컬 `az` 기본 구독은 hub다 |
| aks-platform-gitops | main = origin | **AKS 철거 상태.** hub Secret은 `environment` 라벨이 있다(다음 seed의 입력). dev Secret은 `environment` 라벨이 없고 접속 값은 파기된 클러스터의 것이다. hub ArgoCD는 HA 구성이라 seed가 Ready인 시스템 풀 노드 3대를 요구한다 |

## 지난 세션 (2026-10-14)

**AKS hub·dev를 1.35.8로 세워 1.36.4로 올리고 철거했다.** 컨트롤플레인과 시스템 풀을 다른 apply로 나누려고 노드 풀별 `kubernetes_version`을 모듈에 넣었다(module #66, `aks-cluster-v0.11.0`). dev는 시스템 풀을 올렸다가 커밋 revert로 1.35.8로 되돌린 뒤 다시 올렸고(aks-ref #83~#86), hub는 절차서만 보고 따라 올렸다(#87·#88). 측정용 호출 약 2만 2천 회 중 실패는 시스템 풀 교체 시각의 3건이었다.

**절차를 두 문서로 두었다.** 따라 하는 절차와 시스템 풀 되돌리기는 aks-ref `docs/upgrade.md`(`7b28f0d`, 운영자 관점 보완 `39c9f83`), 순서의 근거와 기각한 안은 module `docs/architectures/gitops-hub-spoke/azure/upgrade.md`(`d8f761c`·`92f64e4`)다. 되돌리기는 절차의 단계가 아니라 증상이 났을 때 여는 대응으로 두어 `upgrade-rollback.md`는 만들지 않았다.

**GitOps를 EKS와 같은 모양으로 맞췄다.** NodePool을 로컬 차트로 바꿔 `disruptionBlockByTier`를 두었고(aks-gitops #30), hub ArgoCD를 HA로 바꿔 시스템 풀에 고정했다(#31). prd 스위치를 켠 PR에서 verify 검사가 틀리는 것을 고쳤다(#34).

**hub·dev를 함께 구축하면 hub vwan의 사후 재-plan이 dev 연결 1건을 보고하는 것을 찾았다.** spoke networking이 끝난 뒤 vwan을 걸도록 hub-lifecycle에 적었다(`eda53fc`).

## 다음 할 일

### 지금

- [ ] [eks-ref·module] hub 계정의 Lambda가 workbench 볼륨의 `Name`을 덮어써 hub `eks` 루트의 plan에 `volume_tags` 한 줄이 남는다. workbench 모듈이 볼륨 이름을 인스턴스 이름에 맞출지, 변경을 무시할지, Lambda를 고칠지 사용자가 정한다(eks-ref `docs/upgrade.md` 「hub를 올릴 때 다른 점」) (10-13~)
- [ ] [eks-gitops] ArgoCD 컴포넌트에 requests가 없다. application-controller가 545~685Mi를 썼다. 값을 정해 `bootstrap/argocd-values.yaml`에 넣는다(철거 상태인 지금이 넣을 때다) (10-13~)
- [ ] [module] AKS 노드 이미지 패치 묶음(`node_os_upgrade_channel`·`maintenance_window_node_os`)을 별도로 설계한다. 지금은 모듈이 열지 않아 provider 기본값(`NodeImage`, 창 없음)으로 선다(`docs/architectures/gitops-hub-spoke/azure/upgrade.md`) (10-14~)
- [ ] [eks-ref·aks-ref] Dependabot PR이 쌓여 있다(eks-ref 8건, aks-ref 10건). `groups`로 묶을지와 언제 올릴지를 사용자가 정한다(`open-pull-requests-limit`은 디렉토리별) (09-23~)
- [ ] [eks-ref·aks-ref] eks-ref `docs/upgrade.md`와 aks-ref `docs/spoke-lifecycle.md`가 400줄이다. 다음에 내용을 더하기 전에 나눈다(`docs/writing-style.md` 1절 4번) (10-02~)
- [ ] [전체] push 권한자가 이미 2명이다(`rajaelime`, 팀 경유 `maintain`). `CLAUDE.md` 「GitOps 저장소 공통」 ⛔ 재검토 트리거가 당겨진 것으로 볼지 사용자가 정한다 (09-23~)

### 조건이 오면

- [ ] [eks-ref] EKS를 다시 세워 마이너를 올리게 되면: `docs/upgrade.md`·`docs/upgrade-rollback.md`의 ⏳를 걷는다 (10-13~)
- [ ] [aks-ref·module] AKS를 다시 세워 마이너를 올리게 되면: aks-ref `docs/upgrade.md`와 module `azure/upgrade.md`의 ⏳를 걷는다 (10-14~)
- [ ] [module] AKS를 다시 세우면: 노드 OS(Azure Linux)의 ⏳를 걷는다(module `docs/architectures/gitops-hub-spoke/azure/README.md` 「노드 OS: Azure Linux」) (10-15~)
- [ ] [eks-gitops] EKS를 다시 세우면: nonprd의 `disruptionByTier`에 Karpenter `Balanced` consolidation을 시험한다(`addons/karpenter/nodepool/values.yaml`) (10-13~)
- [ ] [*-gitops·module] 이 저장소들에 `id-token: write` job이 생기면: 액션 SHA 핀을 넓힌다(지금은 배포 루트만 SHA 핀) (09-23~)
- [ ] [local] context7이 rate limit에 걸리면: 키를 로컬 설정 `Authorization: Bearer`로 넣는다 (09-23~)
