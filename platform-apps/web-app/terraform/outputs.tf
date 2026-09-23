output "resource_id" {
  description = "Web App resource ID."
  value       = module.site.resource_id
}

output "name" {
  description = "Globally unique Web App name."
  value       = module.site.name
}

output "hostname" {
  description = "Site hostname, resolved through private DNS from the client network."
  value       = module.site.resource_uri
}

output "system_assigned_mi_principal_id" {
  description = "Principal ID of the Web App's system-assigned managed identity."
  value       = module.site.system_assigned_mi_principal_id
}
