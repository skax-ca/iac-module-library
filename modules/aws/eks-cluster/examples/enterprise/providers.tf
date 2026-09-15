# 거버넌스 태그는 **루트가 default_tags로** 100% 자동 부착한다.
# 모듈은 거버넌스 태그를 신경 쓰지 않고 Name 태그만 조합한다. 이 분리가 규약의 핵심이다.
# 소비 프로젝트도 이 형태를 그대로 쓴다.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.env
      Workload    = var.workload
      RegionCode  = var.region_code
      ManagedBy   = "opentofu"
      Repository  = var.repository
    }
  }

  # ⚠️ 실제 계정에서는 ignore_tags가 필요하다. 랜딩존/AFT의 자동 태거가 붙인 태그는
  # state에 없어 방치하면 전 리소스에 "태그 제거" 가짜 diff가 생긴다.
  # 예제는 계정에 붙지 않으므로 비워 두되, 소비 프로젝트에서는 실제 키를 채운다.
}
