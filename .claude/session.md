# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 표의 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | hub·dev 전부 destroy. **public**, MIT. 시크릿 0개. 최상위 `README.md` 있음(라우터: 배포 루트 5개·state key·실행 모델·문서 라우팅표). `verify.yml`(시크릿·문서주석셸·OpenTofu 3 job)이 PR·push에서 돌고 ruleset `main`이 그것을 요구한다. environment `hub`·`dev`에 required reviewer `silverte`(self-review 허용)와 브랜치 정책 `main`. plan artifact 7일. 철거 상태 main push: `hub/tgw`만 plan 성공 → apply `waiting`(생성 plan 7건이라 **Reject**한다), 나머지 4개는 `RAM Resource Share`·`TGW`·`VPC` not found로 실패. 시스템 노드그룹 taint `CriticalAddonsOnly=true:NoSchedule`, 라벨 `workload-class=system`. 변수 34개 `nullable = false`. 루트마다 `backend.hcl.example`(로컬 전용 4키). **Dependabot PR 0건** — 모듈 4종이 `vpc-v0.5.0`·`eks-cluster-v0.11.0`·`workbench-v0.9.0`·`cross-account-trust-role-v0.4.0`, aws provider가 루트 5개 전부 `6.64.0`으로 수렴. 액션 6종이 커밋 SHA 핀(태그는 뒤 주석) |
| eks-platform-gitops | main = origin | dev cluster-secret 삭제 상태. **public**, MIT. seed는 1 helm install → 2 AppProject → 3 cluster Secret → 4 root Application(repository Secret 단계 없음, preflight가 `repoURL`을 익명 `ls-remote`). `verify.yml`(시크릿·주석셸·매니페스트 3 job: YAML 파싱·로컬 차트 2개 lint/template·`kyverno test`)과 ruleset. `tests/kyverno/require-karpenter-resources/` 픽스처 5건(pass 1·fail 3·skip 1). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. ApplicationSet `applicationsets/{baseline,catalog}/`(10파일), root App include 매칭 14개. multi-source `$values` 5개. Karpenter AMI 핀 `amiAliasByTier` 둘 다 `al2023@latest`. Kyverno는 `policies.kyverno.io/v1beta1 ValidatingPolicy`. 훅 정규식에 `tests/`·`.github/workflows/` 포함. ⛔ 액션 SHA 핀을 걸지 않았다(OIDC job 0) |
| aks-reference-infra | main = origin | **hub 구축 완료**(networking 27 + vwan 4 + aks 8 + workbench 14). dev는 철거 상태. workbench 공인 IP `20.196.104.126`(`Standard_B2s`), SSH CIDR `211.45.60.3/32`와 일치. 클러스터 `aks-demo-hub-krc-main-01` k8s 1.35 private, `networkPluginMode=overlay`·`podCidr 10.244.0.0/16`·`outboundType=userAssignedNATGateway`·`networkPolicy=cilium`. 시스템 풀 `Standard_D4s_v5` 2대(taint `CriticalAddonsOnly`) + NAP 노드 `Standard_D2als_v6` 1대(taint 없음). provider 7루트 전부 `azurerm 5.5.0`, **Dependabot PR 0건**. 모듈 태그 `aks-cluster-v0.10.0`·`aks-workbench-v0.7.0`·`vnet-v0.2.0`. **public**, MIT. 변수 48건 `nullable = false`. FIC subject는 repo ID에 묶여 있다. 액션 5종이 커밋 SHA 핀. 철거 상태 main push: `dev/networking`만 plan 성공(24 to add → **Reject**), `dev/aks`·`dev/workbench`는 VNet·서브넷 not found로 실패, hub 4개는 `plan=success, apply=skipped` |
| aks-platform-gitops | main = origin | **hub seed 완료.** Application 7개 전부 `Synced/Healthy`. dev 스포크는 철거 상태. **public**, MIT. `bootstrap/argocd-values.yaml`의 client ID는 `ec70a09c-8160-4ba6-8a25-2905d55b9376`. ApplicationSet **5파일 = ApplicationSet 7개**, root App include 매칭 **11개**. ⛔ **초기 admin 비밀번호를 교체하지 않았다** — `argocd-initial-admin-secret`이 남아 있다. `require-nodepool-resources`의 `namespaceSelector`는 **2조건**(`control-plane` 없음 + 이름이 `argocd` 아님, `f798dad`) |

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
`skipped`로 끝나 승인 게이트가 서지 않는다.** `action=plan`은 확인 전용 경로다. `push`는
`inputs.action`이 비어 있어 조건을 그대로 통과한다. ⚠️ **로컬 `tofu plan`은 `require_oidc`/`ci_run`
가드가 막는다.** ⚠️ **승인 대기 중인 run은 `gh run view --log`로 plan을 못 읽는다**(`still in
progress`). 웹 Summary 탭이거나, `gh run download <id> -n tfplan-<id>` 후 `tofu init -backend=false`
+ `tofu show`다. 게이트 거절은
`gh api -X POST .../actions/runs/<id>/pending_deployments -f state=rejected -F "environment_ids[]=<id>"`이고,
응답 파싱에서 `--jq`가 죽어도 거절 자체는 성공한다(run이 `completed/failure`가 되는 것으로 확인한다).

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

## 지난 세션 (2026-09-18 저녁)

**할 일 32개를 현재 상태에 대고 다시 판정하고, 지금 가능한 것부터 진행했다.** 소절 제목("AKS
spoke 구축·철거와 같이")이 항목을 실제보다 좁게 가두고 있었다. 「구축 후」 항목 대부분이 요구하는
전제는 spoke가 아니라 **살아 있는 클러스터 하나**여서 hub로 충족됐다.

**Kyverno를 hub 클러스터에서 검증하고 정책을 줄였다**(`aks-gitops` `f798dad`). 업스트림 PSS 11개가
`Audit`+`Ignore`, 커스텀 1개가 `Deny`(기록의 "2개"는 틀렸다), autogen은 `defaults`+`cronjobs` 두
갈래로 CEL 경로를 재작성하고 selector도 승계했다. 관리형 ns 2개(`kube-system`·`aks-istio-system`)가
`control-plane`과 `managedby`를 **둘 다** 갖는 것을 확인해 `managedby` 조건과 픽스처를 걷었다.
AKS FAQ가 `control-plane`만을 마커로 지목하고 우리 첫 조건과 같은 예시를 싣는다. `--dry-run=server`로
거부·제외 6건을 반영 전후로 대조했고 결과가 동일했다. 웹훅 실물에서 Kyverno가 기본 제외
(`kube-system`·`kyverno`)를 더해 붙이는 것도 찾았다 — 오프라인 `kyverno test`가 흉내 내지 않는 부분이다.

**액션을 커밋 SHA로 고정하고 Dependabot을 붙였다**(`eks-ref` `cdb8010`·`aks-ref` `226e974`).
`tj-actions/changed-files` 침해(CVE-2025-30066)에서 공격자가 기존 버전 태그를 악성 커밋으로 되돌려
붙였고 SHA 고정 저장소만 무사했다. 배포 루트 2곳만 대상으로 했다(OIDC job이 eks 10·aks 14, 나머지
3개 저장소는 0). `github-actions` 생태계를 같이 넣었고, 곧바로 갱신 PR 3건이 열려 SHA와 주석 버전을
함께 바꾸는 것까지 확인했다(`5838de8`·`1415b86`·`addf515`).

**`changes` 가드가 반대로 동작하던 결함을 찾아 고쳤다**(`d99be78`·`8a7951d`). 액션 핀 머지가
`deploy-*.yml`을 건드려 12개 루트를 한꺼번에 깨웠고, "변경 있음"과 "변경 없음"이 같은 묶음에 나란히
나오면서 양쪽 다 `skipped`인 것이 보였다. 원인은 `tofu_wrapper`였다. 수정 뒤 `dev/networking`
(24 to add)이 게이트를 세우고 hub 4개는 `skipped`를 유지하는 것으로 검증했다.

**EKS Dependabot 12건을 짝 단위로 전부 머지했다**(`190b0d8`~`12728a1`). 모듈 4건이 전부 같은 변경
(`nullable = false` 변수 계약)이라 plan을 읽는 대신 "소비자가 명시적 `null`을 넘기는가"를 코드에서
직접 확인했다(0건). Dependabot이 디렉토리마다 PR을 여는 탓에 짝 중 하나만 머지하면 드리프트가
생기는 것을 발견해, 미뤄 두었던 드리프트 보고기를 같이 만들었다(`180614c`·`4716df3`). 검사기가 아니라
보고기라 종료 코드가 항상 0이다.

**stop-slop 잔여 범위는 실질적으로 비어 있었다.** `.tf` 129개와 `docs/*.md` 21개를 4회 스윕하고
문체 커밋이 0건인 `aks-ref`의 `.tf`를 표본으로 읽었는데, 히트 대부분이 의미를 지고 있었고 수사적
밑밥은 0건이었다. 규칙에 맞는 문장을 다시 쓰지 않았다.

## 다음 할 일

재구축을 전제하는 항목이 많아 **인프라 순서**로 묶었다. AKS hub가 서 있고 dev(spoke)가 다음이다.
1·2절은 그 작업과 **같이** 해야 하는 것, 3절은 클러스터와 무관해 아무 때나 되는 것, 4절은 트리거가
와야 열리는 것이다.

### 1. AKS spoke 구축·철거와 같이 (다음 세션)

**구축 전**

- [ ] [aks-gitops] hub ArgoCD 초기 비밀번호를 교체하고 `argocd-initial-admin-secret`을 지운다.
      `hub-lifecycle.md`의 **완료 조건**인데 두 세션째 건너뛰었다. 대화형 프롬프트가 필요해
      사람이 workbench에서 한다(`runbooks.md` 「ArgoCD 관리자 비밀번호 교체」). ⚠️ `--core`로는
      안 된다(세션 토큰이 없다), `--port-forward`를 쓴다

**구축 중 — 이번 재구축에서만 답이 나오는 실측**

- [ ] [aks-ref] 승인 흐름 중 **남은 두 가지**. ①(대기 중 새 push)은 끝났다. 남은 것:
      ② artifact 7일 안에 승인하지 않으면 apply가 어떻게 실패하는지(7일이 걸려 한 세션에 못 한다)
      ③ `gh run rerun --failed`가 승인된 plan을 그대로 쓰는지(**실패한 apply가 나와야** 확인된다)
- [ ] [aks-ref] **`vwan`·`aks` 병렬 apply를 실측한다**(hub 재구축 때). 두 root는 서로를 읽지도
      쓰지도 않아 의존이 없다(`docs/hub-lifecycle.md`). ① 동시 apply가 Azure의 VNet 쓰기
      직렬화에 걸려 `AnotherOperationInProgress`로 떨어지는지 ② 떨어지면 `gh run rerun --failed`로
      복구되는지. 순차는 약 44분, 병렬 임계 경로(networking → aks → workbench)는 약 19분이다.
      ⚠️ workbench는 `aks`만 기다리면 된다
- [ ] [aks-ref] dev 루트 3개를 순서대로 apply한다(`spoke-lifecycle.md`)
- [ ] [aks-ref] **dev 생성 후 `live/hub/vwan`을 한 번 더 apply한다.** `azurerm_resources` 태그
      조회가 그때 dev VNet을 발견해 스포크 연결을 채운다. hub는 spoke 없이 완결되게 지어져 있다
- [ ] [aks-gitops] cluster Secret 등록 — teardown이 라벨을 먼저 뗐다. AKS dev는 `environment`·
      `tier: nonprd`·`addon-karpenter`. `tier`는 staged addon(Kyverno) 선택에도 쓰인다

**구축 후 — 클러스터가 살아 있을 때만 확인 가능**

- [ ] [aks-gitops] dev(nonprd)의 Kyverno는 **hub와 차이만 본다.** hub(prd)에서 정책 형태·autogen·
      관리형 ns 제외·admission 거동을 전부 확인했다. nonprd는 staged라 엔진·PSS 버전이 다를 수
      있으니 그 축만 대조한다
- [ ] [aks-gitops] nonprd 팬아웃 실측. 승격 절차 1회(Kyverno 릴리스나 차트 버전 올림으로)

### 2. EKS 구축·철거와 같이 (AKS 다음)

- [ ] [eks-ref] 승인 흐름은 AKS에서 답이 나온 것을 빼고 **차이만** 본다. eks 고유는 철거 상태에서
      `hub/tgw`만 plan이 성공한다는 점이다(생성 7건, 절차 밖이면 **Reject**)
- [ ] [eks-gitops] seed의 root Application 단계 직후 `argocd app manifests root-app --core`로 include
      확인 — 리소스 14개. ⚠️ **kubeconfig 컨텍스트의 네임스페이스가 `argocd`여야 한다**(아니면
      `configmap "argocd-cm" not found`로 죽는다). 임시 KUBECONFIG 사본에 `kubectl config set-context
      --current --namespace=argocd`를 걸어 영구 변경 없이 돌린다
- [ ] [eks-gitops] cluster Secret 등록. EKS dev는 `environment`·`tier: nonprd`·`vpcName`·
      `karpenterNodeRole`. ⚠️ `karpenterNodeRole`은 26자 hash 접미가 붙어 **재구축마다 바뀐다**
- [ ] [eks-ref·eks-gitops] **taint 키 교체를 검증한다.** coredns·metrics-server·ebs-csi·Karpenter의
      기본값 toleration, coredns `control-plane`·ebs-csi `NoExecute/300s` 복원, cert-manager 3개
      시스템 노드, Karpenter 부트스트랩, ALBC·Kyverno·ArgoCD는 Pending만 아니면 통과.
      ⚠️ AKS에서는 시스템 노드에 관리형 addon(App Routing istiod·gateway)도 올라왔다. EKS는
      관리형 addon 구성이 달라 실제 입주자 명단을 따로 찍는다
- [ ] [eks-gitops] multi-source 5개 addon이 `$values/addons/<addon>/values.yaml`을 읽는지, AppProject
      `sourceRepos`를 통과하는지
- [ ] [eks-gitops] **Karpenter AMI를 prd에 핀한다.** `kubectl get nodeclaim -o wide`로 실제 뜬 노드의
      값. 형식 `al2023@v<YYYYMMDD>`. nonprd는 다음 AMI를 먼저 받는 자리
- [ ] [eks-gitops] Kyverno CEL 클러스터 검증. AKS hub에서 확인한 목록을 그대로 쓰되 관리형 ns
      항목은 뺀다(EKS에는 `control-plane` 라벨 ns가 다르다)

### 3. 재구축과 무관 — 아무 때나

- [ ] [module] `modules/aws/eks-cluster/examples/enterprise/README.md`의 "확인하는 것이 좋다"를
      단정으로 고친다. stop-slop 스윕에서 찾은 유일한 실제 완충 표현인데 그 항목의 범위
      (`.tf` 주석·`docs/*.md`) 밖이라 손대지 않았다
- [ ] [local] context7 rate limit 시 키를 로컬 설정 `Authorization: Bearer`로. 약 한 달 뒤
      `~/archive/` 삭제

### 4. 조건이 오면 (지금 하지 않는다)

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
