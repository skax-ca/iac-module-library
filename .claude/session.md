# Session — iac-module-library (+ 배포·GitOps repo 4개)

이 파일 하나가 5개 저장소의 세션 기억이다. 세션은 이 저장소에서 열고 나머지 4개를
`--add-dir`로 붙인다(`.local/claude-workspace.md`, alias `claude-code`). 형제 저장소에는
session.md를 두지 않는다. 표의 구조와 갱신 절차는 `.claude/rules/session.md`가 정한다.

## 저장소 상태
| repo | git | 상태 |
|------|-----|------|
| eks-reference-infra | main = origin | hub·dev 전부 destroy. main push plan은 `hub/tgw`만 성공(정상. 나머지 4개는 `no matching RAM Resource Share found`로 실패하며, 철거 상태의 `data` 조회 실패라 코드 문제가 아니다). 변수 34개 전부 `nullable = false`. `scripts/argocd-seed.sh`는 없다(GitOps 저장소가 소유). `scripts/README.md`는 GitHub App 발급·private key 배달 절차만 갖는다 |
| eks-platform-gitops | main = origin | dev cluster-secret 삭제 상태(라벨 먼저 뗀 뒤 파일 삭제). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. 주석 규칙 게이트(`scripts/validate-comment-conventions.py` + `.githooks/pre-commit`) 설치됨, 위반 0건. clone마다 `git config core.hooksPath .githooks` 필요 |
| aks-reference-infra | main = origin | 전부 철거 상태. 원본 이식 항목(runbooks·게이트·teardown-verify) 완료. 변수 48건 `nullable = false` 적용 완료 |
| aks-platform-gitops | main = origin | dev 스포크 철거 2단계 완료(라벨 제거 → cluster-secret 삭제). `bootstrap/argocd-seed.sh`의 SSOT가 이 저장소다. ⚠️ 주석 규칙 게이트 미설치(위반 41건 측정됨) |

## 지난 세션 (2026-09-16)

aks 배포 루트 변수 48건에 `nullable = false`를 적용해 두 배포 루트를 같은 계약 위에 올렸다
(PR #50, `df7ae8b`). `default = null` 예외는 0건이었고, `ssh_ingress_cidrs` 두 곳이 `validation`
블록을 가져 `type` 줄 뒤를 앵커로 잡아 회피했다. main plan 실패 5건은 철거 상태의 `data` 조회
실패이고 `must not be null`은 0건이다.

Kyverno 엔진·정책의 짝 규칙을 차트 번호에서 **마이너 라인**으로 바꿨다(`a74a5b8` + GitOps 2곳).
helm index 전수로 3.x 정식은 kyverno 59개·kyverno-policies 51개, 정책 단독 0개, 엔진 단독 8개다.
8개는 전부 유지보수 라인(3.0·3.2·3.3·3.4)의 꼬리라 옛 규칙은 그 라인에 동결된 채 보안 백포트가
오면 그것을 막는다. 두 차트에 helm `dependencies`가 없고 차트 README가 요구하는 것은 app 버전
하한이다. EKS에 없던 3.9 `policyType` 경고(`ClusterPolicy` → `ValidatingPolicy`)도 채웠다.

`writing-style.md` 2절이 작업에 실리지 않던 원인 셋을 닫았다(PR #55, `c04efe9`). 진입점 부재가
핵심이었다: 이 문서를 가리키는 곳이 전부 자동 로드되지 않는 파일이었고 `CLAUDE.md`에 참조가
없었다. 1절(구조)은 저장소 문서, 2절(문체)은 산문 전부로 범위를 갈랐다. em-dash 금지 규칙은
넓혔다가 **전면 폐기**했다(vendored 파일 훼손·절 제목 참조 파손·358줄 중 25줄 콜론 중복).

`argocd-seed.sh`의 vendoring 구조를 걷어내고 SSOT를 각 GitOps 저장소로 옮겼다(4개 저장소).
원본을 아무도 실행하지 않았고(workbench는 GitOps 저장소만 클론한다), 드리프트 검사를 사람이
기억해야 해서 문체 정리 한 번에 갈렸다. AKS 사본은 삭제된 `iac-module-library/scripts/`를
가리키는 끊긴 포인터였다. `eks-reference-infra`의 중복 문서 100줄을 걷어내고(`b7241c9`),
`hub-lifecycle.md`가 적던 잘못된 실행 경로도 고쳤다.

## 다음 할 일
- [ ] [aks-gitops] 주석 규칙 게이트를 이식한다 — `eks-platform-gitops`의
      `scripts/validate-comment-conventions.py` + `.githooks/pre-commit`을 복사하고 적용 범위를
      이 저장소 레이아웃에 맞춘다. 현재 위반 41건(전부 좌표)을 함께 정리해야 게이트가 깨끗이 선다.
      ⚠️ `.yaml`을 새로 만들지 않는다(root App이 `path: .` + `recurse: true`라 흡수한다)
- [ ] [*-ref] `.sh` 셸 문법 게이트 검토 — 주석 규칙은 게이트가 보지만 문법은 아무도 안 본다.
      배포 워크플로에 `bash -n`(가능하면 `shellcheck`) 스텝 추가.
      `eks-reference-infra` `scripts/README.md` 「열린 항목」이 이 건을 갖는다
- [ ] [*-gitops] EKS·AKS 재구축 후 cluster Secret 등록 — ⚠️ teardown이 매칭 라벨을 **먼저 떼고**
      파일을 지웠다. git 이력에서 되살리면 라벨이 빠진 껍데기이고 그 상태로는 Application이 하나도
      안 생긴다. EKS dev는 `environment`·`tier: nonprd`·`vpcName`·`karpenterNodeRole`,
      AKS dev는 `environment`·`tier: nonprd`·`addon-karpenter`가 필요하다
- [ ] [eks-gitops] 재구축 후 첫 sync에서 baseline addon 4개(ALBC·karpenter·cluster-autoscaler·
      keda)가 OutOfSync로 뜬다 — 좌표 정리가 `helm: values: |` 블록 안 주석을 건드려
      `spec.source.helm.values` 문자열이 바뀌었다. 렌더 결과는 같으니 한 번 sync하면 끝이다
- [ ] [*-gitops] nonprd 클러스터가 생기면 `*-nonprd` ApplicationSet 팬아웃 실측 — 지금은 의도된 빈 슬롯이다
- [ ] [*-gitops] 실제 승격 한 번 돌려보기(nonprd 올림 → 검증 → prd 올림). Kyverno는 엔진·정책 값 4개를
      짝으로 움직여야 한다. ⚠️ 3.9 라인으로 넘길 때는 `policyType` 결정을 먼저 답한다
      (②에 `policyType=ClusterPolicy` 명시 vs whitelist·③를 함께 이동)
- [ ] [module] 다음 `workbench`·`aks-workbench` 태그 메시지에 인스턴스/VM 교체를 적는다 — `6e34dec`가
      `.tftpl` 주석을 바꿔 렌더링 결과가 달라졌다(`user_data_replace_on_change`·`custom_data` ForceNew)
- [ ] [local] 약 한 달 뒤 `~/archive/`(에이전트·스킬·hook·`.omc` 백업 3개) 삭제
