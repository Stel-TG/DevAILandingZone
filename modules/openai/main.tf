###############################################################################
# MODULE: AZURE OPENAI SERVICE
# Deploys Azure OpenAI with configurable model deployments.
# Public access disabled; private endpoint required.
###############################################################################

resource "azurerm_cognitive_account" "openai" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "OpenAI"
  sku_name            = var.sku_name

  public_network_access_enabled = false
  custom_subdomain_name         = var.name

  network_acls {
    default_action = "Deny"
    bypass         = "None"
  }

  tags = var.tags
}

resource "azurerm_cognitive_deployment" "models" {
  for_each = var.model_deployments

  name                 = each.key
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = each.value.model_name
    version = each.value.model_version
  }

  scale {
    type     = "Standard"
    capacity = each.value.capacity
  }
}

resource "azurerm_monitor_diagnostic_setting" "openai" {
  count = var.log_analytics_workspace_id != null ? 1 : 0

  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_cognitive_account.openai.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "Audit"
  }
  enabled_log {
    category = "RequestResponse"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}