# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 표의 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | hub·dev 전부 destroy. main push plan은 `hub/tgw`만 성공(정상. 나머지 4개는 `no matching RAM Resource Share found`로 실패하며, 철거 상태의 `data` 조회 실패라 코드 문제가 아니다). 변수 34개 전부 `nullable = false`. CLAUDE.md 27줄(값·좌표만) |
| eks-platform-gitops | main = origin | dev cluster-secret 삭제 상태(라벨 먼저 뗀 뒤 파일 삭제) |
| aks-reference-infra | main = origin | 전부 철거 상태. 원본 이식 항목(runbooks·게이트·teardown-verify) 완료. ⚠️ 변수 48건이 `nullable = false` 누락(기존 16곳은 일부 변수에만 붙어 있었다). CLAUDE.md 43줄(값·좌표·CI 신원 ⛔) |
| aks-platform-gitops | main = origin | dev 스포크 철거 2단계 완료(라벨 제거 → cluster-secret 삭제) |

## 지난 세션 (2026-09-16)
`.tf` 주석 좌표 금지에 강제 지점이 없어 74건이 쌓였던 문제를 닫았다. `scripts/validate-tf-comments.py`를
신설해 pre-commit(staged된 `modules`의 `.tf`·`.tftest.hcl`)과 CI(`tf-comments` job, 전체) 양쪽에 물린다
(#54, `1cc28ee`). `conventions.md`의 판정 grep을 그대로 물릴 수 없었던 이유는 매치 41건이 전부
오탐이었기 때문이다: `.terraform/` 벤더 코드 30건, IAM 정책 언어 버전(`Version = "2012-10-17"`) 8건,
trivy 룰 ID `AVD-AWS-0038`이 `D-A`로 걸린 것 3건. 단어 경계·주석 한정·벤더 제외로 해결했고 현재
위반은 0건이다.

`rules/terraform.md`의 `**/*.tf`가 배포 루트 `.tf`에도 걸리는지를 `InstructionsLoaded` 훅으로 실측했다.
걸리지 않는다. `paths`는 작업 디렉토리 기준으로 매칭되어 `--add-dir`로 붙인 형제 저장소에는 실리지
않는다(같은 패턴의 프로브 규칙이 이 저장소 `.tf`에서는 `path_glob_match`로 발화하고 형제 `.tf`에서는
발화하지 않았다). 그래서 배포 루트에 코드 규약 진입점이 없었고, `CLAUDE.md` 「배포 루트 공통」에
`.tf` 작성 행을 추가했다(`87f911c`). 규칙 본문은 복제하지 않았다. SSOT는 `conventions.md` 「코드 규약」과
`decisions.md` 「변수 계약 (nullable)」이 이미 갖고 있고, 없던 것은 배포 루트에서 그리로 가는 신호였다.

진입점이 없어서 실제로 갈려 있던 것을 eks에서 고쳤다. 변수 34개 전부에 `nullable = false`를 붙였다
(#44, `8e87c3f`. `default = null`인 예외는 0건이었다). aks는 48건이 남아 있다.

실측 중 도구 함정 하나를 찾아 memory에 남겼다: 규칙 파일을 `Read` 도구로 직접 열면 그 세션에서
그 규칙의 자동 주입이 억제된다. 적용 범위를 조사하려고 `terraform.md`를 열어보는 순간 판정이
불가능해지므로, 검증은 프로브 규칙을 따로 만들어서 해야 한다.

## 다음 할 일
- [ ] [aks-ref] 변수 48건에 `nullable = false` 적용 — eks `#44`와 같은 작업이고 `default = null` 예외는
      없다. 감사는 `variable` 블록을 파싱해 default 유무와 null 여부로 가른다(`validation` 블록과
      multiline default가 없는지 먼저 확인할 것. 있으면 "닫는 괄호 앞 삽입"이 엉뚱한 자리를 잡는다)
- [ ] [*-gitops] EKS·AKS 재구축 후 cluster Secret 등록 — ⚠️ teardown이 매칭 라벨을 **먼저 떼고** 파일을
      지웠다. git 이력에서 되살리면 라벨이 빠진 껍데기이고 그 상태로는 Application이 하나도
      안 생긴다. EKS dev는 `environment`·`tier: nonprd`·`vpcName`·`karpenterNodeRole`,
      AKS dev는 `environment`·`tier: nonprd`·`addon-karpenter`가 필요하다.
- [ ] [*-gitops] nonprd 클러스터가 생기면 `*-nonprd` ApplicationSet 팬아웃 실측 — 지금은 의도된 빈 슬롯이다
- [ ] [*-gitops] 실제 승격 한 번 돌려보기(nonprd 올림 → 검증 → prd 올림). Kyverno는 엔진·정책 값 4개를
      짝으로 움직여야 한다
- [ ] [module] 다음 `workbench`·`aks-workbench` 태그 메시지에 인스턴스/VM 교체를 적는다 — `6e34dec`가
      `.tftpl` 주석을 바꿔 렌더링 결과가 달라졌다(`user_data_replace_on_change`·`custom_data` ForceNew)
- [ ] [*-gitops] (검토) Kyverno 엔진 단독 패치를 못 받는 문제 — helm index상 3.x에서 kyverno만 올라간
      릴리스가 8개 있는데 "같은 번호 유지" 규칙이 그것을 막는다. 보안 패치면 부딪힐 자리다
- [ ] [local] `.claude/settings.local.json`의 `InstructionsLoaded` 훅을 정리한다 — 이번 실측용으로 넣었다.
      남겨도 로그만 쌓이지만 로그 경로가 이 세션 스크래치패드라 다음 세션에는 쓸모가 없다
- [ ] [local] 약 한 달 뒤 `~/archive/`(에이전트·스킬·hook·`.omc` 백업 3개) 삭제
