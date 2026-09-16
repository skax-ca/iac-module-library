# Claude Code 작업 환경

**읽는 사람**: 이 저장소와 배포·GitOps 저장소 4개를 Claude Code로 함께 다루는 사람.

이 저장소는 모듈의 SSOT이고, 배포 루트 2개(`eks-reference-infra`·`aks-reference-infra`)와
GitOps 2개(`eks-platform-gitops`·`aks-platform-gitops`)가 그 모듈을 소비한다. 한 작업이
저장소 여러 개에 걸치는 일이 잦다(태그 올림 → 배포 루트 갱신 → cluster-secret 라벨 맞춤).
이 문서는 그 작업을 **세션 하나**에서 하기 위한 환경 구성과, 다른 구성으로 바꿀 때 치러야
할 비용을 적는다.

---

## 1. 현재 구성: workspace 파일 + 허브 세션

디스크 배치는 바꾸지 않는다. 5개 저장소는 `~/born2k/ai/` 아래 형제로 그대로 둔다.

**VS Code**: `~/born2k/ai/platform.code-workspace`(저장소 밖, 커밋 대상 아님)를 연다. 한 창에
5개 폴더가 보이고 Source Control이 저장소 5개를 각각 잡는다. 통합 터미널은
`iac-module-library`에서 열린다.

```bash
code ~/born2k/ai/platform.code-workspace
```

**Claude Code**: 이 저장소에서 시작하고 나머지 4개를 `--add-dir`로 붙인다.

```bash
# ~/.zshrc
alias claude-platform='cd ~/born2k/ai/iac-module-library && \
  CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude \
  --add-dir ../eks-reference-infra ../eks-platform-gitops \
            ../aks-reference-infra ../aks-platform-gitops'
```

이 세션에서 성립하는 것:

| 항목 | 동작 |
|------|------|
| 파일 접근 | 5개 저장소 읽기·수정 |
| CLAUDE.md·`.claude/rules/` | 이 저장소 것은 시작 때. 형제 것은 환경변수 덕에 시작 때 함께 실린다 |
| 스킬 | 형제의 `.claude/skills/`(argocd-tunnel 등)도 실린다 |
| git 훅 | 저장소별 `.githooks/`가 그대로 돈다(Claude 설정이 아니라 git 설정이다) |
| auto memory | 이 저장소의 memory 디렉토리 하나에 모인다 |
| 세션 기록 | 이 저장소 `.claude/session.md` 하나가 5개 저장소 상태를 갖는다 |

`--add-dir` 대신 `permissions.additionalDirectories` 설정으로 영구화하면 형제의 CLAUDE.md·
rules·스킬이 **어느 것도 실리지 않는다**(환경변수도 무효). 팀원이 커밋한 설정이 다른 저장소의
지시문을 끌어오지 못하게 막는 정책이다. 1인 작업이라 이 보호가 필요 없어 alias를 쓴다.

형제 저장소에서 단독 세션을 열어야 하면 방향만 뒤집는다:

```bash
cd ~/born2k/ai/eks-reference-infra && \
  CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude --add-dir ../iac-module-library
```

---

## 2. 규칙 배치

세션 하나에 CLAUDE.md 여러 개가 실리므로 같은 규칙이 두 파일에 있으면 문구가 갈린 채 동시에
들어온다. 배치 원칙:

| 내용 | 자리 |
|------|------|
| 배포 루트 공통 규칙(실행 모델·게이트·모듈 계약 확인·설계 근거의 자리) | 이 저장소 `CLAUDE.md` 「배포 루트 공통」 |
| 저장소 전역 규칙(엔진·브랜치·문서·좌표 금지) | 이 저장소 `CLAUDE.md` 기존 절 |
| 그 저장소에서만 참인 값(루트 목록·변수명·리전 약어·훅 활성화) | 그 저장소 `CLAUDE.md` 값 표 |
| 그 저장소에만 있는 ⛔(예: AKS의 FIC subject) | 그 저장소 `CLAUDE.md` 별도 절 |
| 진행 상태(✅⏳, 철거 여부) | `.claude/session.md`. CLAUDE.md에 쓰지 않는다 |
| 운영 절차 | 그 저장소 `docs/hub-lifecycle.md`·`spoke-lifecycle.md`·`runbooks.md` |

형제 CLAUDE.md는 머리말 한 문장으로 이 저장소를 가리키고 값만 갖는다. import(`@../...`)는
쓰지 않는다. 허브 세션에서는 같은 내용이 두 번 실리고, 단독 세션에서는 외부 import 승인이
필요하다.

`.claude/session.md`는 이 저장소 것 하나만 둔다. 형제 저장소의 session.md는 세션 시작·종료
스킬이 읽지 않아 낡은 채 남는다. 상태는 `## 저장소 상태` 표(저장소·브랜치·미커밋·한 줄 상태)로,
할 일은 `[repo]` 접두어로 구분한다.

---

## 3. 전환 후보: 부모 디렉토리

허브 세션 방식이 유지되면 5개 저장소를 부모 디렉토리 하나로 옮기는 구성으로 바꿀 수 있다.

```
~/born2k/ai/platform/
├── CLAUDE.md            # 한 줄: @iac-module-library/CLAUDE.md
├── .claude/session.md
├── iac-module-library/
├── eks-reference-infra/
├── eks-platform-gitops/
├── aks-reference-infra/
└── aks-platform-gitops/
```

`platform/`을 VS Code로 열고 거기서 `claude`를 실행한다. VS Code는 기본값
(`git.autoRepositoryDetection: true`, 스캔 깊이 1)으로 하위 저장소를 인식한다.

현재 구성과 다른 점:

| 항목 | 현재(`--add-dir`) | 부모 디렉토리 |
|------|------------------|--------------|
| 형제 CLAUDE.md 로드 | 시작 때 전부 | **그 디렉토리 파일을 읽을 때**. EKS 작업 중 AKS 규칙이 안 들어온다 |
| 이 저장소 CLAUDE.md 로드 | 시작 때 | 하위라서 지연 로드. `platform/CLAUDE.md`의 import가 시작 때 실리게 한다(작업 디렉토리 안이라 승인 없음) |
| alias·환경변수 | 필요 | 불필요 |
| session.md 자리 | 이 저장소 | `platform/.claude/` |
| auto memory 키 | 이 저장소 경로 | `platform/`(git 저장소가 아니면 그 경로, 저장소면 그 저장소) |

전환 전에 끝내야 하는 것:

1. **memory·세션 이력 이전.** 키가 저장소 경로에서 나오므로 이 저장소를 옮기면
   `~/.claude/projects/-Users-a07326-born2k-ai-iac-module-library/`가 고아가 된다. 새 경로
   이름으로 디렉토리를 옮긴다. `--resume` 이력도 같은 키다.
2. **`platform/`의 git 여부 결정.** session.md를 버전관리하려면 `platform/`을 CLAUDE.md·
   session.md·workspace 파일만 갖는 메타 저장소로 만들고 하위 5개를 `.gitignore`에 넣는다.
3. **`.claude/rules/terraform.md` 적용 범위 실측.** 이 저장소 rules는 하위 rules가 되어 지연
   로드된다. `**/*.tf` 스코프가 형제 저장소의 `.tf`에도 걸리는지 문서에 없다. 걸리면 모듈
   작성 규칙이 배포 루트 코드에 적용되는 것이라 내용을 다시 봐야 한다.
4. 스킬 `.state/` 파일(argocd-tunnel)에 절대 경로가 있는지 확인한다.

---

## 4. 하지 않는 것

| 안 | 이유 |
|----|------|
| 5개를 모노레포로 합친다 | Claude Code 지원은 가장 좋지만 모듈을 git 태그로 소싱하는 설계와 `docs/decisions.md`를 뒤집는다. 도구 편의로 아키텍처를 바꾸지 않는다 |
| 공통 규칙을 `~/.claude/rules/`에 둔다 | 이 5개가 아니라 이 Mac의 모든 프로젝트에 실린다 |
| `~/born2k/ai/`에 CLAUDE.md를 둔다 | 상위 CLAUDE.md는 하위 전부에 상속된다. 무관한 프로젝트 20여 개에 실린다 |
| 형제 `.claude/rules/`에 이 저장소 rules를 심볼릭 링크한다 | 작업 디렉토리 밖 대상은 외부 import로 취급되어 승인이 필요하고 `paths` 없는 규칙만 실린다. 허브 세션에서는 이 저장소 rules가 이미 실려 이득이 없다 |
| 공통 규칙을 `additionalDirectories` 설정으로 나른다 | 그 설정은 CLAUDE.md·rules·스킬을 싣지 않는다 |

**보류**: 스킬(argocd-tunnel 두 벌이 갈라져 있다)과 세션 스킬을 플러그인으로 묶어 버전을 붙이는
안. 공식 문서가 저장소 간 공유에 권하는 방식이지만 플러그인이 rules까지 나르는지는 확인하지
않았다. 스킬 분기가 문제가 될 때 다시 본다.

---

## 5. 병렬 작업

EKS apply가 도는 동안 AKS를 고쳐야 하면 세션 하나로는 막힌다. 두 번째 세션을 따로 띄우고
결정("aks-cluster 태그 올림, hub도 맞춰야 함")은 세션 간 메시징으로 넘긴다. 같은 Mac이면
설정 없이 동작한다.

---

## 참조

- https://code.claude.com/docs/en/large-codebases.md : 시작 위치별 파일 접근, `--add-dir`와 `additionalDirectories`의 로드 정책 표
- https://code.claude.com/docs/en/memory.md : CLAUDE.md 로드 순서, 하위 디렉토리 지연 로드, import·외부 import, memory 저장 위치
- https://code.claude.com/docs/en/cli-reference.md : `--add-dir`
- https://code.claude.com/docs/en/cross-session-messaging.md
- https://code.claude.com/docs/en/best-practices.md : CLAUDE.md 길이, 병렬 세션
- https://code.claude.com/docs/en/settings.md : `additionalDirectories`는 폴더 trust 이후 적용
