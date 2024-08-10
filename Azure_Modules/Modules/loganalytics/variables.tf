variable "resource_group_name" {
  type        = string
  description = "The name of the resource group in which the Log Analytics workspace is created"
}

variable "key_vault_id" {
  type        = string
  description = "The Id of the Key Vault to which all secrets should be stored"
}

variable "dependencies" {
  type        = list(any)
  description = "Specifies the modules that the Log Analytics Workspace Resource depends on."
  default     = []
}

############################
# log analytics
############################

variable "name" {
  type        = string
  description = "Specifies the name of the Log Analytics Workspace"
}

variable "sku" {
  type        = string
  description = "Specifies the Sku of the Log Analytics Workspace. Possible values are Free, PerNode, Premium, Standard, Standalone, Unlimited, and PerGB2018"
}

variable "retention_in_days" {
  type        = string
  description = "The workspace data retention in days. Possible values range between 30 and 730"
}

variable "law_additional_tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resource."
  default     = {}
}
