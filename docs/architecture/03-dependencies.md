# 03 · 의존성 & 공유/기반 리소스 전략 (SG · IAM)

> **승계**: `terraform-enterprise-poc` `docs/architecture/04-dependencies-shared-resources.md` @ `76285f7`(동결 커밋)
> **개정**: 3순위 참조 수단을 `tfe_outputs`에서 **SSM Parameter Store**로 교체(§3.1) ·
> TFC 고유 개념(run trigger·워크스페이스)을 스택 중립 표현으로 · 예시 워크로드 코드를 `acme`로.
> **문제 A(SG rule 순환)와 §4 소유 모델은 도구 무관이라 무편집 승계**했다.
> 이후 **이 문서가 SSOT**다.

> 공통 규약: [02-naming-tagging-and-pinning.md](02-naming-tagging-and-pinning.md) · 멀티환경: [consumer/멀티환경](../consumer/multi-environment.md)

**다루는 문제**: (A) SG rule 순환 의존, (B) "미리 있어야 하는" 공유/기반 리소스(IAM·공유 SG) 참조를 유연하게 푸는 법.
**소유 방식**: 하이브리드(컴포넌트 전용은 모듈이 생성, 공유/기반은 foundation + data source 조회).

---

## 1. 두 문제를 분리한다

| 문제 | 성격 | 해법 |
|------|------|------|
| **A. SG rule 순환** | SG끼리 상호 참조 시 config-time cycle | rule을 **별도 리소스로 분리** |
| **B. 공유/기반 리소스 참조** | cross-config 의존(순환 아님) | **느슨한 조회**(네이밍/data source), state 강결합 회피 |

> 핵심 시너지: [02 네이밍 거버넌스](02-naming-tagging-and-pinning.md)의 **결정적 이름**이 문제 B의 1순위 해법이다.
> 이름이 규칙적이면 리소스를 **누가 만들었든** 이름/태그로 조회 가능 → 의존이 사라진다.

---

## 2. 문제 A — SG rule은 별도 리소스로 분리 (inline 금지)

### 2.1 규칙
- **inline `ingress{}`/`egress{}` 블록을 쓰지 않는다.** rule은 별도 리소스로 분리.
- `aws ~> 6.0` 기준 **신형 단일 rule 리소스**를 쓴다: `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule`.
  - rule 1개 = 리소스 1개, 안정적 `security_group_rule_id`, **태깅 가능**(→ 02 네이밍 적용).
  - 구형 `aws_security_group_rule`은 rule ID가 없어 영구 diff 이슈 → 신규 코드에서 미사용.
- **inline과 분리형을 혼용하지 않는다**(같은 SG에 둘 다 쓰면 Terraform이 서로 덮어씀).

### 2.2 순환 해소 원리
```hcl
# 1) SG는 rule 없이 먼저 생성 (상호 의존 없음)
resource "aws_security_group" "app" {
  name   = "sgr-acme-prd-an2-app-01"
  vpc_id = var.vpc_id
  tags   = { Name = "sgr-acme-prd-an2-app-01" }
}
resource "aws_security_group" "db" {
  name   = "sgr-acme-prd-an2-db-01"
  vpc_id = var.vpc_id
  tags   = { Name = "sgr-acme-prd-an2-db-01" }
}

# 2) rule은 나중에 SG ID 참조 → cycle 없음
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  from_port = 5432, to_port = 5432, ip_protocol = "tcp"
  tags = { Name = "sgr-acme-prd-an2-db-01-from-app" }
}
```
Terraform이 SG 둘을 먼저 만들고 rule을 붙이므로 순환이 사라진다.

### 2.3 rule 소유권 원칙 (새로운 지옥 방지)
- **하나의 SG에 대한 rule은 단일 소유자(config)에서 관리**한다. 여러 config가 같은 SG의 rule을 각자 붙이면 drift·충돌이 생긴다.
- **cross-SG 참조**(rule이 다른 SG의 ID를 필요로 함)는 rule 소유권을 쪼개지 말고, **상대 SG를 data source로 조회해 ID만 참조**한다(§3).
- 공유 SG에 외부 규칙 기여가 필요하면, 소유 모듈이 **허용 소스 목록을 변수로 파라미터화**(예: `allowed_source_sg_names = [...]`)해 owner가 rule을 생성하게 한다.

---

## 3. 문제 B — 공유/기반 리소스는 느슨하게 조회

### 3.1 선호 순서 (위일수록 우선, HashiCorp 권장)
| 순위 | 방법 | 언제 | 결합도 |
|------|------|------|--------|
| 1 | **결정적 네이밍으로 값 구성** | 이름/ARN을 규칙으로 유도 가능 | **없음** |
| 2 | **provider data source** (`data.aws_*`) | 이름/태그로 AWS 직접 조회 | 낮음 |
| 3 | **SSM Parameter Store 게시/조회** | 이름으로 못 얻는 파생 속성이 필요할 때 | 중간 |
| ❌ | `terraform_remote_state` | 지양(전체 state 접근 필요) | 높음 |

> **3순위가 왜 SSM Parameter인가**: PoC는 이 자리에 `tfe_outputs`(HCP Terraform 전용)를 썼으나 이 스택에는
> 존재하지 않는다. 대체재는 두 가지였다 — `terraform_remote_state`(S3)는 **state 전체 접근**을 요구해
> 이 문서가 이미 ❌로 판정한 방식이고, **SSM Parameter는 값 단위로 게시하고 IAM으로 키 단위 접근 제어**가 되어
> 1·2순위와 같은 "이름으로 조회" 철학에 정합한다. producer가 `aws_ssm_parameter`로 게시하고
> consumer가 `data.aws_ssm_parameter`로 읽는다.
>
> ⚠️ 다만 **1·2순위로 해결되면 3순위를 쓰지 않는다.** PoC 실측에서 워크스페이스 간 전달값
> (vpc_id·subnet_ids·cluster_name)은 **전부 네이밍/태그 조회로 대체 가능**했다 —
> 3순위를 습관적으로 쓰면 결합도만 올라간다.

### 3.2 data source 조회 패턴 (네이밍 규약 활용)
```hcl
# 공유 SG를 이름 태그로 조회 (누가 만들었든 무관)
data "aws_security_group" "shared_alb" {
  filter { name = "tag:Name", values = ["sgr-acme-prd-an2-shared-alb-01"] }
  vpc_id = data.aws_vpc.main.id
}

# 기반 IAM Role 조회 (AFT가 미리 만든 것도 이렇게)
data "aws_iam_role" "aft_exec" { name = "AWSAFTExecution" }

# VPC를 이름 태그로 조회
data "aws_vpc" "main" {
  filter { name = "tag:Name", values = ["vpc-acme-prd-an2-main"] }
}
```
→ 소비자는 리소스가 **존재하기만** 하면 됨. "미리 만들어져 있어야 하는" 시나리오(AFT 제공 IAM, 선행 생성 SG, ClickOps 리소스)에 정확히 맞는다.

### 3.3 data source vs 파라미터 게시 — 언제 무엇을
| 상황 | 선택 |
|------|------|
| 기반/pre-existing, 생성 주체 무관, 이름으로 조회 가능 | **data source** (가장 느슨) |
| 같은 환경 체인 내 producer→consumer, 이름으로 유도 가능 | **data source** — 먼저 시도할 것 |
| 이름·조회로 못 얻는 파생 속성 | **SSM Parameter** 게시/조회 |
| 전체 state 접근 | ❌ 지양 |

> 둘 다 대상이 **plan 시점에 존재**해야 함. 차이는 결합 대상: data source는 **네이밍 규약**에,
> SSM Parameter는 **파라미터 키 이름**에 결합한다. 후자도 결국 네이밍 규약의 연장이므로,
> 키는 `/${workload}/${env}/${component}/<attr>` 같은 **결정적 경로**로 정한다.

---

## 4. 하이브리드 소유 모델 (무엇을 어디서)

| 리소스 | 소유 | 소비 |
|--------|------|------|
| **컴포넌트 전용** SG/IAM (EKS cluster SG·node SG, Karpenter IAM) | **해당 모듈이 직접 생성** | 내부 참조 |
| **공유** SG (공유 ALB SG), **공통** IAM(교차 서비스 역할) | **foundation 계층**(별도 배포 루트) | data source(이름/태그) |
| **AFT 제공** IAM(실행/가드레일 역할) | AFT(외부) | data source / 이름 |
| **rule** (특히 cross-SG) | 대상 SG의 **단일 소유자** | 상대 SG는 data source로 ID 참조 |

### 소유 판별 규칙
- **1개 컴포넌트만 사용** → 그 컴포넌트 모듈이 소유.
- **2개 이상 공유** or **선행 존재 필요** or **보안 거버넌스 대상** → foundation(또는 AFT).
- 애매하면 **컴포넌트 소유로 시작**, 공유 수요가 실제로 생기면 foundation으로 승격(YAGNI).

### foundation 계층 위치 (하이브리드)
```
live/<env>/
  foundation/     # 공유 SG, 공통 IAM (환경별)   ← 소수, 안정적
  networking/
  eks-cluster/    # cluster/node SG는 여기서 생성
# (역할 계정 컴포넌트는 live/<role-account>/ — ../consumer/multi-environment.md 참조)
```
> ⚠️ 위 `live/` 구조는 **소비 프로젝트의 것**이다. 이 repo는 배포 루트를 소유하지 않는다 —
> 여기서는 "모듈이 어떤 소유 가정 위에서 동작하는가"를 설명하기 위해서만 인용한다.
- foundation은 안정적 기반 → **자동 전파(워크플로 체이닝) 미권장, data source 조회만**.

---

## 5. 안티패턴 체크리스트
- [ ] SG에 inline `ingress`/`egress` 사용 (순환·순서·replace 문제)
- [ ] 같은 SG에 inline + 분리형 rule 혼용
- [ ] 하나의 SG rule을 여러 config가 각자 관리 (drift·충돌)
- [ ] 공유 리소스 참조에 `terraform_remote_state`로 전체 state 결합
- [ ] 이름으로 조회 가능한데 굳이 파라미터·원격 state로 강결합
- [ ] 구형 `aws_security_group_rule` 신규 사용 (rule ID 부재)

## 6. 열린 항목
1. foundation 루트의 실제 스코프(어떤 SG/IAM을 공유로 볼지 목록화)
2. 공유 SG rule 기여 방식(owner 파라미터화 변수 스키마)
3. IAM 경계: AFT 제공 vs 이 repo 소유 역할 매핑표
4. data source 조회 실패(리소스 미존재) 시 가드(명시적 에러/전제조건 `precondition`)

## 7. 참고 자료
- [Breaking Circular Dependencies: SG rule 분리 (Carim Fadil)](https://carim.ar/posts/security-group-rules-duplicate-error/)
- [Security Groups Best Practices with Terraform](https://oneuptime.com/blog/post/2026-02-23-how-to-implement-security-groups-best-practices-with-terraform/view)
- [Beyond terraform_remote_state: 5 ways to share data (Eytan Dortort)](https://dortort.com/posts/beyond-terraform-remote-state-five-ways-to-share-data-across-configurations/)
- [Managing Resource Dependencies Across Workspaces in HCP Terraform](https://tingli666.medium.com/managing-resource-dependencies-across-workspaces-in-hcp-terraform-4ed22da82202)
- [terraform_remote_state Data Source (지양 근거)](https://developer.hashicorp.com/terraform/language/state/remote-state-data)
- [aws_vpc_security_group_ingress_rule (Registry)](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule)
