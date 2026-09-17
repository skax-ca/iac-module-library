# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 표의 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | hub·dev 전부 destroy. main push plan은 `hub/tgw`만 성공(정상. 나머지 4개는 `no matching RAM Resource Share found`로 실패하며, 철거 상태의 `data` 조회 실패라 코드 문제가 아니다). 변수 34개 전부 `nullable = false`. `scripts/argocd-seed.sh`는 없다(GitOps 저장소가 소유). pre-commit 셸 게이트가 `.githooks/pre-commit`·`pre-push` 자신까지 덮는다. `scripts/README.md`가 셸 게이트 상세를 소유한다 |
| eks-platform-gitops | main = origin | dev cluster-secret 삭제 상태(라벨 먼저 뗀 뒤 파일 삭제). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. ApplicationSet은 `applicationsets/{baseline,catalog}/`(10파일), `addons/<addon>/`은 values·로컬 차트·CR만. root App include는 `applicationsets/**/*.yaml` 등 5항목이고 매칭 14개. 업스트림 차트 values는 `addons/<addon>/values.yaml` 5개를 multi-source `$values`로 읽는다(인라인 `values: \|` 없음). 규약(팬아웃·finalizers·staged 전파·cluster Secret 라벨 계약)은 README가 소유하고 매니페스트 주석은 그 파일 고유 사실만 갖는다. Kyverno 정책은 `policies.kyverno.io/v1beta1 ValidatingPolicy`고 AppProject whitelist도 그 kind다(legacy `kyverno.io/ClusterPolicy`는 어디에도 없다). 훅·검사기 경로 목록에 `applicationsets/` 포함. 위반 0건 |
| aks-reference-infra | main = origin | 전부 철거 상태. 원본 이식 항목 완료. 변수 48건 `nullable = false`. pre-commit 셸 게이트가 훅 파일 자신까지 덮는다. `bootstrap/config.sh`의 `GH_ORG_ID`·`GH_REPO_ID`는 대입과 `readonly`를 나눠 `gh api` 실패가 `set -e`에 잡힌다 |
| aks-platform-gitops | main = origin | dev 스포크 철거 2단계 완료(라벨 제거 → cluster-secret 삭제). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. ApplicationSet은 `applicationsets/{baseline,catalog}/`(5파일), `addons/<addon>/`은 평문 CR 디렉토리 3개만. root App include는 `applicationsets/**/*.yaml` 등 5항목이고 매칭 9개. 인라인 `values: \|`는 원래 없다(`parameters`만). 규약은 README가 소유하고 매니페스트 주석에 AWS 대조 서술을 두지 않는다. Kyverno 정책은 `policies.kyverno.io/v1beta1 ValidatingPolicy`고 AppProject whitelist도 그 kind다. 커스텀 정책의 `matchConstraints.namespaceSelector`는 조건 셋을 AND로 건다(`control-plane` 부재 · `managedby != aks` · 이름 != argocd). 훅·검사기 경로 목록에 `applicationsets/` 포함. 위반 0건 |

⚠️ 로컬 전제: 훅이 `shellcheck`를 **하드 요구**한다(없으면 즉시 실패). clone마다
`git config core.hooksPath .githooks`와 `brew install shellcheck`가 필요하다. 이 Mac에는
0.11.0이 설치돼 있다. `timeout`은 이 Mac에 없다(coreutils 미설치). `kubeconform` 0.8.0이
설치돼 있다(개발 중 손으로 돌리는 스키마 검증, 훅에는 넣지 않는다). `helm` 3.18.4가 있어
`helm template --repo <url> <chart> --version <v>`로 업스트림 차트를 로컬 렌더할 수 있다
(OCI는 `oci://public.ecr.aws/karpenter/karpenter`). ALBC 차트는 렌더마다 자체 서명 TLS를 새로
만들어 `ca.crt`·`tls.*`·`caBundle` 4줄이 매번 다르다. `kyverno` CLI 1.19.1도 설치돼 있다 —
`kyverno apply <정책> --resource <파드들> [-f <Values>]`로 **클러스터 없이** 정책 판정을 본다.
차트 appVersion과 같은 버전을 쓴다. 네임스페이스 라벨이 필요한 selector는 `-f`에 넘기는 Values의
`namespaceSelector` 목록으로 준다(`apiVersion: cli.kyverno.io/v1alpha1`, 최상위 키다 — `spec:`
아래 넣으면 `unknown field "spec"`으로 죽는다). ⚠️ `--values-file /dev/null`은 deprecated 스키마로
오인돼 에러다. 값이 필요 없으면 옵션 자체를 뺀다.

이 저장소 CI는 워크플로 2개다. `verify.yml`이 OpenTofu 게이트 7개(허용 목록 `paths`),
`verify-docs.yml`이 파이썬 검사기 3개(제외 목록 `paths-ignore`)를 돈다. GitHub Actions에 job별 경로
필터가 없어 파일을 갈랐다. 실측: `.claude/session.md`만 바뀐 push는 run 0건, `docs/*.md`만 바뀐 push는
`verify-docs` 하나만 뜬다. ⚠️ `gh run list --commit`은 전체 40자 SHA만 받는다(짧은 SHA는 에러 없이
0건을 돌려줘 "안 떴다"와 구분되지 않는다).

주석 규칙 검사기는 5개 저장소 전부 `scripts/validate-comment-conventions.py` 한 이름이고,
위반 메시지가 **외부 참조 / 이력 서술** 두 범주 중 어느 쪽인지를 앞에 붙인다. 규칙 SSOT는
이 저장소 `docs/conventions.md` 「주석」 절이다. ⚠️ gitops 두 저장소의 훅 정규식과 검사기
대상 목록은 **최상위 디렉토리 이름을 하드코딩**한다. 새 최상위 디렉토리를 만들면 둘 다 고쳐야
게이트에 잡힌다.

## 지난 세션 (2026-09-17)

addon 차트를 전부 최신으로 올리고, Kyverno를 legacy 타입에서 CEL로 옮겼다. 그 과정에서 비어 있던
GitOps 저장소의 브랜치 규칙을 리서치해 신설했다.

차트 올림(eks `abc1c26`, aks `46bd967`): argo-cd 10.3.0 → 10.9.1(7곳), karpenter 1.14.0 → 1.14.1(3곳).
클러스터가 없어 `argocd app manifests` 대신 `helm template` diff로 봤다. 33,770줄 렌더에서 실질 변경은
넷뿐이었고(이미지 태그, `argocd-tls-certs-cm`에 `optional: true`, `dnsPolicy` 명시, checksum) values 키는
하나도 사라지지 않았다. argo-cd는 자기 관리라 `argocd-app.yaml`과 `argocd-seed.sh`의 핀을 한 커밋에
함께 옮겼다 — 갈리면 seed의 흡수가 업그레이드가 되고 sync 주체가 sync 도중 재시작한다. 철거 상태가
오히려 이 작업에 유리한 시점이다.

Kyverno CEL 전환(eks `35ec069`·`37ffdd6`, aks `8c42bf4`·`973b4e2`): 3.9.1이 rc를 뺀 최신이고 appVersion이
v1.19.1이다. legacy `kyverno.io` 타입은 v1.19 deprecated·**v1.20 제거**라 유예가 마이너 하나뿐이다.
철거 상태라 마이그레이션 경로를 만들지 않고 목표 상태로 바로 갔다. 전환 중 드러난 것 셋 —
`validationActions` enum에 `Enforce`가 없어 `Deny`로 간다, `excludeResourceRules`는 apiGroup·resource
단위라 네임스페이스를 못 빼서 `kubernetes.io/metadata.name`을 selector에 넣어야 한다, `has()` 가드 없이
`.all()`을 부르면 그 필드 없는 파드에서 CEL 런타임 에러가 나고 `failurePolicy: Fail`이 그것을 거부로
바꾼다(가드 뺀 프로브로 `error: 1` 확인). 커스텀 정책 2개는 자동 변환 도구가 없어 손으로 썼고,
`kyverno` CLI 1.19.1로 픽스처 12건을 돌려 legacy `pattern`과 판정이 같음을 확인했다(error 0).

GitOps 브랜치 규칙 신설(`e3ae48e`·`5e462b1`): 두 GitOps 저장소에 `CLAUDE.md`가 없고 루트 표도 `.tf`·
워크플로·문서만 다뤄 매니페스트가 규정 공백이었다. Argo CD 공식 문서·OpenGitOps·Argo 팀 멤버 글을
근거로 대조한 결과 구조(저장소 분리·브랜치로 환경을 나누지 않음)는 이미 권고를 충족했고, 빠진 것은
규정 자체였다. 판정 기준은 그대로 두고 결과만 적었다 — 두 repo에 CI가 없고 5개 저장소 전부
private·무료라 브랜치 보호도 못 걸어 PR이 막을 것이 없다. 대신 배포 루트와 갈리는 사실(push가 곧
apply다)과 진짜 게이트(렌더 확인)를 「GitOps 저장소 공통」 절로 못박았다.

주석 점검(`37ffdd6`·`973b4e2`·`5e462b1`): 새로 쓴 주석이 세 곳에서 **없어질 타입을 기준으로** 설명하고
있었다. 그 타입이 사라지면 서술도 함께 낡으므로, 외부 참조를 금지하는 것과 같은 이유로 걷어냈다.
`⚠️` 등급도 맞췄다 — 문법 설명에 붙어 있던 것을 떼고 진짜 조용한 실패(위 `has()` 건)로 옮겼다.

## 다음 할 일
- [ ] [*-gitops] **Kyverno CEL 전환을 재구축 후 클러스터에서 검증한다.** 매니페스트는 이미 새 타입이다
      (엔진·정책 차트 3.9.1, `policies.kyverno.io/v1beta1 ValidatingPolicy`). 남은 것은 실물 확인이다.
      - 업스트림 PSS 11개가 `ValidatingPolicy`로 뜨고 `validationActions: [Audit]`·`failurePolicy: Ignore`
        조합이 유지되는지
      - ⚠️ **커스텀 정책 2개가 진짜로 막는지** — eks `require-karpenter-resources`,
        aks `require-nodepool-resources`. 둘 다 `validationActions: [Deny]`라 실패 모드가 조용하다.
        requests 없는 파드로 실제 거부를, 완전한 파드로 통과를 본다.
        `kyverno apply`로 오프라인 검증은 끝냈다(픽스처 12건, error 0) — 클러스터에서 다른 것은
        autogen(파드 컨트롤러 대응 규칙을 Kyverno가 서버에서 만든다)과 기본 `resourceFilters`다
      - aks 관리형 ns 제외가 먹는지. `namespaceSelector` 3조건 AND(`control-plane` 부재 ·
        `managedby != aks` · 이름 != argocd). ⚠️ `kubernetes.io/metadata.name`으로 argocd를 빼는 것이
        legacy의 `exclude` 블록을 대신한다 — `excludeResourceRules`는 group/resource 단위라 ns를 못 뺀다
      - 영구 OutOfSync가 없는지. `spec.evaluation.{admission,background}.enabled`를 apiserver가
        채우므로 `ServerSideDiff=true`에 기대고 있다
- [ ] [addon] **남은 차트는 전부 최신이다.** 아래는 실측값이고, 다음에 올릴 때 이 표를 다시 찍는다.

      | addon | 저장소 | 핀 | 비고 |
      |---|---|---|---|
      | `kyverno`·`kyverno-policies` | eks·aks | 3.9.1 | appVersion v1.19.1 |
      | `argo-cd` | eks·aks | 10.9.1 | appVersion v3.5.3 |
      | `karpenter` | eks | 1.14.1 | OCI 태그 = chart = appVersion |
      | `aws-load-balancer-controller` | eks | 3.5.0 | |
      | `keda` | eks | 2.20.2 | `kubeVersion >=1.23` |
      | `cluster-autoscaler` | eks | 9.59.0 | appVersion 1.35.0 = 클러스터 마이너와 일치 |
      | Gateway API CRD | eks | v1.6.2 | |

      ⚠️ `argo-cd`는 자기 관리라 `bootstrap/argocd-app.yaml`과 `argocd-seed.sh`의 핀이 함께 움직인다.
      ⛔ Kyverno를 3.8 라인으로 되돌리지 않는다 — legacy `kyverno.io` 타입은 v1.19 deprecated,
      **v1.20 제거**다. whitelist·커스텀 정책이 이미 새 kind라 셋이 함께 어긋난다
- [ ] [권고 미부합] **AKS 시스템 풀에 `CriticalAddonsOnly=true:NoSchedule` 도입 검토.** Microsoft는 시스템
      풀을 앱에서 격리하라고 권고하고 그 집행 수단으로 이 taint를 지목한다. 지금은 따르지 않으며 그 판단은
      `docs/architectures/gitops-hub-spoke/azure/README.md` 「노드 배치」가 갖는다.
      ⚠️ 세 저장소가 함께 움직인다 — ① `aks-cluster` 모듈이 `default_node_pool`에 taint 노출(지금은 user
      풀의 `node_taints`만 있다) ② `aks-reference-infra`가 값 주입 ③ `aks-platform-gitops`의
      `argocd-values.yaml`에 toleration 추가. ③ 없이 ①②만 하면 seed 시점의 ArgoCD가 갈 곳이 없어 멈춘다
      (그 파일의 ⛔ "tolerations를 넣지 않는다"가 뒤집혀야 하는 줄이다)
- [ ] [권고 미부합] **AKS 시스템 풀 크기.** Microsoft 권고는 vCPU 4 이상·노드 3대인데 현재
      `Standard_D2s_v5`(2 vCPU) 2대다. 강제가 아니라 클러스터는 생성된다. 실 워크로드를 올릴 때 함께
      올린다. ⛔ B 시리즈는 시스템 풀에 쓸 수 없다. 값과 근거는 `live/{hub,dev}/aks/main.tf` 주석
- [ ] [권고 미부합] **Karpenter AMI 핀.** EKS Best Practices Guide가 운영 클러스터에 `@latest` 대신 검증한
      AMI로 핀하라고 강하게 권고한다. 현재 `addons/karpenter/nodepool/values.yaml`이 `al2023@latest`이고
      hub는 `tier: prd`다. ⚠️ 값을 바꾸면 노드가 교체되므로 인프라가 선 상태에서 판단한다.
      핀 형식은 `al2023@v<날짜>`
- [ ] [aks-gitops] **관리형 네임스페이스의 실제 라벨을 찍고, 안 쓰는 조건을 지운다.**
      `addons/kyverno/custom-policies/require-nodepool-resources.yaml`의 `matchConstraints.namespaceSelector`가
      조건 셋을 AND로 건다. `control-plane DoesNotExist`는 AKS FAQ가 admission webhook 제외용으로
      직접 지목하고 selector 예시를 그대로 싣는다. `kubernetes.azure.com/managedby NotIn [aks]`는 공식
      문서가 관리형 **컴포넌트**의 라벨이라 적을 뿐 네임스페이스에도 붙는지가 확정되지 않았다.
      근거가 약한 쪽을 실물로 판정한다.
      절차: `kubectl get ns --show-labels`로 Azure가 만든 네임스페이스(`aks-istio-system`·
      `app-routing-system`·`gatekeeper-system` 등) 전부의 라벨을 본다.
      판정: 그것들이 `control-plane` 하나로 **전부** 잡히면 `managedby` 조건은 죽은 조건이니 지우고,
      주석에서 그 불확실성을 적은 줄도 함께 걷는다. `control-plane`이 없는데 `managedby`만 붙은 것이
      하나라도 있으면 둘 다 남기고 주석에 그 네임스페이스 이름을 적는다.
      ⛔ 세 번째 조건(`kubernetes.io/metadata.name NotIn [argocd]`)은 판정 대상이 아니다. legacy
         `exclude` 블록을 대신하는 자리고, ArgoCD 자신이 막히면 고칠 수단을 잃는다
      ⚠️ `matchExpressions`는 AND다 — 조건을 지우면 정책 사정권이 **넓어진다**. 제외가 줄어드는
         방향이라 전수 확인 전에는 지우지 않는다. 이 정책은 `validationActions: [Deny]`고 실패해도
         에러가 Kyverno 로그에만 남는다
      참고: AKS FAQ는 `kube-system`과 AKS 내부 네임스페이스를 자동 제외하는 admissions enforcer도
      함께 적지만, 그러면서 `control-plane` 제외를 여전히 권고한다. 자동 장치에 기대지 않는다
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
      짝으로 움직여야 한다(엔진 prd·nonprd, 정책 prd·nonprd). 지금은 넷이 전부 3.9.1이라 승격
      구간이 없다 — 다음 릴리스가 나와야 이 절차를 돌려볼 수 있다. 이 항목은 승격 **절차**가
      의도대로 도는지만 본다
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
- [ ] [전체] **5개 저장소를 private → public 으로 전환한다.** 무료 플랜 + private 조합이 막고 있는
      GitHub 기능을 열어 지금 우회로 버티는 것들을 없앤다. 순서는 **① 공개해도 되는 상태로 조치 →
      ② 전환 → ③ 열린 기능으로 개선**이고, ①을 끝내기 전에 ②로 넘어가지 않는다.

      실측한 제약(5개 저장소 전부 private·무료):
      `gh api repos/<org>/<repo>/branches/main/protection` 과 `/rulesets` 가 둘 다 403 이고, 메시지가
      `Upgrade to GitHub Pro or make this repository public to enable this feature` 다. GitHub 공식
      문서도 무료 플랜은 환경(Environment)을 **public 저장소에만** 구성할 수 있다고 적고,
      `Deployment protection rules for public repositories` 를 무료 항목으로 싣는다.

      ① 전환 전 조치 (전환은 되돌려도 이미 클론된 것은 못 되돌린다)
      - ⚠️ **git 이력 전수 스캔.** HEAD 만 보지 않는다. 계정 ID·구독 ID·테넌트 ID·Role ARN·
        App Registration client ID·state 버킷/스토리지 계정 이름·CIDR·private endpoint FQDN
      - ⚠️ **`aks-reference-infra` 의 FIC subject 가 최우선이다.** 그 repo 의 유일한 방어선이
        `subject` 하나로 좁힌 도달 경로인데, public 이 되면 fork·PR 경로가 새로 생긴다.
        `pull_request_target` 이 없음을 확인하고, fork 워크플로 실행 정책을 먼저 잠근다
      - GitOps 매니페스트가 공개되면 클러스터 구성(네임스페이스·정책·NodePool selector·IAM role 이름)이
        읽힌다. 공개해도 되는지 항목별로 판정한다
      - `.trivyignore`·`backend.hcl` 류 로컬 파일이 추적되고 있지 않은지 확인

      ② 전환

      ③ 열리는 것 (전환 후 실제 목록은 그때 리서치한다. 아래는 이미 걸려본 것)
      - **배포 루트 CI**: `environment:` 를 지금은 OIDC `sub` 클레임 때문에만 쓰고 보호 규칙을
        못 건다. public 이면 **required reviewers 를 apply job 에 걸 수 있다** — `workflow_dispatch`
        를 누르는 것이 승인인 현재 모델을 GitHub 이 강제하는 승인으로 바꾼다
      - **브랜치 보호·ruleset**: 지금은 아무 저장소에도 못 건다. 루트 `CLAUDE.md` 「GitOps 저장소
        공통」의 ⛔ 재검토 트리거가 `저장소가 public 이 되면` 을 포함한다 — PR 판정이 뒤집힌다
      - **GitOps CI 신설**: 렌더 검증 CI + 그 CI 가 도는 PR. 지금은 CI 가 없어 PR 이 형식만 남는다
      - **ArgoCD 의 저장소 credential 제거.** `bootstrap/argocd-seed.sh` 2단계가 GitHub App
        private key 를 `argocd-repo-gitops` repository Secret 으로 넣는다. 스크립트 자신이 그것을
        **「자기소멸 원칙의 유일한 예외」**라 부르고, 삭제되면 모든 sync 가 멈춘다고 경고한다.
        GitOps 저장소가 public 이면 ArgoCD 는 익명으로 읽을 수 있다 ⇒ 그 Secret 도, GitHub App 도,
        private key 를 SSM SecureString 으로 나르는 절차도 통째로 사라진다. seed 단계가 하나 줄고
        예외가 0 이 된다. ⚠️ 두 GitOps 저장소만 public 이면 되는 일이라 전환 범위를 저장소별로
        가를 수 있다
      - Actions 사용량: public 저장소의 표준 러너 한도를 확인한다(현재 무료 private 은 월 2,000분)

      ④ 배포 루트 CI 를 손보는 김에 함께 (⚠️ public 과 기술적 의존이 없다 — 지금도 할 수 있고,
         ③ 이 어차피 워크플로를 건드리므로 묶는다)
      - **문서 전용 변경은 이미 안 돈다.** `paths` 가 허용 목록(`live/<root>/**` + 자기 워크플로
        파일)이라 `docs/**` 가 애초에 없다. 실측: aks `a8db0428`(runbooks 만) → run 0건.
        `iac-module-library` 가 워크플로를 둘로 가른 것과 같은 결과를 배포 루트는 허용 목록
        하나로 이미 얻고 있다. ⇒ **이 축은 할 일이 아니다.**
      - **`.tf` 주석만 바뀐 push 는 plan 을 돌린다.** `paths` 는 파일 단위라 diff 내용을 못 본다.
        실측: aks `d484623`·`1cb393a`(둘 다 주석만)이 plan 2개를 돌렸다. 루트 규칙이 동작 변경
        없는 주석 수정을 main 직접 커밋으로 허용하므로 이 경로는 계속 생긴다.
        ⚠️ 비주석 diff 를 세어 건너뛰는 사전 job 은 **오판이 조용하다** — heredoc·문자열 안의
        `#` 를 주석으로 세면 진짜 코드 변경에서 plan 을 건너뛴다. 그 오판은 plan 이 안 돈 것과
        구분되지 않는다. 정규식으로 가르지 않으려면 커밋 메시지 `[skip ci]` 규약이 오판 0 이다
        (대신 사람이 빠뜨릴 수 있고, 그 워크플로만이 아니라 전부를 건너뛴다).
      - **철거 상태에서 plan 이 항상 실패한다.** 원인은 의존 root 가 아직 없어 `data` 조회가
        깨지는 것이고 코드 결함이 아니다. aks 는 `Error: Subnet (...) Resource Group Name:
        "rg-demo-hub-krc-workload-01"`(`data.azurerm_subnet.aks_node`), eks 는
        `no matching RAM Resource Share found` 다. 에러 문구가
        `OpenTofu planned the following actions, but then encountered a problem` 이라 plan 그래프
        자체는 서 있다.
        ⛔ `continue-on-error` 로 덮지 않는다. 진짜 실패와 구분이 사라진다.
        방향은 plan 앞에 의존 리소스의 존재를 확인해 없으면 건너뛰고 run Summary 에 "철거 상태"
        를 적는 것이다. ⚠️ 그 확인이 CI 신원의 read 권한에 기대므로 권한 축소와 같이 움직인다.
- [ ] [local] context7 MCP에 rate limit이 걸리면 context7.com/dashboard에서 키를 받아 로컬 설정에
      `Authorization: Bearer` 헤더로 얹는다(저장소에 넣지 않는다)
- [ ] [local] 약 한 달 뒤 `~/archive/`(에이전트·스킬·hook·`.omc` 백업 3개) 삭제
