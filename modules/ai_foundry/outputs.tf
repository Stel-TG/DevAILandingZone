output "hub_id" {
  value = azurerm_machine_learning_workspace.foundry_hub.id
}
output "hub_name" {
  value = azurerm_machine_learning_workspace.foundry_hub.name
}
output "project_id" {
  value = azurerm_machine_learning_workspace.foundry_project.id
}
output "project_name" {
  value = azurerm_machine_learning_workspace.foundry_project.name
}
output "managed_identity_id" {
  value = azurerm_user_assigned_identity.foundry.id
}
output "managed_identity_principal" {
  value = azurerm_user_assigned_identity.foundry.principal_id
}
output "agent_service_fqdn" {
  value = azurerm_container_app.foundry_agent_service.ingress[0].fqdn
}