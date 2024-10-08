## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 0.12.20 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 0.8.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 2.14.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | ~> 0.8.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 2.14.0 |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_key_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_key_vault_access_policy.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_access_policy) | resource |
| [azurerm_key_vault_secret.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_monitor_diagnostic_setting.storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [null_resource.dependency_kv](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [azuread_group.this](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/group) | data source |
| [azuread_user.this](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/user) | data source |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_policies"></a> [access\_policies](#input\_access\_policies) | A map of access policies for the Key Vault | <pre>map(object({<br>    group_names             = list(string)<br>    object_ids              = list(string)<br>    user_principal_names    = list(string)<br>    certificate_permissions = list(string)<br>    key_permissions         = list(string)<br>    secret_permissions      = list(string)<br>    storage_permissions     = list(string)<br>  }))</pre> | `{}` | no |
| <a name="input_diagnostics_storage_account_name"></a> [diagnostics\_storage\_account\_name](#input\_diagnostics\_storage\_account\_name) | Specifies the name of the Storage Account where Diagnostics Data should be sent | `string` | n/a | yes |
| <a name="input_enabled_for_deployment"></a> [enabled\_for\_deployment](#input\_enabled\_for\_deployment) | Allow Virtual Machines to retrieve certificates stored as secrets from the key vault. | `bool` | `null` | no |
| <a name="input_enabled_for_disk_encryption"></a> [enabled\_for\_disk\_encryption](#input\_enabled\_for\_disk\_encryption) | Allow Disk Encryption to retrieve secrets from the vault and unwrap keys. | `bool` | `null` | no |
| <a name="input_enabled_for_template_deployment"></a> [enabled\_for\_template\_deployment](#input\_enabled\_for\_template\_deployment) | Allow Resource Manager to retrieve secrets from the key vault. | `bool` | `null` | no |
| <a name="input_kv_additional_tags"></a> [kv\_additional\_tags](#input\_kv\_additional\_tags) | A mapping of tags to assign to the resource. | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Specifies the name of the Key Vault | `string` | n/a | yes |
| <a name="input_network_acls"></a> [network\_acls](#input\_network\_acls) | Specifies values for Key Vault network access | <pre>object({<br>    bypass                     = string       # (Required) Specifies which traffic can bypass the network rules. Possible values are AzureServices and None.<br>    default_action             = string       # (Required) The Default Action to use when no rules match from ip_rules / virtual_network_subnet_ids. Possible values are Allow and Deny.<br>    ip_rules                   = list(string) # (Optional) One or more IP Addresses, or CIDR Blocks which should be able to access the Key Vault.<br>    virtual_network_subnet_ids = list(string) # (Optional) One or more Subnet ID's which should be able to access this Key Vault.<br>  })</pre> | `null` | no |
| <a name="input_purge_protection_enabled"></a> [purge\_protection\_enabled](#input\_purge\_protection\_enabled) | Allow purge\_protection be enabled for this Key Vault | `bool` | `true` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | The name of the resource group in which to create the Key Vault | `string` | n/a | yes |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | A map of secrets for the Key Vault | `map(string)` | `{}` | no |
| <a name="input_sku_name"></a> [sku\_name](#input\_sku\_name) | The name of the SKU used for the Key Vault. The options are: `standard`, `premium`. | `string` | `"standard"` | no |
| <a name="input_soft_delete_enabled"></a> [soft\_delete\_enabled](#input\_soft\_delete\_enabled) | Allow Soft Delete be enabled for this Key Vault | `bool` | `true` | no |
| <a name="input_storage_account_ids_map"></a> [storage\_account\_ids\_map](#input\_storage\_account\_ids\_map) | Map of Storage Account Id's | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_depended_on_kv"></a> [depended\_on\_kv](#output\_depended\_on\_kv) | n/a |
| <a name="output_key_vault"></a> [key\_vault](#output\_key\_vault) | Key Vault details |
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | The Id of the Key Vault |
| <a name="output_key_vault_name"></a> [key\_vault\_name](#output\_key\_vault\_name) | The Name of the Key Vault |
| <a name="output_key_vault_policy"></a> [key\_vault\_policy](#output\_key\_vault\_policy) | Key Vault access policy details |
| <a name="output_key_vault_uri"></a> [key\_vault\_uri](#output\_key\_vault\_uri) | The URI of the Key Vault, used for performing operations on keys and secrets |
