# iac-module-library

Cloud Architect 팀의 **재사용 IaC 모듈 자산 라이브러리**.
고객사가 구독 라이선스 없이 바로 착수할 수 있어야 한다.

| | |
|---|---|
| **엔진** | ⚖️ **중립** — OpenTofu와 Terraform 양쪽에서 동작. 선택은 배포 루트가 한다 |
| **실행 기반** | GitHub Actions(OIDC) · S3 backend(`use_lockfile`) · OPA/Conftest — 전부 OSS |
| **상태** | 🚧 **부트스트랩** — 설계 승계 완료, 모듈 코드 착수 전 |
| **규칙** | [`CLAUDE.md`](CLAUDE.md) — 설계 우선, 엔진 중립, 네이밍·태깅, 검증 게이트 |

---

## 왜 이 구성인가

**고객사의 비용 장벽은 CLI가 아니라 HCP Terraform/TFE 구독에 있다.** 두 축은 독립적이다:

| 축 | 선택지 | 비용 |
|---|---|---|
| 엔진(CLI) | Terraform ↔ OpenTofu | 둘 다 $0 |
| 실행 플랫폼 | HCP/TFE ↔ **GitHub Actions + S3** | 여기가 전부 |

플랫폼을 GitHub Actions + S3로 옮긴 것만으로 목표는 달성된다. 그래서 **엔진은 고정하지 않는다** —
고정하면 Terraform으로 표준화된 고객에게 이 자산을 전달할 수 없어 재사용 범위만 줄어든다.

라이선스도 걸림돌이 아니다. [HashiCorp 공식 FAQ](https://www.hashicorp.com/en/license-faq)는
*"고객이 자기 프로덕션 환경에서 BSL 제품을 쓰는 것을 컨설턴트가 돕는 행위"* 를 **명시적으로 허용**한다.
금지되는 것은 Terraform과 경쟁하는 multi-tenant 서비스로 제공하는 경우뿐이다.

> 결정 전문: [`docs/architecture/04-engine-neutrality.md`](docs/architecture/04-engine-neutrality.md) (D-ENGINE-NEUTRAL)
> — `terraform-enterprise-poc`의 D-OSS-STACK 중 **엔진 축을 개정**한 문서다. PoC는 동결이라 그쪽에 개정 표시가 없다.

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
modules/     # 재사용 모듈 (컴포넌트별 semver 태그). 엔진 중립 HCL
examples/    # 모듈별 최소 예제 = 테스트 루트. provider 상한(~> 6.0)의 소유자
docs/        # architecture(전략·규약) · design(모듈) · reference · consumer
.githooks/   # pre-commit(fmt·tflint·trivy) · pre-push(tofu test)
```

> 로컬 hook은 `tofu`만 돌린다(두 엔진 중 제약이 빡빡한 쪽 = 1차 방어선).
> **중립성 실증은 CI의 `terraform` 잡**이 담당한다 — 두 잡이 서로 다른 위반을 잡으므로 둘 다 필요하다.

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
brew install opentofu trivy                  # 로컬 게이트는 tofu 기준
brew install terraform                        # 선택 — 중립성을 로컬에서 재현할 때
git config core.hooksPath .githooks          # clone마다 1회 — 로컬 게이트 활성화
GITHUB_TOKEN=$(gh auth token) tflint --init
```

> ⚠️ 같은 디렉토리에서 두 엔진을 번갈아 쓰면 `.terraform/`·lock 캐시가 충돌한다(신뢰 루트가 다르다).
> 전환 시 `rm -rf .terraform .terraform.lock.hcl` 후 재init한다. `.terraform.lock.hcl`은 **커밋 대상이 아니다.**

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
  실행하지 않고 Registry API만 조회하므로 **어느 엔진을 쓰든 무관하다.**
  provider 스키마는 두 registry가 동일한 upstream을 서빙하므로 조회 결과도 엔진 중립이다.
- ⛔ **TFE/HCP Terraform 연동(`TFE_TOKEN`·`ENABLE_TF_OPERATIONS`)은 넣지 않는다.** 이 repo는
  TFC를 졸업했고(D-OSS-STACK), 해당 toolset은 워크스페이스·run 조작용이라 여기에 대상이 없다.

## 다음 작업

부트스트랩 순서는 D-OSS-STACK §6을 따른다(엔진 축은 [04](docs/architecture/04-engine-neutrality.md)가 개정).

- [x] 0 · repo 신설 + `deepinit`
- [x] 1 · 설계 승계·개정 — PoC의 01~04 이식, TFC 종속부 재작성, **엔진 중립 ADR(04) 신규 작성**
- [ ] 2 · 모듈 이식 + 재사용 파라미터화(`workload` 하드코딩 제거) + 두 엔진 `test` 통과
- [ ] 3 · 모듈 검증 CI — `gate-tofu` + `gate-terraform` + `lint` 3잡
- [ ] 4 · 첫 프로젝트 repo로 End-to-End 검증(실행 기반: S3 state 버킷, GitHub OIDC IdP, 워크플로)
- [ ] 5 · 모듈 `<component>-v1.0.0` 태그
