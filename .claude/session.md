# Session — iac-module-library

## 지난 세션 (2026-09-14)
발표자료(`presentations/2026-09-iac-asset/`) 슬라이드를 흐름·논리 중심으로 전체 리뷰하고
사용자가 고른 항목을 반영해 **확정**했다: 「운영 도구와 승인 게이트」를 1부 끝(6장)으로 이동,
2부 팬아웃(10)↔가드레일(11) 순서 교체, 14장 ② 태그 `신원 경계` 삭제(후속 장 없음), 17장
Auto Mode 기각 사유에 "(self-managed ALBC는 GA, Auto Mode 내장은 미지원)" 병기(웹 확인),
15장 Microsoft 근거를 「랜딩존→구독 스코프로 못 덮음→관리 그룹→비권고」 사슬로, 12장
`allowedRoutes` 줄 삭제, 10장 "정책과 가드레일"→"정책 엔진", 2장 04 카드 태그 `함정`→
`구현체 선택`, 16장 `decisions-aks-cluster.md`→`azure/network.md`(실재 경로). 총 24장 유지.

이어서 md(노션 기술자료)를 확정 슬라이드 기준으로 정렬했다: 1.5 도구 절 신설(옛 2.4),
2.3 가드레일 절 신설(prune/selfHeal·AppProject cluster-admin 근거·세 필드), 2.2 `Exists`
예시 karpenter.yaml→kyverno.yaml(실물 대조: 둘 다 아직 `Exists`, staged 미구현), 3.1 근거
재배열+영향 범위 문장, 존재하지 않는 경로 3건 교정(`addon-rollout.md`→`gitops.md` 「전파
정책」, `decisions.md` 「크로스 계정 네트워킹」→`aws/network.md`, `decisions-aks-cluster.md`→
`azure/network.md`), `PR #36~38` 삭제, 머리 HTML 주석 삭제, 4.2 `allowedRoutes` 검사 주체를
Gateway 컨트롤러로 명시, 4.3에 EKS/AKS Gateway 발췌를 `*-platform-gitops` 실물 템플릿에서
옮겨 추가. 사용자가 md를 재검토해 피드백 주기로 했다.

저장소 커밋 변경 없음. 슬라이드 리뷰 중 남긴 미반영 제안: 20장 마무리에 AWS도 옮기는 이유
부재(22장에 있음), 24장 할 일에 Gateway API 전환 항목 없음(2장은 "곧 겪을 전환").

## 다음 할 일
- [ ] addon staged 전파 구현 (발표 전 필수) — 10장이 "세 가지를 씁니다" 현재형이라 못 끝내면 문구 조정 필요
- [ ] md 재검토 피드백 반영 (사용자가 확인 후 전달 예정)
- [ ] 3부 경로 참조 Notion 반영 — md 쪽 경로는 이번에 교정했으니 Notion 배포본에만 남음
- [ ] 발표자료 수정분을 Notion 배포본에 반영 (md는 update-page, html은 재업로드+embed src 교체)
- [ ] docs에 AWS Ingress→Gateway API 선택 근거 기록 (강제 아님: ALBC Ingress 지원 지속, Ingress API frozen이지 제거 아님. 선택 이유는 앱팀 매니페스트 양 클라우드 통일. `gitops.md` 187행은 "ALBC 조립"까지만 있음)
- [ ] (선택) 20장 마무리에 AWS도 옮기는 이유 반 문장, 24장에 Gateway API 전환 항목 — 사용자 미결
