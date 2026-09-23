mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "11111111-1111-1111-1111-111111111111"
      object_id       = "22222222-2222-2222-2222-222222222222"
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "small_private" {
  command = plan
  assert {
    condition     = module.storage.resource.body.properties.allowSharedKeyAccess == false && module.storage.resource.body.properties.publicNetworkAccess == "Disabled"
    error_message = "Storage must remain private and Entra-only."
  }
  assert {
    condition     = module.storage.resource.body.properties.minimumTlsVersion == "TLS1_2" && module.storage.resource.body.properties.allowBlobPublicAccess == false
    error_message = "The storage plan must require TLS 1.2 and disable anonymous Blob access."
  }
  assert {
    condition     = length(module.storage.private_endpoints) == 1 && module.storage.resource.body.sku.name == "Standard_LRS"
    error_message = "The small tier requires LRS and a Blob private endpoint."
  }
}

run "medium_private" {
  command = plan
  variables { size = "medium" }
  assert {
    condition     = module.storage.resource.body.sku.name == "Standard_ZRS"
    error_message = "The medium tier must select ZRS."
  }
}

run "reject_unapproved_size" {
  command = plan
  variables { size = "unapproved" }
  expect_failures = [var.size]
}
