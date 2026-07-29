# Notepad — iac-module-library

## Priority Context

**OSS IaC 모듈 자산 SSOT** — 2026-07-29 신설. 원격: `skax-ca/iac-module-library`(**private**, 무료 org).
`origin`=`https://github.com/skax-ca/iac-module-library.git`, `main` 추적. push 정상.
- **org/팀 구조**: org `skax-ca`(무료) → Team **`iac`**(slug=`iac`, id=18738969, privacy=closed)에
  이 repo가 `maintain` 권한으로 소속. 향후 IaC repo는 `iac-` 프리픽스 + 아래 명령으로 팀에 붙인다:
  `gh api --method PUT orgs/skax-ca/teams/iac/repos/skax-ca/<repo> -f permission='maintain'`.
  ⚠️ **GitHub엔 org>프로젝트>repo 중첩이 없다** — "프로젝트 묶음"의 실체는 Team + 네이밍 프리픽스다.
- ⚠️ `gh` 토큰(silverte)에 **`workflow` 스코프 추가 완료** — `.github/workflows/` push에 필수.

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
  커밋 `95e41dd` → `a6146ca` → `5abcb84` → `22ff67a` → `f5080f2` → `0754aa6` → `860da79`
  → `30ea306`(중립안 — **정정됨**) → `86cc91a`(D-ENGINE 확정) → `e89742d`(D12) → `1bd6641`(MCP 교체)

### 🔴 세션 시작 시 가장 먼저 볼 것 (2026-07-29 종료 시점)

1. **`modules/vpc/`가 untracked 상태로 남아 있다** — `versions.tf`·`variables.tf` 작성 완료,
   `tofu fmt`·`validate` 통과. 커밋하지 **못한** 이유는 아래 "커밋 단위 제약"이다. 재작성하지 말 것.
2. **MCP가 `terraform` → `opentofu`로 교체됐다**(`1bd6641`). 재시작 후 **project 스코프 승인 필요**.
   툴 이름이 바뀌었다 — `mcp__opentofu__get-resource-docs`(단독 호출, 2단계 아님).
3. ✅ **원격 repo 생성·push 완료**(2026-07-29): `skax-ca/iac-module-library`(private).
   `gh` 토큰에 **`workflow` 스코프 추가됨**(`.github/workflows/` 파일 push에 필수).

### ⏭️ 다음 작업 = §6-2 **2단계 — `modules/vpc` 코드 이식**

설계는 확정됐다(`docs/design/10-vpc-module.md` ✅ 인용 가능). **§2 구현 계획의 Task 10.1~10.7을 순서대로** 수행한다.

| Task | 내용 |
|------|------|
| ~~10.1~~ | ✅ **작성 완료 · untracked** — `modules/vpc/{versions,variables}.tf`. `fmt`·`validate` 통과. `required_version >= 1.12.0`(D12), `deletion_protection` 포함 |
| **10.2** | ⏭️ **여기서 시작.** `main.tf` — vpc/secondary assoc/subnet/RT/IGW/NAT. ⚠️ subnet에 `depends_on` 필수 · `aws_vpc`에 `lifecycle { prevent_destroy = var.deletion_protection }`(D12) |
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

- **착수 전 확인**: 사용자가 설계 §1을 승인했는지. 특히 D10(kill switch 경계),
  D11(Flow Logs 대상 CloudWatch 고정), §1.3(IAM inline policy 약어 미생성).
  ※ D12(삭제 보호)와 D-ENGINE(OpenTofu 단독)은 **2026-07-29 승인 완료** — 재확인 불필요.
- 코드 작성 전 `terraform-style-guide` 스킬 로드. 로컬 게이트는 pre-commit이 강제.
- **스키마 확인 완료**(aws 6.56.0): `aws_cloudwatch_log_group.retention_in_days` 유효값 23종 ·
  `aws_flow_log.traffic_type`(ACCEPT/REJECT/ALL, `vpc_id` 지정 시 **필수**) — 설계와 일치.
  ⚠️ 구 doc ID(12942950 등)는 **교체된 MCP에서 무효**다. 신규 서버는
  `get-resource-docs(namespace="hashicorp", name="aws", resource="subnet")` 형태로 **단독 호출**한다.
- **10.2에서 스키마 확인이 필요한 리소스**: `aws_vpc`(확인 완료 — 8054자) · `aws_subnet` ·
  `aws_vpc_ipv4_cidr_block_association` · `aws_route_table` · `aws_route` ·
  `aws_route_table_association` · `aws_internet_gateway` · `aws_nat_gateway` · `aws_eip` ·
  `data.aws_availability_zones`. **추정 금지**(`CLAUDE.md` 검증 절).

### 문서 인용 규칙 (`docs/README.md` 상태표가 판정 근거)

- `docs/architecture/*` ✅ (**04-engine-decision.md 신규**) · **`docs/design/10-vpc-module.md` ✅ (2026-07-29 개정)**
- `docs/design/{20,30,40}-*.md` ⚠️ **미개정** — 확정 설계로 인용 금지
- `docs/reference/poc-findings.md`는 **외부 스냅샷** — 참조만, 복사·갱신 금지
- `docs/consumer/*` 📦 배포 루트 소유. 모듈 설계 근거로 쓰지 않는다

### MCP (`.mcp.json` project 스코프 — 2026-07-29 **`terraform` → `opentofu` 교체**)

- **`opentofu`**([공식](https://github.com/opentofu/opentofu-mcp-server), `npx -y @opentofu/opentofu-mcp-server`) + `aws-docs`.
  ⏸ 교체 후 **`claude` 재시작 + 승인 필요**.
- 교체 이유: ① `get-resource-docs`가 **단독 호출** — 기존 `terraform-mcp-server`의 2단계 제약 소멸
  ② **`registry.opentofu.org`**(우리가 실제로 쓰는 registry)를 조회 ③ `go install` 불필요.
- ⚠️ **로컬 npx 판은 0.1.x / 툴 5종**, hosted(`mcp.opentofu.org`)는 **1.0.1 / 7종**(실측).
  로컬에는 `get-provider-versions`가 **없다** → 버전 존재 확인은 표준 API로:
  `curl -s https://registry.opentofu.org/v1/providers/<ns>/<name>/versions` (실측 동작 확인).
- ⛔ TFE/HCP 연동 서버·`aws-api`는 의도적으로 제외했다 — 되살리지 말 것.
- 구 `terraform-mcp-server` v1.1.0 바이너리는 `~/go/bin/`에 남아 있다(미사용, 삭제해도 무방).

## 미결 항목

- ~~원격 repo 미생성~~ ✅ **해결**: `skax-ca/iac-module-library`(private) 생성·push 완료(2026-07-29).
  ⚠️ **immutable sub claim 주의**: 이 repo는 2026-07-15 이후 생성 → OIDC `sub`가 숫자 org/repo ID다.
  소비자 repo 신뢰 정책 작성 전 실제 토큰 `sub` 확인 필수(`repo:<org>@<org_id>/<repo>@<repo_id>:...`).
- ⚠️ **TFE_TOKEN 폐기·재발급 미처리**(2026-07-28 세션 중 노출) — 보안 사항, 우선순위 높음
- 보존한 `AWSAFTExecution`이 **assume 불가**(입구 Role 삭제로 principal이 unique ID로 치환)
  → 부트스트랩 시 신뢰 정책 교체 필요
- `docs/design/30-gitops-repo.md`의 소유권 재검토(모듈 repo vs consumer)
- 관리형 ArgoCD 채택 여부 재결정(`docs/architecture/01-module-strategy.md` §3.3)
- VPC 설계 열린 항목 6건은 `docs/design/10-vpc-module.md` 말미 참조
  (TGW 리소스 · prefix list 소유권 · IPAM · Flow Logs 대상 확장 · private NAT · IAM policy 약어)
