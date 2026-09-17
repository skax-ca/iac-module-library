# aks-cluster 모듈 계약 검증
#
# ⚠️ 이 파일이 계약의 유일한 검출 지점이다. 교차변수 validation은 validate가 아니라 plan
#    시점에 평가되므로, examples를 validate까지만 도는 규약으로는 계약 위반이 잡히지 않는다.
#
# mock_provider로 azurerm 전체를 모킹한다. 이 repo는 배포하지 않아 CI에 Azure 자격증명이
# 없다. 모킹에서는 computed 속성(id·oidc_issuer_url 등)이 plan 시점에 unknown이다. 따라서
# assertion은 설정값(tags·name·vm_size 등)과 인스턴스 개수·키 집합만 본다
# (modules/azure/vnet/tests/plan.tftest.hcl과 같은 제약).

mock_provider "azurerm" {
  mock_resource "azurerm_kubernetes_cluster" {
    defaults = {
      id                  = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.ContainerService/managedClusters/example-aks"
      node_resource_group = "MC_example-resource-group_example-aks_koreacentral"
    }
  }

  mock_resource "azurerm_kubernetes_cluster_node_pool" {
    defaults = {
      id = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.ContainerService/managedClusters/example-aks/agentPools/example-pool"
    }
  }
}

# ⚠️ 기본 variables 블록은 cni_mode 기본값(overlay)과 호환되는 조합이다.
#    pod_subnet_id는 null, pod_cidr는 값이 있다. pod_subnet·node_subnet 모드를 테스트하는
#    run은 이 두 값을 명시적으로 뒤집어야 한다(아래 각 run 참조).
variables {
  naming = {
    workload    = "demo"
    env         = "prd"
    region_code = "krc"
  }
  resource_group_name = "rg-demo-prd-krc-main"
  location            = "koreacentral"
  identity_id         = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/rg-demo-prd-krc-main/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-demo-prd-krc-aks-01"
  node_subnet_id      = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/rg-demo-prd-krc-main/providers/Microsoft.Network/virtualNetworks/vnet-demo-prd-krc-main/subnets/snet-demo-prd-krc-aks-node"
  pod_subnet_id       = null
  pod_cidr            = "10.244.0.0/16"

  system_node_pool = {
    vm_size    = "Standard_D4s_v5"
    node_count = 2
  }
}

# ── 네이밍 규약: 릴리스 게이트 필수 항목 ───────────────────────────────────────
run "naming_contract" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].name == "aks-demo-prd-krc-main-01"
    error_message = "클러스터 이름이 aks-<mid>-<purpose>-<serial> 포맷이 아니다: ${azurerm_kubernetes_cluster.this[0].name}"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].dns_prefix == "aks-demo-prd-krc-main-01"
    error_message = "dns_prefix가 클러스터 이름과 다르다: ${azurerm_kubernetes_cluster.this[0].dns_prefix}"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].default_node_pool[0].name == "npsystem"
    error_message = "시스템 노드 풀 이름이 npsystem이 아니다: ${azurerm_kubernetes_cluster.this[0].default_node_pool[0].name}"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].default_node_pool[0].temporary_name_for_rotation == "npsystemt"
    error_message = "시스템 노드 풀의 temporary_name_for_rotation이 npsystemt가 아니다."
  }
}

# ── 시스템 노드 풀: 필수, 서브넷·태그가 배선된다 ───────────────────────────────
run "system_node_pool_required_and_wired" {
  command = plan

  assert {
    condition = alltrue([
      azurerm_kubernetes_cluster.this[0].default_node_pool[0].vm_size == "Standard_D4s_v5",
      azurerm_kubernetes_cluster.this[0].default_node_pool[0].node_count == 2,
      azurerm_kubernetes_cluster.this[0].default_node_pool[0].vnet_subnet_id == var.node_subnet_id,
      # 0.5.0 회귀 방지: upgrade_settings.max_surge를 Azure 기본값(10%)으로 명시
      # 고정한다. 생략하면 Azure가 매 조회마다 같은 기본값을 채워 넣어 plan이
      # 영원히 수렴하지 않는다.
      azurerm_kubernetes_cluster.this[0].default_node_pool[0].upgrade_settings[0].max_surge == "10%",
    ])
    error_message = "시스템 노드 풀 설정이 var.system_node_pool·node_subnet_id·upgrade_settings와 어긋난다."
  }
}

# ── 신원: identity_id를 입력으로만 받는다, identity·role assignment를 만들지 않는다 ──
run "identity_input_only_no_creation" {
  command = plan

  assert {
    condition = alltrue([
      azurerm_kubernetes_cluster.this[0].identity[0].type == "UserAssigned",
      azurerm_kubernetes_cluster.this[0].identity[0].identity_ids == toset([var.identity_id]),
    ])
    error_message = "identity 블록이 UserAssigned + var.identity_id 하나로 구성되지 않았다."
  }

  # 이 모듈이 azurerm_user_assigned_identity·azurerm_role_assignment를 만들지 않는다는 것은
  # main.tf에 그 리소스 타입 자체가 없다는 사실로 보장된다(음성 조건은 플랜 그래프가 아니라
  # 코드 리뷰·grep으로 검증한다. tftest는 존재하는 리소스만 assert할 수 있다).
}

# ── 네트워킹: cni_mode 기본값(overlay), NAT는 만들지 않는다 ──────────────────
run "network_profile_overlay_is_default" {
  command = plan

  assert {
    condition = alltrue([
      azurerm_kubernetes_cluster.this[0].network_profile[0].network_plugin == "azure",
      azurerm_kubernetes_cluster.this[0].network_profile[0].network_plugin_mode == "overlay",
      azurerm_kubernetes_cluster.this[0].network_profile[0].network_data_plane == "cilium",
      # 회귀 방지: network_data_plane = cilium이면 network_policy도 cilium
      # 이어야 한다(provider 문서 "must be set to cilium", ARM도 어기면 거부: main.tf
      # network_policy 주석 참고). "azure"로 두면 apply가 실패하므로 여기서 고정 검사한다.
      azurerm_kubernetes_cluster.this[0].network_profile[0].network_policy == "cilium",
      # ⚠️ pod_cidr는 provider 스키마상 Optional+Computed라 mock에서는 명시적 값을 줘도
      # plan 시점 unknown(임의 mock 문자열)으로 나올 수 있다. 이 파일 상단 주석의 "computed
      # 속성은 assertion 대상에서 뺀다" 제약과 같은 케이스라 여기서는 검사하지 않는다.
      azurerm_kubernetes_cluster.this[0].network_profile[0].outbound_type == "userAssignedNATGateway",
      azurerm_kubernetes_cluster.this[0].network_profile[0].load_balancer_sku == "standard",
      azurerm_kubernetes_cluster.this[0].default_node_pool[0].pod_subnet_id == null,
    ])
    error_message = "cni_mode 기본값(overlay)에서 network_profile·pod_subnet_id 배선이 계약과 다르다."
  }
}

# ── cni_mode = "pod_subnet": 명시적으로 켜야 전용 서브넷을 쓴다 ─────────────────
run "cni_mode_pod_subnet_explicit_wires_dedicated_subnet" {
  command = plan

  variables {
    cni_mode      = "pod_subnet"
    pod_subnet_id = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/rg-demo-prd-krc-main/providers/Microsoft.Network/virtualNetworks/vnet-demo-prd-krc-main/subnets/snet-demo-prd-krc-aks-pod"
    pod_cidr      = null
  }

  assert {
    condition = alltrue([
      azurerm_kubernetes_cluster.this[0].network_profile[0].network_plugin_mode == null,
      azurerm_kubernetes_cluster.this[0].network_profile[0].network_data_plane == null,
      azurerm_kubernetes_cluster.this[0].network_profile[0].network_policy == "azure",
      azurerm_kubernetes_cluster.this[0].default_node_pool[0].pod_subnet_id == var.pod_subnet_id,
    ])
    error_message = "cni_mode = pod_subnet인데 network_profile·pod_subnet_id 배선이 계약과 다르다."
  }
}

# ── cni_mode = "node_subnet": pod_subnet_id 없이 node_subnet_id만 쓴다 ────────
run "cni_mode_node_subnet_no_pod_subnet" {
  command = plan

  variables {
    cni_mode = "node_subnet"
    pod_cidr = null
  }

  assert {
    condition = alltrue([
      azurerm_kubernetes_cluster.this[0].network_profile[0].network_plugin_mode == null,
      azurerm_kubernetes_cluster.this[0].network_profile[0].network_policy == "azure",
      azurerm_kubernetes_cluster.this[0].default_node_pool[0].pod_subnet_id == null,
      azurerm_kubernetes_cluster.this[0].default_node_pool[0].vnet_subnet_id == var.node_subnet_id,
    ])
    error_message = "cni_mode = node_subnet인데 pod_subnet_id가 남아있거나 network_plugin_mode·network_policy가 계약과 다르다."
  }
}

# ── cni_mode = "overlay": pod_cidr 필수, network_plugin_mode·data_plane 켜짐(기본값과 동일 조합을 명시적으로도 검증) ──
run "cni_mode_overlay_wires_pod_cidr_and_cilium" {
  command = plan

  variables {
    cni_mode      = "overlay"
    pod_subnet_id = null
    pod_cidr      = "10.244.0.0/16"
  }

  assert {
    condition = alltrue([
      azurerm_kubernetes_cluster.this[0].network_profile[0].network_plugin_mode == "overlay",
      azurerm_kubernetes_cluster.this[0].network_profile[0].network_data_plane == "cilium",
      azurerm_kubernetes_cluster.this[0].network_profile[0].network_policy == "cilium",
      azurerm_kubernetes_cluster.this[0].default_node_pool[0].pod_subnet_id == null,
    ])
    error_message = "cni_mode = overlay인데 network_plugin_mode·network_data_plane·network_policy 배선이 계약과 다르다."
  }
}

# ── cni_mode 교차변수 validation: plan에서 차단된다 ────────────────────────────
run "reject_invalid_cni_mode" {
  command = plan

  variables {
    cni_mode = "bogus"
    pod_cidr = null
  }

  expect_failures = [var.cni_mode]
}

run "reject_pod_subnet_id_when_cni_mode_not_pod_subnet" {
  command = plan

  variables {
    cni_mode      = "node_subnet"
    pod_subnet_id = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/rg-demo-prd-krc-main/providers/Microsoft.Network/virtualNetworks/vnet-demo-prd-krc-main/subnets/snet-demo-prd-krc-aks-pod"
    pod_cidr      = null
    # pod_subnet_id를 명시적으로 채웠는데 cni_mode가 pod_subnet이 아니므로 위반.
  }

  expect_failures = [var.pod_subnet_id]
}

run "reject_pod_subnet_mode_without_pod_subnet_id" {
  command = plan

  variables {
    cni_mode      = "pod_subnet"
    pod_subnet_id = null
    pod_cidr      = null
    # cni_mode = pod_subnet인데 pod_subnet_id가 없으면 위반.
  }

  expect_failures = [var.pod_subnet_id]
}

run "reject_pod_cidr_when_cni_mode_not_overlay" {
  command = plan

  variables {
    cni_mode = "node_subnet"
    pod_cidr = "10.244.0.0/16"
    # cni_mode가 overlay가 아닌데 pod_cidr를 채웠으므로 위반.
  }

  expect_failures = [var.pod_cidr]
}

run "reject_overlay_without_pod_cidr" {
  command = plan

  variables {
    cni_mode = "overlay"
    pod_cidr = null
    # 기본 cni_mode(overlay)를 명시적으로 다시 지정했지만 pod_cidr를 비워서 위반시킨다.
  }

  expect_failures = [var.pod_cidr]
}

# ── node_provisioning_profile: 항상 존재, enable_karpenter 기본값(false)이면 Manual ──
run "node_provisioning_profile_defaults_to_manual" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].node_provisioning_profile[0].mode == "Manual"
    error_message = "enable_karpenter 기본값(false)인데 node_provisioning_profile.mode가 Manual이 아니다. cni_mode 기본값(overlay)은 NAP과 호환되지만, NAP은 여전히 옵트인이다(GitOps NodePool 준비 없이 기본 켜짐이면 죽은 설정이 된다)."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].node_provisioning_profile[0].default_node_pools == "None"
    error_message = "default_node_pools가 None으로 고정되지 않았다. GitOps가 NodePool을 전량 소유하지 못한다."
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster.this[0].default_node_pool) == 1
    error_message = "default_node_pool(시스템 노드 풀)이 Manual에서도 필수인데 사라졌다."
  }
}

# ── workload_autoscaler_profile(KEDA): 항상 존재, enable_keda 기본값(false)이면 꺼짐 ──
run "workload_autoscaler_profile_defaults_to_disabled" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].workload_autoscaler_profile[0].keda_enabled == false
    error_message = "enable_keda 기본값(false)인데 workload_autoscaler_profile.keda_enabled가 false가 아니다."
  }
}

run "workload_autoscaler_profile_keda_enabled" {
  command = plan

  variables {
    enable_keda = true
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].workload_autoscaler_profile[0].keda_enabled == true
    error_message = "enable_keda = true인데 workload_autoscaler_profile.keda_enabled가 true로 반영되지 않았다."
  }
}

# ── enable_karpenter = true는 cni_mode = overlay·node_subnet과만 유효하다(기본 overlay 포함) ──
run "node_provisioning_profile_auto_with_default_overlay" {
  command = plan

  variables {
    enable_karpenter = true
    # cni_mode·pod_cidr는 기본값(overlay + "10.244.0.0/16") 그대로: 이미 NAP과 호환된다.
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].node_provisioning_profile[0].mode == "Auto"
    error_message = "cni_mode 기본값(overlay) + enable_karpenter = true인데 mode가 Auto로 전환되지 않았다."
  }
}

run "node_provisioning_profile_auto_with_node_subnet" {
  command = plan

  variables {
    cni_mode         = "node_subnet"
    pod_cidr         = null
    enable_karpenter = true
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].node_provisioning_profile[0].mode == "Auto"
    error_message = "cni_mode = node_subnet + enable_karpenter = true인데 mode가 Auto로 전환되지 않았다."
  }
}

# ── enable_karpenter × cni_mode 교차변수 validation: plan에서 차단된다 ────────
run "reject_karpenter_with_pod_subnet_mode" {
  command = plan

  variables {
    cni_mode         = "pod_subnet"
    pod_subnet_id    = "/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/rg-demo-prd-krc-main/providers/Microsoft.Network/virtualNetworks/vnet-demo-prd-krc-main/subnets/snet-demo-prd-krc-aks-pod"
    pod_cidr         = null
    enable_karpenter = true
    # cni_mode = pod_subnet과 enable_karpenter = true는 karpenter-provider-azure#1352가
    # 지원하지 않는 조합이라 차단돼야 한다.
  }

  expect_failures = [var.enable_karpenter]
}

# ── Entra RBAC: 옵트인, 기본은 블록 자체가 없다(G2 확정) ───────────────────────
run "entra_rbac_optin_default_off" {
  command = plan

  assert {
    condition     = length(azurerm_kubernetes_cluster.this[0].azure_active_directory_role_based_access_control) == 0
    error_message = "entra_admin_group_object_ids가 빈 기본값인데 AAD RBAC 블록이 만들어졌다."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].local_account_disabled == false
    error_message = "local_account_disabled 기본값이 false가 아니다."
  }
}

run "entra_rbac_enabled_when_admin_groups_given" {
  command = plan

  variables {
    entra_admin_group_object_ids = ["00000000-0000-0000-0000-000000000001"]
  }

  assert {
    condition = alltrue([
      length(azurerm_kubernetes_cluster.this[0].azure_active_directory_role_based_access_control) == 1,
      azurerm_kubernetes_cluster.this[0].azure_active_directory_role_based_access_control[0].admin_group_object_ids == tolist(["00000000-0000-0000-0000-000000000001"]),
      azurerm_kubernetes_cluster.this[0].azure_active_directory_role_based_access_control[0].azure_rbac_enabled == true,
    ])
    error_message = "entra_admin_group_object_ids를 넘겼는데 AAD RBAC 블록이 그 값대로 만들어지지 않았다."
  }
}

# entra_integration_enabled: admin 그룹 없이도 독립적으로 Entra 통합을 켠다(0-8).
run "entra_rbac_enabled_via_independent_toggle" {
  command = plan

  variables {
    entra_integration_enabled = true
  }

  assert {
    condition = alltrue([
      length(azurerm_kubernetes_cluster.this[0].azure_active_directory_role_based_access_control) == 1,
      length(azurerm_kubernetes_cluster.this[0].azure_active_directory_role_based_access_control[0].admin_group_object_ids) == 0,
      azurerm_kubernetes_cluster.this[0].azure_active_directory_role_based_access_control[0].azure_rbac_enabled == true,
    ])
    error_message = "entra_integration_enabled = true인데 admin 그룹 없이 AAD RBAC 블록이 만들어지지 않았다."
  }
}

# ── local_account_disabled 잠금 위험: plan에서 차단된다(0-8) ───────────────────
run "reject_local_account_disabled_without_admin_group" {
  command = plan

  variables {
    local_account_disabled = true
  }

  expect_failures = [var.local_account_disabled]
}

run "local_account_disabled_allowed_with_admin_group" {
  command = plan

  variables {
    local_account_disabled       = true
    entra_admin_group_object_ids = ["00000000-0000-0000-0000-000000000001"]
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].local_account_disabled == true
    error_message = "entra_admin_group_object_ids를 함께 줬는데 local_account_disabled = true가 반영되지 않았다."
  }
}

# local_account_disabled 완화(0-8). entra_integration_enabled만으로도 잠금 조건을 만족한다.
run "local_account_disabled_allowed_with_independent_toggle" {
  command = plan

  variables {
    local_account_disabled    = true
    entra_integration_enabled = true
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].local_account_disabled == true
    error_message = "entra_integration_enabled = true를 함께 줬는데 local_account_disabled = true가 반영되지 않았다."
  }
}

# ── API 서버 접근 제한: 옵트인 ──────────────────────────────────────────────────
run "api_server_access_profile_optin" {
  command = plan

  assert {
    condition     = length(azurerm_kubernetes_cluster.this[0].api_server_access_profile) == 0
    error_message = "authorized_ip_ranges가 빈 기본값인데 api_server_access_profile 블록이 만들어졌다."
  }
}

run "api_server_access_profile_set_when_ranges_given" {
  command = plan

  variables {
    authorized_ip_ranges = ["203.0.113.0/24"]
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].api_server_access_profile[0].authorized_ip_ranges == toset(["203.0.113.0/24"])
    error_message = "authorized_ip_ranges가 api_server_access_profile에 반영되지 않았다."
  }
}

# ── App Routing(web_app_routing): 옵트인, azurerm이 아는 하위 필드만 선언한다 ───
run "web_app_routing_optin_default_off" {
  command = plan

  assert {
    condition     = length(azurerm_kubernetes_cluster.this[0].web_app_routing) == 0
    error_message = "web_app_routing이 기본값(null)인데 web_app_routing 블록이 만들어졌다."
  }
}

run "web_app_routing_enabled_with_values" {
  command = plan

  variables {
    web_app_routing = {
      dns_zone_ids             = []
      default_nginx_controller = "None"
    }
  }

  assert {
    condition = alltrue([
      length(azurerm_kubernetes_cluster.this[0].web_app_routing) == 1,
      # ⚠️ 빈 리스트끼리의 == 비교는 tolist([])/toset([]) 어느 쪽으로 캐스팅해도 타입
      # 불일치로 항상 false다. length로 비교한다.
      length(azurerm_kubernetes_cluster.this[0].web_app_routing[0].dns_zone_ids) == 0,
      azurerm_kubernetes_cluster.this[0].web_app_routing[0].default_nginx_controller == "None",
    ])
    error_message = "web_app_routing을 넘겼는데 블록이 그 값대로 만들어지지 않았다."
  }
}

run "web_app_routing_dns_zone_ids_default_empty" {
  command = plan

  variables {
    # default_nginx_controller만 넘기고 dns_zone_ids는 생략: optional(list(string), [])
    # 기본값이 적용되는지 확인한다.
    web_app_routing = {
      default_nginx_controller = "Internal"
    }
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster.this[0].web_app_routing[0].dns_zone_ids) == 0
    error_message = "web_app_routing.dns_zone_ids를 생략했는데 기본값 []이 적용되지 않았다."
  }
}

run "reject_web_app_routing_invalid_nginx_controller" {
  command = plan

  variables {
    web_app_routing = {
      default_nginx_controller = "Bogus"
    }
  }

  expect_failures = [var.web_app_routing]
}

# ── private_cluster_public_fqdn_enabled: 기본 false, 옵트인 시 그대로 전달 ─────
run "private_cluster_public_fqdn_optin_default_off" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].private_cluster_public_fqdn_enabled == false
    error_message = "private_cluster_public_fqdn_enabled 기본값이 false가 아니다."
  }
}

run "private_cluster_public_fqdn_enabled_when_set" {
  command = plan

  variables {
    private_cluster_public_fqdn_enabled = true
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].private_cluster_public_fqdn_enabled == true
    error_message = "private_cluster_public_fqdn_enabled = true를 넘겼는데 리소스에 반영되지 않았다."
  }
}

# ── service_cidr · dns_service_ip는 함께 지정하거나 함께 비운다 ─────────────────
run "reject_service_cidr_without_dns_service_ip" {
  command = plan

  variables {
    service_cidr = "10.100.0.0/16"
  }

  expect_failures = [var.service_cidr]
}

run "service_cidr_and_dns_service_ip_together_ok" {
  command = plan

  variables {
    service_cidr   = "10.100.0.0/16"
    dns_service_ip = "10.100.0.10"
  }

  assert {
    condition = alltrue([
      azurerm_kubernetes_cluster.this[0].network_profile[0].service_cidr == "10.100.0.0/16",
      azurerm_kubernetes_cluster.this[0].network_profile[0].dns_service_ip == "10.100.0.10",
    ])
    error_message = "service_cidr·dns_service_ip가 network_profile에 반영되지 않았다."
  }
}

# ── 추가 노드 풀: for_each, np<키> 이름, 순환 예산 ─────────────────────────────
run "additional_node_pools_named_and_wired" {
  command = plan

  variables {
    node_pools = {
      "app" = {
        vm_size     = "Standard_D4s_v5"
        node_count  = 3
        node_labels = { workload = "app" }
        node_taints = ["dedicated=app:NoSchedule"]
      }
    }
  }

  assert {
    condition     = azurerm_kubernetes_cluster_node_pool.this["app"].name == "npapp"
    error_message = "추가 노드 풀 이름이 np<키> 포맷이 아니다: ${azurerm_kubernetes_cluster_node_pool.this["app"].name}"
  }

  assert {
    condition     = azurerm_kubernetes_cluster_node_pool.this["app"].temporary_name_for_rotation == "npappt"
    error_message = "추가 노드 풀의 temporary_name_for_rotation이 <이름>t 포맷이 아니다."
  }

  assert {
    condition = alltrue([
      azurerm_kubernetes_cluster_node_pool.this["app"].mode == "User",
      azurerm_kubernetes_cluster_node_pool.this["app"].vnet_subnet_id == var.node_subnet_id,
      azurerm_kubernetes_cluster_node_pool.this["app"].pod_subnet_id == null,
      azurerm_kubernetes_cluster_node_pool.this["app"].node_labels == tomap({ workload = "app" }),
      # 0.5.0 회귀 방지: default_node_pool과 동일 근거(위 system_node_pool_required_and_wired 참조).
      azurerm_kubernetes_cluster_node_pool.this["app"].upgrade_settings[0].max_surge == "10%",
    ])
    error_message = "추가 노드 풀의 mode·서브넷·라벨·upgrade_settings가 계약과 다르다."
  }
}

# ── node_pools 키 제약: 8자 초과·대문자·숫자 시작은 plan에서 차단된다 ──────────
run "reject_node_pool_key_too_long" {
  command = plan

  variables {
    node_pools = {
      "toolongkey" = { vm_size = "Standard_D4s_v5" }
    }
  }

  expect_failures = [var.node_pools]
}

run "reject_node_pool_key_starting_with_digit" {
  command = plan

  variables {
    node_pools = {
      "1app" = { vm_size = "Standard_D4s_v5" }
    }
  }

  expect_failures = [var.node_pools]
}

# ── 오토스케일링 교차변수 validation ────────────────────────────────────────────
run "reject_autoscaling_without_min_max" {
  command = plan

  variables {
    system_node_pool = {
      vm_size              = "Standard_D4s_v5"
      auto_scaling_enabled = true
    }
  }

  expect_failures = [var.system_node_pool]
}

run "reject_node_pool_autoscaling_without_min_max" {
  command = plan

  variables {
    node_pools = {
      "app" = {
        vm_size              = "Standard_D4s_v5"
        auto_scaling_enabled = true
      }
    }
  }

  expect_failures = [var.node_pools]
}

# ── nullable = false 계약: 명시적 null이 crash 대신 default로 대체된다 ─────────
run "nullable_false_falls_back_to_default" {
  command = plan

  variables {
    tags             = null
    purpose          = null
    serial           = null
    cluster_enabled  = null
    enable_karpenter = null
    cni_mode         = null
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].name == "aks-demo-prd-krc-main-01"
    error_message = "purpose·serial = null이 default로 대체되지 않았다: ${azurerm_kubernetes_cluster.this[0].name}"
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster.this[0].tags) == 0
    error_message = "tags = null이 default {}로 대체되지 않았다."
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster.this) == 1
    error_message = "cluster_enabled = null이 default true로 대체되지 않았다."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].network_profile[0].network_plugin_mode == "overlay"
    error_message = "cni_mode = null이 default \"overlay\"로 대체되지 않았다."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this[0].node_provisioning_profile[0].mode == "Manual"
    error_message = "enable_karpenter = null이 default false(Manual)로 대체되지 않았다."
  }
}

# ── kill switch ─────────────────────────────────────────────────────────────────
# ⚠️ deletion_protection 기본값 false에 의존한다. true면 삭제 보호 validation이 먼저 차단한다.
run "kill_switch_disables_everything" {
  command = plan

  variables {
    cluster_enabled = false
  }

  assert {
    condition = alltrue([
      length(azurerm_kubernetes_cluster.this) == 0,
      length(azurerm_kubernetes_cluster_node_pool.this) == 0,
    ])
    error_message = "cluster_enabled = false인데 리소스가 남아 있다."
  }

  assert {
    condition = alltrue([
      output.cluster_id == null,
      output.cluster_name == null,
      output.oidc_issuer_url == null,
      output.kubelet_identity_object_id == null,
      output.node_resource_group == null,
      output.fqdn == null,
      output.private_fqdn == null,
    ])
    error_message = "비활성 시 스칼라 출력이 null이 아니다."
  }

  assert {
    condition     = length(output.node_pool_ids_by_key) == 0
    error_message = "비활성 시 node_pool_ids_by_key가 빈 값이 아니다."
  }
}

# ── 계약 위반은 plan에서 차단된다 ───────────────────────────────────────────────
run "reject_teardown_while_protected" {
  command = plan

  variables {
    cluster_enabled     = false
    deletion_protection = true
  }

  expect_failures = [var.deletion_protection]
}
