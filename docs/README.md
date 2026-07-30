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

> PoC의 `02 §4`(TFC 연동)·`§5`(Phase 0 태스크)·`01 §5`(Stacks)는 **폐기**했다 — 스택 종속이거나 일회성이다.

> ⚠️ **04는 승계 문서가 아니라 이 repo에서 새로 쓴 ADR이다.** D-OSS-STACK(PoC repo `05`)의
> **엔진 축 근거를 교체**한다 — 결론(OpenTofu)은 같지만 이유가 다르다(05는 라이선스, 04는 조달 마찰·운영 비용).
> PoC는 동결이라 그쪽에 표시가 없으므로 **D-OSS-STACK을 인용할 때는 04를 함께 읽는다.**
> 특히 *"두 엔진을 지원하면 되지 않나"* 라는 제안이 나오면 **04 §3이 이미 값을 매겨 기각한 안**이다.

## design — 모듈 설계

| # | 문서 | 상태 |
|---|------|------|
| 10 | [10-vpc-module.md](design/10-vpc-module.md) | ✅ (2026-07-29 개정 — `vpc-v1.0.0` 계약) |
| 20 | [20-eks-module.md](design/20-eks-module.md) | ⚠️ 미개정 |
| 30 | [30-gitops-repo.md](design/30-gitops-repo.md) | ⚠️ 미개정 |
| 40 | [40-bastion.md](design/40-bastion.md) | ⚠️ 미개정 |
| 50 | [50-reference-consumer-repo.md](design/50-reference-consumer-repo.md) | ✅ (신규 작성 — **D-CONSUME**, 소비 경로 규약) |

> ⚠️ **50은 승계 문서가 아니라 이 repo에서 새로 쓴 설계다.** 모듈이 아니라 **소비 경로**를 다루므로
> `design/`에 있으면서도 다른 문서들과 성격이 다르다 — 산출물은 `.tf`가 아니라 별도 repo
> (`iac-reference-infra`)와 `docs/consumer/*` 개정이다. D26이 그 소유권 경계를 정한다.

> 미개정 문서의 설계 판단(리소스 구성·경계·트레이드오프)은 대체로 유효하나
> **실행 스택 종속부와 실증 서술이 무효**다. 각 모듈을 이식할 때 재검토하며 개정한다(D-OSS-STACK §6-2).

## reference

| 문서 | 내용 | 상태 |
|------|------|------|
| [aws-naming-abbreviations.md](reference/aws-naming-abbreviations.md) | 리소스 약어 **SSOT**(312개). 임의 생성 금지 · **없으면 물어서 등재 후 사용** | ✅ (2026-07-30 `fl`·`iamp`·`iamoidc` 추가 + 종속 객체 상속 규약 + **카테고리 카운트 요약표 정정**) |
| [poc-findings.md](reference/poc-findings.md) | PoC 실증 기록 — **외부 출처, 이 repo에서 재현 안 됨** | 📋 |

> `poc-findings.md`가 승계 설계의 핵심 장치다. 설계 문서 본문에 실증 날짜·run ID를 옮겨 적으면
> **이 repo가 하지 않은 실증을 했다고 주장**하게 되므로, 증거는 이 파일 한 곳에 모으고 설계는 참조만 한다.

## consumer — 배포 루트(프로젝트 repo) 소유

| 문서 | 내용 | 상태 |
|------|------|------|
| [multi-environment.md](consumer/multi-environment.md) | dev/stg/prd 전략, 디렉토리 구조, divergence 3단 규칙, 승격 플로우 | 📦 **개정 예정** |
| [dynamic-credentials.md](consumer/dynamic-credentials.md) | OIDC 2단 역할 체인 구성 | 📦 **개정 예정** |

> ⚠️ **개정 방향이 확정됐다**([design/50](design/50-reference-consumer-repo.md) D26): 두 문서는
> **이관하지 않고 이 repo에 남긴다.** 소싱 인증·backend 규약·OIDC 체인·plan artifact 규칙은
> 모든 소비 repo가 따라야 하는 **계약**이므로 이 repo가 SSOT여야 한다 — 소비 repo마다 복제하면 곧 drift다.
> 소비 repo에는 그 인스턴스 고유의 배포 **사실**(계정 ID·버킷 GUID·Role ARN·실측 `sub`)만 둔다.
>
> 개정 시점은 `iac-reference-infra`의 첫 apply **이후**다. 실측값 없이 다시 쓰면 TFC 전제를
> GitHub Actions 전제로 바꿔 적기만 하고 또 미검증 문서가 된다.

---

## 문서 규칙

- **설계 우선**: `.tf` 작성 전에 해당 설계가 여기 있고 승인됐는지 확인한다([CLAUDE.md](../CLAUDE.md)).
- **provenance 유지**: 승계 문서는 상단에 출처 커밋·개정 내역을 남긴다. 원본과의 양방향 동기화는 하지 않는다 —
  **이 repo가 SSOT**이고 PoC는 동결이다.
- **실증과 설계 분리**: 새로 실증한 것은 해당 설계 문서에 기록한다. `poc-findings.md`는 외부 출처의
  스냅샷이므로 **갱신하지 않는다**.
