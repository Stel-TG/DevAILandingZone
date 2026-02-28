###############################################################################
# MODULE: API MANAGEMENT (APIM)
#
# Deploys Azure API Management in the dedicated API Management subnet.
# APIM acts as the internal gateway between Application Gateway and the
# Container App microservices, providing:
#   - API rate limiting and quotas for AI model endpoints
#   - JWT validation (Entra ID tokens)
#   - Backend circuit breakers for OpenAI throttling
#   - Centralised API versioning for all GenAI app microservices
#   - Caching policies to reduce redundant AI calls
#
# Network mode: Internal VNet (no public management endpoint).
# All traffic routes through Application Gateway -> APIM -> Container Apps.
###############################################################################

resource "azurerm_api_management" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name   # "Developer_1" for non-prod; "Premium_1" for prod

  # VNet integration — internal mode: no public IP, all traffic via VNET
  virtual_network_type = "Internal"

  virtual_network_configuration {
    subnet_id = var.subnet_id   # api-management subnet
  }

  # System-assigned identity for policy expressions (backend auth, KV reads)
  identity {
    type = "SystemAssigned"
  }

  # Zones for Premium SKU production HA
  zones = var.sku_name == "Premium_1" ? ["1", "2", "3"] : []

  tags = var.tags
}

# -----------------------------------------------------------------------------
# PRIVATE ENDPOINT: APIM Management Plane
# For management API calls (ARM operations) in fully private deployments.
# DNS zone: privatelink.azure-api.net
# -----------------------------------------------------------------------------
resource "azurerm_private_endpoint" "apim" {
  count               = var.deploy_private_endpoint ? 1 : 0
  name                = var.pe_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = "psc-apim-${var.name}"
    private_connection_resource_id = azurerm_api_management.this.id
    is_manual_connection           = false
    subresource_names              = ["Gateway"]
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# DIAGNOSTIC SETTINGS: APIM
# GatewayLogs contains per-request latency, status codes, and backend errors.
# Essential for monitoring AI endpoint call patterns and quota usage.
# -----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "apim" {
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_api_management.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "GatewayLogs" }
  enabled_log { category = "WebSocketConnectionLogs" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
