---
paths:
  - "**/*.tf"
---

# `.tf` 작업 규칙

`CLAUDE.md`의 리포 전역 규칙(설계·검토 우선, 브랜치·PR, 버전 정책)을 전제한다. 여기는 `.tf` 파일을
쓰거나 검토할 때만 적용되는 네이밍·아키텍처·검증·설계 원칙을 갖는다.

## 리소스 네이밍 & 태깅 규칙 (필수 준수)

네이밍·태깅 SSOT는 `docs/conventions.md` §2(`Name` 태그 포맷 + 공통/AWS/Azure 3층 강제 방식)다.
여기서 중복 서술하지 않는다. `.tf` 작성 시 그 절을 그대로 따른다 — provider별 태그 주입 방식
(AWS `default_tags` vs Azure 리소스별 `tags` 연동)이 다르므로, 새 provider 모듈을 쓸 때는
공통 절뿐 아니라 해당 provider 절까지 확인한다.

> ⚠️ **재사용 자산의 요건**(같은 절 공통 5번이 소유): workload code·계정/구독 ID·리전을
> **하드코딩하지 않는다.** PoC에서 승계할 때 `workload = "poc"` 같은 고정값을 반드시 걷어낸다.

## 변수 계약: `nullable`

새 `variable` 선언 시 판정 기준(근거는 `docs/decisions.md`의 「변수 계약 (nullable)」이 소유,
여기서 중복 서술하지 않는다):

- default가 없는 **필수** 변수, 또는 default가 **`null`이 아닌** 변수 → `nullable = false`를 추가한다.
- default 자체가 **`null`**이고 그 `null`이 "값 없음"이 아니라 의도된 값(자연 기본 동작·옵션을
  끈 상태)인 변수 → 적용하지 않는다. `nullable = false`는 명시적 `null`을 default로 대체하는
  기능이라, default가 이미 `null`이면 대체해도 결과가 다시 `null`이라 모순이거나 무의미하다.

---

## 아키텍처 & 모듈 규칙

- **모듈 전략**: 계층형 하이브리드. 안정·단순 리소스(VPC/S3/SG)는 스크래치 얇은 모듈, 고속 churn·
  지식밀도 높은 리소스(EKS)는 커뮤니티 모듈을 **wrapper(facade)**로 감싼다.
- **facade 원칙**: 소비자는 안정적 내부 인터페이스만 쓰고, upstream 변수 rename은 wrapper 내부에서만 번역한다.
- **semver 거버넌스 계약**: upstream 파괴적 변경을 인터페이스 유지로 흡수 = 내부 **마이너**(소비자 무영향),
  숨길 수 없으면 내부 **메이저**(의도적 마이그레이션). upstream cadence와 소비자 cadence를 분리한다.
- **버전 핀**: OpenTofu **`>= 1.12.0` 전 모듈 통일**(실행도 1.12.x). 모듈별 하한 대장은 두지 않는다.
  *"근거로만 올린다"* 는 **1.13 이상**에만 적용된다(근거는 `docs/decisions.md`).
  aws `~> 6.0`(예제·프로젝트 루트)/`>= 6.0`(모듈),
  커뮤니티 모듈은 정확 핀. `.terraform.lock.hcl` 커밋 필수.
  ⚠️ registry 주소가 `registry.opentofu.org/...`인지 확인(PoC의 lock을 복사하면 안 된다).
- **워크스페이스 간 데이터**: **결정적 네이밍 → `data` 조회**(AWS `data.aws_*`, Azure `data.azurerm_*`)
  순으로 느슨하게 결합. `terraform_remote_state`·원격 state 직접 참조는 지양한다.
- **네트워크 보안 규칙은 별도 리소스로 만든다.** inline 블록과 혼용 금지. AWS는
  `aws_vpc_security_group_ingress_rule`/`_egress_rule`(vs `aws_security_group`의 inline
  `ingress`/`egress`), Azure는 `azurerm_network_security_rule`(vs `azurerm_network_security_group`의
  inline `security_rule`). 두 provider 모두 inline과 별도 리소스 병용을 규칙 덮어쓰기 충돌로
  공식 문서가 경고한다.

---

## 검증

### 코드 작성 전
- **리소스 스키마**: 새 리소스/인자 사용 전 `mcp__opentofu__get-resource-docs`로 확인(추정 금지).
  인자는 `namespace`·`name`·`resource` 3개이고 **단독 호출된다**(예: `hashicorp`/`aws`/`vpc`).
  data source는 `get-datasource-docs`(`dataSource` 인자). 이름을 모르면 `search-opentofu-registry` 먼저.
- **커뮤니티 모듈 wrapping**: `mcp__opentofu__get_module_details`(`namespace`·`name`·`target`)로
  실제 upstream 변수/출력명 확인 후 작성.
- **버전 존재 확인**: 핀을 걸기 전에 **`tofu`가 실제로 조회하는 registry**에 그 버전이 있는지 본다.
  로컬 npx 판(0.1.x)에는 버전 조회 툴이 없으므로 표준 registry API를 쓴다. 실측으로 동작 확인:
  `curl -s https://registry.opentofu.org/v1/providers/<ns>/<name>/versions`
  (모듈은 `.../v1/modules/<ns>/<name>/<target>/versions`)
- **MCP 미가용 시 대체 경로**: provider 저장소의 문서 원문을 직접 읽는다:
  `https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/main/website/docs/r/<resource>.html.markdown`
  (registry 웹페이지는 SPA라 WebFetch로 읽히지 않는다). **추정으로 대체하지 않는다.**
- **스타일**: `.tf` 작성 시 이 파일의 나머지 절이 HCL 컨벤션을 갖는다(OpenTofu에도 동일 적용).

### 코드 변경 후 (로컬 CLI 게이트, git hook으로 강제)
```
pre-commit: tofu fmt -recursive -check → tflint --recursive → trivy config .
pre-push (코드가 바뀐 모듈만): tofu test
```
- ⚠️ **tflint의 `terraform_unused_declarations`는 선언만 하고 쓰지 않은 변수를 exit 2로 잡는다.**
  따라서 `variables.tf`만 있고 이를 소비하는 `main.tf`가 없는 상태는 **커밋할 수 없다**.
  설계 문서가 태스크마다 Commit 라인을 두더라도 실제 커밋 단위는 "변수가 전부 소비되는 시점"이다.
- **git hook 강제**: `.githooks/pre-commit`(fmt·tflint·trivy)와 `.githooks/pre-push`(push 범위에서 `.tf`·`.tftpl`·`.tftest.hcl`·lock이 바뀐 모듈만
  `tofu test`, `examples/`·README 변경은 제외).
  clone마다 1회 활성화: `git config core.hooksPath .githooks`
  우회(`--no-verify`)는 긴급 시에만, 사유를 커밋 메시지에 명시한다.
- tflint: `.tflint.hcl`(terraform recommended preset + aws ruleset 정확 핀). 설치:
  `brew install trivy opentofu` + tflint는 GitHub 릴리스 바이너리, 이후 `GITHUB_TOKEN=$(gh auth token) tflint --init`.
- trivy 예외는 `.trivyignore`로만. 항목마다 사유·백로그 링크 필수, 무단 추가 금지.
- **모듈 CI**: `.github/workflows/verify.yml`이 **게이트 7개**를 검증한다.
  ① `tofu fmt` ② `tflint --recursive` ③ `trivy config` ④ modules: `init -lockfile=readonly`
  + `validate` + `test`(tests 없는 모듈은 **실패**) ⑤ examples: `init -lockfile=readonly` + `validate`
  ⑥ **lock registry 검사**(`registry.terraform.io` 섞이면 실패, `docs/conventions.md`)
  ⑦ **terraform-docs drift 검사**(모듈 `README.md`가 `.tf` 변경을 반영했는지).
  - ⚠️ **CI와 로컬 훅의 도구 버전·플래그를 일치시킨다.** 어긋나면 "로컬은 통과했는데 CI가 막는다"가
    생기고, 그러면 사람이 CI를 신뢰하지 않게 된다. 정확한 버전은 `.github/workflows/verify.yml`과
    `.tflint.hcl`에서 확인한다(여기 하드코딩하지 않는다. 둘이 갈리면 이 파일이 최신이 아니라는 뜻이다).
    **한쪽을 바꾸면 다른 쪽도 바꾼다.** trivy는 액션 대신 **바이너리를 설치해 pre-commit과 같은
    명령을 그대로** 실행한다.
  - 프로젝트 repo와 달리 이 repo는 배포하지 않으므로 **apply 워크플로가 없다**(누락이 아니라 설계).
  - CI는 읽기 전용이라 `cancel-in-progress: true`다. ⚠️ 소비 repo의 **apply**는 반대여야 한다.
    apply 중단은 state 잠금·부분 적용을 남긴다. 이 블록을 그대로 복사하지 말 것.

---

## 작업 원칙

**이 repo에서 뜻이 달라지는 것은 번역해 뒀다**: 이 repo의 산출물은 **고객사에 배송되는 계약**이라,
일반 애플리케이션 규칙이 그대로 맞지 않는다. *"관심사를 분리한다"·"검증된 라이브러리를 쓴다"* 는
여기 다시 적지 않는다. 위 **「아키텍처 & 모듈 규칙」**(facade 원칙·계층형 하이브리드·semver 거버넌스)이
이미 소유한다.

### 발명하기 전에 찾는다: "그 기능은 없다"고 단정하지 않는다

- 해결책을 짜기 전에 **upstream 모듈·provider·AWS 공식이 그 문제를 이미 어떻게 푸는지** 본다.
  위 「검증」의 MCP 확인 절차가 이 원칙의 이행 장치다.
- 🔑 **facade 에서 특히 자주 틀리는 형태**: "upstream이 지원하지 않는다"가 아니라
  **wrapper 가 그 인자를 안 넘기고 있을 뿐**인 경우다. facade가 통과시키지 않는 upstream 인자를
  "미지원"으로 단정하고 우회(launch template 등)를 짜면 **facade 가 upstream 을 가리는 부채**가 된다.
  → `.terraform/modules/` 실물 소스를 연다. 문서보다 소스가 빠르고 정확할 때가 많다.

### 죽은 경로를 남기지 않는다: 단, 계약 파괴는 semver 로 드러낸다

- 쓰이지 않게 된 코드·변수·분기는 **삭제한다.** 호환 레이어를 덧대 두 경로를 유지하지 않는다.
- 🔴 **"하위 호환을 유지하지 마라"를 모듈 계약에 그대로 적용하지 않는다.** 이 repo의 출력은
  고객사가 **정확 태그로 핀해서 쓰는 계약**이다. 계약 변경은 숨기는 것이 아니라
  **semver 로 드러내는 것**이 규약이다(위 semver 거버넌스). *호환 레이어는 덧대지 않되,
  깨는 변경은 메이저로 표시한다*. 둘은 모순이 아니다.
- 🔴 **릴리스된 태그를 덮어쓰지 않는다.** 예외는 **소비자가 0일 때뿐**이다. 한 번이라도
  apply된 뒤에는 마이너를 컷한다. `0.y.z` 구간에서는 이 예외 자체가 필요할 일이 애초에 없다:
  다음 마이너를 내면 되기 때문이다.

### 지금 요구를 채우는 가장 단순한 형태로 만든다

- 추측에 근거한 변수·추상화·간접 계층을 만들지 않는다. **필요해지면 그때 연다.**
- ⚠️ **kill switch·삭제 보호·교차변수 validation 은 "추측 대비"가 아니다.** 재사용 자산의
  **현재 요구사항**이다. 단순화의 이름으로 걷어내지 않는다.
- ⚠️ **닫힌 열거(validation) 는 값이 늘 때마다 부채가 된다.** 넣을 때 유지보수 비용을 함께 계산한다:
  `eks-cluster`의 `capacity_type` 검증은 AWS가 나중에 추가한 `CAPACITY_BLOCK`을 아직 담지 못하고 있다.

### 레이어로 키운다

- 엔드투엔드로 **동작하는 최소**에서 시작해 그 위에 하나씩 얹는다. 동작하는 코드를
  미완성 복잡도와 맞바꾸지 않는다.
- ⚠️ **이 repo에서 "동작한다"의 기준은 `tofu test` + 예제 `validate` 까지다.** 배포하지 않으므로
  `apply` 판정은 소비 repo 몫이다. 그 경계를 넘어 "검증했다"고 쓰지 않는다.
- ⛔ 계약 테스트가 없는 모듈은 릴리스하지 않는다(`docs/conventions.md`, CI 게이트 ④가 강제).

### 임시방편으로 넘기지 않는다

지금만 넘기고 나중에 교체할 우회를 받아들이지 않는다.
`CLAUDE.md`의 **「⛔ 설계·검토 우선 규칙」**(설계 → 검토 → 구현)이 이 원칙의 이행 장치다.
