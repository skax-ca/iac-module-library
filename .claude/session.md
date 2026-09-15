# Session — iac-module-library

## 지난 세션 (2026-09-15)
staged 전파를 설계부터 구현까지 끝냈다. 구현은 GitOps 저장소 몫이라 세 저장소를 오갔다
(`iac-module-library` 13커밋, `eks-platform-gitops` 6, `aks-platform-gitops` 1, 전부 push 완료).
EKS는 `karpenter`·`aws-load-balancer-controller`·`gateway-api-crds`에 더해 Kyverno 엔진·PSS
정책까지 staged로 갔고(`b4b418e`), AKS는 관리형(NAP·App Routing) 때문에 조립한 것이 Kyverno뿐이라
그 둘만 staged다(`0ba0125`). 클러스터가 전면 철거된 상태라 ApplicationSet 이름을 대칭
(`<addon>-prd`/`-nonprd`)으로 정리할 수 있었다.

설계 문서(`gitops.md`)는 216줄이 바뀌었다. 구현하면서 공백 넷이 드러나 메웠다: 티어로 나누는
것은 **버전 핀을 가진 ApplicationSet만**이라는 조건(`main` 핀은 승격 개념이 없다), 승격 구간에
CR이 두 CRD 버전 모두에서 유효해야 한다는 제약, 판정 단위가 addon이 아니라 **ApplicationSet**
이라는 것(Kyverno 엔진은 가드레일이면서 동시에 컨트롤러라 기존 기준으로 갈리지 않았다),
그리고 파일 구성 규칙(컴포넌트로 나누고 티어 쌍은 한 파일에). 전환 절차 절은 한 번 썼다가
들어냈다 — 마이그레이션 사정이라 최초 구축자에게는 잡음이고 writing-style 규칙 2에도 걸린다.

문서 오류 둘을 `grep` 대조로 잡았다. `environment` 라벨이 "values 경로 해석에 쓰인다"고 적혀
있었는데 실제로는 `gateway.yaml`이 helm 파라미터로 넘겨 **ALB 이름과 태그**를 만든다(`ff1cbdb`).
`karpenter.yaml` 헤더의 "ApplicationSet이 2개"도 3개가 된 뒤 방치돼 있었다. `(O(1))`이 파일
분리를 막는 근거처럼 읽혔지만 README에서 그 표기는 클러스터 수 확장성을 뜻한다.

앞선 항목으로 Gateway API 근거도 신설했다(`d32fc35`, `gitops.md` 6절). "Gateway API를 쓴다"가
전제로만 등장하고 아무 문서도 소유하지 않던 상태였다. 발표 자산은 docs와 맞추고 Notion 배포본도
갱신했다(본문 5곳, HTML·PPTX 첨부 재업로드).

## 다음 할 일
- [ ] EKS·AKS 재구축 후 cluster Secret 등록 — ⚠️ teardown이 매칭 라벨을 **먼저 떼고** 파일을
      지웠다. git 이력에서 되살리면 라벨이 빠진 껍데기이고 그 상태로는 Application이 하나도
      안 생긴다. EKS dev는 `environment`·`tier: nonprd`·`vpcName`·`karpenterNodeRole`,
      AKS dev는 `environment`·`tier: nonprd`·`addon-karpenter`가 필요하다.
- [ ] nonprd 클러스터가 생기면 `*-nonprd` ApplicationSet 팬아웃 실측 — 지금은 의도된 빈 슬롯이다
- [ ] 실제 승격 한 번 돌려보기(nonprd 올림 → 검증 → prd 올림). Kyverno는 엔진·정책 값 4개를
      짝으로 움직여야 한다
- [ ] (검토) Kyverno 엔진 단독 패치를 못 받는 문제 — helm index상 3.x에서 kyverno만 올라간
      릴리스가 8개 있는데 "같은 번호 유지" 규칙이 그것을 막는다. 보안 패치면 부딪힐 자리다
