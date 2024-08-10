# - Resource Group Input variables
name     = "resource_group_name" # "<resource_group_name>"
location = "eastus"              # "<azure_region>"

additional_tags = {
  iac = "Terraform"
  env = "UAT"
}

# - Virtual network Input variables

# - Infrastructure Virtual Network
virtual_networks = {
  virtualnetwork1 = {
    name                 = "vnet1"
    address_space        = ["10.0.0.0/16"]
    dns_servers          = null
    ddos_protection_plan = null
  },
  virtualnetwork2 = {
    name                 = "vnet2"
    address_space        = ["172.16.0.0/16"]
    dns_servers          = null
    ddos_protection_plan = null
  }
}

# - Subnets Input variables
subnets = {
  subnet1 = {
    vnet_key          = "virtualnetwork1"
    nsg_key           = "nsg1"
    rt_key            = null
    name              = "loadbalancer"
    address_prefixes  = ["10.0.138.0/28"]
    service_endpoints = ["Microsoft.Sql", "Microsoft.AzureCosmosDB"]
    pe_enable         = false
    delegation        = []
  },
  subnet2 = {
    vnet_key          = "virtualnetwork1"
    nsg_key           = null
    rt_key            = null
    name              = "proxy"
    address_prefixes  = ["10.0.138.16/28"]
    pe_enable         = true
    service_endpoints = null
    delegation        = []
  },
  subnet3 = {
    vnet_key          = "virtualnetwork1"
    nsg_key           = null
    rt_key            = null
    name              = "application"
    address_prefixes  = ["10.0.138.32/28"]
    pe_enable         = true
    service_endpoints = null
    delegation        = []
  }
}
# - vnet peering Input variables
vnet_peering = {}

# - Infrastructure Route Tables
route_tables = {}

# - Infrastructure Network Security Groups
network_security_groups = {
  nsg1 = {
    name = "nsg1"
    tags = { Resource_Type = "NSG" }
    security_rules = [
      {
        name                                         = "sample-nsg"
        description                                  = "Sample NSG"
        priority                                     = 101
        direction                                    = "Outbound"
        access                                       = "Allow"
        protocol                                     = "Tcp"
        source_port_range                            = "*"
        source_port_ranges                           = null #["443","8080","65200-65535"]
        destination_port_range                       = "*"
        destination_port_ranges                      = null # ["8080-8081"]
        source_address_prefix                        = null
        source_address_prefixes                      = null # [ "10.1.0.128/27","10.1.0.32/27" ]        
        destination_address_prefix                   = null
        destination_address_prefixes                 = null # ["AzureMonitor","AzureActiveDirectory","Internet"]
        source_application_security_group_names      = ["asg-first"]
        destination_application_security_group_names = ["asg-second"]
      }
    ]
  }
}

# - Log Analytics
laname              = "CloudLAW"
sku                 = "PerGB2018"
retention_in_days   = "30"

# - Storage Account

storage_accounts = {
  sa1 = {
    name                       = "cloudstorageaccount"
    sku                        = "Standard_RAGRS"
    account_kind               = null
    access_tier                = null
    assign_identity            = true
    cmk_enable                 = true
    network_rules              = null
    sa_pe_is_manual_connection = false
    sa_pe_subnet_name          = null
    sa_pe_vnet_name            = null
    sa_pe_enabled_services     = ["table", "queue", "blob"]
    enable_large_file_share    = false
  }
}
containers  = {}
blobs       = {}
queues      = {}
file_shares = {}
tables      = {}


# - Infrastructure Key Vault
resource_group_name = "resource"

keyvault_name                   = "cloudkv01"
sku_name                        = "standard"
enabled_for_deployment          = true
enabled_for_disk_encryption     = true
enabled_for_template_deployment = true
soft_delete_enabled             = true
purge_protection_enabled        = true

#log_analytics_workspace_id       = "log_analytics_workspace_id"
diagnostics_storage_account_name = "diagnostics_storage_account_name"

network_acls = {  
  bypass                     = "AzureServices"
  default_action             = "Deny"
  ip_rules                   = ["0.0.0.0/0"]
  virtual_network_subnet_ids = []
  }

secrets = {}

access_policies = {}


###############################################################
#Create loadbalancer
############################################################
#resource_group_name = "resource"

zones = ["1"]

load_balancers = {
  loadbalancer1 = {
    name = "cloudlb"
    sku  = "Standard"
    frontend_ips = [
      {
        name        = "cloudlbfrontend" # <"frontend_ip_config_name">
        subnet_name = "loadbalancer"    # <"subnet_name">
        static_ip   = null              # "10.0.1.4" #(Optional) Set null to get dynamic IP 
        zones       = null
      },
      {
        name        = "cloudlbfrontend1" # <"frontend_ip_config_name">
        subnet_name = "loadbalancer"     # <"subnet_name">
        static_ip   = null               # "10.0.1.4" #(Optional) Set null to get dynamic IP
        zones       = null
      }
    ]
    backend_pool_names = ["cloudlbbackend", "cloudlbbackend1"]
    enable_public_ip   = false # set this to true to if you want to create public load balancer
    public_ip_name     = null  # custom name for public ip 
  }
}

load_balancer_rules = {
  loadbalancerrules1 = {
    name                      = "cloudlbrule"
    lb_key                    = "loadbalancer1"
    frontend_ip_name          = "cloudlbfrontend"
    backend_pool_name         = "cloudlbbackend"
    lb_protocol               = null
    lb_port                   = 22
    probe_port                = 22
    backend_port              = 22
    enable_floating_ip        = null
    disable_outbound_snat     = null
    enable_tcp_reset          = null
    probe_protocol            = "Tcp"
    request_path              = "/"
    probe_interval            = 15
    probe_unhealthy_threshold = 2
    load_distribution         = "SourceIPProtocol"
    idle_timeout_in_minutes   = 5
  },
  loadbalancerrules2 = {
    name                      = "springboot-lb-rule-ha"
    lb_key                    = "loadbalancer1"
    frontend_ip_name          = "springbootlbfrontend1"
    backend_pool_name         = "springbootlbbackend1"
    lb_protocol               = "All"
    lb_port                   = 0
    probe_port                = "22"
    backend_port              = 0
    enable_floating_ip        = null
    disable_outbound_snat     = null
    enable_tcp_reset          = null
    probe_protocol            = "Tcp"
    request_path              = "/"
    probe_interval            = 15
    probe_unhealthy_threshold = 2
    load_distribution         = "SourceIPProtocol"
    idle_timeout_in_minutes   = 5
  }
}

load_balancer_nat_rules = {
  loadbalancernatrules1 = {
    name                    = "ngnixlbnatrule"
    lb_key                  = "loadbalancer1"
    frontend_ip_name        = "cloudlbfrontend"
    lb_port                 = 80
    backend_port            = 22
    idle_timeout_in_minutes = 5
  }
}

lb_outbound_rules = {
  rule1 = {
    name                            = "test"
    lb_key                          = "loadbalancer1"
    protocol                        = "Tcp"
    backend_pool_name               = "cloudlbbackend"
    allocated_outbound_ports        = null
    frontend_ip_configuration_names = ["cloudlbfrontend"]
  }
}

load_balancer_nat_pools = {
  nat_pool1 = {
    name             = "pool1"
    lb_key           = "loadbalancer1"
    frontend_ip_name = "cloudlbfrontend"
    lb_port_start    = "1433"
    lb_port_end      = "1444"
    backend_port     = "8080"
  }
}

#Create Private DNS Zones

#resource_group_name = "resource"

private_dns_zones = {
  zone1 = {
    dns_zone_name = "privatelink.database.windows.net" # <"dns_zone_name">
    vnet_links = [{
      zone_to_vnet_link_name   = "vnet_link"          # <"dns_zone_to_virtual_network_link_name">
      vnet_name                = "vnet1"              # <"virtual_network_linked_to_dns_zone">
      zone_to_vnet_link_exists = false                               # <true | false>
    }]
    zone_exists          = false # <true | false>    
    registration_enabled = true  # <true | false>
  }
}

#Create Private DNS records
#resource_group_name = "resource_group_name" # "<resource_group_name>"

dns_a_records = {
  arecord1 = {
    a_record_name         = "azuresql-arecord"                 # <"dns+a_record_name">
    dns_zone_name         = "privatelink.database.windows.net" # <"dns_zone_name">
    ttl                   = 300                                # <time_to_live_of_the_dns_record_in_seconds>
    ip_addresses          = ["10.0.180.17"]                    # <list_of_ipv4_addresses>
    private_endpoint_name = null                               # <"name of private endpoint for which DNSARecord to be created"
  }
}

#Create Private Link Services

#resource_group_name = "resource_group_name" # "<resource_group_name>"

private_link_services = {
  pls1 = {
    name                           = "privatelinkservice" # "<private_link_service_name>"
    frontend_ip_config_name        = "nginxlbfrontend"    # "<lb_frontend_name>"
    subnet_name                    = "subnet1"              # "<subnet_name>"
    private_ip_address             = null                 # "<private_ip_address>"
    private_ip_address_version     = "IPv4"               # "<private_ip_address_version>"
    visibility_subscription_ids    = null                 # <["00000000-0000-0000-0000-000000000000"]>
    auto_approval_subscription_ids = null                 # <["00000000-0000-0000-0000-000000000000"]>
  }
}

#Private endpoints

#resource_group_name = "resource_group_name" # "<resource_group_name>"

private_endpoints = {
  pe2 = {
    resource_name     = "keyvault"                         # key from the resource_ids Map key-value pairs
    name              = "privateendpointkeyvault"          # <"private_endpoint_name">
    subnet_name       = "subnet1"                            # <"private_endpoint_subnet">    
    approval_required = false                              # <true | false>
    approval_message  = null                               # <"approval-request_message_for_manual_approval">
    group_ids         = ["vault"]                          # <["group_ids_for_private_endpoint"]>
    dns_zone_name     = "privatelink.vaultcore.azure.net"  # <"dns_zone_name_for_this_private_endpoint">
    zone_exists       = false                              # <true | false>
    vnet_links = [{
      zone_to_vnet_link_name   = "custom_name_for_zone_to_vnet_link" # <"dns_zone_to_virtual_network_link_name">
      vnet_name                = "jstartvmss"                        # <"virtual_network_linked_to_dns_zone">
      zone_to_vnet_link_exists = false                               # <true | false>
    }]
    registration_enabled = true  # <true | false>
    dns_a_records        = null  # <list_of_dns_a_record_blocks>
  }
}

#RSV

#resource_group_name = "resource_group_name" # "<resource_group_name>"

recovery_services_vaults = {
  rsv1 = {
    name                = "tfex-recovery-vault"        # <"recovery_services_vault_name">
    policy_name         = "tfex-recovery-vault-policy" # <"vm_backup_policy_name">
    sku                 = "Standard"                   # <"Standard" | "RS0">
    soft_delete_enabled = false                        # <true | false>
    backup_settings = {
      frequency = "Daily" # <"Daily" | "Weekly">
      time      = "23:00" # <"24hour format">
      weekdays  = null    # <["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]>
    }
    retention_settings = {
      daily   = 10   # <1 to 9999>
      weekly  = null # <"<1 to 9999>:<Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday>">
      monthly = null # <"<1 to 9999>:<Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday>:<First,Second,Third,Fourth,Last>">
      yearly  = null # <"<1 to 9999>:<Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday>:<First,Second,Third,Fourth,Last>:<January,February,March,April,May,June,July,Augest,September,October,November,December>">
    }
  }
}

#Virtual machine vars

#resource_group_name = "resource_group_name"

linux_vms = {
  vm1 = {
    name                             = "cloud-test-vm-01"
    vm_size                          = "Standard_DS1_v2"
    assign_identity                  = true
    avaialability_set_key            = "av1"
    vm_nic_keys                      = ["nic1", "nic2"]
    lb_backend_pool_names            = ["lbbepool"]
    lb_nat_rule_names                = ["rule1", "rule2"]
    app_security_group_names         = null #["asg-src"]
    app_gateway_name                 = null #"clouappgw"
    zone                             = "1"
    disable_password_authentication  = true
    source_image_reference_offer     = "RHEL"   # set this to null if you are  using image id from shared image gallery or if you are passing image id to the VM through packer
    source_image_reference_publisher = "RedHat" # set this to null if you are  using image id from shared image gallery or if you are passing image id to the VM through packer  
    source_image_reference_sku       = "7-LVM"  # set this to null if you are using image id from shared image gallery or if you are passing image id to the VM through packer 
    source_image_reference_version   = "Latest" # set this to null if you are using image id from shared image gallery or if you are passing image id to the VM through packer             
    storage_os_disk_caching          = "ReadWrite"
    managed_disk_type                = "Premium_LRS"
    disk_size_gb                     = null
    write_accelerator_enabled        = null
    recovery_services_vault_key      = "rsv1"
    enable_cmk_disk_encryption       = true                                   # set it to true if you want to enable disk encryption using customer managed key
    custom_data_path                 = null #"//Terraform//Scripts//CustomData.tpl" # Optional
    custom_data_args                 = null #{ name = "VMandVMSS", destination = "EASTUS2", version = "1.0" }
    diagnostics_storage_config_path  = null #"//Terraform//Diagnostics//Config.json" # Optional
    custom_script = {
      commandToExecute   = "ls"
      scriptPath         = null
      scriptArgs         = null
      fileUris           = null
      storageAccountName = null
    }
    # custom_script = {
    #   commandToExecute   = "sh script1.sh"
    #   scriptPath         = null
    #   scriptArgs         = null
    #   fileUris           = ["https://vm.blob.core.windows.net/script/script1.sh"]
    #   storageAccountName = "stoargeac01"
    # }
    # custom_script = {
    #   commandToExecute   = null
    #   scriptPath         = "//Terraform//Scripts//script1.sh"
    #   scriptArgs         = null
    #   fileUris           = null
    #   storageAccountName = null
    # }
  }
}

administrator_user_name      = "azureadmin"
administrator_login_password = null # don't define it if you set disable_password_authentication to true

# managed data disks
managed_data_disks = {
  disk1 = {
    disk_name                 = "diskvm2"
    vm_key                    = "vm1"
    lun                       = 10
    storage_account_type      = "Standard_LRS"
    disk_size                 = "1024"
    caching                   = "None"
    write_accelerator_enabled = false
    os_type                   = "Linux"
    create_option             = null
    source_resource_id        = null
  }
}

availability_sets = {
  av1 = {
    name                         = "avsetfirst"
    platform_update_domain_count = 3
    platform_fault_domain_count  = 3
  }
}

linux_vm_nics = {
  nic1 = {
    name                          = "nic1"
    subnet_name                   = "appsubnet"
    internal_dns_name_label       = "testnew2020"
    enable_ip_forwarding          = false
    enable_accelerated_networking = false
    dns_servers                   = []
    nic_ip_configurations = [
      {
        name      = "nic1"
        static_ip = null
      }
    ]
  },
  nic2 = {
    name                          = "nic2"
    subnet_name                   = "appsubnet"
    internal_dns_name_label       = "testapp2020"
    enable_ip_forwarding          = false
    enable_accelerated_networking = false
    dns_servers                   = []
    nic_ip_configurations = [
      {
        name      = "nic2"
        static_ip = null
      }
    ]
  }
}