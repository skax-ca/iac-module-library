# cross-account-trust-role

크로스 계정 신뢰 Role 1개. 지정한 principal만 assume할 수 있다.

## Usage

```hcl
module "spoke_trust_role" {
  source = "git::https://github.com/skax-ca/iac-module-library.git//modules/aws/cross-account-trust-role?ref=cross-account-trust-role-vX.Y.Z"

  naming                 = { workload = "spoke1", env = "prd", region_code = "an2" }
  purpose                = "argocd-hub"
  trusted_principal_arns = [module.eks.argocd_hub_iam_role_arn] # 허브 계정의 신뢰 principal
}
```

`vX.Y.Z`는 자리표시자다. 실제 최신 태그는 `git tag -l 'cross-account-trust-role-v*'`로 확인한다.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.60.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | kill switch(파괴 방향). false면 이 모듈의 전 리소스를 파기한다.<br/>false일 때 스칼라 출력은 전부 null이 된다. | `bool` | `true` | no |
| <a name="input_naming"></a> [naming](#input\_naming) | Name 합성용 네이밍 요소. 모듈이 리소스 타입별 약어를 조합하므로<br/>소비자는 약어를 직접 타이핑하지 않는다.<br/>예: {workload = "spoke1", env = "prd", region\_code = "an2"} → iamr-spoke1-prd-an2-argocd-hub | <pre>object({<br/>    workload    = string<br/>    env         = string<br/>    region_code = string<br/>  })</pre> | n/a | yes |
| <a name="input_purpose"></a> [purpose](#input\_purpose) | Name 태그의 purpose 토큰. 기본값이 없다 = 필수 입력이다.<br/><br/>⚠️ 이 모듈은 workbench와 달리 고정 용도(예: "workbench")로 좁히지 않는다. 여러 목적의<br/>크로스 계정 신뢰 경계를 만드는 데 재사용되므로 소비자가 매번 명시한다(예: "argocd-hub"). | `string` | n/a | yes |
| <a name="input_session_duration_seconds"></a> [session\_duration\_seconds](#input\_session\_duration\_seconds) | assume-role 세션 최대 지속 시간(초). aws\_iam\_role의 max\_session\_duration으로 간다. | `number` | `3600` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | 이 모듈이 만드는 전 리소스에 추가할 태그.<br/>거버넌스 태그(Workload·Env·Owner 등)는 프로젝트 루트의 provider default\_tags 소관이므로<br/>여기에 반복하지 않는다. | `map(string)` | `{}` | no |
| <a name="input_trusted_principal_arns"></a> [trusted\_principal\_arns](#input\_trusted\_principal\_arns) | 이 Role을 assume할 수 있는 IAM Role/User ARN 목록(trust policy의 Principal).<br/><br/>⛔ 계정 root(`:root`)나 와일드카드(`*`)는 허용하지 않는다. 정확히 어느 principal이<br/>이 신뢰 경계를 넘는지 ARN 단위로 못박는 것이 이 모듈의 존재 이유다(아래 validation). | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | 신뢰 Role ARN. 소비 루트가 eks-cluster의 access\_entries principal\_arn으로 넘긴다.<br/><br/>⛔ 이 모듈은 Access Entry를 직접 만들지 않는다. 모듈이 서로를 직접 참조하지 않는다는<br/>원칙에 따라 배포 루트에서만 연결한다. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | 신뢰 Role 이름. |
<!-- END_TF_DOCS -->
