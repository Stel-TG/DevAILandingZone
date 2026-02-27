###############################################################################
# MODULE: APPLICATION INSIGHTS
# Workspace-based Application Insights linked to Log Analytics for unified
# telemetry. Used by AML for experiment tracking via MLflow integration.
###############################################################################

resource "azurerm_application_insights" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = var.application_type
  workspace_id        = var.log_analytics_workspace_id # Workspace-based mode

  # Disable internet ingestion; data flows via Log Analytics workspace
  internet_ingestion_enabled = false
  internet_query_enabled     = false

  tags = var.tags
}
