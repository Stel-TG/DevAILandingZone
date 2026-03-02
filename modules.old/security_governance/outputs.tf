output "network_watcher_id" { value = azurerm_network_watcher.this.id }
output "purview_id"         { value = var.deploy_purview ? azurerm_purview_account.this[0].id : null }
output "purview_endpoint"   { value = var.deploy_purview ? azurerm_purview_account.this[0].atlas_endpoint : null }
