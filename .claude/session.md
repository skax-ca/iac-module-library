# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `iac-module-library`). 형제 저장소에는
session.md를 두지 않는다. 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | **hub·dev 철거 상태(10-08).** 5개 루트를 전부 destroy했고 `teardown-verify.sh`가 두 계정에서 exit 0이다. bootstrap 소유물(state 버킷·OIDC provider·입구/실행 Role)은 남아 있다. 두 eks 루트가 `eks-cluster-v0.14.0`과 cert-manager addon을 갖는다. 네 루트의 `deletion_protection = false`는 의도다 |
| eks-platform-gitops | main = origin | **EKS 철거 상태.** hub Secret은 `environment` 라벨이 있다(다음 seed의 입력). dev Secret은 `environment` 라벨이 없고 접속 값은 파기된 클러스터의 것이다. ALBC의 `enableCertManager`와 ALBC·kyverno의 system 노드그룹 고정은 양 티어 구축에서 확인했다. Karpenter 노드가 있는 상태의 철거는 확인하지 않았다 |
| aks-reference-infra | main = origin | **hub·dev 철거 상태(10-07).** 7개 루트를 전부 destroy했고 `teardown-verify.sh`가 두 구독에서 exit 0이다. bootstrap 소유물(state Storage Account·App Registration·RG)은 남아 있다. hub 구독은 다른 프로젝트(azure-dmz-hcp)와 공용이다. vWAN `prevent_destroy`·VNet·AKS `deletion_protection`이 `false`인 것은 의도다. 로컬 `az` 기본 구독은 hub다 |
| aks-platform-gitops | main = origin | **AKS 철거 상태.** hub Secret은 `environment` 라벨이 있다(다음 seed의 입력). dev Secret은 `environment` 라벨이 없고 접속 값은 파기된 클러스터의 것이다 |

## 지난 세션 (2026-10-08)

**EKS hub·dev를 다시 세워 두 항목을 확인하고 철거했다.** hub는 `tgw → networking → eks` 뒤 seed, dev는 `networking → eks` 뒤 hub networking 재적용과 재등록(eks-gitops #67)이다. 철거는 라벨 제거(#70) 뒤 다섯 루트 destroy이고 `teardown-verify.sh`가 두 계정에서 exit 0이다. dev에 Flow Logs가 다시 만든 빈 로그 그룹 하나는 손으로 지웠다. hub 라벨은 되돌렸다(#71).

**ALBC 웹훅 TLS가 cert-manager로 처음부터 서는 것을 양 티어에서 확인했다.** Certificate·Issuer가 Ready이고, `caBundle` 필드의 소유자가 cainjector라 `aws-lbc`를 hard refresh하고 다시 sync해도 웹훅 설정의 `resourceVersion`이 그대로다. kyverno sync는 `x509` 재시도 없이 끝났다. 스위치를 버전 표에서 빼 ALBC values로 옮겼다(#68·#69, 클러스터가 살아 있는 동안 둘로 나눠 넣었다).

**dev 등록 직후 `gateway-api-crds`의 `Degraded`는 주기 refresh까지 남는 것임을 확인했다.** hub의 리소스 트리와 dev의 CRD 조건을 같은 시각으로 맞댔다. CRD는 생성 4초 안에 전부 `Established`였고 Application은 `comparison expired` refresh에서 손대지 않고 `Healthy`가 됐다. eks-ref `docs/runbooks.md` 5절의 그 행을 고쳤다(`fc09310`).

## 다음 할 일

### 지금

- [ ] [eks-ref·aks-ref] Dependabot PR이 쌓여 있다(eks-ref #71~#75 aws 6.65.0·#82 setup-tflint, aks-ref #72~#78 azurerm 5.6.0). `groups`로 묶을지와 언제 올릴지를 사용자가 정한다(`open-pull-requests-limit`은 디렉토리별) (09-23~)
- [ ] [eks-ref·aks-ref] eks-ref `docs/runbooks.md`가 400줄, aks-ref `docs/runbooks.md`가 399줄·`docs/spoke-lifecycle.md`가 400줄이다. 다음에 내용을 더하기 전에 나눈다(`docs/writing-style.md` 1절 4번) (10-02~)
- [ ] [전체] push 권한자가 이미 2명이다(`rajaelime`, 팀 경유 `maintain`). `CLAUDE.md` 「GitOps 저장소 공통」 ⛔ 재검토 트리거가 당겨진 것으로 볼지 사용자가 정한다 (09-23~)

### 조건이 오면

- [ ] [*-gitops·module] 이 저장소들에 `id-token: write` job이 생기면: 액션 SHA 핀을 넓힌다(지금은 배포 루트만 SHA 핀) (09-23~)
- [ ] [local] context7이 rate limit에 걸리면: 키를 로컬 설정 `Authorization: Bearer`로 넣는다 (09-23~)
