# 40 · Workbench (SSM 기반 도달 지점) 설계

> **흔히 `bastion host`라 부르는 것의 SSM 전용 형태**다. 이름을 바꾼 이유는 §2.0을 읽는다.
>
> **상태**: ✅ **개정 완료 (2026-08-05)** · **개명 (2026-08-06, D-WORKBENCH-RENAME)**.
> [`docs/README.md`](../README.md) 상태표가 인용 가능 여부의 판정 근거다.
>
> **승계 출처**: `terraform-enterprise-poc` `docs/design/40-bastion.md` @ `76285f7`(동결 커밋).
> ⚠️ 그 repo는 동결이므로 **파일명이 구 이름 그대로다** — 개명은 이 repo에만 적용된다.
> 개정 전 이 문서는 **⚠️ 미개정**이었다 — PoC 전제(HCP Terraform 워크스페이스 · `workload=poc` ·
> 인라인 배포 루트 · 실측 리소스 ID)와 실증 서술이 그대로 남아 있었다.
>
> **이번 개정이 바꾼 것**
> 1. **산출물이 배포 루트에서 재사용 모듈로 바뀌었다** — ⛔ `D-BASTION-INLINE` **철회**, `D-WORKBENCH-MODULE` 신설.
> 2. **ArgoCD 종속 서술을 걷어냈다** — 이 문서는 이제 *"private 클러스터에 누가 닿는가"* 만 소유한다(§0).
> 3. **역할 범위를 확정했다** — self-hosted runner 겸용 **안 함**(`D-WORKBENCH-SCOPE`). [`22 §5-2`](22-day2-operations.md)를 닫는다.
> 4. **EKS 접근 3층의 소유를 갈랐다**(`D-WORKBENCH-SEAM`) — 파급으로 `eks-cluster` 계약이 늘어난다(§5).
>
> **실증 기록의 소재**: PoC에서 확인한 값(SSM 등록·tmpfs 고갈·envoy 443 함정·private 전환 V-4~V-9)은
> [`../reference/poc-findings.md`](../reference/poc-findings.md)가 소유한다. **이 repo는 배포하지 않으므로
> 여기에 apply 실증을 적지 않는다** — "동작한다"의 기준은 `tofu test` + 예제 `validate`까지다(§7).

---

## 0. 이 문서가 소유하는 것 / 소유하지 않는 것

| | 내용 |
|---|---|
| **소유** | ① `modules/workbench` 모듈 계약(입력·출력·리소스) ② **private 엔드포인트 클러스터에 대한 도달 지점**의 설계 ③ SSM 기반 접근의 경계와 그 대가 ④ EKS 접근 3층 중 **어느 층을 누가 소유하는가**(§5) |
| **소유하지 않음** | GitOps 부트스트랩 seam(→ [`21`](21-gitops-bootstrap-seam.md) **미결정**) · ArgoCD 토폴로지와 UI 접근 절차(→ 같음) · Day 2 운영 프로파일(→ [`22`](22-day2-operations.md)) · EKS 모듈 계약(→ [`20`](20-eks-module.md)) · 배포 루트 구성(→ [`50`](50-reference-consumer-repo.md)) |

> ⭐ **개정 전 이 문서의 제목은 "ArgoCD private 전환의 선결 과제"였다.** 그 틀을 버린 것이
> 이번 개정의 가장 큰 변화다. 이유는 의존 방향이다 — 40이 ArgoCD를 전제하면 **21(미결정)이 뒤집힐 때
> 40도 함께 흔들린다.** [`01 §3.3`](../architecture/01-module-strategy.md)이 *"관리형 Capability는
> 대안(self-managed ArgoCD 포함)과 함께 다시 결정한다"* 고 적은 이상, 그 재결정은 실제로 뒤집힐 수 있다.
>
> **일반화하면 40은 21과 무관하게 완결된다.** workbench가 푸는 문제는 *"ArgoCD를 어떻게 보나"* 가 아니라
> **"엔드포인트를 닫은 클러스터를 누가 조작하나"** 이고, 이 문제는 21이 무엇으로 결정되든 남는다.
> self-managed ArgoCD를 택해도 helm을 돌릴 지점이 필요하다([`22 §5-1`](22-day2-operations.md)).

---

## 1. 문제 — 엔드포인트를 닫으면 조작 지점이 사라진다

[`20 §3.1`](20-eks-module.md)의 `endpoint_public_access` 기본값은 **`false`** 다. GitOps(pull)를 전제로
한 값이다([`01 §3.1`](../architecture/01-module-strategy.md)). 그런데 private-only 클러스터의 apiserver는
**VPC 내부에서만** 도달한다 — GitHub Actions의 공용 runner도, 운영자 노트북도 닿지 않는다.

**이것이 지금 실제로 비용을 내고 있다.** 소비 repo `iac-reference-infra`의 `live/dev/eks`는
`endpoint_public_access = true`를 켜 두고 다음 주석을 달고 있다.

```
# ⚠️ workbench(design/40)이 아직 없어 private-only 면 kubectl 도달 지점이 없다 — 그래서 public 을 켠다.
```

즉 **모듈의 기본값(private)이 레퍼런스 소비 repo에서 지켜지지 못하는 상태**다. `public_access_cidrs`로
좁혀 두었지만(0.0.0.0/0은 validation이 차단한다) 그것은 완화이지 해소가 아니다.

⭐ **그래서 이 문서 하나만 끝나도 값이 난다** — 위 주석의 이유가 사라지고 소비 repo가 public을 닫을 수 있다.
`21`의 결정을 기다리지 않는다.

### 1.1 도달성 후보 3개와 이 문서의 선택

[`22 §3.4`](22-day2-operations.md)가 세운 후보다.

| 후보 | 성립 방식 | 대가 |
|------|-----------|------|
| **public endpoint + CIDR 제한** | 지금 소비 repo가 쓰는 방식 | 고객사 사무실 IP가 바뀔 때마다 인프라 변경. 재택·VPN·CI runner IP까지 열면 목록이 커진다. **apiserver가 인터넷에 노출된 사실 자체는 남는다** |
| **self-hosted runner** | CI가 VPC 안에서 돈다 | 상시 기동 + runner 등록 자격증명 + 빌드 부하를 견딜 인스턴스. **사람의 조작 지점은 여전히 없다** |
| ⭐ **workbench (SSM)** | VPC 안 조작 지점 | 인스턴스 1대 상시 비용(월 $5 미만). 접근 통제가 **SSM/IAM 한 곳**으로 모인다 |

**workbench를 택한다**(2026-08-04 사용자 결정, [`22 §3.4`](22-day2-operations.md) 상자). 결정적 근거는
비용이 아니라 **경계의 개수**다 — public+CIDR은 "네트워크 경계"와 "IAM 경계"를 둘 다 관리해야 하고,
self-hosted runner는 "CI 자격증명 경계"가 하나 더 는다. SSM은 **인바운드가 아예 없어**
네트워크 경계를 지우고 IAM 하나로 수렴시킨다(§2 D-WORKBENCH-ACCESS).

⚠️ **대신 그 IAM 하나의 무게가 커진다.** SSM 접근 통제가 곧 클러스터 접근 통제가 된다 — §9 열린 항목 1이
그래서 열려 있다.

---

## 2. 결정 요약

### 2.0 ⭐ D-WORKBENCH-RENAME — 왜 `bastion`이 아닌가 (2026-08-06 사용자 결정)

**이름이 실물과 어긋나 있었다.** `bastion host`의 정의적 특성은 **인바운드를 받아 안쪽으로 전달**하는
것(SSH/RDP 점프)인데, 이 모듈은 그 특성을 **하나도 갖지 않는다.**

| 이 모듈의 실물 | bastion 정의와 |
|---|---|
| 인바운드 규칙 **0개** — `main.tf`에 ingress 리소스가 아예 없다 | ⛔ 정반대 |
| private 서브넷 전제, 공인 IP 미할당 | ⛔ 전통적 bastion은 public |
| SSM 세션 전용(22번 없음) — `D-WORKBENCH-ACCESS` | ⛔ |
| `kubectl`·`helm`을 user_data로 설치 | ➕ bastion 정의에 없는 성격 |
| 상태를 담지 않아 수시 생성·파기가 정상 — `D-WORKBENCH-LIFECYCLE` | ➕ 요새가 아니라 소모품 |

즉 이것은 **경계를 지키는 요새가 아니라 도구가 갖춰진 작업대**다. `workbench`가 실물을 가리킨다.

> 🔑 **미학이 아니라 오독 방지다.** "bastion"은 읽는 사람에게 **SSH·22번·public 서브넷**을 연상시킨다.
> 이 모듈은 **인바운드 0이 계약**인데 이름이 그 반대를 암시한다 — 6개월 뒤 다른 사람이
> *"bastion인데 왜 22가 없지"* 로 가는 여지를 **이름이 스스로 만든다.**
>
> ⚠️ **잃는 것**: `bastion`은 업계 표준 용어라 신규 인력·고객사가 즉시 이해한다. 그래서 이 문서와
> 모듈 README 첫 줄에 *"흔히 bastion host라 부르는 것"* 을 명시한다 — 검색·이해 비용을 이름 대신
> 한 줄로 치른다.

**⏱️ 시점이 결정적이었다.** `var.purpose` 기본값이 **식별자**로 흘러간다(태그가 아니라 `name` 인자):
`aws_iam_role.name` · `aws_iam_instance_profile.name` · `aws_security_group.name`(§4.2).

- apply **전**(= 개명 시점)이라 소비 repo plan이 `10 to add, **0 to change, 0 to destroy**` 그대로였다.
- apply **후**였다면 IAM role·instance profile·SG가 **replace**되고, 그 연쇄로 Access Entry
  (principal ARN 변경)와 cluster SG rule(source SG 변경)까지 replace된다.
- ⇒ **소비자 0인 시점에만 공짜다.** `bastion-v0.1.0`은 apply가 0회였으므로
  [`CLAUDE.md`](../../CLAUDE.md)의 *"릴리스된 태그를 덮어쓰지 않는다 — 예외는 소비자가 0일 때뿐"* 에
  정확히 해당한다. 태그는 **삭제하고 `workbench-v0.1.0`을 새로 발행**했다.

#### 구 결정 ID 대응표

2026-08-06 **이전** 커밋·태그·PR 메시지의 `D-BASTION-*`는 이 표로 읽는다.
⛔ **과거 기록은 고치지 않는다** — 커밋 메시지는 그때의 사실이다.

| 구 ID | 신 ID |
|-------|-------|
| `D-BASTION-MODULE` | `D-WORKBENCH-MODULE` |
| `D-BASTION-ACCESS` | `D-WORKBENCH-ACCESS` |
| `D-BASTION-PLACEMENT` | `D-WORKBENCH-PLACEMENT` |
| `D-BASTION-EGRESS` | `D-WORKBENCH-EGRESS` |
| `D-BASTION-LIFECYCLE` | `D-WORKBENCH-LIFECYCLE` |
| `D-BASTION-AMI-PIN` | `D-WORKBENCH-AMI-PIN` |
| `D-BASTION-SCOPE` | `D-WORKBENCH-SCOPE` |
| `D-BASTION-SEAM` | `D-WORKBENCH-SEAM` |

> ⚠️ **`D-BASTION-INLINE` · `D-BASTION-K8S` · `D-BASTION-SUBNET`은 바뀌지 않는다.** 셋 다
> **철회된 PoC repo의 ID**이고 그 repo(`terraform-enterprise-poc`)는 **동결**이라 여전히 구 이름이다.
> 개명하면 그쪽에서 찾을 수 없어져 추적이 끊긴다. 이 문서가 그 셋을 인용할 때는 구 이름을 쓴다.

**개명 범위**: 설계 문서 · 모듈 디렉터리(`modules/workbench`) · 변수(`workbench_enabled`) ·
출력(`workbench_*`) · `purpose` 기본값(`"workbench"`) · 예제. ⛔ `eks-cluster` **계약은 안 바뀐다** —
`cluster_security_group_additional_rules`·`access_entries`는 중립적 이름이라 주석만 갱신했고,
그래서 **`eks-cluster` 태그는 재발행하지 않는다.**

---

승계 결정의 **재판정 결과를 함께 적는다.** "그때 이렇게 정했다"와 "지금도 유효한가"는 다른 질문이고,
미개정 문서를 개정할 때 이 구분을 흐리면 PoC 전제가 조용히 살아남는다.

| ID | 결정 | 승계 상태 | 근거 |
|----|------|-----------|------|
| **D-WORKBENCH-MODULE** | `modules/workbench` **얇은 스크래치 모듈** + `examples/workbench-*` 예제. 소비 repo는 태그로 소싱한다 | 🆕 **신설 — ⛔ `D-BASTION-INLINE` 철회** | 아래 §2.1 |
| **D-WORKBENCH-ACCESS** | **SSM Session Manager 전용** — SSH·키페어·공인 IP·인바운드 SG 규칙 **전부 없음** | ✅ 승계·유효 | SSM Agent가 **아웃바운드로** 연결을 맺고 세션이 그 연결을 역방향으로 흐른다. 인바운드가 원천적으로 불필요하다 → 키 관리·22번 노출·감사 공백이 **동시에** 사라진다. 도구 스택(TFC→OpenTofu)과 무관한 판단이라 그대로 살아 있다 |
| **D-WORKBENCH-PLACEMENT** | **private 서브넷**에 배치. 단 모듈은 **`subnet_id`를 입력받고 서브넷 그룹 이름을 고정하지 않는다** | 🔧 **개정**(구 `D-BASTION-SUBNET`) | 아래 §2.2 |
| **D-WORKBENCH-EGRESS** | 기존 **NAT 경유**. SSM VPCE 3종(`ssm`·`ssmmessages`·`ec2messages`) 미신설 | ✅ 승계·유효(단 §9-2) | 추가 비용 0, 구성 단순. SSM 제어 트래픽은 TLS로 보호되며 AWS 권장 구성 중 하나다. VPCE 3종 × AZ 수는 상시 시간당 요금이라 **NAT가 이미 있는 VPC에서는 중복 지출**이다. ⚠️ NAT 없는 완전 격리 VPC를 요구하는 고객사가 나오면 §9-2로 전환 |
| **D-WORKBENCH-LIFECYCLE** | 상시 기동 **소형 인스턴스**(기본 **`t4g.small`** — 2026-08-10 D-WORKBENCH-SIZE 로 `t4g.nano` 에서 상향) + **`workbench_enabled` kill switch** | 🔧 **개정** | 상시 기동 자체는 유효하다(인바운드가 없어 공격면 증가가 미미하고 월 $5 미만). **개정 지점은 kill switch** — 재사용 자산에서 "파기하려면 코드를 지운다"는 소비자에게 diff 폭을 강요한다. `vpc_enabled`·`cluster_enabled`와 동형의 토글을 낸다(`01 §4` 재사용 자산 요건) |
| **D-WORKBENCH-AMI-PIN** | AMI ID **명시 핀**. 단 **모듈에 기본값을 두지 않는다**(필수 입력) | 🔧 **개정·강화** | 아래 §2.3 |
| **D-WORKBENCH-SCOPE** | **self-hosted runner로 겸용하지 않는다.** workbench는 사람이 조작하는 지점이다 | 🆕 신설 (2026-08-05 사용자 결정) | 아래 §2.4 — [`22 §5-2`](22-day2-operations.md)를 닫는다 |
| **D-WORKBENCH-SEAM** | EKS 접근 3층 중 **1층(주체 IAM)만 workbench가 소유**하고 **2·3층(Access Entry·SG ingress)은 `eks-cluster`가 소유**한다 | 🆕 신설 (2026-08-05 사용자 결정) | 아래 §5 — ⛔ PoC의 `D-BASTION-K8S`(workbench가 3층 전부 소유) **철회** |

### 2.1 D-WORKBENCH-MODULE — 왜 인라인을 철회하는가

PoC의 `D-BASTION-INLINE`은 *"리소스 5개 미만·분기 없음이므로 배포 루트에 인라인"* 이었다.
그 판단은 **PoC repo 안에서는 옳았다** — 거기엔 배포 루트가 있었고 환경이 하나였다.

**이 repo에는 배포 루트가 없다.** 인라인을 유지하면 이 repo가 소유할 산출물이 **문서뿐**이 되고,
workbench는 고객사마다 복사되는 코드가 된다. 그것은 이 repo의 존재 이유
(*"재사용 자산"*, [`01 §4`](../architecture/01-module-strategy.md))와 정면으로 어긋난다.

- 계층형 하이브리드([`01`](../architecture/01-module-strategy.md))의 **얇은 스크래치 모듈**에 정확히 해당한다 —
  EC2·SG·IAM은 안정적이고 churn이 없어 커뮤니티 모듈을 감쌀 이유가 없다.
- 신규 모듈이므로 **`workbench-v0.1.0`에서 시작**한다(`D-VER-NEW`, [`../architecture/05 §3`](../architecture/05-versioning-policy.md)).
- ⚠️ **"리소스가 적어서 모듈로 감쌀 가치가 없다"는 반론은 이 repo에서 성립하지 않는다.** 모듈의 값은
  리소스 개수가 아니라 **하드닝 규약을 계약으로 고정**하는 데 있다 — IMDSv2 강제·볼륨 암호화·
  인바운드 0·키페어 없음은 인라인으로 복사되면 고객사마다 조용히 빠진다. §4.2가 그 목록이다.

### 2.2 D-WORKBENCH-PLACEMENT — 서브넷 **그룹 이름**을 계약에 넣지 않는다

PoC는 `snet-poc-dev-an2-vm-uniq-a/c`라는 구체 서브넷을 지정했다. 재사용 자산에서는 그럴 수 없다 —
`vm-uniq`는 **PoC VPC의 서브넷 그룹 키**일 뿐이고, [`modules/vpc`](10-vpc-module.md)의 `subnet_groups`는
소비자가 자유롭게 정의하는 map이다(그룹 키가 곧 `Name`의 purpose 토큰이 된다).

- 모듈 입력은 **`subnet_id`(단수)** 다. workbench는 1대이므로 AZ 분산이 의미 없다 — 리스트를 받아
  내부에서 하나를 고르면 "어느 AZ에 떴는지"가 모듈 내부 규칙에 숨는다.
- **private 서브넷일 것**은 계약이 아니라 **문서화된 전제**로 둔다. 모듈이 `data.aws_subnet`으로
  `map_public_ip_on_launch`를 검사해 막을 수는 있으나, **public 서브넷 + 공인 IP 미할당** 조합도
  기술적으로 유효하다. 닫힌 검증은 값이 늘 때마다 부채가 된다(CLAUDE.md 작업 원칙).
- ⭐ **인바운드가 0이므로 public 서브넷은 이득 없이 공격면만 늘린다** — 이 논증은 승계 그대로 유효하다.
  예제는 private 그룹에 배치한다.

### 2.3 D-WORKBENCH-AMI-PIN — 핀은 유지, **기본값은 제거**

`latest` SSM 파라미터(`…/al2023-ami-latest/…`)를 쓰지 않는다는 결정은 유효하다. `latest`는 AWS가
새 AMI를 릴리스할 때마다 값이 바뀌어 **리뷰 없이 인스턴스가 재생성**된다.

**개정 지점은 기본값이다.** PoC는 `ami-0e9f53ecbca0f42fd`를 기본값으로 박았는데, AMI ID는
**리전 종속**이라 재사용 자산의 기본값이 될 수 없다 — 다른 리전 고객사는 apply가 실패하고,
같은 리전이라도 그 AMI는 시간이 지나면 deprecated된다.

> 🔑 **이것은 `D-ADDON-VERSION-PIN-1`([`20 §2.6-6`](20-eks-module.md))과 같은 구조다.**
> *"핀을 쓴다"* 와 *"핀의 값을 모듈이 소유한다"* 는 별개이고, 후자가 재사용을 막는다.
> **모듈은 `most_recent = false`에 해당하는 것(= 명시 인자 요구)만 소유하고, 값은 소비 루트가 소유한다.**

- `ami_id`는 **기본값 없는 필수 입력**이다.
- 값을 찾는 방법은 예제 README가 안내한다(`aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/...`
  로 **조회해서 그 값을 커밋**한다 — 조회를 코드에 넣지 않는다).
- 업그레이드는 `ami_id`를 bump하는 **명시적 커밋**으로만. plan diff에 인스턴스 재생성이 보이고,
  그것이 의도된 것임을 리뷰가 확인한 뒤 apply한다.

⚠️ **`instance_type`과 `ami_id`의 아키텍처 정합은 모듈이 검증하지 않는다.** arm64 AMI에 x86 타입을
주면 apply에서 죽는다. 검증하려면 AMI를 조회해야 하고(= 핀의 취지와 충돌), 인스턴스 타입 문자열에서
아키텍처를 유도하는 것은 닫힌 열거를 새로 만드는 일이다. **예제와 변수 설명으로 안내한다.**

### 2.4 D-WORKBENCH-SCOPE — self-hosted runner 겸용을 하지 않는다

[`22 §5-2`](22-day2-operations.md)가 *"`40` 개정과 분리해서 결정하지 않는다"* 고 못박은 항목이다.
역할 범위가 인스턴스 타입·SG·IAM을 전부 정하기 때문이다.

**겸용하지 않는다.** workbench는 **사람이 조작하는 지점**이고, 그 결과 다음이 계약이 된다.

| 축 | 겸용 안 함(채택) | 겸용(기각) |
|----|------------------|-----------|
| 인스턴스 타입 | 소형으로 충분 — **다만 `t4g.nano` 는 아니다**(§4.3 D-WORKBENCH-SIZE 가 `t4g.small` 로 정정. *"빌드 부하가 없다"* 만 보고 **패키지 관리자의 메모리 요구를 빠뜨렸다**) | 빌드 부하를 견뎌야 함 → 타입 대폭 상향 + 비용 |
| IAM | SSM + (선택) `eks:DescribeCluster` | GitHub runner 등록·아티팩트 접근 권한 추가 |
| 자격증명 | **추가 없음** | runner 등록 토큰(회전 대상)이 하나 늘어남 |
| 상시 기동 | 조작할 때만 쓰는 유휴 인스턴스 | CI 대기 시간 때문에 상시가 **요구사항**이 됨 |

**그 대가를 명시한다** — 프로파일 B(helm/kubectl 직접 운영, [`22 §3`](22-day2-operations.md))의 배포는
**사람이 workbench에서 실행**한다. 즉 [`50`](50-reference-consumer-repo.md)의 plan artifact 규약
(*"승인한 계획을 그대로 apply한다"*)에 대응하는 장치가 **helm 경로에는 없다.**

> ⚠️ **이 한계를 숨기지 않는다.** 프로파일 B는 애초에 *"플랫폼 팀이 없는 고객사"* 를 위한 경로이고
> ([`22 §3.1`](22-day2-operations.md)), 그런 조직에 CI 승인 게이트를 강제하면 운영이 멈춘다.
> **작은 조직에 현실적인 절차를 주는 것이 선택의 목적**이지, 구멍을 못 본 것이 아니다.
>
> 🔁 **재검토 조건**: 프로파일 B 고객사가 **환경 3개 이상**(dev/stg/prd)으로 늘어 helm 실행이 반복
> 작업이 되면 그때 다시 판단한다. 그 시점엔 자동화의 값이 자격증명 1개의 대가를 넘어선다.

### 2.5 D-WORKBENCH-REPO — private 저장소 접근은 **GitHub App 토큰, 부트스트랩 시점 한정** (2026-08-07)

**문제**: [`23 §2.1`](23-argocd-self-managed.md)의 seed는 workbench에서 두 가지를 요구한다 —
**(a)** GitOps 저장소의 **커밋본 파일**(자기소멸 원칙이 *"커밋본을 그대로 apply"* 를 요구) ·
**(b)** `argocd-seed.sh`. **둘 다 private 저장소**이고 workbench는 SSM 전용이라 `scp`가 없다.
2026-08-07 실측 시점에 workbench에는 `git`도 GitHub 자격증명도 **없었다.**

> ## ⭐ **결정 ①: 저장소는 GitHub App installation token으로 클론한다**
>
> ArgoCD가 쓰는 그 App([`30 §4.1`](30-gitops-repo.md))의 **installation token**(유효 1시간)으로
> `git clone` 한다. JWT 서명은 workbench에서 `openssl`로 한다 — **AL2023에 `openssl`·`jq`가
> 기본 탑재**라 도구를 늘리지 않는다(2026-08-07 실측).
>
> 🔑 **한계비용이 거의 0인 이유**: [D-KEY-TRANSFER](../../scripts/README.md)에 따라 **그 시점
> workbench에는 App private key가 이미 있다.** seed에 쓰려고 내려받은 그 키를, 같은 저장소를
> 읽는 데 한 번 더 쓰는 것뿐이다. 새 자격증명·새 IAM·새 버킷이 **하나도 생기지 않는다.**
> ⇒ [§2.4](#24-d-workbench-scope--self-hosted-runner-겸용을-하지-않는다)가 계약으로 못박은
> **"자격증명 추가 없음"이 그대로 지켜진다.**

> ### ⚠️ **주체가 다른데 재사용해도 되는가 — [`30 §1.1`](30-gitops-repo.md)의 기준으로 판정한다**
>
> `30 §1.1`은 CI용 App(`skax-ca-module-reader`) 재사용을 **금지**했다. 기준은
> *"다른 주체 · 다른 blast radius"* 였다. 여기서는 **주체가 다르다**(ArgoCD가 아니라 조작자).
> 그런데도 허용하는 근거는 **blast radius가 늘지 않는다**는 것이다:
>
> | 축 | ArgoCD의 사용 | 조작자의 사용 | 판정 |
> |---|---|---|---|
> | 대상 저장소 | `iac-platform-gitops` | **같음** | 동일 |
> | 권한 | `contents: read` | **같음** | 동일 |
> | 목적 | 그 매니페스트를 적용하려고 읽음 | **같음** | 동일 |
>
> 🔑 **기준은 "주체가 같은가"가 아니라 "접근 가능 집합이 늘어나는가"다.** CI용 App 재사용이
> 금지된 진짜 이유는 그것이 **모듈 저장소들**을 함께 열기 때문이었다 — 주체 명칭이 아니라 범위다.
> ⛔ **그래서 반대 방향은 금지된다**: `iac-module-library`를 이 App의 설치 범위에 **추가하지 않는다.**
> 그러면 ArgoCD가 모듈 소스까지 읽게 되어 범위가 실제로 늘어난다.
> (실측 2026-08-07: 이 App의 설치 범위는 `total_count=1`, GitOps 저장소 하나뿐이다.)

> ## ⭐ **결정 ②: `argocd-seed.sh`는 GitOps 저장소에 vendoring한다** — ✅ 이행 완료 (2026-08-10)
>
> 위 ⛔ 때문에 **(b)를 같은 토큰으로 풀 수 없다.** 두 번째 메커니즘을 만드는 대신,
> 스크립트의 **핀된 사본**을 GitOps 저장소 `bootstrap/`에 둔다 ⇒ **클론 한 번으로 (a)(b)가 함께 온다.**
> - **SSOT는 이 repo가 유지한다**([`23 §6-5`](23-argocd-self-managed.md)) — 사본은 편집하지 않는다.
> - 사본 헤더에 **출처**를 적어 어느 버전인지 드러낸다.
> - 저장소 레이아웃은 [`30 §4`](30-gitops-repo.md)가 소유한다.
>
> ⚠️ **이것은 경쟁 SSOT가 아니라 vendoring이다.** 구분 기준은 *"어디를 고치는가"* 하나다 —
> 고치는 곳이 하나면 사본이 여럿이어도 SSOT는 하나다. 사본을 고치기 시작하면 그때 drift가 된다.
>
> ### 📌 이행하면서 정해진 것 2가지 (2026-08-10, `iac-platform-gitops` `ba9d079`)
>
> **① "출처 태그"의 실제 형태는 커밋 SHA다.** 이 절은 *"태그"* 라 적었지만 **`scripts/`에는 태그
> 축이 없다** — 태그는 모듈별 semver(`vpc-v0.3.0`)이고 이 스크립트는 `?ref=`로 소싱되지 않는다.
> 새 태그 축을 발명하는 대신 SHA로 핀했다. 요건(*"어느 버전인지 드러낸다"*)은 그대로 충족되고
> SHA가 더 정확하다. 🔁 사본이 여러 고객사 저장소로 늘어나면 그때 태그 축을 재검토한다.
>
> **② 배너를 붙이는 순간 "편집하지 않았다"를 검증할 수 없게 된다** — 헤더 때문에 사본과 SSOT의
> 바이트가 달라지기 때문이다. ⇒ 배너의 **모든 줄에 `#V#` 접두**를 두어 검사를 한 줄로 만들었다:
> `diff <(grep -v '^#V#' <사본>) scripts/argocd-seed.sh`.
> 🔑 *"사본을 편집하지 않는다"* 는 **검사할 수 있어야 규칙이다** — 그렇지 않으면 권고에 그친다.
> 절차 전문은 [`scripts/README.md`](../../scripts/README.md)의 「vendoring」 절이 소유한다.
>
> ⚠️ **root App의 훑기에 `exclude`를 추가하지 않았다.** ArgoCD directory 소스는 `.yaml`·`.yml`·`.json`만
> 읽으므로([공식 문서](https://argo-cd.readthedocs.io/en/stable/user-guide/directory/)) `.sh`는 애초에
> 스캔되지 않는다 — 제외하면 **죽은 설정**이 되고 다음 사람이 *".sh도 스캔된다"* 로 잘못 읽는다.

> ### 🥚 **닭과 달걀 — 클론 헬퍼는 vendoring으로 풀 수 없다**
>
> 결정 ②는 **seed 스크립트**의 배달을 푼다. 그러나 **클론 자체를 하는 코드**(JWT 서명 →
> installation token → `git clone`)는 **클론하기 전에** 필요하므로 저장소 안에 둘 수 없다.
>
> ⇒ **그 조각은 런북에 인라인으로 둔다**([`scripts/README.md`](../../scripts/README.md)).
> 성립 조건은 **짧을 것**(붙여넣기 가능) · **비밀이 아닐 것**(키는 Parameter Store에서 오고
> 토큰은 출력하지 않는다) 두 가지다. 현재 ~15줄로 둘 다 만족한다.
> ⚠️ 이 조각이 길어지기 시작하면 그것이 **다른 배달 경로(S3 안)가 필요하다는 신호**다 —
> 기각안 표의 재검토 조건 ①과 같은 지점에서 만난다.

> ### 📌 **귀결 — `git`이 모듈 산출물에 들어온다** — ✅ 구현 완료 (2026-08-10)
>
> 클론을 하려면 `git`이 있어야 하는데 **`§4.1`에 그것이 없었다.**
> ⚠️ 2026-08-07 seed는 `git`을 **수동 설치**해서 넘겼다 — `user_data_replace_on_change = true`라
> **인스턴스 교체와 함께 사라지는 상태**였다. `workbench-v0.2.0`이 그 부채를 갚는다.
>
> ⛔ **최초 서술은 *"`kubectl_version`·`helm_version`과 같은 nullable 패턴으로 열어야 한다"* 였다.
> 그 문장을 되살리지 말 것** — [`§4.1`의 상자](#41-variables)가 같은 날 **기각**했고 구현은 그쪽을
> 따랐다. 기각 사유는 `git`에는 **핀할 값이 없다**는 것이다(배포판 패키지). 변수를 두면
> [열린 항목 6](#10-열린-항목)이 경고한 **선택지 없는 분기**만 남는다.
> 🔑 두 절이 같은 날 갈린 것 자체가 기록할 값어치다 — *"같은 패턴을 기계적으로 복사하지 않는다"* 가
> 이 결정의 요지이고, 그 판단은 §2.5를 쓴 뒤에 나왔다.
>
> **계약(입력)은 넓어지지 않았고 산출물만 달라졌다.** 그래도 `workbench` 마이너를 컷한다
> ([`05`](../architecture/05-versioning-policy.md) — `0.y.z`라 전부 마이너).

**기각안**

| 안 | 기각 사유 |
|---|---|
| **Deploy key(SSH)** | 장기 자격증명 신설 + 키 배포 문제가 원점 회귀(D-KEY-TRANSFER를 또 씀). 결정적으로 **`egress_cidr_blocks`가 443만 연다**(§4.1) — SSH는 SG 계약까지 건드린다 |
| **`gh auth login`(device flow)** | **개인 토큰이 공용 workbench에 남는다.** 고객사에서 *"누구 계정으로 부트스트랩했는가"* 가 인스턴스에 각인된다. 도구도 하나 는다 |
| **S3 아티팩트 경유** | ⭐ **가장 유력했던 대안** — workbench가 GitHub 자격증명을 아예 안 갖고, SHA tarball이라 dirty가 원천 불가하다. 기각 이유는 **`s3:GetObject` IAM 추가 + 버킷 결정**(state 버킷 재사용은 경계 위반)이 필요한데, 채택안은 그 비용이 0이기 때문이다. 🔁 **workbench의 GitHub 접근을 금지하는 고객사가 나오면 이 안으로 전환한다** |
| **`send-command`로 배달** | 자격증명·IAM 0이지만 **SendCommand 페이로드 상한**이 있어 저장소가 `addons/`로 커지면 깨진다. 절차를 설계하지 않고 넘기는 것에 가깝다 |

**🔁 재검토 조건**: ① 고객사가 workbench의 GitHub 아웃바운드를 금지 → S3 안 ·
② seed 외에 workbench가 저장소를 **상시** 읽을 요구가 생김(지금은 부트스트랩 시점 한정이라
상시 자격증명이 없다) · ③ GitOps 저장소가 여러 개로 갈려 App 하나로 못 덮을 때.

---

## 3. 도달 경로

```mermaid
flowchart LR
  subgraph laptop["운영자 노트북 / 고객사 단말"]
    cli["aws ssm start-session"]
  end

  subgraph aws["AWS 관리 평면 (VPC 밖)"]
    ssm["SSM Service"]
  end

  subgraph vpc["고객사 VPC"]
    subgraph priv["private 서브넷 (NAT 경유)"]
      workbench["ec2-…-workbench-01<br/>SSM Agent · kubectl · helm"]
    end
    subgraph nodesub["노드 서브넷"]
      api["EKS apiserver ENI<br/>endpoint_public_access = false"]
    end
    nat["NAT GW"]
  end

  cli -->|"① 세션 요청 (IAM 인증)"| ssm
  workbench -->|"② 아웃바운드 폴링 443"| nat --> ssm
  ssm -.->|"③ 세션은 ②의 연결을 역방향으로"| workbench
  workbench -->|"④ kubectl / helm 443"| api
```

**핵심**: ①과 ②는 **별개 방향**이며, workbench으로 들어오는 인바운드 연결은 존재하지 않는다.
③이 성립하는 것은 ②가 이미 열어 둔 연결 위를 세션이 흐르기 때문이다 — 이것이 인바운드 SG 규칙 0개로
셸에 진입할 수 있는 이유다.

④가 성립하려면 **세 층이 모두** 필요하다. 그 소유는 §5가 정한다.

> ⚠️ **PoC가 여기서 한 번 틀렸다** — 앞의 두 층만 갖추고 SG를 빠뜨려 `dial tcp …: i/o timeout`이 났다.
> 🔑 **증상이 인증 오류가 아니라 타임아웃이었다는 것이 단서다** — 인증 계층에 닿지도 못했다는 뜻이다.
> 진단은 **증상의 계층을 먼저 특정하고 그 계층만 의심한다**(원문: [`../reference/poc-findings.md`](../reference/poc-findings.md)).

---

## 4. 모듈 계약 — `modules/workbench`

### 4.1 variables

```hcl
# ── 정체성 (파라미터화 — 01 §4 재사용 자산 요건) ─────────────────────────
variable "naming"  { type = object({ workload = string, env = string, region_code = string }) }
variable "purpose" { type = string, default = "workbench" }
variable "serial"  { type = string, default = "01" }
variable "tags"    { type = map(string), default = {} }

# ── kill switch (D-WORKBENCH-LIFECYCLE) ────────────────────────────────────
variable "workbench_enabled" { type = bool, default = true }

# ── 배치 (D-WORKBENCH-PLACEMENT) ───────────────────────────────────────────
variable "vpc_id"    { type = string }
variable "subnet_id" { type = string }   # private 서브넷 전제(§2.2). 모듈은 검사하지 않는다

# ── 인스턴스 (D-WORKBENCH-AMI-PIN) ─────────────────────────────────────────
variable "ami_id"        { type = string }                      # ⭐ 기본값 없음 = 필수 입력
variable "instance_type" { type = string, default = "t4g.small" } # ⚠️ ami_id 의 아키텍처와 정합할 것
variable "root_volume_size" { type = number, default = 10 }
variable "root_volume_kms_key_id" { type = string, default = null } # null = AWS 관리형 키

# ── 도구 (user_data) ─────────────────────────────────────────────────────
variable "kubectl_version" { type = string, default = null }  # null = 미설치. 예: "v1.35.7"
variable "helm_version"    { type = string, default = null }  # null = 미설치. 예: "v3.21.3" (핀 SSOT 는 23 §5)
variable "argocd_version"  { type = string, default = null }  # null = 미설치. 예: "v3.5.0"  (핀 SSOT 는 23 §5)
# git 은 변수가 없다 — 항상 설치한다(D-WORKBENCH-REPO §2.5). 근거는 바로 아래.

# ── 진단·조작 도구 (D-WORKBENCH-TOOLING §4.3-2, 2026-08-11) ────────────────
variable "eks_node_viewer_version" { type = string, default = null } # null = 미설치. 예: "v0.7.4"
variable "krew_version"            { type = string, default = null } # null = 미설치. 예: "v0.5.0"
variable "krew_plugins" {                                            # krew_version 이 null 이면 무시된다
  type    = list(string)
  default = ["ctx", "ns", "neat", "rbac-tool", "view-secret", "whoami"]
}

# ── EKS 연동 — 1층만 (D-WORKBENCH-SEAM) ────────────────────────────────────
variable "eks_cluster_name" { type = string, default = null }  # null 이면 kubeconfig 생성 안 함
variable "eks_cluster_arn"  { type = string, default = null }  # eks:DescribeCluster 를 이 ARN 으로 한정

# ── egress (D-WORKBENCH-EGRESS) ────────────────────────────────────────────
variable "egress_cidr_blocks" { type = list(string), default = ["0.0.0.0/0"] } # 443/tcp
```

> ### ⭐ **`git`은 왜 nullable 핀이 아닌가** — 비대칭이 실수가 아니라는 기록 (2026-08-07)
>
> `kubectl_version`·`helm_version`이 nullable 핀인 이유는 **버전이 다른 것과 결합**되기 때문이다 —
> `kubectl`은 **클러스터 마이너**에, `helm`은 **차트**([`23 §5`](23-argocd-self-managed.md))에 묶인다.
> 소비자가 골라야 할 실제 값이 있다.
>
> **`git`은 둘 다 아니다.** `dnf`가 주는 배포판 패키지(`git-core`)라 **핀할 값이 없고**,
> 크기도 수 MB다. 여기에 `install_git = bool`을 두면 **선택지 없는 분기**가 하나 생긴다 —
> [열린 항목 6](#10-열린-항목)의 *"분기가 계약을 흐린다"* 에 정확히 해당한다.
> ⇒ **변수 없이 항상 설치한다.** 같은 패턴을 기계적으로 복사하지 않는 것이 이 판단의 요지다.
>
> ⚠️ 이것은 **계약이 넓어지는 변경이 아니다**(입력이 늘지 않는다). 그래도 산출물이 달라지므로
> `workbench` 마이너를 컷한다.

> ### ⭐ **`argocd` CLI는 왜 nullable 핀인가** — 그리고 왜 도구 3개를 일반화하지 않는가 (2026-08-10)
>
> **`git`과 정반대 이유로 변수가 필요하다.** `argocd` CLI의 버전은 **chart `appVersion`에 결합**된다
> ([`23 §5`](23-argocd-self-managed.md)가 핀의 SSOT: chart `argo-cd 10.3.0` ↔ `v3.5.0`). 서로 다른
> 값을 쓰면 *"UI에서 되는데 CLI에서 안 된다"* 를 진단할 근거가 사라진다. **소비자가 고를 실제 값이
> 있으므로** `kubectl_version`·`helm_version`과 같은 nullable 핀이다.
> ⚠️ **chart를 올리면 CLI 핀도 같이 올린다** — CI와 로컬 훅의 도구 버전을 맞추는 규율과 같다.
>
> **왜 두는가 — "로그인해서 쓴다"가 아니다.** 근거가 둘이다:
> - **`30` 판정 ③**: cluster Secret이 내장 `in-cluster`를 **대체하는가 중복인가**.
>   ✅ **2026-08-10 종결** — `argocd admin cluster stats -n argocd`로 닫았다(§7.3-4).
>   ⭐ `argocd admin` 계열은 **API 서버가 아니라 k8s를 직접 읽으므로 port-forward도 login도 없다.**
> - **`23 §2.3` 완료 조건**: `argocd account update-password`로 초기 비밀번호를 교체한다.
>   단, 아래 정정을 함께 읽는다.
>
> > ### 🔴 **정정 — "CLI가 port-forward·대화형 세션 의존을 없앤다"는 틀렸다** (2026-08-10 실측)
> >
> > 최초 서술은 *"CLI가 없으면 port-forward + 대화형 SSM 세션이 필요한데 CLI가 그 의존을 없앤다"* 였다.
> > **두 군데가 틀렸다. 이 서술을 되살리지 말 것.**
> >
> > | 주장 | 실측 |
> > |---|---|
> > | *"CLI가 port-forward를 없앤다"* | ❌ **`argocd-server`는 `ClusterIP`다**(실측 `172.20.144.3`). workbench는 클러스터 **밖** 호스트라 **CLI가 있어도 port-forward가 필요하다.** 없어지는 것은 `argocd admin` 계열뿐이다 |
> > | *"`send-command`로는 터널이 서지 않는다"* | ❌ **선다.** 백그라운드 `kubectl port-forward` + 같은 스크립트에서 CLI 호출로 `argocd-server: v3.5.0` 응답을 받았다. 원래 이 문장은 **운영자 노트북까지의 터널**을 두고 한 말이었고 **인스턴스 로컬 루프백에는 해당하지 않는다** |
> >
> > ⭐ **CLI가 실제로 없애는 것**: ① `argocd admin` 계열은 port-forward 자체가 불필요하다 ·
> > ② 비밀번호 교체가 **브라우저 UI 없이, 인스턴스 안에서** 끝난다 — port-forward가
> > **운영자 노트북까지 가지 않고 로컬 루프백으로 축소**된다.
> >
> > ⛔ **그럼에도 비밀번호 교체는 대화형 세션으로 한다.** 이유는 **기술 제약이 아니라 비밀 취급**이다 —
> > 새 비밀번호를 `send-command` 파라미터에 실으면 **평문으로 CloudTrail·명령 히스토리에 남는다**
> > (D-KEY-TRANSFER가 키를 그렇게 보내지 않은 것과 같은 이유).
> > 🔑 **"기술적으로 가능하다"와 "그렇게 해도 된다"를 구분한다.**
>
> ⚠️ **관리형으로 전환하면 사용법이 달라진다**([`21 §1.2 ⑥`](21-gitops-bootstrap-seam.md)):
> `argocd login` 미지원(계정·프로젝트 토큰) · `argocd admin` 미지원 · `--grpc-web` 필수 ·
> 앱 지정에 namespace 접두. **지금(self-managed)은 `login`이 되지만 절차서를 `login` 전제로 쓰지
> 않는다** — 전환할 때 절차 전체를 다시 써야 하기 때문이다.
>
> ### 📌 **도구가 3개가 되어도 일반화하지 않는다**
>
> | 도구 | 배포 형태 |
> |---|---|
> | `kubectl` | `dl.k8s.io` **단일 바이너리** |
> | `helm` | `get.helm.sh` **tarball**(해제 후 `linux-<arch>/helm`) |
> | `argocd` | **GitHub Releases 단일 바이너리**(`argocd-linux-<arch>`) |
>
> 셋의 URL 조립·설치 절차가 **전부 다르다.** `{name → url_template}` 맵으로 묶으면 템플릿 안에
> tarball 분기가 도로 생겨 **분기가 줄지 않고 한 겹 숨는다** — 열린 항목 6의 *"분기가 계약을 흐린다"* 와
> 같은 이유로 **명시 블록을 유지**한다. 🔑 반복처럼 보이는 것과 실제 공통 구조는 다르다.

> **교차변수 validation** — `eks_cluster_name`과 `eks_cluster_arn`은 **함께 주거나 함께 비운다.**
> 한쪽만 주면 kubeconfig는 만들어지는데 권한이 없거나(이름만), 권한은 있는데 kubeconfig가 없다(ARN만).
> D-EXTDNS-ZONE([`20 §4.2`](20-eks-module.md))과 같은 형태의 가드를 건다.
>
> ⭐ **거기서 배운 것을 그대로 적용한다**: 가드에 **`&& var.workbench_enabled`를 함께 넣는다.**
> 빠뜨리면 kill switch를 끄는 **파기 경로의 plan이 거부**되어 반쪽 토글이 된다.
> 설계 조건식을 그대로 옮기지 않고 선례를 먼저 찾는 것이 차이를 만들었던 지점이다.

### 4.2 리소스 구성과 하드닝

| 리소스 | `Name` | 비고 |
|--------|--------|------|
| `aws_instance` | `ec2-<w>-<e>-<r>-workbench-01` | 아래 하드닝 4종이 **계약**이다 |
| `aws_security_group` | `sgr-<w>-<e>-<r>-workbench-01` | **ingress 규칙 0개** |
| `aws_vpc_security_group_egress_rule` | `sgr-…-workbench-01-egress-https` | 443/tcp 1건만. SSM·패키지·차트 저장소가 전부 HTTPS다 |
| `aws_iam_role` | `iamr-<w>-<e>-<r>-workbench-01` | 관리형 `AmazonSSMManagedInstanceCore` 1개 |
| `aws_iam_role_policy`(inline) | `iamr-…-workbench-01-eks-policy` | `eks:DescribeCluster` **`eks_cluster_arn` 한정**. `eks_cluster_arn = null`이면 생성 안 함 |
| `aws_iam_instance_profile` | `iamr-…-workbench-01` (role과 **동일명**) | 아래 상자 |
| root EBS 볼륨 | `vol-<w>-<e>-<r>-workbench-01` | gp3, `encrypted = true` |

> **인스턴스 프로파일에 새 약어를 만들지 않는다.** 카탈로그([`../reference/aws-naming-abbreviations.md`](../reference/aws-naming-abbreviations.md))에
> 인스턴스 프로파일 약어는 **없다**. 임의 생성 금지(CLAUDE.md)이므로 남은 선택지는 둘이었다 —
> 물어서 등재하거나, 기존 규약으로 처리하거나.
>
> 🔑 **2026-07-30에 신설된 「종속 객체는 약어를 새로 만들지 않고 부모 이름을 상속한다」 규약이 이미 답이다.**
> 인스턴스 프로파일은 role 없이 존재할 수 없고 콘솔·API에서도 role과 짝으로 다뤄진다.
> IAM에서 role과 instance profile은 **별개 네임스페이스**라 같은 이름이 충돌하지 않는다.
> → **카탈로그 변경 없음.** (PoC도 같은 처리를 했으나, 당시엔 근거가 될 규약이 아직 없었다.)

**하드닝 4종 — 변수로 열지 않는다**(§2.1의 "모듈의 값"):

- `metadata_options`: `http_tokens = "required"`(**IMDSv2 강제**), `http_put_response_hop_limit = 1`
- `root_block_device`: `encrypted = true`, `volume_type = "gp3"`
- `key_name` 미지정 — SSH 키페어를 만들지 않는다(D-WORKBENCH-ACCESS)
- `associate_public_ip_address` 미지정 — private 서브넷 전제(§2.2)

> ⚠️ **hop limit 1은 컨테이너를 workbench에서 돌리면 IMDS가 막힌다는 뜻이다.** workbench는 도구를
> 호스트에서 직접 실행하는 지점이므로 지금 요구에는 맞다. docker/nerdctl로 무언가를 돌리는 요구가
> 실제로 생기면 그때 변수를 연다 — **추측으로 미리 열지 않는다**(CLAUDE.md 작업 원칙).

### 4.3 user_data

`git`을 **항상** 설치하고(§2.5), `kubectl`·`helm`·`argocd` 바이너리를 **명시 핀 버전**으로 설치하며,
`eks_cluster_name`이 있으면 kubeconfig를 시스템 전역(`/etc/kubernetes/kubeconfig` + `/etc/profile.d`)에
생성한다.

> **`argocd`는 tarball이 아니라 단일 바이너리다** — `helm` 블록을 복사하면 안 된다.
> `curl -o` → `install -m 0755` 로 끝이며 해제·중간 디렉토리 정리가 없다. 실측(2026-08-06·08-10):
> `https://github.com/argoproj/argo-cd/releases/download/<ver>/argocd-linux-<arch>` — `arm64`·`amd64`
> 둘 다 `200`. arm64(`t4g` 계열)에서 동작한다 — 2026-08-10 apply 로 실물 설치까지 확인했다.
>
> ⚠️ **부팅 로그의 `argocd version --client` 는 `$HOME is not defined` 로 fatal 을 찍는다**(실측).
> **설치 실패가 아니다** — 바이너리는 `/usr/local/bin/argocd` 에 정상으로 놓인다. cloud-init 에는
> `$HOME` 이 없어 CLI 가 설정 경로를 못 정하는 것뿐이다. 로그만 보면 실패로 오독하므로
> 검증 호출에 `HOME=/root` 를 붙인다.

> ## 🔴 **D-WORKBENCH-SIZE — 기본 타입은 `t4g.small`이다** (2026-08-10, 사용자 결정)
>
> **최초 기본값 `t4g.nano`(RAM 512MB)는 실패한다.** `workbench-v0.3.0` 첫 apply 에서
> `dnf install -y git-core`가 **부팅 중 OOM-killer 에 죽었다**(실측, 인스턴스 `i-0c3be7c…`):
>
> ```
> oom-kill: task_memcg=/system.slice/cloud-final.service, task=dnf
> Out of memory: Killed process 1656 (dnf) total-vm:976324kB
> ```
>
> - ⚠️ **`free -m`의 swap 417MB 는 여유가 아니다.** 실물은 **`/dev/zram0`** — RAM 을 압축해 쓰는
>   것이라 **용량이 늘지 않는다.** "swap 이 있는데 왜 죽나"로 오독하기 쉬운 지점이다.
> - 🔑 **`dnf` 하나가 vm 976MB 를 요구한다.** 1GB(`t4g.micro`)면 부팅은 통과하겠지만
>   helm 렌더링·`kubectl`·로그 조회가 겹치는 **실제 운영**에서 다시 아슬아슬해진다.
>   **부팅만 통과시키는 크기는 "적정"이 아니다.**
> - ⭐ **재사용 자산의 기본값은 고객사가 그대로 써도 안전해야 한다.** 기본값이 아슬아슬하면
>   부팅 실패를 **고객사가** 겪는다 — 이 repo 산출물의 성격상 그 비용은 우리가 아니라 그쪽이 낸다.
>
> ⛔ **swapfile·재시도 같은 우회를 먼저 짜지 않는다.** 사용자 결정: *"비용만 생각하지 말고
> 적정한 인스턴스 타입으로 전환도 고려하라."* 우회는 메커니즘을 늘리고 근본은 남긴다.
>
> | 타입 | RAM | 월(Seoul, on-demand 실측) | 판정 |
> |---|---|---|---|
> | `t4g.nano` | 0.5GB | $3.8 | ❌ dnf OOM(실측) |
> | `t4g.micro` | 1GB | $7.6 | 부팅은 통과, 운영 여유 없음 |
> | **`t4g.small`** | **2GB** | **$15.2** | ✅ **채택** |
> | `t4g.medium` | 4GB | $30.4 | 현재 용도엔 과하다 |
>
> ⚠️ **`§2.4`(D-WORKBENCH-SCOPE)의 *"`t4g.nano` 급으로 충분"* 은 이 결정이 대체했다.**
> 그 판단은 *"빌드 부하가 없다"* 만 봤고 **패키지 관리자의 메모리 요구를 계산하지 않았다.**
> 겸용하지 않는다는 결론 자체는 그대로 유효하다 — 틀린 것은 크기 근거뿐이다.

> **⚠️ 다운로드 경로는 `/tmp`가 아니라 `/var/tmp`다 — 승계된 함정 중 가장 값진 것**
>
> PoC에서 `t4g.nano`(RAM 512MB)의 **tmpfs가 210MB**라 바이너리 두 개를 연속으로 받다가
> `curl: (23) Failure writing output to destination`으로 죽었다. HTTP는 전부 200이었다.
> 🔑 **"먼저 받은 것이 공간을 먹는 순서 의존"** 이라 수동 재시도도 실패한다.
> → `/var/tmp`(루트 EBS)로 받고 `install` 직후 원본을 삭제한다.
>
> ⚠️ **D-WORKBENCH-SIZE 로 이 함정의 성격이 바뀌었다**(2026-08-10). `t4g.small`(2GB)에서 `/tmp` 는
> 약 1GB라 **바이너리 3개로는 더 이상 터지지 않는다.** 그래도 `/var/tmp` 를 유지한다 —
> 소비자가 `instance_type` 을 내리면 함정이 그대로 돌아오고, `/var/tmp` 는 그때도 옳다.
> 🔑 **근거가 "필수"에서 "안전"으로 바뀐 것이지 결론이 바뀐 것이 아니다.**
>
> 이 함정은 **`instance_type` 을 소비자가 작게 내리는 한 계속 유효**하다. 실측 원문은
> [`../reference/poc-findings.md`](../reference/poc-findings.md).

- `curl --retry-all-errors`를 유지한다. tmpfs 문제의 해법은 아니지만 부팅 초기 일시적 네트워크 실패를
  흡수한다(`curl --retry`는 연결 실패만 재시도하고 HTTP 오류·DNS 실패는 재시도하지 않는다).
- `aws eks update-kubeconfig`는 **재시도로 감싼다.** IAM 인라인 정책 생성 직후 인스턴스가 부팅하면
  전파 지연으로 권한 오류가 날 수 있다. **Terraform에 `time_sleep`을 넣기보다 부팅 스크립트가 스스로
  견디는 편**이 재생성마다 반복되는 이 상황에 맞다.

### 4.3-1 ⭐ **D-WORKBENCH-KUBECONFIG — 정본은 읽기 전용, 사용자마다 자기 사본** (2026-08-11 확정)

[열린 항목 8](#10-열린-항목)이 미결로 둔 것을 닫는다. ⚠️ **그 항목의 전제부터 틀렸으므로 함께 정정한다.**

#### 🔴 정정 — kubeconfig 는 **없지 않았다**

| 열린 항목 8 서술 | 실측 (2026-08-11, workbench SSM) |
|---|---|
| *"workbench 어디에도 kubeconfig 가 없었다(`find` 전수 0건)"* | 🔴 **틀렸다.** `/etc/kubernetes/kubeconfig` 가 **있었고**, 부팅 로그에 `update-kubeconfig 시도 1` → `kubeconfig 생성 완료` 가 남아 있다 |
| *"선택지 ⓐ user_data 실행 → §5.1-1 순환을 다시 부른다"* | 🔴 **ⓐ는 이미 구현돼 있고 동작했다.** `eks_cluster_name` 은 소비자 입력이라 순환은 **결정적 네이밍으로 이미 끊겨 있다**(§5.1-1 이 의도한 대로) |

🔑 **어떻게 틀렸나**: 홈 디렉토리만 확인했거나, **비로그인 셸에서 `kubectl` 이 실패한 것을 "kubeconfig 없음"으로 오독**했다.
⛔ 2026-08-11 세션에서 **같은 오독이 반복됐다** — `ls /home/ec2-user/.kube` 실패 하나로 "없다"고 확정하고
`/root/.kube/config` 를 손으로 만들어 **사본을 하나 더 늘렸다.** 열린 항목 8 이 경계한 그 행위 자체다.

#### 🔴 진짜 결함은 셋이고, 전부 **"설치"가 아니라 "누가 쓸 수 있나"** 의 문제였다

| # | 결함 | 실측 |
|---|---|---|
| 1 | **비로그인 셸에 전달되지 않는다** | `/etc/profile.d/*.sh` 는 **로그인 셸에서만** 실행된다. 대화형 SSM 세션(`ssm-user`)은 `KUBECONFIG` 를 받지만, **SSM RunShellScript(자동화)는 못 받는다** ⇒ `kubectl` 이 `localhost:8080` 으로 붙는다 |
| 2 | 🔴 **공유 정본이 쓰기 가능해져 전역 오염** | 실물이 **`-rw-rw-rw-`(0666, world-writable)** 였고 기본 네임스페이스가 `argocd` 로 **바뀌어 있었다**. `kubectl config set-context` 한 번이 **모든 사용자**에게 반영된다 |
| 3 | 손으로 만든 사본이 는다 | `/root/.kube/config` (위 오독의 산물) |

> ### ⛔ **2번은 편의 문제가 아니라 보안 문제다**
> kubeconfig 는 `users[].user.exec` 로 **임의 명령**을 지정할 수 있다(EKS 는 실제로 `aws eks get-token` 을 쓴다).
> world-writable kubeconfig 는 그 자리에 다른 명령을 심을 수 있다는 뜻이고,
> 그것을 root 가 쓰는 순간 **로컬 권한 상승 경로**가 된다.

#### 결정 — **정본 `0444` + `/etc/skel` 상속 + 사용자별 `0600` 사본**

```
① aws eks update-kubeconfig → /etc/kubernetes/kubeconfig   (정본)
② chmod 0444                                               ← 아무도 못 쓴다
③ /etc/skel/.kube/config 에 복사 (0600)                    ← 아직 없는 사용자에게 상속
④ 이미 존재하는 홈(root·ec2-user)에 복사 + chown (0600)
⑤ /etc/profile.d/kubeconfig.sh 는 만들지 않는다
```

> ### ⭐ **`/etc/skel` 이 핵심이다 — `ssm-user` 는 user_data 시점에 존재하지 않는다**
>
> **실측**: 부팅 `03:49:28` · user_data 완료 `03:50:11` · **`/home/ssm-user` 생성 `06:26:37`**
> — **2시간 37분 뒤**다. SSM Agent 가 **첫 세션에서** `useradd -m` 으로 만든다.
> ⇒ user_data 는 *"그 사용자의 홈"* 에 아무것도 놓을 수 없다. 그래서 원래 설계가 `/etc/profile.d`
> 전역 export 를 택한 것이고, **그 판단은 합리적이었다** — 다만 결함 1·2를 남겼다.
> 🔑 **`/etc/skel` 은 "아직 없는 사용자"에게 파일을 넘기는 표준 장치다.** `useradd -m` 이 복사한다
> (실증: `.bashrc`·`.bash_profile`·`.bash_logout` 3종이 `ssm-user` 홈에 그대로 상속돼 있다).

#### ⛔ 기각한 대안

| 안 | 기각 근거 |
|---|---|
| **전용 사용자 신설** (*"root 로 실행하지 않게"*) | SSM 대화형은 **항상 `ssm-user`**, RunShellScript 는 **항상 root** 로 붙는다. 새 사용자를 만들어도 **아무도 그 사용자로 들어오지 않는다.** ⚠️ 게다가 `ssm-user` 는 `/etc/sudoers.d/ssm-agent-users` 에 **`NOPASSWD:ALL`**(실측)이라 이미 root 와 동등하다 — **root 회피가 보안 경계를 만들지 못한다.** ⇒ 바꿀 수 있는 것은 *"누가 실행하나"* 가 아니라 **"산출물이 누구 것이 되나"** 다 |
| **홈에 심볼릭 링크**(공유 정본 1개) | 갱신 지점은 1곳이지만 **컨텍스트 변경이 그대로 전역 오염**이다 — 결함 2가 구조적으로 반복된다. `0444` 로 막으면 `kubectl config set-context` 자체가 실패해 일상 조작이 불편해진다 |
| **`/etc/profile.d` 유지 + 사본 병행** | `KUBECONFIG` 환경변수가 `$HOME/.kube/config` 보다 **우선**하므로 사본을 만들어도 **다시 공유본을 가리킨다.** ⇒ 남기면 사본이 죽은 경로가 된다(CLAUDE.md *"죽은 경로를 남기지 않는다"*) |

#### ⚠️ 이 결정이 닫지 **못하는** 것 — 비로그인 셸

`$HOME` 자체가 없는 실행 경로(SSM RunShellScript)는 **user_data 로 닫을 수 없다.**
`/etc/profile.d` 도 `/etc/environment` 도 읽히지 않는다. ⇒ **자동화 규약으로 닫고 §6 에 적는다**:

```bash
export HOME=/root
export KUBECONFIG=/root/.kube/config
```
⚠️ `argocd` CLI 는 `HOME` 이 없으면 **`$HOME is not defined` 로 죽는다**(2026-08-10·08-11 두 번 실측).

### 4.3-2 ⭐ **D-WORKBENCH-TOOLING — `eks-node-viewer` · `krew` 플러그인 · 로그인 프로파일** (2026-08-11 사용자 요청)

#### 무엇을 넣는가

| 항목 | 값 | 계약 |
|---|---|---|
| `eks-node-viewer` | `v0.7.4`(실측 최신) | **nullable 핀** — 기존 3종과 같은 계약 |
| `krew` | `v0.5.0`(실측 최신) | **nullable 핀** |
| krew 플러그인 | `ctx` `ns` `neat` `rbac-tool` `view-secret` `whoami` | **`krew_plugins` 변수, 기본값 = 이 6개.** ⚠️ `krew_version = null` 이면 무시된다 |
| 로그인 프로파일 | `k` alias · `nv` alias · kubectl 완성 · `AWS_DEFAULT_REGION` | **변수 없음** — 아래 |

⛔ **`AWS_DEFAULT_REGION` 을 하드코딩하지 않는다.** `data.aws_region.current.region` 이 이미
템플릿에 주입돼 있다(`${region}`). 리전 이식성은 이 모듈의 계약이다(CLAUDE.md 재사용 자산 요건).

#### 🔴 결정 1 — **`krew` 는 `KREW_ROOT` 로 시스템 설치한다. `$HOME/.krew` 가 아니다**

krew 의 기본 설치 위치는 **`$HOME/.krew`** 다. user_data 는 root 로 도니 **`/root/.krew` 에 갇힌다** —
**[§4.3-1](#43-1--d-workbench-kubeconfig--정본은-읽기-전용-사용자마다-자기-사본-2026-08-11-확정)이 방금 고친 문제의 재발**이다.

⇒ **`KREW_ROOT=/usr/local/krew`** 로 설치하고 `chmod -R a+rX` 한다. `PATH` 에 `$KREW_ROOT/bin` 을 더한다.
- 🔑 **플러그인은 *상태* 가 아니라 *바이너리* 다.** kubeconfig 와 반대로 **공유가 옳다** — 사용자마다
  복제할 이유가 없고, 복제하면 갱신 지점만 늘어난다.
- ⚠️ 사용자가 플러그인을 **추가**하려면 root 가 필요하다: `sudo KREW_ROOT=/usr/local/krew kubectl krew install <x>`.
  `ssm-user` 는 `NOPASSWD:ALL` 이라(§4.3-1 실측) 막히지 않는다.
- 📌 부팅 중에는 `PATH` 를 쓰지 않고 **`$KREW_ROOT/bin/kubectl-krew` 를 직접 호출**한다 —
  `kubectl krew` 는 PATH 탐색에 의존하는데 그 PATH 는 아직 우리가 만들지 않았다.

#### 🔴 결정 2 — **`/etc/profile.d` 를 다시 쓴다. §4.3-1 과 모순이 아니다**

§4.3-1 은 `/etc/profile.d/kubeconfig.sh` 를 **없앴는데** 여기서 프로파일 파일을 **만든다.**
모순처럼 보이지만 **가르는 기준이 있다**:

| 성격 | 예 | 배치 | 이유 |
|---|---|---|---|
| **상태(state)** | kubeconfig | **사용자별 사본** | 사용자가 **바꾼다**(`kubectl config set-context`). 공유하면 한 사람의 변경이 전원에게 간다 |
| **설정(configuration)** | alias · `PATH` · `KREW_ROOT` · `AWS_DEFAULT_REGION` | **전역 `/etc/profile.d`** | 사용자가 바꿀 이유가 없고, 사용자별 사본을 두면 **갱신 지점만 늘어난다** |

🔑 **§4.3-1 이 `profile.d` 를 없앤 진짜 이유는 "전역이라서"가 아니다** — `KUBECONFIG` 환경변수가
`$HOME/.kube/config` 보다 **우선해서 사용자별 사본을 무력화하기** 때문이다.
⇒ ⛔ **금지되는 것은 `profile.d` 자체가 아니라 "공유 정본을 `KUBECONFIG` 로 전역 export 하는 것"** 이다.
⚠️ **T-12 의 음성 판정이 이 구분보다 넓었다** — `> /etc/profile.d/` 자체를 금지했다. **좁힌다**(§7.1).

#### 🔴 결정 3 — 요청 스니펫의 **결함 1건을 고쳐서 넣는다**

요청 원문은 `complete -o default -F __start_kubectl k` 인데, 그 함수는
**`source <(kubectl completion bash)` 가 정의**한다. 없으면 alias `k` 에 완성이 붙지 않는다.

> ### ⚠️ **그런데 실측상 에러가 나지 않는다 — 그래서 더 위험하다**
> `complete -F <없는함수> k` 는 bash 가 **조용히 받아들인다**(실측: 출력 0).
> ⇒ *"설정했는데 안 되는"* 상태가 **아무 신호 없이** 남는다.
> 🔑 오늘 반복된 그 범주다 — **실패가 조용하면 아무도 고치지 않는다.**

- ✅ `bash-completion` 은 **AL2023 에 기본 설치**돼 있다(실측 `2.11-2.amzn2023.0.2`) — 패키지를 더 넣지 않는다.
- 각 줄은 **해당 도구가 설치될 때만** 프로파일에 들어간다(`nv` 는 eks-node-viewer, 완성은 kubectl).
  ⛔ **이를 위해 새 변수를 만들지 않는다** — 이미 있는 nullable 핀이 조건이다(§4.1 *"선택지 없는 분기"* 회피).

생성되는 `/etc/profile.d/workbench.sh`:

```bash
export AWS_DEFAULT_REGION=<region>            # 항상
export KREW_ROOT=/usr/local/krew              # krew_version != null 일 때
export PATH="$PATH:$KREW_ROOT/bin"            #  〃
alias k=kubectl                               # kubectl_version != null 일 때
source <(kubectl completion bash)             #  〃  ← 이것이 __start_kubectl 을 정의한다
complete -o default -F __start_kubectl k      #  〃
alias nv='eks-node-viewer --resources cpu,memory'   # eks_node_viewer_version != null 일 때
```

#### ⚠️ 아키텍처 이름이 **도구마다 다르다** — 네 번째 배포 형태

| 도구 | 배포 형태 | arm64 자산 이름 |
|---|---|---|
| `kubectl` | 단일 바이너리 | `.../linux/arm64/kubectl` |
| `helm` | tarball | `helm-<v>-linux-arm64.tar.gz` |
| `argocd` | 단일 바이너리 | `argocd-linux-arm64` |
| 🆕 `eks-node-viewer` | 단일 바이너리 | **`eks-node-viewer_Linux_arm64`** · x86 은 **`_Linux_x86_64`** ← ⚠️ `amd64` **아님** |
| 🆕 `krew` | tarball | `krew-linux_arm64.tar.gz`(안에 `krew-linux_arm64` 실행파일) |

⇒ **`$ARCH`(arm64/amd64) 하나로 다 못 만든다.** eks-node-viewer 전용 매핑을 따로 둔다.
📌 §4.1 상자가 *"세 도구의 배포 형태가 전부 달라 블록을 합치지 않는다"* 고 한 근거에
**이름 규칙 축이 하나 더 붙었다** — 맵으로 묶으려는 시도를 다시 기각하는 근거다.

#### ✅ egress — 새 축이 아니다 (실측)

`eks-node-viewer`·`krew` 릴리스와 `krew-index` 원문 3종 전부 **HTTP 200**(workbench 에서 직접 확인).
전부 `github.com` / `raw.githubusercontent.com` 이고, `argocd` CLI 가 이미 같은 경로를 쓴다.

### 4.4 outputs

| 출력 | 설명 |
|------|------|
| `workbench_instance_id` | `aws ssm start-session --target <id>`에 그대로 사용 |
| `workbench_security_group_id` | ⭐ **`eks-cluster`의 SG 규칙 소스로 넘긴다**(§5) |
| `workbench_iam_role_arn` | ⭐ **`eks-cluster`의 Access Entry principal로 넘긴다**(§5) |
| `workbench_private_ip` | 도달성 진단용 |

> `workbench_enabled = false`면 위 출력은 전부 `null`이다 — `eks-cluster` 쪽 조립이
> `try()`/조건식 없이 깨지지 않도록 예제가 그 형태를 보여준다.

---

## 5. ⭐ D-WORKBENCH-SEAM — EKS 접근 3층을 누가 소유하는가

workbench가 apiserver에 닿으려면 세 층이 **모두** 성립해야 한다. PoC는 셋을 전부 workbench 컴포넌트가
소유했다(`D-BASTION-K8S`). **이 repo에서는 그렇게 하지 않는다.**

| 층 | 무엇을 결정하나 | 없으면 나타나는 증상 | **소유** |
|----|----------------|---------------------|---------|
| ① IAM `eks:DescribeCluster` | kubeconfig를 **만들 수 있는가** | `update-kubeconfig` 권한 오류 | **`modules/workbench`** |
| ② Access Entry + 정책 | 클러스터 **안에서** 무엇을 하는가 | `401 Unauthorized` | **`modules/eks-cluster`** (`access_entries`) |
| ③ cluster SG ingress 443 | apiserver에 **네트워크로 닿는가** | `dial tcp …: i/o timeout` | **`modules/eks-cluster`** (신설 변수) |

### 5.1 가르는 기준 — 주체냐 대상이냐

**①은 workbench의 권한이고, ②③은 클러스터가 누구를 받아들이는가다.**

- ①은 workbench role에 붙는 인라인 정책이다. 대상 리소스(cluster ARN)를 **참조만** 할 뿐,
  클러스터 쪽에 아무것도 만들지 않는다. → 주체 소유.
- ②③은 클러스터 쪽 리소스다. [`03 §2.3`](../architecture/03-dependencies.md)이 이미 답을 준다:
  > *"cross-SG 참조는 rule 소유권을 쪼개지 말고 (…) 공유 SG에 외부 규칙 기여가 필요하면,
  > **소유 모듈이 허용 소스 목록을 변수로 파라미터화**해 owner가 rule을 생성하게 한다."*

**PoC 방식을 철회하는 실질 이유 3가지**:

1. **의존 방향이 뒤집힌다.** workbench가 Access Entry를 만들면 `workbench → eks-cluster` 의존이 생긴다.
   그런데 실제 생성 순서는 반대다 — 클러스터가 먼저 있고 workbench가 나중에 붙는다.
2. **경쟁 SSOT가 생긴다.** `eks-cluster`는 이미 `access_entries`(type = any) 변수를 노출한다.
   workbench가 두 번째 경로를 만들면 *"이 클러스터의 접근 주체 목록을 어디서 보나"* 의 답이 둘이 된다.
3. **SG rule 소유자가 쪼개진다.** cluster SG의 rule을 두 모듈이 각자 붙이면 drift·충돌이 생긴다
   ([`03 §2.3`](../architecture/03-dependencies.md)).

⚠️ **잃는 것도 있다** — PoC 방식은 *"workbench를 파기하면 접근권도 함께 사라진다"* 는 이점이 있었다.
이 배치에서는 workbench를 지워도 **`eks-cluster` 쪽 Access Entry·SG rule이 남는다**(존재하지 않는 SG를
가리키는 rule은 apply에서 죽고, 존재하지 않는 role의 Access Entry는 조용히 남는다).
→ **예제가 둘을 같은 루트에 두어** `workbench_enabled = false`가 양쪽을 함께 비우는 형태를 보여준다.
이것이 §4.4가 출력을 `null`로 내려 보내는 이유다.

### 5.1-1 ⚠️ 이 배치는 **모듈 간 순환**을 만든다 — 결정적 네이밍이 끊는다

소유를 가르고 나면 참조가 양방향이 된다(2026-08-05 예제 작성 중 발견).

```
workbench.eks_cluster_arn        ← eks-cluster 의 클러스터 ARN
eks-cluster.access_entries     ← workbench 의 role ARN        ⟲ 순환
```

**해법은 [`03 §3.1`](../architecture/03-dependencies.md)의 1순위** — *"결정적 네이밍으로 값 구성"*
(결합도 **없음**). 클러스터 ARN은 이름·리전·계정으로 유도되므로 소비 루트가 **직접 합성**한다.

```hcl
locals {
  cluster_name = "eks-${var.workload}-${var.env}-${var.region_code}-main-01"
  cluster_arn  = "arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${local.cluster_name}"
}
# workbench → local 만 참조 (eks 출력 참조 없음)
# eks     → module.workbench 출력 참조
# ⇒ 단방향. 순환 없음.
```

🔑 **`03`의 조회 우선순위는 "느슨한 결합"만을 위한 것이 아니라 순환 해소 장치이기도 하다** —
SG rule을 별도 리소스로 분리해 순환을 푸는 §2.2와 **같은 역할을 값 층위에서** 한다.
소비 루트는 이미 같은 이유로 `cluster_name`을 local에 두고 VPC·EKS 두 모듈에 넘기고 있었다
([`20 §2.5`](20-eks-module.md)) — 그 패턴을 ARN으로 한 칸 넓힌 것뿐이다.

⛔ **workbench 모듈이 클러스터 이름에서 ARN을 스스로 합성하게 만들지 않는다.** 그러면 모듈이
계정·파티션을 조회해야 하고(`data.aws_caller_identity`·`aws_partition`), 무엇보다 **"이 workbench이
어느 클러스터를 보는가"가 모듈 내부 규칙에 숨는다.** 입력으로 받으면 소비 루트의 코드에 드러난다.

### 5.2 파급 — `eks-cluster` 계약이 늘어난다

②는 기존 `access_entries`로 **이미 가능**하다. **③에는 통과 경로가 없다.**

> 🔑 **또 하나의 "facade가 upstream을 가리는" 사례다.** upstream `terraform-aws-modules/eks` v21에는
> **`security_group_additional_rules`가 처음부터 있다**(`source_security_group_id` 지원 확인).
> upstream이 지원하지 않는 것이 아니라 **우리 wrapper가 넘기지 않고 있을 뿐**이다 —
> `ami_type`(D-NODE-ARCH)과 정확히 같은 형태다. 단정하고 우회를 짰다면
> workbench 모듈이 남의 SG에 rule을 붙이는 부채가 됐을 것이다.

**`20-eks-module.md` 개정에서 정할 것**(이 문서는 요구만 낸다):

- 변수 신설: cluster SG 추가 규칙 통과 (upstream `security_group_additional_rules` → facade 이름은 20이 정한다).
  facade 원칙상 **`cluster_` 접두를 붙여 node SG 쪽과 구분**하는 것을 권한다.
- **릴리스**: `eks-cluster-v0.3.0`. ⛔ `v0.2.0`은 **이미 소비자가 apply까지 마쳐 태그를 옮길 수 없다.**
- ⚠️ **함께 고칠 결함**: `modules/eks-cluster/outputs.tf`의 `cluster_security_group_id` 설명이
  *"EKS가 만든 클러스터 보안 그룹"* 이라고 적혀 있으나, 값은 **upstream 모듈이 만든 SG**다
  (EKS가 자동 생성하는 쪽은 `cluster_primary_security_group_id`이며 우리 모듈은 노출하지 않는다).
  **설명과 값이 다른 SG를 가리킨다** — workbench 규칙을 어디에 붙일지 판단할 때 정확히 오도하는 지점이다.

> ✅ **③이 upstream 경로로 실제 성립하는지 확인했다**: upstream은 `aws_security_group.cluster`를
> `vpc_config.security_group_ids`에 넣으므로 그 SG가 **apiserver ENI에 적용**된다.
> ⚠️ 단 upstream은 이 규칙을 **구형 `aws_security_group_rule`** 로 만든다 —
> [`03 §2.1`](../architecture/03-dependencies.md)이 *"신규 코드에서 미사용"* 이라 판정한 리소스다.
> **우리가 통제할 수 없는 upstream 내부**이므로 규약 위반으로 취급하지 않되, 이 어긋남을 §9-4에 남긴다.

---

## 6. 운영 절차

```bash
# 접속 (인바운드 없음 — IAM 인증만으로 셸에 들어간다)
aws ssm start-session --target <workbench_instance_id> --region <region>

# 클러스터 조작 — kubeconfig 는 **자기 홈의 사본**을 쓴다(D-WORKBENCH-KUBECONFIG, §4.3-1)
kubectl get nodes
helm upgrade --install <release> <chart> -n <ns>
```

> ### ⚠️ **자동화 경로(SSM RunShellScript)는 위와 다르다 — 스크립트가 스스로 열어야 한다**
>
> `ssm send-command` 로 실행되는 셸은 **비로그인 셸**이고 **`HOME` 이 아예 없다**(실측).
> `/etc/profile.d` 도 `/etc/environment` 도 읽히지 않으므로 `kubectl` 은 `localhost:8080` 으로 붙고,
> `argocd` CLI 는 **`$HOME is not defined` 로 죽는다**(2026-08-10·08-11 두 번 실측).
> ⇒ **자동화 스크립트의 첫 줄에 항상 넣는다**:
>
> ```bash
> export HOME=/root
> export KUBECONFIG=/root/.kube/config
> ```
>
> 📌 `--parameters` 는 **JSON 파일**로 준다 — 인라인 `commands=[...]` 축약형은 **개행을 뭉갠다**(실측).
> 📌 `argocd` CLI 를 클러스터에서 직접 쓰려면 `export ARGOCD_OPTS='--core'` 와
> **네임스페이스 지정**(`kubectl config set-context --current --namespace=argocd`)이 **둘 다** 필요하다.
> ⚠️ 같은 CLI 안에서도 네임스페이스를 받는 방식이 다르다 —
> `argocd admin initial-password` 는 `-n` 을 받고 `argocd account update-password` 는 **받지 않는다.**

**로컬 포트포워딩**(VPC 안 엔드포인트를 노트북 브라우저로 보는 경우):

```bash
aws ssm start-session --target <id> --region <region> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters host="<대상 호스트>",portNumber="443",localPortNumber="<로컬 포트>"
```

> ⚠️ **대상 서비스가 Host 헤더로 라우팅하면 로컬 포트를 443으로 맞춰야 한다.** PoC에서 `8443`으로
> 터널을 열었을 때 TLS는 통과하는데 HTTP만 404였다 — 브라우저가 비표준 포트를 **항상 Host에 포함**하기
> 때문이다(`sudo` 필요). 구체 사례와 실측은 [`../reference/poc-findings.md`](../reference/poc-findings.md).
> **어떤 서비스를 어떻게 노출할지는 이 문서 소관이 아니다**(§0).

---

## 7. 검증 계획

⛔ **이 repo는 배포하지 않는다.** 따라서 `apply` 판정(SSM 등록·세션 접속·`kubectl get nodes`)은
**소비 repo 몫**이다 — 그 경계를 넘어 "검증했다"고 쓰지 않는다(CLAUDE.md 작업 원칙).

### 7.1 이 repo에서 판정하는 것 — `tofu test`(plan 단계)

| ID | 검증 | 통과 기준 |
|----|------|-----------|
| T-1 | 기본 생성 | 인스턴스·SG·IAM role·instance profile이 계획됨 |
| T-2 | **`Name` 태그 규약** | `ec2-`·`sgr-`·`iamr-`·`vol-` 접두 + `naming` 3요소 조합 일치(CLAUDE.md 강제 5) |
| T-3 | **kill switch** | `workbench_enabled = false` → 리소스 0개, 출력 전부 `null` |
| T-4 | **인바운드 0** | ingress rule 리소스가 계획에 **없을 것** |
| T-5 | **하드닝 — 검증 가능한 2종** | `http_tokens = "required"` · hop limit 1 · `encrypted = true` · `gp3` |
| T-6 | EKS 연동 **양성** | `eks_cluster_name` + `eks_cluster_arn` 지정 시 인라인 정책이 **그 ARN으로 한정**되어 계획됨 |
| T-7 | EKS 연동 **음성** ×2 | 한쪽만 지정 → **plan 거부**(§4.1 가드) |
| T-8 | 음성 — kill switch × 가드 | `workbench_enabled = false` + 한쪽만 지정 → **거부되지 않을 것**(파기 경로 보호) |
| T-9 | **`git`의 무조건성**(§2.5·§4.1) | `kubectl_version`·`helm_version`이 **둘 다 `null`**인 최소 형상에서도 `user_data`에 `dnf install -y git-core`가 있을 것 |
| T-10 | **`argocd` CLI 양성·음성**(§4.1) | 지정 시 `user_data`에 그 버전의 릴리스 URL이 있을 것 · **`null`이면 없을 것**(기본값이 미설치라는 계약) |
| T-11 | **기본 `instance_type`**(D-WORKBENCH-SIZE) | 기본값이 `t4g.small`일 것 — 더 작은 타입은 부팅 중 `dnf`가 OOM으로 죽는다(§7.3-3) |
| T-12 | 🆕 **kubeconfig 배포 방식**(D-WORKBENCH-KUBECONFIG §4.3-1) | `eks_cluster_name` 지정 시 `user_data`에 **`chmod 0444`**(정본 잠금)와 **`/etc/skel/.kube/config`**(아직 없는 사용자 상속)가 있을 것. ⛔ 음성: **공유 정본을 `KUBECONFIG` 로 전역 export 하지 않을 것** |
| T-13 | 🆕 **진단 도구 nullable 핀**(D-WORKBENCH-TOOLING §4.3-2) | `eks_node_viewer_version`·`krew_version` 지정 시 각 릴리스 URL이 있을 것 · **둘 다 `null`이면 없을 것**(기본이 미설치라는 계약). ⚠️ eks-node-viewer 는 `_Linux_x86_64`/`_Linux_arm64` 로 **`amd64` 가 아니다** |
| T-14 | 🆕 **krew 는 시스템 설치**(§4.3-2 결정 1) | `KREW_ROOT=/usr/local/krew` 가 있을 것 · ⛔ 음성: **`$HOME/.krew` 기본 경로에 의존하지 않을 것** — 그러면 `/root` 에 갇힌다 |
| T-15 | 🆕 **로그인 프로파일**(§4.3-2 결정 3) | kubectl 지정 시 `alias k=kubectl` **와 함께 `kubectl completion bash` 로드**가 있을 것 · `AWS_DEFAULT_REGION` 이 **하드코딩이 아니라 `${region}`** 일 것 |

> ⭐ **T-12가 지키는 것은 "kubeconfig 가 생기는가"가 아니다** — 그건 T-6이 이미 본다.
> 지키는 것은 **정본이 쓰기 가능해지지 않는 것**과 **`ssm-user` 상속 경로가 사라지지 않는 것**이다.
> 🔑 둘 다 *"편의를 위해 되돌리기 쉬운"* 형태다 — `0444` 를 지우면 조작이 편해지고,
> 공유 정본을 다시 전역 export 하면 `$HOME` 없는 경로가 잠깐 편해진다. **그때 결함 1·2가 그대로 돌아온다.**
>
> ### 🔴 **T-12 의 음성 판정을 좁혔다** (2026-08-11, §4.3-2 를 쓰면서)
> 처음엔 **`> /etc/profile.d/` 자체를 금지**했다. 그러나 §4.3-2 가 `alias`·`PATH`·`KREW_ROOT` 를
> 넣으려면 그 파일이 필요하다. 🔑 **금지 대상은 `profile.d` 가 아니라 "공유 정본을 `KUBECONFIG` 로
> 전역 export 하는 것"** 이다 — 그것이 사용자별 사본을 무력화하는 유일한 메커니즘이다.
> ⇒ 판정을 `export KUBECONFIG=/etc/kubernetes` 부재로 바꿨다.
> ⚠️ **넓은 음성 판정은 나중 요구를 부당하게 막는다** — 오늘 하루 만에 그 비용이 실제로 나왔다.

> ⭐ **T-15 가 지키는 것은 alias 가 아니라 completion 로드다.** 실측상
> `complete -F <없는함수> k` 는 **에러 없이 통과**한다 ⇒ `source <(kubectl completion bash)` 를
> 빼먹어도 **아무 신호가 없다.** 🔑 **조용히 실패하는 설정은 테스트가 지켜야 한다.**

> ⚠️ **T-11이 지키는 것은 "OOM이 안 난다"가 아니다** — plan 테스트는 그것을 예측할 수 없다.
> 지키는 것은 **그때 내린 결정이 조용히 되돌아가지 않는 것**이고, 가장 그럴듯한 회귀는
> *"비용을 줄이려고 기본값을 내리는 변경"* 이다. 비용은 `instance_type`이 아니라
> `workbench_enabled`로 줄인다(§9).

> ⭐ **T-9가 지키는 것은 "설치되는가"가 아니라 무조건성이다.** `git`에 변수를 다시 붙이거나 다른
> 도구 옆의 조건 분기 안으로 옮기면 이 케이스만 깨진다 — 그 형태가 정확히 §4.1이 기각한 것이다.
> 음성 확인(설치 줄 제거 → 실패)까지 마쳤다: 통과하는 가짜 테스트가 아니다.

> ⭐ **T-8이 D-EXTDNS-ZONE에서 배운 것의 회수 지점이다.** 가드에 `&& var.workbench_enabled`를 넣지 않으면
> 이 케이스가 실패하고, 그것이 곧 **파기 불가능한 kill switch**를 뜻한다.

> 🔴 **하드닝 4종 중 2종은 plan 테스트로 지킬 수 없다**(2026-08-05 구현 중 실측).
> `key_name` 미지정·`associate_public_ip_address` 미지정은 **인자를 선언하지 않는 것** 자체가
> 계약인데, 둘 다 optional + computed 라 `mock_provider`가 임의 값을 채운다
> (실측: `key_name = "Wb0Vk"`). 실제 apply에서는 `null`이지만 plan 모킹에서는 볼 수 없다.
>
> ⛔ `mock_resource`로 `null`을 강제해 통과시키지 않았다 — 그러면 assertion이 모듈이 아니라
> **자기 자신의 모킹 설정**을 검증하게 된다. 통과하는 가짜 테스트는 없는 것보다 나쁘다.
>
> 🔑 **일반화: "미지정"을 계약으로 삼는 항목은 plan 테스트로 지킬 수 없다.** 이 둘의 회귀 방지는
> 코드 리뷰와 §4.2의 하드닝 목록에 남는다.
>
> ⚠️ **이 일반화를 `user_data`까지 넓히지 말 것**(2026-08-10 실측). `user_data`는 plan에서
> **원문 문자열 그대로** 보이므로 `strcontains`로 내용을 판정할 수 있다 — T-9가 그 위에 선다.
> 위 두 항목이 안 되는 이유는 "plan이라서"가 아니라 **모킹이 값을 지어내기 때문**이고,
> `user_data`는 우리가 계산해 넣는 값이라 지어낼 여지가 없다. 경계는 거기다. 공인 IP는 추가로 서브넷의 `map_public_ip_on_launch`에도
> 달려 있어 **모듈 단독 판정이 애초에 불가능**하다 — 소비 repo의 apply 판정 몫이다(§7.3).

### 7.2 예제 — **기존 `examples/eks-cluster-enterprise`에 넣는다**(신규 예제를 만들지 않는다)

⚠️ 최초 계획은 `examples/workbench-enterprise` 신설이었다. **2026-08-05 구현 중 철회했다.**

- **그 예제는 기존 eks 예제와 90% 중복**이 된다(VPC + EKS 전체를 다시 써야 §5의 3층을 보일 수 있다).
  둘이 갈리면 drift이고, 이 repo는 **예제를 늘리지 않는 문화**다 — PR #9에서 minimal 예제 2종을
  실제로 폐기했다.
- ⭐ **결정적 이유**: `examples/eks-cluster-enterprise`는 이미 `endpoint_public_access = false`이면서
  *"private 클러스터의 kubectl은 VPC 내부(workbench·VPN·DX)에서만 도달한다. 조작 지점을 먼저
  설계하지 않으면 apply 후 클러스터를 만질 수 없다"* 는 주석을 달고 있다.
  **그 예제 자체가 조작 지점이 없는 상태**였다 — workbench를 넣는 것이 그 미해결을 닫는다.

CI 게이트 ⑤(`init -lockfile=readonly` + `validate`)가 검증한다. 이 예제는 `cluster_security_group_
additional_rules`(§5.2)의 **유일한 회귀 방지 장치**이기도 하다 — facade 모듈의 `tofu test`는
upstream에 넘어간 값을 볼 수 없다.

### 7.3 소비 repo가 판정할 것 (이 repo 밖)

`aws ssm describe-instance-information`의 `PingStatus: Online` → 세션 접속 → `kubectl get nodes` →
**`endpoint_public_access = false`로 되돌리고 재확인**. 마지막 단계가 이 설계의 목적이다(§1).

#### ✅ 7.3-1 첫 apply 판정 — `workbench-v0.1.0` (2026-08-06, `iac-reference-infra`)

⛔ **이 절은 이 repo가 apply했다는 뜻이 아니다.** 판정 주체는 소비 repo
(`iac-reference-infra` `live/dev/eks`, apply run
[`31059712680`](https://github.com/skax-ca/iac-reference-infra/actions/runs/31059712680) —
`Apply complete! Resources: 10 added, 0 changed, 0 destroyed.`)이고, 이 문서는 **그 결과를
계약 항목별로 받아 적는다.** "동작한다"의 기준이 `tofu test` + 예제 `validate`라는 것은 그대로다.

**⭐ §5.1이 *"`tofu test`로 지킬 수 없다"* 고 적은 항목이 여기서 처음 실증됐다.**
"미지정 자체가 계약"인 항목은 plan에서 `(known after apply)`라 assertion을 걸 수 없었다 —
mock으로 강제하면 assertion이 자기 모킹 설정을 검증하게 된다.

| 계약 | `tofu test` | 실물(2026-08-06 `describe-instances`·`describe-security-groups`) |
|------|-------------|--------------------------------------------------------------|
| **공인 IP 미할당** | ⛔ 불가(optional+computed) | ✅ `PublicIpAddress: null` |
| **키페어 미지정** | ⛔ 불가(mock이 임의 값을 채움) | ✅ `KeyName: null` |
| **인바운드 0개** | △ 리소스 부재로만 간접 확인 | ✅ `length(IpPermissions) == 0` |
| egress 443/tcp 하나 | ✅ | ✅ `0.0.0.0/0:443` 단일 |
| `ami_id`↔`instance_type` 아키텍처 정합 | ⛔ 불가(§2.3) | ✅ `t4g.nano` + AL2023 arm64 부팅 성공 |

**도달 3층 전부 성립**(§5의 목적):

```
SSM 등록      PingStatus: Online · agent 3.3.4851.0 · AL2023   ← 인바운드 0인 호스트에 제어 평면이 붙었다
cloud-init    status: done                                     ← user_data 완료(비동기라 먼저 본다)
1층           /etc/kubernetes/kubeconfig 생성됨(2447B)         ← eks:DescribeCluster 성립
kubectl       Client Version: v1.35.7                          ← 클러스터 1.35와 마이너 일치
2·3층         kubectl get nodes → 노드 2개 Ready                ← 401도 timeout도 아니다
```

🔑 **`kubectl get nodes`가 반환된 것 자체가 3층 전부의 증거다.** 실패했다면 층별로 **다른 에러**가
났을 것이다 — 1층 없음 → kubeconfig 미생성 / 2층 없음 → `401 Unauthorized` / 3층 없음 →
`i/o timeout`. 층을 특정하는 이 표는 소비 repo `live/dev/eks/README.md §4`가 소유한다.

> ⚠️ **판정 방식**: 대화형 `start-session`이 아니라 `ssm send-command`(AWS-RunShellScript)로
> 실행했다(자동화 환경에 TTY가 없다). **같은 SSM 채널·같은 인스턴스 IAM role·같은 SG**를 지나므로
> 도달성 판정으로는 동등하다. 사람이 붙을 때는 `aws ssm start-session --target <id>`.

#### ✅ 7.3-2 **private-only 전환 판정** (2026-08-06) — §1의 목적 달성

apply run [`31062408357`](https://github.com/skax-ca/iac-reference-infra/actions/runs/31062408357)
= `Apply complete! Resources: 0 added, 2 changed, 0 destroyed.`(클러스터 `vpc_config` **in-place** —
replace 없음). 실물 `describe-cluster`: **`endpointPublicAccess: false`** · `endpointPrivateAccess: true`.

⭐ **음성 대조군이 이 판정의 핵심이다.** workbench에서 kubectl이 되는 것만으로는
*"private 경로로 닿았다"* 가 증명되지 않는다 — public을 통해 닿고 있었을 수 있다. **양쪽을 함께
봐야** 배제된다:

| | 결과 |
|---|---|
| **음성** — VPC 밖에서 apiserver DNS | `10.51.37.9`·`10.51.36.184` — **private IP만** |
| **음성** — VPC 밖에서 `curl <endpoint>/version` | **timeout(12s)**, `http=000` |
| **양성** — workbench에서 DNS | 같은 private IP 2개 |
| **양성** — workbench에서 `kubectl get nodes` | 노드 2개 `Ready` · pod **21개 Running** |

🔑 §7.3-1의 실증은 public이 **켜진 채로** 났다. 이 절이 그 한계를 닫는다 — 그래서 ①~③이
"선행 조건"이고 **④가 판정**이었다.

ℹ️ plan은 3건이었는데 apply는 2건이다. OIDC `thumbprint_list`가 `(known after apply)`였고
재계산 결과가 기존 값과 같아 **no-op**이 됐다 — `known after apply`는 *"바뀔 수도 있다"* 이지
*"바뀐다"* 가 아니다.

> ### ⚠️ 소비 루트가 알아야 할 실측 2건 (모듈 결함 아님)
>
> 1. **`publicAccessCidrs`는 API 응답에 남는다.** public을 끄고 인자를 지워도
>    `describe-cluster`가 **직전 값을 계속 반환**한다(실측: 운영자 IP `/32`). 동작에는 영향이 없는
>    무효 필드지만, **git에서 지운 값이 AWS API에는 남는다**는 뜻이다.
>    ⇒ 🔑 *"인자를 지우는 것과 값이 사라지는 것은 다르다."* 값 노출이 문제라면 별도 조치가 필요하다.
> 2. **공용 계정의 다른 자동화가 EBS `volume_tags`를 덮는다**(실측: `DependencyID`·`DependencyName`
>    추가 + `Name`을 인스턴스 이름으로 변경). tofu가 매번 되돌리므로 **apply마다 반복되는 drift**다.
>    무해하지만 "0 changed"를 기대할 수 없게 만든다 — 소비 repo의 미결 항목으로 추적한다.

#### 🔴 7.3-3 **`workbench-v0.3.0` apply 판정 — 부분 실패** (2026-08-10, `iac-reference-infra`)

apply run [`31352399365`](https://github.com/skax-ca/iac-reference-infra/actions/runs/31352399365)
= `Apply complete! Resources: 1 added, 0 changed, 1 destroyed.` — **replace 대상은 인스턴스 1개뿐**이었고
IAM role·instance profile·SG·SG rule 은 plan 목록에 없었다 ⇒ **Access Entry(2층)·cluster SG
ingress(3층) 유지 예측이 실증됐다.**

| 항목 | 결과 |
|---|---|
| 인스턴스 교체 · SSM 재등록 | ✅ `PingStatus: Online` (교체 후 약 3분) |
| kubeconfig 재생성 | ✅ **첫 시도에 성공** — IAM 전파 재시도 루프가 돌 필요조차 없었다 |
| `kubectl v1.35.7` · `helm v3.21.3` · `argocd v3.5.0` | ✅ 3개 전부 자동 설치 |
| **`git`** | ❌ **미설치 — `dnf` 가 OOM-kill 됐다** |

> ### 🔑 **이 판정이 값진 이유 — `tofu test` 로는 절대 잡을 수 없는 결함이었다**
>
> T-9 는 *"`user_data` 에 `dnf install -y git-core` 가 있는가"* 를 판정하고 **통과했다.**
> 계약은 맞았고 **실행이 실패했다.** plan 은 문자열까지만 보고 그 문자열이 512MB 머신에서
> 무슨 일을 하는지는 모른다.
> ⇒ ⭐ **`§7.1`의 경계선이 여기서 실증됐다**: 이 repo 는 `plan` 까지만 판정하고
> **apply 판정은 소비 repo 몫**이라는 분업이 형식이 아니라는 뜻이다.
> ⚠️ 그러니 *"`tofu test` 가 통과했으니 동작한다"* 고 쓰지 않는다.

**조치**: 원인은 코드가 아니라 **크기**였다 ⇒ [D-WORKBENCH-SIZE](#43-user_data) 로 기본 타입을
`t4g.small` 로 올리고 **`workbench-v0.4.0`** 을 컷한다. `helm`·`argocd`·kubeconfig 는 이미
검증됐으므로 v0.4.0 은 **`git` 하나를 닫는 릴리스**다.

#### ✅ 7.3-4 **`workbench-v0.4.0` apply 판정 — 전부 통과** (2026-08-10)

apply run [`31353547193`](https://github.com/skax-ca/iac-reference-infra/actions/runs/31353547193)
= `1 added, 0 changed, 1 destroyed`(다시 **replace 는 인스턴스 1개뿐**).

| 항목 | 결과 |
|---|---|
| `git` | ✅ **`git version 2.50.1`** — §7.3-3 의 실패가 닫혔다 |
| `kubectl` · `helm` · `argocd` | ✅ `v1.35.7` · `v3.21.3` · `v3.5.0` |
| 메모리 | ✅ 총 **1846MB** · available **1544MB** · **OOM 0건** |
| kubeconfig · 클러스터 | ✅ 첫 시도 성공 · 노드 2개 `Ready` |
| ArgoCD | ✅ root-app `Synced` `Healthy` · pod 5개 Running |

> ### ⏱️ **부팅이 3분+ → 32초로 줄었다**
>
> `03:49:39 → 03:50:11`. 도구가 하나 늘었는데 더 빨라졌다 — 늘어난 시간의 정체는
> **`dnf` 가 메모리를 구하지 못해 헤매던 시간**이었다. 🔑 OOM 은 "죽는 것"만이 아니라
> **죽기 전까지 느려지는 것**으로도 나타난다.

> ### 🔑 **재사용할 실측 — `t4g.small` 에는 zram swap 이 아예 없다**
>
> `free -m` 의 **`Swap: 0`** 이다. AL2023 은 **저메모리 인스턴스에만 zram 을 켠다**
> (`t4g.nano` 에서는 `/dev/zram0` 418MB 가 있었다). ⇒ *"swap 이 줄었으니 나빠졌다"* 가 아니다 —
> **압축 swap 이 필요 없을 만큼 실제 RAM 이 생겼다**는 뜻이다.

> ### ✅ **덤으로 `30` 판정 ③이 닫혔다** — `argocd` CLI 를 넣은 두 근거 중 하나
>
> `argocd admin cluster stats -n argocd`:
> ```
> SERVER                          SHARD  CONNECTION  NAMESPACES  APPS  RESOURCES
> https://kubernetes.default.svc  0      Successful  1           1     536
> ```
> **서버 항목이 하나뿐이다** ⇒ cluster Secret 이 내장 `in-cluster` 를 **대체했다. 중복이 아니다.**
> 2026-08-07 에 `kubectl` 만으로는 *"해석은 되지만 대체인지 중복인지 모른다"* 로 절반만 판정됐던 항목이다.
>
> ⚠️ **`argocd login` 없이 판정했다** — `argocd admin` 은 API 서버가 아니라 **k8s 를 직접 읽는다.**
> 초기 비밀번호를 조회하지 않고도 닫을 수 있었던 이유다(`23 §2.3` 완료 조건은 여전히 미이행).
> 🔴 **함정**: `-n argocd` 를 빠뜨리면 `argocd-cm 을 찾을 수 없다`는 경고가 나온다.
> **설정 공백이 아니라 네임스페이스 누락**이다 — 실제로 한 번 오독했다.

---

## 8. 구현 계획

> ⛔ CLAUDE.md 순서: **설계(이 문서) → 검토/승인 → 구현 → 검증**. 아래는 승인 후 착수한다.
> ⚠️ 커밋 단위는 *"변수가 전부 소비되는 시점"* 이다 — tflint `terraform_unused_declarations`가
> 선언만 되고 쓰이지 않은 변수를 exit 2로 잡는다.

| # | 태스크 | 게이트 |
|---|--------|--------|
| 40.1 | `modules/workbench/` 본체 — `versions.tf`·`variables.tf`(교차변수 가드 포함)·`main.tf`·`outputs.tf` | `fmt`·`validate`·`tflint`·`trivy` |
| 40.2 | `user_data` 템플릿(`/var/tmp` 경로 · kubeconfig 재시도) | 위와 동일 |
| 40.3 | `modules/workbench/tests/plan.tftest.hcl` — T-1 ~ T-8 | `tofu test` 통과 |
| 40.4 | **`eks-cluster` 계약 확장**(§5.2) — cluster SG 추가 규칙 통과 변수 + outputs 설명 정정 + 테스트 | `tofu test`(기존 20개 + 신규) |
| 40.5 | `examples/workbench-enterprise` — VPC+EKS+workbench 3층 조립 + README(AMI ID 조회법·소싱 태그 확인법) | 예제 `validate` |
| 40.6 | 릴리스 — **`workbench-v0.1.0`** + **`eks-cluster-v0.3.0`** | CI 6/6 + 로그 본문 확인 |

> 🔁 **릴리스 때마다 할 일**: 예제의 소싱 태그(`?ref=`)를 갱신한다. 2026-08-03에 실제로 놓쳤던 항목이다.
> 40.5 README에 `git tag -l 'workbench-v*'` 확인 장치를 둔다(eks 예제에 이번에 보완한 것과 같은 형태).

> ⚠️ **분리해야 할 축은 PR이 아니라 릴리스다** — 이 문단은 2026-08-05 구현 중 정정됐다.
>
> 최초 서술은 *"40.4를 별도 PR로 분리한다"* 였다. 근거는 `eks-cluster`가 **이미 apply된 소비자가
> 있는 모듈**이라 workbench의 미완성 상태와 릴리스 주기를 묶으면 소비 repo가 workbench를 안 쓰면서도
> `v0.3.0` 대기에 걸린다는 것이었다 — 그 걱정 자체는 유효하다.
>
> 🔑 **그런데 40.5(예제)가 40.4를 선행 의존한다.** 예제는 §5의 3층 배선을 보여야 의미가 있고,
> 3층은 `eks-cluster`의 새 변수를 쓴다. PR을 쪼개면 **예제가 반쪽이 되는 새 문제**가 생긴다.
>
> ⇒ **한 PR로 가되 태그를 따로 단다**(`workbench-v0.1.0` · `eks-cluster-v0.3.0`). 컴포넌트별 cadence
> 분리는 태그가 소유하는 것이지 PR이 소유하는 것이 아니다
> ([`../architecture/05 §4`](../architecture/05-versioning-policy.md)) — 소비 repo는 각자 필요한
> 태그만 올리면 되고, 한쪽을 올리지 않는 선택이 그대로 성립한다.

---

## 9. 비용

| 항목 | 월 추정 (ap-northeast-2 기준, 상시) |
|------|------------------------------------|
| **`t4g.small` on-demand** | **약 $15.2** (Price List API 실측, 2026-08-10) |
| gp3 10GB | 약 $0.9 |
| NAT 데이터 처리 | 미미 (제어 트래픽 위주) |
| **합계** | **약 $17 내외** |

SSM Session Manager 자체는 추가 요금이 없다. ⚠️ 리전·환경 수에 따라 달라지며 **견적이 아니라 규모감**이다.

> ⚠️ **2026-08-10 이전 이 표는 `t4g.nano` 기준 "$5 미만"이었다.** D-WORKBENCH-SIZE(§4.3)가
> 기본값을 올리면서 **월 약 $11 늘었다.** 그 차액이 사는 것은 *"고객사가 기본값 그대로 apply 해도
> 부팅이 성공한다"* 이다 — nano 기본값에서는 실제로 실패했다(dnf OOM 실측).
> 🔑 **비용을 낮추려면 `instance_type` 을 내리는 것이 아니라 `workbench_enabled = false` 로
> 끈다**(D-WORKBENCH-LIFECYCLE). 필요할 때만 켜면 상시 비용 자체가 사라진다.

---

## 10. 열린 항목

1. 🔴 **SSM 세션 로깅** — 세션 기록을 CloudWatch Logs 또는 S3로 남기는 구성이 없다.
   ⚠️ **D-WORKBENCH-SEAM이 이 항목의 중요도를 낮추지 않는다.** 소유는 갈렸어도 workbench role에 부여되는
   Access Entry 정책이 사실상 클러스터 관리 권한이면 **SSM 접근 통제가 곧 클러스터 보안**이다.
   → 고객사 인도 전에 결정한다. 로깅 구성을 모듈이 소유할지(변수)·계정 수준 SSM 설정으로 둘지가 논점.
2. **SSM VPCE 3종** — D-WORKBENCH-EGRESS는 NAT 경유를 택했다. **NAT 없는 완전 격리 VPC**를 요구하는
   고객사가 나오면 `ssm`·`ssmmessages`·`ec2messages` Interface Endpoint 신설로 전환한다.
   그 경우 `egress_cidr_blocks`도 VPC CIDR로 좁힐 수 있다.
3. **Access Entry 정책 범위** — §5는 *"누가 소유하나"* 만 정했고 *"어떤 정책을 붙이나"* 는 소비자 몫으로
   뒀다. `AmazonEKSClusterAdminPolicy`(cluster scope)는 편하지만 넓다. 프로파일 B에서 helm이 실제로
   요구하는 최소 권한이 무엇인지는 첫 수행 후 판단한다([`22 §2.4`](22-day2-operations.md)와 같은 성격).
4. **upstream의 구형 SG rule 리소스** — §5.2 상자. `03 §2.1`이 금지한 `aws_security_group_rule`을
   upstream이 쓴다. 지금은 우리 코드가 아니므로 수용하되, upstream이 신형으로 옮기면 그때 재확인한다.
   ⚠️ **같은 SG에 우리가 신형 rule을 직접 붙이지 않는다** — 소유자를 쪼개는 일이고(§5.1),
   혼용의 실제 위험은 여기서 발생한다.
5. **다중 workbench / 다중 환경** — 모듈은 1대를 전제한다(`subnet_id` 단수). dev/stg/prd에 각각 두면
   자연히 3대가 되므로 지금 요구에는 맞다. **AZ 이중화가 실제 요구로 나오면** 그때 계약을 연다 —
   SSM 접속은 인스턴스 ID를 지정하므로 이중화의 값은 "가용성"이 아니라 "AZ 장애 시 대체 진입"이다.
6. **Windows/기타 OS 도구 세트** — user_data는 AL2023 + arm64/x86 리눅스를 전제한다. 다른 OS 요구가
   생기면 user_data를 변수로 여는 것이 아니라 **별도 모듈**을 검토한다(분기가 계약을 흐린다).
7. ✅ **`argocd` CLI 추가 — 해소**(2026-08-10, `workbench-v0.3.0`). **이 항목은 닫혔다.**
   결정 본문은 [`§4.1`의 상자](#41-variables)(왜 nullable 핀인가 · 왜 도구 3개를 일반화하지 않는가)와
   [`§4.3`](#43-user_data)(단일 바이너리라 `helm` 블록을 복사하지 않는다)이 소유하고,
   판정은 [`§7.1` T-10](#71-이-repo에서-판정하는-것--tofu-testplan-단계)이 한다.
   - 착수 조건이던 *"[`21`](21-gitops-bootstrap-seam.md) 개정 후"* 는 2026-08-07 **D-GITOPS-SEAM**으로
     충족됐다. 핀 값의 근거는 [`23 §5`](23-argocd-self-managed.md) — chart `appVersion`과 같은 값이다.
   - ⚠️ **`velero` CLI는 이 항목에서 제외됐다**(그대로 유효). [D-BACKUP-AWS](22-day2-operations.md)가
     백업을 **AWS Backup(에이전트 없음)** 으로 확정해 **클러스터 안에서 실행할 CLI가 없어졌다.**
     Velero 예외 경로([`22 §4.5`](22-day2-operations.md))를 여는 고객사가 생기면 그때 함께 연다.
8. 🔴 **kubeconfig 가 인스턴스 교체와 함께 사라진다** (2026-08-11 신설 — 실제로 겪었다)

   [`30 §2.10.5`](30-gitops-repo.md) 판정을 시작하려는데 workbench **어디에도 kubeconfig 가 없었다**
   (`find` 전수 0건). `workbench-v0.4.0`(**D-WORKBENCH-SIZE**)이 인스턴스를 교체했고,
   이전 세션이 손으로 만든 kubeconfig 는 **그때 함께 사라졌다.**

   > ### 🔑 **`user_data` 가 도구를 넣는 것과 "도구가 쓸 수 있는 상태"는 다르다**
   >
   > §4.3 이 `git`·`kubectl`·`helm`·`argocd` 4종을 넣어 *"손으로 넣은 것이 하나도 없다"* 를 달성했지만,
   > **`kubectl` 은 kubeconfig 없이는 아무것도 못 한다.** 도구 설치 부채는 0이 됐는데
   > **설정 부채가 남아 있었고, 그것이 인스턴스 교체마다 되살아난다.**
   > ⚠️ 이 repo 의 *"동작한다"* 기준(`tofu test` + 예제 `validate`)으로는 **영원히 안 잡힌다** —
   > plan 은 도구가 실제로 쓸 수 있는지를 묻지 않는다.

   **실측(2026-08-11, workbench role `iamr-ref-dev-an2-workbench-01`)**

   | 호출 | 결과 |
   |---|---|
   | `eks:DescribeCluster` | ✅ 통과 |
   | `eks:ListClusters` | ⛔ `AccessDeniedException` |
   | `eks:ListAccessEntries` | ⛔ `AccessDeniedException` |
   | Access Entry 등재 | ✅ 등재돼 있다 — **kubeconfig 만 만들면 `kubectl` 이 통한다** |

   ⇒ `aws eks update-kubeconfig --region <r> --name <이름>` 은 **클러스터 이름을 알면 동작한다.**
   ⛔ 이름 없이 목록에서 찾는 흐름은 막힌다 — 절차서에 **이름을 쓰게** 해야 한다.

   > ## 🔴 **이 항목의 전제는 틀렸다 — 2026-08-11 실측으로 반증됐다**
   >
   > kubeconfig 는 **있었다**(`/etc/kubernetes/kubeconfig`, 부팅 로그에 생성 기록).
   > **ⓐ 는 이미 구현돼 있었고 순환도 없었다** — `eks_cluster_name` 이 소비자 입력이라
   > §5.1-1 이 의도한 대로 결정적 네이밍이 끊고 있었다.
   > 위 *"`find` 전수 0건"* 은 **홈 디렉토리만 봤거나, 비로그인 셸에서 `kubectl` 이 실패한 것을
   > "kubeconfig 없음"으로 오독**한 것이다.
   >
   > **진짜 결함은 셋**이었고 전부 *"설치"가 아니라 "누가 쓸 수 있나"* 였다 —
   > ① `/etc/profile.d` 는 **로그인 셸에서만** 읽힌다(자동화 경로가 못 받는다)
   > ② 공유 정본이 **`0666` world-writable** 이 되어 전역 오염 + **로컬 권한 상승 경로**
   > ③ 손으로 만든 사본이 는다
   >
   > ✅ **해소 — [`§4.3-1` D-WORKBENCH-KUBECONFIG](#43-1--d-workbench-kubeconfig--정본은-읽기-전용-사용자마다-자기-사본-2026-08-11-확정)**:
   > 정본 `0444` + `/etc/skel` 상속 + 사용자별 `0600` 사본 + `profile.d` 제거.
   > ⛔ *"전용 사용자 신설"* 은 기각했다(§4.3-1 기각표) — `ssm-user` 가 이미 `NOPASSWD:ALL` 이다.
   > ⚠️ 비로그인 셸은 user_data 로 닫을 수 없어 **§6 자동화 규약**이 소유한다.
   >
   > 🔑 **이 항목이 남긴 교훈은 kubeconfig 가 아니라 판정 방법이다** —
   > **증상에서 원인을 추론하고 실물을 열지 않으면, 없는 문제를 설계하게 된다.**
