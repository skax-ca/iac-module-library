# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 표의 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | hub·dev 전부 destroy. main push plan은 `hub/tgw`만 성공(정상. 나머지 4개는 `no matching RAM Resource Share found`로 실패하며, 철거 상태의 `data` 조회 실패라 코드 문제가 아니다). 변수 34개 전부 `nullable = false`. `scripts/argocd-seed.sh`는 없다(GitOps 저장소가 소유). pre-commit 셸 게이트가 `.githooks/pre-commit`·`pre-push` 자신까지 덮는다. `scripts/README.md`가 셸 게이트 상세를 소유한다 |
| eks-platform-gitops | main = origin | dev cluster-secret 삭제 상태(라벨 먼저 뗀 뒤 파일 삭제). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. ApplicationSet은 `applicationsets/{baseline,catalog}/`(10파일), `addons/<addon>/`은 values·로컬 차트·CR만. root App include는 `applicationsets/**/*.yaml` 등 5항목이고 매칭 14개. 업스트림 차트 values는 `addons/<addon>/values.yaml` 5개를 multi-source `$values`로 읽는다(인라인 `values: \|` 없음). 훅·검사기 경로 목록에 `applicationsets/` 포함. 위반 0건 |
| aks-reference-infra | main = origin | 전부 철거 상태. 원본 이식 항목 완료. 변수 48건 `nullable = false`. pre-commit 셸 게이트가 훅 파일 자신까지 덮는다. `bootstrap/config.sh`의 `GH_ORG_ID`·`GH_REPO_ID`는 대입과 `readonly`를 나눠 `gh api` 실패가 `set -e`에 잡힌다 |
| aks-platform-gitops | main = origin | dev 스포크 철거 2단계 완료(라벨 제거 → cluster-secret 삭제). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. ApplicationSet은 `applicationsets/{baseline,catalog}/`(5파일), `addons/<addon>/`은 평문 CR 디렉토리 3개만. root App include는 `applicationsets/**/*.yaml` 등 5항목이고 매칭 9개. 인라인 `values: \|`는 원래 없다(`parameters`만). 훅·검사기 경로 목록에 `applicationsets/` 포함. 위반 0건 |

⚠️ 로컬 전제: 훅이 `shellcheck`를 **하드 요구**한다(없으면 즉시 실패). clone마다
`git config core.hooksPath .githooks`와 `brew install shellcheck`가 필요하다. 이 Mac에는
0.11.0이 설치돼 있다. `timeout`은 이 Mac에 없다(coreutils 미설치). `kubeconform` 0.8.0이
설치돼 있다(개발 중 손으로 돌리는 스키마 검증, 훅에는 넣지 않는다). `helm` 3.18.4가 있어
`helm template --repo <url> <chart> --version <v>`로 업스트림 차트를 로컬 렌더할 수 있다
(OCI는 `oci://public.ecr.aws/karpenter/karpenter`). ALBC 차트는 렌더마다 자체 서명 TLS를 새로
만들어 `ca.crt`·`tls.*`·`caBundle` 4줄이 매번 다르다.

주석 규칙 검사기는 5개 저장소 전부 `scripts/validate-comment-conventions.py` 한 이름이고,
위반 메시지가 **외부 참조 / 이력 서술** 두 범주 중 어느 쪽인지를 앞에 붙인다. 규칙 SSOT는
이 저장소 `docs/conventions.md` 「주석」 절이다. ⚠️ gitops 두 저장소의 훅 정규식과 검사기
대상 목록은 **최상위 디렉토리 이름을 하드코딩**한다. 새 최상위 디렉토리를 만들면 둘 다 고쳐야
게이트에 잡힌다.

## 지난 세션 (2026-09-17)

전 세션의 ArgoCD 변경(include allow-list 전환)을 자기완결성·규칙 기준으로 검토하고, gitops
저장소 구조를 공식 문서(Best Practices·Cluster Bootstrapping·Directory/Helm source)와
커뮤니티 관례(Kostis의 3층 분리, GitOps Bridge의 `$values` 레이어링)에 대조했다. 세 단계로
적용했다.

③ 문서 결함 7건(eks `55a712f`·aks `d6000f8`): 삭제된 `choose-your-path.md` 참조 5건,
헤더 링크 16건을 `gitops-hub-spoke/aws/`·`gitops.md`로 좁힘, root-app·README에 세 번
중복된 deny-list 기각 근거를 `gitops.md` 한 곳으로, prune 주석의 정정 서술을 긍정문으로,
"root App이 이 파일을 읽을 일이 없다"의 지시 대상 오류, README의 존재하지 않는 "per-cluster
values" 메커니즘, aks README의 진행 상태 절 2개.

`gitops.md` 전면 재작성(`011c3aa`): 4절을 정의(정책 표+라벨 표) → 판정 → 형태 순으로 다시
짜고, 실측 사건 서술을 현재 사실로, `(4절)` 절 번호 인용 제거, deny-list 셀을 세 행으로.
절 제목 참조는 규칙상 허용이지만(번호만 금지, 검사기 메시지가 「절 제목」을 권한다) 밖에서
인용되는 4개만 남기고 새 참조는 넣지 않았다.

① helm values 파일 분리(eks `937d2e7`): 인라인 `values: |` 8블록 → `addons/<addon>/values.yaml`
5개, ApplicationSet은 multi-source `$values`. 팬아웃 시점 값(`{{name}}`·라벨)은 `parameters`에
남긴다. 검증은 HEAD 대조(15개 AppSet 구조 동치) + `helm template` 렌더 비교(5개 차트 동일).

② 디렉토리 분리(`d51e4f0`·eks `e7594da`·aks `d37a7e9`·aks-ref `a8db042`): ApplicationSet을
`applicationsets/{baseline,catalog}/`로 `git mv`, include는 `applicationsets/**/*.yaml` 한 항목,
훅·검사기 목록 갱신, 검사기 헤더의 옛 사실("`path: .`라 어디에 두든 흡수") 정정. 이름·selector·
`path`는 그대로라 계약 위반이 아니다. 마지막에 stop-slop을 돌려 수사적 밑밥·단문 마무리·정형구
반복 11곳을 고쳤다(`6e9fe92`·`fd0581d`).

## 다음 할 일
- [ ] [*-gitops] 재구축 seed 5단계 직후 `argocd app manifests root-app --core`로 include가 의도대로
      동작하는지 확인 — 리소스 수가 aks 9개·eks 14개여야 한다. 평문으로 바꾼 CR 디렉토리
      (aks 3개, eks `kyverno/custom-policies`)의 전담 Application이 Directory 타입으로 렌더되는지도 본다
- [ ] [eks-gitops] 재구축 후 multi-source 전환 5개 addon(ALBC·karpenter·kyverno·keda·cluster-autoscaler)이
      `$values/addons/<addon>/values.yaml`을 실제로 읽어 렌더되는지 `argocd app manifests <app> --core`로
      확인. ApplicationSet `sources:`가 AppProject `sourceRepos`(이 저장소 URL 포함)를 통과하는지도 본다
- [ ] [*-gitops] EKS·AKS 재구축 후 cluster Secret 등록 — ⚠️ teardown이 매칭 라벨을 **먼저 떼고**
      파일을 지웠다. git 이력에서 되살리면 라벨이 빠진 껍데기이고 그 상태로는 Application이 하나도
      안 생긴다. EKS dev는 `environment`·`tier: nonprd`·`vpcName`·`karpenterNodeRole`,
      AKS dev는 `environment`·`tier: nonprd`·`addon-karpenter`가 필요하다
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
- [ ] [module] 경로 필터 실측 — `gh run list`로 두 가지를 본다. `.claude/session.md`만 바뀐 push는
      run이 하나도 안 떠야 하고(이 항목을 쓴 커밋이 첫 표본이다), `docs/*.md`만 바뀐 push는
      `verify-docs`만 약 20초 돌고 `verify`는 안 떠야 한다. 어긋나면 `.github/workflows/`의 필터부터 본다
- [ ] [local] context7 MCP에 rate limit이 걸리면 context7.com/dashboard에서 키를 받아 로컬 설정에
      `Authorization: Bearer` 헤더로 얹는다(저장소에 넣지 않는다)
- [ ] [local] 약 한 달 뒤 `~/archive/`(에이전트·스킬·hook·`.omc` 백업 3개) 삭제
