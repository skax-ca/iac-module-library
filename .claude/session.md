# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 표의 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | hub·dev 전부 destroy. **public**, MIT. 시크릿 0개. 최상위 `README.md` 있음(라우터: 배포 루트 5개·state key·실행 모델·문서 라우팅표). `verify.yml`(시크릿·문서주석셸·OpenTofu 3 job)이 PR·push에서 돌고 ruleset `main`이 그것을 요구한다. environment `hub`·`dev`에 required reviewer `silverte`(self-review 허용)와 브랜치 정책 `main`. plan artifact 7일. 철거 상태 main push: `hub/tgw`만 plan 성공 → apply `waiting`(생성 plan이라 **Reject**한다), 나머지 4개는 `RAM Resource Share`·`TGW`·`VPC` not found로 실패 → apply skipped. 시스템 노드그룹 taint `CriticalAddonsOnly=true:NoSchedule`, 라벨 `workload-class=system`. 변수 34개 `nullable = false`. 루트마다 `backend.hcl.example`(로컬 전용 4키: `bucket`·`key`·`region`·`use_lockfile`). **Dependabot(`opentofu`, 루트 5개) 있음 → PR 12건 열려 있다** |
| eks-platform-gitops | main = origin | dev cluster-secret 삭제 상태. **public**, MIT. seed는 1 helm install → 2 AppProject → 3 cluster Secret → 4 root Application(repository Secret 단계 없음, preflight가 `repoURL`을 익명 `ls-remote`). `verify.yml`(시크릿·주석셸·매니페스트 3 job: YAML 파싱·로컬 차트 2개 lint/template·`kyverno test`)과 ruleset. `tests/kyverno/require-karpenter-resources/` 픽스처 5건(pass 1·fail 3·skip 1). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. ApplicationSet `applicationsets/{baseline,catalog}/`(10파일), root App include 매칭 14개. multi-source `$values` 5개. Karpenter AMI 핀 `amiAliasByTier` 둘 다 `al2023@latest`. Kyverno는 `policies.kyverno.io/v1beta1 ValidatingPolicy`. 훅 정규식에 `tests/`·`.github/workflows/` 포함 |
| aks-reference-infra | main = origin | **hub 구축 완료**(networking 27 + vwan 4 + aks 8 + workbench 14 리소스, 태그 기준 30건). dev는 철거 상태. workbench 공인 IP `20.196.104.126`(`Standard_B2s`), SSH CIDR `211.45.60.3/32`와 일치. 클러스터 `aks-demo-hub-krc-main-01` k8s 1.35 private, `networkPluginMode=overlay`·`podCidr 10.244.0.0/16`·`outboundType=userAssignedNATGateway`·`networkPolicy=cilium`. 시스템 풀 `Standard_D4s_v5` 2대 + NAP 노드 `Standard_D2als_v6` 1대. provider 7루트 전부 `azurerm 5.5.0`(workbench 둘은 `time 0.14.2`), **Dependabot PR 0건**. **public**, MIT. 변수 48건 `nullable = false`. FIC subject는 repo ID에 묶여 있다(저장소를 지우고 다시 만들면 깨진다) |
| aks-platform-gitops | main = origin | **hub seed 완료.** Application 7개 전부 `Synced/Healthy`(root-app·argocd·gateway·karpenter-nodepool·kyverno·kyverno-custom-policies·kyverno-policies). root App이 읽은 revision은 커밋 SHA. dev 스포크는 철거 상태. **public**, MIT. `bootstrap/argocd-values.yaml`의 client ID는 `ec70a09c-8160-4ba6-8a25-2905d55b9376`(`46d6da2`). ApplicationSet **5파일 = ApplicationSet 7개**(`kyverno.yaml`·`kyverno-policies.yaml`이 각각 2개를 담는다), root App include 매칭 **11개**(AppProject 1·Application 2·ApplicationSet 7·Secret 1). ⛔ **초기 admin 비밀번호를 교체하지 않았다** — `argocd-initial-admin-secret`이 남아 있다 |

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
required status check, bypass = repository admin(`always`) — 용도는 문서 직접 커밋 하나. ⚠️ API는 이
bypass를 `RepositoryRole actor_id 5`로만 내보내고 공식 REST 문서에 숫자 매핑이 없다 — 역할 이름은
`Settings → Rules → main → Bypass list`에서만 읽힌다(admin으로 확인했다). 배포 루트의
`deploy-*.yml`은 `push: main` + `paths: live/<root>/**`라 PR에서는 안 돌고, 머지 뒤 그 루트를 건드린 push만
plan을 띄운다. ⚠️ `gh run list --commit`은 40자 SHA만 받는다. fork PR 승인 정책은 3개 저장소
`all_external_contributors`(GitOps 둘은 `.github`가 없어 해당 없음).

배포 루트 `deploy-*.yml`의 apply 게이트는 조건 **3항**이다(`aks-ref` `099dba1`·`eks-ref` `bb9c404`):
`github.ref == main` · `needs.plan.outputs.changes == 'true'` · `inputs.action != 'plan'`.
**변경 0건이면 apply job이 `skipped`로 끝나 승인 게이트가 서지 않는다** — 게이트가 섰다는 사실 자체가
"적용할 것이 있다"는 신호다. `action=plan`은 확인 전용 경로이고 드리프트가 있어도 apply하지 않는다
(Summary가 확인 전용임을 적는다). `push`는 `inputs.action`이 비어 있어 조건을 그대로 통과한다.
`destroy`는 항상 `changes=true`라 영향이 없다. ⚠️ **로컬 `tofu plan`은 `require_oidc`/`ci_run` 가드가
막는다** — 가드를 우회하지 않는다. 드리프트 확인은 이 CI 경로가 유일하다.
⚠️ **승인 대기 중인 run은 `gh run view --log`로 plan을 못 읽는다**(`still in progress`). 웹 Summary
탭이거나, `gh run download <id> -n tfplan-<id>` 후 그 root에서 `tofu init -backend=false` + `tofu show`다.

권한 구조: org `skax-ca`의 기본 권한은 `read`, 멤버는 `silverte`(org admin)·`rajaelime`(org member) 둘.
**직접 collaborator는 0명**이고 접근은 전부 팀 `iac` 경유다(팀이 5개 저장소에 `maintain`). 그래서
`rajaelime`은 팀에서는 member지만 저장소에서는 `maintain`(`push: true`)이다 — 팀 안의 지위와 팀이
저장소에 갖는 권한은 별개 축이다. `silverte`의 저장소 `admin`은 팀이 아니라 org owner에서 온다.

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
⚠️ 문서 길이 한도 400줄은 검사기가 `wc -l`보다 1 크게 센다. `eks-ref`의 `hub-lifecycle.md`가 한도에
차 있어 줄을 늘리려면 기존 문장에 접어 넣어야 한다.

에이전트 스킬은 **클라우드 접두어로 가른다**: `aks-argocd-tunnel-{connect,disconnect}`(SSH,
로컬 `18080`) · `eks-argocd-tunnel-{connect,disconnect}`(SSM, 로컬 `8080`). ⚠️ 접두어 없이 같은 이름을
쓰면 `--add-dir`로 5개를 붙일 때 **먼저 등록된 쪽만 살아남고 나머지는 경고 없이 사라진다**. 로컬 포트가
다른 것은 두 터널을 동시에 열기 위한 의도된 차이다(`connect.sh` 주석이 근거를 갖는다). 원격 포트는
양쪽 다 `8080`이다.

## 지난 세션 (2026-09-18 오후)

**AKS hub를 전 계층 구축했다.** bootstrap drift 확인(hub 22·spoke 28 항목 전부 `ok`) → networking
(27 added) → vwan (4 added, dev가 없어 스포크 연결 0개는 정상) → aks (8 added) → workbench (14 added)
→ GitOps seed 4단계 → Application 7개 `Synced/Healthy`. 완료 판정 7항목 중 6개 통과, 초기 비밀번호
교체만 건너뛰기로 했다. Workload Identity federation을 끝단까지 확인했다(SA 애노테이션 + Pod 라벨 +
`azure-identity-token` 볼륨 주입). Kyverno가 2분간 `Pending`이었던 것은 고장이 아니라 NAP 노드를
기다린 것이고(`untolerated taint(s)`), 예고된 seed 순서가 실측으로 확인됐다.

**Dependabot 9건을 전부 머지했다**(aks-ref `fb4b383`~`5f7daa3`). 전부 provider PR이었고 모듈 PR은
0건이었다 — 할 일 항목이 전제했던 "모듈 `0.y.z`" 판단축이 실물과 달랐다. azurerm `5.5.0`이 AKS
ForceNew 축(`network_profile`·`private_cluster_enabled`)을 건드리지 않음을 공식 CHANGELOG로 확인하고
올렸다. 루트별 드리프트(`5.2.0`/`5.3.0`/`5.4.0`)가 `5.5.0`으로 수렴했다.

**CI의 확인 비용을 구조적으로 줄였다**(`aks-ref` `099dba1`·`eks-ref` `bb9c404`). apply 조건이 브랜치
하나뿐이라 변경 0건에도 승인 게이트가 섰고, 드리프트 확인이 배포와 같은 값을 치렀다. `changes` 가드와
`action=plan`을 넣었다. 그 PR의 머지가 7개 루트를 깨웠고 **hub 4개가 `plan=success, apply=skipped`로
끝나** 완료 판정 7번(재-plan 수렴)이 승인 클릭 0회로 답이 나왔다. 개선이 자기 자신을 검증한 셈이다.
AKS는 워크플로가 `backend.hcl.example`을 읽게 해 backend 값 사본을 하나로 줄였고, EKS는 그 방식을 쓸
수 없어(CI만 `assume_role`이 필요해 로컬과 형태가 다르다) 예시 파일을 로컬 전용으로 5개 신설했다.

**터널 스킬 이름 충돌을 풀었다**(`aks-ref` `c8b6d05`·`eks-ref` `5f98d01`). 두 저장소가 같은 이름을
써서 이번 세션에는 EKS(SSM)만 등록되고 AKS(SSH)는 사라져 있었다. 클라우드 접두어로 갈랐다. 그 과정에
EKS `runbooks.md`의 수동 절차가 1홉 `18080`·2홉 `8080`으로 어긋나 **그대로 따라 하면 연결되지 않던
버그**를 찾아 고쳤다. root 간 의존도 코드로 확인해 문서화했다(`353a647`) — `vwan`과 `aks`는 서로를
읽지도 쓰지도 않아 병렬 가능이고, "관례상"이라고만 적혀 있던 근거를 걷었다.

## 다음 할 일

재구축을 전제하는 항목이 많아 **인프라 순서**로 묶었다. AKS hub가 서 있고 dev(spoke)가 다음이다.
1·2절은 그 작업과 **같이** 해야 하는 것, 3절은 클러스터와 무관해 아무 때나 되는 것, 4절은 트리거가
와야 열리는 것이다.

### 1. AKS spoke 구축·철거와 같이 (다음 세션)

**구축 전**

- [ ] [aks-gitops] hub ArgoCD 초기 비밀번호를 교체하고 `argocd-initial-admin-secret`을 지운다.
      `hub-lifecycle.md` 7절의 **완료 조건**인데 이번 세션에 건너뛰었다. 대화형 프롬프트가 필요해
      사람이 workbench에서 한다(`runbooks.md` 「ArgoCD 관리자 비밀번호 교체」). ⚠️ 임시 비번이
      이전 세션 대화에 남아 있다. `--core`로는 안 된다(세션 토큰이 없다), `--port-forward`를 쓴다

**구축 중 — 이번 재구축에서만 답이 나오는 실측**

- [ ] [aks-ref] **승인 흐름을 실측한다 — spoke 구축 때 한다**(hub 구축에서 창을 놓쳤다. EKS와
      공통 질문이라 여기서 답을 낸다). 확인할 것:
      ① 승인 대기 중 같은 루트에 새 push가 오면 대기 run이 취소되는지. **의도적으로 push를 얹어야
      열리는 창이다** — 자연스러운 구축 흐름만 따라가면 그냥 지나간다. 코드의 예고는 "취소되지
      않는다"이고(`concurrency: {group: live-<env>-<root>, cancel-in-progress: false}`) 새 run이
      대기열에 선다. 실측이 이 예고와 맞는지 본다
      ② artifact 7일 안에 승인하지 않으면 apply가 어떻게 실패하는지(7일이 걸려 한 세션에 못 한다)
      ③ `gh run rerun --failed`가 승인된 plan을 그대로 쓰는지(실패한 apply가 나와야 확인된다.
      hub 구축은 4개 root 전부 성공해 기회가 없었다)
- [ ] [aks-ref] **`vwan`·`aks` 병렬 apply를 실측한다**(hub 재구축 때). 두 root는 서로를 읽지도
      쓰지도 않아 의존이 없다(`docs/hub-lifecycle.md` 5절). ① 동시 apply가 Azure의 VNet 쓰기
      직렬화에 걸려 `AnotherOperationInProgress`로 떨어지는지 ② 떨어지면 `gh run rerun --failed`로
      복구되는지. 순차는 약 44분, 병렬 임계 경로(networking → aks → workbench)는 약 19분이다.
      ⚠️ workbench는 `aks`만 기다리면 된다(vwan 리소스를 하나도 읽지 않는다)
- [ ] [aks-ref] dev 루트 3개를 순서대로 apply한다(`spoke-lifecycle.md`). 철거 상태에서 이번 세션의
      main push는 `dev/networking`만 plan 성공(대기 → Reject), `dev/aks`·`dev/workbench`는 VNet·
      서브넷 not found로 실패했다 — 정상 신호다
- [ ] [aks-ref] **dev 생성 후 `live/hub/vwan`을 한 번 더 apply한다.** `azurerm_resources` 태그
      조회가 그때 dev VNet을 발견해 스포크 연결을 채운다. hub는 spoke 없이 완결되게 지어져 있다
- [ ] [aks-gitops] cluster Secret 등록 — teardown이 라벨을 먼저 뗐다. AKS dev는 `environment`·
      `tier: nonprd`·`addon-karpenter`. `tier`는 staged addon(Kyverno) 선택에도 쓰인다

**구축 후 — 클러스터가 살아 있을 때만 확인 가능**

- [ ] [aks-gitops] **Kyverno CEL 전환을 클러스터에서 검증한다.** 오프라인 판정(`kyverno test`)은 CI에
      있다. 클러스터에서 다른 것은 autogen(파드 컨트롤러 대응 규칙)과 기본 `resourceFilters`다.
      - 업스트림 PSS 11개가 `ValidatingPolicy`로 뜨고 `validationActions: [Audit]`·`failurePolicy: Ignore`인지
      - 커스텀 정책 2개(`Deny`)가 requests 없는 파드를 실제로 거부하는지
      - aks 관리형 ns 제외가 먹는지. 영구 OutOfSync가 없는지(`ServerSideDiff=true`에 기댄다)
- [ ] [aks-gitops] **관리형 네임스페이스 라벨을 찍고 `managedby` 조건을 판정한다.** `kubectl get ns
      --show-labels`. Azure 네임스페이스가 `control-plane` 하나로 전부 잡히면 `managedby` 조건과 그
      주석·픽스처(`skip-managedby-aks`)를 걷는다. ⛔ argocd 제외 조건은 판정 대상이 아니다.
      ⚠️ 조건을 지우면 사정권이 넓어진다
- [ ] [aks-ref·aks-gitops] KEDA addon toleration을 확인한다(`kubectl -n kube-system get pod -o
      custom-columns=NAME:.metadata.name,TOLERATIONS:.spec.tolerations[*].key`). 시스템 노드에
      `kube-system`·`argocd`만 있는지. ✅ seed 순서(ArgoCD 시스템 풀 → NodePool CR → NAP 노드 →
      Kyverno)는 hub에서 실측으로 확인했다
- [ ] [aks-gitops] nonprd 팬아웃 실측. 승격 절차 1회(Kyverno 릴리스나 차트 버전 올림으로)

### 2. EKS 구축·철거와 같이 (AKS 다음)

- [ ] [eks-ref] Dependabot PR 12건을 올릴지 정한다. ⚠️ AKS와 달리 **모듈 PR이 섞여 있을 수 있다** —
      AKS는 9건 전부 provider였다. 모듈은 `0.y.z`라 마이너에 파괴적 변경이 있을 수 있으니 plan을
      읽고 판단한다. `live/hub/tgw`의 aws provider가 다른 루트와 갈려 있었다(6.61.0 vs 6.57.1)
- [ ] [eks-ref] 승인 흐름은 AKS에서 답이 나온 것을 빼고 **차이만** 본다. eks 고유는 철거 상태에서
      `hub/tgw`만 plan이 성공한다는 점이다(생성 plan이라 절차 밖이면 **Reject**)
- [ ] [eks-ref] ⚠️ **의존 방향이 AKS와 반대다**: `live/hub/networking`이 `data.aws_ec2_transit_gateway`로
      TGW를 읽어 `tgw → networking → eks` 선형 사슬이다. AKS의 `networking → {vwan, aks}` 팬아웃과
      달리 병렬 여지가 없다
- [ ] [eks-gitops] seed의 root Application 단계 직후 `argocd app manifests root-app --core`로 include
      확인 — 리소스 14개. ⚠️ **kubeconfig 컨텍스트의 네임스페이스가 `argocd`여야 한다**(아니면
      `configmap "argocd-cm" not found`로 죽는다). 임시 KUBECONFIG 사본에 `kubectl config set-context
      --current --namespace=argocd`를 걸어 영구 변경 없이 돌린다
- [ ] [eks-gitops] cluster Secret 등록. EKS dev는 `environment`·`tier: nonprd`·`vpcName`·
      `karpenterNodeRole`. ⚠️ `karpenterNodeRole`은 26자 hash 접미가 붙어 **재구축마다 바뀐다**
- [ ] [eks-ref·eks-gitops] **taint 키 교체를 검증한다.** coredns·metrics-server·ebs-csi·Karpenter의
      기본값 toleration, coredns `control-plane`·ebs-csi `NoExecute/300s` 복원, cert-manager 3개
      시스템 노드, Karpenter 부트스트랩, ALBC·Kyverno·ArgoCD는 Pending만 아니면 통과
- [ ] [eks-gitops] multi-source 5개 addon이 `$values/addons/<addon>/values.yaml`을 읽는지, AppProject
      `sourceRepos`를 통과하는지
- [ ] [eks-gitops] **Karpenter AMI를 prd에 핀한다.** `kubectl get nodeclaim -o wide`로 실제 뜬 노드의
      값. 형식 `al2023@v<YYYYMMDD>`. nonprd는 다음 AMI를 먼저 받는 자리
- [ ] [eks-gitops] Kyverno CEL 클러스터 검증(1절의 aks 항목과 같은 목록, aks 관리형 ns 항목만 제외)

### 3. 재구축과 무관 — 아무 때나

- [ ] [module·eks-ref·aks-ref] stop-slop 잔여 범위: `.tf` 주석과 `docs/*.md`. README 4곳(모듈 루트·
      배포 루트 둘의 `bootstrap/`·eks-gitops)은 끝났다. ⛔ em-dash 제외. "A가 아니라 B다"·
      "의도적으로"·출처 수동태는 유지
- [ ] [eks-ref·aks-ref] 루트 간 모듈 태그 드리프트를 `verify.yml` Summary에 출력만 하는 안
      (실패시키지 않는다). 지금은 루트별 `ref` 값이 전부 일치해 보류했다. 승격을 스테이지드로
      돌리기 시작하면 갈린 상태가 의도인지 잊은 것인지 구분할 수단이 필요해진다
- [ ] [eks-ref·aks-ref] ⚠️ `allowed_actions: "all"`·`sha_pinning_required: false`다. 업스트림 액션이
      탈취되면 main에서 도는 워크플로의 OIDC 토큰이 노출될 수 있다. SHA 핀을 걸지 판단한다
      (public 전환으로 공격면이 늘어난 축은 push가 아니라 이쪽이다)
- [ ] [local] context7 rate limit 시 키를 로컬 설정 `Authorization: Bearer`로. 약 한 달 뒤
      `~/archive/` 삭제

### 4. 조건이 오면 (지금 하지 않는다)

- [ ] [module] 다음 `workbench`·`aks-workbench` **기능** 태그를 컷할 때 태그 메시지에 user-data 교체
      경고를 싣는다(`6e34dec`는 주석·문서 전용, 양쪽 태그보다 뒤). AWS
      `user_data_replace_on_change = true`, Azure `custom_data` ForceNew:

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
      `targetRevision`은 **항상 같다**(지금 둘 다 `10.9.1`). 갈리면 흡수가 업그레이드가 된다
- [ ] [aks-ref] 실 워크로드를 올릴 때 AKS 시스템 풀 노드 수를 3대(권고)로 볼지 판단한다. 지금 2대는
      권고 미부합을 알고 수락한 값이다
- [ ] [eks-ref·aks-ref] Dependabot에 `groups`로 provider PR을 묶을지, `github-actions` 생태계를 추가할지는
      재구축 후 소음을 실제로 겪어 보고 정한다. ⚠️ `open-pull-requests-limit`은 디렉토리별이라
      루트를 늘리면 전체 상한도 함께 늘어난다
- [ ] [전체] **작업자가 2인 이상이 되면**: ruleset 5개 `required_approving_review_count` 0→1 +
      `require_last_push_approval`·`dismiss_stale_reviews_on_push`, 환경 4개에 두 번째 reviewer +
      `prevent_self_review: true`, 문서 직접 커밋 규칙과 admin bypass(`always`) 재검토. CODEOWNERS는
      모듈 담당이 갈릴 때만. ⚠️ **이미 push 권한자가 2명이다**(`rajaelime`이 팀 경유 `maintain`).
      트리거가 이미 당겨진 것으로 볼지 판단한다
- [ ] [local] org 멤버십 가시성은 그대로 두었다(공개 멤버 0, 멤버 2). 바꾸면 달라지는 것은 People
      탭과 개인 프로필 배지뿐이고 권한·CI·OIDC와는 무관하다. 본인 것은 각자만 바꿀 수 있다
- [ ] [module] ⛔ **모듈 소싱 대안 3종은 기각했다. 다시 제안하기 전에 이 근거를 반박해야 한다.**
      ① 레지스트리 이전 — 공개/사설 레지스트리는 저장소 1개당 모듈 1개(`terraform-<provider>-<name>`)를
      요구해 저장소 7개 분할을 강제한다. 모노레포로 얻는 것(한 PR에서 여러 모듈 수정, 규약 문서와
      코드의 동거)을 잃는다. ② OCI(`oci://`, digest 고정) — 불변성이 가장 강하고 `//subdir`도
      지원하지만 레지스트리 운영·인증·게시 파이프라인이 새로 필요하다. 태그 ruleset이 같은 목적을
      훨씬 싸게 달성한다. 팀이 커지거나 외부 배포가 생기면 그때 다시 본다. ③ `depth=1` 제거 후 SHA
      고정 — 불변성은 얻지만 어느 버전인지 안 보이고 클론이 무거워진다. `examples/`의 상대 경로
      유지는 `docs/decisions.md`에 기록했다
- [ ] [aks-ref·eks-ref] ⛔ **drift 전용 워크플로(`drift.yml`)는 기각했다.** 루트를 matrix로 돌려
      한 번에 확인하는 안인데, EKS는 CI의 `backend.hcl`이 `assume_role` 블록을 갖고 로컬과 형태가
      달라 **인증 배선의 두 번째 사본**이 생긴다. `changes` 가드 + `action=plan`이 같은 목적을
      중복 0으로 달성한다. 루트 수가 크게 늘어 dispatch 횟수가 문제가 되면 다시 본다
