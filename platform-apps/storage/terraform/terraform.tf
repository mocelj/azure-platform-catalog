terraform {
  required_version = "= 1.13.5"
  backend "azurerm" {}
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "= 2.12.0"
    }
    modtm = {
      source  = "Azure/modtm"
      version = "= 0.3.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.9.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "= 0.14.2"
    }
  }
}

provider "azapi" {
  enable_preflight           = false
  skip_provider_registration = true
  use_oidc                   = true
  use_cli                    = false
}
