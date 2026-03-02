###############################################################################
# MODULE: AZURE POLICY — OUTPUTS
###############################################################################

output "allowed_locations_assignment_id" {
  description = "Resource ID of the Allowed Locations policy assignment."
  value       = azurerm_resource_group_policy_assignment.allowed_locations.id
}

output "deny_public_access_definition_id" {
  description = "Resource ID of the custom Deny Public Network Access policy definition."
  value       = azurerm_policy_definition.deny_public_network_access.id
}

output "deny_public_access_assignment_id" {
  description = "Resource ID of the Deny Public Network Access policy assignment."
  value       = azurerm_resource_group_policy_assignment.deny_public_network_access.id
}

output "deny_public_access_effect" {
  description = "The effect configured for all Deny Public Network Access assignments (Deny | Audit | Disabled)."
  value       = var.deny_public_access_effect
}
