mock_provider "azapi" {}
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "11111111-1111-1111-1111-111111111111"
      object_id       = "22222222-2222-2222-2222-222222222222"
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "tls" {}

run "small_private" {
  command = plan
  assert {
    condition     = length(module.vm.public_ips) == 0 && module.vm.resource.disable_password_authentication
    error_message = "No public IP or password authentication is allowed."
  }
  assert {
    condition     = module.vm.resource.secure_boot_enabled && module.vm.resource.vtpm_enabled && module.vm.resource.encryption_at_host_enabled
    error_message = "The VM plan must enable Secure Boot, vTPM and encryption at host."
  }
  assert {
    condition     = module.vm.resource.source_image_reference[0].version == "24.04.202609040" && module.vm.resource.size == "Standard_D2as_v5"
    error_message = "Image and size must match the pinned small tier."
  }
}
run "medium_private" {
  command = plan
  variables { size = "medium" }
  assert {
    condition     = module.vm.resource.size == "Standard_D4as_v5"
    error_message = "The medium tier must select D4as_v5."
  }
}
run "reject_unapproved_region" {
  command = plan
  variables { location = "eastus" }
  expect_failures = [var.location]
}
