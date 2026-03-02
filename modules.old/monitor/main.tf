###############################################################################
# MODULE: AZURE MONITOR
# Action groups, metric alerts, and log alert rules for the AI Landing Zone.
###############################################################################

# ─────────────────────────────────────────────────────────────────────────────
# ACTION GROUP: Platform Team Notifications
# Alert emails routed to platform team and on-call when thresholds breached.
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_monitor_action_group" "platform" {
  name                = "ag-platform-alerts"
  resource_group_name = var.resource_group_name
  short_name          = "PlatformOps"

  dynamic "email_receiver" {
    for_each = var.alert_email_addresses
    content {
      name          = "email-${index(var.alert_email_addresses, email_receiver.value)}"
      email_address = email_receiver.value
    }
  }

  tags = var.tags
}

# ─────────────────────────────────────────────────────────────────────────────
# ALERT: High Log Analytics Ingestion
# Triggers if daily ingestion exceeds expected baseline (potential runaway logging).
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_monitor_metric_alert" "law_ingestion" {
  name                = "alert-law-high-ingestion"
  resource_group_name = var.resource_group_name
  scopes              = [var.log_analytics_workspace_id]
  description         = "Alert when Log Analytics daily ingestion is unusually high"
  severity            = 2  # Warning
  frequency           = "PT1H"
  window_size         = "PT6H"

  criteria {
    metric_namespace = "Microsoft.OperationalInsights/workspaces"
    metric_name      = "DataIngested"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 50000  # 50 GB - adjust based on expected workload
  }

  action {
    action_group_id = azurerm_monitor_action_group.platform.id
  }

  tags = var.tags
}

# ─────────────────────────────────────────────────────────────────────────────
# ALERT RULE: Key Vault Availability
# Critical alert if Key Vault availability drops below 100%.
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: Add scope = key_vault_id after retrieving from module output.
# Implemented here as a pattern - wire to actual KV resource in calling module.

# ─────────────────────────────────────────────────────────────────────────────
# DIAGNOSTIC SETTINGS: Activity Log -> Log Analytics
# Captures all subscription-level events for audit and security.
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "diag-activity-log"
  target_resource_id         = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "Administrative" }   # Resource create/update/delete
  enabled_log { category = "Security" }         # Security alerts
  enabled_log { category = "ServiceHealth" }    # Service outages
  enabled_log { category = "Alert" }            # Azure alerts fired
  enabled_log { category = "Recommendation" }  # Advisor recommendations
  enabled_log { category = "Policy" }           # Policy evaluation results
  enabled_log { category = "Autoscale" }        # Autoscale events
  enabled_log { category = "ResourceHealth" }   # Resource health changes
}

data "azurerm_client_config" "current" {}
