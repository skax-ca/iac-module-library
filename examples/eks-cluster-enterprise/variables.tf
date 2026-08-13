# 예제는 **인자 없이 `tofu validate`가 도는 상태**를 유지한다(examples/AGENTS.md).
# 그래서 모든 변수에 기본값이 있다. 워크로드 코드는 가상값(demo)을 쓴다 —
# 이 repo는 특정 워크로드를 고정하지 않는다.

variable "aws_region" {
  description = "리소스를 만들 리전."
  type        = string
  default     = "ap-northeast-2"
}

variable "workload" {
  description = "워크로드 코드. Name 태그와 거버넌스 태그에 함께 쓰인다."
  type        = string
  default     = "demo"
}

variable "env" {
  description = "환경 코드(prd/stg/dev)."
  type        = string
  default     = "dev"
}

variable "region_code" {
  description = "Name 태그에 쓰는 리전 약어. aws_region과 짝이 맞아야 한다(an2 ↔ ap-northeast-2)."
  type        = string
  default     = "an2"
}

variable "repository" {
  description = "거버넌스 태그 Repository 값. 소비 프로젝트는 자기 repo를 지정한다."
  type        = string
  default     = "skax-ca/iac-module-library"
}

variable "workbench_ami_id" {
  description = <<-EOT
    workbench 이 쓸 AMI ID.

    ⛔ **아래 기본값은 자리표시자다. 반드시 조회한 값으로 바꾼다.**
      aws ssm get-parameter --region <region> \
        --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
        --query Parameter.Value --output text
    조회한 **값을 커밋**한다 — 조회를 코드에 넣으면 AWS 릴리스마다 인스턴스가 리뷰 없이 재생성된다.

    ⚠️ instance_type(기본 t4g.nano = arm64)과 아키텍처가 맞아야 한다. x86 을 쓰려면 위 경로의
       `-x86_64` 파라미터를 조회하고 모듈에 instance_type 도 함께 넘긴다.

    존재하지 않는 ID 를 자리표시자로 두는 것은 의도된 선택이다. 그대로 apply 하면 즉시
       실패해 값을 바꿔야 함이 드러난다 — 더미 zone ARN 은 반대로 apply 가
       **성공해서** 존재하지 않는 zone 을 가리키는 IAM 이 조용히 굳는 것이 문제였다.
  EOT
  type        = string
  default     = "ami-00000000000000000"
}
