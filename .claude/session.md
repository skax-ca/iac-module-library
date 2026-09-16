# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 표의 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | hub·dev 전부 destroy. main push plan은 `hub/tgw`만 성공(정상. 나머지 4개는 `no matching RAM Resource Share found`로 실패하며, 철거 상태의 `data` 조회 실패라 코드 문제가 아니다). 변수 34개 전부 `nullable = false`. `scripts/argocd-seed.sh`는 없다(GitOps 저장소가 소유). pre-commit 셸 게이트가 `.githooks/pre-commit`·`pre-push` 자신까지 덮는다. `scripts/README.md`가 셸 게이트 상세를 소유한다 |
| eks-platform-gitops | main = origin | dev cluster-secret 삭제 상태(라벨 먼저 뗀 뒤 파일 삭제). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. pre-commit에 주석 규칙 + 셸 게이트, 위반 0건. 셸 게이트가 훅 파일 자신까지 덮는다. README 「로컬 게이트」 절이 활성화 방법을 갖는다 |
| aks-reference-infra | main = origin | 전부 철거 상태. 원본 이식 항목 완료. 변수 48건 `nullable = false`. pre-commit 셸 게이트가 훅 파일 자신까지 덮는다. `bootstrap/config.sh`의 `GH_ORG_ID`·`GH_REPO_ID`는 대입과 `readonly`를 나눠 `gh api` 실패가 `set -e`에 잡힌다 |
| aks-platform-gitops | main = origin | dev 스포크 철거 2단계 완료(라벨 제거 → cluster-secret 삭제). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. 주석 규칙 게이트 + 셸 게이트 설치 완료, 위반 0건. 셸 게이트가 훅 파일 자신까지 덮는다 |

⚠️ 로컬 전제: 훅이 `shellcheck`를 **하드 요구**한다(없으면 즉시 실패). clone마다
`git config core.hooksPath .githooks`와 `brew install shellcheck`가 필요하다. 이 Mac에는
0.11.0이 설치돼 있다. `timeout`은 이 Mac에 없다(coreutils 미설치).

## 지난 세션 (2026-09-16)

셸 게이트가 훅 파일 자신을 검사하지 않던 구멍을 4개 저장소에서 닫았다(`4050582`·`3fd5379`·
`d7f680f`·`c1389b6`). 두 계열이 서로 다른 이유로 놓치고 있었다: ref는 경로 화이트리스트가
`bootstrap`·`scripts`·`.claude/skills`로 좁아서, gitops는 `\.sh$` 확장자를 요구해서다. git 훅은
이름이 규격이라 확장자를 붙일 수 없으므로 이름으로 명시했고, `.githooks/` 통째가 아니라
`pre-(commit|push)`로 좁혀 비셸 파일이 섞여도 안전하게 했다.

*"깨지면 실행이 알려 준다"* 는 기대가 성립하지 않음을 최소 재현으로 확인했다. 훅은 조기
`exit 0`으로 끝나는 경로가 있고(ref는 `.tf` 없는 커밋, gitops는 모든 커밋), 그 뒤쪽의 문법
오류는 런타임이 도달하지 못해 종료코드 0으로 통과한다. 파일 전체를 정적으로 보는 것은
`bash -n` 뿐이다. 착수 전 우려했던 재귀는 근거가 없었다 — `bash -n`·shellcheck는 파싱·정적
분석이라 훅을 다시 실행하지 않는다. 남는 사각지대는 게이트보다 **앞선** 줄이 망가져 게이트
자체를 건너뛰는 경우 하나뿐이고, 그 판단을 훅 인라인 주석에 남겼다.

주입 테스트 3건이 전부 차단됨을 실측했다: `pre-push`에 SC2155(변경 전에는 검사 대상 자체가
아니었다), `pre-commit` 자기 자신에 SC2155, gitops 훅의 조기 exit 뒤쪽에 문법 오류.

ref 저장소 2개에는 문서·주석 게이트가 em-dash를 강제한다고 적힌 낡은 주석이 남아 있어 함께
걷어냈다. 검사기 쪽은 이미 문장부호를 보지 않는다고 스스로 선언하고 있었다.

## 다음 할 일
- [ ] [module] 이 저장소 훅 2개(`.githooks/pre-commit`·`pre-push`)에는 셸 게이트가 아예 없다 —
      추적 중인 `.sh`가 0건이라 안 깔았는데 훅 파일 자신이 셸이다. 형제 4개는 이번에 닫았다.
      지금 두 파일은 `bash -n`·`shellcheck -x` 0건이라 넣어도 마찰이 없다
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
- [ ] [module] 다음 `workbench`·`aks-workbench` **기능** 태그 메시지에 아래 문구를 싣는다. 지금 태그를
      컷하지 않는다(`6e34dec`는 주석·문서 전용이다). 미릴리스 확인: `6e34dec`가 `workbench-v0.9.0`·
      `aks-workbench-v0.7.0` 양쪽보다 뒤에 있다. 메커니즘도 실물 확인 완료 — AWS는
      `modules/aws/workbench/main.tf`의 `user_data_replace_on_change = true`(기본값 `false`를 우리가
      뒤집은 것), Azure는 `custom_data`가 provider 강제 ForceNew(azurerm 공식 문서 "Changing this
      forces a new resource to be created"). 붙여 넣을 문구:

      ```
      ⚠️ 이 태그는 user-data 템플릿의 주석 변경을 포함한다. 소비 측 plan에
         인스턴스/VM 교체가 뜬다.
         AWS: aws_instance.user_data_replace_on_change = true
         Azure: azurerm_linux_virtual_machine.custom_data 가 ForceNew
         렌더링 내용은 같고 바뀐 것은 주석뿐이다. apply 전에 교체를 예상할 것.
      ```
- [ ] [local] 약 한 달 뒤 `~/archive/`(에이전트·스킬·hook·`.omc` 백업 3개) 삭제
