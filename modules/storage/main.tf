###############################################################################
# MODULE: STORAGE ACCOUNT
# ADLS Gen2-capable storage for ML datasets, model artifacts, and outputs.
# Public access disabled; private endpoint required.
###############################################################################

resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  is_hns_enabled           = var.is_hns_enabled # ADLS Gen2

  min_tls_version                  = "TLS1_2"
  public_network_access_enabled    = false
  allow_nested_items_to_be_public  = false
  shared_access_key_enabled        = true # Required for AML workspace

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices", "Logging", "Metrics"]
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  blob_properties {
    delete_retention_policy { days = 30 }
    versioning_enabled = true
    change_feed_enabled = true # Audit trail for blob changes
  }

  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  count = var.log_analytics_workspace_id != null ? 1 : 0

  name                       = "diag-${var.name}"
  target_resource_id         = "${azurerm_storage_account.this.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "StorageRead" }
  enabled_log { category = "StorageWrite" }
  enabled_log { category = "StorageDelete" }
  metric { category = "AllMetrics"; enabled = true }
}
