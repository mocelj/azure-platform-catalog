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
    condition     = module.site.resource.body.properties.publicNetworkAccess == "Disabled" && module.site.resource.body.properties.httpsOnly
    error_message = "The site must use HTTPS with private ingress."
  }
  assert {
    condition     = module.site.resource.body.properties.outboundVnetRouting.allTraffic && module.site.resource.body.properties.virtualNetworkSubnetId == var.integration_subnet_resource_id
    error_message = "The site must use the integration subnet and route outbound traffic through the VNet."
  }
  assert {
    condition     = module.site.resource.body.properties.siteConfig.linuxFxVersion == "NODE|24-lts" && module.site.resource.body.properties.siteConfig.appCommandLine == "node server.js"
    error_message = "The runtime and startup command must match the supplied application."
  }
  assert {
    condition     = length(module.site.private_endpoints) == 1 && module.site.resource.body.properties.siteConfig.ftpsState == "Disabled"
    error_message = "The site must have a private endpoint and FTP disabled."
  }
}
run "medium_private" {
  command = plan
  variables { size = "medium" }
  assert {
    condition     = module.site.resource.body.properties.publicNetworkAccess == "Disabled"
    error_message = "Changing size cannot change the network policy."
  }
}
run "reject_unapproved_size" {
  command = plan
  variables { size = "unapproved" }
  expect_failures = [var.size]
}
