# iac-module-library

Cloud Architect 팀의 **재사용 IaC 모듈 자산 라이브러리**.
전 구성요소가 OSI 승인 라이선스인 OSS 스택으로 구성한다 — 고객사가 구독 라이선스 없이 바로 착수할 수 있어야 한다.

| | |
|---|---|
| **스택** | OpenTofu(MPL-2.0) · GitHub Actions(OIDC) · S3 backend(`use_lockfile`) · OPA/Conftest |
| **상태** | 🚧 **부트스트랩** — 골격만 존재. 설계 승계가 첫 작업 |
| **규칙** | [`CLAUDE.md`](CLAUDE.md) — 설계 우선, 네이밍·태깅, 모듈 전략, 검증 게이트 |

---

## 왜 OSS 스택인가

HCP Terraform/TFE는 구독 비용이 고객사 채택의 장벽이 된다. 이 라이브러리는 **라이선스 비용 0으로
시작 가능한** 레퍼런스를 목표로 한다.

확인된 사실: 이 스택에서 BUSL 라이선스는 `terraform` 바이너리 **하나뿐**이었다 —
provider(aws·awscc·tfe)는 전부 MPL-2.0, `terraform-aws-modules/eks`는 Apache-2.0.
따라서 CLI를 OpenTofu로 바꾸는 것만으로 **전 구성요소가 OSI 승인 라이선스**가 된다.

> 결정 전문: `terraform-enterprise-poc/docs/architecture/05-oss-asset-repo-decision.md` (D-OSS-STACK)

## repo 관계

```
iac-module-library  (이 repo — 모듈·설계 SSOT)
   │  git tag 소싱 (vpc-v1.0.0 …)
   ▼
<project>-infra × N  (프로젝트/고객별 배포 루트)

terraform-enterprise-poc  (동결 스냅샷 — TFC 실증·TFE 제안서 레퍼런스, 수정 금지)
```

## 구조

```
modules/     # 재사용 모듈 (컴포넌트별 semver 태그)
examples/    # 모듈별 최소 예제 = tofu test 대상
docs/        # architecture(전략·규약) · design(모듈) · reference · runbooks
.githooks/   # pre-commit(fmt·tflint·trivy) · pre-push(tofu test)
```

## 사용법 (프로젝트 repo에서)

```hcl
module "vpc" {
  source = "git::https://github.com/<org>/iac-module-library.git//modules/vpc?ref=vpc-v1.0.0"

  naming = { workload = "acme", env = "dev", region_code = "an2" }
  # ...
}
```

## 개발 준비

```bash
brew install opentofu trivy
git config core.hooksPath .githooks          # clone마다 1회 — 로컬 게이트 활성화
GITHUB_TOKEN=$(gh auth token) tflint --init
```

### MCP 서버 (AI 에이전트로 작업할 때)

`.mcp.json`(project 스코프)에 두 서버가 등록돼 있다. **clone 후 첫 실행 시 승인이 필요**하다.

| 서버 | 용도 | 준비 |
|------|------|------|
| `terraform` | provider/모듈 스키마 조회 — `CLAUDE.md` 검증 절이 요구하는 "추정 금지" 근거 | 아래 `go install` 1회 |
| `aws-docs` | AWS 공식 문서 조회 (설계 근거 소스) | `uvx`가 자동 설치 |

```bash
go install github.com/hashicorp/terraform-mcp-server/cmd/terraform-mcp-server@v1.1.0
# → ${HOME}/go/bin/terraform-mcp-server (.mcp.json이 이 경로를 참조)
```

- `terraform` 서버는 **`registry` toolset만** 켠다(`--toolsets=registry`). 이름과 달리 로컬 CLI를
  실행하지 않고 Terraform Registry API만 조회하므로 **OpenTofu 사용에 지장이 없다.**
- ⛔ **TFE/HCP Terraform 연동(`TFE_TOKEN`·`ENABLE_TF_OPERATIONS`)은 넣지 않는다.** 이 repo는
  TFC를 졸업했고(D-OSS-STACK), 해당 toolset은 워크스페이스·run 조작용이라 여기에 대상이 없다.

## 다음 작업

부트스트랩 순서는 D-OSS-STACK §6을 따른다.

- [ ] 0 · repo 신설 + `deepinit`
- [ ] 1 · 설계 승계·개정 — PoC의 01~04를 이식하되 TFC 종속부(02 §4·03 §5)는 재작성
- [ ] 2 · 모듈 이식 + 재사용 파라미터화(`workload` 하드코딩 제거) + `tofu test` 전환
- [ ] 3 · 실행 기반 — S3 state 버킷, GitHub OIDC IdP, 워크플로
- [ ] 4 · 첫 프로젝트 repo로 End-to-End 검증
- [ ] 5 · 모듈 `v1.0.0` 태그
