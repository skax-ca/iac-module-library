# examples/eks-cluster-enterprise — 고객사 착수 템플릿

⚠️ **이 예제의 목적은 검증이 아니다.** 계약 검증은 `modules/eks-cluster/tests/`가 이미 커버한다.
여기는 **고객사가 복사해 착수하는 템플릿**이며, `examples/AGENTS.md`의 "예제는 최소로 유지" 원칙에
대한 **의도된 예외**다(`examples/vpc-enterprise`와 같은 위치).

그래서 이 파일과 `main.tf`의 주석은 코드만큼 중요하다 — **"왜 이 값인가"** 가 실제 산출물이다.

## 보이는 것

| 축 | 구성 | 근거 |
|----|------|------|
| **custom networking** | secondary CIDR `100.64.0.0/16` + `pod-dup` 그룹 | VPC D9 — Pod IP를 대량 소모해도 온프레미스 IP 계획을 잠식하지 않는다 |
| **Karpenter discovery** | subnet(`extra_tags`) + SG(모듈이 부여) **양쪽** | 한쪽만 붙으면 selector가 빈 결과 → 조용한 실패 |
| **컨트롤러 IAM** | ALBC · external-dns opt-in | 설계 §2.6a — 정책은 커뮤니티 큐레이션에 위임 |
| **관측·감사** | `enabled_log_types` + VPC Flow Logs | trivy AVD-AWS-0038 |
| **삭제 보호** | `deletion_protection = true` | D-EKS-PROTECT — AWS API 차원 |
| **가용성** | `single_nat_gateway = false` | AZ 장애가 다른 AZ 아웃바운드를 끊지 않게 |

## ⚠️ 구조부터 다르다 — 실제로는 **VPC를 여기서 만들지 않는다**

| | 이 예제 | 소비 프로젝트(`<project>-infra`) |
|---|---|---|
| **VPC** | **같은 루트에서 함께 생성** | **별도 루트**(`live/dev/networking`)가 이미 apply. eks 루트는 **조회만** |
| 소싱 | 상대경로 `../../modules/eks-cluster` | git tag `?ref=eks-cluster-v1.0.0` |
| backend | 없음(`-backend=false`) | S3 + `use_lockfile = true` |
| 워크로드 코드 | 가상값 `acme` | 실제 프로젝트 코드 |
| `ignore_tags` | 비어 있음 | 랜딩존 자동 태거 키를 채운다 |

**첫 행이 가장 중요하다.** 이 예제는 VPC와 EKS를 한 루트에서 만든다 — **예제라서 그렇다**
(`01 §4`가 "예제가 곧 `tofu test` 대상"이라 self-contained해야 `validate`가 돌고, CI 게이트 ⑤도
그걸 요구한다). 이 구조를 그대로 복사하면 두 컴포넌트가 한 state에 묶여, **네트워크를 건드릴
때마다 클러스터가 plan 범위에 들어온다.**

소비 프로젝트에서 networking과 eks-cluster는 **별도 배포 루트**이며(`03 §4`), eks 루트는 이미
apply된 VPC를 **태그로 조회**한다:

```hcl
data "aws_subnets" "node" {
  filter { name = "vpc-id", values = [data.aws_vpc.main.id] }
  filter { name = "tag:SubnetGroup", values = ["node-uniq"] }   # VPC 모듈 D13 (vpc-v1.2.0+)
}
data "aws_subnets" "pod" {
  filter { name = "vpc-id", values = [data.aws_vpc.main.id] }
  filter { name = "tag:SubnetGroup", values = ["pod-dup"] }
}
```

⛔ `terraform_remote_state`는 쓰지 않는다 — state 전체 접근을 요구해 `03 §3.1`이 ❌로 판정했다.
상세는 [`docs/design/20-eks-module.md §2.5-1`](../../docs/design/20-eks-module.md).

⚠️ **배포 순서가 있다**: networking → eks-cluster. networking이 아직 apply되지 않았으면 조회가
에러가 아니라 **빈 결과**를 낸다 — 그래서 `precondition`으로 `length(...ids) > 0`을 확인하는 것이 좋다.

## ⚠️ 착수 전 반드시 바꿀 것

이 예제는 **계정에 붙지 않으므로** 실계정 값이 필요한 자리를 비워 두었다. 그대로 apply하지 않는다.

| 자리 | 지금 | 실환경 |
|------|------|--------|
| `external_dns_hosted_zone_arns` | `[]` | **실제 zone ARN**. 비우면 커뮤니티 정책이 전체 zone(`*`)을 허용한다 — prd 필수 |
| `managed_node_groups.system.ami_release_version` | `null` | concrete 버전(예: `1.35.6-20260724`). null이면 매 plan이 최신을 해석해 **노드 롤링 교체**가 난다(D-NODE-AMI-PIN) |
| `cluster_addons`의 `addon_version` | 미지정(= AWS 기본 버전) | 고정하려면 실측 값을 박는다 — 아래 **"addon 버전 고정"** 절(D-ADDON-VERSION-PIN-1). ⚠️ 모듈은 버전을 **갖지 않는다** |
| CIDR | `10.0.0.0/16` | 사내 IP 계획과 충돌하지 않는 대역 |

## 운영상 알아야 할 것

**private 클러스터의 조작 지점을 먼저 설계한다.** `endpoint_public_access = false`이므로 `kubectl`은
VPC 내부(bastion·VPN·Direct Connect)에서만 도달한다. 이걸 정하지 않고 apply하면 **클러스터를 만들었는데
만질 수 없는** 상태가 된다.

**teardown은 2단계다.** `deletion_protection = true`인 상태에서는 파기되지 않는다 —
`deletion_protection = false`로 apply한 뒤 `cluster_enabled = false`로 파기한다.
이는 결함이 아니라 보호의 정의다. 모듈의 교차변수 `validation`이 이 순서를 plan 시점에 강제한다.

**시스템 노드그룹은 없앨 수 없다.** Karpenter 자신이 뜰 곳이 필요하기 때문이다 —
Karpenter chart의 affinity가 `karpenter.sh/nodepool DoesNotExist`를 요구해서, Karpenter가 만든 노드에는
Karpenter가 뜰 수 없다(자기 자신을 부트스트랩할 수 없다).

## addon 버전 고정 (D-ADDON-VERSION-PIN-1)

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
> ebs-csi 의 pod identity association 은 merge **뒤에** 재주입된다(`addons.tf` §4). shallow merge 로
> 엔트리가 통째로 교체되는 문제는 모듈이 이미 처리했다.

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
