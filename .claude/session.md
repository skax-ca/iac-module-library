# Session — iac-module-library

## 지난 세션 (2026-09-13)
발표자료(`.local/notion/v0.2/`, git 미추적) 3부 14~18장을 리뷰해 고쳤다. 옛 17장 「신원 경계」는
15장과 겹쳐 슬라이드에서 삭제했다(md 절은 유지, 총 24장). 약어 풀기(NAP·ACNS), 15장 제목·소개를
판단형으로, 17장은 기준을 "패턴 충돌 중심, 요금은 운영 부담과 견줌"으로 바꾸고 Auto Mode 묶음 ↔
AKS 기능 단위 대응을 넣었다. 18장 결론을 장 전체 요약으로 바꾸고, 16~17장·md 3.2~3.3에 stop-slop을 적용했다.

리뷰 중 드러난 저장소 문서 오류를 main에 직접 반영했다. `2e0cb72` aws/network.md가 판별 2를 반대
방향으로 인용하던 것 정정. `aa457c9` 「관리형 기능 채택 기준」을 패턴 충돌 중심으로 재작성
(AKS Automatic "별도 요금" 근거 삭제, 다른 사유로 검토한 적 없어 기각 목록에 올리지 않음).
`257e04d` ACNS를 "유료 애드온"이 아닌 `--enable-acns` 클러스터 기능으로 정정(`variables.tf`
description 포함, 사용자 결정으로 PR 생략, tofu test 42 passed). azurerm은
`azurerm_kubernetes_automatic_cluster`로 Automatic을 지원한다(5.2.0·5.3.0 확인).

## 다음 할 일
- [ ] 발표자료 19~24장 리뷰 (19장 4부 구분 슬라이드부터)
- [ ] addon staged 전파 구현 (발표 전 필수)
- [ ] 3부 경로 참조 Notion 반영
- [ ] 발표자료 수정분을 Notion 배포본에 반영 (md는 update-page, html은 재업로드+embed src 교체)
