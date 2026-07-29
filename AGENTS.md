<!-- Generated: 2026-07-29 | Updated: 2026-07-29 -->

# iac-module-library

## Purpose
Cloud Architect 팀이 **여러 실제 프로젝트에서 재사용**하는 IaC 모듈 자산 라이브러리.
OSS 스택(**OpenTofu** + GitHub Actions OIDC + S3 backend + OPA/Conftest)으로 구성한다 —
구독 라이선스가 고객사 채택의 장벽이 되지 않게 하는 것이 존재 이유다.

**⚙️ 엔진: OpenTofu 단독**(D-ENGINE, 2026-07-29 — `docs/architecture/04-engine-decision.md`).
라이선스는 채택 근거가 **아니다**(컨설팅 사용은 BUSL이 명시적으로 허용). 근거는 **리워크 0 + 조달 마찰 제거**다.
**두 엔진 동시 지원은 실측 비용을 근거로 기각**했다(04 §3) — 다시 제안하기 전에 그 절을 읽는다.

**현재 상태**: 부트스트랩. 설계 승계 완료(`docs/`), **모듈 코드는 아직 없다**(`modules/` 비어 있음).
다음 작업은 PoC 모듈 이식 + 재사용 파라미터화다.

**이 repo는 배포하지 않는다.** 모듈만 소유하고, 실제 apply는 소비 프로젝트(`<project>-infra`)가 한다.

## Key Files
| File | Description |
|------|-------------|
| `CLAUDE.md` | 프로젝트 규칙 — repo 경계, 설계 우선, 네이밍·태깅, 모듈 전략, 검증 게이트 |
| `README.md` | 사람용 진입점 — 목적·repo 관계·사용법·부트스트랩 체크리스트 |
| `docs/architecture/04-engine-decision.md` | **엔진 결정(D-ENGINE)** — 라이선스 재평가, 두 엔진 지원 기각 근거(실측), 재검토 조건 |
| `.githooks/pre-commit` | `tofu fmt -check` → `tflint --recursive` → `trivy config`. `.tf`/`.tfvars`/lock/설정 staged 시에만 실행 |
| `.githooks/pre-push` | push 범위에 `modules/*.tf` 변경이 있으면 `tofu test` 실행 |
| `.tflint.hcl` | terraform recommended preset + aws ruleset(정확 핀 `0.48.0`) |
| `.trivyignore` | **현재 예외 0건**. 항목마다 사유·백로그 링크 필수 |
| `.gitignore` | `.terraform/`·tfstate 제외. **`.terraform.lock.hcl`은 커밋 대상** |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `docs/` | 설계·규약 문서. 승계 상태표가 진입점 (see `docs/AGENTS.md`) |
| `modules/` | 재사용 모듈 — **아직 비어 있음** (see `modules/AGENTS.md`) |
| `examples/` | 모듈별 최소 예제 = `tofu test` 대상. provider 상한(`~> 6.0`) 소유 (see `examples/AGENTS.md`) |
| `.github/workflows/` | 모듈 검증 CI — 아직 없음. 배포 워크플로는 두지 않는다 |

## For AI Agents

### Working In This Directory

- **⛔ 설계 우선**: `.tf` 작성 전에 관련 설계가 `docs/architecture/` 또는 `docs/design/`에 있고
  승인됐는지 확인한다. 없으면 구현을 멈추고 설계부터. 순서: 설계 → 검토 → 구현 → 검증.
- **⛔ PoC repo를 고치지 않는다**: `terraform-enterprise-poc`는 2026-07-28 동결됐다(D-OSS-STACK).
  모듈·설계 SSOT는 이 repo다. 양쪽에서 고치면 drift가 생겨 정답 판정이 불가능해진다.
  ⚠️ D-OSS-STACK의 **엔진 축 근거는 `docs/architecture/04-engine-decision.md`가 교체**했다.
  결론(OpenTofu)은 같지만 이유가 다르다 — PoC는 동결이라 그쪽에 표시가 없으니 04를 함께 읽는다.
- **문서 인용 시 상태 확인**: `docs/design/*`은 ⚠️ **미개정**이다(PoC 전제·실증 서술 잔존).
  확정 설계로 인용하지 말 것 — 상태표는 `docs/README.md`.
- **실증 주장 금지**: 이 repo에서 재현하지 않은 것을 "실증됨"으로 쓰지 않는다.
  PoC 관찰은 `docs/reference/poc-findings.md`를 **참조**만 한다.
- **명령은 `tofu`**: `terraform`이 아니다. hook·문서·CI 전부 `tofu` 기준(D-ENGINE).
  OpenTofu 고유 기능(`encryption`·`.tofu` 확장자·`tofu {}`)을 쓸 때만 이유를 설계 문서에 남긴다 —
  강제 장치는 없고, 얇은 모듈에는 등장할 일이 없는 것들이다(04 §5).

### Testing Requirements

```bash
tofu fmt -recursive -check     # hook 1/3
tflint --recursive             # hook 2/3
trivy config .                 # hook 3/3
tofu -chdir=modules/<name> test   # pre-push (modules 변경 시)
```

- ⚠️ **tflint `terraform_unused_declarations`가 미사용 변수를 exit 2로 잡는다** —
  `variables.tf`만 있고 소비하는 `main.tf`가 없으면 커밋이 막힌다. 커밋 단위를 그에 맞춰 묶는다.
- hook 활성화는 clone마다 1회: `git config core.hooksPath .githooks`
- 우회(`--no-verify`)는 긴급 시에만, 사유를 커밋 메시지에 남긴다.
- 도구 설치: `brew install opentofu trivy`, tflint는 GitHub 릴리스 바이너리
  (`GITHUB_TOKEN=$(gh auth token) tflint --init`).

### Common Patterns

- 모듈은 `naming` 객체(`{workload, env, region_code}`)를 입력받아 `Name` 태그를 합성한다.
  **소비자가 약어를 직접 쓰지 않게** 한다.
- 리소스 약어는 `docs/reference/aws-naming-abbreviations.md`(SSOT)에서만. 임의 생성 금지.
- SG rule은 별도 리소스(`aws_vpc_security_group_ingress_rule`). inline 금지·혼용 금지.
- 각 컴포넌트에 `<component>_enabled` **kill switch**를 둔다 — `false`면 data source의 `count`까지
  0이 되어 참조 대상이 사라진 뒤에도 plan이 통과한다(teardown 가능성 확보).
- 커뮤니티 모듈은 **정확 핀** + wrapper(facade)로 감싸 upstream 변수명을 소비자에게 노출하지 않는다.

## Dependencies

### External
- **OpenTofu** `>= 1.9.0` (실행 1.12.x) — MPL-2.0. 하한 1.9의 근거는 **교차변수 `validation`**이다
- `hashicorp/aws` provider `>= 6.0` (모듈) — MPL-2.0
- `terraform-aws-modules/*` — Apache-2.0, 정확 핀으로만
- tflint(aws ruleset `0.48.0`) · trivy — 로컬 게이트

### Internal
- 출처: `terraform-enterprise-poc` @ `76285f7`(동결 커밋) — 설계 승계 원본. **단방향 참조**.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
