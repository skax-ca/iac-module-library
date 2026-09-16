# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 표의 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | hub·dev 전부 destroy. main push plan은 `hub/tgw`만 성공(정상). CLAUDE.md 27줄(값·좌표만) |
| eks-platform-gitops | main = origin | dev cluster-secret 삭제 상태(라벨 먼저 뗀 뒤 파일 삭제) |
| aks-reference-infra | main = origin | 전부 철거 상태. 원본 이식 항목(runbooks·게이트·teardown-verify) 완료. CLAUDE.md 43줄(값·좌표·CI 신원 ⛔) |
| aks-platform-gitops | main = origin | dev 스포크 철거 2단계 완료(라벨 제거 → cluster-secret 삭제) |

## 지난 세션 (2026-09-16)
5개 저장소를 세션 하나로 다루는 구성을 정했다. 공식 문서 확인 결과 `--add-dir`+
`CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1`만 형제 CLAUDE.md·스킬을 싣고(`additionalDirectories`
설정은 안 싣는다), 부모 디렉토리 구성은 memory 키 이전이 따라와 보류했다. 리서치와 전환 조건은
`.local/claude-workspace.md`(로컬 전용, `git mv`로 잘못 추적된 것을 `2cca17a`로 끊음), VS Code는
`~/born2k/ai/iac.code-workspace`. 규칙 배치: 배포 루트 공통 규칙을 이 repo CLAUDE.md 「배포 루트 공통」
으로 올리고(`24b5f2d`, 108줄) eks(`40e9b17`, 27줄)·aks(`348a9de`→`c3c0bad`, 43줄) CLAUDE.md는 같은
골격의 값 표만 남겼다. session.md는 이 repo 하나로 통합(형제 것 삭제 `48bd7ca`·`de5ca83`),
전역 session-start·end 스킬에 "프로젝트 rule이 추가 절을 정하면 따른다" 확장점 한 문장을 넣고
(dotfiles `4a534f9`) 표의 구조·절차는 `.claude/rules/session.md`(`18542a9`)가 갖는다. 이 종료가 그
rule의 첫 적용이다.

## 다음 할 일
- [ ] [*-gitops] EKS·AKS 재구축 후 cluster Secret 등록 — ⚠️ teardown이 매칭 라벨을 **먼저 떼고** 파일을
      지웠다. git 이력에서 되살리면 라벨이 빠진 껍데기이고 그 상태로는 Application이 하나도
      안 생긴다. EKS dev는 `environment`·`tier: nonprd`·`vpcName`·`karpenterNodeRole`,
      AKS dev는 `environment`·`tier: nonprd`·`addon-karpenter`가 필요하다.
- [ ] [*-gitops] nonprd 클러스터가 생기면 `*-nonprd` ApplicationSet 팬아웃 실측 — 지금은 의도된 빈 슬롯이다
- [ ] [*-gitops] 실제 승격 한 번 돌려보기(nonprd 올림 → 검증 → prd 올림). Kyverno는 엔진·정책 값 4개를
      짝으로 움직여야 한다
- [ ] [module] 다음 `workbench`·`aks-workbench` 태그 메시지에 인스턴스/VM 교체를 적는다 — PR #53이
      `.tftpl` 주석을 바꿔 렌더링 결과가 달라졌다(`user_data_replace_on_change`·`custom_data` ForceNew)
- [ ] [*-gitops] (검토) Kyverno 엔진 단독 패치를 못 받는 문제 — helm index상 3.x에서 kyverno만 올라간
      릴리스가 8개 있는데 "같은 번호 유지" 규칙이 그것을 막는다. 보안 패치면 부딪힐 자리다
- [ ] [module] (검토) `.tf` 주석 좌표 금지(`conventions.md` 5절)의 판정 grep이 어떤 게이트에도 물려 있지
      않다 — 그래서 날짜·실측 서술이 74건까지 쌓였다
- [ ] [module] 허브 세션 첫 실행 때 `/context`로 eks·aks CLAUDE.md 로드와 `rules/terraform.md`가 형제
      `.tf`에도 걸리는지 확인한다(`.local/claude-workspace.md` 전환 조건 3번)
- [ ] [local] 약 한 달 뒤 `~/archive/`(에이전트·스킬·hook·`.omc` 백업 3개) 삭제
