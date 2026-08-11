# 07. 운영 런북

**읽는 사람**: 이미 선 환경을 운영하는 사람.

환경을 **만드는** 절차는 [`03-new-project.md`](03-new-project.md),
**걷어내는** 절차는 [`04-teardown.md`](04-teardown.md)가 소유한다.

---

## 1. 클러스터에 접근하기

EKS 엔드포인트가 private이므로 노트북에서 `kubectl`이 직접 닿지 않는다. workbench를 경유한다.

```bash
aws --profile <profile> --region <region> ssm start-session --target <instance-id>
```

workbench에는 kubeconfig가 이미 있다. `KUBECONFIG` 환경변수를 설정할 필요가 없다.

```bash
kubectl get nodes
k get po -A          # alias k 가 프로파일에 있다
nv                   # eks-node-viewer
```

인스턴스 ID를 모르면:

```bash
aws --profile <profile> --region <region> ec2 describe-instances \
  --filters "Name=tag:Name,Values=*workbench*" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`]|[0].Value]' --output text
```

> `send-command`로 비밀·자격증명을 조회하지 않는다. 출력이 SSM에 저장되고 CloudTrail에 남는다.
> 값을 봐야 하면 **대화형 세션**에서 사람이 직접 읽는다.

---

## 2. ArgoCD 웹 UI 접속 — 2홉

ArgoCD `Service`는 `ClusterIP`다. 노출을 만들지 않고 기존 인증 채널 위에 스트림만 얹는다.

```bash
# 1홉: workbench 안에서 port-forward
export HOME=/root KUBECONFIG=/root/.kube/config
setsid nohup kubectl -n argocd port-forward svc/argocd-server 18080:443 \
  --address 127.0.0.1 > /tmp/argocd-pf.log 2>&1 < /dev/null &

# 2홉: 로컬에서 SSM 포트 포워딩
aws --profile <profile> --region <region> ssm start-session \
  --target <instance-id> --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["18080"],"localPortNumber":["18080"]}'
```

브라우저에서 **https://localhost:18080**. 자체 서명 인증서 경고는 통과한다.

| 증상 | 원인 | 대응 |
|------|------|------|
| 갑자기 끊긴다 | SSM 세션 **유휴 타임아웃**(기본 20분) | 2홉만 다시 실행한다. 1홉은 살아 있다 |
| 재부팅·교체 후 안 된다 | 1홉이 사라졌다 | 1홉부터 다시 |

두 홉이 필요한 이유가 서로 다르다. 안쪽은 **`ClusterIP`가 가상 IP**라서 —
실재하는 주소가 아니라 각 **노드**의 kube-proxy가 DNAT할 뿐이고, 노드가 아닌 workbench엔 그 규칙이 없다.
바깥쪽은 **workbench에 인바운드가 0**이라서다.

---

## 3. ArgoCD 관리자 비밀번호 교체

seed 직후 **완료 조건**이다. 선택 항목이 아니다.

```bash
export ARGOCD_OPTS='--port-forward --port-forward-namespace argocd --insecure'

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo      # 대화형 세션에서만

argocd login --username admin                            # 프롬프트
argocd account update-password 2>/tmp/argocd-pw.err
kubectl -n argocd delete secret argocd-initial-admin-secret
```

| 주의 | 내용 |
|------|------|
| `--core`는 쓸 수 없다 | argocd-server를 우회해 **세션 토큰이 없다**. 신원이 필요한 작업은 `--port-forward` |
| `--insecure`의 뜻 | **클라이언트** 인증서 검증 생략이다. 서버 TLS를 끄는 것이 아니다 |
| `broken pipe` 로그 | 포워더가 CLI 안에서 돌아 stderr로 섞인다. **실패가 아니다** — `2>`로 분리한다 |
| 새 비밀번호 | `^.{8,32}$`를 만족해야 한다 |

교체 확인:

```bash
kubectl -n argocd get secret argocd-secret \
  -o jsonpath='{.data.admin\.passwordMtime}' | base64 -d; echo
kubectl -n argocd get secret argocd-initial-admin-secret     # NotFound 여야 한다
```

> 이 patch는 `selfHeal`에 되돌려지지 않는다. 차트가 `argocd-secret`을 `data` 없이 렌더하므로
> 런타임에 채워진 `admin.password`는 ArgoCD의 소유 필드가 아니다.

---

## 4. EKS 업그레이드

### 하드 제약 두 가지

- **마이너는 1단계씩만.** `1.35 -> 1.37` 직행은 불가하다. 두 번 돈다.
- **컨트롤플레인을 올리기 전에** 노드 kubelet이 이미 컨트롤플레인과 같은 마이너여야 한다.

### apply를 셋으로 나눈다

| 단계 | 바꾸는 값 | 무엇이 일어나나 |
|------|----------|----------------|
| 사전 | (없음) | Upgrade Insights로 deprecated API 스캔 + 노드 kubelet 버전 확인 |
| **apply 1** | `kubernetes_version` **+1 마이너** | 컨트롤플레인만 |
| **apply 2** | `managed_node_groups[*].ami_release_version` | 노드 롤링 교체 |
| **apply 3** | `cluster_addons[*].addon_version` **전부** | addon |

**한 커밋에 몰지 않는다.** 순서가 의존성 그래프에 맡겨지고, 모듈이 심어 둔 순서
(vpc-cni의 `before_compute`)는 **최초 생성**에서 옳도록 설계된 것이지 업그레이드 기준이 아니다.

승인 관점에서도 나뉘는 편이 낫다 — 컨트롤플레인 업그레이드는 되돌리기 어렵고(7일 rollback 창),
노드 교체는 워크로드 중단을 동반한다. 한 plan에 섞이면 **승인자가 무엇을 승인하는지 분간할 수 없다.**

### 값을 조회하는 법 — 추정하지 않는다

```bash
# 현재 버전
aws eks describe-cluster --name <cluster> --query 'cluster.version'

# ami_release_version — 아키텍처별로 값이 다르다
aws ssm get-parameter --region <region> \
  --name /aws/service/eks/optimized-ami/<k8s>/amazon-linux-2023/arm64/standard/recommended/release_version
#                                                                  ^^^^^ x86_64 는 여기를 바꾼다

# addon_version — f(kubernetes_version, region) 이다. k8s를 올릴 때마다 전 addon 재조회
aws eks describe-addon-versions --region <region> \
  --kubernetes-version <k8s> --addon-name <name> \
  --query 'addons[].addonVersions[].addonVersion'
```

> addon 버전이 **k8s 축과 리전 축 양쪽으로 파손된다**는 것이 실측으로 확인됐다.
> 그래서 핀의 소유자가 모듈이 아니라 배포 루트다.

---

## 5. GitOps 상태 확인

```bash
kubectl -n argocd get applications \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
```

| 상태 | 뜻 |
|------|-----|
| `Synced` / `Healthy` | 정상 |
| `OutOfSync`가 **고착** | 대개 CRD 스키마 defaulting. 해당 Application에 `ServerSideDiff=true`를 켠다 |
| `Progressing`이 오래 | 파드 이벤트를 본다. 대개 이미지 pull 또는 리소스 부족 |

root Application이 저장소를 실제로 읽었는지는 **revision으로** 판정한다:

```bash
kubectl -n argocd get application root-app -o jsonpath='{.status.sync.revision}{"\n"}'
```

값이 `main`이면 아직 **설정값**이다. **실제 커밋 SHA여야** pull에 성공한 것이다.

---

## 6. workbench 교체

인스턴스가 교체되면 kubeconfig · 도구 · 프로파일은 `user_data`가 다시 만든다.
**다시 서지 않는 것은 port-forward뿐이다** — 위 2절을 다시 실행한다.

`instance_type`을 기본값보다 작게 잡지 않는다. 부팅 중 `dnf`가 OOM으로 죽어
도구가 설치되지 않은 채 인스턴스만 정상으로 보인다.

---

## 7. 자주 쓰는 조회

```bash
# kubeconfig 재생성 (--name 필수. ListClusters 권한이 없다)
aws eks update-kubeconfig --region <region> --name <cluster>

# 노드 현황
kubectl get nodes -L node.kubernetes.io/instance-type,topology.kubernetes.io/zone

# Karpenter가 만든 노드만
kubectl get nodes -l karpenter.sh/nodepool
```

> `kubectl -o jsonpath`는 map 순회를 지원하지 않는다. 필요하면 `-o go-template`을 쓴다.
