# hub/spoke 생애주기 문서 재편 계획

**상태**: `pending approval` — 승인 전에는 파일을 삭제하거나 생성하지 않는다.
**작성**: 2026-08-21
**결정자**: 사용자 (2026-08-21, `iac-reference-infra`에서 spoke teardown+재배포 리허설을 준비하며
"기존 절차는 hub만 있는 케이스에서 작성된거라서 hub와 spoke를 나누어서 정리해야할거 같다"고 지적,
브레인스토밍으로 "토폴로지가 상위 축"·"기존 체계 변경 반영"·"접근 A(1:1 교체)"를 확정)

---

## 1. 왜 재편인가 — 실측 근거

`docs/04-teardown.md`·`docs/03-new-project.md`는 hub-spoke 분리(2026-08-19) **이전**,
단일 클러스터 토폴로지로 검증됐다(`04-teardown.md:5` "실환경에서 끝까지 실행해 검증"은 그
시점 기준). `iac-reference-infra`에서 spoke(dev) teardown 절차를 실제로 점검하며 다음 3가지
어긋남을 실측·문서 대조로 확인했다(2026-08-21):

| # | 문제 | 근거 |
|---|---|---|
| 1 | `04-teardown.md` 3절의 "컨트롤러 정지"가 대상 클러스터 자신 안에 ArgoCD가 도는 것을 전제로 쓰여 있다 | spoke(dev)는 자체 ArgoCD가 없다 — hub가 크로스 계정 원격 관리. dev teardown 시 hub 컨트롤러를 향해야 하는지, `iac-platform-gitops`에서 dev의 `cluster-secret.yaml`을 먼저 지워야 하는지 문서에 없다 |
| 2 | `03-new-project.md` 6절은 "신규 등록"만 다루고 "재등록"이 없다 | dev EKS destroy→재생성 시 `cluster-secret.yaml`의 `server`(endpoint)·`caData`가 반드시 바뀐다(`iac-platform-gitops/clusters/dev/eks-demo-dev-an2-main-01/cluster-secret.yaml` 실물로 확인) — 갱신 절차·addon 라벨(`addon-cluster-autoscaler`·`addon-keda`) 유지 절차가 없다 |
| 3 | `deployment-facts.md` 5.8의 "teardown 후 재생성 시" 절은 hub가 destroy된 경우만 다룬다 | spoke만 단독 destroy(hub 유지) 시 hub의 `aws_ec2_transit_gateway_route.tgw_rt_to_spoke`(살아있는 `data.aws_ec2_transit_gateway_vpc_attachment.spoke`로 `for_each` 결정, `live/hub/networking/main.tf:399`)가 어떻게 정리되는지 미실측 |

부수 발견: `deletion_protection`이 dev networking·dev eks·hub networking·hub eks **넷 다**
코드·AWS 실물 양쪽에서 이미 `false`다(`live/dev/eks` `describe-cluster` 실측:
`deletionProtection` 필드 자체가 응답에 없음 = AWS 기본값 `false`와 일치). 알려진 open-item
(`hub/networking`만 drift)보다 범위가 넓다. **사용자 결정**: 모듈 v1.0 출시 전까지는 `false`
유지 — 별도 코드 변경 없음, `deployment-facts.md`에 사실로만 기록한다.

---

## 2. 설계 — 접근 A (2026-08-11 zero-base 원칙 P1·P4·P6 계승)

`03-new-project.md`·`04-teardown.md` 두 자리를 **토폴로지로 재편**한다. 상위 축을 "무엇을
할지"(작업)에서 "어느 계정인지"(토폴로지)로 뒤집는다 — 독자가 자기 역할(hub 담당·spoke 담당)
하나만 읽으면 되게 하려는 것이 사용자가 이 축을 고른 이유다. `05-modules.md`~`08-decisions.md`
번호는 유지한다(변경 범위 최소화).

### 신설

| 파일 | 내용 |
|---|---|
| `03-hub-lifecycle.md` | hub 계정 생애주기 전체: 착수 전 확정값 → 배포 저장소 → 부트스트랩(`BOOTSTRAP_TARGET=hub`) → L1/L2/L3(GitOps는 `argocd-seed.sh`, hub만 자기 seed) → 완료 판정 → 걷어내기(0단계 삭제보호 → IaC 밖 자원 선처리 → destroy → 잔존물 검증 → 되돌릴 수 없는 것). 부트스트랩 실행 문법·`backend.hcl`·workflow dispatch 패턴·"로컬 불가" 설명 등 **공통 메커니즘의 원본**을 여기 둔다 |
| `04-spoke-lifecycle.md` | spoke 계정 생애주기: 같은 골격이나 (a) hub가 이미 서 있어야 한다는 전제 명시, (b) `cross-account-trust-role` 모듈 연결 단계, (c) GitOps는 자체 seed 대신 **hub의 `cluster-secret.yaml` 등록**(신규·재등록 둘 다 — 이번에 발견한 간극 #2 메움), (d) 걷어내기의 "컨트롤러 정지"를 hub 쪽 `cluster-secret` 제거로 정정(간극 #1), spoke 단독 teardown 시 hub TGW 잔존 라우트 처리를 열린 질문으로 명시(간극 #3, 리허설로 실측 후 확정). 공통 메커니즘은 "동일 절차는 `03-hub-lifecycle.md` §X 참조"로 링크(기존 04→03 상호참조 관례 계승) |

### 폐기

`03-new-project.md`·`04-teardown.md` — git 이력에 남으므로 내용 손실 없음(P7 "정정 서술을
남기지 않는다"와 동일 원칙: 과거 판은 git이 안다).

### 리스크

hub 파일이 기존 03(247줄)+04의 hub 관련 절반을 합치면 400줄 캡(P4)에 근접할 수 있다.
실제 작성 후 넘으면 그때 GitOps(§6)나 걷어내기(§8)를 분리한다 — 지금 미리 쪼개지 않는다
(YAGNI, `CLAUDE.md` 「8-3」).

---

## 3. 영향받는 참조 — 전부 갱신 대상

`grep -rn "03-new-project\|04-teardown"` 실측 결과(`.omc/notepad.md` 제외 — 세션 이력이라
과거 시점 서술이 맞다):

**`iac-module-library`**:
`README.md` · `docs/README.md` · `docs/00-team-access.md` · `docs/01-architecture.md` ·
`docs/02-choose-your-path.md` · `docs/05-modules.md` · `docs/07-runbooks.md` ·
`docs/08-decisions.md` · `docs/AGENTS.md` · `scripts/README.md`

**`iac-reference-infra`**:
`live/dev/eks/README.md`·`live/hub/eks/README.md` — `03-new-project.md`의
「2. 배포 저장소 만들기」를 **절 번호로** 인용 중. 이건 2026-08-11 zero-base 원칙 P6
("문서 간 링크는 문서 단위") 위반이기도 하다 — 이번에 문서 단위 링크로 함께 정정한다.

각 참조는 가리키는 절차가 hub 전용인지 spoke 전용인지 판별해 새 파일명으로 바꾼다
(예: `00-team-access.md`의 "부트스트랩 절차" 링크는 `03-hub-lifecycle.md`로 — 부트스트랩
원본 설명이 그쪽에 있으므로).

---

## 4. 사용자 결정 기록 — deletion_protection

`deployment-facts.md`에 다음을 사실로 추가한다(코드 변경 없음):

> 모듈 v1.0 출시 전까지 dev·hub의 `deletion_protection`은 의도적으로 `false`를 유지한다.
> 개발 단계 반복 배포 편의가 우선이며, v1.0 이후에는 `CLAUDE.md`·`04-teardown.md`(신)
> 원칙대로 기본 `true`로 전환한다.

---

## 다음

`writing-plans` 스킬로 구체적 구현 계획(파일별 작성 순서·검증 명령)을 만든다.
