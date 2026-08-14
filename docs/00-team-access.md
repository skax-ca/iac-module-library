# 00. 팀 온보딩 — 접근과 구조

**읽는 사람**: 새로 합류해 이 조직에 접근 권한부터 얻어야 하는 사람.

---

## 1. 이 문서 집합이 무엇인가 — 레퍼런스이지 실제 배포가 아니다

이 저장소(`iac-module-library`)는 **모듈과 설계의 SSOT**다. `.tf` 코드와 `docs/`의 나머지 문서는
고객사 프로젝트가 인프라를 세울 때 따르는 **패턴**을 담을 뿐, 우리 팀이 실제로 운영 중인
계정·저장소 그 자체가 아니다. 이 저장소는 배포하지 않는다.

실제 배포는 프로젝트마다 새로 만드는 `<project>-infra` 저장소가 한다 — 이 저장소의 모듈을
git tag로 소싱해서. 레퍼런스 구현은 `iac-reference-infra`에 있다.

전체 그림은 [`01-architecture.md`](01-architecture.md), repo 간 역할 분담은 `CLAUDE.md`를 본다.

---

## 2. GitHub org 구조

| 무엇 | 값 |
|---|---|
| Organization | `skax-ca` (무료 플랜) |
| Team | `iac` (slug `iac`, privacy **closed**) |
| 이 저장소의 Team 내 권한 | `maintain` |

**"프로젝트 묶음"이라는 별도 계층은 GitHub에 없다.** org > 프로젝트 > repo처럼 중첩된 구조는
지원되지 않는다 — 관련 저장소를 묶는 실체는 **Team + 이름 프리픽스**(`iac-`)뿐이다.

새 IaC 관련 저장소를 만들면 아래로 Team에 붙인다:

```bash
gh api --method PUT orgs/skax-ca/teams/iac/repos/skax-ca/<repo> -f permission='maintain'
```

**무료 플랜의 제약**: private repo에 required reviewers를 걸 수 없다. 승인 게이트가 필요하면
Team 플랜 이상이 필요하다([`08-decisions.md`](08-decisions.md)의 "승인 게이트는 GitHub Team 이상
요구" 전제).

---

## 3. 합류(join) 방법

GitHub organization은 **초대 전용**이다 — 검색이나 자기소개로 스스로 들어올 방법이 없다.

> "org를 public으로 전환"하는 기능은 없다. 있는 것은 **멤버십 공개 여부**뿐이다 — 각 멤버가
> 자기 프로필에 소속을 보여줄지 말지 정하는 화면 표시 설정이고, 접근 권한과는 무관하다.

1. **org owner가 초대한다** — `skax-ca` → People → Invite member → username 또는 이메일
2. 초대받은 사람이 이메일의 링크를 클릭해 수락한다(7일 내. 미수락 시 초대 만료)
3. Team(`iac`)에 추가한다 — 초대 시점에 지정하거나, 가입 후 People에서 추가
4. Team에 붙은 모든 저장소에 `maintain` 권한이 그대로 생긴다

---

## 4. GitHub ↔ AWS 인증 — 패턴 개요

고객 프로젝트의 배포 저장소(`<project>-infra`)는 **장기 AWS 키를 쓰지 않는다.** GitHub Actions의
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

**이건 프로젝트마다 반복되는 패턴이지, 이 저장소가 소유한 실제 AWS 계정이 있다는 뜻이 아니다**
(이 저장소는 배포하지 않는다 — [`01-architecture.md`](01-architecture.md)).

| 알고 싶은 것 | 어디 |
|---|---|
| 부트스트랩 절차(OIDC provider·두 Role 생성) | [`03-new-project.md`](03-new-project.md) |
| 실행 단계 규칙(plan artifact·승인 게이트·동시 실행) | `CLAUDE.md` "실행 기반" · [`06-conventions.md`](06-conventions.md) |

⚠️ 2026-07-15 이후 생성된 저장소는 `sub` claim이 이름이 아니라 **숫자 org/repo ID**를 쓴다 —
신뢰 정책을 쓰기 전에 실제 토큰의 `sub`를 확인한다. 추정하지 않는다.

---

## 다음

- 전체 그림 → [`01-architecture.md`](01-architecture.md)
- 새 프로젝트 착수 → [`03-new-project.md`](03-new-project.md)
