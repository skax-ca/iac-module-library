#!/usr/bin/env python3
# docs/conventions.md 「코드 규약」의 주석 절이 금지한 두 가지 중 기계로 판정 가능한 3개만
# 검사한다. 위반을 어느 쪽으로 부르는지가 고치는 방향을 가른다: 외부 참조는 가리키는 것을
# 본문으로 옮겨 쓰면 되고, 이력 서술은 통째로 지우면 된다(git 이 이미 갖고 있다).
#
#  외부 참조 - 이 파일 바깥의 식별자를 가리킨다. 가리키는 쪽이 움직이면 조용히 틀려진다.
#  1. "§": 문서 절 번호 인용. 이 저장소에 정당한 용례가 없다(자기 절 번호도 "## 1." 형식이다).
#  2. 결정 식별자 "D-...": 단어 경계를 요구한다. 경계가 없으면 trivy 룰 ID(AVD-AWS-0038)가
#     "D-A"로 걸려 정책을 지적하는 주석마다 오탐이 난다.
#
#  이력 서술 - 언제 있었던 일인지를 적는다. 읽는 사람의 다음 행동을 바꾸지 않는다.
#  3. 날짜: 이력 서술의 표지. 언제 누가 왜 바꿨는지는 git blame과 커밋 메시지가 답한다.
#
#  나머지 이력 서술("실측했다"·"여기만 빠져 있었다")은 문맥 판단이 필요해 자동화하지 않는다.
#  억지로 정규식화하면 오탐이 사람 검토보다 비싸진다.
#
#  적용 범위: modules 아래 *.tf · *.tftest.hcl, 그리고 훅 2개(.githooks/pre-commit·pre-push).
#  .terraform/(다운로드된 upstream 모듈)은 우리 코드가 아니라 제외한다. 주석뿐 아니라
#  description 산문도 본다: 소비자가 읽는 면이라 같은 기준이고, 대부분이 heredoc이라 주석만
#  골라내면 그 면이 통째로 빠진다.
#
#  훅이 대상인 이유: 규약은 산문이 실리는 면을 확장자로 가르지 않는다. 훅 주석은 그 면인데
#  ".tf 를 찾아라" 조건에서 빠져 있었다. scripts/*.py 는 대상이 아니다 — 이 파일이 금지 문자를
#  검출하려고 리터럴로 담고 있어 자기 자신을 잡는다. 그 예외를 두는 것보다 범위를 좁게 둔다.
#
#  실행 (repo 루트에서): python3 scripts/validate-comment-conventions.py [파일...]
#  인자를 안 주면 적용 범위 전체를 스캔한다.

import glob
import os
import re
import sys

# (범주, 패턴, 고치는 방향). 범주는 메시지 앞에 붙어 무엇을 어겼는지 이름으로 알려 준다.
CHECKS = [
    ("외부 참조", re.compile("§"), "'§' 절 번호 인용. 문서 링크 또는 「절 제목」 참조로 바꾼다"),
    (
        "외부 참조",
        re.compile(r"\bD-[A-Z]"),
        "결정 식별자 'D-...'. 왜 이 값·이 형태인지를 직접 쓴다",
    ),
    (
        "이력 서술",
        re.compile(r"20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]"),
        "날짜. 언제 누가 바꿨는지는 git blame과 커밋 메시지가 답한다",
    ),
]

# AWS IAM 정책 언어 버전. AWS가 정한 두 값뿐이고 날짜처럼 생겼을 뿐 사건 서술이 아니다.
# 이 예외가 없으면 IAM 정책을 쓰는 모든 모듈이 걸린다. HCL(Version = "2012-10-17")과
# JSON 문자열 안의 이스케이프 형태(\"Version\":\"2012-10-17\") 양쪽을 지운다.
IAM_POLICY_VERSION = re.compile(
    r'\\?"?Version\\?"?\s*[:=]\s*\\?"(?:2012-10-17|2008-10-17)\\?"'
)

VENDORED = "/.terraform/"
HOOKS = (".githooks/pre-commit", ".githooks/pre-push")


def default_targets() -> list[str]:
    targets = set(glob.glob("modules/**/*.tf", recursive=True))
    targets |= set(glob.glob("modules/**/*.tftest.hcl", recursive=True))
    # git 훅은 이름이 규격이라 확장자가 없다. glob 패턴이 아니라 이름으로 적는다.
    targets |= {h for h in HOOKS if os.path.exists(h)}
    return sorted(t for t in targets if VENDORED not in t)


def check_file(path: str) -> list[str]:
    errors = []
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except FileNotFoundError:
        return errors

    for i, line in enumerate(lines, 1):
        scrubbed = IAM_POLICY_VERSION.sub("", line)
        for category, pattern, message in CHECKS:
            if pattern.search(scrubbed):
                errors.append(f"{path}:{i}: {category} 금지 위반. {message}")

    return errors


def main() -> int:
    if len(sys.argv) > 1:
        targets = [t for t in sys.argv[1:] if VENDORED not in t]
    else:
        targets = default_targets()

    all_errors = []
    for path in targets:
        all_errors.extend(check_file(path))

    if all_errors:
        for e in all_errors:
            print(f"[ERROR] {e}")
        print(f"\n주석 규칙 위반 {len(all_errors)}건")
        return 1

    print(f"주석 규칙 검사 통과: {len(targets)}개 파일")
    return 0


if __name__ == "__main__":
    sys.exit(main())
