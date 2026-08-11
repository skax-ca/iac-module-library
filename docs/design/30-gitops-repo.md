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

> # 🔶 **부분 개정 상태 — 절 단위로 판정한다** (2026-08-11 갱신)
>
> 전수 개정하지 않는다. **그때 필요한 절만** 연다. 1차(2026-08-07)는 [`23`](23-argocd-self-managed.md)이
> 요구한 §1·§4를, 2차(2026-08-10)는 **addon 증분이 딛는 §2·§3·§5**를 열었다.
> **§2.10 이하는 승계본이 아니라 이 repo에서 새로 쓴 절**이다(2026-08-11) — 인용 제한이 없다.
>
> | 절 | 상태 | 판정을 소유하는 절 |
> |---|---|---|
> | **§0 · §0.1** 3계층 소유 · CR 소유 경계 | ✅ **경로 무관 확정** | [`21 §1.7`](21-gitops-bootstrap-seam.md) *"갈리지 않는 것"* 이 판정. 본문 수정 불필요 |
> | **§1** 저장소 호스팅·접근 방식 | ✅ **개정**(1차) | **§1.1** — D-REPO-CODECONNECTIONS 재판정 |
> | **§2.1~§2.5** 등록·팬아웃·값 계약 | 🔶 **판정만 개정**(2차) | **§2.9** — 승계/갈림 판정. ⚠️ 본문 단독 인용 금지 |
> | **§3** AppProject 테넌시 | 🔶 **판정만 개정**(2차) | **§3.1** — 경로별 구체값 + 선결 과제 재판정 |
> | **§4** 부트스트랩 seed | ✅ **개정**(1차·2차) | **§4.1** 경로별 분기 · **§4.2** D-ROOTAPP-SKIP |
> | **§5** addon 경계 | ✅ **경로 무관 확정**(2차) | §5 말미 상자 — 인용 제한 **해제** |
> | **§2.10** addon 증분 ②③④ + diff 전략 | ✅ **신규 집필**(2026-08-11) | 자기 자신. **§2.10.6 = D-SSDIFF** 가 §2.10.5의 원인 귀인 2건을 **정정**한다 — 둘을 함께 읽는다 |
>
> ⛔ **미개정 본문을 다시 쓰지 않는 것은 의도다.** 기계적 치환은 **역사적 사실을 위조한다** —
> 2026-08-06 workbench 개명에서 실제로 3곳이 그렇게 됐고 되돌려야 했다.
> ⇒ 새 절이 **판정을 소유**하고, 본문은 *"그때 그렇게 정했다"* 의 기록으로 남는다.
>
> 🔑 **`🔶 판정만 개정`의 뜻**: 그 절의 **설계 판단은 인용 가능**하되 **본문 단독으로는 안 된다.**
> 반드시 판정 절과 함께 읽는다 — 본문에는 관리형 전제와 PoC 실증 서술이 남아 있다.
> ⇒ **이 문서를 인용할 때 절 번호까지 쓴다.** *"30에 따르면"* 은 판정 근거가 못 된다.

> # 🏗️ **현행 구현체 — [`skax-ca/iac-platform-gitops`](https://github.com/skax-ca/iac-platform-gitops)**
>
> 2026-08-07 신설(private · Team `iac`). 이 문서가 설계한 것의 **현행 실물**이다.
> **경로는 self-managed**([`23`](23-argocd-self-managed.md)). ✅ **seed 실행 완료(2026-08-07)** —
> root App `Synced Healthy`. `addons/`는 다음 증분.
>
> | 파일 | 역할 | 소유 결정 |
> |---|---|---|
> | `bootstrap/argocd-values.yaml` | seed **0**단계 helm values — 이후 자기 관리의 SSOT | [`23 §2.1`](23-argocd-self-managed.md) |
> | `bootstrap/argocd-seed.sh` | seed 절차 **vendored 사본**(SSOT는 이 repo) | [`40 §2.5`](40-workbench.md) D-WORKBENCH-REPO |
> | `projects/platform.yaml` | seed **3** — AppProject 가드레일 | §3 · **§3.1** |
> | `clusters/dev/eks-ref-dev-an2-main-01/cluster-secret.yaml` | seed **4** — 라벨과 이름 | §2.1 · **§4.1** |
> | `bootstrap/root-app.yaml` | seed **5** — 자기 자신을 흡수 | §4 |
>
> **시작값을 좁게 잡았다** — `clusterResourceWhitelist: []` · `sourceRepos`는 이 저장소 하나.
> **addon 증분마다 필요한 것만 연다**(그때마다 리뷰 지점 — **§3.1**이 그 목록을 소유).
>
> ### ✅ **apply 판정 3건 전부 종결**
>
> | 판정 | 결과 | 시점 |
> |---|---|---|
> | ① root App이 저장소 HEAD를 읽었는가 | ✅ `sync.revision`이 **실제 SHA** = HEAD 일치(`main` 아님) ⇒ **자기소멸 원칙이 작동**했다 | 2026-08-07 |
> | ② GitHub App 설치 범위 | ✅ `GET /installation/repositories` → `total_count=1`, 이 저장소 하나 | 2026-08-07 |
> | ③ `server: https://kubernetes.default.svc` Secret이 내장 `in-cluster`를 **대체**하는가 | ✅ **대체한다 — 중복이 아니다.** `argocd admin cluster stats -n argocd` → 서버 항목 **1개**(Successful · apps 1 · resources 536) | 2026-08-10 |
>
> > **③은 두 번에 걸쳐 닫혔다.** 2026-08-07엔 `kubectl`만 있어 *"해석은 된다"* 까지만 봤고
> > (Secret 1개 + root App `Synced`), *"대체인가 중복인가"* 는 못 봤다. `argocd` CLI가
> > workbench에 들어온 뒤([`40 §7.3-4`](40-workbench.md)) 닫혔다.
> > 🔑 **`argocd admin`은 API 서버가 아니라 k8s를 직접 읽는다** — `argocd login`도, 초기 비밀번호
> > 조회도 없이 판정할 수 있었던 이유다. **읽기 판정에 로그인을 전제하지 않는다.**

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
>
> **— 이 repo 이관 후 —**
> 2026-08-07 **1차 부분 개정** — §1.1(D-REPO-CODECONNECTIONS 재판정: 경로마다 갈린다) · §4.1(seed 경로별 분기,
> 4단계 자기 정정) 신설. §1에 `argocd-seed.sh` vendoring 포인터 상자.
> 2026-08-10 **2차 부분 개정 — addon 증분 착수 조건** — **§2.9 신설**(§2.1~§2.5의 승계/갈림 판정 ·
> egress 실증 비승계 · 버전 핀 비승계) · **§3.1 신설**(`platform` AppProject 경로별 구체값 +
> ⭐ **선결 과제 2건 재판정 → 1건**: self-managed는 chart가 cluster-admin ClusterRole을 주므로
> D-ARGOCD-CLUSTER-READ/WRITE 벽이 성립하지 않는다. 남은 `clusterResourceWhitelist`는 증분과
> 같은 PR에서 여는 것이라 **착수를 막지 않는다**) · §5 인용 제한 해제 · 헤더 상태 상자 갱신
> (seed apply 완료 + 판정 3건 종결 반영 — **"아직 apply 되지 않았다"가 stale이었다**).
> 2026-08-10 **§2.9에 실계정 판정 추가** — **egress canary 3호스트 전부 통과**(ALBC·argo-helm·
> Karpenter OCI, 배포 0으로 확인 후 삭제) · 차트 핀 실측(`3.5.0`·`1.14.0`) ·
> ⭐ **판독법 정정**: *"연결 실패 = rendered 0 + ComparisonError"* 는 불충분하고 **1차 신호는
> `revision` 해석 여부**다(Karpenter가 그 형태였으나 원인은 values 누락이었다) ·
> OCI가 repository 등록 없이 동작 · `default` AppProject 실측(self-managed도 완전 개방,
> 단 `sourceNamespaces` 필드 없음).
> 2026-08-10 **§2.9에 ⭐ D-ADDON-NS 신설**(사용자 결정) — *"계층 2 addon은 **전용 네임스페이스를
> 신설**한다. 예외는 **ALBC·Karpenter → `kube-system`** 둘뿐"*. 예외 근거를 공식 문서 리서치로
> 세 겹(Karpenter **APF FlowSchema** 기술 근거 · ALBC AWS/upstream 공식 · Pod Identity association)
> 으로 세우고, **반증된 논거**(`system-cluster-critical`의 `kube-system` 전용 제약 — 실측상 **없다**)를
> 명시적으로 폐기했다. 함께: NodePool 아키텍처는 managed NG를 따라간다(§2.2의 `amd64`는 PoC의 x86 값,
> 현행은 **Graviton**). 🔑 둘 다 **계층 1이 정해 둔 값을 계층 2가 다시 고르려다** 생기는 같은 형태다.
> 2026-08-10 **§4.2 신설 — D-ROOTAPP-SKIP** — 증분 ① 머지가 root App을 **두 번 깨뜨린** 기록.
> ① `exclude` 확장이 **자기소멸 데드락**을 만들었다(spec 변경과 그 spec이 있어야 읽는 파일을 같은
> 커밋에 넣을 수 없다) ② 마커로 바꾸며 **마커를 설명하는 주석까지 마커로 작동**해 root App이
> 자기 자신을 스캔에서 제외했다. ⭐ **`prune: false`(§4)가 root App의 자기 삭제를 막았다** —
> 방어 결정이 값을 회수한 순간. ⇒ **증분 ① apply 판정 완료**(§2.9 말미).

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

> ### 📌 **`bootstrap/`에 `argocd-seed.sh` 사본이 추가된다** — 결정은 [`40 §2.5`](40-workbench.md)가 소유 (2026-08-07)
>
> ⚠️ **위 트리는 미개정 구역이라 고치지 않는다.** 여기엔 사실과 포인터만 둔다
> (`30 §5`에서 이미 쓴 방식 — 결정을 미개정 본문에 쓰면 *어디까지가 PoC 전제인지* 판정 불가능해진다).
>
> **왜 생기나**: self-managed 경로에서 seed는 workbench가 실행하는데, workbench는 SSM 전용이라
> `scp`가 없고 **private 저장소 두 개**(GitOps · `iac-module-library`)에 닿아야 한다.
> **D-WORKBENCH-REPO**는 GitHub App installation token으로 **GitOps 저장소만** 클론하고,
> `argocd-seed.sh`의 **핀된 사본을 `bootstrap/`에 vendoring**하기로 했다 —
> ⇒ **클론 한 번으로 매니페스트와 실행 절차가 함께 온다.**
>
> - **SSOT는 `iac-module-library`가 유지**한다([`23 §6-5`](23-argocd-self-managed.md)). **사본은 편집하지 않는다** —
>   고치는 곳이 하나면 사본이 여럿이어도 SSOT는 하나다(vendoring이지 경쟁 SSOT가 아니다).
> - 사본 헤더에 **출처 태그**를 적는다.
> - ⛔ **이 App의 설치 범위에 `iac-module-library`를 추가하지 않는다** — 그러면 ArgoCD가 모듈 소스까지
>   읽게 되어 접근 집합이 실제로 늘어난다([`§1.1`](#11--d-repo-codeconnections-재판정--경로마다-갈린다-2026-08-07)의 기준).
> - ⚠️ **관리형 경로에는 이 항목이 없다** — seed 자체가 없다.
>
> 🔁 `bootstrap/`은 [§4](#4-부트스트랩)가 소유하므로, 사본의 **파일명·갱신 절차**가 정해지면 그쪽에 적는다.

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
  📌 **self-managed는 `https://kubernetes.default.svc`다**(§4.1 정정 · §2.9 갈림점 1). 나머지 필드·라벨 규약은 공통.
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
> 📌 **이 선결 과제는 해소됐다**(2026-08-10 확인 — §2.9 말미 상자). `modules/eks-cluster`가
> `enable_karpenter`일 때 `node_security_group_tags`로 태그를 부여하고 테스트가 assert한다.
> 아래는 그때의 갭 기록이다.
>
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

> ### 🔄 **분류 현황 갱신 (2026-08-11, §2.10)**
>
> | 분류 | 실물 | 상태 |
> |---|---|---|
> | ① baseline | ALBC · Karpenter(+NodePool) | ✅ 배포됨(증분 ①) |
> | ① baseline | **Kyverno + PSS 정책** | 🆕 증분 ③ — **사용자 결정**: 정책 엔진은 가드레일이고 **옵트인 가드레일은 가드레일이 아니다** |
> | ② 카탈로그 | **KEDA** | 🆕 증분 ④ — 이 표가 예시로 든 그 KEDA다. **`addons/catalog/` 경로가 처음 실물이 된다** |
> | ③ team-scoped | — | ⛔ 여전히 범위 밖(계층 3) |
>
> ⇒ *"②는 경로만 명문화, 구현은 미룸"* 은 **증분 ④로 해소된다.** ⚠️ ③(앱팀 셀프서비스)에는 해당하지 않는다.

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

## 2.9 🔀 addon 증분 — **경로별 분기** (2026-08-10 신설)

§4.1이 seed 절차에 대해 한 일을 **addon 팬아웃**에 대해 한다. §2.1~§2.5 본문은 **관리형 Capability
전제**이므로, 무엇이 승계되고 무엇이 갈리는지를 여기서 한 번만 판정한다.

> ### ⚠️ **번호가 §2.6이 아닌 이유 — 그 자리는 이미 점유돼 있다**
>
> 이 문서 본문의 `§2.6`(9곳)·`§2.6a`(4곳)·`§2.7`(4곳)·`§2.8`(17곳)은 **전부
> [`20`](20-eks-module.md)의 절**을 가리킨다. 문서 번호 접두가 빠진 PoC 시절 표기이고,
> **이 문서에는 그 번호의 절이 없다.** 새 절에 `§2.6`을 쓰면 기존 참조 30여 곳이 이 절로 잘못 걸린다.
> 📌 **재사용할 절차**: 절을 신설하기 전에 `grep -o "§[0-9.a-z-]*" <파일> | sort | uniq -c` 로
> **번호 점유 현황을 먼저 본다.** 접두 없는 타 문서 참조가 남아 있는 문서에서는 번호가 자유롭지 않다.

### ✅ 승계되는 것 — 경로 무관

공식 근거: *"Applications and ApplicationSets work identically to upstream Argo CD **with no changes
to your manifests**"*([`21 §1.7`](21-gitops-bootstrap-seam.md)). ⇒ **팬아웃 기계 전체가 공통부**다.

| 절 | 승계 자산 | 왜 경로와 무관한가 |
|---|---|---|
| §2.1 | cluster Secret **이름 = 실제 EKS 클러스터명** 규약 · `project` 필드 함정 | `{{name}}`이 ALBC `clusterName`으로 흐르는 것은 **ArgoCD 기능**이지 ArgoCD **설치 형태**가 아니다 |
| §2.2 | cluster generator + `matchLabels` 팬아웃 · fasttemplate 라벨 주입 · `ServerSideApply` · **`sourceRepos` 제3 가드레일** · AppProject 갱신 후 `refresh=hard` 전파 | 〃 |
| §2.2 | **IMDS hop limit 상향 기각안**(파드→노드 권한 상승) | 논증에 ArgoCD가 등장하지 않는다 — 노드·파드 IAM 격리의 문제 |
| §2.3 | per-spoke 값 계약 4종 · *"`targetRevision`은 valueFiles로 못 바꾼다"* | Application **Source 필드**의 성질 |
| §2.4 | addon 3분류 · paved road · 버전 스큐 대응(values 핀 → 채널 라벨) | 소유·권한 경계의 문제 |
| §2.5 | (A) 라벨→`targetRevision` · (B) multi-source `valueFiles` · (C) region 라벨화 | 같은 이음새의 파생 |

### 🔀 갈리는 것 — 4개

| # | 지점 | 관리형 (§2.x 본문) | **self-managed (현행 경로)** |
|---|---|---|---|
| 1 | cluster Secret `server` | EKS 클러스터 **ARN** | **`https://kubernetes.default.svc`** — §4.1 정정 |
| 2 | `sourceRepos`에 등재할 저장소 URL | **CodeConnections 프록시 URL** | **GitHub URL** — §1.1 재판정 |
| 3 | **public helm egress 실증** | ✅ 2026-07-27 canary | ⚠️ **승계되지 않는다** — 아래 |
| 4 | ArgoCD 자신의 chart repo | ⛔ 해당 없음(AWS가 소유) | 🆕 **`https://argoproj.github.io/argo-helm`를 `sourceRepos`에 추가해야 한다** — 자기 관리([`23 §2.1`](23-argocd-self-managed.md)). ⏭️ **증분 ②가 수행**(§2.10.1) |

> ### ⚠️ **3 — egress 실증을 승계하지 않는 이유**
>
> §2.2의 canary가 물은 것은 *"**관리형 capability의** repo-server가 `https://aws.github.io/eks-charts`에
> 닿는가"* 였다. self-managed의 repo-server는 **우리 노드 위의 파드**라 나가는 경로가 다르다
> (노드 SG → NAT → IGW). ⇒ *"이미 확인됐다"* 로 쓰면 [`CLAUDE.md`](../../CLAUDE.md) 검증 절이
> 금지한 **추정**이 된다.
>
> ⭐ **값은 버리고 방법은 그대로 재사용한다** — `syncPolicy` **없는**(=비교만 하는) canary
> Application을 심고 `status.sync.revision`·rendered 리소스 수를 본다.
> 🔑 **배포를 만들지 않으므로 addon 증분의 첫 스텝으로 두기 좋다.**
> ⚠️ Karpenter의 `public.ecr.aws/karpenter`는 **다른 호스트**라 따로 봐야 한다(§2.2가 이미 경고).

### ✅ **egress canary 실행 완료 — 3 호스트 전부 통과** (2026-08-10, workbench SSM)

`project: default`·`syncPolicy` 없음으로 Application 3개를 심고 판정 후 삭제했다
(**클러스터 배포 0** — `root-app` 외 Application 0, ALBC deployment 없음, `karpenter` ns 없음으로 확인).

| canary | 호스트 | 핀 | `revision` | rendered | 판정 |
|---|---|---|---|---|---|
| `canary-albc` | `https://aws.github.io/eks-charts` | `3.5.0` | **3.5.0** | **19** | ✅ conditions 없음 |
| `canary-argocd` | `https://argoproj.github.io/argo-helm` | `10.3.0` | **10.3.0** | **55** | ✅ conditions 없음 — **갈림점 4가 성립한다** |
| `canary-karpenter` | `public.ecr.aws/karpenter` (**OCI**) | `1.14.0` | **1.14.0** | 0 | 🔶 egress ✅ · **values 누락**으로 template 실패 — 아래 |

> ## 🔑 **재사용할 판독법 — 1차 신호는 rendered가 아니라 `revision`이다**
>
> ⚠️ **§2.2가 적은 *"연결 실패면 rendered 0 + `ComparisonError`"* 는 판별식으로 불충분하다.**
> `canary-karpenter`가 **정확히 그 형태**(rendered 0 + `ComparisonError`)였는데 원인은 egress가
> **전혀 아니었다**:
>
> ```
> failed to execute helm template command: … `helm template . --name-template canary-karpenter
> --namespace karpenter --kube-version 1.35.6 --include-crds` failed exit status 1:
> Error: execution error at (karpenter/templates/deployment.yaml:151:25):
>   Chart cannot be installed without a valid settings.clusterName!
> ```
>
> ⇒ **`revision`이 `1.14.0`으로 해석됐다는 것 자체가 차트를 이미 받아왔다는 증거다.**
> 못 받았으면 revision을 채울 수 없다. 게다가 `deployment.yaml:151`까지 렌더가 진행됐다 —
> **네트워크 단계는 이미 지났다.**
>
> | 신호 | 뜻 |
> |---|---|
> | `revision` 비어 있음 + `ComparisonError` | **fetch 실패** — egress·인증·버전 부재 |
> | `revision` 해석됨 + rendered 0 + `ComparisonError` | **fetch 성공, render 실패** — values·`kubeVersion`·차트 버그 |
> | `revision` 해석됨 + rendered > 0 | ✅ **완전 통과** |
>
> 📌 **이것이 canary를 먼저 두는 이유다.** 실제 ApplicationSet에서 같은 에러를 만났다면
> *"public.ecr.aws에 못 나가는구나 → 미러링을 검토하자"* 로 갔을 것이다. **없는 문제를 푸는 설계**다.

> ### ⭐ **덤으로 확인된 것 3건**
>
> ① **OCI helm은 repository 사전 등록 없이 동작한다.** `repoURL: public.ecr.aws/karpenter`(scheme 없음)
> \+ `chart: karpenter`만으로 argo-cd v3.5.0이 pull했다 — `enableOCI` 설정이나 Repository Secret이
> **필요 없었다**. ⇒ §2.2 Karpenter 증분 (1)이 남긴 *"배포 시 재실측"* 은 이것으로 닫힌다.
> ② **클러스터 실제 버전은 `1.35.6`** — repo-server가 `helm template --kube-version 1.35.6`으로
> 렌더한다. 🔑 **차트의 `kubeVersion` 제약은 이 값으로 판정된다**(`.Capabilities`도 여기서 온다).
> ③ **`default` AppProject는 self-managed에도 존재하고 완전 개방이다**(실측:
> `sourceRepos: ['*']` · `destinations: [{'*','*'}]` · `clusterResourceWhitelist: [{'*','*'}]`).
> ⇒ §3.1의 *"쓰지 않는다"* 결론이 **추론이 아니라 실측으로** 뒷받침된다.
> ⚠️ **관리형과 한 곳 다르다 — `sourceNamespaces` 필드가 아예 없다**(관리형 실물엔 `[argocd]`가
> 있었다, §3). apps-in-any-namespace가 꺼져 있는 upstream 기본값이다.
>
> > **canary에 `project: default`를 쓴 것은 의도된 한정 예외다** — 차트 repo를 물으려면
> > `sourceRepos: ['*']`가 필요한데, 진단 하나 때문에 `platform`의 가드레일을 미리 열 수는 없다.
> > ⛔ **판정 직후 삭제하는 것까지가 절차다.** 남기면 §3.1이 금지한 *"`default`에 올라간
> > 가드레일 없는 Application"* 이 그대로 된다.

> ### 📌 **버전 핀도 승계하지 않는다 — 자산은 값이 아니라 원칙이다**
>
> 본문의 ALBC `3.4.2` · Karpenter chart `1.13.0`은 **2026-07-27 PoC 시점 실측값**이다. 근거였던
> *"클러스터 k8s 버전 ↔ 차트 호환성 매트릭스"* 는 유효하고 클러스터도 **여전히 1.35**지만,
> **차트는 그동안 움직였다.**
> ⇒ 증분 착수 시 registry에서 다시 실측한다 — §2.2가 이미 **"실측 핀"** 이라 부른 원칙이다.
> ⚠️ **구조(`{{name}}`·`{{metadata.labels.vpcId}}`·sync-wave 분리)는 그대로 쓰고 숫자만 다시 잡는다.**
>
> #### ✅ **2026-08-10 실측 — 둘 다 움직였다**
>
> | 차트 | PoC 핀 | **현행 핀** | 근거 |
> |---|---|---|---|
> | `aws-load-balancer-controller` | `3.4.2` | **`3.5.0`** (appVersion `v3.5.0`) | `https://aws.github.io/eks-charts/index.yaml` 전수(80개) semver 정렬. **`kubeVersion` 제약 없음** |
> | `karpenter` (OCI) | `1.13.0` | **`1.14.0`** | ECR Public 태그 전수(2,317개, 페이지네이션) + 호환성 매트릭스 원문 **`1.35 → >= 1.9`** |
>
> 🔑 **ECR OCI 태그를 읽으면 §2.2가 경고한 *"git 태그 v1.14.0인데 Chart.yaml은 1.13.0"* 함정에
> 걸리지 않는다.** OCI 스펙상 helm 차트의 **태그가 곧 차트 버전**이고, `--version`·`targetRevision`에
> 그대로 넣는 값이다. 📌 **GitHub 릴리스는 그 질문에 답할 수 없는 소스다** —
> 소스마다 대답할 수 있는 질문이 다르다.
> ⚠️ ECR Public `tags/list`는 **1,000개에서 잘린다.** `Link` 헤더로 페이지네이션하지 않으면
> `1.13.x`가 통째로 빠진 목록을 보게 된다(실제로 첫 조회가 그랬다).
> ⚠️ 참고 — 매트릭스는 **`1.36 → >= 1.13`** 이다. 클러스터를 1.36으로 올릴 때 `1.14.0`은 이미 충족한다.

### 🏗️ 현행 실물이 **이미 준비해 둔** 것

`iac-platform-gitops`의 cluster Secret은 addon 증분이 소비할 라벨을 이미 담고 있다(2026-08-07 실측값):

| 라벨 | 소비자 | 비고 |
|---|---|---|
| `environment: dev` | 팬아웃 `matchLabels` + `clusters/<env>/<name>/values.yaml` 경로 키 | §2.1·§2.5(B) |
| `vpcId: vpc-00e16675363a702a5` | ALBC `--aws-vpc-id` **명시 주입** | §2.2 IMDS 정정 |
| `karpenterNodeRole: Karpenter-eks-ref-dev-an2-main-01-…` | EC2NodeClass `spec.role` | Karpenter가 요구하는 값 중 **유일하게 클러스터명에서 파생 불가**(hash 접미) |

⇒ **`addons/`만 추가하면 되고 cluster Secret은 손대지 않는다.** 새 클러스터도 Secret 1개 = O(1).

> 🔴 **정정(2026-08-11, §2.10.3)**: *"cluster Secret은 손대지 않는다"* 는 **① baseline addon 전제**였다.
> **② opt-in 카탈로그는 옵트인이 곧 라벨**이므로 손댄다(KEDA가 `addon-keda: "enabled"` 를 요구한다).
> 🔑 **O(1)은 그대로다** — 새 클러스터는 여전히 Secret 1개이고, 그 안의 라벨이 하나 늘 뿐이다.

> ### ✅ **§2.2가 경고한 Karpenter SG 태그 선결 과제는 해소됐다** (2026-08-10 확인)
>
> §2.2 Karpenter 증분 (3)은 *"노드 SG에 `karpenter.sh/discovery` 태그가 없다 → `modules/eks-cluster`에
> `node_security_group_tags`를 넣고 재apply해야 이 증분이 성립한다"* 고 적었다. **그 일은 끝났다.**
>
> - `modules/eks-cluster/main.tf` — `node_security_group_tags = var.enable_karpenter ? {"karpenter.sh/discovery" = local.cluster_name} : {}`
> - `outputs.tf`가 `karpenter_discovery_tag`로 노출하고 `tests/plan.tftest.hcl`이 값을 assert한다
> - [`20 §5.2`](20-eks-module.md) — 열린 항목에서 **계약으로 승격**됨(`20 §3.1` 변수 계약 + Task 20.3)
> - 소비 루트가 `enable_karpenter = true`로 apply 완료(2026-08-04)
>
> ⚠️ **모듈이 태그를 부여한다**까지가 이 repo의 판정이다. **실물 SG에 붙어 있는지**는 소비 repo
> 소관이며, 증분 착수 시 `aws ec2 describe-security-groups` 조회로 몇 초 만에 닫을 수 있다
> ([`CLAUDE.md`](../../CLAUDE.md) — *"동작한다"의 기준은 `tofu test` + 예제 `validate`까지*).

## ⭐ **D-ADDON-NS — addon 네임스페이스 규칙** (2026-08-10 확정, 사용자 결정)

> ## 규칙
>
> **계층 2(GitOps helm addon)는 addon마다 전용 네임스페이스를 신설한다.**
> **예외는 둘뿐이다 — `aws-load-balancer-controller` · `karpenter` → `kube-system`.**
>
> ⛔ 예외를 늘리려면 **아래 세 근거에 준하는 것**을 대야 한다. *"차트 기본값이 `kube-system`이라서"* 는
> 근거가 아니다.

### 예외 2개의 근거 — 세 겹으로 선다

| # | 근거 | 성격 |
|---|---|---|
| **1** | **Karpenter 공식 문서가 `kube-system`을 기본으로 하고 이유를 밝힌다** — `system-leader-election`·`kube-system-service-accounts` **FlowSchema**가 `kube-system`의 호출을 `leader-election`·`workload-high` PriorityLevelConfiguration으로 보낸다. *"If you install Karpenter in a different namespace … you will need to create **custom FlowSchemas**"* | ⭐ **기술적** — API Priority & Fairness. 다른 ns면 apiserver 스로틀링 시 **Karpenter가 굶는다** |
| **2** | **ALBC도 공식이 `kube-system`이다** — AWS EKS User Guide(`eksctl create iamserviceaccount --namespace=kube-system` + `helm ... -n kube-system`)와 upstream `kubernetes-sigs` 설치 가이드가 **둘 다** | 관례(기술 근거는 명시 없음) |
| **3** | **Pod Identity association이 이미 `kube-system`이다** — ALBC는 `modules/eks-cluster/iam.tf`가 명시, Karpenter는 upstream `modules/karpenter` v21.24.1 기본값 | **집행 장치** — 어기면 자격증명이 안 붙는다 |

> ### ⚠️ **근거 3은 근거 1·2를 대체하지 못한다 — 순서가 중요하다**
>
> *"association이 `kube-system`이니까 거기 배포한다"* 만 적으면 **논리가 뒤집힌다.** 그건 우리가 고른
> 값이 아니라 **upstream 기본값을 받은 것**이고, 그렇게 읽으면 다음 사람이 *"IaC 우연에 GitOps를
> 맞췄구나"* 로 이해한다. **공식 권고(1·2)가 먼저 있고, 3은 그것을 어길 수 없게 만드는 장치다.**
>
> 🔑 실제로 가역적이다 — upstream이 `namespace` 변수를 노출한다(기본 `kube-system`).
> 우리 facade가 안 넘기고 있을 뿐이며, `ami_type`(D-NODE-ARCH)·`cluster_security_group_additional_rules`와
> **같은 패턴**이다. ⇒ 바꾸고 싶으면 변수 하나면 되고, **그래서 "못 바꾼다"가 아니라 "안 바꾼다"** 다.

### 🔴 **근거로 쓰지 말 것 — 실측으로 반증됐다**

*"두 차트 모두 `priorityClassName: system-cluster-critical`(기본값)이고 그 PriorityClass는
`kube-system`에서만 쓸 수 있다"* — **틀렸다.**

- `default` 네임스페이스에 server-side dry-run → **`pod/... created (server dry run)`** 통과(실측 2026-08-10)
- k8s `master`·`release-1.31`의 priority admission plugin 소스에 **그 제약이 없다**

⚠️ 구버전 제약의 기억이다. **이 논거를 되살리지 말 것.**

### 왜 나머지는 전용 네임스페이스인가

전용 ns가 주는 것(정책 스코프·quota·RBAC 경계·삭제 안전성)은 **addon 수가 늘수록** 값이 커지는데,
`kube-system`은 **한번 들어가면 되돌리기 어렵다**(EKS managed addon과 뒤섞이고 삭제도 불가).
⇒ **기본을 전용 ns로 두고 예외에 근거를 요구**하는 편이 비대칭을 올바른 방향으로 잡는다.

⛔ **계층 1(Terraform managed/community addon)은 이 규칙의 대상이 아니다.** 그쪽 ns는 AWS·차트가
정하고 우리가 고르지 않는다. 실측(2026-08-10)상 결과적으로 규칙과 어긋나지도 않는다:

| ns | 도는 것 | 계층 |
|---|---|---|
| `kube-system` | coredns · ebs-csi-controller · metrics-server | 1 (EKS managed addon) |
| `cert-manager` | cert-manager · cainjector · webhook | 1 (community addon) |
| `external-dns` | external-dns | 1 (community addon — `iam.tf`가 association을 이 ns로 만든다) |

### 🔧 집행 — 전용 ns addon을 넣을 때

- ApplicationSet template의 `syncPolicy.syncOptions`에 **`CreateNamespace=true`** 를 넣는다.
- ✅ **판정할 것 2건은 종결됐다**(2026-08-11, **§2.10.0** — 첫 전용-ns addon = Kyverno):
  - **① 받는다 — 단 "네임스페이스가 아직 없을 때"만.** argo-cd `v3.5.0` 소스 판정(자동 생성 ns가
    **같은 sync task 목록에 append**되어 `permissionValidator`를 거친다). ⇒ **`{group: "", kind: Namespace}` 를 연다.**
    🔴 이미 있는 ns는 검사 자체가 없으므로 **dev에서 통과하고 신규 클러스터에서만 깨지는** 형태가 된다.
  - **② 그렇다 ⇒ `managedNamespaceMetadata`를 쓰지 않는다.** 공식 원문이 *"including the possibility
    to delete it"* 로 못박는다. `prune: true`와의 조합은 실제로 네임스페이스를 지운다.

### 🔴 **부수 발견 — NodePool의 아키텍처는 클러스터를 따라간다** (§2.2의 `amd64`는 PoC 값이다)

`§2.2` NodePool 스펙은 `kubernetes.io/arch In [amd64]`인데, 이 클러스터의 managed NG는
**`AL2023_ARM_64_STANDARD` · `t4g.medium`(Graviton)** 이다(실측).
그대로 쓰면 arm64 클러스터에 amd64 노드가 섞이고 **멀티아키 이미지가 없는 워크로드가 죽는다.**

⇒ 증분 ①은 **`arm64`** 로 넣었다. ⚠️ 이것도 고정값이 아니다 —
**소비 루트의 `ami_type`(D-NODE-ARCH)이 정하는 값**이라 Graviton을 쓰지 않는 고객사에서는 뒤집힌다.
🔑 **재사용 자산 관점에서 옳은 표현은 "arm64"가 아니라 *"managed NG와 같은 아키텍처"* 다.**

> ### 📌 **재사용할 판단 — 네임스페이스와 아키텍처가 같은 형태다**
>
> 둘 다 **계층 1(Terraform)이 이미 정해 둔 값을 계층 2가 다시 고르려다** 생긴다.
> `30 §0`의 3계층 소유 모델은 *"누가 무엇을 소유하는가"* 를 정했지만,
> **소유하지 않는 계층이 그 값을 어떻게 알아내는가**는 적지 않았다.
> ⇒ **addon 매니페스트를 쓰기 전에 `list-pod-identity-associations`와 `describe-nodegroup`을 본다.**
> ⚠️ cluster Secret 라벨은 그 답의 일부일 뿐이다 — 라벨에 없는 제약이 이렇게 존재한다.

### ✅ **증분 ① apply 판정 — 전부 통과** (2026-08-10, `iac-platform-gitops` PR #1 머지 `10083ef` → 복구 `28cefaf`)

| 판정 | 결과 |
|---|---|
| root App이 `addons/baseline`을 흡수했는가 | ✅ `Synced` `Healthy` · revision = **실제 SHA**(`28cefaf…`) · conditions 없음 |
| ApplicationSet → Application | ✅ **3 → 3** (`aws-lbc` · `karpenter` · `karpenter-nodepool`) 전부 `Synced Healthy` |
| 컨트롤러 기동 | ✅ `kube-system`에 `…-aws-lbc-aws-load-balancer-controller` **2/2** · `…-karpenter` **2/2** |
| Karpenter CR | ✅ `NodePool/default` · `EC2NodeClass/default` 모두 **`Ready=True`** ⇒ CRD 순서(wave 5 + `SkipDryRunOnMissingResource`)가 작동했다 |
| 노드 프로비저닝 | ✅ **2개 그대로**(managed NG). pending pod이 없으므로 Karpenter가 idle인 것이 정상 |

⚠️ **여기까지가 "동작한다"의 범위다.** ALB 실제 생성·spot 중단 처리·consolidation은
**워크로드가 들어와야** 검증되고, 그 판정은 이 절이 아니라 그때의 증분이 소유한다.

> ### 🔴 **머지가 root App을 두 번 깨뜨렸다 — 원인과 교훈은 §4.2가 소유한다**
>
> ① `exclude` 확장이 만든 **자기소멸 데드락** ② 마커를 설명하는 주석이 **마커로 작동**.
> ⭐ `prune: false`가 root App의 자기 삭제를 막았다.
> 🔑 **`tofu test`도 canary도 이 둘을 잡을 수 없었다** — 둘 다 *"저장소 상태가 root App spec과
> 어떻게 상호작용하는가"* 의 문제이고, **머지해서 reconcile을 돌려야만** 드러난다.
> ⇒ [`CLAUDE.md`](../../CLAUDE.md)의 *"apply 판정은 소비 repo 몫"* 이 GitOps 계층에도 그대로 산다.

---

## 2.10 🆕 addon 증분 ②③④ — ArgoCD 자기 관리 · Kyverno · KEDA (2026-08-11 신설)

증분 ①(ALBC·Karpenter)이 팬아웃 기계를 실물로 세웠다. 이 절은 그 위에 **세 증분**을 얹는다.
번호 점유는 §2.9가 명령한 절차(`grep -o "§[0-9.a-z-]*" | sort | uniq -c`)로 먼저 확인했다 — `§2.10`은 비어 있었다.

| 증분 | 대상 | 분류 | 네임스페이스 | 계층 1(.tf) 영향 |
|---|---|---|---|---|
| **②** | ArgoCD 자기 관리 (`argo-cd` 10.3.0) | — (hub 단일, 팬아웃 아님) | `argocd`(기존) | 없음 |
| **③** | Kyverno + PSS 정책 (`3.8.2`) | **① baseline** (사용자 결정 2026-08-11) | **`kyverno`(신설)** | 없음 |
| **④** | KEDA (`2.20.2`) | **② opt-in 카탈로그** (§2.4가 이미 그렇게 분류) | **`keda`(신설)** | 없음 |

> ## ⛔ **세 증분을 한 PR에 넣지 않는다 — 순서는 ② → ③ → ④**
>
> 증분 ①에서 **머지해야만 드러나는 결함이 2건**이었다(§4.2). 머지 = 배포이므로 셋을 한 번에
> 넣으면 root App이 깨졌을 때 **원인을 가를 수 없다.**
> **②가 먼저인 이유**는 우선순위가 아니라 의존이다 — ArgoCD는 ③④를 배포하는 **주체**이고,
> 자기 흡수가 불안정한 상태에서 그 위에 addon을 얹지 않는다.

---

### 2.10.0 ✅ D-ADDON-NS가 남긴 **미판정 2건 — 둘 다 종결**

§2.9 「집행」 절이 *"첫 전용-ns addon에서 판정할 것"* 으로 미뤄 둔 두 건이다. ③이 그 첫 addon이다.

#### 판정 ① — **받는다. 단 "네임스페이스가 아직 없을 때"만.** (argo-cd `v3.5.0` 소스)

| 지점 | 사실 |
|---|---|
| `controller/sync.go:337` | `CreateNamespace=true` → `sync.WithNamespaceModifier(syncNamespace(app.Spec.SyncPolicy))` |
| `gitops-engine/pkg/sync/sync_context.go:846` | `tasks = sc.autoCreateNamespace(tasks)` — **같은 `tasks` 목록에 append한다** |
| 같은 파일 `:904` | 그 목록 **전체**에 `sc.permissionValidator(task.obj(), serverRes)` |
| `controller/sync.go:657` | `project.IsGroupKindNamePermitted(gk, name, res.Namespaced)` — Namespace는 `Namespaced=false` ⇒ **`clusterResourceWhitelist` 검사** |
| `controller/sync_namespace.go` | `isNewNamespace := liveNs == nil`. ns가 **이미 있고** `managedNamespaceMetadata`도 없으면 `false` 반환 ⇒ **task 자체가 생기지 않는다** |

> ### 🔴 **그래서 이것은 "dev에서 통과하고 신규 클러스터에서 깨지는" 유형의 결함이다**
>
> 네임스페이스를 손으로 먼저 만들어 두면 **whitelist가 없어도 통과한다.** 그 상태로 커밋하면
> 정상으로 보이고, **두 번째 클러스터가 등록되는 순간** 거기서만
> `resource :Namespace is not permitted in project platform` 로 sync가 깨진다.
> ⇒ **`{group: "", kind: Namespace}` 를 whitelist에 넣는다.** 지금 안 열면 신호가 **몇 달 뒤에** 온다.
> 🔑 이 증분에서 같은 형태가 **두 번** 나온다 — 다른 하나는 §2.10.1 결정 1(Application vs ApplicationSet)이다.
> **단일 클러스터는 팬아웃 결함을 숨긴다**는 것이 재사용할 판단이다.

#### 판정 ② — **그렇다 ⇒ `managedNamespaceMetadata`를 쓰지 않는다.** (공식 문서 원문)

> *"Once a namespace is owned by Argo CD, it will be managed by ArgoCD, **including the possibility
> to delete it**, which Argo CD normally does not do."* — argo-cd `user-guide/sync-options`

⇒ §2.9가 우려한 *"`prune: true`와 겹치면 addon 제거가 네임스페이스째 지운다"* 는 **성립한다.**
⛔ ns에 라벨·애노테이션을 붙일 요구가 생기면 **그때 이 문장을 다시 읽고** 판단한다. 지금은 요구가 없다.
ℹ️ 같은 문서가 *"manually managing the tracking metadata on a namespace is strongly discouraged"* 라고도
경고한다 — **손으로 애노테이션을 붙여 우회하는 길도 막혀 있다.**

#### 🆕 새 축 — **노드의 이미지 pull egress는 canary가 볼 수 없다**

§2.9의 canary는 **repo-server의 차트 fetch**만 판정한다. 지금까지 addon 이미지는 전부
`public.ecr.aws`였고(ALBC·Karpenter), 이번에 처음으로 **`ghcr.io`·`reg.kyverno.io`** 를 요구한다.

- 경로가 다르다 — repo-server는 **파드→NAT**, 이미지 pull은 **kubelet(노드)→NAT**.
- 🔑 **canary로 앞당길 수 없다.** 파드를 실제로 띄워야 알 수 있으므로 **apply 판정 항목**이다.
- 실패 신호는 명확하다 — `ImagePullBackOff` / `ErrImagePull`. ⚠️ 이것을 **egress 문제로 단정하지 않는다**:
  §2.9 판독법과 같은 함정이 있다(레이트리밋·태그 오타도 같은 증상). `kubectl describe pod`의 원문을 읽는다.

---

### 2.10.1 증분 ② — **D-ARGOCD-ADOPT**: ArgoCD가 자기 자신을 흡수한다

[`23 §2.1`](23-argocd-self-managed.md)이 *"seed 1회 + 자기 관리"* 를 결정했고, 그 3단계 중 **2단계(흡수)** 가
아직 실물이 아니다. 이 증분이 그것을 배선한다. ⚠️ `23`은 *"무엇을 세우는가"*, 이 절은 *"그것이 어떻게 읽히는가"* 다
([`23 §4`](23-argocd-self-managed.md) 인터페이스 선언과 정합).

#### 결정 1 — 🔴 **`Application`이다. `ApplicationSet`이 아니다.**

⛔ **cluster generator를 쓰면 등록된 모든 스포크에 ArgoCD가 설치된다.** ArgoCD는 hub에만 산다.

> ⚠️ **지금은 클러스터가 1개라 증상이 나타나지 않는다.** `matchLabels: {environment: dev}` 로
> 팬아웃해도 대상이 hub 자신 하나뿐이라 **정상으로 보인다.** 두 번째 클러스터가 등록되는 순간
> 거기에 ArgoCD가 통째로 깔린다. ⇒ 판정 ①과 **같은 형태의 함정**이다(§2.10.0).
> 🔑 **`addons/`의 파일은 전부 "N개 클러스터에 반복"을 뜻한다.** hub 단일 리소스를 그 디렉토리에 두면
> 계약과 어긋난다 — 그래서 위치도 `addons/baseline/`이 아니다(결정 2).

#### 결정 2 — 위치는 **`bootstrap/argocd-app.yaml`**

- `addons/baseline/`의 계약은 *"전 클러스터 팬아웃"* 이고 이것은 hub 단일이다(결정 1).
- seed 산출물인 `bootstrap/argocd-values.yaml`과 **같은 자리**에 둔다 — 자기 관리의 SSOT 두 파일이 붙어 있다.
- root App은 `path: .` + `recurse: true`라 **위치와 무관하게 흡수한다**(§1 O(1) 규칙). 위치는 **사람이 읽는 의미**의 문제다.

#### 결정 3 — **multi-source** (§2.5 (B)가 예고한 그 메커니즘의 **첫 실전 사용**)

```yaml
sources:
  - repoURL: https://argoproj.github.io/argo-helm
    chart: argo-cd
    targetRevision: 10.3.0
    helm:
      valueFiles: ['$values/bootstrap/argocd-values.yaml']
  - repoURL: https://github.com/skax-ca/iac-platform-gitops.git
    targetRevision: main
    ref: values          # 값 참조 전용 source — 렌더 대상이 아니다
```

> ### 🔑 **같은 파일이 한 Application에서는 제외되고 다른 Application에서는 입력이다 — 모순이 아니다**
>
> `bootstrap/argocd-values.yaml`은 **root App의 `exclude` 대상**이다(§4.2). 여기서는 그 파일을
> **helm values로 읽는다.** 둘은 충돌하지 않는다 — `exclude`는 *root App이 그것을 k8s 매니페스트로
> 오인하지 않게* 하는 설정이고, `$values` 참조는 *다른 Application의 다른 source*다.
> ⚠️ 이 구분을 놓치면 *"exclude된 파일을 어떻게 읽지?"* 로 막힌다. **exclude는 파일을 숨기는 것이 아니라
> 한 Application의 훑기 대상에서 빼는 것**이다.

#### 결정 4 — **`targetRevision: 10.3.0`** — seed가 설치한 것과 **같은 값**

⛔ **이 증분에서 차트를 올리지 않는다.** [`23 §5`](23-argocd-self-managed.md)의 정확 핀 그대로다.

- 흡수와 업그레이드를 같은 커밋에 넣으면 실패했을 때 **"흡수가 문제인가 새 차트가 문제인가"** 를 가를 수 없다.
- 🔑 [`23 §5`](23-argocd-self-managed.md)가 helm CLI를 v4가 아닌 v3로 핀할 때 쓴 것과 **같은 셈법**이다 —
  *변수를 하나씩만 움직인다. 진단 가능성도 비용 항목이다.*
- ⭐ 게다가 §2.1의 **자기소멸 원칙이 이것을 요구한다**: 흡수 대상은 seed 산출물의 *바이트 동일 사본*이어야 한다.
  버전을 올리면 흡수가 아니라 **업그레이드**이고, 그건 다른 행위다.

#### 결정 5 — ⭐ **자동 sync를 처음부터 켜지 않는다 — 2단계로 흡수한다**

| 단계 | 커밋 | 내용 |
|---|---|---|
| **1** | PR-②a | `syncPolicy.syncOptions`만 두고 **`automated`를 넣지 않는다** = **비교만 한다** |
| — | (판정) | workbench에서 `argocd app diff argocd` — helm install ↔ helm template 차이를 **사람이 읽는다** |
| **2** | PR-②b | 차이가 없거나 설명 가능하면 `automated: {selfHeal: true, prune: false}` 추가 |

> ⚠️ **1단계에서 `syncPolicy`를 통째로 비우지 않는다 — `syncOptions`는 처음부터 넣는다.**
> `ServerSideApply=true`가 있으면 ArgoCD의 diff가 **server-side dry-run apply**로 계산된다.
> 없으면 1단계에서 본 diff와 2단계에서 실제로 적용될 결과가 **다른 계산**이 되고, 그러면 1단계가
> 판정으로서 값을 잃는다. 🔑 **판정 단계와 실행 단계는 같은 방식으로 계산해야 한다.**

> ### 🔴 **왜 한 번에 켜지 않는가 — 적용 대상이 application-controller 자신이다**
>
> 흡수 순간 diff가 있으면 **즉시 적용**되고, 그 적용이 `argocd-application-controller`·`repo-server`를
> 재시작시킨다. **sync를 수행하는 주체가 sync 도중에 죽는다** — 중단된 채로 남으면 무엇이 적용되고
> 무엇이 안 됐는지 알 수 없다.
> ⭐ **1단계는 egress canary와 같은 도구를 다른 질문에 쓰는 것이다** — `syncPolicy` 없는 Application =
> *배포하지 않고 비교만*. §2.9가 *"배포를 만들지 않으므로 증분의 첫 스텝으로 두기 좋다"* 고 쓴 그 성질이
> 여기서 **두 번째 용도**를 얻는다.
> 📌 ⚠️ **`prune: true`는 2단계에서도 켜지 않는다** — root App과 같은 이유(§4)에 더해, 아래 결정 6의
> helm 잔존물이 *"저장소에 없는 리소스"* 로 분류된다.

#### 🔴 1단계에서 **반드시 읽어야 할 판정 3건** (렌더 실측에서 미리 특정했다)

1단계의 값은 *"diff가 비어 있길 바란다"* 가 아니라 **"무엇이 나올지 미리 알고 본다"** 에 있다.
로컬 렌더(`helm template argo-cd 10.3.0 -f argocd-values.yaml`)로 **세 지점을 미리 특정했다.**

| # | 지점 | 무엇을 보는가 | 위험 |
|---|---|---|---|
| **1** | 🔴 **`Secret/argocd-secret`** | 차트가 이것을 **`data` 없이**(메타데이터 + `type: Opaque`만) 렌더한다 — **argocd-server가 런타임에 admin 비밀번호 해시·`server.secretkey`·TLS를 채우는** 자리다 | 잘못 적용하면 **관리자 자격증명과 세션 키가 날아간다** |
| **2** | **helm hook 4개** — `argocd-redis-secret-init`(ServiceAccount·Role·RoleBinding·Job), `helm.sh/hook: pre-install,pre-upgrade` | ArgoCD가 이것을 **`PreSync` 훅으로 번역**한다 ⇒ **sync마다 Job이 하나 뜬다** | 놀랄 일이지 사고는 아니다. **정상으로 기록해 둔다** |
| **3** | 리소스 44개 전체의 이름 | 렌더 이름이 seed의 helm release 이름(`argocd`)에서 나온다 | 아래 ⭐ |

> ### 🔴 **`argocd-secret`이 `ServerSideApply=true`를 필수로 만든다**
>
> SSA는 **자신이 선언한 필드만 소유**한다. 차트가 `data`를 선언하지 않으므로 ArgoCD는 그 키들을
> **건드리지 않는다** — argocd-server가 채운 값이 보존된다.
> ⛔ **`Replace=true`를 쓰지 않는다.** 그것은 객체를 통째로 교체하므로 정확히 이 사고를 낸다.
> 📌 **`ignoreDifferences`를 미리 넣지 않는다.** 필요한지 아닌지를 **1단계가 답한다** — 필요 없는데
> 넣으면 죽은 설정이고, 필요하면 그때 `{kind: Secret, name: argocd-secret, jsonPointers: ["/data"]}`
> 를 **근거와 함께** 넣는다. ⭐ **이 판정을 안전하게 할 수 있다는 것이 2단계로 나눈 값 그 자체다.**

> ### ⭐ **release 이름이 `argocd`여야 한다 — 틀리면 흡수가 아니라 두 번째 설치가 된다**
>
> `argocd-seed.sh`의 `ARGOCD_RELEASE` 기본값이 **`argocd`** 이고(실측 `:137`), helm은 릴리스 이름으로
> 리소스 이름을 만든다(`argocd-server`·`argocd-repo-server`…).
> ArgoCD는 helm source의 release 이름을 **Application 이름에서 가져온다** ⇒ Application을
> `argocd-self` 따위로 지으면 `argocd-self-server` 같은 **완전히 새로운 44개 리소스**를 만든다.
> **흡수(adopt)가 아니라 병렬 설치다.**
> ⇒ Application 이름을 `argocd`로 하고, **그 위에 `helm.releaseName: argocd`를 명시한다.**
> ⚠️ 명시는 중복처럼 보이지만 죽은 설정이 아니다 — **Application 이름을 바꾸는 순간 조용히 깨지는
> 결합**을 값으로 고정하고, `argocd-seed.sh`의 변수와의 연결을 문서화한다.

#### 결정 6 — **helm release Secret은 남는다. 지우지 않는다.**

seed의 `helm install`이 만든 `sh.helm.release.v1.argocd.v1` Secret이 `argocd` ns에 남는다.
ArgoCD가 만든 것이 아니므로 흡수 대상도 prune 대상도 아니다.

> ⚠️ **이것이 남아 있는 한 누군가 `helm upgrade`를 돌릴 수 있다** — [`23 §2.1`](23-argocd-self-managed.md)의
> *"helm CLI를 다시 쓰지 않는다"* 를 어길 수 있는 **유일한 실물 경로**다.
> ⛔ 그럼에도 지우지 않는다: 지우는 행위 자체가 **helm의 상태를 손대는 것**이고, 실패하면 seed를
> 다시 밟아야 하는 자리다. **규약으로 막고 기록으로 남긴다** — 얻는 것(미관)보다 잃을 수 있는 것이 크다.
> 🔑 D27이 `AWSAFTExecution`을 *"깨진 채로 둔다"* 고 판단한 것과 같은 형태다([`50`](50-reference-consumer-repo.md)) —
> **고치는 것도 위험을 만든다.**

#### ✅ 증분 ②의 실측 — AppProject 델타

| 항목 | 값 | 근거 |
|---|---|---|
| egress | ✅ **이미 실측됨** | §2.9 canary: `canary-argocd` revision `10.3.0` · rendered **55** · conditions 없음 |
| 이미지 pull | ✅ **이미 도는 파드다** | 흡수일 뿐 새 이미지를 받지 않는다 — 새 egress 축 없음 |
| `sourceRepos` | 🆕 `https://argoproj.github.io/argo-helm` | `projects/platform.yaml`의 `⏳ 아직 넣지 않는다` 주석을 **실제 항목으로** 승격 |
| `clusterResourceWhitelist` | **추가 0건** | 로컬 렌더 실측(`helm template argo-cd 10.3.0 --kube-version 1.35.6 --include-crds -f argocd-values.yaml`): cluster-scoped는 **CRD 3 · ClusterRole 2 · ClusterRoleBinding 2** 뿐이고 **전부 이미 열려 있다** |

---

### 2.10.2 증분 ③ — **D-KYVERNO**: 정책 엔진을 baseline으로

**사용자 결정(2026-08-11)**: **① baseline**. 근거 — 정책 엔진은 **가드레일**이고, **옵트인 가드레일은
가드레일이 아니다.** ALBC·Karpenter와 같은 층에 둔다.
정책 세트도 함께 넣는다 — **`kyverno-policies`(PSS baseline)를 Audit 모드로.**
⛔ *"정책 0인 엔진"* 은 아무것도 하지 않는 **죽은 경로**이고, Audit은 위험 없이 값을 낸다.

#### 실측 핀 (2026-08-11, `kyverno.github.io/kyverno` index.yaml 전수)

| 차트 | 핀 | appVersion | `kubeVersion` | 판정 |
|---|---|---|---|---|
| `kyverno` | **`3.8.2`** | `v1.18.2` | `>=1.25.0-0` | ✅ 클러스터 **1.35.6** 충족 |
| `kyverno-policies` | **`3.8.2`** | `v1.18.2` | `>=1.25.0-0` | ✅ **컨트롤러와 번호가 같다** — 스큐 판단이 필요 없다 |

⭐ 두 차트가 **같은 번호로 함께 릴리스된다**(전체 263 / 199개 중 stable 79 / 61개 전수 확인).
⇒ §2.4가 경고한 *"버전 스큐"* 문제가 이 쌍에는 **구조적으로 없다.** 올릴 때 **둘을 같이 올린다.**

#### 구조 — Karpenter와 **같은 형태**(파일 1개 · ApplicationSet 2개 · wave 분리)

CRD 순서가 똑같은 문제를 낸다: `kyverno` 차트가 `ClusterPolicy` CRD를 동봉하고, `kyverno-policies`는
그 CRD가 **선존재해야** 적용된다.

| | ApplicationSet | wave | syncOption |
|---|---|---|---|
| ① | `kyverno`(컨트롤러) | `0` | `ServerSideApply=true` · **`CreateNamespace=true`** |
| ② | `kyverno-policies`(ClusterPolicy 11개) | `5` | `ServerSideApply=true` · **`SkipDryRunOnMissingResource=true`** |

⚠️ **wave는 생성 순서만 정하고 완료를 기다리지 않는다** — 실제 안전장치는 ②의
`SkipDryRunOnMissingResource`와 ArgoCD의 재시도다(증분 ①에서 작동을 실증했다, §2.9 판정표).

#### 🔴 결정 — **`failurePolicy`는 chart 기본 `Fail`에서 `Ignore`로 바꾼다**

> ## ⭐ **두 값은 이름이 비슷하지만 완전히 다른 축이다**
>
> | 값 | 묻는 것 | chart 기본 | 우리 값 |
> |---|---|---|---|
> | `validationFailureAction` | **정책을 위반했을 때** 무엇을 하는가 | **`Audit`** | **`Audit`(기본 유지 — 적지 않는다)** |
> | `failurePolicy` | **웹훅에 닿지 못할 때** 무엇을 하는가 | **`Fail`** | 🔴 **`Ignore`(변경)** |
>
> **Audit + Fail은 비정합이다.** 아무것도 막지 않기로 결정해 놓고, **Kyverno가 죽으면 전부 막는다** —
> 얻는 것 없이 가용성만 깎는다.
> ⭐ **`background: true`(chart 기본)라 잃는 것이 거의 없다** — 웹훅을 놓쳐도 **백그라운드 스캔이
> PolicyReport를 만든다.** `Ignore`로 잃는 것은 *"실시간 리포트"* 뿐이다.
> ⚠️ **Enforce로 전환할 때 `Fail`로 함께 올린다.** 두 값은 **짝으로 움직인다** — 한쪽만 바꾸면
> 다시 비정합이 된다.

#### ⭐ chart 기본 웹훅 제외가 **ALBC·Karpenter를 이미 지켜 준다**

렌더 실측 — `ConfigMap/kyverno`의 `webhooks`:
```json
{"namespaceSelector":{"matchExpressions":[
  {"key":"kubernetes.io/metadata.name","operator":"NotIn","values":["kube-system"]},
  {"key":"kubernetes.io/metadata.name","operator":"NotIn","values":["kyverno"]}]}}
```
`resourceFilters`도 `[*/*,kube-system,*]`·`[*/*,kube-public,*]`·`[*/*,kube-node-lease,*]`·`[*/*,kyverno,*]`를 제외한다.

⇒ **`kube-system`의 ALBC·Karpenter는 Kyverno 경로에 아예 들어가지 않는다.** apiserver가 웹훅을 호출조차 하지 않는다.
🔑 **D-ADDON-NS의 예외 2개가 여기서 부수적 이득을 낸다** — 예외를 만든 이유(APF·Pod Identity)와
무관한 방향에서 값이 돌아왔다.

> ### 🔴 **그러나 `argocd`는 제외 대상이 아니다 — Enforce 전환 전에 답해야 할 질문**
>
> Audit + `Ignore` 조합에서는 무해하다. 그러나 **Enforce + `Fail`로 가면 Kyverno 장애가 ArgoCD의
> 리소스 생성을 막는다** — 그리고 **ArgoCD가 Kyverno를 고치는 수단**이다. **순환 의존이다.**
> ⇒ Enforce 전환은 *"`argocd` ns를 webhook `namespaceSelector` 제외에 넣을 것인가"* 를 **먼저** 답한다.
> ⛔ 지금 미리 넣지 않는다 — 현재 조합에서는 **아무 일도 하지 않는 설정**이고, 죽은 설정은
> 다음 사람에게 *"이게 왜 있지"* 를 남긴다.

#### ⚠️ 웹훅 설정은 **ArgoCD가 소유하지 않는다**

렌더 결과에 `ValidatingWebhookConfiguration`이 **하나도 없다**(실측). Kyverno는 웹훅을 **컨트롤러가
런타임에 동적 등록**한다 — 어떤 정책이 어떤 리소스를 대상으로 하는지에 따라 규칙이 달라지기 때문이다.

- ⇒ whitelist에 넣을 필요가 없고, **ArgoCD의 drift 감지 대상도 아니다.**
- ⚠️ 뒤집으면 이런 뜻이다 — **웹훅이 잘못돼도 ArgoCD는 `Synced Healthy`로 보인다.** 판정을 Application
  상태에만 의존하지 않는다.

#### 이미지 — **`reg.kyverno.io` = GHCR 앞의 vanity 도메인** (실측)

`https://reg.kyverno.io/v2/kyverno/kyverno/manifests/v1.18.2` → **HTTP 401** +
`www-authenticate: Bearer realm="https://ghcr.io/token",service="ghcr.io"` + `x-github-request-id` 헤더.

- ⇒ 노드가 이미지를 받으려면 **`reg.kyverno.io`와 `ghcr.io` 둘 다** 나가야 한다(토큰 발급이 ghcr.io).
- ✅ **arm64 지원 확인** — `ghcr.io/kyverno/kyverno:v1.18.2` manifest index에
  `linux/amd64, linux/arm, linux/arm64, linux/ppc64le, linux/s390x`. 🔑 **클러스터가 Graviton이므로
  이 확인은 선택이 아니다**(§2.9 「부수 발견」 — 아키텍처는 클러스터를 따라간다).
- 파드 4개(admission · background · cleanup · reports 컨트롤러) 각 **replicas 미지정 = 1**. dev 2노드에 무리 없다.
  ⚠️ `podAntiAffinity`가 걸려 있으나 replicas 1이라 지금은 무해하다 — **HA로 올릴 때 노드 수를 함께 본다.**

#### AppProject 델타

| 항목 | 값 |
|---|---|
| `sourceRepos` | 🆕 `https://kyverno.github.io/kyverno/` |
| `clusterResourceWhitelist` | 🆕 **`{group: kyverno.io, kind: ClusterPolicy}`**(정책 11개) · 🆕 `{group: "", kind: Namespace}`(§2.10.0 판정 ①, ④와 공용) |

⭐ **컨트롤러의 cluster-scoped 47종은 추가 0건이다** — CRD **22** · ClusterRole **17** ·
ClusterRoleBinding **8**(렌더 실측)이 **전부 ALBC 증분에서 이미 열린 kind**다.
🔑 *"CRD를 22개나 까는 차트"* 라는 인상과 달리 **whitelist는 kind 단위**라 개수가 아니라 종류만 문제다.

---

### 2.10.3 증분 ④ — **D-KEDA-CATALOG**: `addons/catalog/` 를 처음 켠다

§2.4가 KEDA를 **② opt-in 카탈로그**로 이미 분류해 두었다(*"Kafka/Redis operator·KEDA·service mesh"*).
그 절은 *"경로만 명문화, 구현은 미룸"* 이라고 적었고 — **이 증분이 그 경로를 처음 실제로 켠다.**

#### 실측 핀

| 차트 | 핀 | appVersion | `kubeVersion` | 이미지 |
|---|---|---|---|---|
| `keda` | **`2.20.2`** | `2.20.2` | `>=v1.23.0-0` ✅ | `ghcr.io/kedacore/{keda,keda-metrics-apiserver,keda-admission-webhooks}` |

✅ **arm64 3개 전부 확인** — 각 manifest index에 `linux/amd64, linux/arm64, linux/s390x`.
파드 3개 각 `replicas: 1`, `podAntiAffinity` 없음.

#### 🔴 §2.9 정정 — **cluster Secret을 손댄다**

§2.9 「현행 실물이 이미 준비해 둔 것」이 *"`addons/`만 추가하면 되고 **cluster Secret은 손대지 않는다**"* 라고
적었다. **그 문장은 baseline addon 전제였다.** 카탈로그는 **옵트인이 곧 라벨**이므로 손댄다.

```yaml
# clusters/dev/eks-ref-dev-an2-main-01/cluster-secret.yaml 의 labels 에 추가
addon-keda: "enabled"
```
- ApplicationSet generator: `matchLabels: {addon-keda: enabled}` — `environment: dev`가 **아니다.**
- 🔑 **O(1)은 유지된다** — 새 클러스터도 여전히 Secret 1개이고, 그 안의 **라벨이 하나 늘 뿐**이다.
  §2.4의 *"팀이 라벨로 옵트인"* 이 실물에서 뜻하는 바가 이것이다.
- ⚠️ **라벨 값은 문자열이어야 한다** — `enabled: true`가 아니라 `"enabled"`. k8s 라벨 값에 boolean은 없다.

#### 🔴 `APIService` — 이번 증분에서 **유일하게 성격이 다른 리소스**

KEDA는 `v1beta1.external.metrics.k8s.io` **APIService**를 등록한다(렌더 실측 1건).

- ⚠️ 계층 1의 `metrics-server`가 이미 `v1beta1.metrics.k8s.io`를 갖고 있으나 **API 그룹이 달라 충돌하지 않는다.**
- 🔴 **APIService는 깨지면 그 API 그룹 전체가 죽는다.** 지금은 `external.metrics.k8s.io`를 소비하는 것이
  없어 무해하지만, **HPA가 그것을 쓰기 시작하면 KEDA 장애 = HPA 장애**다.
  ⇒ 실제 워크로드가 `ScaledObject`를 쓰기 시작할 때 **가용성 요구를 다시 본다**(현재 `replicas: 1`).

#### AWS 스케일러 — **지금 만들지 않는다** (사용자 결정 2026-08-11)

- in-cluster 트리거(cron · prometheus · kafka)만 쓴다 ⇒ **Pod Identity·IAM 0건.**
- ⭐ **그래서 이 증분이 계층 2 안에서 닫힌다** — 이 repo의 `.tf`도, 소비 repo의 apply도 없다.
- ⚠️ SQS·CloudWatch 스케일러 요구가 생기면 `modules/eks-cluster/iam.tf`에 `keda/keda-operator`
  association을 연다. **가역적이다** — ALBC·external-dns와 같은 패턴이라 새로 발명할 것이 없다.

#### AppProject 델타

| 항목 | 값 |
|---|---|
| `sourceRepos` | 🆕 `https://kedacore.github.io/charts` |
| `clusterResourceWhitelist` | 🆕 **`{group: apiregistration.k8s.io, kind: APIService}`** · `{group: "", kind: Namespace}`(③과 공용) |

ℹ️ 나머지 cluster-scoped(CRD 6 · ClusterRole 4 · ClusterRoleBinding 5 · ValidatingWebhookConfiguration 1)는
**전부 이미 열려 있다**(ALBC 증분에서). 추가는 위 2건뿐이다.

---

### 2.10.4 📋 세 증분의 **AppProject 총 델타** — 한눈에

`projects/platform.yaml`에 최종적으로 추가되는 것은 **`sourceRepos` 3개 · `clusterResourceWhitelist` 3개**뿐이다.

```yaml
sourceRepos:
  + https://argoproj.github.io/argo-helm      # 증분 ② — ArgoCD 자기 관리
  + https://kyverno.github.io/kyverno/        # 증분 ③
  + https://kedacore.github.io/charts         # 증분 ④

clusterResourceWhitelist:
  + { group: "",                       kind: Namespace }    # ③④ 공용 — §2.10.0 판정 ①
  + { group: kyverno.io,               kind: ClusterPolicy } # ③ — 정책 11개
  + { group: apiregistration.k8s.io,   kind: APIService }    # ④ — external.metrics
```

> ### 🔑 **재사용할 판단 — "차트가 크다"와 "whitelist가 커진다"는 다른 질문이다**
>
> Kyverno는 cluster-scoped 리소스를 **47개** 만드는데 whitelist 추가는 **1개**다(+공용 Namespace).
> whitelist는 **kind 단위**이고, 대부분의 차트는 같은 몇 가지 kind(CRD·ClusterRole·CRB·webhook)를
> 반복해서 쓰기 때문이다.
> ⇒ **첫 addon이 목록의 대부분을 연다.** 증분 ①이 낸 5종이 이후 세 증분의 거의 전부를 커버했다.
> 📌 각 증분마다 **렌더해서 세는 절차는 그대로 유지한다** — 값이 작다는 것이 *"안 세도 된다"* 를 뜻하지 않는다.
> 실제로 이번에도 `APIService`와 `ClusterPolicy` **2건이 그 절차로만 잡혔다.**

---

### 2.10.5 ✅ **apply 판정 — 증분 ②③④ 전부 배포 완료** (2026-08-11, workbench SSM 실물 조회)

| 증분 | 커밋 | 결과 |
|---|---|---|
| ② | `3cecd80` (PR #2) | ✅ `Application/argocd` 생성 · **파드 재시작 0** · root App 무결 |
| ③ | `b13e9ea` (PR #5) | ✅ Kyverno 4 컨트롤러 Running · ClusterPolicy 11개 `Ignore`/`Audit` |
| ④ | `1bb27e9` (PR #4) | ✅ KEDA 3 파드 Running · `APIService` **Available** · **`Synced Healthy`** |

⚠️ PR 번호가 ③만 **#3 → #5**로 바뀌었다. 절차 사고이며 아래 「📌 절차」가 소유한다.

#### ✅ 통과한 판정

| # | 항목 | 결과 |
|---|---|---|
| 1 | 🆕 **노드의 `ghcr.io` 이미지 pull** | ✅ **통과** — `reg.kyverno.io/kyverno/*` 4종 · `ghcr.io/kedacore/*` 3종 전부 기동. §2.10.0이 *"canary로 앞당길 수 없다"* 고 남긴 축이 **열렸다** |
| 2 | **판정 ① 실증** — `CreateNamespace` ↔ whitelist | ✅ ns `kyverno`·`keda` 생성, `not permitted` 오류 **0건**. `{group:"", kind: Namespace}` 를 **미리 연 것이 맞았다** |
| 3 | Kyverno 정책 | ✅ 11개 전부 `failurePolicy=Ignore` · `background=true` · `Succeeded` — **의도한 값 그대로** |
| 4 | 🔴 `APIService` ↔ `metrics-server` | ✅ `v1beta1.external.metrics.k8s.io` **Available/Passed**, `v1beta1.metrics.k8s.io` **그대로 Passed** — 그룹이 달라 충돌하지 않는다는 예측이 **실측으로 확인** |
| 5 | ⭐ **라벨 옵트인**(②경로 첫 실증) | ✅ **인과적으로 보였다** — cluster Secret 라벨이 `<no value>` → `enabled` 로 바뀐 **직후** Application 이 나타났다 |
| 6 | 기존 워크로드 무영향 | ✅ ALBC · Karpenter · NodePool · root-app 전부 `Synced Healthy` 유지 |
| 7 | ② 파드 재시작 | ✅ **0회** — argocd 파드 5개의 `startTime` 이 **2026-08-07 그대로**. `automated` 를 안 켠 것이 실제로 아무것도 건드리지 않았다 |

#### 🔴 **핵심 발견 — `ServerSideApply=true` 는 *적용* 만 바꾸고 *diff* 는 바꾸지 않는다**

> ## ⭐ **세 개의 `OutOfSync` 가 전부 같은 원인이었다**
>
> | 대상 | non-Synced | live 를 쓴 field manager |
> |---|---|---|
> | ② `Application/argocd` | **37개 전부** | **`helm`** — `meta.helm.sh/release-name`·`release-namespace` 애노테이션. `helm install` 이 붙이고 `helm template` 은 안 붙인다 |
> | ③ `kyverno` | CRD **11개**(`policies.kyverno.io`) | ~~**`kube-apiserver`** — 스키마 기본값을 채운다~~ 🔴 **틀렸다 → §2.10.6** |
> | ③ `kyverno-policies` | ClusterPolicy **11개** | ~~**`kyverno`** — 자기 mutating webhook 이 admission 에서 주입한다~~ 🔴 **틀렸다 → §2.10.6** |
>
> 🔴 **뒤 두 줄의 귀인은 2026-08-11 같은 날 실측으로 반증됐다**(§2.10.6). 두 매니저 모두 실제로는
> **`status` 서브리소스만** 소유하고, 차이나는 필드는 **apiserver 가 CRD 스키마의 `default:` 로 채운
> 무소유 필드**였다. **mutation webhook 은 관여하지 않는다.**
> ⚠️ 결론(*"선언하지 않은 필드를 우리가 안 가졌다"*)은 유효하고 아래 문단도 유효하다 — **틀린 것은 범인 이름**이다.
>
> **셋 다 "우리가 선언하지 않은 필드를 다른 매니저가 소유"** 다. `ServerSideApply=true` 는 그 필드를
> **건드리지 않게** 해 주지만(그래서 `argocd-secret` 이 안전했다), ArgoCD 의 **diff 계산은 여전히
> 클라이언트 측**이라 그 필드가 차이로 잡힌다.
> ⇒ 🔑 **`ServerSideApply` 와 `ServerSideDiff` 는 별개 스위치다.** 하나를 켰다고 다른 하나가 켜지지 않는다.
>
> ### ⭐ **KEDA 가 대조군이 되어 진단을 확증했다**
> 같은 날 **같은 옵션**(`ServerSideApply=true`·`CreateNamespace=true`)으로 배포했는데 KEDA만
> **`Synced Healthy`** 다. 차이는 **KEDA는 자기 리소스를 런타임에 변형하지 않는다**는 것뿐이다.
> ⇒ *"ArgoCD 설정이 잘못됐다"* 가설이 **배제된다.** 📌 **증분을 나눈 덕에 대조군이 생겼다.**
>
> ### 🔴 **방치하면 안 되는 이유는 sync 실패가 아니라 신호 오염이다**
> 두 Application 모두 `phase=Succeeded` · *"successfully synced (all tasks run)"* 이고 리소스는
> 정상 동작한다. **기능적으로는 문제가 없다.**
> ⛔ 그러나 **항상 `OutOfSync` 이면 "`OutOfSync` = 문제"라는 신호가 죽는다** — 진짜 drift 가
> 들어와도 구분할 수 없다.
> 🔑 이 세션에서 같은 범주의 사고가 **세 번째**다(D-ROOTAPP-SKIP 자기 점검의 `^./` 앵커 ·
> CI 캐시 판정 기준 "8회") — **거짓 신호를 내는 장치는 곧 무시당한다.**
>
> ✅ **닫혔다 — §2.10.6 (D-SSDIFF)**: 실측 후 **`ServerSideDiff=true`** 로 결정했다.
> ⭐ *"즉흥으로 넣지 않는다"* 를 지킨 값이 실제로 나왔다 — 실측이 **위 표의 귀인 2건을 반증**했고,
> 그 정정이 `IncludeMutationWebhook` 을 넣지 않는 근거가 됐다. 바로 넣었다면 원인을 틀리게 안 채로
> 맞는 옵션을 골랐을 것이고, **다음에 비슷한 증상이 오면 같은 오진을 반복**했을 것이다.

#### ⏭️ 증분 ②의 2단계(PR-②b)에 남은 질문

`automated` 를 켜면 **37개 리소스에 sync 가 걸린다**(`Deployment` 4 · `StatefulSet` 1 포함).
`meta.helm.sh/*` 는 `helm` 매니저 소유라 SSA로 **제거되지 않으므로**, 켜도 `Synced` 가 안 되고
`selfHeal` 이 계속 재시도할 수 있다.
⭐ **이 질문을 배포 없이 물을 수 있다는 것이 결정 5(2단계 분리)의 값이다** — 한 번에 켰다면
**ArgoCD 자신을 재시작시키며** 답을 배웠을 것이다.

#### 📌 절차 — **스택 PR을 squash + `--delete-branch` 로 머지하면 자식 PR이 닫힌다**

②(#2)를 `--delete-branch` 로 머지하자 그 브랜치를 base 로 삼던 **#3이 자동으로 CLOSED** 됐고,
**닫힌 PR은 base 를 바꿀 수 없어**(`Cannot change the base branch of a closed pull request`)
새 PR(#5)을 열어야 했다. 게다가 squash 라 자식 브랜치에는 부모의 **원본 커밋**이 남아 `CONFLICTING` 이었다.

⇒ **규칙**: 스택을 머지할 때는 ⓐ `--delete-branch` 를 쓰지 않고, ⓑ 다음 PR 을 `main` 으로
**리베이스 + retarget** 한 뒤, ⓒ 마지막에 브랜치를 지운다.
🔑 브랜치가 원격에 남아 있어 **잃은 것은 없었다** — 복구 가능성이 사고의 크기를 결정한다.

#### ⚠️ 부수 발견 — workbench 의 kubeconfig 는 **인스턴스 교체와 함께 사라진다**

판정을 시작하려는데 workbench 어디에도 kubeconfig 가 없었다(`find` 전수 0건).
`workbench-v0.4.0`(D-WORKBENCH-SIZE)이 **인스턴스를 교체**했고, 손으로 만든 kubeconfig 는
그때 사라졌다. ⇒ [`40`](40-workbench.md)이 소유하는 문제로 넘긴다.

- 실측: workbench role `iamr-ref-dev-an2-workbench-01` 은 **`eks:DescribeCluster` 는 되고
  `eks:ListClusters`·`eks:ListAccessEntries` 는 안 된다** ⇒ `aws eks update-kubeconfig --name <이름>` 은
  **클러스터 이름을 알면 동작한다**(이름 없이 목록으로 찾는 흐름은 막힌다).
- ✅ Access Entry 에는 등재돼 있다 — kubeconfig 만 만들면 `kubectl` 이 통한다.

---

### 2.10.6 🔴 **D-SSDIFF — `OutOfSync` 고착은 `ServerSideDiff` 로 푼다** (2026-08-11 확정)

§2.10.5가 후속 증분(②-b·③-b)에 넘긴 질문 — *`ServerSideDiff=true` 인가 대상별 `ignoreDifferences` 인가* —
을 **실측으로 닫는다.** 전제 실측: ArgoCD **v3.5.0**(`quay.io/argoproj/argocd:v3.5.0`),
ServerSideDiff 는 **v3.1.0 에서 stable**([공식 문서](https://argo-cd.readthedocs.io/en/stable/user-guide/diff-strategies/)).

#### 🔴 먼저 — §2.10.5의 원인 서술 2건이 틀렸다

| §2.10.5 서술 | 실측 (`--show-managed-fields`) |
|---|---|
| ② `argocd-cm` = `helm` 소유 | ✅ **맞다.** 다만 매니저가 **`helm` 하나뿐**이다 — `argocd-controller` 가 **아예 없다**(automated 를 안 켰으니 당연). ArgoCD 는 이 37개를 **한 번도 적용한 적이 없다** |
| ③ CRD = *"`kube-apiserver` 가 스키마 기본값을 채운다"* | 🔴 **틀렸다.** `kube-apiserver` 는 **`subresource: status` 만** 소유한다. `spec` 은 `argocd-controller`(Apply) 단독이고, 실제 차이는 **`spec.conversion`** — managedFields 어디에도 없는 **무소유 필드**다 |
| ③ ClusterPolicy = *"`kyverno` 자기 mutating webhook 이 주입한다"* | 🔴 **틀렸다.** `kyverno` 매니저도 **`status` 만** 소유한다. 실제 차이는 **`spec.admission`·`spec.emitWarning`** — **Kyverno CRD openAPI 스키마의 `default:`** 를 apiserver 가 채운 것이다 |

⇒ 원인은 **세 가지가 아니라 두 가지**다: **① `helm` 이 소유한 애노테이션** · **② apiserver defaulting**(CRD·ClusterPolicy 공통).
🔑 **mutation webhook 은 애초에 관여하지 않았다** — 이 사실이 아래 **결정 2**를 직접 가른다.
🔑 **어떻게 틀렸나**: 판정 당시 *"다른 매니저가 소유"* 까지만 보고 **어느 매니저가 무엇을 소유하는지**
(`managedFields[].subresource`)를 열지 않았다. ⛔ **요약이 맞아 보이면 한 겹 더 열지 않게 된다** —
§2.10.5의 상위 결론(`ServerSideApply` ≠ `ServerSideDiff`)이 맞았기 때문에 하위 귀인이 검증을 통과해 버렸다.

#### ✅ 실측 — SSA dry-run 은 비파괴이고, `ServerSideDiff` 가 하는 일 그 자체다

**방법**: live 객체에서 *우리가 선언하지 않은 필드* 를 제거해 desired 를 합성하고
`kubectl apply --server-side --dry-run=server --field-manager=argocd-controller` 로 predicted 를 얻어
live 와 비교했다. 클러스터를 바꾸지 않는다.

| 대상 | desired 에서 뺀 것 | predicted vs live |
|---|---|---|
| `ClusterPolicy/disallow-host-path` | `spec.admission`·`spec.emitWarning` | **IDENTICAL** (predicted 가 둘을 되살렸다) |
| `CRD/mutatingpolicies.policies.kyverno.io` | `spec.conversion` | **IDENTICAL** |
| `ConfigMap/argocd-cm` | 애노테이션 **전부** | `meta.helm.sh/*` **보존됨** |
| 🔴 `Secret/argocd-secret` (§2.10.1 위험 1) | `data` **전체** | 5개 키(`admin.password`·`admin.passwordMtime`·`server.secretkey`·`tls.crt`·`tls.key`) **전부 보존됨** |

⇒ **`ServerSideDiff=true` 하나로 세 Application 이 전부 `Synced` 가 된다.**

#### 결정 1 — **`ServerSideDiff=true`. `ignoreDifferences` 가 아니다**

원인이 *"선언하지 않은 필드는 live 를 따른다"* **하나**이고, SSA dry-run 이 그것을 그대로 구현한다.
`ignoreDifferences` 는 **같은 원인을 세 모양으로 세 번** 열거해야 한다(애노테이션 2개 ·
`spec.conversion` · `spec.admission`+`emitWarning`), 그리고 **차트가 기본값을 늘릴 때마다 다시** 열거해야 한다.
⚠️ `CLAUDE.md` 「닫힌 열거는 값이 늘 때마다 부채가 된다」가 정확히 이 형태다.
- ⛔ **`managedFieldsManagers: [helm]` 변형도 기각한다** — apiserver 기본값은 **소유자가 없어서**
  그 방식으로 잡히지 않는다(위 실측: `spec.conversion` 은 managedFields 어디에도 없다). ②만 풀고 ③은 남는다.

#### 결정 2 — **`IncludeMutationWebhook` 은 넣지 않는다** (기본값 `false` 유지)

gitops-engine `pkg/diff/diff.go`: `ignoreMutationWebhook` 일 때
`removeWebhookMutation(predictedLive, live, gvkParser, manager)` 가 **manager 소유가 아닌 필드를
live 값으로 되살린다** — 우리 네 케이스가 정확히 그 형태다. 위 정정대로 **웹훅 주입은 없었으므로
켤 이유가 없다.** ⚠️ 켜면 반대로 웹훅 변형까지 diff 에 들어와 새 고착을 만든다.

#### 결정 3 — **앱 3개 애노테이션. 전역 스위치가 아니다** (2026-08-11 사용자 결정)

전역(`argocd-cmd-params-cm` 의 `controller.diff.server.side: "true"`)은 한 줄이지만
ⓐ application-controller **재시작**이 필요하고 ⓑ 현재 `Synced` 인 앱들(ALBC·Karpenter·NodePool·KEDA·root-app)의
diff 계산까지 **동시에** 바꾼다.
⭐ **KEDA 가 대조군인 것이 이 증분이 번 자산이다**(§2.10.5) — 전역으로 켜면 **그 대조군을 잃는다.**
⏭️ **승격 조건**: 신규 addon 이 같은 이유로 `OutOfSync` 가 되는 사례가 **2건 더** 나오면 전역으로
올리고 controller 재시작 1회를 감수한다. 그 전에는 올리지 않는다.

#### 🔴 대가 — 바꾸는 것은 표시 방식이 아니라 **"무엇을 drift 로 볼 것인가"의 정의**다

ServerSideDiff 는 *우리가 선언하지 않은 필드* 의 변경을 **더 이상 drift 로 보고하지 않는다.**
누가 `argocd-cm` 에 애노테이션을 하나 더 붙여도 `Synced` 다.
그럼에도 택하는 이유는 §2.10.5 가 적은 것과 같다 — **항상 `OutOfSync` 이면 신호가 죽는다.**
🔑 **좁지만 살아 있는 신호가, 넓지만 아무도 안 보는 신호보다 낫다.**
⚠️ **부하**: 리소스마다 dry-run apply 1회. 캐시되며 refresh·revision·resourceVersion 변경 때만 재요청한다(공식 문서).

#### ⚠️ 이 실측이 **답하지 않은 것** — PR-②b 의 conflict 질문은 여전히 열려 있다

위 dry-run 은 `--force-conflicts` **없이도 통과**했지만, 그것을 *"실제 sync 도 conflict 없이 된다"* 로
읽으면 안 된다 — desired 를 **live 에서 합성**했으므로 값이 같아 conflict 가 **날 수 없는 구성**이었다.
차트 렌더본과 live 가 다른 필드에서 `helm` 매니저와 부딪히는지는 **미판정**이다.
- 확인한 것: diff 경로의 구조적 병합은 `Apply(..., force=true)` 로 호출된다(`pkg/diff/diff.go`).
  ⛔ **sync(실제 apply) 경로의 force 여부는 확인하지 않았다** — PR-②b 가 소유한다.

#### 적용 대상 3곳 (`iac-platform-gitops`)

| 파일 | 대상 | 위치 |
|---|---|---|
| `bootstrap/argocd-app.yaml` | `Application/argocd` | `metadata.annotations` **신설** |
| `addons/baseline/kyverno.yaml` | ApplicationSet `kyverno` | `template.metadata.annotations` (`sync-wave` 옆) |
| `addons/baseline/kyverno.yaml` | ApplicationSet `kyverno-policies` | 〃 |

값은 세 곳 모두 `argocd.argoproj.io/compare-options: ServerSideDiff=true`.

#### 📋 판정 항목 (머지 후)

| # | 항목 | 기대 |
|---|---|---|
| 1 | 세 Application | `Synced Healthy` |
| 2 | **파드 재시작 0** | diff 전략은 apply 를 하지 않는다. `argocd` 앱은 `automated` 가 꺼져 있어 더더욱 |
| 3 | `Secret/argocd-secret` | data 5키 유지 (§2.10.1 위험 1 — dry-run 이 이미 예측했다) |
| 4 | 현재 `Synced` 인 앱 + root-app | **무영향** — 애노테이션을 안 건드렸으니 그래야 한다 |
| 5 | ⚠️ 반증 조건 | 셋 중 **하나라도** `OutOfSync` 로 남으면 그 대상만 `ignoreDifferences` 로 보완하고 **근거를 여기 적는다** |

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
> 📌 **이 "2건"은 아래 §3.1이 재판정했다 — self-managed 경로에서는 두 번째가 성립하지 않는다.**
> 첫 번째(whitelist)만 남는다.
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

## 3.1 🔀 `platform` AppProject — 경로별 구체값 + **선결 과제 재판정** (2026-08-10 신설)

§3 본문의 구체값은 **관리형 Capability 전제**다. 여기서 경로별 값을 확정하고, §3이 예고한
*"addon 증분의 선결 과제 2건"* 을 다시 판정한다.

### 경로별 구체값

| 필드 | 관리형 (§3 본문) | **self-managed (현행 실물)** | 갈리는가 |
|---|---|---|:---:|
| `sourceNamespaces` | `[argocd]` — **강제**(capability가 단일 ns) | `[argocd]` — **규약으로 유지** | 🔶 강제성만 |
| `sourceRepos` | CodeConnections 프록시 URL | **`https://github.com/skax-ca/iac-platform-gitops.git`** | 🔀 §1.1 |
| `destinations` | `[{server: <EKS ARN>, namespace: '*'}]` | `[{server: https://kubernetes.default.svc, namespace: '*'}]` | 🔀 §4.1 |
| `clusterResourceWhitelist` | `[]`에서 시작 → 증분마다 개방 | **동일** | ⛔ |
| `namespaceResourceWhitelist` | `[{'*','*'}]` | **동일** | ⛔ |

> ### 📌 **`sourceNamespaces`는 값이 같고 이유가 다르다 — 그래서 규약으로 남긴다**
>
> 관리형은 Application을 capability 네임스페이스 1개에만 둘 수 있어 **강제**다. self-managed는
> upstream 전체를 쓰므로 **자유**다(apps-in-any-namespace 가능).
> ⇒ 그럼에도 `[argocd]`로 고정한다: **경로를 바꿔도 매니페스트가 그대로 통하게** 하기 위해서다
> ([`23 §3`](23-argocd-self-managed.md) 갈림점 4). 🔑 **자유로운 쪽을 제약 있는 쪽에 맞춰 두면
> 이행이 무비용이 된다** — 반대로 열어 두면 관리형 전환 시 전수 수정이 된다.

### ⭐ 승계되는 가장 값진 자산 — `clusterResourceWhitelist` 개방 목록

§3이 두 번의 증분에서 실제로 열었던 kind 목록은 **경로와 무관하다**(k8s API 그룹의 사실이다).
addon 증분은 이것을 그대로 쓴다.

```yaml
clusterResourceWhitelist:
  # ── ALBC 증분 (2026-07-25) ──
  - {group: apiextensions.k8s.io,         kind: CustomResourceDefinition}
  - {group: rbac.authorization.k8s.io,    kind: ClusterRole}
  - {group: rbac.authorization.k8s.io,    kind: ClusterRoleBinding}
  - {group: admissionregistration.k8s.io, kind: ValidatingWebhookConfiguration}
  - {group: admissionregistration.k8s.io, kind: MutatingWebhookConfiguration}
  # ── Karpenter 증분 (2026-07-27) — 위 5종은 재사용된다 ──
  - {group: karpenter.sh,                 kind: NodePool}
  - {group: karpenter.sh,                 kind: NodeClaim}
  - {group: karpenter.k8s.aws,            kind: EC2NodeClass}
```
⚠️ **한꺼번에 붙여넣지 않는다.** §3의 원칙은 *"그 addon이 실제로 만드는 kind만, 그 증분에서"* 이고
그 시점이 곧 **권한 확대의 리뷰 지점**이다. 위 목록은 **도착지**이지 시작값이 아니다.

---

### 🔴 **선결 과제 재판정 — 2건이 아니라 1건이고, 그 1건은 차단 요인이 아니다** (self-managed 한정)

§3은 이렇게 적었다:

> ⚠️ 이 선택은 addon 증분에서 **의도된 실패**를 만든다(sync 시 "resource not permitted in project").
> **20 §2.8의 Access Entry ns 스코프 문제와 함께 그 증분의 선결 과제 2건이다.**

**두 번째(Access Entry → apiserver RBAC)는 self-managed 경로에 존재하지 않는다.**

| 근거 | 실측 |
|---|---|
| ① ArgoCD가 **클러스터 안**에 있다 | §4.1 1단계 — Access Entry 자체가 불필요. apiserver 접근은 **ServiceAccount** |
| ② chart가 **cluster-admin을 준다** | `argo-cd 10.3.0` 기본값 `createClusterRoles: true` · `controller.clusterRoleRules.enabled: false` ⇒ application controller의 ClusterRole이 `apiGroups: ['*'] / resources: ['*'] / verbs: ['*']` + `nonResourceURLs: ['*']` (chart 원문 실측) |
| ③ 실물이 그렇게 동작한다 | `argocd admin cluster stats -n argocd` → **Successful · resources 536**(2026-08-10). 관리형이 막혔던 **cluster-wide read가 그대로 된다** |

⇒ **D-ARGOCD-CLUSTER-READ**(20 §2.8 열린 항목)와 **D-ARGOCD-CLUSTER-WRITE**([`21 §2.8`](21-gitops-bootstrap-seam.md))는
**관리형 경로의 결정**이다. self-managed에서는 **재현되지 않는다** — 관리형의 auto-managed Access Entry가
`kubernetesGroups`를 비워 두는 것이 원인이었고, 그 산출물 자체가 여기엔 없다.

⇒ **남는 것은 `clusterResourceWhitelist` 하나**다.

> ### ⚠️ **"0건"이라고 쓰지 않는 이유 — 남은 1건은 사라진 것이 아니라 성격이 다르다**
>
> 사라진 쪽(Access Entry/RBAC)은 **다른 repo·다른 계층에서 먼저 끝나야 하는 일**이었다 —
> 진짜 의미의 선행 과제다. 남은 쪽(whitelist)은 **같은 저장소·같은 PR에서 addon 매니페스트와
> 함께 여는 것**이라 착수를 막지 않는다.
> ⛔ 그럼에도 **"없다"고 쓰지 않는다.** 빠뜨리면 sync가 `resource not permitted in project`로
> 실패하고, §3이 그것을 **"의도된 실패"** 라고 부른 이유가 바로 리뷰를 강제하기 위해서다.
> 🔑 **차단 요인이 아닌 것과 잊어도 되는 것은 다르다.**

> ## ⛔ **뒤집어 읽지 말 것 — 이건 "더 안전하다"가 아니라 "더 넓게 열려 있다"이다**
>
> 관리형에서 그 벽이 있었던 것은 **결함이 아니라 최소권한의 부작용**이었다. AWS가 준 Access Entry는
> 좁았고, 그래서 넓히는 결정(D-ARGOCD-CLUSTER-WRITE)을 **명시적으로** 내려야 했다 — 그 결정이 곧 리뷰였다.
>
> self-managed는 **chart 기본값이 이미 cluster-admin**이라 그 리뷰 지점이 **아예 생기지 않는다.**
> ⇒ 🔑 **AppProject `clusterResourceWhitelist`가 실질적으로 유일한 가드레일이 된다.**
> §3이 `[]`에서 시작하기로 한 선택은 관리형보다 self-managed에서 **더** 중요하다.
> ⛔ *"어차피 controller가 cluster-admin이니 whitelist는 형식"* 이라는 추론은 **틀렸다** —
> 두 층은 다른 것을 막는다. ClusterRole은 **apiserver가** 막고, whitelist는 **ArgoCD가** 막는다.
> 후자는 *"저장소에 실수로 들어온 매니페스트"* 를 막는 층이고, 그게 GitOps에서 실제로 일어나는 사고다.
>
> 📌 **재검토 조건**: controller ClusterRole을 좁히려면 `controller.clusterRoleRules`로 가능하다
> (chart가 지원). ⚠️ 다만 ArgoCD가 관리할 **모든** kind를 열거해야 해서 addon이 늘 때마다
> 부채가 된다([`CLAUDE.md`](../../CLAUDE.md) *"닫힌 열거는 값이 늘 때마다 부채가 된다"*).
> **고객사 보안 요건이 실제로 요구할 때** 착수한다.

> ### 🔶 **`default` AppProject — 결론은 같고 근거가 갈린다**
>
> §3의 근거는 *"capability가 만든 리소스라 우리가 수정했을 때 되돌리는지 **미검증**"* 이었다.
> self-managed에는 그 전제가 없다 — **chart 템플릿에 AppProject가 없다**(argo-cd 10.3.0
> `templates/` 전수 실측: `argocd-configs`·`crds`·컴포넌트별 디렉토리뿐). `default`는 **Argo CD
> 런타임이 부재 시 생성**하는 upstream 산출물이다.
>
> ⇒ **결론은 유지된다: 쓰지 않는다.** 근거만 바뀐다 —
> **`default`를 좁히면 그 변경이 Git 밖에 있게 되어 자기소멸 원칙(§4)을 정면으로 위반한다.**
> 전용 `platform` 프로젝트는 **저장소가 소유**하므로 그 문제가 없다.
>
> 🔑 **관리형에서는 "되돌려질까 봐" 안 건드렸고, self-managed에서는 "Git에 없어서" 안 건드린다.**
> ⇒ *"런타임이 수정을 reconcile 하는가"* 는 **판정할 필요가 없는 질문**이 됐다. 어차피 쓰지 않는다.

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
| 실행 **절차·검증** | ✅ **[`scripts/argocd-seed.sh`](../../scripts/argocd-seed.sh) + [`scripts/README.md`](../../scripts/README.md)** (2026-08-07) | 재현성·감사. ⚠️ *"`docs/runbooks/` 신설 예정"* 은 **폐기** — 절차가 실행 가능한 스크립트라 문서 디렉토리가 아니라 `scripts/`가 맞다 |
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

> ## 🔴 **2단계는 자기소멸 원칙의 *유일한 예외*다** (2026-08-07 신설)
>
> §4의 자기소멸 원칙은 *"손으로 apply하는 매니페스트는 저장소에 커밋된 것과 **바이트 단위로
> 동일**해야 한다"* 고 요구한다. **repository Secret은 그럴 수 없다** — GitHub App private key가
> 들어 있어 **저장소에 커밋하면 안 되기 때문**이다.
>
> ⇒ **이 Secret 하나만 저장소가 소유하지 않는다.** root App이 훑어도 대상이 없고,
> `selfHeal`·`prune`의 관리를 받지 않는다. **의도된 예외**이며 아래가 성립해야 한다:
> - root App의 `prune: false`(§4) 덕에 **지워지지 않는다**
> - 이 Secret이 사라지면 ArgoCD가 저장소를 못 읽어 **모든 sync가 멈춘다** ⇒ 복구 절차에 명시한다
>
> ⚠️ **관리형에는 이 예외가 없다** — CodeConnections는 Secret을 만들지 않고 IAM으로 끝난다
> ([`§1.1`](#11--d-repo-codeconnections-재판정--경로마다-갈린다-2026-08-07)).
> 🔑 **`§1.1`이 말한 *"장기 자격증명을 만들지 않는다"* 의 대가가 여기서 두 번째 형태로 나타난다** —
> 자격증명이 생길 뿐 아니라 **GitOps 관리 밖의 리소스가 하나 생긴다.**
>
> 📌 **해소 경로는 있으나 지금 쓰지 않는다**: External Secrets Operator + Secrets Manager ·
> Sealed Secrets · SOPS. 전부 **컴포넌트를 하나 늘린다** — 요구가 생기면 그때 연다
> (CLAUDE.md *"지금 요구를 채우는 가장 단순한 형태"*).

> ### 📌 **GitHub App 규격** (2026-08-07 확정 — 기존 CI용 App 실측을 기준으로)
>
> | 항목 | 값 | 근거 |
> |---|---|---|
> | 소유 | org **`skax-ca`** | 개인 계정에 묶이면 퇴사·권한 변경으로 끊긴다 |
> | 권한 | **Repository → Contents: Read-only** (`metadata: read`는 자동) | 기존 `skax-ca-module-reader` 실측과 동일. ArgoCD는 **clone만** 한다 |
> | 이벤트(webhook) | **없음** | ⭐ ArgoCD가 `ClusterIP`+port-forward라([`23 §2.2`](23-argocd-self-managed.md)) **GitHub webhook을 받을 수 없다.** 폴링만 쓴다 |
> | 설치 범위 | **`skax-ca/iac-platform-gitops` 하나** | ⛔ *All repositories* 금지 |
>
> ⛔ **CI용 `skax-ca-module-reader`를 재사용하지 않는다**([`§1.1`](#11--d-repo-codeconnections-재판정--경로마다-갈린다-2026-08-07)) —
> 다른 주체·다른 blast radius다.
> 🔑 **webhook을 끄는 것이 도달성 결정의 부수 효과**라는 점에 주의: 관리형으로 전환하면
> ArgoCD 서버가 URL을 갖게 되어 **webhook을 다시 검토할 수 있다.**

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

## 4.2 🔴 **D-ROOTAPP-SKIP — root App 훑기에서 파일을 빼는 방법** (2026-08-10, 두 번의 실패에서)

**`directory.exclude`를 늘리지 않는다. 파일 안에 `+argocd:skip-file-rendering` 마커를 넣는다.**

증분 ①(ALBC·Karpenter)이 `{{ }}` 템플릿을 담은 로컬 helm 차트를 들여오면서 필요해졌고,
**두 가지 방법으로 연속해서 실패했다.** 둘 다 §4의 자기소멸 원칙의 그림자다.

### 실패 ① — `exclude` 확장은 **자기소멸 데드락**을 만든다

같은 커밋에 ⓐ 차트 파일과 ⓑ 그것을 걸러낼 `exclude`를 함께 넣었더니 root App이 멈췄다:

```
Failed to unmarshal "ec2nodeclass.yaml": json: offset 2: invalid character '{' …
```

1. root App은 **자기 spec을 git에서 읽어 갱신**한다 — 그러려면 **먼저 저장소를 렌더**해야 한다
2. 렌더는 **아직 적용되지 않은 옛 `exclude`** 로 수행된다
3. 옛 `exclude`는 새 차트 템플릿을 못 걸러낸다 → 렌더 실패
4. 렌더가 실패하니 **새 `exclude`가 영원히 적용되지 않는다** — 무한 루프

> ### ⚠️ **글롭 문제로 오진할 뻔했다 — "설정이 틀렸나"보다 "적용되긴 했나"를 먼저 본다**
>
> 첫 가설은 *"`**` 패턴이 안 먹는다"* 였다. **틀렸다.** ArgoCD가 쓰는 `gobwas/glob`을
> (separators 없이 컴파일하는) 실제 호출 방식 그대로 재현하니
> `{…,addons/karpenter/nodepool/**}` 는 대상 경로에 **정확히 매치**했다.
> 확증은 실물이었다 — `.spec.source.directory.exclude`가 **옛 값 그대로**였다.
> 🔑 **패턴을 계속 고쳤다면 영원히 못 고쳤을 것이다.** 설정이 안 듣는 것처럼 보이면
> **그 설정이 살아 있는 spec에 들어갔는지부터** 확인한다.

### 실패 ② — **마커를 *설명하는* 주석도 마커다**

마커로 바꾸면서 `bootstrap/root-app.yaml` **주석에 마커 문자열을 그대로 적었다.**
판정은 파일 전체 **문자열 포함 검사**(`bytes.Contains`)라, 주석이든 뭐든 한 번 나타나면 그 파일이
통째로 빠진다 ⇒ **root App이 자기 자신을 스캔에서 제외**했다.

증상이 조용하다 — 에러가 없고 이것만 나온다:
```
RESULT PruneSkipped Application/root-app :: ignored (requires pruning)
log: Skipping auto-sync: need to prune extra resources only but automated prune is disabled
```
저장소 렌더 결과에 root App이 없으니 **live에만 있는 여분 리소스**가 되어 영구 `OutOfSync`다.

> ## ⭐ **`prune: false`가 재앙을 막았다 — §4의 결정이 값을 회수한 순간**
>
> root App이 *"저장소에 없는 리소스"* 로 분류됐으므로, `prune: true`였다면
> **root App이 스스로를 삭제**하고 seed 5단계를 처음부터 다시 밟아야 했다.
> §4가 *"root 레벨에서 prune을 켜면 저장소 실수 하나가 `platform` AppProject와 cluster Secret까지
> 지워 seed를 다시 밟게 한다"* 고 적은 시나리오가 **정확히 실현됐다.**
> 🔑 **방어 결정의 값은 사고가 나야 회수된다** — 그때까지는 비용처럼만 보인다.

### ⇒ 규칙

| | `exclude` | **마커** |
|---|---|---|
| 어디에 사는가 | root App **spec** | **파일 자신** |
| 새 파일 추가 시 | spec 변경 필요 → **데드락 가능** | 변경 없음 |
| 파일 이동·개명 | 패턴을 같이 고쳐야 함 | **따라간다** |
| 판정 | 경로 글롭(`gobwas/glob`) | 내용 검사(`bytes.Contains`) |

- 평문 YAML: `# +argocd:skip-file-rendering` · helm 템플릿: `{{- /* … */ -}}`
  (**파일 내용에는 남고 렌더 출력에는 안 남는다** — 검증됨)
- ⛔ **다른 `.yaml`에 마커 문자열을 적지 않는다.** 문서(`.md`)는 안전하다 —
  스캔 대상은 `^.*\.(yaml|yml|json|jsonnet)$` 뿐이다.
- 기존 `exclude` 항목은 **그대로 둔다**(동작 중인 것을 건드리지 않는다). **늘리지만 않는다.**
- **자기 점검**: `grep -rl 'argocd:skip-file-rendering' --include='*.yaml' …` 로
  의도 밖 파일이 마커를 물고 있지 않은지 본다. 출력이 있으면 **조용히 빠지고 있다.**

> ### 📌 **재사용할 판단 — 자기소멸 모델의 일반 위험**
>
> *"root App이 자기 자신을 관리한다"* 는 **자기 spec을 바꾸는 변경에 순서 제약을 만든다.**
> ⇒ **root App spec 변경과, 그 변경이 있어야 처리되는 파일을, 같은 커밋에 넣을 수 없다.**
> 해법은 둘 중 하나다: **①커밋을 둘로 쪼갠다** 또는 **②spec을 안 건드리는 수단을 쓴다.**
> ⭐ 마커가 ②이고, 순서 제약이 **사라지므로** 우월하다.

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
> 🔴 **~~이 상자를 근거로 GitOps repo 구조를 확정하지 않는다.~~ 제한 해제 (2026-08-10)** — 아래 참조.

> ## ✅ **§5 인용 제한 해제 — 이 절은 경로 무관하다** (2026-08-10, 2차 부분 개정)
>
> 위 상자는 *"이 문서가 미개정이라 인용 불가"* 라는 이유로 자기 자신에 제한을 걸었다.
> **그 제한을 푼다.** 이 표에 PoC 전제가 **하나도 없기** 때문이다:
>
> - 표가 답하는 질문은 *"이 addon을 **Terraform이 까는가 GitOps가 까는가**"* 하나이고,
>   그 판정 함수는 **D-ADDON-BOUNDARY**([`20 §1.1`](20-eks-module.md))다 —
>   입력이 *"`aws_eks_addon`으로 설치되는가"* 라서 **ArgoCD의 설치 형태와 무관**하다.
> - 실행 스택 종속부(TFC 워크스페이스·`workload=poc`·상대경로 소싱)가 이 절에는 **등장하지 않는다.**
> - 2026-08-06 실측(Kyverno·KEDA)은 **이 repo에서 `describe-addon-versions`로 직접** 한 것이다 —
>   PoC 승계 서술이 아니다.
>
> ⇒ **addon 증분은 이 표를 근거로 착수할 수 있다.** 함께 읽을 것: **§2.9**(팬아웃 경로 판정 ·
> **D-ADDON-NS** 네임스페이스 규칙) · **§3.1**(AppProject 개방 목록).
>
> 🔑 **이 표에 네임스페이스 열을 만들지 않는다** — **D-ADDON-NS**(§2.9)가 규칙으로 소유한다.
> *"계층 2 addon은 전용 ns를 신설한다. 예외는 ALBC·Karpenter → `kube-system` 둘뿐."*
> ⇒ 표에 값을 적으면 addon이 늘 때마다 두 곳이 갈린다. **규칙 하나가 표 전체를 덮는다.**
>
> ⚠️ **여전히 유효한 제한 2개**:
> ① 표의 `§2.6`·`§2.6a`는 **[`20`](20-eks-module.md)의 절**이다(§2.9 번호 상자).
> ② **Kyverno의 "프로파일 A 한정" 범위는 `20 §1.1`에만 있다** — 위 표는 경로(helm)만 담는다.

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
