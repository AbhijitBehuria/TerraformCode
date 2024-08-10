data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  tags = merge(var.law_additional_tags, data.azurerm_resource_group.this.tags)
}

# -
# - Create Log Analytics Workspace
# -
resource "azurerm_log_analytics_workspace" "this" {
  name                = var.name
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location

  sku               = var.sku
  retention_in_days = var.retention_in_days

  tags = local.tags
}

# -
# - Install the VMInsights solution
# -
resource "azurerm_log_analytics_solution" "this" {
  solution_name         = "VMInsights"
  location              = data.azurerm_resource_group.this.location
  resource_group_name   = data.azurerm_resource_group.this.name
  workspace_resource_id = azurerm_log_analytics_workspace.this.id
  workspace_name        = azurerm_log_analytics_workspace.this.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/VMInsights"
  }
}

# -
# - Store LAW Workspace Id and Primary Key to Key Vault Secrets
# -
locals {
  log_analytics_workspace = {
    law-primary-shared-key = azurerm_log_analytics_workspace.this.primary_shared_key
    law-workspace-id       = azurerm_log_analytics_workspace.this.workspace_id
    law-resource-id        = azurerm_log_analytics_workspace.this.id
  }
}
resource "null_resource" "dependency_modules" {
  provisioner "local-exec" {
    command = "echo ${length(var.dependencies)}"
  }
}
resource "azurerm_key_vault_secret" "this" {
  for_each     = local.log_analytics_workspace
  name         = each.key
  value        = each.value
  key_vault_id = var.key_vault_id
  depends_on = [
    azurerm_log_analytics_workspace.this,
    null_resource.dependency_modules
  content_type = "password"
  expiration_date = "2022-12-03"
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

