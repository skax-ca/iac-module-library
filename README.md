# iac-module-library

Cloud Architect 팀이 여러 고객사 프로젝트에서 재사용하는 **IaC 모듈 자산 라이브러리**.
고객사가 **구독 라이선스 없이 바로 착수**할 수 있는 것이 이 저장소의 목표다.

**스택**: OpenTofu · GitHub Actions(OIDC) · S3 backend · ArgoCD

---

## 현황

모듈은 `modules/<provider>/<모듈명>/`에 둔다. 현재 AWS 4개, Azure 0개다.

| provider | 모듈 | 설명 |
|----------|------|------|
| aws | [`vpc`](modules/aws/vpc) | VPC · 서브넷 · NAT · Flow Logs |
| aws | [`eks-cluster`](modules/aws/eks-cluster) | EKS 클러스터 · 노드그룹 · addon · IAM |
| aws | [`workbench`](modules/aws/workbench) | private 클러스터 운영 지점 (SSM 전용, 인바운드 0) |
| aws | [`cross-account-trust-role`](modules/aws/cross-account-trust-role) | 크로스 계정 IAM 신뢰 Role |

모든 모듈이 개발 단계(`0.y.z`)다. 최신 태그는 `git tag -l`로 확인한다(여기 고정 표기하지 않는다.
컷할 때마다 갱신을 잊으면 stale해진다). 실계정 배포로 검증된 조합이 `eks-reference-infra`에 있다.

태그 이름에는 provider 층이 들어가지 않는다(`vpc-vX.Y.Z`). 따라서 모듈 디렉터리명은
provider를 가로질러 고유해야 한다.

---

## 세 저장소의 관계

```
iac-module-library          이 저장소. 모듈(.tf)과 설계 문서를 소유한다
        |
        |  git tag 소싱 (vpc-v0.3.0 ...)
        v
eks-reference-infra          배포 루트. 어떤 값으로 어떻게 부르는지의 실증
        |
        |  EKS 클러스터를 만들고 ArgoCD를 세운다
        v
eks-platform-gitops          플랫폼 매니페스트. ArgoCD가 pull로 reconcile한다
```

새 고객사 프로젝트는 `eks-reference-infra`를 본떠 `<project>-infra`를 만들고,
이 저장소의 모듈을 **태그로 고정해** 소싱한다.

---

## 어디서 시작하나

| 당신이 | 읽을 것 |
|--------|---------|
| 이 조직에 막 합류했다 | [`docs/team-access.md`](docs/team-access.md): GitHub org 구조·합류 방법 |
| 팀에 처음 왔다 | [`docs/architectures/README.md`](docs/architectures/README.md): 아키텍처 패턴 라우팅표 |
| 새 프로젝트를 맡았다 | [`docs/architectures/eks-gitops-hub-spoke/choose-your-path.md`](docs/architectures/eks-gitops-hub-spoke/choose-your-path.md): 패턴을 고른 뒤 세우기·걷어내기 절차는 `eks-reference-infra` 참조 |
| 모듈을 쓰려 한다 | [`docs/module-catalog.md`](docs/module-catalog.md): 입출력 계약 |
| 왜 이렇게 됐는지 궁금하다 | [`docs/decisions.md`](docs/decisions.md): 검토하고 기각한 것들 |

---

## 쓰는 법

```hcl
module "vpc" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/aws/vpc?ref=vpc-vX.Y.Z"

  naming = { workload = "demo", env = "dev", region_code = "an2" }
  # ...
}
```

`vX.Y.Z`는 자리표시자다. 실제 최신 태그는 `git tag -l 'vpc-v*'`로 확인한다.
태그는 컴포넌트별 semver다. `ref=main`을 쓰지 않는다(움직이는 참조다).

---

## 개발 준비

```bash
brew install opentofu trivy
git config core.hooksPath .githooks        # clone마다 1회
GITHUB_TOKEN=$(gh auth token) tflint --init
```

커밋 전 로컬 게이트와 CI가 같은 7개 게이트를 돈다:
`tofu fmt` · `tflint` · `trivy config` · 모듈 `validate`+`test` · 예제 `validate` · lock registry 검사 · terraform-docs drift 검사.

규칙은 [`docs/conventions.md`](docs/conventions.md)가 소유한다.
AI 에이전트로 작업할 때의 규칙은 [`CLAUDE.md`](CLAUDE.md)에 있다.
