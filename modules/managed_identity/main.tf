###############################################################################
# MODULE: MANAGED IDENTITIES
#
# Creates user-assigned managed identities for each major workload:
#   - Foundry identity  (AI Foundry Hub + Agent Service)
#   - Apps identity     (Container App Environment microservices)
#   - Build identity    (Build agent VM for CI/CD pipelines)
#
# Using user-assigned (vs system-assigned) allows the same identity to be
# pre-authorized on dependent resources before the principal resource exists,
# and permits sharing across resources where needed.
###############################################################################

resource "azurerm_user_assigned_identity" "foundry" {
  name                = var.foundry_identity_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = merge(var.tags, { Workload = "ai-foundry" })
}

resource "azurerm_user_assigned_identity" "apps" {
  name                = var.apps_identity_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = merge(var.tags, { Workload = "container-apps" })
}

resource "azurerm_user_assigned_identity" "build" {
  name                = var.build_identity_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = merge(var.tags, { Workload = "build-agent" })
}
