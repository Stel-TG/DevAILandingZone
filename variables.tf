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

variable "deny_public_access_effect" {
  description = <<-DESC
    Effect for all Deny Public Network Access policy assignments.
    "Deny"     — Block resource creation/update if publicNetworkAccess != Disabled (use in prod).
    "Audit"    — Log a compliance violation but allow the operation (use during onboarding).
    "Disabled" — Policy is inactive (break-glass only).
  DESC
  type    = string
  default = "Deny"
  validation {
    condition     = contains(["Deny", "Audit", "Disabled"], var.deny_public_access_effect)
    error_message = "deny_public_access_effect must be Deny, Audit, or Disabled."
  }
}
variable "deploy_log_analytics"        { type = bool; default = true;  description = "Deploy Log Analytics Workspace for centralized logging." }
variable "deploy_monitor"              { type = bool; default = true;  description = "Deploy Azure Monitor action groups and alert rules." }
variable "deploy_application_insights" { type = bool; default = true;  description = "Deploy Application Insights for application telemetry." }
variable "deploy_networking"           { type = bool; default = true;  description = "Deploy spoke VNET, subnets, and hub peering." }
variable "deploy_key_vault"            { type = bool; default = true;  description = "Deploy Azure Key Vault for secrets and key management." }
variable "deploy_storage"              { type = bool; default = true;  description = "Deploy Azure Storage Account for ML artifacts." }
variable "deploy_container_registry"   { type = bool; default = true;  description = "Deploy Azure Container Registry for ML container images." }
variable "deploy_machine_learning"     { type = bool; default = true;  description = "Deploy Azure Machine Learning workspace." }
variable "deploy_cognitive_services"   { type = bool; default = true;  description = "Deploy Azure AI Services (Cognitive Services) multi-service account. Required for chatbot NLP features; public access disabled, PE required." }
variable "deploy_openai"               { type = bool; default = true;  description = "Deploy Azure OpenAI Service with model deployments. Required for chatbot LLM inference; public access disabled, PE required." }
variable "deploy_private_endpoints"    { type = bool; default = true;  description = "Deploy private endpoints for all services." }
variable "deploy_rbac"                 { type = bool; default = true;  description = "Deploy RBAC role assignments for team groups." }

# AI Foundry and new services (from reference architecture screenshot)
variable "deploy_ai_foundry"           { type = bool; default = true;  description = "Deploy Azure AI Foundry Service, Project, and Agent Service." }
variable "deploy_ai_search"            { type = bool; default = true;  description = "Deploy Azure AI Search (AI Foundry Agent Service dependency)." }
variable "deploy_cosmos_db"            { type = bool; default = true;  description = "Deploy Azure Cosmos DB (AI Foundry and GenAI app dependency)." }
variable "deploy_container_app_env"    { type = bool; default = true;  description = "Deploy Container App Environment with GenAI microservices." }
variable "deploy_app_configuration"    { type = bool; default = true;  description = "Deploy Azure App Configuration for GenAI app settings." }
variable "deploy_api_management"       { type = bool; default = true;  description = "Deploy Azure API Management in internal VNet mode." }
variable "deploy_jumpbox"              { type = bool; default = true;  description = "Deploy jump box VM for secure administrative access." }
variable "deploy_app_gateway"          { type = bool; default = true;  description = "Deploy Application Gateway with WAF for ingress." }
variable "deploy_build_agent"          { type = bool; default = true;  description = "Deploy self-hosted build agent VM in build-agent subnet." }
variable "deploy_security_governance"  { type = bool; default = true;  description = "Deploy Defender for Cloud, Purview, and Entra ID integration." }
variable "deploy_managed_identity"     { type = bool; default = true;  description = "Deploy user-assigned managed identities for workloads." }
variable "deploy_network_watcher"      { type = bool; default = true;  description = "Deploy Network Watcher for flow logs and diagnostics." }

# -----------------------------------------------------------------------------
# NETWORKING VARIABLES
# -----------------------------------------------------------------------------
variable "vnet_address_space" {
  description = "CIDR address space for the spoke VNET. Expanded to /24 (256 IPs) to accommodate all AI Landing Zone subnets with room for growth. 80 IPs remain unallocated (.176 – .255) for future subnets."
  type        = list(string)
  default     = ["10.226.214.0/24"]
}

variable "subnets" {
  description = "Map of subnet definitions. Nine subnets carved from the /24 address space (10.226.214.0/24). 104 IPs remain unallocated (.160 – .255) for future growth."
  type = map(object({
    address_prefix    = string
    service_endpoints = list(string)
  }))
  default = {
    # ── Core private endpoints ─────────────────────────────────────────────────
    "private-endpoints" = {
      # 10.226.214.0 – 10.226.214.31  (27 usable) — all service private endpoints
      address_prefix    = "10.226.214.0/27"
      service_endpoints = []
    }

    # ── AI Foundry Agent ───────────────────────────────────────────────────────
    "ai-foundry-agent" = {
      # 10.226.214.32 – 10.226.214.47  (11 usable) — AI Foundry Agent Service
      address_prefix    = "10.226.214.32/28"
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.CognitiveServices"]
    }

    # ── API Management ─────────────────────────────────────────────────────────
    "api-management" = {
      # 10.226.214.48 – 10.226.214.55  (3 usable) — APIM internal VNet mode
      address_prefix    = "10.226.214.48/29"
      service_endpoints = ["Microsoft.Storage", "Microsoft.Sql", "Microsoft.EventHub"]
    }

    # ── Container App Environment ──────────────────────────────────────────────
    "container-app-environment" = {
      # 10.226.214.64 – 10.226.214.95  (27 usable) — Container Apps Environment
      # /27 is the Microsoft-mandated minimum for VNet-injected workload-profiles CAE.
      address_prefix    = "10.226.214.64/27"
      service_endpoints = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]
    }

    # ── Application Gateway / WAF ──────────────────────────────────────────────
    "application-gateway" = {
      # 10.226.214.96 – 10.226.214.111  (11 usable) — AppGW requires dedicated subnet
      address_prefix    = "10.226.214.96/28"
      service_endpoints = []
    }

    # ── Build agent ────────────────────────────────────────────────────────────
    "build-agent" = {
      # 10.226.214.112 – 10.226.214.119  (3 usable) — self-hosted build agent VM
      address_prefix    = "10.226.214.112/29"
      service_endpoints = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]
    }

    # ── Jump box ───────────────────────────────────────────────────────────────
    "jumpbox" = {
      # 10.226.214.120 – 10.226.214.127  (3 usable) — admin jump box VM
      address_prefix    = "10.226.214.120/29"
      service_endpoints = []
    }

    # ── Databricks (reserved) ──────────────────────────────────────────────────
    "databricks-public" = {
      # 10.226.214.128 – 10.226.214.143  (11 usable) — reserved, future Azure Databricks
      address_prefix    = "10.226.214.128/28"
      service_endpoints = ["Microsoft.Storage"]
    }
    "databricks-private" = {
      # 10.226.214.144 – 10.226.214.159  (11 usable) — reserved, future Azure Databricks
      address_prefix    = "10.226.214.144/28"
      service_endpoints = ["Microsoft.Storage"]
    }

    # ── AML Compute Instances (no-public-IP) ───────────────────────────────────
    "aml-compute" = {
      # 10.226.214.160 – 10.226.214.175  (11 usable) — AML Compute Instances
      # Dedicated subnet required by Microsoft for no-public-IP compute instances.
      # Compute Instance NICs inject here so developers reach services via spoke PEs.
      # No service endpoints — all traffic routes through private endpoints.
      address_prefix    = "10.226.214.160/28"
      service_endpoints = []
    }

    # ── Growth space ───────────────────────────────────────────────────────────
    # 10.226.214.176 – 10.226.214.255  (80 IPs, ~72 usable across subnets)
    # Reserved for future expansion — add subnets here as needed.
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

# -----------------------------------------------------------------------------
# AI FOUNDRY VARIABLES
# -----------------------------------------------------------------------------
variable "ai_foundry_display_name" {
  description = "Display name for the Azure AI Foundry hub resource."
  type        = string
  default     = "AI Foundry Hub"
}

variable "ai_foundry_project_name" {
  description = "Name of the AI Foundry Project within the hub."
  type        = string
  default     = "GenAI Platform"
}

variable "ai_foundry_sku" {
  description = "SKU for the AI Foundry (Azure AI Hub) resource."
  type        = string
  default     = "Basic"
}

# -----------------------------------------------------------------------------
# AI SEARCH VARIABLES
# -----------------------------------------------------------------------------
variable "ai_search_sku" {
  description = "SKU for Azure AI Search. Standard or higher required for semantic search."
  type        = string
  default     = "standard"
  validation {
    condition     = contains(["free", "basic", "standard", "standard2", "standard3"], var.ai_search_sku)
    error_message = "ai_search_sku must be one of: free, basic, standard, standard2, standard3."
  }
}

variable "ai_search_replica_count" {
  description = "Number of replicas for Azure AI Search. Minimum 2 for HA in production."
  type        = number
  default     = 1
}

variable "ai_search_partition_count" {
  description = "Number of partitions for Azure AI Search."
  type        = number
  default     = 1
}

# -----------------------------------------------------------------------------
# COSMOS DB VARIABLES
# -----------------------------------------------------------------------------
variable "cosmos_db_offer_type" {
  description = "Cosmos DB offer type. Standard is the only option currently."
  type        = string
  default     = "Standard"
}

variable "cosmos_db_kind" {
  description = "Cosmos DB account kind: GlobalDocumentDB (NoSQL), MongoDB, Parse."
  type        = string
  default     = "GlobalDocumentDB"
}

variable "cosmos_db_consistency_level" {
  description = "Default consistency level for Cosmos DB."
  type        = string
  default     = "Session"
}

variable "cosmos_db_databases" {
  description = "Map of Cosmos DB databases and containers to create for GenAI workloads."
  type = map(object({
    throughput  = number
    containers  = list(string)
  }))
  default = {
    "agent-memory" = {
      throughput = 400
      containers = ["sessions", "history", "entities"]
    }
    "app-data" = {
      throughput = 400
      containers = ["configs", "results"]
    }
  }
}

# -----------------------------------------------------------------------------
# CONTAINER APP ENVIRONMENT VARIABLES
# -----------------------------------------------------------------------------
variable "container_app_environment_sku" {
  description = "Container App Environment SKU: Consumption or Premium."
  type        = string
  default     = "Consumption"
}

variable "container_app_microservices" {
  description = "Map of GenAI microservice container apps to deploy in the environment."
  type = map(object({
    image            = string
    cpu              = number
    memory           = string
    min_replicas     = number
    max_replicas     = number
    ingress_enabled  = bool
  }))
  default = {
    "frontend" = {
      image           = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu             = 0.5
      memory          = "1.0Gi"
      min_replicas    = 1
      max_replicas    = 10
      ingress_enabled = true
    }
    "orchestrator" = {
      image           = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu             = 0.5
      memory          = "1.0Gi"
      min_replicas    = 1
      max_replicas    = 5
      ingress_enabled = false
    }
    "sk-agent" = {
      image           = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu             = 1.0
      memory          = "2.0Gi"
      min_replicas    = 1
      max_replicas    = 10
      ingress_enabled = false
    }
    "mcp-server" = {
      image           = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu             = 0.5
      memory          = "1.0Gi"
      min_replicas    = 1
      max_replicas    = 5
      ingress_enabled = false
    }
    "ingestion" = {
      image           = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu             = 1.0
      memory          = "2.0Gi"
      min_replicas    = 0
      max_replicas    = 5
      ingress_enabled = false
    }
  }
}

# -----------------------------------------------------------------------------
# API MANAGEMENT VARIABLES
# -----------------------------------------------------------------------------
variable "apim_sku" {
  description = "APIM SKU. Developer for non-prod; Premium for production VNet integration."
  type        = string
  default     = "Developer"
  validation {
    condition     = contains(["Developer", "Basic", "Standard", "Premium", "Consumption"], var.apim_sku)
    error_message = "apim_sku must be Developer, Basic, Standard, Premium, or Consumption."
  }
}

variable "apim_publisher_name" {
  description = "Publisher name for Azure API Management."
  type        = string
  default     = "AI Platform Team"
}

variable "apim_publisher_email" {
  description = "Publisher email for Azure API Management notifications."
  type        = string
  default     = "platform-team@example.com"
}

# -----------------------------------------------------------------------------
# APPLICATION GATEWAY / WAF VARIABLES
# -----------------------------------------------------------------------------
variable "app_gateway_sku_name" {
  description = "Application Gateway SKU name."
  type        = string
  default     = "WAF_v2"
}

variable "app_gateway_sku_tier" {
  description = "Application Gateway SKU tier."
  type        = string
  default     = "WAF_v2"
}

variable "app_gateway_capacity" {
  description = "Number of Application Gateway instances. Min 2 for HA."
  type        = number
  default     = 2
}

variable "waf_mode" {
  description = "WAF mode: Detection (log only) or Prevention (block)."
  type        = string
  default     = "Prevention"
}

# -----------------------------------------------------------------------------
# JUMP BOX VARIABLES
# -----------------------------------------------------------------------------
variable "jumpbox_vm_size" {
  description = "VM size for the jump box. Standard_B2s is sufficient for admin access."
  type        = string
  default     = "Standard_B2s"
}

variable "jumpbox_admin_username" {
  description = "Admin username for the jump box VM."
  type        = string
  default     = "azureadmin"
}

variable "jumpbox_os_disk_type" {
  description = "OS disk storage type for jump box VM."
  type        = string
  default     = "Standard_LRS"
}

# -----------------------------------------------------------------------------
# BUILD AGENT VARIABLES
# -----------------------------------------------------------------------------
variable "build_agent_vm_size" {
  description = "VM size for the self-hosted build agent VM."
  type        = string
  default     = "Standard_D4s_v3"
}

variable "build_agent_admin_username" {
  description = "Admin username for the build agent VM."
  type        = string
  default     = "azureadmin"
}

# -----------------------------------------------------------------------------
# MANAGED IDENTITY VARIABLES
# -----------------------------------------------------------------------------
variable "managed_identity_names" {
  description = "List of user-assigned managed identity names to create for workload use."
  type        = list(string)
  default     = ["id-ai-foundry", "id-container-apps", "id-build-agent"]
}

# -----------------------------------------------------------------------------
# SECURITY & GOVERNANCE VARIABLES
# -----------------------------------------------------------------------------
variable "defender_for_cloud_plans" {
  description = "List of Defender for Cloud plans to enable on the subscription."
  type        = list(string)
  default = [
    "VirtualMachines",
    "ContainerRegistry",
    "KeyVaults",
    "StorageAccounts",
    "AppServices"
  ]
}

variable "purview_account_name" {
  description = "Override name for Microsoft Purview account. Leave empty to use naming convention."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# BING GROUNDING VARIABLES
# -----------------------------------------------------------------------------
variable "deploy_bing_grounding" {
  description = "Deploy Bing Search resource for enterprise knowledge grounding in GenAI apps."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# VM ACCESS VARIABLES
# SSH public key used by both the jump box and build agent VMs.
# Generate with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/ailz_id_rsa
# -----------------------------------------------------------------------------
variable "admin_ssh_public_key" {
  description = "SSH public key for admin access to jump box and build agent VMs."
  type        = string
  default     = "ssh-rsa AAAA...replace-with-your-public-key"
}
