<!-- Parent: ../AGENTS.md -->

# docs

## Purpose
이 저장소의 설계·규약 SSOT. 아홉 개 문서이고 **읽는 사람으로 갈랐다.**
디렉토리 계층이 없다 — 문서 하나가 독자 하나를 온전히 담당한다.

## Key Files
| File | Description |
|------|-------------|
| `README.md` | 진입점 — 아홉 문서와 각각의 독자 |
| `00-team-access.md` | GitHub org/Team 구조 · 합류 방법 · GitHub↔AWS 인증 패턴 개요 |
| `01-architecture.md` | 전체 그림 · 3계층 소유 모델 · 계층 경계 판별 |
| `02-choose-your-path.md` | 프로파일 A/B · 관리형 vs self-managed ArgoCD · addon 배치 |
| `03-new-project.md` | 새 배포 루트 착수 절차 |
| `04-teardown.md` | 파기 절차. 공용 계정에서 가장 위험한 작업이라 독립 문서다 |
| `05-modules.md` | 모듈 입출력 계약 (`vpc` · `eks-cluster` · `workbench`) |
| `06-conventions.md` | 엔진 · 네이밍 · 버전 · 검증 게이트 · 브랜치 · 문서 작성 규칙 |
| `07-runbooks.md` | 운영 절차 |
| `08-decisions.md` | 검토하고 기각한 것들. 재제안하려면 여기 이유가 깨졌음을 먼저 보여야 한다 |
| `aws-naming-abbreviations.md` | 리소스 타입 약어 SSOT (310개). 데이터라 위 규칙의 예외다 |

## For AI Agents

### Working In This Directory

- **문서 작성 규칙은 `06-conventions.md` §8이 소유한다.** 편집 전에 읽는다.
  핵심은 독자로 파일을 가르기 · 변경 이력을 본문에 쓰지 않기 · 400줄 상한 ·
  정정 서술 금지(현재 사실만 쓴다).
- **문서를 늘리기 전에 기존 여덟 개 중 어디에 속하는지 먼저 답한다.**
  속할 곳이 없다면 독자가 새로 생긴 것인지 확인한다 — 대개는 아니다.
- **기각한 안은 `08-decisions.md`에 한 행으로 남긴다.** 본문에 *"~는 하지 않기로 했다"* 를
  흩뿌리지 않는다. 흩뿌리면 다음 사람이 전수 검색을 해야 한다.
- **실증 결과는 절차 문서에 접는다.** 실증 로그를 그대로 옮기지 않고, `03`·`04`·`07`의
  명령과 주의사항으로 바꿔 쓴다. 로그 원본은 `.omc/notepad.md`가 갖는다.

### Testing Requirements
문서에는 코드 게이트가 없다 — **단, 약어 카탈로그(`aws-naming-abbreviations.md`)는 데이터 SSOT라 유일한 예외다**.
카탈로그 편집 후 편집 전·후로 SSOT 검사를 돌린다 (로컬 게이트 `.githooks/pre-commit`도 동일 명령을 실행):

```bash
python3 scripts/validate-abbreviations.py                 # 카탈로그 SSOT 검사 (중복·소문자·카운트 정합)
```

그 외 문서는 링크 정합성을 확인한다:

```bash
python3 - <<'PY'
import re, pathlib
for p in pathlib.Path('docs').rglob('*.md'):
    for m in re.finditer(r'\]\(([^)#]+\.md)(#[^)]*)?\)', p.read_text()):
        if not m.group(1).startswith('http') and not (p.parent / m.group(1)).resolve().exists():
            print(p, '->', m.group(1))
PY
```

작성 규칙의 자동 판정:

```bash
wc -l docs/*.md                                          # 각 400 이하
grep -rc "정정\|틀렸다\|철회\|초판\|무효" docs/*.md      # 06(규칙 선언) 1건만 허용
```

## Dependencies

### Internal
- 루트 `CLAUDE.md` — 규칙 요약본. 이 디렉토리 문서와 충돌하면 **문서가 상세, `CLAUDE.md`가 요약**이다.

### External
- 이 문서 집합 이전 판은 태그 `docs-archive-20260811`에 전문이 있다.

<!-- MANUAL: -->
