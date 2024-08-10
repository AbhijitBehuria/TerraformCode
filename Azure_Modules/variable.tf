#############################################################################
# Resource Group VARIABLES
#############################################################################

variable "resource_group_name" {
  type        = string
  description = "The Azure region where your resources will be created"
}

variable "location" {
  type        = string
  description = "The Azure region where your resources will be created"
}
variable "name" {
  type        = string
  description = "The Azure resource group where your resources will be created"
}
variable "additional_tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resource."
}
#############################################################################
# Virtual network VARIABLES
#############################################################################

# -
# - Virtual Network object
# -
variable "virtual_networks" {
  description = "The virtal networks with their properties."
  type = map(object({
    name          = string
    address_space = list(string)
    dns_servers   = list(string)
    ddos_protection_plan = object({
      id     = string
      enable = bool
    })
  }))
}

variable "vnet_peering" {
  description = "Vnet Peering to the destination Vnet"
  type = map(object({
    destination_vnet_name        = string
    destination_vnet_rg          = string
    vnet_key                     = string
    allow_virtual_network_access = bool
    allow_forwarded_traffic      = bool
    allow_gateway_transit        = bool
    use_remote_gateways          = bool
  }))
}

# -
# - Subnet object
# -
variable "subnets" {
  description = "The virtal networks subnets with their properties."
  type = map(object({
    name              = string
    vnet_key          = string
    nsg_key           = string
    rt_key            = string
    address_prefixes  = list(string)
    pe_enable         = bool
    service_endpoints = list(string)
    delegation = list(object({
      name = string
      service_delegation = list(object({
        name    = string
        actions = list(string)
      }))
    }))
  }))
}

# -
# - Route Table object
# -
variable "route_tables" {
  description = "The route tables with their properties."
  type = map(object({
    name                          = string
    disable_bgp_route_propagation = bool
    routes = list(object({
      name                   = string
      address_prefix         = string
      next_hop_type          = string
      next_hop_in_ip_address = string
      azure_firewall_name    = string
    }))
  }))
}

# -
# - Network Security Group object
# -
variable "network_security_groups" {
  description = "The network security groups with their properties."
  type = map(object({
    name = string
    tags = map(string)
    security_rules = list(object({
      name                                         = string
      description                                  = string
      protocol                                     = string
      direction                                    = string
      access                                       = string
      priority                                     = number
      source_address_prefix                        = string
      source_address_prefixes                      = list(string)
      destination_address_prefix                   = string
      destination_address_prefixes                 = list(string)
      source_port_range                            = string
      source_port_ranges                           = list(string)
      destination_port_range                       = string
      destination_port_ranges                      = list(string)
      source_application_security_group_names      = list(string)
      destination_application_security_group_names = list(string)
    }))
  }))
}

variable "app_security_group_ids_map" {
  type        = map(string)
  description = "Specifies the Map of Application Security Group Id's"
  default     = {}
}

############################
# log analytics
############################
variable "laname" {
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

############################
# Storage Account
############################
variable "storage_accounts" {
  type = map(object({
    name            = string
    sku             = string
    account_kind    = string
    access_tier     = string
    assign_identity = bool
    cmk_enable      = bool
    network_rules = object({
      bypass                     = list(string) # (Optional) Specifies whether traffic is bypassed for Logging/Metrics/AzureServices. Valid options are any combination of Logging, Metrics, AzureServices, or None.
      default_action             = string       # (Required) The Default Action to use when no rules match from ip_rules / virtual_network_subnet_ids. Possible values are Allow and Deny.
      ip_rules                   = list(string) # (Optional) One or more IP Addresses, or CIDR Blocks which should be able to access the Key Vault.
      virtual_network_subnet_ids = list(string) # (Optional) One or more Subnet ID's which should be able to access this Key Vault.
    })
  enable_large_file_share = bool
  }))
  description = "Map of storage accouts which needs to be created in a resource group"
}

############################
# Container
############################ 
variable "containers" {
  type = map(object({
    name                  = string
    storage_account_name  = string
    container_access_type = string
  }))
  description = "Map of Storage Containers"
}

############################
# Bolb
############################ 
variable "blobs" {
  type = map(object({
    name                   = string
    storage_account_name   = string
    storage_container_name = string
    type                   = string
    size                   = number
    content_type           = string
    source_uri             = string
    metadata               = map(any)
  }))
  description = "Map of Storage Blobs"
}

############################
# Queue
############################ 
variable "queues" {
  type = map(object({
    name                 = string
    storage_account_name = string
  }))
  description = "Map of Storages Queues"
}

############################
# File Share
############################ 
variable "file_shares" {
  type = map(object({
    name                 = string
    storage_account_name = string
    quota                = number
  }))
  description = "Map of Storages File Shares"
}

############################
# Table
############################ 
variable "tables" {
  type = map(object({
    name                 = string
    storage_account_name = string
  }))
  description = "Map of Storage Tables"
}

############################
# keyvault
############################
variable "keyvault_name" {
  type        = string
  description = "Specifies the name of the Key Vault"
}

variable "enabled_for_deployment" {
  type        = bool
  description = "Allow Virtual Machines to retrieve certificates stored as secrets from the key vault."
  default     = null
}

variable "enabled_for_disk_encryption" {
  type        = bool
  description = "Allow Disk Encryption to retrieve secrets from the vault and unwrap keys."
  default     = null
}

variable "enabled_for_template_deployment" {
  type        = bool
  description = "Allow Resource Manager to retrieve secrets from the key vault."
  default     = null
}

variable "soft_delete_enabled" {
  type        = bool
  description = "Allow Soft Delete be enabled for this Key Vault"
  default     = true
}

variable "purge_protection_enabled" {
  type        = bool
  description = "Allow purge_protection be enabled for this Key Vault"
  default     = true
}

variable "sku_name" {
  type        = string
  description = "The name of the SKU used for the Key Vault. The options are: `standard`, `premium`."
  default     = "standard"
}

variable "network_acls" {
  type = object({
    bypass                     = string       # (Required) Specifies which traffic can bypass the network rules. Possible values are AzureServices and None.
    default_action             = string       # (Required) The Default Action to use when no rules match from ip_rules / virtual_network_subnet_ids. Possible values are Allow and Deny.
    ip_rules                   = list(string) # (Optional) One or more IP Addresses, or CIDR Blocks which should be able to access the Key Vault.
    virtual_network_subnet_ids = list(string) # (Optional) One or more Subnet ID's which should be able to access this Key Vault.
  })
  description = "Specifies values for Key Vault network access"
  default     = null
}

variable "diagnostics_storage_account_name" {
  type        = string
  description = "Specifies the name of the Storage Account where Diagnostics Data should be sent"
}

########################
# Key Vault Serets
########################
variable "secrets" {
  type        = map(string)
  description = "A map of secrets for the Key Vault"
  default     = {}
}

########################
# Key Vault Access Policy
########################
variable "access_policies" {
  type = map(object({
    group_names             = list(string)
    object_ids              = list(string)
    user_principal_names    = list(string)
    certificate_permissions = list(string)
    key_permissions         = list(string)
    secret_permissions      = list(string)
    storage_permissions     = list(string)
  }))
  description = "A map of access policies for the Key Vault"
  default     = {}
}

###################################
#LB (balancers)
################################
variable "load_balancers" {
  type = map(object({
    name = string
    sku  = string
    frontend_ips = list(object({
      name        = string
      subnet_name = string
      static_ip   = string
      zones       = list(string)
    }))
    backend_pool_names = list(string)
    enable_public_ip      = bool
    public_ip_name     = string
  }))
  description = "Map containing load balancers"
}

variable "load_balancer_rules" {
  type = map(object({
    name                      = string
    lb_key                    = string
    frontend_ip_name          = string
    backend_pool_name         = string
    lb_protocol               = string
    lb_port                   = string
    backend_port              = number
    enable_floating_ip        = bool
    disable_outbound_snat     = bool
    enable_tcp_reset          = bool
    probe_port                = number
    probe_protocol            = string
    request_path              = string
    probe_interval            = number
    probe_unhealthy_threshold = number
    load_distribution         = string
    idle_timeout_in_minutes   = number
  }))
  description = "Map containing load balancer rule and probe parameters"
}

variable "load_balancer_nat_pools" {
  type = map(object({
    name             = string
    lb_key           = string
    frontend_ip_name = string
    lb_port_start    = number
    lb_port_end      = number
    backend_port     = number
  }))
  description = "Map containing load balancer nat pool parameters"
}

variable "lb_outbound_rules" {
  type = map(object({
    name                            = string
    lb_key                          = string
    protocol                        = string
    backend_pool_name               = string
    allocated_outbound_ports        = number
    frontend_ip_configuration_names = list(string)

  }))
  description = "Map containing outbound nat rule parameters"
}

variable "load_balancer_nat_rules" {
  type = map(object({
    name                    = string
    lb_key                  = string
    frontend_ip_name        = string
    lb_port                 = number
    backend_port            = number
    idle_timeout_in_minutes = number
  }))
  description = "Map containing load balancer nat rule parameters"
}

variable "zones" {
  type        = list(string)
  description = "A list of Availability Zones which the Load Balancer's IP Addresses should be created in"
}

#Private DNS zone

variable "private_dns_zones" {
  type = map(object({
    dns_zone_name = string
    vnet_links = list(object({
      zone_to_vnet_link_name   = string
      vnet_name                = string
      zone_to_vnet_link_exists = bool
    }))
    zone_exists          = bool
    registration_enabled = bool
  }))
  description = "Map containing Private DNS Zone Objects"
}

#Private DNS records

variable "dns_a_records" {
  type = map(object({
    a_record_name         = string
    dns_zone_name         = string
    ttl                   = number
    ip_addresses          = list(string)
    private_endpoint_name = string
  }))
  description = "Map containing Private DNS A Records Objects"
}
/*
variable "a_records_depends_on" {
  type        = any
  description = "Resoure/Module on which DNS A Record module depends on"
}*/

variable "private_endpoint_ip_addresses" {
  type        = map(string)
  description = "Map of Private Endpoint IP Addresses"
  default     = {}
}

## Private Link services vars

variable "private_link_services" {
  type = map(object({
    name                           = string       # (Required) Specifies the name of this Private Link Service.
    frontend_ip_config_name        = string       # (Required) Frontend IP Configuration name from a Standard Load Balancer, where traffic from the Private Link Service should be routed    
    subnet_name                    = string       # (Required) Specifies the name of the Subnet which should be used for the Private Link Service.
    private_ip_address             = string       # (Optional) Specifies a Private Static IP Address for this IP Configuration.
    private_ip_address_version     = string       # (Optional) The version of the IP Protocol which should be used
    visibility_subscription_ids    = list(string) # (Optional) A list of Subscription UUID/GUID's that will be able to see this Private Link Service.
    auto_approval_subscription_ids = list(string) # (Optional) A list of Subscription UUID/GUID's that will be automatically be able to use this Private Link Service.
  }))
  description = "Map containing private link services"
}

#Private endpoint vars

variable "private_endpoints" {
  type = map(object({
    name                 = string
    subnet_name          = string
    resource_name        = string
    group_ids            = list(string)
    approval_required    = bool
    approval_message     = string
    dns_zone_name        = string
    zone_exists          = bool
    registration_enabled = bool
    vnet_links = list(object({
      zone_to_vnet_link_name   = string
      vnet_name                = string
      zone_to_vnet_link_exists = bool
    }))
    dns_a_records = list(object({
      name                  = string
      ttl                   = number
      ip_addresses          = list(string)
      private_endpoint_name = string
    }))
  }))
  description = "Map containing Private Endpoint and Private DNS Zone details"
}
#RSV vars

variable "recovery_services_vaults" {
  type = map(object({
    name                = string # (Required) Specifies the name of the Recovery Services Vault.
    sku                 = string # (Required) Sets the vault's SKU. Possible values include: Standard, RS0.
    soft_delete_enabled = bool   # (Optional) Is soft delete enable for this Vault? Defaults to true.
    policy_name         = string # (Required) Specifies the name of the Backup Policy.
    backup_settings = object({
      frequency = string # (Required) Sets the backup frequency. Must be either Daily orWeekly.
      time      = string # (Required) The time of day to perform the backup in 24hour format.
      weekdays  = string # (Optional) The days of the week to perform backups on and weekdays should be seperated by ','(comma).
    })
    retention_settings = object({
      daily   = number # (Required) The number of daily backups to keep. Must be between 1 and 9999
      weekly  = string # count:weekdays and weekdays should be seperated by ','(comma)
      monthly = string # count:weekdays:weeks and weekdays & weeks should be seperated by ','(comma)
      yearly  = string # count:weekdays:weeks:months and weekdays, weeks & months should be seperated by ','(comma)
    })
  }))
  description = "Map of recover services vaults properties"
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

variable "lb_nat_rule_map" {
  type        = map(string)
  description = "Map of network interfaces to LB NAT rules"
  default     = {}
}

variable "administrator_user_name" {
  type        = string
  description = "Specifies the name of the local administrator account"
}

variable "administrator_login_password" {
  type        = string
  description = "Specifies the password associated with the local administrator account"
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