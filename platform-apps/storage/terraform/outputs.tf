output "resource_id" {
  description = "Storage account resource ID."
  value       = module.storage.resource_id
}

output "name" {
  description = "Globally unique storage account name."
  value       = module.storage.name
}

output "hostname" {
  description = "Blob hostname, resolved through private DNS from the client network."
  value       = module.storage.fqdn.blob
}

output "private_endpoint_resource_id" {
  description = "Private Blob endpoint resource ID."
  value       = module.storage.private_endpoints.blob.id
}
