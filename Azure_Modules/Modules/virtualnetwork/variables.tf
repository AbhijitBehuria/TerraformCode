# - General variables for vnet & subnet creation
variable "resource_group_name" {
  type        = string
  description = "The Azure resource group where your resources will be created"
}
variable "location" {
  type        = string
  description = "Network resources location if different that the resource group's location."
  default     = ""
}
variable "net_additional_tags" {
  type        = map(string)
  description = "Additional Network resources tags, in addition to the resource group tags."
  default     = {}
}
variable "net_location" {
  type        = string
  description = ""
  default     = ""
}
variable "rgname" {
  type        = string
  description = "Network resources location if different that the resource group's location."
  default     = ""
}

# -
# - Virtual Network object
# -
variable "virtual_networks" {
  description = "The virtal networks with their properties."
  type = map(object({
    name          = string
    address_space = list(string)
    dns_servers   = list(string)
  }))
  default = {}
}

variable "network_ddos_protection_plan" {
  type        = any
  description = "Network network ddos protection plan parameters."
  default     = []
}

# -
# - vnet peering
# -
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
  default = {}
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
  default = {}
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
  default = {}
}

variable "dependencies" {
  type        = list(any)
  description = "Specifies the modules that the Infrastructure Resources depends on."
  default     = []
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
  default = {}
}

variable "app_security_group_ids_map" {
  type        = map(string)
  description = "Specifies the Map of Application Security Group Id's"
  default     = {}
}