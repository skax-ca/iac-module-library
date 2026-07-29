# Notepad — iac-module-library

## Priority Context

**OSS IaC 모듈 자산 SSOT** — 2026-07-29 신설. 로컬 전용(원격 repo 미생성 → `git push` 불가).

- **배경**: `terraform-enterprise-poc`가 2026-07-28 **동결(졸업)**. 결정 전문은 그 repo의
  `docs/architecture/05-oss-asset-repo-decision.md`(D-OSS-STACK).
  ⛔ **PoC repo의 모듈·설계를 고치지 않는다** — 양쪽 개발은 곧 drift다.
- **스택**: OpenTofu **1.12.5** + GitHub Actions(OIDC) + S3 backend(`use_lockfile`) + OPA/Conftest.
  명령은 `terraform`이 아니라 **`tofu`**. hook 활성화됨(`git config core.hooksPath .githooks`).
- **⚙️ 엔진 결정 확정**(2026-07-29, `docs/architecture/04-engine-decision.md` = **D-ENGINE**):
  **OpenTofu 단독.** D-OSS-STACK(PoC repo `05`)의 엔진 축 **근거를 교체**했다 — 결론은 같고 이유가 다르다.
  - ⛔ **라이선스는 채택 근거가 아니다.** HashiCorp FAQ가 컨설팅 사용을 **명시적 허용**한다.
    비용 장벽은 CLI가 아니라 **HCP/TFE 구독**이었고 축 B(Actions+S3)로 이미 해소됐다.
    실제 근거는 **리워크 0 + OSI 조달 마찰 제거**다.
  - ⛔ **"두 엔진 지원" 재제안 금지 — 이미 값을 매겨 기각했다**(04 §3). Task 10.1 구현 중 실측:
    교차변수 validation 지원 확인 비용 · sentinel 우회 · lock 커밋 포기 · 로컬↔CI 피드백 지연 ·
    그리고 **`required_version`이 영구적으로 느린 엔진에 묶임**. 재검토는 **사건 발생 시에만**(04 §7-1).
  - Terraform 호환성은 **계약이 아니라 부산물** — 보장 안 하되 이유 없이 깨지 않는다(04 §5).
    OpenTofu 고유 기능(`encryption`·`.tofu` 확장자·`language {}`)을 쓸 때만 설계 문서에 이유를 남긴다. CI 없음.
    ⚠️ **`tofu {}` 블록은 존재하지 않는다**(04 §5 정정). 최상위는 `terraform {}`이고, 네이티브 대안은 1.12 `language {}`.
  - `.terraform.lock.hcl` **커밋 대상**(기존 규약 유지, `registry.opentofu.org` 확인).
  - `required_version`은 **모듈마다 다르다**(`02 §2` 하한 대장). 기준선 `>= 1.9.0`(교차변수 validation),
    **`vpc`는 `>= 1.12.0`**(D12 동적 `prevent_destroy`). 근거 없는 상향은 소비자만 배제한다.
- **D12 신설**(`design/10`): `deletion_protection`(기본 `false`) → `aws_vpc`에 동적 `prevent_destroy`.
  **OpenTofu 채택으로 얻는 첫 기능적 이득** — Terraform은 리터럴만 받아 모듈이 소비자에게 위임 불가.
  - 실측(1.12.5): `vpc_enabled=false` + `deletion_protection=true` → **plan 차단**. `false`면 통과.
  - ⚠️ **교차변수 validation은 `validate`가 아니라 `plan`에서 평가된다**(실측). `validate`는 Success로
    통과했다 → **`*.tftest.hcl`이 유일한 검출 지점**. `examples`의 `validate`로는 안 잡힌다.
- **완료**: §6-0 골격 + deepinit · §6-1 설계 승계 · §6-2 1단계 VPC 설계 개정 · MCP 설정 ·
  **엔진 결정 ADR 04**.
  커밋 `95e41dd` → `a6146ca` → `5abcb84` → `22ff67a` → `f5080f2` → `0754aa6` → `860da79` → `30ea306`(중립안, 정정됨)

### ⏭️ 다음 작업 = §6-2 **2단계 — `modules/vpc` 코드 이식**

설계는 확정됐다(`docs/design/10-vpc-module.md` ✅ 인용 가능). **§2 구현 계획의 Task 10.1~10.7을 순서대로** 수행한다.

| Task | 내용 |
|------|------|
| ~~10.1~~ | ✅ **작성 완료**(미커밋) — `modules/vpc/{versions,variables}.tf`. `tofu validate` 통과 |
| 10.2 | `main.tf` — vpc/secondary assoc/subnet/RT/IGW/NAT. ⚠️ subnet에 `depends_on` 필수 |
| 10.3 | `flow-logs.tf` — D11 리소스 4종 |
| 10.4 | `outputs.tf` — §1.4, **null-safe**(D10) |
| 10.5 | `examples/vpc/`(minimal) + `examples/vpc-enterprise/`(9그룹). `versions.tf`에 `aws ~> 6.0` 상한 |
| 10.6 | `modules/vpc/tests/plan.tftest.hcl` — `Name` 태그 assertion 필수 |
| 10.7 | 릴리스 게이트(`02 §4`) + `vpc-v1.0.0` 태그 |

### ⚠️ 커밋 단위 제약 (2026-07-29 실측)

**tflint `terraform_unused_declarations`가 미사용 변수를 exit 2로 잡는다.** 따라서
`variables.tf`(10.1)만으로는 **커밋이 불가능**하다 — 설계 §2가 태스크마다 Commit 라인을 두었지만
실제 커밋 단위는 **"선언한 변수가 전부 소비되는 시점"**이다.
→ **10.1 + 10.2(main.tf) + 10.3(flow-logs.tf)을 한 커밋으로 묶는다.** `--no-verify`는 쓰지 않는다.

- **착수 전 확인**: 사용자가 설계 §1을 승인했는지. 특히 신규 결정 3건 — D10(kill switch 경계),
  D11(Flow Logs 대상 CloudWatch 고정), §1.3(IAM inline policy 약어 미생성).
- 코드 작성 전 `terraform-style-guide` 스킬 로드. 로컬 게이트는 pre-commit이 강제.
- **MCP로 확인 완료한 스키마**(aws 6.56.0): `aws_cloudwatch_log_group.retention_in_days` 유효값 ·
  `aws_flow_log.traffic_type`(ACCEPT/REJECT/ALL, vpc_id 지정 시 필수) — 설계와 일치.
  10.2용 doc ID: `vpc_ipv4_cidr_block_association`=12942950 · `subnet`=12942884 · `nat_gateway`=12942351.

### 문서 인용 규칙 (`docs/README.md` 상태표가 판정 근거)

- `docs/architecture/*` ✅ (**04-engine-decision.md 신규**) · **`docs/design/10-vpc-module.md` ✅ (2026-07-29 개정)**
- `docs/design/{20,30,40}-*.md` ⚠️ **미개정** — 확정 설계로 인용 금지
- `docs/reference/poc-findings.md`는 **외부 스냅샷** — 참조만, 복사·갱신 금지
- `docs/consumer/*` 📦 배포 루트 소유. 모듈 설계 근거로 쓰지 않는다

### MCP (2026-07-29 신설, `.mcp.json` project 스코프)

- `terraform`(registry toolset만) + `aws-docs`. ⏸ **승인 대기 상태** — `claude` 재시작 시 승인 필요.
- `terraform-mcp-server` **v1.1.0**은 `go install` 완료(`~/go/bin/`). CLI를 실행하지 않아 **tofu와 무관하게 동작**(실측 확인).
- ⛔ `TFE_TOKEN`·`ENABLE_TF_OPERATIONS`·`aws-api`는 의도적으로 제외했다 — 되살리지 말 것.
- ⚠️ `get_provider_details`는 단독 호출 불가 — `search_providers`로 `providerDocID`를 먼저 얻는 **2단계**(`CLAUDE.md` 검증 절).

## 미결 항목

- **원격 repo 미생성** → 커밋만 되고 push 불가. 생성 시 ⚠️ **immutable sub claim**
  (2026-07-15 이후 repo는 OIDC `sub`가 숫자 org/repo ID)
- ⚠️ **TFE_TOKEN 폐기·재발급 미처리**(2026-07-28 세션 중 노출) — 보안 사항, 우선순위 높음
- 보존한 `AWSAFTExecution`이 **assume 불가**(입구 Role 삭제로 principal이 unique ID로 치환)
  → 부트스트랩 시 신뢰 정책 교체 필요
- `docs/design/30-gitops-repo.md`의 소유권 재검토(모듈 repo vs consumer)
- 관리형 ArgoCD 채택 여부 재결정(`docs/architecture/01-module-strategy.md` §3.3)
- VPC 설계 열린 항목 6건은 `docs/design/10-vpc-module.md` 말미 참조
  (TGW 리소스 · prefix list 소유권 · IPAM · Flow Logs 대상 확장 · private NAT · IAM policy 약어)
