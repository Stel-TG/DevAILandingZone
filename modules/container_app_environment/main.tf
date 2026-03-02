###############################################################################
# MODULE: CONTAINER APP ENVIRONMENT + GENAI MICROSERVICES
#
# Deploys the Container App Environment (CAE) that hosts the GenAI application
# microservices shown in the reference architecture:
#
#   Container App Environment (VNet-integrated, workload profiles)
#   ├── ca-frontend     – Public-facing UI / API gateway (Dapr-enabled)
#   ├── ca-orchestrator – Agent orchestration logic (Semantic Kernel / LangChain)
#   ├── ca-sk           – Semantic Kernel plugin host
#   ├── ca-mcp          – Model Context Protocol server
#   └── ca-ingestion    – Data ingestion pipeline (RAG indexing)
#
# Network:
#   - CAE is VNet-integrated into the container-app-environment subnet
#   - Private endpoint registered in private-endpoints subnet
#   - Internal-only load balancer (no public ingress on CAE itself)
#   - Application Gateway / WAF provides the public ingress layer
#
# Dapr:
#   - Enabled on all microservice apps for service-to-service invocation,
#     pub/sub, state store binding to Cosmos DB, and secret management via KV.
###############################################################################

# -----------------------------------------------------------------------------
# CONTAINER APP ENVIRONMENT
# Workload profiles mode enables dedicated resources and VNet integration.
# -----------------------------------------------------------------------------
resource "azurerm_container_app_environment" "this" {
  name                               = var.name
  location                           = var.location
  resource_group_name                = var.resource_group_name
  log_analytics_workspace_id         = var.log_analytics_workspace_id

  # VNet integration — all egress routed through the CAE subnet
  infrastructure_subnet_id           = var.subnet_id
  internal_load_balancer_enabled     = true   # No direct public access; WAF/APIM fronts it

  # Workload profiles enable Dedicated SKU for production throughput
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 10
  }

  workload_profile {
    name                  = "Dedicated-D4"
    workload_profile_type = "D4"
    minimum_count         = 1
    maximum_count         = 5
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# MICROSERVICE: FRONTEND
# Public-facing container app (Dapr-enabled) – REST API or web UI entry point.
# Exposed via Application Gateway ingress; internal CAE routing via Dapr.
# -----------------------------------------------------------------------------
resource "azurerm_container_app" "frontend" {
  name                         = var.frontend_app_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.apps_identity_id]
  }

  dapr {
    app_id       = "frontend"
    app_port     = 8080
    app_protocol = "http"
  }

  ingress {
    external_enabled = false   # Exposed only via App Gateway — no direct public ingress
    target_port      = 8080
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    container {
      name   = "frontend"
      image  = var.frontend_image   # e.g. acrailzprodcc.azurecr.io/frontend:latest
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "AZURE_CLIENT_ID"
        value = var.apps_identity_client_id
      }
      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = var.app_insights_connection_string
      }
      env {
        name  = "APP_CONFIG_ENDPOINT"
        value = var.app_configuration_endpoint
      }
    }
    min_replicas = 1
    max_replicas = 20
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# MICROSERVICE: ORCHESTRATOR
# Core agent orchestration — coordinates tool calls, model invocations,
# and memory reads/writes. Wires to AI Foundry Project via Dapr bindings.
# -----------------------------------------------------------------------------
resource "azurerm_container_app" "orchestrator" {
  name                         = var.orchestrator_app_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Dedicated-D4"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.apps_identity_id]
  }

  dapr {
    app_id       = "orchestrator"
    app_port     = 8080
    app_protocol = "http"
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    container {
      name   = "orchestrator"
      image  = var.orchestrator_image
      cpu    = 2.0
      memory = "4Gi"

      env {
        name  = "AZURE_CLIENT_ID"
        value = var.apps_identity_client_id
      }
      env {
        name  = "AZURE_OPENAI_ENDPOINT"
        value = var.openai_endpoint
      }
      env {
        name  = "AZURE_AI_SEARCH_ENDPOINT"
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
# MICROSERVICE: SEMANTIC KERNEL (SK) PLUGIN HOST
# Hosts Semantic Kernel plugins / skills used by the orchestrator.
# Isolated so plugins can be independently scaled and updated.
# -----------------------------------------------------------------------------
resource "azurerm_container_app" "sk" {
  name                         = var.sk_app_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.apps_identity_id]
  }

  dapr {
    app_id       = "sk"
    app_port     = 8080
    app_protocol = "http"
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    container {
      name   = "sk"
      image  = var.sk_image
      cpu    = 1.0
      memory = "2Gi"

      env {
        name  = "AZURE_CLIENT_ID"
        value = var.apps_identity_client_id
      }
      env {
        name  = "AZURE_OPENAI_ENDPOINT"
        value = var.openai_endpoint
      }
    }
    min_replicas = 0   # Scale to zero when idle
    max_replicas = 10
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# MICROSERVICE: MODEL CONTEXT PROTOCOL (MCP) SERVER
# Hosts the MCP server that exposes tools and resources to AI models via the
# standardised MCP protocol. Acts as a bridge between agents and external APIs.
# -----------------------------------------------------------------------------
resource "azurerm_container_app" "mcp" {
  name                         = var.mcp_app_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.apps_identity_id]
  }

  dapr {
    app_id       = "mcp"
    app_port     = 8080
    app_protocol = "http"
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    container {
      name   = "mcp"
      image  = var.mcp_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "AZURE_CLIENT_ID"
        value = var.apps_identity_client_id
      }
    }
    min_replicas = 0
    max_replicas = 10
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# MICROSERVICE: INGESTION PIPELINE
# Handles RAG data ingestion: chunking, embedding, and indexing documents
# into AI Search. Triggered by Storage events or message queue.
# -----------------------------------------------------------------------------
resource "azurerm_container_app" "ingestion" {
  name                         = var.ingestion_app_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.apps_identity_id]
  }

  dapr {
    app_id       = "ingestion"
    app_port     = 8080
    app_protocol = "http"
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    container {
      name   = "ingestion"
      image  = var.ingestion_image
      cpu    = 1.0
      memory = "2Gi"

      env {
        name  = "AZURE_CLIENT_ID"
        value = var.apps_identity_client_id
      }
      env {
        name  = "AZURE_STORAGE_ENDPOINT"
        value = var.storage_endpoint
      }
      env {
        name  = "AZURE_SEARCH_ENDPOINT"
        value = var.ai_search_endpoint
      }
      env {
        name  = "AZURE_OPENAI_ENDPOINT"
        value = var.openai_endpoint
      }
    }
    min_replicas = 0
    max_replicas = 5
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# PRIVATE ENDPOINT: Container App Environment
# Routes all CAE management traffic via the private-endpoints subnet.
# DNS zone: privatelink.azurecontainerapps.io
# -----------------------------------------------------------------------------
resource "azurerm_private_endpoint" "cae" {
  name                = var.pe_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = "psc-cae-${var.name}"
    private_connection_resource_id = azurerm_container_app_environment.this.id
    is_manual_connection           = false
    subresource_names              = ["managedEnvironments"]
  }

  tags = var.tags
}
