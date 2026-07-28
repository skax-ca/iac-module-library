<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-29 | Updated: 2026-07-29 -->

# consumer

## Purpose
📦 **보관 문서 — 이 repo의 규칙이 아니다.**

여기 문서가 다루는 것은 **배포 루트(프로젝트 repo)의 관심사**다. 이 repo는 모듈만 소유하고
`live/`가 없어 **검증할 수단이 없으므로**, `architecture/`가 아니라 여기에 격리해 둔다.

**왜 버리지 않는가**: 검증된 논증(안티패턴 근거·환경 divergence 규칙·승격 게이트·2단 역할 체인)을
지금 버리면 첫 프로젝트 repo를 만들 때 처음부터 다시 논증해야 한다.

## Key Files
| File | Description |
|------|-------------|
| `multi-environment.md` | dev/stg/prd 전략 — 단일 repo + 계정별 디렉토리, branch/repo-per-env 안티패턴 근거, divergence 3단 규칙, 환경별 apply 정책, 승격 플로우 |
| `dynamic-credentials.md` | OIDC 2단 역할 체인(입구 Role → 실행 Role) 구성 절차, 신뢰 정책, 트러블슈팅, AFT 이관 경로 |

## For AI Agents

### Working In This Directory

- ⛔ **이 문서를 근거로 모듈을 설계하지 않는다.** 모듈 규약은 `../architecture/`가 소유한다.
  여기를 인용해야 한다면, 그 규칙이 정말 모듈의 관심사인지 먼저 의심한다.
- ⛔ **개정하지 않는다.** 보관 상태 그대로 둔다 — 개정은 이관 시점에, 이관될 repo의 맥락에서 한다.
- **이관 시 처리**(첫 프로젝트 repo 생성 시):
  - `multi-environment.md`: §5(TFC 조직 구조·워크스페이스 바인딩)를 **GitHub Actions + S3 backend**
    기준으로 재작성. §3 디렉토리·§4 divergence·§6 승격·§8 안티패턴은 **도구 무관이라 그대로** 유효
  - `dynamic-credentials.md`: OIDC 발급자를 `app.terraform.io` → `token.actions.githubusercontent.com`로.
    **2단 체인 구조와 AFT 이관 절차는 그대로 승계**. ⚠️ 2026-07-15 이후 생성 repo는
    immutable sub claim(숫자 org/repo ID)이라 신뢰 정책 형식이 다르다
  - ⚠️ 보존한 `AWSAFTExecution`은 현재 assume 불가 상태다(입구 Role 삭제로 principal이 unique ID로 치환)

### Testing Requirements
없음. 이 repo에서는 검증할 수 없다는 것이 이 디렉토리가 존재하는 이유다.

### Common Patterns
- 문서 상단에 **보관 헤더**(출처·개정 안 됨·왜 여기 있나·이관 시 처리)를 유지한다.

## Dependencies

### Internal
- `../architecture/03-dependencies.md` — foundation 계층 위치를 설명하며 `live/` 구조를 인용한다
  (인용일 뿐, 이 repo가 소유하는 규칙이 아니다).

### External
- `terraform-enterprise-poc` @ `76285f7` — 출처. 그 repo에서는 이 문서들이 `docs/architecture/03-*`과
  `docs/DYNAMIC_CREDENTIALS.md`였다.

<!-- MANUAL: -->
