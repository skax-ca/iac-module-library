# Notepad — iac-module-library

## Priority Context

**OSS IaC 모듈 자산 SSOT** — 2026-07-29 신설. 로컬 전용(원격 repo 미생성).

- **배경**: `terraform-enterprise-poc`가 2026-07-28 **동결(졸업)**. 결정 전문은 그 repo의
  `docs/architecture/05-oss-asset-repo-decision.md`(D-OSS-STACK).
  ⛔ **PoC repo의 모듈·설계를 고치지 않는다** — 양쪽 개발은 곧 drift다.
- **스택**: OpenTofu **1.12.5**(설치됨) + GitHub Actions(OIDC) + S3 backend(`use_lockfile`) + OPA/Conftest.
  명령은 `terraform`이 아니라 **`tofu`**. hook 활성화됨(`git config core.hooksPath .githooks`).
- **완료**: §6-0 골격 + deepinit(AGENTS.md 8개) · §6-1 설계 승계.
  커밋 `95e41dd` → `a6146ca` → `5abcb84`.
- **다음 작업 = §6-2 모듈 이식** (`vpc` → `eks-cluster` 순, 의존 방향). 모듈마다 4단계:
  1. `docs/design/*` 개정 — ⚠️ 현재 **미개정**(PoC 전제·실증 서술 잔존). 제거 후 재사용 요건 적용
  2. 코드 이식 + 파라미터화(`workload=poc` 등 하드코딩 제거) + kill switch
  3. `examples/<module>/` + `tofu test`(`Name` 태그 assertion 필수)
  4. `<module>-vX.Y.Z` 태그
  상세 절차는 `docs/design/AGENTS.md`, 릴리스 게이트는 `modules/AGENTS.md`.
- **문서 인용 규칙**: `docs/README.md`의 승계 상태표가 판정 근거.
  - `docs/architecture/*` ✅ 인용 가능 · `docs/design/*` ⚠️ **확정 설계로 인용 금지**
  - `docs/reference/poc-findings.md`는 **외부 스냅샷** — 참조만, 복사·갱신 금지
  - `docs/consumer/*` 📦 배포 루트 소유. 모듈 설계 근거로 쓰지 않는다
- **미결 항목**:
  - 원격 repo 미생성 (생성 시 ⚠️ **immutable sub claim** — 2026-07-15 이후 repo는 OIDC `sub`가 숫자 org/repo ID)
  - 보존한 `AWSAFTExecution`이 **assume 불가** 상태(입구 Role 삭제로 principal이 unique ID로 치환)
    → 부트스트랩 시 신뢰 정책 교체 필요
  - ⚠️ **TFE_TOKEN 폐기·재발급 미처리**(2026-07-28 세션 중 노출)
  - `docs/design/30-gitops-repo.md`의 소유권 재검토(모듈 repo vs consumer)
  - 관리형 ArgoCD 채택 여부 재결정(`docs/architecture/01-module-strategy.md` §3.3)
