# Terraform Cloud Dynamic Credentials (AWS OIDC) 설정 가이드

> 🗄️ **TFC 시절 잔재 — PoC 절차 기록이다. 규약도, 유효한 구성 가이드도 아니다.**
>
> **출처**: `terraform-enterprise-poc` @ `76285f7`(동결 커밋) / **개정 안 됨**
> **성격 확정**: [`design/50` D26-1](../design/50-reference-consumer-repo.md)(2026-07-30, 사용자 결정)
>
> - ⛔ **이 문서의 절차를 따라 하지 않는다.** 발급자가 `app.terraform.io`이고 `aud`가
>   `aws.workload.identity`다 — **현행 스택(GitHub Actions)에서는 한 단계도 맞지 않는다.**
>   절차서는 도구가 바뀌면 남는 게 없다. 살아남은 것은 **2단 역할 체인이라는 구조** 하나뿐이다.
> - **현행 대체물이 이미 실측 기반으로 존재한다**:
>   2단 체인 규약 → 소비 repo `CLAUDE.md` §4 · [`design/50` D28](../design/50-reference-consumer-repo.md) ·
>   실측 `sub` 3패턴 → 소비 repo `docs/deployment-facts.md` §3 · `AWSAFTExecution` 처리 → D27.
> - **이관하지 않는다.** ⚠️ 2026-07-29판 헤더는 "첫 프로젝트 repo로 옮기며 개정한다"였으나
>   **D26이 이관을 기각**했다. 이관 여부를 다시 묻지 말 것.
> - **왜 버리지 않는가**: AFT 이관 경로와 트러블슈팅이 PoC 당시의 실제 시행착오 기록이다.
> - ⚠️ **PoC 계정 ID(`533616270150`)가 12곳 있다.** private repo인 동안의 **유예**이지 해소가 아니다 —
>   `design/50` D20 기각안이 "모듈 repo public 전환"의 선결 과제로 등재하고 있다.


Terraform Cloud(`born2k`)의 워크스페이스(`networking-dev` · `eks-cluster-dev` · `gitops-hub-cicd`)가
정적 AWS 키 없이 **OIDC 기반 임시 자격증명**으로 대상 account에 접근하도록 구성한다.

> 배경: 정적 키 방식에서 `Error: No valid credential sources found`가 발생했다.
> **2단 역할 체인(role chaining)** 구조를 사용한다: TFC가 OIDC로 "입구 Role"을 인증하고,
> 입구 Role이 다시 "실행 Role(`AWSAFTExecution`)"을 assume 하여 실제 리소스를 배포한다.
> 이는 향후 Control Tower/AFT가 계정마다 자동 생성하는 `AWSAFTExecution` 구조에 코드를
> 미리 맞춰두기 위함이다(아래 [AFT 도입 시 마이그레이션](#aft-도입-시-마이그레이션) 참조).

## 동작 원리

```
Terraform Cloud 실행
  └─ 서명된 신원 토큰(JWT) 발급  (aud=aws.workload.identity, sub=organization:born2k:project:skhy-poc:workspace:networking-dev:...)
        │
        ▼  sts:AssumeRoleWithWebIdentity
[입구 Role] tfc-terraform-enterprise-poc   ← OIDC 신뢰. 권한은 "AWSAFTExecution assume" 하나뿐
        │
        ▼  sts:AssumeRole  (역할 체인)
[실행 Role] AWSAFTExecution                ← AdministratorAccess. 실제 리소스 생성 주체
        │
        ▼
AWS Provider(providers.tf 의 assume_role) 가 임시 자격증명으로 워크로드 배포 (VPC, S3 ...)
```

> 역할 체인 세션은 최대 유효기간이 **1시간**(연장 불가)이다. 일반 TFC run에는 충분하다.

## 0. 준비 값

| 항목 | 값 |
|------|-----|
| TFC Organization | `born2k` |
| TFC Workspace | `networking-dev` · `eks-cluster-dev` · `gitops-hub-cicd` (컴포넌트×계정, [03-multi-environment §5](multi-environment.md)) |
| TFC Project | `skhy-poc` |
| 대상 Account ID | `533616270150` (AWS_PROFILE=`silverte`, region `ap-northeast-2`) |
| Audience | `aws.workload.identity` (TFC 기본값) |
| 입구 Role | `tfc-terraform-enterprise-poc` (OIDC 신뢰, assume-only) |
| 실행 Role | `AWSAFTExecution` (AdministratorAccess) — 지금은 수동 생성한 **AFT 대체용 임시 Role** |

## 1. OIDC Identity Provider 생성 (대상 account IAM)

**콘솔**: IAM → Identity providers → Add provider → OpenID Connect
- Provider URL: `https://app.terraform.io` → Get thumbprint
- Audience: `aws.workload.identity`

**CLI**:
```bash
aws iam create-open-id-connect-provider \
  --url "https://app.terraform.io" \
  --client-id-list "aws.workload.identity"
```

생성 ARN: `arn:aws:iam::533616270150:oidc-provider/app.terraform.io`

## 2. 입구 Role (`tfc-terraform-enterprise-poc`) — OIDC 신뢰 + assume-only

TFC OIDC 토큰으로만 assume되고, 권한은 "실행 Role을 assume" 하나뿐인 게이트웨이 Role.

`trust-policy.json` (account `533616270150`, project `skhy-poc` 반영 완료):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::533616270150:oidc-provider/app.terraform.io"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "app.terraform.io:aud": "aws.workload.identity"
        },
        "StringLike": {
          "app.terraform.io:sub": [
            "organization:born2k:project:skhy-poc:workspace:*-dev:run_phase:*",
            "organization:born2k:project:skhy-poc:workspace:*-cicd:run_phase:*"
          ]
        }
      }
    }
  ]
}
```
- `project:skhy-poc` → 실제 TFC 프로젝트명으로 고정하여 다른 프로젝트의 워크스페이스가 이 Role을 assume하지 못하게 제한.
- `workspace:*-dev` → **dev 워크스페이스만** 매칭(2026-07-15 갱신). dev 컴포넌트 추가 시 신뢰 정책 수정 불필요,
  향후 stg/prd 워크스페이스는 매칭되지 않아 환경 격리 유지(각 환경은 자기 계정의 입구 Role 사용).
- `workspace:*-cicd` → **역할 계정 워크스페이스**(`gitops-hub-cicd` 등, 03 §3.1) 매칭(2026-07-19 추가).
  PoC 동안 cicd 컴포넌트가 dev 계정에 배포되므로 dev 입구 Role에 매칭을 추가했다 —
  실제 hub 계정 이관 시 **hub 계정 전용 입구 Role로 분리**하고 이 패턴은 제거한다.
  ⚠️ 워크스페이스 rename 시 sub 클레임이 바뀌어 이 조건과 불일치하면
  `Not authorized to perform sts:AssumeRoleWithWebIdentity`로 즉시 깨진다(2026-07-19 실증
  — eks-bootstrap-dev → gitops-hub-cicd rename 직후 run errored).
- `run_phase:*` → plan/apply 모두 허용.

`entry-assume-only.json` (입구 Role 의 유일한 권한 — 실행 Role assume):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AssumeAWSAFTExecution",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::533616270150:role/AWSAFTExecution"
    }
  ]
}
```

```bash
# 입구 Role 생성 (OIDC 신뢰 정책)
aws iam create-role \
  --role-name tfc-terraform-enterprise-poc \
  --assume-role-policy-document file://trust-policy.json

# 입구 Role 권한: AWSAFTExecution assume 만 허용 (인라인)
aws iam put-role-policy \
  --role-name tfc-terraform-enterprise-poc \
  --policy-name AssumeAWSAFTExecution \
  --policy-document file://entry-assume-only.json
```

입구 Role ARN: `arn:aws:iam::533616270150:role/tfc-terraform-enterprise-poc`

> ℹ️ 입구 Role은 `AdministratorAccess`를 갖지 않는다. 유출돼도 곧장 admin이 아니라
> "실행 Role을 거쳐야만" 권한을 얻는 진짜 게이트웨이다. 실질 권한은 실행 Role이 보유.

## 2b. 실행 Role (`AWSAFTExecution`) — 실제 배포 권한

지금은 수동 생성한 **AFT 대체용 임시 Role**. 향후 AFT가 계정마다 자동 생성하는 동명 Role로 대체된다.

`aftexec-trust-policy.json` (입구 Role 만 assume 허용):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::533616270150:role/tfc-terraform-enterprise-poc"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

```bash
# 실행 Role 생성 + AdministratorAccess
aws iam create-role \
  --role-name AWSAFTExecution \
  --assume-role-policy-document file://aftexec-trust-policy.json
aws iam attach-role-policy \
  --role-name AWSAFTExecution \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

실행 Role ARN: `arn:aws:iam::533616270150:role/AWSAFTExecution`

> ℹ️ `AdministratorAccess`를 붙이는 이유: 워크로드 범위가 열려 있고(IAM Role/정책 포함)
> 최소권한을 매번 갱신하는 비용이 크기 때문. 다음 3중 안전장치가 상한을 잡는다:
> 1. **Control Tower/AFT SCP 가드레일** — 조직 레벨에서 admin이라도 금지 행위를 먼저 차단
> 2. **좁은 신뢰 정책** — 입구 Role(그리고 그 입구 Role은 이 워크스페이스 OIDC)만 assume 가능
> 3. **OIDC + 체인 임시 자격증명** — 실행 시마다 발급되는 최대 1시간 만료 토큰(상시 유효 키 아님)

## 3. `providers.tf` — 실행 Role assume 설정

입구 Role 인증 후 provider가 실행 Role을 assume 하도록 `assume_role` 블록을 활성화한다(현재 반영됨):
```hcl
provider "aws" {
  region = var.aws_region
  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_id}:role/${var.execution_role_name}"
  }
  ...
}
```
→ `workload_account_id = 533616270150`, `execution_role_name = "AWSAFTExecution"` 조합으로
`arn:aws:iam::533616270150:role/AWSAFTExecution` 이 조립된다.

## 4. TFC 변수 — Variable Set `aws-oidc-poc-dev`

dev 환경 공통 변수는 개별 워크스페이스 변수가 아니라 **Variable Set `aws-oidc-poc-dev`**
(`varset-wFAphHRBcoHVShNM`)로 관리하며, dev 워크스페이스 3개에 attach되어 있다
([03-multi-environment §5 변수 관리](multi-environment.md) — "환경 공통 = Variable Set").

| Key | Value | Category | 용도 |
|-----|-------|----------|------|
| `TFC_AWS_PROVIDER_AUTH` | `true` | env | OIDC 동적 자격증명 활성화 |
| `TFC_AWS_RUN_ROLE_ARN` | `arn:aws:iam::533616270150:role/tfc-terraform-enterprise-poc` | env | 입구 Role OIDC 인증 |
| `workload_account_id` | `533616270150` | terraform | provider assume_role 조립 |

> `execution_role_name`은 각 루트 `variables.tf`의 기본값(`AWSAFTExecution`)을 사용하므로 변수 주입 불필요.

(plan/apply 분리가 필요하면 `TFC_AWS_PLAN_ROLE_ARN`, `TFC_AWS_APPLY_ROLE_ARN` 사용 — POC엔 불필요.)

## 5. 검증

- New run 트리거 → 입구 Role OIDC 인증 → `AWSAFTExecution` 체인 assume 통과 후
  `+2 ~0 -0`(VPC + S3) plan 이 나오면 정상.
- 실패 시 CloudTrail에서 두 이벤트를 순서대로 확인:
  1. `AssumeRoleWithWebIdentity` (입구 Role) — 실제 `sub` 값을 신뢰 정책과 대조
  2. `AssumeRole` (실행 Role) — 입구 Role이 principal 인지, 거부 사유가 SCP 인지 확인

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | 입구 Role aud/sub 조건 불일치 | project/workspace 이름·audience 재확인 (2단계) |
| `No OpenIDConnect provider found` | provider 미생성/ARN 오타 | 1단계 확인 |
| 입구 Role 인증 후 `AccessDenied ... sts:AssumeRole ... AWSAFTExecution` | 입구 Role 인라인 정책 누락 또는 실행 Role 신뢰정책이 입구 Role 미신뢰 | 2단계 `AssumeAWSAFTExecution` 인라인 정책 + 2b단계 신뢰정책 확인 |
| 실행 Role assume 후 `AccessDenied` | 실행 Role 권한 부족 또는 SCP 가드레일 차단 | 2b단계 AdministratorAccess 연결 확인. 여전히 막히면 CloudTrail `explicitDeny` 주체가 SCP인지 확인 |
| S3 `BucketAlreadyExists` | 버킷명 전역 충돌 | `variables.tf` 버킷명 조정 |

## VCS 자동 실행 범위 제한 (경로 기반 트리거)

각 워크스페이스는 VCS 연동이므로 추적 브랜치(`main`)에 **push하면 자동으로 Plan이 실행**된다.
자기 컴포넌트와 무관한 변경으로 run이 돌지 않도록, **Trigger Patterns를 경로 단위**로 제한한다
(설정 경로: 워크스페이스 → **Settings → Version Control** → `Only trigger runs when files in
specified paths change` → Patterns):

| 워크스페이스 | Trigger Patterns (2026-07-15 갱신) |
|--------------|-------------------------------------|
| `networking-dev` | `live/dev/networking/**/*.tf`, `live/dev/networking/**/*.tfvars`, `live/dev/networking/**/.terraform.lock.hcl`, `modules/vpc/**/*.tf` |
| `eks-cluster-dev` | `live/dev/eks-cluster/**/*.tf`, `live/dev/eks-cluster/**/*.tfvars`, `live/dev/eks-cluster/**/.terraform.lock.hcl`, `modules/eks-cluster/**/*.tf` |
| `gitops-hub-cicd` | `live/cicd/gitops-hub/**/*.tf`, `live/cicd/gitops-hub/**/*.tfvars`, `live/cicd/gitops-hub/**/.terraform.lock.hcl` |

- **경로 + 파일 확장자 이중 제한**: 디렉토리만 제한(`live/dev/<comp>/**`)하면 그 안의
  `AGENTS.md` 같은 문서 변경도 run을 유발한다. plan 결과에 영향을 주는 파일(`.tf`/`.tfvars`/
  `.terraform.lock.hcl`)만 매칭하도록 좁혔다 (`**`는 0개 이상 세그먼트 매칭).
- `modules/<name>/**/*.tf`를 포함하는 이유: live 루트가 모듈을 **상대 경로**로 소비하므로
  모듈 코드 변경이 곧 해당 컴포넌트 plan 변경이다.
- 결과적으로 `README.md`, `docs/**`, `.github/**`, 컴포넌트 디렉토리 내 `AGENTS.md` 변경으로는
  어떤 워크스페이스도 트리거되지 않는다.

## AFT 도입 시 마이그레이션

현재 `AWSAFTExecution`은 이 PoC를 위해 **수동 생성한 임시 대체 Role**이다. 실제 Control Tower/AFT가
계정을 프로비저닝하면 AFT가 **동명의 `AWSAFTExecution` Role을 자동 생성·관리**한다. 이때
차이점과 해야 할 일은 다음과 같다.

### 무엇이 달라지나

| 항목 | 지금 (수동 임시 Role) | AFT 도입 후 |
|------|-----------------|-------------|
| `AWSAFTExecution` 생성 주체 | 우리가 CLI로 수동 생성 | AFT가 계정 프로비저닝 시 자동 생성 |
| `AWSAFTExecution` 신뢰 정책 | **입구 Role(TFC)** 을 신뢰 | **AFT 관리 계정**(`AWSAFTAdmin`)을 신뢰 (TFC는 기본 미포함) |
| 권한 | AdministratorAccess (수동 부여) | AdministratorAccess (AFT 기본) |
| 관리 방식 | 수동, IaC 밖 | AFT 파이프라인이 관리 (수동 변경 시 드리프트) |

핵심 충돌 지점: **AFT가 만드는 `AWSAFTExecution`은 TFC 입구 Role을 신뢰하지 않는다.**
따라서 TFC 체인이 계속 동작하려면 신뢰 정책에 입구 Role을 **추가**해야 한다.

### 마이그레이션 절차

1. **수동 임시 Role 제거**: AFT가 계정을 관리하기 전에, 수동 생성한 `AWSAFTExecution`을 삭제한다.
   (AFT가 동명 Role을 만들 때 충돌/드리프트를 피하기 위함)
   ```bash
   aws iam detach-role-policy --role-name AWSAFTExecution \
     --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
   aws iam delete-role --role-name AWSAFTExecution
   ```
2. **AFT로 계정 프로비저닝**: `account-request`로 계정 생성 → AFT가 `AWSAFTExecution` 자동 생성.
3. **신뢰 정책에 입구 Role 추가**: AFT의 **`account-customizations`**(또는
   `global-customizations`)에서 `AWSAFTExecution` 신뢰 정책에 TFC 입구 Role 주체를 추가한다.
   AFT가 관리하는 Role을 콘솔에서 직접 수정하면 다음 AFT run에 되돌려지므로, **반드시 AFT
   커스터마이징 코드로** 반영한다.
   ```json
   {
     "Effect": "Allow",
     "Principal": { "AWS": "arn:aws:iam::<계정ID>:role/tfc-terraform-enterprise-poc" },
     "Action": "sts:AssumeRole"
   }
   ```
4. **입구 Role의 assume 대상 ARN 갱신**: 계정 ID가 바뀌면 입구 Role 인라인 정책
   (`AssumeAWSAFTExecution`)의 `Resource` ARN도 새 계정의 `AWSAFTExecution`으로 수정한다.
5. **변수 재확인**: `workload_account_id`를 새 대상 계정 ID로 갱신. `execution_role_name`은
   `AWSAFTExecution` 그대로 유지되므로 `providers.tf`는 무수정.

> 💡 코드(`providers.tf`)가 이미 "`AWSAFTExecution`을 assume" 전제로 작성돼 있어, AFT 전환 시
> Terraform 코드 변경은 사실상 없다. 바뀌는 건 **IAM 신뢰 관계 구성과 계정 ID**뿐이다.
