output "id" {
  value = azurerm_linux_virtual_machine.jumpbox.id
}
output "name" {
  value = azurerm_linux_virtual_machine.jumpbox.name
}
output "private_ip_address" {
  value = azurerm_network_interface.jumpbox.private_ip_address
}
output "principal_id" {
  value = azurerm_linux_virtual_machine.jumpbox.identity[0].principal_id
}