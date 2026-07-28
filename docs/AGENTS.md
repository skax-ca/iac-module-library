<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-29 | Updated: 2026-07-29 -->

# docs

## Purpose
이 repo의 설계·규약 SSOT. 전부 `terraform-enterprise-poc` @ `76285f7`(동결)에서 승계했으며,
**승계는 복사가 아니라 재검토를 동반한 이전**이라 문서마다 개정 수준이 다르다.
그 수준을 명시하는 것이 이 디렉토리의 핵심 장치다.

## Key Files
| File | Description |
|------|-------------|
| `README.md` | **진입점** — 승계 상태표(✅ 개정 완료 / 📋 무편집 / ⚠️ 미개정 / 📦 보관)와 전체 인덱스 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `architecture/` | 전략·공통 규약 — **개정 완료, 인용 가능** (see `architecture/AGENTS.md`) |
| `design/` | 모듈별 설계 — **미개정, 확정 설계로 인용 금지** (see `design/AGENTS.md`) |
| `reference/` | 약어 SSOT + PoC 실증 기록 (see `reference/AGENTS.md`) |
| `consumer/` | 배포 루트(프로젝트 repo) 소유 문서 — 보관용 (see `consumer/AGENTS.md`) |
| `runbooks/` | 운영 절차 — 아직 없음. PoC 런북은 TFC 종속이라 미승계 |

## For AI Agents

### Working In This Directory

- **문서를 인용하기 전에 상태를 확인한다.** `README.md`의 상태표가 판정 근거다.
  `design/*`을 "우리 설계"로 인용하면 PoC 전제(TFC·`workload=poc`·상대경로 소싱)를 사실로 옮기게 된다.
- **provenance 헤더를 지운다면 그 문서를 완전히 개정했을 때뿐이다.** 헤더는 "어디서 왔고 무엇을 고쳤나"를
  기록해 원본과의 혼동을 막는다. 원본과 **양방향 동기화하지 않는다** — 이 repo가 SSOT이고 PoC는 동결이다.
- **실증과 설계를 섞지 않는다.** 새로 실증한 것은 해당 설계 문서에 기록하고,
  `reference/poc-findings.md`는 **외부 출처의 스냅샷이므로 갱신하지 않는다.**
- 문서 용어는 번역투를 피한다(배선→연동, 대역→임시 대체 등). 금지어 자동 검사는 하지 않는다.

### Testing Requirements
문서에는 코드 게이트가 없다. 대신 편집 후 **상대 링크 정합성**을 확인한다:

```bash
python3 - <<'PY'
import re, pathlib
for p in pathlib.Path('docs').rglob('*.md'):
    for m in re.finditer(r'\]\(([^)#]+\.md)(#[^)]*)?\)', p.read_text()):
        if not m.group(1).startswith('http') and not (p.parent / m.group(1)).resolve().exists():
            print(p, '->', m.group(1))
PY
```

### Common Patterns
- 문서 상단 provenance 헤더: **승계 출처(커밋) · 개정 내역 · SSOT 선언** 3줄.
- 번호 체계는 PoC와 다르다(혼동 방지). `architecture/`는 01·02·03, `design/`은 모듈별 10·20·30·40.
- 폐기한 절은 삭제하고 헤더에 **무엇을 왜 폐기했는지** 남긴다(추적 가능성).

## Dependencies

### Internal
- 루트 `CLAUDE.md` — 규칙 요약본. 이 디렉토리 문서와 충돌하면 **문서가 상세, CLAUDE.md가 요약**이다.

### External
- 출처: `terraform-enterprise-poc` @ `76285f7`. 해당 repo의 `docs/architecture/05-oss-asset-repo-decision.md`가
  분기 결정(D-OSS-STACK)과 승계 판정표를 담고 있다.

<!-- MANUAL: -->
