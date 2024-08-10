# - Variables for Resource Group creation

variable "resource_group_name" {
  type        = string
  description = "The Name which should be used for this Resource Group."
}

variable "location" {
  type        = string
  description = "The Azure Region used for resources such as: key-vault, storage-account, log-analytics and resource group."
}

variable "rg_additional_tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resource."
  default     = {}
}
