
data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

# -
# - Storage Account Data Source for diagnostic logs
# - 
data "azurerm_storage_account" "diagnostics_storage_account" {
  name                = var.diagnostics_sa_name
  resource_group_name = data.azurerm_resource_group.this.name
  depends_on          = [null_resource.dependency_modules]
}

data "azurerm_storage_account_sas" "diagnostics_storage_account_sas" {
  connection_string = data.azurerm_storage_account.diagnostics_storage_account.primary_connection_string
  https_only        = true

  resource_types {
    service   = false
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = true
    file  = false
  }

  start  = timestamp()
  expiry = timeadd(timestamp(), "8760h")

  permissions {
    read    = true
    write   = true
    delete  = false
    list    = true
    add     = true
    create  = true
    update  = true
    process = true
  }
}

# -
# - Storage Account Data Source for custom script extension
# - 
data "azurerm_storage_account" "custom_script_storage_account" {
  for_each            = local.linux_vm_custom_script_storage_accounts
  name                = each.value
  resource_group_name = data.azurerm_resource_group.this.name
  depends_on          = [null_resource.dependency_modules]
}

# -
# - Get the current user config
# -
data "azurerm_client_config" "current" {}

locals {
  tags = merge(var.vm_additional_tags, data.azurerm_resource_group.this.tags)

  key_permissions         = ["get", "wrapkey", "unwrapkey"]
  secret_permissions      = ["get", "set", "list"]
  certificate_permissions = ["get", "create", "update", "list", "import"]
  storage_permissions     = ["get"]
}

# -
# - Generate Private/Public SSH Key for Linux Virtual Machine
# -
resource "tls_private_key" "this" {
  for_each  = var.linux_vms
  algorithm = "RSA"
  rsa_bits  = 2048
}

# -
# - Store Generated Private SSH Key to Key Vault Secrets

resource "azurerm_key_vault_secret" "this" {
  for_each     = var.linux_vms
  name         = each.value["name"]
  value        = lookup(tls_private_key.this, each.key)["private_key_pem"]
  key_vault_id = var.key_vault_id
  content_type = "password"
  expiration_date = "2022-12-03"

  lifecycle {
    ignore_changes = [value]
  }

  depends_on = [null_resource.dependency_modules]
}

#
#- Availability Set
#
resource "azurerm_availability_set" "this" {
  for_each                     = var.availability_sets
  name                         = each.value["name"]
  location                     = data.azurerm_resource_group.this.location
  resource_group_name          = data.azurerm_resource_group.this.name
  platform_update_domain_count = coalesce(lookup(each.value, "platform_update_domain_count"), 5)
  platform_fault_domain_count  = coalesce(lookup(each.value, "platform_fault_domain_count"), 3)
}

# -
# - Linux Virtual Machine
# -
resource "azurerm_linux_virtual_machine" "linux_vms" {
  for_each                        = var.linux_vms
  name                            = each.value["name"]
  location                        = data.azurerm_resource_group.this.location
  resource_group_name             = data.azurerm_resource_group.this.name
  size                            = coalesce(lookup(each.value, "vm_size"), "Standard_DS1_v2")
  zone                            = lookup(each.value, "avaialability_set_key", null) == null ? lookup(each.value, "zone", null) : null
  availability_set_id             = lookup(each.value, "avaialability_set_key", null) == null ? null : lookup(azurerm_availability_set.this, each.value["avaialability_set_key"])["id"]
  disable_password_authentication = coalesce(lookup(each.value, "disable_password_authentication"), true)
  admin_username                  = var.administrator_user_name
  admin_password                  = coalesce(lookup(each.value, "disable_password_authentication"), true) == false ? var.administrator_login_password : null
  allow_extension_operations	  = false

  dynamic "admin_ssh_key" {
    for_each = coalesce(lookup(each.value, "disable_password_authentication"), true) == true ? [var.administrator_user_name] : []
    content {
      username   = var.administrator_user_name
      public_key = lookup(tls_private_key.this, each.key)["public_key_openssh"]
    }
  }

  os_disk {
    name                      = "${each.value["name"]}-osdisk"
    caching                   = coalesce(lookup(each.value, "storage_os_disk_caching"), "ReadWrite")
    storage_account_type      = coalesce(lookup(each.value, "managed_disk_type"), "Standard_LRS")
    disk_size_gb              = lookup(each.value, "disk_size_gb", null)
    write_accelerator_enabled = lookup(each.value, "write_accelerator_enabled", null)
    disk_encryption_set_id    = coalesce(lookup(each.value, "enable_cmk_disk_encryption"), false) == true ? lookup(azurerm_disk_encryption_set.this, each.key)["id"] : null
  }

  dynamic "source_image_reference" {
    for_each = lookup(var.linux_image_ids, each.value["name"], null) == null ? (lookup(each.value, "source_image_reference_publisher", null) == null ? [] : [lookup(each.value, "source_image_reference_publisher", null)]) : []
    content {
      publisher = lookup(each.value, "source_image_reference_publisher", null)
      offer     = lookup(each.value, "source_image_reference_offer", null)
      sku       = lookup(each.value, "source_image_reference_sku", null)
      version   = lookup(each.value, "source_image_reference_version", null)
    }
  }

  computer_name   = each.value["name"]
  custom_data     = lookup(each.value, "custom_data_path", null) == null ? null : (base64encode(templatefile("${path.root}.${each.value["custom_data_path"]}", each.value["custom_data_args"] != null ? each.value["custom_data_args"] : {})))
  source_image_id = lookup(var.linux_image_ids, each.value["name"], null)

  boot_diagnostics {
    storage_account_uri = var.sa_bootdiag_storage_uri
  }

  dynamic "identity" {
    for_each = coalesce(lookup(each.value, "assign_identity"), false) == false ? [] : list(coalesce(lookup(each.value, "assign_identity"), false))
    content {
      type = "SystemAssigned"
    }
  }

  lifecycle {
    ignore_changes = [
      admin_ssh_key,
      network_interface_ids,
      os_disk[0].disk_encryption_set_id
    ]
  }

  network_interface_ids = [
    for nic_k, nic_v in azurerm_network_interface.linux_nics :
    nic_v.id if contains(each.value["vm_nic_keys"], nic_k)
  ]

  tags = local.tags

  depends_on = [azurerm_disk_encryption_set.this, azurerm_key_vault_access_policy.cmk]
}

# -
# - Linux Network Interfaces
# -
resource "azurerm_network_interface" "linux_nics" {
  for_each                      = var.linux_vm_nics
  name                          = each.value["name"]
  location                      = data.azurerm_resource_group.this.location
  resource_group_name           = data.azurerm_resource_group.this.name
  internal_dns_name_label       = lookup(each.value, "internal_dns_name_label", null)
  enable_ip_forwarding          = false
  enable_accelerated_networking = lookup(each.value, "enable_accelerated_networking", null)
  dns_servers                   = lookup(each.value, "dns_servers", null)

  dynamic "ip_configuration" {
    for_each = coalesce(each.value.nic_ip_configurations, [])
    content {
      name                          = coalesce(ip_configuration.value.name, "${each.value["name"]}-vm-nic")
      subnet_id                     = lookup(each.value, "subnet_name", null) == null ? null : lookup(var.subnet_ids, lookup(each.value, "subnet_name"))
      private_ip_address_allocation = lookup(ip_configuration.value, "static_ip", null) == null ? "Dynamic" : "Static"
      private_ip_address            = lookup(ip_configuration.value, "static_ip", null)
      primary                       = index(each.value.nic_ip_configurations, ip_configuration.value) == 0 ? true : false
    }
  }

  tags = local.tags
}

# -
# - Linux Network Interfaces - Internal Backend Pools Association
# -
locals {
  vm_nics_map = {
    for nic_k, nic_v in azurerm_network_interface.linux_nics : nic_k => {
      id                = nic_v.id
      name              = nic_v.name
      primary_ip_config = nic_v.ip_configuration[0].name
    }
  }
  linux_nics_with_internal_bp_list = flatten([
    for vm_k, vm_v in var.linux_vms : [
      for backend_pool_name in coalesce(vm_v["lb_backend_pool_names"], []) :
      {
        key                     = "${vm_k}_${backend_pool_name}"
        nic_key                 = vm_v.vm_nic_keys[0]
        backend_address_pool_id = lookup(var.lb_backend_address_pool_map, backend_pool_name, null)
      }
    ]
  ])
  linux_nics_with_internal_bp = {
    for bp in local.linux_nics_with_internal_bp_list : bp.key => bp
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "linux_nics_with_internal_backend_pools" {
  for_each                = local.linux_nics_with_internal_bp
  network_interface_id    = lookup(local.vm_nics_map, each.value["nic_key"], null)["id"]
  ip_configuration_name   = lookup(local.vm_nics_map, each.value["nic_key"], null)["primary_ip_config"]
  backend_address_pool_id = each.value["backend_address_pool_id"]

  lifecycle {
    ignore_changes = [network_interface_id]
  }

  depends_on = [azurerm_network_interface.linux_nics]
}

#
# Linux Network Interfaces - NAT Rules Association
#
locals {
  linux_nics_with_natrule_list = flatten([
    for vm_k, vm_v in var.linux_vms : [
      for nat_rule_name in coalesce(vm_v["lb_nat_rule_names"], []) :
      {
        key         = "${vm_k}_${nat_rule_name}"
        nat_rule_id = lookup(var.lb_nat_rule_map, nat_rule_name, null)
        nic_key     = vm_v.vm_nic_keys[0]
      }
    ]
  ])
  linux_nics_with_nat_rule = {
    for bp in local.linux_nics_with_natrule_list : bp.key => bp
  }
}

resource "azurerm_network_interface_nat_rule_association" "this" {
  for_each              = local.linux_nics_with_nat_rule
  network_interface_id  = lookup(local.vm_nics_map, each.value["nic_key"], null)["id"]
  ip_configuration_name = lookup(local.vm_nics_map, each.value["nic_key"], null)["primary_ip_config"]
  nat_rule_id           = each.value["nat_rule_id"]

  lifecycle {
    ignore_changes = [network_interface_id]
  }

  depends_on = [azurerm_network_interface.linux_nics]
}

# -
# - Linux Network Interfaces - Application Security Groups Association
# -
locals {
  linux_nics_with_asg_list = flatten([
    for vm_k, vm_v in var.linux_vms : [
      for asg_name in coalesce(vm_v["app_security_group_names"], []) :
      {
        key                           = "${vm_k}_${asg_name}"
        nic_key                       = vm_v.vm_nic_keys[0]
        application_security_group_id = lookup(var.app_security_group_ids_map, asg_name, null)
      }
    ]
  ])
  linux_nics_with_asg = {
    for asg in local.linux_nics_with_asg_list : asg.key => asg
  }
}

resource "azurerm_network_interface_application_security_group_association" "this" {
  for_each                      = local.linux_nics_with_asg
  network_interface_id          = lookup(local.vm_nics_map, each.value["nic_key"], null)["id"]
  application_security_group_id = each.value["application_security_group_id"]

  lifecycle {
    ignore_changes = [network_interface_id]
  }

  depends_on = [azurerm_network_interface.linux_nics]
}

# -
# - Linux Network Interfaces - Application Gateway's Backend Address Pools Association
# -
locals {
  linux_nics_with_app_gateway_list = flatten([
    for vm_k, vm_v in var.linux_vms : [
      for backend_pool in lookup(var.application_gateway_backend_pools, vm_v.app_gateway_name, []) :
      {
        key                     = "${vm_k}_${backend_pool}"
        nic_key                 = vm_v.vm_nic_keys[0]
        backend_address_pool_id = lookup(var.application_gateway_backend_pool_ids_map, backend_pool, null)
      }
    ] if vm_v.app_gateway_name != null
  ])
  linux_nics_with_app_gateway = {
    for appgw in local.linux_nics_with_app_gateway_list : appgw.key => appgw
  }
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "this" {
  for_each                = local.linux_nics_with_app_gateway
  network_interface_id    = lookup(local.vm_nics_map, each.value["nic_key"], null)["id"]
  ip_configuration_name   = lookup(local.vm_nics_map, each.value["nic_key"], null)["primary_ip_config"]
  backend_address_pool_id = each.value["backend_address_pool_id"]

  lifecycle {
    ignore_changes = [network_interface_id]
  }

  depends_on = [azurerm_network_interface.linux_nics]
}

# -
# - Create Key Vault Accesss Policy for VM MSI
# -
locals {
  msi_enabled_linux_vms = [
    for vm_k, vm_v in var.linux_vms :
    vm_v if coalesce(lookup(vm_v, "assign_identity"), false) == true
  ]

  vm_principal_ids = flatten([
    for x in azurerm_linux_virtual_machine.linux_vms :
    [
      for y in x.identity :
      y.principal_id if y.principal_id != ""
    ] if length(keys(azurerm_linux_virtual_machine.linux_vms)) > 0
  ])
}

resource "azurerm_key_vault_access_policy" "this" {
  count        = length(local.msi_enabled_linux_vms) > 0 ? length(local.vm_principal_ids) : 0
  key_vault_id = var.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = element(local.vm_principal_ids, count.index)

  key_permissions         = local.key_permissions
  secret_permissions      = local.secret_permissions
  certificate_permissions = local.certificate_permissions
  storage_permissions     = local.storage_permissions

  depends_on = [azurerm_linux_virtual_machine.linux_vms]
    content_type = "password"
  expiration_date = "2022-12-03"
}

# -
# - Azure Backup for an Linux Virtual Machine
# -
locals {
  linux_vms_for_backup = {
    for vm_k, vm_v in var.linux_vms :
    vm_k => vm_v if vm_v.recovery_services_vault_key != null
  }
}
resource "azurerm_backup_protected_vm" "this" {
  for_each            = var.recovery_services_vaults != null ? local.linux_vms_for_backup : {}
  resource_group_name = data.azurerm_resource_group.this.name
  recovery_vault_name = lookup(var.recovery_services_vaults, each.value["recovery_services_vault_key"])["recovery_vault_name"]
  source_vm_id        = azurerm_linux_virtual_machine.linux_vms[each.key].id
  backup_policy_id    = lookup(var.recovery_services_vaults, each.value["recovery_services_vault_key"])["backup_policy_id"]

  depends_on = [
    null_resource.dependency_modules,
    azurerm_linux_virtual_machine.linux_vms,
    azurerm_virtual_machine_extension.storage,
    azurerm_virtual_machine_extension.network_watcher,
    azurerm_virtual_machine_extension.log_analytics,
    azurerm_virtual_machine_extension.vm_insights,
    azurerm_virtual_machine_extension.custom_script,
    azurerm_virtual_machine_extension.blob_custom_script
  ]
}

#########################################################
# Linux VM Managed Disk and VM & Managed Disk Attachment
#########################################################
locals {
  linux_vms = {
    for vm_k, vm_v in var.linux_vms :
    vm_k => {
      enable_cmk_disk_encryption = coalesce(vm_v.enable_cmk_disk_encryption, false)
      zone                       = vm_v.zone
    }
  }
}

# -
# - Managed Disk
# -
resource "azurerm_managed_disk" "this" {
  for_each            = var.managed_data_disks
  name                = lookup(each.value, "disk_name", null) == null ? "${azurerm_linux_virtual_machine.linux_vms[each.value["vm_key"]]["name"]}-datadisk-${each.value["lun"]}" : each.value["disk_name"]
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  disk_encryption_set_id = "koko"
  zones                  = list(lookup(lookup(local.linux_vms, each.value["vm_key"]), "zone", null))
  storage_account_type   = coalesce(lookup(each.value, "storage_account_type"), "Standard_LRS")
#  disk_encryption_set_id = lookup(lookup(local.linux_vms, each.value["vm_key"]), "enable_cmk_disk_encryption") == true ? lookup(azurerm_disk_encryption_set.this, each.value["vm_key"])["id"] : null
  disk_size_gb           = coalesce(lookup(each.value, "disk_size"), 1)
  os_type                = coalesce(lookup(each.value, "os_type"), "Linux")
  create_option          = coalesce(lookup(each.value, "create_option"), "Empty")
  source_resource_id     = coalesce(lookup(each.value, "create_option"), "Empty") == "Copy" ? each.value.source_resource_id : null

  tags = local.tags

  lifecycle {
    ignore_changes = [disk_encryption_set_id]
  }

  depends_on = [azurerm_linux_virtual_machine.linux_vms, azurerm_disk_encryption_set.this, azurerm_key_vault_access_policy.cmk]
}

# -
# - Linux VM - Managed Disk Attachment
# -
resource "azurerm_virtual_machine_data_disk_attachment" "this" {
  for_each                  = var.managed_data_disks
  managed_disk_id           = lookup(lookup(azurerm_managed_disk.this, each.key), "id", null)
  virtual_machine_id        = azurerm_linux_virtual_machine.linux_vms[each.value["vm_key"]]["id"]
  lun                       = coalesce(lookup(each.value, "lun"), "10")
  caching                   = coalesce(lookup(each.value, "caching"), "ReadWrite")
  write_accelerator_enabled = lookup(each.value, "write_accelerator_enabled", null)
  depends_on                = [azurerm_managed_disk.this, azurerm_linux_virtual_machine.linux_vms]
}

#####################################################
# Linux VM Extension
#####################################################
locals {
  vm_ids = [for x in azurerm_linux_virtual_machine.linux_vms : x.id]

  linux_vm_diag_storage = {
    for vm_k, vm_v in var.linux_vms :
    azurerm_linux_virtual_machine.linux_vms[vm_k].id => vm_v.diagnostics_storage_config_path
  }

  diagnostics_storage_config_parms = {
    storage_account  = data.azurerm_storage_account.diagnostics_storage_account.name
    log_level_config = "LOG_DEBUG"
  }

  linux_vm_custom_script_storage_accounts = {
    for script_k, script_v in local.linux_vm_custom_scripts :
    script_k => script_v.custom_script.storageAccountName if(script_v.custom_script.storageAccountName != null && script_v.custom_script.fileUris != null && script_v.custom_script.commandToExecute != null)
  }

  linux_vm_custom_scripts = {
    for vm_k, vm_v in var.linux_vms :
    vm_k => {
      id            = azurerm_linux_virtual_machine.linux_vms[vm_k].id
      custom_script = vm_v.custom_script
    } if vm_v.custom_script != null
  }

  linux_vm_file_custom_scripts = {
    for script_k, script_v in local.linux_vm_custom_scripts :
    script_k => script_v if(script_v.custom_script.storageAccountName == null && script_v.custom_script.fileUris == null && (script_v.custom_script.commandToExecute != null || script_v.custom_script.scriptPath != null))
  }

  linux_vm_blob_custom_scripts = {
    for script_k, script_v in local.linux_vm_custom_scripts :
    script_k => script_v if(script_v.custom_script.storageAccountName != null && script_v.custom_script.fileUris != null && script_v.custom_script.commandToExecute != null)
  }
}

# -
# - Custom Script with Linux virtual machines
# -
resource "azurerm_virtual_machine_extension" "custom_script" {
  for_each                   = local.linux_vm_file_custom_scripts
  name                       = "custom-script"
  virtual_machine_id         = each.value.id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "commandToExecute": "${each.value.custom_script.scriptPath == null ? coalesce(each.value.custom_script.commandToExecute, "") : ""}",
      "script": "${(each.value.custom_script.commandToExecute == null && each.value.custom_script.scriptPath != null) ? (base64encode(templatefile("${path.root}.${each.value.custom_script.scriptPath}", "${coalesce(each.value.custom_script.scriptArgs, {})}"))) : ""}"
    }
  SETTINGS

  tags = local.tags

  depends_on = [azurerm_linux_virtual_machine.linux_vms, azurerm_virtual_machine_data_disk_attachment.this]
}

# -
# - Custom Script from Blob with Linux virtual machines
# -
resource "azurerm_virtual_machine_extension" "blob_custom_script" {
  for_each                   = local.linux_vm_blob_custom_scripts
  name                       = "blob-custom-script"
  virtual_machine_id         = each.value.id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "commandToExecute": "${each.value.custom_script.commandToExecute}",
      "fileUris": ["${join(",", each.value.custom_script.fileUris)}"]
    }
  SETTINGS

  protected_settings = <<SETTINGS
    {      
      "storageAccountName": "${lookup(data.azurerm_storage_account.custom_script_storage_account, each.key)["name"]}",
      "storageAccountKey": "${lookup(data.azurerm_storage_account.custom_script_storage_account, each.key)["primary_access_key"]}"  
    }
  SETTINGS

  tags = local.tags

  depends_on = [azurerm_linux_virtual_machine.linux_vms, azurerm_virtual_machine_data_disk_attachment.this]
}

# -
# - Enable Storage Diagnostics and Logs on Azure Linux VM
# -
resource "azurerm_virtual_machine_extension" "storage" {
  count                      = length(local.vm_ids)
  name                       = "storage-diagnostics"
  virtual_machine_id         = element(local.vm_ids, count.index)
  publisher                  = "Microsoft.Azure.Diagnostics"
  type                       = "LinuxDiagnostic"
  type_handler_version       = "3.0"
  auto_upgrade_minor_version = true

  settings = lookup(local.linux_vm_diag_storage, element(local.vm_ids, count.index), null) == null ? templatefile("${path.module}/diagnostics/config.json", merge({ vm_id = element(local.vm_ids, count.index) }, local.diagnostics_storage_config_parms)) : templatefile("${path.root}.${lookup(local.linux_vm_diag_storage, element(local.vm_ids, count.index))}", merge({ vm_id = element(local.vm_ids, count.index) }, local.diagnostics_storage_config_parms))

  protected_settings = <<SETTINGS
    {
      "storageAccountName": "${data.azurerm_storage_account.diagnostics_storage_account.name}",
      "storageAccountSasToken": "${data.azurerm_storage_account_sas.diagnostics_storage_account_sas.sas}",
      "storageAccountEndPoint": "https://core.windows.net/",
      "sinksConfig": {
        "sink": [
          {
              "name": "SyslogJsonBlob",
              "type": "JsonBlob"
          },
          {
              "name": "LinuxCpuJsonBlob",
              "type": "JsonBlob"
          }
        ]
      }
    }
  SETTINGS

  tags = local.tags

  depends_on = [azurerm_linux_virtual_machine.linux_vms]
}

# -
# - Enabling Network Watcher extension on Azure Linux VM 
# -
resource "azurerm_virtual_machine_extension" "network_watcher" {
  count                      = length(local.vm_ids)
  name                       = "network-watcher"
  virtual_machine_id         = element(local.vm_ids, count.index)
  publisher                  = "Microsoft.Azure.NetworkWatcher"
  type                       = "NetworkWatcherAgentLinux"
  type_handler_version       = "1.4"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_linux_virtual_machine.linux_vms]
}

# -
# - Enable Log Analytics Diagnostics and Logs on Azure Linux VM
# -
resource "azurerm_virtual_machine_extension" "log_analytics" {
  count                = length(local.vm_ids)
  name                 = "log-analytics"
  virtual_machine_id   = element(local.vm_ids, count.index)
  publisher            = "Microsoft.EnterpriseCloud.Monitoring"
  type                 = "OmsAgentForLinux"
  type_handler_version = "1.13"

  settings = <<SETTINGS
    {
      "workspaceId": "${var.law_workspace_id}"       
    }
  SETTINGS

  protected_settings = <<SETTINGS
    {
      "workspaceKey": "${var.law_workspace_key}"
    }
  SETTINGS

  tags = local.tags

  depends_on = [azurerm_linux_virtual_machine.linux_vms]
}

# -
# - Enabling Azure Monitor Dependency virtual machine extension for Azure Linux VM 
# -
resource "azurerm_virtual_machine_extension" "vm_insights" {
  count                      = length(local.vm_ids)
  name                       = "vm-insights"
  virtual_machine_id         = element(local.vm_ids, count.index)
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentLinux"
  type_handler_version       = "9.5"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_linux_virtual_machine.linux_vms, azurerm_virtual_machine_extension.log_analytics]
}

#####################################################
# Linux VM CMK and Disk Encryption Set
#####################################################
locals {
  cmk_enabled_virtual_machines = {
    for vm_k, vm_v in var.linux_vms :
    vm_k => vm_v if coalesce(lookup(vm_v, "enable_cmk_disk_encryption"), false) == true
  }
}

# -
# - Generate CMK Key for Linux VM
#
# -
resource "null_resource" "dependency_modules" {
  provisioner "local-exec" {
    command = "echo ${length(var.dependencies)}"
  }
}
resource "azurerm_key_vault_key" "this" {
  for_each     = local.cmk_enabled_virtual_machines
  name         = each.value.name
  key_vault_id = var.key_vault_id
  key_type     = "RSA-HSM"
  key_size     = 2048

  key_opts = [
    "decrypt", "encrypt", "sign",
    "unwrapKey", "verify", "wrapKey"
  ]

  depends_on = [null_resource.dependency_modules]
    content_type = "password"
  expiration_date = "2022-12-03"
}

# -
# - Enable Disk Encryption Set for Linux VM using CMK
# -
resource "azurerm_disk_encryption_set" "this" {
  for_each            = local.cmk_enabled_virtual_machines
  name                = each.value.name
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  key_vault_key_id    = lookup(azurerm_key_vault_key.this, each.key)["id"]

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [key_vault_key_id]
  }

  tags = local.tags
}

# -
# - Adding Access Policies for Disk Encryption Set MSI
# -
resource "azurerm_key_vault_access_policy" "cmk" {
  for_each     = local.cmk_enabled_virtual_machines
  key_vault_id = var.key_vault_id

  tenant_id = lookup(azurerm_disk_encryption_set.this, each.key).identity.0.tenant_id
  object_id = lookup(azurerm_disk_encryption_set.this, each.key).identity.0.principal_id

  key_permissions    = local.key_permissions
  secret_permissions = local.secret_permissions
}

###########################################   Windows ######################################################

# -
# - Windows Virtual Machine
# -
resource "azurerm_windows_virtual_machine" "windows_vms" {
  for_each            = var.windows_vms
  name                = each.value["name"]
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name

  network_interface_ids = [lookup(azurerm_network_interface.windows_nics, each.key)["id"]]
  size                  = coalesce(lookup(each.value, "vm_size"), "Standard_F2")
  zone                  = lookup(each.value, "zone", null)

  admin_username = var.administrator_user_name
  admin_password = var.administrator_login_password
  allow_extension_operations = false

  os_disk {
    name                      = "${each.value["name"]}${each.value["id"]}-osdisk"
    caching                   = coalesce(lookup(each.value, "storage_os_disk_caching"), "ReadWrite")
    storage_account_type      = coalesce(lookup(each.value, "managed_disk_type"), "Standard_LRS")
    disk_size_gb              = lookup(each.value, "disk_size_gb", null)
    write_accelerator_enabled = lookup(each.value, "write_accelerator_enabled", null)
    disk_encryption_set_id    = lookup(each.value, "disk_encryption_set_id", null)
  }

  dynamic "source_image_reference" {
    for_each = var.windows_image_id == null ? (lookup(each.value, "source_image_reference_publisher", null) == null ? [] : [lookup(each.value, "source_image_reference_publisher", null)]) : []
    content {
      publisher = lookup(each.value, "source_image_reference_publisher", null)
      offer     = lookup(each.value, "source_image_reference_offer", null)
      sku       = lookup(each.value, "source_image_reference_sku", null)
      version   = lookup(each.value, "source_image_reference_version", null)
    }
  }

  computer_name   = each.value["name"]
  custom_data     = lookup(each.value, "custom_data_path", null) == null ? null : (base64encode(templatefile("${path.root}.${each.value["custom_data_path"]}", each.value["custom_data_args"] != null ? each.value["custom_data_args"] : {})))
  source_image_id = var.windows_image_id

  boot_diagnostics {
    storage_account_uri = var.sa_bootdiag_storage_uri
  }

  dynamic "identity" {
    for_each = coalesce(lookup(each.value, "assign_identity"), false) == false ? [] : list(coalesce(lookup(each.value, "assign_identity"), false))
    content {
      type = "SystemAssigned"
    }
  }

  tags = local.tags
}

# -
# - Windows Network Interfaces
# -
resource "azurerm_network_interface" "windows_nics" {
  for_each                      = var.windows_vms
  name                          = "${each.value["name"]}-vm-nic"
  location                      = data.azurerm_resource_group.this.location
  resource_group_name           = data.azurerm_resource_group.this.name
  internal_dns_name_label       = lookup(each.value, "internal_dns_name_label", null)
  enable_ip_forwarding          = false
  enable_accelerated_networking = lookup(each.value, "enable_accelerated_networking", null)
  dns_servers                   = lookup(each.value, "dns_servers", null)

  ip_configuration {
    name                          = "${each.value["name"]}-vm-nic"
    subnet_id                     = lookup(each.value, "subnet_name", null) == null ? null : lookup(var.subnet_ids, lookup(each.value, "subnet_name"))
    private_ip_address_allocation = lookup(each.value, "static_ip", null) == null ? "dynamic" : "static"
    private_ip_address            = lookup(each.value, "static_ip", null)
  }

  tags = local.tags
}

# -
# - Windows Network Interfaces - Internal Backend Pools Association
# -

locals {
  windows_nics_with_internal_bp_keys = [
    for x in var.windows_vms : x.name if lookup(x, "lb_backend_pool_name", null) != null
  ]

  windows_nics_with_internal_bp_values = [
    for x in var.windows_vms : {
      lb_backend_pool_name = x.lb_backend_pool_name
    } if lookup(x, "lb_backend_pool_name", null) != null
  ]

  windows_nics_with_internal_bp = zipmap(local.windows_nics_with_internal_bp_keys, local.windows_nics_with_internal_bp_values)
}

resource "azurerm_network_interface_backend_address_pool_association" "windows_nics_with_internal_backend_pools" {
  for_each                = local.windows_nics_with_internal_bp
  network_interface_id    = [for x in azurerm_network_interface.windows_nics : x.id if x.name == "${each.key}-vm-nic"][0]
  ip_configuration_name   = "${each.key}-vm-nic"
  backend_address_pool_id = lookup(var.lb_backend_address_pool_map, each.value["lb_backend_pool_name"], null)
  depends_on = [
    azurerm_network_interface.windows_nics, azurerm_windows_virtual_machine.windows_vms
  ]
}

kv_additional_tags = {

app = "[__app__]"
mots_id = "[__mots_id__]"
location = "[__location__]"
env = "[__env__]"
created_by = "[__created_by__]"
automated_by = "[__automated_by__]"
contact_dl = "[__contact_dl__]"
iac = "[__iac__]"
pe_enable = true

}


