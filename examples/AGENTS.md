<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-29 | Updated: 2026-08-03 -->

# examples

## Purpose
**모듈당 예제 하나.** 두 역할을 겸한다:

1. **고객사 착수 템플릿** — 프로덕션에 가까운 형상을 그대로 복사해 시작할 수 있는 자산
2. **`validate` 진입점** — CI 게이트 ⑤가 도는 곳

⚠️ **2026-08-03: minimal 예제를 폐기했다**(`examples/vpc` · `examples/eks-cluster`).
**모듈당 예제를 2벌 유지하는 비용이 minimal이 주는 값보다 컸다** — 계약이 바뀔 때마다
같은 수정을 두 곳에 하고, 두 README가 같은 설명을 다르게 낡아간다.
🔑 **계약 검증은 예제가 아니라 `modules/<module>/tests/*.tftest.hcl`이 한다.** minimal 예제가
"검증 자산"처럼 보였던 것은 착시였고, 실제 판정은 `tofu test`가 내리고 있었다.
남은 예제는 **착수 템플릿**이라는 단일 목적을 갖는다.

## Key Files

현재: `vpc-enterprise/` · `eks-cluster-enterprise/`
(⚠️ `-enterprise` 접미사는 **폐기된 minimal과의 짝** 때문에 남은 이름이다. 지금은 유일한 예제라
이름과 실제가 어긋나 있다 — 개명은 하류 문서 링크를 전부 건드려야 해 보류했다.)

예제 하나의 표준 구성:

| File | Description |
|------|-------------|
| `<module>-enterprise/main.tf` | 모듈 호출 — **상대경로 소싱**(`source = "../../modules/<module>"`) |
| `<module>-enterprise/variables.tf` | 예제가 받는 입력 |
| `<module>-enterprise/outputs.tf` | 모듈 출력 계약이 실제로 소비되는지 보이는 곳 |
| `<module>-enterprise/README.md` | 무엇을 보이는지 + **"소비 프로젝트와 다른 점" 비교표**(필수) |

## For AI Agents

### Working In This Directory

- **소싱은 상대경로**다. git tag 소싱은 **소비 프로젝트**의 방식이고, repo 내부 예제는 현재 코드를
  검증해야 하므로 상대경로를 쓴다. 이 둘을 혼동하지 않는다.
- **예제 없는 모듈은 릴리스하지 않는다**(`../docs/06-conventions.md` §6 게이트).
  예제가 없다는 것은 "쓰는 법을 검증하지 않았다"는 뜻이다.
- ⛔ **모듈당 예제를 늘리지 않는다.** "minimal도 하나 있으면 좋지 않나"는 **2026-08-03에 값을 매겨
  기각했다** — 실제로 2벌을 운영했고 유지 비용이 값보다 컸다(위 Purpose). 형상 차이를 보이고 싶으면
  예제를 늘리지 말고 **README에 표로** 적거나 `tests/`에 run 블록을 추가한다.
- **예제는 프로덕션에 가깝게 유지한다.** 고객사가 복사해 시작하는 자산이기 때문이다.
  ⚠️ 대신 **계약 검증을 예제에 기대지 않는다** — `validate`는 교차변수 `validation`·`precondition`을
  평가하지 못한다(`plan`에서만 평가). 그 판정은 `modules/<module>/tests/`가 한다.
- 예제도 **네이밍 규약을 지킨다**(`naming` 객체 주입). 예제가 규약을 어기면 소비자가 그대로 복사한다.
  워크로드 코드는 가상값(`acme` 등)을 쓴다.

### Testing Requirements

```bash
tofu -chdir=examples/<module> init -backend=false
tofu -chdir=examples/<module> validate
```

- 예제는 **apply하지 않는다** — 이 repo는 배포하지 않는다. `validate`와 `tofu test`(plan 기반)까지다.
- 실제 AWS 자원을 만드는 검증이 필요하면 **소비 프로젝트 repo**에서 한다.

### Common Patterns
- 예제 디렉토리명 = 모듈명. 한 모듈에 여러 시나리오가 필요하면 `<module>-<scenario>/`.
- 예제의 `variables.tf`는 기본값을 채워 **인자 없이 `validate`가 도는 상태**로 둔다.

## Dependencies

### Internal
- `../modules/*` — 검증 대상. 상대경로로 참조한다.
- `../docs/05-modules.md` — 모듈 입출력 계약. 예제가 보여줄 사용 시나리오의 근거.

<!-- MANUAL: -->
