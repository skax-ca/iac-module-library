# 규약

**읽는 사람**: 이 저장소에 코드를 쓰거나, 모듈을 소비하는 사람.

---

## 1. 엔진

명령은 `terraform`이 아니라 **`tofu`**다. 로컬 · CI · 문서 · lock 전부 하나로 일원화한다.

Terraform 호환성은 **부산물**이다. 보장하지 않지만 이유 없이 깨뜨리지도 않는다.
OpenTofu 고유 기능(`encryption` 블록 · `.tofu` 확장자 · `language {}`)을 쓸 때는 설계에 이유를 남긴다.

OpenTofu 채택 근거는 [`decisions.md`](decisions.md)가 소유한다.

---

## 2. 네이밍과 태깅

### 리소스 이름 포맷

```
(리소스약어)-(workload)-(env)-(리전코드)-(purpose)-(일련번호)

vpc-demo-prd-an2-main       # AWS: Name 태그에 실린다
eks-demo-prd-an2-main-01
sgr-demo-prd-an2-web-01
vnet-demo-prd-krc-main      # Azure: name 인자에 실린다
```

**이 조합이 실리는 자리는 provider마다 다르다.** AWS는 `Name` 태그로, Azure는 `name` 인자로
실린다(Azure 서브넷처럼 태그 자체를 지원하지 않는 리소스가 있어 태그로 통일할 수 없다).
리소스 그룹·구독에 스코프된 리소스에서는 조합 방식과 구성 요소가 클라우드와 무관하게 같다.
**부모 리소스에 스코프된 자식 리소스는 예외이며 아래 provider별 절이 소유한다**(Azure 강제
방식 6번).

| 구성 요소 | 값 |
|-----------|-----|
| 리소스 약어 | [AWS](naming/abbreviations/aws.md) · [Azure](naming/abbreviations/azure.md)(**SSOT**, 클라우드마다 한 파일) |
| workload | 프로젝트별 입력 변수. 이 저장소가 고정하지 않는다 |
| env | `prd` / `stg` / `dev` |
| 리전코드 | `an2`(ap-northeast-2) · `ue1`(us-east-1) · `krc`(koreacentral) |
| purpose | `web` · `db` · `main` · `worker` (소문자·하이픈) |
| 일련번호 | `01` · `20260415` · `policy` (선택) |

### 공통 강제 방식

클라우드와 무관하게 성립하는 규칙이다. 거버넌스 태그를 **어떤 수단으로** 주입하는지는
provider마다 다르므로 아래 provider별 절이 소유한다.

1. **이름은 모듈이 조합한다.** 소비자는 `naming` 객체만 넘긴다. 약어를 직접 쓰지 않는다.
2. **약어가 없으면 만들지 말고 등재한다.** 거버넌스 리뷰 후 카탈로그에 추가하고 쓴다
   (등재 기준은 카탈로그의 신규 약어 등재 규칙:
   [AWS](naming/abbreviations/aws.md) · [Azure](naming/abbreviations/azure.md)).
   카탈로그는 클라우드마다 한 파일이고, 약어 고유성은 그 파일 안에서만 판정한다.
3. **모든 리소스에 태그를 단다.** 자동 주입 수단이 닿지 않는 리소스도 예외가 아니다.
   어디가 닿지 않는 자리인지는 provider별 절에 적는다.
4. **이름 assertion을 계약 테스트에 넣는다.** plan 단계에서 규약 위반을 잡는다.
5. **재사용 자산의 요건**: workload code · 계정/구독 ID · 리전을 **하드코딩하지 않는다.**
   고객사 고유값이 모듈에 남으면 재사용이 아니다.

### AWS 강제 방식

1. **거버넌스 태그는 `default_tags`로.** 배포 루트의 provider에 설정한다. 개별 리소스에 반복하지 않는다.
2. **제약 리소스 주의**: S3(전역 고유 + DNS) · ALB/TG(32자 이하) · IAM/SG(이름이 곧 식별자).
3. **`default_tags`가 닿지 않는 묵시적 리소스도 태그 대상이다.**
   `default_tags`는 provider가 **`resource` 블록으로 직접 만드는** 리소스에만 붙는다. AWS가
   다른 리소스의 부산물로 자동 생성하는 객체(TGW의 기본 연결 라우트테이블, VPC의 기본
   라우트테이블·기본 보안그룹 등)는 그 생성 API 호출 자체를 하지 않으므로
   `default_tags`가 낄 자리가 없다. 우선순위는 셋이다:
   1. **끌 수 있으면 끄고 명시적 리소스로 대체한다.** 예: TGW의
      `default_route_table_association`/`_propagation`을 `disable`로 두고
      `aws_ec2_transit_gateway_route_table`을 직접 만들어 연결한다. provider가 직접 만드는
      리소스라 `default_tags`가 그대로 적용된다.
   2. **끌 수 없으면(VPC의 기본 라우트테이블·기본 보안그룹처럼 항상 생성되는 것) 전용
      adoption 리소스로 입양한다.** `aws_default_route_table`·`aws_default_security_group` 등이며,
      이 역시 `resource` 블록이라 `default_tags`가 적용된다.
   3. **위 둘 다 안 될 때만(우리가 소유하지 않는 리소스, 예: RAM 으로 받기만 하는 대상)
      `aws_ec2_tag`로 리소스 ID를 직접 타겟한다.** 마지막 수단이다. 거버넌스 태그 하나당
      `aws_ec2_tag` 하나이고, `default_tags`처럼 한 번에 묶여 적용되지 않는다.

### Azure 강제 방식

1. **거버넌스 태그를 provider 한 곳에서 주입할 수 없다. 모듈이 리소스마다 `tags`로 넘긴다.**
   azurerm provider 블록에는 `default_tags`에 대응하는 인자가 없다
   ([Argument Reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)의
   인자 목록에 태그 항목이 없다). 따라서 AWS 1번과 같은 "배포 루트에 한 번" 경로가 Azure에는 없고,
   공통 3번("모든 리소스에 태그를 단다")은 모듈의 명시적 연동으로만 달성된다.
2. **리소스는 리소스 그룹·구독의 태그를 상속하지 않는다.**
   Azure는 *"Resources don't inherit the tags you apply to a resource group or a subscription"* 이라고
   명시한다([Use tags to organize your Azure
   resources](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tag-resources)).
   상속은 Azure Policy를 할당해야 얻는 별도 기능이며, 내장 정책 `Inherit a tag from the resource group`
   (효과 `modify`)이 그 역할을 한다([Policy definitions for tagging
   resources](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tag-policies)).
   태그 상속은 플랫폼(Azure Policy) 구성이라 이 저장소의 모듈이 제공하지 않는다.
3. **태그 자체의 한도**(위 「Use tags」 문서): 리소스당 최대 50쌍, 태그 이름 512자·값 256자
   (스토리지 계정은 이름 128자). 일부 리소스(Automation · CDN · DNS 영역 등)는 15개까지만.
   태그 이름에 `< > % & \ ? /` 를 쓸 수 없고, 태그를 아예 지원하지 않는 리소스 타입이 있다.
4. **조합한 이름은 `name` 인자에 넣는다. `Name` 태그는 달지 않는다.**
   거버넌스 태그는 별개이고 위 1번대로 리소스마다 `tags`로 여전히 연동한다. 이름이 실리는
   자리(`name` 인자)와 거버넌스 태그(`tags`)는 서로 다른 관심사다.
5. **제약 리소스**([Naming rules and restrictions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules)):

   | 리소스 | 스코프 | 길이 |
   |---|---|---|
   | `virtualNetworks` | 리소스 그룹 | 2~64 |
   | `virtualNetworks/subnets` | 부모 vnet | 1~80 |
   | `networkSecurityGroups` · `routeTables` · `natGateways` · `publicIPAddresses` | 리소스 그룹 | 1~80 |

   ⚠️ 전역 고유 이름 제약은 이 집합에 나타나지 않는다. 마주치는 지점은 스토리지 계정이나
   Flow Logs를 여는 순간이다.
6. **하위 스코프 리소스는 부모가 이미 나르는 토큰을 반복하지 않는다.** 위 공통 강제 방식
   1번("이름은 모듈이 조합한다")의 예외다. AKS 노드 풀
   (`azurerm_kubernetes_cluster_node_pool`, 스코프가 클러스터 리소스 그룹이 아니라
   **managed cluster**)이 첫 사례다. 클러스터 이름에 이미 `workload`·`env`·`리전코드`
   토큰이 들어 있어, 노드 풀 이름에서 그 토큰들은 정보를 나르지 않는다.

   | 항목 | 내용 |
   |---|---|
   | 이름 형태 | 시스템 노드 풀 `npsystem` 고정, 사용자 노드 풀 `np<그룹키>`. 하이픈 없음 |
   | 물리 제약 | 1~12자(Linux) · 소문자+숫자만 · 숫자로 시작 불가([Naming rules and restrictions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules)의 `managedClusters/agentPools` 행) |
   | 길이 예산 | 그룹 키는 **8자 이하**(`np` + 8 = 10자). `temporary_name_for_rotation`(속성 변경 시 순환에 쓰는 임시 노드 풀 이름)이 같은 12자 한도를 쓰므로, 그 이름이 들어갈 자리를 남겨 둔다 |
   | 출처 | Microsoft CAF 권장 약어 `npsystem`·`np`. ⚠️ 약어 카탈로그(`azure.md`)에는 등재하지 않는다(하이픈 금지·길이 초과가 카탈로그의 등재 규칙 4(7자 상한)와 예시 형식 검사를 동시에 위반한다) |
   | Windows | ⛔ Windows 노드 풀은 이름 한도가 6자라 위 규칙이 성립하지 않는다. 지원하지 않는다 |

7. ⚠️ **아래 한 가지는 규정하지 않는다. 실측 수단이 생기면 정한다.**
   - Azure Policy가 `modify`로 태그를 덧붙이는 환경에서 OpenTofu 상태와 어떻게 상호작용하는지
     (drift 발생 여부와 대응). 확인하지 않았으므로 값을 쓰지 않는다.

---

## 3. 버전

### 모듈 버전

**모든 모듈이 개발 단계(`0.y.z`)다.** 이 구간에서는 파괴적 변경도 마이너로 흡수하고,
소비자에게 계약 안정을 약속하지 않는다.

- *"이 변경이 마이너인가 메이저인가"* 를 **판정하지 않는다.** 전부 마이너다.
- `1.0.0`은 **모듈별로** 컷한다. 전 모듈 일괄 컷은 하지 않는다.
- 신규 모듈은 `0.1.0`에서 시작한다.
- 버전 혼재(`vpc-v0.3.0` + `workbench-v0.6.0`)는 정상이다. 컴포넌트마다 바뀌는 속도가
  다르다는 사실을 그대로 보여준다.

### 릴리스된 태그를 옮기지 않는다

예외는 **소비자가 0일 때뿐**이다. 한 번이라도 apply된 뒤에는 다음 마이너를 낸다.

### 도구·provider 핀

| 대상 | 값 | 어디서 |
|------|-----|--------|
| OpenTofu (모듈) | `>= 1.12.0` | `versions.tf` |
| OpenTofu (실행) | `1.12.5` | CI · 로컬 |
| aws provider (모듈) | `>= 6.0`(**하한만**) | `versions.tf` |
| aws provider (루트) | `~> 6.0`(상한은 루트가 통제) | `examples/` · 배포 루트 |
| azurerm provider (모듈) | `>= 5.0`(**하한만**) | `versions.tf` |
| azurerm provider (루트) | `~> 5.0`(상한은 루트가 통제) | `examples/` · 배포 루트 |
| tflint | `v0.63.1` + aws ruleset `0.48.0` + azurerm ruleset `0.32.0` | `.tflint.hcl` |
| trivy | `v0.72.0` | CI · 훅 |
| terraform-docs | `v0.24.0` | CI · 훅 |
| 커뮤니티 모듈 | **정확 핀** | `main.tf` |

**CI와 로컬 훅의 도구 버전을 일치시킨다.** 어긋나면 *"로컬은 통과했는데 CI가 막는다"* 가 생기고,
그러면 사람이 CI를 신뢰하지 않게 된다. **한쪽을 바꾸면 다른 쪽도 바꾼다.**

### lock 파일

`.terraform.lock.hcl`을 커밋한다. registry 주소가 **`registry.opentofu.org`** 인지 확인한다.
`registry.terraform.io`가 섞이면 CI 게이트 6이 막는다.

---

## 4. 모듈 소싱

호출 예시와 태그 고정 규칙(`ref=main` 금지 포함)은 [`README.md`](../README.md)의
"쓰는 법" 절이 소유한다. 이 절은 그 내용을 반복하지 않는다.

---

## 5. 코드 규약

| 규칙 | 이유 |
|------|------|
| SG rule은 **별도 리소스**(`aws_vpc_security_group_ingress_rule`) | inline은 순환과 전체 교체를 부른다. 혼용도 금지 |
| 워크스페이스 간 데이터는 **결정적 네이밍 -> `data` 조회** | `terraform_remote_state`는 state 전체 접근이다 |
| 커뮤니티 모듈은 **wrapper(facade)로 감싼다** | upstream 변수 rename을 내부에서 흡수한다 |
| 새 리소스·인자는 **문서로 확인하고 쓴다** | 추정하지 않는다 |

### facade에서 자주 틀리는 것

*"upstream이 그 기능을 지원하지 않는다"* 로 단정하기 전에, **wrapper가 그 인자를 안 넘기고 있는 것은 아닌지**
확인한다. `.terraform/modules/`의 실물 소스를 여는 것이 문서보다 빠르고 정확할 때가 많다.

### 주석

주석의 기준은 **자립**이다. 독자가 바깥을 보지 않고 읽을 수 있어야 한다.

**세 질문 중 하나에만 답한다.**

| | 질문 | 판정 |
|---|---|---|
| ❌ | 이 코드가 **무엇을** 하는가 | 코드가 이미 답한다. 쓰지 않는다 |
| ✅ | **왜 이 값·이 형태인가** | 대안을 골랐고 그 이유가 코드에 보이지 않을 때 |
| ✅ | **바꾸면 무엇이 깨지는가** | 실패가 조용하거나 apply 시점까지 지연될 때 |

**본문에 좌표를 쓰지 않는다.** 결정 식별자(`D-...`) · 문서 절 번호 · Task 번호 · 날짜 ·
*"실측했다"* · *"여기만 빠져 있었다"* 같은 사건 서술은 넣지 않는다.
언제 누가 왜 바꿨는지는 `git blame`과 커밋 메시지가 답한다.
문서 링크는 **파일 헤더 한 곳**에 문서 단위로만 둔다.

**독자로 가른다.** 같은 사실을 두 곳에 쓰지 않는다.

| 위치 | 독자 | 담는 것 |
|------|------|---------|
| `variable`/`output`의 `description` | **소비자**(모듈을 호출하는 사람) | 무엇을 넘기고, 무엇이 깨지는가 |
| `.tf` 주석 | **유지보수자**(모듈을 고치는 사람) | 왜 이렇게 파생·번역하는가 |

**경고는 두 등급뿐이다.** `⚠️` 실패가 조용하다 · `⛔` 하지 말 것(이미 시도해서 깨졌다).
다른 기호는 쓰지 않는다.

**파일 헤더는 3~6줄이다.**

```hcl
# <이 파일이 소유하는 것 한 줄>
#
# <이 파일에만 있는 비직관적 결정 1~3개, 각 한 줄>
#
# 계약: docs/module-catalog.md
```

**섹션 구분선**(`# ── 절 이름 ──`)은 **100줄 이상에 블록 5개 이상인 파일**에만 쓴다. 짧은 파일에서는 블록이 이미 눈에 구분되므로 구분선은 장식이다.

**지우기 전에**: *"이 줄이 없으면 다음 사람이 무엇을 틀리나"* 에 답한다.
답할 수 없으면 지운다. 답할 수 있으면 **짧게 다시 쓴다. 지우지 않는다.**

판정:

```bash
grep -rn "§\|D-[A-Z]\|20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" --include='*.tf' --include='*.tftest.hcl' modules examples
```

---

## 6. 검증 게이트

### 코드 변경 후 (로컬)

```
pre-commit: tofu fmt -recursive -check -> tflint --recursive -> trivy config .
pre-push (modules/ 변경 시만): tofu test
```

git hook으로 강제한다. clone마다 1회 활성화:

```bash
git config core.hooksPath .githooks
```

`--no-verify` 우회는 긴급 시에만 쓰고 **사유를 커밋 메시지에 남긴다.**

> `tflint`의 `terraform_unused_declarations`는 선언만 하고 쓰지 않은 변수를 잡는다.
> 따라서 `variables.tf`만 있고 소비하는 `main.tf`가 없는 상태는 **커밋할 수 없다.**
> 커밋 단위는 "변수가 전부 소비되는 시점"이다.

### CI (`.github/workflows/verify.yml`)

게이트 7개를 돈다:

| # | 게이트 |
|---|--------|
| 1 | `tofu fmt` |
| 2 | `tflint --recursive` |
| 3 | `trivy config` |
| 4 | modules: `init -lockfile=readonly` + `validate` + `test`(**테스트 없는 모듈은 실패**) |
| 5 | examples: `init -lockfile=readonly` + `validate` |
| 6 | lock registry 검사 |
| 7 | terraform-docs drift 검사 |

**계약 테스트가 없는 모듈은 릴리스하지 않는다.** 게이트 4가 강제한다.

이 저장소는 배포하지 않으므로 **apply 워크플로가 없다.**

> CI는 읽기 전용이라 `cancel-in-progress: true`다.
> **배포 루트의 apply는 반대여야 한다.** apply 중단은 state 잠금과 부분 적용을 남긴다.

### trivy 예외

`.trivyignore`로만 처리한다. 항목마다 사유와 백로그 링크를 남긴다.

---

## 7. 브랜치와 PR

| 변경 대상 | 경로 |
|-----------|------|
| `.tf` · `.github/workflows/` | **브랜치 -> PR** |
| 문서 | **`main` 직접 커밋** |

기준은 *"CI가 머지 전에 막아야 하는가"* 하나다. 문서에는 main을 깨뜨릴 산출물이 없다.

**문서 전용 변경에 PR을 쓰지 않는다.** 사실상 1인 작업이라 리뷰가 형식이 되고,
커밋 메시지를 길게 쓰는 문화라 PR 본문도 중복이다.

문서를 쓰거나 고칠 때 지킬 형식·문체 규칙은 [`writing-style.md`](writing-style.md)가 소유한다.
