output "resource_id" {
  description = "Storage account resource ID, never account keys."
  value       = module.storage.resource_id
}

output "name" {
  description = "Globally unique storage account name."
  value       = module.storage.name
}

output "hostname" {
  description = "Blob hostname; private DNS and connectivity are required."
  value       = module.storage.fqdn.blob
}

output "private_endpoint_resource_id" {
  description = "Private Blob endpoint resource ID."
  value       = module.storage.private_endpoints.blob.id
}
