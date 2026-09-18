# CLAUDE.md: 프로젝트 규칙

**읽는 사람**: 이 저장소에 코드를 쓰거나 설계를 검토하는 사람, 그리고 이 저장소의 모듈을 소비하는
배포 루트에서 작업하는 사람.

우리 팀이 **여러 실제 프로젝트에서 재사용**하는 IaC 모듈 자산 라이브러리.
프로젝트마다 아키텍처를 새로 그리는 건 당연하다. 문제는 그때 내린 **설계 판단이 남지 않아
비슷한 고민을 반복**하는 것이고, 그 판단을 모듈·패턴·규약으로 축적하는 것이 이 repo의 존재 이유다.

**스택**: **OpenTofu**(MPL-2.0) + GitHub Actions(OIDC) + S3 backend(`use_lockfile`) + OPA/Conftest

**`.tf` 작업 규칙**(네이밍·아키텍처·검증·모듈 설계 원칙)은 `.claude/rules/terraform.md`가 소유한다
(`.tf` 파일을 열 때 자동 로드된다). 이 파일은 리포 전역 규칙과 「배포 루트 공통」 규칙만 갖는다.

**작성 규칙**은 `docs/writing-style.md`가 소유하고, 두 절의 범위가 다르다.
**구조 규칙(1절)**은 저장소 문서(`docs/*.md`·전역 `README.md`·루트 `CLAUDE.md`)에만 걸린다.
**문체 규칙(2절)**은 **산문을 쓰는 모든 작업에 걸린다**: 문서·`.tf` 주석·`variables.tf`
description·GitOps 매니페스트 주석·셸 `echo` 문구. 파일 확장자로 가르지 않는다.

## 엔진: OpenTofu 단독

명령은 `terraform`이 아니라 **`tofu`**다. 로컬·CI·문서·lock 전부 하나로 일원화한다.
채택 근거(라이선스가 아니라 조달 마찰·리워크 제거)는 `docs/decisions.md`가 소유한다.

- **두 엔진 동시 지원은 검토 후 기각했다**(실측 비용 5건). *"둘 다 지원하면 되지 않나"* 라는
  질문이 나오면 **`docs/decisions.md`를 먼저 읽는다**. 이미 값을 매겨 기각한 안이다.
- **Terraform 호환성은 계약이 아니라 부산물**이다. 보장하지 않지만 이유 없이 깨뜨리지도 않는다:
  OpenTofu 고유 기능을 쓸 때는 이유를 설계 문서에 남긴다(강제 장치는 없다, `docs/conventions.md`).

---

## 0. 이 repo의 위치 (반드시 먼저 읽을 것)

| repo | 역할 |
|------|------|
| **이 repo (`iac-module-library`)** | 모듈·설계의 **현행 SSOT**. 모든 개발은 여기서 |
| `eks-reference-infra` | AWS 배포 루트. 이 repo의 모듈을 **git tag로 소싱** |
| `eks-platform-gitops` | AWS 플랫폼 GitOps 매니페스트(**계층 2**). ArgoCD가 pull로 reconcile |
| `aks-reference-infra` | Azure 배포 루트. 이 repo의 모듈을 **git tag로 소싱** |
| `aks-platform-gitops` | Azure 플랫폼 GitOps 매니페스트(**계층 2**). ArgoCD가 pull로 reconcile |

### 소비 방식 (프로젝트 repo에서)

```hcl
module "vpc" {
  source = "git::https://github.com/<org>/iac-module-library.git//modules/aws/vpc?ref=vpc-vX.Y.Z"
  # ...
}
```

`vX.Y.Z`는 자리표시자다. 실제 최신 태그는 `git tag -l`로 확인한다.
태그는 **컴포넌트별 semver**: `vpc-vX.Y.Z` · `eks-cluster-vX.Y.Z`.

## 버전 정책: 전 모듈 `0.y.z`

번호 체계의 SSOT는 **`docs/conventions.md`**이고, 기각한 안은 **`docs/decisions.md`**가 갖는다.
요약: 전 모듈이 개발 단계(`0.y.z`)라 파괴적 변경도 마이너로 흡수한다("마이너/메이저 판정"을 하지
않는다, 전부 마이너다). `1.0.0`은 전 모듈 일괄이 아니라 **모듈별로** 컷한다. 신규 모듈은 `0.1.0`에서
시작한다. 버전 혼재(`vpc-v0.3.0` + `workbench-v0.6.0`)는 결함이 아니라 **정보**다.

## 배포 루트 공통

`eks-reference-infra`·`aks-reference-infra`에서 작업할 때 적용한다. 두 repo의 `CLAUDE.md`는 그 repo에서만
참인 값(루트 목록·변수명·리전 약어·훅 활성화)과 문서 위치만 갖고, 규칙은 이 절이 소유한다.

| 항목 | 규칙 |
|------|------|
| 역할 | 이 repo의 모듈을 태그로 소비해 세우고 걷어낸다. 모듈 내부는 고치지 않는다. 고칠 것이 있으면 여기서 고치고 태그를 올린다 |
| state | 배포 루트마다 별도 state, key는 `<env>/<component>.tfstate`. 루트 간 결합은 `terraform_remote_state`가 아니라 Name·태그 기반 `data` 조회다. 예외(크로스 구독 등)는 그 repo 값 표가 적는다 |
| plan → apply | push가 plan을 돌리고, apply job은 environment(`hub`·`dev`)의 required reviewers 승인을 기다린다. 승인자는 **그 run의** plan 요약을 읽고 누르고, 같은 run이 저장된 plan을 적용한다. `workflow_dispatch`는 destroy·replace·재-plan 경로이고 역시 승인을 기다린다. `pull_request` 트리거는 두지 않는다(PR plan은 OIDC subject를 넓혀야 한다) |
| 재시도 | ⚠️ 실패한 apply는 `gh run rerun <run-id> --failed`로 **이미 승인한 저장된 plan을 그대로** 다시 적용한다. 새 dispatch는 새 plan이고 다시 승인 대상이다. plan artifact는 7일 보존이라 그 안에 승인한다 |
| 로컬 | `tofu init`·`validate`까지. apply·destroy는 각 repo의 가드(실행 Role 신뢰 관계, `ci_run` 검사)가 막는다 |
| 네이밍 | 약어 SSOT는 `docs/naming/abbreviations/{aws,azure}.md`. 배포 루트는 약어를 직접 조합하지 않고 모듈에 `naming` 객체를 넘긴다 |
| 로컬 게이트 | pre-commit(문서·주석 규칙 → 셸 `bash -n`·`shellcheck -x` → fmt → tflint → trivy), pre-push(변경된 루트 `validate`). `verify.yml`이 같은 명령을 PR·main push에서 다시 돈다(훅이 꺼진 클론과 fork PR을 막는다). 명령이 갈리면 둘 중 하나가 틀린 것이다. `.tflint.hcl` ruleset 핀은 이 repo와 같게 유지한다. 모듈 내부 지적은 `.trivyignore`에 넣지 않는다(모듈 쪽 위험 수락은 이 repo가 한다) |
| 모듈 계약 | 루트 `main.tf`가 넘기는 변수와 참조하는 출력은 추정하지 않는다. `live/*/.terraform/modules/`의 실물이나 이 repo 소스로 확인한다 |
| `.tf` 작성 | 배포 루트도 리소스와 변수를 직접 선언한다. 그 코드에도 `docs/conventions.md` 「코드 규약」(보안 규칙은 inline이 아닌 별도 리소스, 워크스페이스 간 데이터는 `data` 조회, 새 리소스·인자는 문서로 확인하고 추정하지 않는다)과 `docs/decisions.md` 「변수 계약 (nullable)」, `docs/writing-style.md` 2절(문체)이 그대로 적용된다. ⚠️ 이 repo의 `.claude/rules/terraform.md`는 **배포 루트에 실리지 않는다**(`paths` 규칙은 작업 디렉토리 기준이다). 그 파일은 모듈 전용이고, 배포 루트의 진입점은 이 행이다 |
| 설계 근거의 자리 | 배포 루트에 설계 문서 계층(ADR 등)을 두지 않는다. 패턴 갈림길은 이 repo `docs/architectures/`, 그 repo 고유 판단은 적용된 `.tf`/`.sh`의 인라인 주석, 운영 절차는 그 repo `docs/hub-lifecycle.md`·`spoke-lifecycle.md`·`runbooks.md` |
| 외부 참조·이력 서술 금지 | 주석·문서에 **외부 참조**(절 번호·결정 식별자·PR 번호)와 **이력 서술**(날짜·사건 서술)을 쓰지 않는다(`docs/conventions.md`). 주석은 "왜 이 값인가"와 "바꾸면 무엇이 깨지는가"에만 답한다 |
| 세션 메모 | 에이전트 세션 메모는 저장소 지식이 아니다. 절차·gotcha는 운영 절차 문서나 인라인 주석에 반영한다 |

## GitOps 저장소 공통

`eks-platform-gitops`·`aks-platform-gitops`에서 작업할 때 적용한다. 두 repo는 `CLAUDE.md`를 두지 않는다
(세션을 이 repo에서 열고 `--add-dir`로 붙이므로 이 절이 닿는다). 규약은 각 repo의 `README.md`가 갖는다.

| 항목 | 규칙 |
|------|------|
| 브랜치 | 매니페스트는 **브랜치 → PR**. `verify.yml`이 PR에서 돌고 ruleset이 그것을 요구한다. push가 곧 apply인 저장소라 머지 전 게이트가 유일한 게이트다. README만 바뀐 커밋은 main 직접이다 |
| ⚠️ 배포 루트와의 차이 | 배포 루트는 push가 plan, environment 승인이 apply인 2단계다. **매니페스트는 push가 곧 apply다**(`targetRevision: main` + `automated`) |
| 커밋 전 확인 | `verify.yml`이 PR·main push에서 YAML 파싱·로컬 차트 `helm lint`/`template`·`kyverno test`를 돈다(오프라인). ArgoCD의 렌더(Application 조립·파라미터 주입·`include`)는 CI가 흉내 내지 않는다. 클러스터가 살아 있으면 `argocd app manifests <app> --core`, 철거 상태면 `helm template --repo <url> <chart> --version <v> -f <values>`로 대체한다. ⚠️ ApplicationSet의 `parameters`는 values 파일에 없으므로 `--set`으로 함께 넘긴다 — 빠뜨리면 렌더가 0건에 `ComparisonError`가 되는데, 이는 차트를 받아오지 못했을 때와 같은 모양이라 값 문제인지 네트워크 문제인지 구분되지 않는다 |
| ⚠️ 정책은 렌더로 부족하다 | admission 정책(Kyverno)은 렌더가 성공해도 **판정이 틀릴 수 있다**. 차단 정책이 조용히 안 걸리거나 무관한 워크로드를 막아도 렌더는 통과한다. 그래서 커스텀 정책마다 `tests/kyverno/<정책>/`에 통과·차단·제외 픽스처와 기대 판정(`kyverno-test.yaml`)을 두고 `verify.yml`이 `kyverno test`로 돌린다. CLI는 차트 `appVersion`과 같은 버전으로 핀한다. 네임스페이스 라벨에 기대는 selector는 `values.yaml`(`apiVersion: cli.kyverno.io/v1alpha1`, `namespaceSelector`가 최상위 키)로 준다. 정책을 고치면 픽스처도 같이 고친다 |
| 환경 분리 | ⛔ **브랜치로 나누지 않는다.** 티어는 `applicationsets/`의 prd·nonprd 블록과 cluster Secret의 `tier` 라벨이 나눈다. 두 블록에서 갈려도 되는 값은 `targetRevision` 하나다 |
| 승격 | 클러스터가 있으면 nonprd → 검증 → prd. **철거 상태에서는 양 티어를 같이 올리고 재구축 때 한 번에 검증한다** — 검증할 대상이 없는 상태에서 커밋을 둘로 쪼개는 것은 절차만 남는다 |
| 자기 관리 ArgoCD | `bootstrap/argocd-app.yaml`의 `targetRevision`과 `bootstrap/argocd-seed.sh`의 `ARGOCD_CHART_VERSION`은 **항상 같다**. 갈리면 흡수가 업그레이드가 되고, sync 주체가 sync 도중에 재시작한다. 올리는 것은 **클러스터가 철거된 상태에서** 한다 |
| 버전 핀의 자리 | 한 차트 버전이 여러 곳에 박힌다(`eks-platform-gitops`는 `README.md`의 addon 표가 버전을 중복 보유한다 — 자동 생성이 아니라 손으로 쓴 표다). 올린 뒤 `grep -rn '<옛버전>'`으로 0건을 확인한다 |
| ⛔ 재검토 트리거 | **클러스터를 상시 가동으로 바꾸거나 작업자가 2인 이상이 되면** 이 절을 다시 연다. 그때는 ruleset의 승인 수(지금 0)와 bypass 범위, 그리고 `argocd app diff`를 CI로 끌어올 수 있는지(클러스터가 있어야 한다)를 본다 |

---

## 설계·검토 우선 규칙 (최우선, 필수 준수)

**구현하기 전에 반드시 설계 및 검토를 완료한 후 구현할 것.**

- 코드(`.tf`) 작성/변경 전에 관련 설계가 `docs/`에 존재하고 승인·검토되었는지 확인한다.
  모듈 자체의 입력·출력 계약은 각 모듈의 README(terraform-docs 자동 생성)가, 모듈 간 연동은
  `docs/module-catalog.md`가, 규약은 `docs/conventions.md`가 소유한다.
- 배포 루트에서는 설계 문서가 그 repo의 `docs/hub-lifecycle.md`·`spoke-lifecycle.md`·`runbooks.md`와
  `.tf`/`.sh` 인라인 주석이다. 작업 전에 해당 절차 문서를 먼저 읽는다.
- 설계가 없거나 불완전하면 **구현을 멈추고** 먼저 설계 문서(설계 → 검토 → 승인)를 작성/보완한다.
- "간단해 보인다"는 이유로 이 단계를 건너뛰지 않는다. 새 모듈·아키텍처 변경·인터페이스 변경은 예외 없음.
- 순서: **설계 문서화 → 검토/승인 → 구현 → 검증(fmt/validate/test)**.

> ⛔ **기각한 안을 다시 제안하기 전에 그 스코프의 기록을 읽는다.** 저장소 전역은
> `docs/decisions.md`(패턴 문서 색인도 여기 있다), 아키텍처마다 갈리는 것은 그 패턴 문서의
> 「하지 않는 것」, 모듈 하나에만 걸리는 것은 그 모듈의 `variables.tf` description과 README다.
> 거기 적힌 이유가 더 이상 성립하지 않음을 먼저 보여야 재검토가 열린다.

---

## 브랜치·PR 규칙

| 변경 대상 | 경로 |
|-----------|------|
| **`.tf` · `.github/workflows/` · GitOps 매니페스트 · 셸 · 검사기** — `verify.yml`이 보는 것 전부 | **브랜치 → PR** |
| **문서 전용** | **`main` 직접 커밋** |

- 기준은 *"CI가 **머지 전에** 막아야 하는가"* 하나다. 5개 저장소 전부 `verify.yml`이 `pull_request`에서 돌고
  main의 ruleset이 그 job을 required status check로 요구한다. 문서에는 main을 깨뜨릴 산출물이 없다.
- **main ruleset**(5개 저장소 동일): 삭제 금지 · force-push 금지 · PR 필수(승인 수 0) · required status check.
  bypass는 repository admin뿐이고 **그 용도는 문서 직접 커밋 하나다.** CI가 보는 파일을 bypass로 밀지 않는다 —
  규칙은 외부 기여자에게 걸리고 유지자는 훅과 이 문장이 지킨다.
- ⛔ **문서 전용 변경에 PR을 쓰지 않는다.** 이 repo는 사실상 1인 작업이라 리뷰는 self-merge = 형식이고,
  커밋 메시지를 길게 쓰는 문화라 PR 본문도 중복이다. 형식만 남은 절차는 비용만 낸다.
