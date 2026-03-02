###############################################################################
# MODULE: SECURITY & GOVERNANCE
#
# Deploys the security and governance tooling shown in the reference
# architecture "Security & governance" band:
#
#   - Subscription-level Policy assignments (allowed locations, tag enforcement)
#   - Microsoft Defender for Cloud (Defender CSPM + Defender for AI services)
#   - Microsoft Purview account (data governance, classification, lineage)
#   - Entra ID diagnostic settings (sign-in and audit logs -> Log Analytics)
#   - Network Watcher for the spoke subscription region
#
# Note: Entra ID and Defender are subscription-scoped resources.
#       Purview is a resource-group-scoped account.
###############################################################################

# -----------------------------------------------------------------------------
# NETWORK WATCHER
# Required per region per subscription. Enables NSG flow logs, Connection
# Monitor, and VPN diagnostics for the landing zone VNET.
# -----------------------------------------------------------------------------
resource "azurerm_network_watcher" "this" {
  name                = var.network_watcher_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# -----------------------------------------------------------------------------
# MICROSOFT DEFENDER FOR CLOUD
# Enables enhanced security monitoring plans for AI workloads.
# Plans enabled: Arm, KeyVaults, StorageAccounts, Containers, VirtualMachines
# -----------------------------------------------------------------------------
resource "azurerm_security_center_subscription_pricing" "arm" {
  tier          = "Standard"
  resource_type = "Arm"
}

resource "azurerm_security_center_subscription_pricing" "key_vaults" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

resource "azurerm_security_center_subscription_pricing" "storage" {
  tier          = "Standard"
  resource_type = "StorageAccounts"
}

resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "Containers"
}

resource "azurerm_security_center_subscription_pricing" "ai" {
  tier          = "Standard"
  resource_type = "Ai"   # Defender for AI services (Azure AI / OpenAI)
}

# Route Defender alerts to the central Log Analytics Workspace
resource "azurerm_security_center_workspace" "this" {
  scope        = "/subscriptions/${var.subscription_id}"
  workspace_id = var.log_analytics_workspace_id
}

# Contact information for Defender security alerts
resource "azurerm_security_center_contact" "this" {
  count = length(var.security_contact_emails) > 0 ? 1 : 0

  email               = var.security_contact_emails[0]
  alert_notifications = true
  alerts_to_admins    = true
}

# -----------------------------------------------------------------------------
# MICROSOFT PURVIEW ACCOUNT
# Provides data governance, sensitivity classification, and data lineage
# across Storage, Cosmos DB, and AI Search data sources.
# -----------------------------------------------------------------------------
resource "azurerm_purview_account" "this" {
  count               = var.deploy_purview ? 1 : 0

  name                = var.purview_account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
