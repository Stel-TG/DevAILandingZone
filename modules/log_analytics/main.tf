###############################################################################
# MODULE: LOG ANALYTICS WORKSPACE
# Provisions a workspace-based Log Analytics workspace for centralized log
# aggregation from all Azure platform and application resources.
###############################################################################

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  retention_in_days   = var.retention_days

  # Disable local authentication to enforce AAD-based access
  local_authentication_disabled = true

  tags = var.tags
}

# -----------------------------------------------------------------------------
# SOLUTIONS
# Add optional OMS solutions for enhanced monitoring capabilities.
# SecurityCenter and ContainerInsights are common for AI workloads.
# -----------------------------------------------------------------------------
resource "azurerm_log_analytics_solution" "security_center" {
  count = var.enable_security_center_solution ? 1 : 0

  solution_name         = "SecurityCenterFree"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.this.id
  workspace_name        = azurerm_log_analytics_workspace.this.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityCenterFree"
  }

  tags = var.tags
}

resource "azurerm_log_analytics_solution" "container_insights" {
  count = var.enable_container_insights_solution ? 1 : 0

  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.this.id
  workspace_name        = azurerm_log_analytics_workspace.this.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  tags = var.tags
}
