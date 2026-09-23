data "azapi_client_config" "current" {}

locals {
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  site_name = "${var.name}-${substr(sha256("${data.azapi_client_config.current.subscription_id}/${var.resource_group_name}/${var.name}"), 0, 8)}"
  tags = merge(var.tags, {
    environment    = "demo"
    platform       = "avm-platform-catalog"
    workload       = "web-app"
    engine         = "terraform"
    catalogVersion = "0.1.0"
  })
}

module "plan" {
  source  = "Azure/avm-res-web-serverfarm/azurerm"
  version = "2.0.8"

  name                   = "asp-${var.name}"
  parent_id              = local.parent_id
  location               = var.location
  os_type                = "Linux"
  sku_name               = var.size == "small" ? "B1" : "B2"
  worker_count           = 1
  zone_balancing_enabled = false
  enable_telemetry       = false
  tags                   = local.tags
  diagnostic_settings = {
    platform = {
      workspace_resource_id = var.log_analytics_workspace_resource_id
      metrics               = [{ category = "AllMetrics", enabled = true }]
    }
  }
}

module "site" {
  source  = "Azure/avm-res-web-site/azurerm"
  version = "0.23.0"

  name                                     = local.site_name
  parent_id                                = local.parent_id
  location                                 = var.location
  service_plan_resource_id                 = module.plan.resource_id
  kind                                     = "webapp"
  os_type                                  = "Linux"
  https_only                               = true
  public_network_access_enabled            = false
  ftp_publish_basic_authentication_enabled = false
  scm_publish_basic_authentication_enabled = false
  virtual_network_subnet_id                = var.integration_subnet_resource_id
  vnet_route_all_traffic                   = true
  enable_telemetry                         = false
  tags                                     = local.tags
  managed_identities = {
    system_assigned = true
  }
  site_config = {
    linux_fx_version                  = "NODE|24-lts"
    app_command_line                  = "node server.js"
    always_on                         = true
    minimum_tls_version               = "1.2"
    scm_minimum_tls_version           = "1.2"
    ftps_state                        = "Disabled"
    remote_debugging_enabled          = false
    http2_enabled                     = true
    vnet_route_all_enabled            = true
    ip_restriction_default_action     = "Deny"
    scm_ip_restriction_default_action = "Deny"
  }
  private_endpoints = {
    site = {
      name                          = "pe-${var.name}-site"
      subnet_resource_id            = var.private_endpoint_subnet_resource_id
      private_dns_zone_resource_ids = [var.private_dns_zone_resource_id]
      tags                          = local.tags
    }
  }
  diagnostic_settings = {
    platform = {
      workspace_resource_id = var.log_analytics_workspace_resource_id
      logs                  = [{ category_group = "allLogs", enabled = true }]
      metrics               = [{ category = "AllMetrics", enabled = true }]
    }
  }
}
