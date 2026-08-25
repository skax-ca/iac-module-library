# CLAUDE.md: 프로젝트 규칙

**읽는 사람**: 이 저장소에 코드를 쓰거나 설계를 검토하는 사람.

Cloud Architect 팀이 **여러 실제 프로젝트에서 재사용**하는 IaC 모듈 자산 라이브러리.
고객사가 **구독 라이선스 없이 바로 착수**할 수 있어야 하는 것이 이 repo의 존재 이유다.

**스택**: **OpenTofu**(MPL-2.0) + GitHub Actions(OIDC) + S3 backend(`use_lockfile`) + OPA/Conftest

**`.tf` 작업 규칙**(네이밍·아키텍처·검증·모듈 설계 원칙)은 `.claude/rules/terraform.md`가 소유한다
(`.tf` 파일을 열 때 자동 로드된다). 이 파일은 리포 전역 규칙만 갖는다.

## 엔진: OpenTofu 단독

명령은 `terraform`이 아니라 **`tofu`**다. 로컬·CI·문서·lock 전부 하나로 일원화한다.
채택 근거(라이선스가 아니라 조달 마찰·리워크 제거)는 `docs/decisions.md`가 소유한다.

- **두 엔진 동시 지원은 검토 후 기각했다**(실측 비용 5건). *"둘 다 지원하면 되지 않나"* 라는
  질문이 나오면 **`docs/decisions.md`를 먼저 읽는다**. 이미 값을 매겨 기각한 안이다.
- **Terraform 호환성은 계약이 아니라 부산물**이다. 보장하지 않지만 이유 없이 깨뜨리지도 않는다:
  OpenTofu 고유 기능을 쓸 때는 이유를 설계 문서에 남긴다(강제 장치는 없다, `docs/conventions.md`).

---

## 0. 이 repo의 위치 (반드시 먼저 읽을 것)

| repo | 역할 |
|------|------|
| **이 repo (`iac-module-library`)** | 모듈·설계의 **현행 SSOT**. 모든 개발은 여기서 |
| `terraform-enterprise-poc` | TFC 기반 **동결 스냅샷**(2026-07-28 졸업). TFE 제안서 레퍼런스 전용. **고치지 않는다** |
| `silverte/eks-platform-gitops` | PoC GitOps 구현체(**동결**). 참조 자산으로만 쓴다 |
| `<project>-infra` (향후 N개) | 프로젝트/고객별 배포 루트. 이 repo의 모듈을 **git tag로 소싱** |
| **`eks-platform-gitops`** (2026-08-07 신설) | 플랫폼 GitOps 매니페스트(**계층 2**). ArgoCD가 pull로 reconcile |

> ⚠️ **`.yaml` 매니페스트는 이 repo에 두지 않는다.** 여기는 모듈(`.tf`)과 설계(`docs/`)만 소유한다.
> ArgoCD Application·AppProject·cluster Secret은 **`eks-platform-gitops`** 소관이다
> (3계층 소유 모델, `docs/architectures/eks-gitops-hub-spoke/overview.md`).

- 결정 근거: `terraform-enterprise-poc/docs/architecture/05-oss-asset-repo-decision.md`.
  ⚠️ 그중 **엔진 축의 근거는 `docs/decisions.md`가 교체**했다.
  결론(OpenTofu)은 같지만 **이유가 다르다**: PoC repo는 라이선스를, 여기는 조달 마찰·운영 비용을 든다.
  PoC repo는 동결이라 그쪽에 개정 표시가 없으므로 **`08`을 함께 읽는다.**
- ⛔ **PoC repo에서 모듈·설계를 수정하지 않는다.** 양쪽 개발은 곧 drift이고, 6개월 뒤 어느 쪽이
  정답인지 판정 불가능해진다.

### 소비 방식 (프로젝트 repo에서)

```hcl
module "vpc" {
  source = "git::https://github.com/<org>/iac-module-library.git//modules/vpc?ref=vpc-vX.Y.Z"
  # ...
}
```

`vX.Y.Z`는 자리표시자다. 실제 최신 태그는 `git tag -l`로 확인한다.
태그는 **컴포넌트별 semver**: `vpc-vX.Y.Z` · `eks-cluster-vX.Y.Z`.

## 버전 정책: 전 모듈 `0.y.z`

번호 체계의 SSOT는 **`docs/conventions.md`**이고, 기각한 안은 **`docs/decisions.md`**가 갖는다.
요약: 전 모듈이 개발 단계(`0.y.z`)라 파괴적 변경도 마이너로 흡수한다("마이너/메이저 판정"을 하지
않는다, 전부 마이너다). `1.0.0`은 전 모듈 일괄이 아니라 **모듈별로** 컷한다. 신규 모듈은 `0.1.0`에서
시작한다. 버전 혼재(`vpc-v0.3.0` + `workbench-v0.6.0`)는 결함이 아니라 **정보**다.

---

## 설계·검토 우선 규칙 (최우선, 필수 준수)

**구현하기 전에 반드시 설계 및 검토를 완료한 후 구현할 것.**

- 코드(`.tf`) 작성/변경 전에 관련 설계가 `docs/`에 존재하고 승인·검토되었는지 확인한다.
  모듈 계약은 `docs/module-index.md`, 규약은 `docs/conventions.md`가 소유한다.
- 설계가 없거나 불완전하면 **구현을 멈추고** 먼저 설계 문서(설계 → 검토 → 승인)를 작성/보완한다.
- "간단해 보인다"는 이유로 이 단계를 건너뛰지 않는다. 새 모듈·아키텍처 변경·인터페이스 변경은 예외 없음.
- 순서: **설계 문서화 → 검토/승인 → 구현 → 검증(fmt/validate/test)**.

> ⛔ **기각한 안을 다시 제안하기 전에 `docs/decisions.md`를 읽는다.** 거기 적힌 이유가
> 더 이상 성립하지 않음을 먼저 보여야 재검토가 열린다.

---

## 브랜치·PR 규칙

| 변경 대상 | 경로 |
|-----------|------|
| **`.tf` · `.github/workflows/`** | **브랜치 → PR** |
| **문서 · `.omc/notepad.md` 전용** | **`main` 직접 커밋** |

- 기준은 *"CI가 **머지 전에** 막아야 하는가"* 하나다. `verify.yml`은 **`push: branches: [main]`에도 돌므로**
  "PR이어야 CI가 돈다"는 성립하지 않는다. 차이는 **깨진 것이 main에 들어가기 전에 걸리느냐**뿐이다.
  문서에는 main을 깨뜨릴 산출물이 없다.
- ⛔ **문서 전용 변경에 PR을 쓰지 않는다.** 이 repo는 사실상 1인 작업이라 리뷰는 self-merge = 형식이고,
  커밋 메시지를 길게 쓰는 문화라 PR 본문도 중복이다. 형식만 남은 절차는 비용만 낸다.
- ⚠️ **브랜치 작업 시 `.omc/notepad.md` 갱신을 같은 브랜치에 싣는다.** 누락되면 다음 세션이
  이미 끝난 일을 다시 다음 태스크로 안내받는다. 브랜치가 늘 때마다 "무엇을 어디에 실을지"를
  판단해야 하는 지점이라 놓치기 쉽다.
