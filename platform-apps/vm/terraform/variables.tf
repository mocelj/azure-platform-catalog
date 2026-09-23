variable "name" {
  type        = string
  description = "Approved instance name."
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

variable "subnet_resource_id" {
  type        = string
  description = "Private VM subnet; platform NSG and NAT-backed egress must already exist."
  nullable    = false
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.subnet_resource_id))
    error_message = "A private VM subnet ARM ID is required."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "Platform operator SSH public key. Never supply a private key."
  nullable    = false
  validation {
    condition     = can(regex("^ssh-(rsa|ed25519) [A-Za-z0-9+/=]+( [^\\r\\n]+)?$", var.ssh_public_key))
    error_message = "Supply an OpenSSH RSA or Ed25519 public key, never a private key."
  }
}
