<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-29 | Updated: 2026-07-29 -->

# modules

## Purpose
재사용 모듈의 소유 디렉토리이자 이 repo의 존재 이유.
소비 프로젝트는 여기의 모듈을 **git tag로 소싱**한다:

```hcl
source = "git::https://github.com/<org>/iac-module-library.git//modules/vpc?ref=vpc-v0.3.0"
```

**현재 비어 있다.** PoC 모듈(vpc·eks-cluster·workbench) 이식이 다음 작업이다(D-OSS-STACK §6-2).

## Key Files
아직 없음. 모듈 하나의 표준 구성:

| File | Description |
|------|-------------|
| `<module>/main.tf` | 리소스 정의 |
| `<module>/variables.tf` | 입력. `naming` 객체 + `<component>_enabled` kill switch 필수 |
| `<module>/outputs.tf` | **출력 계약** — 메이저 버전 내 안정 |
| `<module>/versions.tf` | `required_version` + `required_providers`(모듈은 하한만) |
| `<module>/tests/*.tftest.hcl` | `Name` 태그 assertion 포함 |
| `<module>/.terraform.lock.hcl` | 커밋 대상. ⚠️ `registry.opentofu.org` 주소여야 한다 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| (예정) `vpc/` | 스크래치 얇은 모듈, EKS-aware 태깅 (설계: `../docs/design/10-vpc-module.md`) |
| (예정) `eks-cluster/` | `terraform-aws-modules/eks` wrapper(facade) (설계: `../docs/design/20-eks-module.md`) |
| (예정) `workbench/` | SSM 기반 관리 호스트 (설계: `../docs/design/40-workbench.md`) |

## For AI Agents

### Working In This Directory

- **⛔ 설계 없이 모듈을 만들지 않는다.** `../docs/design/`에 해당 설계가 있어야 하고,
  그 문서가 **⚠️ 미개정 상태면 개정이 먼저**다(PoC 전제 제거 + 재사용 요건 적용).
- **재사용 요건 5종**(`../docs/architecture/01-module-strategy.md` §4) — 하나라도 빠지면 릴리스하지 않는다:
  1. **파라미터화** — workload·계정·리전 하드코딩 금지. `naming` 객체로 주입
  2. **kill switch** — `<component>_enabled = false`면 전 리소스 파기.
     **data source의 `count`까지 0**이 되어야 참조 대상이 사라진 뒤에도 plan이 통과한다
  3. **환경 프로파일** — dev/stg/prd 차이를 모듈 변수로 흡수(소비자가 조건 분기를 짜지 않게)
  4. **예제 + 테스트** — `../examples/<module>/`이 곧 `tofu test` 대상
  5. **출력 계약** — 이름 변경은 메이저 버전
- **커뮤니티 모듈 wrapping 시**: upstream 변수·출력명을 registry에서 **직접 확인**한다(추정 금지).
  facade가 upstream 변수명을 소비자에게 노출하면 wrapper의 의미가 사라진다.
- **버전 태그**: `<module>-vX.Y.Z`. upstream 파괴적 변경을 인터페이스 유지로 흡수하면 **마이너**,
  숨길 수 없으면 **메이저**.

### Testing Requirements

```bash
tofu -chdir=modules/<name> init -backend=false
tofu -chdir=modules/<name> test          # pre-push hook이 modules/*.tf 변경 시 자동 실행
```

- `*.tftest.hcl`에 **`Name` 태그 assertion을 반드시 포함**한다 — plan 단계에서 네이밍 규약 위반을 잡는다.
- kill switch가 `false`일 때도 plan이 통과하는지 테스트한다(teardown 가능성 보장).

### Common Patterns

```hcl
locals {
  name_mid = "${var.naming.workload}-${var.naming.env}-${var.naming.region_code}"
  # Name = "vpc-${local.name_mid}-main"  → vpc-acme-prd-an2-main
}
```

- 약어는 `../docs/reference/aws-naming-abbreviations.md`에서만 가져온다.
- SG rule은 별도 리소스(`aws_vpc_security_group_ingress_rule`), inline 금지·혼용 금지.
- 공유/기반 리소스는 네이밍 → data source 순으로 느슨하게 조회
  (`../docs/architecture/03-dependencies.md`).

## Dependencies

### Internal
- `../docs/design/*` — 각 모듈의 설계 근거
- `../docs/architecture/*` — 따라야 할 규약
- `../examples/*` — 각 모듈의 검증 진입점

### External
- `hashicorp/aws` `>= 6.0` · `terraform-aws-modules/*`(정확 핀)

<!-- MANUAL: -->
