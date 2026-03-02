###############################################################################
# MODULE: RBAC
# Assigns Azure role definitions to AAD principals (groups, service principals).
# See docs/roles.md for recommended group structure and role assignments.
###############################################################################

# ─────────────────────────────────────────────────────────────────────────────
# DYNAMIC ROLE ASSIGNMENTS
# Iterates over the rbac_assignments variable list.
# Each assignment specifies principal_id, role_definition_name, and scope.
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_role_assignment" "assignments" {
  for_each = { for idx, a in var.rbac_assignments : "${a.role_definition_name}-${a.principal_id}" => a }

  # Resolve scope: "resource_group" shorthand maps to full RG ID
  scope = each.value.scope == "resource_group" ? var.resource_group_id : each.value.scope

  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id

  # Skip service principal not found errors during initial bootstrap
  skip_service_principal_aad_check = false
}
