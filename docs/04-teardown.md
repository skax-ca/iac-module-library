# 04. 환경 걷어내기

**읽는 사람**: PoC가 끝나 자산을 철수하거나, 환경 일부를 지워야 하는 사람.

> **검증 상태**: 이 절차는 아직 처음부터 끝까지 실행된 적이 없다.
> 실증 재구축으로 검증한 뒤 이 줄을 지운다.

---

## 0. 시작 전에 — 공용 계정이면 특히 읽는다

**삭제는 이 자산에서 가장 위험한 작업이다.** 생성은 잘못해도 내 것만 늘어나지만,
삭제는 잘못하면 **남의 것이 사라진다.**

대상 계정에 다른 팀의 자원이 있는지 먼저 확인한다.

```bash
aws --profile <p> --region <r> ec2 describe-vpcs --query 'length(Vpcs)'
aws --profile <p> --region <r> eks list-clusters
```

여러 개가 나오면 **공용 계정이다.** 이후 모든 수동 정리는 반드시 태그로 특정한다.

```bash
# 우리 것만 — Name 태그에 workload와 env가 들어간다
--filters "Name=tag:Name,Values=*<workload>-<env>*"
```

**이름을 눈으로 보고 지우지 않는다.** 비슷한 이름이 남의 것일 수 있다.

---

## 1. 삭제는 생성의 역순이 아니다

레이어는 역순으로 지우지만, 그 **앞에 단계가 하나 더 있다.**
`tofu destroy`는 **IaC가 만들지 않은 것을 모른다.**

| 무엇이 남는가 | 누가 만들었나 | tofu가 아는가 |
|--------------|-------------|--------------|
| Karpenter 노드 (EC2) | Karpenter 컨트롤러 | ❌ |
| ALB · TargetGroup | AWS Load Balancer Controller | ❌ |
| EBS 볼륨 | PVC (CSI 드라이버) | ❌ |
| ENI | VPC CNI | ❌ |
| CRD | helm 차트 (`crds.keep: true`) | ❌ |

**이것들을 먼저 치우지 않으면**: 노드는 계속 과금되고, ALB와 ENI는 **VPC 삭제를 막는다.**

```
0단계  삭제 보호 해제
1단계  클러스터 안에서 — IaC 밖 자원을 만든 것들을 먼저 지운다
2단계  L2 destroy  (EKS · workbench)
3단계  L1 destroy  (VPC)
4단계  잔존물 검증
```

---

## 2. 0단계 — 삭제 보호 해제

`deletion_protection = true`면 destroy가 **실패한다.** 2단계로 나눠 apply한다.

```hcl
# ① 보호만 끈다
module "vpc" { deletion_protection = false ... }
module "eks" { deletion_protection = false ... }
```

```bash
tofu -chdir=live/dev/eks apply
tofu -chdir=live/dev/networking apply
```

VPC 모듈은 `prevent_destroy`를 쓴다. **CLI 플래그로 우회할 수 없다** — 코드를 고쳐 apply해야 한다.
모듈이 교차 검증도 하므로 `deletion_protection = true`와 `vpc_enabled = false`를 동시에 줄 수 없다.

---

## 3. 1단계 — IaC 밖 자원 선처리

workbench에서 실행한다.

```bash
# ① ArgoCD가 다시 만들지 않게 자동 동기화를 끈다
kubectl -n argocd patch application <app> --type merge \
  -p '{"spec":{"syncPolicy":null}}'

# ② LoadBalancer 타입 Service와 Ingress — ALB/TG가 여기 딸려 있다
kubectl get svc -A --field-selector spec.type=LoadBalancer
kubectl get ingress -A
kubectl delete ingress --all -A
kubectl delete svc -A --field-selector spec.type=LoadBalancer

# ③ PVC — EBS 볼륨이 딸려 있다
kubectl get pvc -A
kubectl delete pvc --all -A

# ④ Karpenter NodePool — 이걸 지워야 노드가 회수된다
kubectl delete nodepool --all
kubectl delete ec2nodeclass --all
```

**순서가 중요하다.** ①을 건너뛰면 ArgoCD가 ②③④를 되살린다.
④를 건너뛰고 클러스터를 지우면 Karpenter 컨트롤러가 먼저 죽어 **노드가 고아가 된다** —
아무도 회수하지 않고 계속 과금된다.

확인:

```bash
kubectl get nodes            # Karpenter 노드가 사라졌는지
aws elbv2 describe-load-balancers --query 'LoadBalancers[?VpcId==`<vpc-id>`]'
```

---

## 4. 2단계 · 3단계 — destroy

```bash
tofu -chdir=live/dev/eks destroy
tofu -chdir=live/dev/networking destroy
```

**EKS destroy가 끝난 것을 확인하고 VPC로 넘어간다.** 겹치면 ENI가 남아 VPC가 막힌다.

```bash
aws eks list-clusters       # 우리 클러스터가 없어야 한다
```

---

## 5. 4단계 — 잔존물 검증

```bash
./scripts/teardown-verify.sh
```

수동으로 확인한다면, **비용이 계속 나는 것부터** 본다.

| 순위 | 자원 | 확인 |
|:---:|------|------|
| 1 | **NAT Gateway** | 트래픽 0이어도 시간당 과금 |
| 2 | **EC2 인스턴스** | Karpenter 고아 노드 |
| 3 | **EBS 볼륨** (`available`) | 붙어 있지 않아도 과금 |
| 4 | **Elastic IP** (미연결) | 미연결일 때 과금 |
| 5 | **ALB / NLB** | |
| 6 | EKS 클러스터 | 노드 0대여도 컨트롤 플레인 과금 |
| 7 | ENI (`available`) | 과금은 없으나 VPC 삭제를 막는다 |
| 8 | CloudWatch 로그 그룹 | 보존 기간만큼 저장 과금 |

```bash
R="--profile <p> --region <r>"
aws $R ec2 describe-nat-gateways --filter "Name=state,Values=available"
aws $R ec2 describe-instances --filters "Name=tag:Name,Values=*<workload>*" \
  "Name=instance-state-name,Values=running"
aws $R ec2 describe-volumes --filters "Name=status,Values=available"
aws $R ec2 describe-addresses --query 'Addresses[?AssociationId==null]'
aws $R elbv2 describe-load-balancers
aws $R logs describe-log-groups --log-group-name-prefix /aws/eks/<cluster>
```

---

## 6. 부분 삭제

전체 철수보다 이쪽이 흔하다.

### GitOps만 걷어내기

클러스터는 두고 ArgoCD만 뺀다.

```bash
kubectl -n argocd patch application <app> --type merge -p '{"spec":{"syncPolicy":null}}'
helm -n argocd uninstall argocd
kubectl delete ns argocd
```

**CRD는 남는다** (`crds.keep: true`). 다시 설치할 계획이면 그대로 두고,
완전히 뺄 거면 명시적으로 지운다.

```bash
kubectl get crd | grep argoproj.io
```

### 노드만 줄이기

```bash
kubectl scale deployment --all --replicas=0 -n <ns>     # 워크로드부터
kubectl delete nodepool <name>                          # Karpenter 노드 회수
```

관리형 노드그룹은 `managed_node_groups`의 `desired_size`를 줄여 apply한다.

### 환경 하나만 지우기

`live/<env>/` 하나만 destroy한다. **state가 분리돼 있어야 가능하다** —
그래서 networking과 eks의 state를 나눈 것이다.

### 야간 정지 (비용 절감)

EKS 컨트롤 플레인은 **끌 수 없다.** 노드만 줄인다.

```bash
kubectl delete nodepool --all              # Karpenter
# managed node group은 desired_size = 0 으로 apply
```

workbench는 정지할 수 있다.

```bash
aws ec2 stop-instances --instance-ids <id>
```

> workbench를 **재시작**하면 kubeconfig와 도구는 그대로다(`user_data`가 만든 디스크 상태).
> **종료 후 재생성**하면 `user_data`가 다시 돌아 같은 상태가 선다. 어느 쪽이든 port-forward는 다시 띄운다.

---

## 7. 되돌릴 수 없는 것

| 지우면 | 무엇을 잃나 |
|--------|------------|
| **S3 state 버킷** | state 전체. 남은 자원을 IaC로 회수할 방법이 사라진다 |
| **CloudWatch 로그 그룹** | 감사 로그. 보존 요건이 있으면 먼저 export |
| **EBS 볼륨** | 데이터. 스냅샷을 먼저 뜬다 |
| **OIDC provider** | CI가 즉시 멈춘다. 다른 저장소가 같은 provider를 쓸 수 있다 |

**state 버킷은 가장 마지막에 지운다.** 그리고 versioning이 켜져 있어 일반 삭제로는 지워지지 않는다.

```bash
aws s3api delete-objects --bucket <b> --delete "$(aws s3api list-object-versions \
  --bucket <b> --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"
aws s3 rb s3://<b>
```

> 부트스트랩(L0)은 계정 단위 자산이다. **다른 프로젝트가 같은 계정을 쓰면 남긴다.**

---

## 8. 자주 막히는 지점

| 증상 | 원인 | 대응 |
|------|------|------|
| `DependencyViolation` — 서브넷을 지울 수 없다 | ENI가 남아 있다 | `describe-network-interfaces`로 소유자 확인. 대개 ALB나 EKS |
| VPC destroy가 몇 분째 멈춰 있다 | ENI 해제 대기 | EKS가 완전히 사라졌는지 먼저 확인 |
| `prevent_destroy`로 plan이 실패한다 | 삭제 보호 | 2절 — 코드를 고쳐 apply한다 |
| destroy 후에도 노드가 살아 있다 | Karpenter 고아 | NodePool을 먼저 지웠어야 한다. 태그로 특정해 수동 종료 |
| 클러스터를 지웠는데 ALB가 남았다 | ALBC가 먼저 죽었다 | 태그(`elbv2.k8s.aws/cluster`)로 특정해 수동 삭제 |
| state lock이 풀리지 않는다 | apply가 중단됐다 | S3의 lock 객체를 확인 후 제거 |

---

## 다음

- 다시 세우기 → [`03-new-project.md`](03-new-project.md)
