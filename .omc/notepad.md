# Notepad — iac-module-library

## Priority Context

**OSS IaC 모듈 자산 SSOT** — 2026-07-29 신설. 로컬 전용(원격 repo 미생성 → `git push` 불가).

- **배경**: `terraform-enterprise-poc`가 2026-07-28 **동결(졸업)**. 결정 전문은 그 repo의
  `docs/architecture/05-oss-asset-repo-decision.md`(D-OSS-STACK).
  ⛔ **PoC repo의 모듈·설계를 고치지 않는다** — 양쪽 개발은 곧 drift다.
- **⚖️ 엔진 중립**(2026-07-29 신규 결정, `docs/architecture/04-engine-neutrality.md` = **D-ENGINE-NEUTRAL**):
  모듈 코드는 **OpenTofu·Terraform 양쪽에서 동작**한다. 엔진 선택은 **배포 루트의 결정**이다.
  - D-OSS-STACK(PoC repo `05`)의 **엔진 축을 개정**했다. PoC는 동결이라 그쪽에 개정 표시가 없으니
    **05를 인용할 때 04를 함께 읽지 않으면 "이 repo는 OpenTofu 전용"이라는 낡은 결론을 쓰게 된다.**
  - 근거: ① HashiCorp FAQ가 **컨설팅 사용을 명시적 허용**(라이선스는 걸림돌이 아님)
    ② 고객 비용 장벽은 CLI가 아니라 **HCP/TFE 구독** — GitHub Actions+S3로 이미 해소
    ③ lock은 remote module을 추적하지 않아 **모듈이 소비자의 엔진을 강제하지 않는다**
  - **로컬/hook = `tofu`**(제약이 빡빡한 1차 방어선). **중립성 실증 = CI의 `terraform` 잡**.
    로컬 통과 ≠ 중립성 통과.
  - ⛔ **`.terraform.lock.hcl` 커밋 금지**(04 §4) — `.gitignore` + `pre-commit` **2중 차단, 실측 검증됨**.
    상한 방어는 **예제의 `~> 6.0`**이 맡는다(모듈은 하한만).
  - 중립성 규칙 N1~N7(04 §5) 대표: `required_version` 하한을 **1.12 위로 올리지 말 것** ·
    `.tofu` 확장자/`tofu {}`/`encryption` 블록 금지 · provider source에 **registry 호스트 금지**.
- **완료**: §6-0 골격 + deepinit · §6-1 설계 승계 · §6-2 1단계 VPC 설계 개정 · MCP 설정 ·
  **엔진 중립 전환(ADR 04 + 문서 11개 개정)**.
  커밋 `95e41dd` → `a6146ca` → `5abcb84` → `22ff67a` → `f5080f2` → `0754aa6` → `860da79` → **(엔진 중립: 미커밋)**

### ⏭️ 다음 작업 = §6-2 **2단계 — `modules/vpc` 코드 이식**

설계는 확정됐다(`docs/design/10-vpc-module.md` ✅ 인용 가능). **§2 구현 계획의 Task 10.1~10.7을 순서대로** 수행한다.

| Task | 내용 |
|------|------|
| 10.1 | `versions.tf` + `variables.tf` — §1.2 계약, validation. ⚠️ `required_version` **상한 금지** |
| 10.2 | `main.tf` — vpc/secondary assoc/subnet/RT/IGW/NAT. ⚠️ subnet에 `depends_on` 필수 |
| 10.3 | `flow-logs.tf` — D11 리소스 4종 |
| 10.4 | `outputs.tf` — §1.4, **null-safe**(D10) |
| 10.5 | `examples/vpc/`(minimal) + `examples/vpc-enterprise/`(9그룹). **`versions.tf`에 `aws ~> 6.0` 상한 필수** |
| 10.6 | `modules/vpc/tests/plan.tftest.hcl` — `Name` 태그 assertion 필수 |
| 10.7 | 릴리스 게이트(`02 §4`) + **두 엔진 test 통과 실증** + `vpc-v1.0.0` 태그 |

- **착수 전 확인**: 사용자가 설계 §1을 승인했는지. 특히 신규 결정 3건 — D10(kill switch 경계),
  D11(Flow Logs 대상 CloudWatch 고정), §1.3(IAM inline policy 약어 미생성).
  ※ 엔진 중립(D-ENGINE-NEUTRAL)은 **2026-07-29 사용자 승인 완료** — 재확인 불필요.
- 코드 작성 전 `terraform-style-guide` 스킬 로드. 각 Task 후 로컬 게이트(pre-commit이 강제).
- VPC는 순수 AWS 리소스라 **엔진 고유 문법을 쓸 이유가 없다** — 설계 판단은 04 이전과 동일하다.

### 문서 인용 규칙 (`docs/README.md` 상태표가 판정 근거)

- `docs/architecture/*` ✅ (**04-engine-neutrality.md 신규**) · **`docs/design/10-vpc-module.md` ✅ (2026-07-29 개정)**
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
