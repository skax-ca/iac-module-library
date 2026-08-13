# scripts — 운영 절차 스크립트

소비 프로젝트가 **실행하는 절차** 중 재사용 가치가 있는 것을 여기서 소유한다.

> ⚠️ **이 repo는 배포하지 않는다.** 여기 있는 것은 **실행되는 자산**이지 이 repo가 실행하는 것이 아니다.
> 그래서 모든 스크립트는 **환경값을 하드코딩하지 않는다**([`06-conventions.md`](../docs/06-conventions.md) 파라미터화 요건).
> 특정 클러스터·계정·저장소를 가정하는 순간 재사용 자산이 아니게 된다.

| 스크립트 | 무엇 | 설계 SSOT |
|---|---|---|
| `argocd-seed.sh` | self-managed ArgoCD 부트스트랩 seed (0·2·3·4·5단계) | [`02-choose-your-path.md`](../docs/02-choose-your-path.md) · [`03-new-project.md`](../docs/03-new-project.md) |

---

## `argocd-seed.sh`

### 무엇을 하는가

GitOps 저장소를 pull 하는 self-managed ArgoCD를 부트스트랩한다. 단계는 **순서대로** 실행되며
각 단계가 다음 단계의 전제다.

| # | 단계 | 비고 |
|---|---|---|
| 0 | `helm install argo-cd` | 저장소에 커밋된 values 파일 **그대로** |
| — | ~~1 Access Entry~~ | ⛔ self-managed에는 없다 — ArgoCD가 클러스터 안에 있다. spoke 붙일 때만 필요(Terraform 소관) |
| 2 | GitHub App repository Secret | ⚠️ **자기소멸 원칙의 유일한 예외** — 아래 |
| 3 | `platform` AppProject | |
| 4 | cluster Secret | ⚠️ "등록"이 아니라 **라벨·이름 공급**이 목적 |
| 5 | root Application | 자기 자신을 흡수 |

### ⭐ 이 스크립트의 설계 제약 — 자기소멸(self-superseding)

**매니페스트를 생성하지 않는다.** GitOps 저장소에 커밋된 파일을 **그대로 apply** 한다.
생성하면 커밋본과 바이트가 달라지고, root App이 흡수한 순간 `selfHeal`이 그 차이를 되돌린다.
증상은 *"방금 넣은 설정이 사라진다"* 이고 **원인을 가리키지 않는다.**

그래서 스크립트는:
- ⛔ `helm --set`을 쓰지 않는다 (values는 저장소 파일 하나뿐)
- ⛔ 인라인 heredoc 매니페스트를 쓰지 않는다
- ✅ **저장소가 dirty하면 실행을 거부한다** (`git status --porcelain`)
- ✅ 로컬 HEAD가 upstream과 다르면 경고한다 — **ArgoCD는 원격을 읽는다**

### 🔴 2단계는 유일한 예외다

repository Secret은 GitHub App private key를 담아 **저장소에 커밋할 수 없다.**
⇒ 이 Secret 하나만 GitOps 관리 밖에 남는다.

- root App의 `prune: false` 덕에 **지워지지 않는다**
- ⚠️ **이것이 사라지면 모든 sync가 멈춘다** — 복구 절차는 아래 **키 전달 경로** 절이 소유한다

### 🔑 private key를 workbench로 옮기는 경로 — **SSM Parameter Store SecureString**

클러스터가 private이라 seed는 **workbench 안에서** 실행되는데([`05-modules.md`](../docs/05-modules.md) `workbench`),
workbench는 **SSM Session Manager 전용**이라 `scp`가 없다. 그리고 스크립트는 키를
**파일 경로**로 받는다(`--from-file=`) — 환경변수 주입으로는 대체되지 않는다.
⇒ **키의 실물 파일이 workbench 디스크에 있어야 한다.** 그 경로를 이렇게 정한다.

**실측 근거** (2026-08-07, 실계정 조회):

| 확인한 것 | 값 | 그래서 |
|---|---|---|
| `AmazonSSMManagedInstanceCore` | `ssm:GetParameter`/`GetParameters` on **`Resource: "*"`** 포함 | workbench Role에 **IAM 추가 0** |
| `alias/aws/ssm` 키 정책 | `Principal: {"AWS":"*"}` + `kms:ViaService=ssm.<region>` **직접 부여** | SecureString 복호화에 **`kms:Decrypt` 추가 불필요** |
| Standard tier 파라미터 | 4KB · **과금 없음** | RSA 2048 PEM(~1.7KB)이 들어간다. 넘으면 `--tier Advanced`(유료) |

#### 절차

```bash
# ── ① 노트북에서 한 번 — 키를 SecureString으로 올린다 ──────────────────
#    `file://~/...` 의 틸드는 AWS CLI가 확장한다(실측). 값은 stdout에 찍히지 않는다.
aws ssm put-parameter --region <region> \
  --name /<workload>/<env>/gitops/github-app-private-key \
  --type SecureString \
  --description "ArgoCD seed 임시 — GitHub App private key. seed 완료 후 삭제한다" \
  --value file://~/.config/gh-apps/<app>.private-key.pem
#  ⭐ --description 을 반드시 붙인다. 공용 계정에는 남의 파라미터가 섞여 있어,
#     정체를 밝히지 않으면 아무도 지우지 못하는(= 남는) 자격증명이 된다.

# ── ② workbench 안에서 — 파일로 내린다 ────────────────────────────────
umask 077                                    # 0600으로 만든다. chmod 전에 넣는다
aws ssm get-parameter \
  --name /<workload>/<env>/gitops/github-app-private-key \
  --with-decryption --query Parameter.Value --output text > ~/gh-app.pem
#  ⭐ 리다이렉트가 핵심이다 — 키가 터미널에 출력되지 않으므로
#     세션 로깅이 켜진 계정에서도 로그에 남지 않는다.
#  ℹ️ 내려받은 파일은 원본보다 **1바이트 크다** — `--output text`가 후행 개행을
#     붙이기 때문이다(실측: 1675 → 1676). PEM은 이를 정상으로 받는다.
#     체크섬이 다르다고 손상으로 오해하지 말 것. 검증은 `openssl rsa -noout -check`로.

export GH_APP_PRIVATE_KEY=~/gh-app.pem
./scripts/argocd-seed.sh

# ── ③ 완료 조건 — 위생이 아니라 조건이다 ──────────────────────────────
shred -u ~/gh-app.pem
aws ssm delete-parameter --region <region> \
  --name /<workload>/<env>/gitops/github-app-private-key
```

> 🔴 **③은 선택이 아니다.** `AmazonSSMManagedInstanceCore`가 `GetParameter`를 **`Resource: "*"`** 로
> 주기 때문에, 그 파라미터는 **계정 안의 SSM 관리 인스턴스 전부가 읽을 수 있다.**
> 남겨 두면 blast radius가 workbench 하나가 아니라 계정 전체다.
> ⚠️ 이것은 관리형 정책의 성질이라 **우리가 좁힐 수 없다** — workbench 모듈이 `eks:DescribeCluster`를
> 클러스터 ARN으로 한정한 것과 대비된다. 관리형을 붙이면 그 안의 권한은 통제 밖이다.

#### 복구 절차

repository Secret이 사라지면 **모든 sync가 멈춘다.** 이때 위 파라미터는 이미 지워졌고
노트북의 `.pem`도 영구 보관물이 아니다. ⇒ **키를 다시 발급한다.**

1. GitHub App 설정에서 **새 private key 발급** → 옛 키 **삭제**(App당 복수 키를 가질 수 있다)
2. 위 ①~③을 그대로 다시 실행
3. `./scripts/argocd-seed.sh --from 2 --to 2` — 2단계만 재적용한다

🔑 **키를 보관해서 복구하는 것이 아니라 재발급으로 복구한다.** 그래서 ③의 삭제가
복구 가능성을 해치지 않는다. 장기 자격증명을 계정에 남기지 않는 쪽이 항상 낫다.

#### 기각안

| 안 | 기각 사유 |
|---|---|
| SSM 세션에 **heredoc 붙여넣기** | 리소스는 0이지만, **세션 로깅이 켜진 계정에서는 키 전체가 로그에 남는다.** 고객사는 감사 요건으로 켜 두는 것이 보통이라 **재사용 절차로 적을 수 없다** |
| `aws ssm send-command` | 명령 파라미터가 **평문으로 command 히스토리·CloudTrail에 남는다**(조회 가능). 붙여넣기보다 나쁘다 |
| **Secrets Manager**(workbench가 직접 조회) | 효과는 같은데 workbench Role에 `secretsmanager:GetSecretValue`가 **없어 `.tf` 변경(브랜치→PR)이 필요**하고 시크릿당 월 $0.40이 붙는다. 같은 값을 더 비싸게 산다 |

#### ✅ 승인됨 — External Secrets Operator 도입 (2026-08-13, 부트스트랩 방식 확정)

위 절차의 진짜 비용은 "매번 새 키를 발급하고 손으로 옮기는 것"이 아니라 **재구축마다 그 비용이
반복되는 것**이다. Secrets Manager는 EKS 클러스터 생명주기와 **독립적**이다 — 클러스터를 통째로
파괴·재생성해도 그 안의 값은 살아남는다. 그래서 워크로드를 재구축할 때마다 사람이 raw key를
다시 만지는 대신, **키를 한 번만 Secrets Manager에 넣어 두고 클러스터마다 자동으로 동기화**하는
경로가 있는지 검토한다.

> ⚠️ 위 "기각안"의 Secrets Manager 항목과 **다른 제안이다.** 그건 "workbench가 SSM Parameter
> Store 대신 Secrets Manager를 직접 조회"였고 사람이 매번 발급·삭제하는 절차는 그대로였다.
> 여기서는 **키를 한 번만 넣고 다시는 사람이 만지지 않는 것**이 목표라 비교 대상이 다르다.

**제안 구조**

| # | 구성요소 | 역할 |
|---|---|---|
| 1 | Secrets Manager (out-of-band, 1회) | GitHub App private key를 KMS로 암호화해 durable 보관 — 사람이 raw key를 만지는 것은 이때 한 번뿐 |
| 2 | IAM Pod Identity (신설) | ESO 서비스어카운트에 **그 시크릿 ARN 하나**만 `secretsmanager:GetSecretValue` — `AmazonSSMManagedInstanceCore`의 `Resource:"*"` 문제가 구조적으로 사라진다 |
| 3 | External Secrets Operator | `SecretStore` + `ExternalSecret` CRD로 Secrets Manager → k8s `repository` Secret 자동 동기화. 재적용은 2단계(`argocd-seed.sh --from 2 --to 2`)를 완전히 대체한다 |

**부트스트랩 순서 — 해결됨**: ArgoCD는 `repository` Secret이 있어야 `iac-platform-gitops`를
읽어 나머지(Karpenter·ALBC·KEDA…)를 GitOps로 편다. ESO도 그 Secret을 채우는 주체라 GitOps보다
먼저 서야 하는 같은 처지다. **`eks-cluster` 모듈의 addon으로는 편입하지 않는다** —
`modules/eks-cluster/addons.tf`는 AWS EKS 관리형 addon API(`aws_eks_addon`) 전용이고 helm/manifest
기반 컴포넌트는 그 경계를 넘지 않는다(파일 내 주석 — vpc-cni custom networking 설계 근거와 동일
경계). 대신 **ArgoCD와 같은 방식으로 `argocd-seed.sh`가 helm install로 직접 세운다** — ArgoCD가
이미 "GitOps보다 먼저 서야 하는 것은 seed script가 helm으로 설치한다"는 선례를 실증하고 있으므로
새 패턴을 발명하지 않는다.

**얻는 것과 드는 것**

| 얻는 것 | 드는 것 |
|---|---|
| 이후 모든 재구축에서 raw key 취급 0회 | 새 addon 하나(버전 핀·보안 패치 대상 추가) |
| `Resource:"*"` blast radius가 IAM Pod Identity로 정밀 스코프됨 | 새 IAM Role + Pod Identity association(`.tf` 변경) |
| — | 부트스트랩 순서에 ArgoCD 외의 두 번째 "GitOps 밖" 예외가 생김 |

**다음 단계**: 부트스트랩 방식(위)까지는 이 repo의 설계 범위이자 확정 사항이다. 남은 것:
① `argocd-seed.sh`에 ESO helm install 단계 추가(이 repo, 브랜치 → PR — `.sh` 변경) —
values·서비스어카운트 이름 등 상세 설계 필요, 아직 미착수.
② `iac-reference-infra`·`iac-platform-gitops`의 실제 배선(IAM Pod Identity·`SecretStore`·
`ExternalSecret` CRD)은 별도 설계로 이어진다 — 이 repo는 재사용 자산만 소유하므로 특정 계정
값을 여기 두지 않는다.
⛔ 구현 전 ①의 상세 설계(설계 → 검토 → 승인)가 아직 남아 있다(이 repo `CLAUDE.md`의
설계·검토 우선 규칙) — 승인은 "방향"에 대한 것이지 "상세 구현"에 대한 것이 아니다.

### 사용법

> ### 🔑 **0단계 — workbench에 GitOps 저장소를 가져온다**
>
> workbench는 SSM 전용이라 `scp`가 없고 GitHub 자격증명도 없다. **ArgoCD가 쓰는 그 App의
> installation token**으로 클론한다 — 새 자격증명이 생기지 않는다.
> ⚠️ **키 전달보다 앞이 아니다**: 키가 **클론에도 쓰이므로 키를 먼저 내린다.**
>
> ```bash
> # 키는 위 ②로 이미 내려받은 상태여야 한다 (~/gh-app.pem)
> APP_ID=<app_id>; INST_ID=<installation_id>; KEYFILE=~/gh-app.pem
> ORG=<org>; REPO=<gitops-repo>; DEST=~/$REPO
>
> b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
> now=$(date +%s)
> h=$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | b64url)
> p=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$((now-60))" "$((now+540))" "$APP_ID" | b64url)
> sig=$(printf '%s.%s' "$h" "$p" | openssl dgst -sha256 -sign "$KEYFILE" | b64url)
> TOKEN=$(curl -s -X POST -H "Authorization: Bearer $h.$p.$sig" \
>   -H 'Accept: application/vnd.github+json' \
>   "https://api.github.com/app/installations/$INST_ID/access_tokens" | jq -r .token)
>
> git clone --quiet "https://x-access-token:$TOKEN@github.com/$ORG/$REPO.git" "$DEST"
> git -C "$DEST" remote set-url origin "https://github.com/$ORG/$REPO.git"   # ⛔ 토큰을 .git/config에 남기지 않는다
> ```
>
> - ⛔ **`TOKEN`을 출력하지 않는다.** 설치 범위 확인이 필요하면
>   `curl -H "Authorization: token $TOKEN" https://api.github.com/installation/repositories`
>   로 **저장소 목록만** 본다(실측 2026-08-07: `total_count=1`).
> - `openssl`·`jq`는 **AL2023 기본 탑재**라 도구를 늘리지 않는다. `git`은 workbench 모듈이 설치한다.
> - 🥚 **이 조각만은 vendoring할 수 없다** — 클론하기 전에 필요하기 때문이다.
>   길어지기 시작하면 다른 배달 경로가 필요하다는 신호다.

```bash
# 1) 저장소를 최신 상태로 둔다 (ArgoCD는 원격을 읽는다 — 갓 클론했다면 생략)
git -C ~/iac-platform-gitops pull

# 2) 파라미터
export GITOPS_REPO_DIR=~/iac-platform-gitops
export CLUSTER_DIR=clusters/dev/eks-ref-dev-an2-main-01
export GITOPS_REPO_URL=https://github.com/skax-ca/iac-platform-gitops.git
export GH_APP_ID=...                 # GitHub App 설정 페이지
export GH_APP_INSTALLATION_ID=...    # gh api orgs/<org>/installations
export GH_APP_PRIVATE_KEY=~/gh-app.pem   # ⬅ 위 ②로 내려받은 파일

# 3) 먼저 dry-run — 노트북에서도 돌아간다
./scripts/argocd-seed.sh --dry-run

# 4) 실제 실행은 workbench 안에서 (private endpoint)
./scripts/argocd-seed.sh
```

⚠️ **`GH_APP_PRIVATE_KEY`를 노트북의 키 원본으로 두지 않는다.** 실행은 workbench 안에서
일어나므로 그 경로는 **workbench의 파일**이어야 한다 — 어떻게 거기 두는지는 위 **키 전달 경로** 절에 있다.

**선택 인자**: `--from N` · `--to N` (단계 구간 재실행). `--help`로 전체 옵션.
**선택 환경변수**: `ARGOCD_NAMESPACE`(`argocd`) · `ARGOCD_CHART_VERSION`(`10.3.0`) ·
`ARGOCD_VALUES`(`bootstrap/argocd-values.yaml`) · `ARGOCD_RELEASE`(`argocd`).

### ⚠️ `--dry-run`이 검증하지 않는 이유 (2026-08-07 실측)

`--dry-run`은 **kubectl을 아예 부르지 않는다.** 오프라인에서 검증할 방법이 없기 때문이다:

| 시도 | 결과 (VPC 밖) |
|---|---|
| `kubectl apply --dry-run=client` | `failed to download openapi ... i/o timeout` |
| `+ --validate=false` | `unable to recognize ... /api i/o timeout` |

🔑 두 번째가 핵심이다 — `AppProject`·`Application`은 **CRD**라 kubectl이 RESTMapping을 풀려면
**discovery API(`/api`)** 를 쳐야 한다. **검증을 꺼도 그 호출은 남는다.**
클러스터는 private이므로([`05-modules.md`](../docs/05-modules.md) `eks-cluster`) 팀원 노트북에서는 늘 막힌다.

⇒ `--dry-run`의 역할을 **"무엇을 어디서 적용하는지 보여주기"** 로 좁혔다.
**진짜 검증은 실제 실행 경로의 `kubectl apply --dry-run=server`가 한다** — 사라진 것이 아니라 뒤로 미뤄진다.

### 실행 후 — 사람이 확인한다

스크립트가 자동 판정하지 않는다. 실패 모드가 여러 겹이라 한 번에 하나씩만 보이기 때문이다
(PoC에서 **에러가 세 겹으로 벗겨진** 전례).

1. **root App이 저장소를 실제로 읽었는가**
   `.status.sync.revision`이 **실제 커밋 SHA**여야 한다.
   ⚠️ 값이 `main`이면 아직 **설정값**이다 — PoC가 이것을 성급히 성공으로 읽은 전례가 있다.
2. `Synced` / `Healthy` 인가
3. **cluster Secret이 내장 `in-cluster`를 대체했는가 / 중복인가**
   ⚠️ argo-cd v3.5.0 문서에 서술이 없는 **미검증 항목**이다.
4. UI 접근 — `port-forward` 후 `https://localhost:8080` (자체 서명 인증서 경고는 **정상**)
5. ⛔ **초기 비밀번호 교체 + `argocd-initial-admin-secret` 삭제** — 선택이 아니라 **완료 조건**이다

### 호환성

- **bash 3.2 호환**으로 작성했다 — macOS 기본 bash가 3.2다(실측). 연상배열·`mapfile`·`${var^^}`를 쓰지 않는다.
- 필요 도구: `kubectl` · `helm` · `git`

---

## 🔁 vendoring — GitOps 저장소의 사본

**이 파일이 SSOT다.** 사본이 `skax-ca/iac-platform-gitops`의 `bootstrap/argocd-seed.sh`에 있다.
근거·기각안은 [`08-decisions.md`](../docs/08-decisions.md).

⛔ **사본을 편집하지 않는다.** 고칠 일이 생기면 **여기를 고치고 다시 복사**한다.
⚠️ 경쟁 SSOT가 아니라 vendoring이다 — 구분 기준은 *"어디를 고치는가"* 하나다.

### 다시 vendoring 하는 법

```bash
SRC=scripts/argocd-seed.sh          # 이 파일 (모듈 repo 루트에서 실행)
DST=<gitops>/bootstrap/argocd-seed.sh

# 배너의 '출처' SHA를 지금 값으로 갱신한 뒤 실행한다
git log -1 --format='%H (%ad)' --date=short -- "$SRC"

# 배너(모든 줄이 #V#로 시작)를 보존한 채 본문만 갈아끼운다
{ head -1 "$SRC"; grep '^#V#' "$DST"; tail -n +2 "$SRC"; } > "$DST.new"
mv "$DST.new" "$DST" && chmod +x "$DST"
```

### 🔍 드리프트 검사 — 한 줄

```bash
diff <(grep -v '^#V#' <gitops>/bootstrap/argocd-seed.sh) scripts/argocd-seed.sh
```

배너를 뺀 나머지는 **바이트 단위로 같아야 한다.** 배너의 모든 줄에 `#V#` 접두를 둔 이유가 이것이다 —
헤더를 붙이는 순간 사본이 SSOT와 달라져 *"편집하지 않았다"* 를 검증할 수 없게 되므로,
**검사가 한 줄로 끝나도록** 접두를 설계했다.

> 📌 **"출처 태그"의 실제 형태는 커밋 SHA다.** 초기 설계는 *"출처 태그"* 라고 적었지만
> `scripts/`에는 **태그 축이 없다** — 태그는 모듈별 semver(`vpc-v0.3.0`)이고 이 스크립트는
> `?ref=`로 소싱되지 않는다. 새 태그 축을 발명하는 대신 SHA로 핀했다.
> 🔁 **여러 고객사 저장소로 사본이 늘어나면** 그때 태그 축을 재검토한다 — 지금은 사본이 1개다.

> ⚠️ **이 절차에도 게이트가 없다.** 아래 열린 항목과 같은 공백이며, 드리프트 검사를 **사람이
> 기억해서** 돌려야 한다. `verify.yml`에 `.sh` 게이트를 넣을 때 이 검사도 함께 검토한다
> (사본이 있는 저장소를 CI가 읽어야 하므로 **같은 작업이 아니다** — 별도 판단이 필요하다).

---

## ⚠️ 열린 항목 — 이 디렉토리는 **어떤 게이트도 통과하지 않는다**

실측(2026-08-07): `.githooks/pre-commit`은 `.tf`/`.tfvars`/lock/설정만 보고,
`.github/workflows/verify.yml`의 6개 게이트도 **`.sh`를 검사하지 않는다.**

⇒ 지금은 **사람이 `bash -n`을 돌리는 것이 유일한 방어**다.

📌 **제안**: `verify.yml`에 `bash -n scripts/*.sh`(가능하면 `shellcheck`) 게이트를 추가한다.
⛔ 단 `.github/workflows/` 변경은 **브랜치 → PR**이다(`CLAUDE.md` 브랜치 규칙) — 별도 태스크로 다룬다.

> 🔑 **이 공백이 브랜치 규칙의 경계 사례를 드러낸다.** 규칙의 기준은 *"CI가 머지 전에 막아야 하는가"* 인데,
> `scripts/`는 **막을 CI가 없어서** 문서와 같은 취급(main 직접 커밋)을 받는다.
> **게이트를 추가하는 순간 이 디렉토리도 브랜치 → PR 대상이 된다** — 그때 규칙 표에 함께 등재한다.
