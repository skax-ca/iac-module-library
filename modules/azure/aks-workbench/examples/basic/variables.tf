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
  description = "Azure 리전. region_code와 별개로 관리한다(리전코드는 이름 조합용 약어다)."
  type        = string
  default     = "koreacentral"
}

variable "admin_ssh_public_key" {
  description = <<-EOT
    workbench 로컬 계정의 SSH 공개키. 기본값을 두지 않는다. 이 예제를 실제로 validate·apply
    하려면 `ssh-keygen -t ed25519`로 만든 공개키를 소비자가 직접 채운다.
  EOT
  type        = string
}
