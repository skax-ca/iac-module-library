# examples/eks-cluster-enterprise — 고객사 착수 템플릿

⚠️ **이 예제의 목적은 검증이 아니다.** 계약 검증은 `modules/eks-cluster/tests/`가 이미 커버한다.
여기는 **고객사가 복사해 착수하는 템플릿**이며, `examples/AGENTS.md`의 "예제는 최소로 유지" 원칙에
대한 **의도된 예외**다(`examples/vpc-enterprise`와 같은 위치).

그래서 이 파일과 `main.tf`의 주석은 코드만큼 중요하다 — **"왜 이 값인가"** 가 실제 산출물이다.

## 보이는 것

| 축 | 구성 | 근거 |
|----|------|------|
| **custom networking** | secondary CIDR `100.64.0.0/16` + `pod-dup` 그룹 | Pod IP를 대량 소모해도 온프레미스 IP 계획을 잠식하지 않는다 |
| **Karpenter discovery** | subnet(`extra_tags`) + SG(모듈이 부여) **양쪽** | 한쪽만 붙으면 selector가 빈 결과 → 조용한 실패 |
| **컨트롤러 IAM** | ALBC · external-dns opt-in | 정책은 커뮤니티 큐레이션에 위임 |
| **관측·감사** | `enabled_log_types` + VPC Flow Logs | trivy AVD-AWS-0038 |
| **삭제 보호** | `deletion_protection = true` | AWS API 차원의 보호 |
| **가용성** | `single_nat_gateway = false` | AZ 장애가 다른 AZ 아웃바운드를 끊지 않게 |
| ⭐ **도달 지점** | `module.workbench` + **EKS 접근 3층 연결** | 설계 [`05-modules.md`](../../docs/05-modules.md) — private 클러스터를 조작할 유일한 지점 |

### ⭐ EKS 접근 3층 — 이 예제의 핵심 연결

`endpoint_public_access = false`인 클러스터에 kubectl이 닿으려면 **세 층이 모두** 있어야 한다.
소유가 두 모듈로 갈리는 기준은 **주체냐 대상이냐**다.

| 층 | 무엇을 결정하나 | 빠뜨렸을 때 증상 | 소유 |
|----|----------------|------------------|------|
| ① `eks:DescribeCluster` | kubeconfig를 **만들 수 있는가** | `update-kubeconfig` 권한 오류 | `module.workbench` (자기 권한) |
| ② Access Entry | 클러스터 **안에서** 무엇을 하는가 | `401 Unauthorized` | `module.eks` (`access_entries`) |
| ③ cluster SG ingress 443 | apiserver에 **네트워크로 닿는가** | **`dial tcp …: i/o timeout`** | `module.eks` (`cluster_security_group_additional_rules`) |

> 🔑 **증상의 계층이 다르다는 것이 진단의 단서다.** PoC는 ①②만 갖추고 timeout을 만났는데,
> 인증 오류가 아니라 **타임아웃**이었다는 것이 "인증 계층에 닿지도 못했다"를 뜻했다.
>
> ⚠️ **`local.cluster_arn`을 지우지 말 것.** workbench는 클러스터 ARN을 받고 eks는 workbench role ARN을
> 받아 **양방향 참조**가 된다. ARN을 루트에서 합성해 끊는다 —
> [`docs/06-conventions.md`](../../docs/06-conventions.md)의 원칙(결정적 네이밍, 결합도 없음).
> `module.eks.cluster_arn`으로 바꾸면 **순환으로 plan이 죽는다**.

## ⚠️ 구조부터 다르다 — 실제로는 **VPC를 여기서 만들지 않는다**

| | 이 예제 | 소비 프로젝트(`<project>-infra`) |
|---|---|---|
| **VPC** | **같은 루트에서 함께 생성** | **별도 루트**(`live/dev/networking`)가 이미 apply. eks 루트는 **조회만** |
| **Route53 zone** | **같은 루트에서 함께 생성**(`aws_route53_zone.internal`) | **만들지 않는다.** external-dns를 끄거나(기본), 기존 zone을 `data`로 **조회만** — 아래 **"external-dns"** 절 |
| 소싱 | 상대경로 `../../modules/eks-cluster` | git tag `?ref=eks-cluster-v0.5.0` (**현행 릴리스**) |
| backend | 없음(`-backend=false`) | S3 + `use_lockfile = true` |
| 워크로드 코드 | 가상값 `demo` | 실제 프로젝트 코드 |
| `ignore_tags` | 비어 있음 | 랜딩존 자동 태거 키를 채운다 |

**첫 행이 가장 중요하다.** 이 예제는 VPC와 EKS를 한 루트에서 만든다 — **예제라서 그렇다**
([`examples/AGENTS.md`](../AGENTS.md)의 원칙 — 예제가 곧 CI 게이트 ⑤의 `validate` 대상이라
self-contained해야 한다). 이 구조를 그대로 복사하면 두 컴포넌트가 한 state에 묶여, **네트워크를
건드릴 때마다 클러스터가 plan 범위에 들어온다.**

소비 프로젝트에서 networking과 eks-cluster는 **별도 배포 루트**이며, eks 루트는 이미
apply된 VPC를 **태그로 조회**한다:

```hcl
data "aws_subnets" "node" {
  filter { name = "vpc-id", values = [data.aws_vpc.main.id] }
  filter { name = "tag:SubnetGroup", values = ["node-uniq"] }   # vpc 모듈이 붙이는 조회 키
}
data "aws_subnets" "pod" {
  filter { name = "vpc-id", values = [data.aws_vpc.main.id] }
  filter { name = "tag:SubnetGroup", values = ["pod-dup"] }
}
```

⛔ `terraform_remote_state`는 쓰지 않는다 — state 전체 접근을 요구해 판정은 ❌였다.
상세는 [`docs/05-modules.md`](../../docs/05-modules.md).

⚠️ **배포 순서가 있다**: networking → eks-cluster. networking이 아직 apply되지 않았으면 조회가
에러가 아니라 **빈 결과**를 낸다 — 그래서 `precondition`으로 `length(...ids) > 0`을 확인하는 것이 좋다.

### 소싱 태그를 어떻게 고르나

```hcl
source = "git::https://github.com/skax-ca/iac-module-library.git//modules/eks-cluster?ref=eks-cluster-v0.5.0"
source = "git::https://github.com/skax-ca/iac-module-library.git//modules/workbench?ref=workbench-v0.6.0"
```

⚠️ **핀은 착수 시점의 현행 릴리스로 건다** — `git tag -l 'eks-cluster-v*'` · `git tag -l 'workbench-v*'`로
확인한다. 위 표의 태그가 낡은 채 복사되면 그대로 굳는데, 이 모듈은 실패 방식이 특히 나쁘다:
`eks-cluster-v0.2.0`이 넣은 external-dns 가드가 빠지면 **문제 조합의 `plan`이 통과하고 `apply`가
죽는다**. ⚠️ **이 README 자신이 두 번 그 함정에 걸렸다** — 경고문을 쓴 것만으로는
갱신되지 않는다. 태그를 컷할 때 이 파일을 함께 고치는 것이 유일하게 작동하는 방법이다.
릴리스 이력은 각 태그의 annotated 메시지(`git show eks-cluster-v0.5.0`)와
[`docs/05-modules.md`](../../docs/05-modules.md)에 있다.

> 🔑 **두 모듈의 태그는 따로 움직인다.** `workbench`을 쓰지 않는 프로젝트는 `eks-cluster`만 올리면 되고
> 그 반대도 성립한다 — 컴포넌트별 cadence 분리가 `0.y.z` 정책의 요점이다
> ([`docs/06-conventions.md`](../../docs/06-conventions.md)).
> ⚠️ 단 **3층 연결(위 표)을 쓰려면 `eks-cluster-v0.3.0` 이상**이 필요하다 —
> `cluster_security_group_additional_rules`가 그 릴리스에서 생겼다.

⚠️ **`0.y.z`는 개발 단계를 뜻한다**([`docs/06-conventions.md`](../../docs/06-conventions.md)) —
이 구간에서는 **마이너 업그레이드도 계약을 바꿀 수 있다.** 태그를 올릴 때 릴리스 메시지를 읽는다.

## ⚠️ 착수 전 반드시 바꿀 것

이 예제는 **계정에 붙지 않으므로** 실계정 값이 필요한 자리를 비워 두었다. 그대로 apply하지 않는다.

| 자리 | 지금 | 실환경 |
|------|------|--------|
| 🔴 **`workbench_ami_id`** | **자리표시자 `ami-00000000000000000`** | **조회한 실제 AMI ID.** 아래 **"workbench AMI"** 절 — 그대로 apply하면 즉시 실패한다(의도된 것) |
| `external_dns_hosted_zone_arns` | 예제가 만든 `aws_route53_zone.internal.arn` | **운영 중인 zone의 ARN**. 아래 **"external-dns"** 절 참조 |
| `managed_node_groups.system.ami_release_version` | `null` | concrete 버전(예: `1.35.6-20260724`). null이면 매 plan이 최신을 해석해 **노드 롤링 교체**가 난다 |
| `cluster_addons`의 `addon_version` | 미지정(= AWS 기본 버전) | 고정하려면 실측 값을 박는다 — 아래 **"addon 버전 고정"** 절. ⚠️ 모듈은 버전을 **갖지 않는다** |
| CIDR | `10.0.0.0/16` | 사내 IP 계획과 충돌하지 않는 대역 |

## workbench AMI — 핀의 소유자는 소비 루트다

`modules/workbench`의 `ami_id`에는 **기본값이 없다.** AMI ID는 리전 종속이라 재사용 자산의
기본값이 될 수 없기 때문이다 — `addon_version`과 같은 구조다.

```bash
# arm64(기본 instance_type = t4g.nano)
aws ssm get-parameter --region ap-northeast-2 \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
  --query Parameter.Value --output text

# x86 을 쓸 경우 — instance_type 도 함께 바꾼다
#   --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64
```

⛔ **조회한 값을 커밋한다. 조회를 코드에 넣지 않는다.** `resolve:ssm:` 이나 `most_recent = true`를
쓰면 AWS가 새 AMI를 낼 때마다 **리뷰 없이 인스턴스가 재생성**된다. 업그레이드는 `workbench_ami_id`를
bump하는 **명시적 커밋**으로만 하고, plan diff에서 재생성이 보이는 것을 확인한 뒤 apply한다.

> 🔑 **자리표시자가 존재하지 않는 ID인 것은 의도된 선택이다.** 그대로 apply하면 즉시 실패해
> "값을 바꿔야 한다"가 드러난다. 아래 external-dns의 더미 zone ARN은 반대로 **apply가 성공해서**
> 존재하지 않는 zone을 가리키는 IAM이 조용히 굳는 것이 문제였다 — 그래서 그쪽은 예제가 zone을 직접 만든다.

⚠️ **`instance_type`과 아키텍처가 어긋나면 plan은 통과하고 부팅이 실패한다.** 모듈은 검증하지
않는다 — 검증하려면 AMI를 조회해야 하고 그건 핀의 취지와 충돌한다.
`ami_type`/`instance_types`를 함께 고쳐야 하는 노드 그룹과 같은 성격의 함정이다.

## workbench 접속

```bash
# 인바운드 규칙 0개로 셸에 진입한다 — IAM 인증만으로 성립한다
aws ssm start-session --target $(tofu output -raw workbench_instance_id) --region ap-northeast-2

# 접속 후 (kubeconfig 는 user_data 가 /etc/kubernetes 에 전역 생성)
kubectl get nodes
```

⚠️ **SSM 세션 로깅이 아직 없다**. Access Entry가 `AmazonEKSClusterAdminPolicy`이므로
**SSM 접근 통제가 곧 클러스터 보안**이다. 고객사 인도 전에 CloudWatch Logs 또는 S3 기록을 결정한다.

## external-dns — 예제와 소비 프로젝트가 다른 지점

**예제는 Route53 private zone까지 직접 만든다**(`aws_route53_zone.internal`). `examples/AGENTS.md`의
self-contained 요건 때문이기도 하지만, 더 직접적인 이유는 **`enable_external_dns_iam = true`가 zone ARN 없이는
성립하지 않기 때문**이다 — `external_dns_hosted_zone_arns`를 비우면 upstream이 `Resource = "*"`
정책을 만들고 AWS가 `400 MalformedPolicyDocument`로 거부한다.
모듈의 교차변수 validation이 그 조합을 **plan에서** 막는다.

> ⚠️ 더미 ARN을 적어 두는 선택지도 있었으나 기각했다. 고객사가 그대로 복사해 apply하면
> **존재하지 않는 zone을 가리키는 IAM role이 조용히 만들어진다** — apply가 성공하기 때문에
> 아무도 지적하지 않은 채 굳는다.

### 소비 프로젝트에서는 어떻게 하나

**⛔ 이 zone 리소스를 복사하지 않는다.** DNS zone은 워크로드 수명주기보다 오래 살고 보통 이미
존재한다 — 클러스터 루트가 zone을 소유하면 클러스터를 지울 때 zone이 함께 지워진다.

**기본값은 external-dns를 끄고 가는 것이다.**

```hcl
# cluster_addons 에서 external-dns 항목을 넣지 않는다
enable_external_dns_iam = false   # zone ARN 없이 true 로 두면 plan 이 거부된다
```

되켤 때는 **zone을 먼저 확보한 뒤** 그 ARN을 넘긴다. zone은 별도 루트(또는 수동 생성)가 소유하고
클러스터 루트는 `data.aws_route53_zone`으로 **조회만** 한다 —
[`docs/06-conventions.md`](../../docs/06-conventions.md)의 "이름이 아니라 조회로 느슨하게 결합"
원칙이 여기에도 적용된다.

```hcl
data "aws_route53_zone" "this" {
  name         = "example.internal"
  private_zone = true
}

enable_external_dns_iam       = true
external_dns_hosted_zone_arns = [data.aws_route53_zone.this.arn]
```

> 🔑 그때 이 validation이 **되켜는 사람을 보호한다** — zone ARN을 빠뜨리면 2026-08-04와 같은
> apply 실패를 반복하는데, 이제는 몇 초 만에 plan에서 잡힌다.

### `force_destroy = true`는 예제에서만

예제 zone은 `force_destroy = true`다. external-dns는 클러스터 안에서 돌며 **IaC 밖에서** 레코드를
쓰기 때문에, 그 레코드가 남으면 zone 삭제가 실패해 teardown이 막힌다.
⛔ **실제 프로젝트에서는 켜지 않는다** — IaC가 모르는 레코드를 말없이 지우는 스위치다.

## 운영상 알아야 할 것

**private 클러스터의 조작 지점을 먼저 설계한다.** `endpoint_public_access = false`이므로 `kubectl`은
VPC 내부(workbench·VPN·Direct Connect)에서만 도달한다. 이걸 정하지 않고 apply하면 **클러스터를 만들었는데
만질 수 없는** 상태가 된다.

**teardown은 2단계다.** `deletion_protection = true`인 상태에서는 파기되지 않는다 —
`deletion_protection = false`로 apply한 뒤 `cluster_enabled = false`로 파기한다.
이는 결함이 아니라 보호의 정의다. 모듈의 교차변수 `validation`이 이 순서를 plan 시점에 강제한다.

**시스템 노드그룹은 없앨 수 없다.** Karpenter 자신이 뜰 곳이 필요하기 때문이다 —
Karpenter chart의 affinity가 `karpenter.sh/nodepool DoesNotExist`를 요구해서, Karpenter가 만든 노드에는
Karpenter가 뜰 수 없다(자기 자신을 부트스트랩할 수 없다).

## addon 버전 고정

**모듈은 addon 버전을 갖지 않는다.** 버전을 안 주면 EKS가 그 클러스터의 k8s 버전·리전에 맞는
**AWS 기본 버전**을 해석한다 — 안전하고, 어떤 조합에서도 깨지지 않는다.

⚠️ 모듈이 값을 들지 않는 이유는 **업그레이드 주기가 워크로드마다 다르기 때문**이다. 공통 모듈이
버전을 소유하면 우리 kube-proxy 상향이 모듈 릴리스를 요구하고, 그 릴리스는 **다른 고객사에게도
배송된다.** 반대로 우리는 남이 준비될 때까지 못 올린다. 버전은 이 루트가 소유한다.

프로덕션에서 완전히 결정적으로 고정하려면 값을 조회해 `cluster_addons`에 박는다:

```bash
# 이 클러스터의 k8s 버전·리전 기준으로 조회한다 — 둘 다 값에 영향을 준다
aws eks describe-addon-versions \
  --kubernetes-version 1.35 --region ap-northeast-2 --addon-name coredns \
  --query 'addons[].addonVersions[].addonVersion' --output text | tr '\t' '\n' | head -5

# ⭐ **AWS 기본 버전만** 뽑는다 — 위 명령의 첫 줄은 기본이 아니라 '최신'이다(둘은 다르다)
aws eks describe-addon-versions \
  --kubernetes-version 1.35 --region ap-northeast-2 --addon-name coredns \
  --query 'addons[0].addonVersions[?compatibilities[0].defaultVersion==`true`].addonVersion | [0]' \
  --output text
```

```hcl
cluster_addons = {
  "coredns"    = { addon_version = "v1.13.2-eksbuild.11" }
  "kube-proxy" = { addon_version = "v1.35.3-eksbuild.17" }
}
```

> 🔑 **최신이 아니라 기본(default) 버전을 박는다.** 기본 버전을 박으면 **핀 전후 동작이 같다** —
> 핀은 "지금 상태를 고정"하는 일이다. 최신을 박으면 "핀을 추가한다"는 작업에 **업그레이드 결정이
> 섞여 들어간다.** 상향은 값을 올리는 **별도 커밋**이어야 plan diff 로 리뷰된다.
> 실측(1.35 · an2, 2026-08-04): `coredns` 기본 `v1.13.2-eksbuild.11` ≠ 최신 `v1.14.3-eksbuild.3`.
>
> ℹ️ `addon_version`만 적어도 **모듈 소유 필드는 살아남는다** — vpc-cni 의 custom networking 구성과
> ebs-csi 의 pod identity association 은 merge **뒤에** 재주입된다(`addons.tf`의 "4) 최종 변환" 블록).
> shallow merge 로 엔트리가 통째로 교체되는 문제는 모듈이 이미 처리했다.

**갱신 규칙 두 가지.**

1. ⚠️ **`kubernetes_version`을 올리면 고정한 버전도 같이 올린다.** addon 버전은
   `f(k8s 버전, 리전)`이라 k8s만 올리면 *"그 버전 없음"* 으로 apply가 죽는다.
   특히 `kube-proxy`는 **정의상** k8s 마이너를 따라간다(`v1.35.3` ↔ k8s 1.35).
2. ⚠️ **리전마다 가용 버전이 다르다.** 2026-08-03 실측: `cert-manager`가 ap-northeast-2에는
   `v1.21.0-eksbuild.3`, us-east-1·eu-west-1에는 `eksbuild.2`까지만 있었다.
   멀티리전 배포에서 버전 문자열을 공유하려면 **리전 공통으로 가용한 값**을 쓴다.

고정하지 않아도 **리뷰 없는 자동 업데이트는 일어나지 않는다** — 모듈이 `most_recent = false`를
넘기므로 "매 plan이 최신을 재해석"하는 upstream 기본 동작은 꺼져 있다.

## 비용 주의

이 형상은 **예제 중 가장 비싸다**. NAT 2개(AZ별, 개당 월 ~$43) + EKS 컨트롤플레인 + 노드 2대 +
CloudWatch 로그(컨트롤플레인 3종 + VPC Flow Logs)가 상시 과금된다.
비용을 낮추려면 `single_nat_gateway = true`, `enabled_log_types = []`부터 조정한다.

## 실행

```bash
tofu -chdir=examples/eks-cluster-enterprise init -backend=false
tofu -chdir=examples/eks-cluster-enterprise validate
```
