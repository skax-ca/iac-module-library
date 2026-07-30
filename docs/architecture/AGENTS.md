<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-29 | Updated: 2026-07-29 -->

# architecture

## Purpose
모든 모듈이 공유하는 **전략·규약**. 이 디렉토리의 3개 문서는 **개정 완료 상태(✅)** 로,
이 repo의 확정 규칙으로 인용할 수 있다. 모듈 설계(`../design/`)와 달리 PoC 전제가 남아 있지 않다.

## Key Files
| File | Description |
|------|-------------|
| `01-module-strategy.md` | 계층형 하이브리드 모듈 전략(3계층 토폴로지·리소스 등급제·semver 계약), IaC↔GitOps 경계, **재사용 자산 요건**(§4) |
| `02-naming-tagging-and-pinning.md` | 거버넌스 태그 vs `Name` 태그 분리, `Name` 포맷·어휘 표준, `default_tags`/`ignore_tags`, 버전 핀, 모듈 소싱(git tag), 검증 게이트 |
| `03-dependencies.md` | SG rule 순환 해소(별도 리소스), 공유/기반 리소스 참조 선호 순서(네이밍 → data source → **SSM Parameter**), 하이브리드 소유 모델 |

## For AI Agents

### Working In This Directory

- 이 3개 문서는 **인용 가능한 확정 규칙**이다. 여기에 없는 규칙을 모듈 코드가 전제하면 안 된다 —
  필요하면 먼저 이 문서를 개정한다(설계 우선 규칙).
- **PoC에서 폐기한 것을 되살리지 않는다**: `tfe_outputs`·run trigger·TFC 워크스페이스 구조·
  Terraform Stacks·Sentinel. 이들은 HCP 전용이거나 이 스택에 존재하지 않는다.
- **배포 루트 규칙을 여기에 쓰지 않는다.** 환경 승격·디렉토리 구조·자격증명 구성은
  **`../design/50`(D-CONSUME) 소관**이다. 이 repo는 `live/`가 없어 검증할 수단이 없다.
  ⚠️ `../consumer/`는 **TFC 잔재 보관소**이지 소관 문서가 아니다(D26-1).
- 새 규약을 추가할 때는 **강제 수단**을 함께 정한다(모듈 코드 / `*.tftest.hcl` assertion / tflint / trivy / OPA).
  강제 수단이 없는 규약은 문서에만 남고 지켜지지 않는다.

### Testing Requirements
문서 자체에 테스트는 없다. 다만 여기 규약은 **아래 수단으로 강제되어야** 한다:

| 규약 | 강제 수단 |
|------|-----------|
| `Name` 포맷·약어 | 모듈이 합성 + `*.tftest.hcl` assertion |
| 거버넌스 태그 | 소비 프로젝트의 `default_tags` |
| 버전 핀·lock | `.terraform.lock.hcl` 커밋 + 리뷰 |
| 보안 구성 | `trivy config` (pre-commit) |
| 네이밍 정규식 | OPA/Conftest (소비 프로젝트 CI) |

### Common Patterns
- 문서 번호는 **PoC와 다르다**: PoC 01→01, PoC 02→02, PoC **04→03**. PoC 03(멀티환경)은 `../consumer/`로 갔다.
- 결정에는 근거를 남긴다 — "왜 이 선택인가"와 "무엇을 배제했나"가 함께 있어야 나중에 재논증하지 않는다.

## Dependencies

### Internal
- `../reference/aws-naming-abbreviations.md` — 약어 SSOT. 02가 이 카탈로그를 강제한다.
- `../reference/poc-findings.md` — 규약의 실측 근거(예: `ignore_tags`의 가짜 diff, IAM 6,144자 한도).
- `../design/*` — 이 규약을 구현하는 모듈 설계. 방향은 **architecture → design**이다.

<!-- MANUAL: -->
