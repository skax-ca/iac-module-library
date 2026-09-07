# hub/spoke 생애주기 문서 재편 — 실행 계획

> **For Claude:** REQUIRED SUB-SKILL: 이 계획은 `superpowers:executing-plans`이 아니라
> 이 세션에서 직접(또는 subagent-driven-development로) 실행한다 — 코드 TDD가 아니라 문서
> 재작성이므로 "테스트"는 `scripts/validate-doc-conventions.py` + 상호참조 grep이다.

**Goal**: `docs/03-new-project.md`·`docs/04-teardown.md`(단일 클러스터 토폴로지 전제, hub-spoke
분리 이전 작성)를 `docs/03-hub-lifecycle.md`·`docs/04-spoke-lifecycle.md`로 교체하고, 이번
세션에 실측으로 확인한 3가지 간극(ArgoCD 컨트롤러 정지 대상·cluster-secret 재등록·spoke 단독
teardown 시 hub TGW 라우트)을 spoke 문서에 채워 넣는다. 참조하는 9+2곳을 전부 갱신한다.

**Architecture**: 설계는 `.omc/plans/2026-08-21-hub-spoke-lifecycle-docs.md`(승인됨, 접근 A).
hub 문서는 기존 두 문서의 hub 관련 내용을 재배치하는 것에 가깝고(hub는 원래 단일 클러스터
전제가 그대로 맞는 유일한 대상), spoke 문서가 실질적 신규 집필이다.

**대상 repo**: `iac-module-library`(로컬 `/Users/a07326/born2k/ai/iac-module-library`).
이 계획 파일이 있는 repo와 별개로, `docs/deployment-facts.md` 갱신 1건만
`iac-reference-infra`(로컬 `/Users/a07326/born2k/ai/iac-reference-infra`) 대상이다.

**검증 도구**: 두 repo 모두 pre-commit이 `scripts/validate-doc-conventions.py`로 절 번호
인용·비표준 이모지·400줄 제한을 기계 검사한다. **커밋은 사용자 최종 승인 전까지 만들지 않는다**
— 각 태스크는 `git add`(스테이징)까지만 하고, pre-commit이 아니라 검증 스크립트를 **직접
호출**해 통과를 확인한다(스테이징만으로는 훅이 안 돈다).

---

### Task 1: `docs/03-hub-lifecycle.md` 작성

**Files:**
- Create: `docs/03-hub-lifecycle.md`
- Source: 기존 `docs/03-new-project.md`(hub 관련 전부) + `docs/04-teardown.md`(전체 — hub는
  기존 단일 클러스터 전제가 그대로 유효한 유일한 대상이므로 04의 절차는 거의 그대로 옮긴다)

**Step 1: 목차 뼈대 작성**

```markdown
# 03. hub 계정 생애주기 — 세우기와 걷어내기

**읽는 사람**: hub(team 계정)의 인프라를 세우거나 걷어내는 사람.

> **검증 상태**: 세우기는 L1~L3을 백지에서 한 번에 세워 검증했다(`03-new-project.md` 구판
> 계승). 걷어내기는 실환경에서 끝까지 실행해 검증했다(`04-teardown.md` 구판 계승).
> ⚠️ **부트스트랩(L0)은 세우기 검증 범위 밖이다** — 검증 때 이미 있던 것을 그대로 썼다.

---

## 세우기

### 0. 준비물
### 1. 착수 전에 확정할 값
### 2. 배포 저장소 만들기
### 3. 부트스트랩 — state 버킷 · OIDC · Role (`BOOTSTRAP_TARGET=hub`)
### 4. 네트워크 (L1)
### 5. EKS와 workbench (L2)
### 6. GitOps (L3) — `argocd-seed.sh`
### 7. 완료 판정

## 걷어내기

### 8. 시작 전에 — 공용 계정이면 특히 읽는다
### 9. 삭제는 생성의 역순이 아니다
### 10. 0단계 — 삭제 보호 해제
### 11. 1단계 — IaC 밖 자원 선처리
### 12. 2단계 · 3단계 — destroy
### 13. 4단계 — 잔존물 검증
### 14. 부분 삭제
### 15. 되돌릴 수 없는 것
### 16. 자주 막히는 지점
```

**Step 2: 세우기 절(0~7) 본문 이식**

구판 `03-new-project.md`를 그대로 옮기되:
- 「2. 배포 저장소 만들기」의 예시 구조(`live/<env>/...`)에 `env=hub` 예시를 명시한다(구판은
  `dev` 예시만 있었다).
- 「3. 부트스트랩」의 커맨드를 `BOOTSTRAP_TARGET=hub`(기본값)로 맞추고, `bootstrap/README.md`
  「2. 기대 상태」 표를 참조하도록 링크를 추가한다(구판엔 이 표가 아직 없던 시절 내용이 섞여
  있었다 — 최신 표와 어긋나는 서술은 이 기회에 정리).
- 「6. GitOps (L3)」에 "hub만 자기 `argocd-seed.sh`를 돈다 — spoke는 자체 seed가 없다,
  `04-spoke-lifecycle.md` 참조"를 한 줄 추가한다(다음 문서와의 경계를 명시).
- 「7. 완료 판정」 표는 그대로 유지.

**Step 3: 걷어내기 절(8~16) 본문 이식**

구판 `04-teardown.md` 전체(0~8절)를 그대로 옮긴다 — 이 문서가 원래 검증된 전제(단일 클러스터,
ArgoCD가 대상 클러스터 자신 안에 있음)가 hub에는 정확히 들어맞으므로 절차 변경이 필요 없다.
단, 다음만 정정한다:
- 「3. 1단계 — IaC 밖 자원 선처리」 도입부에 "hub는 자기 ArgoCD를 스스로 멈춘다 — spoke는
  다르다(`04-spoke-lifecycle.md` 참조)"를 한 줄 추가해 경계를 명시.
- 마지막 "다음" 절의 `03-new-project.md` 링크를 `03-hub-lifecycle.md`(자기 자신 상단 세우기
  절)로, 필요하면 문서 내부 앵커로 바꾼다.

**Step 4: 400줄 확인**

```bash
wc -l docs/03-hub-lifecycle.md
```
Expected: 400 이하. 넘으면 「6. GitOps」나 「11. IaC 밖 자원 선처리」를 별도 문서로 분리할지
그 자리에서 판단(설계 문서 「2. 리스크」에 이미 예견됨 — 지금 미리 쪼개지 않는다).

**Step 5: 문서 컨벤션 검증**

```bash
python3 scripts/validate-doc-conventions.py docs/03-hub-lifecycle.md
```
Expected: 통과(절 번호 인용 없음·비표준 이모지 없음·400줄 이하).

**Step 6: 스테이징(커밋 아님)**

```bash
git add docs/03-hub-lifecycle.md
```

---

### Task 2: `docs/04-spoke-lifecycle.md` 작성 — 실질 신규 집필

**Files:**
- Create: `docs/04-spoke-lifecycle.md`
- Source: 구판 `03-new-project.md`(spoke로 갈아 끼울 부분) + 구판 `04-teardown.md`(구조만
  차용) + 이번 세션 실측(간극 3건) + `bootstrap/README.md`(spoke 부트스트랩 표) +
  `iac-reference-infra`의 `cluster-secret.yaml` 실물 + `deployment-facts.md` §5.8(TGW 순서)

**Step 1: 목차 뼈대 작성**

```markdown
# 04. spoke 계정 생애주기 — 세우기와 걷어내기

**읽는 사람**: spoke(예: asset 계정의 dev)의 인프라를 세우거나 걷어내는 사람.

> ⚠️ **hub가 이미 서 있어야 한다.** spoke는 hub의 `argocd_hub_pod_identity`
> Role·TGW·프리픽스 리스트에 의존한다 — hub를 먼저 세운다(`03-hub-lifecycle.md`).
> **검증 상태**: 세우기·걷어내기 둘 다 `iac-reference-infra`의 dev(spoke 첫 인스턴스)로
> 실환경 검증했다. spoke 단독 teardown 시 hub 쪽 잔존물 처리(§13)는 **열린 질문**이다 —
> 아래 명시.

---

## 세우기

### 0. 준비물
### 1. 착수 전에 확정할 값 (hub와 다른 것만)
### 2. 배포 저장소 — hub와 같은 repo, 새 env 하나
### 3. 부트스트랩 — `BOOTSTRAP_TARGET=spoke SPOKE_ENV=<env>`
### 4. 네트워크 (L1) — TGW attachment + RAM 초대 수락
### 5. EKS와 workbench (L2) — `cross-account-trust-role` 연결
### 6. GitOps 등록 — hub에 `cluster-secret.yaml` 신규 등록 (자체 seed 없음)
### 7. 완료 판정

## 걷어내기

### 8. 시작 전에 — 공용 계정이면 특히 읽는다
### 9. 0단계 — 삭제 보호 해제
### 10. 1단계 — IaC 밖 자원 선처리 (컨트롤러 정지 대상이 hub다)
### 11. 2단계 · 3단계 — destroy
### 12. 4단계 — 잔존물 검증
### 13. spoke 단독 teardown 시 hub TGW 잔존 라우트 — 열린 질문
### 14. 재배포 시 GitOps 재등록
### 15. 되돌릴 수 없는 것 / 자주 막히는 지점
```

**Step 2: 세우기 절(0~5) — 구판에서 갈아 끼우기**

구판 `03-new-project.md`의 준비물·값 확정·배포 저장소·네트워크·EKS 절을 가져오되:
- 「3. 부트스트랩」 커맨드를 `bootstrap/README.md` 「1. 실행」의 spoke 예시 그대로
  인용한다(`BOOTSTRAP_TARGET=spoke SPOKE_ENV=dev AWS_PROFILE=asset EXPECTED_ACCOUNT=...`).
- 「4. 네트워크」에 TGW attachment·RAM 초대 수락(`aws_ram_resource_share_accepter`) 단계를
  추가한다 — `deployment-facts.md` §5.8 표(hub networking → hub eks → spoke networking →
  spoke eks → hub networking 재적용)를 문서 링크로 인용(값이 아니라 순서 표 자체를 가리킨다).
- 「5. EKS와 workbench」에 `cross-account-trust-role` 모듈 연결을 추가 — hub의
  `argocd_hub_pod_identity` Role ARN을 Principal로 받는 것, 그리고 그 Role이 **아직 없어도
  trust policy 생성은 막히지 않는다**(AWS가 trust policy Principal 존재를 생성 시점에
  검증하지 않음 — `iac-reference-infra` 2026-08-19 실측, 이 사실을 한 줄로 남긴다).

**Step 3: 「6. GitOps 등록」 — 신규 작성 (간극 #2 메움)**

```markdown
### 6. GitOps 등록 — hub에 cluster-secret.yaml 신규 등록

spoke는 자체 ArgoCD가 없다. hub의 ArgoCD가 크로스 계정으로 원격 관리하므로, **GitOps 저장소에
이 클러스터를 등록**하는 것이 spoke의 "L3"에 해당한다.

`<project>-platform-gitops`(iac-platform-gitops 레이아웃)에
`clusters/<env>/<cluster-name>/cluster-secret.yaml`을 추가한다:

- `metadata.name` = 클러스터 이름
- `metadata.labels.environment` = `<env>` (baseline addon ApplicationSet의 cluster generator가
  이 라벨의 **존재만** 검사한다 — 값 자체는 경로 해석용)
- `metadata.labels.vpcName`·`karpenterNodeRole` 등 per-cluster addon 파라미터(실측으로 채운다,
  추정 금지 — `aws ec2 describe-vpcs`·`aws iam list-roles`)
- opt-in 카탈로그 구독은 `addon-<name>: enabled` 라벨로 추가한다
- `stringData.server` = **EKS API endpoint**(`https://<hash>.<region>.eks.amazonaws.com`).
  ⚠️ EKS 클러스터 ARN이 아니다 — ARN 계약은 AWS 완전관리형 "EKS Capability for Argo CD"(이
  프로젝트가 쓰지 않는 별개 제품) 전용이다. self-managed ArgoCD 공식 계약은 API endpoint다.
- `stringData.config`의 `awsAuthConfig.roleARN` = `cross-account-trust-role` 모듈이 만든
  Role ARN(위 5절)
- `stringData.config.tlsClientConfig.caData` = 클러스터의 `certificateAuthority.data`
  (base64, `aws eks describe-cluster`로 조회)

root-app이 이 커밋을 pull하면 baseline ApplicationSet이 이 클러스터를 fan-out 대상에 자동
추가한다 — 별도 seed 스크립트를 이 클러스터에서 실행하지 않는다.

**재배포 시 재등록** — §14 참조. 처음 등록과 재등록은 **같은 파일을 같은 방식으로 갱신**하지만,
재등록에서는 `server`·`caData`가 반드시 바뀐다는 것과 기존 `addon-*` 라벨을 그대로 옮겨야
한다는 것이 함정이다.
```

**Step 4: 「10. 1단계 — IaC 밖 자원 선처리」 — 신규 작성 (간극 #1 메움)**

```markdown
### 10. 1단계 — IaC 밖 자원 선처리

⚠️ **hub-lifecycle.md의 같은 절과 다르다.** spoke는 자체 ArgoCD가 없으므로 "컨트롤러를
scale 0"할 대상이 spoke 안에 없다 — hub의 ApplicationSet이 이 spoke를 계속 fan-out 대상으로
보는 한, spoke 안의 LoadBalancer Service·PVC·Karpenter NodePool을 지워도 hub가 되살린다
(`03-hub-lifecycle.md` §11이 경고하는 것과 같은 메커니즘, 대상만 원격이다).

```bash
# ① GitOps 저장소에서 이 spoke의 cluster-secret.yaml을 먼저 지운다 (hub 쪽에서)
# root-app이 이 커밋을 pull하면 baseline ApplicationSet이 이 spoke를 fan-out 대상에서 뺀다
# — 이게 spoke판 "컨트롤러 정지"다

# ② hub의 root-app이 새 커밋을 실제로 반영했는지 확인 (2026-08-20 GitOps 4계층 함정 참조:
#    Synced/Healthy만으로는 반영을 보장 못 한다 — sync revision이 새 커밋 SHA인지 본다)
kubectl -n argocd get application root-app -o jsonpath='{.status.sync.revision}'

# ③ 이 spoke가 생성한 Application들이 실제로 pruned(삭제)됐는지 hub에서 확인
kubectl -n argocd get applications | grep <spoke-cluster-name>   # 결과 없어야 함

# ④ 이후부터는 hub-lifecycle.md §11의 ②③④(LB·PVC·NodePool)를 이 spoke의 workbench에서
#    동일하게 수행 — 이 부분은 hub와 spoke가 같다, hub가 이미 fan-out을 멈췄으니 되살아나지
#    않는다
```

**순서가 중요하다.** ①②③을 건너뛰고 바로 LB·PVC·NodePool을 지우면, hub가 여전히 fan-out
중이라 지운 것이 되살아난다 — hub-lifecycle.md §11이 자기 자신의 ArgoCD에 대해 경고하는 것과
정확히 같은 실패 모드가, 이번엔 **원격 컨트롤러 때문에** 생긴다.
```

**Step 5: 「13. spoke 단독 teardown 시 hub TGW 잔존 라우트」 — 열린 질문으로 명시 (간극 #3)**

```markdown
### 13. spoke 단독 teardown 시 hub TGW 잔존 라우트 — 열린 질문

`deployment-facts.md` §5.8의 "teardown 후 재생성 시" 절은 **hub가 destroy된 경우**만
다룬다. spoke만 단독으로 destroy하고 hub는 그대로 두는 이번 케이스는 다르다.

hub의 `aws_ec2_transit_gateway_route.tgw_rt_to_spoke`와
`aws_ec2_transit_gateway_route_table_association.spoke`는 **살아있는 데이터소스**
(`data.aws_ec2_transit_gateway_vpc_attachment.spoke`)로 `for_each`가 결정된다
(`live/hub/networking/main.tf:399`). spoke의 attachment가 destroy로 사라진 뒤:

- AWS가 attachment 삭제 시 이 라우트를 **자동으로 정리**하는지
- 아니면 dangling 상태로 남아 hub의 다음 plan에서 에러를 내는지
- hub를 굳이 재적용하지 않아도 되는지, 아니면 정리를 위해 재적용이 **필요**한지

**미실측이다.** 다음 spoke teardown 리허설에서 확인하고 이 절을 갱신한다. 확인 순서 제안:

```bash
# spoke networking destroy 직후
aws ec2 describe-transit-gateway-route-tables --profile team --region ap-northeast-2 \
  --transit-gateway-route-table-ids <hub-rt-id>
# hub plan을 돌려 dangling 엔트리가 있으면 어떻게 나오는지 관찰
gh workflow run deploy-hub-network.yml --ref main -f action=apply   # plan만 우선 확인
```
```

**Step 6: 「14. 재배포 시 GitOps 재등록」 — 신규 작성 (간극 #2 마무리)**

```markdown
### 14. 재배포 시 GitOps 재등록

spoke EKS를 destroy 후 재생성하면 클러스터 이름이 같아도 API endpoint·CA 인증서는 **반드시
새로 발급**된다. §6에서 등록한 `cluster-secret.yaml`은 옛 값을 그대로 갖고 있으므로, 재적용
없이는 hub ArgoCD가 죽은 엔드포인트를 계속 찌른다.

```bash
# 새 클러스터의 endpoint·CA를 다시 조회
aws eks describe-cluster --profile <spoke-profile> --region ap-northeast-2 \
  --name <cluster-name> \
  --query 'cluster.{endpoint:endpoint,ca:certificateAuthority.data}'
```

`cluster-secret.yaml`의 `server`·`caData`만 갱신하고 **`addon-*` 라벨은 그대로 유지**한다
(빠뜨리면 addon 구독이 조용히 빠진 채 재배포된다 — 라벨 목록을 갱신 전에 먼저 `git diff`로
확인해 옮겨 적는다). `roleARN`은 바뀌지 않는다 — `cross-account-trust-role`이 만드는 Role
이름은 네이밍 규약상 결정적이라 재생성 후에도 동일하다.
```

**Step 7: 걷어내기 나머지(8,9,11,12,15) 이식**

구판 `04-teardown.md`의 「0. 시작 전에」·「2. 0단계 삭제보호 해제」·「4. 2단계·3단계 destroy」·
「5. 4단계 잔존물 검증」·「7. 되돌릴 수 없는 것」·「8. 자주 막히는 지점」을 거의 그대로
옮긴다. 단 「5. 4단계 잔존물 검증」의 `teardown-verify.sh` 실행 예시에
`AWS_PROFILE=asset`(spoke는 team이 아니다)을 명시하고, "profile을 잘못 넣으면 자원이 하나도
안 잡혀 잔존물 없음으로 오판할 수 있다"는 경고를 한 줄 추가한다(이번 세션 리뷰에서 짚은
실수 포인트).

**Step 8: 400줄 확인 및 검증**

```bash
wc -l docs/04-spoke-lifecycle.md
python3 scripts/validate-doc-conventions.py docs/04-spoke-lifecycle.md
```
Expected: 400줄 이하, 컨벤션 통과. 신규 집필 분량이 많아 이 파일이 400줄을 넘을 가능성이
hub 문서보다 크다 — 넘으면 §13(열린 질문)과 §14(재등록)를 묶어 별도 부록으로 뺄지 그 자리에서
판단한다.

**Step 9: 스테이징**

```bash
git add docs/04-spoke-lifecycle.md
```

---

### Task 3: 상호 참조 10곳 갱신

**Files (grep으로 재확인 후 정확히 이 목록대로):**

| 파일 | 현재 링크 | 새 링크 |
|---|---|---|
| `README.md` | `docs/03-new-project.md`(새 프로젝트 행)·`docs/04-teardown.md`(걷어내기 행) | 표를 hub/spoke 두 행으로 갈라 `docs/03-hub-lifecycle.md`·`docs/04-spoke-lifecycle.md` 각각 링크 |
| `docs/README.md` | 카탈로그 표 03·04 행 | 파일명·읽는 사람 문구 갱신(위 목차의 "읽는 사람" 그대로 반영) |
| `docs/00-team-access.md` | 「부트스트랩 절차」·「새 프로젝트 착수」 링크 2곳 | `03-hub-lifecycle.md`(부트스트랩 원본 설명이 이쪽에 있음) |
| `docs/01-architecture.md` | 「부트스트랩·워크플로 명령 실물」 링크 | `03-hub-lifecycle.md` |
| `docs/02-choose-your-path.md` | "골랐다 →"·"걷어내야 한다 →" 2곳 | 상황에 따라 `03-hub-lifecycle.md` 또는 `04-spoke-lifecycle.md`로 분기 서술(질문 D에서 이미 hub/spoke를 다루므로 "hub를 세운다면 → 03-hub-lifecycle.md, spoke를 세운다면 → 04-spoke-lifecycle.md"로 자연스럽게 갈린다) |
| `docs/05-modules.md` | 「이 값들을 어떻게 정하나」 링크 | 문맥상 hub 예시면 03, spoke 예시(`cross-account-trust-role` 등)면 04 |
| `docs/07-runbooks.md` | 「환경을 만드는/걷어내는 절차는 …가 소유한다」 2곳 | "hub는 `03-hub-lifecycle.md`, spoke는 `04-spoke-lifecycle.md`가 소유한다"로 갈라 명시 |
| `docs/08-decisions.md` | 「로컬에서 파기…」 항목의 04 링크 | 문맥이 destroy workflow 일반론이면 두 문서 다 링크하거나 대표로 hub 문서 링크 |
| `docs/AGENTS.md` | 카탈로그 표 03·04 행 | 파일명·설명 갱신 |
| `scripts/README.md` | `argocd-seed.sh` 행(02·03 링크)·`teardown-verify.sh` 행(04 링크) | `argocd-seed.sh`는 hub 전용이므로 `03-hub-lifecycle.md`만. `teardown-verify.sh`는 공통이므로 두 문서 다 링크 |
| `iac-reference-infra/live/dev/eks/README.md` | `` `docs/03-new-project.md`의 「2. 배포 저장소 만들기」 `` (절 번호 인용 — P6 위반) | `` `docs/04-spoke-lifecycle.md`(iac-module-library) `` — **문서 단위 링크로 정정**, 절 번호 삭제 |
| `iac-reference-infra/live/hub/eks/README.md` | 동일 패턴 | `` `docs/03-hub-lifecycle.md`(iac-module-library) `` — 문서 단위 링크로 정정 |

**Step 1: 위 표대로 각 파일을 `Edit`으로 수정한다.**

**Step 2: 갱신 후 재검색으로 잔존 참조가 없는지 확인**

```bash
cd /Users/a07326/born2k/ai/iac-module-library
grep -rn "03-new-project\|04-teardown" --include="*.md" . | grep -v ".omc/notepad.md"
cd /Users/a07326/born2k/ai/iac-reference-infra
grep -rn "03-new-project\|04-teardown" --include="*.md" . | grep -v ".omc/notepad.md"
```
Expected: 둘 다 결과 없음(`.omc/notepad.md`는 과거 시점 세션 기록이라 의도적으로 그대로 둔다 —
고치면 그 시점의 사실을 왜곡한다).

**Step 3: 각 repo에서 수정한 `.md` 파일 전체를 대상으로 컨벤션 검증**

```bash
cd /Users/a07326/born2k/ai/iac-module-library
python3 scripts/validate-doc-conventions.py $(git diff --name-only --cached -- '*.md')
```

**Step 4: 스테이징**

```bash
# iac-module-library
git add README.md docs/README.md docs/00-team-access.md docs/01-architecture.md \
  docs/02-choose-your-path.md docs/05-modules.md docs/07-runbooks.md docs/08-decisions.md \
  docs/AGENTS.md scripts/README.md
# iac-reference-infra
cd /Users/a07326/born2k/ai/iac-reference-infra
git add live/dev/eks/README.md live/hub/eks/README.md
```

---

### Task 4: 구판 파일 폐기

**Files:**
- Delete: `docs/03-new-project.md`, `docs/04-teardown.md`

**Step 1: Task 1~3이 전부 통과한 뒤에만 삭제한다** (git 이력에 남으므로 내용 손실 없음 — 설계
문서 「2. 폐기」 참조).

```bash
cd /Users/a07326/born2k/ai/iac-module-library
git rm docs/03-new-project.md docs/04-teardown.md
```

**Step 2: 삭제 후 재검증** — Task 3 Step 2의 grep을 다시 돌려 끊어진 링크가 없는지 최종 확인.

---

### Task 5: `iac-reference-infra`의 `docs/deployment-facts.md`에 결정 기록

**Files:**
- Modify: `docs/deployment-facts.md` — §5(배포 루트 형상과 CI 제약) 아래에 신규 소절 추가

**Step 1: 다음 내용을 §5.8 뒤에 「5.9」로 추가**

```markdown
### 5.9 deletion_protection — v1.0 이전까지 의도적으로 false

dev·hub의 `deletion_protection`(VPC `prevent_destroy`·EKS 네이티브 속성 둘 다)은 2026-08-21
현재 코드·AWS 실물 양쪽에서 `false`다(EKS는 `describe-cluster`로 실측 확인 — 필드 자체가
응답에 없음 = AWS 기본값 `false`와 일치). **사용자 결정(2026-08-21)**: 모듈 v1.0 출시
전까지는 반복 배포 편의를 위해 `false`를 유지한다. v1.0 이후에는 `CLAUDE.md`·
`03-hub-lifecycle.md`/`04-spoke-lifecycle.md`(module repo) 원칙대로 기본 `true`로 전환한다.
```

**Step 2: 400줄·컨벤션 확인**

```bash
cd /Users/a07326/born2k/ai/iac-reference-infra
wc -l docs/deployment-facts.md
python3 <module-repo-path>/scripts/validate-doc-conventions.py docs/deployment-facts.md
```

**Step 3: 스테이징**

```bash
git add docs/deployment-facts.md
```

---

### Task 6: 최종 리뷰 준비 (커밋은 사용자 승인 후)

**Step 1: 두 repo 각각 `git status`·`git diff --cached`로 변경 전체를 사용자에게 요약**

**Step 2: 사용자 승인 시에만 커밋** — 커밋 메시지는 두 repo 각각:

```
iac-module-library:
docs: 03/04를 hub/spoke 생애주기 문서로 재편

iac-reference-infra:
docs: deletion_protection v1.0 이전 정책 기록 + 참조 링크 정정
```

`git push`는 이 계획 범위 밖이다 — 사용자가 별도로 지시할 때까지 하지 않는다.

---

## 실행 방식 선택

**1. Subagent-Driven(이 세션)** — 태스크마다 새 subagent를 붙여 실행·리뷰. 문서 두 편(Task
1·2)이 분량이 크므로 이 방식이면 Task 1과 Task 2를 각각 다른 subagent에 맡길 수 있다.

**2. 이 세션에서 직접 순차 실행** — 문서 재편이라 코드 리뷰 사이클이 필요 없고, 내가 이미
소스 문맥(구판 전문·`cluster-secret.yaml` 실물·`deployment-facts.md` §5.8)을 전부 갖고 있어
subagent에 다시 브리핑하는 비용이 더 클 수 있다.

어느 쪽으로 진행할까요?
