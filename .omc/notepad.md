# Notepad — iac-module-library

## Priority Context
SSOT=이 repo. 엔진=OpenTofu(decisions.md 필독). 규약=conventions.md. 네이밍=docs/naming/abbreviations/. 모듈경로=modules/<provider>/<name>/. .tf규칙=.claude/rules/terraform.md. AWS4+Azure2 전 6모듈 릴리스 완료. aks-cluster v0.5.0(cni_mode 선택형, 기본 overlay, NAP 호환). v0.4.0=network_policy 정정(ARM 거부), v0.5.0=upgrade_settings 정정(perpetual diff) — 둘 다 aks-reference-infra 실배포에서 발견, hub AKS 실배포 완료. 다음 Azure 모듈은 사용자 판단. 영구사실=project-memory.json. notepad/project-memory MCP 도구는 permissions.deny로 전면 제거(Read/Edit만 사용).

## Working Memory
### 2026-09-03 — aks-cluster CNI 모드 리서치·확장(v0.2.0)·기본값 overlay 전환(v0.3.0)

`aks-reference-infra`의 `live/hub/aks` 설계 라운드에서 사용자가 발견한 두 문제(Karpenter가
Overlay 없이는 안 된다는 것, Azure에 workbench 대응 모듈이 없다는 것)를 공식 문서로 검증하며
시작된 세션. `karpenter-provider-azure` 메인테이너가 공식 이슈(#1352, 2026-01-15 오픈,
미해결)에서 "Pod Subnet(dynamic·static block 모두)은 NAP과 전혀 호환되지 않는다"고 직접
명시한 것을 확인 — 8월 세션이 "미검증"으로 남긴 리스크가 확정으로 바뀜.

**PR #39(aks-cluster-v0.2.0)**: `cni_mode` 변수 신설(`pod_subnet`(당시 기본)·`node_subnet`·
`overlay`), `enable_karpenter` 기본값 `true`→`false`(기본값 조합 상충 회피), 교차변수
validation으로 `pod_subnet`+`enable_karpenter=true` 조합을 plan에서 차단.

**후속 리서치**: 사용자가 "AWS 모양 맞추기가 정답이 아니라 Azure 권고안으로 검토해야
한다"고 방향을 잡아 Microsoft 공식 결정 가이드(`plan-pod-networking`)와 AKS 베이스라인
참조 아키텍처를 재확인 — 둘 다 AWS 대칭성과 무관하게 Overlay를 일반 기본값으로 명시
("Our general recommendation is to use Azure CNI Overlay"). 0.1.0이 Overlay를 기각한
유일한 사유(SNAT로 인한 Pod 단위 관측성 손실)에 대해서도 Azure의 유료 애드온 Advanced
Container Networking Services(ACNS)가 eBPF로 SNAT 이전 지점에서 Pod identity를 캡처하는
별도 답을 갖고 있음을 확인(완전한 대체재는 아님, 저장 로그는 Cilium 전용·기본 집계는
워크로드 단위).

**PR #40(aks-cluster-v0.3.0)**: `cni_mode` 기본값을 `"pod_subnet"`→`"overlay"`로 전환.
`enable_karpenter` 기본값은 `false` 유지(이제 호환성이 아니라 순수 옵트인 설계). 32개
테스트 전부 overlay 기준으로 재작성. `examples/basic`·README.md Usage 예시 둘 다 새
기본값이 요구하는 최소 구조(secondary CIDR·`aks-pod` 서브넷 불필요)로 재작성 — 사용자가
README Usage 스니펫에서 `aks-pod` 잔재를 직접 발견해 추가 커밋으로 수정.

**부수 발견**: `docs/decisions.md`에서 직전(PR #39) 세션이 새 절을 기존 blockquote 중간에
잘못 삽입해 blockquote가 깨져 있던 버그를 발견·복구.

**vnet 모듈 자체는 무변경**: `address_space`·`subnet_groups`는 CNI를 전혀 모르는 범용
입력이라(검증 블록 없음, 실측 확인) `cni_mode` 관련 작업은 전부 소비자 root
(`aks-reference-infra`) 또는 이 모듈 안에서 끝났다.

⚠️ **다음 세션 확인 필요**: `aks-reference-infra`의 hub(`100.64.0.0/16`)·dev
(`100.65.0.0/16`)는 아직 옛 기본값(`pod_subnet`) 전제로 secondary CIDR을 VNet에
붙여둔 상태다. `cni_mode` 기본값이 overlay로 바뀐 지금 이 CIDR은 죽은 대역이다(지우지
않아도 안전, 참조하는 서브넷 없음) — 정리할지 남겨둘지는 그 repo 세션에서 판단할 것.
`docs/module-catalog.md`「Pod 네트워킹, cni_mode별 VNet 구조」절에 이 불일치를 명시
경고해뒀다.

### 2026-09-03(2차) — aks-cluster v0.4.0: overlay network_policy 버그 수정 + hub/dev CIDR 정리 확인

위 "다음 세션 확인 필요" 두 항목 모두 같은 날 해소됐다. (1) `aks-reference-infra`의
hub·dev secondary CIDR(`100.64.0.0/16`·`100.65.0.0/16`)은 그 repo 세션에서 실제로
제거·apply 완료(PR #1). (2) 그 직후 `live/hub/aks` 배포 계획의 Architect 검토에서
`cni_mode="overlay"`(0.2.0~0.3.0 공통) 경로가 실제로는 apply 불가였다는 걸 발견 —
`network_data_plane="cilium"`은 조건부로 켰지만 `network_policy`는 `"azure"`로
고정해 둬 ARM이 "Cilium dataplane requires network policy cilium."으로 거부한다
(provider 문서에도 짝 요구가 명시돼 있었다). `network_policy`를 `cni_mode`에 따라
조건부화(PR #41, aks-cluster-v0.4.0 태그)하고 테스트 3건에 assertion 추가.
`tofu test`는 `mock_provider`라 이런 ARM 레벨 정합성 오류를 구조적으로 못 잡는다는
한계를 재확인 — 소비 repo의 실제 apply가 최종 검증선이라는 원칙이 이번에도 성립했다.

### 2026-09-03(3차) — aks-cluster v0.5.0: upgrade_settings perpetual diff 정정 + hub AKS 실배포 완료

v0.4.0으로 `aks-reference-infra`의 `live/hub/aks`(hub 구독 첫 실배포)를 진행하며 두 번째
모듈 버그를 발견했다. `default_node_pool`·추가 노드 풀(`azurerm_kubernetes_cluster_
node_pool`) 둘 다 `upgrade_settings`를 선언하지 않아, Azure가 노드 풀 생성 시 이 블록을
`max_surge="10%"` 기본값으로 채워 반환하는데 HCL에 선언이 없으면 OpenTofu가 매 plan마다
"제거 대상"으로 표시한다 — apply해도 Azure가 다음 조회에서 같은 기본값을 또 채워 넣어
**수렴하지 않는 perpetual diff**였다(완료 판정 §4-8 "재-plan 수렴" 확인 중 독립된 plan
3회 연속 같은 diff로 실측, 파괴적이진 않았음). `azurerm_kubernetes_cluster.default_
node_pool.upgrade_settings.max_surge`는 provider 스키마상 Required라 블록 자체를
생략할 수 없다(직접 스키마 조회로 확인, `azurerm_kubernetes_cluster_node_pool` 쪽은
Optional). 두 리소스 모두 `upgrade_settings { max_surge = "10%" }`를 명시해 Azure
기본값과 맞춰 정정(PR #42, aks-cluster-v0.5.0 태그), 테스트 2건에 assertion 추가.

`live/hub/aks`를 v0.5.0으로 업그레이드해 재적용 → 완료 판정 §4 8항목 전부 통과, hub
구독에 `aks-demo-hub-krc-main-01` 클러스터가 실제로 떠 있다(노드 2대 `Ready`, Overlay
CNI, Karpenter는 GitOps 계층 부재로 꺼둔 채). 이 세션에서 발견한 버그 2건(v0.4.0
network_policy, v0.5.0 upgrade_settings) 모두 모듈 자체 `tofu test`(mock_provider
기반)로는 구조적으로 못 잡는 ARM 레벨 정합성 문제였다 — 소비 repo의 실제 apply가
최종 검증선이라는 원칙이 이번 세션에서 두 번 연속 성립했다.

### 2026-09-01 — 발표자료 마무리 + notepad/project-memory MCP 도구 사용 전면 중단

`presentations/ai-iac-asset-library.md`는 사용자가 "이걸로 마무리"라고 확정 — 더 이상 진행 중 상태 아님.

세션 시작 시 `project_memory_read` 호출로 `techStack`/`build`/`conventions`/`structure`/`hotPaths`가
또다시 빈 자동스캔 스키마로 손상된 것을 발견(2026-08-30과 완전히 동일한 재발) — `git show HEAD`
기준으로 즉시 복원. 이를 계기로 사용자가 "근본원인을 제거하고 핸드오프만 잘 되게 개선하라"고 요청,
Claude Code 공식 문서(`memory.md`·`hooks.md`·`permissions.md`)와 OMC 저장소를 리서치해 근본원인과
개선안을 도출·적용:

- **원인**: `mcp__t__notepad_*`/`project_memory_*`는 "읽기"조차 내부적으로 프로젝트를 재스캔해
  서술형 필드를 덮어쓰는 부수효과를 가짐 — 표준 Read/Write 도구엔 없는 숨은 로직. 쓰기 6종만
  막았던 기존 PreToolUse 훅으로는 읽기 쪽 재발을 못 막았다.
- **검토했다가 기각한 안**: Claude Code 네이티브 auto memory(`~/.claude/projects/.../memory/`)로
  전면 이전 — 공식 문서에 "절대경로 또는 `~/`만 허용, 머신 간 공유 안 됨"이라 명시돼 있고, 이
  저장소 자체가 과거에 머신별 홈 경로가 다름을 겪은 전례가 있어(a07326→born2k) git 포터블
  요구사항을 충족 못 함.
- **적용한 안**: `.claude/settings.json`을 `permissions.deny`(`mcp__plugin_oh-my-claudecode_t__notepad_*`·
  `..._project_memory_*`)로 교체 — 호출을 막는 게 아니라 도구 자체를 Claude의 도구 목록에서
  제거(공식 문서: "a bare tool name... removes the tool from Claude's context entirely"). 기존
  PreToolUse 훅(쓰기 6종만) 대비 더 근본적이고 훅 타임아웃 리스크도 없음. `notepad-sync` 스킬
  문서도 세션 시작/종료 절차를 MCP 호출 대신 `Read`/`Edit` 직접 사용으로 재작성.
- **적용 직후 실측 확인**: 설정 반영과 동시에 해당 10개 도구가 세션에서 즉시 연결 해제됨을 확인
  (재시작 불필요).
- 이 결정은 이 저장소 한정 — `eks-reference-infra`·`aks-reference-infra`는 아직 같은 MCP 도구를
  그대로 씀. 전파 여부는 다음에 그쪽 세션에서 판단.

상세 리서치 근거(공식 문서 인용 포함)는 `.omc/project-memory.json`의 `mcp-tooling-fix` 카테고리 참조.

### 2026-08-30 (세션5) — 팀 발표자료 전면 재구성 + presentations/ 디렉토리 신설

사용자가 노션에 있던 발표자료("AI를 활용한 IaC Asset 만들기")를 팀 발표용으로 다시 쓰고 싶다고
요청. 처음엔 원문을 그대로 스크래치패드(`.local/`)에 옮겨 평가했는데, 사용자가 핵심 메시지를
완전히 뒤집기로 결정: 원래는 Claude Code 활용기가 중심이었으나, "iac-module-library가 팀의
Terraform 모듈·아키텍처 패턴 자산이고 계속 추가·갱신한다"가 주메시지, Claude Code는 그 실행을
도운 부연이라는 구도로 전환. `eks/aks-reference-infra`·`eks/aks-platform-gitops` 4개 repo는
자산이 아니라 자산을 소비한 예시(GitOps 패턴 사례)라는 구분도 명확히 함.

여러 라운드에 걸쳐 다듬음: stop-slop 스킬로 em dash·이분법 대비·행위자 누락 등 AI 문체 패턴
제거, 한국 IT에서 안 쓰는 번역투 제거("트랙 레코드"→"실적", "자산 본체"→삭제 등), 제목 6개를
콜론·질문형에서 통일된 명사구로 재작성(최종: 매번 다시 만들던 것들 / 코드와 패턴 / 구조와 사례 /
지금까지 만든 것 / 일관성을 지키는 장치 / 다음 할 일).

**실측으로 잡은 것 2건**: (1) 트랙 레코드 초안에 "최근 한 달"이라고 썼는데 `git log --tags`로
확인하니 실제로는 나흘 이내라 정정. (2) 사용자가 직접 편집하는 과정에서 1부에 "라이선스 문제"라는
표현이 잠깐 들어갔는데, `CLAUDE.md` 16행("채택 근거는 라이선스가 아니라 조달 마찰·리워크 제거")과
정면으로 모순되는 오해라 근거를 인용해 지적 — 사용자가 "비용 문제"로 정정.

**최종 위치**: `presentations/ai-iac-asset-library.md`(신규 최상위 디렉토리). `docs/README.md`가
`docs/`를 "설계·규약 문서"로 명시적으로 범위 한정해서(발표자료는 이 범주 아님), `docs/` 대신
별도 최상위 디렉토리로 분리 — 이 저장소의 새 구조적 선례. 문서 전용 변경이라 브랜치 없이 main
직접 커밋(`3f9bf6c`). 세션 종료 시점 기준 사용자가 IDE에서 직접 계속 다듬는 중, 아직 미완성.

**교훈**: opus5 서브에이전트에 도입부·1부 톤 다듬기를 위임했더니 "이 팀은 ~한다"는 3인칭
관찰자 시점으로 다시 써서 사용자가 반려("발표자 본인이 팀원들에게 말하는 자리인데 남 얘기하듯
들린다"). 1인칭 화자가 자기 팀에게 말하는 발표 대본류 문서는 톤이 사용자 취향에 민감해서,
서브에이전트 위임보다 여러 라운드에 걸친 직접 수정이 더 잘 맞았다. 비슷한 발표/커뮤니케이션
문서 톤 작업은 다음에도 위임보다 직접 처리를 우선 고려할 것.

### 2026-08-30 (세션4) — 문서 중복 정리 + Azure 저장소 관계 반영 + aks-reference-infra 실사 + 아키텍처 문서 작성 시점 평가

두 건의 docs 정리를 main에 직접 커밋: (1) README.md·conventions.md의 모듈 소싱 예시 중복 제거,
conventions.md는 README.md를 SSOT로 가리키는 링크로 대체(`4e9ad3d`) (2) README.md·CLAUDE.md에
Azure 배포 체인(`aks-reference-infra`·`aks-platform-gitops`, 후자는 아직 미생성) 반영 — README의
"세 저장소의 관계"는 저장소가 5개로 늘어 "저장소 관계" 표로 재구성(`1ff6c7b`). 둘 다
`validate-doc-conventions.py`·`validate-abbreviations.py` 통과 확인 후 커밋.

이어서 사용자 요청으로 `gh repo clone skax-ca/aks-reference-infra`를 스크래치패드에 실행해 실물
확인 — project-memory의 기존 인식(리서치만 완료)보다 훨씬 진행돼 있었음(hub networking·vwan
실배포 완료, dev bootstrap 완료, dev networking 코드 완성했으나 Azure 권한 전파 지연으로 CI
블록). 특히 aks-cluster-v0.1.0 릴리스로 그쪽 repo의 Phase 2(AKS) 착수 조건이 이미 충족됐다는
연결점을 발견. 상세는 `.omc/project-memory.json`의 `azure-architecture-doc-readiness` 카테고리
(timestamp 1788088000000) 참조.

그 조사를 근거로 `docs/architectures/aks-gitops-hub-spoke/` 작성 가능 여부를 평가 — **아직 이르다고
결론**. `eks-gitops-hub-spoke/`가 전부 실전 검증 사실만 담는 문서인 반면, Azure 쪽은 핵심 메커니즘
(AKS 배포·ArgoCD 대응물·크로스 구독 GitOps 인가)이 전부 미실현 상태. 작성 트리거 3가지와 트리거
도달 시 작성 순서를 정의해 project-memory에 기록, `docs/architectures/README.md`에는 빈 스텁을
추가하지 않기로 함(vnet·aks-cluster에서 두 번 겪은 "설계 단계 placeholder 미제거" 패턴 재발 방지).

`aks-reference-infra`의 CLAUDE.md가 stale하다는 것과 그쪽 notepad.md에도 같은 stale-cache 중복
버그가 있다는 것도 발견했으나, 사용자 지시로 그 repo 수정은 그쪽 세션 몫으로 남기고 이 세션에서는
손대지 않음.

### 2026-08-30 (세션3) — PreToolUse 훅 라이브 검증 완료

세션2가 미검증으로 남긴 항목(MCP 쓰기 툴 6개 차단 훅이 실제로 발동하는지)을 확인. `notepad_write_priority`를
현재 Priority Context와 바이트 단위로 동일한 내용으로 호출해 라이브 테스트 — 설정한 deny 메시지가 그대로
반환되고 `git status`로 notepad.md 무변경 확인. `.claude/settings.json`이 세션 시작 시점에 이미 존재해
watcher가 정상 감지한 것으로 보임(`/hooks` 리로드 불필요). 부수 확인: 이번 세션 `project_memory_read` 호출로도
techStack/build/conventions/structure 손상은 재현되지 않음(hotPaths 접근 카운트만 갱신) — 표본 1건이라
이 읽기-부수효과 버그가 사라졌다고 단정하지는 않음, 앞으로도 read 직후 git diff 확인 습관 유지. 상세는
`.omc/project-memory.json`의 `open-items` 카테고리(timestamp 1788077000000) 참조.

### 2026-08-30 (세션2) — 글로벌 CLAUDE.md 트리밍 + notepad.md 2차 중복 발견·제거 + pre-commit 훅 레벨 버그 수정

사용자 요청으로 `~/.claude/CLAUDE.md`의 "OMC 플러그인 disabled" 트러블슈팅 절(위 세션1이 그날 작성)을
63줄→8줄로 정리. 근본원인 절의 날짜·사건 서술을 걷어내고 확인·해결 명령 두 줄만 남김. bootstrap.sh의
`enabledPlugins` 병합 로직이 실제로 존재하고 현재 플러그인도 `enabled: true`임을 실측 확인 후 진행.
dotfiles push(`eea8feb`)로 반영.

이어서 "notepad 문제 없는지 확인"을 요청받아 점검하던 중 **2026-08-28 사고와 별개의 신규 중복 사고**를
발견: 335~441줄(106줄)이 58~163줄과 완전히 동일한 블록으로 중복 삽입돼 있었다(diff로 바이트 단위
동일 확인). git blame으로 근본원인 추적: PR #38 squash-merge 커밋(`4fc6a488`, 17:40)이 브랜치에
쌓여있던 304줄을 main에 얹었는데, 4분 뒤 세션5가 자신의 요약을 기록한 커밋(`8297c8ba`, 17:44)이
**merge로 막 갱신된 디스크 최신본이 아니라 merge 이전 stale 캐시를 기준으로 파일을 재구성**하며
방금 들어온 내용 상당수를 "새 내용"인 양 다시 덧붙였다 — project-memory의 `mcp-tooling-bug`
카테고리가 기록한 "stale 캐시 기반 전체 재작성" 패턴이 git merge 직후 시점에 재현된 것.

**왜 방어 훅이 못 막았는지도 규명**: `.githooks/pre-commit`의 중복 검사가 `/^## /`(H2)만 보는데
실제 세션 항목 헤더는 전부 `### `(H3)라 애초에 이 클래스의 중복을 구조적으로 탐지 불가능한
상태였다(이 사고 자체는 2026-08-28로 훅 신설(2026-08-30) 이전이라 어차피 안 잡혔겠지만, 훅의
레벨 버그는 지금도 살아있어 같은 사고가 재발해도 여전히 못 잡는 상태였다). `.githooks/pre-commit`의
정규식을 `/^#{2,3} /`로 확장해 H2·H3 모두 검사하도록 수정 — 백업본(중복 있던 원본)에 새 정규식을
적용해 18개 헤더가 정확히 잡힘을, 수정된 현재 파일엔 0건임을 각각 실측 검증.

부수 발견: Priority Context와 Working Memory 사이에 깨진 잔여 줄 2개("## MANUAL(자동 로드 안 됨)
참조."/"## MANUAL`(자동 로드 안 됨) 참조.", 커밋 `0e17b01d`·`7b07a9ad`로 하루 간격을 두고 각각
추가된 것 — 이 역시 같은 계열의 소규모 중복 삽입 사고로 추정)를 발견해 제거.

결과: notepad.md 3803줄/356KB → 3696줄/337KB(중복 106줄 + 잔여 4줄 제거). 백업은 `/tmp/notepad.md.bak`.

**교훈**: 이 프로젝트의 stale-캐시 재작성 버그는 "MCP 쓰기 도구 호출 시"뿐 아니라 "git 상태가
방금 바뀐 직후(merge/pull 등)의 다음 쓰기"에서도 같은 증상으로 재현된다 — 트리거가 도구 종류가
아니라 "디스크 상태와 세션이 들고 있는 캐시가 어긋난 타이밍"이라는 뜻. 방어 훅은 만든 뒤에도
정규식이 실제 데이터 형태(H2 vs H3)와 맞는지 반드시 백업본으로 역검증할 것 — 이번처럼 "훅이
있으니 안전하다"는 가정 자체가 거짓일 수 있다.

**(이어서)** 사용자 요청으로 "150KB 넘는 오래된 세션을 MANUAL로 이관"까지 진행. 점검 중 헤더
레벨만 다른 중복(`## 2026-08-21 15:58` vs `### 2026-08-21 15:58`, 커밋 히스토리상 서로 다른 시점에
독립적으로 삽입된 것)을 추가 발견 — `uniq -d`는 문자열 완전 일치만 잡아서 훅이 놓치는 사각지대였다.
orphan(`##` 버전)을 삭제하고, 훅 정규식에 `gsub(/^#+ /,"")`로 헤더 텍스트 정규화를 추가해 이 클래스도
잡히게 함(백업본 역검증으로 확인). 이관 자체는 Working Memory(6~48줄, 2026-08-30 두 항목만 남김)의
과거 완료 스레드(2026-08-14~08-28, Azure 기반구조·vnet·aks-cluster·iac-platform-gitops 리뷰 등
전부 완료·미결 없음)를 `## MANUAL` 최상단(기존 아카이브보다 최신이라 그 위)에 이관. ⚠️ **중요한 한계**:
이 이동은 파일 총 바이트를 줄이지 않는다(MANUAL도 같은 파일 안이라 pre-commit의 150KB 총량 경고는
그대로 유지) — MANUAL 자체가 이미 옛 아카이브(2026-07-29~08-14, ~270KB)로 커서 그게 총량의
대부분을 차지한다. 실질 효과는 **세션 시작마다 notepad-sync가 읽는 Working Memory 크기**를
65KB→6KB로 줄인 것(MANUAL은 자동 로드 안 됨, 필요 시에만 조회). 150KB 총량 경고 자체를 없애려면
MANUAL 자체를 별도 파일로 분리하거나 더 오래된 부분을 쳐내는 별도 작업이 필요 — 오늘은 미착수,
다음에 필요성 판단.

**(다시 이어서)** 사용자가 곧바로 "MANUAL도 별도 파일로 분리해줘"를 요청해 실행. `## MANUAL`
섹션 본문 전체(3684줄)를 `.omc/notepad-manual.md`로 옮기고, `notepad.md` 쪽엔 그 파일을
가리키는 포인터 한 줄만 남겼다 — 결과: `notepad.md` 337KB→8KB(150KB 경고 완전 해소),
`notepad-manual.md`는 334KB(자동 로드 안 되니 무관). `.gitignore`에 새 파일 화이트리스트 추가,
내용 손실은 백업 대비 정렬-비교로 무손실 확인. `notepad-sync` 스킬 문서도 갱신: (1) MANUAL만
`eks-reference-infra`와 구조가 갈렸다는 점 명시 (2) `notepad_write_manual` MCP 툴이 이제
포인터만 건드리고 실제 아카이브는 모른다는 것, 이후 MANUAL 편집은 Edit으로 `.omc/notepad-manual.md`를
직접 쓸 것 (3) pre-commit 훅은 `notepad.md`만 검사하고 `notepad-manual.md`는 대상 밖(정상)
(4) `.opencode/plugins/notepad.ts`가 이 분리를 아는지는 미확인 — 다음에 opencode 세션에서
MANUAL을 다룰 때 먼저 소스 확인 필요.

**(마지막)** 사용자가 이어서 "opencode 플러그인도 분리 반영해줘"를 요청 — `.opencode/plugins/notepad.ts`
수정. `notepad_read(section=manual)`/`notepad_write_manual`이 이제 `.omc/notepad-manual.md`를
직접 읽고 쓰도록 분리(각각 새 `manualPath()`/`DEFAULT_MANUAL` 사용), `notepad_write_priority`/
`notepad_write_working`은 그대로 `notepad.md`의 `splitSections`/`rebuild`를 쓰되 MANUAL 섹션은
건드리지 않아 포인터가 보존됨. 직접편집 차단 게이트(`tool.execute.before`)에 `notepad-manual.md`
경로도 추가. bun이 이 머신에 없어 기존 단위 테스트(2026-08-18 세션이 언급한 10건)를 못 돌렸고,
저장소에 그 테스트 파일 자체가 없다는 것도 이번에 확인(당시 세션 한정 산출물이었던 듯) — 대신
핵심 함수(`splitSections`/`rebuild`/`loadFile`/`saveFile`)를 그대로 복제한 순수 node 스크립트를
스크래치패드에서 실제 파일 **사본**에 대해 실행해 13개 항목 검증: priority/working/manual 읽기가
각각 올바른 파일에서 올바른 내용을 반환하는지, write_manual이 notepad.md를 전혀 안 건드리는지,
rebuild가 옛 아카이브 내용을 notepad.md로 새어들게 하지 않는지, 게이트가 두 파일 경로를 모두
인식하는지. 실제 repo 파일은 무손상(git status로 확인). ⚠️ 미해결: bun 단위 테스트 자체가
없다는 사실 — 다음에 이 플러그인을 또 고칠 일이 있으면 스크래치패드 임시검증 대신 정식 테스트
파일을 만드는 걸 고려할 것.

**(진짜 마지막)** 사용자가 "세션종료 시 중복 작성을 원천적으로 방지하고 싶다"고 요청 — "이번엔
조심하겠다"류의 기억 의존 대책이 아니라 구조적 차단을 요구한 것으로 판단. `update-config` 스킬로
`.claude/settings.json`(신규, 커밋 대상) PreToolUse 훅 신설: OMC MCP 쓰기 툴 6개
(`notepad_write_working`·`notepad_write_priority`·`notepad_write_manual`·`project_memory_add_note`·
`project_memory_add_directive`·`project_memory_write`)를 이 저장소 세션 전체에서 `permissionDecision:
deny`로 기계적으로 차단, 대체 경로(Edit 직접 편집)를 거부 사유 메시지에 안내. 이 세 파일
(`notepad.md`·`notepad-manual.md`·`project-memory.json`)에 대해 이제까지 "Edit이 더 안전하다"는
스킬 문서상의 **권고**였던 것을 **강제**로 뒤집었다 — 이 세션이 잊거나 규율을 어겨도 도구 자체가
막는다.

⚠️ 라이브 테스트는 의도적으로 생략: 이 세션은 `.claude/settings.json`이 없는 상태로 시작해 설정
watcher가 이 파일 생성을 못 감지했을 가능성이 높다(update-config 스킬의 알려진 캐비어트). 실제로
`notepad_write_working`을 호출해 "막히는지" 확인하는 건, 훅이 아직 안 걸렸을 경우 **바로 지금
막으려는 그 중복 버그를 직접 유발**하는 위험한 시도라 하지 않았다. 대신 `jq -e`로 스키마·구문
검증, 파이프 테스트로 훅 command가 올바른 deny JSON을 뱉는지만 확인했다. **다음 세션(재시작 또는
`/hooks` 이후)에서 이 훅이 실제로 발동하는지 첫 notepad 관련 작업 때 확인할 것** — 발동 안 하면
`/hooks`를 한 번 열어 설정을 리로드해야 한다(사용자 조작 필요, Claude가 대신 할 수 없음).

`notepad-sync` 스킬 문서도 갱신: 세션종료 2번 절의 "MCP 쓰기 툴을 통해서만 쓴다" 지시를 정반대로
뒤집어 "Edit이 유일한 쓰기 경로, MCP 쓰기 툴은 훅이 막는다"로 재작성. 읽기 툴(`notepad_read`/
`project_memory_read`)은 훅 대상에서 제외(세션 시작에 필요하고, 손상 시 즉시 git diff로 잡을 수
있어 상대적으로 안전) — 다만 읽기도 과거 부수효과가 있었으니 호출 후 git diff 습관은 유지.

### 2026-08-30 — 세션 요약: dotfiles OMC 플러그인 disabled 해결 + project-memory 도구 부수효과 버그 발견·복구

세션 시작 시 dotfiles `sync.sh pull`이 "oh-my-claudecode@omc(user scope)가 플러그인 등록부에서 disabled" 경고를 출력. `claude plugin list --json`으로 실측 확인 후 `claude plugin enable oh-my-claudecode@omc` 실행으로 해결. 이번 세션은 이미 로드된 상태를 쓰고 있어 무영향이었지만, 재시작 시 OMC 스킬·MCP 도구가 전부 안 보일 뻔했다. `~/dotfiles-claude/claude/CLAUDE.md`의 "머신별 OMC 활성화" 절에 이 별개 레이어(dotfiles opt-in 플래그 vs Claude Code 자체 플러그인 등록부) 관련 증상·확인법·해결법을 하위 항목으로 추가(커밋 `3ac1be2`, sync.sh의 auto-commit/push로 이미 원격 반영됨).

세션종료 절차 중 `git status`로 `.omc/project-memory.json`이 수정된 것을 발견 — 이번 세션에서 `mcp__t__project_memory_read`를 호출한 것 외엔 손댄 적이 없는데도, techStack/build/conventions/structure 4개 필드가 유효한 서술형 문자열에서 빈 자동스캔 스키마로 통째로 대체돼 있었다(customNotes 20개·userDirectives는 손실 없음). git show HEAD로 4개 필드를 복원. 이어서 `project_memory_add_directive`/`add_note`로 이 발견을 기록하려다 **두 번째 버그**를 발견: `add_note`가 20개 고정 상한 FIFO로 동작해, 새 노트 추가 시 가장 오래된 노트(azure-vnet 최초 구현 완료 기록, 다음 노트가 직접 참조하던 항목)를 경고 없이 삭제했다. git show HEAD로 삭제된 노트를 timestamp 순서에 맞춰 재삽입해 복구(21개로 정정). 이어서 이 항목 자체를 `notepad_write_working`으로 기록하려다 **세 번째 버그**를 재현: 2026-08-28 세션4와 동일하게 stale 캐시 기반 전체 재작성으로 다수 헤더가 3배 중복 삽입됨(322줄 증가, 헤더 다수 3중복 실측) — 즉시 `git checkout -- .omc/notepad.md`로 원복 후 이 항목은 Edit으로 직접 삽입.

**교훈**: 이 프로젝트에서 `mcp__t__project_memory_*`/`notepad_*` 계열 도구는 읽기·쓰기 가리지 않고 부수효과(재스캔에 의한 필드 손실, 20개 상한 FIFO 삭제, stale 캐시 기반 전체 재작성에 의한 3중복)를 낸다 — 이번 세션 한 세션 안에서만 3가지 서로 다른 유형을 실측했다. 매 호출 후 반드시 `git diff`/개수 대조로 검증하고, 손상 시 `git show HEAD` 또는 `git checkout --`로 즉시 복구할 것. 이 시점부터는 이 두 파일에 한해 MCP 쓰기 도구보다 Edit 직접 사용을 기본값으로 삼는 편이 안전하다. 상세는 `.omc/project-memory.json`의 `mcp-tooling-bug` 카테고리 노트 2건, critical directive 1건 참조.


## MANUAL

`.omc/notepad-manual.md` 참조 — 별도 파일로 분리됨(2026-08-30), 자동 로드 안 됨.
