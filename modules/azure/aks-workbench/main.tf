# private AKS 클러스터의 운영 지점 — NIC · NSG(명시적 Deny) · Linux VM · Entra SSH 확장.
#
# 이 모듈은 identity·role assignment·서브넷·리소스 그룹을 만들지 않는다(aks-cluster와 같은
# 경계 원칙). SSH가 일상 운영 경로이고 Run Command(이 모듈이 리소스를 만들지 않는다 — VM
# Agent 기본 활성)는 그 경로가 없을 때의 브레이크글래스 진단 수단이다.
#
# 계약: docs/module-catalog.md

locals {
  enabled = var.workbench_enabled

  # name 인자의 중간 토큰. 소비자가 약어를 타이핑하지 않도록 모듈이 조합한다.
  name_mid    = "${var.naming.workload}-${var.naming.env}-${var.naming.region_code}"
  name_suffix = "${var.purpose}-${var.serial}"

  vm_name  = "vm-${local.name_mid}-${local.name_suffix}"
  nic_name = "nic-${local.name_mid}-${local.name_suffix}"
  # nsg는 서브넷 그룹 키가 아니라 이 모듈 자신의 purpose 토큰을 쓴다 — NIC 레벨 NSG라
  # 서브넷 그룹 키가 없기 때문이다(docs/naming/abbreviations/azure.md의 nsg 의미론 확장 참조).
  nsg_name = "nsg-${local.name_mid}-${local.name_suffix}"
  pip_name = "pip-${local.name_mid}-${local.name_suffix}"
}

resource "azurerm_public_ip" "this" {
  count = local.enabled && var.public_ip_enabled ? 1 : 0

  name                = local.pip_name
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_network_interface" "this" {
  count = local.enabled ? 1 : 0

  name                = local.nic_name
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip_enabled ? azurerm_public_ip.this[0].id : null
  }

  tags = var.tags
}

resource "azurerm_network_security_group" "this" {
  count = local.enabled ? 1 : 0

  name                = local.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# 규칙 우선순위(낮을수록 먼저 평가, provider 허용 범위 100~4096):
#   100  : ssh_ingress_cidrs 허용(source_address_prefixes에 목록 전달 — CIDR 편집이
#          이 규칙 하나의 속성만 갱신하고 다른 리소스를 재생성하지 않는다)
#   4096 : 인바운드 전체 차단 — 플랫폼 기본 AllowVNetInBound(65000)를 실제로 덮는다.
#          이 Deny는 플랫폼 인프라 통신(DHCP·DNS·IMDS·health, 168.63.129.16·
#          169.254.169.254)은 막지 않는다 — 그 통신은 서비스 태그를 명시하지 않는 한
#          NSG 적용 대상 밖이다(MS Learn). Run Command·VM Agent·boot diagnostics는
#          이 Deny와 무관하게 동작한다.
resource "azurerm_network_security_rule" "ssh_allow" {
  count = local.enabled && length(var.ssh_ingress_cidrs) > 0 ? 1 : 0

  name                        = "AllowSsh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefixes     = var.ssh_ingress_cidrs
  destination_port_range      = "22"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this[0].name
}

resource "azurerm_network_security_rule" "deny_all_inbound" {
  count = local.enabled ? 1 : 0

  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this[0].name
}

# azurerm 3.0+는 network_interface에 network_security_group_id 인자가 없다 — 이 연결
# 리소스가 유일한 부착 수단이다(vnet 모듈의 subnet_network_security_group_association과
# 같은 패턴). 이게 없으면 위 NSG·규칙을 아무리 정교하게 만들어도 NIC에 실제로 안 붙는다.
resource "azurerm_network_interface_security_group_association" "this" {
  count = local.enabled ? 1 : 0

  network_interface_id      = azurerm_network_interface.this[0].id
  network_security_group_id = azurerm_network_security_group.this[0].id
}

resource "azurerm_linux_virtual_machine" "this" {
  count = local.enabled ? 1 : 0

  name                  = local.vm_name
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.this[0].id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching                = var.os_disk_caching
    storage_account_type   = var.os_disk_storage_account_type
    disk_size_gb           = var.os_disk_size_gb
    disk_encryption_set_id = var.os_disk_encryption_set_id
  }

  source_image_reference {
    publisher = var.source_image_reference.publisher
    offer     = var.source_image_reference.offer
    sku       = var.source_image_reference.sku
    version   = var.source_image_reference.version
  }

  # system-assigned 절반은 AADSSHLoginForLinux 확장이 강제한다(exit code 22, MS Learn) —
  # entra_ssh_login_enabled = false로 확장 자체를 끄지 않는 한 항상 필요하다. 그 확장을
  # 끈 배포에서는 쓰이지 않는 신원이 하나 더 만들어질 뿐이라 무해하다.
  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [var.identity_id]
  }

  # ForceNew — 부팅 실패 시 유일한 복구 경로는 VM 재생성이다(README「부팅 후 확인」 참조).
  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init.sh.tftpl", {
    identity_id             = var.identity_id
    identity_client_id      = var.identity_client_id
    az_cli_version          = var.az_cli_version
    aks_cluster_name        = var.aks_cluster_name
    aks_resource_group_name = var.aks_resource_group_name
    aks_entra_rbac_enabled  = var.aks_entra_rbac_enabled
    kubectl_version         = var.kubectl_version
    helm_version            = var.helm_version
    argocd_version          = var.argocd_version
    krew_version            = var.krew_version
    krew_plugins            = var.krew_plugins
    aks_node_viewer_version = var.aks_node_viewer_version
  }))

  # cloud-init 실패 시 유일한 사후 진단 수단(README「부팅 후 확인」 참조). null이면 관리형
  # 스토리지를 자동 사용한다(provider 문서).
  boot_diagnostics {
    storage_account_uri = null
  }

  tags = var.tags
}

resource "azurerm_virtual_machine_extension" "aad_ssh_login" {
  count = local.enabled && var.entra_ssh_login_enabled ? 1 : 0

  name               = "AADSSHLoginForLinux"
  virtual_machine_id = azurerm_linux_virtual_machine.this[0].id
  publisher          = "Microsoft.Azure.ActiveDirectory"
  type               = "AADSSHLoginForLinux"
  # 핀 정책: source_image_reference·az_cli_version과 같은 "핀의 소유자는 소비 루트"
  # 계약을 여기 적용하지 않는다 — 이 확장은 MS가 관리형으로 굴리는 것이라(aks-cluster의
  # managed addon과 같은 성격) 최신 마이너를 자동 추종하는 편이 안전 패치를 놓치지 않는다.
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}
