# addon 전파 정책

**읽는 사람**: 등록된 클러스터들에 addon을 내보내거나 그 버전을 올리려는 사람.

허브 하나에 ArgoCD를 두고 스포크를 등록하는 구조에서, addon 하나를 어느 클러스터에
어떤 버전으로 내보낼지 정한다. addon을 계층 1과 2 중 어디에 둘지는
[choose-your-path.md](choose-your-path.md)가 소유한다.

---

## 1. selector는 "누가 받나"까지만 가른다

ApplicationSet의 cluster generator selector는 팬아웃 대상을 고른다. 버전은 고르지 않는다.
`targetRevision`이 리터럴 한 개라, 그 selector에 걸린 클러스터는 전부 같은 버전을 받는다.

| selector | 대상 |
|------|------|
| `matchExpressions [{key: environment, operator: Exists}]` | 등록된 전 클러스터 |
| `matchLabels {addon-<name>: enabled}` | 그 라벨을 단 클러스터 |

`environment` 라벨의 값(`hub` · `dev`)은 이름과 values 경로를 푸는 데 쓴다. 버전 분기에는
쓰지 않는다.

이 상태에서 `targetRevision`을 올리면 등록된 클러스터가 동시에 올라간다. 컨트롤러를
비운영 클러스터에서 먼저 검증하고 운영으로 승격하려면 정책이 하나 더 필요하다.

---

## 2. 전파 정책 셋

addon마다 아래 셋 중 하나를 고른다.

| 정책 | selector | 버전 | 상태 |
|------|----------|------|------|
| **uniform** | `environment` Exists | 전 클러스터 한 개 | ✅ |
| **staged** | `tier` 값별 ApplicationSet 분리 | 티어마다 한 개 | ⏳ |
| **opt-in** | `matchLabels {addon-<name>: enabled}` | 구독 클러스터 한 개 | ✅ |

### 고르는 기준

| 이 addon이 | 정책 | 이유 |
|-----------|------|------|
| 앱팀을 제약하는 가드레일인가 | **uniform** | 클러스터마다 정책 버전이 다르면 통과 기준이 갈린다. 차이 자체가 위험이다 |
| 인프라를 직접 움직이는 컨트롤러인가 | **staged** | 노드를 만들고 트래픽을 받는다. 비운영에서 먼저 확인하고 승격한다 |
| 팀이 필요할 때만 켜는 기능인가 | **opt-in** | 쓰는 클러스터가 정해져 있어 승격 단계를 나눌 대상이 적다 |

| addon | 정책 |
|-------|------|
| `kyverno` · `kyverno-policies` · `kyverno-custom-policies` | uniform |
| `karpenter` · `aws-load-balancer-controller` · `gateway-api-crds` | staged |
| `keda` · `cluster-autoscaler` | opt-in |

---

## 3. staged를 쓰는 형태

addon 파일 하나에 ApplicationSet을 티어 수만큼 둔다. 파일은 나누지 않는다.

```yaml
# addons/baseline/karpenter.yaml
metadata:
  name: karpenter-nonprd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            tier: nonprd
  template:
    spec:
      source:
        targetRevision: 1.15.0    # 검증 중
---
metadata:
  name: karpenter-prd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            tier: prd
  template:
    spec:
      source:
        targetRevision: 1.14.0    # 운영
```

🔑 두 `targetRevision`의 차이가 승격이 어디까지 갔는지를 저장소에 기록한다. 파일에 적힌
차이는 의도한 것이고, 그 밖의 클러스터 간 차이는 사고다. 클러스터를 열어 보지 않고
저장소만 읽어 판정한다.

블록 수는 티어 수를 따라간다. 클러스터 수를 따라가지 않는다. 스포크를 몇 개 늘려도
addon 파일은 그대로다.

### 승격 절차

1. `karpenter-nonprd`의 `targetRevision`을 새 버전으로 올려 커밋한다.
2. 비운영 클러스터에서 컨트롤러 동작을 확인한다.
3. `karpenter-prd`의 `targetRevision`을 같은 값으로 올려 커밋한다.
4. 두 값이 같아지면 승격이 끝난 것이다.

---

## 4. 전제: `tier` 라벨 어휘를 먼저 고정한다

staged는 cluster Secret의 `tier` 라벨을 소비한다. 이 라벨은 이미 붙어 있고, 값 어휘가
저장소마다 갈려 있다.

| 저장소 | 클러스터 | 현재 값 |
|--------|---------|--------|
| `eks-platform-gitops` | hub | `prd` |
| `aks-platform-gitops` | hub | `prd` |
| `aks-platform-gitops` | dev | `dev` |

⚠️ staged를 구현하기 전에 값을 `nonprd`와 `prd` 둘로 고정한다. 값이 갈린 채로 selector를
걸면 어느 쪽에도 안 걸리는 클러스터가 조용히 생긴다. ArgoCD는 대상이 0개인 팬아웃을
오류로 보고하지 않는다.

`environment`가 아니라 `tier`를 쓰는 이유는 값의 개수다. `environment`는 클러스터가 늘면
값이 함께 늘고, `tier`는 둘로 고정된다.

---

## 5. 기각한 안

| 안 | 기각 이유 |
|----|-----------|
| cluster Secret에 `addon-version-<name>` 라벨을 달고 `targetRevision`에 그 값을 주입 | 승인된 버전이 클러스터 파일마다 흩어진다. 플랫폼이 어떤 버전을 승인했는지 한 곳에서 읽지 못하고, 버전을 올릴 때 클러스터 수만큼 파일을 고쳐야 한다 |
| matrix generator로 `clusters/<tier>/versions.yaml`을 읽어 주입 | 버전 목록은 한 곳에 모이지만 generator 조합이 늘어 팬아웃이 안 될 때 원인을 좁히기 어렵다. baseline addon이 다섯 개인 지금은 값에 비해 비싸다. addon이 늘면 다시 본다 |
| `goTemplate`으로 `tier`를 조건 분기해 `targetRevision`을 고름 | 버전이 템플릿 표현식 안으로 들어간다. helm values를 저장소 파일 그대로 쓰고 `--set`을 금지한 이 패턴의 기준과 어긋난다 |
