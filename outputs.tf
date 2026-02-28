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

# -----------------------------------------------------------------------------
# AI FOUNDRY
# -----------------------------------------------------------------------------
output "ai_foundry_hub_id" {
  description = "Azure AI Foundry Hub resource ID."
  value       = var.deploy_ai_foundry ? module.ai_foundry[0].hub_id : null
}

output "ai_foundry_project_id" {
  description = "Azure AI Foundry Project resource ID."
  value       = var.deploy_ai_foundry ? module.ai_foundry[0].project_id : null
}

# -----------------------------------------------------------------------------
# AI SEARCH
# -----------------------------------------------------------------------------
output "ai_search_id" {
  description = "Azure AI Search resource ID."
  value       = var.deploy_ai_search ? module.ai_search[0].id : null
}

output "ai_search_endpoint" {
  description = "Azure AI Search endpoint URL."
  value       = var.deploy_ai_search ? module.ai_search[0].endpoint : null
}

# -----------------------------------------------------------------------------
# COSMOS DB
# -----------------------------------------------------------------------------
output "cosmos_db_endpoint" {
  description = "Cosmos DB account endpoint URI."
  value       = var.deploy_cosmos_db ? module.cosmos_db[0].endpoint : null
}

output "cosmos_db_id" {
  description = "Cosmos DB account resource ID."
  value       = var.deploy_cosmos_db ? module.cosmos_db[0].id : null
}

# -----------------------------------------------------------------------------
# CONTAINER APP ENVIRONMENT
# -----------------------------------------------------------------------------
output "container_app_environment_id" {
  description = "Container App Environment resource ID."
  value       = var.deploy_container_app_env ? module.container_app_environment[0].id : null
}

output "container_app_environment_default_domain" {
  description = "Default domain for the Container App Environment."
  value       = var.deploy_container_app_env ? module.container_app_environment[0].default_domain : null
}

# -----------------------------------------------------------------------------
# API MANAGEMENT
# -----------------------------------------------------------------------------
output "apim_gateway_url" {
  description = "API Management gateway URL."
  value       = var.deploy_api_management ? module.api_management[0].gateway_url : null
}

output "apim_private_ip_addresses" {
  description = "Private IP addresses assigned to the APIM instance (internal VNet mode)."
  value       = var.deploy_api_management ? module.api_management[0].private_ip_addresses : null
}

# -----------------------------------------------------------------------------
# APP CONFIGURATION
# -----------------------------------------------------------------------------
output "app_configuration_endpoint" {
  description = "App Configuration store endpoint URL."
  value       = var.deploy_app_configuration ? module.app_configuration[0].endpoint : null
}

# -----------------------------------------------------------------------------
# APPLICATION GATEWAY
# -----------------------------------------------------------------------------
output "app_gateway_public_ip" {
  description = "Public IP address of the Application Gateway (WAF) front-end."
  value       = var.deploy_app_gateway ? module.app_gateway[0].public_ip_address : null
}

# -----------------------------------------------------------------------------
# MANAGED IDENTITIES
# -----------------------------------------------------------------------------
output "managed_identity_foundry_id" {
  description = "Resource ID of the AI Foundry user-assigned managed identity."
  value       = var.deploy_managed_identity ? module.managed_identity[0].foundry_identity_id : null
}

output "managed_identity_apps_id" {
  description = "Resource ID of the Container Apps user-assigned managed identity."
  value       = var.deploy_managed_identity ? module.managed_identity[0].apps_identity_id : null
}

output "managed_identity_build_id" {
  description = "Resource ID of the build agent user-assigned managed identity."
  value       = var.deploy_managed_identity ? module.managed_identity[0].build_identity_id : null
}
