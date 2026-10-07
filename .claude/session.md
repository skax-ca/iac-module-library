# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `iac-module-library`). 형제 저장소에는
session.md를 두지 않는다. 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | **hub·dev 철거 상태(10-07).** 5개 루트를 전부 destroy했고 `teardown-verify.sh`가 두 계정에서 exit 0이다. bootstrap 소유물(state 버킷·OIDC provider·입구/실행 Role)은 남아 있다. 두 eks 루트가 `eks-cluster-v0.14.0`과 cert-manager addon을 갖는다. 네 루트의 `deletion_protection = false`는 의도다 |
| eks-platform-gitops | main = origin | **EKS 철거 상태.** hub Secret은 `environment` 라벨이 있다(다음 seed의 입력). dev Secret은 `environment` 라벨이 없고 접속 값은 파기된 클러스터의 것이다. `awsLbcCertManager`가 양 티어 `"true"`이고 ALBC·kyverno가 system 노드그룹에 고정돼 있다. 둘 다 클러스터에서 확인하지 않았다 |
| aks-reference-infra | main = origin | **hub·dev 철거 상태(10-07).** 7개 루트를 전부 destroy했고 `teardown-verify.sh`가 두 구독에서 exit 0이다. bootstrap 소유물(state Storage Account·App Registration·RG)은 남아 있다. hub 구독은 다른 프로젝트(azure-dmz-hcp)와 공용이다. vWAN `prevent_destroy`·VNet·AKS `deletion_protection`이 `false`인 것은 의도다. 로컬 `az` 기본 구독은 hub다 |
| aks-platform-gitops | main = origin | **AKS 철거 상태.** hub Secret은 `environment` 라벨이 있다(다음 seed의 입력). dev Secret은 `environment` 라벨이 없고 접속 값은 파기된 클러스터의 것이다 |

## 지난 세션 (2026-10-07)

**`eks-cluster` 모듈을 두 번 릴리스했다.** `v0.13.0`은 `cluster_addons` 엔트리에 `preserve`를 연다(#63). `v0.14.0`은 cert-manager addon을 실으면 그 webhook 포트(10260)를 control plane에 연다(#64). 이 포트가 닫혀 있어 `Certificate`·`Issuer` 생성이 거부되던 것을 dev에서 겪고 고쳤고, hub·dev에서 `Issuer` server-side dry-run으로 도달을 확인했다.

**ALBC 웹훅 TLS를 두 단계로 고쳤다.** dev `kyverno` sync 지연의 원인이 ALBC 차트가 렌더마다 TLS를 새로 만드는 것임을 audit 로그로 확인하고 `ignoreDifferences`로 유지하게 했다(eks-gitops #60). 공식 문서가 권장안으로 cert-manager를 들어 dev에서 전환을 켰다가 dev의 Service 생성·수정이 10분쯤 막혀 되돌렸다(#61·#62). 철거 뒤에 양 티어 스위치를 켜 두었다(#65).

**EKS hub·dev를 철거했다.** 다섯 루트를 destroy했고 `teardown-verify.sh`가 두 계정에서 exit 0이다. 철거 중에 `preserve = false`의 정리 범위(metrics-server, cert-manager)와 wave 역순 삭제를 실측해 eks-ref `docs/runbooks.md`·`docs/spoke-lifecycle.md`에 옮겼다(`1ce0ce9`·`9e763ad`). dev에 ALBC backend SG가 남은 원인이 같은 wave의 NodePool 삭제가 ALBC 리더를 퇴거시킨 것이어서 ALBC와 kyverno를 system 노드그룹에 고정했다(eks-gitops #64).

**AKS hub·dev는 다른 세션이 철거했다.** 이 세션에서 hub 구독의 `teardown-verify.sh` exit 0과 dev 구독에 bootstrap 소유물만 남은 것을 확인했다.

## 다음 할 일

### 지금

- [ ] [eks-ref·aks-ref] Dependabot PR이 쌓여 있다(eks-ref #71~#75 aws 6.65.0·#82 setup-tflint, aks-ref #72~#78 azurerm 5.6.0). `groups`로 묶을지와 언제 올릴지를 사용자가 정한다(`open-pull-requests-limit`은 디렉토리별) (09-23~)
- [ ] [eks-ref·aks-ref] eks-ref `docs/runbooks.md`가 400줄, aks-ref `docs/runbooks.md`가 399줄·`docs/spoke-lifecycle.md`가 400줄이다. 다음에 내용을 더하기 전에 나눈다(`docs/writing-style.md` 1절 4번) (10-02~)
- [ ] [전체] push 권한자가 이미 2명이다(`rajaelime`, 팀 경유 `maintain`). `CLAUDE.md` 「GitOps 저장소 공통」 ⛔ 재검토 트리거가 당겨진 것으로 볼지 사용자가 정한다 (09-23~)

### 조건이 오면

- [ ] [eks-gitops·eks-ref] EKS를 다시 구축하면: eks-platform-gitops `README.md` 「운영 노트」의 ⏳를 걷는다(cert-manager로 처음부터 서는 경로). 같이 본다: ALBC·kyverno 파드가 system 노드에 서는지, kyverno sync가 `x509` 재시도 없이 끝나는지. 그 뒤 `awsLbcCertManager`를 버전 표에서 빼 ALBC values로 옮긴다. 다음 철거에서는 ALBC backend SG가 0건인지 본다(eks-ref `docs/spoke-lifecycle.md` 10절 ④) (10-07~)
- [ ] [eks-gitops] dev 등록 직후 `gateway-api-crds` 자식이 1분 넘게 `Degraded`로 남으면: 그동안 ArgoCD 리소스 트리(`argocd app get <dev 부모>-gateway-api-crds -o tree`)와 dev의 CRD `status.conditions`를 같은 시각에 떠 맞댄다. Application의 `status.resources[].health`는 비어 있어 근거가 되지 않는다. 근거: `addons/cluster-addons/templates/gateway-api-crds.yaml` (10-02~)
- [ ] [*-gitops·module] 이 저장소들에 `id-token: write` job이 생기면: 액션 SHA 핀을 넓힌다(지금은 배포 루트만 SHA 핀) (09-23~)
- [ ] [local] context7이 rate limit에 걸리면: 키를 로컬 설정 `Authorization: Bearer`로 넣는다 (09-23~)
