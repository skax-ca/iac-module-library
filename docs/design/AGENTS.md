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
| `10-vpc-module.md` | 스크래치 VPC 모듈 — `subnet_groups` 계약, EKS-aware 태깅, custom networking용 100.64 대역, kill switch(D10), Flow Logs(D11) | ✅ 개정 완료 (`vpc-v1.0.0`) |
| `20-eks-module.md` | EKS wrapper(facade) — addon 경계(D-ADDON-BOUNDARY), Karpenter, Access Entry, 관리형 ArgoCD seam(§2.7) | ⚠️ 미개정 |
| `30-gitops-repo.md` | GitOps 저장소 구조 — App-of-Apps + ApplicationSet, AppProject 테넌시, addon 3분류 | ⚠️ 미개정 |
| `40-bastion.md` | SSM 기반 bastion — private 클러스터의 유일 조작 지점, `bastion_enabled` kill switch | ⚠️ 미개정 |

## For AI Agents

### Working In This Directory

- ⛔ **미개정 문서를 확정 설계로 인용하지 않는다.** 각 파일 상단 헤더를 먼저 읽어
  개정 여부를 판정한다 — 미개정 문서에 적힌 "실증됨"은 **이 repo에서 재현한 것이 아니다**.
  개정 완료 문서(현재 `10-vpc-module.md`)는 이 repo의 SSOT이므로 인용 가능하다.
- **개정 시 반드시 할 일**:
  1. 실증 서술(날짜·run ID·"확인됨")을 본문에서 제거하고 `../reference/poc-findings.md` 참조로 대체
  2. `workload=poc`·상대경로 소싱·TFC 워크스페이스 전제를 걷어낸다
  3. **재사용 요건 적용**(`../architecture/01-module-strategy.md` §4): 파라미터화·kill switch·
     환경 프로파일·예제/테스트·출력 계약
  4. 개정 완료 후 헤더를 provenance 형식으로 교체하고 `../README.md` 상태표를 ✅로 갱신
- **30-gitops-repo.md의 소유권은 재검토 대상이다.** GitOps 저장소는 모듈이 아니라 배포 자산에 가까워
  `../consumer/`로 옮기는 것이 맞을 수 있다. EKS 모듈과의 결합도를 보고 이식 시 판단한다.
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
- `../consumer/*` — 40-bastion 등이 배포 루트 구조를 전제하는 부분.

### External
- `terraform-aws-modules/eks` — 20이 wrapping하는 upstream(정확 핀 대상).

<!-- MANUAL: -->
