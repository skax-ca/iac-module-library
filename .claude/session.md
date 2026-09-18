# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 표의 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | hub·dev 전부 destroy. **public**, MIT. 시크릿 0개. 최상위 `README.md` 있음(라우터: 배포 루트 5개·state key·실행 모델·문서 라우팅표). `verify.yml`(시크릿·문서주석셸·OpenTofu 3 job)이 PR·push에서 돌고 ruleset `main`이 그것을 요구한다. environment `hub`·`dev`에 required reviewer `silverte`(self-review 허용)와 브랜치 정책 `main`. apply job은 `if: github.ref == main`이라 push든 dispatch든 plan 뒤 승인 대기. plan artifact 7일. 철거 상태 main push: `hub/tgw`만 plan 성공 → apply `waiting`(생성 plan이라 **Reject**한다), 나머지 4개는 `RAM Resource Share`·`TGW`·`VPC` not found로 실패 → apply skipped. 시스템 노드그룹 taint `CriticalAddonsOnly=true:NoSchedule`, 라벨 `workload-class=system`. 변수 34개 `nullable = false`. **Dependabot(`opentofu`, 루트 5개) 있음 → PR 12건 열려 있다** |
| eks-platform-gitops | main = origin | dev cluster-secret 삭제 상태. **public**, MIT. seed는 1 helm install → 2 AppProject → 3 cluster Secret → 4 root Application(repository Secret 단계 없음, preflight가 `repoURL`을 익명 `ls-remote`). `verify.yml`(시크릿·주석셸·매니페스트 3 job: YAML 파싱·로컬 차트 2개 lint/template·`kyverno test`)과 ruleset. `tests/kyverno/require-karpenter-resources/` 픽스처 5건(pass 1·fail 3·skip 1). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. ApplicationSet `applicationsets/{baseline,catalog}/`(10파일), root App include 매칭 14개. multi-source `$values` 5개. Karpenter AMI 핀 `amiAliasByTier` 둘 다 `al2023@latest`. Kyverno는 `policies.kyverno.io/v1beta1 ValidatingPolicy`. 훅 정규식에 `tests/`·`.github/workflows/` 포함 |
| aks-reference-infra | main = origin | 전부 철거 상태. **public**, MIT. 시크릿 0개. 최상위 `README.md` 있음(eks와 같은 골격, 배포 루트 7개). `verify.yml`·ruleset·environment reviewers·apply 조건·artifact 7일은 eks와 같다. 철거 상태 main push: `hub/networking`·`dev/networking` plan 성공 → apply `waiting`(**Reject**), `live/*/aks`·workbench·vwan은 Subnet·VNet not found로 실패. 시스템 풀 `Standard_D4s_v5` 2대 `only_critical_addons_enabled = true`(모듈 태그 `aks-cluster-v0.10.0`). 변수 48건 `nullable = false`. FIC subject는 `repo:<org>@<org_id>/<repo>@<repo_id>:…`로 repo ID에 묶여 있다(저장소를 지우고 다시 만들면 깨진다). **Dependabot(루트 7개) 있음 → PR 9건 열려 있다** |
| aks-platform-gitops | main = origin | dev 스포크 철거 2단계 완료. **public**, MIT. seed 1~4단계·preflight 익명 조회·`verify.yml`(로컬 차트 없어 렌더 단계 없음)·ruleset은 eks와 같다. `tests/kyverno/require-nodepool-resources/` 픽스처 7건(제외 3: argocd ns·`control-plane` 라벨·`managedby=aks`가 각각 `Excluded`). ArgoCD는 `global.tolerations`로 `CriticalAddonsOnly`를 견딘다. ApplicationSet 5파일, root App include 매칭 9개. ⚠️ `bootstrap/argocd-values.yaml:44,51`의 workload identity client ID는 `live/hub/vwan`이 만드는 UAMI 값이 **고정**돼 있어 hub 재구축 때 손으로 바꿔야 federate된다 |

⚠️ 로컬 전제: 훅이 `shellcheck`·`gitleaks`를 **하드 요구**한다(없으면 즉시 실패). clone마다
`git config core.hooksPath .githooks`와 `brew install shellcheck gitleaks`가 필요하다. 이 Mac에는
shellcheck 0.11.0·gitleaks 8.30.1이 있고 CI가 같은 버전을 릴리스 바이너리로 핀한다(apt shellcheck는
구버전이라 `A && B || true`의 SC2015 판정이 갈린다). `timeout`은 이 Mac에 없다. `kubeconform` 0.8.0(훅에
넣지 않는다). `helm` 3.18.4로 업스트림 차트를 로컬 렌더할 수 있다(OCI는
`oci://public.ecr.aws/karpenter/karpenter`). ALBC 차트는 렌더마다 TLS 4줄이 다르다. `kyverno` CLI
1.19.1 — `kyverno test <dir>`가 `ValidatingPolicy`를 판정한다(음성 대조 실패·ns 제외 `Excluded`).
namespaceSelector는 Values 파일(`apiVersion: cli.kyverno.io/v1alpha1`, `namespaceSelector` 최상위 키)로
준다. `terraform-docs` v0.24.0. gitleaks 규칙 주의: AWS 키는 `AKIA`+base32 16자여야 잡히고
`AKIAIOSFODNN7EXAMPLE`은 allowlist다. `gitleaks git --pre-commit --staged` 조합은 exit 126, `--staged`만 쓴다.

5개 저장소 CI 모양: 모듈은 `verify.yml`(OpenTofu 7게이트, push는 허용 목록 `paths`)·`verify-docs.yml`(검사기 3,
`paths-ignore`는 `.claude/**`·`.mcp.json` 둘)·`secrets.yml`(gitleaks 전체 이력, 필터 없음). 배포 루트·GitOps는
`verify.yml` 하나(job 3개, 필터 없음). 전부 `pull_request` 트리거가 있고 PR에는 경로 필터가 없어 required
check가 pending에 갇히지 않는다. ruleset `main`(5개 동일): 삭제·force-push 금지, PR 필수(승인 0),
required status check, bypass = repository admin(`always`) — 용도는 문서 직접 커밋 하나. 배포 루트의
`deploy-*.yml`은 `push: main` + `paths: live/<root>/**`라 PR에서는 안 돌고, 머지 뒤 그 루트를 건드린 push만
plan을 띄운다. ⚠️ `gh run list --commit`은 40자 SHA만 받는다. fork PR 승인 정책은 3개 저장소
`all_external_contributors`(GitOps 둘은 `.github`가 없어 해당 없음).

태그 ruleset `release-tags`는 이 저장소만 갖는다(태그를 컷하는 곳이 여기뿐이다): `refs/tags/*-v*`의
삭제·갱신·force push를 막고 생성만 연다. ⛔ **bypass가 없어 admin도 막힌다.** 예외 절차(일시 해제 →
정리 → 재적용)와 함정은 `docs/conventions.md` 「릴리스된 태그를 옮기지 않는다」가 갖는다. ⚠️ rulesets
엔드포인트는 `PATCH`가 404이고 전체 본문 `PUT`만 받는다. ⚠️ push 거부와 네트워크 단절이 같은 모양으로
보인다 — 판정은 `git ls-remote`로 서버 실물을 다시 읽는다(`remote rejected` = 거부, `Bypassed rule
violations` = 규칙에 걸렸지만 통과).

주석 규칙 검사기는 5개 저장소 전부 `scripts/validate-comment-conventions.py` 한 이름이고 인자 없이 돌리면
저장소 전체를 본다(모듈 28·eks-ref 45·aks-ref 59). 규칙 SSOT는 `docs/conventions.md` 「주석」. 이모지 허용
범위가 면마다 다르다(`docs/*.md` 7종, `.tf`는 ⚠️·⛔ 두 종, GitOps 매니페스트는 관행 7종). ⚠️ 훅 정규식과
검사기 글롭이 경로를 하드코딩한다 — 새 최상위 디렉토리나 새 파일은 **세 곳**(훅 정규식·검사기 글롭·검사기
헤더 주석)을 같이 고쳐야 게이트에 잡힌다(배포 루트 둘은 `.github/dependabot.yml`을 그렇게 넣었다). 참조는
파일 단위다. 다른 파일의 단계 번호·절 번호에 기대는 서술은 규칙 위반이고 seed 단계는 이름으로 가리킨다.

## 지난 세션 (2026-09-18)

**public 전환 뒤 밖에서 보이는 면을 정리했다.** ① `presentations/`를 `.local/`로 되돌리고 남은 참조
4곳(`build-deck-pptx.py`·`.gitignore`·`verify-docs.yml`·`conventions.md`)을 걷었다(`ac73db4`, PR #61).
② 5개 저장소 repo 설명을 한 틀로 통일하고 토픽을 달았다(GitHub 메타데이터, `eks-reference-infra`의
죽은 참조 `design/50 D-CONSUME`도 여기서 사라졌다). ③ README: 모듈 저장소는 존재 이유·오너·기여 경로를
올리고 스택을 provider 중립으로 고쳤다(`37b361c`·`1da3aac`, `aks-workbench` 누락·게이트 서술 오류·
`brew install` 누락을 실물 대조로 잡았다). 배포 루트 둘에는 최상위 README를 신설했다(`5c33e3e`·`8697a92`,
라우터 구조 — 절차·규칙·고유 판단은 기존 문서가 소유한다). stop-slop을 README 4곳에 돌렸다.
④ LICENSE MIT(저작권자 `skax-ca`)를 5개에 같은 내용으로 넣었다. GitHub이 5개 전부 `MIT`로 인식한다.

**모듈 소싱을 공식 문서와 대조해 평가하고 두 가지를 실행했다.** 형식(`//`subdir 위치·태그 핀·`depth=1`·
익명 HTTPS)은 공식 기준과 어긋나는 데가 없었다. 구조적 약점 둘을 메웠다. ① **태그 ruleset**
`release-tags`(bypass 없음). 「태그를 옮기지 않는다」가 문장뿐이었고 `depth=1`이 SHA 핀을 막아 불변성이
없었다(`0e4098b`). ② **Dependabot**을 배포 루트 둘에 넣었다(eks PR #50·#63, aks PR #56). 게이트 세 곳을
`.github/dependabot.yml`까지 넓혔다. 실측으로 확인한 것: 접두사 태그(`vpc-v0.4.0`)를 접두사를 벗겨
비교한다(Renovate `extractVersion` 불필요) · 모듈 PR은 `main.tf`의 `source` 한 줄만, provider PR은 그
루트의 `.terraform.lock.hcl`만 건드린다 · `open-pull-requests-limit`은 **디렉토리별**로 걸린다(10을 줬는데
12건이 떠서 5로 낮췄다). 첫 실행에서 모듈 4종이 전부 한 마이너씩 밀려 있었고 `live/hub/tgw`의 aws
provider가 다른 루트와 갈려 있었다(6.61.0 vs 6.57.1).

**브랜치를 전부 정리했다.** 로컬 13개·원격 7개를 지워 5개 저장소 모두 `main` 하나만 남았다. 판정은
3단계였다: `rev-list --count` → `git cherry`(`-`면 동등 패치가 main에 있다) → `diff --stat main...브랜치`로
파일 경로 대조. 3단계가 필요한 것이 2개였고 둘 다 **파일이 옮겨진 뒤 버려진 브랜치**였다
(`feat/addons-baseline-albc-karpenter` `858c274`: `addons/baseline/` → main의 `applicationsets/baseline/`,
Karpenter 1.14.0 < main 1.14.1 / `feat/destroy-workflow` `cd26444`: 통합 워크플로 2개 → main의 루트별 5개,
destroy 경로가 5개 전부에 있다). `git cherry`는 이 경우 `+`를 내므로 살아 있는 작업으로 오판한다.

## 다음 할 일
- [ ] [eks-ref·aks-ref] **재구축 때 승인 흐름을 실측한다.** push → plan → apply `waiting` → Summary 읽고
      Review deployments 승인 → 같은 run이 apply. 확인할 것: ① 승인 대기 중 같은 루트에 새 push가 오면
      대기 run이 취소되는지(공식 문서가 답하지 않는다. 취소되면 헤더에 적는다) ② artifact 7일 안에
      승인하지 않으면 apply가 어떻게 실패하는지 ③ `gh run rerun --failed`가 승인된 plan을 그대로 쓰는지.
      ⚠️ 철거 상태에서 plan이 성공하는 루트(eks `hub/tgw`, aks `hub/networking`·`dev/networking`)는 apply가
      대기로 남는다. 재구축 절차 밖이면 **Reject**한다(승인하면 만든다)
- [ ] [eks-ref·aks-ref] **Dependabot PR 21건(eks 12 · aks 9)은 재구축 때 plan을 보며 올린다.** 지금
      머지하지 않는다 — 철거 상태라 검증할 대상이 없고 모듈이 전부 `0.y.z`라 마이너에 파괴적 변경이
      들어 있을 수 있다. ⚠️ 재구축이 몇 주 더 미뤄지면 주기를 `monthly`로 내린다(열린 PR이 배경 소음이
      되면 알림의 값이 사라진다). provider PR은 루트별로 뜨므로 재구축 후 소음을 겪어 보고 `groups`로
      묶을지 정한다. `github-actions` 생태계 추가도 그때 함께 본다
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
- [ ] [eks-ref·aks-ref] 루트 간 모듈 태그 드리프트를 `verify.yml` Summary에 출력만 하는 안(실패시키지 않는다).
      지금은 루트별 `ref` 값이 전부 일치해 보류했다. 승격을 스테이지드로 돌리기 시작하면 갈린 상태가
      의도인지 잊은 것인지 구분할 수단이 필요해진다
- [ ] [전체] **작업자가 2인 이상이 되면**: ruleset 5개 `required_approving_review_count` 0→1 +
      `require_last_push_approval`·`dismiss_stale_reviews_on_push`, 환경 4개에 두 번째 reviewer +
      `prevent_self_review: true`, 문서 직접 커밋 규칙과 admin bypass(`always`) 재검토. CODEOWNERS는 모듈
      담당이 갈릴 때만
- [ ] [local] org 멤버십 가시성은 그대로 두었다(공개 멤버 0, 멤버 2). 바꾸면 달라지는 것은 People 탭과
      개인 프로필 배지뿐이고 권한·CI·OIDC와는 무관하다. 본인 것은 각자만 바꿀 수 있다
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
- [ ] [module·eks-ref·aks-ref] stop-slop 잔여 범위: `.tf` 주석과 `docs/*.md`. README 4곳(모듈 루트·배포 루트
      둘의 `bootstrap/`·eks-gitops)은 이번에 돌렸다. ⛔ em-dash 제외. "A가 아니라 B다"·"의도적으로"·출처
      수동태는 유지
- [ ] [module] ⛔ **모듈 소싱 대안 3종은 기각했다. 다시 제안하기 전에 이 근거를 반박해야 한다.**
      ① 레지스트리 이전 — 공개/사설 레지스트리는 저장소 1개당 모듈 1개(`terraform-<provider>-<name>`)를
      요구해 저장소 7개 분할을 강제한다. 모노레포로 얻는 것(한 PR에서 여러 모듈 수정, 규약 문서와 코드의
      동거)을 잃는다. ② OCI(`oci://`, digest 고정) — 불변성이 가장 강하고 `//subdir`도 지원하지만 레지스트리
      운영·인증·게시 파이프라인이 새로 필요하다. 태그 ruleset이 같은 목적을 훨씬 싸게 달성한다. 팀이
      커지거나 외부 배포가 생기면 그때 다시 본다. ③ `depth=1` 제거 후 SHA 고정 — 불변성은 얻지만 어느
      버전인지 안 보이고 클론이 무거워진다. `examples/`의 상대 경로 유지는 `docs/decisions.md`에 기록했다
- [ ] [local] context7 rate limit 시 키를 로컬 설정 `Authorization: Bearer`로. 약 한 달 뒤 `~/archive/` 삭제
