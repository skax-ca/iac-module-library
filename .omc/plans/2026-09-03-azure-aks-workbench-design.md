# Azure `aks-workbench` 모듈 설계 (RALPLAN-DR)

**상태**: **v6(최종) — pending approval.** RALPLAN-DR 최대 반복(5회) 도달. 5차 Critic 판정은 ITERATE(REJECT 아님, "6차 설계 라운드가 아니라 문서 보완 1회로 닫힌다"고 명시) — 그 보완 6건(CRITICAL 1·MAJOR 5)을 전부 반영해 v6으로 제출한다. 사용자 승인 대기.
**대응 모듈**: `modules/aws/workbench` (AWS)
**변경 이력**:
v1 → Architect+Critic 1차 리뷰(REJECT: system-assigned 신원이 `docs/decisions.md:121-122`와 충돌, `tls_private_key`가 state에 평문 자격증명 상재, 베이스 이미지 축 부재, NSG 소유권 미정, kill switch 누락 등) → v2
v2 → Architect 2차 리뷰(조건부 승인) + Critic 2차 리뷰(REJECT — **"기본 인바운드 0" 주장 자체가 거짓**: `AllowVNetInBound`가 VNet·피어·온프레미스 전체 허용, Run Command 4,096B/90분/비대화형/취소불가) → v3
v3 → Architect 3차 리뷰(구현 착수 불가 — CRITICAL: ①`az login --identity --resource-id`는 az CLI **2.72.0 이상**에서만 지원되는데 미결 A의 예시 핀이 그 미만이라 자기 예시로 부트스트랩이 깨짐 ②이미지 축이 결정만 되고 §2에 변수로 착지하지 않아 §5 assertion 9의 대상이 없음. Antithesis: "진짜 인바운드 0"이 성립하는 유일한 구성(`ssh_ingress_cidrs=[]`)이 정확히 ADR이 "일상 운영 불가"라 선언한 구성이라 헤드라인 안전성 주장이 아무도 안 쓸 설정에서만 참) → v4

---

## 0. 목적

private AKS 클러스터의 운영 지점(kubectl·helm·argocd·az CLI·kubelogin이 설치된 지속적 작업대). AWS `workbench` 모듈("private 클러스터 운영 지점, SSM 전용, 인바운드 0")의 Azure 대응.

**⚠️ v3에서 정정하는 근본 프레이밍(Critic C-3)**: AWS의 SSM Session Manager는 "완전한 대화형 + 진짜 인바운드 0"을 동시에 주는 유일한 수단이라 workbench의 일상 운영 경로 그 자체였다. Azure에는 이 조합을 주는 서비스가 없다 — Run Command는 인바운드 0이지만 출력 4,096바이트·90분·비대화형·취소불가라는 확정된 제약(공식 문서) 때문에 일상 운영(kubectl 진단·helm install·argocd 대화형 세션)을 감당 못 한다. **이 모듈의 일상 운영 경로는 SSH(§2.1)이고, Run Command는 "SSH 경로 자체가 없는 상황의 브레이크글래스 진단 수단"이다** — v1·v2가 서술한 "기본은 Run Command, SSH는 예외"라는 위계는 뒤집혔다.

---

## 1. RALPLAN-DR 요약

### Principles (3~5)

1. **AWS workbench와 같은 경계 원칙을 유지한다** — 모듈은 "리소스가 뭘 하는가"만 정의하고 "누가 접근하는가"는 정의하지 않는다.
2. **"닫혀 있음"은 명시적 Deny로만 만들어진다는 것을 인정하고 설계한다** — v2까지는 "규칙을 안 만들면 닫힌다"고 암묵 가정했다(AWS SG의 default-deny를 무의식적으로 이식). Azure NSG는 **기본이 열림**(`AllowVNetInBound`/`AllowInternetOutBound`)이므로, 이 모듈이 "닫혀 있다"고 주장하려면 **그 기본 규칙을 실제로 덮는 Deny 규칙을 만들어야 한다.** v3 §2.5에서 이를 반영한다.
3. **플랫폼이 강제하는 것과 우리가 선택한 것을 구분한다** — (v2에서 정정 완료, 유지) `admin_password`/`admin_ssh_key` 중 하나가 플랫폼 강제, SSH 키 방식은 우리 선택.
4. **role assignment(`Microsoft.Authorization/roleAssignments/write`)는 이 모듈이 만들지 않는다** — (v2에서 정정 완료, 유지) dual identity + `identity_id`/`identity_client_id` 입력.
5. **미결 사항은 "구현 착수 시 확인"으로 미루지 않는다 — 검토 시점에 확인 가능한 것은 지금 확인한다**(v3 신규 원칙, Architect steelman 반영: v2의 client_id 유예가 실제로는 `az login --identity --resource-id`라는 이미 조사 가능했던 공식 경로를 조사하지 않아 만든 "가짜 딜레마"였다). 입력 변수 표면(어떤 변수가 존재하는가)은 특히 구현 디테일이 아니라 설계 결정이므로 유예 대상이 아니다.

### Decision Drivers (top 3)

1. **`aks-reference-infra`가 이미 vWAN으로 hub-spoke를 구성 중** — Azure Bastion을 vWAN 허브 안에 배포 불가(공식 제약). 스포크 배치·IP 기반 연결은 네트워크 계층의 선택지로 남아 있고, 이 모듈은 `ssh_ingress_cidrs`로 그 선택과 무관하게 흡수한다.
2. **"인바운드 0"·"기본이 안전함"이라는 주장은 실제로 검증 가능해야 한다** — v3 신규 driver(Critic C-1 직접 반영). 커스텀 규칙 개수가 0이라는 것과 인바운드가 실제로 막혀 있다는 것은 Azure에서 **다른 명제**다.
3. **`aks-cluster`가 이미 확립한 신원 경계(identity_id 입력·role assignment 미생성)와의 설계 일관성** — user-assigned identity + client_id 입력까지 이 세션에서 확정한다(유예하지 않는다).

### Viable Options — 접속 모델 (실측값 반영해 재비교, Critic C-3 요구)

| | Option 1: Bastion(스포크 배치) | **Option 2: SSH(주 경로) + Run Command(브레이크글래스) — 채택** | Option 3: VNet-injected Cloud Shell | Option 4: `az aks command invoke` 전용, VM 없음 |
|---|---|---|---|---|
| 인바운드(기본, 명시 Deny 적용 시) | Bastion 서브넷에서 1개(상시) | **실제로 0**(§2.5의 Deny 규칙으로 `AllowVNetInBound` 덮음) — `ssh_ingress_cidrs` 채울 때만 그 소스에서 열림 | 0(VM 없음) | 0(VM 없음) |
| 일상 운영(대화형·무제한 출력) | 가능 | **가능(단, `ssh_ingress_cidrs`가 채워져 있을 때만)** | 불가(매 세션 컨테이너 재생성) | **불가** — 출력 4,096B 상한·90분 타임아웃·비대화형·취소불가(공식 문서 확정값) |
| SSH 경로 자체가 없을 때의 진단 수단 | 없음(Bastion 자체가 그 경로) | **Run Command**(짧은 1회성 명령·4,096B 이내 한정) | 없음 | 이것 자체가 유일한 경로 |
| 상시 비용 | Bastion SKU 시간당 과금(Standard 이상 필요, native client용) | VM 비용만(기존과 동일) | 없음 | 없음 |
| vWAN 허브 내 배치 | 불가(공식 문서) | 해당 없음 | 해당 없음 | 해당 없음 |
| argocd CLI·GitOps clone(디스크 상태 전제) | 가능 | 가능(SSH 경로가 있을 때) | 불가 | 불가 |

**Option 1 기각 아님, 흡수**: vWAN **허브 안**에 배포 불가하다는 것이 Bastion 자체의 무효를 뜻하지 않는다(공식 문서: 스포크 배치·IP 기반 연결 가능). 이 모듈은 Bastion을 특별 취급하지 않고 그 서브넷 CIDR을 `ssh_ingress_cidrs`의 한 값으로 받는다 — **네트워크 계층의 선택은 소비 레포 몫, 이 모듈은 CIDR 하나를 어디서 받든 동일하게 처리한다.**
**Option 3 기각**: "지속적인 작업대" 정체성과 근본적으로 안 맞음.
**Option 4 기각(근거 좁힘, Critic Minor-3)**: 무상태이므로 argocd CLI·git clone "자체가 성립 안 함"은 과대 서술이다 — pod 안에서 네트워크·파일 첨부(`--file`)는 된다. 실제로 안 되는 것은 **지속성**(재호출마다 새 pod, 세션 간 상태 없음)이다. 이 모듈의 존재 이유(지속적 작업대)와 무관해지므로 기각.

**채택**: Option 2. **단, v1·v2의 "기본은 Run Command" 위계를 버리고 §0의 정정된 프레이밍을 따른다** — SSH(`ssh_ingress_cidrs` 비어있지 않음)가 일상 운영 경로, Run Command는 그 경로 자체가 없을 때의 보조 진단 수단.

### Viable Options — 미결 사항 (A/B/C/D) — v2에서 확정된 것은 유지, v3는 정합성만 보강

**미결 D(베이스 이미지·OS, 변경 없음)**: Ubuntu LTS(24.04) 채택. **⚠️ Architect 지적 반영 — 가장 강한 근거를 놓쳤었다**: Entra ID SSH(§2.3)의 공식 지원 배포판 목록에 **"Amazon Linux/AL2023은 없다"**(MS Learn 지원 목록 실측: AlmaLinux·Azure Linux·Debian·openSUSE·Oracle·RHEL·Rocky·SLES·Ubuntu). 즉 D2(AL2023 계열)를 택하면 §2.3의 핵심 기능(Entra SSH) 자체가 성립하지 않는다 — 이게 D1 채택의 가장 강한 이유이고 v2는 이걸 안 썼다.

**미결 A(az CLI 버전 고정)**: A1(apt 정확 핀) 채택, 유지. **⚠️ v2의 자기모순(Architect 지적) 해소**: `az_cli_version`은 apt 버전 문자열 **전체**(예 아래 참조, codename 포함)를 받는다 — codename을 모듈이 유도하지 않는다(닫힌 매핑 금지, `terraform.md` 부채 경고). `ami_id`가 "핀의 소유자는 소비 루트"를 이미 확립했으므로 같은 소유자에게 같은 책임을 주는 것과 정합한다. 누출된 추상화이지만 자기모순보다 낫다.

**⚠️ v4 CRITICAL 수정(Architect 3차 리뷰), v5에서 인용 오류 정정(Architect 4차 리뷰)**: `custom_data`(§2.2)가 `az login --identity --resource-id`를 쓰는데, 이 플래그는 az CLI **2.69.0**부터 지원된다(`azure-cli` `HISTORY.rst` 실측: 2.69.0에서 `--username`으로 UAMI ID 전달을 deprecated 처리하며 "`--client-id`·`--object-id`·`--resource-id`를 대신 쓰라"고 도입, #30525). `--username`으로 UAMI를 지정하는 경로 자체를 제거하는 breaking change는 **2.73.0**이다(#31015). **v4는 이 breaking change 문장을 2.72.0의 것으로 잘못 귀속시켰다** — 결과(하한 값)는 안전한 방향으로 틀렸지만(2.72.0 ≥ 2.69.0이라 실무 영향 없음) 인용 자체가 사실과 다르므로 정정한다. `az_cli_version` 변수 설명에 정확한 하한과 근거를 명문화한다: *"2.72.0 이상을 권장한다(`--resource-id`는 2.69.0부터 지원되지만, `--username`으로 UAMI를 지정하는 경로가 아직 살아있던 2.69~2.72 구간의 혼선을 피하기 위해 그 이후 버전으로 하한을 둔다) — 예: `\"2.72.0-1~noble\"` 이상."* `custom_data`에 `az version` 출력을 로그에 남기는 한 줄을 추가해 이 하한 위반을 boot diagnostics(§2.10)로 사후 확인 가능하게 한다.

**미결 B(kubelogin convert 조건)**: `aks_entra_rbac_enabled` + `aks_cluster_name`/`aks_resource_group_name` 쌍. 유지. **v6 추가**: 같은 교차 validation에 `identity_client_id != null`도 묶는다(§2.2 정정 — `identity_client_id`가 이 슬롯에서만 소비되므로 조건부 필수의 짝이 셋으로 늘었다).

**미결 C(`vm_size`, 변경 없음)**: `Standard_B2s`, x86_64. 유지.

---

## 2. 상세 설계

### 2.0 정체성·배치

`naming`(object, 필수)·`purpose`(기본 `"workbench"`)·`serial`(기본 `"01"`)·`resource_group_name`(필수)·`location`(필수)·`tags`(`map(string)`, 기본 `{}`).

**⚠️ v5 추가(Architect 4차 리뷰 — §1 Principle 5 자기위반 지적)**: `subnet_id`(`string`, `nullable = false`) — workbench VM을 놓을 서브넷. §2.6이 "이 VM이 붙는 서브넷"을 이미 전제하고 있었는데 정작 이 변수 선언이 빠져 있었다. AWS `subnet_id`(private 서브넷 전제, AZ 분산 불필요 — `modules/aws/workbench/variables.tf:71-82`)와 같은 형태로 승계한다.

### 2.1 접속 모델 — SSH가 주 경로, Run Command가 브레이크글래스(재구성)

```hcl
variable "ssh_ingress_cidrs" {
  # 소스 무관 — Bastion 서브넷 CIDR · P2S VPN 풀 · ExpressRoute 대역 · 사무실 공인 IP.
  # 이 값이 비어있지 않은 것이 **일상 운영이 가능한 상태**다(v1·v2의 "escape hatch" 프레이밍 철회).
  #
  # ⚠️ v4: 기본값을 없앤다(필수 입력). Architect 3차 리뷰 antithesis 반영 —
  # "진짜 인바운드 0"이 성립하는 유일한 구성(빈 리스트)이 정확히 §4 ADR이
  # "일상 운영 불가"라 선언한 구성이라, 그걸 default로 두면 이 모듈의 안전성 헤드라인
  # 주장이 아무도 배포하지 않을 설정에서만 참이 된다. `ami_id`(기본값 없음, "핀의 소유자는
  # 소비 루트")와 같은 형태로 이 결정을 plan 시점에 강제한다 — 빈 리스트를 원하면
  # `ssh_ingress_cidrs = []`를 **명시적으로** 써야 한다(순수 Run Command 전용 배포는
  # 실재하는 프로파일이지 실수가 아니므로 막지는 않는다, 다만 침묵으로 얻어지지 않는다).
  type     = list(string)
  nullable = false
}

variable "public_ip_enabled" {
  type     = bool
  default  = false
  nullable = false
}
```

- 교차 validation(변경 없음): `!var.workbench_enabled || !var.public_ip_enabled || length(var.ssh_ingress_cidrs) > 0`.
- **VPN/ExpressRoute를 이미 가진 고객**: `ssh_ingress_cidrs = [vpn_pool_cidr]` + `public_ip_enabled = false` → 공용 노출 0인 대화형 세션(§2.5의 Deny 규칙이 실제로 이걸 보장한다).
- **레퍼런스 아키텍처(VPN 미보유)**: `ssh_ingress_cidrs = ["<사무실 공인 IP>/32"]` + `public_ip_enabled = true`.
- **순수 Run Command 전용(네트워크 경로 자체가 없는 격리 환경)**: `ssh_ingress_cidrs = []` **와** `entra_ssh_login_enabled = false`(§2.3) **둘 다** 명시적으로 지정 — 이때 일상 운영이 사실상 불가능하다는 것을 소비자가 plan 시점에 이미 알고 있는 상태로 만든다(README·변수 설명 양쪽에 이 프로파일을 "두 값을 한 세트로" 문서화 — Architect 4차 지적: 둘 중 하나만 적으면 나머지 하나를 놓친 소비자가 의도치 않게 아웃바운드 의존을 만든다).
- **인증 축(경로별 분리, 변경 없음)**: Run Command 경로는 호출자의 ARM RBAC(`Microsoft.Compute/virtualMachines/runCommand/action`, 이 모듈 스코프 밖). SSH 경로는 §2.3(Entra ID SSH)로 사람이 로그인.
- Run Command는 이 모듈이 별도 리소스를 안 만든다(VM Agent 기본 활성). **다만 이제 이 모듈의 README·§0은 Run Command를 "일상 경로"가 아니라 "SSH 경로가 없을 때의 진단 수단(출력 4,096B 이내 명령만)"으로 명시한다.**

### 2.2 신원 — dual identity, client_id 유예 철회(Architect antithesis 채택)

**v2의 client_id 유예를 철회한다.** 근거(Architect 재조사 결과): `az login`은 리소스 ID를 직접 받는 공식 경로가 있다(`az login --identity --resource-id <ARM resource id>`, `az` CLI 공식 레퍼런스 실측) — client_id 파생이나 별도 입력 여부를 놓고 고민할 필요 자체가 없었다. 단, **kubelogin의 msi 모드는 `--client-id`를 받는다**(Azure/kubelogin 공식 문서, `az login`과 별개 CLI라 인자 체계가 다르다) — 이건 실제로 필요하다.

```hcl
identity {
  type         = "SystemAssigned, UserAssigned"
  identity_ids = [var.identity_id]
}
```

- `identity_id`(`string`, `nullable = false`, 변경 없음) — user-assigned managed identity의 리소스 ID. `custom_data`에서 `az login --identity --resource-id "${identity_id}"`로 사용(client_id 불필요, ID 파싱 불필요, 두 번째 입력 불필요).
- **신규 변수 `identity_client_id`**(`string`, 기본값 `null`) — 같은 identity의 client ID. `custom_data`에서 `kubelogin convert-kubeconfig -l msi --client-id "${identity_client_id}"`에 사용. **⚠️ v6 정정(Critic 최종 리뷰 MAJOR-4)**: v5는 이 변수를 무조건 필수로 두면서 근거로 `ami_id`를 들었는데, 이는 틀린 유비였다 — `ami_id`는 `main.tf`에서 **무조건 소비**되지만(`ami = var.ami_id`), `identity_client_id`는 §1 미결 B의 kubelogin 슬롯(`aks_entra_rbac_enabled = true`이고 `aks_cluster_name`/`aks_resource_group_name` 쌍이 채워졌을 때만)에서만 쓰인다 — **조건부로만 소비되는 값**이다. 이 저장소의 조건부 소비 변수 선례는 `ami_id`가 아니라 AWS `eks_cluster_arn`(기본값 `null`, 교차 validation으로 짝을 강제, `modules/aws/workbench/variables.tf:240-261`)이다. 그 형태를 그대로 승계: 기본값 `null`, `aks_entra_rbac_enabled = true`일 때만 `identity_client_id != null`을 요구하는 교차 validation을 §1 미결 B의 `aks_cluster_name`/`aks_resource_group_name` 쌍 가드에 함께 넣는다(§5에 `expect_failures` assertion 1건 추가). AKS 연동 없이 워크벤치만 쓰는 소비자가 쓰이지도 않는 GUID를 채워야 하는 부담이 이렇게 사라진다.
- 두 값(`identity_id`·`identity_client_id`)을 나란히 받는 이유를 README에 명시: "같은 identity를 가리키는 두 값이라 불일치 위험이 있어 보이지만, 둘 다 bootstrap이 만든 `azurerm_user_assigned_identity` 리소스의 서로 다른 attribute(`.id`/`.client_id`)이므로 소비 루트에서 같은 리소스 참조로 채우면 불일치가 구조적으로 불가능하다."
- 나머지(role assignment 미생성, "순서 의존" 문서화, 재생성 시 고아 없음)는 v2와 동일, 유지.
- 출력 `workbench_system_identity_principal_id` 유지(감사용).

### 2.3 인증 자료 — 소비자 공개키 입력, 확장 게이트를 전용 변수로 분리(v4 수정)

(변경 없음, v2 유지) `admin_ssh_public_key`(`string`, `nullable = false`, 기본값 없음) — 소비자 공개키 입력, private key는 이 모듈이 전혀 다루지 않는다.

**⚠️ v5 추가(Architect 4차 리뷰)**: `admin_username`(`string`, 기본 `"azureuser"`, `nullable = false`) — `admin_ssh_key.username`(Required)과 로컬 계정 사용자명에 공용으로 쓰인다. Entra SSH로 로그인한 사람은 이 로컬 계정과 별개의 자기 신원으로 들어오므로(§2.3의 Entra 확장 절 참조) 값 자체는 브레이크글래스 계정 이름일 뿐 — 고정값으로 충분하고 변수로 열되 소비자가 조직 표준이 있으면 바꿀 수 있게만 한다.

**⚠️ v4 수정(Architect 3차 리뷰 synthesis 채택)**: v3는 `AADSSHLoginForLinux` 확장의 생성을 `length(ssh_ingress_cidrs) > 0`로 게이트했는데, 이는 §2.1에서 `ssh_ingress_cidrs`의 기본값을 없애 필수 입력으로 바꾼 것과 결합하면 **네트워크 도달성(누가 22에 닿는가)과 인증 방식(Entra로 로그인할 것인가)이라는 직교 관심사를 하나의 변수에 묶는** 결과가 된다. 분리한다:

```hcl
variable "entra_ssh_login_enabled" {
  type     = bool
  default  = true
  nullable = false
}
```

```hcl
# ⚠️ v6: 리소스명 확정("가칭" 제거) + Required 인자 5개 전부 명시(Critic 최종 리뷰 MAJOR-2 —
# §1 Principle 5 "입력 변수 표면은 유예 대상이 아니다"를 3라운드째 자기위반하고 있었다).
resource "azurerm_virtual_machine_extension" "aad_ssh_login" {
  count = var.entra_ssh_login_enabled ? 1 : 0

  name                       = "AADSSHLoginForLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.this[0].id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADSSHLoginForLinux"
  # 핀 정책: source_image_reference·az_cli_version과 같은 "핀의 소유자는 소비 루트"
  # 계약을 여기 그대로 적용하지 않는다 — 이 확장은 MS가 관리형으로 굴리는 것이라
  # (aks-cluster의 managed addon과 같은 성격, "Terraform으로 관리할 필요 자체가 없는"
  # 부류) 최신 마이너를 자동 추종하는 편이 안전 패치를 놓치지 않는다.
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}
```

이 확장의 생성은 `entra_ssh_login_enabled`로 게이트한다(`ssh_ingress_cidrs`와 무관). 근거: 이 확장은 apply 시점에 `packages.microsoft.com`·`login.microsoftonline.com`·`pas.windows.net`(모두 443/tcp) + IMDS로 나가는 아웃바운드를 요구한다(MS Learn 「Network」절) — 이 확장을 끄면 그 아웃바운드 의존도 사라진다. 기본값은 `true`(주 인증 경로이므로) — 순수 격리 환경(아웃바운드 자체가 없어 확장 provisioning이 실패할 배포)에서만 명시적으로 `false`로 끈다. 이렇게 분리하면 **`ssh_ingress_cidrs`가 채워져 있는데 확장이 꺼져 있는 조합도, 그 반대도** 각각 정당한 프로파일로 표현되고(예: Bastion을 이미 통과했지만 아직 Entra RBAC 배선 전인 과도기), 아웃바운드 결핍이 그 확장의 provisioning 실패로 apply 시점에 드러난다(§2.10과 연결 — Critic M-8이 우려한 "조용한 실패"의 유일한 loud canary를 임의로 꺼버리지 않는다).

**신규(§2.3 「전제 role assignment」 — Critic 최종 리뷰 MAJOR-5)**: 원칙 4("role assignment는 이 모듈이 만들지 않는다")는 만들지 않는다는 것이지, 무엇이 필요한지 적지 않는다는 뜻이 아니다. `aks-cluster`가 「신원 순서 의존」 절에서 `Network Contributor`까지 역할명을 명시한 것과 같은 해상도로, SSH 경로에 필요한 것을 이 모듈 밖 전제조건으로 명시한다:

- **`Virtual Machine Administrator Login`**(sudo) 또는 **`Virtual Machine User Login`**(일반 사용자) — 로그인할 사람/그룹의 Entra 계정에 부여. ⚠️ 스코프가 VM 하나가 아니라 **"VM과 그 연관 VNet·NIC·공용 IP·로드밸런서 리소스를 포함하는 리소스 그룹"**이어야 한다(MS Learn 원문) — 이 모듈이 NIC·PIP·NSG를 전부 같은 `resource_group_name`에 만드므로(§2.5) 그 RG 스코프로 부여하면 충분하다.
- ⚠️ 구독 **Owner·Contributor 역할은 이 로그인 권한을 자동으로 주지 않는다**(MS Learn: "의도적으로 분리·감사된 설계") — 고객사 담당자가 "권한 있는데 왜 안 되지"로 부딪히는 지점이라 README에 명시.
- `Azure Kubernetes Service Cluster User Role`(§2.2, `identity_id`에 부여, 변경 없음) — kubeconfig 다운로드.
- (`aks_entra_rbac_enabled = true`일 때) `Azure Kubernetes Service RBAC Reader`/`Writer`/`Admin` 등 — K8s API 레벨 권한, 대상은 로그인하는 사람의 Entra 계정(또는 `identity_id`의 msi 경로).
- 클라이언트 측(운영자 로컬 PC): `az extension add --name ssh`(SSH 확장), az CLI 2.22.1 이상. 이 모듈이 강제할 수 없는 소비자 환경 요구이므로 README 안내용으로만 남긴다.

- **v1의 원칙 3 재확인**: `identity { type = "SystemAssigned, ... }`의 system-assigned 절반은 이 확장이 **강제**한다(MS Learn: "exit code 22 ... a system-assigned managed identity is required") — §2.2가 이를 선택지처럼 서술하지 않도록 명시한다. `entra_ssh_login_enabled = false`로 확장 자체를 끄지 않는 한 system-assigned identity는 항상 필요하다.
- README에 §2.6과 연결해 4개 엔드포인트를 전제조건으로 명시.
- `vm_size` 하한(변경 없음): `Standard_B2s`.
- **신규**: `azurerm_linux_virtual_machine`에 `boot_diagnostics { storage_account_uri = null }`(관리형 스토리지 자동 사용) 추가 — cloud-init 실패 시 유일한 사후 진단 수단(Critic M-8). README에 "부팅 후 확인" 절 신설: `/var/log/cloud-init-output.log` 확인, `cloud-init status --wait` 규약, 도구 존재 확인 원라이너.

### 2.3B 이미지·디스크 (신규 — Architect 3차 리뷰 CRITICAL-2)

v1~v3는 §1 미결 D에서 "Ubuntu LTS 채택"까지만 결정하고 이를 담을 변수를 §2 어디에도 선언하지 않았다 — `source_image_reference`(4개 서브필드 전부 provider Required)와 `os_disk`(Required 블록, `caching` Required 인자)가 통째로 누락된 채였다. §5 assertion 9(`version == "latest"` 거부)가 검증할 대상 자체가 없었다.

```hcl
variable "source_image_reference" {
  # ami_id와 같은 계약: 기본값 없음(필수), 소비 루트가 리전·세대 갱신을 소유한다.
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  nullable = false
  validation {
    condition     = lower(var.source_image_reference.version) != "latest"
    error_message = "source_image_reference.version에 \"latest\"를 쓰지 않는다 — 재현성이 깨진다(같은 코드로 다른 시점에 만든 VM 두 대가 다른 이미지를 갖게 됨). 정확한 버전을 핀한다."
  }
}

variable "os_disk_caching" {
  type     = string
  default  = "ReadWrite"
  nullable = false
}

variable "os_disk_storage_account_type" {
  type     = string
  default  = "StandardSSD_LRS"
  nullable = false
}

variable "os_disk_size_gb" {
  # AWS의 root_volume_size(기본 10)에 대응하나 기본값을 두지 않는다 — 이미지 기본 디스크
  # 크기보다 작게 줄 수 없다는 provider 제약이 있어, 이미지를 정하는 소비 루트가
  # 같이 정하는 게 맞다(닫힌 가정을 모듈이 갖지 않는다).
  type     = number
  default  = null
}

variable "os_disk_encryption_set_id" {
  # AWS의 root_volume_kms_key_id 대응. null이면 플랫폼 관리형 키(암호화 자체는 항상 켜져
  # 있다 — 끌 수 없음이 강제, CMK 사용 여부만 선택).
  type    = string
  default = null
}
```

- 이 절이 §5 assertion 9의 실제 대상이 된다.
- 미결 D(Ubuntu LTS)와 미결 A(az CLI 정확 핀)의 관계: `source_image_reference`가 필수 입력이므로 apt codename은 이 값에서 소비자가 알아서 도출한다 — 모듈은 codename을 유도하지 않는다(변경 없음, 유지).

### 2.4 부트스트랩 (`custom_data`) — Ubuntu/apt 기준, 신원 순서 문제 해소 반영

(v2 표 유지, kubeconfig 행만 갱신)

| 슬롯 | 처리 |
|---|---|
| kubeconfig | `az login --identity --resource-id "${identity_id}"` → `az aks get-credentials --resource-group <rg> --name <cluster>` → (§1 미결 B 조건) `kubelogin convert-kubeconfig -l msi --client-id "${identity_client_id}"`. **§2.2 신원 확정으로 이 시점에 이미 권한이 붙어 있고(bootstrap이 VM보다 먼저 role assignment 완료), client_id 유예도 없어 스크립트가 완결적으로 쓰인다.** |

나머지 슬롯(`git`/`az` CLI/`kubectl`/`helm`/`argocd`/`kubelogin`/`krew`/`aks-node-viewer`)은 v2와 동일.

### 2.5 NSG — 명시적 Deny로 플랫폼 기본 규칙을 실제로 덮는다(전면 재설계, Critic C-1 채택)

**v2의 핵심 결함**: "커스텀 인바운드 규칙 개수 0 = 인바운드 0"이라고 암묵 가정했다. Azure NSG의 플랫폼 기본 규칙(공식 문서 실측):

> `AllowVNetInBound`(priority 65000, source/dest `VirtualNetwork`, 전 포트, Allow) — `VirtualNetwork` 서비스 태그는 **같은 VNet + 피어링된 VNet + 연결된 온프레미스 대역(VPN/ExpressRoute 게이트웨이 경유) 전체**를 포함한다.

즉 커스텀 규칙을 하나도 안 만들면, **이 VM은 같은 VNet·피어·온프레미스 전체에서 22번이 열려 있는 것과 같다.** vWAN hub-spoke(Driver 1)에서는 이게 사실상 "허브에 연결된 모든 스포크에 열림"을 뜻한다.

**채택**: 이 모듈의 NIC 레벨 NSG(`azurerm_network_security_group`, v2 §2.5의 소유권 결정 유지)에 우선순위를 명시적으로 설계한다.

**⚠️ v5 재작성(Architect 4차 리뷰) — for_each+index() 방식을 단일 규칙으로 교체**: v4의 CIDR별 `for_each` 규칙은 `name`이 provider 스키마상 **ForceNew**인데 그 이름을 `index()`(리스트 위치)로 유도했다 — 중간 CIDR 하나를 빼면 뒤 항목들의 `name`이 밀리며 **재생성**된다. 스니펫 자신이 "인덱스 키잉의 결함을 회피한다"고 주석에 적어놓고 `name` 쪽에서 그대로 재현한 것(Architect 4차: "발명하기 전에 찾는다" 위반 — provider가 이미 `source_address_prefixes`(복수형, CIDR 목록을 그대로 받는 단일 필드)를 제공한다). 단일 규칙으로 교체한다:

```hcl
# 규칙 우선순위 스킴(낮을수록 먼저 평가, provider 스키마 실측: 허용 범위 100~4096):
#   100  : ssh_ingress_cidrs 허용 규칙(단일 리소스, source_address_prefixes에 목록 전달)
#   4096 : 인바운드 전체 명시 차단 — 플랫폼 기본 AllowVNetInBound(65000)·
#          AllowAzureLoadBalancerInBound(65001)를 실제로 덮는다(이 모듈은 지금
#          LB를 안 쓰지만, 나중에 workbench를 LB 뒤에 두면 이 규칙이 헬스 프로브도
#          막는다는 것을 README에 남긴다)
#
# ⚠️ Deny 4096은 플랫폼 인프라 통신(DHCP·DNS·IMDS·health, 168.63.129.16/169.254.169.254)을
# 막지 않는다 — MS Learn 「Azure platform considerations」: 이 통신은 AzurePlatformDNS 등
# 전용 서비스 태그를 명시하지 않는 한 NSG 적용 대상 밖이다. 즉 이 Deny는 Run Command·
# VM Agent·boot diagnostics를 죽이지 않는다(README에 근거와 함께 명시 — 안 그러면
# 구현자가 "Deny 걸면 Run Command 죽는 거 아니냐"로 되돌아갈 위험이 있다).
#
# ⚠️ 두 규칙 모두 workbench_enabled로 게이트한다(count) — 이게 없으면 kill switch를
# 끌 때 azurerm_network_security_group.this[0] 참조가 index out of range로 plan을
# 깨고, §5 assertion 6("전 리소스 0개")과 모순된다(Architect 4차 지적).
resource "azurerm_network_security_rule" "ssh_allow" {
  count = local.enabled && length(var.ssh_ingress_cidrs) > 0 ? 1 : 0

  name                         = "AllowSsh"
  priority                     = 100
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  source_address_prefixes      = var.ssh_ingress_cidrs   # 복수형 — CIDR 목록을 그대로 전달, 태그 사용 불가(우리는 순수 CIDR만 받으므로 무관)
  destination_port_range       = "22"
  destination_address_prefix   = "*"
  resource_group_name          = var.resource_group_name
  network_security_group_name  = azurerm_network_security_group.this[0].name
}

resource "azurerm_network_security_rule" "deny_all_inbound" {
  count = local.enabled ? 1 : 0

  name                         = "DenyAllInbound"
  priority                     = 4096
  direction                    = "Inbound"
  access                       = "Deny"
  protocol                     = "*"
  source_port_range            = "*"
  source_address_prefix        = "*"
  destination_port_range       = "*"
  destination_address_prefix   = "*"
  resource_group_name          = var.resource_group_name
  network_security_group_name  = azurerm_network_security_group.this[0].name
}

resource "azurerm_network_interface_security_group_association" "this" {
  # v5 추가(Architect 4차 CRITICAL급 누락 — 이게 없으면 NSG를 아무리 정교하게 설계해도
  # NIC에 실제로 붙지 않는다. azurerm 3.0+는 network_interface에 network_security_group_id
  # 인자가 없어 이 연결 리소스가 유일한 부착 수단이다. vnet 모듈의
  # azurerm_subnet_network_security_group_association과 같은 패턴).
  count = local.enabled ? 1 : 0

  network_interface_id     = azurerm_network_interface.this[0].id
  network_security_group_id = azurerm_network_security_group.this[0].id
}
```

- CIDR 목록 편집(추가·삭제·순서 변경)이 규칙 1개의 `source_address_prefixes` 속성만 갱신하고 **다른 어떤 리소스도 재생성하지 않는다** — v4가 "회피했다"고 잘못 주장했던 것을 이번엔 실제로 회피한다. priority 예산(100개 상한) validation과 §5 assertion 11(101개 조합 `expect_failures`)은 이제 불필요해져 삭제한다.
- `ssh_ingress_cidrs = []`(명시 지정, §2.1에서 기본값 제거됨)이면 `ssh_allow`가 `count = 0`으로 아예 안 만들어지고 `deny_all_inbound`만 남아 — **이제 정말로 인바운드 0**(커스텀 우선순위 100·4096이 플랫폼 65000보다 먼저 평가되므로 `AllowVNetInBound`가 절대 도달하지 못한다).
- NIC 레벨 NSG는 서브넷 레벨 NSG(vnet의 `nsg_enabled`)와 **AND**로 평가된다는 v2의 순서 의존 문서화는 유지.

### 2.6 아웃바운드 — 계약(변수)으로 만들지 않고 전제조건으로 정직하게 선언(전면 철회, Architect+Critic 공통 채택)

**v2의 `egress_cidr_blocks` 변수를 완전히 삭제한다.** 근거(Architect+Critic 독립적으로 동일 결론): Azure NSG의 플랫폼 기본 규칙(`AllowInternetOutBound`, priority 65001, 전 포트 Allow)이 이미 아웃바운드를 전부 허용한다 — 443 허용 규칙을 "추가"해도 그 위에 이미 열려 있는 65001 위에 얹히는 장식일 뿐 아무것도 좁히지 않는다. 게다가 v2의 validation error_message(*"VM Agent가 제어 평면에 연결 못 해 Run Command가 성립 안 한다"*)는 사실과 반대다 — MS Learn 원문: *"VM Agent의 168.63.129.16 통신(80/32526)은 NSG 적용 대상이 아니다."*

**대신 전제조건을 정직하게 선언한다(변수 없음, 코드 없음, README 문서로만)**:

- 이 모듈은 아웃바운드를 제한하지 않는다. Azure NSG 기본 규칙(`AllowInternetOutBound`)이 그대로 적용된다.
- 이 VM이 정상 동작하려면 다음 443/tcp 아웃바운드가 실제로 도달해야 한다(NSG는 안 막지만, 서브넷에 NAT/기본 아웃바운드 경로 자체가 없으면 막힌다 — `vnet` 모듈의 `nat_routed`/`default_outbound_access_enabled` 참조):
  - Entra SSH 확장(§2.3, **`entra_ssh_login_enabled = false`면 미생성** — v5에서 이 게이트가 `ssh_ingress_cidrs`에서 옮겨졌다, v6에서 이 절의 stale한 참조를 정정): `packages.microsoft.com`·`login.microsoftonline.com`·`pas.windows.net`(443/tcp) + IMDS(`169.254.169.254`, 443이 아님 — 총 4개 엔드포인트, §2.3과 개수 일치시킴)
  - `az aks get-credentials`/Run Command 결과 반환: `AzureCloud` 서비스 태그(Azure 공용 IP 대역, 고정 CIDR 목록으로 표현 불가 — MS Learn이 서비스 태그 사용을 권장)
  - 도구 다운로드(§2.4): `dl.k8s.io`·`get.helm.sh`·`github.com`(argocd·kubelogin·krew·aks-node-viewer 릴리스)

**⚠️ v6 CRITICAL 추가(Critic 최종 리뷰) — DNS 해석 전제조건이 통째로 빠져 있었다**: 위 아웃바운드 전제조건은 전부 **ARM/공용 엔드포인트**용이고, 워크벤치의 진짜 존재 이유인 **private AKS API 서버(kubectl 대상)로의 도달**은 여기 없었다. `aks-cluster` 모듈은 `private_cluster_enabled` 기본값이 `true`이고 `private_dns_zone_id`를 변수로 노출하지 않는다 — 즉 AKS가 만드는 private DNS zone(`privatelink.<region>.azmk8s.io`)은 **AKS 노드가 속한 VNet에만 링크**된다(MS Learn: "linked only to the VNet that the cluster nodes are attached to ... can only be resolved by hosts in that linked VNet"). `az login`·`az aks get-credentials`·`kubelogin convert-kubeconfig`(§2.4)는 전부 ARM 호출이라 이 DNS 문제와 무관하게 성공하고 kubeconfig까지 만들어진다 — **실패는 운영자가 처음 `kubectl get nodes`를 칠 때만 드러난다**(cloud-init은 이미 성공을 보고한 뒤라 §2.10의 boot diagnostics도 이 실패를 못 잡는다). Driver 1이 명시한 배포 형태(vWAN hub-spoke, 워크벤치와 AKS 노드가 서로 다른 스포크/VNet일 수 있음)에서 이 문제가 실제로 발생한다.

전제조건을 명시한다(이 모듈은 아래를 강제하지 않는다 — `aks-cluster`의 identity_id/role assignment 경계와 같은 이유로 소비 레포 몫이지만, README에 반드시 적는다):
1. 워크벤치의 `subnet_id`가 AKS 노드와 **같은 VNet**에 있으면 별도 조치가 필요 없다(system-managed private DNS zone이 그 VNet에 이미 링크돼 있으므로).
2. 다른 VNet(스포크)에 있다면, 그 VNet에 대한 **`azurerm_private_dns_zone_virtual_network_link`를 소비 레포가 별도로 만들어야 한다**(`Private DNS Zone Contributor` 필요 — 이 모듈이 아니라 `identity_id`를 만드는 bootstrap 계층과 같은 층위의 작업).
3. 커스텀 DNS 서버를 쓰는 스포크라면 `168.63.129.16`(Azure DNS)으로의 conditional forwarder가 추가로 필요하다(MS Learn 「Prerequisites」).

§2.10의 "부팅 후 확인" 순서에 `nslookup <api-fqdn>` 또는 `kubectl get nodes`를 **"cloud-init 성공이 검증하지 못하는 항목"으로 별도 표기**하고, §4 Consequences에 "이 모듈은 DNS 도달성을 검증하지 않는다 — `aks-cluster`의 신원 순서 의존과 같은 성격의, plan에서 잡을 수 없는 전제조건"이라고 남긴다.
- 아웃바운드를 좁히고 싶은 소비자는 **이 모듈이 아니라 서브넷 NSG**(또는 자체 방화벽)에 Deny 규칙을 추가한다 — 이 모듈은 그 결정에 관여하지 않는다(원칙 1의 경계 원칙을 아웃바운드에도 그대로 적용).

원칙 2("정직하게 표현한다")·`.claude/rules/terraform.md`("작동하지 않는 손잡이보다 없는 것이 낫다"류의 죽은 경로 금지)가 이 철회를 지지한다.

**⚠️ v4 추가(Architect 3차 리뷰 M-2 상당)**: 이 모듈의 아웃바운드 성립 여부는 **형제 모듈(`vnet`)의 기본값 하나에 매달려 있다** — `vnet/variables.tf`의 `default_outbound_access_enabled`(기본 `true`) 덕분에 오늘 기준 신규 서브넷은 별도 조치 없이 아웃바운드가 된다. 다만 MS Learn이 명시한 대로 **2026-03-31 이후 API 버전부터 신규 VNet의 서브넷은 기본이 private(아웃바운드 없음)로 바뀐다** — 이 모듈은 그 변화를 감지할 방법이 없으므로(subnet_id 문자열만 받음), README에 "이 VM이 붙는 서브넷이 NAT gateway·Standard 공용 IP·UDR+NVA 중 하나로 명시적 아웃바운드 경로를 가져야 한다"고 명시하고, "그냥 기본값이 되겠지"라는 가정에 기대지 않는다.

### 2.7 Kill switch (변경 없음)

`workbench_enabled`(`bool`, 기본 `true`). `deletion_protection` 의도적 미도입, AWS와 동일 사유 승계. **명시(Critic "What's Missing" 응답, v6에서 `identity_client_id` 정정)**: `identity_id`·`admin_ssh_public_key`·`ssh_ingress_cidrs`(v4부터 기본값 없음)·`source_image_reference`는 `workbench_enabled = false`일 때도 여전히 타입 검사를 통과해야 하는 필수 변수다 — `ami_id`가 이미 확립한 선례("kill switch와 무관하게 필수 입력은 항상 필요")를 그대로 따른다. `identity_client_id`는 v6에서 조건부 필수(기본 `null`)로 정정됐으므로 이 목록에서 제외한다 — `eks_cluster_arn`과 같은 성격이다.

### 2.8 출력 (변경 없음)

`workbench_vm_id`·`workbench_private_ip`·`workbench_public_ip`(null 조건 포함)·`workbench_nsg_id`·`workbench_system_identity_principal_id`.

### 2.9 네이밍 — `nsg` 의미론 확장을 착수 게이트에 명시(Critic M-5 반영)

신규 약어(CAF 등재): `vm`·`nic`. **⚠️ v5 추가(Architect 4차 리뷰)**: 카탈로그 현행 구성은 A.1~A.5(Network·Management/governance·Storage·Identity·Containers)뿐이라 `nic`은 A.1(8→9)에 들어가지만 **`vm`은 새 카테고리(예: "A.6 Compute") 신설이 필요하다** — 착수 게이트의 "3곳 동시 수정"에 "신규 카테고리 섹션 추가"가 얹힌다는 것을 명시한다. `docs/naming/abbreviations/azure.md:84-86`은 *"`snet`·`nsg`·`rt`는 서브넷 그룹 키를 `purpose` 자리에 쓴다"*고 SSOT를 선언하는데, 이 모듈의 NSG는 **NIC 레벨**이라 서브넷 그룹 키가 없다. **결정**: `purpose` 자리에 이 모듈 자신의 purpose 토큰(`"workbench"`)을 쓴다(다른 리소스와 동일 규칙) — 이는 `nsg` 약어의 의미론을 "서브넷 그룹 전용"에서 "그룹 키가 없는 경우 모듈 purpose로 대체"로 **확장**하는 것이다. 착수 게이트는 **둘 다** 필요하다(택일 아님, Architect 지적): ① `vm`·`nic` 신규 등재의 기계적 절차(섹션 헤더·상단 총계·카운트 요약 표 3곳 동시 수정, `validate-abbreviations.py` 통과) ② `azure.md:84-86` 본문 자체의 의미론 개정(검증기가 못 잡는 부분이라 사람이 직접).

### 2.10 부팅 실패 진단 (신규, Critic M-8)

§2.3의 `boot_diagnostics` 활성화 + README "부팅 후 확인" 절 참조. `custom_data`가 ForceNew이므로 복구는 VM 재생성뿐이라는 것을 명시하고, 재생성 전 확인 순서(boot diagnostics 콘솔 로그 → `/var/log/cloud-init-output.log` → 도구별 존재 확인)를 README에 순서 목록으로 제공한다.

---

## 3. 부수 발견 (변경 없음)

- Azure Portal "Kubernetes 리소스" 그래픽 뷰의 VNet 도달성 요구, Run command 포털 기능은 도달성 무관.
- `aks-cluster`의 `entra_admin_group_object_ids` 빈 값 → Entra RBAC 블록 미생성.

---

## 4. ADR (v3)

- **Decision**: AWS workbench의 Azure 대응 모듈. 일상 운영 경로는 SSH(`ssh_ingress_cidrs`, 명시적 Deny로 실제 인바운드 0을 보장), Run Command는 그 경로가 없을 때의 브레이크글래스 진단 수단. 신원은 dual identity + `identity_id`/`identity_client_id` 둘 다 필수 입력(client_id 파생·유예 없음). 인증 자료는 소비자 공개키. 베이스 이미지 Ubuntu LTS(Entra SSH 지원 배포판 목록에 근거). 아웃바운드는 제한하지 않고 전제조건으로 문서화.
- **Drivers**: §1 참조.
- **Alternatives considered**: **Bastion — 기각이 아니라 흡수**(vWAN 허브 내 배치만 불가, 스포크 배치는 `ssh_ingress_cidrs`의 값으로 들어옴. v2 ADR이 이를 "기각"으로 오기했던 것을 v3에서 정정, Critic M-1), VNet-injected Cloud Shell(지속 상태 없음), `az aks command invoke` 전용(무상태, 근거는 "지속성 부재"로 좁힘), system-assigned 단독 신원(기각 사유 재확인), `tls_private_key`(state 내 평문 자격증명), `egress_cidr_blocks` 변수(Azure NSG 기본 규칙 하에서 의미론적으로 무효 — v2에서 신설했다가 v3에서 철회).
- **Why chosen**: dual identity + 두 입력(client_id 유예 없음)이 "발명하기 전에 찾는다" 원칙과 plan-time 검증 가능성을 동시에 만족하는 유일한 조합(`az login --resource-id` 공식 경로 확인). 명시적 Deny 규칙이 "기본 인바운드 0"이라는 주장을 실제로 성립시키는 유일한 방법. 아웃바운드를 변수로 안 만드는 것이 "작동하지 않는 안전 손잡이보다 없는 것이 낫다"는 원칙과 정합.
- **Consequences**: `ssh_ingress_cidrs`가 비어 있으면(순수 Run Command 배포) 일상 운영이 사실상 불가능하다 — 이는 이 모듈의 근본적 한계이지 설정 실수가 아니다. **v4에서 이 변수의 기본값을 제거**해(§2.1) 이 선택이 침묵 속의 default가 아니라 plan 시점의 명시적 의사결정이 되도록 만들었다 — Architect 3차 리뷰가 지적한 "헤드라인 안전성 주장이 아무도 안 쓸 default에서만 참"이라는 문제를 이렇게 해소한다. AWS 대비 Azure는 "완전한 대화형 + 진짜 인바운드 0"을 동시에 주는 서비스가 없다는 클라우드 간 근본 격차를 이 설계는 감추지 않고 드러낸다.
  **⚠️ v5 헤드라인 정정(Architect 4차 antithesis)**: 기본값 제거가 그 명제 자체("진짜 인바운드 0은 실배포에서 아무도 안 쓴다")를 없애지는 못한다 — 바뀐 건 "타이핑 한 줄"뿐이다. 이 모듈이 실제로 내세울 검증 가능한 강한 주장은 "인바운드 0"이 아니라 **"명시적 Deny 바닥(§2.5의 priority 4096)을 깐 SSH 운영 지점 — 규칙을 하나도 안 열면 정말 아무것도 안 열리고, 열면 그 CIDR만 열린다"**이다. README·§0의 헤드라인 문구를 이렇게 정정한다(서술 정정이라 구현에 영향 없음). "안전한 경로에 변수 2개를 명시하게 만든 것이 위험한 경로보다 마찰을 더 키운 것 아니냐"는 반론에는 `ami_id` 선례("보안 태세를 결정하는 값을 침묵의 기본값에 맡기지 않는다")로 답한다 — plan 시점 강제가 타이핑 비용보다 이 저장소에서 항상 우선한다.
- **Follow-ups**: `docs/naming/abbreviations/azure.md:84-86` 개정(§2.9), `docs/module-catalog.md` 체인 추가, `examples/` 설계, `versions.tf`, `trivy config` 사전 검토(공용 IP+22 인바운드 조합), Run Command의 4,096B/90분 제약을 README에 "브레이크글래스 전용" 근거로 명시, `az_cli_version` 하한(2.72.0) README 명시.

---

## 5. 검증 계획 — assertion 재설계(Critic M-2/M-4/M-6 반영)

1. 네이밍: `vm-`·`nic-`·`nsg-`·`pip-`(4종, `public_ip_enabled=true`일 때만) 접두 assertion.
2. **`identity[0].type == "SystemAssigned, UserAssigned"`**, **`identity[0].identity_ids == toset([var.identity_id])`**(신규, `aks-cluster/tests/plan.tftest.hcl:95-100` 선례 형식 승계) — v1→v2 최대 변경점이었는데 v2에 검증이 0건이었던 공백을 메운다.
3. **`ssh_ingress_cidrs`에 빈 리스트를 명시적으로 준 run**(v4: 더 이상 "기본값"이 아니다, §2.1)에서: **`length(azurerm_network_security_rule.ssh_allow) == 0`**, **`length(azurerm_network_security_rule.deny_all_inbound) == 1`이고 그 priority가 4096**, **`length(azurerm_network_interface_security_group_association.this) == 1`** — "규칙 0개"가 아니라 "Deny가 실제로 있고 NSG가 실제로 NIC에 붙어 있다"를 검증(C-1 수정 + v5 NIC association 추가 반영, 이게 진짜 안전성 검증 지점). ⚠️ v6 정정(Critic 최종 리뷰 MAJOR-1): `azurerm_network_security_rule.ssh_allow` 자체를 인덱스 없이 참조하면 `count` 기반 리소스라 `length(...)` 형식이어야 한다(`ssh_allow[0]` 참조는 개수 0일 때 index out of range로 테스트가 깨진다).
4. `ssh_ingress_cidrs`가 N개(N>0)일 때: `length(azurerm_network_security_rule.ssh_allow) == 1`(v5: 단일 규칙 설계), **`azurerm_network_security_rule.ssh_allow[0].source_address_prefixes == toset(var.ssh_ingress_cidrs)`**(⚠️ v6 정정, Critic 최종 리뷰 MAJOR-1: `source_address_prefixes`는 provider 스키마상 **Set**이고 `ssh_ingress_cidrs`는 `list(string)`이라 `toset()` 없이 비교하면 타입이 달라 항상 `false`로 평가되어 `tofu test`가 반드시 실패한다 — 바로 위 assertion 2가 이미 `identity_ids == toset([var.identity_id])`로 이 패턴을 정확히 쓰고 있었는데 여기서 놓쳤다), priority(100) < deny priority(4096).
5. `public_ip_enabled = true` + `ssh_ingress_cidrs = []` 조합 `expect_failures`.
6. `workbench_enabled = false`일 때 전 리소스 0개, 스칼라 출력 null.
7. `az_cli_version = null` + `aks_cluster_name != null` 조합 `expect_failures`.
8. `aks_entra_rbac_enabled = true` + `aks_cluster_name`/`aks_resource_group_name`/`identity_client_id`(v6 추가) 중 하나라도 누락된 조합 `expect_failures`.
9. `source_image_reference.version == "latest"` 조합 `expect_failures`(§2.3B 신설로 대상 확보, Critic M-3).
10. **`entra_ssh_login_enabled = false`일 때 `length(azurerm_virtual_machine_extension.aad_ssh_login) == 0`**(v4: 게이트가 `ssh_ingress_cidrs`에서 `entra_ssh_login_enabled`로 이전됨, §2.3. v6: 리소스명 확정으로 "가칭" 제거).
11. ~~`length(ssh_ingress_cidrs)`가 101개인 조합 `expect_failures`~~ — v5에서 단일 규칙 설계(`source_address_prefixes`)로 교체하며 priority 예산 제약 자체가 사라져 **삭제**(§2.5).
12. `workbench_enabled = false`일 때 `length(azurerm_network_security_rule.deny_all_inbound) == 0`·`length(azurerm_network_interface_security_group_association.this) == 0`(v5, `length(...)` 형식 명시로 v6 정정)·**`length(azurerm_virtual_machine_extension.aad_ssh_login) == 0`·`length(azurerm_public_ip.this) == 0`**(v6 추가, Critic 최종 리뷰 "What's Missing" — assertion 6의 "전 리소스 0개"가 함의한다고 넘기지 않고 명시 열거하는 v5의 취지를 확장의 2개 리소스에도 동일 적용).

~~구 assertion 8(`custom_data` re-plan diff)은 삭제~~ — `tofu test`가 두 run 간 diff를 비교하는 구문을 지원하지 않고, `custom_data` ForceNew는 provider가 이미 보장하므로 모듈이 아니라 provider를 시험하는 항목이었다(Critic M-4). 대체: 위 항목들로 커버.

**미검증으로 남기는 것**(배포하지 않는 저장소의 한계, README에 명시): `kubelogin convert-kubeconfig -l msi`가 로컬 계정 전용 클러스터에서 무해한지, `AADSSHLoginForLinux`의 "최소 1GB" 요구가 신규 VM에도 동일 적용되는지, Run Command의 4,096B/90분 제약이 실제 진단 시나리오를 감당하는 최소선인지.

---

## 6. Changelog (v2 → v3)

| 항목 | v2 | v3 | 근거 |
|---|---|---|---|
| 접속 모델 프레이밍 | 기본 Run Command, SSH는 escape hatch | **SSH가 일상 경로, Run Command는 브레이크글래스**(위계 역전) | Critic C-3 — Run Command 4,096B/90분/비대화형/취소불가 확정값 |
| NSG 인바운드 | 규칙 0개 = 인바운드 0(암묵 가정) | **명시적 Deny(priority 4096)로 플랫폼 65000을 실제로 덮음** | Critic C-1 — `AllowVNetInBound`가 VNet·피어·온프레미스 전체 허용 |
| 아웃바운드 | `egress_cidr_blocks` 변수 + validation(v2 신설) | **변수 철회, 전제조건으로 문서화만** | Architect+Critic 공통 — NSG `AllowInternetOutBound` 하에서 변수가 무효, error_message 사실 오류 |
| identity client_id | 유예("구현 착수 시 결정") | **`identity_client_id` 필수 입력으로 즉시 확정**, `az login`은 `--resource-id`로 client_id 불필요 확인 | Architect antithesis — 유예가 "발명하기 전에 찾는다" 위반, 미조사 상태의 가짜 딜레마였음 |
| 미결 D 근거 | "az CLI 설치 경로가 Debian 계열" | **+ "Entra SSH 지원 배포판에 AL2023 자체가 없음"**(가장 강한 근거 추가) | Architect Minor-3f |
| 미결 A 자기모순 | "이미지 핀 필수"(D)와 "codename 상수"(A)가 모순 | `az_cli_version`이 apt 버전 문자열 전체를 받음(codename 유도 안 함) | Architect M-7/자기모순 지적 |
| Bastion ADR 서술 | §4가 "기각"으로 오기(§1과 불일치) | "기각 아님, `ssh_ingress_cidrs`로 흡수" | Critic M-1 |
| NSG 규칙 리소스 형태 | 미정 | 별도 `azurerm_network_security_rule`(for_each), 인라인 금지 | Critic M-6 — mock_provider Optional+Computed 불안정성 |
| Entra SSH 확장 생성 조건 | 무조건 생성 | `length(ssh_ingress_cidrs) > 0`로 게이트 | Critic M-7 — 미사용 시 불필요한 아웃바운드 의존 제거 |
| boot_diagnostics | 없음 | 추가 + README 부팅 실패 진단 절 | Critic M-8 |
| §5 assertion | 8건(1건 실행 불가, identity 검증 0건) | 10건(identity 2건·Deny 규칙 검증·`latest` 거부·확장 조건부 생성 추가, 실행 불가 항목 삭제) | Critic M-2/M-3/M-4 |
| `nsg` 네이밍 착수 게이트 | "거버넌스 리뷰 절차" 일반 언급 | `azure.md:84-86` 본문 개정을 명시적 게이트로 추가 | Critic M-5 |

## 7. Changelog (v3 → v4)

| 항목 | v3 | v4 | 근거 |
|---|---|---|---|
| `az_cli_version` 하한 | 예시값 `"2.64.0-1~noble"`(하한 미명시) | **2.72.0 이상 명문화**, 예시값 교체, `az version` 로그 한 줄 추가 | Architect 3차 CRITICAL-1 — `az login --identity --resource-id`는 2.72.0부터, 이전엔 `--username` |
| 이미지·디스크 축 | 미결 D에서 "결정"만, §2에 변수 미선언 | **§2.3B 신설** — `source_image_reference`(4필드 필수, `latest` 거부 validation)·`os_disk_*` 4종 | Architect 3차 CRITICAL-2 — §5 assertion 9의 대상 부재 |
| `ssh_ingress_cidrs` 기본값 | `default = []`(기본값이 곧 "일상 운영 불가" 구성) | **기본값 제거(필수 입력)** — 빈 리스트를 원하면 명시 지정 | Architect 3차 antithesis — "진짜 인바운드 0"이 성립하는 유일한 구성이 정확히 ADR이 "일상 운영 불가"라 선언한 default였음 |
| Entra SSH 확장 게이트 | `length(ssh_ingress_cidrs) > 0`(네트워크 도달성과 인증 방식이 한 변수에 결합) | **전용 `entra_ssh_login_enabled`(기본 `true`)로 분리** | Architect 3차 synthesis — 직교 관심사 분리, 아웃바운드 결핍이 apply 시점에 드러나도록 |
| system-assigned identity 서술 | 선택지처럼 서술 | **§2.3의 확장이 강제한다고 명시**(exit code 22 근거) | Architect 3차 — 강제 vs 선택 원칙(§1 Principle 3) 재적용 |
| NSG 규칙 스니펫 | `source_port_range`·`destination_address_prefix`·`name` 생략, 인덱스 키잉 | 필수 인자 전체 명시, `toset(cidrs)` 값 키잉 + `index()` priority, `length<=100` validation | Architect 3차 — 스키마 완결성, 삭제 시 무관 규칙 재생성 방지 |
| Deny 4096의 부수효과 | 65000만 언급 | **65001(LB 프로브)도 덮인다는 것 + 플랫폼 인프라(IMDS 등)는 안 막힌다는 것 명시** | Architect 3차 — 완결성, 되돌림 방지 |
| 아웃바운드-형제 모듈 의존 | 미언급 | `vnet`의 `default_outbound_access_enabled` 기본값 의존 + 2026-03-31 API 변경 명시 | Architect 3차 M-2 상당 |
| §5 assertion | 10건(identity·Deny·latest·확장게이트, 일부는 여전히 "기본값" 전제) | assertion 3의 "기본값" 표현 정정, assertion 10을 `entra_ssh_login_enabled` 기준으로 교체, priority 상한 assertion 11 추가 | Architect 3차 반영 |
| `nsg` 착수 게이트 | "신규 등재 절차와 별개로" (택일처럼 읽힘) | 신규 등재(3곳)와 의미론 개정 **둘 다** 게이트임을 명시 | Architect 3차 — 게이트 누락 방지 |

## 8. Changelog (v4 → v5)

| 항목 | v4 | v5 | 근거 |
|---|---|---|---|
| `az_cli_version` 하한 근거 | "2.72.0에서 BREAKING CHANGE" (버전 귀속 오류) | `--resource-id`는 **2.69.0** 도입, breaking change는 **2.73.0** — 정정. 하한값 2.72.0은 유지(안전) | Architect 4차 — HISTORY.rst 버전 헤더 재대조 결과 인용 오류 확인 |
| NSG 인바운드 규칙 | CIDR당 `for_each` + `index()`로 `name`/`priority` 유도 | **단일 규칙 + `source_address_prefixes`**(복수형)로 전면 교체 | Architect 4차 HIGH — `name`이 ForceNew인데 `index()`를 재사용해 "회피했다"던 재생성 결함이 그대로 재현됨. provider의 `source_address_prefixes` 공식 경로 미조사(재발한 "발명 전에 찾는다" 위반) |
| NIC-NSG 연결 | 미선언 | `azurerm_network_interface_security_group_association` 추가 | Architect 4차 MEDIUM — 이게 없으면 NSG가 아무리 정교해도 NIC에 안 붙어 전부 무효 |
| NSG 리소스 kill switch 게이트 | 없음(assertion 6과 모순) | `count = local.enabled ? ...` 추가, assertion 12 신설 | Architect 4차 MEDIUM |
| `subnet_id`·`admin_username` | 미선언(§1 Principle 5 자기위반) | §2.0·§2.3에 각각 추가 | Architect 4차 MEDIUM |
| `latest` 거부 validation | `!= "latest"`(대소문자 우회 가능) | `lower(...) != "latest"` | Architect 4차 LOW |
| 격리 프로파일 문서화 | `ssh_ingress_cidrs=[]`만 언급 | `entra_ssh_login_enabled=false`와 한 세트로 명시 | Architect 4차 LOW |
| `vm` 네이밍 등재 | 기존 카테고리에 추가하는 것처럼 서술 | **신규 "Compute" 카테고리 신설** 필요함을 명시 | Architect 4차 LOW |
| §0/§4 헤드라인 프레이밍 | "인바운드 0" 강조 | **"명시적 Deny 바닥을 깐 SSH 운영 지점"**으로 정정(검증 가능한 강한 주장으로 교체) | Architect 4차 antithesis |
| §5 assertion | 11건(priority 예산 검증 포함) | assertion 3·4 갱신(단일 규칙 반영), assertion 11 삭제(예산 제약 소멸), assertion 12 신설(kill switch) | v5 설계 변경 반영 |

**Architect 4차 리뷰 결론**: "조건부 APPROVE — 구현 착수 가능, 5차 설계 라운드는 불필요, 위 항목은 국소 수정으로 충분." v5는 그 국소 수정을 전부 반영했다. Critic의 v3~v4 라인 검토가 아직 없었으므로(3차 라운드는 CRITICAL 때문에 Architect 단독으로 조기 반려), 최종 확인으로 Critic을 이번 v5에 대해 실행한다.

## 9. Changelog (v5 → v6, 최종) — Critic 5차(최종) 리뷰 반영

**Critic 5차 판정**: ITERATE("6차 설계 라운드가 아니라 문서 보완 1회로 닫힌다"). CRITICAL 1건·MAJOR 5건 발견, 전부 국소 수정으로 해소 가능하다고 명시.

| # | 항목 | v5 | v6 | 근거 |
|---|---|---|---|---|
| 1(CRITICAL) | private AKS API 서버 DNS 해석 | 전제조건 없음 | §2.6에 DNS 해석 3항 전제조건 신설 + §4 Consequences 추가 | Critic 최종 — `aks-cluster`의 private DNS zone이 노드 VNet에만 링크됨(MS Learn 실측), Driver 1의 vWAN hub-spoke에서 실제로 발생 |
| 2(MAJOR-1) | §5 assertion 4 | `source_address_prefixes == var.ssh_ingress_cidrs`(타입 불일치로 항상 false) | `== toset(var.ssh_ingress_cidrs)` | Critic 최종 — provider 스키마 실측(`source_address_prefixes`는 Set), `tofu console` 실측으로 항상 false 확인 |
| 3(MAJOR-1 부수) | §5 assertion 3·12 | 카운트 표현 모호 | `length(...)` 형식 명시 | Critic 최종 — `[0]` 인덱스 참조 시 개수 0에서 index out of range |
| 4(MAJOR-2) | 확장 리소스 | "가칭", Required 인자 미명시 | 리소스명 확정, 5개 인자 전부 명시, `type_handler_version` 핀 정책 결정(추종형) | Critic 최종 — §1 Principle 5 3라운드 연속 자기위반 |
| 5(MAJOR-3) | §2.6 게이트 참조 | v3 이전 게이트(`ssh_ingress_cidrs`) 그대로 stale | `entra_ssh_login_enabled`로 정정 | Critic 최종 — v4에서 이미 철회된 게이트가 §2.6에만 잔존, §2.3/§5-10과 모순 |
| 6(MAJOR-4) | `identity_client_id` | 무조건 필수(근거로 `ami_id` 오인용) | 조건부 필수(기본 `null`, `aks_entra_rbac_enabled` 교차 validation) | Critic 최종 — `ami_id`는 무조건 소비, `identity_client_id`는 조건부 소비라 `eks_cluster_arn` 선례가 맞는 유비 |
| 7(MAJOR-5) | SSH 경로 role assignment | Run Command만 액션 문자열까지 명시, SSH는 미언급 | §2.3에 「전제 role assignment」 신설(4종 역할·크로스 RG 스코프·클라이언트 요구) | Critic 최종 — `aks-cluster`의 「신원 순서 의존」과 같은 해상도 요구 |

**남은 MINOR·What's Missing 항목**(Critic: "APPROVE를 막지 않는다", 구현 착수 후 확인 목록으로 이월): NIC/PIP/NSG 본체의 Required 인자 상세, kubeconfig의 public/private FQDN 선택 영향, cloud-init 부분 실패 정책(`set -e` 여부), `os_disk_size_gb` 미달 시 진단 경로, `admin_ssh_public_key` 형식 검증 기각 여부 명문화, §2.3B 5종 변수의 배선 assertion, `entra_ssh_login_enabled=true`인데 아웃바운드가 없을 때 `tofu apply` 재시도 수렴 여부(배포 안 하는 저장소 한계로 미검증 유지).
