###############################################################################
# AZURE AI LANDING ZONE - ROOT ORCHESTRATION
# Reference: https://github.com/Azure/AI-Landing-Zones
#
# PURPOSE: This file serves as the primary orchestration layer for the Azure
#          AI Landing Zone deployment. It composes all modules together and
#          controls which resources are provisioned via feature flags.
#
# USAGE:   Toggle the `deploy_*` variables in terraform.tfvars to enable or
#          disable specific modules without modifying this file.
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # -------------------------------------------------------------------------
  # REMOTE STATE CONFIGURATION
  # State is stored in Azure Blob Storage for team collaboration and locking.
  # The storage account is bootstrapped via scripts/bootstrap.sh before
  # running terraform init with this backend configuration.
  # -------------------------------------------------------------------------
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-prod-cc"
    storage_account_name = "sttfstateprodcc"
    container_name       = "tfstate"
    key                  = "ai-landing-zone/terraform.tfstate"
    use_oidc             = true # Use workload identity federation for CI/CD
  }
}

# -----------------------------------------------------------------------------
# PROVIDER CONFIGURATION
# The hub provider alias is retained for any future cross-subscription reads
# (e.g., DNS zone data sources). Hub VNET peering is managed separately via
# scripts\setup-peering.ps1 and does not require Terraform provider aliases.
# -----------------------------------------------------------------------------
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false # Retain deleted vaults for 90 days
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true # Safety guard for production
    }
  }
  subscription_id = var.spoke_subscription_id
  use_oidc        = true
}

provider "azurerm" {
  alias = "hub"
  features {}
  subscription_id = var.hub_subscription_id
  use_oidc        = true
}

provider "azuread" {}

# -----------------------------------------------------------------------------
# LOCAL VALUES
# Imports naming conventions from naming.tf and computes derived values
# used across multiple modules to ensure consistency.
# -----------------------------------------------------------------------------
locals {
  # Pull standardized resource names from naming.tf
  names = local.naming_convention

  # Common tags applied to all resources for governance and cost tracking
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    CostCenter  = var.cost_center
    Owner       = var.owner_email
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
  }
}

###############################################################################
# MODULE: RESOURCE GROUP
# Creates the primary resource group for all AI Landing Zone resources.
# All subsequent modules reference this resource group.
###############################################################################
module "resource_group" {
  source = "./modules/resource_group"

  name     = local.names.resource_group
  location = var.location
  tags     = local.common_tags
}

###############################################################################
# MODULE: POLICY
# Deploys Azure Policy definitions and assignments to enforce:
#   - Allowed locations (canadacentral, canadaeast, eastus, eastus2)
#   - Required tags on all resources
#   - Deny public network access on AI services
#   - Require private endpoints for storage and key vault
#
# count = 1 always; policy is mandatory for landing zone compliance.
###############################################################################
module "policy" {
  source = "./modules/policy"

  count = var.deploy_policy ? 1 : 0

  resource_group_name = module.resource_group.name
  location            = var.location
  environment         = var.environment
  allowed_locations   = var.allowed_locations
  project_name        = var.project_name
  tags                = local.common_tags

  depends_on = [module.resource_group]
}

###############################################################################
# MODULE: LOG ANALYTICS WORKSPACE
# Central logging destination for all platform and application logs.
# Required by monitoring, application insights, and diagnostic settings.
# Deployed before other modules as many depend on its workspace ID.
###############################################################################
module "log_analytics" {
  source = "./modules/log_analytics"

  count = var.deploy_log_analytics ? 1 : 0

  name                = local.names.log_analytics_workspace
  resource_group_name = module.resource_group.name
  location            = var.location
  sku                 = var.log_analytics_sku
  retention_days      = var.log_retention_days
  tags                = local.common_tags

  depends_on = [module.resource_group]
}

###############################################################################
# MODULE: AZURE MONITOR
# Configures action groups, alert rules, and diagnostic settings.
# Requires log_analytics to be deployed first for log routing.
###############################################################################
module "monitor" {
  source = "./modules/monitor"

  count = var.deploy_monitor ? 1 : 0

  resource_group_name        = module.resource_group.name
  location                   = var.location
  log_analytics_workspace_id = var.deploy_log_analytics ? module.log_analytics[0].workspace_id : null
  alert_email_addresses      = var.alert_email_addresses
  project_name               = var.project_name
  environment                = var.environment
  tags                       = local.common_tags

  depends_on = [module.log_analytics]
}

###############################################################################
# MODULE: APPLICATION INSIGHTS
# Application performance monitoring for AI workloads and MLflow tracking.
# Linked to Log Analytics for unified log querying via workspace-based mode.
###############################################################################
module "application_insights" {
  source = "./modules/application_insights"

  count = var.deploy_application_insights ? 1 : 0

  name                       = local.names.application_insights
  resource_group_name        = module.resource_group.name
  location                   = var.location
  application_type           = "web"
  log_analytics_workspace_id = var.deploy_log_analytics ? module.log_analytics[0].workspace_id : null
  tags                       = local.common_tags

  depends_on = [module.log_analytics]
}

###############################################################################
# MODULE: NETWORKING
# Provisions the spoke VNET (10.226.214.192/26) and four /28 subnets.
#
# NOTE: Hub VNET peering is NOT performed here. Run scripts\setup-peering.ps1
#       after this deployment to establish hub-spoke connectivity.
###############################################################################
module "networking" {
  source = "./modules/networking"

  count = var.deploy_networking ? 1 : 0

  vnet_name           = local.names.virtual_network
  resource_group_name = module.resource_group.name
  location            = var.location
  vnet_address_space  = var.vnet_address_space  # ["10.226.214.192/26"]
  subnets             = var.subnets
  tags                = local.common_tags

  depends_on = [module.resource_group]
}

###############################################################################
# MODULE: NETWORK SECURITY GROUP
# Defines NSG rules for each subnet to allow required traffic:
#   - Azure services (AzureActiveDirectory, Storage, KeyVault service tags)
#   - Inter-subnet communication within the spoke VNET
#   - Deny all inbound internet traffic by default
###############################################################################
module "nsg" {
  source = "./modules/nsg"

  count = var.deploy_networking ? 1 : 0

  resource_group_name = module.resource_group.name
  location            = var.location
  subnets             = var.subnets
  vnet_name           = local.names.virtual_network
  tags                = local.common_tags

  depends_on = [module.networking]
}

###############################################################################
# MODULE: KEY VAULT
# Stores secrets, certificates, and encryption keys for all AI services.
# Soft-delete and purge protection enabled. RBAC authorization model used.
# Access restricted to private endpoint only (no public network access).
###############################################################################
module "key_vault" {
  source = "./modules/key_vault"

  count = var.deploy_key_vault ? 1 : 0

  name                       = local.names.key_vault
  resource_group_name        = module.resource_group.name
  location                   = var.location
  sku_name                   = var.key_vault_sku
  tenant_id                  = var.tenant_id
  log_analytics_workspace_id = var.deploy_log_analytics ? module.log_analytics[0].workspace_id : null
  allowed_subnet_ids         = var.deploy_networking ? [module.networking[0].subnet_ids["services"]] : []
  tags                       = local.common_tags

  depends_on = [module.networking, module.log_analytics]
}

###############################################################################
# MODULE: STORAGE ACCOUNT
# General-purpose storage for ML artifacts, datasets, and model outputs.
# Hierarchical namespace enabled for Data Lake Gen2 capability.
# TLS 1.2 minimum, public access disabled, private endpoint required.
###############################################################################
module "storage" {
  source = "./modules/storage"

  count = var.deploy_storage ? 1 : 0

  name                       = local.names.storage_account
  resource_group_name        = module.resource_group.name
  location                   = var.location
  account_tier               = var.storage_account_tier
  account_replication_type   = var.storage_replication_type
  is_hns_enabled             = true # Data Lake Gen2
  log_analytics_workspace_id = var.deploy_log_analytics ? module.log_analytics[0].workspace_id : null
  allowed_subnet_ids         = var.deploy_networking ? [module.networking[0].subnet_ids["storage"]] : []
  tags                       = local.common_tags

  depends_on = [module.networking, module.log_analytics]
}

###############################################################################
# MODULE: CONTAINER REGISTRY
# Stores Docker images for ML training and inference containers.
# Geo-replication to secondary region for HA. Admin user disabled.
# Content trust enabled for image signing in production.
###############################################################################
module "container_registry" {
  source = "./modules/container_registry"

  count = var.deploy_container_registry ? 1 : 0

  name                       = local.names.container_registry
  resource_group_name        = module.resource_group.name
  location                   = var.location
  sku                        = var.container_registry_sku
  log_analytics_workspace_id = var.deploy_log_analytics ? module.log_analytics[0].workspace_id : null
  allowed_subnet_ids         = var.deploy_networking ? [module.networking[0].subnet_ids["services"]] : []
  tags                       = local.common_tags

  depends_on = [module.networking, module.log_analytics]
}

###############################################################################
# MODULE: AZURE MACHINE LEARNING
# Single AML workspace integrating with all platform services.
# Uses managed virtual network for compute isolation.
# Requires: Key Vault, Storage, App Insights, Container Registry.
###############################################################################
module "machine_learning" {
  source = "./modules/machine_learning"

  count = var.deploy_machine_learning ? 1 : 0

  name                       = local.names.machine_learning_workspace
  resource_group_name        = module.resource_group.name
  location                   = var.location
  sku_name                   = var.machine_learning_sku
  key_vault_id               = var.deploy_key_vault ? module.key_vault[0].id : var.existing_key_vault_id
  storage_account_id         = var.deploy_storage ? module.storage[0].id : var.existing_storage_id
  application_insights_id    = var.deploy_application_insights ? module.application_insights[0].id : var.existing_app_insights_id
  container_registry_id      = var.deploy_container_registry ? module.container_registry[0].id : null
  log_analytics_workspace_id = var.deploy_log_analytics ? module.log_analytics[0].workspace_id : null
  allowed_subnet_ids         = var.deploy_networking ? [module.networking[0].subnet_ids["ml"]] : []
  tags                       = local.common_tags

  depends_on = [
    module.key_vault,
    module.storage,
    module.application_insights,
    module.container_registry,
    module.networking,
    module.log_analytics
  ]
}

###############################################################################
# MODULE: AZURE COGNITIVE SERVICES (AI Services)
# Deploys Azure AI multi-service account for vision, language, speech, and
# decision AI capabilities. Custom subdomain for private endpoint FQDN.
###############################################################################
module "cognitive_services" {
  source = "./modules/cognitive_services"

  count = var.deploy_cognitive_services ? 1 : 0

  name                       = local.names.cognitive_services
  resource_group_name        = module.resource_group.name
  location                   = var.location
  sku_name                   = var.cognitive_services_sku
  log_analytics_workspace_id = var.deploy_log_analytics ? module.log_analytics[0].workspace_id : null
  allowed_subnet_ids         = var.deploy_networking ? [module.networking[0].subnet_ids["ai"]] : []
  tags                       = local.common_tags

  depends_on = [module.networking, module.log_analytics]
}

###############################################################################
# MODULE: AZURE OPENAI SERVICE
# Deploys Azure OpenAI with model deployments (GPT-4, text-embedding, etc.)
# Restricted to regions supporting OpenAI: eastus, eastus2, canadaeast.
# Content filtering and responsible AI policies enforced by default.
###############################################################################
module "openai" {
  source = "./modules/openai"

  count = var.deploy_openai ? 1 : 0

  name                       = local.names.openai_service
  resource_group_name        = module.resource_group.name
  location                   = var.openai_location # OpenAI has limited regional availability
  sku_name                   = "S0"
  model_deployments          = var.openai_model_deployments
  log_analytics_workspace_id = var.deploy_log_analytics ? module.log_analytics[0].workspace_id : null
  allowed_subnet_ids         = var.deploy_networking ? [module.networking[0].subnet_ids["ai"]] : []
  tags                       = local.common_tags

  depends_on = [module.networking, module.log_analytics]
}

###############################################################################
# MODULE: PRIVATE ENDPOINTS
# Creates private endpoints for all deployed services ensuring no public
# internet exposure. DNS A records registered in the appropriate private zones.
# NOTE: Private DNS zones are hosted in the hub subscription and must be linked
#       to this spoke VNET separately (see scripts\setup-peering.ps1 notes).
###############################################################################
module "private_endpoints" {
  source = "./modules/private_endpoints"

  count = var.deploy_private_endpoints && var.deploy_networking ? 1 : 0

  resource_group_name = module.resource_group.name
  location            = var.location
  subnet_id           = module.networking[0].subnet_ids["private-endpoints"]

  # Conditionally pass resource IDs only for deployed services
  key_vault_id             = var.deploy_key_vault ? module.key_vault[0].id : null
  storage_account_id       = var.deploy_storage ? module.storage[0].id : null
  container_registry_id    = var.deploy_container_registry ? module.container_registry[0].id : null
  machine_learning_id      = var.deploy_machine_learning ? module.machine_learning[0].id : null
  cognitive_services_id    = var.deploy_cognitive_services ? module.cognitive_services[0].id : null
  openai_id                = var.deploy_openai ? module.openai[0].id : null
  log_analytics_id         = var.deploy_log_analytics ? module.log_analytics[0].workspace_id : null

  tags = local.common_tags

  depends_on = [
    module.networking,
    module.key_vault,
    module.storage,
    module.container_registry,
    module.machine_learning,
    module.cognitive_services,
    module.openai,
    module.log_analytics
  ]
}

###############################################################################
# MODULE: RBAC
# Assigns Azure RBAC roles to service principals and managed identities.
# Follows least-privilege principle. See docs/roles.md for full role matrix.
###############################################################################
module "rbac" {
  source = "./modules/rbac"

  count = var.deploy_rbac ? 1 : 0

  resource_group_id          = module.resource_group.id
  machine_learning_id        = var.deploy_machine_learning ? module.machine_learning[0].id : null
  storage_account_id         = var.deploy_storage ? module.storage[0].id : null
  key_vault_id               = var.deploy_key_vault ? module.key_vault[0].id : null
  openai_id                  = var.deploy_openai ? module.openai[0].id : null
  data_scientist_group_id    = var.data_scientist_group_id
  ml_engineer_group_id       = var.ml_engineer_group_id
  data_engineer_group_id     = var.data_engineer_group_id
  ai_app_developer_group_id  = var.ai_app_developer_group_id
  platform_admin_group_id    = var.platform_admin_group_id

  depends_on = [
    module.machine_learning,
    module.storage,
    module.key_vault,
    module.openai
  ]
}
