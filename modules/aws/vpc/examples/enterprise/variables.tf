# 예제는 **인자 없이 `tofu validate`가 도는 상태**를 유지한다.
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
