variable "name" {
  type        = string
  description = "Application name used for the Container App."
  nullable    = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name))
    error_message = "name must be 3-20 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "location" {
  type        = string
  description = "Azure region used by this example."
  default     = "swedencentral"
  nullable    = false
  validation {
    condition     = var.location == "swedencentral"
    error_message = "This example is configured for swedencentral."
  }
}

variable "size" {
  type        = string
  description = "Capacity tier: small uses 0.25 vCPU/0.5 GiB and up to two replicas; medium uses 0.5 vCPU/1 GiB and up to three."
  nullable    = false
  validation {
    condition     = contains(["small", "medium"], var.size)
    error_message = "size must be small or medium."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Existing resource group assigned to this Terraform instance."
  nullable    = false
  validation {
    condition     = can(regex("^rg-[a-z0-9-]{3,70}$", var.resource_group_name))
    error_message = "Use the rg- resource group assigned to this instance by the platform team."
  }
}

variable "log_analytics_workspace_resource_id" {
  type        = string
  description = "Resource ID of the shared Log Analytics workspace."
  nullable    = false
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.OperationalInsights/workspaces/[^/]+$", var.log_analytics_workspace_resource_id))
    error_message = "A Log Analytics workspace resource ID is required."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional resource tags. The wrapper retains the required catalog tags."
  nullable    = false
}

variable "private_endpoint_subnet_resource_id" {
  type        = string
  description = "Resource ID of the subnet used for private endpoints."
  nullable    = false
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.private_endpoint_subnet_resource_id))
    error_message = "A private endpoint subnet ARM ID is required."
  }
}

variable "private_dns_zone_resource_id" {
  type        = string
  description = "Resource ID of the privatelink.swedencentral.azurecontainerapps.io DNS zone."
  nullable    = false
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/privateDnsZones/privatelink\\.swedencentral\\.azurecontainerapps\\.io$", var.private_dns_zone_resource_id))
    error_message = "Supply the resource ID of the swedencentral Container Apps private DNS zone."
  }
}

variable "infrastructure_subnet_resource_id" {
  type        = string
  description = "Infrastructure subnet for this environment, delegated to Microsoft.App/environments and connected to NAT."
  nullable    = false
  validation {
    condition = (
      can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.infrastructure_subnet_resource_id)) &&
      lower(var.infrastructure_subnet_resource_id) != lower(var.private_endpoint_subnet_resource_id)
    )
    error_message = "Use a separate infrastructure subnet for the environment, not the private endpoint subnet."
  }
}
