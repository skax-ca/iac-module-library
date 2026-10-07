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

## 지난 세션 (2026-10-06)

**자체 설치 ingress-nginx의 이전 시점을 바로잡았다**(`4b2c41e`). `gitops.md` 6절의 "Azure와 같은 일정으로 옮긴다"는 지원 일정이 같다는 뜻으로 읽혔다. 2026-11까지의 중요 보안 패치는 Microsoft가 App Routing add-on에만 주고, 자체 설치한 쪽은 업스트림 유지보수가 2026-03에 끝났다(Kubernetes 공식 발표와 Microsoft Learn `app-routing`으로 확인했다).

**발표 자료를 같은 내용으로 맞췄다.** `.local/presentations/2026-09-iac-asset/`의 `script.md`(20장 문단)·`slides.html`(20장 AWS 카드)·`article.md`(4.1)를 고치고 `deck.pptx`를 다시 빌드했다. Notion의 대본 페이지와 자산 페이지(pptx·`slides.html` embed·본문 4.1)에도 반영했다.

**데모 ⑥의 NAP 확인 화면을 바꿨다.** 포털에 Node autoprovisioning 항목이 나오지 않아 `Overview` › `JSON View`의 `nodeProvisioningProfile.mode`를 가리키기로 했다. 사용자가 포털에서 값이 보이는 것을 확인했다. dev EKS 콘솔의 Resources 탭도 역할 전환으로 보이는 것을 사용자가 확인했다.

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
