# 04 · 실행 엔진 결정 (D-ENGINE)

- **작성일**: 2026-07-29
- **상태**: ✅ **결정 완료** — 인용 가능
- **결정 ID**: `D-ENGINE`
- **관계**: `terraform-enterprise-poc/docs/architecture/05-oss-asset-repo-decision.md`(D-OSS-STACK)의
  **엔진 축 근거를 교체**한다. 결론(OpenTofu)은 같지만 **이유가 다르다** — 05는 라이선스를,
  이 문서는 조달 마찰과 운영 비용을 근거로 든다. PoC repo는 동결이므로 기록은 **이 문서가 보유**한다.
- **이력**: 초안(2026-07-29)은 **엔진 중립(두 엔진 동시 지원)**을 결정했으나, 같은 날 실제 구현에
  착수하며 측정된 유지보수 비용으로 **기각하고 단일 엔진으로 정정**했다(§3). 기각 기록을 남기는
  이유는 §3.4에 있다.

---

## 0. 결정

| 항목 | 결정 |
|------|------|
| **엔진** | **OpenTofu 단독**. 로컬·CI·문서·lock 전부 `tofu` 하나로 일원화한다 |
| **두 엔진 동시 지원** | ❌ **기각**(§3) — 이득은 대부분 공짜로 따라오고, 보장 비용만 영구적이다 |
| **Terraform 호환성** | **계약이 아니라 부산물**. 보장하지 않지만 **이유 없이 깨뜨리지도 않는다**(§5) |
| **`.terraform.lock.hcl`** | **커밋한다**(기존 규약 유지). registry 주소는 `registry.opentofu.org` |
| **`required_version`** | `>= 1.9.0`. 하한은 실제로 쓰는 기능을 근거로만 올린다(§4.3) |

> **핵심**: 라이선스는 걸림돌이 아니므로(§1) 엔진 선택은 **자유로운 운영 판단**이다.
> 자유로운 판단의 결론은 **하나를 잘 쓰는 것**이지 둘을 떠받치는 것이 아니다.

---

## 1. 라이선스 재평가 — 준수 문제가 아니다

D-OSS-STACK §1은 *"전환 동기는 라이선스 위반 회피가 아니다"* 라고 이미 인정했다.
2026-07-29 원문 확인으로 그 판단이 확정됐다.

[HashiCorp Licensing FAQ](https://www.hashicorp.com/en/license-faq):

> All non-production use of BSL licensed HashiCorp products is permitted.
> **Assisting a customer with their own use of BSL licensed HashiCorp products for their
> production environment is also permitted.** However, embedding or hosting BSL licensed
> HashiCorp products in an offering to be made available to **multiple customers that is
> competitive with HashiCorp products** is not permitted.

| 형태 | 판정 |
|------|------|
| 고객사 프로덕션 인프라를 Terraform으로 구축·지원 | ✅ **허용**(FAQ 명시) |
| 팀 내부 개발·검증 | ✅ 허용(non-production) |
| Terraform 기반 관리형 IaC를 **다수 고객에게 서비스로 판매** | ❌ 금지 |

- Terraform CLI는 **무상**이다. BUSL은 유료화가 아니라 경쟁 제한 조항이다.
- IBM 인수(2024-04) 이후에도 재오픈소스화는 없었고 BUSL이 유지 중이다.

**따라서 "라이선스 때문에 OpenTofu를 써야 한다"는 명제는 거짓이다.**
이 문서의 나머지는 그 자유 위에서 무엇이 유리한지를 다룬다.

---

## 2. 비용 장벽의 실제 위치 — 두 축을 분리한다

D-OSS-STACK이 든 동기는 *"고객사가 TFE/HCP 연간 구독 비용에 거부감을 보인다"* 였다.
그런데 두 축은 독립적이고, **돈은 한쪽에만 있다**:

| 축 | 선택지 | 비용 | 고객 착수 장벽 |
|---|---|---|---|
| **A. 엔진(CLI)** | Terraform ↔ OpenTofu | **둘 다 $0** | **없음** |
| **B. 실행 플랫폼** | HCP/TFE ↔ GitHub Actions + S3 | **여기가 전부** | **여기가 전부** |

**비용 목표는 축 B 이전만으로 이미 100% 달성됐다.** 축 A의 기여분은 0원이다.
D-OSS-STACK은 두 축을 묶어 결정했고, 그래서 엔진 선택의 실제 근거가 흐려져 있었다.

> 이 문서는 **축 B 결정(GitHub Actions + S3 + OPA)을 그대로 유지**한다. 다루는 것은 축 A뿐이다.

---

## 3. 두 엔진 동시 지원 — 검토했고 기각했다

### 3.1 검토한 안

모듈을 두 엔진 교집합 문법으로 쓰고, CI 2잡(`tofu test` + `terraform test`)으로 호환성을
**계약으로 보장**하는 안. 근거는 *"lock은 remote module을 추적하지 않으므로 모듈이 소비자의 엔진을
강제하지 않는다"* 는 관찰이었다([OpenTofu 공식 문서](https://opentofu.org/docs/language/files/dependency-lock/)).

### 3.2 실측 비용 (`modules/vpc` Task 10.1 구현 중 측정)

관찰 자체는 옳았으나 **결론이 틀렸다.** 변수 15개짜리 인터페이스 하나를 쓰는 동안 다음이 발생했다:

| # | 발생한 비용 | 단일 엔진이었다면 |
|---|---|---|
| ① | `az_selection` validation이 `az_count`를 참조하기 전에 **두 엔진의 교차변수 validation 지원 시점을 외부 검색으로 확인** | 그냥 쓰고 `validate`로 확인 |
| ② | `eks_role` enum에 **sentinel 우회** 작성 — 단락 평가 의미가 두 엔진에서 동일하다고 확신할 수 없어 방어적으로 | 자연스러운 표현 + 테스트 |
| ③ | **lock 커밋 포기** — provider 재현성을 호환성과 맞바꿈 | lock 유지, CI 재현 가능 |
| ④ | 로컬은 `tofu`만 → **Terraform 위반은 CI에서만 발견** | 데스크에서 즉시 발견 |

가장 무거운 것은 표에 없다. 중립성 규칙은 **`required_version` 하한을 OpenTofu 최신 위로
올리지 못하게** 만드는데, 이는 일회성 제약이 아니라 **모듈 라이브러리를 영구적으로 느린 쪽 엔진의
기능 집합에 묶는 것**이다. 앞으로 만들 모든 모듈이 이 세금을 낸다.

### 3.3 기각 근거 — 보장할 필요가 없다

세 가지를 구분했어야 했다:

| | 내용 | 비용 |
|---|---|---|
| **(A) 보장** | 두 엔진 지원을 계약화, CI 2잡·규칙으로 강제 | **높고 영구적** |
| **(B) 비파괴** | 평범한 HCL로 쓰고 엔진 고유 기능을 이유 없이 쓰지 않음 | **거의 0** |
| **(C) 종속** | 엔진 전용 기능 적극 사용 | — |

순수 AWS 리소스 모듈은 **(B)만으로도 사실상 두 엔진에서 돈다.** 호환성은 기본값이지 성취가 아니다.
따라서 (A)는 **공짜로 얻는 것을 비싸게 사는 구조**다. §3.1의 관찰은 오히려 **일원화를 지지하는 근거**였다 —
모듈이 소비자의 엔진을 강제하지 않는다면, 우리가 두 엔진을 떠받칠 이유도 없다.

### 3.4 기각 기록을 남기는 이유

*"두 엔진을 지원하면 되지 않나"* 는 앞으로 반복해서 나올 질문이다. 검토하지 않은 것이 아니라
**비용을 측정해 기각했다**는 사실과 그 수치가 남아 있어야, 6개월 뒤 같은 논의를 처음부터 다시 하지 않는다.
재검토를 여는 조건은 §7-1에 명시한다.

---

## 4. 왜 OpenTofu인가

### 4.1 비교

| | **OpenTofu 단독 (채택)** | Terraform 단독 |
|---|---|---|
| 이 repo 리워크 | **0** — hook·문서·MCP·설계가 이미 `tofu` 기준 | 전면 재작업 |
| 조달 | **OSI 승인 → 라이선스 대화 자체가 없음** | BUSL 설명 필요(위법 아니나 대화 발생) |
| 시장 점유율 | 12% | **33~62%** — 고객 엔지니어 친숙도 우위 |
| 기능 cadence | 느림(1.12) | **빠름(1.15)** |
| HCP/TFE 전환 | 불가 | 가능 |
| 고유 기능 | **state 클라이언트 측 암호화**(Terraform CE에 없음) | Stacks(HCP 전용 — 축 B에서 이미 이탈) |
| 거버넌스 | CNCF / Linux Foundation | IBM |

### 4.2 채택 근거

1. **리워크 0** — 두 안의 실질적 차별 요소가 전환 비용인데, 그것이 0이다.
2. **조달 마찰 제거가 공짜** — 공공·금융에서 OSI-only 정책을 만나면 설명 없이 통과한다.
   Terraform이 위법은 아니지만 **"설명해야 하는 것"과 "설명할 필요가 없는 것"의 차이**는 실재한다.
3. **평범한 HCL로 쓰는 한 Terraform 고객에게도 그대로 전달된다**(§5) — 일원화의 대가가 작다.

### 4.3 감수하는 것 (정직하게 기록)

- **고객 엔지니어 친숙도**: 대다수는 `terraform`에 익숙하다. `tofu`는 drop-in이라 적응 비용이 작지만
  0은 아니다. 인수인계 문서에 명시한다(§7-2).
- **기능 cadence**: Terraform이 먼저 넣는 언어 기능을 늦게 쓰게 된다.
  `required_version` 하한은 **실제로 쓰는 기능을 근거로만** 올린다(`02 §2`).
- **HCP/TFE 경로 차단**: 축 B에서 이미 이탈했으므로 새로 잃는 것은 없다. 다만 고객이 TFE를
  원하면 그 프로젝트 루트는 Terraform으로 별도 구성해야 한다 — **모듈은 그대로 재사용된다**(§5).

---

## 5. Terraform 호환성 — 계약이 아니라 부산물

**가이드라인 (강제 장치 없음, CI 없음)**

> 모듈에 **OpenTofu 고유 기능**을 쓸 때는 그 이유를 해당 설계 문서에 남긴다. 이유 없이 쓰지 않는다.

- 대표 고유 기능: `encryption` 블록(state 암호화, 1.7) · `.tofu`/`.tofu.json` 확장자(1.8) ·
  provider `for_each`(1.9) · early variable evaluation(1.10) · **`language {}` 블록(1.12)**.
  이들은 **대부분 루트 관심사**라 얇은 모듈에는 애초에 등장할 이유가 없다.
- ⚠️ **`tofu {}` 블록은 존재하지 않는다**(2026-07-29 정정 — 초판의 오류). OpenTofu의 최상위
  설정 블록은 `terraform {}`이며, 공식 문서는 이를 *"only for compatibility with Terraform"*으로
  규정한다. 네이티브 대안은 **1.12의 `language {}` 블록**(`compatible_with`·`edition`·`experiments`)이다.
- **모듈 레벨에 실제로 해당하는 고유 기능은 1.12의 두 가지뿐이다**:
  **동적 `prevent_destroy`**(입력 변수 참조 가능 — Terraform은 리터럴만 허용) ·
  **`destroy = false`**(원격 객체를 파기하지 않고 state에서만 제거). 채택 판단은 각 모듈 설계에서 한다.
- `backend`/`cloud` 블록을 모듈에 두지 않는 것은 엔진과 무관한 기존 규약이다.
- **CI 잡을 추가하지 않는다. 규칙 검사도 하지 않는다.** 지키면 좋고, 못 지켜도 릴리스를 막지 않는다.

**Terraform 고객이 실제로 생기면**: 그때 1회성 호환 점검(`terraform validate` + `terraform test`)을
수행하고 결과를 그 프로젝트 문서에 남긴다. **옵션은 보존하되 비용을 미리 내지 않는다.**

---

## 6. 영향 범위

| 대상 | 변경 |
|------|------|
| `modules/vpc` 구현 계획(`design/10 §2`) | **없음** — Task 10.1~10.7 그대로 |
| 작성 완료된 `modules/vpc/{versions,variables}.tf` | **그대로 유효** — 평범한 HCL이라 재작업 불필요 |
| `02 §2` 버전 핀 · `§4` 릴리스 게이트 | **원복**(lock 커밋 유지) |
| `.gitignore` · `.githooks/*` | **원복** |
| `.github/workflows/` | `tofu` 1잡 기준으로 신설 — 2잡 설계 폐기 |
| `CLAUDE.md` · 각 `AGENTS.md` | 엔진 절을 이 문서 링크로 축약 |

---

## 7. 열린 항목

1. **재검토 조건 (§3 기각의 유효기간)** — 다음 중 하나가 **실제로 발생하면** 이 결정을 다시 연다:
   ① Terraform으로 표준화된 고객이 **계약됐다** · ② OpenTofu가 우리에게 필요한 기능을 2년 이상
   따라잡지 못한다 · ③ OpenTofu 프로젝트의 지속가능성에 실질적 신호가 생긴다.
   **가정이 아니라 사건이 트리거다** — 예상만으로 다시 열지 않는다.
2. **인수인계용 `tofu` 안내 1페이지** — 고객 엔지니어 대상. `terraform`과의 차이·명령 대응표.
3. **state 클라이언트 측 암호화 채택 여부** — OpenTofu 고유 이점이나 **루트 관심사**다.
   프로젝트 repo 설계에서 판단한다.

---

## 8. 참고 자료

- [HashiCorp Licensing FAQ](https://www.hashicorp.com/en/license-faq) — 컨설팅 사용 허용 조항(§1)
- [OpenTofu — Dependency Lock File](https://opentofu.org/docs/language/files/dependency-lock/) — lock이 remote module을 추적하지 않음(§3.1)
- [OpenTofu 1.9 What's new](https://opentofu.org/docs/v1.9/intro/whats-new/) — 교차변수 validation. `required_version >= 1.9.0`의 실제 근거(§3.2-①)
- [OpenTofu vs Terraform: Enterprise Guide (env0)](https://www.env0.com/blog/opentofu-vs-terraform-a-practical-guide-for-enterprise-infrastructure-teams)
- [Terraform vs OpenTofu 2026: Post-BSL Decision Framework](https://www.rack2cloud.com/terraform-vs-opentofu-2026-post-bsl-decision/)
