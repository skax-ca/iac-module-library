# AKS 클러스터 · 시스템 노드 풀(필수) · 추가 노드 풀(옵트인, for_each)
#
# 이 모듈은 identity·role assignment·서브넷·리소스 그룹을 만들지 않는다. 전부 입력으로만
# 받는다(축3·축10, docs/decisions.md「Azure 컨테이너 (aks-cluster)」ADR).
#
# 계약: docs/module-catalog.md

locals {
  enabled = var.cluster_enabled

  # name 인자의 중간 토큰. 소비자가 약어를 타이핑하지 않도록 모듈이 조합한다.
  name_mid     = "${var.naming.workload}-${var.naming.env}-${var.naming.region_code}"
  cluster_name = "aks-${local.name_mid}-${var.purpose}-${var.serial}"

  enable_aad                 = length(var.entra_admin_group_object_ids) > 0
  enable_api_server_ip_range = length(var.authorized_ip_ranges) > 0

  # ── 노드 풀 이름 — 하이픈 금지·12자 한도(축1). 부모(클러스터) 이름이 이미
  # workload·env·리전코드 토큰을 나르므로 노드 풀 이름은 그 토큰을 반복하지 않는다.
  system_pool_name      = "npsystem"
  system_pool_temp_name = "${local.system_pool_name}t" # 9자, 12자 한도 이내

  node_pool_names = { for key, pool in var.node_pools : key => "np${key}" }

  # ── CNI 모드 — cni_mode 변수 설명 참조. 세 값 모두 network_plugin = "azure" 기반이다.
  is_overlay = var.cni_mode == "overlay"
  # 검증(variables.tf)이 이미 cni_mode = "pod_subnet" ⇔ pod_subnet_id != null을 보장하므로
  # 여기서는 그 결과를 그대로 옮기기만 한다 — pod_subnet 모드가 아니면 null.
  pod_subnet_id_by_mode = var.cni_mode == "pod_subnet" ? var.pod_subnet_id : null
}

resource "azurerm_kubernetes_cluster" "this" {
  count = local.enabled ? 1 : 0

  name                = local.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  # dns_prefix는 letters·numbers·hyphens를 받는다(1~54자) — cluster_name을 그대로 쓴다.
  dns_prefix = local.cluster_name

  kubernetes_version = var.kubernetes_version
  sku_tier           = var.sku_tier

  private_cluster_enabled = var.private_cluster_enabled

  default_node_pool {
    name                        = local.system_pool_name
    vm_size                     = var.system_node_pool.vm_size
    node_count                  = var.system_node_pool.auto_scaling_enabled ? null : var.system_node_pool.node_count
    auto_scaling_enabled        = var.system_node_pool.auto_scaling_enabled
    min_count                   = var.system_node_pool.auto_scaling_enabled ? var.system_node_pool.min_count : null
    max_count                   = var.system_node_pool.auto_scaling_enabled ? var.system_node_pool.max_count : null
    os_disk_size_gb             = var.system_node_pool.os_disk_size_gb
    max_pods                    = var.system_node_pool.max_pods
    zones                       = var.system_node_pool.zones
    vnet_subnet_id              = var.node_subnet_id
    pod_subnet_id               = local.pod_subnet_id_by_mode
    temporary_name_for_rotation = local.system_pool_temp_name

    tags = var.tags
  }

  identity {
    type = "UserAssigned"
    # 이 모듈은 identity를 만들지 않는다 — var.identity_id는 소비자(bootstrap 계층)가
    # 미리 만든 리소스 ID다(축3). "Currently only one User Assigned Identity is supported"
    # (provider 공식 문서) — 리스트지만 원소는 1개다.
    identity_ids = [var.identity_id]
  }

  # RBAC는 provider 기본값이 이미 true라 로직상 불필요하지만, trivy(AZU-0042)가 소스에
  # 명시되지 않은 provider 기본값은 신뢰하지 않는다 — 명시로 고정한다. 노출은 하지 않는다
  # (Must NOT Have — false로 갈 이유가 재사용 자산에 없다, 0-8).
  role_based_access_control_enabled = true

  network_profile {
    network_plugin = "azure"
    # cni_mode 변수 설명 참조 — overlay일 때만 켠다. provider 제약: network_plugin_mode가
    # "overlay"가 아니면 pod_cidr 자체를 설정할 수 없다(azurerm_kubernetes_cluster 문서).
    network_plugin_mode = local.is_overlay ? "overlay" : null
    pod_cidr            = local.is_overlay ? var.pod_cidr : null
    # Overlay는 Microsoft가 NAP에 권장하는 Cilium 데이터플레인으로 고정한다. 그 외
    # 모드는 provider 기본값(azure)에 맡긴다 — 명시할 이유가 없다(cilium은 network_policy도
    # cilium으로 맞춰야 하는데 이 라운드 스코프가 아니다, cni_mode 변수 설명 참조).
    network_data_plane = local.is_overlay ? "cilium" : null
    outbound_type      = "userAssignedNATGateway"
    # network_plugin = "azure"와 자연스럽게 짝지어지는 Azure 자체 네트워크 정책 엔진이다
    # (calico·cilium은 추가 조건이 필요해 이 라운드 스코프가 아니다). 노출하지 않는다 —
    # 방어 종심 목적의 고정값이다(설계 라운드에서 다루지 않은 축, 구현 시점 결정).
    network_policy = "azure"
    # NAP(enable_karpenter)이 custom VNet에서 Standard LB를 요구한다(공식 문서 확인) —
    # provider 기본값이 이미 "standard"라 동작은 바뀌지 않지만, 암묵적 의존 대신 명시
    # 고정한다(network_policy와 같은 방어 종심 목적).
    load_balancer_sku = "standard"
    # 이 모듈은 NAT Gateway를 만들지 않는다 — vnet 모듈이 node_subnet_id·pod_subnet_id가
    # 속한 서브넷 그룹에 nat_routed = true로 이미 붙여 둔 것을 쓴다(docs/module-catalog.md
    # 「vnet과의 연동」 참조).
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = local.enable_aad ? [1] : []
    content {
      admin_group_object_ids = var.entra_admin_group_object_ids
      azure_rbac_enabled     = true
    }
  }

  local_account_disabled = var.local_account_disabled

  dynamic "api_server_access_profile" {
    for_each = local.enable_api_server_ip_range ? [1] : []
    content {
      authorized_ip_ranges = var.authorized_ip_ranges
    }
  }

  # OIDC issuer는 항상 켠다 — workload_identity_enabled와 무관하게 oidc_issuer_url을
  # 출력하기 위해서다(0.1.0의 원시 재료 원칙, 축6·축11이 참조하는 지점).
  oidc_issuer_enabled       = true
  workload_identity_enabled = var.workload_identity_enabled

  # kubelet_identity 블록을 쓰지 않는다 — AKS가 노드 리소스 그룹에 자동 생성한다(축11,
  # 0.1.0 스코프 밖). 그 auto-created 신원의 object_id는 outputs.tf가 그대로 노출한다.

  # provider 문서는 이 블록을 (Optional)이라 적지만 실측(tofu validate, azurerm 5.3.0)
  # 결과는 다르다 — 블록 자체가 Required이고, 그 안에서 mode 또는 default_node_pools 중
  # 하나가 Required다.
  #
  # Node Auto Provisioning(NAP)은 오픈소스 Karpenter + AKS Karpenter provider 기반이다
  # (eks-cluster의 enable_karpenter와 개념 대응 — AWS는 별도 IAM 리소스 뭉치, Azure는
  # 이 필드 하나). default_node_pool은 Auto에서도 여전히 필수이고(공식 문서 확인),
  # NodePool/AKSNodeClass CRD 설치는 이 모듈 밖(GitOps 소관, eks-cluster와 같은 경계).
  #
  # 네트워킹 조합 제약(cni_mode = "pod_subnet"과 절대 못 씀)은 variables.tf의
  # enable_karpenter validation이 plan에서 강제한다 — 근거·출처는 그 변수 설명 참조.
  #
  # default_node_pools = "None" 고정(하드코딩, 변수 아님) — 기본값("Auto")이면 Azure가
  # Karpenter NodePool을 "default"·"system-surge" 2개 자동 생성한다. GitOps가
  # NodePool/AKSNodeClass를 전량 소유하게 하려면(ArgoCD self-heal/prune과 "정의 안 된
  # 리소스" 충돌을 막으려면) 이 자동 생성을 꺼야 한다 — tofu validate로 mode 양쪽(Auto·
  # Manual) 모두와 공존 가능함을 확인했다(2026-08-28).
  node_provisioning_profile {
    mode               = var.enable_karpenter ? "Auto" : "Manual"
    default_node_pools = "None"
  }

  tags = var.tags

  lifecycle {
    # 재사용 모듈이 소비자에게 삭제 보호를 위임할 수 있는 유일한 수단이다 — AKS에는
    # 네이티브 삭제 보호 인자가 없다(0-13).
    prevent_destroy = var.deletion_protection
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "this" {
  for_each = local.enabled ? var.node_pools : {}

  name                  = local.node_pool_names[each.key]
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this[0].id
  mode                  = "User"

  vm_size              = each.value.vm_size
  node_count           = each.value.auto_scaling_enabled ? null : each.value.node_count
  auto_scaling_enabled = each.value.auto_scaling_enabled
  min_count            = each.value.auto_scaling_enabled ? each.value.min_count : null
  max_count            = each.value.auto_scaling_enabled ? each.value.max_count : null
  os_disk_size_gb      = each.value.os_disk_size_gb
  max_pods             = each.value.max_pods
  zones                = each.value.zones
  node_labels          = each.value.node_labels
  node_taints          = each.value.node_taints

  # 전 노드 풀이 pod_subnet_id 하나를 공유한다(축10, 풀별 인자이지만 클러스터 단위 단일
  # 입력으로 계약한다) — 풀별 오버라이드는 이월. cni_mode가 pod_subnet이 아니면 null
  # (local.pod_subnet_id_by_mode, cni_mode 변수 설명 참조).
  vnet_subnet_id = var.node_subnet_id
  pod_subnet_id  = local.pod_subnet_id_by_mode

  temporary_name_for_rotation = "${local.node_pool_names[each.key]}t"

  tags = var.tags
}
