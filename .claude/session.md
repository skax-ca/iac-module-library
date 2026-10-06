# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `iac-module-library`). 형제 저장소에는
session.md를 두지 않는다. 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | **hub·dev 구축 상태(10-06 재구축), 발표(10-07)에 쓴다.** 5개 루트 apply 성공, hub·dev eks 재-plan이 `No changes`다. hub 완료 판정 6항목이 닫혔다. IaC 밖 자원 둘이 asset 계정에 있다: Role `iamr-demo-dev-an2-console-hub-01`과 dev 클러스터의 그 Role Access Entry. 네 루트의 `deletion_protection = false`는 의도다 |
| eks-platform-gitops | main = origin | **EKS 구축 상태.** hub·dev의 Application 24개가 전부 `Synced`/`Healthy`다(10-06). hub·dev Secret 모두 `environment` 라벨이 있고 접속 값은 지금 클러스터의 것이다 |
| aks-reference-infra | main = origin | **hub·dev 구축 상태(10-02 재구축), 발표(10-07)에 쓴다.** 7개 루트 재-plan이 `No changes`다(10-02). hub 완료 판정 7항목이 닫혔다. hub 구독은 다른 프로젝트(azure-dmz-hcp)와 공용이다. vWAN `prevent_destroy`·VNet·AKS `deletion_protection`이 `false`인 것은 의도다. 로컬 `az` 기본 구독은 hub다 |
| aks-platform-gitops | main = origin | **AKS 구축 상태.** hub·dev의 Application 14개가 전부 `Synced`/`Healthy`다(10-02). hub·dev Secret 모두 `environment` 라벨이 있고 접속 값은 지금 클러스터의 것이다 |

## 지난 세션 (2026-10-06)

**EKS hub·dev를 재구축했다.** hub tgw → hub networking → hub eks·dev networking → dev eks → hub networking 재적용 순으로 승인했고, hub seed 뒤 eks-gitops #59(dev 재등록)로 dev를 붙였다. hub eks의 첫 apply는 `tofu init`의 provider 서명 다운로드가 500으로 실패해 `gh run rerun --failed`로 같은 plan을 다시 적용했다. 완료 판정 6항목을 닫았다.

**health Lua의 `Synced` 조건을 EKS에서 확인했다.** 부모가 wave 1과 wave 2 사이에서 hub 2분 47초, dev 6분 39초를 기다렸고 양쪽 다 멈추지 않고 `Healthy`로 수렴했다. `karpenter`가 `OutOfSync` + `Healthy`인 동안, `kyverno`가 `Synced` + `Healthy`인데 operation이 `Running`인 동안 부모가 넘어가지 않았다. `gateway-api-crds`의 `Degraded`는 hub·dev 모두 5초 샘플 한 번에만 잡혔고 그때 dev의 CRD 10개는 이미 `Established`였다. 3분짜리는 재현되지 않았다.

**cert-manager addon을 EKS hub·dev에서 걷었다**(eks-ref #83·#84, eks-gitops `4034b63`). CR이 0건이고 쓰는 곳이 없었다. addon이 `preserve = true`로 만들어져 `enabled = false` apply가 EKS 등록만 지우고 파드·CRD·webhook·RBAC를 남겨, workbench에서 걷었다. 절차는 eks-ref `runbooks.md` 9절 「addon을 뺄 때」에 적었다.

**`spoke-lifecycle.md` 5절을 고쳤다**(eks-ref `3039301`). dev eks의 trust policy가 hub의 `argocd_hub_pod_identity` Role을 Principal로 써서 hub eks apply 뒤에 걸어야 하는데, 문서는 반대로 적고 있었다.

**발표용 접근을 준비했다.** EKS·AKS 두 hub ArgoCD의 `admin` 비밀번호를 `argocd-secret`의 bcrypt 해시 patch로 바꿨다. asset 계정에 hub 계정의 `silverte`만 신뢰하는 `ReadOnlyAccess` Role을 CLI로 만들고 dev 클러스터에 `AmazonEKSViewPolicy` Access Entry를 붙였다.

## 다음 할 일

### 지금

- [ ] [local] 발표 준비: `script.md` 데모 ⑤의 포털 화면 표기(`Settings` › `Networking`, Node autoprovisioning 항목)를 눈으로 보고 캡처를 뜬 뒤 「발표 전 확인 · 전날」을 돈다. hub 계정에서 `iamr-demo-dev-an2-console-hub-01`로 역할 전환해 dev EKS 콘솔의 Resources 탭이 보이는지도 본다(엔드포인트가 private 전용이라 안 보일 수 있다) (09-30~)
- [ ] [module] `eks-cluster` 모듈이 addon의 `preserve`를 노출할지 사용자가 정한다. 지금은 upstream 기본값 `true`라 addon을 빼면 실물이 남는다. 근거: eks-ref `docs/runbooks.md` 9절 「addon을 뺄 때」 (10-06~)
- [ ] [eks-ref·aks-ref] Dependabot PR이 쌓여 있다(eks-ref #71~#75 aws 6.65.0·#82 setup-tflint, aks-ref #72~#78 azurerm 5.6.0). `groups`로 묶을지와 언제 올릴지를 사용자가 정한다(`open-pull-requests-limit`은 디렉토리별) (09-23~)
- [ ] [eks-ref] hub eks plan에 workbench `volume_tags`의 `Name`이 `ec2-…` → `vol-…`로 잡혀 적용됐다. dev plan에는 없었다. hub에만 난 이유를 본다. 근거: run 37403309963 plan 로그 (10-06~)
- [ ] [eks-gitops] dev의 `kyverno` sync operation이 5분가량 `Running`이었다(hub는 30초 안팎). 원인을 본다. 근거: `docs/architectures/gitops-hub-spoke/ordering.md` 4절 (10-06~)
- [ ] [eks-ref·aks-ref] eks-ref `docs/runbooks.md`가 400줄, aks-ref `docs/runbooks.md`가 399줄·`docs/spoke-lifecycle.md`가 400줄이다. 다음에 내용을 더하기 전에 나눈다(`docs/writing-style.md` 1절 4번) (10-02~)
- [ ] [전체] push 권한자가 이미 2명이다(`rajaelime`, 팀 경유 `maintain`). `CLAUDE.md` 「GitOps 저장소 공통」 ⛔ 재검토 트리거가 당겨진 것으로 볼지 사용자가 정한다 (09-23~)

### 조건이 오면

- [ ] [eks-ref] 발표(10-07)가 끝나면: IaC 밖 자원을 지운다. dev 클러스터의 Access Entry(`aws eks delete-access-entry`) → asset 계정 Role `iamr-demo-dev-an2-console-hub-01`(`detach-role-policy` 뒤 `delete-role`) 순이다. 두 hub ArgoCD의 `admin` 비밀번호도 바꾼다 (10-06~)
- [ ] [eks-gitops] dev 등록 직후 `gateway-api-crds` 자식이 1분 넘게 `Degraded`로 남으면: 그동안 ArgoCD 리소스 트리(`argocd app get <dev 부모>-gateway-api-crds -o tree`)와 dev의 CRD `status.conditions`를 같은 시각에 떠 맞댄다. Application의 `status.resources[].health`는 비어 있어 근거가 되지 않는다. 근거: `addons/cluster-addons/templates/gateway-api-crds.yaml` (10-02~)
- [ ] [*-gitops·module] 이 저장소들에 `id-token: write` job이 생기면: 액션 SHA 핀을 넓힌다(지금은 배포 루트만 SHA 핀) (09-23~)
- [ ] [local] context7이 rate limit에 걸리면: 키를 로컬 설정 `Authorization: Bearer`로 넣는다 (09-23~)
