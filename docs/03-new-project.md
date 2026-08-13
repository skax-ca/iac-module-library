# 03. 새 프로젝트 착수

**읽는 사람**: 새 고객사 프로젝트의 인프라를 처음부터 세우는 사람.

> **검증 상태**: L1~L3 을 백지에서 한 번에 세워 검증했다.
> ⚠️ **L0(부트스트랩)은 아직이다** — 검증 때 이미 있던 것을 그대로 썼다(3절).

레퍼런스 구현이 `iac-reference-infra`에 있다. 막히면 그 저장소의 실물을 본다.

---

## 0. 준비물

| 항목 | 확인 |
|------|------|
| AWS 계정 + 관리자 권한 | `aws sts get-caller-identity` |
| GitHub org + 저장소 생성 권한 | |
| 로컬 도구 | `tofu` · `aws` · `gh` · `session-manager-plugin` · `jq` |
| 이 저장소 접근 | private이면 배포 저장소가 읽을 GitHub App이 필요하다 |

```bash
brew install opentofu awscli gh jq
brew install --cask session-manager-plugin
```

---

## 1. 착수 전에 확정할 값

**되돌릴 수 없는 것들이다.** 고객사와 합의하고 시작한다.
판단 근거는 [`02-choose-your-path.md`](02-choose-your-path.md)가 소유한다.

| 값 | 예 | 왜 되돌릴 수 없나 |
|----|-----|------------------|
| `workload` 코드 | `demo` | 모든 리소스 이름에 들어간다 |
| 리전 | `ap-northeast-2` (`an2`) | 전면 재구축 |
| VPC CIDR | `10.50.0.0/24` | VPC 재생성 |
| 클러스터 이름 | `eks-demo-dev-an2-main-01` | 클러스터 재생성 |
| EKS 엔드포인트 public 여부 | `false` | 정책상 되돌리기 어렵다 |
| GitOps 경로 | 관리형 / self-managed | 재설치 + 재등록 |

**대상 계정이 공용인지 전용인지도 여기서 확인한다.** 공용이면 삭제 절차가 달라진다
([`04-teardown.md`](04-teardown.md)).

---

## 2. 배포 저장소 만들기

```bash
gh repo create <org>/<project>-infra --private
```

`iac-reference-infra`의 구조를 본뜬다:

```
bootstrap/            state 버킷 · OIDC provider · Role   (IaC 밖)
live/<env>/networking/  VPC
live/<env>/eks/         EKS + workbench
.github/workflows/    배포 루트마다 워크플로 하나
```

`live/*/networking`과 `live/*/eks`는 **state를 분리**한다.
결합은 `terraform_remote_state`가 아니라 **Name·태그 기반 `data` 조회**로만 한다.

---

## 3. 부트스트랩 — state 버킷 · OIDC · Role

`tofu`가 state 버킷을 만들려면 이미 state 버킷이 있어야 한다. 이 한 겹만 IaC 밖에 둔다.

```bash
export EXPECTED_ACCOUNT=<12자리 계정 ID>   # 필수. 기본값이 없다
cd bootstrap && ./bootstrap.sh
```

`EXPECTED_ACCOUNT`는 검증용이 아니라 **ARN 조립에 쓰인다.** 빠지면 부트스트랩이 성립하지 않는다.
스크립트가 실제 계정과 대조해 다르면 즉시 중단한다 — 공용 계정에서 조용히 다른 계정을 치지 않게 하는 장치다.

### 만들어지는 것

| 리소스 | 요점 |
|--------|------|
| S3 state 버킷 | 버저닝 + AES256 + 퍼블릭 차단 4개 + **lifecycle 7일** |
| OIDC provider | `token.actions.githubusercontent.com` · `aud=sts.amazonaws.com` · **thumbprint 설정 안 함** |
| 입구 Role | 신뢰 = OIDC + `sub` 3패턴 · 권한 = 실행 Role `AssumeRole` **하나뿐** |
| 실행 Role | 신뢰 = **입구 Role만** (계정 루트 아님) |

`use_lockfile = true`가 lock 객체 버전을 폭증시키므로 lifecycle이 선택이 아니다.

### 순서가 자유롭지 않다

```
① OIDC provider -> ② 입구 Role(신뢰=①) -> ③ 실행 Role(신뢰=②) -> ④ 입구 inline 정책(Resource=③)
```

IAM은 **신뢰 정책의 principal이 실제로 존재하는지 검증한다.** 아직 없는 Role을 principal로 쓰면
`MalformedPolicyDocument`다. ARN을 계산해서 상호 참조를 끊는 접근은 동작하지 않는다.

④가 마지막이어도 되는 이유는 **`Resource`는 존재 검증을 받지 않기** 때문이다.

**IAM은 eventual consistency다.** ②를 만든 직후 ③을 만들면 방금 만든 Role이 아직 안 보인다.
`bootstrap.sh`는 `Invalid principal`일 때만 재시도한다.

### OIDC `sub` 패턴 확인

2026-07-15 이후 생성된 저장소는 `sub`에 **이름이 아니라 숫자 ID**를 쓴다.

```
repo:<org>@<org_id>/<repo>@<repo_id>:environment:dev
```

**신뢰 정책을 쓰기 전에 실제 토큰의 `sub`를 확인한다.** 추정하지 않는다.
`environment`를 선언한 job만 `:environment:`를 받으므로 패턴을 하나로 뭉칠 수 없다.

### 검증

```bash
./verify.sh      # exit 0=일치 / 1=drift / 2=실행 불가
```

버킷명은 **git에 넣지 않는다.** GitHub 저장소 변수 `TF_STATE_BUCKET`과 로컬 `backend.hcl`에만 둔다.

---

## 4. 네트워크 (L1)

```bash
cat > live/dev/networking/backend.hcl <<'EOF'
bucket       = "<bootstrap.sh 가 출력한 버킷명>"
key          = "dev/networking.tfstate"
region       = "ap-northeast-2"
use_lockfile = true
EOF

tofu -chdir=live/dev/networking init -backend-config=backend.hcl
tofu -chdir=live/dev/networking validate
```

`backend.hcl`은 `.gitignore` 대상이라 **루트마다 새로 만든다.** 커밋하지 않는다.

> 🔴 **로컬에서 `plan`·`apply` 는 성립하지 않는다.** provider 가 실행 Role 을 assume 하는데
> 그 Role 은 **입구 Role 만 신뢰**한다 — 개인 IAM user 로는 관리자여도 `AccessDenied` 다.
> **로컬은 `init` + `validate` 까지**이고, 그 위는 전부 워크플로가 한다.
> **`validate` 만으로도 잡히는 것이 있다**(순환 참조·타입 오류). 훅이 push 때 이걸 돌린다.

`main.tf`는 [`05-modules.md`](05-modules.md)의 연결 예시를 따른다.
`eks_cluster_name`을 넘겨 EKS 자동 발견용 서브넷 태그를 붙인다 — 클러스터를 만들기 전에 해야 한다.

apply는 워크플로로 한다:

```bash
gh workflow run deploy-network.yml --ref main -f action=apply
```

> **L1 apply 전까지 EKS 워크플로의 plan은 실패한다** — `no matching EC2 VPC found`.
> EKS 루트가 VPC를 이름으로 조회하는데 아직 없기 때문이다. **순서가 있다는 신호이지 고장이 아니다.**
> 두 루트를 같은 커밋으로 건드리면 plan이 동시에 돌아 `main`에 빨간 X가 한 번 뜬다.

---

## 5. EKS와 workbench (L2)

같은 방식으로 `live/dev/eks`를 초기화한다(`key = "dev/eks.tfstate"`).

**세 모듈의 연결 순서**에 주의한다. `workbench`는 자기 SG ID와 Role ARN을 출력하고,
`eks-cluster`가 그것을 `access_entries`와 `cluster_security_group_additional_rules`로 받는다.
모듈끼리 직접 참조하지 않는다 — **배포 루트가 연결한다.**

> 🔴 **`workbench`에는 `eks_cluster_name`을 `module.eks.cluster_name`으로 넘긴다.**
> 값이 같다고 `local`에서 만든 문자열을 쓰면 **순서 간선이 없어져** workbench와 클러스터가
> 병렬로 생성된다. EC2는 1분, EKS는 10분이라 `user_data`의 `update-kubeconfig`가 전부 실패하고
> **kubeconfig 없는 workbench**가 남는다.
>
> ⛔ `depends_on = [module.eks]`로 풀지 않는다 — **순환이다.** `depends_on`은 모듈 전체에 걸리는데
> `eks-cluster`가 workbench의 role·SG를 이미 받아가고 있다. 값 참조는 리소스 단위라 고리가 닫히지 않는다.
> ⚠️ `eks_cluster_arn`은 **`local`을 유지한다.** 실 ARN은 plan 시점에 unknown이라 모듈의
> `count`를 깨뜨린다. 가르는 기준은 일관성이 아니라 **plan 시점에 값을 아느냐**다.

`workbench`의 도구 핀은 **nullable이다.** 지정하지 않으면 설치되지 않는다.

```hcl
kubectl_version = "1.34.1"
helm_version    = "3.21.3"
argocd_version  = "3.5.0"     # ArgoCD 차트 appVersion과 맞춘다
```

apply 후 접근을 확인한다:

```bash
aws ssm start-session --target <instance-id>
kubectl get nodes            # KUBECONFIG 설정 없이 동작해야 한다
```

---

## 6. GitOps (L3)

프로파일 B면 여기서 끝난다.

### GitOps 저장소 만들기

```bash
gh repo create <org>/<project>-platform-gitops --private
```

`iac-platform-gitops`의 레이아웃을 본뜬다. **이 저장소에 `.tf`를 두지 않는다.**

### ArgoCD seed

```bash
# workbench에서 실행한다
./scripts/argocd-seed.sh
```

스크립트는 매니페스트를 **생성하지 않는다.** GitOps 저장소에 커밋된 파일을 **그대로 apply**한다.
생성하면 커밋본과 바이트가 달라지고 그 차이가 영구 드리프트가 된다.
그래서 `--set`도, 인라인 heredoc 매니페스트도 쓰지 않는다.

### 완료 조건 — 비밀번호 교체

seed의 마지막 단계다. **선택이 아니다.** 절차는 [`07-runbooks.md`](07-runbooks.md) 3절.

---

## 7. 완료 판정

| # | 확인 | 명령 |
|---|------|------|
| 1 | 부트스트랩 drift 없음 | `./bootstrap/verify.sh` |
| 2 | 노드가 Ready | `kubectl get nodes` |
| 3 | root Application이 **커밋 SHA**를 읽음 | `kubectl -n argocd get application root-app -o jsonpath='{.status.sync.revision}'` |
| 4 | 전 Application이 `Synced` / `Healthy` | `kubectl -n argocd get applications` |
| 5 | 초기 비밀번호 Secret 삭제됨 | `kubectl -n argocd get secret argocd-initial-admin-secret` → NotFound |
| 6 | CI 게이트 통과 | GitHub Actions |

3번에서 값이 `main`이면 아직 **설정값**이다. 실제 커밋 SHA여야 pull에 성공한 것이다.

4번은 **두 열을 따로 본다.** `Synced`는 *"Git이 요구한 것을 적용했다"* 일 뿐이고, 그 요구 자체가
틀렸으면 여전히 `Synced`다 — 실패는 한 계층 아래(IAM·컨트롤러 런타임)에서 난다.
`Synced` / `Degraded` 조합이 보이면 컨트롤러 로그로 내려간다.

---

## 다음

- 운영 → [`07-runbooks.md`](07-runbooks.md)
- 걷어내기 → [`04-teardown.md`](04-teardown.md)
