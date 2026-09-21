# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 표의 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | **hub·dev 둘 다 철거 완료**(dev eks 87 → networking 69, hub eks 87 → networking 74 → tgw 7 순 destroy, 양 계정 `teardown-verify.sh` exit 0). bootstrap(state 버킷·OIDC·Role)은 남아 있다. ⚠️ 네 루트(`live/{hub,dev}/{eks,networking}`)의 `deletion_protection = false`가 `main`에 남아 있다 — 재구축이 끝나면 `true`로 되돌린다. **public**, MIT. 시크릿 0개. 최상위 `README.md` 있음(라우터: 배포 루트 5개·state key·실행 모델·문서 라우팅표). `verify.yml`(시크릿·문서주석셸·OpenTofu 3 job)이 PR·push에서 돌고 ruleset `main`이 그것을 요구한다. environment `hub`·`dev`에 required reviewer `silverte`(self-review 허용)와 브랜치 정책 `main`. plan artifact 7일. 철거 상태에서 main push는 `hub/tgw`만 plan이 성공한다(생성 7건이라 **Reject**). 나머지 4개는 `RAM Resource Share`·`TGW`·`VPC` not found로 실패한다. ⚠️ plan artifact 이름은 `eks` 루트만 `tfplan-eks-<run_id>`이고 나머지 4개는 `tfplan-<run_id>`다. 시스템 노드그룹 taint `CriticalAddonsOnly=true:NoSchedule`, 라벨 `workload-class=system`. 변수 34개 `nullable = false`. 루트마다 `backend.hcl.example`(로컬 전용 4키). **Dependabot PR 0건** — 모듈 4종이 `vpc-v0.5.0`·`eks-cluster-v0.11.0`·`workbench-v0.9.0`·`cross-account-trust-role-v0.4.0`, aws provider가 루트 5개 전부 `6.64.0`으로 수렴. 액션 6종이 커밋 SHA 핀(태그는 뒤 주석) |
| eks-platform-gitops | main = origin | **EKS 철거 상태.** `clusters/dev/`는 삭제했고(PR #24 라벨 제거 → #25 파일 삭제) `clusters/hub/`는 재구축용으로 남겼다. dev 재등록은 `4b4007a` 형태(`tier: nonprd`, `addon-cluster-autoscaler`·`addon-keda`, 고정 이름 `karpenterNodeRole`)를 따른다. ⚠️ root-app은 `prune: false`라 파일을 지워도 hub의 라이브 cluster Secret은 남는다. **public**, MIT. seed는 1 helm install → 2 AppProject → 3 cluster Secret → 4 root Application(repository Secret 단계 없음, preflight가 `repoURL`을 익명 `ls-remote`). `verify.yml`(시크릿·주석셸·매니페스트 3 job: YAML 파싱·로컬 차트 2개 lint/template·`kyverno test`)과 ruleset. `tests/kyverno/require-karpenter-resources/` 픽스처 5건(pass 1·fail 3·skip 1). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. ApplicationSet `applicationsets/{baseline,catalog}/`(10파일), root App 렌더 리소스 19개(AppProject 1·Application 2·ApplicationSet 15·Secret 1, cluster Secret이 늘면 Secret도 는다). multi-source `$values` 5개. Karpenter AMI 핀 `amiAliasByTier`는 prd `al2023@v20260917`(PR #23 `c34d73d`, hub NodeClaim 실측), nonprd `al2023@latest`. Kyverno는 `policies.kyverno.io/v1beta1 ValidatingPolicy`. 훅 정규식에 `tests/`·`.github/workflows/` 포함. ⛔ 액션 SHA 핀을 걸지 않았다(OIDC job 0) |
| aks-reference-infra | main = origin | **hub·dev 둘 다 철거 완료**(dev workbench 15 → aks 6 → networking 24, hub workbench 14 → aks 8 → vwan 5 → networking 27 순 destroy, 양 구독 `teardown-verify.sh` "잔존물 없음"). state Storage Account(bootstrap)만 남아 있다. hub 구독 `57bb4b4a…`, dev 구독 `af8171fb…`(로컬 `az` 기본 구독은 dev). ⚠️ vWAN `prevent_destroy = false`와 VNet·AKS `deletion_protection = false`가 `main`에 남아 있다 — 재구축이 끝나면 `true`로 되돌린다. 재구축이 이어받는 값: k8s 1.35 private, `networkPluginMode=overlay`·`podCidr 10.244.0.0/16`·`outboundType=userAssignedNATGateway`·`networkPolicy=cilium`(dev는 hub 값 승계). provider 7루트 전부 `azurerm 5.5.0`, **Dependabot PR 0건**. 모듈 태그 `aks-cluster-v0.10.0`·`aks-workbench-v0.7.0`·`vnet-v0.2.0`. **public**, MIT. dev workbench `vm_size = Standard_B2s_v2` 오버라이드, SSH 키는 hub `workbench_ed25519`·dev `workbench_dev_ed25519`. ⚠️ workbench 최초 부팅의 apt lock 결함은 재구축 때 다시 나온다(`runbooks.md`에 수동 복구 절차). 철거 상태에서 main push는 루트 7개가 대상 없음으로 실패한다 |
| aks-platform-gitops | main = origin | **AKS 철거 상태.** `clusters/dev/`는 삭제했고(PR #6 라벨 제거 → #7 파일 삭제) `clusters/hub/`는 재구축용으로 남겼다. **public**, MIT. ⚠️ 재구축하면 hub ArgoCD 초기 admin 비밀번호를 다시 교체해야 하고(이번에 교체한 값은 클러스터와 함께 사라졌다), `bootstrap/argocd-values.yaml`과 cluster Secret의 client ID(`ec70a09c…`)는 새 UAMI 값으로 갱신한다. root-app은 `prune: false`라 파일을 지워도 라이브 cluster Secret은 남는다. ApplicationSet 5파일 = ApplicationSet 7개, root App include 매칭 11개. Kyverno 엔진 3.9.1(업스트림 PSS 11개 Audit + 커스텀 1개 Deny). `require-nodepool-resources`의 `namespaceSelector`는 2조건(`control-plane` 없음 + 이름이 `argocd` 아님, `f798dad`) |

⚠️ 로컬 전제: 훅이 `shellcheck`·`gitleaks`를 **하드 요구**한다(없으면 즉시 실패). clone마다
`git config core.hooksPath .githooks`와 `brew install shellcheck gitleaks`가 필요하다. 이 Mac에는
shellcheck 0.11.0·gitleaks 8.30.1이 있고 CI가 같은 버전을 릴리스 바이너리로 핀한다. `timeout`은 이
Mac에 없다. `kubeconform` 0.8.0(훅에 넣지 않는다). `helm` 3.18.4로 업스트림 차트를 로컬 렌더할 수
있다. ALBC 차트는 렌더마다 TLS 4줄이 다르다. `kyverno` CLI 1.19.1. namespaceSelector는 Values
파일(`apiVersion: cli.kyverno.io/v1alpha1`, `namespaceSelector` 최상위 키)로 준다.
`terraform-docs` v0.24.0. gitleaks 규칙 주의: AWS 키는 `AKIA`+base32 16자여야 잡히고
`AKIAIOSFODNN7EXAMPLE`은 allowlist다. `gitleaks git --pre-commit --staged` 조합은 exit 126, `--staged`만 쓴다.

5개 저장소 CI 모양: 모듈은 `verify.yml`(OpenTofu 7게이트, push는 허용 목록 `paths`)·`verify-docs.yml`(검사기 3,
`paths-ignore`는 `.claude/**`·`.mcp.json` 둘)·`secrets.yml`(gitleaks 전체 이력). 배포 루트·GitOps는
`verify.yml` 하나(job 3개, 필터 없음). 전부 `pull_request` 트리거가 있고 PR에는 경로 필터가 없다.
ruleset `main`(5개 동일): 삭제·force-push 금지, PR 필수(승인 0), required status check,
bypass = repository admin(`always`) — 용도는 문서 직접 커밋 하나. ⚠️ API는 이 bypass를
`RepositoryRole actor_id 5`로만 내보내고 역할 이름은 `Settings → Rules → main → Bypass list`에서만
읽힌다. 배포 루트의 `deploy-*.yml`은 `push: main` + `paths`인데 **그 paths에 워크플로 파일 자신이
들어 있다** — `.github/workflows/`를 건드리는 머지가 그 루트 전부를 깨운다. ⚠️ `gh run list --commit`은
40자 SHA만 받는다. fork PR 승인 정책은 3개 저장소 `all_external_contributors`.

배포 루트 `deploy-*.yml`의 apply 게이트는 조건 **3항**이다: `github.ref == main` ·
`needs.plan.outputs.changes == 'true'` · `inputs.action != 'plan'`. **변경 0건이면 apply job이
`skipped`로 끝나 승인 게이트가 서지 않는다.** `action=plan`은 확인 전용 경로이지만, apply가
`skipped`인 것만으로 "changes=false"를 증명하지는 않는다(action=plan 자체도 조건 3을 깨 skip을
강제한다) — `No changes` 여부는 plan job 로그를 직접 읽어야 확정된다. ⚠️ **로컬 `tofu plan`은
`require_oidc`/`ci_run` 가드가 막는다.** ⚠️ **승인 대기 중인 run은 `gh run view --log`로 plan을 못
읽는다**(`still in progress`). 웹 Summary 탭이거나, `gh run download <id> -n tfplan-<id>` 후
`tofu init -backend=false` + `tofu show -no-color`다(색상 코드가 있으면 `^Plan:` 같은 grep이
비어 있는 것처럼 보인다). 게이트 거절은
`gh api -X POST .../actions/runs/<id>/pending_deployments -f state=rejected -F "environment_ids[]=<id>"`이고,
응답 파싱에서 `--jq`가 죽어도 거절 자체는 성공한다(run이 `completed/failure`가 되는 것으로 확인한다).
승인은 같은 엔드포인트에 `state=approved`.

⚠️ **`setup-opentofu`는 `tofu_wrapper: false`가 필수다**(`aks-ref` `8a7951d`·`eks-ref` `d99be78`).
기본값 `true`는 `tofu` 호출을 래퍼로 감싸 `stdout`·`stderr`·`exitcode`를 스텝 출력으로 내보내는데,
그 과정에서 `-detailed-exitcode`의 `2`가 **스텝 종료 코드로 전달되지 않는다**. 그래서 `changes`
가드가 `Plan: 24 to add`에도 `changes=false`를 내보내 apply가 `skipped`로 끝났고, apply job의
`apply 후 수렴 검증`도 같은 원인으로 무엇을 보든 통과했다. 액션 문서가 직접 적는 증상이다
("Having trouble with exit codes or the output format? Try setting the `tofu_wrapper` setting to
`false`"). `verify.yml`은 처음부터 `false`라 증상이 없었다. ⛔ 새 워크플로에 setup 스텝을 추가할 때
이 값을 빠뜨리지 않는다.

⚠️ 동시성 그룹(`group: live-<env>-<root>`, `cancel-in-progress: false`)의 실제 거동은 **두 갈래**다.
승인 게이트에 선 `waiting` run은 새 push가 와도 **취소되지 않는다**(예고대로). 그런데 그 뒤 대기열의
`pending` run은 **새 run이 오면 취소된다** — GitHub이 그룹당 대기 슬롯을 하나만 두기 때문이고
`cancel-in-progress`와 무관하다. 승인을 미룬 채 push를 이어 가면 대기 run은 마지막 하나만 남는다.
`waiting` run을 거절하면 그룹이 풀려 대기 run이 곧바로 출발한다.

⚠️ `gh pr checks`/`gh run view`의 job `status`는 `conclusion`보다 늦게 갱신된다. 완료를 기다리는
루프는 `status != pending`이 아니라 **`conclusion`이 비어 있지 않은지**로 건다. run 수준 `conclusion`이
빈 문자열인 채로 먼저 나타나므로 `!= "null"` 비교도 통과해 버린다.

주석 규칙 검사기는 5개 저장소 전부 `scripts/validate-comment-conventions.py` 한 이름이고 인자 없이
돌리면 저장소 전체를 본다(모듈 28·eks-ref 46·aks-ref 60). 규칙 SSOT는 `docs/conventions.md` 「주석」.
이모지 허용 범위가 면마다 다르다. ⚠️ 훅 정규식과 검사기 글롭이 경로를 하드코딩하는데 `scripts/*.py`와
`^scripts/.*\.(sh|py)$`는 **이미 와일드카드라 새 스크립트는 자동으로 잡힌다**(새 최상위 디렉토리일
때만 세 곳을 같이 고친다). 참조는 파일 단위다. ⚠️ 문서 길이 한도 400줄은 검사기가 `wc -l`보다 1 크게
센다. `eks-ref`의 `hub-lifecycle.md`가 한도에 차 있다.

에이전트 스킬은 **클라우드 접두어로 가른다**: `aks-argocd-tunnel-{connect,disconnect}`(SSH,
로컬 `18080`) · `eks-argocd-tunnel-{connect,disconnect}`(SSM, 로컬 `8080`). ⚠️ 접두어 없이 같은 이름을
쓰면 `--add-dir`로 5개를 붙일 때 **먼저 등록된 쪽만 살아남는다**. hub AKS에 kubectl을 쓸 때는 터널
없이 `ssh -i ~/.ssh/workbench_ed25519 azureuser@<공인IP> 'kubectl ...'`이 가장 싸다.

⚠️ **비밀값을 워크벤치 등 원격 호스트에서 비대화형으로 다뤄야 할 때**: SSH 명령의 argv가 아니라
heredoc으로 stdin에 실어 보낸다(`ssh host bash -s <<'REMOTE' ... REMOTE`). `ps aux`는 argv를
비추지만 stdin 스크립트 본문은 비추지 않고, `bash -s`(비대화형)는 원격 `~/.bash_history`에도
안 남는다. 비밀번호에 `$` 같은 셸 특수문자가 있으면 **heredoc 구분자를 따옴표로 감싼다**
(`<<'REMOTE'`)—그래야 로컬 셸이 `$2`처럼 오해해 변수 치환을 시도하지 않는다.

## 지난 세션 (2026-09-21)

**AKS hub·dev를 전부 철거했다. 직전 세션(`2ea2a12`)의 EKS 철거와 합쳐 두 클라우드가 모두 철거된 상태다.** 순서는 dev 등록 해제 → dev destroy → hub 선처리 → hub destroy(workbench → aks → vwan → networking)이고, 승인 게이트 8번 모두 plan artifact로 추가·변경·교체 0건과 구축 때 수량 일치(15·6·24·14·8·5·27)를 확인한 뒤 승인했다. 0단계는 삭제 보호가 이미 `false`라 PR이 필요 없었다.

**dev 등록 해제**(aks-gitops PR #6 `e1b9a76`, #7 `130884f`): `environment`·`tier`·`addon-karpenter` 라벨만 먼저 뺐다. 🔴 `karpenter-nodepool`이 `kyverno`보다 먼저 prune돼 NAP 노드가 사라졌고, kyverno 파드와 Helm 삭제 훅 Job(`scale-to-zero`·`rm-webhooks`)이 시스템 노드의 `CriticalAddonsOnly` taint를 견디지 못해 `Pending`에 걸려 kyverno·kyverno-policies Application이 삭제를 못 끝냈다. dev 클러스터가 살아 있는 동안 hub에서 그 두 Application의 finalizer만 비웠다. root-app은 머지 뒤 5분이 지나도 옛 SHA라 hard refresh(`argocd.argoproj.io/refresh=hard`)로 반영시켰고, `prune: false`라 라이브 dev Secret은 직접 지웠다.

**hub 선처리**: ArgoCD 컨트롤러 `scale 0` → Gateway 삭제(관리형 Istio가 살아 있는 채) → NodePool·AKSNodeClass 삭제. LB Service·Azure LB·NAP 노드가 모두 정리된 것을 확인한 뒤 destroy했다. hub vwan destroy는 vHub 때문에 10분을 넘겼고 성공했다.

**「조건이 오면」 실측**: dev networking destroy 뒤 hub vwan `action=plan`이 `spoke["dev"]` 연결 1건의 destroy만 잡았다(그 밖 변경 0건, 코드 수정 불필요). `spoke-lifecycle.md` 13절 서술이 맞았다.

**문서 반영**(aks-ref `73e919a`, main 직접 커밋): `spoke-lifecycle.md` 10절에 kyverno 삭제 교착과 finalizer 정리, `prune=false`로 인한 라이브 Secret 직접 삭제, hard refresh를 넣고 13절에 plan 실측을 넣었다. 문서 길이 한도(400) 때문에 같은 절의 기존 문단 2개를 줄였다.

**하지 않은 것**: `rerun --failed` 실측(destroy 8건이 전부 한 번에 성공), 두 구독의 `action=plan` 재확인.

## 다음 할 일

EKS·AKS hub·dev 모두 철거된 상태다. 클라우드별 「구축·철거와 같이」 절은 다음 재구축·철거 일정이 정해질 때 다시 만든다. 지금 할 수 있는 것과 트리거가 와야 열리는 것만 남는다.

### 1. 재구축과 무관 — 아무 때나

없음. 지금 착수할 수 있는 항목은 남아 있지 않다.

### 2. 조건이 오면 (지금 하지 않는다)

- [ ] [eks-gitops] **eks hub를 다시 세울 때**: ALBC와 Gateway API CRD 경쟁이 재현되는지 본다. 잦으면 CRD를 ALBC보다 먼저 세우는 안(sync-wave 등)을 설계 문서부터 검토한다. 지금은 ALBC 재시작으로 푼다
- [ ] [eks-gitops] **새 AL2023 AMI가 나오면**: nonprd(dev)가 `latest`로 먼저 받는다. dev 노드가 정상으로 뜨는 것을 보고 같은 값을 prd(`amiAliasByTier`)에 올린다. ⚠️ 지금 dev에는 Karpenter 노드가 0이라 nonprd가 실제로 검증한 적이 없다 — 그때 dev에 워크로드를 올려 노드를 띄운 뒤 본다
- [ ] [eks-ref] **EKS를 다시 세울 때 네 루트의 `deletion_protection`을 `true`로 되돌린다**(`live/{hub,dev}/{eks,networking}` 4곳, 코드 주석이 요구). 재구축이 끝나기 전에는 `main`에 `false`가 남는 것이 의도다
- [ ] [eks-ref] **EKS 재구축에서 dev를 세운 뒤 hub networking을 재적용할 때**: 추가되는 dev 라우트가 5건인지 6건인지 센다. 철거 plan은 5건(TGW route 1 + VPC route 4)이었는데 지난 구축 기록은 6건이라 1건이 어디서 나왔는지 확인되지 않았다
- [ ] [eks-ref] **다음에 dev spoke를 철거할 때**: `spoke-lifecycle.md`에 적은 회피책(ALBC가 살아 있는 동안 spoke에서 `kubectl delete gateway --all -A`)이 SG 고아를 막는지 실측한다. hub에서는 이 순서로 고아 0이었지만 spoke에서는 검증하지 못했다
- [ ] [aks-ref] **AKS를 다시 세운 뒤 vWAN `prevent_destroy`와 VNet·AKS `deletion_protection`을 `true`로 되돌린다**(`live/hub/vwan` 리소스 2곳, `live/{hub,dev}/networking`·`live/{hub,dev}/aks`). 재구축이 끝나기 전에는 `main`에 `false`가 남는 것이 의도다
- [ ] [aks-gitops·aks-ref] **다음에 dev spoke를 철거할 때**: kyverno 삭제 교착(`spoke-lifecycle.md` 10절)을 피하는 순서를 정한다. NodePool Application이 kyverno보다 먼저 지워지는 것이 원인이라, 지우는 순서를 바꾸거나 kyverno에 시스템 노드 toleration을 주는 안을 설계 문서부터 검토한다
- [ ] [aks-ref·eks-ref] **다음 apply가 실패하면**: `gh run rerun --failed`가 승인된 plan을 그대로 쓰는지
      확인한다. AKS·EKS 모두 지금까지 apply와 destroy가 전부 성공해 기회가 없었다
- [ ] [aks-gitops·eks-gitops] **다음 차트 버전 업데이트가 생기면**: nonprd→prd 승격 절차를 실측한다. 지금은
      추적 중인 모든 addon이 이미 최신이라(kyverno 3.9.1 등) 올릴 대상이 없다
- [ ] [aks-ref] **hub를 다시 세울 때**: `vwan`·`aks` 병렬 apply를 실측한다. 두 root는
      서로를 읽지도 쓰지도 않아 의존이 없다(`docs/hub-lifecycle.md`). ① 동시 apply가 Azure의
      VNet 쓰기 직렬화에 걸려 `AnotherOperationInProgress`로 떨어지는지 ② 떨어지면
      `gh run rerun --failed`로 복구되는지. 순차는 약 44분, 병렬 임계 경로(networking → aks →
      workbench)는 약 19분이다. ⚠️ workbench는 `aks`만 기다리면 된다.
      hub가 철거된 지금은 재구축을 시작하면 바로 확인할 수 있다
- [ ] [aks-ref·eks-ref] **승인 게이트를 7일 넘게 방치하게 되면**: artifact 만료 뒤 apply가 어떻게
      실패하는지 본다. plan artifact 보존이 7일이라 한 세션에 답이 나오지 않는다. ⚠️ 일부러
      만들 일은 아니다 — 게이트는 뜬 세션에 처리하는 것이 규칙이고, 그 규칙을 어긴 run이
      생겼을 때 관찰만 한다
- [ ] [local] **context7이 rate limit에 걸리면**: 키를 로컬 설정 `Authorization: Bearer`로 넣는다
- [ ] [local] **약 한 달 뒤**: `~/archive/` 삭제
- [ ] [module] 다음 `workbench`·`aks-workbench` **기능** 태그를 컷할 때 태그 메시지에 user-data 교체
      경고를 싣는다. AWS `user_data_replace_on_change = true`, Azure `custom_data` ForceNew:

      ```
      ⚠️ 이 태그는 user-data 템플릿의 주석 변경을 포함한다. 소비 측 plan에
         인스턴스/VM 교체가 뜬다.
         AWS: aws_instance.user_data_replace_on_change = true
         Azure: azurerm_linux_virtual_machine.custom_data 가 ForceNew
         렌더링 내용은 같고 바뀐 것은 주석뿐이다. apply 전에 교체를 예상할 것.
      ```
- [ ] [module] `aks-cluster` 예시 SKU 변경(`4f4bb10`)은 다음 기능 릴리스에 싣는다
- [ ] [addon] 차트 버전을 올릴 때 다시 찍는다(지금 전부 최신: kyverno 3.9.1 / argo-cd 10.9.1 /
      karpenter 1.14.1 / ALBC 3.5.0 / keda 2.20.2 / cluster-autoscaler 9.59.0 / Gateway API v1.6.2).
      ⛔ Kyverno 3.8 라인으로 되돌리지 않는다(legacy 타입 v1.20 제거). `kyverno test` CLI 핀도
      appVersion과 같이 올린다. ⚠️ `argocd-seed.sh`의 `ARGOCD_CHART_VERSION`과 `argocd-app.yaml`의
      `targetRevision`은 **항상 같다**(지금 둘 다 `10.9.1`)
- [ ] [aks-ref] 실 워크로드를 올릴 때 AKS 시스템 풀 노드 수를 3대(권고)로 볼지 판단한다. 지금 2대는
      권고 미부합을 알고 수락한 값이다. ⚠️ 판단 입력이 예상보다 무겁다 — 시스템 노드 2대에
      `kube-system` 30 + `argocd` 5 + App Routing 관리형 4(`istiod` 2·`shared-gateway` 2)가 올라와
      있다. 그 4개는 Azure가 `CriticalAddonsOnly` toleration을 붙여 보내므로 우리가 배치를 통제하지
      않는다. App Routing의 Gateway API 구현이 `nodeSelector`·`tolerations`를 노출하는지는 확인 안 했다
      (NGINX 변형 문서의 `NginxIngressController` 필드 표에는 스케줄링 항목이 없다)
- [ ] [eks-ref·aks-ref] Dependabot에 `groups`로 provider PR을 묶을지는 재구축 후 소음을 실제로 겪어
      보고 정한다. ⚠️ `open-pull-requests-limit`은 디렉토리별이라 루트를 늘리면 전체 상한도 함께
      늘어난다. `github-actions` 생태계는 이미 넣었다(디렉토리 하나, 상한 eks 6·aks 5)
- [ ] [eks-gitops·aks-gitops·module] 액션 SHA 핀을 이 3곳으로 넓힐지. 지금 안 한 이유는 OIDC job이
      0이라 훔칠 토큰이 없어서다. 이 저장소들에 `id-token: write`가 생기면 그때 넓힌다
- [ ] [전체] **작업자가 2인 이상이 되면**: ruleset 5개 `required_approving_review_count` 0→1 +
      `require_last_push_approval`·`dismiss_stale_reviews_on_push`, 환경 4개에 두 번째 reviewer +
      `prevent_self_review: true`, 문서 직접 커밋 규칙과 admin bypass(`always`) 재검토. CODEOWNERS는
      모듈 담당이 갈릴 때만. ⚠️ **이미 push 권한자가 2명이다**(`rajaelime`이 팀 경유 `maintain`).
      트리거가 이미 당겨진 것으로 볼지 판단한다
- [ ] [local] org 멤버십 가시성은 그대로 두었다(공개 멤버 0, 멤버 2). 바꾸면 달라지는 것은 People
      탭과 개인 프로필 배지뿐이고 권한·CI·OIDC와는 무관하다
- [ ] [module] ⛔ **모듈 소싱 대안 3종은 기각했다. 다시 제안하기 전에 이 근거를 반박해야 한다.**
      ① 레지스트리 이전 — 저장소 1개당 모듈 1개를 요구해 저장소 7개 분할을 강제한다. 모노레포로
      얻는 것을 잃는다. ② OCI(`oci://`, digest 고정) — 불변성이 가장 강하지만 레지스트리 운영·인증·
      게시 파이프라인이 새로 필요하다. 태그 ruleset이 같은 목적을 훨씬 싸게 달성한다. ③ `depth=1`
      제거 후 SHA 고정 — 불변성은 얻지만 어느 버전인지 안 보이고 클론이 무거워진다
- [ ] [aks-ref·eks-ref] ⛔ **drift 전용 워크플로(`drift.yml`)는 기각했다.** 루트를 matrix로 돌리는
      안인데, EKS는 CI의 `backend.hcl`이 `assume_role` 블록을 갖고 로컬과 형태가 달라 **인증 배선의
      두 번째 사본**이 생긴다. `changes` 가드 + `action=plan`이 같은 목적을 중복 0으로 달성한다
