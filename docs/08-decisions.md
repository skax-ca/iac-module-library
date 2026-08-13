# 08. 검토하고 기각한 것들

**읽는 사람**: *"왜 X 안 해요?"* 라고 묻고 싶은 사람. 또는 그 질문을 받은 사람.

여기 있는 것은 전부 **한 번 검토해서 값을 매겨 기각했거나, 실측으로 반증된** 안이다.
다시 제안하려면 **여기 적힌 이유가 더 이상 성립하지 않음을 먼저 보여야 한다.**

---

## 엔진과 버전

| 하지 말 것 | 이유 |
|---|---|
| Terraform과 OpenTofu **동시 지원** | 실측 비용 5건으로 기각. 교차변수 validation 확인 비용 · lock 커밋 포기 · 로컬↔CI 피드백 지연, 그리고 `required_version`이 **영구적으로 느린 엔진에 묶인다** |
| 전 모듈 **`1.0.0` 일괄 컷** | 컴포넌트별 churn 속도가 다르다. 묶으면 소비자가 매 릴리스마다 *"뭐가 바뀌었지"* 를 확인해야 한다 |
| 개발 중 태그 없이 GA에 `1.0.0` **일괄 발행** | 소비 경로가 태그 하나뿐이다. 태그가 없으면 소비자가 `ref=main`(움직이는 참조)을 써야 한다 |
| 모듈별 OpenTofu **하한 대장** 유지 | 실행 지점이 전부 1.12라 분기가 소비자를 배제한 적이 없었다. 하한을 통일했다 |

> 라이선스는 OpenTofu 채택의 근거가 **아니다.** HashiCorp FAQ는 컨설턴트가 고객 프로덕션에서
> BSL 제품 사용을 돕는 것을 명시적으로 허용한다. 고객사 비용 장벽은 CLI가 아니라 **HCP/TFE 구독**이었고,
> GitHub Actions + S3로 이미 해소됐다. 실제 근거는 **리워크 0과 조달 마찰 제거**다.

---

## 모듈 설계

| 하지 말 것 | 이유 |
|---|---|
| 모듈이 **addon 버전 핀의 기본값**을 소유 | 선택지 4종을 비교해 기각. 핀 소유자는 소비 루트다 |
| **더미 ARN** 기본값 | 고객사가 복사해 apply하면 **존재하지 않는 zone을 가리키는 IAM role**이 선다 |
| `lifecycle { ignore_changes }` 로 drift 눈감기 | *"값이 어긋나도 눈감는다"* 이지 해결이 아니다 |
| `workbench`가 클러스터 이름에서 **ARN을 합성** | 모듈이 계정 ID와 파티션을 알아야 해진다. 배포 루트가 연결한다 |
| `mock_resource`로 `null`을 강제해 테스트 통과 | assertion이 모듈이 아니라 **mock을 검증**하게 된다 |
| 예제를 **minimal + enterprise 2벌**로 | 유지 비용만 늘고 어느 쪽이 정답인지 판정이 갈린다 |

---

## 네이밍

| 하지 말 것 | 이유 |
|---|---|
| 기존 약어를 **AWS 물리 접두사로 일괄 이주** | `snet`·`sgr`·`ngw`·`nacl`·`kp`·`dh`는 AWS 물리 ID 접두사(`subnet-`·`sg-`…)와 다르다. 근거가 기록에 없고(`sgr`은 `sg-` name 금지로 설명 가능), 릴리스된 `modules/vpc`가 실사용 중이라 이주는 이름 변경 = breaking이다. 근거가 생기면 **개별 약어만** 재검토한다 |
| 기존 약어의 **프리픽스 계열 통일**(FSx `fs`/`fz`→`fx` · CloudFront SaaS `mtd`/`dtnt`→`cf*` · API GW `agw*`/`ag*` · MemoryDB `mdb`/`md*`) | 재명명은 전부 breaking이고 이 repo 릴리스 모듈 어디에도 쓰이지 않아 즉시 이득이 없다. 카탈로그는 섹션 컨텍스트로 소속이 드러나고, 신규 항목은 등재 규칙 2항(계열 유지)이 통제한다 |

---

## GitOps와 ArgoCD

| 하지 말 것 | 이유 |
|---|---|
| `iac-module-library`를 ArgoCD App **설치 범위에 추가** | ArgoCD가 **모듈 소스까지 reconcile**하게 된다 |
| **cluster generator**로 ArgoCD 자체를 팬아웃 | 등록된 모든 스포크에 ArgoCD가 설치된다. ArgoCD는 **hub에만** 산다 |
| `Replace=true` · `Force=true` | 객체를 통째로 교체하거나 `delete+create`로 동기화한다. `ServerSideApply`보다 우선해 무력화한다 |
| `ignoreDifferences` · `managedFieldsManagers` · **전역 스위치**로 `OutOfSync` 해소 | 정답은 **앱별 `ServerSideDiff=true`**. 전역 적용은 *"`OutOfSync` = 문제"* 라는 신호를 죽인다 |
| root App 훑기 제외를 **`exclude`** 로 | **자기소멸 데드락** — root App이 자기 자신을 지운다. 마커(`+argocd:skip-file-rendering`)를 쓴다 |
| `argocd app sync --dry-run`의 `Phase: Succeeded`를 **SSA 성공 증거로** | dry-run은 그것을 증명하지 않는다 |
| seed에 `helm --set` · **인라인 heredoc 매니페스트** | 저장소 커밋본과 바이트가 달라져 **영구 드리프트**가 된다 |
| self-managed에서 **CodeConnections** | argo-cd에 지원이 없다. 관리형 Capability의 direct integration 기능이다 |
| 관리형에서 **`argocd-rbac-cm`** | 관리형은 IdC 강제 + `rbac_role_mappings`다. local user를 지원하지 않는다 |
| CI용 GitHub App **재사용** · 설치 범위를 **All repositories**로 | 권한 경계가 무너진다. GitOps용을 별도로 만들고 저장소 1개로 한정한다 |
| 매니페스트에 **AWS가 발급한 ID**(VPC ID · 해시 붙은 role 이름) 적기 | 환경을 다시 세우면 값이 바뀌어 없는 자원을 가리킨다. 계층 1이 **이름을 결정적으로** 만들고 계층 2는 이름을 참조한다 |
| ALBC를 위해 노드 **IMDS hop limit을 2로** | 그 노드의 모든 파드가 노드 IAM role을 탈취할 수 있다. VPC는 `--aws-vpc-tags`로 찾는다 |
| addon 증분 **여러 개를 한 PR에** | 실패 원인 귀인이 불가능해진다. 하나씩 넣는다 |
| **Kyverno를 정책 0개로** 설치 | 아무것도 하지 않는 **죽은 경로**다. Audit 모드는 위험 없이 값을 낸다 |
| **internal ALB + Ingress**를 지금 만들기 | ACM 인증서 · Route53 · `global.domain` · SG가 새로 필요하고 **고객사마다 다르다**. 요구가 생기면 그때 연다 |
| `argocd --core`로 **비밀번호 변경** | core는 argocd-server를 우회해 **세션 토큰이 없다**. `--port-forward`를 쓴다 |
| **pod IP 직결**로 ArgoCD 접속 | VPC CNI라 도달은 되지만 주소가 **재스케줄마다 바뀌고** SG 두 층을 뚫어야 한다 |

---

## 운영

| 하지 말 것 | 이유 |
|---|---|
| **eksctl** 도입 | IaC 소유 경계를 깬다 |
| EKS 마이너 **2단계 점프** (`1.35 -> 1.37`) | 불가능하다. 한 단계씩 두 번 돈다 |
| workbench OOM에 **swapfile · 재시도** 우회 | 원인은 인스턴스 크기다. 우회는 임시방편이다 |
| workbench에 **전용 사용자 신설** | `ssm-user`가 이미 `NOPASSWD:ALL`이다 |
| 비밀번호를 **`ssm send-command`** 로 조회 | 출력이 SSM에 저장되고 CloudTrail에 남는다. 대화형 세션에서만 읽는다 |
| `argocd-initial-admin-secret` **남겨두기** | 평문에 가까운 관리자 자격증명이 클러스터에 상주한다 |
| 고객사 **IdP · 도메인 하드코딩** | 재사용 자산은 환경값을 갖지 않는다 |
| 로컬에서 파기하려고 **실행 Role 신뢰에 사용자 추가** | 파기가 승인 게이트를 우회하게 된다. 파기 경로는 신뢰 경계 **안에** 낸다 — 워크플로 `action=destroy`([04-teardown.md](04-teardown.md)) |
| 잔존물을 **자동으로 지우는** 스크립트 | 만드는 스크립트는 멱등성이 안전망이지만 파기는 아니다. 공용 계정에서 한 번 잘못 돌면 끝이다. **삭제는 사람이, 검증은 기계가** |

---

## 프로세스

| 하지 말 것 | 이유 |
|---|---|
| `terraform-enterprise-poc`에서 모듈·설계 수정 | 그 저장소는 동결됐다. 양쪽 개발은 곧 drift이고, 6개월 뒤 어느 쪽이 정답인지 판정할 수 없게 된다 |
| 문서를 **GitOps 경로별로 복제** | 공통부가 두 벌이 되면 곧 drift다. 하나로 유지하고 갈림점만 표시한다 |

---

## 되살리면 안 되는 근거

아래는 한때 근거로 쓰였다가 **실측으로 반증된** 것이다. 논거로 다시 꺼내지 않는다.

| 근거 | 무엇이 반증했나 |
|---|---|
| *"`system-cluster-critical` 때문에 `kube-system`에 두어야 한다"* | 네임스페이스 제약이 아니다. Karpenter가 `kube-system`인 진짜 이유는 **APF FlowSchema**다 |
| *"`kube-apiserver`와 `kyverno`가 스키마 기본값을 채워 `OutOfSync`가 난다"* | 두 매니저는 `status` 서브리소스만 소유했다. 진짜 원인은 **CRD 스키마 defaulting**이다 |
| *"in-cluster는 자동 등록되니 cluster Secret이 불필요하다"* | 연결은 자동이지만 **ApplicationSet 팬아웃이 Secret의 라벨과 이름을 읽는다** |
