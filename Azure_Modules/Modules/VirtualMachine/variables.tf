variable "resource_group_name" {
  type        = string
  description = "Specifies the name of the Resource Group in which the Virtual Machine should exist"
}

variable "vm_additional_tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resource"
  default     = {}
}

variable "dependencies" {
  type        = list(any)
  description = "Specifies the modules that the Virtual Machine Resource depends on."
  default     = []
}

# -
# - Linux VM's
# -
variable "linux_vms" {
  type = map(object({
    name                             = string
    vm_size                          = string
    zone                             = string
    assign_identity                  = bool
    lb_backend_pool_names            = list(string)
    vm_nic_keys                      = list(string)
    avaialability_set_key            = string
    lb_nat_rule_names                = list(string)
    app_security_group_names         = list(string)
    app_gateway_name                 = string
    disable_password_authentication  = bool
    source_image_reference_publisher = string
    source_image_reference_offer     = string
    source_image_reference_sku       = string
    source_image_reference_version   = string
    storage_os_disk_caching          = string
    managed_disk_type                = string
    disk_size_gb                     = number
    write_accelerator_enabled        = bool
    recovery_services_vault_key      = string
    enable_cmk_disk_encryption       = bool
    custom_data_path                 = string
    custom_data_args                 = map(string)
    diagnostics_storage_config_path  = string
    custom_script = object({
      commandToExecute   = string
      scriptPath         = string
      scriptArgs         = map(string)
      fileUris           = list(string)
      storageAccountName = string
    })
  }))
  description = "Map containing Linux VM objects"
  default     = {}
}

variable "linux_vm_nics" {
  type = map(object({
    name                          = string
    subnet_name                   = string
    internal_dns_name_label       = string
    enable_ip_forwarding          = bool
    enable_accelerated_networking = bool
    dns_servers                   = list(string)
    nic_ip_configurations = list(object({
      name      = string
      static_ip = string
    }))
  }))
}

variable "subnet_ids" {
  type        = map(string)
  description = "Map of network interfaces subnets"
  default     = {}
}

variable "lb_backend_address_pool_map" {
  type        = map(string)
  description = "Map of network interfaces internal load balancers backend pool id's"
  default     = {}
}

variable "lb_nat_rule_map" {
  type        = map(string)
  description = "Map of network interfaces to LB NAT rules"
  default     = {}
}

variable "app_security_group_ids_map" {
  type        = map(string)
  description = "Specifies the Map of network interfaces Application Security Group Id's"
  default     = {}
}

variable "application_gateway_backend_pool_ids_map" {
  type        = map(string)
  description = "Specifies the Map of network interfaces Application Gateway Backend Address Pool Id's"
  default     = {}
}

variable "application_gateway_backend_pools" {
  type        = map(list(string))
  description = "Specifies the Map of Application Gateway Backend Address Pool Names by Application Gateway Name"
  default     = {}
}

variable "key_vault_id" {
  type        = string
  description = "The Id of the Key Vault to which all secrets should be stored"
}

variable "administrator_user_name" {
  type        = string
  description = "Specifies the name of the local administrator account"
}

variable "administrator_login_password" {
  type        = string
  description = "Specifies the password associated with the local administrator account"
  default     = null
}

variable "linux_image_ids" {
  type        = map(string)
  description = "Specifies the Map of image Id's from which the Virtual Machines should be created."
  default     = {}
}

variable "recovery_services_vaults" {
  type        = map(any)
  description = "Map of recovery services vaults"
  default     = null
}

# -
# - Linux VM Boot Diagnostics
# -
variable "sa_bootdiag_storage_uri" {
  type        = string
  description = "Azure Storage Account Primary Queue Service Endpoint."
}

# -
# - Diagnostics Extensions
# -
variable "diagnostics_sa_name" {
  type        = string
  description = "The name of diagnostics storage account"
}

variable "law_workspace_id" {
  type        = string
  description = "Log analytics workspace resource workspace id"
}

variable "law_workspace_key" {
  type        = string
  description = "Log analytics workspace primary shared key"
}

# -
# - Managed Disks
# -
variable "managed_data_disks" {
  type = map(object({
    disk_name                 = string
    vm_key                    = string
    lun                       = string
    storage_account_type      = string
    disk_size                 = number
    caching                   = string
    write_accelerator_enabled = bool
    create_option             = string
    os_type                   = string
    source_resource_id        = string
  }))
  description = "Map containing storage data disk configurations"
  default     = {}
}

# -
# - Availability Sets
# -
variable "availability_sets" {
  type = map(object({
    name                         = string
    platform_update_domain_count = number
    platform_fault_domain_count  = number
  }))
  description = "Map containing availability set configurations"
  default     = {}
}

# -
# - Windows VM's
# -
variable "windows_vms" {
  type = map(object({
    name                             = string
    vm_size                          = string
    zones                            = string
    assign_identity                  = bool
    subnet_name                      = string
    lb_backend_pool_name             = string
    source_image_reference_publisher = string
    source_image_reference_offer     = string
    source_image_reference_sku       = string
    source_image_reference_version   = string
    storage_os_disk_caching          = string
    managed_disk_type                = string
    disk_size_gb                     = number
    write_accelerator_enabled        = bool
    disk_encryption_set_id           = string
    internal_dns_name_label          = string
    enable_ip_forwarding             = bool
    enable_accelerated_networking    = bool
    dns_servers                      = list(string)
    custom_data_path                 = string
    custom_data_args                 = map(string)
    static_ip                        = string
  }))
  description = "Map containing windows vm's"
  default     = {}
}

variable "windows_image_id" {
  type        = string
  description = "Specifies the Id of the image which this Virtual Machine should be created from"
  default     = null
}
