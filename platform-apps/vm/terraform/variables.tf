variable "name" {
  type        = string
  description = "Application name used for the virtual machine."
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
  description = "VM tier: small uses Standard_D2as_v5; medium uses Standard_D4as_v5."
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

variable "subnet_resource_id" {
  type        = string
  description = "Resource ID of the VM subnet, with its NSG and NAT egress already configured."
  nullable    = false
  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.subnet_resource_id))
    error_message = "A private VM subnet ARM ID is required."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access. Keep the private key on the management host."
  nullable    = false
  validation {
    condition     = can(regex("^ssh-(rsa|ed25519) [A-Za-z0-9+/=]+( [^\\r\\n]+)?$", var.ssh_public_key))
    error_message = "Supply an OpenSSH RSA or Ed25519 public key."
  }
}
