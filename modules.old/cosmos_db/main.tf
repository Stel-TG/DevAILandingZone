###############################################################################
# MODULE: AZURE COSMOS DB
#
# Deploys Cosmos DB (NoSQL / GlobalDocumentDB) for:
#   1. AI Foundry Agent Service — agent memory, session state, conversation history
#   2. GenAI App Dependencies   — application config and result storage
#
# Key configuration:
#   - NoSQL API (GlobalDocumentDB) for document + vector storage
#   - Private endpoint in the private-endpoints subnet
#   - System-assigned managed identity (no key-based auth)
#   - Serverless or provisioned throughput per database (configurable)
#   - Backup policy: continuous for production (point-in-time restore)
#   - Diagnostic settings to Log Analytics
###############################################################################

resource "azurerm_cosmosdb_account" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = var.offer_type      # "Standard"
  kind                = var.kind            # "GlobalDocumentDB" for NoSQL

  # Disable key-based auth; use RBAC / managed identity only
  local_authentication_disabled = true

  # Disable public access — private endpoint only
  public_network_access_enabled = false

  # Network: only allow traffic from private endpoints
  is_virtual_network_filter_enabled = true

  # Consistency policy for agent state — Session provides good balance
  consistency_policy {
    consistency_level       = var.consistency_level  # "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  # Single-region write (primary region = landing zone region)
  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = true  # Zone-redundant for production HA
  }

  # Continuous backup enables point-in-time restore for agent state recovery
  backup {
    type               = "Continuous"
    tier               = "Continuous7Days"  # 7-day PITR window
  }

  # System-assigned identity for RBAC access from Foundry and Container Apps
  identity {
    type = "SystemAssigned"
  }

  # Analytical store for Synapse link (useful for AI training data pipelines)
  analytical_storage_enabled = false  # Enable if Synapse integration needed

  tags = var.tags
}

# -----------------------------------------------------------------------------
# DATABASES AND CONTAINERS
# Created from the cosmos_db_databases variable map.
# Each database hosts containers for specific agent/app workloads.
# -----------------------------------------------------------------------------
resource "azurerm_cosmosdb_sql_database" "databases" {
  for_each = var.databases

  name                = each.key
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name

  # Throughput at database level (shared across containers)
  # Use autoscale for variable GenAI workloads
  autoscale_settings {
    max_throughput = each.value.throughput  # Min 400, max 1000000
  }
}

resource "azurerm_cosmosdb_sql_container" "containers" {
  # Flatten databases x containers into a single map
  for_each = {
    for item in flatten([
      for db_name, db_config in var.databases : [
        for container in db_config.containers : {
          key        = "${db_name}__${container}"
          db_name    = db_name
          container  = container
        }
      ]
    ]) : item.key => item
  }

  name                = each.value.container
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = azurerm_cosmosdb_sql_database.databases[each.value.db_name].name
  partition_key_path  = "/sessionId"  # Default partition key for agent sessions

  # Enable vector indexing for semantic similarity search in agent memory
  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/\"_etag\"/?"
    }
  }

  # TTL for agent session data (-1 = disabled; set seconds for auto-expiry)
  default_ttl = -1
}

# -----------------------------------------------------------------------------
# PRIVATE ENDPOINT: Cosmos DB
# Routes all data plane and control plane traffic via spoke VNET.
# DNS zone: privatelink.documents.azure.com
# -----------------------------------------------------------------------------
resource "azurerm_private_endpoint" "cosmos" {
  name                = var.pe_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = "psc-cosmos-${var.name}"
    private_connection_resource_id = azurerm_cosmosdb_account.this.id
    is_manual_connection           = false
    subresource_names              = ["Sql"]  # NoSQL / Core SQL API
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# DIAGNOSTIC SETTINGS: Cosmos DB
# Captures data plane requests, throttling, and partition advisor logs.
# Essential for tuning throughput and partition key selection.
# -----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "cosmos" {
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_cosmosdb_account.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "DataPlaneRequests" }
  enabled_log { category = "QueryRuntimeStatistics" }
  enabled_log { category = "PartitionKeyStatistics" }
  enabled_log { category = "ControlPlaneRequests" }

  metric {
    category = "Requests"
    enabled  = true
  }
}
