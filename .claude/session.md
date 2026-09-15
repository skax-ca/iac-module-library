# Session — iac-module-library

## 지난 세션 (2026-09-15)
aws-mcp MCP는 사내 SSL 인터셉션 루트 CA(SK holdings C&C)가 Basic Constraints를 critical로
표시하지 않아 클라이언트 설정으로 우회할 수 없어(strict·partial-chain·리프 핀닝 모두 실측 실패)
서버를 지우고 aws-docs의 무효 CA 설정도 뺐다(`2eb4154`). 문서 쪽은 문체 규칙 일괄 적용(`d5f6bcd`),
team-access.md 배포 자격증명 절을 AWS 문서로 이관(`8c1c947`), 아카이브 태그 참조·썩는 모듈 수 제거와
약어 「개정 이력」→「등재 근거」 전환(`1d8faac`)을 했다. `modules/`는 주석·README의 날짜·실측·
설계문서 좌표(축N)·버전 이력 74건과 em-dash 682건을 정리하면서 코드와 반대로 적힌 network_policy
주석 등 결함 3건을 고쳤다(PR #53, `7920327`). 코드 동작 변경이 없어 태그는 달지 않았다.

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
