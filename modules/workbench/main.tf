# workbench 코어 리소스 — 보안 그룹 · 인스턴스
#
# 모든 리소스가 var.workbench_enabled 게이트를 지난다. IAM은 iam.tf가 소유한다.
#
# 계약: docs/module-catalog.md

locals {
  enabled = var.workbench_enabled

  # Name 태그의 중간 토큰. 소비자가 약어를 타이핑하지 않도록 모듈이 조합한다.
  name_mid  = "${var.naming.workload}-${var.naming.env}-${var.naming.region_code}"
  name_tail = "${var.purpose}-${var.serial}"

  role_name     = "iamr-${local.name_mid}-${local.name_tail}"
  instance_name = "ec2-${local.name_mid}-${local.name_tail}"
  sg_name       = "sgr-${local.name_mid}-${local.name_tail}"
  volume_name   = "vol-${local.name_mid}-${local.name_tail}"

  # EKS 연동은 두 변수가 **함께** 있을 때만 성립한다(variables.tf의 교차변수 가드가 강제).
  # 여기서 둘 다 검사하는 것은 방어가 아니라 의도 표현이다 — 한쪽만으로는 층이 반쪽이다.
  eks_integration_enabled = local.enabled && var.eks_cluster_name != null && var.eks_cluster_arn != null

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    kubectl_version = var.kubectl_version
    helm_version    = var.helm_version
    argocd_version  = var.argocd_version

    # 진단·조작 도구
    eks_node_viewer_version = var.eks_node_viewer_version
    # krew 는 kubectl 없이는 의미가 없다 — 조건을 여기서 접어 템플릿 분기를 하나로 줄인다.
    krew_version = var.kubectl_version != null ? var.krew_version : null
    krew_plugins = var.krew_plugins
    # kubeconfig 생성 조건을 로컬과 일치시킨다 — 권한 없이 kubeconfig만 만들지 않는다.
    eks_cluster_name = local.eks_integration_enabled ? var.eks_cluster_name : null
    region           = data.aws_region.current.region
  })
}

# 리전을 하드코딩하지 않는다 — update-kubeconfig가 리전을 요구하고, 이 모듈은 리전 이식성이 계약이다.
data "aws_region" "current" {}

# ── 보안 그룹 ───────────────────────────────────────────────────────────────────
#
# ingress 규칙이 하나도 없다. SSM Agent가 아웃바운드로 연결을 맺고 세션이 그 연결을 역방향으로
# 흐르므로 인바운드가 원천적으로 불필요하다 — SSH 키·22번 노출·감사 공백이 함께 사라진다.
#
# ⛔ inline ingress/egress 블록을 쓰지 않는다. rule은 별도 리소스로만 만든다.
resource "aws_security_group" "this" {
  count = local.enabled ? 1 : 0

  name        = local.sg_name
  description = "Workbench host - outbound HTTPS only, no inbound (SSM Session Manager)"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = local.sg_name
  })

  # SG는 rule 없이 먼저 생성되고 rule이 나중에 ID를 참조한다 — 순환을 이렇게 끊는다.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "https" {
  for_each = local.enabled ? toset(var.egress_cidr_blocks) : toset([])

  security_group_id = aws_security_group.this[0].id
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS out - SSM control plane, package and chart repositories"

  tags = merge(var.tags, {
    Name = "${local.sg_name}-egress-https"
  })
}

# ── 인스턴스 ──────────────────────────────────────────────────────────────────

resource "aws_instance" "this" {
  count = local.enabled ? 1 : 0

  # AMI는 변수로 받은 명시 핀이다. data source 조회를 두지 않는 것이 그 결정의 실물이다.
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this[0].id]
  iam_instance_profile   = aws_iam_instance_profile.this[0].name

  # ── 하드닝 — 변수로 열지 않는다 ────────────────────────────────────────────
  #
  # key_name·associate_public_ip_address를 지정하지 않는 것도 계약의 일부다.
  # 서브넷이 private이면 공인 IP는 애초에 붙지 않고, 키페어가 없으면 SSH 경로가 존재하지 않는다.

  metadata_options {
    http_endpoint = "enabled"
    # IMDSv2 강제. trivy AVD-AWS-0028이 검사하는 항목이다.
    http_tokens = "required"
    # ⚠️ hop limit 1은 컨테이너에서 IMDS에 닿지 못한다는 뜻이다. workbench는 도구를 호스트에서
    #    직접 실행하는 지점이라 지금 요구에는 맞다 — 컨테이너 요구가 생기면 그때 변수를 연다.
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    kms_key_id  = var.root_volume_kms_key_id
    volume_type = "gp3"
    volume_size = var.root_volume_size
  }

  # ⚠️ root_block_device.tags가 아니라 volume_tags를 쓴다.
  #    전자는 인스턴스 생성 **후** 별도 API 호출로 붙어서, 볼륨 태그를 생성 시점에 요구하는
  #    SCP·ABAC 정책(ec2:CreateAction 조건)에 걸린다. 고객사 계정에는 그런 가드레일이 흔하다.
  #    root 볼륨 하나뿐이라 "모든 볼륨에 균일 적용"이라는 volume_tags의 제약도 문제가 되지 않는다.
  volume_tags = merge(var.tags, {
    Name = local.volume_name
  })

  user_data = local.user_data
  # 도구 버전·클러스터를 바꾸면 재생성한다. workbench는 상태를 담지 않으므로 재생성이 안전하고,
  # in-place 갱신은 "코드와 실물이 다른" 상태를 만든다(user_data는 부팅 시에만 실행된다).
  user_data_replace_on_change = true

  tags = merge(var.tags, {
    Name = local.instance_name
  })
}
