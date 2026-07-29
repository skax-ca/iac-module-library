<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-29 | Updated: 2026-07-29 -->

# examples

## Purpose
모듈별 **최소 실행 예제**. 두 역할을 겸한다:

1. **소비자 문서** — 이 모듈을 어떻게 쓰는지 보여주는 가장 정확한 형태(문서는 낡지만 코드는 검증된다)
2. **테스트 진입점** — `validate`/`test`가 도는 곳. **두 엔진 모두에서** 검증된다
3. **provider 상한의 소유자** — 예제는 **루트 구성**이므로 `~> 6.0` 상한을 여기에 건다.
   이 repo는 lock을 커밋하지 않으므로(04 §4) **major 파괴 변경 방어가 전적으로 여기에 달려 있다**

**현재 비어 있다.** 모듈 이식과 함께 만들어진다.

## Key Files
아직 없음. 예제 하나의 표준 구성:

| File | Description |
|------|-------------|
| `<module>/main.tf` | 모듈 호출 — **상대경로 소싱**(`source = "../../modules/<module>"`) |
| `<module>/versions.tf` | `required_version >= 1.9.0` + **`aws ~> 6.0` 상한**(루트이므로 상한을 건다) |
| `<module>/variables.tf` | 예제가 받는 최소 입력 |
| `<module>/outputs.tf` | 모듈 출력 계약이 실제로 소비되는지 보이는 곳 |
| `<module>/README.md` | 이 예제가 무엇을 보여주는지 1~2문단 |

> ⚠️ 모듈(`../modules/*`)은 **하한만**(`>= 6.0`), 예제는 **상한까지**(`~> 6.0`). 역할이 다르다 —
> 모듈은 소비자의 선택 폭을 넓히고, 루트는 실제로 쓸 버전을 고정한다(`../docs/architecture/02-naming-tagging-and-pinning.md` §2).

## For AI Agents

### Working In This Directory

- **소싱은 상대경로**다. git tag 소싱은 **소비 프로젝트**의 방식이고, repo 내부 예제는 현재 코드를
  검증해야 하므로 상대경로를 쓴다. 이 둘을 혼동하지 않는다.
- **예제 없는 모듈은 릴리스하지 않는다**(`../docs/architecture/02-naming-tagging-and-pinning.md` §4 게이트).
  예제가 없다는 것은 "쓰는 법을 검증하지 않았다"는 뜻이다.
- **최소로 유지한다.** 예제가 프로덕션 구성을 흉내 내기 시작하면 유지 비용이 모듈보다 커진다.
  환경 프로파일 차이는 모듈 변수로 흡수하고, 예제는 **가장 단순한 호출 한 벌**만 보인다.
- 예제도 **네이밍 규약을 지킨다**(`naming` 객체 주입). 예제가 규약을 어기면 소비자가 그대로 복사한다.
  워크로드 코드는 가상값(`acme` 등)을 쓴다.

### Testing Requirements

```bash
# 로컬 1차
tofu -chdir=examples/<module> init -backend=false
tofu -chdir=examples/<module> validate

# 중립성 확인 (CI가 강제)
terraform -chdir=examples/<module> init -backend=false
terraform -chdir=examples/<module> validate
```

- 예제는 **apply하지 않는다** — 이 repo는 배포하지 않는다. `validate`와 `test`(plan 기반)까지다.
- 실제 AWS 자원을 만드는 검증이 필요하면 **소비 프로젝트 repo**에서 한다.
- ⚠️ 엔진 전환 시 `rm -rf examples/<module>/.terraform .terraform.lock.hcl` 후 재init한다
  (신뢰 루트가 달라 checksum이 충돌한다 — `../docs/architecture/04-engine-neutrality.md` §4).

### Common Patterns
- 예제 디렉토리명 = 모듈명. 한 모듈에 여러 시나리오가 필요하면 `<module>-<scenario>/`.
- 예제의 `variables.tf`는 기본값을 채워 **인자 없이 `validate`가 도는 상태**로 둔다.
- `.terraform.lock.hcl`은 **커밋하지 않는다**. 생성되더라도 `.gitignore`가 잡는다.

## Dependencies

### Internal
- `../modules/*` — 검증 대상. 상대경로로 참조한다.
- `../docs/design/*` — 예제가 보여줄 사용 시나리오의 근거.

<!-- MANUAL: -->
