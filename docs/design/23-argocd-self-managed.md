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

### 2.3-1 seed 마무리 실행 — **비밀번호 교체는 `--core`로 못 한다** (2026-08-11 실측·완료)

§2.3이 **완료 조건**으로 규정한 seed 마무리를 실행했다. 절차 자체에 함정이 있어 여기 남긴다.

#### 🔴 `ARGOCD_OPTS='--core'` 로는 `argocd account update-password` 가 실패한다

```
rpc error: code = Unknown desc = failed to get issue time: unable to extract token claims
```

argo-cd `server/account/account.go` `UpdatePassword()`:

```go
issuer := session.Iss(ctx)                          // core 모드엔 JWT 클레임이 없어 "" 를 반환
...
if issuer == session.SessionManagerClaimsIssuer {   // "argocd" 와 불일치 → else 로 빠진다
    // 로컬 사용자 경로: 현재 비밀번호 검증
} else {
    iat, err := session.Iat(ctx)                    // util/session/sessionmanager.go:687
    if err != nil {
        return nil, fmt.Errorf("failed to get issue time: %w", err)
    }
```

`Iat()` 는 클레임이 없으면 `errors.New("unable to extract token claims")` 를 낸다.

- 🔑 **`--core` 는 "인증 우회"가 아니라 "인증 부재"다.** CLI 가 argocd-server 를 **우회**해
  kube-apiserver 에 직접 붙으므로 세션 토큰이 아예 없다.
  ⇒ **신원이 필요한 작업(비밀번호·계정·토큰)은 `--core` 로 하지 않는다.**
- ⚠️ 분기 조건이 `issuer != "argocd"` **하나뿐**이라 core 모드가 **"SSO 사용자"로 오분류**된다.
  설계자가 *"argocd 발급 토큰 아니면 SSO"* 로 가정했으나 core 는 **제3의 상태(토큰 없음)** 다 —
  **닫힌 열거가 새 상태를 만난 형태**(CLAUDE.md 「닫힌 열거는 값이 늘 때마다 부채가 된다」).

#### ✅ 정정된 절차 — `--port-forward`(CLI 내장, 별도 `kubectl` 불필요)

`cmd/argocd/commands/login.go:67-74` 가 `--port-forward` 일 때 **SERVER 인자를 요구하지 않고**
`server = "port-forward"` 컨텍스트를 만든다. CLI 가 스스로 터널을 뚫는다.

```bash
export ARGOCD_OPTS='--port-forward --port-forward-namespace argocd --insecure'
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo      # ⛔ 대화형 세션에서만
argocd login --username admin                            # 프롬프트(에코 없음)
argocd account update-password 2>/tmp/argocd-pw.err
```

- ⚠️ **`--insecure`(클라이언트)와 `server.insecure`(서버)는 다르다.** 우리는 후자를 건드리지 않아
  argocd-server 가 자체 서명 TLS 를 한다. 접속 주소가 `localhost:<random>` 이라 CN 이 절대 안 맞으므로
  **클라이언트 검증만** 건너뛴다. 서버 TLS 를 끄는 것이 아니다.
- ⚠️ **`--port-forward` 는 포워더를 CLI 프로세스 안에서 돌린다** → 커넥션 teardown 마다
  `broken pipe` 가 **stderr** 로 쏟아져 프롬프트(**stdout**, `util/cli/cli.go:167`)와 한 줄에 겹친다.
  **실패가 아니다** — `2>` 로 분리한다. 🔑 프롬프트에 서버에서 받아온 `(admin)` 이 찍힌 것이
  **앞 호출이 성공했다는 증거**다(로그 레벨이 아니라 산출물을 본다).
- ⚠️ 새 비밀번호는 **`^.{8,32}$`** 를 만족해야 한다(`common/common.go:145` —
  `argocd-cm.passwordPattern` 미설정 시 기본값).

#### ✅ 완료 판정 (2026-08-11)

| 항목 | 결과 |
|---|---|
| `admin.passwordMtime` | `2026-08-07T06:25:04Z` → **`2026-08-11T06:35:19Z`** |
| `argocd-initial-admin-secret` | **삭제됨** — §2.3 완료 조건 충족 |
| Application 8개 | **전부 `Synced`/`Healthy`** — 교체가 GitOps 에 무영향 |

> ### ⭐ **`selfHeal` 이 비밀번호를 되돌리지 않는다 — 추론이 실물로 닫혔다**
>
> [`30 §2.10.1`](30-gitops-repo.md)이 기록한 대로 차트가 `Secret/argocd-secret` 을 **`data` 없이**
> (메타데이터 + `type: Opaque` 만) 렌더한다. 그래서 argocd-server 가 런타임에 채운 `admin.password` 는
> **ArgoCD 의 소유 필드가 아니다**(`ServerSideDiff=true` 하 SSA 필드 소유권 — [`30 §2.10.6`](30-gitops-repo.md)).
> 교체 후에도 `argocd` Application 이 `Synced` 를 유지한 것이 직접 증거다.

#### 🖥️ 웹 UI 접속 — 2홉 (§2.2 의 실행형)

```bash
# ① workbench (SSM send-command — root 로 돌므로 HOME/KUBECONFIG 를 명시한다)
export HOME=/root KUBECONFIG=/root/.kube/config
setsid nohup kubectl -n argocd port-forward svc/argocd-server 18080:443 \
  --address 127.0.0.1 > /tmp/argocd-pf.log 2>&1 < /dev/null &

# ② 로컬
aws --profile <profile> --region ap-northeast-2 ssm start-session \
  --target <instance-id> --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["18080"],"localPortNumber":["18080"]}'
```

⇒ 브라우저 **https://localhost:18080** (계정 `admin`). 실측: `200` / `{"Version":"v3.5.0"}`.

- 🔑 **두 홉의 이유가 서로 다르다.** 안쪽은 **`ClusterIP` 가 가상 IP** 라서다 — 실재하는 주소가 아니라
  각 **노드**의 kube-proxy 가 iptables/IPVS 로 DNAT 할 뿐이고, 노드가 아닌 workbench 엔 그 룰이 없다.
  바깥쪽은 workbench 에 **인바운드가 0** 이라서다(`modules/workbench/main.tf:43`).
  ⭐ **둘 다 SG 를 열지 않는다** — 기존 인증 채널(kube-apiserver 443 · SSM) 위에 스트림만 얹으므로
  §2.2 의 *"새 인프라 0 · 공개 표면 0"* 이 그대로 유지된다.
- ⛔ **pod IP 직결로 우회하지 않는다.** VPC CNI 라 pod 는 **실제 VPC IP** 를 가져 이론상 도달 가능하지만,
  그 주소는 재스케줄마다 바뀌고(계약이 아니다) SG 두 층을 뚫어야 한다 —
  **재현 불가능한 임시방편**이다(CLAUDE.md 「임시방편으로 넘기지 않는다」).
- ⚠️ **이 두 홉은 인스턴스 교체와 함께 사라진다.** kubeconfig·도구는 [`40 §4.3-1/-2`](40-workbench.md)가
  user_data 로 회수했지만 **port-forward 는 여전히 수동**이다 — §2.2 가 명시한 *"상시 UI 가 아니다"* 의
  대가이고, 앱팀 셀프서비스 요구가 서면 **열린 항목 1**로 돌아간다.

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
| **`helm` CLI** | **`v3.21.3`** | ⛔ **최신은 `v4.2.3`인데 일부러 v3 계열이다** — 아래 |
| helm chart `argo-cd` | **`10.3.0`** (정확 핀) | argo-helm 최신. CLAUDE.md *"커뮤니티 모듈은 정확 핀"* |
| ArgoCD 본체 | `v3.5.0` | chart `appVersion`. **chart가 결정한다 — 따로 핀하지 않는다** |
| `argocd` CLI | **`v3.5.0`** | ⭐ chart appVersion과 **같은 값** → [`40` 열린 항목 7](40-workbench.md)의 핀 근거 |
| k8s 호환 | chart `kubeVersion: ">=1.25.0-0"` | 실클러스터 **1.35** ✅ |

> ### ⭐ **`40` 열린 항목 7의 근거가 여기서 나온다**
> *"어떤 버전을 무슨 용도로 핀하는가"* 의 답: **chart appVersion과 CLI를 같은 값으로 묶는다.**
> 서로 다른 값을 핀하면 *"UI에서 되는데 CLI에서 안 된다"* 를 진단할 근거가 없어진다.
> ⚠️ chart를 올리면 **CLI 핀도 같이 올린다** — CI와 로컬 훅의 도구 버전을 맞추는 것(CLAUDE.md)과 같은 규율이다.

> ### ⛔ **`helm` CLI는 최신(v4)이 아니라 v3 계열을 핀한다** (2026-08-07 신설)
>
> 이 행은 **2026-08-07 seed 실행 때 비어 있었다.** chart·본체·CLI·k8s는 있는데 **정작 §2.1의
> 0단계를 실행하는 도구가 표에 없었다** — 실행자가 그 자리에서 버전을 골라야 했고, 그 근거가
> 어디에도 남지 않을 뻔했다.
>
> **실측**(GitHub Releases API, 2026-08-07): 최신 **`v4.2.3`**(2026-07-09) · v3 계열 최신
> **`v3.21.3`**(같은 날). 즉 v3는 **유기된 계열이 아니라 병행 유지 중**이다.
>
> **v3를 고르는 이유는 chart가 helm 4를 못 쓴다는 근거가 있어서가 아니다** — 그런 근거는 없다.
> 🔑 **최초 부트스트랩에 메이저 CLI 변경을 겹치지 않기 위해서다.** seed가 실패했을 때
> *"chart 문제인가 helm 4 문제인가"* 를 가를 수 없게 되고, 이 절차는 **고객사에서 처음 실행되는
> 순간이 곧 첫 실행**이라 그 모호함의 비용을 우리가 아니라 고객사가 낸다.
> ⇒ 변수를 하나씩만 움직인다. [`04 §3`](../architecture/04-engine-decision.md)이 두 엔진 지원을
> 기각할 때 쓴 것과 같은 셈법이다 — **진단 가능성도 비용 항목이다.**
>
> **재검토 조건**: ① argo-helm chart가 `kubeVersion`처럼 helm 4를 **명시적으로 요구/보증**할 때
> ② v3 계열이 EOL을 선언할 때. 그전까지 *"최신이니까"* 는 올릴 이유가 아니다.
>
> ⚠️ **이 핀에는 아직 강제 장치가 없다.** [`40`](40-workbench.md)의 `helm_version` 변수가
> 유일한 집행 지점인데, 2026-08-07 실측 시점에 소비 repo가 그 값을 **지정하지 않아 helm이 아예
> 없었고** 수동 설치로 때웠다. ⇒ **인스턴스 교체 시 사라진다.**
>
> 🔴 **그리고 그 변수의 설명이 이 결정보다 낡았다** — *"Day 2 운영 프로파일 B(helm 직접 운영,
> [`22 §3`](22-day2-operations.md))에서 쓴다"* 라고 적혀 있으나, **§2.1이 seed를 `helm install`로
> 정한 이상 helm은 프로파일과 무관하게 필수다.** [`40 §0`](40-workbench.md)은 이미
> *"self-managed ArgoCD를 택해도 helm을 돌릴 지점이 필요하다"* 고 예견했는데 **변수 설명만
> 그 이전 세계에 남아 있다.**
> ⇒ 변수 설명 정정은 `.tf` 변경이라 **브랜치 → PR**이다(별도 태스크). 이 문서는 *무엇이 참인지*를
> 소유하고, 모듈은 *그것을 어떻게 집행하는지*를 소유한다.

---

## 6. 열린 항목

1. **앱팀 셀프서비스 시 UI 노출**(§2.2) — port-forward는 운영자 조작용이다. [`30 §0`](30-gitops-repo.md)
   계층 3이 실제로 생기면 internal ALB + Ingress를 다시 검토한다. **지금 만들지 않는다.**
2. **spoke 등록 IAM**(§3 갈림점 3) — 두 번째 클러스터가 생길 때 착수. 이 repo의 **첫 IaC 산출물**이 될 수 있다.
3. ~~**배포 루트 이름·위치**~~ ✅ **해소**(2026-08-07, [`50` D31](50-reference-consumer-repo.md)).
   **결론: 배포 루트를 만들지 않는다.** self-managed 경로가 소유할 IaC 리소스가 **0개**이고
   (§0이 예고한 그대로), D22의 YAGNI 기준이 그대로 적용된다.
   ⭐ **선례**: `workbench`도 자기 설계 문서(`40`)와 모듈이 있지만 별도 루트가 아니라
   `live/dev/eks` 안에 있다 — *"설계 문서가 있다"가 "배포 루트가 필요하다"를 뜻하지 않는다.*
   재검토 조건 3개와 그때 물을 순서는 **D31**이 소유한다.
4. ~~**저장소 접근 방식** — `30 §1`의 CodeConnections 재판정~~
   ✅ **해소**(2026-08-07, [`30 §1.1`](30-gitops-repo.md)). 결론: **self-managed는 GitHub App**이다.
   🔴 **CodeConnections는 선택지조차 아니었다** — argo-cd v3.5.0 문서 전수 검색에서
   `codeconnections`·`codecommit` **0건**. 그것은 관리형 Capability의 *direct integration* 기능이다.
   ⚠️ **대가**: §1의 driver였던 *"장기 자격증명을 만들지 않는다"* 를 **self-managed는 달성할 수 없다.**
   ⇒ 이것이 [`21 §1.7`](21-gitops-bootstrap-seam.md)의 **6번째 갈림점**이다.
5. ~~**seed 절차서의 자리**~~ ✅ **해소**(2026-08-07, 사용자 결정 — *"팀원이 재사용할 수 있도록"*).
   **이 repo가 소유한다**: [`scripts/argocd-seed.sh`](../../scripts/argocd-seed.sh) +
   [`scripts/README.md`](../../scripts/README.md).
   ⚠️ `30 §4`가 예고한 `docs/runbooks/`는 **폐기**했다 — 절차가 **실행 가능한 스크립트**라
   문서 디렉토리가 아니라 `scripts/`가 맞다.
   🔑 **재사용 자산이므로 환경값을 하드코딩하지 않는다**([`01 §4`](../architecture/01-module-strategy.md)) —
   클러스터·저장소·App ID를 전부 파라미터로 받는다. 실행은 소비 프로젝트 몫이다.
