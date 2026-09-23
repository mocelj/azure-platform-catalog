locals {
  tags = merge(var.tags, {
    environment    = "demo"
    platform       = "avm-platform-catalog"
    workload       = "vm"
    engine         = "terraform"
    catalogVersion = "0.1.0"
  })
}

module "vm" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "0.21.0"

  name                               = var.name
  resource_group_name                = var.resource_group_name
  location                           = var.location
  zone                               = "1"
  os_type                            = "Linux"
  sku_size                           = var.size == "small" ? "Standard_D2as_v5" : "Standard_D4as_v5"
  secure_boot_enabled                = true
  vtpm_enabled                       = true
  encryption_at_host_enabled         = true
  boot_diagnostics                   = true
  disable_password_authentication    = true
  generate_admin_password_or_ssh_key = false
  provision_vm_agent                 = true
  patch_mode                         = "AutomaticByPlatform"
  patch_assessment_mode              = "AutomaticByPlatform"
  enable_telemetry                   = false
  tags                               = local.tags

  account_credentials = {
    password_authentication_disabled = true
    admin_credentials = {
      username                           = "platformadmin"
      ssh_keys                           = [var.ssh_public_key]
      generate_admin_password_or_ssh_key = false
    }
  }
  source_image_reference = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "24.04.202609040"
  }
  managed_identities = {
    system_assigned = true
  }
  os_disk = {
    name                 = "osdisk-${var.name}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }
  network_interfaces = {
    primary = {
      name                           = "nic-${var.name}"
      is_primary                     = true
      accelerated_networking_enabled = false
      ip_forwarding_enabled          = false
      tags                           = local.tags
      ip_configurations = {
        primary = {
          name                          = "private"
          is_primary_ipconfiguration    = true
          private_ip_subnet_resource_id = var.subnet_resource_id
          private_ip_address_allocation = "Dynamic"
          create_public_ip_address      = false
          public_ip_address_resource_id = null
        }
      }
    }
  }
  diagnostic_settings = {
    platform = {
      name                  = "diag-vm-platform"
      workspace_resource_id = var.log_analytics_workspace_resource_id
      metric_categories     = ["AllMetrics"]
      log_groups            = []
    }
  }
}
