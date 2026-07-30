<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-29 | Updated: 2026-07-29 -->

# consumer

## Purpose
🗄️ **TFC 시절 잔재 — 보관 전용. 이 repo의 규칙도, 소비 규약의 SSOT도 아니다.**

**소비 규약의 SSOT는 `../design/50-reference-consumer-repo.md`(D-CONSUME)다.** D20~D29가
모듈 소싱 인증·backend 규약·OIDC 체인·plan artifact를 소유한다. 이 디렉토리가 아니다.

여기 문서는 `terraform-enterprise-poc` @ `76285f7`에서 온 **TFC 전제**다. 이 repo는 모듈만 소유하고
`live/`가 없어 **검증할 수단이 없으므로**, `architecture/`가 아니라 여기에 격리해 둔다.

**왜 버리지 않는가**: `multi-environment.md`의 논증(안티패턴 근거·divergence 규칙·승격 게이트)은
**도구 무관이라 유효**하고 `design/50` D22가 직접 인용한다. `dynamic-credentials.md`는 PoC 시행착오 기록.

## Key Files
| File | Description |
|------|-------------|
| `multi-environment.md` | dev/stg/prd 전략 — 단일 repo + 계정별 디렉토리, branch/repo-per-env 안티패턴 근거, divergence 3단 규칙, 환경별 apply 정책, 승격 플로우 |
| `dynamic-credentials.md` | OIDC 2단 역할 체인(입구 Role → 실행 Role) 구성 절차, 신뢰 정책, 트러블슈팅, AFT 이관 경로 |

## For AI Agents

### Working In This Directory

- ⛔ **이 문서를 근거로 모듈을 설계하지 않는다.** 모듈 규약은 `../architecture/`가 소유한다.
  여기를 인용해야 한다면, 그 규칙이 정말 모듈의 관심사인지 먼저 의심한다.
- ⛔ **이 문서를 근거로 소비 경로를 구현하지 않는다.** 규약은 `../design/50`(D-CONSUME)이 소유한다.
  인용 전에 **그 규칙이 도구 무관인지** 먼저 확인한다 — TFC 종속부는 무효다.
- ⛔ **개정하지 않는다.** 잔재는 잔재로 둔다. 고쳐야 할 규약이 있으면 `../design/50`을 고친다.
- ⛔ **이관 여부를 다시 묻지 않는다.** 소비 repo로 옮기지 **않는다** — `design/50` D26이 기각했고
  D26-1이 성격을 확정했다(2026-07-30, 사용자 결정). 2026-07-29판 이 파일은 이관 절차를 규정하고
  있었고, 그 stale 서술이 실제로 "소비 repo로 넘겨야 하지 않나"라는 오독을 한 번 유발했다.

### 각 문서의 유효 범위

| 문서 | 아직 유효 | 무효 |
|------|----------|------|
| `multi-environment.md` | §3 디렉토리 · §4 divergence 3단 · §6 승격 · §8 안티패턴 (**도구 무관**) | §5 TFC 조직·워크스페이스 바인딩 |
| `dynamic-credentials.md` | 2단 역할 체인이라는 **구조**, AFT 이관 경로 | **절차 전체** — 발급자·`aud`·신뢰 정책·환경변수가 전부 TFC 기준 |

- 현행 대체물: 2단 체인 규약 → 소비 repo `CLAUDE.md` §4 · `design/50` D28 /
  실측 `sub` 3패턴 → 소비 repo `docs/deployment-facts.md` §3 / `AWSAFTExecution` 처리 → D27
- ⚠️ 보존한 `AWSAFTExecution`은 현재 assume 불가 상태다(입구 Role 삭제로 principal이 unique ID로 치환)
- ⚠️ `dynamic-credentials.md`에 **PoC 계정 ID 12곳** — public 전환 시 선결 과제(`design/50` D20 기각안)

### Testing Requirements
없음. 이 repo에서는 검증할 수 없다는 것이 이 디렉토리가 존재하는 이유다.

### Common Patterns
- 문서 상단에 **잔재 헤더**(출처 커밋 · SSOT가 어디인지 · 유효/무효 범위 · 왜 안 버리는지)를 유지한다.
  ⚠️ 헤더에서 **"이관"을 다시 언급하지 않는다** — 그 서술이 실제로 오독을 유발한 이력이 있다.

## Dependencies

### Internal
- `../architecture/03-dependencies.md` — foundation 계층 위치를 설명하며 `live/` 구조를 인용한다
  (인용일 뿐, 이 repo가 소유하는 규칙이 아니다).

### External
- `terraform-enterprise-poc` @ `76285f7` — 출처. 그 repo에서는 이 문서들이 `docs/architecture/03-*`과
  `docs/DYNAMIC_CREDENTIALS.md`였다.

<!-- MANUAL: -->
