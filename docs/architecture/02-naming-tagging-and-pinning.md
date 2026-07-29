# 02 · 네이밍·태깅 거버넌스 & 버전 핀

> **승계**: `terraform-enterprise-poc` `docs/architecture/02-common-governance.md` @ `76285f7`(동결 커밋)
> **개정**: §4(TFC 워크스페이스·run trigger·`tfe_outputs` 연동)와 §5(Phase 0 스캐폴딩) **폐기** —
> 전자는 TFC 종속이자 배포 루트 관심사(→ [`../consumer/`](../consumer/)), 후자는 PoC 일회성 태스크 ·
> workloadcode를 **프로젝트 정의**로 전환 · 정책 엔진을 Sentinel에서 **OPA**로 ·
> 소싱 승격 경로를 **git tag** 모델로.
> **재개정(2026-07-29)**: §2 버전 핀과 §4 릴리스 게이트를 **엔진 중립**으로 전환
> ([`04-engine-neutrality.md`](04-engine-neutrality.md), D-ENGINE-NEUTRAL).
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
| 엔진 (`required_version`) | 모듈 하한 `>= 1.9.0`. **상한 없음, 단 하한을 1.12.x 위로 올리지 않는다** | 1.12 초과 하한은 OpenTofu를 전부 배제 → 중립성 파괴([04 §5 N1](04-engine-neutrality.md)) |
| aws provider | 모듈 `>= 6.0`(하한만) / **예제·소비 루트 `~> 6.0`** | 상한은 **루트가 통제**. 예제도 루트다 |
| provider source | `hashicorp/aws` 형태 **짧은 주소만** | 호스트를 쓰면 엔진이 갈린다([04 §5 N6](04-engine-neutrality.md)) |
| 커뮤니티 모듈 | **정확 핀**(`= x.y.z`), wrapper 내부에서만 | churn 격리 |
| 내부 모듈 소비 | git tag `<module>-vX.Y.Z` | §3 |

- **`.terraform.lock.hcl`은 이 repo에서 커밋하지 않는다**([04 §4](04-engine-neutrality.md)).
  두 엔진의 GPG 신뢰 루트가 달라 해시가 갈리고, 파일명이 고정이라 병존할 수 없다.
  lock은 **remote module을 추적하지 않으므로** 소비자에게 전달되지도 않는다.
  → major 파괴 변경 방어는 **예제의 `~> 6.0` 상한**이 맡는다. minor/patch 회귀는 fresh init으로 조기 검출한다.
- ⚠️ 이 규약은 **이 repo에만** 적용된다. 소비 프로젝트 루트는 실제로 apply하므로 **lock을 반드시 커밋**한다.
- 하한을 올릴 때는 **그 버전의 어떤 기능이 필요한지**를 근거로 남긴다.

---

## 3. 모듈 소싱 규약

3계층: **Consumer(프로젝트 루트) → 내부 Golden Path 모듈(이 repo) → Upstream**.
소비자는 upstream을 직접 참조하지 않는다([01 §2.1](01-module-strategy.md)).

**소싱 경로**

| 단계 | 방식 |
|------|------|
| 이 repo 내부 개발·테스트 | `examples/<module>/`에서 상대경로 `source = "../../modules/vpc"` |
| 소비 프로젝트 | **git tag** `source = "git::https://github.com/<org>/iac-module-library.git//modules/vpc?ref=vpc-v1.0.0"` |

- 태그는 **컴포넌트별 semver**: `vpc-v1.0.0` · `eks-cluster-v1.0.0`.
- git 소싱은 `~>` 같은 버전 제약이 동작하지 않는다 — 소비자가 **정확 태그**를 지정하고,
  업그레이드는 태그를 올리는 명시적 커밋으로 한다. 이것이 오히려 승격 게이트로 작동한다.
- 사설 registry(예: 조직 내부 registry)를 도입하면 `~>` 제약이 가능해진다 → 확산 단계의 검토 항목.

---

## 4. 공통 검증 게이트 (모듈 완료 판정)

**엔진 중립 검증 — 두 엔진 모두에서** (`<E>` = `tofu` · `terraform`)

- [ ] `<E> fmt -recursive -check` clean **(양쪽)**
- [ ] 모든 `modules/*`: `<E> validate` + `<E> test` 통과 **(양쪽)**
- [ ] `examples/*`: `<E> validate` 통과 **(양쪽)**. 예제 없는 모듈은 릴리스하지 않는다
- [ ] [04 §5](04-engine-neutrality.md) 중립성 규칙 N1~N7 위반 없음
- [ ] `.terraform.lock.hcl`이 **커밋되지 않았다**(04 §4 — 커밋하면 반대 엔진에서 checksum 실패)

**엔진 무관 검증** (1회만)

- [ ] `Name` 태그가 §1.2 포맷 + 카탈로그 약어 준수 (`*.tftest.hcl` assertion으로 증명)
- [ ] 커뮤니티 모듈은 정확 핀, facade가 upstream 변수를 소비자에게 노출하지 않음
- [ ] `<component>_enabled` kill switch 존재([01 §4](01-module-strategy.md))
- [ ] `tflint --recursive` · `trivy config` 통과
