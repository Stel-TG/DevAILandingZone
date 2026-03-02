output "id" {
  value = azurerm_linux_virtual_machine.build.id
}
output "name" {
  value = azurerm_linux_virtual_machine.build.name
}
output "private_ip_address" {
  value = azurerm_network_interface.build.private_ip_address
}