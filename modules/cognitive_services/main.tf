###############################################################################
# MODULE: COGNITIVE SERVICES (Azure AI Services)
# Multi-service AI account for Vision, Language, Speech, and Decision APIs.
###############################################################################

resource "azurerm_cognitive_account" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "CognitiveServices" # Multi-service
  sku_name            = var.sku_name

  public_network_access_enabled = false
  custom_subdomain_name         = var.name

  network_acls {
    default_action             = "Deny"
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "ais" {
  count = var.log_analytics_workspace_id != null ? 1 : 0

  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_cognitive_account.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "Audit"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
