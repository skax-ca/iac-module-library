# addon 설치·해제 순서

**읽는 사람**: addon을 새로 얹거나, 클러스터를 등록·해제하는 사람.

addon 사이에는 순서가 있다. CR은 그 CRD가 있어야 적용되고, CR의 finalizer는 그것을 처리하는
컨트롤러가 살아 있어야 풀린다. 이 문서는 그 순서를 **부모 Application의 sync-wave 하나로** 설치와
해제 양쪽에 거는 방법을 정한다. 부모 Application이 무엇이고 addon을 어떻게 고르는지는
[gitops.md](gitops.md)가 소유한다. 클라우드별 wave 표는 [aws/README.md](aws/README.md)·
[azure/README.md](azure/README.md)가 갖는다.

---

## 1. wave를 정하는 규칙

addon Application의 wave는 **그것이 기대는 addon의 wave보다 크다.** 기대는 것은 셋이다.

| 기대는 것 | 예 | 순서가 틀리면 |
|---|---|---|
| 자기 리소스의 CRD | Gateway CR → Gateway API CRD | CR이 적용되지 않는다. 컨트롤러가 시작할 때 CRD를 한 번만 감지하면(ALBC) 기능이 조용히 꺼진 채 남는다 |
| 자기 CR의 finalizer를 처리하는 컨트롤러 | Gateway CR → ALBC · NodePool → Karpenter | 해제 때 CR이 `deletionTimestamp`를 낀 채 멈추고 클라우드 쪽 뒷정리가 끝나지 않는다 |
| 자기 파드가 뜰 노드 | 시스템 풀 taint를 견디지 못하는 addon → 노드를 만드는 NodePool | 설치 때 `Pending`, 해제 때 삭제 훅 Job이 `Pending`에 걸린다 |

같은 wave 안의 addon은 서로를 기다리지 않는다. 기댈 것이 없는 addon은 가장 앞 wave에 둔다.

---

## 2. Argo CD가 무엇을 보장하나

부모 Application이 addon Application을 자기 리소스로 sync하므로, 아래 동작이 addon 사이에 걸린다.

| 동작 | 보장 | 근거 |
|---|---|---|
| 설치(부모 sync) | 앞 wave의 리소스가 Synced·Healthy가 된 뒤에 다음 wave를 적용한다 | [Sync Phases and Waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) |
| 부분 해제(부모 sync의 prune) | wave가 높은 것부터 prune하고, 삭제가 끝나지 않은 객체가 있으면 다음 wave로 넘어가지 않는다 | 같은 문서("Resources in higher waves are pruned first") · Argo CD v3.5 `gitops-engine/pkg/sync/sync_context.go` |
| 전체 해제(부모 cascade 삭제) | wave가 높은 것부터 지우고, `deletionTimestamp`가 남은 객체가 있으면 다음 wave로 넘어가지 않는다 | Argo CD v3.5 `controller/sort_delete.go` · `controller/appcontroller.go`. ⚠️ 문서에 없는 동작이다 |

🔑 **대기는 `argoproj.io/Application`의 health가 있어야 성립한다.** Argo CD는 1.8에서 이 health를
뺐고 v3.5에도 내장 체크가 없다. health가 없으면 부모는 addon Application을 만들자마자 다음 wave로
넘어가 wave가 생성 순서만 정한다. 각 GitOps 저장소의 `bootstrap/argocd-values.yaml`이
`configs.cm`의 `resource.customizations.health.argoproj.io_Application`에
[업그레이드 문서](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/1.7-1.8/)의
Lua를 넣는다. CRD에는 내장 health(`Established`)가 있어 따로 넣지 않는다.

⚠️ 이 health는 전역 설정이라 root App에도 걸린다. root App의 health가 ArgoCD 자기 관리
Application과 부모들의 health를 반영하게 된다.

---

## 3. 해제는 2단계다

cluster Secret을 먼저 지우면 순서가 무너진다. Argo CD는 목적지 클러스터를 찾지 못한 Application을
지울 때 클러스터 쪽 리소스를 지우지 않고 기록만 버린다(`Resource entries removed from undefined
cluster`). CR의 finalizer도, 그 CR이 만든 클라우드 리소스도 남는다.

| 단계 | 무엇을 하나 | 무엇이 일어나나 |
|---|---|---|
| 1 | cluster Secret에서 `environment` 라벨을 뺀다 | ApplicationSet이 부모를 지우고, 부모의 finalizer가 addon을 wave 역순으로 지운다. 컨트롤러는 자기 CR이 지워질 때까지 살아 있다 |
| 2 | 부모가 hub에서 사라진 것을 확인하고 cluster Secret을 지운다 | ArgoCD가 그 클러스터를 잊는다 |

⛔ 부모 Application에서 `resources-finalizer.argocd.argoproj.io`를 빼지 않는다. root App과 달리
부모에는 cascade가 있어야 한다. 빼면 1단계가 addon을 지우지 않는다.

명령 순서는 배포 루트의 `spoke-lifecycle.md`가 갖는다.

---

## 4. 대가

| 대가 | 대응 |
|---|---|
| 앞 wave의 addon 하나가 Healthy가 되지 못하면 그 클러스터의 뒤 wave가 전부 멈춘다. wave가 없으면 addon은 서로를 기다리지 않는다 | 1절 규칙대로 두면 뒤 wave에는 앞 wave 없이는 어차피 동작하지 않는 것만 남는다. Healthy까지 오래 걸리는 것(ALB를 만드는 Gateway)은 마지막 wave에 둔다 |
| 부모의 sync operation이 앞 wave를 기다리는 동안 새 커밋의 버전 변경이 addon Application spec에 반영되지 않는다. 멈춘 addon을 고치는 커밋도 같다. `controller.sync.timeout.seconds` 기본값이 `0`(무제한)이라 스스로 풀리지 않는다 | `argocd app terminate-op <cluster>-platform`으로 operation을 끊으면 다음 auto-sync가 새 커밋으로 돈다. `addons/<addon>/values.yaml`만 고친 커밋은 addon Application이 직접 읽으므로 부모를 거치지 않는다 |
| 전체 해제의 순서가 문서에 없는 코드 동작에 기댄다 | ⏳ 다음 spoke 해제에서 실측한다. Argo CD를 올릴 때 `controller/sort_delete.go`가 남아 있는지 본다 |

---

## 5. 하지 않는 것

| 하지 말 것 | 이유 |
|---|---|
| addon Application을 **ApplicationSet이 직접** 만들게 두고 `sync-wave`를 단다 | 그 Application을 sync하는 부모가 없어 wave가 아무 순서도 정하지 않는다. 순서를 addon 쪽 우회(컨트롤러 재시작 · 해제 전용 라벨 · finalizer 수동 제거)로 메우게 된다 |
| 순서를 **Progressive Syncs**(`RollingSync` 단계 · `deletionOrder: Reverse`)로 맞추기 | 순서는 한 ApplicationSet이 만든 Application 사이에만 걸리고, RollingSync는 생성되는 Application의 autosync를 강제로 끈다. v3.3부터 베타다 |
| 컨트롤러가 CRD를 기다리게 **PreSync Job**을 addon마다 두기 | Job·RBAC·이미지가 addon마다 늘고, 해제 순서는 풀지 못한다 |
| CRD를 쓰는 CR을 **컨트롤러와 같은 Application**에 합치기 | 설치 순서는 같은 sync 안의 kind 순서로 서지만, 컨트롤러를 지울 때 CR과 finalizer가 같은 cascade에 섞인다. CR과 컨트롤러의 버전 축도 갈린다(CR은 `main`, 컨트롤러는 버전 핀) |
