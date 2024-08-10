
# - Data Resource
data "azurerm_subscription" "this" {}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  tags = merge(var.lb_additional_tags, data.azurerm_resource_group.this.tags)
  public_ips = {
    for k, v in var.load_balancers :
    k => v if lookup(v, "enable_public_ip", false) == true
  }
}

resource "azurerm_public_ip" "this" {
  for_each            = local.public_ips
  name                = each.value.public_ip_name
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "Standard"
  allocation_method   = "Static"
  tags                = local.tags
}

# -
# - Load Balancer
# -
resource "azurerm_lb" "this" {
  for_each            = var.load_balancers
  name                = each.value["name"]
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = coalesce(lookup(each.value, "enable_public_ip"), false) == true ? "Standard" : coalesce(each.value.sku, "Standard")

  dynamic "frontend_ip_configuration" {
    for_each = coalesce(lookup(each.value, "frontend_ips"), [])
    content {
      name                          = frontend_ip_configuration.value.name
      subnet_id                     = coalesce(lookup(each.value, "enable_public_ip"), false) == true ? null : lookup(var.subnet_ids, frontend_ip_configuration.value.subnet_name, null)
      private_ip_address_allocation = coalesce(lookup(each.value, "enable_public_ip"), false) == true ? null : (lookup(frontend_ip_configuration.value, "static_ip", null) == null ? "dynamic" : "static")
      private_ip_address            = coalesce(lookup(each.value, "enable_public_ip"), false) == true ? null : lookup(frontend_ip_configuration.value, "static_ip", null)
      public_ip_address_id          = coalesce(lookup(each.value, "enable_public_ip"), false) == true ? lookup(azurerm_public_ip.this, each.key)["id"] : null
      zones                         = coalesce(lookup(each.value, "enable_public_ip"), false) == true ? null : lookup(frontend_ip_configuration.value, "zones", null)
    }
  }

  tags = local.tags

  depends_on = [azurerm_public_ip.this]
}

# -
# - Load Balancer Backend Address Pool
# -
locals {
  backend_pools = flatten([
    for lb_k, lb_v in var.load_balancers :
    [
      for backend_pool_name in coalesce(lb_v.backend_pool_names, []) :
      {
        lb_key = lb_k
        name   = backend_pool_name
      }
    ]
  ])
}

resource "azurerm_lb_backend_address_pool" "this" {
  count               = length(local.backend_pools)
  name                = lookup(element(local.backend_pools, count.index), "name")
  resource_group_name = data.azurerm_resource_group.this.name
  loadbalancer_id     = lookup(azurerm_lb.this, lookup(element(local.backend_pools, count.index), "lb_key"))["id"]
  depends_on          = [azurerm_lb.this]
}

# -
# - Load Balancer Probe
# -
resource "azurerm_lb_probe" "this" {
  for_each            = var.load_balancer_rules
  name                = each.value["name"]
  resource_group_name = data.azurerm_resource_group.this.name
  loadbalancer_id     = lookup(azurerm_lb.this, each.value["lb_key"], null)["id"]
  port                = each.value["probe_port"]
  protocol            = lookup(each.value, "probe_protocol", null)
  request_path        = lookup(each.value, "probe_protocol", null) == "Tcp" ? null : lookup(each.value, "request_path", null)
  interval_in_seconds = lookup(each.value, "probe_interval", null)
  number_of_probes    = lookup(each.value, "probe_unhealthy_threshold", null)
  depends_on          = [azurerm_lb.this]
}

# -
# - Load Balancer Rule
# -
locals {
  backend_address_pool_map = {
    for bp in azurerm_lb_backend_address_pool.this :
    bp.name => bp.id
  }
}

resource "azurerm_lb_rule" "this" {
  for_each                       = var.load_balancer_rules
  name                           = each.value["name"]
  resource_group_name            = data.azurerm_resource_group.this.name
  loadbalancer_id                = lookup(azurerm_lb.this, each.value["lb_key"])["id"]
  protocol                       = coalesce(each.value["lb_protocol"], "Tcp")
  frontend_port                  = each.value["lb_port"]
  backend_port                   = each.value["backend_port"]
  frontend_ip_configuration_name = each.value["frontend_ip_name"]
  backend_address_pool_id        = lookup(local.backend_address_pool_map, each.value["backend_pool_name"], null)
  probe_id                       = lookup(azurerm_lb_probe.this, each.key, null) != null ? lookup(azurerm_lb_probe.this, each.key)["id"] : null
  load_distribution              = lookup(each.value, "load_distribution", null)
  idle_timeout_in_minutes        = lookup(each.value, "idle_timeout_in_minutes", null)
  enable_floating_ip             = coalesce(lookup(each.value, "enable_floating_ip"), false)
  disable_outbound_snat          = coalesce(lookup(each.value, "disable_outbound_snat"), false)
  enable_tcp_reset               = coalesce(lookup(each.value, "enable_tcp_reset"), false)
  depends_on                     = [azurerm_lb.this, azurerm_lb_backend_address_pool.this, azurerm_lb_probe.this]
}
# -
# - Load Balancer outbound Rule
# -
resource "azurerm_lb_outbound_rule" "this" {
  for_each                 = var.lb_outbound_rules
  resource_group_name      = data.azurerm_resource_group.this.name
  loadbalancer_id          = lookup(azurerm_lb.this, each.value["lb_key"])["id"]
  name                     = each.value["name"]
  protocol                 = each.value["protocol"]
  backend_address_pool_id  = lookup(local.backend_address_pool_map, each.value["backend_pool_name"], null)
  allocated_outbound_ports = lookup(each.value, "allocated_outbound_ports", null)

  dynamic "frontend_ip_configuration" {
    for_each = lookup(each.value, "frontend_ip_configuration_names", [])
    content {
      name = frontend_ip_configuration.value
    }
  }
  depends_on = [azurerm_lb.this, azurerm_lb_backend_address_pool.this]
}

# -
# - Load Balancer NAT Rule
# -
resource "azurerm_lb_nat_rule" "this" {
  for_each                       = var.load_balancer_nat_rules
  name                           = each.value["name"]
  resource_group_name            = data.azurerm_resource_group.this.name
  loadbalancer_id                = lookup(azurerm_lb.this, each.value["lb_key"])["id"]
  protocol                       = "Tcp"
  frontend_port                  = each.value["lb_port"]
  backend_port                   = each.value["backend_port"]
  frontend_ip_configuration_name = each.value["frontend_ip_name"]
  idle_timeout_in_minutes        = lookup(each.value, "idle_timeout_in_minutes", null)
  depends_on                     = [azurerm_lb.this]
}

# -
# - Load Balancer NAT Pool
# -
resource "azurerm_lb_nat_pool" "this" {
  for_each                       = var.load_balancer_nat_pools
  name                           = each.value["name"]
  resource_group_name            = data.azurerm_resource_group.this.name
  loadbalancer_id                = lookup(azurerm_lb.this, each.value["lb_key"])["id"]
  protocol                       = "Tcp"
  frontend_port_start            = each.value["lb_port_start"]
  frontend_port_end              = each.value["lb_port_end"]
  backend_port                   = each.value["backend_port"]
  frontend_ip_configuration_name = each.value["frontend_ip_name"]
  depends_on                     = [azurerm_lb.this]
}