###############################################################################
# MODULE: KEY VAULT
# RBAC authorization model, soft-delete + purge protection, private endpoint.
###############################################################################

resource "azurerm_key_vault" "this" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name  # "standard" or "premium"

  # Security hardening
  soft_delete_retention_days = var.soft_delete_retention_days  # 90
  purge_protection_enabled   = var.purge_protection_enabled    # true
  enable_rbac_authorization  = var.enable_rbac_authorization   # true (prefer over access policies)

  # Network ACLs: deny all public access; allow only private endpoint traffic
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"  # Allow trusted Azure services (AML, etc.)
    ip_rules                   = []               # No public IP exceptions
    virtual_network_subnet_ids = []               # No service endpoint exceptions (private EP only)
  }

  tags = var.tags
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "kv" {
  name                = "pe-kv-${var.key_vault_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-kv-${var.key_vault_name}"
    private_connection_resource_id = azurerm_key_vault.this.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_dns_zone_id != "" ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = [var.private_dns_zone_id]
    }
  }

  tags = var.tags
}

# Diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "diag-${var.key_vault_name}"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "AuditEvent" }      # All read/write operations on secrets/keys
  enabled_log { category = "AzurePolicyEvaluationDetails" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
