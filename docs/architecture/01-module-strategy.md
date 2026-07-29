# 01 · 모듈 전략 & 경계 설계

> **승계**: `terraform-enterprise-poc` `docs/architecture/01-strategy-and-decisions.md` @ `76285f7`(동결 커밋)
> **개정**: §5(TFC 오케스트레이션·Stacks 파일럿) **폐기** — HCP 전용이라 이 스택에 해당 없음 ·
> 모듈 소싱을 상대경로에서 **git tag**로 · 실증 서술은 [`reference/poc-findings.md`](../reference/poc-findings.md)로 이관 ·
> 재사용 자산 요건(파라미터화·kill switch) 추가.
> 이후 **이 문서가 SSOT**다. 원본은 이력 조회용으로만 본다.

---

## 1. 근본 질문과 결론

**커뮤니티 AWS 모듈을 쓸 것인가, 스크래치로 짤 것인가.** 커뮤니티 모듈은 코드가 작고 가독성이 좋지만
버전 업그레이드 시 의존성 문제가 커진다 — 특히 EKS 모듈은 빠른 버전업이 AWS provider와 Terraform
버전 업그레이드까지 강요했다.

**결론: 이분법이 아니라 리소스별 스펙트럼이다.**

- 커뮤니티 모듈의 진짜 가치는 "코드를 덜 쓰는 것"이 아니다 — 그건 AI 코딩이 지운 이점이다.
  진짜 가치는 **수천 명이 프로덕션에서 검증한 운영 지식의 응축**(정확성 오라클)이다.
- AI는 최적점을 스크래치 쪽으로 약간 밀지만 wrapper를 없애진 않는다 — **wrapper를 싸게 만든다**.
- churn은 도구 선택으로 없어지지 않는다. EKS 모듈의 churn이 큰 것은 저자 변덕이 아니라
  **EKS 자체(AWS API + k8s)가 빠르게 움직이기 때문**이다. 스크래치로 짜도 같은 변화를 직접 따라가야 한다.
  churn은 제거 대상이 아니라 **관리 전략으로 통제**하는 대상이다.

---

## 2. 결정 1 — 계층형 하이브리드 모듈 전략

### 2.1 3계층 토폴로지 (upstream 격리)

```
Consumer 계층 (프로젝트 repo의 live/<account>/<component>/)
  module "eks" {
    source = "git::https://github.com/<org>/iac-module-library.git//modules/eks-cluster?ref=eks-cluster-v1.0.0"
  }
        │  (소비자는 upstream을 절대 직접 참조하지 않는다)
        ▼
내부 "Golden Path" 모듈 계층 (이 repo — 컴포넌트별 semver)
  modules/eks-cluster/  →  terraform-aws-modules/eks 를 wrapping(facade)
  modules/vpc/          →  스크래치 (EKS-aware 태깅)
        │  (= 정확 버전 핀)
        ▼
Upstream 계층 (커뮤니티 모듈 / provider)
```

**핵심 이득**: upstream이 메이저를 올려도 wrapper **한 곳**에서 흡수 → 소비 프로젝트 코드 무변경.

### 2.2 리소스 등급제 (판별 규칙)

| 규칙 | 전략 | 리소스 |
|------|------|--------|
| 안정 + 단순 + 지식밀도 낮음 | **스크래치 얇은 모듈** | VPC, S3, SG, IAM baseline, KMS |
| 고속 churn + 지식밀도 높음 + 정확성 비직관적 | **커뮤니티 모듈 + wrapper** | **EKS**(+Karpenter/addons/access entries), 필요시 RDS |

### 2.3 의존성 통제 메커니즘

1. **정확 버전 핀 + lock 커밋** — 내부 모듈은 upstream을 `= x.y.z`로, `required_providers`에 테스트한 범위.
   ⚠️ lock의 registry 주소가 `registry.opentofu.org/...`인지 확인(다른 스택의 lock을 복사하지 않는다).
2. **Wrapper(facade) 패턴** — 업그레이드 폭발 반경을 한 곳에 가둔다.
3. **provider 핀을 컴포넌트 단위로 격리** — 한 모듈이 전체 estate의 provider를 끌고 가지 못하게.
4. **의존성 봇은 이 repo에만, 자동 머지 금지** — 소비 프로젝트는 우리가 릴리스한 태그로만 올린다.
5. **semver 거버넌스 계약** — upstream 파괴적 변경을 인터페이스 유지로 흡수 = 내부 **마이너**(소비자 무영향),
   숨길 수 없으면 내부 **메이저**(의도적 마이그레이션). **upstream cadence와 소비자 cadence를 분리**한다.
6. **마이그레이션 헬퍼 활용** — 공식 CHANGELOG, upstream이 제공하는 마이그레이션 도구.

---

## 3. 결정 2 — EKS Day 0/1 (IaC) ↔ Day 2 (GitOps) 경계

### 3.1 왜 이 경계인가

- **AWS EKS Blueprints가 v4→v5에서 방향 전환**: "IaC로 helm/k8s addon을 관리하지 마라."
  v4의 addon wrapping이 상태 드리프트·순환 의존을 유발 → v5는 **GitOps Bridge 패턴**으로 전환.
- **push vs pull 충돌**: IaC는 push(외부 API 호출) → 클러스터 엔드포인트 public access를 강제하고,
  `kubernetes_manifest`는 plan 시점에 클러스터 API에 의존 → 순환.
  GitOps는 pull(클러스터 내부 controller가 Git을 당김) → 엔드포인트 private 유지 가능, 더 안전.
- **원격 실행 환경에서 kubernetes/helm provider는 안티패턴**: 인증 토큰 만료, plan-time API 의존,
  GitOps 도구의 변경을 IaC가 drift로 오인.

### 3.2 경계선

| 계층 | 도구 | 대상 | 근거 |
|------|------|------|------|
| Day 0/1 인프라 | **IaC** | 클러스터, managed node group, IAM(Pod Identity/IRSA), OIDC provider | 순수 AWS API, 안정적 상태 |
| Managed/Community Addons | **IaC `aws_eks_addon`** | core(vpc-cni·coredns·kube-proxy·pod-identity-agent)·ebs-csi·metrics-server + 관측성 + cert-manager·external-dns **컨트롤러** | Helm이 아니라 AWS API — push 안티패턴 무관 |
| Day 2 GitOps | **GitOps** | helm-only 컴포넌트(ALB Controller 등), 컨트롤러 **설정**(Issuer·애노테이션), 앱 워크로드 | helm-only이거나 설정(CR) |

> **한 줄 규칙**: `aws_eks_addon` API로 설치 가능 → IaC. Helm chart / k8s manifest → GitOps.
> 단 **컨트롤러(+CRD)는 IaC addon, 그 addon이 소비하는 CR·애노테이션만 GitOps**.

### 3.3 부트스트랩 seam — **이 repo에서 재결정 필요**

PoC는 관리형 **EKS Capability for Argo CD**를 채택했다(self-managed helm 설치 대비: 클러스터 내 설치 없음,
helm provider 불필요, spoke 등록은 Access Entry). 그 과정의 실측은
[`reference/poc-findings.md` §3](../reference/poc-findings.md)에 있다.

⚠️ **이 repo는 아직 이 선택을 승계하지 않았다.** 관리형 Capability는 IdC 필수·cross-region 계정 인스턴스·
RETAIN 삭제 정책 등 제약이 크고, findings §3의 항목 대부분이 재확인 대상이다.
GitOps 모듈을 설계할 때 **대안(self-managed ArgoCD 포함)과 함께 다시 결정**한다.

---

## 4. 결정 3 — 재사용 자산으로서의 요건 (PoC에는 없던 것)

이 repo의 모듈은 **여러 프로젝트·여러 고객 환경**에서 소비된다. 다음은 PoC 모듈에 없었고 반드시 추가한다.

| 요건 | 내용 |
|------|------|
| **파라미터화** | workload code·계정 ID·리전·환경 프로파일을 하드코딩하지 않는다. `naming` 객체로 주입받는다 |
| **kill switch** | 각 컴포넌트에 `<component>_enabled` 변수를 두어 `false`면 전 리소스를 파기한다. **data source의 `count`까지 0**이 되게 해야 참조 대상이 사라진 뒤에도 plan이 통과한다(findings §6.2) |
| **환경 프로파일** | dev/stg/prd 차이를 모듈 변수로 흡수(`single_nat_gateway`, `az_count`, spot 비율 등). 소비자가 조건 분기를 짜지 않게 한다 |
| **예제 + 테스트** | `examples/<module>/`이 곧 `tofu test` 대상. 모듈은 예제 없이 릴리스하지 않는다 |
| **출력 계약** | 소비자가 의존하는 출력은 **메이저 버전 내에서 안정**. 이름 변경은 메이저 |

---

## 5. VPC/S3에 대한 제로 베이스 판단

- **VPC**: EKS는 VPC에 특정 태그(`kubernetes.io/role/elb`, `.../internal-elb`, `kubernetes.io/cluster/<name>`)를
  요구하므로 VPC 모듈이 **EKS-aware**해야 한다. 커뮤니티 VPC 모듈의 EKS 태그 옵션은 복잡 →
  **얇은 스크래치 모듈이 오히려 유리**.
- **S3**: 단독 버킷은 리소스 1~2개 → 모듈로 감쌀 가치가 의문. 루트에서 직접 선언이 더 단순
  (모듈 남용 안티패턴 회피). 다만 **암호화·퍼블릭 차단·버전 관리 기본값**을 강제할 필요가 있으면 얇은 모듈로.

---

## 6. AI의 역할

- 레버리지가 가장 큰 곳은 **내부 모듈 계층**: upstream CHANGELOG 독해, wrapper 생성, 마이그레이션 diff,
  정책·테스트 생성, 스크래치 모듈 최신 유지.
- AI는 EKS의 "정답 오라클"로서 커뮤니티 모듈을 **대체하지 못한다**(할루시네이션 위험).
  **AI + 커뮤니티 모듈 소스 = 정답 패턴 추출 → wrapper 유지보수**가 최상 조합.
- 그래서 규칙: 새 리소스·인자는 **registry/provider 문서로 확인**하고 추정하지 않는다.

---

## 7. 열린 항목

1. GitOps 부트스트랩 seam 재결정(§3.3) — 관리형 Capability vs self-managed.
2. 모듈 릴리스 프로세스 — 태그 규칙(`<module>-vX.Y.Z`)은 정했으나 CHANGELOG·릴리스 노트 형식 미정.
3. 노드 관리 조합 — managed node group + Karpenter의 역할 분담(시스템 계층 vs 앱 계층).
4. 모듈 간 의존 표현 — VPC 출력을 EKS 모듈이 어떻게 받을지(변수 vs data source, → `03-dependencies.md`).
5. S3·IAM baseline 등 얇은 모듈의 최소 집합 확정.

---

## 8. 참고 자료

- [terraform-aws-modules/eks (Registry)](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [AWS EKS Blueprints — v4→v5 Motivation (GitOps 전환)](https://aws-ia.github.io/terraform-aws-eks-blueprints/v4-to-v5/motivation/)
- [GitOps Bridge](https://github.com/gitops-bridge-dev/gitops-bridge)
- [OpenTofu 문서](https://opentofu.org/docs/)
