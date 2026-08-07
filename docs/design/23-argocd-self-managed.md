# 23 · self-managed ArgoCD 설계 (helm) — ✅ 확정 (2026-08-07)

> **[`21 §1`](21-gitops-bootstrap-seam.md)(D-GITOPS-SEAM)이 연 두 경로 중 self-managed 쪽**을 채운다.
> 계약면은 **[`21 §1.7`](21-gitops-bootstrap-seam.md)** — 그 표의 *self-managed* 열이 이 문서의 목차다.
>
> ⚠️ **`24-argocd-managed-capability.md`와 대칭이 아닌 것이 정상이다.** `21 §1.7`이 못박았듯
> 두 경로는 같은 층에 있지 않다 — 관리형은 `.tf`를 낳고, **이 문서는 helm 실행 절차를 낳는다**.
> ⛔ **공통부(App-of-Apps·팬아웃·AppProject 테넌시)는 여기 적지 않는다** — [`30`](30-gitops-repo.md)이 소유한다.

## 0. 이 문서가 소유하는 것 / 소유하지 않는 것

| | 내용 |
|---|---|
| **소유** | ① ArgoCD를 **무엇으로 어디서 세우는가**(부트스트랩) ② 사람이 UI/API에 **어떻게 닿는가** ③ 인증 경계 ④ chart values 계약과 **무엇을 켜지 않는가** ⑤ chart·CLI 버전 핀 |
| **소유하지 않음** | GitOps 저장소 구조·App-of-Apps·팬아웃·테넌시(→ [`30`](30-gitops-repo.md)) · 경로 선택 근거(→ [`21 §1`](21-gitops-bootstrap-seam.md)) · workbench 모듈 계약(→ [`40`](40-workbench.md)) · EKS 모듈 계약(→ [`20`](20-eks-module.md)) · 배포 루트 구성(→ [`50`](50-reference-consumer-repo.md)) |

> ### ⭐ **이 문서는 이 repo에 `.tf`를 만들지 않는다**
>
> 산출물은 **설계 + seed 절차 + values 계약**이다. ArgoCD가 지금 요구하는 AWS 리소스는
> **Git 저장소 접근 하나뿐**이고, 그것은 [`30 §1`](30-gitops-repo.md)이 이미 소유한다.
> spoke 접근 IAM은 클러스터가 **둘 이상일 때** 생긴다(현재 dev 단일).
> ⇒ CLAUDE.md *"지금 요구를 채우는 가장 단순한 형태"* — **모듈을 만들지 않는다.**
> 🔑 이것이 `21 §1.7`의 *"두 경로는 같은 층에 있지 않다"* 가 실제로 뜻하는 바다.

---

## 1. 전제 — 이 설계는 대부분 **이미 결정돼 있었다**

착수 시점에 자유도가 있다고 본 갈림점 1(부트스트랩)은, 실은 기존 결정 셋의 **논리적 귀결**이었다.

| # | 이미 있던 결정 | 실측 |
|---|---------------|------|
| 1 | [`20 §3.1`](20-eks-module.md) `endpoint_public_access` 기본 **`false`** | 실클러스터 `endpointPublicAccess: false` · `private: true` |
| 2 | [`40 §1`](40-workbench.md) — *"private-only apiserver는 VPC 내부에서만 도달. **GitHub Actions 공용 runner도 닿지 않는다**"* | — |
| 3 | **D-WORKBENCH-SCOPE**([`40 §2.4`](40-workbench.md)) — workbench를 **self-hosted runner로 겸용하지 않는다** | — |

⇒ **`helm_release`·`kubernetes` provider를 CI apply 경로에 넣을 수 없다.** 도달 지점이 없다.
⇒ helm을 돌릴 수 있는 곳은 **workbench 하나**이고, 거기서는 **사람이** 실행한다
([`22 §3.2`](22-day2-operations.md)가 프로파일 B에 이미 그렇게 정해 두었다).

> ### 🔑 **자유도가 줄어든 것은 좋은 신호다**
> 결정들이 서로 정합하면 새 결정의 자유도가 줄고, 자유도가 줄면 **틀릴 여지도 준다.**
> ⇒ 새 설계를 시작할 때 **먼저 기존 결정이 이미 답을 정해 두었는지** 본다.

---

## 2. 결정

### 2.1 D-ARGOCD-SM-BOOTSTRAP — **workbench seed 1회 + 자기 관리**

> ## ⭐ **helm install은 seed이고, 그 뒤로 ArgoCD가 자기 자신을 관리한다**
>
> 1. **seed(1회)** — workbench에서 사람이 `helm install`. 저장소에 커밋된 values 파일을 **그대로** 쓴다.
> 2. **흡수** — root Application이 `argocd` chart를 **Application으로 흡수**한다.
> 3. **이후** — 업그레이드·values 변경은 **전부 Git → pull**. helm CLI를 다시 쓰지 않는다.
>
> 🔑 이것은 [`30 §4`](30-gitops-repo.md)의 **자기소멸(self-superseding) 원칙을 ArgoCD 자신에게
> 적용한 것**이다. seed 산출물은 저장소 콘텐츠의 **바이트 동일 사본**이어야 하며, 어긋나면
> 그 차이가 **영구 드리프트**로 남는다.
> ⇒ seed 절차서는 *"무엇을 입력하라"* 가 아니라 **"저장소의 어느 파일을 그대로 쓰라"** 로 쓴다.

**배제한 대안 2개 — 검토했고 같은 벽에 막혔다**

| 대안 | 배제 근거 |
|------|----------|
| `helm_release` provider (IaC) | §1의 도달성. CI 러너가 private apiserver에 닿지 않는다 |
| **`aws-ia/eks-blueprints-addons` `enable_argocd`** | **실재한다**(v1.24.3 실측). 그러나 `helm_release` 기반이라 **같은 벽**이다 |

> ### 📌 **"upstream이 있다"와 "upstream을 쓸 수 있다"는 다르다**
>
> CLAUDE.md *"발명하기 전에 찾는다"* 를 이행해 `enable_argocd`를 찾았고, **성숙한 구현이 실재한다.**
> 그럼에도 못 쓰는 이유는 기능이 아니라 **우리 실행 모델(private-only + 공용 runner)** 이다.
> ⇒ **찾은 뒤 우리 제약과 대조하는 것까지가 절차다.** 찾았다는 이유로 채택하면
> *plan은 되는데 apply가 안 되는* 설계가 된다.
> ⚠️ 기록하는 이유는 *"검토 안 했다"* 가 아니라 **"검토했고 도달성 축으로 배제됐다"** 를 남기기 위해서다.

⚠️ **[`30 §4`](30-gitops-repo.md)가 든 *"TF가 seed 산출물을 소유하면 안 되는 이유"* 3개 중 ②는 무효다** —
*"TFC SaaS 러너는 private apiserver에 도달 불가"* 는 TFC 전제다. **①(reconcile 대상을 TF가 쥐면
self-heal이 죽는다)과 ③(격리가 구조에서 규율로 격하)은 유효**하고, 그 둘만으로 결론이 선다.
🔑 스택이 바뀌어도 **근거 ①은 도구 무관**이다 — 그래서 이 결정이 살아남았다.

### 2.2 D-ARGOCD-SM-REACH — **`ClusterIP` 유지 + workbench port-forward**

chart 기본값이 `server.service.type: ClusterIP`다(실측). **바꾸지 않는다.**

```
사람 → SSM 세션 → workbench → kubectl port-forward svc/argocd-server -n argocd
```

- **새 인프라 0 · 공개 표면 0** — [`40`](40-workbench.md)이 만든 도달 지점을 **그대로 재사용**한다.
- `40 §0`이 예견한 그대로다: *"self-managed ArgoCD를 택해도 helm을 돌릴 지점이 필요하다."*

> ### ⚠️ **대가를 숨기지 않는다 — 이것은 상시 UI가 아니다**
>
> port-forward는 **운영자 1인 조작**에 맞고, **앱팀 셀프서비스에는 맞지 않는다.**
> [`30 §0`](30-gitops-repo.md)의 계층 3(앱팀 GitOps)이 실제로 생기면 이 결정은 **다시 물어야 한다**
> (→ 열린 항목 1).
> 🔑 **여기가 관리형과 갈리는 실질 지점이다** — 관리형은 AWS가 `server_url`을 주고
> `network_access.vpce_ids`로 private 접속까지 제공한다([`21 §1.2 ⑦`](21-gitops-bootstrap-seam.md)).
> **self-managed는 그 노출을 우리가 소유한다.** `21 §1.7` 운영축 3(private 도달성)이 이것이다.

⛔ **internal ALB + Ingress는 지금 만들지 않는다.** ACM 인증서·Route53·`global.domain`·SG가
새로 필요하고 **고객사마다 다르다** — 재사용 자산이 고정할 값이 아니다. 요구가 생기면 그때 연다.

### 2.3 D-ARGOCD-SM-AUTH — **seed는 local admin, OIDC는 변수로 개방, dex는 끈다**

| 항목 | 값 | 근거 |
|------|-----|------|
| seed 초기 인증 | **local admin** | 부트스트랩에 IdP 의존을 만들지 않는다 |
| 이후 인증 | `configs.cm.oidc.config`를 **소비자 입력**으로 개방 | ⛔ **고객사 IdP를 하드코딩하지 않는다** — [`01 §4`](../architecture/01-module-strategy.md) 파라미터화 요건 |
| `dex.enabled` | **`false`** (chart 기본은 `true`) | OIDC 직결이면 불필요. **죽은 경로를 남기지 않는다**(CLAUDE.md) |

> ### ⛔ **`argocd-initial-admin-secret`은 seed 절차의 마지막 단계에서 지운다**
> chart는 초기 admin 비밀번호를 그 Secret에 만든다. **비밀번호 교체 후 Secret을 삭제**하는 것까지가
> seed 절차다. 남겨 두면 *"평문에 가까운 관리자 자격증명이 클러스터에 상주"* 한다.
> ⚠️ 이 단계를 절차서의 선택 항목으로 두지 않는다 — **완료 조건**이다.

ℹ️ **IdC를 OIDC IdP로 쓸 수도 있다**(계정에 실재 — [`21 §1.2 ⑨`](21-gitops-bootstrap-seam.md)).
그러나 **기본값으로 삼지 않는다**: self-managed를 택하는 대표 이유가 *IdC 미보유*(탈출 조건 ①)라
기본값이 IdC를 요구하면 **경로의 존재 이유와 모순**된다. 쓰고 싶으면 위 OIDC 변수로 넣는다.

### 2.4 D-ARGOCD-SM-HA — **chart 기본값(단일) + 변수로 개방**

`redis-ha.enabled: false` · controller `replicas: 1`(chart 기본, 실측)을 **그대로 받는다.**

- CLAUDE.md *"지금 요구를 채우는 가장 단순한 형태로 만든다"*. 현재 유일한 실증 환경은 **dev 단일 클러스터**다.
- HA는 `redis-ha.enabled`·각 컴포넌트 `replicas`를 **소비자 값으로 열어 둔다** — 필요해지면 그때 켠다.
- ⚠️ **프로파일 A가 다중 클러스터를 전제한다는 것이 "지금 HA가 필요하다"를 뜻하지 않는다.**
  hub SPOF의 비용은 *"복구까지 pull이 멈춘다"* 이고, **desired state는 Git에 그대로 있다.**

### 2.5 기능 표면 — **무엇을 켜지 않는가**

⭐ 관리형에서는 *"무엇이 지원되지 않나"* 를 확인하는 문제였는데, self-managed에서는 upstream이
전부 열려 있으므로 **"무엇을 켜지 않을 것인가"** 로 뒤집힌다. 여기가 가장 실수하기 쉬운 자리다.

| chart 값 | 기본 | **우리 값** | 근거 |
|---|---|---|---|
| `dex.enabled` | `true` | **`false`** | §2.3 |
| `notifications.enabled` | **`true`** | **`false`** | 요구 없음. 아래 상자 |
| `redis-ha.enabled` | `false` | `false`(유지) | §2.4 |
| `server.service.type` | `ClusterIP` | `ClusterIP`(유지) | §2.2 |
| `crds.install` / `crds.keep` | `true` / `true` | 유지 | 아래 ⚠️ |
| `global.domain` | `argocd.example.com` | ⛔ **소비자 입력** | 예시 도메인을 자산에 남기지 않는다 |

> ### 🔑 **`notifications`를 끄는 것이 모순처럼 보이는 이유와, 모순이 아닌 이유**
>
> [`21 §1.1`](21-gitops-bootstrap-seam.md) 탈출 조건 ②가 **Notifications controller 필요**를
> self-managed로 내려가는 사유로 든다. 그런데 여기서 기본값을 `false`로 둔다 — 모순 같다.
> **아니다**: 탈출 조건은 *"그 기능이 **필요한 고객사**"* 를 가리키고, 그 고객사는 **켠다.**
> baseline이 켜 두는 것과는 다른 질문이다.
> ⇒ **탈출 조건에 쓰인 기능을 baseline에 자동으로 켜지 않는다.** 켜면 쓰지도 않는 컨트롤러가
> 모든 고객사에서 도는 죽은 경로가 된다(CLAUDE.md).
> 📌 이것을 **변수로 확실히 열어 둔다** — 탈출 조건이 실제로 발동한 고객사의 유일한 진입점이다.

> ### ⚠️ **`crds.keep: true` — self-managed에도 잔존물이 있다**
>
> chart를 uninstall해도 **CRD가 남는다**(chart 기본, 실측).
> ⛔ 그래서 *"관리형만 `RETAIN`으로 지저분하게 남는다"* 는 **잘못된 대비**다.
> [`21 §1.2 ⑦`](21-gitops-bootstrap-seam.md)의 RETAIN 경고를 인용할 때 이 사실을 함께 적는다.
> 🔑 차이는 **잔존 여부가 아니라 무엇이 남는가**다 — 관리형은 Capability가 만든 워크로드 전체,
> self-managed는 CRD(그리고 그것이 지키는 CR).

---

## 3. `21 §1.7` 갈림점 — self-managed 열

| # | 갈림점 | 이 문서의 값 |
|---|--------|-------------|
| **1** | 부트스트랩 | **workbench에서 사람이 `helm install`(seed 1회) → 자기 관리**(§2.1) |
| **2** | 인증·RBAC | local admin seed → **OIDC 변수 개방**, `dex` off. `argocd-rbac-cm` 그대로 사용(§2.3) |
| **3** | cluster 등록 | `in-cluster` 기본 제공. spoke는 **D-SPOKE-SEAM 그대로**(IAM grant=IaC · Secret=GitOps) |
| **4** | namespace | **`argocd` 고정**. 자유지만 규약으로 고정해 [`30`](30-gitops-repo.md)의 매니페스트와 맞춘다 |
| **5** | 기능 표면 | §2.5 표 |

⚠️ **갈림점 3은 현재 `in-cluster` 하나뿐이다** — 클러스터가 dev 단일이다. 두 번째 클러스터가
생길 때 spoke 등록 IAM이 처음으로 IaC 산출물을 만든다(→ 열린 항목 2).

---

## 4. [`30`](30-gitops-repo.md)과의 인터페이스 — **접점은 1지점이다**

`30`은 ⚠️ 미개정이다. 이 문서가 그 위에 서면 [`design/AGENTS.md`](AGENTS.md) 개정 규칙 4번이
경고한 실패(개정 전 `40`이 미결정 `21` 위에 서 있던 것)가 재발한다.

> ## ⭐ **인터페이스 선언 — 이 문서가 `30`에 요구하는 것은 이것 하나다**
>
> **seed 마지막 단계에서 apply하는 root Application 매니페스트가 저장소에 존재한다.**
>
> - 그 매니페스트의 **내용·경로·App-of-Apps 구조는 `30`이 소유**한다.
> - 이 문서는 **"그것이 있다"** 만 전제하고, `30`의 본문을 인용하지 않는다.
> - ⇒ **`30` 전수 개정을 이 문서의 선행 조건으로 삼지 않는다.**

*"ArgoCD를 어떻게 세우는가"*(이 문서)와 *"ArgoCD가 무엇을 읽는가"*(`30`)는 다른 질문이고,
**이 한 지점에서만 만난다.** `40`이 `21`에서 떨어져 나온 것과 같은 형태다.

---

## 5. 버전 핀

| 대상 | 핀 | 실측 |
|------|-----|------|
| helm chart `argo-cd` | **`10.3.0`** (정확 핀) | argo-helm 최신. CLAUDE.md *"커뮤니티 모듈은 정확 핀"* |
| ArgoCD 본체 | `v3.5.0` | chart `appVersion`. **chart가 결정한다 — 따로 핀하지 않는다** |
| `argocd` CLI | **`v3.5.0`** | ⭐ chart appVersion과 **같은 값** → [`40` 열린 항목 7](40-workbench.md)의 핀 근거 |
| k8s 호환 | chart `kubeVersion: ">=1.25.0-0"` | 실클러스터 **1.35** ✅ |

> ### ⭐ **`40` 열린 항목 7의 근거가 여기서 나온다**
> *"어떤 버전을 무슨 용도로 핀하는가"* 의 답: **chart appVersion과 CLI를 같은 값으로 묶는다.**
> 서로 다른 값을 핀하면 *"UI에서 되는데 CLI에서 안 된다"* 를 진단할 근거가 없어진다.
> ⚠️ chart를 올리면 **CLI 핀도 같이 올린다** — CI와 로컬 훅의 도구 버전을 맞추는 것(CLAUDE.md)과 같은 규율이다.

---

## 6. 열린 항목

1. **앱팀 셀프서비스 시 UI 노출**(§2.2) — port-forward는 운영자 조작용이다. [`30 §0`](30-gitops-repo.md)
   계층 3이 실제로 생기면 internal ALB + Ingress를 다시 검토한다. **지금 만들지 않는다.**
2. **spoke 등록 IAM**(§3 갈림점 3) — 두 번째 클러스터가 생길 때 착수. 이 repo의 **첫 IaC 산출물**이 될 수 있다.
3. **배포 루트 이름·위치** — 소비 repo는 `live/dev/{networking,eks}`뿐이고 **`live/cicd/`가 없다.**
   [`21 §2.8`](21-gitops-bootstrap-seam.md)의 `live/cicd/gitops-hub`는 **PoC 시절 이름**이고
   [`50`](50-reference-consumer-repo.md)이 채택한 적 없다 — **`50`에서 정한다.**
4. ~~**저장소 접근 방식** — `30 §1`의 CodeConnections 재판정~~
   ✅ **해소**(2026-08-07, [`30 §1.1`](30-gitops-repo.md)). 결론: **self-managed는 GitHub App**이다.
   🔴 **CodeConnections는 선택지조차 아니었다** — argo-cd v3.5.0 문서 전수 검색에서
   `codeconnections`·`codecommit` **0건**. 그것은 관리형 Capability의 *direct integration* 기능이다.
   ⚠️ **대가**: §1의 driver였던 *"장기 자격증명을 만들지 않는다"* 를 **self-managed는 달성할 수 없다.**
   ⇒ 이것이 [`21 §1.7`](21-gitops-bootstrap-seam.md)의 **6번째 갈림점**이다.
5. **seed 절차서의 자리** — `30 §4`는 `docs/runbooks/`(신설 예정)를 가리킨다. 이 repo가 런북을
   소유할지, 소비 repo가 소유할지는 [`50`](50-reference-consumer-repo.md) 소관이다.
