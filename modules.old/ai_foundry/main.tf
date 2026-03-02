###############################################################################
# MODULE: AZURE AI FOUNDRY
#
# Deploys the full AI Foundry standard setup from the reference architecture:
#
#   AI Foundry Hub (Azure AI Hub / azurerm_ai_foundry)
#   └── AI Foundry Project
#       ├── AI Services endpoints       (linked to Cognitive Services account)
#       ├── Foundry models              (model catalog deployments)
#       ├── Connections                 (to Storage, Search, OpenAI, etc.)
#       └── Foundry Agent Service       (agentic AI runtime in agent subnet)
#
# Dependencies wired in via variables:
#   - Storage Account  (for artifacts and dataset storage)
#   - Key Vault        (for secrets used by agents and connections)
#   - AI Search        (vector index for RAG / grounding)
#   - Cosmos DB        (agent memory / session state)
#   - Cognitive Services account (AI Services endpoints)
#   - Managed Identity (system-assigned + user-assigned passed in)
#
# Network:
#   - AI Foundry hub itself gets a private endpoint in the PE subnet
#   - Foundry Agent Service runs within the dedicated ai-foundry-agent subnet
#   - Public network access disabled; all traffic via private endpoints
###############################################################################

# -----------------------------------------------------------------------------
# USER-ASSIGNED MANAGED IDENTITY for AI Foundry
# Used by the hub and project to access linked resources without secrets.
# The same identity is passed to connections so they can authenticate to
# Storage, AI Search, and Cosmos DB using RBAC instead of keys.
# -----------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "foundry" {
  name                = var.managed_identity_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# -----------------------------------------------------------------------------
# AI FOUNDRY HUB
# The hub is the top-level Azure AI Foundry resource. It acts as a shared
# workspace for projects, connections, compute, and governance settings.
#
# Backed by an Azure Machine Learning workspace resource under the hood;
# the azurerm_ai_foundry resource type (preview) wraps this cleanly.
# Until the dedicated resource type is GA, provision as an AML workspace
# with kind="Hub" via AzAPI or azurerm_machine_learning_workspace with
# the appropriate workspace kind flag.
# -----------------------------------------------------------------------------
resource "azurerm_machine_learning_workspace" "foundry_hub" {
  # PSEUDO CODE:
  # Replace with azurerm_ai_foundry once provider GA (currently in preview).
  # For now this represents the AI Foundry Hub as an AML workspace with
  # AI Hub kind. The actual resource type becomes available in AzureRM >= 3.110.
  #
  # resource "azurerm_ai_foundry" "hub" { ... }   <-- target resource type
  #
  name                = var.hub_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = var.sku                      # "Basic"

  # Link all required AI Foundry hub dependencies
  storage_account_id      = var.storage_account_id
  key_vault_id            = var.key_vault_id
  application_insights_id = var.application_insights_id

  # System-assigned identity for cross-service access
  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.foundry.id]
  }

  # Disable all public network access — all traffic via private endpoints
  public_network_access_enabled = false

  tags = var.tags
}

# -----------------------------------------------------------------------------
# AI FOUNDRY PROJECT
# Projects are logical scopes within a Foundry Hub. Each project can have
# its own models, connections, agents, and access controls.
#
# In the reference architecture this is shown as "AI Foundry Project" containing:
#   - AI Services endpoints
#   - Foundry models
#   - Connections
#   - Foundry Agent Service
# -----------------------------------------------------------------------------
resource "azurerm_machine_learning_workspace" "foundry_project" {
  # PSEUDO CODE:
  # Replace with azurerm_ai_foundry_project when GA.
  # Projects are child resources of the hub and share its compute/storage.
  #
  name                = var.project_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = var.sku

  # Projects inherit storage and KV from their hub workspace
  storage_account_id      = var.storage_account_id
  key_vault_id            = var.key_vault_id
  application_insights_id = var.application_insights_id

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.foundry.id]
  }

  public_network_access_enabled = false

  tags = merge(var.tags, { "ai-foundry-hub" = var.hub_name })
}

# -----------------------------------------------------------------------------
# AI FOUNDRY CONNECTIONS
# Connections allow the AI Foundry Project to securely access external services.
# Each connection stores credentials in Key Vault and uses managed identity.
#
# Connections shown in reference architecture:
#   - Azure OpenAI endpoint
#   - Azure AI Search (for vector retrieval)
#   - Azure Storage (for datasets)
#   - Cosmos DB (for grounding data)
# -----------------------------------------------------------------------------

# Connection: Azure OpenAI Service
resource "azurerm_machine_learning_workspace_connection" "openai" {
  count = var.openai_endpoint != "" ? 1 : 0

  name         = "conn-openai-${var.project_name}"
  workspace_id = azurerm_machine_learning_workspace.foundry_project.id
  category     = "AzureOpenAI"
  target       = var.openai_endpoint   # e.g. https://oai-xxx.openai.azure.com/

  identity_configuration {
    type = "managed_identity"
  }

  # Metadata passed to agents using this connection
  metadata = {
    "ApiType"         = "Azure"
    "ResourceId"      = var.openai_resource_id
    "ApiVersion"      = "2024-02-01"
  }
}

# Connection: Azure AI Search (vector index for RAG grounding)
resource "azurerm_machine_learning_workspace_connection" "ai_search" {
  count = var.ai_search_endpoint != "" ? 1 : 0

  name         = "conn-search-${var.project_name}"
  workspace_id = azurerm_machine_learning_workspace.foundry_project.id
  category     = "CognitiveSearch"
  target       = var.ai_search_endpoint  # e.g. https://srch-xxx.search.windows.net

  identity_configuration {
    type = "managed_identity"
  }
}

# Connection: Cosmos DB (for agent memory / session grounding)
resource "azurerm_machine_learning_workspace_connection" "cosmos" {
  count = var.cosmos_db_endpoint != "" ? 1 : 0

  name         = "conn-cosmos-${var.project_name}"
  workspace_id = azurerm_machine_learning_workspace.foundry_project.id
  category     = "CosmosDb"
  target       = var.cosmos_db_endpoint

  identity_configuration {
    type = "managed_identity"
  }
}

# -----------------------------------------------------------------------------
# AI FOUNDRY AGENT SERVICE
# The Foundry Agent Service (shown as "Foundry Agent Service" in the project)
# is a managed service that runs agentic AI workflows within the AI Foundry
# Agent subnet. It orchestrates tool calls, memory, and model invocations.
#
# Deployed as a Container App or managed compute in the ai-foundry-agent subnet.
# In the reference architecture it appears as a service within the VNET.
# -----------------------------------------------------------------------------
resource "azurerm_container_app" "foundry_agent_service" {
  name                         = var.agent_service_name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  # Use workload profile for VNet integration in the ai-foundry-agent subnet
  workload_profile_name = "Dedicated-D4"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.foundry.id]
  }

  template {
    container {
      name   = "foundry-agent"
      image  = var.agent_service_image  # AI Foundry Agent Service container image
      cpu    = 2.0
      memory = "4Gi"

      # Environment variables wire the agent service to Foundry project and tools
      env {
        name  = "AZURE_AI_FOUNDRY_PROJECT_ID"
        value = azurerm_machine_learning_workspace.foundry_project.id
      }
      env {
        name  = "AZURE_OPENAI_ENDPOINT"
        value = var.openai_endpoint
      }
      env {
        name  = "AZURE_SEARCH_ENDPOINT"
        value = var.ai_search_endpoint
      }
      env {
        name  = "AZURE_COSMOS_ENDPOINT"
        value = var.cosmos_db_endpoint
      }
    }

    min_replicas = 1
    max_replicas = 10
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# PRIVATE ENDPOINT: AI Foundry Hub
# Restricts all access to the AI Foundry to the spoke VNET only.
# -----------------------------------------------------------------------------
resource "azurerm_private_endpoint" "foundry_hub" {
  name                = var.pe_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = "psc-aif-${var.hub_name}"
    private_connection_resource_id = azurerm_machine_learning_workspace.foundry_hub.id
    is_manual_connection           = false
    subresource_names              = ["amlworkspace"]
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# DIAGNOSTIC SETTINGS: AI Foundry Hub
# Forward all hub activity and metrics to the central Log Analytics Workspace.
# -----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "foundry_hub" {
  name                       = "diag-${var.hub_name}"
  target_resource_id         = azurerm_machine_learning_workspace.foundry_hub.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "AmlComputeClusterEvent" }
  enabled_log { category = "AmlRunStatusChangedEvent" }
  enabled_log { category = "AmlEnvironmentEvent" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# -----------------------------------------------------------------------------
# RBAC: Foundry Managed Identity -> Required service roles
# Grants the foundry identity least-privilege access to all linked services.
# -----------------------------------------------------------------------------
resource "azurerm_role_assignment" "foundry_storage_contributor" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.foundry.principal_id
  description          = "AI Foundry managed identity read/write access to linked storage"
}

resource "azurerm_role_assignment" "foundry_search_index_reader" {
  count                = var.ai_search_id != "" ? 1 : 0
  scope                = var.ai_search_id
  role_definition_name = "Search Index Data Reader"
  principal_id         = azurerm_user_assigned_identity.foundry.principal_id
  description          = "AI Foundry managed identity read access to AI Search indexes"
}

resource "azurerm_role_assignment" "foundry_search_service_contributor" {
  count                = var.ai_search_id != "" ? 1 : 0
  scope                = var.ai_search_id
  role_definition_name = "Search Service Contributor"
  principal_id         = azurerm_user_assigned_identity.foundry.principal_id
  description          = "AI Foundry managed identity manage Search indexes"
}

resource "azurerm_role_assignment" "foundry_kv_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.foundry.principal_id
  description          = "AI Foundry managed identity read secrets from Key Vault"
}

resource "azurerm_role_assignment" "foundry_openai_user" {
  count                = var.openai_resource_id != "" ? 1 : 0
  scope                = var.openai_resource_id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.foundry.principal_id
  description          = "AI Foundry managed identity invoke OpenAI model endpoints"
}
