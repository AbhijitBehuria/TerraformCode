
#Create Resource Groups
###########################################################################################
module "resourcegroup" {
  source    = "./modules/resourcegroup"
  resource_group_name           = var.name
  location                      = var.location
  rg_additional_tags            = var.additional_tags
}

###########################################################################################
#Create vnet & subnets
###########################################################################################
module "virtualnetwork" {
  source    = "./modules/virtualnetwork"
  resource_group_name              = module.resourcegroup.resource_group_name #var.resource_group_name
  virtual_networks                 = var.virtual_networks                 # VNet's Block
  subnets                          = var.subnets                          # Subnet's Block
  route_tables                     = var.route_tables                     # Route Tables Block
  net_additional_tags              = var.additional_tags                  # Additional Tags
  vnet_peering                     = var.vnet_peering                     # VNet Peering Block
  network_security_groups          = var.network_security_groups          # NSG Rules Block
  #dependencies                     = [module.ApplicationSecurityGroup.depended_on_asg, module.Firewall.depended_on_firewall]
} 
###########################################################################################
#Create Log Analytics
###########################################################################################

module "loganalytics" {
  source    = "./modules/loganalytics"
  resource_group_name              = module.resourcegroup.resource_group_name #var.resource_group_name
  name                             = var.laname    # Log Analytics Name
  sku                              = var.sku                              # Log Analytics SKU
  retention_in_days                = var.retention_in_days                # Log Analytics Retention In Days
  key_vault_id                     = module.keyvault.key_vault_id 
  law_additional_tags              = var.additional_tags
  #dependencies                     = [module.ApplicationSecurityGroup.depended_on_asg, module.Firewall.depended_on_firewall]
}
###########################################################################################
#Create Storage account
###########################################################################################
module "storageaccount" {
  source              = "./modules/storageaccount"
  resource_group_name = module.resourcegroup.resource_group_name
  key_vault_id        = module.keyvault.key_vault_id
  storage_accounts    = var.storage_accounts
  containers          = var.containers
  blobs               = var.blobs
  queues              = var.queues
  file_shares         = var.file_shares
  tables              = var.tables
  #enable_large_file_share = var.enable_large_file_share
  sa_additional_tags  = var.additional_tags
  #dependencies = [    module.BaseInfrastructure.depended_on_kv, module.PrivateEndpoint.depended_on_ado_pe  ]
}
###########################################################################################
#Create Keyvault
###########################################################################################

module "keyvault" {
  source    = "./modules/keyvault"
  resource_group_name              = module.resourcegroup.resource_group_name #var.resource_group_name
  storage_account_ids_map          = module.storageaccount.sa_ids_map
  diagnostics_storage_account_name = var.diagnostics_storage_account_name # Key Valut  Storage Account for Diagnostics 
  name                             = var.keyvault_name                    # Key Valut Name  
  sku_name                         = var.sku_name                         # Key Vault SKU Name
  network_acls                     = var.network_acls                     # Key Valut Network Access Block
  access_policies                  = var.access_policies                  # Key Vault Access Policies Block
  soft_delete_enabled              = var.soft_delete_enabled              # KV Soft Delete Flag
  purge_protection_enabled         = var.purge_protection_enabled         # KV Purge Protection Flag
  enabled_for_deployment           = var.enabled_for_deployment           # KV Enable for Deployment Flag
  enabled_for_disk_encryption      = var.enabled_for_disk_encryption      # KV Enable for Disk Encryption Flag
  enabled_for_template_deployment  = var.enabled_for_template_deployment  # KV Enable for Template Deployment Flag
  kv_additional_tags               = var.additional_tags
 # dependencies                     = [module.ApplicationSecurityGroup.depended_on_asg, module.Firewall.depended_on_firewall]
}

###########################################################################################
#Create LoadBalancer
###########################################################################################
module "loadbalancer" {
  source                  = "./modules/loadbalancer"
  load_balancers          = var.load_balancers
  resource_group_name     = module.resourcegroup.resource_group_name
  subnet_ids              = module.virtualnetwork.map_subnet_ids
  load_balancer_rules     = var.load_balancer_rules
  load_balancer_nat_rules = var.load_balancer_nat_rules
  lb_outbound_rules       = var.lb_outbound_rules
  load_balancer_nat_pools = var.load_balancer_nat_pools
  lb_additional_tags      = var.additional_tags
}

###########################################################################################
#Create Virtual Machine
###########################################################################################

locals {
  linux_image_ids = {
    nginxvm = null # var.nginxvm # This variable need to be create with VM name for each VM while consuming this Module.
    vm_name = null #var.vm_name
  }
}

module "Virtualmachine" {
  source                                   = "./modules/VirtualMachine"
  resource_group_name                      = module.resourcegroup.resource_group_name
  linux_vms                                = var.linux_vms
  linux_vm_nics                            = var.linux_vm_nics
  availability_sets                        = var.availability_sets
  linux_image_ids                          = local.linux_image_ids
  administrator_user_name                  = var.administrator_user_name
  administrator_login_password             = var.administrator_login_password
  key_vault_id                             = module.keyvault.key_vault_id
  subnet_ids                               = module.virtualnetwork.map_subnet_ids
  lb_backend_address_pool_map              = module.loadbalancer.pri_lb_backend_map_ids
  recovery_services_vaults                 = module.RecoveryServicesVault.map_recovery_vaults
  app_security_group_ids_map               = null #module.ApplicationSecurityGroup.app_security_group_ids_map
  application_gateway_backend_pool_ids_map = null #module.ApplicationGateway.application_gateway_backend_pool_ids_map
  application_gateway_backend_pools        = null #module.ApplicationGateway.application_gateway_backend_pools
  sa_bootdiag_storage_uri                  = module.storageaccount.primary_blob_endpoints[0]
  diagnostics_sa_name                      = module.storageaccount.sa_names[0]
  law_workspace_id                         = module.loganalytics.law_workspace_id
  law_workspace_key                        = module.loganalytics.law_key
  managed_data_disks                       = var.managed_data_disks
  lb_nat_rule_map                          = module.loadbalancer.pri_lb_natrule_map_ids
  vm_additional_tags                       = var.additional_tags
  #dependencies = [
  #  module.BaseInfrastructure.depended_on_kv, module.RecoveryServicesVault.depended_on_rsv,
  #  module.BaseInfrastructure.depended_on_sa, module.PrivateEndpoint.depended_on_ado_pe
 # ]
}
