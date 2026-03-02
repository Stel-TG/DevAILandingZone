output "id" {
  value = azurerm_container_app_environment.this.id
}
output "name" {
  value = azurerm_container_app_environment.this.name
}
output "default_domain" {
  value = azurerm_container_app_environment.this.default_domain
}
output "static_ip_address" {
  value = azurerm_container_app_environment.this.static_ip_address
}
output "frontend_app_id" {
  value = azurerm_container_app.frontend.id
}
output "orchestrator_app_id" {
  value = azurerm_container_app.orchestrator.id
}
output "sk_app_id" {
  value = azurerm_container_app.sk.id
}
output "mcp_app_id" {
  value = azurerm_container_app.mcp.id
}
output "ingestion_app_id" {
  value = azurerm_container_app.ingestion.id
}