# scripts — 운영 절차 스크립트

소비 프로젝트가 **실행하는 절차** 중 재사용 가치가 있는 것을 여기서 소유한다.

> ⚠️ **이 repo는 배포하지 않는다.** 여기 있는 것은 **실행되는 자산**이지 이 repo가 실행하는 것이 아니다.
> 그래서 모든 스크립트는 **환경값을 하드코딩하지 않는다**([`architecture/01 §4`](../docs/architecture/01-module-strategy.md) 파라미터화 요건).
> 특정 클러스터·계정·저장소를 가정하는 순간 재사용 자산이 아니게 된다.

| 스크립트 | 무엇 | 설계 SSOT |
|---|---|---|
| `argocd-seed.sh` | self-managed ArgoCD 부트스트랩 seed (0·2·3·4·5단계) | [`design/23 §2.1`](../docs/design/23-argocd-self-managed.md) · [`design/30 §4.1`](../docs/design/30-gitops-repo.md) |

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
- ⚠️ **이것이 사라지면 모든 sync가 멈춘다** — 복구 절차에 반드시 포함한다

### 사용법

```bash
# 1) GitOps 저장소를 체크아웃하고 최신 상태로 둔다 (ArgoCD는 원격을 읽는다)
git -C ~/iac-platform-gitops pull

# 2) 파라미터
export GITOPS_REPO_DIR=~/iac-platform-gitops
export CLUSTER_DIR=clusters/dev/eks-ref-dev-an2-main-01
export GITOPS_REPO_URL=https://github.com/skax-ca/iac-platform-gitops.git
export GH_APP_ID=...                 # GitHub App 설정 페이지
export GH_APP_INSTALLATION_ID=...    # gh api orgs/<org>/installations
export GH_APP_PRIVATE_KEY=~/Downloads/....pem

# 3) 먼저 dry-run — 노트북에서도 돌아간다
./scripts/argocd-seed.sh --dry-run

# 4) 실제 실행은 workbench 안에서 (private endpoint)
./scripts/argocd-seed.sh
```

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
클러스터는 private이므로([`design/20 §3.1`](../docs/design/20-eks-module.md)) 팀원 노트북에서는 늘 막힌다.

⇒ `--dry-run`의 역할을 **"무엇을 어디서 적용하는지 보여주기"** 로 좁혔다.
**진짜 검증은 실제 실행 경로의 `kubectl apply --dry-run=server`가 한다** — 사라진 것이 아니라 뒤로 미뤄진다.

### 실행 후 — 사람이 확인한다

스크립트가 자동 판정하지 않는다. 실패 모드가 여러 겹이라 한 번에 하나씩만 보이기 때문이다
(PoC에서 **에러가 세 겹으로 벗겨진** 전례 — [`design/30 §4`](../docs/design/30-gitops-repo.md)).

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

## ⚠️ 열린 항목 — 이 디렉토리는 **어떤 게이트도 통과하지 않는다**

실측(2026-08-07): `.githooks/pre-commit`은 `.tf`/`.tfvars`/lock/설정만 보고,
`.github/workflows/verify.yml`의 6개 게이트도 **`.sh`를 검사하지 않는다.**

⇒ 지금은 **사람이 `bash -n`을 돌리는 것이 유일한 방어**다.

📌 **제안**: `verify.yml`에 `bash -n scripts/*.sh`(가능하면 `shellcheck`) 게이트를 추가한다.
⛔ 단 `.github/workflows/` 변경은 **브랜치 → PR**이다(`CLAUDE.md` 브랜치 규칙) — 별도 태스크로 다룬다.

> 🔑 **이 공백이 브랜치 규칙의 경계 사례를 드러낸다.** 규칙의 기준은 *"CI가 머지 전에 막아야 하는가"* 인데,
> `scripts/`는 **막을 CI가 없어서** 문서와 같은 취급(main 직접 커밋)을 받는다.
> **게이트를 추가하는 순간 이 디렉토리도 브랜치 → PR 대상이 된다** — 그때 규칙 표에 함께 등재한다.
