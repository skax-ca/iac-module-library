# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 표의 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | hub·dev 전부 destroy. **public**. 시크릿 0개(`MODULE_READER_*` 삭제, App도 삭제). `verify.yml`(시크릿·문서주석셸·OpenTofu 3 job)이 PR·push에서 돌고 ruleset `main`이 그것을 요구한다. environment `hub`·`dev`에 required reviewer `silverte`(self-review 허용)와 브랜치 정책 `main`. apply job은 `if: github.ref == main`이라 push든 dispatch든 plan 뒤 승인 대기. plan artifact 7일. 철거 상태 main push: `hub/tgw`만 plan 성공 → apply `waiting`(생성 plan이라 **Reject**한다), 나머지 4개는 `RAM Resource Share`·`TGW`·`VPC` not found로 실패 → apply skipped. 시스템 노드그룹 taint `CriticalAddonsOnly=true:NoSchedule`, 라벨 `workload-class=system`. 변수 34개 `nullable = false`. `scripts/README.md`의 GitHub App·SSM 왕복 절은 삭제됨 |
| eks-platform-gitops | main = origin | dev cluster-secret 삭제 상태. **public**. seed는 1 helm install → 2 AppProject → 3 cluster Secret → 4 root Application(repository Secret 단계 없음, preflight가 `repoURL`을 익명 `ls-remote`). `verify.yml`(시크릿·주석셸·매니페스트 3 job: YAML 파싱·로컬 차트 2개 lint/template·`kyverno test`)과 ruleset. `tests/kyverno/require-karpenter-resources/` 픽스처 5건(pass 1·fail 3·skip 1). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. ApplicationSet `applicationsets/{baseline,catalog}/`(10파일), root App include 매칭 14개. multi-source `$values` 5개. Karpenter AMI 핀 `amiAliasByTier` 둘 다 `al2023@latest`. Kyverno는 `policies.kyverno.io/v1beta1 ValidatingPolicy`. 훅 정규식에 `tests/`·`.github/workflows/` 포함 |
| aks-reference-infra | main = origin | 전부 철거 상태. **public**. 시크릿 0개. `verify.yml`·ruleset·environment reviewers·apply 조건·artifact 7일은 eks와 같다. 철거 상태 main push: `hub/networking`·`dev/networking` plan 성공 → apply `waiting`(**Reject**), `live/*/aks`·workbench·vwan은 Subnet·VNet not found로 실패. 시스템 풀 `Standard_D4s_v5` 2대 `only_critical_addons_enabled = true`(모듈 태그 `aks-cluster-v0.10.0`). 변수 48건 `nullable = false`. FIC subject는 `repo:<org>@<org_id>/<repo>@<repo_id>:…`로 repo ID에 묶여 있다(저장소를 지우고 다시 만들면 깨진다). `bootstrap/README.md` 승인 방식 행은 required reviewers로 갱신됨 |
| aks-platform-gitops | main = origin | dev 스포크 철거 2단계 완료. **public**. seed 1~4단계·preflight 익명 조회·`verify.yml`(로컬 차트 없어 렌더 단계 없음)·ruleset은 eks와 같다. `tests/kyverno/require-nodepool-resources/` 픽스처 7건(제외 3: argocd ns·`control-plane` 라벨·`managedby=aks`가 각각 `Excluded`). ArgoCD는 `global.tolerations`로 `CriticalAddonsOnly`를 견딘다. ApplicationSet 5파일, root App include 매칭 9개. ⚠️ `bootstrap/argocd-values.yaml:44,51`의 workload identity client ID는 `live/hub/vwan`이 만드는 UAMI 값이 **고정**돼 있어 hub 재구축 때 손으로 바꿔야 federate된다 |

⚠️ 로컬 전제: 훅이 `shellcheck`·`gitleaks`를 **하드 요구**한다(없으면 즉시 실패). clone마다
`git config core.hooksPath .githooks`와 `brew install shellcheck gitleaks`가 필요하다. 이 Mac에는
shellcheck 0.11.0·gitleaks 8.30.1이 있고 CI가 같은 버전을 릴리스 바이너리로 핀한다(apt shellcheck는
구버전이라 `A && B || true`의 SC2015 판정이 갈린다). `timeout`은 이 Mac에 없다. `kubeconform` 0.8.0(훅에
넣지 않는다). `helm` 3.18.4로 업스트림 차트를 로컬 렌더할 수 있다(OCI는
`oci://public.ecr.aws/karpenter/karpenter`). ALBC 차트는 렌더마다 TLS 4줄이 다르다. `kyverno` CLI
1.19.1 — `kyverno test <dir>`가 `ValidatingPolicy`를 판정한다(실측: 음성 대조 실패·ns 제외 `Excluded`).
namespaceSelector는 Values 파일(`apiVersion: cli.kyverno.io/v1alpha1`, `namespaceSelector` 최상위 키)로
준다. `terraform-docs` v0.24.0. gitleaks 규칙 주의: AWS 키는 `AKIA`+base32 16자여야 잡히고
`AKIAIOSFODNN7EXAMPLE`은 allowlist다. `gitleaks git --pre-commit --staged` 조합은 exit 126, `--staged`만 쓴다.

5개 저장소 CI 모양: 모듈은 `verify.yml`(OpenTofu 7게이트, push는 허용 목록 `paths`)·`verify-docs.yml`(검사기 3,
`paths-ignore`)·`secrets.yml`(gitleaks 전체 이력, 필터 없음). 배포 루트·GitOps는 `verify.yml` 하나(job 3개, 필터
없음). 전부 `pull_request` 트리거가 있고 PR에는 경로 필터가 없어 required check가 pending에 갇히지 않는다.
ruleset `main`(5개 동일): 삭제·force-push 금지, PR 필수(승인 0), required status check, bypass = repository
admin(`always`) — 용도는 문서 직접 커밋 하나. 배포 루트의 `deploy-*.yml`은 `push: main` + `paths:
live/<root>/**`라 PR에서는 안 돌고, 머지 뒤 그 루트를 건드린 push만 plan을 띄운다. ⚠️ `gh run list --commit`은
40자 SHA만 받는다. fork PR 승인 정책은 3개 저장소 `all_external_contributors`(GitOps 둘은 `.github`가 없어 해당 없음).

주석 규칙 검사기는 5개 저장소 전부 `scripts/validate-comment-conventions.py` 한 이름이고 인자 없이 돌리면
저장소 전체를 본다. 규칙 SSOT는 `docs/conventions.md` 「주석」. 이모지 허용 범위가 면마다 다르다
(`docs/*.md` 7종, `.tf`는 ⚠️·⛔ 두 종, GitOps 매니페스트는 관행 7종). ⚠️ gitops 두 저장소의 훅 정규식은
최상위 디렉토리 이름을 하드코딩한다 — 새 최상위 디렉토리는 둘 다 고쳐야 게이트에 잡힌다. 참조는 파일
단위다. 다른 파일의 단계 번호·절 번호에 기대는 서술은 규칙 위반이고 seed 단계는 이름으로 가리킨다.

## 지난 세션 (2026-09-18)

**5개 저장소를 public으로 전환하고 그것으로 열린 것을 전부 켰다.** ① git 이력 전수 스캔(gitleaks 0건,
패턴 grep으로 계정 ID·구독 ID·공인 IP·client ID가 삭제된 notepad·cluster-secret 이력에 남음) → 전부 팀
테스트 값으로 수락, 이력 재작성·커밋 삭제는 기각(메모리 `public-repos-history-rewrite-rejected`). ② GitOps →
module → 배포 루트 순으로 전환, fork PR 승인 정책. ③-1 ArgoCD repository Secret 제거(seed 2단계 삭제, 단계
1~4 재번호, 다른 파일의 번호 참조를 이름으로, preflight 익명 `ls-remote`, eks `scripts/README.md` 148줄
삭제, 설계 문서 갱신) + GitHub App `skax-ca-gitops-reader` 삭제. MODULE_READER 제거(워크플로 12개, PR #46·#52,
변수·시크릿 삭제, App `skax-ca-module-reader` 삭제) → 배포 루트 시크릿 0개.

**CI 리서치 후 제안한 순서대로 4단계.** D1 environment required reviewers(4개 환경 설정, apply `if:` 되돌림,
retention 7일, 문서 4개 승인 문단·🔴 문단 재작성, PR #47·#53; 머지 push의 plan 성공 3건이 `waiting`으로
멈춘 것을 확인하고 Reject). D2 배포 루트 `verify.yml`(PR #48·#54, apt shellcheck 구버전 SC2015로 한 번
실패 → 0.11.0 핀). G1 GitOps `verify.yml` + `tests/kyverno/` 픽스처 eks 5·aks 7(PR #20·#1, `kyverno test`의
`ValidatingPolicy` 지원을 실측한 뒤 도입). C1 ruleset 5개(관리자 직접 push가 bypass로 통과함을 확인).
C2 gitleaks 훅 5개 + CI job 5개 + required check(PR #60·#49·#55·#21·#2). 규칙 SSOT(루트 `CLAUDE.md`
배포 루트 공통·GitOps 공통·브랜치 PR 규칙, `docs/conventions.md` 7절) 갱신.

**확인 안 된 주장은 뺐다.** "승인 대기 job이 concurrency group에서 취소된다"는 공식 문서에 없어 헤더에서
삭제했다(아래 재구축 실측 항목). gitleaks-action은 org에 라이선스 키를 요구해 바이너리를 직접 받는다.

## 다음 할 일
- [ ] [eks-ref·aks-ref] **재구축 때 승인 흐름을 실측한다.** push → plan → apply `waiting` → Summary 읽고
      Review deployments 승인 → 같은 run이 apply. 확인할 것: ① 승인 대기 중 같은 루트에 새 push가 오면
      대기 run이 취소되는지(공식 문서가 답하지 않는다. 취소되면 헤더에 적는다) ② artifact 7일 안에
      승인하지 않으면 apply가 어떻게 실패하는지 ③ `gh run rerun --failed`가 승인된 plan을 그대로 쓰는지.
      ⚠️ 철거 상태에서 plan이 성공하는 루트(eks `hub/tgw`, aks `hub/networking`·`dev/networking`)는 apply가
      대기로 남는다. 재구축 절차 밖이면 **Reject**한다(승인하면 만든다)
- [ ] [aks-gitops] **hub 재구축 때 `bootstrap/argocd-values.yaml:44,51`의 client ID를 새 UAMI 값으로 바꾼다.**
      `live/hub/vwan`이 만드는 UAMI의 client ID가 고정돼 있고 seed는 치환하지 않는다. 빠뜨리면 ArgoCD가
      federate되지 않는다. 값은 `az identity show`로 읽는다
- [ ] [*-gitops] **Kyverno CEL 전환을 재구축 후 클러스터에서 검증한다.** 오프라인 판정(`kyverno test`)은 CI에
      들어갔다. 클러스터에서 다른 것은 autogen(파드 컨트롤러 대응 규칙)과 기본 `resourceFilters`다.
      - 업스트림 PSS 11개가 `ValidatingPolicy`로 뜨고 `validationActions: [Audit]`·`failurePolicy: Ignore`인지
      - 커스텀 정책 2개(`Deny`)가 requests 없는 파드를 실제로 거부하는지
      - aks 관리형 ns 제외가 먹는지. 영구 OutOfSync가 없는지(`ServerSideDiff=true`에 기댄다)
- [ ] [aks-ref·aks-gitops] **시스템 풀 taint를 재구축 후 검증한다.** seed 순서(ArgoCD 시스템 풀 → NodePool CR →
      NAP 노드 → Kyverno), KEDA addon toleration(`kubectl -n kube-system get pod -o custom-columns=NAME:.metadata.name,TOLERATIONS:.spec.tolerations[*].key`),
      시스템 노드에 `kube-system`·`argocd`만 있는지
- [ ] [eks-ref·eks-gitops] **taint 키 교체를 재구축 후 검증한다.** coredns·metrics-server·ebs-csi·Karpenter의
      기본값 toleration(`kubectl -n kube-system get pod -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,TOLERATIONS:.spec.tolerations[*].key`),
      coredns `control-plane`·ebs-csi `NoExecute/300s` 복원, cert-manager 3개 시스템 노드, Karpenter 부트스트랩,
      ALBC·Kyverno·ArgoCD는 Pending만 아니면 통과
- [ ] [eks-gitops] **재구축 후 Karpenter AMI를 prd에 핀한다.** `kubectl get nodeclaim -o wide`로 실제 뜬 노드의
      값. 형식 `al2023@v<YYYYMMDD>`. nonprd는 다음 AMI를 먼저 받는 자리
- [ ] [*-gitops] seed의 root Application 단계 직후 `argocd app manifests root-app --core`로 include 확인 —
      리소스 aks 9개·eks 14개, 평문 CR 디렉토리의 전담 Application이 Directory 타입으로 렌더되는지
- [ ] [eks-gitops] 재구축 후 multi-source 5개 addon이 `$values/addons/<addon>/values.yaml`을 읽는지, AppProject
      `sourceRepos`를 통과하는지
- [ ] [*-gitops] 재구축 후 cluster Secret 등록 — teardown이 라벨을 먼저 뗐다. EKS dev는 `environment`·`tier:
      nonprd`·`vpcName`·`karpenterNodeRole`, AKS dev는 `environment`·`tier: nonprd`·`addon-karpenter`. `tier`는
      AMI 핀 선택에도 쓰인다
- [ ] [*-gitops] nonprd 팬아웃 실측. 승격 절차 1회(다음 Kyverno 릴리스나 AMI 핀으로)
- [ ] [aks-gitops] **관리형 네임스페이스 라벨을 찍고 `managedby` 조건을 판정한다.** `kubectl get ns --show-labels`.
      Azure 네임스페이스가 `control-plane` 하나로 전부 잡히면 `managedby` 조건과 그 주석·픽스처(`skip-managedby-aks`)를
      걷는다. ⛔ argocd 제외 조건은 판정 대상이 아니다. ⚠️ 조건을 지우면 사정권이 넓어진다
- [ ] [전체] **작업자가 2인 이상이 되면**: ruleset 5개 `required_approving_review_count` 0→1 +
      `require_last_push_approval`·`dismiss_stale_reviews_on_push`, 환경 4개에 두 번째 reviewer +
      `prevent_self_review: true`, 문서 직접 커밋 규칙과 admin bypass(`always`) 재검토. CODEOWNERS는 모듈
      담당이 갈릴 때만
- [ ] [module] 다음 `workbench`·`aks-workbench` **기능** 태그 메시지에 user-data 교체 경고를 싣는다(`6e34dec`는
      주석·문서 전용, 양쪽 태그보다 뒤). AWS `user_data_replace_on_change = true`, Azure `custom_data` ForceNew:

      ```
      ⚠️ 이 태그는 user-data 템플릿의 주석 변경을 포함한다. 소비 측 plan에
         인스턴스/VM 교체가 뜬다.
         AWS: aws_instance.user_data_replace_on_change = true
         Azure: azurerm_linux_virtual_machine.custom_data 가 ForceNew
         렌더링 내용은 같고 바뀐 것은 주석뿐이다. apply 전에 교체를 예상할 것.
      ```
- [ ] [module] `aks-cluster` 예시 SKU 변경(`4f4bb10`)은 다음 기능 릴리스에 싣는다
- [ ] [addon] 차트 전부 최신(kyverno 3.9.1 / argo-cd 10.9.1 / karpenter 1.14.1 / ALBC 3.5.0 / keda 2.20.2 /
      cluster-autoscaler 9.59.0 / Gateway API v1.6.2). 다음 올릴 때 다시 찍는다. ⛔ Kyverno 3.8 라인으로
      되돌리지 않는다(legacy 타입 v1.20 제거). `kyverno test` CLI 핀도 appVersion과 같이 올린다
- [ ] [aks-ref] azurerm `5.5.0` 검토 — AKS ForceNew 축(`network_profile`·`private_cluster_enabled`) 변경 여부 먼저.
      5개 루트 lock 함께
- [ ] [권고 미부합] AKS 시스템 풀 노드 수 3대(권고) vs 2대. 실 워크로드 때
- [ ] [module·eks-ref·aks-ref] stop-slop 패스. ⛔ em-dash 제외. "A가 아니라 B다"·"의도적으로"·출처 수동태는 유지
- [ ] [local] context7 rate limit 시 키를 로컬 설정 `Authorization: Bearer`로. 약 한 달 뒤 `~/archive/` 삭제
