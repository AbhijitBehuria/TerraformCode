# VNets
output "vnet_ids" {
  value = [for x in azurerm_virtual_network.this : x.id]
}

output "map_vnet_ids" {
  value = { for x in azurerm_virtual_network.this : x.name => x.id }
}

output "vnet_names" {
  value = [for x in azurerm_virtual_network.this : x.name]
}

output "vnet_locations" {
  value = [for x in azurerm_virtual_network.this : x.location]
}

output "vnet_rgnames" {
  value = [for x in azurerm_virtual_network.this : x.resource_group_name]
}

output "private_endpoint_vnets" {
  description = ""
  value       = distinct([for s in azurerm_subnet.this : split("/subnet", s.id)[0] if(s.enforce_private_link_endpoint_network_policies != false && s.enforce_private_link_service_network_policies != false)])
}

output "map_vnets" {
  description = ""
  value       = { for k, x in azurerm_virtual_network.this : k => { "id" = x.id, "name" = x.name, "location" = x.location, resource_group_name = x.resource_group_name } }
}

# Subnets
output "subnet_ids" {
  value = [for x in azurerm_subnet.this : x.id]
}

output "map_subnet_ids" {
  value = { for x in azurerm_subnet.this : x.name => x.id }
}

output "subnets_with_serviceendpoints" {
  value = [
    for s in azurerm_subnet.this :
    s.id if length(coalesce(s.service_endpoints, [])) > 0
  ]
}

output "private_endpoint_subnets" {
  description = ""
  value       = distinct([for s in azurerm_subnet.this : s.id if(s.enforce_private_link_endpoint_network_policies != false && s.enforce_private_link_service_network_policies != false)])
}

output "map_subnets" {
  description = ""
  value       = { for k, b in azurerm_subnet.this : k => { "address_prefix" = b.address_prefix, "id" = b.id, "name" = b.name } }
}

# NSGs
output "network_security_group_ids" {
  value = [for x in azurerm_network_security_group.this : x.id]
}

output "map_nsg_ids" {
  value = { for x in azurerm_network_security_group.this : x.name => x.id }
}

# VNet Peering
output "vnet_peering_source_to_dest" {
  value = [for x in azurerm_virtual_network_peering.source_to_destination : x.id]
}

output "vnet_peering_dest_to_source" {
  value = [for x in azurerm_virtual_network_peering.destination_to_source : x.id]
}