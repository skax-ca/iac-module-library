<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-29 | Updated: 2026-07-29 -->

# design

## Purpose
모듈별 상세 설계. **10(VPC)은 개정 완료**, 나머지는 ⚠️ **미개정**이다 —
PoC(Terraform 1.15 + HCP Terraform) 전제와 실증 서술이 그대로 남아 있다.
각 모듈을 이식할 때 재검토하며 개정한다(D-OSS-STACK §6-2).

**미개정 문서의 설계 판단(리소스 구성·경계·트레이드오프)은 대체로 유효하고, 실행 스택 종속부가 무효다.**
이 구분이 이 디렉토리를 다루는 핵심이다.

## Key Files
| File | Description | 상태 |
|------|-------------|------|
> ⚠️ **판정 근거는 이 표가 아니라 [`../README.md`](../README.md) 상태표다.** 이 표가 stale해진 전례가
> 있다(2026-08-05에 20을 "미개정"으로 적고 있던 것을 정정). 어긋나면 README를 따른다.

| File | Description | 상태 |
|------|-------------|------|
| `10-vpc-module.md` | 스크래치 VPC 모듈 — `subnet_groups` 계약, EKS-aware 태깅, custom networking용 100.64 대역, kill switch(D10), Flow Logs(D11) | ✅ 개정 완료 (현행 `vpc-v0.3.0`) |
| `20-eks-module.md` | EKS wrapper(facade) — addon 경계(D-ADDON-BOUNDARY), Karpenter, Access Entry, 노드 아키텍처(D-NODE-ARCH), external-dns zone 가드(D-EXTDNS-ZONE) | ✅ 개정 완료 (현행 `eks-cluster-v0.2.0`) |
| `21-gitops-bootstrap-seam.md` | 20에서 분리한 ArgoCD seam(§2.7·§2.8) | 🔴 **미결정** — "미개정"과 다르다. 판단 자체가 이 repo의 것이 아니다(`../architecture/01 §3.3`) |
| `22-day2-operations.md` | 업그레이드 런북 + Day 2 운영 프로파일(D-DAY2-PROFILE) | ✅ 신규 작성 |
| `30-gitops-repo.md` | GitOps 저장소 구조 — App-of-Apps + ApplicationSet, AppProject 테넌시, addon 3분류 | ⚠️ 미개정 |
| `40-workbench.md` | SSM 기반 workbench **모듈** — 도달 지점, `workbench_enabled` kill switch, EKS 접근 3층 소유 분할(D-WORKBENCH-SEAM) | ✅ 개정 완료 (2026-08-05) |
| `50-reference-consumer-repo.md` | 소비 경로 규약(D-CONSUME) — 이 repo에서 새로 쓴 설계 | ✅ 신규 작성 |

## For AI Agents

### Working In This Directory

- ⛔ **미개정 문서를 확정 설계로 인용하지 않는다.** 각 파일 상단 헤더를 먼저 읽어
  개정 여부를 판정한다 — 미개정 문서에 적힌 "실증됨"은 **이 repo에서 재현한 것이 아니다**.
  개정 완료 문서는 이 repo의 SSOT이므로 인용 가능하다(현재 남은 미개정은 `30`뿐).
- **개정 시 반드시 할 일**:
  1. 실증 서술(날짜·run ID·"확인됨")을 본문에서 제거하고 `../reference/poc-findings.md` 참조로 대체
  2. `workload=poc`·상대경로 소싱·TFC 워크스페이스 전제를 걷어낸다
  3. **재사용 요건 적용**(`../architecture/01-module-strategy.md` §4): 파라미터화·kill switch·
     환경 프로파일·예제/테스트·출력 계약
  4. ⭐ **의존 방향을 먼저 본다 — 개정은 번역이 아니다.** 그 문서가 **미결정 문서 위에 서 있으면**
     제목·범위부터 다시 잡는다. 실측(2026-08-05, `40`): 개정 전 40은 *"ArgoCD private 전환의 선결
     과제"* 여서 미결정(`21`)에 묶여 있었고, *"엔드포인트를 닫은 클러스터에 누가 닿는가"* 로
     일반화하자 **21과 무관하게 완결**됐다. 문장만 고쳤다면 그 종속이 남았을 것이다.
  5. **PoC의 결정 ID를 재판정하고 그 결과를 표에 남긴다**(승계·유효 / 개정 / 철회).
     실측: `D-BASTION-INLINE`은 PoC repo 안에서는 옳았으나(배포 루트가 있었다) 이 repo에는
     배포 루트가 없어 **철회**됐다. "그때 이렇게 정했다"와 "지금도 유효한가"는 다른 질문이다.
  6. 개정 완료 후 헤더를 provenance 형식으로 교체하고 `../README.md` 상태표를 ✅로 갱신
     — **이 파일(AGENTS.md)의 표도 같이 고친다.** 실제로 놓친 적이 있다.
- **30-gitops-repo.md의 소유권은 재검토 대상이다.** GitOps 저장소는 모듈이 아니라 배포 자산에 가깝다.
  EKS 모듈과의 결합도를 보고 이식 시 판단한다.
  ⚠️ **`../consumer/`로 옮기는 안은 이제 성립하지 않는다** — 그 디렉토리는 TFC 잔재 보관소가 됐다(D26-1).
  배포 자산 규약의 자리는 `50` 계열(소비 경로 설계)이다.
- **20의 관리형 ArgoCD 결정(§2.7)은 승계되지 않았다.** `../architecture/01-module-strategy.md` §3.3이
  "이 repo에서 재결정 필요"로 열어두었다 — IdC 필수·cross-region·RETAIN 등 제약이 크다.

### Testing Requirements
설계 문서가 규정한 동작은 모듈의 `*.tftest.hcl`로 증명한다. 특히:
- `Name` 태그 assertion (네이밍 규약 위반을 plan 단계에서 차단)
- 조건부 리소스(kill switch `false`)에서 plan이 통과하는지
- 모듈이 만든 출력 계약이 예제에서 실제로 소비되는지

### Common Patterns
- 결정에 ID를 부여한다(`D-<주제>`) — 나중에 문서 간 상호 참조가 쉬워진다.
- 열린 항목을 문서 말미에 남기고, 해소되면 그 자리에서 결정으로 승격한다.

## Dependencies

### Internal
- `../architecture/*` — 이 설계가 따라야 할 규약. **architecture가 상위**다.
- `../reference/poc-findings.md` — 본문의 실증 서술이 이관될 목적지.
- `../consumer/*` — 🗄️ TFC 잔재(보관 전용). 미개정 문서가 배포 루트 구조를 전제하는 부분의 출처이며,
  **확정 규약으로 인용하지 않는다**(D26-1). 소비 규약의 SSOT는 `50`이다.

### External
- `terraform-aws-modules/eks` — 20이 wrapping하는 upstream(정확 핀 대상).

<!-- MANUAL: -->
