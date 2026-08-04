# iac-module-library

Cloud Architect 팀의 **재사용 IaC 모듈 자산 라이브러리**.
고객사가 구독 라이선스 없이 바로 착수할 수 있어야 한다.

| | |
|---|---|
| **스택** | **OpenTofu**(MPL-2.0) · GitHub Actions(OIDC) · S3 backend(`use_lockfile`) · OPA/Conftest |
| **상태** | 🚧 **부트스트랩** — 설계 승계 완료, 모듈 코드 착수 전 |
| **규칙** | [`CLAUDE.md`](CLAUDE.md) — 설계 우선, 네이밍·태깅, 모듈 전략, 검증 게이트 |

---

## 왜 이 구성인가

**고객사의 비용 장벽은 CLI가 아니라 HCP Terraform/TFE 구독에 있다.** 두 축은 독립적이다:

| 축 | 선택지 | 비용 |
|---|---|---|
| 엔진(CLI) | Terraform ↔ OpenTofu | 둘 다 $0 |
| 실행 플랫폼 | HCP/TFE ↔ **GitHub Actions + S3** | 여기가 전부 |

플랫폼을 GitHub Actions + S3로 옮긴 것만으로 비용 목표는 달성된다.

**라이선스도 걸림돌이 아니다.** [HashiCorp 공식 FAQ](https://www.hashicorp.com/en/license-faq)는
*"고객이 자기 프로덕션 환경에서 BSL 제품을 쓰는 것을 컨설턴트가 돕는 행위"* 를 **명시적으로 허용**한다.
금지되는 것은 Terraform과 경쟁하는 multi-tenant 서비스로 제공하는 경우뿐이다.

그럼에도 **OpenTofu 단독**을 쓰는 이유는 준수가 아니라 운영 판단이다 — 이 repo의 hook·문서·설계가
이미 `tofu` 기준이라 **리워크가 0**이고, OSI 승인 라이선스라 공공·금융 조달에서 **설명할 일이 없다**.
두 엔진 동시 지원은 **실측 비용을 근거로 기각**했다.

> 결정 전문: [`docs/architecture/04-engine-decision.md`](docs/architecture/04-engine-decision.md) (D-ENGINE)
> — 두 엔진 지원 기각 근거(§3)와 재검토 조건(§7-1) 포함.

## repo 관계

```
iac-module-library  (이 repo — 모듈·설계 SSOT)
   │  git tag 소싱 (vpc-v0.3.0 …)
   ▼
<project>-infra × N  (프로젝트/고객별 배포 루트)

terraform-enterprise-poc  (동결 스냅샷 — TFC 실증·TFE 제안서 레퍼런스, 수정 금지)
```

## 구조

```
modules/     # 재사용 모듈 (컴포넌트별 semver 태그)
examples/    # 모듈별 최소 예제 = tofu test 대상. provider 상한(~> 6.0)의 소유자
docs/        # architecture(전략·규약) · design(모듈) · reference · consumer
.githooks/   # pre-commit(fmt·tflint·trivy) · pre-push(tofu test)
```

## 사용법 (프로젝트 repo에서)

```hcl
module "vpc" {
  source = "git::https://github.com/<org>/iac-module-library.git//modules/vpc?ref=vpc-v0.3.0"

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
| `opentofu` | provider/모듈 스키마 조회 — `CLAUDE.md` 검증 절의 "추정 금지" 근거 | **없음**(`npx`가 자동 설치) |
| `aws-docs` | AWS 공식 문서 조회 (설계 근거 소스) | `uvx`가 자동 설치 |

- **[OpenTofu 공식 MCP 서버](https://github.com/opentofu/opentofu-mcp-server)**(`@opentofu/opentofu-mcp-server`)를 쓴다.
  인증 토큰이 필요 없고, **우리가 실제로 `tofu init`으로 조회하는 `registry.opentofu.org`**를 본다.
- `get-resource-docs`는 `namespace`·`name`·`resource`만으로 **단독 호출**된다 — 이전에 쓰던
  `terraform-mcp-server`의 2단계 호출(`search` → `details`) 제약이 없다.
- ⚠️ **로컬 npx 판(0.1.x)에는 버전 조회 툴이 없다**(hosted `mcp.opentofu.org` 1.0.x에만 있다).
  버전 존재 확인은 표준 registry API로 한다 — `CLAUDE.md` 검증 절 참조.
- ⛔ **TFE/HCP Terraform 연동 서버는 넣지 않는다.** 이 repo는 TFC를 졸업했고(D-OSS-STACK),
  해당 toolset은 워크스페이스·run 조작용이라 여기에 대상이 없다.

## 다음 작업

부트스트랩 순서는 D-OSS-STACK §6을 따른다(엔진 축 근거는 [04](docs/architecture/04-engine-decision.md)로 교체).

- [x] 0 · repo 신설 + `deepinit`
- [x] 1 · 설계 승계·개정 — PoC의 01~04 이식, TFC 종속부 재작성, **엔진 결정 ADR(04) 신규 작성**
- [ ] 2 · 모듈 이식 + 재사용 파라미터화(`workload` 하드코딩 제거) + `tofu test` 전환
- [ ] 3 · 모듈 검증 CI (fmt·validate·tflint·trivy·`tofu test`)
- [ ] 4 · 첫 프로젝트 repo로 End-to-End 검증(실행 기반: S3 state 버킷, GitHub OIDC IdP, 워크플로)
- [ ] 5 · 모듈 `<component>-v1.0.0` 태그
