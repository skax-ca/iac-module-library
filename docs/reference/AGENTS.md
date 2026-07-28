<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-29 | Updated: 2026-07-29 -->

# reference

## Purpose
바뀌지 않는 참조 자료 두 종류: **약어 SSOT**(규약의 기준)와 **PoC 실증 기록**(외부 출처의 증거).
성격이 정반대다 — 전자는 이 repo가 계속 관리하고, 후자는 **동결된 스냅샷**이다.

## Key Files
| File | Description |
|------|-------------|
| `aws-naming-abbreviations.md` | 리소스 타입 표준 약어 **309개**, 8개 카테고리. `Name` 태그 조합의 SSOT. 예시 워크로드 코드는 가상값 `acme` |
| `poc-findings.md` | PoC 실증 기록 — EKS/노드·IAM/OIDC·관리형 ArgoCD·네트워크·도구·teardown 6개 절. 항목마다 ✅/⚠️/🔒 유효성 표기 |

## For AI Agents

### Working In This Directory

**`aws-naming-abbreviations.md`**
- ⛔ **약어를 임의로 만들지 않는다.** 카탈로그에 없는 리소스는 거버넌스 리뷰로 **추가한 뒤** 사용한다.
- 예시의 `acme`는 **자리표시자**다. 실제 워크로드 코드는 소비 프로젝트가 정의한다 —
  이 카탈로그에 특정 프로젝트 코드를 등재하지 않는다.
- 약어 추가 시 카테고리 개수와 총계(현재 309)를 함께 갱신한다.

**`poc-findings.md`**
- ⛔ **갱신하지 않는다.** 외부 repo(동결)에서 얻은 관찰의 스냅샷이므로, 여기에 새 발견을 덧붙이면
  출처가 섞여 "무엇이 어디서 검증됐는지"를 잃는다. 새 실증은 **해당 설계 문서**에 기록한다.
- 유효성 표기의 의미:
  - ✅ 도구 무관(AWS 사실) — 그대로 쓸 수 있다
  - ⚠️ 재확인 필요 — 스택 전환/아키텍처 재선택의 영향을 받는다. 해당 모듈 구현 시 **재실증**하고
    그 결과를 설계 문서에 남긴다
  - 🔒 TFC 전용 — 이 스택에 해당 없음. 참고만
- 설계 문서가 이 파일을 **참조**하는 것은 권장, **내용을 복사해 오는 것은 금지**다.
  복사하는 순간 그 문서가 "우리가 실증했다"고 주장하게 된다.

### Testing Requirements
없음(참조 자료). 다만 약어 카탈로그는 모듈의 `Name` 태그 assertion을 통해 **간접적으로 검증**된다 —
모듈이 카탈로그에 없는 약어를 쓰면 리뷰에서 걸러야 한다.

### Common Patterns
- 카탈로그 표 형식: `L0(서비스) | L2(리소스) | 약어 | Name 예시`.
- findings 표 형식: `# | 관찰 | 유효성`. 관찰은 **한 문장으로 결론부터**.

## Dependencies

### Internal
- `../architecture/02-naming-tagging-and-pinning.md` — 약어를 쓰는 포맷·강제 방식을 정의(상호 참조).
- `../design/*` · `../architecture/*` — findings를 참조하는 쪽.

### External
- `terraform-enterprise-poc` @ `76285f7` — findings의 출처. 원본 문서는 그 repo의
  `docs/design/*`·`docs/runbooks/*`에 흩어져 있다.

<!-- MANUAL: -->
