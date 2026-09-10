# 팀 온보딩: 접근과 구조

**읽는 사람**: 새로 합류해 이 조직에 접근 권한부터 얻어야 하는 사람.

---

## 1. 이 문서 집합이 무엇인가: 레퍼런스이지 실제 배포가 아니다

이 저장소(`iac-module-library`)는 **모듈과 설계의 SSOT**(Single Source of Truth, 단일 진실 공급원)다. `.tf` 코드와 `docs/`의 나머지 문서는
고객사 프로젝트가 인프라를 세울 때 따르는 **패턴**을 담을 뿐, 우리 팀이 실제로 운영 중인
계정·저장소 그 자체가 아니다. 이 저장소는 배포하지 않는다.

전체 그림은 [`architectures/eks-gitops-hub-spoke/overview.md`](architectures/eks-gitops-hub-spoke/overview.md), repo 간 역할 분담은 `CLAUDE.md`를 본다.

---

## 2. GitHub org 구조

| 무엇 | 값 |
|---|---|
| Organization | `skax-ca` (무료 플랜) |
| Team | `iac` (slug `iac`, privacy **closed**) |
| 이 저장소의 Team 내 권한 | `maintain` |

**"프로젝트 묶음"이라는 별도 계층은 GitHub에 없다.** org > 프로젝트 > repo처럼 중첩된 구조는
지원되지 않는다. 관련 저장소를 묶는 실체는 **Team**(`iac`)이다.

org 기본 권한(`default_repository_permission`)이 `read`라 org 멤버는 Team 없이도 저장소를
읽는다. Team이 주는 것은 `maintain`(push·브랜치 관리)이다.

새 IaC 관련 저장소를 만들면 아래로 Team에 붙인다:

```bash
gh api --method PUT orgs/skax-ca/teams/iac/repos/skax-ca/<repo> -f permission='maintain'
```

**무료 플랜의 제약**: private repo에 required reviewers를 걸 수 없다. 무료 플랜은 **public
repo에서만** environment protection rule을 설정할 수 있어서, 승인 게이트가 필요하면 Team
플랜 이상으로 올리거나 저장소를 public으로 전환해야 한다.

**GitHub Actions(CI) 무료 사용량**: private 저장소 기준 **월 2,000분**까지 무료다(공개 저장소는
표준 러너로 무제한). Artifact storage 500MB · Cache storage 10GB(저장소당)를 넘으면 과금된다.

---

## 3. 합류(join) 방법

GitHub organization은 **초대 전용**이다. 검색이나 자기소개로 스스로 들어올 방법이 없다.

1. **org owner가 초대한다**: `skax-ca` → People → Invite member → username 또는 이메일
2. 초대받은 사람이 이메일의 링크를 클릭해 수락한다(7일 내. 미수락 시 초대 만료)
3. Team(`iac`)에 추가한다: 초대 시점에 지정하거나, 가입 후 People에서 추가
4. Team에 붙은 모든 저장소에 `maintain` 권한이 그대로 생긴다

---

## 4. GitHub ↔ AWS 인증: 패턴 개요

고객 프로젝트의 배포 저장소는 **장기 AWS 키를 쓰지 않는다.** GitHub Actions의
OIDC 토큰으로 AWS Role을 2단계로 assume한다.

```
GitHub Actions job
  │  OIDC 토큰 (sub = repo:<org>@<org_id>/<repo>@<repo_id>:environment:<env>)
  ▼
입구 Role   — 신뢰: OIDC. 권한: 실행 Role로 AssumeRole 하나뿐
  ▼
실행 Role   — 신뢰: 입구 Role만 (계정 루트 아님)
  ▼
실제 plan / apply
```