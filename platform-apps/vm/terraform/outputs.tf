output "resource_id" {
  description = "Private virtual machine resource ID."
  value       = module.vm.resource_id
}

output "name" {
  description = "Virtual machine name."
  value       = module.vm.name
}

output "private_ip_address" {
  description = "Primary private IP; no public IP is assigned."
  value       = module.vm.virtual_machine_azurerm.private_ip_address
}

output "system_assigned_mi_principal_id" {
  description = "System-assigned identity principal ID; not a credential."
  value       = module.vm.system_assigned_mi_principal_id
}
