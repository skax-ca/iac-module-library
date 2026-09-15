# Session — iac-module-library

## 지난 세션 (2026-09-15)
버전 한정 표현을 걷어냈다(`70243ce`). 할 일에 적힌 4곳을 전수 검색했더니 같은 성격이 3곳 더
나왔다(cni_mode 표의 기본값 이력 2곳, aks-cluster `main.tf`의 끊긴 참조 "0.5.0 정정 주석").
Windows 노드 풀·Flow Logs는 최신 태그에서도 지원하지 않아 "지원하지 않는다"로 썼다. description·
주석만 바뀌어 main 직접 커밋했고 태그는 컷하지 않는다. 할 일에서 원격 Mac 정리와 다른 저장소 `.omc`
정리는 이 저장소 소관이 아니라 뺐다. 전역 session-start·end 스킬이 `다음 할 일`에 번호를 붙여
보여주게 고쳤다(dotfiles). `3cc5c6a`·`af98957`은 같은 작업 디렉토리의 다른 세션 커밋이다.
pre-push 훅이 코드가 바뀐 모듈만 test하고 `.tftpl`·`.tftest.hcl`·lock 변경도 잡게 고쳤다(`7b432c8`).
주석 전용 판정은 description heredoc을 못 걸러 절약이 없어 넣지 않았다.

## 다음 할 일
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
