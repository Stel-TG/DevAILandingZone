###############################################################################
# AZURE AI LANDING ZONE - OUTPUTS
# Key resource identifiers exposed for consumption by other Terraform
# configurations, pipelines, or downstream automation.
###############################################################################

output "resource_group_name" {
  description = "Name of the primary resource group."
  value       = module.resource_group.name
}

output "resource_group_id" {
  description = "Resource ID of the primary resource group."
  value       = module.resource_group.id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID."
  value       = var.deploy_log_analytics ? module.log_analytics[0].workspace_id : null
}

output "log_analytics_workspace_key" {
  description = "Log Analytics Workspace primary shared key."
  value       = var.deploy_log_analytics ? module.log_analytics[0].primary_shared_key : null
  sensitive   = true
}

output "key_vault_id" {
  description = "Key Vault resource ID."
  value       = var.deploy_key_vault ? module.key_vault[0].id : null
}

output "key_vault_uri" {
  description = "Key Vault URI for secret retrieval."
  value       = var.deploy_key_vault ? module.key_vault[0].vault_uri : null
}

output "storage_account_id" {
  description = "Storage Account resource ID."
  value       = var.deploy_storage ? module.storage[0].id : null
}

output "storage_account_name" {
  description = "Storage Account name."
  value       = var.deploy_storage ? module.storage[0].name : null
}

output "container_registry_id" {
  description = "Container Registry resource ID."
  value       = var.deploy_container_registry ? module.container_registry[0].id : null
}

output "container_registry_login_server" {
  description = "Container Registry login server URL."
  value       = var.deploy_container_registry ? module.container_registry[0].login_server : null
}

output "machine_learning_workspace_id" {
  description = "Azure Machine Learning Workspace resource ID."
  value       = var.deploy_machine_learning ? module.machine_learning[0].id : null
}

output "machine_learning_workspace_name" {
  description = "Azure Machine Learning Workspace name."
  value       = var.deploy_machine_learning ? module.machine_learning[0].name : null
}

output "application_insights_connection_string" {
  description = "Application Insights connection string for SDK configuration."
  value       = var.deploy_application_insights ? module.application_insights[0].connection_string : null
  sensitive   = true
}

output "vnet_id" {
  description = "Spoke VNET resource ID."
  value       = var.deploy_networking ? module.networking[0].vnet_id : null
}

output "subnet_ids" {
  description = "Map of subnet names to their resource IDs."
  value       = var.deploy_networking ? module.networking[0].subnet_ids : null
}

output "openai_endpoint" {
  description = "Azure OpenAI service endpoint URL."
  value       = var.deploy_openai ? module.openai[0].endpoint : null
}

output "cognitive_services_endpoint" {
  description = "Azure AI Services endpoint URL."
  value       = var.deploy_cognitive_services ? module.cognitive_services[0].endpoint : null
}
