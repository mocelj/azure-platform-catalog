data "azapi_client_config" "current" {}

locals {
  account_name = "${substr(replace(var.name, "-", ""), 0, 15)}${substr(sha256("${data.azapi_client_config.current.subscription_id}/${var.resource_group_name}/${var.name}"), 0, 8)}"
  tags = merge(var.tags, {
    environment    = "demo"
    platform       = "avm-platform-catalog"
    workload       = "storage"
    engine         = "terraform"
    catalogVersion = "0.1.0"
  })
}

module "storage" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.10.0"

  name                              = local.account_name
  parent_id                         = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  location                          = var.location
  account_kind                      = "StorageV2"
  account_sku_name                  = var.size == "small" ? "Standard_LRS" : "Standard_ZRS"
  access_tier                       = "Hot"
  public_network_access_enabled     = false
  shared_access_key_enabled         = false
  allow_nested_items_to_be_public   = false
  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  default_to_oauth_authentication   = true
  infrastructure_encryption_enabled = true
  cross_tenant_replication_enabled  = false
  local_user_enabled                = false
  enable_telemetry                  = false
  tags                              = local.tags

  managed_identities = {
    system_assigned = true
  }
  network_rules = {
    default_action = "Deny"
    bypass         = ["None"]
  }
  containers = {
    data = {
      name          = "data"
      public_access = "None"
    }
  }
  blob_properties = {
    versioning_enabled = true
    delete_retention_policy = {
      enabled = true
      days    = 7
    }
    container_delete_retention_policy = {
      enabled = true
      days    = 7
    }
  }
  private_endpoints = {
    blob = {
      name                          = "pe-${var.name}-blob"
      subnet_resource_id            = var.private_endpoint_subnet_resource_id
      subresource_name              = "blob"
      private_dns_zone_resource_ids = [var.private_dns_zone_resource_id]
      tags                          = local.tags
    }
  }
  diagnostic_settings_storage_account = {
    platform = {
      workspace_resource_id = var.log_analytics_workspace_resource_id
      metrics               = [{ category = "AllMetrics", enabled = true }]
    }
  }
  diagnostic_settings_blob = {
    platform = {
      workspace_resource_id = var.log_analytics_workspace_resource_id
      logs                  = [{ category_group = "allLogs", enabled = true }]
      metrics               = [{ category = "AllMetrics", enabled = true }]
    }
  }
}
