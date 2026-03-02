output "id" {
  value = azurerm_application_gateway.this.id
}
output "name" {
  value = azurerm_application_gateway.this.name
}
output "public_ip" {
  value = azurerm_public_ip.app_gateway.ip_address
}
output "waf_policy_id" {
  value = azurerm_web_application_firewall_policy.this.id
}