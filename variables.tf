###############################################################################
# AZURE AI LANDING ZONE - ROOT VARIABLES
# All configurable inputs for the landing zone. Override in terraform.tfvars.
###############################################################################

# -----------------------------------------------------------------------------
# CORE ENVIRONMENT VARIABLES
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Short project identifier used in all resource names (e.g., 'aiplatform'). Max 10 chars, lowercase alphanumeric."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{1,10}$", var.project_name))
    error_message = "project_name must be 1-10 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Deployment environment. Used in resource names and tags."
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, staging, prod."
  }
}

variable "location" {
  description = "Primary Azure region for resource deployment."
  type        = string
  default     = "canadacentral"
  validation {
    condition     = contains(["canadacentral", "canadaeast", "eastus", "eastus2"], var.location)
    error_message = "location must comply with policy: canadacentral, canadaeast, eastus, or eastus2."
  }
}

variable "location_short" {
  description = "Short code for location used in resource names (e.g., 'cc' for canadacentral)."
  type        = string
  default     = "cc"
}

variable "allowed_locations" {
  description = "List of Azure regions permitted by policy assignment."
  type        = list(string)
  default     = ["canadacentral", "canadaeast", "eastus", "eastus2"]
}

variable "cost_center" {
  description = "Cost center code for resource tagging and billing allocation."
  type        = string
}

variable "owner_email" {
  description = "Email of the team or individual responsible for this landing zone."
  type        = string
}

# -----------------------------------------------------------------------------
# SUBSCRIPTION AND TENANT
# -----------------------------------------------------------------------------
variable "spoke_subscription_id" {
  description = "Azure Subscription ID where AI Landing Zone resources will be deployed."
  type        = string
  sensitive   = true
}

variable "hub_subscription_id" {
  description = "Azure Subscription ID containing the existing hub VNET (separate from spoke)."
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure Active Directory Tenant ID."
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# MODULE FEATURE FLAGS
# Set to false to skip deployment of specific modules.
# Useful for phased rollouts or environments that don't require all services.
# -----------------------------------------------------------------------------
variable "deploy_policy"               { type = bool; default = true;  description = "Deploy Azure Policy definitions and assignments." }
variable "deploy_log_analytics"        { type = bool; default = true;  description = "Deploy Log Analytics Workspace for centralized logging." }
variable "deploy_monitor"              { type = bool; default = true;  description = "Deploy Azure Monitor action groups and alert rules." }
variable "deploy_application_insights" { type = bool; default = true;  description = "Deploy Application Insights for application telemetry." }
variable "deploy_networking"           { type = bool; default = true;  description = "Deploy spoke VNET, subnets, and hub peering." }
variable "deploy_key_vault"            { type = bool; default = true;  description = "Deploy Azure Key Vault for secrets and key management." }
variable "deploy_storage"              { type = bool; default = true;  description = "Deploy Azure Storage Account for ML artifacts." }
variable "deploy_container_registry"   { type = bool; default = true;  description = "Deploy Azure Container Registry for ML container images." }
variable "deploy_machine_learning"     { type = bool; default = true;  description = "Deploy Azure Machine Learning workspace." }
variable "deploy_cognitive_services"   { type = bool; default = false; description = "Deploy Azure AI Services (Cognitive Services) multi-service account." }
variable "deploy_openai"               { type = bool; default = false; description = "Deploy Azure OpenAI Service with model deployments." }
variable "deploy_private_endpoints"    { type = bool; default = true;  description = "Deploy private endpoints for all services." }
variable "deploy_rbac"                 { type = bool; default = true;  description = "Deploy RBAC role assignments for team groups." }

# -----------------------------------------------------------------------------
# NETWORKING VARIABLES
# -----------------------------------------------------------------------------
variable "vnet_address_space" {
  description = "CIDR address space for the spoke VNET. 10.226.214.192/26 = 64 IPs (.192–.255)."
  type        = list(string)
  default     = ["10.226.214.192/26"]
}

variable "subnets" {
  description = "Map of subnet definitions. Each subnet requires name, prefix, and service_endpoints."
  type = map(object({
    address_prefix    = string
    service_endpoints = list(string)
  }))
  default = {
    # Four /28 subnets (16 IPs each) carved from 10.226.214.192/26
    "machine-learning" = {
      # 10.226.214.192 – 10.226.214.207  (14 usable)
      address_prefix    = "10.226.214.192/28"
      service_endpoints = ["Microsoft.Storage", "Microsoft.ContainerRegistry", "Microsoft.KeyVault", "Microsoft.MachineLearningServices"]
    }
    "private-endpoints" = {
      # 10.226.214.208 – 10.226.214.223  (14 usable)
      address_prefix    = "10.226.214.208/28"
      service_endpoints = []
    }
    "databricks-public" = {
      # 10.226.214.224 – 10.226.214.239  (14 usable) – reserved for future Databricks
      address_prefix    = "10.226.214.224/28"
      service_endpoints = ["Microsoft.Storage"]
    }
    "databricks-private" = {
      # 10.226.214.240 – 10.226.214.255  (14 usable) – reserved for future Databricks
      address_prefix    = "10.226.214.240/28"
      service_endpoints = ["Microsoft.Storage"]
    }
  }
}

variable "hub_vnet_id" {
  description = "Resource ID of the existing hub VNET for peering and DNS zone linking."
  type        = string
}

variable "hub_vnet_name" {
  description = "Name of the existing hub VNET."
  type        = string
}

variable "hub_resource_group" {
  description = "Resource group name containing the hub VNET."
  type        = string
}

# -----------------------------------------------------------------------------
# SERVICE SKU VARIABLES
# -----------------------------------------------------------------------------
variable "log_analytics_sku"        { type = string; default = "PerGB2018"; description = "Log Analytics Workspace pricing SKU." }
variable "log_retention_days"       { type = number; default = 90;          description = "Log retention period in days (30-730)." }
variable "key_vault_sku"            { type = string; default = "premium";   description = "Key Vault SKU. premium supports HSM-backed keys." }
variable "storage_account_tier"     { type = string; default = "Standard";  description = "Storage account performance tier." }
variable "storage_replication_type" { type = string; default = "GRS";       description = "Storage replication: LRS, GRS, ZRS, GZRS." }
variable "container_registry_sku"   { type = string; default = "Premium";   description = "Container Registry SKU. Premium required for private endpoints." }
variable "machine_learning_sku"     { type = string; default = "Basic";     description = "Azure ML workspace SKU." }
variable "cognitive_services_sku"   { type = string; default = "S0";        description = "Cognitive Services SKU." }

# -----------------------------------------------------------------------------
# AZURE OPENAI VARIABLES
# -----------------------------------------------------------------------------
variable "openai_location" {
  description = "Region for Azure OpenAI (limited regional availability - must support OpenAI)."
  type        = string
  default     = "eastus"
}

variable "openai_model_deployments" {
  description = "Map of OpenAI model deployments to create."
  type = map(object({
    model_name    = string
    model_version = string
    capacity      = number
  }))
  default = {
    "gpt-4" = {
      model_name    = "gpt-4"
      model_version = "0613"
      capacity      = 10
    }
    "text-embedding" = {
      model_name    = "text-embedding-ada-002"
      model_version = "2"
      capacity      = 20
    }
  }
}

# -----------------------------------------------------------------------------
# MONITORING VARIABLES
# -----------------------------------------------------------------------------
variable "alert_email_addresses" {
  description = "List of email addresses to receive Azure Monitor alerts."
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# RBAC / GROUP VARIABLES
# AAD Object IDs of security groups for role assignment.
# -----------------------------------------------------------------------------
variable "data_scientist_group_id"   { type = string; default = null; description = "AAD group object ID for Data Scientists." }
variable "ml_engineer_group_id"      { type = string; default = null; description = "AAD group object ID for ML Engineers." }
variable "data_engineer_group_id"    { type = string; default = null; description = "AAD group object ID for Data Engineers." }
variable "ai_app_developer_group_id" { type = string; default = null; description = "AAD group object ID for AI Application Developers." }
variable "platform_admin_group_id"   { type = string; default = null; description = "AAD group object ID for Platform Administrators." }

# -----------------------------------------------------------------------------
# FALLBACK RESOURCE IDs (when dependent modules are disabled)
# Used when deploy_* flags are false but other modules still need the resource.
# -----------------------------------------------------------------------------
variable "existing_key_vault_id"    { type = string; default = null; description = "Existing Key Vault ID if deploy_key_vault is false." }
variable "existing_storage_id"      { type = string; default = null; description = "Existing Storage Account ID if deploy_storage is false." }
variable "existing_app_insights_id" { type = string; default = null; description = "Existing App Insights ID if deploy_application_insights is false." }
