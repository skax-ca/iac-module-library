# 30 · 플랫폼 GitOps 저장소 구조 — App-of-Apps · ApplicationSet · AppProject

> **승계(미개정)**: `terraform-enterprise-poc` `docs/design/30-gitops-repo.md` @ `76285f7`(동결 커밋)
>
> ⚠️ **이 문서는 아직 정밀 개정되지 않았다.** PoC 전제(Terraform 1.15 + HCP Terraform,
> `workload=poc`, 상대경로 모듈 소싱, TFC 워크스페이스)와 **실증 서술이 그대로 남아 있다.**
>
> - 본문의 실증 날짜·run ID·"실증됨" 서술은 **이 repo에서 재현된 것이 아니다** —
>   정리본은 [`../reference/poc-findings.md`](../reference/poc-findings.md)를 본다.
> - 설계 판단(리소스 구성·경계·트레이드오프)은 대체로 유효하나, **실행 스택 종속부는 무효**다.
>
> **모듈 이식 시점(D-OSS-STACK §6-2)에 재검토하며 개정한다.** 그 전까지 이 문서를
> "이 repo의 확정 설계"로 인용하지 않는다.

> # 🔶 **2026-08-07 부분 개정 — §1·§4만 개정됐다**
>
> [`23`](23-argocd-self-managed.md)이 요구하는 범위만 열었다. **§0·§2·§3·§5는 손대지 않았다.**
>
> | 절 | 상태 |
> |---|---|
> | **§1** 저장소 호스팅·접근 방식 | ✅ **개정** — D-REPO-CODECONNECTIONS **재판정**(§1.1 신설) |
> | **§4** 부트스트랩 seed | ✅ **개정** — 경로별 분기(§4.1 신설) |
> | §0 · §2 · §3 · §5 | ⚠️ **미개정 유지** — 인용 불가 |
>
> ⛔ **전수 개정하지 않은 것은 의도다.** [`23 §4`](23-argocd-self-managed.md)가 접점을
> **root Application 1지점으로 격리**해 두었으므로, 전수 개정을 선행 조건으로 삼으면
> 필요 없는 일을 먼저 하게 된다.
> ⇒ **이 문서를 인용할 때 절 번호까지 쓴다.** *"30에 따르면"* 은 판정 근거가 못 된다.

> # 🏗️ **현행 구현체 — [`skax-ca/iac-platform-gitops`](https://github.com/skax-ca/iac-platform-gitops)**
>
> 2026-08-07 신설(private · Team `iac`). 이 문서가 설계한 것의 **현행 실물**이다.
> **경로는 self-managed**([`23`](23-argocd-self-managed.md)) — seed 3종(§4.1의 3·4·5단계) 작성 완료,
> ⚠️ **아직 apply 되지 않았다.** `addons/`는 다음 증분.
>
> | 파일 | seed 단계 |
> |---|---|
> | `projects/platform.yaml` | 3 |
> | `clusters/dev/eks-ref-dev-an2-main-01/cluster-secret.yaml` | 4 |
> | `bootstrap/root-app.yaml` | 5 |
>
> **시작값을 좁게 잡았다** — `clusterResourceWhitelist: []` · `sourceRepos`는 이 저장소 하나.
> **addon 증분마다 필요한 것만 연다**(그때마다 리뷰 지점).
> ⚠️ **apply 시 판정할 것 2건**: ① `server: https://kubernetes.default.svc` Secret이 내장
> `in-cluster`를 대체하는지 ② GitHub App 설치 범위에 이 저장소가 포함되는지.

> # 📚 **PoC 구현체 — `silverte/eks-platform-gitops`**
>
> 이 문서가 설계한 것의 **실물**이 있다(2026-07-24~27 증분 B1). 매니페스트 7개 + README.
> ⚠️ **`terraform-enterprise-poc`와 같은 지위다 — 동결 스냅샷이고 고치지 않는다**(CLAUDE.md §0).
> **참조 자산으로만** 쓴다.
>
> ⭐ **설계 문서보다 실물이 빨리 답한 적이 이미 있다**: §4.1의 4단계 오판을 잡은 것이
> 이 저장소의 `addons/aws-load-balancer-controller.yaml`이었다.
>
> | 파일 | 재사용성 |
> |---|---|
> | `projects/platform.yaml` | ⭐ **높음** — `default` 미사용·`clusterResourceWhitelist` 점진 개방·`sourceRepos` 제3 가드레일. ⚠️ `sourceNamespaces: [argocd]`의 *근거*는 관리형 제약이지만, self-managed에서도 **규약으로 유지**한다([`23 §3`](23-argocd-self-managed.md) 갈림점 4) |
> | `bootstrap/root-app.yaml` | ⭐ **높음** — `recurse: true` + `exclude` 패턴 · `prune: false` · finalizer 없음. **경로 무관** |
> | `addons/*.yaml` (ApplicationSet) | ⭐ **높음** — cluster generator + `matchLabels` 팬아웃. **경로 무관** |
> | `clusters/**/cluster-secret.yaml` | 🔶 **구조는 재사용, `server` 값은 갈린다**(§4.1) |
> | `README.md`의 "접근 방식"(CodeConnections) | ⛔ **관리형 전용** — §1.1 재판정 |
> | `repoURL`·클러스터 ARN·`vpcId`·`karpenterNodeRole` | ⛔ **PoC 환경 고유값** — 그대로 복사 금지 |
>
> 🔑 **`{{name}}`이 실제 EKS 클러스터명이어야 한다**는 규약이 특히 값지다 —
> ALBC의 필수 파라미터 `clusterName`으로 그대로 흘러가므로 **별칭을 쓰면 조용히 틀린다.**


> 2026-07-20 신설, 2026-07-20 개정(3계층 소유 모델·addon 3분류·app 영역 범위 정리),
> 2026-07-24 개정(**§4 부트스트랩 확정** — D-SEED-KUBECTL: workbench kubectl seed·자기소멸 원칙·소유 3분할),
> 2026-07-24 실측 반영(workbench kubectl로 hub `argocd` ns 조회) — **§3 전용 `platform` AppProject 결정**
> (`default`가 완전 개방 상태임을 확인), §2.1 cluster Secret `project` 필드 함정, `sourceNamespaces` 필수.
> 2026-07-24 **§1 D-REPO-CODECONNECTIONS 확정** — GitHub private + AWS CodeConnections(장기 자격증명 없음).
> 콘솔 수동 승인 게이트·`repoURL` 결합도 트레이드오프 명시, §4 seed 2단계 갱신.
> 2026-07-24 **증분 B1 구현 반영** — seed 3종을 `silverte/eks-platform-gitops`에 작성하며 확정/정정한 3건:
> §2.1 cluster Secret 이름 규약 정정(별칭 금지 — §2.2 `{{name}}`과의 모순 해소),
> §3 `platform` AppProject 구체값(`clusterResourceWhitelist: []`로 시작),
> §4 root Application 범위·sync 정책(루트 recurse·`prune: false`·finalizer 없음).
> 2026-07-24 **seed 실행** — 3·4·5단계 apply 완료(쓰기·CodeConnections pull 실증), 6단계(reconcile)는
> cluster-wide read 권한 벽에 막힘(D-ARGOCD-CLUSTER-READ, 20 §2.8 신설 열린 항목).
> 2026-07-28 **§0.1 D-CR-OWNERSHIP 신설 + critic 검토 봉합** — 컨트롤러≠CR을 넘어 "CR을 플랫폼(계층 2) vs
> 앱팀(계층 3)이 갖나"를 확정. Karpenter NodePool=계층 2(인프라)·KEDA ScaledObject=계층 3(앱)·Kyverno
> ClusterPolicy=계층 2(가드레일)/네임스페이스 Policy=계층 3(위임). critic(APPROVE with changes) 반영:
> blast radius를 판별 기준→보조 신호로 강등하고 실제 판별자 2개(인프라 정체성·제약 대상) 명문화(C-1),
> namespaced-but-platform(Issuer·SecretStore·Gateway)·cluster-but-app(ClusterTriggerAuthentication) 예외
> 표에 반영(H-1·H-2), 창작 인용을 원문 실측으로 교체(H-3), `default` 개방 구멍·Kyverno `failurePolicy`
> 트레이드오프로 집행 톤 조정(H-4). §5 표 KEDA·Kyverno 등재(설치 경로 TBD)·§2.4 카탈로그 변별자 정정.
> ralplan 합의(D-SPOKE-SEAM, [`20-eks-module.md §2.8`](20-eks-module.md))의 GitOps 쪽 절반이다.
> [`20-eks-module.md §1`](20-eks-module.md)의 Day 0/1↔Day 2 경계에서 **"Day 2 전부 = GitOps(ArgoCD)"**
> 로 넘긴 것 중 **플랫폼 소관**의 저장소 구조를 정의한다. 01-strategy §8 열린 항목 4를 이 문서가 확정한다.

**범위**: 이 문서는 **플랫폼 GitOps 저장소**(이 Terraform repo와 분리된 별도 repo)의 **구조·규약**을
설계한다. 개별 매니페스트의 완성된 내용(AWS Load Balancer Controller values 전체 등)은 구현 단계 소관 — 여기서는
무엇이 어디에 놓이고 어떻게 확장되는지의 **골격과 계약**을 정한다.

**⛔ 범위 밖 (관심사 분리)**: **app 워크로드 GitOps(계층 3, 아래 §0)는 이 프로젝트 범위 밖**이다.
비즈니스 앱의 배포·CICD·레포는 각 앱팀 소관으로, 이 프로젝트는 그 경계(seam)인 **AppProject 가드레일**
(§3)만 정의하고 앱 내용에는 관여하지 않는다. 근거: ArgoCD 공식 best practice(config↔소스 분리, CI 루프·
권한 분리)와 AWS EKS Blueprints(addons 레포 ↔ workloads 레포 분리).

---

## 0. 3계층 소유 모델 (열린 항목 2 확정)

GitOps를 "인프라 vs 앱" 한 덩어리로 다루지 않는다. **소유·변경주기·blast radius가 다른 3계층**으로
가르되, **ArgoCD 허브는 하나로 공유**한다(계층별 ArgoCD 분리 금지 — D-ARGOCD의 N-인스턴스 문제 부활).

| 계층 | 무엇 | 소유 | 위치 | 도구 | 이 프로젝트 |
|------|------|------|------|------|:---:|
| **1. Terraform (Day 0/1)** | 클러스터·baseline addon 6종·IAM·Access Entry | 플랫폼팀 | 이 Terraform repo | Terraform | ✅ 범위 |
| **2. 플랫폼 GitOps (Day 2 platform)** | helm addon·Karpenter NodePool·클러스터 등록·AppProject 가드레일 | 플랫폼팀 | **플랫폼 GitOps repo 1개**(이 문서) | ArgoCD | ✅ 범위 |
| **3. 앱 GitOps (Day 2 apps)** | 비즈니스 워크로드 | **각 앱팀** | **앱팀별 repo N개** | ArgoCD | ⛔ **범위 밖** |

- **분리 근거**: 플랫폼 addon 업그레이드(전 클러스터 영향)와 앱 배포(단일 팀 영향)는 **다른 레포·다른
  리뷰어·다른 CICD·다른 릴리스 주기**여야 실수 하나가 fleet 전체를 흔들지 않는다.
- **레포 전략 확정**: **플랫폼 monorepo(이 저장소) + 앱팀별 repo(범위 밖)** 하이브리드. 앱팀이 실제로
  생길 때 계층 3을 각 팀 repo로 떼어내는 **점진 경로** — PoC(dev 단일)는 계층 1·2만 존재한다.
- **seam은 AppProject**: 계층 2가 소유하는 AppProject의 `sourceRepos`·`destinations`가 "각 앱팀은 자기
  repo에서 자기 namespace로만"을 강제 → 계층 3 레포 분리를 안전하게 만든다(§3).

---

## 0.1 CR 소유 경계 — "컨트롤러≠CR"을 넘어서 (D-CR-OWNERSHIP, 2026-07-28)

> **2026-07-28 critic 검토 반영(APPROVE with changes)**: 초판은 "2축 모델"을 전방위 결정 절차로 제시했으나,
> critic이 (C-1) 축 2가 tier를 뒤집지 못해 사실상 blast-radius 단일 규칙으로 환원되고 (H-1) 그 규칙이
> namespaced-but-platform 반례(§5 cert-manager Issuer 배치)로 무너지며 (H-2) cluster-but-app 반례
> (KEDA `ClusterTriggerAuthentication`)가 누락됐고 (H-3) karpenter.sh·keda.sh **직접인용 2건이 원문에
> 없는 창작**임을 지적. 아래는 그 봉합본이다 — **blast radius를 판별 기준에서 보조 신호로 강등**하고,
> 실제 판별자 2개를 명문화하며, 인용을 원문 실측으로 교체하고, 예외 칸을 표에 채웠다. 세 개별 판정
> (NodePool=계층2·ScaledObject=계층3·Kyverno 분할)은 근거가 견고해 **유지**한다.

§0의 3계층과 §1의 D-ADDON-BOUNDARY(컨트롤러=Terraform addon, 설정 CR=GitOps)는 **컨트롤러와 CR을**
가른다. 그러나 그 다음 질문 — **"그 CR은 플랫폼(계층 2)이 갖나, 앱팀(계층 3)이 갖나"** — 은 열려 있었다.
Karpenter NodePool을 반영하며, 이 경계가 KEDA·Kyverno 도입 **전에** 확정돼야 함이 드러났다.

**❌ 순진한 휴리스틱: "컨트롤러=중앙, CR=분산"** — 직관적이지만 틀린다. **CR이라고 다 같은 CR이 아니다.**
Karpenter NodePool과 KEDA ScaledObject는 둘 다 "컨트롤러가 소비하는 CR"이지만 올바른 소유자가 정반대다.

**❌ "cluster-scoped=플랫폼, namespace-scoped=앱"(blast radius 단일 규칙)도 틀린다** — 반례가 실재한다:
cert-manager `Issuer`는 namespaced인데 §5가 이미 플랫폼(`config/cert-manager/`)에 두고, KEDA
`ClusterTriggerAuthentication`은 cluster-scoped인데 앱 인증에 결합된다. blast radius는 **보조 신호**일 뿐이다.

**✅ 실제 판별 기준 — 두 질문이 tier를 정한다(blast radius는 보조)**:
- **판별 1 (인프라 정체성)**: 이 CR이 **IAM role·비용·용량·발급 신뢰** 같은 인프라 정체성을 인코딩하는가?
  → 그렇다면 **계층 2**, 스코프 무관. (Karpenter EC2NodeClass `spec.role`, ESO `SecretStore` 백엔드 인증,
  cert-manager `Issuer` 발급 신뢰가 여기 해당 — 전부 namespaced일 수 있으나 인프라라 플랫폼.)
- **판별 2 (제약 대상 = 소유자?)**: 이 CR이 **누군가를 제약하는 규칙**인가, 제약 대상이 소유자와 같은가?
  가드레일은 **제약받는 쪽이 소유하면 무의미** → 앱팀을 제약하는 정책은 **계층 2**. (Kyverno ClusterPolicy.)
- **보조 신호 (blast radius)**: 판별 1·2에 걸리지 않으면 대체로 cluster→계층 2, namespace→계층 3. **단 위
  두 판별이 우선**하며 아래 표의 ⚠️예외 칸이 그 증거다.

```
                   워크로드 고유 동작              인프라 / 비용 / 거버넌스
                ┌────────────────────────────┬──────────────────────────────────┐
  namespace-    │  KEDA ScaledObject           │  cert-manager Issuer      ⚠️예외   │
  scoped        │  KEDA TriggerAuthentication  │  ESO SecretStore          ⚠️예외   │
                │  → 계층 3 (앱팀)             │  Gateway (Gateway API)    ⚠️예외   │
                │                              │  → 계층 2 (판별 1이 우선)          │
                ├────────────────────────────┼──────────────────────────────────┤
  cluster-      │  KEDA ClusterTrigger-        │  Karpenter NodePool/EC2NodeClass  │
  scoped        │  Authentication      ⚠️예외  │  Kyverno ClusterPolicy            │
                │  → 계층 2(공유 제공, 아래)   │  → 계층 2 (플랫폼)                 │
                └────────────────────────────┴──────────────────────────────────┘
  ⚠️ blast radius(행)만으로는 tier가 안 정해진다 — ⚠️예외 두 칸이 반례. tier는 판별 1·2가 정한다.
```

**컴포넌트별 판정 (공식 문서 원문 실측 — 창작 인용 금지)**:

| CR | 스코프 | 근거 (원문 실측) | 계층 |
|---|---|---|---|
| **Karpenter** NodePool·EC2NodeClass | cluster | karpenter.sh — NodePool은 "constraints on the nodes that can be created by Karpenter and the pods that can run on those nodes"를 설정(원문 verbatim). EC2NodeClass가 **IAM role**(`spec.role`)·AMI·capacity type을 인코딩 → **판별 1** | **계층 2 (플랫폼)** |
| **KEDA** ScaledObject | namespace | keda.sh — "It allows you to define the Kubernetes Deployment or StatefulSet that you want KEDA to scale based on a scale trigger"(원문 verbatim). 특정 워크로드 결합·앱 고유 트리거 | **계층 3 (앱팀)** |
| **KEDA** TriggerAuthentication | namespace | keda.sh — "defined in one namespace and can only be used by a `ScaledObject` in that same namespace"(원문 verbatim). ScaledObject와 동행 | **계층 3 (앱팀)** |
| **KEDA** ClusterTriggerAuthentication | **cluster** | keda.sh — "global object" that "can be used from any namespace"(원문 verbatim). cluster-scoped인데 앱 인증에 결합 = **예외**(아래 정책) | **계층 2 (공유 제공)** |
| **Kyverno** ClusterPolicy | cluster | kyverno.io — "platform engineers ... deliver secure self-service to application teams"(원문, 생략 인용). 앱팀을 **제약**하는 가드레일 → **판별 2** | **계층 2 (플랫폼/보안)** |
| **Kyverno** 네임스페이스 Policy | namespace | 자기 네임스페이스 리소스에만 적용되는 로컬 규칙 | **계층 3 (위임)** |
| (참조) cert-manager Issuer | namespace | §5가 이미 `config/cert-manager/`(플랫폼)에 배치 — namespaced인데 발급 신뢰(판별 1)라 계층 2. 이 표가 §5와 정합함을 보이는 앵커 | **계층 2 (플랫폼)** |

> **⚠️ Kyverno API 명명 주의 (도입 시 재확인)**: 위 `ClusterPolicy`/`Policy`는 `kyverno.io/v1` API 기준이다.
> Kyverno는 CEL 기반 신 정책 타입(`ValidatingPolicy`·`MutatingPolicy` 등)으로 이동 중이며 공식 nav에서
> `ClusterPolicy`가 "Deprecated"로 표기된다(2026-07-28 실측). 컨트롤러 도입 시점에 신 API로의 스코프 매핑
> (cluster/namespace 구분이 신 타입에서 어떻게 표현되는가)을 재확인한다 — 소유 판정(판별 1·2)은 API 명명과
> 무관하게 유지된다.
>
> **⚠️ ClusterTriggerAuthentication 예외 정책**: cluster-scoped이나 앱 스케일러 인증에 결합돼 "플랫폼이
> 다 쥐면 병목 / 앱이 쥐면 cluster 오브젝트를 앱이 소유"의 딜레마가 있다. **paved road = 앱팀은 namespaced
> `TriggerAuthentication`을 쓰도록 유도**하고, 공유가 불가피한 크레덴셜만 플랫폼이 `ClusterTriggerAuthentication`
> 으로 제공(계층 2). 앱팀 AppProject `clusterResourceWhitelist`에서 이 kind를 빼 앱팀 자작을 차단.

> **⚠️ 순진한 휴리스틱과 어긋나는 두 지점 (사용자 초기 직관 대비 정정)**
> 1. **Karpenter NodePool은 "각 서비스가 관리하는 CR"이 아니다.** ScaledObject처럼 보이지만 IAM role·
>    비용(spot 비중)·용량 상한을 품은 **인프라**다(판별 1). 앱팀에 주면 사실상 노드 IAM 권한 편집권을 주는 셈.
>    앱팀은 NodePool을 **편집하지 않고** 워크로드 스펙(`nodeSelector`·`tolerations`·instance-type·resource
>    requests)으로 NodePool requirements의 **부분집합으로 좁힌다**(karpenter.sh: 파드 요구는 NodePool 요구의
>    범위 안이어야 함). NodePool은 플랫폼이 제공하는 **메뉴**, 워크로드 스펙이 **주문서**다.
>    - ⚠️ taint/label로 워크로드를 managed NG↔Karpenter 노드로 가르는 **계약 어휘 자체는 아직 미확정** —
>      **20 열린 항목 2**(역할 분담)·**30 §2.5(B)**에서 확정 예정. 여기선 소유(플랫폼)만 확정하고 어휘는 위임.
> 2. **Kyverno는 방향이 반대다.** KEDA는 "앱팀이 자기 스케일링을 정한다"지만, 정책엔진의 존재 이유는
>    "앱팀이 못 하게 막는다"이다(판별 2). 제약받는 쪽이 제약을 소유하면 여우에게 닭장을 맡기는 격 →
>    가드레일 ClusterPolicy는 중앙, 자기 네임스페이스에만 미치는 로컬 Policy만 위임한다.

**집행 — soft backstop이지 hard guarantee가 아니다**: 경계는 §3 AppProject가 sync 거부로 **1차** 강제하나 완전하지 않다.
- **(1차 · AppProject)** 앱팀 AppProject `clusterResourceWhitelist`에서 NodePool·ClusterPolicy를 **빼면**
  `resource not permitted in project`로 거부된다(ALBC 배포 때 겪은 §2.2 "제3 가드레일"과 동일 층).
  `sourceRepos`·`destinations`가 "앱팀 repo → 자기 namespace"로 한정 → cluster-scoped 리소스는 애초에 대상 밖.
- **⚠️ 알려진 구멍 — `default` AppProject 개방**: §3(`default`를 쓰지 않는다 블록)이 인정하듯 capability가
  만든 `default` AppProject는 완전 개방(`sourceRepos:['*']`·`clusterResourceWhitelist:[{'*','*'}]`)이며 이를
  막는 정책(Sentinel·admission)은 **확산 단계로 이연**돼 있다. argocd 쓰기 권한자가 `default`에 Application을
  심으면 1차 가드레일을 **우회**할 수 있다 → "기술로 강제"는 이 구멍이 열려 있는 한 완전하지 않다.
- **(2차 · Kyverno admission)** 위 구멍 때문에 Kyverno 백스톱은 **선택이 아니라 필수**다. cluster-scoped kind
  (NodePool·EC2NodeClass·ClusterPolicy)는 **네임스페이스가 없으므로** "앱 ns에서 생성 금지"가 아니라 **요청
  주체(앱팀 ServiceAccount/group) 기준**으로 cluster-wide 생성 요청을 거부한다. 단 트레이드오프: (a) webhook
  `failurePolicy`가 `Fail`이면 Kyverno 장애 시 cluster-wide admission이 막히고, `Ignore`면 그 틈에 우회 허용;
  (b) Kyverno 설치 **이전** 부트스트랩 구간엔 백스톱이 없다. → `default`를 좁히는 Sentinel/admission이
  확산 단계 선결 과제로 남는다(§3 미검증 사항과 동일 계열).
- **네임스페이스 Policy 위임은 안전하다(논거)**: 앱팀에 자기 ns Policy를 위임해도, 앱팀은 이미 자기 ns
  워크로드를 편집할 수 있어 namespaced mutating Policy가 "매니페스트를 직접 고치는 것" 이상의 권한을 주지
  않는다. 보안 임계 통제는 **validating ClusterPolicy(계층 2)**로 커버하며 이는 ns Policy로 우회 불가
  (admission에서 함께 평가·거부 우선). **전제**: 보안 임계 필드는 반드시 validating ClusterPolicy로 덮는다
  (그렇지 않으면 앱이 mutating으로 permissive default를 self-service할 여지).

**paved road 정합(§2.4)**: 플랫폼이 **메뉴를 깔고**(컨트롤러 설치·NodePool 카탈로그·가드레일 ClusterPolicy
라이브러리), 앱팀은 **계약으로 소비**(워크로드 스펙·자기 ScaledObject·네임스페이스 Policy). §2.4의
addon 3분류와 이 CR 소유 경계는 **같은 원칙의 두 표현**이다(전자는 "누가 CRD를 설치하나", 후자는 "누가 CR을 쓰나").

**PoC 함의**: dev 단일·앱팀 0개라 지금 켜야 할 건 계층 2뿐이다. **구조(계층 2 repo·`platform` AppProject
경계)는 이미 있고**, 앱팀 AppProject·계층 3 위임은 앱팀이 실제로 생기는 **stg 도입 시점**에 §3대로 활성화한다
(§2.4 "구현은 미룸"·열린 항목 9 테넌시 확정 시점과 정합). KEDA/Kyverno 컨트롤러 도입 시 판별 1·2가 각 CR을
**1차 분류**한다 — 단 새 CR은 위 ⚠️예외(namespaced-but-platform·cluster-but-app)를 **반드시 점검**한 뒤 확정한다.

**addon 배치 귀결(§5 갱신)**: Kyverno 컨트롤러 = ①baseline(가드레일 ClusterPolicy는 fleet 전역에 필요) ·
KEDA 컨트롤러 = ②catalog(구독 클러스터만, §2.4에 이미 등재). **CR 소유(이 절 주제)와 컨트롤러 설치 도구는
독립**이다 — 설치 경로(Terraform community addon vs GitOps helm)는 도입 시 D-ADDON-BOUNDARY로 재확인하며,
KEDA/Kyverno가 EKS community addon으로 존재하는지 미기록이라 §5 표에 **TBD**로 둔다(Karpenter·ALBC처럼 실측 후 확정).

---

## 1. 저장소 레이아웃 (플랫폼 GitOps repo)

```
platform-gitops-repo/
├── bootstrap/
│   └── root-app.yaml            # App-of-Apps root Application (§4 — workbench kubectl로 seed 후 자기 흡수)
├── clusters/
│   ├── dev/
│   │   └── eks-poc-dev-an2-main-01/   # 클러스터명 디렉토리 — 같은 env에 여러 클러스터 구분(§2.3)
│   │       ├── cluster-secret.yaml    # argocd.argoproj.io/secret-type: cluster, server=<ARN>, labels
│   │       └── values.yaml            # 이 클러스터 고유 helm value(NodePool 형태·상한 등)
│   └── <env>/<cluster-name>/…         # 신규 클러스터 = 이 디렉토리 1개 추가 (O(1))
├── addons/
│   ├── baseline/                # ① 전역 helm addon (§2.4-①) — community addon 부재분만
│   │   ├── aws-load-balancer-controller.yaml  # ApplicationSet(clusters generator) · IAM §2.6a
│   │   └── karpenter.yaml       #   NodePool/NodeClass (IAM 전제는 Terraform §2.6)
│   └── catalog/                 # ② opt-in 카탈로그 (§2.4-②) — 구독한 클러스터만
│       ├── kafka-operator.yaml  #   ApplicationSet(matchLabels: {addon-kafka: enabled})
│       └── keda.yaml            #   〃
├── config/                      # 컨트롤러 설정(CR) — 컨트롤러는 Terraform addon, 설정만 GitOps(§1)
│   └── cert-manager/            #   ClusterIssuer/Issuer (cert-manager 컨트롤러는 Terraform §2.6)
├── projects/                    # AppProject 가드레일(계층 3으로의 seam, §3) — 플랫폼 소유
│   ├── platform.yaml            #   플랫폼팀(ADMIN)
│   └── <team>.yaml              #   앱팀 경계(sourceRepos=앱팀 repo, destinations 제한)
└── (apps/ 없음)                 # ⛔ 앱 워크로드 = 계층 3, 앱팀별 repo, 범위 밖
```
> **cert-manager·external-dns·관측성(fluent-bit·KSM·node-exporter)은 여기 없다** — 컨트롤러가 Terraform
> community addon으로 이동(§1 재개정 D-ADDON-BOUNDARY, 20 §2.6). GitOps에는 그 **설정만** 남는다:
> cert-manager Issuer는 `config/cert-manager/`, external-dns 애노테이션은 앱 Ingress(계층 3, 앱팀 repo).

**확장 규칙 (O(1))**:
- 새 클러스터 = `clusters/<env>/<cluster-name>/` 1개(cluster Secret + values). `addons/`의 ApplicationSet은
  **불변** — cluster generator가 라벨로 자동 팬아웃, valueFiles는 `{{name}}`으로 그 클러스터 값만 소비.
- 새 앱팀 = `projects/<team>.yaml` 가드레일 1개(플랫폼 소유). 앱 워크로드 자체는 **앱팀 repo(범위 밖)**.

### ⭐ 저장소 호스팅·접근 방식 — GitHub private + AWS CodeConnections (2026-07-24 확정, D-REPO-CODECONNECTIONS)

**결정**: 플랫폼 GitOps 저장소는 **GitHub private**으로 두고, ArgoCD의 접근은 **AWS CodeConnections**로 한다.

**Decision driver — 장기 자격증명을 만들지 않는다.** 후보 비교:

| 방식 | 자격증명 | 만료·로테이션 | 저장 위치 |
|---|---|---|---|
| **CodeConnections** ✅ | **없음**(IAM만) | 불필요 | — |
| Secrets Manager + PAT | PAT | **관리 필요** | Secrets Manager |
| Kubernetes Secret + PAT | PAT | 관리 필요 | **클러스터에 평문** |
| public repo | 없음 | — | — (플랫폼 매니페스트가 공개됨) |

seed 경로를 kubectl(IAM 인증)로 정한 것(§4 D-SEED-KUBECTL)과 같은 성격의 선택이다 —
**권한 사슬을 IAM에서 끝낸다.** public repo는 자격증명은 없지만 플랫폼 매니페스트(클러스터 ARN·
네트워크 구조·addon 구성)가 공개되므로 채택하지 않는다.

**구성 3요소**:
1. **커넥션** — `aws_codeconnections_connection`. 소유는 `live/cicd/gitops-hub`(Capability role과 같은 위치).
2. **IAM 가산** — Capability role에 `codeconnections:UseConnection` + `codeconnections:GetConnection`,
   Resource는 **커넥션 ARN으로 한정**(20 §2.7 정정 블록 — "CodeConnections는 추가 정책 불필요"는 오류였다).
3. **`repoURL`** — Repository Secret 불필요(direct integration). URL 자체가 인증 경로다:
   ```
   https://codeconnections.<region>.amazonaws.com/git-http/<account-id>/<region>/<connection-id>/<owner>/<repo>.git
   ```

> **⚠️ 제약 1 — 콘솔 수동 승인이 필수(자동화 불가)**
>
> Terraform provider 원문: *"The `aws_codeconnections_connection` resource is created in the state
> `PENDING`. Authentication with the connection provider must be completed in the **AWS Console**."*
>
> 즉 `apply` → `PENDING` → **사람이 콘솔에서 GitHub 인증 플로우 완료** → `AVAILABLE`.
> TFC apply만으로 끝나지 않는다. TFC의 VCS GitHub App 연결과 **같은 패턴**이다(API 토큰으로 불가,
> 사용자 UI 필요). 관리형 OAuth 핸드셰이크는 사람의 동의를 증명하는 지점이라 의도적으로 API에 열려
> 있지 않다 — 완전 자동화를 목표로 잡지 않는다. 구현 계획에 **수동 게이트로 명시**한다.

> **⚠️ 제약 2 — `repoURL`에 인프라 좌표가 새겨진다(수용한 트레이드오프)**
>
> URL에 `account-id`·`region`·`connection-id`가 하드코딩된다. 결과:
> - **자기소멸 원칙과의 상호작용(§4)**: seed하는 `root-app.yaml`과 저장소에 커밋된 것이 바이트 단위로
>   같아야 하는데, 그 안에 환경 고유값이 들어간다. seed 시점에 URL이 확정되어야 하고 커밋본과 일치해야 한다.
> - **저장소가 AWS 계정에 결합**된다. stg/prd가 별도 계정·리전이면 커넥션도 별도이므로 URL이 달라진다
>   → 환경별로 다른 `repoURL`이 필요하다(kustomize·helm 파라미터화 또는 ApplicationSet 템플릿 변수).
> - **커넥션은 EKS 클러스터와 동일 리전** 필수(공식 제약).
>
> "자격증명을 없애는 대가로 결합도를 얻는" 교환이며, PoC 단계에서는 **자격증명 제거 쪽을 택한다**.
> 다중 계정 확장 시 URL 파라미터화 방식은 구현 단계(증분 B1) 과제로 남긴다.

---

## 1.1 🔴 D-REPO-CODECONNECTIONS **재판정** — 경로마다 갈린다 (2026-08-07)

[`21 §1`](21-gitops-bootstrap-seam.md)(D-GITOPS-SEAM)이 두 경로를 열면서 위 §1의 전제가 깨졌다.
**§1은 관리형 Capability를 전제로 내려진 결정**이었다 — 그 사실이 당시엔 보이지 않았다.

### 무엇이 전제였나

§1의 구성 3요소는 *"Repository Secret 불필요(**direct integration**). URL 자체가 인증 경로"* 이고,
IAM 가산의 주체는 **Capability role**이다. 그런데 그 direct integration은
[`21 §1.2 ⑥`](21-gitops-bootstrap-seam.md)이 인용한 **관리형 전용 기능**이다:

> *"The capability provides **direct integration with AWS services** through the Capability Role's
> IAM permissions. You can reference CodeCommit repositories, ECR Helm charts, and **CodeConnections**
> directly in Application resources **without creating Repository configurations**."*

### 🔴 실측 — self-managed ArgoCD에는 그 경로가 **없다**

`argoproj/argo-cd` **v3.5.0**의 `docs/operator-manual/declarative-setup.md` 전수 검색:

| 검색어 | 결과 |
|---|---|
| `codeconnections` | **0건** |
| `codecommit` | **0건** |
| `awsAuthConfig` | 있음 — 단 **cluster secret 전용**(`clusterName`·`roleARN`·`profile`). repository용이 아니다 |

⇒ **self-managed ArgoCD의 repository 인증은 표준 git 방식뿐이다**:
`username`/`password` · `sshPrivateKey` · **GitHub App**(`githubAppID`·`githubAppInstallationID`·
`githubAppPrivateKey`) · `bearerToken` · `gcpServiceAccountKey`(GCP) · Azure workload identity.

> ### 📌 **재사용할 판단 — "관리형이 준 편의"와 "우리 설계"를 구분한다**
>
> §1은 CodeConnections를 **우리가 고른 것**처럼 서술하지만, 실은 **관리형이 준 것을 쓴 것**이다.
> 그 차이는 경로가 하나일 때는 드러나지 않는다.
> ⇒ **관리형 위에서 내린 결정을 재판정할 때 물을 질문**: *"이건 우리가 고른 것인가,
> 그 서비스가 준 것인가."* 후자라면 다른 경로에서 **선택지 자체가 없을 수 있다.**
> ⭐ [`23 §2.1`](23-argocd-self-managed.md)의 *"upstream이 있다 ≠ 쓸 수 있다"* 와 같은 형태의 함정이다.

### ⭐ 결정 — **경로별로 갈린다**

| 경로 | 저장소 접근 | 자격증명 |
|------|------------|---------|
| **관리형 Capability** | **CodeConnections**(§1 그대로 유효) | **없음**(IAM만) |
| **self-managed** | **GitHub App**(repository Secret) | **private key**(장기) |

**self-managed에서 GitHub App을 고른 근거** (SSH deploy key·PAT 대비):
- **세밀한 권한** — installation을 저장소 단위로 좁힌다. deploy key는 저장소마다 키가 생긴다.
- **사람에 묶이지 않는다** — PAT는 발급자 계정에 묶여 **퇴사·권한 변경으로 끊긴다.**
- ⭐ **이 프로젝트가 이미 GitHub App을 운영한다**(D20 — CI 모듈 소싱, [`50`](50-reference-consumer-repo.md)).
  운영 절차·발급 경험이 이미 있다. CLAUDE.md *"발명하기 전에 찾는다"*.

> ### ⛔ **그렇다고 CI용 App을 재사용하지 않는다 — 별도로 만든다**
>
> D20의 App은 **CI가 `iac-module-library`를 읽는** 주체이고, 이것은 **ArgoCD가 GitOps 저장소를
> 읽는** 주체다. **다른 주체 · 다른 blast radius**다.
> 키를 공유하면 **클러스터 침해가 CI 소싱 권한으로 번진다.**
> ⚠️ 자격증명 공유는 *단순함*이 아니라 **결합**이다 — CLAUDE.md의 *"가장 단순한 형태"* 가
> 옹호하는 대상이 아니다.

> ### 🔴 **§1의 Decision driver를 self-managed는 달성할 수 없다 — 숨기지 않는다**
>
> §1이 든 driver는 *"**장기 자격증명을 만들지 않는다**"* 였다. GitHub App private key는
> **만료가 없는 장기 자격증명**이다. ⇒ self-managed를 택하면 **그 목표를 포기한다.**
> 이것은 [`21 §1.7`](21-gitops-bootstrap-seam.md)에 **없던 6번째 갈림점**이며,
> `21 §1.1`의 탈출 조건을 저울질할 때 **비용에 포함해야 한다.**

> ### ⚠️ **정정 — §1 표의 *"클러스터에 평문"* 은 이 클러스터에 정확하지 않다**
>
> §1 후보 비교표는 `Kubernetes Secret + PAT`를 *"클러스터에 **평문**"* 으로 적었다.
> **실측(2026-08-07)**: 실클러스터 `eks-ref-dev-an2-main-01`의 `encryptionConfig`에
> `resources: ["secrets"]` + KMS `keyArn`이 **붙어 있다** ⇒ **envelope 암호화된다.**
> 🔑 흥미로운 것은 **[`modules/eks-cluster`](../../modules/eks-cluster)의 `.tf`에 `encryption`
> 설정이 한 줄도 없다**는 점이다 — upstream `terraform-aws-modules/eks`가 **기본으로 켠다.**
> ⭐ `D-NODE-ARCH`(2026-08-04, CLAUDE.md 작업 원칙)와 **같은 형태**다:
> *"facade가 안 넘길 뿐 upstream엔 처음부터 있었다."*
> ⇒ 위험도는 *"평문 상주"* 가 아니라 **"KMS로 암호화된 장기 자격증명 상주"** 로 다시 읽는다.
> ⚠️ 그래도 **0은 아니다** — etcd 암호화는 클러스터 내부 탈취(RBAC 우회·노드 침해)를 막지 못한다.

---

## 2. 클러스터 등록 + addon 팬아웃

### 2.1 cluster Secret (등록의 GitOps 절반 — §2.8)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <cluster-name>            # ⚠️ 실제 EKS 클러스터명 (아래 규약 블록 — 별칭 금지)
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    environment: <dev|stg|prd>      # ← matchLabels 선택 키 (필수)
    tier: <nonprd|prd>              # ← 분리 트리거·정책 스코프
    region: <an2|ue1>
    # ② opt-in 카탈로그 구독 라벨(§2.4-②) — 필요한 클러스터만
    addon-kafka: enabled            # (예) 이 클러스터가 Kafka operator 구독
type: Opaque
stringData:
  name: <cluster-name>            # ⚠️ metadata.name과 동일 — ApplicationSet {{name}}의 소스
  server: arn:aws:eks:<region>:<account>:cluster/<cluster-name>   # ⚠️ ARN (API URL 아님, §2.8)
  project: <플랫폼 프로젝트명>     # ⚠️ 아래 함정 블록 — §3의 AppProject 이름과 일치
```

> **⭐ 규약 정정: cluster Secret 이름 = 실제 EKS 클러스터명 (2026-07-24, 증분 B1 구현 중 발견)**
>
> 원안은 `<env>-cluster`(예: `dev-cluster`)였으나 **§2.2와 모순된다.** §2.2의 ApplicationSet은
> cluster generator의 `{{name}}`을 **ALBC의 필수 파라미터 `clusterName`** 으로 넘기는데, 이 값은
> AWS API가 인식하는 실제 클러스터명이어야 한다. `dev-cluster` 같은 별칭을 쓰면 ALBC가 존재하지
> 않는 클러스터명을 받아 기동에 실패한다.
>
> **해소**: `stringData.name`(= ArgoCD가 인식하는 클러스터 이름)을 실제 클러스터명으로 고정한다.
> 라벨 하나를 더 두고 `{{metadata.labels.cluster-name}}`으로 우회하는 대안도 있으나, 같은 값을 두 곳에
> 적으면 표류한다. 부수 효과로 ArgoCD UI의 클러스터 이름이 AWS 콘솔과 일치해 운영자 대조가 쉬워진다.
> `metadata.name`도 같은 값으로 맞춰 파일 하나 안에서 이름이 갈라지지 않게 한다.
>
> **경로 키 정정(2026-07-27)**: 값 파일 경로는 **클러스터명(`{{name}}`)까지** 내려간다 —
> `valueFiles: $values/clusters/{{metadata.labels.environment}}/{{name}}/values.yaml`. 초판은 `environment`
> 라벨까지만 키해 "라벨을 쓰지 이름을 쓰지 않는다"고 적었으나, 그러면 **같은 env의 여러 클러스터가 값 파일
> 하나를 공유**해 클러스터별 NodePool 차별화(§2.5 B)가 불가능하다. env는 디렉토리 그룹핑, `{{name}}`이 개별
> 클러스터 값을 가른다. cluster-secret도 `clusters/<env>/<cluster-name>/`에 함께 둔다.
- `server`는 **EKS 클러스터 ARN** — 관리형 Capability는 ARN으로 클러스터를 식별(kubernetes.default.svc 미지원).
- 라벨은 **Terraform `spoke_clusters` 맵과 동일 소스**여야 한다(§2.8 pre-mortem 3 — 표류 방지). 로컬(dev)
  클러스터도 이 방식으로 명시 등록(§2.8: 자동 등록 안 됨 — 2026-07-24 실측: cluster-type Secret **0건**).

> **⚠️ 함정: `project` 필드가 cluster credential의 사용 범위를 가둔다 (2026-07-24)**
>
> AWS 공식 문서의 등록 예시는 `project: default`다(2026-07-24 재확인). 그런데 ArgoCD에서 `project`가
> **지정된** cluster Secret은 **그 프로젝트에서만 destination으로 쓸 수 있는** project-scoped cluster가
> 된다. 아래 §3에 따라 플랫폼 root App을 전용 `platform` AppProject에 두면, `project: default`인
> cluster Secret은 `platform`에서 **보이지 않아** destination 해석에 실패한다.
>
> 증상이 오해를 부른다 — 라벨·권한·Access Entry는 전부 정상인데 UI에 클러스터가 `unknown`으로 뜨거나
> Application이 destination을 못 찾는다. 원인은 이 한 줄이다.
>
> **규약**: 플랫폼 소유 cluster Secret은 **`project` 필드를 비우거나(전역) 플랫폼 프로젝트명과 일치**
> 시킨다. 앱팀 전용 클러스터를 테넌시로 가둬야 할 때만 의도적으로 특정 프로젝트명을 넣는다.
> 구현 시 §3의 `platform` 프로젝트명과 이 필드의 정합을 반드시 확인한다.

### 2.2 addon ApplicationSet — cluster generator + matchLabels
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: aws-load-balancer-controller
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: dev          # 이 라벨의 클러스터에만 팬아웃
  template:
    metadata: { name: '{{name}}-aws-lbc' }
    spec:
      project: platform
      source:                                                       # 직접 helm-repo source(단일)
        repoURL: https://aws.github.io/eks-charts                   # egress 실측됨(§2.2 note) — vendoring 없음
        chart: aws-load-balancer-controller
        targetRevision: 3.4.2                                       # 버전 핀(실측 최신, app v3.4.2)
        helm:
          parameters:                                               # per-cluster 값은 generator에서
          - { name: clusterName, value: '{{name}}' }                # ALBC 필수 — 대상 클러스터명
          - { name: vpcId, value: '{{metadata.labels.vpcId}}' }     # 각 cluster Secret의 vpcId 라벨(§2.1)
          values: |                                                 # cluster-agnostic inline만
            serviceAccount: { create: true, name: aws-load-balancer-controller }  # Pod Identity 바인딩 대상
            createIngressClassResource: false                       # cluster-scoped IngressClass 미생성(whitelist 최소)
            region: ap-northeast-2                                   # 동일 리전 공유값(cross-region 스포크 시 라벨화)
      destination: { server: '{{server}}', namespace: kube-system } # ALBC 기본 ns
      syncPolicy:
        automated: { prune: true, selfHeal: true }
        syncOptions: [ServerSideApply=true]                         # ALBC CRD가 커서 client-side 한계 회피
```
> **소싱 모델(2026-07-27 확정·배포 실증 반영)**: values는 대부분 cluster-agnostic inline이되, **진짜
> per-cluster 값(vpcId)은 cluster Secret 라벨 → generator parameter**로 끌어온다(`clusterName`과 동일
> 패턴). ApplicationSet은 불변, 새 클러스터 = Secret 1개 추가 O(1). `$values` multi-source(관리형
> capability 지원 미실증)·per-spoke `values.yaml`(§2.3)는 도입하지 않았다.
> - **⚠️ 정정 — region/vpcId는 IMDS 자동 탐지가 안 된다**: 노드 IMDSv2 hop limit=1이라 파드에서 IMDS
>   도달 불가 → ALBC가 `failed to get VPC ID ... ec2imds context deadline exceeded`로 CrashLoop(2026-07-27
>   배포 실증). **명시 주입 필수**. vpcId는 VPC마다 달라 라벨화, region은 동일 리전 공유라 inline
>   (cross-region 스포크 도입 시 라벨화).
>   - **대안 "hop limit=2로 올려 파드 IMDS 자동 탐지" — 검토 후 기각(2026-07-27)**: vpcId 라벨 1줄을
>     없애려고 노드 hop limit을 올리면 그 노드의 **모든 파드가 노드 인스턴스 프로파일(IAM role)을 탈취**
>     가능해진다(파드→노드 권한 상승). 우리는 Pod Identity로 파드별 스코프 크레덴셜을 주는데, hop 상향은
>     그 격리를 클러스터 전체에 걸쳐 되돌린다. 라벨 방식이 O(1)·보안 무변경·노드 무중단이라 우위.
>     ALBC 공식 가이드도 `--aws-vpc-id` 명시 주입을 흔히 권장(런타임 IMDS 의존보다 선언적).
> - **⚠️ AppProject `sourceRepos`는 제3 가드레일**: destinations·clusterResourceWhitelist와 별개로,
>   Application의 source repoURL이 여기 없으면 `InvalidSpecError: repo not permitted in project`로 sync
>   자체가 안 선다(배포 실증). 직접 helm-repo source는 차트 repo(`https://aws.github.io/eks-charts`)도
>   platform AppProject `sourceRepos`에 추가해야 한다.
> - **전파 지연**: AppProject 갱신 후에도 기존 Application은 stale spec 에러를 유지 → 해당 Application에
>   `argocd.argoproj.io/refresh=hard`를 줘야 재평가된다(read 결정의 RBAC 전파 지연과 같은 계열).
> ⚠️ **ALBC는 ALB를 프로비저닝할 IAM 권한이 필요** → 그 role·정책·association은 **Terraform 전제**
> (§2.6a, Pod Identity 모듈 위임 — Karpenter·EBS CSI와 동일 배치). in-cluster 프록시인
> ingress-nginx(retirement/EOL)에서 AWS-native ALBC로 전환하며 이 IAM 전제가 추가된다.
> **Pod Identity라 GitOps는 SA 이름(`aws-load-balancer-controller`)만 맞추면 되고 IRSA 애노테이션 불필요**
> — association(Terraform)이 `(cluster, ns, SA)`를 role에 바인딩한다.

> **⭐ 2026-07-27 실측 — 관리형 ArgoCD repo-server의 public helm egress 확인 (canary)**
> 열린 질문(private 환경에서 repo-server가 `https://aws.github.io/eks-charts`에 닿는가 / ECR 미러링이
> 필요한가)을 workbench kubectl로 canary Application(`project: default`·helm **chart** source·`targetRevision:
> 1.8.1`·**syncPolicy 없음**=비교만)을 심어 실측했다:
> - `status.sync.revision=1.8.1` · rendered resources **14** · `status.conditions` **비어 있음**
>   → repo-server가 차트를 **fetch + helm template 렌더**했다는 직접 증거(연결 실패였다면 rendered 0 +
>   ComparisonError). canary는 삭제(syncPolicy 없어 클러스터 배포 0, 무해).
> - **결론: public helm repo egress 가능 → ECR/OCI 미러링 불필요.** (c)(d)는 public repoURL 직행.
> - **함의(소싱 모델)**: 위 template은 차트를 git-vendored `path`로 소싱하는데(umbrella + `helm
>   dependency` 필요), egress가 확인됐으니 **직접 helm-repo source**(`repoURL: https://aws.github.io/
>   eks-charts` + `chart: aws-load-balancer-controller` + `targetRevision: <핀>`)로 단순화 가능하다 —
>   vendoring·dependency build 없음. per-spoke `values.yaml`을 별도 git에서 겹치려면 **multi-source**
>   (`$values` ref)를 쓴다. **최종 소싱 모델은 (c) 작성 시 확정하고 이 §2.2 template을 갱신**한다.
> - **운영 함정(SSM)**: `AWS-RunShellScript`는 `HOME` 미설정 → kubectl이 `~/.kube/config`를 `/​.kube/
>   config`로 해석해 못 찾고 localhost:8080 폴백. seed/canary 시 `export HOME=/root` +
>   `KUBECONFIG=/root/.kube/config` 필수(sudo가 HOME 바꾸는 40 §6 함정과 같은 계열).

### ⭐ 2026-07-27 Karpenter 증분 — 컨트롤러(OCI helm) + NodePool/EC2NodeClass

Karpenter는 §2.2 ALBC ApplicationSet 패턴을 그대로 쓰되 **세 지점**에서 다르다. 전제조건(컨트롤러
IAM role·노드 IAM role·중단 SQS·Pod Identity association `karpenter`/`kube-system`)은 **Terraform이
이미 완비**(20 §2.6 `module.karpenter`, 실물 확인 2026-07-27). GitOps는 컨트롤러 helm + NodePool/
EC2NodeClass만.

**(1) OCI helm source — registry가 다르다**
- ALBC는 `https://aws.github.io/eks-charts`(HTTP helm repo). Karpenter chart는
  `oci://public.ecr.aws/karpenter/karpenter`(**OCI registry**). ArgoCD source는 scheme 없이
  `repoURL: public.ecr.aws/karpenter` + `chart: karpenter`.
- **`sourceRepos`에 `public.ecr.aws/karpenter/karpenter` 추가**(제3 가드레일 — §2.2 note). egress는
  aws.github.io와 **다른 호스트**라 배포 시 재실측(§2.2 canary와 동종 — 컨트롤러 App이 rendered>0으로
  Synced면 egress OK, ComparisonError면 미러링 검토).
- **버전 핀**: 클러스터 k8s **1.35** → chart **1.13.x** 계열. 근거는 호환성 매트릭스 원문 실측
  (compatibility.md: `1.35 → karpenter >= 1.9`, 최신 계열 `1.13.x`. git 태그 v1.14.0도 Chart.yaml은
  chart `1.13.0`을 담는다 — Karpenter는 마이너 병행 backport라 태그≠chart 버전). 정확 patch는 workbench
  `helm show chart oci://public.ecr.aws/karpenter/karpenter --version <x>` 실측 후 확정(ALBC "실측 핀" 원칙).

**(2) CRD 순서 — Application 2개 분리 + sync-wave**
- Karpenter helm chart는 CRD(`NodePool`·`NodeClaim`·`EC2NodeClass`)를 `crds/`로 함께 설치한다.
  NodePool/EC2NodeClass(CR)는 그 CRD가 **선존재**해야 적용 가능 → ALBC(컨트롤러만, CR은 앱)와 다른
  순서 문제.
- **결정**: `addons/karpenter.yaml` 안에 ApplicationSet **2개**를 둔다(파일 O(1) 유지) —
  ① `{{name}}-karpenter`(컨트롤러 helm, `argocd.argoproj.io/sync-wave: "0"`)와
  ② `{{name}}-karpenter-nodepool`(NodePool+EC2NodeClass plain manifest, `sync-wave: "5"`).
  CR App에 `SkipDryRunOnMissingResource=true`(CRD가 방금 생성된 첫 sync의 dry-run 실패 회피)+
  `ServerSideApply=true` syncOption.
- ②의 매니페스트 소싱은 **git**(플랫폼 monorepo `addons/karpenter/nodepool/`)이라 `sourceRepos`
  CodeConnections URL을 재사용(추가 없음). ①만 OCI repo 추가가 필요하다.

**(3) 값 전달 — cluster Secret label (ALBC vpcId 패턴 그대로, fasttemplate)**
- Karpenter가 필요로 하는 per-cluster 값 대부분은 **클러스터명에서 파생**된다 → cluster Secret에 넘길
  값이 최소화된다:
  - `settings.clusterName` = `{{name}}` (cluster Secret 이름 = 실제 EKS명)
  - `settings.interruptionQueue` = `Karpenter-{{name}}` — Terraform 서브모듈이 SQS를 `Karpenter-<cluster>`로
    명명(실물 `Karpenter-eks-poc-dev-an2-main-01`). 파생.
  - EC2NodeClass subnet/SG `karpenter.sh/discovery` selector 값 = `{{name}}`. 파생.
  - **EC2NodeClass `spec.role`** = `Karpenter-<cluster>-<26자 hash>` — **hash가 파생 불가**한 유일한 값.
- 따라서 cluster Secret(`clusters/dev/<cluster-name>/cluster-secret.yaml`)에 **label 1개**만 추가(ALBC `vpcId`와 동일
  fasttemplate 패턴 — `{{metadata.labels.karpenterNodeRole}}`):
  - `karpenterNodeRole: Karpenter-eks-poc-dev-an2-main-01-af0c2e7263837c83ac8a034a07` (59자 < 63자 label 한도,
    charset `[A-Za-z0-9-]` 유효). 20 outputs 주석은 "annotation으로 소비"라 했으나, 검증된 ALBC label+
    fasttemplate 패턴 일관성을 우선(goTemplate 미도입). **fleet 확장 시 주의**: 클러스터명이 길어져 role
    이름이 63자를 넘으면 그 ApplicationSet만 `goTemplate: true`+annotation으로 전환(가역).

**컨트롤러 helm values (cluster-agnostic inline + generator 주입)**
```yaml
parameters:
- { name: settings.clusterName,       value: '{{name}}' }
- { name: settings.interruptionQueue, value: '{{metadata.annotations.karpenter.eks.poc/interruption-queue}}' }
values: |
  serviceAccount: { create: true, name: karpenter }   # Pod Identity 바인딩(association 기존) — IRSA 애노테이션 불필요
  replicas: 2                                          # leader election HA(ALBC와 동일)
  # 컨트롤러는 managed NG에 떠야 한다(자기 노드를 부트스트랩 못 함). chart 기본 affinity가
  # karpenter.sh/nodepool DoesNotExist라 Karpenter 노드를 회피 → managed NG로 자연 배치(nodeSelector 불필요).
```

**NodePool/EC2NodeClass 스펙 (실전형 spot — 2026-07-27 사용자 결정)**
```yaml
# EC2NodeClass
spec:
  amiSelectorTerms: [{ alias: al2023@latest }]         # k8s 1.35 · AL2023
  role: '{{metadata.annotations.karpenter.eks.poc/node-role}}'   # instance profile은 Karpenter v1이 자체 생성
  subnetSelectorTerms:        [{ tags: { karpenter.sh/discovery: '{{name}}' } }]   # node-uniq(태그 완비 ✅)
  securityGroupSelectorTerms: [{ tags: { karpenter.sh/discovery: '{{name}}' } }]   # ⚠️ Terraform SG 태그 선결(20 열린 항목 4)
# NodePool
spec:
  template:
    spec:
      requirements:
      - { key: karpenter.sh/capacity-type, operator: In, values: [spot, on-demand] }
      - { key: kubernetes.io/arch,         operator: In, values: [amd64] }
      - { key: karpenter.k8s.aws/instance-category,   operator: In, values: [c, m, r] }
      - { key: karpenter.k8s.aws/instance-generation, operator: Gt, values: ['2'] }
  limits: { cpu: '100' }
  disruption: { consolidationPolicy: WhenEmptyOrUnderutilized, consolidateAfter: 30s }
```
> **⚠️ SG discovery 태그 선결(20 열린 항목 4 갭)**: subnet 태그는 node-uniq 그룹에 완비됐으나(실물 확인),
> **노드 SG에는 `karpenter.sh/discovery` 태그가 없다**(실물 확인 2026-07-27 — eks-scale-lab 것만 존재).
> `securityGroupSelectorTerms`가 빈 결과를 내면 Karpenter가 노드에 붙일 SG를 못 찾아 프로비저닝 실패.
> → **modules/eks-cluster의 `node_security_group_tags`로 태그를 부여하고 eks-cluster-dev를 재apply**
> (in-place 태그, 노드 재생성 없음)해야 이 증분이 성립한다. 20 §2.5·열린 항목 4에 반영.
> spot 중단은 Terraform이 만든 중단 SQS를 컨트롤러가 소비(위 `settings.interruptionQueue`)해 graceful 처리.

### 2.3 per-spoke 값 계약 (설계 결정 — 구현 세부 아님)
클러스터별 구성 차이를 넘기는 **단일 계약**을 고정한다:
| 차이 유형 | 전달 수단 |
|---|---|
| 팬아웃 대상 선택 | cluster Secret **라벨** → `matchLabels`/`matchExpressions` |
| 클러스터별 **helm value**(domain·issuer·resource 상한·NodePool 형태) | **`clusters/<env>/<cluster-name>/values.yaml`**(경로 키=`{{name}}`) → 템플릿 `valueFiles`(multi-source, `ignoreMissingValueFiles`) |
| **차트 버전 핀**(`targetRevision`) | cluster Secret **라벨**(소규모) 또는 **채널 라벨**(fleet) → generator `parameters` — §2.5 |
| 소수 동적 키(region·cluster name) | generator **`parameters`** |

> ⚠️ **차트 버전은 valueFiles로 못 바꾼다** — `targetRevision`은 Application **Source 필드**이지 helm value가 아니다.
> `clusters/<env>/<cluster-name>/values.yaml`은 **value**(NodePool 형태·상한 등)만 담당하고, 버전 분기는
> 라벨→parameter로 해석한다(§2.4 채널 라벨과 정합, §2.5 활성화 로드맵). 이 절 초판(2026-07-20)이 버전 핀을 valueFiles로 적은 것은
> 오류였고 §2.5에서 봉합.

이 계약이 있어야 새 클러스터가 O(1) 구조로 붙는다(값 파일 1개 추가, ApplicationSet 불변).
자유로운 임의 override(클러스터마다 ApplicationSet 복제)는 **금지** — O(n) 복붙 회귀.

### 2.4 addon 3분류 — 버전 스큐·팀별 상이 대응 (2026-07-20)
"모든 클러스터가 동일 addon·동일 버전"은 **아니다**. 클러스터는 설치 시점마다 k8s 버전이 다르고
(→ 호환 차트 버전도 다름), 팀·서비스마다 필요한 addon도 다르다. **클러스터 전역(cluster-scoped) 리소스를
설치하는가**가 소유·권한을 가르는 경계다(§2.8 최소권한과 정합 — 앱팀 AppProject는 namespace-scoped라
CRD 설치 불가).

> **먼저 §1 재개정(D-ADDON-BOUNDARY)**: community addon으로 설치 가능한 컨트롤러(cert-manager·external-dns·
> 관측성 3종)는 **GitOps가 아니라 Terraform addon**(20 §2.6). 아래 GitOps 3분류는 **helm-only이거나 GitOps로
> 남긴 것**만 다룬다 — ① 에서 ALBC·Karpenter가 대표.

| 분류 | 예시(GitOps 소관만) | 소유 | 설치 대상 | 메커니즘 | 이 프로젝트 |
|------|------|------|-----------|----------|:---:|
| **① baseline (전역)** | **AWS Load Balancer Controller**(helm)·**Karpenter** NodePool | 플랫폼팀 | 모든 클러스터 | `addons/baseline/`, matchLabels 전체 | ✅ 범위 |
| **② opt-in 카탈로그** | Kafka/Redis operator·KEDA·service mesh — **일부 클러스터만 필요(opt-in)** | 플랫폼팀(차트·버전 큐레이션) | 구독 클러스터만 | `addons/catalog/`, matchLabels `{addon-X: enabled}` — 팀이 라벨로 옵트인 | ✅ 범위(경로) |
| **③ team-scoped** | 앱에 딸린 namespace 한정 리소스·helper chart | **앱팀(셀프서비스)** | 자기 namespace | 앱팀 repo + 자기 AppProject | ⛔ **범위 밖(계층 3)** |

> 컨트롤러가 Terraform addon인 것들의 **설정(CR)**은 GitOps `config/`에 둔다(cert-manager Issuer 등) —
> 컨트롤러≠설정 분리(§1). external-dns 애노테이션은 앱 Ingress(계층 3).

- **버전 스큐 대응**: `clusters/<env>/<cluster-name>/values.yaml`이 "이 클러스터는 k8s 1.35 → AWS LB Controller 차트 X.Y"를
  인코딩(§2.3). 소규모는 이 **values 핀**, fleet 확장 시 **채널 라벨**(`addon-channel: stable|canary` →
  `targetRevision` 해석, 클러스터가 채널 구독 — EKS Blueprints 패턴)로 진화. baseline 6종(Terraform)은
  각 eks-cluster 워크스페이스에서 이미 클러스터별 핀. **활성화 배선의 구체 3메커니즘·순서는 §2.5.**
- **paved road 원칙**: ②는 플랫폼이 "무엇을·어떤 버전으로" 승인(보안·호환성), 팀은 "쓸지" 라벨로 옵트인.
  CRD를 까는 addon을 앱팀이 직접 설치하지 못하는 것은 §2.8 최소권한의 **구조적 귀결**이지 별도 규칙이 아니다.
- **PoC 함의**: dev 단일·팀 미분리라 지금은 ①만 필요. ②(카탈로그)·③(앱팀 셀프서비스)은 팀이 실제로
  상이한 operator를 요구할 때의 확장점 — 경로만 명문화, 구현은 미룸.

### 2.5 멀티클러스터 분기 활성화 로드맵 (2026-07-27 증분)

**문제**: §2.3/§2.4가 규정한 "클러스터별 버전·NodePool 상이"를 현재 구현은 아직 켜지 않았다. ALBC·Karpenter
ApplicationSet은 `targetRevision`을 템플릿에 **하드코딩**(ALBC `3.4.2`·controller `1.13.0`)하고 NodePool은
`default` 1종을 전 클러스터에 동일 렌더한다. 즉 `environment: dev` 라벨을 단 클러스터가 N개면 **전부 같은
버전·같은 NodePool**을 받는다. 이 증분은 §2.3 계약을 **실전 배선**하는 3개 메커니즘과 순서를 확정한다.

**불변 원칙(재확인)**: ApplicationSet은 **cluster-agnostic·불변**, per-cluster 차이는 (a) cluster Secret 라벨
→ generator parameter, (b) `clusters/<env>/<cluster-name>/values.yaml` → `valueFiles`로만 흐른다. 클러스터마다 ApplicationSet을
복제하는 것은 **금지**(§2.3 O(n) 회귀). 아래 3개는 전부 이 이음새의 파생이다.

**(A) 차트 버전 클러스터별 분기 — 라벨→`targetRevision`**
- `targetRevision`은 Source 필드라 valueFiles로 못 바꾼다(§2.3 경고). cluster generator `parameters`로 해석한다.
- **소규모(2~3 클러스터)**: cluster Secret에 버전 라벨을 직접 둔다 — `albcChartVersion: 3.4.2`·
  `karpenterChartVersion: 1.13.0` → `targetRevision: '{{metadata.labels.albcChartVersion}}'`. vpcId와 동일 패턴,
  matrix generator 불필요. k8s 1.35 클러스터는 1.13.0, 1.33 클러스터는 호환 하위 버전 — ApplicationSet 불변.
- **fleet 확장**: 클러스터마다 버전 라벨을 채우는 게 번거로워지면 **채널 라벨**(`addonChannel: stable|canary`)로
  전환 → 채널→버전 매핑을 `goTemplate` 또는 matrix/merge generator로 해석(§2.4·EKS Blueprints 패턴). 채널은
  클러스터 수와 무관하게 O(1)이라 fleet에서 유리하나, 매핑 해석에 `goTemplate: true`가 필요(fasttemplate 한계).
- **트레이드오프**: 직접 버전 라벨은 단순하되 O(클러스터), 채널은 O(1)이되 goTemplate 도입 비용. **2번째
  클러스터에서 직접 라벨로 시작, 4~5개 넘어가면 채널로 승격**(가역).

**(B) NodePool 다양화·클러스터별 — multi-source + `valueFiles`(§2.3 값 계약 실전 배선)**
- 현재 `karpenter-nodeclass` ApplicationSet은 로컬 helm 차트에 `clusterName`·`nodeRole` 2개 parameter만 넘긴다.
  여기에 **multi-source**를 도입해 per-cluster 값 파일을 겹친다:
  - source1 = 플랫폼 monorepo(CodeConnections URL, `ref: values`) — 값 파일 참조 전용(이미 `sourceRepos`에 등재).
  - source2 = 로컬 차트(`path: addons/karpenter/nodeclass`) + `valueFiles: ['$values/clusters/{{metadata.labels.environment}}/{{name}}/values.yaml']`.
- **경로 키는 `{{name}}`(클러스터명)** — env가 아니다. 같은 env에 여러 클러스터가 와도 이름으로 값을 가른다
  (2026-07-27 정정 — 초판은 env까지만 키해 같은 env 클러스터가 값 파일 하나를 공유하는 결함이 있었다).
  디렉토리는 `clusters/<env>/<cluster-name>/`(env는 그룹핑, name이 개별화), cluster-secret도 같은 디렉토리.
- 차트 템플릿을 **`range .Values.nodePools`**(리스트)로 리팩터한다. 각 항목이 자체 `requirements`·`taints`·
  `labels`·`limits`·`disruption`을 갖는다 → dev는 spot general 1종, 다른 클러스터는 **gpu·arm 풀 추가**를 값 파일로만
  선언(⑥). EC2NodeClass도 필요 시 리스트화(예: gpu는 별도 AMI alias).
- **함정 해소**: `$values` 참조 파일이 없으면 sync 에러가 나므로 **두 겹**으로 막는다 — (1) 차트 `values.yaml`에
  **기본 NodePool 세트**(fleet 공통 baseline), (2) source2 helm에 **`ignoreMissingValueFiles: true`**로
  per-cluster 파일을 **선택적 override**로 만든다(파일 부재 시 baseline만으로 성립). 값 계약이 "차트 기본 →
  per-cluster override" 2계층이 된다.
- **root-app 상호작용**: exclude glob을 **`clusters/**/values.yaml`**(depth 무관, ** )로 둔다 — 중첩
  `clusters/<env>/<cluster-name>/values.yaml`까지 제외. cluster-secret.yaml은 제외 대상이 아니라 recurse
  (클러스터 등록 매니페스트). 새 클러스터 값 파일이 자동 포함되므로 root-app 불변(O(1)).

**(C) region 라벨화 — cross-region 스포크(⑤)**
- ALBC의 `region: ap-northeast-2` inline을 vpcId와 동일하게 cluster Secret 라벨(`region`은 이미 있음)→parameter로
  승격한다(현 매니페스트 line 56-57에 예고됨). 동일 리전 스포크면 실효 없지만 cross-region 도입 시 필수.
- **주의**: cluster Secret `server`(EKS ARN)와 IdC·vpce가 이미 cross-region 함정을 안는다(§2.7). region 승격은
  ALBC 값에 국한, 클러스터 등록 자체의 cross-region은 별도(⑤ 본과제).

**순서·실익**:
1. **(B) 먼저** — §2.3 값 계약이 처음 실전 배선되는 지점. NodePool 다양화(⑥)는 **dev 단일 클러스터에서도 실익**이
   있다(GPU/arm 워크로드 수용). B를 하면 A·C·⑤가 "같은 이음새의 반복"이 된다.
2. **(A)·(C)·⑤는 2번째 클러스터(stg) 도입이 실제 트리거** — 단일 클러스터에선 분기 대상이 없어 실익이 없다
   (§2.4 "구현은 미룸"과 정합). 배선만 B와 함께 준비하고 값은 stg에서 채운다.

**연계**: NodePool taint/label로 워크로드를 가르는 전략(어떤 워크로드가 managed NG vs Karpenter 노드에 뜨는가)은
**20 열린 항목 2(managed NG↔Karpenter 역할 분담)** 소관이다. 원칙: 시스템·컨트롤러(Karpenter 자신 포함)는 managed
NG, 앱·버스트 워크로드는 Karpenter 노드 — Karpenter 컨트롤러가 자기 노드를 부트스트랩 못 하는 제약(chart affinity
`karpenter.sh/nodepool DoesNotExist`)이 이 분담을 강제한다. taint 도입 시 시스템 addon에 toleration 선결.

---

## 3. 테넌시 — AppProject (계층 3으로의 seam, 플랫폼 소유)

관리형 ArgoCD는 Application이 단일 namespace라 **네임스페이스 격리 불가** → 테넌시는 **AppProject**로.
AppProject는 **플랫폼팀이 소유하는 가드레일**이며, 그 울타리 안의 **앱 워크로드는 앱팀 repo(계층 3, 범위 밖)**
소관이다. 이 문서는 울타리만 정의한다.
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata: { name: <team>, namespace: argocd }
spec:
  sourceNamespaces: [ argocd ]                        # ⚠️ 필수 — 누락 시 Application이 이 프로젝트를
                                                      #    참조하지 못해 배포 실패(아래 참조)
  sourceRepos: [ '<앱팀 repo>' ]                     # ← 계층 3 seam: 이 팀은 자기 repo에서만
  destinations:                                       # 배포 대상 클러스터·ns 제한
  - { server: 'arn:aws:eks:<region>:<account>:cluster/<c>', namespace: '<team>-*' }
  roles:                                              # IdC 그룹 → project role
  - name: developer
    policies: [ 'p, proj:<team>:developer, applications, sync, <team>/*, allow' ]
    groups: [ '<idc-group-id>' ]
```
> **`sourceNamespaces` 필수 (2026-07-24 실측 반영)**: EKS Capability는 Application·ApplicationSet을
> **capability 네임스페이스 1개**(=`argocd`)에만 둘 수 있고(OSS의 apps-in-any-namespace 미지원),
> AppProject는 이 필드로 "어느 네임스페이스의 Application이 나를 참조할 수 있는가"를 명시해야 한다.
> 누락하면 해당 네임스페이스의 Application이 이 프로젝트를 참조하지 못해 배포가 실패한다.
> 실물 `default` 프로젝트도 `sourceNamespaces: [argocd]`를 갖고 있다.
- **2단 권한 모델**: 글로벌 `rbac_role_mappings`(§2.7 — ADMIN/EDITOR/VIEWER, IdC 그룹) + AppProject
  project roles. 플랫폼팀=ADMIN, 부서 리드=EDITOR(자기 프로젝트 role 셀프서비스), 개발자=VIEWER+role.
- **신규 앱팀 온보딩 = `projects/<team>.yaml` 가드레일 1개**(플랫폼 소유). 앱 워크로드·CICD는 앱팀 repo(범위 밖).
- `sourceRepos`가 계층 3 레포 분리를 안전하게 만드는 핵심 장치 — 앱팀은 승인된 자기 repo에서만 배포.
- **분리(제2 hub) 트리거**(열린 항목 9): prd 완전 격리 확정 / 부서 규제 격리 / 1,000 identity 한도 /
  단일 hub blast radius 수용 불가. 트리거 전엔 분리하지 않는다.

### ⭐ `default` AppProject를 쓰지 않는다 — 전용 `platform` 프로젝트 (2026-07-24 실측 근거)

Capability 생성 시 AWS가 만드는 `default` AppProject는 **완전 개방 상태**다(workbench kubectl 실측):

```yaml
spec:
  sourceRepos:              ['*']                        # 아무 저장소에서
  destinations:             [{namespace: '*', server: '*'}]   # 아무 클러스터·네임스페이스로
  clusterResourceWhitelist: [{group: '*', kind: '*'}]    # 클러스터 스코프 리소스까지
  sourceNamespaces:         [argocd]
```

즉 **`default`에 올라간 Application은 가드레일이 사실상 없다.** 플랫폼 root App(App-of-Apps)을
`default`에 두는 선택은 §3이 세우려는 테넌시 모델을 시작부터 무력화한다 — root App은 이후 모든
플랫폼 리소스를 만들어내는 지점이라 blast radius가 가장 큰 Application이다.

**결정**: 플랫폼 계층 2(root App · addon ApplicationSet · cluster Secret)는 전용 **`platform`
AppProject**에 둔다. `default`는 **사용하지 않는다**(삭제하지 않고 방치 — 아래 근거).

- **`default`를 좁히지 않고 새로 만드는 이유**: `default`는 capability가 생성한 리소스라 우리가
  수정했을 때 되돌리는지(reconcile) **미검증**이다. 검증하려면 쓰기가 필요하다. 전용 프로젝트를
  새로 만들면 이 질문 자체를 피해 간다 — 관리 주체가 겹치지 않는 쪽이 안전하다.
- **`platform` 프로젝트의 가드레일**: `sourceRepos`는 플랫폼 monorepo 1개로, `destinations`는
  등록된 스포크 ARN 목록으로, `clusterResourceWhitelist`는 실제 필요한 것(Namespace·CRD 등)으로
  좁힌다.

> **⭐ 구체값 확정 (2026-07-24, 증분 B1 구현)** — `projects/platform.yaml`
>
> | 필드 | 값 | 근거 |
> |---|---|---|
> | `sourceNamespaces` | `[argocd]` | 필수(위 블록) |
> | `sourceRepos` | 플랫폼 monorepo의 CodeConnections 프록시 URL 1개 | §1 D-REPO-CODECONNECTIONS |
> | `destinations` | `[{server: <dev 클러스터 ARN>, namespace: '*'}]` | 플랫폼 계층은 `kube-system`·`karpenter` 등 시스템 ns에 addon을 배포한다 |
> | `clusterResourceWhitelist` | **`[]` (전면 차단)로 시작** | seed 3종은 전부 namespace 스코프다 |
> | `namespaceResourceWhitelist` | `[{'*','*'}]` | 플랫폼은 관리자 tier |
>
> **`clusterResourceWhitelist: []`로 시작하는 이유**: "실제 필요한 것으로 좁힌다"를 문자 그대로 적용한
> 결과다. 지금 필요한 클러스터 스코프 리소스가 **하나도 없으므로** 빈 목록이 최소권한이다. ALBC의
> ClusterRole·CRD와 Karpenter의 `NodePool`/`EC2NodeClass`가 들어오는 **addon 증분에서 필요한 kind만
> 명시적으로 추가**한다 — 그 시점이 곧 권한 확대의 리뷰 지점이 된다.
>
> ⚠️ 이 선택은 addon 증분에서 **의도된 실패**를 만든다(sync 시 "resource not permitted in project").
> 20 §2.8의 Access Entry ns 스코프 문제와 함께 그 증분의 선결 과제 2건이다.
>
> **⭐ 2026-07-25 개정 (addon 증분 · ALBC) — `clusterResourceWhitelist`를 명시 목록으로 개방**
> 위에서 예고한 "권한 확대의 리뷰 지점"이 도래했다. ALBC 배포를 위해 `[]`(전면 차단) → 아래 kind 목록:
> ```yaml
> clusterResourceWhitelist:
>   - {group: apiextensions.k8s.io,         kind: CustomResourceDefinition}   # targetgroupbindings·ingressclassparams
>   - {group: rbac.authorization.k8s.io,    kind: ClusterRole}
>   - {group: rbac.authorization.k8s.io,    kind: ClusterRoleBinding}
>   - {group: admissionregistration.k8s.io, kind: ValidatingWebhookConfiguration}
>   - {group: admissionregistration.k8s.io, kind: MutatingWebhookConfiguration}
> ```
> - **`*`가 아니라 kind 열거인 이유**: 최소권한 — 지금 필요한 ALBC의 kind만 연다. Karpenter
>   (`NodePool`·`EC2NodeClass`) 등 후속 addon은 각자의 증분에서 추가한다(그때마다 리뷰 지점).
> - **IAM→RBAC 쓰기(20 §2.8 D-ARGOCD-CLUSTER-WRITE)와는 별개 층** — 이 화이트리스트는 ArgoCD project
>   가드레일이고, 저쪽은 apiserver 쓰기 권한이다. **둘 다 열려야** ALBC가 배포된다.
> - **파일 소유**: 별도 repo `eks-platform-gitops`의 `projects/platform.yaml`(root App이 흡수). 이
>   로컬 저장소가 아니다 — 수정 후 root App sync(또는 workbench re-seed)로 반영.
>
> **⭐ 2026-07-27 개정 (Karpenter 증분) — whitelist·sourceRepos 확대**
> 위에서 예고한 "각자의 증분에서 추가"가 Karpenter에 도래. `clusterResourceWhitelist`에 아래 3 kind 추가:
> ```yaml
>   - {group: karpenter.sh,     kind: NodePool}       # 클러스터 스코프
>   - {group: karpenter.sh,     kind: NodeClaim}       # Karpenter가 NodePool로부터 생성(중간 리소스)
>   - {group: karpenter.k8s.aws, kind: EC2NodeClass}   # 클러스터 스코프
> ```
> Karpenter helm이 설치하는 **CRD·ClusterRole/Binding·webhook은 ALBC 증분에서 이미 개방된 kind와
> 동일**(apiextensions·rbac·admissionregistration)이라 추가 불필요 — 재사용된다. `sourceRepos`에는
> OCI 차트 repo `public.ecr.aws/karpenter/karpenter` 1개 추가(§2.2 Karpenter 증분 (1)). NodePool/
> EC2NodeClass는 git(monorepo) 소싱이라 CodeConnections URL 재사용.
- **정합 확인 필수**: cluster Secret의 `project` 필드를 이 프로젝트명과 맞춘다(§2.1 함정 블록).
  둘이 어긋나면 destination 해석에 실패하는데 증상이 원인을 가리키지 않는다.
- **미검증 사항**: `default`를 방치할 때 누군가 실수로 그 프로젝트에 Application을 만들 수 있다.
  이를 막는 정책(Sentinel·admission)은 확산 단계 과제로 남긴다.

---

## 4. 부트스트랩 — root App-of-Apps (§2.8 V1~V3)

**치킨-에그**: cluster Secret이 이 저장소에 있어도, 저장소를 가리키는 **최초 root Application**을 누가
심느냐가 남는다. §2.8 V1~V3로 확정했으며 **2026-07-24 종결**되었다:

- **V1 (NEGATIVE, 2026-07-20)**: `awscc_eks_capability`에 네이티브 seed 필드 없음 → 외부 행위자 필요.
- **V2 (확정, 2026-07-24)**: 외부 행위자 = **workbench의 kubectl**. 관리형 Capability의 등록·앱 정의는
  전부 hub 클러스터 `argocd` 네임스페이스의 CR이고 공식 절차가 `kubectl apply`다.
- **V3 (무의미화)**: seed 수행자가 TFC 러너가 아니므로 러너 도달성 게이트는 성립하지 않는다.

> **⭐ 결정 (D-SEED-KUBECTL)** — 상세 근거·기각된 대안은 [`20-eks-module.md §2.8`](20-eks-module.md).
> ArgoCD API/CLI 경로는 **기각**했다: 관리형 Capability의 CLI 인증은 JWT 토큰뿐이고 발급이 UI를 선행
> 요구해 private 환경에서 새 치킨-에그를 만든다. kubectl 경로는 **IAM(Access Entry)만으로 인증**되어
> 신규 자격증명이 생기지 않는다.

### seed 절차 (수행 지점: workbench, 1회성)

**결정적 순서** — 각 단계가 다음 단계의 전제다:

| # | 단계 | 소유 | 비고 |
|---|------|------|------|
| 1 | Access Entry + access policy | **Terraform** (`live/cicd/gitops-hub`) | hub는 AWS 자동 완비(§2.8 실측 보정 ①). 스포크만 TF |
| 2 | **CodeConnections 커넥션 + IAM 가산** | **Terraform** (`live/cicd/gitops-hub`) | §1 D-REPO-CODECONNECTIONS. **콘솔 수동 승인 게이트 포함**(PENDING→AVAILABLE). Repository Secret은 만들지 않는다 |
| 3 | ✅ **`platform` AppProject** | seed(kubectl) → root App이 흡수 | 2026-07-24 apply 완료. `default`는 쓰지 않는다 |
| 4 | ✅ **cluster Secret**(hub 자신) | seed(kubectl) → root App이 흡수 | 2026-07-24 apply 완료. `project: platform`(§2.1 함정 회피) |
| 5 | ✅ **root Application**(App-of-Apps) | seed(kubectl) → 자기 자신을 흡수 | 2026-07-24 apply 완료 |
| 6 | ✅ 이후 전부 | **GitOps(pull)** | **2026-07-24 완료** — root App `Synced`/`Healthy`, `revision=1d1525b`(실제 SHA). seed 3종 흡수 |

> **⭐ 자기소멸(self-superseding) 원칙 — seed 설계의 핵심**
>
> 3·4에서 손으로 apply하는 매니페스트는 **이 저장소에 커밋된 것과 바이트 단위로 동일**해야 한다.
> 그래야 root App이 첫 sync에서 그 리소스들을 자기 소유로 흡수(adopt)하고 즉시 no-op이 된다.
> seed 산출물은 저장소 콘텐츠의 **사본**이지 별개 아티팩트가 아니다.
>
> 이 원칙이 깨지면(손으로 조금 다르게 적으면) 그 차이가 **영구 드리프트**로 남는다. 따라서
> seed 절차서는 "무엇을 입력하라"가 아니라 **"저장소의 어느 파일을 그대로 apply하라"** 로 쓴다.

**소유 3분할** — "seed 작업 내용을 어디서 관리하는가"에 대한 답:

| 무엇 | 어디 | 왜 |
|---|---|---|
| 매니페스트 **실체** | 이 저장소 `bootstrap/` | root App이 흡수 → 드리프트 0. 위 자기소멸 원칙 |
| 실행 **절차·검증** | `docs/runbooks/` (신설 예정) | 재현성·감사. 기존 런북 관행 |
| 수행 **권한** | Terraform (`live/dev/workbench`·`live/cicd/gitops-hub`) | 이미 보유(ClusterAdmin Access Entry) |

> **Terraform이 seed 산출물을 소유하면 안 되는 이유**: ① cluster Secret·Application은 reconcile되는
> desired-state라 TF가 쥐면 ArgoCD와 드리프트를 다투고 self-heal이 죽는다(D-SPOKE-SEAM). ② TFC SaaS
> 러너는 private apiserver에 도달 불가 — kubernetes provider를 넣어도 plan에서 실패한다. ③ §2.7이
> 구조적으로 소거한 provider가 부활해 격리가 "구조"에서 "규율"로 격하된다. 무엇보다 **TF가 계속
> 소유하면 root App이 흡수할 수 없어 seed의 존재 이유 자체가 사라진다.**

> **⭐ 2026-07-24 seed 실행 완료 — 5단계까지 apply, 6단계(reconcile)는 권한 벽에 막힘**
>
> workbench kubectl로 seed 3종(3·4·5단계)을 실제 apply했다(sha256 바이트 동일성 확인 → server dry-run →
> 순차 apply). 결과:
> - **✅ 3·4·5 apply 성공** — AppProject `platform` · cluster Secret `eks-poc-dev-an2-main-01` ·
>   root Application `root-app` 전부 created. **쓰기 미실증 해소**(아래 미실증 표 갱신).
> - **✅ root App이 저장소를 pull** — `status.sync.revision = main`. CodeConnections 접근 실증
>   (커넥션 `AVAILABLE`이 이 저장소 실제 pull로 이어짐 — 아래 미실증 표 갱신).
> - **✅ 6단계(reconcile) 완료 (2026-07-24 저녁)** — `AmazonEKSAdminViewPolicy` apply + GitHub App
>   설치 범위 조정 후 root App이 `Synced`/`Healthy`, `revision=1d1525b`(실제 커밋 SHA). seed 3종을
>   흡수(adopt)해 conditions가 비었다(에러 없음). GitOps 루프가 실제로 돈다.
>
> > **⭐ 에러가 세 겹으로 벗겨진 진단 궤적** — 각 층이 다음 층을 가리므로 한 번에 하나씩만 보였다:
> > 1. `clusterrolebindings/deployments forbidden` → cluster-wide **read** 부족 → D-ARGOCD-CLUSTER-READ
> >    (`AmazonEKSAdminViewPolicy` association, 20 §2.8)로 해소.
> > 2. `repository not found: ProviderResourceNotFoundException` → CodeConnections **저장소 접근** 부족.
> >    커넥션 `AVAILABLE`은 계정↔GitHub 신뢰일 뿐 — **GitHub App 설치 범위**에 이 저장소를 사람이
> >    추가해야 한다(github.com/settings/installations → AWS Connector → Repository access). 수동 게이트.
> > 3. `Synced` — 두 층 통과 후 흡수 완료.
> >
> > **⚠️ 정정**: seed 직후 `sync.revision=main`을 "CodeConnections pull 성공"으로 본 것은 **성급했다**.
> > `main`은 target revision **설정값**이었고, 당시엔 RBAC 층(read)이 저장소 층(fetch)을 가려 fetch는
> > 시도조차 못 됐다. 실제 pull 성공은 read 벽 해소 **후** `revision=1d1525b`(SHA)로 드러났다.

**미실증(실행 시 확인)** — 2026-07-24 완료:
- ✅ **해소**: workbench kubectl의 `argocd` ns CR apply를 관리형 컨트롤플레인이 반영(저장·조회됨).
- ✅ **해소**: CodeConnections로 저장소 실제 pull(`revision=1d1525b` — GitHub App 설치 범위 추가 후).
- ✅ **해소**: cluster-wide read → reconcile 루프(sync) 정상 — root App `Synced`(D-ARGOCD-CLUSTER-READ).
- ❌ **남음**: `default` AppProject 수정 시 capability reconcile 여부(우회 설계라 당장 불필요, §3).

## 4.1 🔀 seed 절차 — **경로별 분기** (2026-08-07 신설)

위 §4 표는 **관리형 Capability 전제**다. [`23 §2.1`](23-argocd-self-managed.md)이 self-managed
경로를 열었으므로 순서가 갈린다. ⭐ **단계가 하나 늘고 둘 줄어든다.**

| # | 단계 | **관리형** | **self-managed** |
|---|------|-----------|------------------|
| **0** | **ArgoCD 자체 설치** | ⛔ 없음(AWS가 소유) | 🆕 **workbench에서 `helm install`** — [`23 §2.1`](23-argocd-self-managed.md) |
| 1 | Access Entry (hub 자신) | TF — spoke만(§2.8 실측 보정 ①) | ⛔ **불필요** — ArgoCD가 **클러스터 안**에 있다. spoke만 TF |
| 2 | 저장소 접근 | TF — CodeConnections 커넥션 + IAM 가산 | **GitHub App repository Secret**(kubectl seed) — §1.1 |
| 3 | `platform` AppProject | kubectl seed → root App이 흡수 | **동일** |
| 4 | cluster Secret (hub 자신) | kubectl seed — **명시 등록 필수**([`21 §1.2 ⑥`](21-gitops-bootstrap-seam.md)) | ⚠️ **여전히 필요** — 이유가 다르다. 아래 🔴 |
| 5 | root Application | kubectl seed → 자기 자신을 흡수 | **동일** |
| 6 | 이후 전부 | GitOps(pull) | **동일** + ⭐ **argocd chart 자체도 Application으로 흡수** |

> ### 🔑 **갈림의 실질 — "ArgoCD가 클러스터 안에 있는가"**
>
> 1이 self-managed에서 사라지는 이유: **ArgoCD가 클러스터 내부 워크로드**라 자기 apiserver에
> ServiceAccount로 닿는다. 관리형은 **클러스터 밖**에 있어 Access Entry가 필요하다.
> ⇒ [`21 §1.7`](21-gitops-bootstrap-seam.md) 갈림점 1·3이 여기서 **같은 뿌리**임이 드러난다.

> ## 🔴 **정정 — 4단계는 self-managed에서도 사라지지 않는다** (2026-08-07, PoC repo 실물 대조)
>
> 이 절의 초판은 4단계를 *"⛔ 불필요 — `in-cluster`가 기본 제공"* 이라고 적었다. **틀렸다.**
> **연결(등록)** 관점에서만 맞고, **팬아웃** 관점에서는 여전히 필요하다.
>
> **근거 — `silverte/eks-platform-gitops` 실물**(PoC 구현체):
> `addons/aws-load-balancer-controller.yaml`의 ApplicationSet은 **cluster Secret의 라벨**을 읽는다.
>
> ```yaml
> generators:
>   - clusters:
>       selector:
>         matchLabels: {environment: dev}     # ← cluster Secret 라벨
> parameters:
>   - {name: clusterName, value: '{{name}}'}                    # ← Secret 이름
>   - {name: vpcId,       value: '{{metadata.labels.vpcId}}'}   # ← Secret 라벨
> ```
>
> ArgoCD의 내장 `in-cluster`는 **Secret이 없고 따라서 라벨도 없다**. 그대로 두면:
> - `matchLabels`가 매칭되지 않아 **팬아웃이 아예 안 된다**
> - `{{name}}`이 `in-cluster`가 되어 ALBC의 `clusterName`에 **틀린 값이 들어간다** —
>   PoC README가 경고한 *"별칭을 쓰면 그 자리에 틀린 값이 들어간다"* 가 **그대로 발생**한다
>
> ### ⇒ self-managed의 4단계는 **"등록"이 아니라 "라벨과 이름"을 위해 존재한다**
>
> | | 관리형 | self-managed |
> |---|---|---|
> | 4단계 목적 | **연결** + 라벨/이름 | **라벨/이름만** |
> | `server` 값 | EKS 클러스터 **ARN** | **`https://kubernetes.default.svc`** |
>
> **어디에 두는가** — chart에 `configs.clusterCredentials`(라벨 지원, 실측)가 있어 helm values로도
> 되지만, ⛔ **매니페스트로 둔다.** spoke는 *"클러스터 추가 = Secret 매니페스트 1개"* 인데
> hub만 helm values에 두면 **같은 일이 두 곳에서 다르게** 일어난다(D-SPOKE-SEAM의 *cluster Secret =
> GitOps* 도 매니페스트 쪽이다).
>
> ⚠️ **apply 시 확인할 것**: `server: https://kubernetes.default.svc`인 Secret이 내장 `in-cluster`
> 항목을 **대체하는지 / 중복으로 뜨는지**는 argo-cd v3.5.0 문서에 서술이 없다.
> 이 repo는 배포하지 않으므로 **소비 루트가 판정한다**(CLAUDE.md — *"동작한다"의 기준은
> `tofu test` + 예제 `validate`까지*).

> ### 📌 **재사용할 절차 — 설계를 바꾸면 그 설계의 *소비자*를 열어 본다**
>
> 4단계를 지운 판단은 **`21 §1.2 ⑥`의 관리형 서술만 뒤집어 읽은 것**이었다
> (*"관리형은 local cluster를 자동 등록하지 않는다"* → *"self-managed는 자동이니 불필요"*).
> 그 추론은 **연결에 대해서는 맞았고**, 그 Secret을 **누가 소비하는지**를 보지 않아 틀렸다.
> ⇒ **어떤 산출물을 없앤다고 판단하면, 그것을 참조하는 곳을 먼저 grep한다.**
> ⭐ 이번엔 **PoC 구현체 실물**이 그 역할을 했다 — 설계 문서만 봤다면 못 잡았다.

> ### ⭐ **자기소멸 원칙이 helm values에도 적용된다**
>
> §4의 자기소멸(self-superseding) 원칙은 kubectl seed 매니페스트에 대한 것이었는데,
> self-managed에서는 **0단계의 helm values 파일**에도 그대로 걸린다 —
> 6단계에서 ArgoCD가 자기 chart를 Application으로 흡수하기 때문이다.
> ⇒ **`helm install -f`에 넘기는 values는 저장소에 커밋된 그 파일이어야 한다.**
> 손으로 `--set`을 얹으면 그 차이가 **영구 드리프트**로 남는다.
> ⛔ **seed 절차서에 `--set`을 쓰지 않는다.**

⚠️ **2단계는 순서가 다르다** — 관리형은 TF(apply 전)이지만 self-managed는 **kubectl seed**다.
GitHub App private key가 k8s Secret으로 들어가므로 **helm install(0단계) 이후**여야 한다
(`argocd` namespace가 존재해야 한다).

> ### ⛔ **§4 표의 `live/cicd/gitops-hub`는 존재하지 않는 루트다** (2026-08-07)
>
> 위 §4 표는 1·2단계의 소유를 *"Terraform (`live/cicd/gitops-hub`)"* 라고 적지만,
> **[`50` D31](50-reference-consumer-repo.md)이 그 루트를 만들지 않기로 판정했다** —
> self-managed 경로에서 그 루트가 소유할 리소스가 **0개**이기 때문이다
> (ALBC·Karpenter IAM은 이미 `live/dev/eks`가 소유한다).
> ⇒ §4 표의 그 표기는 **PoC 시절 서술**이다. 배포 루트의 SSOT는 `50`이다(D26).
> 📌 재검토 조건(관리형 전환 · 두 번째 클러스터 · ArgoCD의 AWS 접근)은 **D31**이 소유한다.

---

### ⭐ root Application의 범위·sync 정책 확정 (2026-07-24, 증분 B1 구현 — 열린 항목 5 부분 해소)

`bootstrap/root-app.yaml`의 두 결정이 자기소멸 원칙의 성립 여부를 좌우한다.

**① source path = 저장소 루트(`.`) + `recurse: true`** — `bootstrap/`이 아니다.

`bootstrap/`만 가리키면 root App은 **자기 자신만** 흡수하고, seed 3·4단계로 손수 apply한
`projects/platform.yaml`·`clusters/<env>/<cluster-name>/cluster-secret.yaml`은 **주인 없는 리소스로 남아 영구
드리프트**가 된다. seed 3종 전부가 흡수 대상이어야 seed가 소멸한다. 루트를 훑으면 §1의 새 디렉토리
(`addons/`·`config/`)가 늘어도 이 파일이 불변이라는 O(1) 성질도 함께 얻는다.

> **⚠️ 함정 — `directory` 소스는 모든 `.yaml`을 k8s 매니페스트로 파싱한다.**
> §2.3이 규정한 `clusters/<env>/<cluster-name>/values.yaml`은 helm values라 매니페스트가 아니다. 파일이 생기는
> 순간 파싱 에러가 나므로 `directory.exclude: 'clusters/**/values.yaml'`(depth 무관 — 중첩
> `clusters/<env>/<cluster-name>/values.yaml`까지)을 **파일이 없는 시점에 미리** 넣는다. 이후
> `addons/*/charts/` 같은 차트 디렉토리가 생기면 같은 이유로 exclude를 확장한다.

**② `selfHeal: true` · `prune: false`**

- `selfHeal`은 **켠다** — 손으로 바꾼 것을 저장소 상태로 되돌리는, 자기소멸 원칙의 집행 장치다.
- `prune`은 root 레벨에서만 **끈다**. 켜면 저장소 쪽 실수 하나(파일 이동·경로 오타)가 `platform`
  AppProject와 cluster Secret까지 삭제하고, 그 둘이 사라지면 **root App 자신이 destination을 잃어
  복구가 불가능해져 seed를 처음부터 다시 밟아야 한다.** 하위 ApplicationSet에서는 §2.2대로 prune을 켠다.
- 같은 이유로 root Application에 `resources-finalizer.argocd.argoproj.io` **finalizer를 넣지 않는다** —
  root App 삭제가 플랫폼 리소스 전체의 cascade 삭제가 되지 않게 한다.

**③ `targetRevision: main`** — 저장소 기본 브랜치. 태그·릴리스 승격 전략은 stg 도입 시 재검토.

---

## 5. addon 경계 (20-eks-module §1 승계 — 정합 필수)

| addon | 소관 | 비고 |
|---|---|---|
| vpc-cni·coredns·kube-proxy·pod-identity-agent·ebs-csi·metrics-server | **Terraform** (§2.6 baseline) | 이 저장소 아님(계층 1) |
| **fluent-bit·kube-state-metrics·prometheus-node-exporter** | **Terraform** (§2.6 관측성 tier, community addon) | 이 저장소 아님 · §1 재개정(D-ADDON-BOUNDARY) |
| **cert-manager (컨트롤러+CRD)** | **Terraform** (community addon, §2.6) | **컨트롤러 Terraform, Issuer/Certificate CR만 GitOps** `config/cert-manager/` |
| **external-dns (컨트롤러)** | **Terraform** (community addon, §2.6a eks-pod-identity IAM) | **컨트롤러 Terraform, 애노테이션만 GitOps**(앱 Ingress, 계층 3) |
| AWS Load Balancer Controller (ALBC) | **GitOps helm** (①baseline) | community addon **부재** → helm · IAM은 eks-pod-identity 위임(§2.6a) · ingress-nginx(EOL) 대체 |
| Karpenter (컨트롤러 helm + NodePool/NodeClass) | **GitOps** (①baseline) | 컨트롤러 OCI helm(§2.2 증분) + CR. IAM·SQS 전제는 Terraform(§2.6). CRD는 chart 동봉. **NodePool/EC2NodeClass=계층 2**(§0.1 인프라 CR) |
| Kafka/Redis operator | **GitOps** (②catalog) | 구독 클러스터만, 플랫폼 큐레이션 |
| **KEDA** (컨트롤러 + ScaledObject) | 컨트롤러 **TBD**(②catalog, 경로는 D-ADDON-BOUNDARY 실측) | **ScaledObject·TriggerAuthentication=계층 3**(앱팀 repo, 범위 밖)·**ClusterTriggerAuthentication=계층 2 공유** — §0.1 D-CR-OWNERSHIP |
| **Kyverno** (컨트롤러 + 정책) | ✅ **TBD 해소 → GitOps helm · 프로파일 A 한정 baseline** (2026-08-06, **D-POLICY-ENGINE**) | **ClusterPolicy=계층 2**(플랫폼 가드레일 `config/kyverno/`)·**네임스페이스 Policy=계층 3**(위임) — §0.1. API 명명은 kyverno.io/v1 기준(신 CEL 타입 도입 시 재확인) |

> ### 📌 2026-08-06 — 이 표의 TBD 2건에 대한 정합 표시 (**이 문서의 개정이 아니다**)
>
> 이 문서는 [`docs/README.md`](../README.md) 상태표상 **⚠️ 미개정**(PoC 전제 잔존)이라
> **확정 설계로 인용하지 않는다.** 그러나 위 표는 스스로 *"20 §1 승계 — 정합 필수"* 라고 적은
> **파생 표**이고, 원본이 갱신됐는데 여기만 `TBD`로 남으면 다음 사람이 잘못 읽는다.
> 그래서 **결정 내용은 원본에 두고 여기에는 포인터만** 남긴다.
>
> - **Kyverno** — [`20 §1.1` **D-POLICY-ENGINE**](20-eks-module.md)이 확정했다. 경로는 **helm**,
>   ⚠️ **범위는 위 §0.1이 예정한 "①baseline(전 클러스터)"에서 "프로파일 A 한정"으로 좁혀졌다** —
>   프로파일 B에는 제약할 앱팀이 없다는 것이 근거다([`22 §3.2`](22-day2-operations.md)).
>   - 🔴 **`nirmata_kyverno` addon은 실재한다**(`describe-addon-versions` 실측). 그럼에도 helm인
>     이유는 **`owner = aws-marketplace`(구독 전제)** 이며, 부수적으로 **k8s 1.35 호환 버전이 없다**
>     (최신이 1.31까지). 근거 전문과 규칙 공백 보완은 `20 §1.1`이 소유한다.
> - **KEDA** — 실측 결과 **어떤 `owner`에도 KEDA addon이 없다**(community·aws·aws-marketplace 전부).
>   ⇒ 경로는 **helm**으로 확정된다. ⚠️ **②catalog라는 배치는 재확인하지 않았다.** 도입 시
>   Kyverno와 같은 질문(*"어느 프로파일에 필요한가"*)을 먼저 통과시킨다.
>
> ⛔ **이 상자를 근거로 GitOps repo 구조를 확정하지 않는다.** 이 문서 전체의 개정은 별도 작업이다.

> 검증 7(§2.8): 이 표의 GitOps helm 목록(ALBC·Karpenter·②) == 20 §1 "Day 2 GitOps" 행. 컨트롤러가
> Terraform addon인 것(cert-manager·external-dns·관측성)은 GitOps엔 **설정만** 존재. 불일치 시 규약 위반.
> ⚠️ **2026-08-06 기준 이 검증은 Kyverno를 포함해 성립한다** — 20 §1 "Day 2 GitOps" 행에 Kyverno가
> 등재됐고 경로(helm)가 일치한다. 다만 **범위(프로파일 A 한정)는 20 §1 쪽에만 있다.**

---

## 6. 열린 항목 (이 문서 범위 밖)
1. 개별 addon 차트 버전·values 구체값(AWS LB Controller·cert-manager Issuer 등) — 구현 단계.
2. ~~GitOps 저장소 레포 분리 전략~~ **확정(2026-07-20, §0)**: 플랫폼 monorepo + 앱팀별 repo(범위 밖)
   하이브리드. 앱팀 repo의 내부 구조·CICD는 계층 3 소관(이 프로젝트 밖).
3. **② 카탈로그 거버넌스** — 누가·어떤 기준으로 opt-in addon을 카탈로그에 승인·추가하나(보안 리뷰·버전
   지원 정책). 팀 분리 시점에 확정.
4. ~~Karpenter NodePool/NodeClass 스펙(인스턴스 타입·subnet selector 태그)~~ **확정(2026-07-27, §2.2
   Karpenter 증분)**: 컨트롤러 OCI helm(chart 1.13.x) + NodePool(spot 우선 c/m/r gen>2 cpu100) +
   EC2NodeClass(al2023@latest, discovery 태그 selector). SG 태그 갭은 20-eks 열린 항목 4에서 해소.
5. sync wave·health check·PruneLast 등 rollout 정책 — **root Application 몫은 §4에서 확정**
   (루트 recurse·`selfHeal: true`·`prune: false`·finalizer 없음). 남은 것은 하위 ApplicationSet의
   sync wave 순서와 health check — addon 증분에서 결정.
6. secret 관리(External Secrets Operator vs SSM/Secrets Manager) — addon 목록 개정으로 반영.
