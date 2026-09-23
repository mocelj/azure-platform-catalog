variable "name" {
  type        = string
  description = "Application name used to derive the storage account name and its unique suffix."
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
  description = "Storage tier: small uses LRS; medium uses ZRS."
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
  description = "Resource ID of the privatelink.blob.core.windows.net zone linked to the client network."
  nullable    = false
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/privateDnsZones/privatelink\\.blob\\.core\\.windows\\.net$", var.private_dns_zone_resource_id))
    error_message = "Supply the resource ID of the privatelink.blob.core.windows.net zone."
  }
}
