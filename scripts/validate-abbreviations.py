#!/usr/bin/env python3
# docs/aws-naming-abbreviations.md (약어 카탈로그 SSOT) 일관성 검사.
#
#  문서가 스스로 선언한 불변식만 강제한다 — 의견 검사는 여기 두지 않는다.
#  1. 카탈로그 표(## A.N) 약어가 소문자 알파벳·숫자 2자 이상, 7자 이하 (등재 규칙 4)
#  2. 각 행의 예시(Name)가 그 행의 약어로 시작한다
#  3. 약어가 전체에서 고유하다 (개정 이력 표와의 반복 등재는 제외)
#  4. 섹션 헤더 "(NN)" == 실제 행 수 == 카운트 요약 표의 값
#  5. 상단 "총 NN개" == 합계, 8개 카테고리
#  6. 개정 이력 표의 약어가 카탈로그에 존재한다
#
#  실행 (repo 루트에서): python3 scripts/validate-abbreviations.py

import re
import sys

PATH = sys.argv[1] if len(sys.argv) > 1 else "docs/aws-naming-abbreviations.md"

TEXT = open(PATH, encoding="utf-8").read()
LINES = TEXT.splitlines()
ERRORS = []


def err(msg: str) -> None:
    ERRORS.append(msg)


section = None
section_rows = {}      # "A.N" -> [(약어, 라벨, 예시)]
section_header = {}    # "A.N" -> 헤더 선언 카운트
summary_claim = {}     # "A.N" -> 카운트 요약 표 선언
seen = {}              # 약어 -> 첫 등장 위치
revision_abbrs = []
in_revision = False

for i, line in enumerate(LINES, 1):
    msec = re.match(r"^## (A\.\d) ", line)
    if msec:
        section = msec.group(1)
        h = re.search(r"\((\d+)\)", line)
        section_header[section] = int(h.group(1)) if h else None
        continue
    mhead = re.match(r"^#{2,4} ", line)
    if mhead:
        section = None
        in_revision = "개정 이력" in line
        continue
    if not line.startswith("|"):
        continue
    cells = [c.strip() for c in line.strip("|").split("|")]

    mrev = re.fullmatch(r"`([a-z0-9]{2,})`", cells[1] if len(cells) > 1 else "")
    if in_revision and mrev:
        revision_abbrs.append(mrev.group(1))
        continue

    abbr = None
    for c in cells:
        ma = re.fullmatch(r"`([a-z0-9]{2,})`", c)
        if ma:
            abbr = ma.group(1)
    if not abbr:
        continue
    if section is None:
        continue
    label = cells[1] if len(cells) > 1 else ""
    example = cells[3] if len(cells) > 3 else ""
    section_rows.setdefault(section, []).append((abbr, label, example, i))
    if abbr in seen:
        err(
            f"약어 중복 `{abbr}` — {seen[abbr]} 와 {i}행"
            f" (카탈로그는 리소스 타입 구분에 유일해야 한다)"
        )
    else:
        seen[abbr] = i
    if not re.fullmatch(r"[a-z0-9]{2,}", abbr):
        err(f"{i}행 약어 `{abbr}` — 소문자 알파벳·숫자 2자 이상이어야 한다")
    if len(abbr) > 7:
        err(f"{i}행 약어 `{abbr}` — 길이 7자를 초과한다 (등재 규칙 4)")
    if not re.match(rf"^{re.escape(abbr)}-", example):
        err(f"{i}행 예시 `{example}` 는 약어 `{abbr}` 로 시작해야 한다")

for mn in LINES:
    ms = re.match(r"\|\s*(A\.\d)\s*\|\s*\*\*?(카테고리별|[\w\s,]*)\*?\s*\|\s*(\d+)\s*\|", mn)
    if ms:
        summary_claim[ms.group(1)] = int(ms.group(3))

total_declared = None
for mn in LINES:
    mt = re.search(r"총 \*\*(\d+)\*\*개 약어", mn)
    if mt:
        total_declared = int(mt.group(1))

summary_total = None
for mn in LINES:
    mt = re.match(r"\|\s*\|\s*\*\*합계\*\*\s*\|\s*\*\*(\d+)\*\*\s*\|", mn)
    if mt:
        summary_total = int(mt.group(1))

actual_total = 0
for sec, rows in sorted(section_rows.items()):
    n = len(rows)
    actual_total += n
    if section_header.get(sec) is not None and section_header[sec] != n:
        err(f"섹션 {sec}: 헤더 선언 {section_header[sec]} ≠ 실제 {n}행")
    if sec in summary_claim and summary_claim[sec] != n:
        err(f"섹션 {sec}: 카운트 요약 표 {summary_claim[sec]} ≠ 실제 {n}행")

if len(section_rows) != 8:
    err(f"카테고리는 8개여야 한다 — 실제 {len(section_rows)}개")

if total_declared is not None and total_declared != actual_total:
    err(f"상단 총계 {total_declared} ≠ 실제 합계 {actual_total}")
if summary_total is not None and summary_total != actual_total:
    err(f"카운트 요약 표 합계 {summary_total} ≠ 실제 합계 {actual_total}")

for a in revision_abbrs:
    if a not in seen:
        err(f"개정 이력의 약어 `{a}` 가 카탈로그에 없다")

if ERRORS:
    for e in ERRORS:
        print(f"[ERROR] {e}")
    sys.exit(1)

print(f"약어 카탈로그 SSOT 검사 통과 — {actual_total}개 · {len(section_rows)}개 카테고리")