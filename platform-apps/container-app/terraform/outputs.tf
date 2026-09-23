output "resource_id" {
  description = "Container App resource ID."
  value       = module.app.resource_id
}

output "name" {
  description = "Container App name."
  value       = module.app.name
}

output "url" {
  description = "HTTPS ingress URL; accessible only through the environment's private endpoint."
  value       = module.app.fqdn_url
}

output "environment_resource_id" {
  description = "Resource ID of the workload-profiles environment."
  value       = module.environment.resource_id
}

output "private_endpoint_resource_id" {
  description = "Environment private endpoint resource ID."
  value       = module.private_endpoint.resource_id
}
