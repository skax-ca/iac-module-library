variable "workload" {
  description = "naming 객체의 workload 토큰."
  type        = string
  default     = "demo"
}

variable "env" {
  description = "naming 객체의 env 토큰."
  type        = string
  default     = "dev"
}

variable "region_code" {
  description = "naming 객체의 리전 코드 토큰."
  type        = string
  default     = "krc"
}

variable "location" {
  description = "Azure 리전. region_code와 별개로 관리한다(리전코드는 이름 조합용 약어일 뿐이다)."
  type        = string
  default     = "koreacentral"
}
