###############################################################################
# MODULE: CONTAINER REGISTRY
# Premium SKU required for private endpoints, geo-replication, and content trust.
###############################################################################

resource "azurerm_container_registry" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = false

  public_network_access_enabled = false

  network_rule_set {
    default_action = "Deny"
    virtual_network {
      action    = "Allow"
      subnet_id = length(var.allowed_subnet_ids) > 0 ? var.allowed_subnet_ids[0] : null
    }
  }

  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "acr" {
  count = var.log_analytics_workspace_id != null ? 1 : 0

  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_container_registry.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }
  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
