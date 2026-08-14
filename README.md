# iac-module-library

Cloud Architect 팀이 여러 고객사 프로젝트에서 재사용하는 **IaC 모듈 자산 라이브러리**.
고객사가 **구독 라이선스 없이 바로 착수**할 수 있는 것이 이 저장소의 목표다.

**스택**: OpenTofu · GitHub Actions(OIDC) · S3 backend · ArgoCD

---

## 현황

| 모듈 | 최신 태그 | 계약 테스트 | 설명 |
|------|----------|------------|------|
| `vpc` | `vpc-v0.3.0` | 13 | VPC · 서브넷 · NAT · Flow Logs |
| `eks-cluster` | `eks-cluster-v0.7.0` | 24 | EKS 클러스터 · 노드그룹 · addon · IAM |
| `workbench` | `workbench-v0.6.0` | 18 | private 클러스터 운영 지점 (SSM 전용, 인바운드 0) |

모든 모듈이 개발 단계(`0.y.z`)다. 실계정 배포로 검증된 조합이 `iac-reference-infra`에 있다.

---

## 세 저장소의 관계

```
iac-module-library          이 저장소. 모듈(.tf)과 설계 문서를 소유한다
        |
        |  git tag 소싱 (vpc-v0.3.0 ...)
        v
iac-reference-infra         배포 루트. 어떤 값으로 어떻게 부르는지의 실증
        |
        |  EKS 클러스터를 만들고 ArgoCD를 세운다
        v
iac-platform-gitops         플랫폼 매니페스트. ArgoCD가 pull로 reconcile한다
```

새 고객사 프로젝트는 `iac-reference-infra`를 본떠 `<project>-infra`를 만들고,
이 저장소의 모듈을 **태그로 고정해** 소싱한다.

---

## 어디서 시작하나

| 당신이 | 읽을 것 |
|--------|---------|
| 이 조직에 막 합류했다 | [`docs/00-team-access.md`](docs/00-team-access.md) — GitHub org 구조·합류 방법 |
| 팀에 처음 왔다 | [`docs/01-architecture.md`](docs/01-architecture.md) — 전체 그림 |
| 새 프로젝트를 맡았다 | [`docs/02-choose-your-path.md`](docs/02-choose-your-path.md) → [`docs/03-new-project.md`](docs/03-new-project.md) |
| 모듈을 쓰려 한다 | [`docs/05-modules.md`](docs/05-modules.md) — 입출력 계약 |
| 환경을 걷어내야 한다 | [`docs/04-teardown.md`](docs/04-teardown.md) |
| 왜 이렇게 됐는지 궁금하다 | [`docs/08-decisions.md`](docs/08-decisions.md) — 검토하고 기각한 것들 |

---

## 쓰는 법

```hcl
module "vpc" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/vpc?ref=vpc-v0.3.0"

  naming = { workload = "demo", env = "dev", region_code = "an2" }
  # ...
}
```

태그는 컴포넌트별 semver다. `ref=main`을 쓰지 않는다 — 움직이는 참조다.

---

## 개발 준비

```bash
brew install opentofu trivy
git config core.hooksPath .githooks        # clone마다 1회
GITHUB_TOKEN=$(gh auth token) tflint --init
```

커밋 전 로컬 게이트와 CI가 같은 6개 게이트를 돈다:
`tofu fmt` · `tflint` · `trivy config` · 모듈 `validate`+`test` · 예제 `validate` · lock registry 검사.

규칙은 [`docs/06-conventions.md`](docs/06-conventions.md)가 소유한다.
AI 에이전트로 작업할 때의 규칙은 [`CLAUDE.md`](CLAUDE.md)에 있다.
