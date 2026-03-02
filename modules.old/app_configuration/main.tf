###############################################################################
# MODULE: AZURE APP CONFIGURATION
#
# Centralised feature flags and app settings store for all GenAI microservices.
# Container Apps reference this via the Azure App Configuration provider or
# environment variable injection at startup.
#
# Key configuration:
#   - Standard SKU for private link and geo-replication support
#   - Soft-delete enabled (7-day retention)
#   - Private endpoint in the private-endpoints subnet
#   - Local authentication disabled — RBAC / managed identity only
#   - Diagnostic settings to Log Analytics
###############################################################################

resource "azurerm_app_configuration" "this" {
  name                       = var.name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  sku                        = var.sku   # "standard" required for private link

  # Disable key-based access; all reads via managed identity (App Configuration Data Reader)
  local_authentication_enabled  = false

  # Soft-delete protects against accidental config loss
  soft_delete_retention_days    = 7

  # Public access disabled — private endpoint only
  public_network_access         = "Disabled"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# PRIVATE ENDPOINT: App Configuration
# DNS zone: privatelink.azconfig.io
# -----------------------------------------------------------------------------
resource "azurerm_private_endpoint" "app_config" {
  name                = var.pe_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = "psc-appcs-${var.name}"
    private_connection_resource_id = azurerm_app_configuration.this.id
    is_manual_connection           = false
    subresource_names              = ["configurationStores"]
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# DIAGNOSTIC SETTINGS: App Configuration
# -----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "app_config" {
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_app_configuration.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "Audit" }
  enabled_log { category = "HttpRequest" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# -----------------------------------------------------------------------------
# RBAC: Apps managed identity -> App Configuration Data Reader
# Allows microservices to read feature flags and settings without keys.
# -----------------------------------------------------------------------------
resource "azurerm_role_assignment" "apps_config_reader" {
  count                = var.apps_identity_principal_id != "" ? 1 : 0
  scope                = azurerm_app_configuration.this.id
  role_definition_name = "App Configuration Data Reader"
  principal_id         = var.apps_identity_principal_id
  description          = "GenAI microservices read feature flags and config"
}
