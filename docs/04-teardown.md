# 04. 환경 걷어내기

**읽는 사람**: PoC가 끝나 자산을 철수하거나, 환경 일부를 지워야 하는 사람.

> **검증 상태**: 이 절차는 실환경에서 끝까지 실행해 검증했다.
> ⚠️ 다시 세우는 절차([`03-new-project.md`](03-new-project.md))는 **아직 검증되지 않았다** —
> *"지울 수 있다"* 가 *"되돌릴 수 있다"* 를 뜻하지는 않는다.

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
| **CloudWatch 로그 그룹** (재생성분) | AWS가 **destroy 도중** 자동 생성 | ❌ |

**이것들을 먼저 치우지 않으면**: 노드는 계속 과금되고, ALB와 ENI는 **VPC 삭제를 막는다.**

```
0단계  삭제 보호 해제
1단계  클러스터 안에서 — IaC 밖 자원을 만든 것들을 먼저 지운다
2단계  L2 destroy  (EKS · workbench)
3단계  L1 destroy  (VPC)
4단계  잔존물 검증 — destroy의 "성공" 보고를 믿지 않는다
```

> 🔑 **삭제는 한 번의 명령이 아니라 수렴 과정이다.** 이 문서에서 두 번 나온다 —
> ArgoCD가 지운 것을 되살리고(3절), CloudWatch가 지운 로그 그룹을 다시 만든다(5절).
> 둘 다 *"명령은 성공했는데 상태가 원래대로"* 다. 그래서 4단계는 마무리가 아니라 **절차의 일부**다.

---

## 2. 0단계 — 삭제 보호 해제

`deletion_protection = true`면 destroy가 **실패한다.** 2단계로 나눠 apply한다.

```hcl
# ① 보호만 끈다 — 커밋 메시지에 되돌릴 것임을 남긴다
module "vpc" { deletion_protection = false ... }
module "eks" { deletion_protection = false ... }
```

```bash
gh workflow run deploy-eks.yml     --ref main -f action=apply
gh workflow run deploy-network.yml --ref main -f action=apply
```

VPC 모듈은 `prevent_destroy`를 쓴다. **CLI 플래그로 우회할 수 없다** — 코드를 고쳐 apply해야 한다.
모듈이 교차 검증도 하므로 `deletion_protection = true`와 `vpc_enabled = false`를 동시에 줄 수 없다.

로컬 `tofu apply`가 아니다. 4절과 같은 이유로 이 apply도 워크플로에서만 실행된다.

🔴 **`false` 커밋을 되돌리는 것까지가 이 단계다.** 파기가 끝나면 `true`로 복원한다.
이 절의 변경은 **오래 살아 있으면 안 되는 커밋**이다 — 남겨 두면 다음 환경이 보호 없이 선다.

> `git push`가 pre-push 훅에서 막히면, 훅의 `tofu validate`가 backend 자격증명을 요구하는 것이다.
> `AWS_PROFILE=<프로파일> git push`로 넘긴다. `--no-verify`로 훅을 끄지 않는다.

> 🔴 **실측(2026-08-13): VPC와 EKS는 이 단계에서 다르게 반응한다.** VPC의 `deletion_protection`은
> `prevent_destroy`(Terraform lifecycle 메타 인자)로만 이어져 **AWS 쪽 실제 속성이 아니다** — `false`로
> 바꿔 apply해도 `No changes. Your infrastructure matches the configuration.`가 나온다. 반면 EKS의
> `deletion_protection`은 **AWS 네이티브 클러스터 속성**(`aws_eks_cluster.deletion_protection`)이라
> 실제로 `~ deletion_protection = true -> false`가 in-place 변경으로 잡히고, **apply를 돌려야 AWS에
> 반영된다.** 두 모듈을 같은 방식으로 다루면(둘 다 apply 필요/불필요로 가정) VPC 쪽에서
> *"apply했는데 아무 일도 안 일어났다"*로 당황하게 된다 — 결함이 아니라 애초에 바뀔 게 없었던 것이다.

---

## 3. 1단계 — IaC 밖 자원 선처리

workbench에서 실행한다.

**먼저 ArgoCD 컨트롤러를 멈춘다.** 살아 있으면 아래 ②③④를 지우는 족족 되살린다.
Application의 `syncPolicy`를 끄는 것으로는 **부족하다** — `kubectl patch`로 GitOps 리소스를
바꾸는 것은 컨트롤러와의 경쟁이고, App-of-Apps라 **root-app이 그 설정 자체를 복원한다.**

⚠️ **전체 파기에서만 이렇게 한다.** 클러스터를 남긴다면 6절 — 거기서는 Git에서 지운다.

```bash
# ① 컨트롤러 정지 — 이걸 건너뛰면 아래가 전부 되살아난다
kubectl -n argocd scale statefulset argocd-application-controller --replicas=0
kubectl -n argocd scale deployment  argocd-applicationset-controller --replicas=0

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

확인 — **지운 직후가 아니라 30초쯤 뒤에 본다.** 되살아나는 것은 시간차로 온다.

```bash
kubectl get nodes            # Karpenter 노드가 사라졌는지
kubectl get nodepool -A      # 되살아나지 않았는지
aws elbv2 describe-load-balancers --query 'LoadBalancers[?VpcId==`<vpc-id>`]'
```

> 🔴 **실측(2026-08-13): `kubectl get nodes`에 노드가 남아 있어도 실패가 아닐 수 있다.**
> NodePool의 `NODES` 열이 애초에 `0`이었다면(버스트 워크로드가 없어 Karpenter가 아무것도
> 프로비저닝하지 않은 상태), `kubectl delete nodepool`은 지울 Karpenter 노드가 없으므로
> `kubectl get nodes`의 노드 수는 그대로다. **그 노드들은 EKS 관리형 노드그룹(시스템 계층)
> 소속이라 Karpenter가 아니라 2단계 `tofu destroy`(EKS 모듈)가 회수한다.** 이 절차의 대상은
> Karpenter가 만든 노드뿐이다 — `kubectl get nodepool -A`로 원래 `NODES`가 몇 개였는지 먼저
> 보고, 0이었다면 이 단계에서 노드 수가 안 줄어도 정상이다.

---

## 4. 2단계 · 3단계 — destroy

🔴 **파기도 워크플로로 한다. 로컬에서는 실행할 수 없다.**
provider가 실행 Role을 assume하는데 그 Role은 **입구 Role만 신뢰**한다 —
로컬 사용자가 계정 관리자여도 `sts assume-role`이 `AccessDenied`다.

```bash
gh workflow run deploy-eks.yml --ref main \
  -f action=destroy -f confirm='destroy live/dev/eks'

# EKS 가 끝난 것을 확인한 뒤에 ↓
gh workflow run deploy-network.yml --ref main \
  -f action=destroy -f confirm='destroy live/dev/networking'
```

`confirm`에 **루트 이름을 손으로 적어야** 한다. 공용 계정이고 파기는 되돌릴 수 없어,
잘못된 워크플로에 dispatch하는 사고를 여기서 막는다.

`plan`만 `-destroy`로 갈리고 **apply는 생성과 같은 job이다** — 저장된 plan 파일을 적용하는
구조라 파기 계획도 **같은 승인 게이트를 그대로 흐른다.** 승인자는 요약의 `will be destroyed`를 읽고 누른다.

> 🔴 **실측(2026-08-13): "읽고 누른다"의 "누른다"는 이미 지나간 뒤다.** `workflow_dispatch`로
> `action=destroy`를 실행하면 그 **한 번의 dispatch 안에서** `plan` job이 끝나자마자 `apply` job이
> **자동으로** 이어진다(`needs: plan`) — 둘 사이에 사람이 개입할 별도 승인 스텝이 없다. 실측
> 간격은 **plan 완료 후 수십 초 이내**였다. 즉 진짜 승인 지점은 *"plan을 보고 apply를 누른다"*가
> 아니라 **"dispatch 자체를 누르기 전에 대상을 확인한다"**이다.
> - `confirm` 문자열은 **잘못된 루트를 파괴하는 사고**만 막지, **그 루트 안에서 예상 밖의 자원이
>   걸리는 것**은 막지 못한다.
> - 진짜 검토는 **dispatch 전에** 5절의 `teardown-verify.sh` 또는 `aws ec2 describe-*`로 태그
>   기준 현황을 먼저 눈으로 확인해 둬야 한다. dispatch 이후에 plan을 읽고 취소하려면
>   `gh run cancel <run-id>`를 **plan job이 끝나는 순간**(초 단위) 실행해야 하므로, 계획적 검토
>   수단으로 기대하지 않는다.

**EKS destroy가 끝난 것을 확인하고 VPC로 넘어간다.** 겹치면 ENI가 남아 VPC가 막힌다.

```bash
aws eks list-clusters       # 우리 클러스터가 없어야 한다
```

> `backend.hcl`은 **루트마다 따로** 있고 `.gitignore` 대상이라 clone 직후 로컬에 없다.
> 파기는 워크플로가 하므로 필요 없지만, **로컬에서 state를 들여다볼 때** 걸린다.

---

## 5. 4단계 — 잔존물 검증

```bash
WORKLOAD=<code> ENVIRONMENT=<env> AWS_PROFILE=<p> ./scripts/teardown-verify.sh
```

종료 코드: `0` 잔존물 없음 · `1` 잔존물 있음 · `2` 실행 불가.
**아무것도 지우지 않는다** — 남은 것을 찾을 뿐이다. 지우는 것은 사람이 한다.

🔴 **`tofu destroy`가 성공해도 로그 그룹이 남을 수 있다.** 원본이 지워진 뒤에도 아직 살아 있던
Flow Logs가 로그를 쓰면 CloudWatch가 같은 이름을 **자동으로 만든다.** 자동 생성분은
**보존 무기한**이라 저장 비용이 영원히 나가고, state에 없으니 다음 apply에서도 보이지 않는다.
`retentionInDays`가 비어 있으면 그것이다 — **손으로 지운다.**

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

⚠️ **3절의 "컨트롤러를 멈춘다"를 여기 가져오지 않는다.** 클러스터를 남기는데 컨트롤러만 죽이면
Git과 클러스터가 조용히 갈라진다 — 걷어낸 것이 아니라 부순 것이다. **여기서는 Git에서 지운다.**

```bash
# ① Git에서 매니페스트를 지운다 (플랫폼 매니페스트는 iac-platform-gitops 소관)
# ② ArgoCD가 그것을 반영한 뒤에 제거한다
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
| 로컬 destroy가 `AccessDenied` | 실행 Role 신뢰가 입구 Role 하나뿐 | 로컬 경로는 **없다.** 4절 — 워크플로로 파기한다 |
| 지운 리소스가 되살아난다 | ArgoCD 컨트롤러가 살아 있다 | 3절 — `patch`가 아니라 컨트롤러를 `scale 0` |
| destroy 성공 후 로그 그룹이 남았다 | 살아 있던 Flow Logs가 쓰자 CloudWatch가 자동 생성 | state에 없다. **손으로 지운다**(5절) |
| `git push`가 훅에서 막힌다 | pre-push의 `validate`가 backend 자격증명을 요구 | `AWS_PROFILE=<p> git push`. `--no-verify` 금지 |
| `tofu init`이 `context deadline exceeded`로 실패(provider SHA256SUMS 다운로드) | GitHub Actions runner ↔ provider registry 간 일시적 네트워크 지연. 일회성 아님(H2와 같은 계열) | **새 dispatch가 아니라** `gh run rerun <run-id> --failed` — 새 dispatch는 plan을 다시 돌려 승인 대상이 바뀐다. `--failed`는 실패한 job만 재시도해 기존 plan을 유지한다(실측 확인) |

---

## 다음

- 다시 세우기 → [`03-new-project.md`](03-new-project.md)
