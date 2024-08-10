data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

# -
# - Get the current user config
# -
data "azurerm_client_config" "current" {}

locals {
  tags = merge(var.sa_additional_tags, data.azurerm_resource_group.this.tags)

  default_network_rules = {
    bypass                     = ["AzureServices"]
    default_action             = "Deny"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
  disable_network_rules = {
    bypass                     = ["None"]
    default_action             = "Allow"
    ip_rules                   = null
    virtual_network_subnet_ids = null
  }

  blobs = {
    for b in var.blobs : b.name => merge({
      type         = "Block"
      size         = 0
      content_type = "application/octet-stream"
      source_file  = null
      source_uri   = null
      metadata     = {}
    }, b)
  }

  key_permissions         = ["get", "wrapkey", "unwrapkey"]
  secret_permissions      = ["get"]
  certificate_permissions = ["get"]
  storage_permissions     = ["get"]
}

# -
# - Storage Account
# -
resource "azurerm_storage_account" "this" {
  for_each                  = var.storage_accounts
  name                      = each.value["name"]
  resource_group_name       = data.azurerm_resource_group.this.name
  location                  = data.azurerm_resource_group.this.location
  account_tier              = coalesce(lookup(each.value, "account_kind"), "StorageV2") == "FileStorage" ? "Premium" : split("_", each.value["sku"])[0]
  account_replication_type  = coalesce(lookup(each.value, "account_kind"), "StorageV2") == "FileStorage" ? "LRS" : split("_", each.value["sku"])[1]
  account_kind              = coalesce(lookup(each.value, "account_kind"), "StorageV2")
  access_tier               = lookup(each.value, "access_tier", null)
  enable_https_traffic_only = true 
  bypass                    = ["AzureServices"]
  network_rules {
  default_action= "Deny" 
  }
  min_tls_version      = "TLS1_2"
  
  dynamic "identity" {
    for_each = coalesce(lookup(each.value, "assign_identity"), false) == false ? [] : list(lookup(each.value, "assign_identity", false))
    content {
      type = "SystemAssigned"
    }
  }

  dynamic "network_rules" {
    for_each = lookup(each.value, "network_rules", null) != null ? [merge(local.default_network_rules, lookup(each.value, "network_rules", null))] : [local.default_network_rules]
    content {
      bypass                     = ["AzureServices"]
      default_action             = "Deny"
      ip_rules                   = network_rules.value.ip_rules
      virtual_network_subnet_ids = network_rules.value.virtual_network_subnet_ids
    }
  }

  tags = local.tags
}

# -
# - Store Storage Account Access Key to Key Vault Secrets
# -
resource "azurerm_key_vault_secret" "this" {
  for_each     = var.storage_accounts
  name         = "${each.value["name"]}-access-key"
  value        = lookup(lookup(azurerm_storage_account.this, each.key), "primary_access_key")
  key_vault_id = var.key_vault_id
  depends_on = [
    azurerm_storage_account.this,
    null_resource.dependency_modules
  ]  
  content_type  = "password"
  expiration_date = "2022-12-03"
}

resource "null_resource" "dependency_sa" {
  depends_on = [azurerm_storage_account.this]
}

resource "null_resource" "this" {
  for_each = var.storage_accounts
  triggers = {
    storage_account_id      = azurerm_storage_account.this[each.key].id
    enable_large_file_share = each.value["enable_large_file_share"]
  }
  provisioner "local-exec" {
    command = coalesce(lookup(each.value, "enable_large_file_share"), false) == true ? "az storage account update --name ${each.value["name"]} -g ${data.azurerm_resource_group.this.name} ${coalesce(lookup(each.value, "enable_large_file_share"), false) == true ? "--enable-large-file-share" : ""}" : "echo ${coalesce(lookup(each.value, "enable_large_file_share"), false)}"
  }
}

# -
# - Container
# -
resource "azurerm_storage_container" "this" {
  for_each              = var.containers
  name                  = each.value["name"]
  storage_account_name  = each.value["storage_account_name"]
  depends_on            = [azurerm_storage_account.this, null_resource.dependency_modules]
  container_access_type = "private"
}

resource "azurerm_monitor_activity_log_alert" "this" {
  name                = "this-activitylogalert"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [azurerm_resource_group.this.id]
  description         = "This alert will monitor a specific storage account updates."

  criteria {
    resource_id    = azurerm_storage_account.this.id
    operation_name = "Microsoft.Storage/storageAccounts/write"
    category       = "Recommendation"
  }


  action {
    action_group_id = azurerm_monitor_action_group.this.id

    webhook_properties = {
      from = "terraform"
    }
  }
}

# -
# - Blob
# -
resource "azurerm_storage_blob" "this" {
  for_each               = local.blobs
  name                   = each.value["name"]
  storage_account_name   = each.value["storage_account_name"]
  storage_container_name = each.value["storage_container_name"]
  type                   = each.value["type"]
  size                   = lookup(each.value, "size", null)
  content_type           = lookup(each.value, "content_type", null)
  source_uri             = lookup(each.value, "source_uri", null)
  metadata               = lookup(each.value, "metadata", null)
  depends_on = [
    azurerm_storage_account.this,
    azurerm_storage_container.this,
    null_resource.dependency_modules
  ]
}

# -
# - Queue
# -
resource "azurerm_storage_queue" "this" {
  for_each             = var.queues
  name                 = each.value["name"]
  storage_account_name = each.value["storage_account_name"]
  depends_on           = [azurerm_storage_account.this, null_resource.dependency_modules]
}

# -
# - File Share
# -
resource "azurerm_storage_share" "this" {
  for_each             = var.file_shares
  name                 = each.value["name"]
  storage_account_name = each.value["storage_account_name"]
  quota                = coalesce(lookup(each.value, "quota"), 110)
  depends_on           = [azurerm_storage_account.this, null_resource.dependency_modules]
}

# -
# - Table
# -
resource "azurerm_storage_table" "this" {
  for_each             = var.tables
  name                 = each.value["name"]
  storage_account_name = each.value["storage_account_name"]
  depends_on           = [azurerm_storage_account.this, null_resource.dependency_modules]
}

# -
# - Create Key Vault Accesss Policy for SA MSI
# -
locals {
  msi_enabled_storage_accounts = [
    for sa_k, sa_v in var.storage_accounts :
    sa_v if coalesce(lookup(sa_v, "assign_identity"), false) == true
  ]

  sa_principal_ids = flatten([
    for x in azurerm_storage_account.this :
    [
      for y in x.identity :
      y.principal_id if y.principal_id != ""
    ] if length(keys(azurerm_storage_account.this)) > 0
  ])
}

resource "azurerm_key_vault_access_policy" "this" {
  count        = length(local.msi_enabled_storage_accounts) > 0 ? length(local.sa_principal_ids) : 0
  key_vault_id = var.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = element(local.sa_principal_ids, count.index)

  key_permissions         = local.key_permissions
  secret_permissions      = local.secret_permissions
  certificate_permissions = local.certificate_permissions
  storage_permissions     = local.storage_permissions

  depends_on = [azurerm_storage_account.this]
}

# -
# - Enabled Customer Managed Key Encryption for Storage Account
# -
locals {
  cmk_enabled_sa_ids = [
    for sa_k, sa_v in var.storage_accounts :
    azurerm_storage_account.this[sa_k].id if coalesce(lookup(sa_v, "cmk_enable"), false) == true && length(keys(azurerm_storage_account.this)) > 0
  ]
  mk_enabled_sa_names = [
    for sa_k, sa_v in var.storage_accounts :
    azurerm_storage_account.this[sa_k].name if coalesce(lookup(sa_v, "cmk_enable"), false) == true && length(keys(azurerm_storage_account.this)) > 0
  ]
  cmk_enable_storage_accounts = [
    for sa_k, sa_v in var.storage_accounts :
    sa_k if coalesce(lookup(sa_v, "cmk_enable"), false) == true
  ]
}

resource "null_resource" "dependency_modules" {
  provisioner "local-exec" {
    command = "echo ${length(var.dependencies)}"
  }
}
resource "azurerm_key_vault_key" "this" {
  count        = length(local.cmk_enable_storage_accounts)
  name         = element(local.mk_enabled_sa_names, count.index)
  key_vault_id = var.key_vault_id
  key_type     = "RSA-HSM"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
  depends_on   = [azurerm_storage_account.this, null_resource.dependency_modules]
  expiration_date = "2022-12-03"
}

resource "azurerm_storage_account_customer_managed_key" "this" {
  count              = length(local.cmk_enable_storage_accounts)
  storage_account_id = element(local.cmk_enabled_sa_ids, count.index)
  key_vault_id       = var.key_vault_id
  key_name           = element(local.mk_enabled_sa_names, count.index)
  key_version        = element(azurerm_key_vault_key.this.*.version, count.index)
  depends_on         = [azurerm_storage_account.this, azurerm_key_vault_key.this]
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

