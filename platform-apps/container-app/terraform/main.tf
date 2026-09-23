locals {
  capacity = {
    small  = { cpu = 0.25, memory = "0.5Gi", maximum_replicas = 2 }
    medium = { cpu = 0.5, memory = "1Gi", maximum_replicas = 3 }
  }[var.size]
  tags = merge(var.tags, {
    environment    = "demo"
    platform       = "avm-platform-catalog"
    workload       = "container-app"
    engine         = "terraform"
    catalogVersion = "0.1.0"
  })
}

module "environment" {
  source  = "Azure/avm-res-app-managedenvironment/azurerm"
  version = "0.5.0"

  name                  = "cae-${var.name}"
  resource_group_name   = var.resource_group_name
  location              = var.location
  public_network_access = "Disabled"
  enable_telemetry      = false
  tags                  = local.tags
  managed_identities = {
    system_assigned = true
  }
  vnet_configuration = {
    infrastructure_subnet_id = var.infrastructure_subnet_resource_id
    internal                 = false
  }
  workload_profiles = [{
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }]
  app_logs_configuration = {
    destination = "azure-monitor"
  }
  diagnostic_settings = {
    platform = {
      name                  = "diag-environment-platform"
      workspace_resource_id = var.log_analytics_workspace_resource_id
      log_groups            = ["allLogs"]
      metric_categories     = ["AllMetrics"]
    }
  }
}

module "private_endpoint" {
  source  = "Azure/avm-res-network-privateendpoint/azurerm"
  version = "0.2.0"

  name                           = "pe-${var.name}-environment"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  network_interface_name         = "nic-${var.name}-pe"
  subnet_resource_id             = var.private_endpoint_subnet_resource_id
  private_connection_resource_id = module.environment.resource_id
  subresource_names              = ["managedEnvironments"]
  private_dns_zone_group_name    = "default"
  private_dns_zone_resource_ids  = [var.private_dns_zone_resource_id]
  enable_telemetry               = false
  tags                           = local.tags
}

module "app" {
  source  = "Azure/avm-res-app-containerapp/azurerm"
  version = "0.9.0"

  name                                  = var.name
  resource_group_name                   = var.resource_group_name
  location                              = var.location
  container_app_environment_resource_id = module.environment.resource_id
  revision_mode                         = "Single"
  workload_profile_name                 = "Consumption"
  enable_telemetry                      = false
  tags                                  = local.tags
  managed_identities = {
    system_assigned = true
  }
  ingress = {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = 80
    transport                  = "http"
    traffic_weight = [{
      latest_revision = true
      percentage      = 100
    }]
  }
  template = {
    min_replicas = 0
    max_replicas = local.capacity.maximum_replicas
    containers = [{
      name   = "hello"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld@sha256:e9b3e7c34664c7cffd7144864b0e4eec369bfde80068f9095dc63b37058bec48"
      cpu    = local.capacity.cpu
      memory = local.capacity.memory
    }]
  }
}
