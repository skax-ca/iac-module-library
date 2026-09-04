# aks-workbench 모듈 계약 검증
#
# ⚠️ 이 파일이 계약의 유일한 검출 지점이다. 교차변수 validation은 plan 시점에 평가되므로,
#    examples를 validate까지만 도는 규약으로는 계약 위반이 잡히지 않는다.
#
# mock_provider로 azurerm 전체를 모킹한다 — 이 repo는 배포하지 않아 CI에 Azure 자격증명이
# 없다. 모킹에서는 computed 속성(id 등)이 plan 시점에 unknown일 수 있다. assertion은 설정값과
# 인스턴스 개수·키 집합만 본다(modules/azure/aks-cluster/tests/plan.tftest.hcl과 같은 제약).

mock_provider "azurerm" {
  mock_resource "azurerm_linux_virtual_machine" {
    defaults = {
      id = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.Compute/virtualMachines/example-vm"
    }
  }

  mock_resource "azurerm_network_interface" {
    defaults = {
      id                 = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.Network/networkInterfaces/example-nic"
      private_ip_address = "10.60.1.10"
    }
  }

  mock_resource "azurerm_public_ip" {
    defaults = {
      id         = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.Network/publicIPAddresses/example-pip"
      ip_address = "203.0.113.10"
    }
  }

  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.Network/networkSecurityGroups/example-nsg"
    }
  }
}

variables {
  naming = {
    workload    = "demo"
    env         = "prd"
    region_code = "krc"
  }
  resource_group_name = "rg-demo-prd-krc-main"
  location            = "koreacentral"
  subnet_id           = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/rg-demo-prd-krc-main/providers/Microsoft.Network/virtualNetworks/vnet-demo-prd-krc-main/subnets/snet-demo-prd-krc-workbench"
  identity_id         = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/rg-demo-prd-krc-main/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-demo-prd-krc-workbench-01"
  # 실제로 유효한 SSH 공개키 형태여야 한다 — provider가 client-side로 파싱을 검증해
  # mock_provider로도 형식 오류(placeholder 문자열)는 못 가린다. 이 값은 테스트 전용
  # 더미 키페어의 공개키다(private key는 존재하지 않음, 순수 fixture).
  admin_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP6HacqFxdt5rCsQz945B26C+K5Jy476LkPBtxrwwWvD test-fixture"
  ssh_ingress_cidrs    = ["203.0.113.0/24"]

  source_image_reference = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "24.04.202601010"
  }
}

# ── 네이밍 규약 — 릴리스 게이트 필수 항목 ───────────────────────────────────────
run "naming_contract" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine.this[0].name == "vm-demo-prd-krc-workbench-01"
    error_message = "VM 이름이 vm-<mid>-<purpose>-<serial> 포맷이 아니다: ${azurerm_linux_virtual_machine.this[0].name}"
  }

  assert {
    condition     = azurerm_network_interface.this[0].name == "nic-demo-prd-krc-workbench-01"
    error_message = "NIC 이름이 nic-<mid>-<purpose>-<serial> 포맷이 아니다: ${azurerm_network_interface.this[0].name}"
  }

  assert {
    condition     = azurerm_network_security_group.this[0].name == "nsg-demo-prd-krc-workbench-01"
    error_message = "NSG 이름이 nsg-<mid>-<purpose>-<serial> 포맷이 아니다: ${azurerm_network_security_group.this[0].name}"
  }
}

run "naming_contract_public_ip" {
  command = plan

  variables {
    public_ip_enabled = true
  }

  assert {
    condition     = azurerm_public_ip.this[0].name == "pip-demo-prd-krc-workbench-01"
    error_message = "공용 IP 이름이 pip-<mid>-<purpose>-<serial> 포맷이 아니다: ${azurerm_public_ip.this[0].name}"
  }
}

# ── 신원 — dual identity, identity_id 하나만 소비한다 ───────────────────────────
run "dual_identity_wired" {
  command = plan

  assert {
    condition = alltrue([
      azurerm_linux_virtual_machine.this[0].identity[0].type == "SystemAssigned, UserAssigned",
      azurerm_linux_virtual_machine.this[0].identity[0].identity_ids == toset([var.identity_id]),
    ])
    error_message = "identity 블록이 dual identity(SystemAssigned, UserAssigned) + var.identity_id 하나로 구성되지 않았다."
  }

  # 이 모듈이 azurerm_user_assigned_identity·azurerm_role_assignment를 만들지 않는다는 것은
  # main.tf에 그 리소스 타입 자체가 없다는 사실로 보장된다(tftest는 존재하는 리소스만 검사한다).
}

# ── NSG — ssh_ingress_cidrs를 명시적으로 비우면 진짜 인바운드 0 ─────────────────
run "empty_ssh_ingress_cidrs_yields_true_zero_inbound" {
  command = plan

  variables {
    ssh_ingress_cidrs = []
  }

  assert {
    condition     = length(azurerm_network_security_rule.ssh_allow) == 0
    error_message = "ssh_ingress_cidrs = []인데 AllowSsh 규칙이 만들어졌다."
  }

  assert {
    condition = alltrue([
      length(azurerm_network_security_rule.deny_all_inbound) == 1,
      azurerm_network_security_rule.deny_all_inbound[0].priority == 4096,
    ])
    error_message = "DenyAllInbound 규칙이 없거나 priority가 4096이 아니다."
  }

  assert {
    condition     = length(azurerm_network_interface_security_group_association.this) == 1
    error_message = "NSG가 NIC에 연결되지 않았다 — 이게 없으면 NSG가 있어도 무효하다."
  }
}

# ── NSG — CIDR이 채워지면 단일 규칙이 그 목록을 그대로 받는다 ───────────────────
run "ssh_ingress_cidrs_wired_to_single_rule" {
  command = plan

  variables {
    ssh_ingress_cidrs = ["203.0.113.0/24", "198.51.100.0/24"]
  }

  assert {
    condition     = length(azurerm_network_security_rule.ssh_allow) == 1
    error_message = "CIDR이 여러 개인데 AllowSsh 규칙이 1개가 아니다 — for_each+index() 방식으로 되돌아갔을 가능성이 있다."
  }

  assert {
    condition = alltrue([
      azurerm_network_security_rule.ssh_allow[0].source_address_prefixes == toset(["203.0.113.0/24", "198.51.100.0/24"]),
      azurerm_network_security_rule.ssh_allow[0].priority < azurerm_network_security_rule.deny_all_inbound[0].priority,
    ])
    error_message = "AllowSsh의 source_address_prefixes가 CIDR 목록과 다르거나, priority가 DenyAllInbound보다 낮지 않다."
  }
}

# ── public_ip_enabled = true는 ssh_ingress_cidrs가 비어 있으면 죽은 구성이다 ────
run "reject_public_ip_without_ssh_ingress" {
  command = plan

  variables {
    public_ip_enabled = true
    ssh_ingress_cidrs = []
  }

  expect_failures = [var.public_ip_enabled]
}

# ── source_image_reference.version = "latest"는 재현성을 깬다 ──────────────────
run "reject_latest_image_version" {
  command = plan

  variables {
    source_image_reference = {
      publisher = "Canonical"
      offer     = "ubuntu-24_04-lts"
      sku       = "server"
      version   = "latest"
    }
  }

  expect_failures = [var.source_image_reference]
}

# ── AKS 연동 — az_cli_version 없이 aks_cluster_name만 주면 부팅 시점에야 실패한다 ──
run "reject_aks_cluster_name_without_az_cli_version" {
  command = plan

  variables {
    aks_cluster_name        = "aks-demo-prd-krc-main-01"
    aks_resource_group_name = "rg-demo-prd-krc-main"
    az_cli_version          = null
  }

  expect_failures = [var.az_cli_version]
}

run "reject_aks_cluster_name_without_resource_group" {
  command = plan

  variables {
    aks_cluster_name = "aks-demo-prd-krc-main-01"
    # az_cli_version을 채워 그 validation은 통과시키고, resource_group 쌍 위반만 격리한다.
    az_cli_version = "2.72.0-1~noble"
  }

  expect_failures = [var.aks_resource_group_name]
}

# ── aks_entra_rbac_enabled = true는 셋(cluster_name·resource_group·client_id) 전부를 요구한다 ──
run "reject_entra_rbac_without_full_triplet" {
  command = plan

  variables {
    aks_entra_rbac_enabled  = true
    aks_cluster_name        = "aks-demo-prd-krc-main-01"
    aks_resource_group_name = "rg-demo-prd-krc-main"
    az_cli_version          = "2.72.0-1~noble"
    # identity_client_id를 비워서 위반시킨다.
  }

  expect_failures = [var.aks_entra_rbac_enabled]
}

run "entra_rbac_enabled_with_full_triplet_ok" {
  command = plan

  variables {
    aks_entra_rbac_enabled  = true
    aks_cluster_name        = "aks-demo-prd-krc-main-01"
    aks_resource_group_name = "rg-demo-prd-krc-main"
    identity_client_id      = "00000000-0000-0000-0000-000000000001"
    az_cli_version          = "2.72.0-1~noble"
  }

  assert {
    condition     = length(azurerm_linux_virtual_machine.this) == 1
    error_message = "aks_entra_rbac_enabled 셋이 전부 채워졌는데 plan이 통과하지 않았다."
  }
}

# ── entra_ssh_login_enabled — ssh_ingress_cidrs와 직교하는 별도 게이트 ───────────
run "entra_ssh_login_disabled_skips_extension" {
  command = plan

  variables {
    entra_ssh_login_enabled = false
  }

  assert {
    condition     = length(azurerm_virtual_machine_extension.aad_ssh_login) == 0
    error_message = "entra_ssh_login_enabled = false인데 AADSSHLoginForLinux 확장이 만들어졌다."
  }
}

run "entra_ssh_login_default_creates_extension" {
  command = plan

  assert {
    condition     = length(azurerm_virtual_machine_extension.aad_ssh_login) == 1
    error_message = "entra_ssh_login_enabled 기본값(true)인데 AADSSHLoginForLinux 확장이 만들어지지 않았다."
  }
}

# ── kill switch ─────────────────────────────────────────────────────────────────
run "kill_switch_disables_everything" {
  command = plan

  variables {
    workbench_enabled = false
    public_ip_enabled = true
  }

  assert {
    condition = alltrue([
      length(azurerm_linux_virtual_machine.this) == 0,
      length(azurerm_network_interface.this) == 0,
      length(azurerm_network_security_group.this) == 0,
      length(azurerm_network_security_rule.deny_all_inbound) == 0,
      length(azurerm_network_interface_security_group_association.this) == 0,
      length(azurerm_virtual_machine_extension.aad_ssh_login) == 0,
      length(azurerm_public_ip.this) == 0,
    ])
    error_message = "workbench_enabled = false인데 리소스가 남아 있다."
  }

  assert {
    condition = alltrue([
      output.workbench_vm_id == null,
      output.workbench_private_ip == null,
      output.workbench_public_ip == null,
      output.workbench_nsg_id == null,
      output.workbench_system_identity_principal_id == null,
    ])
    error_message = "비활성 시 스칼라 출력이 null이 아니다."
  }
}

# ── nullable = false 계약: 명시적 null이 crash 대신 default로 대체된다 ─────────
run "nullable_false_falls_back_to_default" {
  command = plan

  variables {
    tags                         = null
    purpose                      = null
    serial                       = null
    workbench_enabled            = null
    public_ip_enabled            = null
    admin_username               = null
    entra_ssh_login_enabled      = null
    os_disk_caching              = null
    os_disk_storage_account_type = null
    vm_size                      = null
    aks_entra_rbac_enabled       = null
    krew_plugins                 = null
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this[0].name == "vm-demo-prd-krc-workbench-01"
    error_message = "purpose·serial = null이 default로 대체되지 않았다: ${azurerm_linux_virtual_machine.this[0].name}"
  }

  assert {
    condition     = length(azurerm_linux_virtual_machine.this) == 1
    error_message = "workbench_enabled = null이 default true로 대체되지 않았다."
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this[0].size == "Standard_B2s"
    error_message = "vm_size = null이 default \"Standard_B2s\"로 대체되지 않았다."
  }
}
