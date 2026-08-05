# 02 · 네이밍·태깅 거버넌스 & 버전 핀

> **승계**: `terraform-enterprise-poc` `docs/architecture/02-common-governance.md` @ `76285f7`(동결 커밋)
> **개정**: §4(TFC 워크스페이스·run trigger·`tfe_outputs` 연동)와 §5(Phase 0 스캐폴딩) **폐기** —
> 전자는 TFC 종속이자 배포 루트 관심사(→ [`../consumer/`](../consumer/)), 후자는 PoC 일회성 태스크 ·
> workloadcode를 **프로젝트 정의**로 전환 · 버전 핀을 OpenTofu 기준으로 · 정책 엔진을 Sentinel에서 **OPA**로 ·
> 소싱 승격 경로를 **git tag** 모델로.
> 이후 **이 문서가 SSOT**다.

> 모든 모듈이 공유하는 규약. 개별 모듈 문서는 이 문서를 참조한다.
> 약어 카탈로그는 [`../reference/aws-naming-abbreviations.md`](../reference/aws-naming-abbreviations.md)(SSOT).

---

## 1. 태그 & 네이밍 거버넌스

### 1.1 두 종류의 태그를 분리한다

| 종류 | 목적 | 부착 방식 | 예 |
|------|------|-----------|-----|
| **거버넌스 태그** | 비용배분·감사·소유권 | provider `default_tags`로 **전 리소스 자동** | `Environment`, `Workload`, `ManagedBy`, `Owner`, `CostCenter` |
| **`Name` 태그** | 사람이 읽는 식별자 | 리소스별로 **약어 조합** | `vpc-acme-prd-an2-main` |

> 핵심 원칙: 거버넌스 태그는 자동화로 100% 커버(누락 불가), `Name`은 **모듈이** 약어 규칙을 강제.
> 소비자가 약어를 직접 타이핑하는 순간 규약은 깨진다.

### 1.2 `Name` 포맷

```
(resourcetype)-(workloadcode)-(env)-(regioncode)-(purpose)-(serialnumber|suffix)
```

| 구성 요소 | 정의 위치 | 값 |
|-----------|-----------|-----|
| resourcetype | [약어 카탈로그](../reference/aws-naming-abbreviations.md) (309개) | `ec2`, `vpc`, `eks`, `sgr` … |
| workloadcode | **소비 프로젝트가 정의**(§1.3) | `acme`, `shop` … |
| env | §1.3 | `prd`, `stg`, `dev` |
| regioncode | §1.3 | `an2`, `ue1` … |
| purpose | 자유(소문자, 하이픈) | `web`, `db`, `main`, `worker` |
| serial/suffix | 선택 | `01`, `20260415`, `policy` |

- 소문자·하이픈 구분. 단일 리소스면 `serial/suffix` 생략 가능.
- 스냅샷/AMI 등 시점 자원은 날짜 suffix 권장.

### 1.3 어휘(Vocabulary) 표준

**env 코드**: `prd`(production) · `stg`(staging) · `dev`(development).
역할 계정(CI/CD·shared-services 등) 전용 토큰이 필요하면 **소비 프로젝트의 거버넌스 리뷰로 추가**한다.

**regioncode 매핑** (사용 리전만 등재)

| 코드 | AWS 리전 |
|------|----------|
| `an2` | ap-northeast-2 (서울) |
| `ue1` | us-east-1 (버지니아) |

**workloadcode**: ⚠️ **이 repo는 특정 값을 고정하지 않는다.** 소비 프로젝트가 자기 코드를 정의하고
그 repo의 문서에 등재한다. 모듈은 `naming.workload`로 주입받을 뿐이다.

### 1.4 코드 강제 구현

**(a) 거버넌스 태그 — `default_tags`** (소비 프로젝트의 루트 provider가 소유)

```hcl
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.env
      Workload    = var.workload
      RegionCode  = var.region_code
      ManagedBy   = "opentofu"
      Repository  = var.repository   # 소비 프로젝트가 자기 repo를 지정
    }
  }
}
```

→ 이 루트에서 만드는 **모든** 리소스에 자동 부착. 모듈은 거버넌스 태그를 신경 쓰지 않는다.

**(a-2) 외부 주체가 관리하는 태그 — `ignore_tags`**

계정 쪽 자동 태깅(랜딩존/AFT의 생성 시각 태거, 조직 정책 태그 등)이 붙이는 태그는 state에 없으므로,
방치하면 **모든 리소스에 "태그 제거" 가짜 diff**가 발생한다(PoC에서 32개 리소스 가짜 변경으로 실측 —
[findings](../reference/poc-findings.md)).

```hcl
provider "aws" {
  # …
  ignore_tags {
    keys         = [/* 계정이 주입하는 태그 키 */]
    key_prefixes = [/* 조직 정책 태그 접두 */]
  }
}
```

- 구체 목록은 **계정마다 다르다** — 소비 프로젝트가 자기 계정에서 실측해 등재한다.
- 등재 규칙은 `.trivyignore`와 동일: **항목마다 발견 근거를 기록**, 무단 추가 금지.
- 계정 강제 태깅은 계정 전역이므로, 한 루트에서 발견되면 **같은 계정의 모든 루트에 예방적으로 정렬**한다.

**(b) `Name` 조합 — 공유 규약 변수 `naming`**

```hcl
variable "naming" {
  type = object({
    workload    = string
    env         = string
    region_code = string
  })
}

locals {
  name_mid = "${var.naming.workload}-${var.naming.env}-${var.naming.region_code}"
}

# 모듈 내부 사용 예:
#   Name = "vpc-${local.name_mid}-main"        → vpc-acme-prd-an2-main
#   Name = "snet-${local.name_mid}-pub-${az}"  → snet-acme-prd-an2-pub-a
```

**(c) 검증 — 3중**

1. **`*.tftest.hcl`의 `Name` assertion** (모듈 단위, 이 repo) — plan 단계에서 규약 위반을 잡는다.
2. **정규식 정책** (OPA/Conftest, 소비 프로젝트 CI):
   ```
   ^[a-z0-9]+-[a-z0-9]+-(prd|stg|dev)-[a-z0-9]+-[a-z0-9-]+$
   ```
3. **`trivy config`** (보안 구성) — 게이트는 CLAUDE.md 검증 절 참조.

### 1.5 제약과 예외 (반드시 인지)

| 상황 | 문제 | 대응 |
|------|------|------|
| **S3 버킷** | 이름이 곧 전역 고유 식별자, DNS 규칙 | 포맷 유지하되 계정ID/난수 suffix로 고유화, `.` 회피 |
| **ALB/NLB/대상그룹** | 이름 길이 ≤ 32자 | workload/purpose 축약, serial 생략 |
| **IAM 역할/보안그룹** | 이름이 곧 식별자 | 포맷 적용하되 길이 검증 |
| **EKS/RDS 등** | 리소스명 자체가 API 식별자 | `Name` 태그와 리소스명 모두 포맷 적용 |
| **Karpenter/ASG 노드** | 노드명은 AWS/Karpenter가 관리 | 우리가 태깅하지 않음(discovery 태그만) |
| **IAM 정책 문서** | managed policy 6,144자 한도(조정 불가) | 초과 시 inline(10,240자) 또는 정책 분할 |

---

## 2. 버전 핀 규약

| 대상 | 규약 | 근거 |
|------|------|------|
| OpenTofu | **전 모듈 `>= 1.12.0` 통일**(D-TOFU-FLOOR) / 실행 최신 1.12.x | 아래 표 |
| aws provider | 모듈 `>= 6.0` / 소비 루트 `~> 6.0` + lock 커밋 | 상한은 소비자가 통제 |
| 커뮤니티 모듈 | **정확 핀**(`= x.y.z`), wrapper 내부에서만 | churn 격리 |
| 내부 모듈 소비 | git tag `<module>-vX.Y.Z` (현재 전 모듈 **`0.y.z`** — [05](05-versioning-policy.md)) | §3 |

- `.terraform.lock.hcl`은 **커밋**한다. ⚠️ registry 주소가 `registry.opentofu.org/...`인지 확인 —
  다른 스택의 lock을 복사하면 안 된다.
- **`1.12.0`을 넘겨 더 올릴 때는** 그 버전의 어떤 기능이 필요한지를 근거로 남긴다.
  근거 없는 상향은 소비자만 배제한다 — 이 원칙은 **폐기되지 않았다**(아래 D-TOFU-FLOOR).

### ⭐ D-TOFU-FLOOR — 전 모듈 하한 `>= 1.12.0` 통일 (2026-08-05, 사용자 결정)

| 모듈 | 하한 | 비고 |
|------|------|------|
| **전 모듈 공통** | **`>= 1.12.0`** | `vpc` · `eks-cluster` · `bastion` — 개별 근거를 따지지 않는다 |

**바뀐 것은 원칙이 아니라 기준선(floor)이다.** *"근거로만 올린다"* 는 여전히 유효하며,
**1.13 이상을 요구하려면 그때는 근거가 필요하다.** 바닥값이 `1.9` → `1.12`로 올라갔을 뿐이다.

**근거 3가지**

1. ⭐ **실행 지점은 이미 전부 `1.12.0`이다**(2026-08-05 실측): 예제 2종 · 소비 repo
   `live/dev/networking` · `live/dev/eks`가 모두 `>= 1.12.0`을 선언하고, 실제 바이너리는 CI·로컬
   모두 **1.12.5 하나**다. 즉 모듈 하한의 분기는 **실행에 아무 영향을 주지 않았다.**
2. **분기는 읽을 때마다 판정 비용을 낸다.** `1.12 / 1.9 / 1.9`를 볼 때마다 *"왜 다른가"* 를 확인해야
   하고, **2026-08-05에 실제로 그 비용이 발생했다** — `bastion` 하한을 `1.9`로 잡은 것이
   납득되지 않는다는 지적이 나왔고, 그 판단 근거는 `versions.tf` 주석에도 없었다(주석은
   *"vpc와 왜 다른가"* 만 설명하고 *"왜 통일하지 않는가"* 는 답하지 않았다).
3. **낮은 하한의 수혜자는 아직 가정이다.** *"모듈을 단독 소싱하는 1.9~1.11 환경의 제3자"* 는
   실재한 적이 없다. 반면 위 2의 비용은 실재했다.

**🔴 대가 — 정직하게 적는다**

- **가역성을 잃는다.** 하한은 근거가 사라지면 **내릴 수 있었다** — `eks-cluster`가 실제로
  `1.12.0` → `1.9.0`으로 내려간 전례가 있다([`design/20 §3.3`](../design/20-eks-module.md), Task 20.1(e)).
  통일 이후에는 **내릴 계기 자체가 없다**(근거를 따지지 않으므로).
- **`1.12` 미만 환경의 고객사를 선제적으로 배제한다.** 지금은 비용이 0이지만, 조달 제약으로
  구버전이 고정된 고객사가 나오면 그때는 **모듈이 아니라 이 결정이 원인**이 된다.
- 🔁 **재검토 조건**: 위 상황이 실제로 발생하면. 그때는 통일을 깨는 것이 아니라
  **그 모듈만 예외로 내리고 이 표에 사유와 함께 등재**한다.

> ⚠️ **모듈별 하한 대장은 폐지됐다.** 이전 표(기준선 `1.9` + 모듈별 예외)는 위 결정으로 대체됐다.
> 개별 근거는 각 설계 문서에 기록이 남아 있다 — [`design/10` D12](../design/10-vpc-module.md)(동적
> `prevent_destroy`) · [`design/20 §3.3`](../design/20-eks-module.md)(네이티브 `deletion_protection`).
> **그 기록은 지우지 않는다** — *"어느 시점에 무엇이 하한을 정했는가"* 의 추적점이기 때문이다.

---

## 3. 모듈 소싱 규약

3계층: **Consumer(프로젝트 루트) → 내부 Golden Path 모듈(이 repo) → Upstream**.
소비자는 upstream을 직접 참조하지 않는다([01 §2.1](01-module-strategy.md)).

**소싱 경로**

| 단계 | 방식 |
|------|------|
| 이 repo 내부 개발·테스트 | `examples/<module>/`에서 상대경로 `source = "../../modules/vpc"` |
| 소비 프로젝트 | **git tag** `source = "git::https://github.com/<org>/iac-module-library.git//modules/vpc?ref=vpc-v0.3.0"` |

- 태그는 **컴포넌트별 semver**: `vpc-v0.3.0` · `eks-cluster-v0.2.0`.
  ⚠️ **번호 체계는 [`05-versioning-policy.md`](05-versioning-policy.md)(D-VERSION)가 소유한다** —
  현재 전 모듈이 **`0.y.z`**(개발 단계)이고, `1.0.0`은 05 §2의 기준을 충족할 때 **모듈별로** 컷한다.
  이 절은 *어떻게 소싱하는가*만 정한다.
- git 소싱은 `~>` 같은 버전 제약이 동작하지 않는다 — 소비자가 **정확 태그**를 지정하고,
  업그레이드는 태그를 올리는 명시적 커밋으로 한다. 이것이 오히려 승격 게이트로 작동한다.
- 사설 registry(예: 조직 내부 registry)를 도입하면 `~>` 제약이 가능해진다 → 확산 단계의 검토 항목.

---

## 4. 공통 검증 게이트 (모듈 완료 판정)

- [ ] `tofu fmt -recursive -check` clean
- [ ] 모든 `modules/*`: `tofu validate` + `tofu test` 통과
- [ ] `examples/*`: `tofu validate` 통과 (예제 없는 모듈은 릴리스하지 않는다)
- [ ] `.terraform.lock.hcl` 커밋됨 + registry 주소가 `registry.opentofu.org`
- [ ] `Name` 태그가 §1.2 포맷 + 카탈로그 약어 준수 (`*.tftest.hcl` assertion으로 증명)
- [ ] 커뮤니티 모듈은 정확 핀, facade가 upstream 변수를 소비자에게 노출하지 않음
- [ ] `<component>_enabled` kill switch 존재([01 §4](01-module-strategy.md))
- [ ] `tflint --recursive` · `trivy config` 통과
