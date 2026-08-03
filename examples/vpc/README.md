# examples/vpc — minimal

`modules/vpc`의 **핵심 경로를 최소 비용으로** 보이는 예제다. 소비자가 복사해 시작하는 지점이기도 하다.
public 그룹(`pub-uniq`)이 IGW와 NAT를 호스팅하고, private 그룹(`app-uniq`)이 그 NAT로 아웃바운드한다.
`single_nat_gateway = true`로 NAT를 1개만 두어 예제 비용을 낮췄다 — prd는 `false`(AZ별 NAT)가 기본값이다.

이 예제가 보여주는 것은 **계약의 형태**다. 그룹 키(`pub-uniq`·`app-uniq`)가 곧 `Name` 태그의 purpose
토큰이 되고(`snet-acme-dev-an2-pub-uniq-a`), 출력 map의 키로 되돌아온다(`outputs.tf`의 `app_subnet_ids`).
거버넌스 태그는 모듈이 아니라 **루트의 `default_tags`**가 붙인다(`providers.tf`) — 이 분리가 규약의 핵심이다.

## 실행

```bash
tofu -chdir=examples/vpc init -backend=false
tofu -chdir=examples/vpc validate
```

> ⚠️ **`validate`는 계약 위반을 잡지 못한다.** 교차변수 `validation`과 `precondition`은 `plan` 시점에만
> 평가되므로, 계약 검증은 `modules/vpc/tests/plan.tftest.hcl`이 담당한다(`tofu -chdir=modules/vpc test`).
> 이 예제의 역할은 "**쓰는 법**이 검증됐다"는 것까지다.

## 소비 프로젝트와 다른 점

| | 이 예제 | 소비 프로젝트(`<project>-infra`) |
|---|---|---|
| 소싱 | 상대경로 `../../modules/vpc` | git tag `?ref=vpc-v1.2.0` (**현행 릴리스**) |
| backend | 없음(`-backend=false`) | S3 + `use_lockfile = true` |
| 자격증명 | 없음(plan/apply 안 함) | GitHub OIDC → 입구 Role → 실행 Role |
| 워크로드 코드 | 가상값 `acme` | 실제 프로젝트 코드 |

⚠️ **핀은 착수 시점의 현행 릴리스로 건다** — `git tag -l 'vpc-v*'`로 확인한다. 이 표의 태그가
낡은 채 복사되면 그대로 굳는데, 실패 방식이 나쁘다: `vpc-v1.1.0`은 Flow Logs confused deputy
방어(보안 수정)라 **그것이 빠진 채로도 `apply`는 성공한다.** 릴리스 이력은 각 태그의 annotated
메시지(`git show vpc-v1.2.0`)와 [`docs/design/10-vpc-module.md §3`](../../docs/design/10-vpc-module.md)에 있다.
