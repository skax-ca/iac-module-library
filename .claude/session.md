# Session — iac-module-library

## 지난 세션 (2026-09-15)
OMC 종속성을 걷어냈다. 이 저장소는 `.omc` 11개(899파일, 추적 0)를 `~/archive/`에 압축한 뒤 지웠고,
로컬 유일본 `open-questions.md` 6건 중 기록이 없던 vnet `*_wo` 기각만 `vnet/main.tf` 주석으로,
`.trivyignore.yaml`의 끊긴 설계 참조(ralplan v4)는 걷어냈다(`7de7df8`), `.gitignore`의
`.omc`·opencode 규칙도 뺐다(`2657e1c`). 전역은 dotfiles에서 CLAUDE.md 18줄 축소(`88bb574`),
bootstrap 9단계 OMC 잔재 정리(`abed034`, `36dd4f7`), opencode 동기화 제거(`39499f7`), audit hook
제거(`3b7e901`), 스킬 3개(session-start·end, stop-slop)·hook 1개(permission-request)만 남김(`e006a3a`).
에이전트 6개(OMC 5.4.0 복사본)와 insane-search 플러그인·gptaku 마켓플레이스도 지웠다.

## 다음 할 일
- [ ] 원격 Mac 세션 시작 시 bootstrap 9단계 출력(`[cleanup]`·`[warn]`) 확인. 플러그인은 머신별이라
      `claude plugin uninstall insane-search@gptaku-plugins --scope user` ·
      `claude plugin marketplace remove gptaku-plugins`를 직접 실행하고, `~/.claude/skills` 아래
      링크가 아닌 디렉토리·`~/.config/opencode`도 직접 지운다
- [ ] ⚠️ 다른 저장소 `.omc` 정리 — `aks-reference-infra`의 `hub-argocd-rbac-direction-flip.md`·
      `dev-gitops-registration.md`는 gitignore된 유일본인데 `.tf` 주석·docs·`aks-platform-gitops`가
      근거로 가리킨다. `eks-reference-infra` plans 2개도 유일본. curo는 팀 저장소라 따로 판단
- [ ] `0.1.0` 버전 한정 표현 4곳 정리(writing-style 규칙 2): `module-catalog.md:130·247`,
      `conventions.md:125`, `aks-cluster/variables.tf` node_pools
- [ ] EKS·AKS 재구축 후 cluster Secret 등록 — ⚠️ teardown이 매칭 라벨을 **먼저 떼고** 파일을
      지웠다. git 이력에서 되살리면 라벨이 빠진 껍데기이고 그 상태로는 Application이 하나도
      안 생긴다. EKS dev는 `environment`·`tier: nonprd`·`vpcName`·`karpenterNodeRole`,
      AKS dev는 `environment`·`tier: nonprd`·`addon-karpenter`가 필요하다.
- [ ] nonprd 클러스터가 생기면 `*-nonprd` ApplicationSet 팬아웃 실측 — 지금은 의도된 빈 슬롯이다
- [ ] 실제 승격 한 번 돌려보기(nonprd 올림 → 검증 → prd 올림). Kyverno는 엔진·정책 값 4개를
      짝으로 움직여야 한다
- [ ] 다음 `workbench`·`aks-workbench` 태그 메시지에 인스턴스/VM 교체를 적는다 — PR #53이
      `.tftpl` 주석을 바꿔 렌더링 결과가 달라졌다(`user_data_replace_on_change`·`custom_data` ForceNew)
- [ ] (검토) Kyverno 엔진 단독 패치를 못 받는 문제 — helm index상 3.x에서 kyverno만 올라간
      릴리스가 8개 있는데 "같은 번호 유지" 규칙이 그것을 막는다. 보안 패치면 부딪힐 자리다
- [ ] (검토) `.tf` 주석 좌표 금지(`conventions.md` 5절)의 판정 grep이 어떤 게이트에도 물려 있지
      않다 — 그래서 날짜·실측 서술이 74건까지 쌓였다
- [ ] 약 한 달 뒤 `~/archive/`(에이전트·스킬·hook·`.omc` 백업 3개) 삭제
