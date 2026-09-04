# aks-workbench

private AKS 클러스터의 운영 지점(kubectl·helm·argocd·az CLI·kubelogin이 설치된 지속적
작업대). AWS `modules/aws/workbench`의 Azure 대응 모듈이다.

이 모듈은 identity·role assignment·서브넷·리소스 그룹을 만들지 않는다. 전부 입력으로만
받는다 — `aks-cluster`와 같은 경계 원칙이다(`docs/decisions.md`「Azure 워크벤치
(aks-workbench)」ADR 참조).

## Usage

```hcl
module "vnet" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/azure/vnet?ref=vnet-vX.Y.Z"

  naming               = { workload = "demo", env = "prd", region_code = "krc" }
  resource_group_name  = azurerm_resource_group.this.name
  location             = azurerm_resource_group.this.location
  address_space         = ["10.70.0.0/24"]

  subnet_groups = {
    "workbench" = { address_prefixes = ["10.70.0.0/27"], nat_routed = true }
  }
}

# 이 모듈은 identity를 만들지 않는다(「신원」 절 참조). 실제 배포에서는 별도 bootstrap
# 계층이 이 리소스를 만든다.
resource "azurerm_user_assigned_identity" "workbench" {
  name                = "id-demo-prd-krc-workbench-01"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}

module "aks_workbench" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/azure/aks-workbench?ref=aks-workbench-vX.Y.Z"

  naming               = { workload = "demo", env = "prd", region_code = "krc" }
  resource_group_name  = azurerm_resource_group.this.name
  location             = azurerm_resource_group.this.location

  subnet_id    = module.vnet.subnet_ids_by_group["workbench"]
  identity_id  = azurerm_user_assigned_identity.workbench.id

  # 이 값이 채워져 있는 것이 일상 운영이 가능한 상태다(「접속 모델」 절 참조).
  ssh_ingress_cidrs     = ["203.0.113.0/32"]
  admin_ssh_public_key  = file("~/.ssh/workbench_ed25519.pub")

  source_image_reference = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "24.04.202601010"
  }

  kubectl_version = "v1.35.7"
  helm_version    = "v3.21.3"
}
```

`vX.Y.Z`는 자리표시자다. 실제 최신 태그는 `git tag -l 'aks-workbench-v*'`로 확인한다.
착수 템플릿은 [`examples/basic/`](examples/basic/)를 참조한다.

## 접속 모델 — SSH가 일상 경로, Run Command가 브레이크글래스

AWS SSM Session Manager는 "완전한 대화형 + 진짜 인바운드 0"을 동시에 주는 유일한
수단이라 AWS `workbench`의 일상 운영 경로 그 자체였다. Azure에는 이 조합을 주는
서비스가 없다 — Run Command(이 모듈이 리소스를 만들지 않는다, VM Agent 기본 활성)는
인바운드 0이지만 출력 4,096바이트·90분 타임아웃·비대화형·취소불가라는 확정된 제약
때문에 일상 운영(kubectl 진단·helm install·argocd 대화형 세션)을 감당하지 못한다.

**이 모듈의 일상 운영 경로는 SSH(`ssh_ingress_cidrs`)이고, Run Command는 SSH 경로
자체가 없을 때의 브레이크글래스 진단 수단이다.**

| 프로파일 | `ssh_ingress_cidrs` | `entra_ssh_login_enabled` | `public_ip_enabled` |
|---|---|---|---|
| VPN/ExpressRoute를 이미 가진 소비자 | `[vpn_pool_cidr]` | `true`(기본) | `false` |
| 레퍼런스(VPN 미보유) | `["<사무실 공인 IP>/32"]` | `true`(기본) | `true` |
| 순수 Run Command 전용(네트워크 경로 자체가 없는 격리 환경) | `[]`(명시) | `false`(명시) | `false` |

⚠️ 마지막 프로파일은 **두 값을 한 세트로** 지정해야 한다. `ssh_ingress_cidrs = []`만
지정하고 `entra_ssh_login_enabled`를 기본값(`true`)으로 두면, Entra SSH 확장이
여전히 아웃바운드 의존(아래「아웃바운드」절)을 만든다 — 실제로는 못 쓰는 경로인데
의존만 남는다.

## NSG — 명시적 Deny로 플랫폼 기본 규칙을 실제로 덮는다

Azure NSG의 플랫폼 기본 규칙(`AllowVNetInBound`, priority 65000)은 커스텀 규칙이
0개여도 같은 VNet·피어링된 VNet·연결된 온프레미스 전체에서 22번을 열어 둔다 —
"커스텀 규칙 0개 = 인바운드 0"이라는 AWS Security Group 감각을 그대로 옮기면 거짓
명제가 된다.

이 모듈이 실제로 내세우는 검증 가능한 주장은 "인바운드 0"이 아니라 **"명시적 Deny
바닥(priority 4096)을 깐 SSH 운영 지점 — 규칙을 하나도 안 열면 정말 아무것도 안
열리고, 열면 그 CIDR만 열린다"**이다.

- `AllowSsh`(priority 100): `ssh_ingress_cidrs`가 비어 있지 않을 때만 만들어진다.
- `DenyAllInbound`(priority 4096): 항상 만들어진다. 플랫폼 기본 규칙(65000·65001)을
  실제로 덮는다.
- `azurerm_network_interface_security_group_association`으로 NIC에 명시적으로
  붙인다 — azurerm 3.0+는 `network_interface`에 `network_security_group_id` 인자가
  없어 이 연결 리소스가 유일한 부착 수단이다. 이게 없으면 NSG를 아무리 정교하게
  만들어도 무효하다.

⚠️ 이 Deny는 플랫폼 인프라 통신(DHCP·DNS·IMDS·health, `168.63.129.16`·
`169.254.169.254`)은 막지 않는다 — 그 통신은 서비스 태그를 명시하지 않는 한 NSG
적용 대상 밖이다(MS Learn). Run Command·VM Agent·boot diagnostics는 이 Deny와
무관하게 동작한다.

## 아웃바운드 — 제한하지 않는다, 전제조건으로만 문서화

Azure NSG의 플랫폼 기본 규칙(`AllowInternetOutBound`)이 이미 아웃바운드를 전부
허용한다. 이 모듈은 아웃바운드 변수를 두지 않는다 — 443만 허용하는 규칙을 "추가"해도
이미 열려 있는 65001 위에 얹히는 장식일 뿐이다.

이 VM이 정상 동작하려면 다음 443/tcp 아웃바운드가 실제로 도달해야 한다(NSG는 안
막지만, 서브넷에 아웃바운드 경로 자체가 없으면 막힌다 — `vnet` 모듈의
`nat_routed`/`default_outbound_access_enabled` 참조):

| 용도 | 엔드포인트 | 게이트 |
|---|---|---|
| Entra SSH 확장 | `packages.microsoft.com`·`login.microsoftonline.com`·`pas.windows.net`(443) + IMDS(`169.254.169.254`) | `entra_ssh_login_enabled = false`면 미생성 |
| `az aks get-credentials`/Run Command 결과 반환 | `AzureCloud` 서비스 태그 | `az_cli_version != null`일 때 |
| 도구 다운로드 | `dl.k8s.io`·`get.helm.sh`·`github.com` | 각 도구 버전 변수가 null이 아닐 때 |

### private AKS API 서버로의 DNS 해석 — 이 모듈이 검증하지 않는 전제조건

`aks-cluster` 모듈은 `private_cluster_enabled` 기본값이 `true`이고
`private_dns_zone_id`를 변수로 노출하지 않는다 — AKS가 만드는 system-managed
private DNS zone(`privatelink.<region>.azmk8s.io`)은 **노드가 속한 VNet에만
링크된다**(MS Learn). `az login`·`az aks get-credentials`·
`kubelogin convert-kubeconfig`는 전부 ARM 호출이라 이 문제와 무관하게 성공하고
kubeconfig도 만들어진다 — **실패는 운영자가 처음 `kubectl get nodes`를 칠 때만
드러난다.** cloud-init은 이미 성공을 보고한 뒤라 아래「부팅 후 확인」절의 boot
diagnostics도 이 실패를 못 잡는다.

1. workbench의 `subnet_id`가 AKS 노드와 **같은 VNet**에 있으면 별도 조치가 필요 없다.
2. 다른 VNet(스포크)에 있다면, 그 VNet에 대한
   `azurerm_private_dns_zone_virtual_network_link`를 소비 레포가 별도로 만들어야
   한다(`Private DNS Zone Contributor` 필요 — `identity_id`를 만드는 bootstrap
   계층과 같은 층위의 작업이다).
3. 커스텀 DNS 서버를 쓰는 스포크라면 `168.63.129.16`(Azure DNS)으로의 conditional
   forwarder가 추가로 필요하다.

이 모듈은 이 DNS 도달성을 검증하지 않는다 — `aks-cluster`의 신원 순서 의존과 같은
성격의, plan에서 잡을 수 없는 전제조건이다.

## 신원 — dual identity, `identity_id`·`identity_client_id`는 같은 신원의 다른 속성

```hcl
identity {
  type         = "SystemAssigned, UserAssigned"
  identity_ids = [var.identity_id]
}
```

- `identity_id`(필수) — user-assigned managed identity의 리소스 ID.
  `az login --identity --resource-id`가 이 형태를 요구한다.
- `identity_client_id`(`aks_entra_rbac_enabled = true`일 때만 필수) — 같은 identity의
  client ID. `kubelogin convert-kubeconfig -l msi --client-id`가 `az login`과 별개
  CLI라 다른 인자 체계(client ID)를 요구한다. 둘 다 bootstrap이 만든
  `azurerm_user_assigned_identity` 리소스의 서로 다른 attribute(`.id`/`.client_id`)라
  같은 리소스를 참조하면 불일치가 구조적으로 불가능하다.
- system-assigned 절반은 이 모듈이 선택한 것이 아니라 **Entra SSH 확장이 강제한다**
  (MS Learn: system-assigned managed identity가 없으면 exit code 22로 실패). 그
  확장을 `entra_ssh_login_enabled = false`로 끄지 않는 한 항상 필요하다.

### 전제 role assignment — 이 모듈이 만들지 않지만, 무엇이 필요한지는 명시한다

| 역할 | 스코프 | 대상 | 용도 |
|---|---|---|---|
| `Virtual Machine Administrator Login`(sudo) 또는 `Virtual Machine User Login`(일반) | **VM이 아니라 그 VM·NIC·공용 IP·NSG를 포함하는 리소스 그룹**(MS Learn) | 로그인할 사람/그룹의 Entra 계정 | Entra SSH로 로그인 |
| `Azure Kubernetes Service Cluster User Role` | 대상 AKS 클러스터 | `identity_id` | kubeconfig 다운로드 |
| `Azure Kubernetes Service RBAC Reader`/`Writer`/`Admin` 등 | 대상 AKS 클러스터 | 로그인하는 사람의 Entra 계정(또는 `identity_id`의 msi 경로) | `aks_entra_rbac_enabled = true`일 때 K8s API 레벨 권한 |

⚠️ 구독 Owner·Contributor 역할은 `Virtual Machine Administrator/User Login`을
자동으로 주지 않는다(MS Learn: "의도적으로 분리·감사된 설계") — "권한 있는데 왜
로그인이 안 되지"로 부딪히는 지점이다.

클라이언트 측(운영자 로컬 PC)에는 `az extension add --name ssh`(SSH 확장)가
필요하다. 이 모듈이 강제할 수 없는 소비자 환경 요구다.

## 인증 자료 — 로컬 계정과 Entra SSH는 완전히 별개 경로

- `admin_ssh_public_key`(필수) — 로컬 관리 계정(`admin_username`)의 SSH 공개키. Azure는
  VM 생성 시 비밀번호 또는 SSH 키 중 하나를 강제한다(플랫폼 요구) — 이 모듈은 그중
  SSH 키를 선택했다(우리 선택). private key는 이 모듈이 전혀 다루지 않는다.
- Entra ID SSH(`entra_ssh_login_enabled`, 기본 `true`)는 이 로컬 계정과 **완전히
  별개**로, 사람이 자기 Entra 계정으로 직접 SSH 로그인하게 해준다 — AWS SSM의
  IAM 신원 기반 세션과 개념적으로 대응한다. 로그인한 사람이 sudo를 받을지는 위
  role assignment 표가 결정하지, 로컬 계정 이름과 무관하다.

## AKS 연동 — 옵트인, kubeconfig 부트스트랩만 한다

`aks_cluster_name`·`aks_resource_group_name`(함께 주거나 함께 비운다)이 채워지면
`custom_data`가 `az aks get-credentials`로 kubeconfig를 만든다.
`aks_entra_rbac_enabled = true`면 `kubelogin`(GitHub 릴리스 zip, `kubelogin_version`
필수 — 아래 「신원」절)을 설치하고 `kubelogin convert-kubeconfig -l msi`로 그
kubeconfig를 변환하는 단계가 추가된다 — 이때 `identity_client_id`도 함께 필요하다.

이 단계는 root 컨텍스트(cloud-init)에서 실행돼 정본은 `/root/.kube/config`에 생긴다.
이 VM에 실제로 로그인하는 사람은 root가 아니므로, `admin_username`(부팅 시점에
이미 존재가 보장되는 유일한 로컬 계정)의 홈에는 사용자별 사본(`~/.kube/config`,
0600, 그 계정 소유)을 직접 넣는다.

⛔ **Entra SSH로 로그인하는 계정(Administrator Login이든 User Login이든)에는 아무것도
자동으로 안 준다 — `/etc/skel`을 쓰지 않는다.** AWS `workbench` 모듈은
(`modules/aws/workbench/user-data.sh.tftpl`「kubeconfig」절) 로그인 시점에야 동적으로
생기는 계정에 `/etc/skel`로 kubeconfig를 미리 넘겨 두는데, 이 패턴을 그대로 옮기면
안 된다 — AWS의 SSM 접근은 IAM 정책 하나로만 통제돼(OS 레벨 2단계 로그인 역할 구분이
없다) skel이 안전하지만, 이 모듈은 「전제 role assignment」절 표에 `Virtual Machine
Administrator Login`(sudo)·`Virtual Machine User Login`(비-sudo) 두 단계를 명시해
뒀다. skel로 자동 배포하면 User Login만 받은 사람도 sudo 없이 이 VM의 공유
`identity_id` 권한(kubeconfig)을 물려받아 그 두 역할을 가르는 경계 자체가 무너진다
(2026-09-04 code-review로 발견·정정 — 첫 시도가 정확히 이 실수를 냈었다).

Administrator Login을 가진 사람이 Entra SSH로 로그인했다면 이미 sudo가 있으므로
`sudo cp /root/.kube/config ~/.kube/config && sudo chown $(id -u):$(id -g)
~/.kube/config`로 스스로 가져갈 수 있다 — 이 한 걸음이 이 모듈이 대신 자동화하지
않는 의도된 마찰이다. User Login만 가진 사람은 애초에 이 모듈이 AKS 접근권을
주기로 한 대상이 아니다.

kubeconfig 부트스트랩(`az aks get-credentials`, 필요시 `kubelogin` 설치·변환)이 실패하면
`admin_username` 사본 배포 자체를 건너뛴다 — 변환 안 된 stale kubeconfig가 조용히 퍼지는 것보다
아예 없는 편이 안전하다(부팅 로그에 실패 원인이 남는다, 「부팅 후 확인」절).

이 모듈은 role assignment를 만들지 않는다 — `aks-cluster`가 `identity_id`로 받는
권한과 같은 이유(`docs/decisions.md`「Azure 컨테이너 (aks-cluster)」ADR)로, 위
「전제 role assignment」 표의 권한은 소비 레포의 bootstrap 계층이 부여한다.

## 이미지·디스크

`source_image_reference`는 필수 입력이고 `version = "latest"`를 거부한다(재현성
보장). Ubuntu LTS를 권장한다 — **Entra SSH의 공식 지원 배포판 목록에 Amazon Linux
계열이 없다**는 것이 결정적 근거다(AlmaLinux·Azure Linux·Debian·openSUSE·Oracle·
RHEL·Rocky·SLES·Ubuntu만 지원).

## 부팅 후 확인

`custom_data`는 provider 스키마상 ForceNew다 — 부트스트랩 실패 시 유일한 복구
경로는 VM 재생성이다. 실패 진단 순서:

1. `boot_diagnostics` 콘솔 로그(Azure Portal 또는 `az vm boot-diagnostics
   get-boot-log`) — VM이 아예 못 뜬 경우.
2. `/var/log/cloud-init-output.log` — `custom_data` 스크립트 실행 로그. `az version`
   출력이 여기 남아 `az_cli_version` 위반(하한 미달) 여부를 사후 확인할 수 있다.
3. `cloud-init status --wait`로 부트스트랩이 실제로 끝났는지 확인한 뒤, 도구별 존재
   확인(`kubectl version --client`·`helm version`·`argocd version --client` 등).

⚠️ 이 로그들은 **DNS 해석 실패**(위 절 참조)나 **아웃바운드 결핍으로 인한 Entra SSH
확장 provisioning 실패**는 잡지만, `kubectl get nodes`가 조용히 실패하는 것 자체는
잡지 않는다 — cloud-init은 그 명령을 실행하지 않기 때문이다.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 5.4.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_linux_virtual_machine.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine) | resource |
| [azurerm_network_interface.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_network_interface_security_group_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_security_group_association) | resource |
| [azurerm_network_security_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_network_security_rule.deny_all_inbound](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_network_security_rule.ssh_allow](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_public_ip.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_virtual_machine_extension.aad_ssh_login](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_ssh_public_key"></a> [admin\_ssh\_public\_key](#input\_admin\_ssh\_public\_key) | 로컬 관리 계정(admin\_username)의 SSH 공개키. 기본값이 없다 = 필수 입력이다.<br/>private key는 이 모듈이 전혀 다루지 않는다 — 소비자가 자기 공개키만 넘긴다.<br/><br/>⚠️ Azure는 VM 생성 시 비밀번호 또는 SSH 키 중 하나를 강제한다(플랫폼 요구). 이<br/>모듈이 SSH 키만 받는 것은 그중 하나를 고른 선택이다. | `string` | n/a | yes |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | 로컬 관리 계정 사용자명. admin\_ssh\_key.username(provider Required)과 VM 로컬 계정<br/>이름에 공용으로 쓰인다.<br/><br/>Entra ID SSH(entra\_ssh\_login\_enabled)로 로그인하는 사람은 이 로컬 계정과 완전히<br/>별개의 자기 신원으로 들어온다 — 이 값은 사실상 브레이크글래스 계정 이름표일 뿐이라<br/>고정값으로 충분하고, 조직 표준이 있으면 바꿀 수 있게 변수로만 열어 둔다.<br/><br/>⚠️ cloud-init.sh.tftpl이 이 값을 이스케이프 없이 셸 명령에 그대로 보간한다<br/>(kubeconfig 사용자별 사본을 만드는 getent/install 호출) — 아래 validation이<br/>Linux 계정명 관례(영숫자·밑줄·하이픈, 문자/밑줄로 시작)만 허용해 셸 메타문자<br/>주입을 plan 단계에서 막는다(2026-09-04 code-review 발견). | `string` | `"azureuser"` | no |
| <a name="input_aks_cluster_name"></a> [aks\_cluster\_name](#input\_aks\_cluster\_name) | kubeconfig를 생성할 AKS 클러스터 이름. null이면 kubeconfig를 만들지 않는다(az CLI<br/>설치 여부와도 무관하게 그 단계를 건너뛴다).<br/><br/>⚠️ aks\_resource\_group\_name과 함께 주거나 함께 비운다(아래 validation). | `string` | `null` | no |
| <a name="input_aks_entra_rbac_enabled"></a> [aks\_entra\_rbac\_enabled](#input\_aks\_entra\_rbac\_enabled) | 대상 AKS 클러스터가 Entra RBAC(aks-cluster 모듈의 entra\_admin\_group\_object\_ids 옵트인)를<br/>쓰는지. true면 kubelogin convert-kubeconfig -l msi로 kubeconfig를 변환하는 단계가<br/>추가된다 — 로컬 계정 전용 클러스터에는 이 변환이 불필요하다.<br/><br/>true면 aks\_cluster\_name·aks\_resource\_group\_name·identity\_client\_id·kubelogin\_version<br/>넷 다 값이 있어야 한다(kubelogin 변환 명령 자체가 앞의 셋을 요구하고, 그 명령을<br/>실행할 kubelogin 바이너리 설치에 버전 핀이 필요하다 — 아래 validation). | `bool` | `false` | no |
| <a name="input_aks_node_viewer_version"></a> [aks\_node\_viewer\_version](#input\_aks\_node\_viewer\_version) | 설치할 aks-node-viewer 버전(예: "v0.0.2-alpha"). null이면 설치하지 않는다.<br/><br/>⚠️ Azure/aks-node-viewer는 eks-node-viewer의 공식 fork이지만 2024-11 이후 갱신이<br/>없는 alpha 단계다(리서치 확인) — 프로덕션 의존으로 삼지 말 것. 설치 실패도<br/>부팅을 막지 않는다(다른 도구 슬롯과 동일). | `string` | `null` | no |
| <a name="input_aks_resource_group_name"></a> [aks\_resource\_group\_name](#input\_aks\_resource\_group\_name) | aks\_cluster\_name이 속한 리소스 그룹. null이면 kubeconfig를 만들지 않는다.<br/><br/>⚠️ aks\_cluster\_name과 함께 주거나 함께 비운다. | `string` | `null` | no |
| <a name="input_argocd_version"></a> [argocd\_version](#input\_argocd\_version) | 설치할 argocd CLI 버전(예: "v3.5.0"). null이면 설치하지 않는다. | `string` | `null` | no |
| <a name="input_az_cli_version"></a> [az\_cli\_version](#input\_az\_cli\_version) | 설치할 az CLI 버전(apt 패키지 버전 문자열 전체, codename 포함 — 예:<br/>"2.72.0-1~noble"). null이면 az CLI를 설치하지 않는다.<br/><br/>⚠️ 2.72.0 이상을 권장한다. az login --identity --resource-id는 az CLI 2.69.0부터<br/>지원되지만, --username으로 UAMI를 지정하는 옛 경로가 아직 살아있던 2.69~2.72<br/>구간의 혼선을 피하기 위해 그 이후 버전으로 하한을 둔다.<br/><br/>⚠️ 이 모듈은 codename을 유도하지 않는다(닫힌 매핑 금지) — 버전 문자열 전체를 그대로<br/>apt에 넘긴다. source\_image\_reference가 정하는 배포판·codename과 정합하는 값을<br/>소비 루트가 함께 관리한다. | `string` | `null` | no |
| <a name="input_entra_ssh_login_enabled"></a> [entra\_ssh\_login\_enabled](#input\_entra\_ssh\_login\_enabled) | Entra ID 계정으로 SSH 로그인하는 AADSSHLoginForLinux 확장을 만들지 여부. 기본<br/>true(주 인증 경로) — ssh\_ingress\_cidrs(네트워크 도달성)와는 직교하는 관심사라 별도<br/>변수로 분리했다(둘 다 채워야 실제로 Entra SSH를 쓸 수 있다).<br/><br/>이 확장은 apply 시점에 packages.microsoft.com·login.microsoftonline.com·<br/>pas.windows.net(전부 443/tcp) + IMDS로 나가는 아웃바운드를 요구한다(MS Learn<br/>「Network」절). 순수 격리 환경(아웃바운드 자체가 없는 배포)에서는 false로 꺼서 그<br/>의존 자체를 없앤다 — 이때는 ssh\_ingress\_cidrs = []와 한 세트로 지정해야 "일상 운영<br/>불가"라는 결과를 소비자가 plan 시점에 이미 알고 있는 상태로 만든다(README 참조).<br/><br/>⚠️ true로 두면 identity에 System-assigned가 강제로 필요하다(이 확장의 요구사항,<br/>exit code 22) — main.tf의 identity 블록이 이 게이트와 무관하게 항상<br/>"SystemAssigned, UserAssigned"인 이유다. | `bool` | `true` | no |
| <a name="input_helm_version"></a> [helm\_version](#input\_helm\_version) | 설치할 helm 버전(예: "v3.21.3"). null이면 설치하지 않는다. | `string` | `null` | no |
| <a name="input_identity_client_id"></a> [identity\_client\_id](#input\_identity\_client\_id) | identity\_id와 같은 identity의 client ID(GUID). kubelogin의 msi 모드가<br/>`--client-id`로 요구한다(az login과 별개 CLI라 인자 체계가 다르다).<br/><br/>aks\_entra\_rbac\_enabled = true일 때만 소비된다(kubelogin convert-kubeconfig 슬롯) — 그<br/>외에는 조건부로 무시되는 값이라 기본값을 null로 둔다. AKS 연동 없이 워크벤치만 쓰는<br/>소비자는 이 값을 채울 필요가 없다(아래 aks\_entra\_rbac\_enabled 교차 validation 참조). | `string` | `null` | no |
| <a name="input_identity_id"></a> [identity\_id](#input\_identity\_id) | user-assigned managed identity의 리소스 ID. aks-cluster와 같은 경계 원칙(축3) —<br/>이 모듈은 identity도 role assignment도 만들지 않는다. custom\_data에서<br/>`az login --identity --resource-id`로 쓴다. | `string` | n/a | yes |
| <a name="input_krew_plugins"></a> [krew\_plugins](#input\_krew\_plugins) | krew로 설치할 플러그인 목록. krew\_version이 null이면 무시된다.<br/>닫힌 열거가 아니다 — 고객사가 다른 세트를 원하면 이 변수로 바꾼다. | `list(string)` | <pre>[<br/>  "ctx",<br/>  "ns",<br/>  "neat",<br/>  "rbac-tool",<br/>  "view-secret",<br/>  "whoami"<br/>]</pre> | no |
| <a name="input_krew_version"></a> [krew\_version](#input\_krew\_version) | 설치할 krew(kubectl 플러그인 관리자) 버전(예: "v0.5.0"). null이면 설치하지 않는다.<br/>kubectl\_version이 null이면 이 값도 무시된다. | `string` | `null` | no |
| <a name="input_kubectl_version"></a> [kubectl\_version](#input\_kubectl\_version) | 설치할 kubectl 버전(예: "v1.35.7"). null이면 설치하지 않는다. | `string` | `null` | no |
| <a name="input_kubelogin_version"></a> [kubelogin\_version](#input\_kubelogin\_version) | 설치할 kubelogin(Azure/kubelogin) 버전(예: "v0.2.19", "v" 접두사 포함). null이면<br/>설치하지 않는다 — aks\_entra\_rbac\_enabled = true일 때는 필수(위 validation).<br/><br/>kubectl\_version 등과 달리 기본값을 null로만 두지 않고 aks\_entra\_rbac\_enabled와<br/>교차 검증하는 이유: 이 값이 없으면 kubelogin 바이너리 자체가 없어<br/>`kubelogin convert-kubeconfig -l msi`가 "command not found"로 실패하는데, 스크립트에<br/>set -e가 없어 그 실패가 조용히 넘어가고 변환 안 된 stale kubeconfig가 그대로<br/>배포되는 문제가 있었다(2026-09-04 aks-reference-infra 실배포 code-review로 발견). | `string` | `null` | no |
| <a name="input_location"></a> [location](#input\_location) | 리소스를 배치할 Azure 리전. | `string` | n/a | yes |
| <a name="input_naming"></a> [naming](#input\_naming) | name 인자 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로<br/>소비자는 약어를 직접 타이핑하지 않는다.<br/>예: {workload = "demo", env = "prd", region\_code = "krc"} → vm-demo-prd-krc-workbench-01 | <pre>object({<br/>    workload    = string<br/>    env         = string<br/>    region_code = string<br/>  })</pre> | n/a | yes |
| <a name="input_os_disk_caching"></a> [os\_disk\_caching](#input\_os\_disk\_caching) | OS 디스크 캐싱 모드. | `string` | `"ReadWrite"` | no |
| <a name="input_os_disk_encryption_set_id"></a> [os\_disk\_encryption\_set\_id](#input\_os\_disk\_encryption\_set\_id) | OS 디스크 암호화에 쓸 Disk Encryption Set ID. null이면 플랫폼 관리형 키를 쓴다<br/>(암호화 자체는 끌 수 없다 — CMK 사용 여부만 선택). | `string` | `null` | no |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | OS 디스크 크기(GiB). null이면 이미지 기본 크기를 그대로 쓴다.<br/>⚠️ 기본값을 두지 않는다 — 이미지 기본 디스크보다 작게 줄 수 없다는 provider 제약이<br/>있어, 이미지를 정하는 소비 루트가 같이 정하는 게 맞다(모듈이 닫힌 가정을 갖지 않는다). | `number` | `null` | no |
| <a name="input_os_disk_storage_account_type"></a> [os\_disk\_storage\_account\_type](#input\_os\_disk\_storage\_account\_type) | OS 디스크 스토리지 계정 종류. | `string` | `"StandardSSD_LRS"` | no |
| <a name="input_public_ip_enabled"></a> [public\_ip\_enabled](#input\_public\_ip\_enabled) | 공용 IP를 만들지 여부. VPN/ExpressRoute로 이미 사설 경로가 있는 소비자는 false로 두고<br/>ssh\_ingress\_cidrs에 그 사설 대역만 채운다. | `bool` | `false` | no |
| <a name="input_purpose"></a> [purpose](#input\_purpose) | name 인자의 purpose 토큰. | `string` | `"workbench"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | 이 모듈이 만드는 전 리소스를 배치할 리소스 그룹. | `string` | n/a | yes |
| <a name="input_serial"></a> [serial](#input\_serial) | name 인자의 일련번호 토큰. | `string` | `"01"` | no |
| <a name="input_source_image_reference"></a> [source\_image\_reference](#input\_source\_image\_reference) | OS 이미지 참조. 기본값이 없다(필수 입력) — ami\_id와 같은 계약이다. 리전·세대 갱신은<br/>소비 루트가 소유한다. Ubuntu LTS를 권장한다(Entra SSH 지원 배포판 목록에 Amazon<br/>Linux 계열이 없다는 것이 결정적 근거 — README 참조). | <pre>object({<br/>    publisher = string<br/>    offer     = string<br/>    sku       = string<br/>    version   = string<br/>  })</pre> | n/a | yes |
| <a name="input_ssh_ingress_cidrs"></a> [ssh\_ingress\_cidrs](#input\_ssh\_ingress\_cidrs) | SSH(22/tcp) 인바운드를 허용할 CIDR 목록. 소스 무관 — Bastion 서브넷 CIDR·P2S VPN<br/>풀·ExpressRoute 대역·사무실 공인 IP 전부 이 값으로 받는다.<br/><br/>이 값이 비어있지 않은 것이 일상 운영이 가능한 상태다. Azure NSG는 규칙을 하나도 안<br/>만들어도 플랫폼 기본 규칙(AllowVNetInBound)이 같은 VNet·피어링·온프레미스 전체에<br/>22번을 열어두므로, 이 모듈은 명시적 Deny(priority 4096, main.tf 참조)로 그 기본<br/>규칙을 실제로 덮는다 — "인바운드 0"은 규칙 개수가 아니라 그 Deny의 존재로 성립한다.<br/><br/>⚠️ 기본값이 없다(필수 입력) — ami\_id와 같은 계약이다. "진짜 인바운드 0"이 성립하는<br/>유일한 구성(빈 리스트)이 곧 일상 운영이 불가능한 구성이기도 해서, 침묵하는 기본값에<br/>맡기면 이 모듈의 안전성 주장이 아무도 쓰지 않을 설정에서만 참이 된다. 빈 리스트를<br/>원하면 ssh\_ingress\_cidrs = []를 명시적으로 써야 한다(entra\_ssh\_login\_enabled = false와<br/>한 세트로 — 아래 변수 설명 참조). | `list(string)` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | workbench VM을 놓을 서브넷. AWS workbench의 subnet\_id(private 서브넷 전제, AZ 분산<br/>불필요)와 같은 형태다 — workbench는 1대이므로 리스트를 받아 내부에서 고르지 않는다. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | 이 모듈이 만드는 전 리소스에 연동할 태그. Azure는 provider 한 곳에서 거버넌스 태그를<br/>주입할 수 없어(docs/conventions.md「Azure 강제 방식」1번) 모듈이 리소스마다 명시로 넘긴다. | `map(string)` | `{}` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | VM 크기(SKU). | `string` | `"Standard_B2s"` | no |
| <a name="input_workbench_enabled"></a> [workbench\_enabled](#input\_workbench\_enabled) | kill switch(파괴 방향). false면 이 모듈의 전 리소스를 파기한다.<br/>false일 때 스칼라 출력은 전부 null이 된다.<br/><br/>⚠️ AWS workbench와 동일하게 삭제 보호 대상이 아니다 — 수시 생성·파기가 정상 운용이다. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_workbench_nsg_id"></a> [workbench\_nsg\_id](#output\_workbench\_nsg\_id) | workbench NIC에 붙은 NSG의 리소스 ID. workbench\_enabled = false면 null이다. |
| <a name="output_workbench_private_ip"></a> [workbench\_private\_ip](#output\_workbench\_private\_ip) | workbench VM의 사설 IP. workbench\_enabled = false면 null이다. |
| <a name="output_workbench_public_ip"></a> [workbench\_public\_ip](#output\_workbench\_public\_ip) | workbench VM의 공용 IP. public\_ip\_enabled = false거나 workbench\_enabled = false면<br/>null이다. |
| <a name="output_workbench_system_identity_principal_id"></a> [workbench\_system\_identity\_principal\_id](#output\_workbench\_system\_identity\_principal\_id) | VM의 system-assigned 신원 Principal ID(감사용) — identity 블록은 항상<br/>"SystemAssigned, UserAssigned"이므로 entra\_ssh\_login\_enabled 값과 무관하게 존재한다.<br/>workbench\_enabled = false면 null이다. |
| <a name="output_workbench_vm_id"></a> [workbench\_vm\_id](#output\_workbench\_vm\_id) | workbench VM의 리소스 ID. workbench\_enabled = false면 null이다. |
<!-- END_TF_DOCS -->
