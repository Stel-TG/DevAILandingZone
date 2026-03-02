###############################################################################
# MODULE: AZURE AI SEARCH
#
# Deploys Azure AI Search for vector indexing and RAG grounding.
# Used by both the AI Foundry Agent Service (for grounding with Bing and
# enterprise knowledge) and GenAI app microservices (orchestrator, ingestion).
#
# Key configuration:
#   - Standard SKU minimum for semantic ranking capability
#   - Private endpoint in the private-endpoints subnet
#   - System-assigned identity for RBAC-based blob indexer access
#   - Diagnostic settings to Log Analytics
#   - Semantic search enabled for hybrid retrieval
###############################################################################

resource "azurerm_search_service" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku                    # "standard" minimum for semantic search
  replica_count       = var.replica_count          # >= 2 for production HA
  partition_count     = var.partition_count        # 1 default; increase for larger indexes

  # Disable public access — private endpoint only
  public_network_access_enabled = false

  # Use local RBAC (Entra ID) for data plane operations; no admin keys needed
  local_authentication_enabled   = false    # Force AAD-only data plane auth
  authentication_failure_mode    = "http403"

  # System-assigned identity for indexer to access Storage/Cosmos without keys
  identity {
    type = "SystemAssigned"
  }

  # Semantic search: enables L2 reranking for RAG quality improvement
  semantic_search_sku = "standard"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# PRIVATE ENDPOINT: AI Search
# All search API calls routed via the private-endpoints subnet.
# DNS resolution requires a private DNS zone linked to the spoke VNET:
#   privatelink.search.windows.net
# -----------------------------------------------------------------------------
resource "azurerm_private_endpoint" "search" {
  name                = var.pe_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = "psc-srch-${var.name}"
    private_connection_resource_id = azurerm_search_service.this.id
    is_manual_connection           = false
    subresource_names              = ["searchService"]
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# DIAGNOSTIC SETTINGS: AI Search
# Captures query latency, indexing errors, and throttling events.
# -----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "search" {
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_search_service.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "OperationLogs" }  # Query and indexing operations

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
