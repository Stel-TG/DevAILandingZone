output "foundry_identity_id"           { value = azurerm_user_assigned_identity.foundry.id }
output "foundry_identity_principal_id"  { value = azurerm_user_assigned_identity.foundry.principal_id }
output "foundry_identity_client_id"     { value = azurerm_user_assigned_identity.foundry.client_id }

output "apps_identity_id"               { value = azurerm_user_assigned_identity.apps.id }
output "apps_identity_principal_id"     { value = azurerm_user_assigned_identity.apps.principal_id }
output "apps_identity_client_id"        { value = azurerm_user_assigned_identity.apps.client_id }

output "build_identity_id"              { value = azurerm_user_assigned_identity.build.id }
output "build_identity_principal_id"    { value = azurerm_user_assigned_identity.build.principal_id }
output "build_identity_client_id"       { value = azurerm_user_assigned_identity.build.client_id }
