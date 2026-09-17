# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 표의 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | hub·dev 전부 destroy. main push plan은 `hub/tgw`만 성공(정상. 나머지 4개는 `no matching RAM Resource Share found`로 실패하며, 철거 상태의 `data` 조회 실패라 코드 문제가 아니다). 변수 34개 전부 `nullable = false`. `scripts/argocd-seed.sh`는 없다(GitOps 저장소가 소유). pre-commit 셸 게이트가 `.githooks/pre-commit`·`pre-push` 자신까지 덮는다. `scripts/README.md`가 셸 게이트 상세를 소유한다 |
| eks-platform-gitops | main = origin | dev cluster-secret 삭제 상태(라벨 먼저 뗀 뒤 파일 삭제). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. root App은 `directory.include` allow-list(14개 파일)이고 exclude·skip-rendering 마커를 쓰지 않는다. `kyverno/custom-policies`는 평문 디렉토리, `shared-gateway`·`karpenter/nodepool`은 값 주입이 있어 helm 유지. pre-commit에 주석 규칙 + 셸 게이트, 위반 0건 |
| aks-reference-infra | main = origin | 전부 철거 상태. 원본 이식 항목 완료. 변수 48건 `nullable = false`. pre-commit 셸 게이트가 훅 파일 자신까지 덮는다. `bootstrap/config.sh`의 `GH_ORG_ID`·`GH_REPO_ID`는 대입과 `readonly`를 나눠 `gh api` 실패가 `set -e`에 잡힌다 |
| aks-platform-gitops | main = origin | dev 스포크 철거 2단계 완료(라벨 제거 → cluster-secret 삭제). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. root App은 `directory.include` allow-list(9개 파일)이고 exclude·마커를 쓰지 않는다. 로컬 차트 3개 전부 평문 디렉토리(템플릿 문법 없음). 주석 규칙 게이트 + 셸 게이트, 위반 0건 |

⚠️ 로컬 전제: 훅이 `shellcheck`를 **하드 요구**한다(없으면 즉시 실패). clone마다
`git config core.hooksPath .githooks`와 `brew install shellcheck`가 필요하다. 이 Mac에는
0.11.0이 설치돼 있다. `timeout`은 이 Mac에 없다(coreutils 미설치). `kubeconform` 0.8.0이
설치돼 있다(개발 중 손으로 돌리는 스키마 검증, 훅에는 넣지 않는다).

주석 규칙 검사기는 5개 저장소 전부 `scripts/validate-comment-conventions.py` 한 이름이고,
위반 메시지가 **외부 참조 / 이력 서술** 두 범주 중 어느 쪽인지를 앞에 붙인다. 규칙 SSOT는
이 저장소 `docs/conventions.md` 「주석」 절이다.

## 지난 세션 (2026-09-17)

ArgoCD "자기소멸(self-superseding)" 설계를 공식 문서·커뮤니티로 평가했다. 패턴 자체는
공식(「Manage Argo CD Using Argo CD」 + App of Apps)이고 유일한 강제 조건 `ServerSideApply=true`를
이미 충족한다. 비용은 패턴이 아니라 root App이 저장소 루트를 `path: .`로 통째 스캔하고
예외를 exclude·`skip-file-rendering` 마커(deny-list)로 빼던 적용 방식에 있었다 — 마커 때문에
값도 없는 addon이 helm 차트가 됐고, 마커를 설명하는 주석이 든 ApplicationSet 파일이 스캔에서
빠진 사고가 eks 이력에 두 번 있다.

`gitops.md` 「하지 않는 것」을 deny-list 기각 → `directory.include` allow-list로 바꿨다
(`dd055e6`). 두 gitops 저장소에 반영(`8f59b56`·`9130c6a`): root-app include 전환, 마커 전부
제거, 마커 때문에만 차트였던 것은 평문 디렉토리로(aks 3개 전부, eks는 custom-policies만).
include 패턴은 Argo CD 소스의 gobwas/glob(구분자 없음, `*`가 `/`를 넘는다) 의미론으로 전체
파일 목록에 대조해 옛 규약과 스캔 집합이 같음을 확인했다. `argocd-app.yaml`의 `prune: false`
근거 중 "helm 릴리스 Secret·repository Secret이 prune될 수 있다"는 절반은 틀려서 걷어냈다
(`d8db91f`·`c9afa8d`) — Argo CD 3.x는 `tracking-id` 애노테이션이 있는 리소스만 prune 후보다.

Context7 MCP를 프로젝트 스코프 `.mcp.json`에 등록했다(`2477acf`, API 키 없음). Argo CD 작성
시점을 돕는 전용 MCP는 없고 공식 `mcp-for-argocd`는 운영용이라 넣지 않았다. kubeconform +
datree CRDs-catalog로 바뀐 매니페스트를 strict 검증해 전부 통과했고, `AKSNodeClass
imageFamily: Ubuntu` 지적 1건은 카탈로그가 낡은 오탐이다(업스트림 CRD는 허용·기본값).

## 다음 할 일
- [ ] [local] 다음 세션 첫 시작 때 `.mcp.json`의 `context7` 승인 프롬프트가 뜬다. rate limit이 걸리면
      context7.com/dashboard에서 키를 받아 로컬 설정에 `Authorization: Bearer` 헤더로 얹는다(저장소에 넣지 않는다)
- [ ] [*-gitops] 재구축 seed 5단계 직후 `argocd app manifests root-app --core`로 include가 의도대로
      동작하는지 확인 — 리소스 수가 aks 9개·eks 14개여야 한다. 평문으로 바꾼 CR 디렉토리
      (aks 3개, eks `kyverno/custom-policies`)의 전담 Application이 Directory 타입으로 렌더되는지도 본다
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
- [ ] [module] `verify.yml`에 `paths` 필터를 달지 검토. 지금은 `push: main`에 필터가 없어 `.claude/session.md`·
      `.mcp.json`만 바뀐 push에도 전체가 돈다. 비용은 읽기 전용 runner 몇 분이고, 필터를 달면 경로 목록이
      검사기의 대상 목록(`validate-doc-conventions.py`의 `docs/**`·`**/README.md`·`CLAUDE.md`,
      `validate-comment-conventions.py`의 `modules/**`·훅)과 어긋날 때 검사가 조용히 빠진다. 달려면
      job별 `paths`가 아니라 검사기 대상과 같은 한 목록으로 두고, `.claude/**`·`.mcp.json`만 빼는 형태가 후보다
- [ ] [local] 약 한 달 뒤 `~/archive/`(에이전트·스킬·hook·`.omc` 백업 3개) 삭제
