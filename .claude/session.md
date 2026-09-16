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

주석 규칙 검사기는 5개 저장소 전부 `scripts/validate-comment-conventions.py` 한 이름이고,
위반 메시지가 **외부 참조 / 이력 서술** 두 범주 중 어느 쪽인지를 앞에 붙인다. 규칙 SSOT는
이 저장소 `docs/conventions.md` 「주석」 절이다.

## 지난 세션 (2026-09-16)

이 저장소 훅 2개에 셸 게이트를 심었다(`7166f6d`). 형제 4개는 지난 세션에 닫았고 여기만
*"추적 중인 `.sh`가 0건"* 이라는 이유로 빠져 있었는데, 훅 파일 자신이 셸이다. 게이트 없는 HEAD
버전에 문법 오류를 붙여 `.tf` 없이 실행하면 조기 `exit 0` 경로라 exit 0으로 통과하고, 같은
파일을 `bash -n`은 exit 2로 잡는 것을 대조로 확인했다. 정규식은 형제와 같게 뒀다(없는 경로는
매치 비용 0, 다섯 저장소 게이트 줄이 같아야 diff로 대조된다).

주석 좌표 검사 대상에 훅 2개를 넣었다(`b78c69b`). 규약이 *"산문이 실리는 면을 확장자로 가르지
않는다"* 고 선언해 두고 검사는 `.tf`만 보고 있었다. 넓히니 `pre-commit` 안에 위반 3건이 이미
있었다 — 두 건은 게이트가 무엇을 금지하는지 설명하느라 금지 기호를 리터럴로 쓴 것이고, 한 건은
stale 태그 검사의 근거를 날짜와 사건 서술로 적은 것이라 메커니즘 서술로 바꿨다. CI가 검사기를
인자 없이 부르므로 `default_targets()`만 넓혀 `verify.yml`을 건드리지 않았다.

검사기 이름과 규칙 용어를 실제 범위에 맞췄다(PR #56, `936e19d`·`3613093`, 머지 `9bad04c`).
`validate-tf-comments.py` → `validate-comment-conventions.py`(형제 4개가 이미 쓰는 이름이고,
그 4개도 ref 쌍과 gitops 쌍 내용이 달라 같은 이름 아래 범위가 다른 것이 이미 관행이다).
그리고 이 저장소 전용어였던 `좌표`를 **외부 참조**(절 번호·결정 식별자·Task·PR 번호)와
**이력 서술**(날짜·사건 서술) 둘로 나눴다. 값은 "읽기 좋다"보다 **고치는 방향이 갈린다** 쪽이
크다 — 외부 참조는 가리키던 내용을 본문으로 옮겨 쓰고, 이력 서술은 통째로 지운다. 한국 IT
업계에 이 개념 전체를 가리키는 확립 용어가 없음을 리서치로 확인한 뒤 내린 결론이다.

형제 4개에 같은 용어를 스윕했다(`c1ad2fb`·`d83db1d`·`5ebcd86`·`d09c312`). 검사기 헤더가
*"규칙 SSOT는 그 문서다"* 라고 선언하므로 사본이 다른 말을 쓰면 그 선언이 거짓이 된다. 패턴
순서는 바꾸지 않고 범주 라벨만 얹어 탐지 동작과 보고 순서를 그대로 뒀다. `CLAUDE.md` 세 곳에서
**다른 뜻**으로 쓰이던 `문서 좌표`도 `문서 위치`로 걷어냈다.

## 다음 할 일
- [ ] [*-gitops] EKS·AKS 재구축 후 cluster Secret 등록 — ⚠️ teardown이 매칭 라벨을 **먼저 떼고**
      파일을 지웠다. git 이력에서 되살리면 라벨이 빠진 껍데기이고 그 상태로는 Application이 하나도
      안 생긴다. EKS dev는 `environment`·`tier: nonprd`·`vpcName`·`karpenterNodeRole`,
      AKS dev는 `environment`·`tier: nonprd`·`addon-karpenter`가 필요하다
- [ ] [eks-gitops] 재구축 후 첫 sync에서 baseline addon 4개(ALBC·karpenter·cluster-autoscaler·
      keda)가 OutOfSync로 뜬다 — 문구 정리가 `helm: values: |` 블록 안 주석을 건드려
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
