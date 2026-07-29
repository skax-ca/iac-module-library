# 04 · 실행 엔진 중립 결정 (D-ENGINE-NEUTRAL)

- **작성일**: 2026-07-29
- **상태**: ✅ **결정 완료** — 인용 가능
- **결정 ID**: `D-ENGINE-NEUTRAL`
- **관계**: `terraform-enterprise-poc/docs/architecture/05-oss-asset-repo-decision.md`(D-OSS-STACK)의
  **엔진 축을 개정**한다. PoC repo는 동결이므로 개정 기록은 **이 문서가 보유**한다.
  D-OSS-STACK의 나머지 결정(repo 분기·GitHub Actions·S3 backend·OPA)은 **전부 유효**하다.

---

## 0. 결정

| 항목 | 결정 |
|------|------|
| **모듈 `.tf` 코드** | **엔진 중립** — OpenTofu와 Terraform의 **교집합 문법만** 사용한다 |
| **로컬 게이트(hook)** | `tofu` — 더 제약이 빡빡한 타깃이므로 1차 방어선으로 적합(§3.2) |
| **CI** | **2잡** — `tofu test` + `terraform test`. 중립성은 주장이 아니라 **실증**한다 |
| **엔진 선택 주체** | **프로젝트 repo(배포 루트)**. 이 repo는 엔진을 강제하지 않는다 |
| **`.terraform.lock.hcl`** | **커밋하지 않는다**(방침 전환, §4) |
| **`required_version`** | `>= 1.9.0` 유지. **상한을 OpenTofu 최신(1.12.x) 위로 올리지 않는다** |

> **핵심**: 엔진 선택은 **모듈 repo의 속성이 아니라 배포 루트의 속성**이다. 모듈이 엔진을 못 박으면
> 재사용 범위가 절반으로 줄어든다. 이 repo가 파는 것은 실행 엔진이 아니라 **설계와 규약**이다.

---

## 1. 재평가 계기 — D-OSS-STACK 엔진 축의 논거 부족

D-OSS-STACK §1은 스스로 *"전환 동기는 라이선스 위반 회피가 아니다"* 라고 인정한 뒤,
유일하게 남은 근거를 **조건절**로 제시했다:

> *"고객 앞에서 '이 스택은 전부 OSI 승인 라이선스입니다'라고 검증 가능하게 말할 수 있어야 한다면, 답은 예다."*

그 조건이 참인지는 **검증된 적이 없다**. 2026-07-29 재평가에서 두 가지가 드러났다.

### 1.1 라이선스 — 우리 사용 형태는 명시적 허용 범위

[HashiCorp Licensing FAQ](https://www.hashicorp.com/en/license-faq) 원문:

> All non-production use of BSL licensed HashiCorp products is permitted.
> **Assisting a customer with their own use of BSL licensed HashiCorp products for their
> production environment is also permitted.** However, embedding or hosting BSL licensed
> HashiCorp products in an offering to be made available to **multiple customers that is
> competitive with HashiCorp products** is not permitted.

| 형태 | 판정 |
|------|------|
| 고객사 프로덕션 인프라를 Terraform으로 구축·지원 | ✅ **허용** (FAQ 명시) |
| 팀 내부 개발·검증 | ✅ 허용(non-production) |
| Terraform 기반 관리형 IaC를 **다수 고객에게 서비스로 판매** | ❌ 금지 |

- Terraform CLI는 **무상**이다. BUSL은 유료화 조항이 아니라 경쟁 제한 조항이다.
- IBM 인수(2024-04) 이후에도 재오픈소스화는 없었고 BUSL이 유지 중이다.

### 1.2 비용 장벽은 엔진 축이 아니라 플랫폼 축에 있었다

D-OSS-STACK이 든 실제 동기는 *"고객사가 TFE/HCP 연간 구독 비용에 거부감을 보인다"* 였다.
그런데 두 축은 독립적이다:

| 축 | 선택지 | 비용 | 고객 착수 장벽 |
|---|---|---|---|
| **A. 엔진(CLI)** | Terraform ↔ OpenTofu | **둘 다 $0** | **없음** |
| **B. 실행 플랫폼** | HCP/TFE ↔ GitHub Actions + S3 | **여기가 전부** | **여기가 전부** |

D-OSS-STACK은 두 축을 하나로 묶어 결정했다. **비용 목표는 축 B 이전만으로 이미 100% 달성**됐고,
축 A에서 `terraform`을 `tofu`로 바꾼 것이 기여한 절감액은 **0원**이다.

> 이 문서는 축 B 결정(GitHub Actions + S3 + OPA)을 **그대로 유지**한다. 개정 대상은 축 A뿐이다.

---

## 2. 이 repo에만 성립하는 구조적 사실

[OpenTofu 공식 문서](https://opentofu.org/docs/language/files/dependency-lock/):

> The lock file tracks only **provider** dependencies, **not remote modules**.
> It is "a file that belongs to the configuration as a whole."

```
iac-module-library/modules/vpc/*.tf      ← 순수 HCL. 엔진 식별자 없음
        │ git tag 소싱 (02 §3)
        ▼
<project>-infra/live/dev/networking/     ← 여기가 엔진을 결정하고 자기 lock을 생성
```

**모듈은 소비자의 엔진을 강제하지 않는다.** 따라서 이 repo가 엔진을 하나로 못 박을 구조적 필연이 없다.
못 박으면 잃는 것만 생긴다:

| 고객 상황 | 엔진 고정 시 | 중립 시 |
|---|---|---|
| 이미 Terraform 표준화(시장 다수) | 자산 전달 불가 → 재작성 | ✅ 그대로 전달 |
| OSI-only 조달 정책(공공·금융) | ✅ | ✅ 그대로 전달 |
| 향후 HCP/TFE 채택 결정 | OpenTofu는 HCP 인증 불가 → 루트 재작업 | ✅ 루트만 교체, 모듈 무영향 |

**지금이 가장 싼 결정 시점이다.** `modules/`는 아직 비어 있어 폐기할 코드가 없다.

---

## 3. 옵션 비교와 채택 근거

| | A안 OpenTofu 단독 | B안 Terraform 단독 | **C안 엔진 중립 (채택)** |
|---|---|---|---|
| 모듈 `.tf` | tofu 전용 가정 | terraform 전용 가정 | **교집합 문법** |
| 로컬 게이트 | `tofu` | `terraform` | **`tofu`** |
| CI | 1잡 | 1잡 | **2잡(중립성 실증)** |
| Terraform 표준 고객 | ❌ | ✅ | ✅ |
| OSI-only 정책 고객 | ✅ | ❌ | ✅ |
| 기존 결정 폐기량 | 0 | 문서·hook·MCP 전면 재작업 | **≈0** |
| 유지 비용 | — | — | CI 1잡 추가 + 중립성 규칙 준수 |

### 3.1 C안의 비용은 작고 자동 강제된다

추가 비용은 **CI 잡 1개**와 **§5 중립성 규칙**뿐이다. 규칙 위반은 사람이 아니라
`terraform test` 잡이 잡는다 — 이것이 C안이 "선언적 중립"으로 썩지 않는 이유다.

### 3.2 왜 로컬 게이트는 `tofu`인가

OpenTofu(1.12.x)가 Terraform(1.15.x)보다 **버전이 낮고 제약이 빡빡한 타깃**이다.
tofu에서 통과한 코드는 terraform에서도 거의 통과하지만, **역은 성립하지 않는다**.
빠른 1차 방어선은 더 좁은 쪽에 두는 것이 효율적이다.

역방향 위험(OpenTofu 전용 기능 사용)은 CI의 `terraform test` 잡이 담당한다.
**두 잡은 서로 다른 위반을 잡으므로 둘 다 필요하다.**

### 3.3 검토했으나 채택하지 않은 것

| 항목 | 판단 |
|------|------|
| OpenTofu 전용 **state 암호화** | 실질 이점이나 **루트 관심사**다. 모듈에 넣으면 중립성 파괴. 프로젝트 repo가 선택 |
| Terraform **Stacks** · Sentinel | HCP 전용. 축 B에서 이미 이탈했으므로 무관 |
| 두 엔진 lock 파일 병존 | **불가능** — 파일명 고정(`.terraform.lock.hcl`) → §4 |

---

## 4. `.terraform.lock.hcl` — 커밋 중단 (방침 전환)

**이전 방침**: 커밋하고 registry 주소가 `registry.opentofu.org`인지 확인
**신규 방침**: **이 repo에서는 커밋하지 않는다.** `.gitignore`로 제외한다.

### 근거

| # | 근거 |
|---|------|
| ① | **두 엔진 공유 불가** — 신뢰 루트(GPG 키)가 달라 해시가 다르다. 파일명이 고정이라 병존할 수 없다 |
| ② | **소비자에게 전달되지 않는다** — lock은 루트 구성의 소유물이고 remote module을 추적하지 않는다(§2) |
| ③ | **이 repo는 apply하지 않는다** — lock이 보호하는 "동일 바이너리 재현" 가치가 낮다 |
| ④ | 커밋해두면 다른 엔진 사용자가 `init` 시 **checksum 실패**를 만난다. 중립을 표방하는 repo에 엔진 고유 산출물을 두는 것은 자기모순이다 |

### 상실분과 대체

lock 없이 fresh init하면 **provider 신규 릴리스로 CI가 갑자기 깨질 수 있다.** 대체 장치:

- **모듈**은 하한만 선언(`>= 6.0`) — 기존 규약 유지(`02 §2`)
- **예제(`examples/*`)는 테스트 루트이므로 상한을 건다** — `~> 6.0`.
  major 파괴 변경을 막으면서 minor/patch 회귀는 조기 검출한다.
- 재현이 필요한 디버깅에서는 로컬에서 lock을 임시 생성하되 **커밋하지 않는다**.

> 이 트레이드오프는 의도적이다. 모듈 라이브러리에서 upstream provider의 파괴적 변경은
> **숨겨야 할 위험이 아니라 빨리 알아야 할 신호**다.

---

## 5. 중립성 규칙 (강제 대상)

| # | 규칙 | 위반 시 검출 |
|---|------|-------------|
| N1 | `required_version` 상한을 **OpenTofu 최신(1.12.x) 위로 올리지 않는다**. 현행 `>= 1.9.0` | `tofu` 전 명령 실패 |
| N2 | `.tofu` / `.tofu.json` 확장자, `tofu {}` 블록 **금지** | `terraform validate` |
| N3 | **OpenTofu 전용 기능 금지** — state 암호화(`encryption` 블록), provider `for_each` 등 | `terraform validate` |
| N4 | **Terraform 전용 기능 금지** — OpenTofu 미탑재 신규 문법 | `tofu validate` |
| N5 | 모듈에 `backend` / `cloud` 블록을 두지 않는다 | 리뷰 + 루트 전용 규약 |
| N6 | provider source는 `hashicorp/aws` 형태의 **짧은 주소**만. registry 호스트를 명시하지 않는다 | 리뷰 |
| N7 | 문서·주석에서 특정 엔진 실행을 전제하지 않는다(예: *"명령은 tofu다"*) | 리뷰 |

> `hashicorp/aws`는 Terraform에서 `registry.terraform.io/hashicorp/aws`로,
> OpenTofu에서 `registry.opentofu.org/hashicorp/aws`로 각각 해석된다. **같은 provider, 같은 코드**다.
> 호스트를 명시하는 순간 중립성이 깨진다(N6).

---

## 6. CI 설계 (`.github/workflows/` — 아직 미구현)

```
job: gate-tofu          job: gate-terraform
  tofu fmt -check         terraform fmt -check
  tofu init -backend=false   terraform init -backend=false
  tofu validate           terraform validate
  tofu test               terraform test
        └────────┬────────┘
                 ▼
     job: lint (tflint --recursive · trivy config)   # 엔진 무관, 1회만
```

- 두 잡은 **병렬**로 돌리고 **둘 다 required check**로 건다. 한쪽만 통과하면 중립성이 깨진 것이다.
- `tflint` / `trivy`는 HCL 정적 분석이라 엔진과 무관하다 — 중복 실행하지 않는다.
- 두 잡은 **각자의 러너에서 fresh init**하므로 lock 충돌이 발생하지 않는다(§4의 부수 효과).
- `terraform` 바이너리를 CI에서 실행하는 것은 §1.1의 허용 범위다(비경쟁 내부 사용).

---

## 7. 영향 범위

| 대상 | 변경 |
|------|------|
| `modules/vpc` 구현 계획(`design/10 §2`) | **없음** — Task 10.1~10.7 내용 그대로. §5 규칙만 준수 |
| `CLAUDE.md` · 각 `AGENTS.md` | *"명령은 tofu"* → *"로컬 기본 tofu, 코드는 중립"* 으로 개정 |
| `02 §2` 버전 핀 · `§4` 릴리스 게이트 | lock 항목 교체, terraform 검증 항목 추가 |
| `.gitignore` | lock 제외로 전환 |
| `.githooks/*` | **변경 없음** — 로컬 게이트는 `tofu`(§3.2) |
| `.github/workflows/` | 처음부터 2잡으로 작성(§6) |
| 프로젝트 repo | 고객별로 엔진 선택. 선택 기준은 §8 |

---

## 8. 프로젝트 repo의 엔진 선택 기준

| 고객 상황 | 권장 엔진 |
|---|---|
| 기존 Terraform 자산·인력이 있다 | **Terraform** |
| HCP/TFE를 이미 쓰거나 도입 예정 | **Terraform**(OpenTofu는 HCP 인증 불가) |
| OSI 승인 라이선스만 허용하는 조달 정책 | **OpenTofu** |
| 그린필드 + 특별한 제약 없음 | **OpenTofu**(라이선스 질문 자체를 제거) |
| state 클라이언트 측 암호화가 요건 | **OpenTofu**(Terraform CE에 없음) |

어느 쪽을 고르든 **이 repo의 모듈은 동일한 태그로 소싱**된다.

---

## 9. 열린 항목

1. **`terraform` CLI의 CI 도입 형태** — `hashicorp/setup-terraform` 액션 사용 여부.
   액션 자체의 라이선스와 버전 핀을 확인한다.
2. **엔진별 동작 차이 실측** — 현재 §5는 문법 수준 규칙이다. plan 산출물이나 오류 메시지가
   갈리는 사례가 나오면 여기에 기록한다. **아직 실측 없음.**
3. **`required_version` 상한 재검토 시점** — OpenTofu가 Terraform 기능을 따라잡는 속도에 따라
   N1의 실효 하한이 바뀐다. 모듈이 신규 문법을 필요로 할 때 재판단한다.
4. **D-OSS-STACK 원문과의 정합성 표시** — PoC repo는 동결이라 그쪽에 개정 표시를 남기지 않는다.
   이 문서가 유일한 개정 기록임을 `docs/README.md`가 안내한다.

---

## 10. 참고 자료

- [HashiCorp Licensing FAQ](https://www.hashicorp.com/en/license-faq) — 컨설팅 사용 허용 조항(§1.1)
- [OpenTofu — Dependency Lock File](https://opentofu.org/docs/language/files/dependency-lock/) — lock이 remote module을 추적하지 않음(§2)
- [OpenTofu — Migrating from Terraform](https://opentofu.org/docs/intro/migration/)
- [Terraform — Dependency Lock File](https://developer.hashicorp.com/terraform/language/files/dependency-lock)
- [OpenTofu vs Terraform: Enterprise Guide (env0)](https://www.env0.com/blog/opentofu-vs-terraform-a-practical-guide-for-enterprise-infrastructure-teams)
- [Terraform vs OpenTofu 2026: Post-BSL Decision Framework](https://www.rack2cloud.com/terraform-vs-opentofu-2026-post-bsl-decision/)
- [How to Handle OpenTofu Provider Compatibility](https://oneuptime.com/blog/post/2026-02-23-handle-opentofu-provider-compatibility/view) — 신뢰 루트 차이로 인한 checksum 불일치(§4)
