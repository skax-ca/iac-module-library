# 문서 진입점

이 repo의 설계·규약 문서. 규칙 요약은 루트 [`CLAUDE.md`](../CLAUDE.md)를 본다.

---

## 승계 상태 (2026-07-29)

모든 문서는 `terraform-enterprise-poc` @ `76285f7`(동결 커밋)에서 승계했다.
**승계는 복사가 아니라 재검토를 동반한 이전**이므로, 문서마다 개정 수준이 다르다.

| 상태 | 의미 |
|------|------|
| ✅ **개정 완료** | 이 repo의 스택·재사용 요건으로 다시 쓴 것. **인용 가능** |
| 📋 **무편집 승계** | 도구·프로젝트 중립이라 손댈 것이 없던 것. **인용 가능** |
| ⚠️ **미개정** | PoC 전제와 실증 서술이 남아 있음. **확정 설계로 인용하지 말 것** |
| 📦 **보관** | 배포 루트(프로젝트 repo) 소유. 이 repo에서 검증 불가 |

---

## architecture — 전략·공통 규약

| # | 문서 | 내용 | 상태 |
|---|------|------|------|
| 01 | [01-module-strategy.md](architecture/01-module-strategy.md) | 계층형 하이브리드 모듈 전략, IaC↔GitOps 경계, **재사용 자산 요건** | ✅ |
| 02 | [02-naming-tagging-and-pinning.md](architecture/02-naming-tagging-and-pinning.md) | 태그·`Name` 거버넌스, 어휘 표준, 버전 핀, 모듈 소싱, 검증 게이트 | ✅ |
| 03 | [03-dependencies.md](architecture/03-dependencies.md) | SG rule 순환 해소, 공유/기반 리소스 참조(**SSM Parameter**), 소유 모델 | ✅ |
| 04 | [04-engine-decision.md](architecture/04-engine-decision.md) | **엔진 결정(D-ENGINE)** — 라이선스 재평가, **두 엔진 지원 기각 근거(실측)**, 재검토 조건 | ✅ (신규 작성) |
| **05** | [05-versioning-policy.md](architecture/05-versioning-policy.md) | **버전 정책(D-VERSION)** — `0.x` 개발 단계, **`1.x` → `0.x` 재매핑**, `1.0.0` 컷 기준 5개 | ✅ (2026-08-05 신규 작성) |

> PoC의 `02 §4`(TFC 연동)·`§5`(Phase 0 태스크)·`01 §5`(Stacks)는 **폐기**했다 — 스택 종속이거나 일회성이다.

> ⚠️ **04는 승계 문서가 아니라 이 repo에서 새로 쓴 ADR이다.** D-OSS-STACK(PoC repo `05`)의
> **엔진 축 근거를 교체**한다 — 결론(OpenTofu)은 같지만 이유가 다르다(05는 라이선스, 04는 조달 마찰·운영 비용).
> PoC는 동결이라 그쪽에 표시가 없으므로 **D-OSS-STACK을 인용할 때는 04를 함께 읽는다.**
> 특히 *"두 엔진을 지원하면 되지 않나"* 라는 제안이 나오면 **04 §3이 이미 값을 매겨 기각한 안**이다.

> ⚠️ **05도 승계 문서가 아니라 이 repo에서 새로 쓴 ADR이다.** 버전 **생애주기**를 소유한 문서가
> 없어서 `1.x`가 결정 없이 기본값처럼 쓰였고, 그 대가로 **태그를 한 번 옮겼다**(05 §0).
> 2026-08-05부로 **모든 모듈이 `0.y.z`** 이며, `1.0.0`은 05 §2의 기준 5개를 충족할 때 **모듈별로**
> 컷한다. ⛔ *"전 모듈을 1.0.0으로 맞추자"* 는 **05 §4가 기각한 안**이다.
> 이 문서가 `01 §7-2`(릴리스 프로세스 미정)의 절반을 닫는다 — 나머지 절반(번들·CHANGELOG)은 05 §5.

## design — 모듈 설계

| # | 문서 | 상태 |
|---|------|------|
| 10 | [10-vpc-module.md](design/10-vpc-module.md) | ✅ (2026-08-03 개정 — 현행 **`vpc-v0.3.0`** 계약, D13 SubnetGroup 태그 포함) |
| 20 | [20-eks-module.md](design/20-eks-module.md) | ✅ (2026-08-06 갱신 — 현행 **`eks-cluster-v0.4.0`** 계약 + §4.1~§4.4 릴리스·apply 판정 기록 + **§1.1 D-POLICY-ENGINE·D-BACKUP-AWS**) |
| **21** | [21-gitops-bootstrap-seam.md](design/21-gitops-bootstrap-seam.md) | ✅ (2026-08-07 재결정 — **§1 D-GITOPS-SEAM**: 프로파일 A 내부 분기. ⚠️ **§1만 확정이고 §2.7·§2.8 본문은 여전히 PoC 이관본**) |
| **22** | [22-day2-operations.md](design/22-day2-operations.md) | ✅ (2026-08-06 개정 — **D-DAY2-PROFILE** + **§4 백업·복구**(D-BACKUP-AWS 수용). ⚠️ 구 §4 열린 항목 → **§5**로 이동) |
| **23** | [23-argocd-self-managed.md](design/23-argocd-self-managed.md) | ✅ (2026-08-07 신규 — **D-ARGOCD-SM-BOOTSTRAP**(workbench seed + 자기 관리) · **-REACH**(port-forward) · **-AUTH** · **-HA**. ⚠️ `.tf` 산출물 없음 — 설계상 그렇다. **§5에 `helm` CLI 핀 `v3.21.3` 추가**(2026-08-07 seed 실행 후 — 표에 빠져 있어 실행자가 그 자리에서 골라야 했다. ⚠️ 강제 장치는 여전히 없다 — `helm_version`은 nullable 핀이라 **소비자가 지정해야** 한다. 2026-08-10에 `40`의 변수 설명과 예제를 이 사실에 맞췄고, 소비 repo가 실제로 켜는 것은 별건이다) |
| **24** | `design/24-argocd-managed-capability.md` | ⏳ **미작성** — 관리형 Capability 경로. 계약면은 [21 §1.7](design/21-gitops-bootstrap-seam.md) |
| 30 | [30-gitops-repo.md](design/30-gitops-repo.md) | 🔶 **부분 개정** (2026-08-07) — **§1.1**(D-REPO-CODECONNECTIONS 재판정) · **§4.1**(seed 경로별 분기)만 ✅. **§0·§1·§2·§3·§5는 미개정 = 인용 불가**. ⇒ 인용 시 **절 번호 필수**. 📌 §1에 `bootstrap/argocd-seed.sh` vendoring **포인터 상자**가 붙었다 — 결정 본체는 [40 §2.5](design/40-workbench.md)가 소유(미개정 본문에 결정을 쓰지 않는 기존 관행) |
| **40** | [40-workbench.md](design/40-workbench.md) | ✅ (2026-08-07 갱신 — **D-WORKBENCH-REPO**(§2.5, private 저장소 = GitHub App 토큰 + seed 스크립트 vendoring, **부트스트랩 시점 한정**) 신설 · §4.1에 `git`은 변수 없이 항상 설치. ✅ **`.tf` 반영 완료**(2026-08-10, `workbench-v0.2.0` — §2.5 귀결 상자의 *"nullable 패턴으로 열어야 한다"* 는 §4.1이 기각했고 구현은 §4.1을 따랐다. **T-9** 신설). 이전: **D-WORKBENCH-MODULE** · **-SCOPE** · **-SEAM** · **-RENAME** + §7.3-1·§7.3-2 apply 판정 + 열린 항목 7 `argocd` CLI 예정) |
| 50 | [50-reference-consumer-repo.md](design/50-reference-consumer-repo.md) | ✅ (2026-08-07 개정 — **D31**: GitOps 배포 루트를 만들지 않는다. D-CONSUME 소비 경로 규약 · **배포 루트의 SSOT**) |

> ⚠️ **21은 "미개정"이 아니라 "미결정"이었다 — 그 구분이 2026-08-07에 닫혔다.**
> 미개정 문서(30)는 *판단은 섰으나 실행 스택 전제가 무효*인 상태고, **21은 판단 자체가 이 repo의
> 것이 아니었다**([`01 §3.3`](architecture/01-module-strategy.md)). 그 위임을 **§1 D-GITOPS-SEAM**이 받아 닫았다.
> 절 번호(§2.7·§2.8)는 30·40의 기존 참조를 보존하려고 그대로 뒀다.
>
> 🔴 **그래서 21은 이 표에서 유일하게 "문서 단위로 판정되지 않는" 문서다.**
> **§1 = ✅ 확정 · §2.7·§2.8 = PoC 이관본(인용 불가)** 이 한 파일에 있다.
> ⇒ **21을 인용할 때는 절 번호까지 쓴다.** *"21에 따르면"* 은 이 문서에 한해 판정 근거가 못 된다.
> ⚠️ 이는 **상태표의 결함이 아니라 의도된 예외**다 — 이관본을 버리면 PoC가 실물로 부딪힌 벽의
> 기록이 사라지고, 분리하면 30·40의 참조 20여 곳이 끊긴다. §0 상태표가 절 단위 판정을 대신한다.

> ⭐ **40 개정(2026-08-05)이 21과의 의존을 끊었다.** 개정 전 40의 제목은 *"ArgoCD private 전환의
> 선결 과제"* 여서 **미결정(21) 위에 서 있었다.** 개정은 40을 *"엔드포인트를 닫은 클러스터에
> 누가 닿는가"* 로 일반화해 ArgoCD 종속부를 걷어냈다 — 21이 self-managed ArgoCD로 뒤집혀도
> **40은 흔들리지 않는다**(어느 쪽이든 helm/kubectl 실행 지점이 필요하다).
> 🔑 **미개정 문서를 개정할 때 "번역"에 그치지 않고 의존 방향을 먼저 본 사례**다.
>
> ✅ 파급 처리 완료: `eks-cluster` 계약이 늘어났다(40 §5.2 — cluster SG 추가 규칙 통과).
> **`bastion-v0.1.0` · `eks-cluster-v0.3.0` 발행 완료**(2026-08-05, PR #12 `417154b` · [20 §4.3](design/20-eks-module.md)).
> ⭐ **한 PR에 태그를 둘 달았다** — 컴포넌트별 cadence 분리(`architecture/05 §4`)를 릴리스 단위로 지킨 것이다.
> ⚠️ **`bastion-v0.1.0`은 2026-08-06에 `workbench-v0.1.0`으로 대체·삭제됐다**(D-WORKBENCH-RENAME,
> [40 §2.0](design/40-workbench.md)). 위 날짜의 이름은 **그때의 사실**이므로 고치지 않는다.

> ⚠️ **50은 승계 문서가 아니라 이 repo에서 새로 쓴 설계다.** 모듈이 아니라 **소비 경로**를 다루므로
> `design/`에 있으면서도 다른 문서들과 성격이 다르다 — 산출물은 `.tf`가 아니라 별도 repo
> (`iac-reference-infra`)다. D26이 소유권 경계를, **D26-1이 `consumer/`의 성격(TFC 잔재)** 을 정한다.
> **50 자신이 소비 규약의 SSOT다.**

> 미개정 문서의 설계 판단(리소스 구성·경계·트레이드오프)은 대체로 유효하나
> **실행 스택 종속부와 실증 서술이 무효**다. 각 모듈을 이식할 때 재검토하며 개정한다(D-OSS-STACK §6-2).

## reference

| 문서 | 내용 | 상태 |
|------|------|------|
| [aws-naming-abbreviations.md](reference/aws-naming-abbreviations.md) | 리소스 약어 **SSOT**(312개). 임의 생성 금지 · **없으면 물어서 등재 후 사용** | ✅ (2026-07-30 `fl`·`iamp`·`iamoidc` 추가 + 종속 객체 상속 규약 + **카테고리 카운트 요약표 정정**) |
| [poc-findings.md](reference/poc-findings.md) | PoC 실증 기록 — **외부 출처, 이 repo에서 재현 안 됨** | 📋 |

> `poc-findings.md`가 승계 설계의 핵심 장치다. 설계 문서 본문에 실증 날짜·run ID를 옮겨 적으면
> **이 repo가 하지 않은 실증을 했다고 주장**하게 되므로, 증거는 이 파일 한 곳에 모으고 설계는 참조만 한다.

## consumer — 🗄️ TFC 시절 잔재 (보관 전용)

| 문서 | 내용 | 상태 |
|------|------|------|
| [multi-environment.md](consumer/multi-environment.md) | dev/stg/prd 전략, 디렉토리 구조, divergence 3단 규칙, 승격 플로우 | 🗄️ **잔재** — §3·§4·§6·§8만 유효(도구 무관), §5 무효 |
| [dynamic-credentials.md](consumer/dynamic-credentials.md) | TFC OIDC 2단 역할 체인 **구성 절차** | 🗄️ **잔재** — 절차 전체 무효. 구조만 유효 |

> ⛔ **소비 규약의 SSOT는 여기가 아니라 [design/50](design/50-reference-consumer-repo.md)(D-CONSUME)이다.**
> D20~D30가 모듈 소싱 인증·backend 규약·OIDC 체인·plan artifact를 소유한다.
> **두 문서를 확정 규약으로 인용하지 않는다** — `terraform-enterprise-poc` @ `76285f7`의 TFC 전제다.
>
> **이관하지 않는다**(D26). 소비 repo에는 그 인스턴스 고유의 배포 **사실**(계정 ID·버킷 GUID·
> Role ARN·실측 `sub`)만 둔다. **삭제도 하지 않는다**(D26-1, 2026-07-30 사용자 결정) —
> `multi-environment.md`의 논증은 도구 무관이라 살아 있고 `design/50` D22가 직접 인용한다.
>
> ⚠️ **최초 D26은 "두 문서를 개정해 SSOT로 삼는다"였고, D26-1이 그 배정을 철회했다.**
> GitHub Actions 규약의 SSOT가 TFC 절차서일 수는 없다 — 경쟁 SSOT는 그 자체로 drift다.
> 개정은 예정하지 않는다. 규약을 고쳐야 하면 `design/50`을 고친다.

---

## 문서 규칙

- **설계 우선**: `.tf` 작성 전에 해당 설계가 여기 있고 승인됐는지 확인한다([CLAUDE.md](../CLAUDE.md)).
- **provenance 유지**: 승계 문서는 상단에 출처 커밋·개정 내역을 남긴다. 원본과의 양방향 동기화는 하지 않는다 —
  **이 repo가 SSOT**이고 PoC는 동결이다.
- **실증과 설계 분리**: 새로 실증한 것은 해당 설계 문서에 기록한다. `poc-findings.md`는 외부 출처의
  스냅샷이므로 **갱신하지 않는다**.
