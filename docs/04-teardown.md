# 04. 환경 걷어내기

**읽는 사람**: PoC가 끝나 자산을 철수하거나, 환경 일부를 지워야 하는 사람.

> **검증 상태**(2026-08-12 갱신): **파기는 2026-08-11 `ref-dev` 에서 끝까지 실행됐다** —
> `teardown-verify.sh` 잔존물 0 · `exit 0`. 이 문서의 🔬 표시가 그때의 실측이고,
> 초안이 **틀렸던 지점**은 그 자리에 적어 뒀다.
>
> ⚠️ **재구축은 아직 검증되지 않았다.** "지울 수 있다"가 "되돌릴 수 있다"를 뜻하지는 않는다 —
> 다시 세우는 절차는 [`03-new-project.md`](03-new-project.md) 소관이고 그쪽은 여전히 초안이다.

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
| 🔬 **CloudWatch 로그 그룹** (재생성분) | **AWS가 destroy 도중 자동 생성** | ❌ |

**이것들을 먼저 치우지 않으면**: 노드는 계속 과금되고, ALB와 ENI는 **VPC 삭제를 막는다.**

> 🔬 마지막 행은 실증에서만 나온 것이다. `tofu` 가 로그 그룹을 지운 **뒤에도** 아직 살아 있던
> Flow Logs 가 로그를 쓰자 CloudWatch 가 같은 이름을 **자동으로 다시 만들었다**(5절). 자동 생성분은
> 보존 기간이 없어 **영원히 과금**되고, state 에 없으니 다음 apply 에서도 보이지 않는다.

```
0단계  삭제 보호 해제
1단계  클러스터 안에서 — IaC 밖 자원을 만든 것들을 먼저 지운다
2단계  L2 destroy  (EKS · workbench)
3단계  L1 destroy  (VPC)
4단계  잔존물 검증 — destroy 의 "성공" 보고를 믿지 않는다
```

> 🔑 **삭제는 한 번의 명령이 아니라 수렴 과정이다.** 실증에서 나온 결함 2건(G7·G8)이 같은 형태였다 —
> *"명령은 성공했는데 상태가 원래대로"*. 그래서 4단계는 형식적 마무리가 아니라 **절차의 일부**다.

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

> 🔬 **로컬 `tofu apply` 가 아니다.** 4절과 같은 이유로 이 apply 도 워크플로에서만 실행된다.

🔴 **`false` 커밋을 되돌리는 것까지가 이 단계다.** 재구축 전에 `true` 로 복원한다 —
실증 때 이 복원이 다음 세션 몫으로 남았고, 그동안 두 루트가 **보호 없는 상태로 `main` 에 있었다.**
지금 지우려는 것이 아니라면 이 절의 변경은 **오래 살아 있으면 안 되는 커밋**이다.

🔬 **`git push` 가 pre-push 훅에서 막힐 수 있다**(G5). 훅의 `tofu validate` 가 backend 를 초기화하려
자격증명을 요구한다. `AWS_PROFILE=<프로파일> git push` 로 넘긴다 — `--no-verify` 로 훅을 끄지 않는다.

---

## 3. 1단계 — IaC 밖 자원 선처리

workbench에서 실행한다.

> ### 🔴 🔬 초안이 틀렸던 지점 — **`syncPolicy` 를 꺼도 되돌려진다**
>
> 초안은 ①에서 `syncPolicy` 를 `null` 로 patch 하라고 했다. **부족하다.**
> 실측: 자식 Application 7개를 patch 했는데 확인 시점에 **6개가 원래 값으로 돌아와 있었고**,
> NodePool 도 삭제 직후 되살아났다(`NodePool: 1`).
>
> **원인**: `kubectl patch` 로 GitOps 리소스를 바꾸는 것은 **컨트롤러와의 경쟁**이다.
> 컨트롤러가 계속 살아 있으니 큐에 있던 sync 가 Git 의 desired state 로 되돌린다.
> 게다가 App-of-Apps 구조라 **root-app 이 자식의 `syncPolicy` 자체를 복원한다.**
>
> **해법 — 전체 파기에서는 컨트롤러를 멈춘다.**
> ```bash
> kubectl -n argocd scale statefulset argocd-application-controller --replicas=0
> kubectl -n argocd scale deployment  argocd-applicationset-controller --replicas=0
> ```
> 정지 후 삭제하니 30초 뒤에도 **NodePool 0 이 유지**됐다.
>
> ⚠️ **전체 파기에서만 옳다.** 클러스터를 남기는 부분 삭제라면 6절을 본다 — 거기서는
> **Git 에서 지우는 것**이 정석이고, 컨트롤러를 죽이는 것은 GitOps 를 부수는 짓이다.

```bash
# ① 컨트롤러를 멈춘다 — patch 로는 이길 수 없다(위 실측)
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

확인 — 🔬 **지운 직후가 아니라 30초쯤 뒤에 다시 본다.** 되살아나는 것은 시간차로 온다.

```bash
kubectl get nodes            # Karpenter 노드가 사라졌는지
kubectl get nodepool -A      # 되살아나지 않았는지 (실측: 정지 전에는 되살아났다)
aws elbv2 describe-load-balancers --query 'LoadBalancers[?VpcId==`<vpc-id>`]'
```

---

## 4. 2단계 · 3단계 — destroy

> ### 🔴 🔬 초안이 틀렸던 지점 — **로컬에서 `tofu destroy` 를 실행할 수 없다**
>
> 초안은 `tofu -chdir=... destroy` 를 시켰다. **그 명령은 이 형상에서 성립하지 않는다.**
> 세 사실이 겹쳐 **파기 경로가 아예 존재하지 않았다**:
> ① 워크플로에 destroy 잡이 없었다 ② provider 가 `assume_role` 로 실행 Role 을 쓴다
> ③ 실행 Role 의 신뢰가 **입구 Role 하나뿐**이다.
> 실측: 로컬 사용자가 관리자 권한(`AWStf_admin`)인데도 `sts assume-role` → **`AccessDenied`**.
>
> 🔑 **결함이 아니라 누락이다** — 생성 경로만 만들고 파기 경로를 안 만든, D27-1 의 의도된 귀결이다.
> **해결**: 워크플로에 `action=destroy` 입력을 신설했다. 신뢰 경계를 **우회하지 않고 그 안에** 냈다.

```bash
gh workflow run deploy-eks.yml --ref main \
  -f action=destroy -f confirm='destroy live/dev/eks'

# EKS 가 끝난 것을 확인한 뒤에 ↓
gh workflow run deploy-network.yml --ref main \
  -f action=destroy -f confirm='destroy live/dev/networking'
```

`confirm` 에 **루트 이름을 손으로 적게 한다.** 공용 계정이고 파기는 되돌릴 수 없어,
잘못된 워크플로에 dispatch 하는 사고를 여기서 막는다.

⭐ **`apply` job 은 한 줄도 바꾸지 않았다.** `plan` 만 `-destroy` 로 갈리고, 저장된 plan 파일을
적용하는 구조라 **파기 계획도 같은 승인 게이트를 그대로 흐른다.** 승인자는 요약에서
`will be destroyed` 목록을 읽고 누른다.

**EKS destroy가 끝난 것을 확인하고 VPC로 넘어간다.** 겹치면 ENI가 남아 VPC가 막힌다.

```bash
aws eks list-clusters       # 우리 클러스터가 없어야 한다
```

> 🔬 **`backend.hcl` 은 루트마다 따로 있다**(G1). gitignore 대상이라 clone 직후 로컬에 없을 수 있다.
> 워크플로가 파기를 수행하므로 파기 자체에는 필요 없지만, **로컬에서 state 를 들여다볼 때** 걸린다.

---

## 5. 4단계 — 잔존물 검증

```bash
WORKLOAD=<code> ENVIRONMENT=<env> AWS_PROFILE=<p> ./scripts/teardown-verify.sh
```

종료 코드: `0` 잔존물 없음 · `1` 잔존물 있음 · `2` 실행 불가.
**아무것도 지우지 않는다** — 남은 것을 찾을 뿐이다.

> 🔑 **"삭제는 사람이, 검증은 기계가"** 는 의식적인 설계 판단이고, 실증에서 값을 냈다.
> 자동 삭제 스크립트였다면 아래 G8 을 **못 봤다** — 지우고 끝냈을 테니까.

🔬 **양성·음성 양쪽으로 검증됨**: 자원이 있을 때 공용 계정에서 **정확히 우리 것만** 잡았고
(VPC 27개 중 1개 · EKS 3개 중 1개) `exit 1`, 전부 지운 뒤 **잔존물 0 · `exit 0`**.

> ### 🔴 🔬 초안이 놓친 것 — **로그 그룹이 destroy 도중 되살아난다**
>
> `tofu destroy` 가 **성공을 보고한 뒤** 검증이 로그 그룹 하나를 잡았다.
> 생성 시각이 **destroy 진행 중**이고 `retentionInDays` 가 **`None`** 이었다 —
> 모듈은 보존 기간을 항상 설정하므로 **우리가 만든 것이 아니다.**
>
> **원인**: 원본은 지워졌는데 **아직 살아 있던 Flow Logs 가 로그를 쓰자 CloudWatch 가 자동 생성**했다.
> 자동 생성분은 **보존 무기한** = 저장 비용이 영원히 나가는 고아다.
>
> 🔑 **`tofu` 는 이것을 영원히 모른다.** destroy 는 성공했고 state 에도 없어 **다음 apply 에서도 안 보인다.**
> ⇒ 그래서 4단계는 생략 가능한 마무리가 아니다. 잡히면 **손으로 지운다**(태그·이름으로 특정할 것).

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

> ⚠️ **3절의 "컨트롤러를 멈춘다"를 여기 가져오지 않는다.** 저것은 **전부 지울 때만** 옳다.
> 클러스터를 남기는데 컨트롤러만 죽이면 Git 과 클러스터가 조용히 갈라진다 — GitOps 를 부순 것이지
> 걷어낸 것이 아니다. **여기서는 Git 에서 지우는 것이 정석이다.**

```bash
# ① Git 에서 지운다 — desired state 를 바꾸는 것이 유일하게 안정적인 방법이다
#    (플랫폼 매니페스트는 iac-platform-gitops 소관)

# ② Git 이 비워진 것을 ArgoCD 가 반영한 뒤에 제거한다
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
| 🔬 로컬 destroy가 `AccessDenied` | 실행 Role 신뢰가 입구 Role 하나뿐 | 로컬 경로는 **없다.** 4절 — 워크플로로 파기한다 |
| 🔬 지운 리소스가 되살아난다 | ArgoCD 컨트롤러가 살아 있다 | 3절 — `patch` 가 아니라 컨트롤러를 `scale 0` |
| 🔬 destroy 성공 후 로그 그룹이 남았다 | 살아 있던 Flow Logs가 쓰자 CloudWatch가 자동 생성 | state에 없다. **손으로 지운다**(5절) |
| 🔬 `git push`가 훅에서 막힌다 | pre-push의 `validate`가 backend 자격증명을 요구 | `AWS_PROFILE=<p> git push`. `--no-verify` 금지 |

---

## 다음

- 다시 세우기 → [`03-new-project.md`](03-new-project.md)
