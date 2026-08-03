# examples/eks-cluster — minimal

`modules/eks-cluster`의 **핵심 경로를 최소 비용으로** 보이는 예제다. 소비자가 복사해 시작하는 지점이기도 하다.
VPC 모듈과 결선하고, 시스템 노드그룹 1개를 두고, addon은 baseline 6종을 그대로 상속한다.

## 이 예제가 보여주는 것 — **클러스터 이름을 한 번만 정의한다**

`main.tf`의 `locals.cluster_name`이 이 예제의 요점이다. 같은 문자열이 **두 모듈에 각각** 들어간다:

| 어디에 | 무엇을 위해 |
|--------|-----------|
| `module.vpc.eks_cluster_name` | 서브넷에 `kubernetes.io/cluster/<name>` 디스커버리 태그를 붙인다 |
| `module.eks`의 `naming`·`purpose`·`serial` | 모듈이 **같은 규칙으로 같은 이름을 합성**한다 |

**왜 EKS 모듈이 VPC 서브넷에 직접 태그를 달지 않는가**: 그러려면 EKS가 VPC의 리소스를 수정하면서
동시에 VPC의 서브넷을 읽어야 한다 — **양방향 의존(순환)**이다. 대신 양쪽이 같은 규칙으로 같은
문자열을 각자 유도하면 순환 없이 풀린다(`03 §3.1`의 1순위 "결정적 네이밍"). 이름 규약이 의존성을
지우는 실제 사례이며, 대가는 "소비자가 두 곳에 값을 넣는다"는 것이고 이 `local`이 그 대가를 한 줄로 줄인다.

⚠️ **포맷을 임의로 바꾸면 안 된다.** `eks-<workload>-<env>-<region_code>-<purpose>-<serial>`은
모듈 내부의 합성 규칙과 같아야 한다. 어긋나면 태그가 다른 이름을 가리켜 **EKS가 서브넷을 못 찾는다** —
plan은 통과하고 apply 후에 드러나는 종류의 실패다.

## 최소 형상에서 꺼 둔 것

- **`enable_custom_networking = false`** — 모듈 기본값은 `true`다. custom networking(VPC D9)은 Pod 전용
  비라우팅 대역(secondary CIDR)을 전제하는데 이 예제는 그 대역을 만들지 않으므로 **명시적으로 끈다**.
  켜는 형상은 [`../eks-cluster-enterprise`](../eks-cluster-enterprise)를 본다.
- Karpenter IAM은 기본 `true`라 생성되지만, **subnet discovery 태그는 붙이지 않았다** —
  실제로 Karpenter를 쓰려면 노드 서브넷 그룹의 `extra_tags`에도 같은 태그가 필요하다(enterprise 예제 참조).

## 실행

```bash
tofu -chdir=examples/eks-cluster init -backend=false
tofu -chdir=examples/eks-cluster validate
```

> ⚠️ **`validate`는 계약 위반을 잡지 못한다.** 교차변수 `validation`은 `plan` 시점에만 평가되므로,
> 계약 검증은 `modules/eks-cluster/tests/plan.tftest.hcl`이 담당한다(`tofu -chdir=modules/eks-cluster test`).
> 이 예제의 역할은 "**쓰는 법**이 검증됐다"는 것까지다.

## ⚠️ 소비 프로젝트와 다른 점 — **VPC를 여기서 만들지 않는다**

| | 이 예제 | 소비 프로젝트(`<project>-infra`) |
|---|---|---|
| **VPC** | **같은 루트에서 함께 생성** | **별도 루트**(`live/dev/networking`)가 이미 apply. eks 루트는 **조회만** |
| 소싱 | 상대경로 `../../modules/eks-cluster` | git tag `?ref=eks-cluster-v1.0.0` |
| backend | 없음(`-backend=false`) | S3 + `use_lockfile` |
| 워크로드 코드 | 가상값 `acme` | 프로젝트 실제 코드 |
| `ignore_tags` | 비어 있음 | 랜딩존 자동 태거 키를 채운다 |

**첫 행이 가장 중요하다.** 이 예제가 VPC를 함께 만드는 것은 **예제이기 때문**이다 —
`01 §4`가 "예제가 곧 `tofu test` 대상"이라 self-contained해야 `validate`가 돌고, CI 게이트도 그걸
요구한다. 하지만 소비 프로젝트에서 networking과 eks-cluster는 **별도 배포 루트**다(`03 §4`).
이 구조를 그대로 복사하면 두 컴포넌트가 한 state에 묶여, 네트워크를 건드릴 때마다 클러스터가
plan 범위에 들어온다.

실제 소비 프로젝트는 이렇게 쓴다 — `terraform_remote_state`가 아니라 **태그 조회**다(`03 §3.1` 2순위):

```hcl
data "aws_vpc" "main" {
  filter { name = "tag:Name", values = ["vpc-acme-prd-an2-main"] }
}

data "aws_subnets" "node" {
  filter { name = "vpc-id", values = [data.aws_vpc.main.id] }
  # ⭐ VPC 모듈 D13이 붙이는 그룹 태그(vpc-v1.2.0+). Name 와일드카드 파싱이 아니다.
  filter { name = "tag:SubnetGroup", values = ["node-uniq"] }
}

module "eks" {
  source = "git::https://github.com/<org>/iac-module-library.git//modules/eks-cluster?ref=eks-cluster-v1.0.0"

  vpc_id     = data.aws_vpc.main.id
  subnet_ids = data.aws_subnets.node.ids
  # ...
}
```

**모듈은 이 방식을 이미 지원한다** — `vpc_id`·`subnet_ids`를 ID 리스트로 받으므로 값의 출처가
무엇이든 무관하다. 상세는 [`docs/design/20-eks-module.md §2.5-1`](../../docs/design/20-eks-module.md).
