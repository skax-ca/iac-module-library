# iac-module-library

**읽는 사람**: 이 저장소의 모듈을 쓰려는 사람, 그리고 여기에 모듈·설계를 더하는 사람.

**오너**: GitHub org [`skax-ca`](https://github.com/skax-ca). 질문과 제안은 Issues로 받는다.

여러 프로젝트에서 재사용하는 **IaC 모듈 자산 라이브러리**. 프로젝트마다 아키텍처를 새로
그리는 것은 당연하다. 문제는 그때 내린 설계 판단이 남지 않아 다음 프로젝트에서 같은 고민을
반복하는 것이고, 그 판단을 모듈·패턴·규약으로 쌓는 것이 이 저장소가 있는 이유다. 그래서
`modules/`와 `docs/`가 같은 무게를 갖는다.

**스택**: OpenTofu · GitHub Actions(OIDC) · 원격 state backend(S3 · Azure Storage) · ArgoCD

---

## 모듈

모듈은 `modules/<provider>/<모듈명>/`에 둔다.

| provider | 모듈 | 설명 |
|----------|------|------|
| aws | [`vpc`](modules/aws/vpc) | VPC · 서브넷 · NAT · Flow Logs |
| aws | [`eks-cluster`](modules/aws/eks-cluster) | EKS 클러스터 · 노드그룹 · addon · IAM |
| aws | [`workbench`](modules/aws/workbench) | private 클러스터 운영 지점 (SSM 전용, 인바운드 0) |
| aws | [`cross-account-trust-role`](modules/aws/cross-account-trust-role) | 크로스 계정 IAM 신뢰 Role |
| azure | [`vnet`](modules/azure/vnet) | VNet · 서브넷 · 옵트인 NSG · 옵트인 라우팅 테이블 · NAT Gateway |
| azure | [`aks-cluster`](modules/azure/aks-cluster) | AKS 클러스터 · 시스템/추가 노드 풀 · Karpenter(NAP) |
| azure | [`aks-workbench`](modules/azure/aks-workbench) | private 클러스터 운영 지점 (SSH 일상 경로, Run Command 브레이크글래스) |

모든 모듈이 개발 단계(`0.y.z`)다. 최신 태그는 `git tag -l`로 확인한다. 실계정 배포로 검증된
조합은 [`eks-reference-infra`](https://github.com/skax-ca/eks-reference-infra)(AWS)·
[`aks-reference-infra`](https://github.com/skax-ca/aks-reference-infra)(Azure)에 있다.

태그 이름에는 provider 층이 들어가지 않는다(`vpc-vX.Y.Z`). 따라서 모듈 디렉터리명은
provider를 가로질러 고유해야 한다.

---

## 저장소 관계

이 저장소는 모듈(`.tf`)과 설계 문서를 소유하는 SSOT다. AWS·Azure 두 provider가 이 SSOT를 각자의
체인으로 소비하고, 이후 단계부터 갈린다.

| 단계 | AWS | Azure | 무엇을 하는지 |
|------|-----|-------|----------------|
| 배포 루트 | [`eks-reference-infra`](https://github.com/skax-ca/eks-reference-infra) | [`aks-reference-infra`](https://github.com/skax-ca/aks-reference-infra) | 이 저장소의 모듈을 git tag로 소싱해 클러스터를 구축하고 ArgoCD를 심는다 |
| 플랫폼 GitOps | [`eks-platform-gitops`](https://github.com/skax-ca/eks-platform-gitops) | [`aks-platform-gitops`](https://github.com/skax-ca/aks-platform-gitops) | ArgoCD가 pull로 reconcile하는 플랫폼 매니페스트 |

새 프로젝트는 AWS면 `eks-reference-infra`, Azure면 `aks-reference-infra`를 본떠
`<project>-infra`를 만들고, 이 저장소의 모듈을 **태그로 고정해** 소싱한다.

---

## 어디서 시작하나

| 당신이 | 읽을 것 |
|--------|---------|
| 저장소 접근 권한부터 필요하다 | [`docs/team-access.md`](docs/team-access.md): GitHub org 구조·합류 방법 |
| 이 팀이 쌓아 둔 패턴이 궁금하다 | [`docs/architectures/README.md`](docs/architectures/README.md): 아키텍처 패턴 라우팅표 |
| 새 프로젝트를 맡았다 | [`docs/architectures/gitops-hub-spoke/README.md`](docs/architectures/gitops-hub-spoke/README.md): 이 패턴이 맞는지 판정한다. 구축·철거 절차는 `eks-reference-infra`(AWS)·`aks-reference-infra`(Azure) 참조 |
| 모듈을 쓰려 한다 | [`docs/module-catalog.md`](docs/module-catalog.md): 입출력 계약 |
| 왜 이렇게 됐는지 궁금하다 | [`docs/decisions.md`](docs/decisions.md): 검토하고 기각한 것들 |

---

## 쓰는 법

```hcl
module "vpc" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/aws/vpc?ref=vpc-vX.Y.Z&depth=1"

  naming = { workload = "demo", env = "dev", region_code = "an2" }
  # ...
}
```

`vX.Y.Z`는 자리표시자다. 실제 최신 태그는 `git tag -l 'vpc-v*'`로 확인한다.
태그는 컴포넌트별 semver다. `ref=main`을 쓰지 않는다(움직이는 참조다).

`depth=1`은 얕은 클론이다. 이 저장소는 모듈 전부의 태그 이력을 한 트리에 쌓으므로, 모듈 하나를
받는 데 전체 이력을 끌어올 이유가 없다. ⚠️ `depth`를 주면 OpenTofu가 `ref`를 `git clone
--branch`로 넘기므로 **`ref`에 커밋 SHA를 쓸 수 없다.** 태그나 브랜치만 받는다. 이 저장소는
`ref`가 항상 태그라 제약에 걸리지 않는다.

---

## 개발 준비

```bash
brew install opentofu tflint trivy terraform-docs shellcheck gitleaks
git config core.hooksPath .githooks        # clone마다 1회
GITHUB_TOKEN=$(gh auth token) tflint --init
```

`verify.yml`이 게이트 7개를 돈다: `tofu fmt` · `tflint` · `trivy config` · 모듈
`validate`+`test` · 예제 `validate` · lock registry 검사 · terraform-docs drift 검사.
로컬 훅은 그중 커밋 때 `fmt`·`tflint`·`trivy`·terraform-docs drift를, push 때 코드가 바뀐
모듈의 `test`를 돈다. 예제 `validate`와 lock registry 검사는 CI에만 있다.

규칙은 [`docs/conventions.md`](docs/conventions.md)가 소유한다.
AI 에이전트로 작업할 때의 규칙은 [`CLAUDE.md`](CLAUDE.md)에 있다.

`.tf`·워크플로·검사기 변경은 브랜치 → PR이다. `verify.yml`이 훅과 같은 게이트를 PR에서 다시
돈다. 문서만 바뀌는 커밋은 `main` 직접이다.

---

## 라이선스

[MIT](LICENSE). 다섯 저장소가 같은 라이선스다.
