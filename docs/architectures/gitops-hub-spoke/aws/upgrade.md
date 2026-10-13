# EKS 마이너 업그레이드의 설계

**읽는 사람**: Kubernetes 마이너 업그레이드 절차를 설계하거나 검토하는 사람.

따라 하는 절차는 레퍼런스 배포 저장소 `eks-reference-infra`의 `docs/upgrade.md`와
`docs/upgrade-rollback.md`가 갖는다. 이 문서는 그 절차가 왜 그 순서인지를 갖는다.

---

## 1. 순서

```
[필요할 때만] 플랫폼 addon 승격 (GitOps, nonprd → prd)
  → Karpenter disruption 차단    (GitOps)
  → 컨트롤플레인                  (배포 루트)
  → system 노드그룹               (배포 루트)
  → cluster-autoscaler 이미지     (GitOps)
  → 되돌릴지 정한다
  → Karpenter disruption 차단 해제 (GitOps)
  → EKS 관리형 addon              (배포 루트)
  → workbench의 kubectl           (배포 루트)
```

AWS의 두 문서가 addon과 노드의 앞뒤를 다르게 적는다.

| 문서 | 순서 |
|------|------|
| [Update existing cluster](https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html) | 컨트롤플레인 → 노드 → cluster-autoscaler → EKS addon → `kubectl` |
| [Best Practices for Cluster Upgrades](https://docs.aws.amazon.com/eks/latest/best-practices/cluster-upgrades.html) | 컨트롤플레인 → addon·컨트롤러 → `kubectl` → 노드 |

두 순서 모두 Kubernetes의 버전 skew 정책 안에 있다. 이 패턴은 앞의 것을 따른다. EKS는 되돌릴 때
addon을 되돌려 주지 않는다. addon을 맨 뒤에 두면 되돌릴 수 있는 구간에서 되돌릴 대상이 컨트롤플레인과
노드뿐이다. 치르는 값은 노드를 다 바꾼 뒤 `vpc-cni`와 `kube-proxy` DaemonSet이 전 노드에서 한 번 더
롤링되는 것이다.

---

## 2. 컨트롤플레인과 노드그룹을 다른 apply로 나눈다

노드그룹의 `kubernetes_version`을 배포 루트가 명시로 적는다. 적지 않으면 upstream 모듈이 노드그룹
버전을 클러스터 버전에서 받아 와, 클러스터 버전만 올린 plan에 노드그룹 교체가 함께 뜬다.

| 얻는 것 | 내용 |
|---------|------|
| 멈춰 볼 지점 | 컨트롤플레인만 올라간 상태에서 API·addon·워크로드를 확인하고 노드로 넘어간다 |
| 실패의 격리 | 노드그룹이 `PodEvictionFailure`로 실패해도 컨트롤플레인 apply는 이미 끝난 run이다 |
| 자격증명 한도 | CI의 자격증명이 1시간짜리다. apply 하나가 한 작업만 해서 한도에서 멀어진다 |
| 대칭인 되돌리기 | 되돌릴 때 두 커밋을 역순으로 revert한다 |

---

## 3. Karpenter의 disruption을 차단했다가 푼다

`EC2NodeClass`는 버전을 적은 alias(`al2023@v<날짜>`)로 AMI를 고른다. 이 alias는 AMI 릴리스만 고정하고
Kubernetes 마이너는 고정하지 않는다. Karpenter가 alias를 **컨트롤플레인 버전에 맞는 AMI**로 풀기
때문이다([Managing AMIs](https://karpenter.sh/docs/tasks/managing-amis/)). 컨트롤플레인이 올라가면 alias를
고치지 않아도 기존 노드가 drift로 판정되어 교체된다.

app 워크로드가 Karpenter 노드에 있다. 컨트롤플레인과 system 노드그룹을 확인하기 전에 app 노드가 먼저
바뀌는 것을 막으려고, `NodePool`의 disruption budget에 `Drifted`와 `Underutilized`를 `nodes: "0"`으로 막는
줄을 티어별 스위치로 둔다.

| 막는 것 | 막지 못하는 것 |
|---------|----------------|
| drift 교체, consolidation | 스케일 아웃, spot 중단, 만료(`expireAfter`). 이렇게 새로 뜨는 노드는 새 마이너다 |

`Underutilized`까지 막는 이유는 차단 중에 consolidation이 노드를 바꾸면 그 노드가 새 마이너로 뜨기
때문이다. `Empty`는 막지 않는다. 파드가 없는 노드라 워크로드가 움직이지 않는다.

### 🔑 차단을 풀기 전까지가 되돌릴 수 있는 구간이다

되돌릴 때는 노드가 컨트롤플레인보다 먼저 내려가야 한다. 관리형 노드그룹은 값을 내려 되돌릴 수 있다.
Karpenter 노드는 alias가 컨트롤플레인을 따라가므로 먼저 내릴 수단이 없다. 그래서 차단을 풀기 전에
되돌릴지를 정하고, 푼 뒤에는 되돌리지 않고 새 마이너에서 고친다.

차단 중에 새어 나간 몇 대는 EKS의 insight 검사를 `--force`로 건너뛰어 컨트롤플레인을 내린 뒤 지운다.
AWS가 먼저 내릴 수단이 없는 Fargate에 대안으로 적은 방법이고, 새 마이너의 kubelet이 옛 마이너의
컨트롤플레인 아래에 잠시 놓인다. 차단 기간이 짧을수록 이 경로를 탈 일이 줄어든다.

---

## 4. addon은 종류마다 시점이 다르다

| 종류 | 무엇 | 자리 | 시점 |
|------|------|------|------|
| 플랫폼 addon | Karpenter, AWS Load Balancer Controller, Kyverno, KEDA, Gateway API CRD | GitOps 버전 표 | 클러스터보다 **먼저**. 지금 버전이 새 마이너를 지원하지 않을 때만 |
| cluster-autoscaler 이미지 | 클러스터 마이너를 따라가는 값 | GitOps, 티어별 | system 노드그룹 뒤 |
| EKS 관리형 addon | `vpc-cni`, `coredns`, `kube-proxy` 등 | 배포 루트 `cluster_addons` | 노드 전부 뒤 |

플랫폼 addon이 앞이고 EKS 관리형 addon이 뒤인 것은 호환의 방향이 반대라서다. 컨트롤러는 한 버전이 여러
마이너를 지원하고 새 버전이 옛 마이너에서도 돈다. 먼저 올려 두면 두 티어의 마이너가 갈린 승격 구간을
한 버전으로 건넌다. EKS 관리형 addon은 마이너마다 호환 목록이 따로 있어 컨트롤플레인보다 먼저 올릴 수
없다. 지금 핀이 새 마이너의 호환 목록에 없는 addon만 예외로 먼저 올린다.

플랫폼 addon 승격은 Kubernetes 업그레이드와 다른 변경이다. 같은 구간에 섞으면 문제의 원인이 컨트롤러
버전인지 Kubernetes 마이너인지 가를 수 없다.

---

## 5. 티어 승격과 hub

nonprd 티어의 클러스터를 끝까지 올리고 확인한 뒤 prd 티어를 올린다. GitOps의 티어별 값(disruption 차단,
cluster-autoscaler 이미지)이 이 승격을 클러스터 하나씩으로 가른다. 배포 루트는 클러스터마다 파일과
워크플로가 달라 PR 하나가 클러스터 하나만 건드린다.

- 승격 구간에는 티어로 가르지 않은 매니페스트가 두 마이너 모두에서 유효해야 한다. 새 마이너에만 있는
  API를 쓰는 변경은 마지막 클러스터까지 끝난 뒤에 넣는다.
- hub는 ArgoCD가 도는 클러스터다. ArgoCD가 system 노드그룹에 있어 hub의 노드그룹을 올리는 동안 노드와
  함께 옮겨진다. 복제본이 하나인 application-controller가 옮겨지는 동안 전 클러스터의 reconcile이 멈춘다.
  그래서 ArgoCD를 HA 구성으로 두고 system 노드그룹을 3대로 잡는다.

---

## 6. 하지 않는 것

| 하지 말 것 | 이유 |
|---|---|
| 컨트롤플레인·노드그룹·addon을 **한 apply로** 올리기 | 멈춰 볼 지점이 없고, 중간에 실패하면 어디까지 적용됐는지를 state와 실제에서 따로 읽어야 한다. 1시간 자격증명 한도에도 가까워진다 |
| EKS 관리형 addon을 **노드보다 먼저** 올리기 | 되돌릴 수 있는 구간에 addon 내리기가 항상 끼어든다. 재평가 트리거: DaemonSet의 두 번째 롤링이 워크로드를 끊는 것이 확인되면 |
| 되돌리기 위해 **AMI를 옛 마이너로 고정하는 스위치**를 NodePool 차트에 두기 | Karpenter 노드를 컨트롤플레인보다 먼저 내리는 AWS 권장 순서를 맞추지만, alias 대신 AMI 이름을 고르는 값과 그 전환 절차가 티어 맵에 하나 더 생긴다. 차단을 풀기 전에 되돌릴지를 정하면 필요한 경우가 새어 나간 몇 대뿐이다. 재평가 트리거: 차단을 푼 뒤에 되돌려야 하는 일이 생기면 |
| disruption 차단을 **켠 채로 두기** | 낡은 AMI의 노드가 남고 노드가 합쳐지지 않는다. 차단 중에 새로 뜨는 노드가 늘어 되돌리기가 비상 경로가 된다 |
| prd의 Karpenter 노드에 **spot** 쓰기 | 회수 시점을 고를 수 없다. 차단 중에도 spot 중단은 노드를 새 마이너로 바꾼다 |
