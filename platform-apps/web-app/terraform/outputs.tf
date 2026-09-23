output "resource_id" {
  description = "Web App resource ID."
  value       = module.site.resource_id
}

output "name" {
  description = "Globally unique Web App name."
  value       = module.site.name
}

output "hostname" {
  description = "Site hostname; private DNS and connectivity are required."
  value       = module.site.resource_uri
}

output "system_assigned_mi_principal_id" {
  description = "System-assigned identity principal ID; not a credential."
  value       = module.site.system_assigned_mi_principal_id
}
