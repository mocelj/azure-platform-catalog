variable "name" {
  type        = string
  description = "Approved instance name; the wrapper derives a globally unique storage account name."
  nullable    = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name))
    error_message = "name must match the platform application naming contract."
  }
}

variable "location" {
  type        = string
  description = "Approved Azure region."
  default     = "swedencentral"
  nullable    = false
  validation {
    condition     = var.location == "swedencentral"
    error_message = "Only swedencentral is approved."
  }
}

variable "size" {
  type        = string
  description = "Approved capacity tier: small or medium."
  nullable    = false
  validation {
    condition     = contains(["small", "medium"], var.size)
    error_message = "size must be small or medium."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Existing, Terraform-target-specific workload resource group."
  nullable    = false
  validation {
    condition     = can(regex("^rg-[a-z0-9-]{3,70}$", var.resource_group_name))
    error_message = "Use a platform-owned rg- resource group."
  }
}

variable "log_analytics_workspace_resource_id" {
  type        = string
  description = "Existing platform Log Analytics workspace ARM resource ID."
  nullable    = false
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.OperationalInsights/workspaces/[^/]+$", var.log_analytics_workspace_resource_id))
    error_message = "A Log Analytics workspace resource ID is required."
  }
}

variable "tags" {
  type        = map(string)
  description = "Platform-owned metadata; mandatory tags are enforced by the wrapper."
  nullable    = false
}

variable "private_endpoint_subnet_resource_id" {
  type        = string
  description = "Existing dedicated private endpoint subnet ARM ID."
  nullable    = false
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.private_endpoint_subnet_resource_id))
    error_message = "A private endpoint subnet ARM ID is required."
  }
}

variable "private_dns_zone_resource_id" {
  type        = string
  description = "Existing privatelink.blob.core.windows.net DNS zone linked to private clients."
  nullable    = false
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/privateDnsZones/privatelink\\.blob\\.core\\.windows\\.net$", var.private_dns_zone_resource_id))
    error_message = "Use the platform privatelink.blob.core.windows.net zone."
  }
}
