# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 표의 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | hub·dev 전부 destroy. main push plan은 `hub/tgw`만 성공(정상. 나머지 4개는 `no matching RAM Resource Share found`로 실패하며, 철거 상태의 `data` 조회 실패라 코드 문제가 아니다). 변수 34개 전부 `nullable = false`. `scripts/argocd-seed.sh`는 없다(GitOps 저장소가 소유). pre-commit에 셸 게이트(`bash -n` + `shellcheck -x`) 있음. `scripts/README.md`가 셸 게이트 상세를 소유한다 |
| eks-platform-gitops | main = origin | dev cluster-secret 삭제 상태(라벨 먼저 뗀 뒤 파일 삭제). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. pre-commit에 주석 규칙 + 셸 게이트, 위반 0건. README 「로컬 게이트」 절이 활성화 방법을 갖는다 |
| aks-reference-infra | main = origin | 전부 철거 상태. 원본 이식 항목 완료. 변수 48건 `nullable = false`. pre-commit에 셸 게이트 있음. `bootstrap/config.sh`의 `GH_ORG_ID`·`GH_REPO_ID`는 대입과 `readonly`를 나눠 `gh api` 실패가 `set -e`에 잡힌다 |
| aks-platform-gitops | main = origin | dev 스포크 철거 2단계 완료(라벨 제거 → cluster-secret 삭제). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. 주석 규칙 게이트 + 셸 게이트 설치 완료, 위반 0건 |

⚠️ 로컬 전제: 훅이 `shellcheck`를 **하드 요구**한다(없으면 즉시 실패). clone마다
`git config core.hooksPath .githooks`와 `brew install shellcheck`가 필요하다. 이 Mac에는
0.11.0이 설치돼 있다.

## 지난 세션 (2026-09-16)

`aks-platform-gitops`에 주석 규칙 게이트를 이식했다(`d3af114`). `eks-platform-gitops`의
검사기·훅을 바이트 동일로 가져왔고 glob 범위가 파일 전부를 덮어 레이아웃 조정이 없었다.
좌표 41건을 걷어냈고, YAML 블록 스칼라 안에 숨어 검사기가 못 보던 2건도 손으로 정리했다.
`.omc/plans/` 7건과 `alb-controller` 8건은 가리키는 대상이 사라진 끊긴 포인터였다.
`eks-platform-gitops`에는 README 「로컬 게이트」 절을 신설하고 `.pyc` 추적을 끊었다(`ebeb8ce`).

`.sh` 문법을 아무도 검사하지 않던 구멍을 4개 저장소 pre-commit으로 닫았다(`858f994`·`135d698`·
`16d98ef`·`b59553c`). CI가 아니라 훅에 둔 이유: 배포 워크플로는 루트별 트리거라 `.sh`만 바뀐
커밋은 아무 워크플로도 돌리지 않고, GitOps 저장소에는 워크플로 자체가 없어 `argocd-seed.sh`를
못 덮는다. shellcheck 지적 49건 중 34건은 의도된 패턴이라 사유를 적은 `disable` 지시자로
남겼다(`--tags $(tag_args_iam …)`의 비인용은 인용하면 aws CLI가 거부한다). `-x`가 `source`를
따라가 SC1091 4건이 사라졌다.

동작이 바뀌는 수정 셋을 넣었다. `cd "$(dirname …)" || exit 1` 4곳은 `set -euo`가 `config.sh`에
있고 `cd`가 그 전에 돌아 실패 시 엉뚱한 디렉토리를 읽던 자리다. AKS `GH_ORG_ID`·`GH_REPO_ID`는
`readonly`의 종료코드가 `gh api` 실패를 덮어 빈 ID가 `GH_ORG_REPO_SUBJECT`를 망가뜨릴 수
있었다. jq 주석의 작은따옴표는 셸 문자열을 끊고 있었다(동작은 했다. 공백 하나만 더 들어가면
인자가 쪼개지는 구조였다). 철거 상태라 실행 검증은 못 했고 정적 검사로만 확인했다.

두 배포 루트의 `validate-doc-conventions.py`가 폐기된 em-dash 금지를 아직 강제하고 있었다.
`writing-style.md`에 그 항목이 없고 지금 「문체 규칙 6」은 전혀 다른 규칙이다. 걷어내고 기각
근거를 검사기 헤더에 남겼다. 지난 세션에 걷어낸 것은 *주석* 게이트였고 *문서* 게이트가 남아
있었다.

## 다음 할 일
- [ ] [*-ref] [*-gitops] 훅 파일 자신(`.githooks/pre-commit`·`pre-push`)은 셸인데 어느 게이트도
      보지 않는다 — 셸 게이트의 `sh_staged` 패턴이 `.githooks/`를 안 잡는다. 이번 세션에
      손으로 `bash -n`·`shellcheck` 0건을 확인했을 뿐이라 다음 편집 때 깨져도 안 걸린다.
      ⚠️ 패턴에 `^\.githooks/`를 넣으면 훅이 자기 자신을 검사하게 되니 그 순환을 먼저 판단한다
- [ ] [*-gitops] EKS·AKS 재구축 후 cluster Secret 등록 — ⚠️ teardown이 매칭 라벨을 **먼저 떼고**
      파일을 지웠다. git 이력에서 되살리면 라벨이 빠진 껍데기이고 그 상태로는 Application이 하나도
      안 생긴다. EKS dev는 `environment`·`tier: nonprd`·`vpcName`·`karpenterNodeRole`,
      AKS dev는 `environment`·`tier: nonprd`·`addon-karpenter`가 필요하다
- [ ] [eks-gitops] 재구축 후 첫 sync에서 baseline addon 4개(ALBC·karpenter·cluster-autoscaler·
      keda)가 OutOfSync로 뜬다 — 좌표 정리가 `helm: values: |` 블록 안 주석을 건드려
      `spec.source.helm.values` 문자열이 바뀌었다. 렌더 결과는 같으니 한 번 sync하면 끝이다
- [ ] [*-gitops] nonprd 클러스터가 생기면 `*-nonprd` ApplicationSet 팬아웃 실측 — 지금은 의도된 빈 슬롯이다
- [ ] [*-gitops] 실제 승격 한 번 돌려보기(nonprd 올림 → 검증 → prd 올림). Kyverno는 엔진·정책 값 4개를
      짝으로 움직여야 한다. ⚠️ 3.9 라인으로 넘길 때는 `policyType` 결정을 먼저 답한다
      (②에 `policyType=ClusterPolicy` 명시 vs whitelist·③를 함께 이동)
- [ ] [module] 다음 `workbench`·`aks-workbench` 태그 메시지에 인스턴스/VM 교체를 적는다 — `6e34dec`가
      `.tftpl` 주석을 바꿔 렌더링 결과가 달라졌다(`user_data_replace_on_change`·`custom_data` ForceNew)
- [ ] [local] 약 한 달 뒤 `~/archive/`(에이전트·스킬·hook·`.omc` 백업 3개) 삭제
