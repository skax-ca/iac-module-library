# 계층 2: addon을 GitOps로 운영한다

**읽는 사람**: addon을 클러스터에 얹거나, 그 버전을 올리려는 사람.

계층 2가 무엇인지와 계층 1과의 경계는 [README.md](README.md)가 소유한다. 이 문서는 그 경계
안에서 **어디에 두고 · 어떤 이름으로 · 어떻게 내보내는가**를 정한다. 클라우드가 어떤 addon을
관리형으로 제공하는지는 [aws/README.md](aws/README.md)·[azure/README.md](azure/README.md)가 갖는다.

---

## 1. 이 addon은 계층 2인가

컨트롤러는 계층 1, 그 컨트롤러가 읽는 설정 CR은 계층 2다. 설정 CR은 다시 계층 2(플랫폼)와
계층 3(앱, 범위 밖)으로 갈린다. *"cluster-scoped면 플랫폼, namespace-scoped면 앱"* 은
**성립하지 않는다**(아래 표의 굵은 두 행). 두 질문이 정한다.

**판별 1: 인프라 정체성을 담는가?** 권한 · 비용 · 용량 · 발급 신뢰를 인코딩하면 **계층 2**다.
스코프와 무관하다.

**판별 2: 누군가를 제약하는 규칙인가?** 가드레일은 **제약받는 쪽이 소유하면 무의미**하다.
앱팀을 제약하는 정책은 **계층 2**다.

| CR | 스코프 | 계층 | 판별 |
|---|---|---|---|
| Karpenter NodePool · EC2NodeClass | cluster | 2 | 1: `spec.role`이 권한을 인코딩 |
| Kyverno ClusterPolicy | cluster | 2 | 2: 앱팀을 제약하는 가드레일 |
| cert-manager Issuer | **namespace** | **2** | 1: 발급 신뢰는 인프라다 |
| KEDA ScaledObject | namespace | 3 | 특정 워크로드에 결합 |
| KEDA ClusterTriggerAuthentication | **cluster** | **2** | 앱 인증에 결합하나 공유 제공물 |

---

## 2. 네임스페이스 배치

**계층 2 addon은 전용 네임스페이스를 신설한다.** 격리가 기본값이다.

예외를 만들려면 **컨트롤러가 그 네임스페이스를 전제로 동작한다는 근거**를 댄다. *"차트
기본값이 `kube-system`이라서"* 는 근거가 아니다. 클라우드별 예외 목록과 근거는 각 클라우드
문서가 갖는다.

---

## 3. Application 이름과 release 이름을 분리한다

클러스터마다 있는 부모 Application(「전파 정책」)이 addon Application 이름을 `<cluster>-<addon>`으로
짓는다. 하나의 ArgoCD가 여러 클러스터를 관리하므로 콘솔에서 어느 클러스터의 addon인지 가르려면
이 접두사가 필요하다.

**release 이름을 따로 주지 않으면 그 접두사가 Kubernetes 리소스 이름까지 전파된다.** ArgoCD는
`spec.source.helm.releaseName`이 없으면 release 이름을 Application 이름과 같게 쓰고
([ArgoCD 공식 문서](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)), 대부분의 차트는
`{{ .Release.Name }}-{{ .Chart.Name }}` 형태로 리소스 이름을 만든다. 접두사가 두 번 겹친다.

⚠️ Kubernetes 객체 이름은 DNS-1123 규격상 63자 제한이 있어, 접두사가 길면 서로 다른 리소스가
63자 지점에서 같은 이름으로 잘려 충돌한다(`cluster-autoscaler`가 그 예다).

**결정**: release 이름이 리소스 이름에 그대로 쓰이는 addon은 `spec.source.helm.releaseName`을
짧게 명시한다. Application 이름은 그대로 둔다. 콘솔 식별과 리소스 이름은 서로 다른 축이고,
[Kubernetes 공식 문서](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)도
클러스터·인스턴스 식별을 `app.kubernetes.io/instance` 라벨의 몫으로 다룬다.

release 이름은 **클러스터 안에서만** 유일하면 된다. `destination.server`가 클러스터마다 다르므로
허브와 스포크가 같은 release 이름을 써도 충돌하지 않는다. ArgoCD의 소유권 추적 라벨은 Application
이름 기준이라 release 이름을 바꿔도 클러스터·addon 단위 추적은 유지된다.

예외: 차트가 release 이름과 무관하게 컨트롤러 이름을 고정으로 렌더링하면(kyverno 계열) 접두사가
겹치지 않으므로 지정하지 않는다.

---

## 4. 전파 정책: 누가 받고, 어떤 버전을 받나

### 클러스터마다 부모 Application 하나

hub ArgoCD는 등록된 클러스터마다 부모 Application `<cluster>-platform`을 하나 만든다. 그 부모가
그 클러스터의 addon Application을 전부 렌더한다.

```
root-app
└─ ApplicationSet platform              cluster generator. environment 라벨이 있는 클러스터마다 부모 하나
   └─ <cluster>-platform                로컬 helm 차트 addons/platform/ 를 렌더한다
      ├─ <cluster>-gateway-api-crds     wave 0
      ├─ <cluster>-aws-lbc              wave 1
      └─ <cluster>-gateway              wave 2
```

| 누가 | 무엇을 정하나 |
|---|---|
| ApplicationSet `platform` | 어느 클러스터가 플랫폼을 받나. selector는 `environment` 라벨의 **존재** 하나다 |
| 부모 차트 `addons/platform/` | 그 클러스터가 어느 addon을 어떤 버전으로, 어떤 wave에 받나. cluster Secret 라벨을 helm parameter로 받아 고른다 |
| addon Application | addon 하나. 차트 source·values 파일·sync 정책을 갖는다 |

부모를 두는 이유는 순서다. sync-wave는 Application 하나의 sync 안에서만 순서를 정한다. addon
Application을 ApplicationSet이 직접 만들면 그것을 sync하는 Application이 없어 wave가 아무 순서도
정하지 않는다. 부모가 addon Application을 자기 리소스로 sync해야 wave가 설치와 해제의 순서가
된다([ordering.md](ordering.md)). 콘솔에서 클러스터 하나의 addon이 한 트리에 모이는 것은 따라오는 효과다.

부모는 `prune`을 켠다. opt-in 해지(라벨 제거)는 부모 sync의 prune으로 이루어진다. ⚠️ 그래서
차트에서 addon 템플릿을 지우면 등록된 전 클러스터에서 그 addon이 wave 역순으로 지워진다.

### 정책 셋

| 정책 | 부모 차트가 고르는 방법 | 버전 |
|------|----------|------|
| **uniform** | 조건 없이 렌더한다 | 전 클러스터가 한 개 |
| **staged** | `versions.<addon>.<tier>`를 읽는다 | 티어마다 한 개 |
| **opt-in** | `addon-<name>` 라벨 값이 `enabled`일 때만 렌더한다 | 구독 클러스터가 한 개 |

정책은 하나만 고르고 조합하지 않는다. 한 addon이 컨트롤러와 CR로 나뉘면 **addon Application마다
따로** 고른다(Karpenter·Kyverno가 그렇다).

세 라벨은 전부 cluster Secret에 붙는다. 버전은 부모 차트의 values 파일이 갖고, 라벨은 그 표에서
어느 줄을 읽을지만 정한다.

| 라벨 | 무엇을 정하나 | 값 |
|---|---|---|
| `environment` | **존재**가 부모의 대상. **값**은 리소스 이름의 재료(AWS 공유 Gateway가 ALB 이름·태그에 쓴다) | 클러스터마다(`hub`·`dev`…) |
| `tier` | **값**이 staged 버전의 줄 | `prd`(운영. 재구축 대상이 아닌 hub도 여기) · `nonprd`(그 밖 전부, 승격을 먼저 받는다). **둘뿐이다** |
| `addon-<name>` | **값**이 opt-in의 대상 | `enabled` |

`tier`를 `environment`와 따로 두는 이유는 값의 개수다. `environment`는 클러스터가 늘면 값이 함께
늘고, `tier`는 둘로 고정된다. `tier`에 다른 값을 쓰면 부모 차트가 `required`로 렌더를 실패시켜 그
클러스터의 부모가 `ComparisonError`로 멈춘다. ⚠️ `environment`를 빠뜨리면 부모가 아예 생기지 않고,
ArgoCD는 대상 0개인 팬아웃을 오류로 보고하지 않는다.

⚠️ **세 이름은 이 저장소가 붙인 것이다.** 업계는 비슷한 개념을 ring 배포·staged rollout이라
부른다. ArgoCD ApplicationSet의
[Progressive Syncs](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Progressive-Syncs/)는
**같은 버전**을 그룹 순서대로 적용하는 기능(순서 제어)이고, 여기 staged는 **버전 자체**를 티어마다
다르게 주어 승격 판단을 커밋에 남긴다. 두 저장소 모두 Progressive Syncs를 쓰지 않는다.

### 어느 정책을 고르나

판정 단위는 addon Application이다. `main` 핀은 승격할 버전이 없어 staged가 될 수 없다. 버전 핀을
가진 것만 아래 표로 티어로 나눌지 판단한다.

| 이 addon Application이 | 정책 | 이유 |
|-----------|------|------|
| 인프라를 직접 움직이는 **컨트롤러**인가 | **staged** | 노드를 만들고 트래픽을 받는다. 깨지면 클러스터가 망가지므로 비운영에서 먼저 확인하고 승격한다 |
| 컨트롤러와 **같은 마이너 라인**을 요구하는 업스트림 차트인가 | **컨트롤러를 따라간다** | 상류가 그 내용을 컨트롤러 app 버전에 맞춰 쓴다. 라인이 갈리면 업스트림이 내지 않는 조합이 된다 |
| 팀이 필요할 때만 켜는 기능인가 | **opt-in** | 쓰는 클러스터가 정해져 있어 승격 단계를 나눌 대상이 적다 |
| 그 밖(주로 이 저장소가 소유한 CR·정책) | **uniform** | `main` 핀이라 승격할 버전이 없다. 클러스터 간 차이 자체가 위험이기도 하다 |

⚠️ *"가드레일이니 uniform"* 은 **정책 내용**에만 해당한다. 정책 **엔진**은 admission webhook
컨트롤러라 깨지면 그 클러스터의 모든 배포가 막힌다. 폭발 반경이 노드 프로비저너보다 크다. 그래서
Kyverno는 엔진과 PSS 정책이 staged이고, 이 저장소가 만든 커스텀 정책만 uniform이다.

같은 기준을 적용해도 **답은 클라우드마다 갈린다.** 관리형으로 받은 기능은 GitOps 계층에 없어
정책을 고를 일이 없기 때문이다.

| addon Application | `targetRevision` | AWS(EKS) | Azure(AKS) |
|---|---|---|---|
| Kyverno 엔진 | 버전 핀 | **staged** | **staged** |
| Kyverno PSS 정책(업스트림 차트) | 버전 핀(엔진과 같은 마이너 라인) | **staged** | **staged** |
| Kyverno 커스텀 정책 | `main` | uniform | uniform |
| 공유 Gateway CR | `main` | uniform | uniform |
| Karpenter 컨트롤러 | 버전 핀 | **staged** | 없음(NAP가 배포·관리) |
| Karpenter NodePool CR | `main` | uniform | **opt-in** |
| ALB Controller | 버전 핀 | **staged** | 없음(App Routing) |
| Gateway API 표준 CRD | 버전 핀 | **staged** | 없음(AKS 관리형) |
| KEDA | 버전 핀 | **opt-in** | 없음(관리형 add-on) |
| Cluster Autoscaler | 버전 핀 | **opt-in** | 없음(NAP를 쓴다) |

Azure 열에 "없음"이 많은 이유는 노드와 트래픽을 다루는 컨트롤러(NAP · App Routing · 관리형
KEDA)를 전부 관리형으로 받고, 버전 승격도 AKS가 클러스터 업그레이드에 맞춰 하기 때문이다.
조립한 것 중 버전 핀을 가진 것이 Kyverno 엔진과 PSS 정책뿐이라 **Azure에서 staged는 Kyverno뿐**이다.

### Kyverno: 엔진과 PSS 정책은 같은 마이너 라인에 둔다

두 차트 사이에 helm `dependencies`는 없다(`kyverno` 차트가 `crds`·`grafana` 등 5개를 선언하므로
붙일 자리가 없어서가 아니다). 정책 차트가 요구하는 것은 엔진 app 버전의 **하한**이다(차트 README:
PSS 정책은 Kyverno 1.6.0 이상, CEL 기반 `ValidatingPolicy` 경로는 1.17 이상).

상류는 현행 라인(3.5부터 3.9)에서 엔진과 정책을 같은 번호로 함께 내고, 유지보수 라인(3.0·3.2·
3.3·3.4)에서는 **엔진만** 패치한다. 정책 내용이 거의 바뀌지 않기 때문이다. 정책 단독 릴리스는 없다.

⇒ 티어 안에서 엔진과 정책을 같은 라인에 두고, 정책은 그 라인에서 받을 수 있는 최신 패치에 둔다.
그 라인에 짝이 없는 엔진 패치는 **엔진만 올린다**(보안 백포트가 이 형태로 온다). 라인을 넘는
승격은 4개 값(엔진·정책 × 티어 2)을 짝으로 움직인다.

⛔ 차트 번호 일치를 불변식으로 쓰지 않는다. 번호를 맞춰도 app 버전은 갈린다: 엔진 3.3.7은 app
v1.13.4인데 같은 라인 정책 최신 3.3.6은 app v1.13.6으로 앞선다. 판정은 `appVersion`으로 한다.

### uniform: 전 클러스터가 같은 버전

```yaml
# addons/platform/templates/kyverno-custom-policies.yaml
spec:
  source:
    targetRevision: main          # 조건도 티어도 없다
```

클러스터를 등록하는 행위가 곧 배포라, 스포크가 늘어도 addon 파일은 그대로다. `targetRevision`이
하나라 올리면 등록된 전 클러스터가 함께 올라간다. 클러스터마다 정책 버전이 다르면 무엇이 통과하는지가
갈리므로 가드레일에는 그것이 맞다.

### staged: 티어별로 승격

**버전 핀을 가진 addon만** 티어별 값을 두 개 갖는다. 그 둘은 부모 차트의 values 파일 한 곳에
나란히 둔다.

| addon Application | `targetRevision` | 티어로 나누나 |
|---|---|:---:|
| 컨트롤러 helm(업스트림 차트 버전 핀) | `1.14.0` | ✅ |
| CR(이 저장소의 로컬 차트) | `main` | ❌ |

`main`은 저장소 최신을 따라가는 참조다. 티어별로 적어도 두 값이 같을 수밖에 없어 승격은 기록되지
않고 줄만 는다.

```yaml
# addons/platform/values.yaml
versions:
  karpenter:
    prd: 1.14.0       # 운영 버전
    nonprd: 1.15.0    # 검증 중인 버전
```

```yaml
# addons/platform/templates/karpenter.yaml
targetRevision: {{ required "tier 는 prd·nonprd 둘뿐이다" (index .Values.versions.karpenter .Values.tier) }}
```

🔑 두 값의 차이가 승격이 어디까지 갔는지를 저장소에 기록한다. 파일에 적힌 차이는 의도한 것이고,
그 밖의 클러스터 간 차이는 사고다. 클러스터를 열어 보지 않고 저장소만 읽어 판정한다. 줄 수는 티어
수를 따라가고 클러스터 수를 따라가지 않는다. 버전 리터럴은 values 파일에만 있고 템플릿은 표에서
읽기만 한다. `eks-platform-gitops`의 Karpenter AMI 핀(`amiAliasByTier`)이 같은 경로를 쓴다.

addon Application 이름에는 티어가 들어가지 않는다(`<cluster>-karpenter`). 한 클러스터는 한 티어에만
속하므로 이름이 겹치지 않는다.

**승격 절차**

1. `versions.karpenter.nonprd`를 새 버전으로 올려 커밋한다.
2. 비운영 클러스터에서 컨트롤러 동작을 확인한다.
3. `versions.karpenter.prd`를 같은 값으로 올려 커밋한다.
4. 두 값이 같아지면 승격이 끝난 것이다.

⚠️ **1~3 사이에는 CR이 두 버전 모두에서 유효해야 한다.** 티어로 나누지 않은 CR은 양 티어가 같은
차트를 본다. 그 구간에는 nonprd가 새 CRD를, prd가 옛 CRD를 갖고 있으므로, 새 버전에서 생긴 필드를
CR 차트에 넣으면 prd에서 미지의 필드가 된다. 새 필드가 필요하면 3을 끝내고 커밋한다. 승격 구간이
길수록 이 제약에 걸리는 커밋이 는다.

### opt-in: 구독한 클러스터에만

```yaml
# addons/platform/templates/keda.yaml
{{- if eq .Values.addons.keda "enabled" }}
...
{{- end }}
```

라벨의 **값**을 본다. ApplicationSet이 cluster Secret 라벨을 `index`로 읽어 넘기므로 라벨이 없으면
빈 값이 되고 렌더하지 않는다. 라벨을 붙이고 떼는 것이 곧 구독과 해지다. ⚠️ 라벨을 빠뜨린 채
클러스터를 등록하면 그 addon이 **빠진 채** 배포되고, ArgoCD는 이것을 오류로 보고하지 않는다.

버전은 하나다. 구독한 클러스터가 여럿이면 함께 올라간다. 티어별 승격이 필요해질 만큼 대상이 늘면
그 addon을 staged로 옮긴다.

### 파일 구성: 컴포넌트로 나누고 티어는 붙여 둔다

| 파일 | 무엇을 갖나 |
|---|---|
| `applicationsets/platform.yaml` | ApplicationSet 하나. root App이 읽는다 |
| `addons/platform/templates/<addon>.yaml` | addon Application 하나와 그 wave |
| `addons/platform/values.yaml` | 버전 표. staged의 티어 쌍이 여기 나란히 있다 |
| `addons/<addon>/values.yaml` · `addons/<addon>/<로컬 차트>/` | addon Application의 source가 읽는 내용물 |

| 나누는 축 | 파일을 나누나 | 이유 |
|---|:---:|---|
| 컴포넌트(컨트롤러·CR·정책) | ✅ | 서로를 보지 않고도 읽힌다. 나눠도 잃는 것이 없다 |
| 티어(`prd`·`nonprd`) | ❌ | 승격은 두 값을 **비교하는** 행위다. 한 화면에 있어야 저장소만 읽고 판정할 수 있다 |

템플릿 이름은 주 컴포넌트가 addon 이름을 그대로 쓰고 부속에 접미사를 붙인다(`karpenter.yaml` ·
`karpenter-nodepool.yaml`). 각 파일 헤더에 **형제 파일 목록과 나뉜 이유**를 둔다.

root App의 `include`는 `applicationsets/`만 읽는다. `addons/`는 그 범위 밖이라 부모 차트와 addon
내용물을 무엇으로 두든 root App이 보지 않는다.

### helm values는 addon Application 밖 파일에 둔다

| 값 | 자리 | 이유 |
|---|---|---|
| 저장소가 이미 아는 값(tolerations · replicas · serviceAccount) | `addons/<addon>/values.yaml` | 양 티어가 **같은 파일**을 읽으므로 갈릴 수 없다. 주석을 고쳐도 Application spec은 그대로다 |
| 클러스터마다 갈리는 값(클러스터 이름 · cluster Secret 라벨) | addon Application의 `helm.parameters` | values 파일은 전 클러스터가 같은 파일을 읽어 클러스터별 값을 담지 못한다. ApplicationSet이 부모에 넘기고 부모 차트가 옮겨 적는다 |

addon Application은 multi-source로 읽는다. 차트 source에 `valueFiles`와 `ref` source가 더해진다.
`$values`는 `ref: values`를 단 source의 저장소 루트다.

```yaml
sources:
  - repoURL: public.ecr.aws/karpenter         # 차트 source
    chart: karpenter
    targetRevision: 1.14.0                    # 부모 차트가 versions 표에서 읽은 값
    helm:
      parameters:
        - name: settings.clusterName          # 클러스터마다 갈리는 값은 여기 남는다
          value: eks-demo-dev-an2-main-01
      valueFiles:
        - $values/addons/karpenter/values.yaml  # 저장소가 아는 값은 파일로
  - repoURL: https://github.com/<org>/eks-platform-gitops.git
    targetRevision: main
    ref: values                               # 렌더 대상이 아니다. 경로만 빌려준다
```

⚠️ values 파일은 `applicationsets/` **밖**에 둔다. root App의 `include`가 그 디렉토리를
`**/*.yaml`로 읽으므로, 안에 두면 매니페스트로 읽혀 root App의 렌더가 깨진다.

---

## 5. 관리형으로 받을 것과 조립할 것

기준은 [`decisions.md`](../../decisions.md)의 「관리형 기능 채택 기준」이 소유한다. 두 클라우드의
제공 형태가 달라 같은 기준에서 답이 갈린다.

| 기능 | AWS(EKS, Auto Mode 아님) | Azure(AKS, Automatic 아님) |
|---|---|---|
| 노드 오토프로비저닝 | 관리형은 Auto Mode뿐이다(패턴 충돌, [aws/README.md](aws/README.md) 「하지 않는 것」). Karpenter를 GitOps로 조립한다 | NAP: AKS가 Karpenter를 배포·관리한다. AKS 요금표에 별도 항목이 없다. `aks-cluster`의 `enable_karpenter`로 채택 |
| L7 인그레스(Gateway API) | EKS에 ALBC 관리형 addon이 없다. ALBC를 GitOps로 조립한다 | App Routing(Istio 기반): 컨트롤러·CRD·GatewayClass를 AKS가 관리하고 internal LB를 annotation으로 지원한다. 채택 |
| KEDA | 관리형이 없다. opt-in 카탈로그로 조립한다 | 관리형 add-on. `aks-cluster`의 `enable_keda`로 채택 |

---

## 6. L7 진입: Gateway API

양 클라우드 공통이다. Azure는 옮겨야 하고 AWS는 옮기지 않아도 되지만, 둘 다 Gateway API로 받는다.

| 클라우드 | 강제인가 | 근거 |
|---|:---:|---|
| Azure(AKS) | **그렇다** | App Routing add-on이 ingress-nginx 기반이다. 업스트림 ingress-nginx는 지원이 끝나 릴리스·버그 수정·보안 패치가 없고, AKS 관리형 NGINX도 2026-11까지만 중요 보안 패치를 받는다. Microsoft는 App Routing의 Gateway API 구현을 후속으로 권고한다 |
| AWS(EKS) | **아니다** | ALB Controller는 ingress-nginx 위에서 돌지 않아 이 지원 종료의 영향을 받지 않는다. Ingress API는 frozen이고 제거 계획이 없다(Kubernetes 공식 문서). 그대로 써도 된다 |

**그런데도 AWS까지 옮기는 이유**는 앱팀 매니페스트다. Ingress는 라우팅 규칙과 인프라 설정을
리소스 하나에 담고 세부 동작을 구현체별 annotation으로 확장한다. 구현체가 다르면 같은 라우팅에
다른 파일을 쓰게 되고, 구현체를 바꾸면 앱 저장소를 다시 쓴다. Gateway API는 그 책임을
GatewayClass · Gateway · HTTPRoute로 가른다. 클라우드 차이가 플랫폼이 소유하는 앞의 둘에 갇히고,
앱팀의 HTTPRoute는 양 클라우드에서 같은 파일이 된다. 리소스 경계가 [README.md](README.md)
「3계층 소유 모델」의 플랫폼-앱 경계와 일치한다.

**예외**: EKS에 ingress-nginx를 자체 설치한 클러스터는 AWS 쪽이어도 Azure와 같은 일정으로 옮긴다.

구현체를 관리형으로 받을지 조립할지는 「관리형으로 받을 것과 조립할 것」이, 구현체 후보를 무엇까지
보고 무엇을 기각했는지는 [aws/README.md](aws/README.md) · [azure/README.md](azure/README.md)가 갖는다.

---

## 7. 하지 않는 것

| 하지 말 것 | 이유 |
|---|---|
| **cluster generator**로 ArgoCD 자체를 팬아웃 | 등록된 모든 스포크에 ArgoCD가 설치된다. ArgoCD는 **hub에만** 산다 |
| 돌고 있는 클러스터가 있는데 **ApplicationSet·addon Application 이름이나 selector 변경** | ApplicationSet 이름이 바뀌면 기존 ApplicationSet이 삭제된 것으로 처리되어 부모가 ownerReference를 따라 지워지고, 부모의 finalizer가 그 클러스터의 addon을 전부 지운다. addon 템플릿의 `metadata.name`이 바뀌면 부모의 prune이 옛 이름의 addon을 지운다. 어느 쪽이든 `resources-finalizer.argocd.argoproj.io`가 **클러스터의 실제 리소스까지 prune한다.** CRD를 설치하는 addon이면 그 CRD를 쓰던 CR도 함께 사라진다. selector도 기존 대상이 안 걸리게 바꾸면 같은 경로다. **이름과 selector는 배포된 순간 계약**이고, 바꿀 수 있는 시점은 전면 철거 이후 seed 이전뿐이다. 같은 편집이 클러스터 상태에 따라 무해하기도 파괴적이기도 한데 diff만 봐서는 구분되지 않는다 |
| `Replace=true` · `Force=true` | 객체를 통째로 교체하거나 `delete+create`로 동기화한다. `ServerSideApply`(kubectl 대신 API 서버가 patch를 계산하는 적용 방식)보다 우선해 무력화한다 |
| `ignoreDifferences` · `managedFieldsManagers` · **전역 스위치**로 `OutOfSync` 해소 | 정답은 **앱별 `ServerSideDiff=true`**. 전역 적용은 *"`OutOfSync` = 문제"* 라는 신호를 죽인다 |
| root App 스캔 범위를 **`exclude`** 로(deny-list) | 새 차트 디렉토리가 생기면 **아직 적용되지 않은 옛 spec**으로 렌더가 실패해 root App이 자기 갱신을 못 한다. seed의 root Application 단계를 사람이 다시 밟아야 풀린다 |
| root App 스캔 범위를 **`+argocd:skip-file-rendering` 마커**로(deny-list) | 판정이 파일 전체의 문자열 포함 검사라 마커를 **설명하는 주석**이 있는 파일까지 조용히 빠진다. 마커가 붙은 파일을 Directory 소스로 읽는 전담 Application은 자기 담당 파일까지 걸러 렌더가 비는데, 리소스 0개라 `Synced`로 표시된다 |
| ↳ 대신 | root App은 **`include`(allow-list)로 매니페스트 디렉토리만 지정**한다. 범위 밖 파일은 무엇이든 무시되므로 로컬 차트에 마커가 필요 없고, 값이 갈리지 않는 addon을 마커를 피하려고 helm 차트로 만들 이유도 없다 |
| addon Application 안에 **`helm.values: \|` 인라인** | 문자열 필드라 주석 한 줄이 바뀌어도 Application spec이 바뀌고, 렌더 결과가 같은데도 전 클러스터가 `OutOfSync`로 뜬다. *"`OutOfSync` = 문제"* 신호가 죽는다. `valuesObject`는 주석 문제만 없애고 부모 차트 템플릿이 addon values까지 떠안는다. 값은 `addons/<addon>/values.yaml`에 둔다 |
| seed에 `helm --set` · **인라인 heredoc 매니페스트** | 저장소 커밋본과 바이트가 달라져 **영구 드리프트**가 된다 |
| GitOps 저장소를 **private**으로 되돌리기 · ArgoCD에 repository credential 두기 | 저장소가 public이라 ArgoCD가 익명으로 읽고, seed가 GitOps 관리 밖에 남기는 리소스가 0이다. private이면 GitHub App private key를 담은 repository Secret이 seed의 예외로 되살아나고, 그 키를 workbench로 나르는 절차와 키 분실 시 복구 절차가 함께 생긴다. 매니페스트에는 비밀이 없어 public으로 잃는 것이 없다. seed의 preflight가 익명 `ls-remote`로 이 전제를 확인한다 |
| `argocd-initial-admin-secret` **남겨두기** | 평문에 가까운 관리자 자격증명이 클러스터에 상주한다 |
| 관리형이 **버전 승격 시점을 가져간다**는 이유로 관리형을 기각 | 관리형 addon은 라이프사이클이 클러스터에 묶여 있다. AKS가 클러스터 업그레이드에 맞춰 버전을 갱신하므로 플랫폼 관리자가 addon 버전을 따로 추적·승격하지 않아도 된다. 티어별 승격은 GitOps로 조립한 addon에만 적용한다 |
| cluster Secret에 `addon-version-<name>` 라벨을 달고 `targetRevision`에 주입 | 승인된 버전이 클러스터 파일마다 흩어진다. 플랫폼이 어떤 버전을 승인했는지 한 곳에서 읽지 못하고, 버전을 올릴 때 클러스터 수만큼 파일을 고쳐야 한다 |
| matrix generator로 `clusters/<tier>/versions.yaml`을 읽어 주입 | generator 조합이 늘어 팬아웃이 안 될 때 원인을 좁히기 어렵다. 버전 표를 한 곳에 모으는 일은 부모 차트의 values 파일이 generator 없이 한다 |
| ApplicationSet `goTemplate`으로 `tier`를 조건 분기하고 **버전 리터럴을 표현식 안에** 둠 | 버전이 템플릿 표현식 안으로 들어간다. helm values를 저장소 파일 그대로 쓰고 `--set`을 금지한 이 패턴의 기준과 어긋난다. 부모 차트는 버전 리터럴을 values 파일에 두고 템플릿은 `tier`로 표에서 읽기만 한다 |

### 되살리면 안 되는 근거

| 근거 | 무엇이 반증했나 |
|---|---|
| *"`kube-apiserver`와 `kyverno`가 스키마 기본값을 채워 `OutOfSync`가 난다"* | 두 매니저는 `status` 서브리소스만 소유했다. 원인은 **CRD 스키마 defaulting**이다 |
| *"in-cluster는 자동 등록되니 cluster Secret이 불필요하다"* | 연결은 자동이지만 **ApplicationSet 팬아웃과 부모 차트가 Secret의 라벨과 이름을 읽는다** |
| *"마커는 파일 안에 있으니 root App spec을 안 건드려 순서 제약이 없다"* | 마커는 root App만 빼는 것이 아니라 **그 파일을 Directory 소스로 읽는 모든 Application**에서 뺀다. 전담 Application이 자기 담당 파일을 걸러내고, 그것을 피하려면 `Chart.yaml`을 두어 Helm 타입으로 만들어야 한다. 순서 제약을 없앤 대가로 파일 형식 제약이 생긴 것이다 |
