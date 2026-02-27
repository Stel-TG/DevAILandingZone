###############################################################################
# MODULE: AZURE POLICY
# Enforces governance controls:
#   1. Allowed Locations - restrict deployments to approved regions
#   2. AI/ML Security Baseline - from Azure AI Landing Zones reference
#   3. Require tags on resources
###############################################################################

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN POLICY: Allowed Locations
# Policy Definition ID: e56962a6-4747-49cd-b67b-bf8b01975c4f
# Prevents creation of resources outside approved Azure regions.
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4f"
  display_name         = "Allowed Azure Regions - AI Landing Zone"
  description          = "Restricts resource deployment to approved regions: ${join(", ", var.allowed_locations)}"

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = var.allowed_locations  # ["canadacentral", "canadaeast", "eastus", "eastus2"]
    }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN POLICY: Require HTTPS on Storage Accounts
# Enforces secure transfer (HTTPS) for all storage accounts.
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "storage_https" {
  name                 = "storage-https-required"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
  display_name         = "Secure Transfer to Storage Accounts Enabled"
  description          = "Requires HTTPS on all storage accounts in the AI Landing Zone"
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN POLICY: Key Vault Purge Protection
# Ensures Key Vaults have purge protection enabled.
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "kv_purge_protection" {
  name                 = "kv-purge-protection"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
  display_name         = "Key Vaults Should Have Purge Protection Enabled"
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN POLICY: Require Tag - CostCenter
# Enforces cost center tagging for chargeback compliance.
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "require_cost_center_tag" {
  name                 = "require-cost-center-tag"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
  display_name         = "Require CostCenter Tag on Resources"

  parameters = jsonencode({
    tagName = { value = "CostCenter" }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# CUSTOM POLICY: Deny Public Network Access on AML Workspaces
# Ensures all AML workspaces are deployed with private endpoint only.
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_policy_definition" "deny_aml_public_access" {
  name         = "deny-aml-public-network-access"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny Public Network Access on Azure ML Workspaces"
  description  = "Ensures AML workspaces do not allow public network access"

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.MachineLearningServices/workspaces"
        },
        {
          field  = "Microsoft.MachineLearningServices/workspaces/publicNetworkAccess"
          equals = "Enabled"
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "deny_aml_public_access" {
  name                 = "deny-aml-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = azurerm_policy_definition.deny_aml_public_access.id
  display_name         = "Deny Public Network Access on AML Workspaces"
}
