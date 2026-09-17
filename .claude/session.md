# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 표의 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | hub·dev 전부 destroy. main push plan은 `hub/tgw`만 성공(정상. 나머지 4개는 `no matching RAM Resource Share found`로 실패하며, 철거 상태의 `data` 조회 실패라 코드 문제가 아니다). 변수 34개 전부 `nullable = false`. `scripts/argocd-seed.sh`는 없다(GitOps 저장소가 소유). pre-commit 셸 게이트가 `.githooks/pre-commit`·`pre-push` 자신까지 덮는다. `scripts/README.md`가 셸 게이트 상세를 소유한다 |
| eks-platform-gitops | main = origin | dev cluster-secret 삭제 상태(라벨 먼저 뗀 뒤 파일 삭제). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. ApplicationSet은 `applicationsets/{baseline,catalog}/`(10파일), `addons/<addon>/`은 values·로컬 차트·CR만. root App include는 `applicationsets/**/*.yaml` 등 5항목이고 매칭 14개. 업스트림 차트 values는 `addons/<addon>/values.yaml` 5개를 multi-source `$values`로 읽는다(인라인 `values: \|` 없음). 규약(팬아웃·finalizers·staged 전파·cluster Secret 라벨 계약)은 README가 소유하고 매니페스트 주석은 그 파일 고유 사실만 갖는다. 훅·검사기 경로 목록에 `applicationsets/` 포함. 위반 0건 |
| aks-reference-infra | main = origin | 전부 철거 상태. 원본 이식 항목 완료. 변수 48건 `nullable = false`. pre-commit 셸 게이트가 훅 파일 자신까지 덮는다. `bootstrap/config.sh`의 `GH_ORG_ID`·`GH_REPO_ID`는 대입과 `readonly`를 나눠 `gh api` 실패가 `set -e`에 잡힌다 |
| aks-platform-gitops | main = origin | dev 스포크 철거 2단계 완료(라벨 제거 → cluster-secret 삭제). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. ApplicationSet은 `applicationsets/{baseline,catalog}/`(5파일), `addons/<addon>/`은 평문 CR 디렉토리 3개만. root App include는 `applicationsets/**/*.yaml` 등 5항목이고 매칭 9개. 인라인 `values: \|`는 원래 없다(`parameters`만). 규약은 README가 소유하고 매니페스트 주석에 AWS 대조 서술을 두지 않는다. 커스텀 정책의 관리형 ns 제외는 `control-plane`·`managedby` 두 라벨을 AND로 건다. 훅·검사기 경로 목록에 `applicationsets/` 포함. 위반 0건 |

⚠️ 로컬 전제: 훅이 `shellcheck`를 **하드 요구**한다(없으면 즉시 실패). clone마다
`git config core.hooksPath .githooks`와 `brew install shellcheck`가 필요하다. 이 Mac에는
0.11.0이 설치돼 있다. `timeout`은 이 Mac에 없다(coreutils 미설치). `kubeconform` 0.8.0이
설치돼 있다(개발 중 손으로 돌리는 스키마 검증, 훅에는 넣지 않는다). `helm` 3.18.4가 있어
`helm template --repo <url> <chart> --version <v>`로 업스트림 차트를 로컬 렌더할 수 있다
(OCI는 `oci://public.ecr.aws/karpenter/karpenter`). ALBC 차트는 렌더마다 자체 서명 TLS를 새로
만들어 `ca.crt`·`tls.*`·`caBundle` 4줄이 매번 다르다.

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

CI 경로 필터를 넣고, 두 GitOps 저장소의 문서·주석을 전면 정리한 뒤, 거기 적힌 기술적 주장을
공식 문서·차트 실물과 대조해 검증했다.

CI(`c226d6f`, PR #57): 워크플로를 `verify.yml`(OpenTofu 게이트 7개, 허용 목록 `paths`)과
`verify-docs.yml`(검사기 3개, 제외 목록 `paths-ignore`)로 가르고 job 이름을 「OpenTofu 검증 게이트」로
바꿨다. GitHub Actions에 job별 필터가 없어 파일을 가르는 것이 유일한 네이티브 수단이다. 필터 방향이
갈린 이유는 입력을 열거할 수 있느냐다 — OpenTofu 게이트는 닫힌 집합, 검사기는 넓은 글롭. 사전 작업으로
`presentations/README.md`를 지워 그 디렉토리를 게이트 밖으로 뺐다(`b7c12ed`).

문서·주석 정리(eks `64800a5`·`0bf9907`, aks `7f6776c`·`7c58ebc`·`36b078e`): yaml 44개에서 1500줄 넘게
걷어냈다. 헤더 3~6줄 규칙을 32개 파일이 어겼고(최대 58줄), 본문 `✅` 14건·확정 사실에 붙은 `🔴` 35건·
이력 서술 39건이 있었다. 반복되던 규약은 지우지 않고 README로 올렸다(「ApplicationSet 공통 규약」·
「staged 전파」·「cluster Secret 라벨 계약」). aks 쪽은 "AWS 원본과 무엇이 다른가" 서술 15건을 이 저장소
기준 서술로 바꿨다. 모든 yaml을 HEAD와 파싱 대조해 구조 동치를 확인했다.

검증(eks `af0ad0e`·`b51b3f1`, aks `0437c27`): 차트 6개 핀이 전부 실재하고 `appVersion`·`kubeVersion`
주장이 맞았다. 틀린 것 다섯을 고쳤다 — Karpenter values의 `tolerations`가 차트 기본
`CriticalAddonsOnly`를 교체한다는 사실 누락(helm은 리스트를 병합하지 않는다), `replicas: 2`가 차트
기본값과 중복, aks Kyverno의 `namespaceSelector`가 문서상 컴포넌트 라벨에만 의존(FAQ가 지목하는
`control-plane`을 AND로 더했다), aks NodePool 주석이 모듈 실물(`default_node_pools = "None"`)과 어긋남,
kyverno 3.9 legacy 타입 deprecation 누락.

결정 기록(`0481b9b`, aks-ref `d484623`): Microsoft 권고 셋을 따르지 않는다는 사실이 어디에도 없어
`azure/README.md`에 「노드 배치: 시스템 풀에 taint를 두지 않는다」를 신설했다. 안 하는 이유는 부트스트랩
순서(시스템 풀을 잠그면 seed 시점의 ArgoCD가 갈 곳이 없다)이고, 도입 시 세 저장소가 함께 움직인다.

## 다음 할 일
- [ ] [질문] aks `addons/kyverno/custom-policies/require-nodepool-resources.yaml`의 `namespaceSelector`에
      `control-plane DoesNotExist`를 더한 변경(`0437c27`)의 내용을 다시 설명받는다. 요지: 그 정책은
      Enforce라 requests/limits 없는 파드를 막는데, AKS가 관리하는 네임스페이스(`aks-istio-system` 등)의
      파드는 그 값을 선언하지 않아 함께 막힌다. 그래서 제외해야 하고, **무엇으로 제외를 판정하느냐**가
      쟁점이었다. 기존은 `kubernetes.azure.com/managedby: aks` 하나였는데 공식 문서는 그 라벨을 관리형
      **컴포넌트**의 것이라 적고, 네임스페이스 마커로는 AKS FAQ가 `control-plane` 라벨을 지목한다
- [ ] [addon] **차트 버전을 클러스터가 지원하는 최신으로 올린다.** 아래는 실측한 현재/최신이다.
      클러스터는 EKS 1.35 · AKS 1.35다. 올릴 때마다 `argocd app manifests`로 렌더를 먼저 본다

      | addon | 저장소 | 현재 | 최신 | 비고 |
      |---|---|---|---|---|
      | `kyverno`·`kyverno-policies` | eks·aks | 3.8.2 | **3.9.1** | ⚠️ 이것만 단순 버전 올림이 아니다(아래 별도 항목) |
      | `argo-cd` | eks·aks | 10.3.0 | **10.9.1** | appVersion v3.5.0 → v3.5.3. `kubeVersion >=1.25` 충족 |
      | `karpenter` | eks | 1.14.0 | **1.14.1** | OCI 태그 = chart = appVersion |
      | `aws-load-balancer-controller` | eks | 3.5.0 | 3.5.0 | 이미 최신 |
      | `keda` | eks | 2.20.2 | 2.20.2 | 이미 최신. `kubeVersion >=1.23` |
      | `cluster-autoscaler` | eks | 9.59.0 | 9.59.0 | 이미 최신. appVersion 1.35.0 = 클러스터 마이너와 일치 |
      | Gateway API CRD | eks | v1.6.2 | v1.6.2 | 이미 최신 |

      ⚠️ `argo-cd` 올림은 자기 관리 Application이라 순서가 있다. seed가 설치한 핀과 저장소 값이
      갈리면 흡수가 아니라 업그레이드가 된다(`bootstrap/argocd-app.yaml` 헤더)
- [ ] [addon] **Kyverno 3.9 전환은 버전 올림이 아니라 kind 이동이다.** 3.9 차트 values 원문이 legacy
      `kyverno.io` 타입을 deprecated·향후 제거로 표시하고 `policyType` 기본값이 `ValidatingPolicy`(CEL)다.
      선택지 둘: ① `policyType=ClusterPolicy` 명시로 현행 유지(시한부다) ② whitelist·커스텀 정책을
      CEL로 함께 이동. **②를 기본으로 잡고 ①은 시간이 없을 때의 후퇴선으로 둔다.**
      ②를 고르면 함께 움직이는 것: 양쪽 `projects/platform.yaml`의 `clusterResourceWhitelist`
      (`kyverno.io/ClusterPolicy` → 새 kind), eks `require-karpenter-resources.yaml`,
      aks `require-nodepool-resources.yaml`
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
      짝으로 움직여야 한다. 3.9 라인으로 넘기는 것 자체는 위 「Kyverno 3.9 전환」 항목이 갖는다 —
      이 항목은 승격 **절차**가 의도대로 도는지만 본다
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
- [ ] [local] context7 MCP에 rate limit이 걸리면 context7.com/dashboard에서 키를 받아 로컬 설정에
      `Authorization: Bearer` 헤더로 얹는다(저장소에 넣지 않는다)
- [ ] [local] 약 한 달 뒤 `~/archive/`(에이전트·스킬·hook·`.omc` 백업 3개) 삭제
