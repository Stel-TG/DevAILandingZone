###############################################################################
# MODULE: AZURE POLICY
#
# Enforces governance controls across the AI Landing Zone resource group.
#
# Policy categories:
#
#   1.  Allowed Locations              — restrict to approved Azure regions
#   2.  Require HTTPS on Storage       — built-in secure-transfer enforcement
#   3.  Key Vault Purge Protection     — built-in soft-delete + purge protection
#   4.  Require CostCenter Tag         — built-in tag enforcement
#   5.  Deny Public Network Access     — CUSTOM policy covering every resource
#                                        type in this landing zone that supports
#                                        private endpoints.
#
# DENY PUBLIC NETWORK ACCESS — resource types covered:
#   Azure AI / ML
#     Microsoft.MachineLearningServices/workspaces      (AML + AI Foundry Hub/Project)
#     Microsoft.CognitiveServices/accounts              (Cognitive Services, OpenAI)
#     Microsoft.Search/searchServices                   (Azure AI Search)
#   Data
#     Microsoft.DocumentDB/databaseAccounts             (Cosmos DB)
#     Microsoft.Storage/storageAccounts                 (Storage)
#     Microsoft.DBforPostgreSQL/flexibleServers         (PostgreSQL Flexible)
#   Integration & messaging
#     Microsoft.ServiceBus/namespaces                   (Service Bus)
#     Microsoft.EventHub/namespaces                     (Event Hub)
#     Microsoft.AppConfiguration/configurationStores   (App Configuration)
#   Developer / API services
#     Microsoft.ApiManagement/service                   (API Management)
#     Microsoft.ContainerRegistry/registries            (Container Registry)
#     Microsoft.Web/sites                               (App Service / Function Apps)
#     Microsoft.Web/staticSites                         (Static Web Apps)
#   Security / identity
#     Microsoft.KeyVault/vaults                         (Key Vault)
#     Microsoft.KeyVault/managedHSMs                    (Managed HSM)
#   Monitoring
#     Microsoft.OperationalInsights/workspaces          (Log Analytics)
#     Microsoft.Insights/components                     (Application Insights)
#   Automation
#     Microsoft.Automation/automationAccounts           (Automation Account)
#     Microsoft.Batch/batchAccounts                     (Azure Batch)
#
# SCOPE: All assignments target the resource group (not subscription) so
#        hub resources and other subscriptions are unaffected.
#
# EFFECT: "Deny" — blocks the resource PUT/PATCH API call at creation or
#         update time if publicNetworkAccess is "Enabled".
#
# EXCLUSION: Virtual Machines are intentionally excluded. VMs are network
#            resources by nature (they exist in the VNet), do not have a
#            "publicNetworkAccess" property in the same sense, and are
#            secured by NSG/UDR/Bastion instead.
###############################################################################

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN POLICY: Allowed Locations
# Definition ID: e56962a6-4747-49cd-b67b-bf8b01975c4f
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4f"
  display_name         = "Allowed Azure Regions — AI Landing Zone"
  description          = "Restricts resource deployment to approved regions: ${join(", ", var.allowed_locations)}"

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = var.allowed_locations
    }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN POLICY: Require HTTPS on Storage Accounts
# Definition ID: 404c3081-a854-4457-ae30-26a93ef643f9
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
# Definition ID: 0b60c0b2-2dc2-4e1c-b5c9-abbed971de53
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "kv_purge_protection" {
  name                 = "kv-purge-protection"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
  display_name         = "Key Vaults Should Have Purge Protection Enabled"
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN POLICY: Require Tag — CostCenter
# Definition ID: 96670d01-0a4d-4649-9c89-2d3abc0a5025
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

###############################################################################
# CUSTOM POLICY: Deny Public Network Access on PE-capable Resources
#
# One policy definition using a parameterised resource-type list.
# The "field" condition matches "publicNetworkAccess" across all supported
# resource types. Using a single definition + assignment keeps the policy
# inventory clean and makes exemptions straightforward.
#
# The condition structure is:
#   IF   type IN <pe_capable_resource_types>
#   AND  publicNetworkAccess == "Enabled"   (or field exists but != "Disabled")
#   THEN Deny
#
# This catches both explicit "Enabled" values and properties set to any value
# other than "Disabled" (e.g. "SecuredByPerimeter"), ensuring only an explicit
# "Disabled" value satisfies the policy.
###############################################################################

# ─────────────────────────────────────────────────────────────────────────────
# CUSTOM POLICY DEFINITION
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_policy_definition" "deny_public_network_access" {
  name         = "deny-public-network-access-pe-resources"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny Public Network Access on Private-Endpoint-Capable Resources"

  description = <<-DESC
    Blocks creation or update of any resource that:
      (a) supports Azure Private Link / Private Endpoints, AND
      (b) has publicNetworkAccess set to anything other than "Disabled".

    Virtual Machines are explicitly excluded — VMs are network resources
    secured by NSG, UDR, and Azure Bastion; they do not expose a
    publicNetworkAccess toggle in the same sense as PaaS services.

    Resource types covered:
      AI / ML:        AML workspaces, Cognitive Services, Azure OpenAI, AI Search
      Data:           Cosmos DB, Storage Accounts, PostgreSQL Flexible Server
      Integration:    Service Bus, Event Hub, App Configuration
      Developer:      API Management, Container Registry, App Service, Function Apps
      Security:       Key Vault, Managed HSM
      Observability:  Log Analytics, Application Insights
      Automation:     Automation Accounts, Azure Batch
  DESC

  # Metadata for portal display
  metadata = jsonencode({
    category = "AI Landing Zone"
    version  = "2.0.0"
  })

  # Parameters allow the effect to be overridden (Audit vs Deny) per-assignment
  # without modifying the definition — useful for rollout / break-glass.
  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "Deny"
      allowedValues = ["Deny", "Audit", "Disabled"]
      metadata = {
        displayName = "Effect"
        description = "Deny (default), Audit (log only), or Disabled (inactive)."
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        # ── Match every PE-capable resource type in this landing zone ──────────
        {
          anyOf = [
            # AI / ML
            { field = "type"; equals = "Microsoft.MachineLearningServices/workspaces" },
            { field = "type"; equals = "Microsoft.CognitiveServices/accounts" },
            { field = "type"; equals = "Microsoft.Search/searchServices" },
            # Data
            { field = "type"; equals = "Microsoft.DocumentDB/databaseAccounts" },
            { field = "type"; equals = "Microsoft.Storage/storageAccounts" },
            { field = "type"; equals = "Microsoft.DBforPostgreSQL/flexibleServers" },
            # Integration & messaging
            { field = "type"; equals = "Microsoft.ServiceBus/namespaces" },
            { field = "type"; equals = "Microsoft.EventHub/namespaces" },
            { field = "type"; equals = "Microsoft.AppConfiguration/configurationStores" },
            # Developer / API
            { field = "type"; equals = "Microsoft.ApiManagement/service" },
            { field = "type"; equals = "Microsoft.ContainerRegistry/registries" },
            { field = "type"; equals = "Microsoft.Web/sites" },
            { field = "type"; equals = "Microsoft.Web/staticSites" },
            # Security / identity
            { field = "type"; equals = "Microsoft.KeyVault/vaults" },
            { field = "type"; equals = "Microsoft.KeyVault/managedHSMs" },
            # Observability
            { field = "type"; equals = "Microsoft.OperationalInsights/workspaces" },
            { field = "type"; equals = "Microsoft.Insights/components" },
            # Automation
            { field = "type"; equals = "Microsoft.Automation/automationAccounts" },
            { field = "type"; equals = "Microsoft.Batch/batchAccounts" }
          ]
        },
        # ── publicNetworkAccess exists AND is not explicitly "Disabled" ─────────
        # Using "notEquals" rather than "equals Enabled" catches all non-disabled
        # values including "SecuredByPerimeter", "Enabled", null, etc.
        {
          allOf = [
            {
              # Property must exist on the resource (excludes resource types
              # that genuinely don't have this field)
              field  = "[concat('Microsoft.', last(split(field('type'), '/')), '/publicNetworkAccess')]"
              exists = "true"
            },
            {
              field       = "[concat(field('type'), '/publicNetworkAccess')]"
              notEquals   = "Disabled"
            }
          ]
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# ASSIGNMENT: Deny Public Network Access (Effect = Deny)
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_public_network_access" {
  name                 = "deny-public-network-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = azurerm_policy_definition.deny_public_network_access.id
  display_name         = "Deny Public Network Access on Private-Endpoint-Capable Resources"

  description = <<-DESC
    Enforces private-only access on all PaaS services in this resource group
    that support Azure Private Link. VMs are excluded — they are network
    resources controlled by NSG and UDR, not by publicNetworkAccess flags.
  DESC

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}

###############################################################################
# PER-SERVICE BUILT-IN POLICY ASSIGNMENTS
#
# Azure ships built-in "Deny public network access" policies for several
# specific resource types. Assigning these in addition to the custom policy
# above provides defence in depth and improves compliance dashboard coverage
# because the built-in policies show up under their service-specific
# Regulatory Compliance controls.
#
# Built-in definitions used (all use the same pattern: Deny/Audit/Disabled):
###############################################################################

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN: Azure Cognitive Services accounts should disable public network access
# Definition ID: 0725b4dd-7e76-479c-a735-68e7ee23d5ca
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_cognitive_public_access" {
  name                 = "deny-cog-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0725b4dd-7e76-479c-a735-68e7ee23d5ca"
  display_name         = "Cognitive Services Accounts Should Disable Public Network Access"

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN: Azure Cosmos DB should disable public network access
# Definition ID: 797b37f7-06b8-444c-b1ad-fc62867f335a
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_cosmos_public_access" {
  name                 = "deny-cosmos-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/797b37f7-06b8-444c-b1ad-fc62867f335a"
  display_name         = "Azure Cosmos DB Should Disable Public Network Access"

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN: Container registries should not allow unrestricted network access
# Definition ID: d0793b48-0edc-4296-a390-4c75d1bdfd71
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_acr_public_access" {
  name                 = "deny-acr-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/d0793b48-0edc-4296-a390-4c75d1bdfd71"
  display_name         = "Container Registries Should Not Allow Unrestricted Network Access"

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN: Storage accounts should disable public network access
# Definition ID: b2982f36-99f2-4db5-8eff-283140c09693
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_storage_public_access" {
  name                 = "deny-storage-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/b2982f36-99f2-4db5-8eff-283140c09693"
  display_name         = "Storage Accounts Should Disable Public Network Access"

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN: Azure Machine Learning workspaces should disable public network access
# Definition ID: 438c38d2-3772-465a-a9cc-7a6666a275ce
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_aml_public_access" {
  name                 = "deny-aml-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/438c38d2-3772-465a-a9cc-7a6666a275ce"
  display_name         = "AML Workspaces Should Disable Public Network Access"

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN: Azure Key Vault should disable public network access
# Definition ID: 405c5871-3e91-4644-8a63-58e19d68ff5b
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_kv_public_access" {
  name                 = "deny-kv-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/405c5871-3e91-4644-8a63-58e19d68ff5b"
  display_name         = "Azure Key Vault Should Disable Public Network Access"

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN: Azure AI Search service should disable public network access
# Definition ID: ee980b6d-600d-4f21-8d7b-383a0ee78e0e
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_search_public_access" {
  name                 = "deny-search-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/ee980b6d-600d-4f21-8d7b-383a0ee78e0e"
  display_name         = "Azure AI Search Service Should Disable Public Network Access"

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN: Service Bus namespaces should disable public network access
# Definition ID: cbd11fd3-3002-4907-b6c8-579f0e700e13
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_servicebus_public_access" {
  name                 = "deny-sbus-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/cbd11fd3-3002-4907-b6c8-579f0e700e13"
  display_name         = "Service Bus Namespaces Should Disable Public Network Access"

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN: Event Hub namespaces should disable public network access
# Definition ID: d9d5b15c-c2f4-4977-8c7d-1b7e3b43c29b
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_eventhub_public_access" {
  name                 = "deny-ehub-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/d9d5b15c-c2f4-4977-8c7d-1b7e3b43c29b"
  display_name         = "Event Hub Namespaces Should Disable Public Network Access"

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN: App Configuration stores should disable public network access
# Definition ID: 3d9f5e4c-9947-4579-9539-2a7695fbc187
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_appconfig_public_access" {
  name                 = "deny-appconfig-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/3d9f5e4c-9947-4579-9539-2a7695fbc187"
  display_name         = "App Configuration Stores Should Disable Public Network Access"

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN: API Management services should disable public network access
# Definition ID: df73bd84-a0f0-4c52-b38a-3e735db8b3c2
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_apim_public_access" {
  name                 = "deny-apim-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/df73bd84-a0f0-4c52-b38a-3e735db8b3c2"
  display_name         = "API Management Services Should Disable Public Network Access"

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN: Log Analytics workspaces should block log ingestion and querying
#           from public networks
# Definition ID: 6c53d030-cc64-46f0-906d-2bc061cd1334
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_law_public_access" {
  name                 = "deny-law-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/6c53d030-cc64-46f0-906d-2bc061cd1334"
  display_name         = "Log Analytics Workspaces Should Block Public Network Access"

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN: Automation account should disable public network access
# Definition ID: 955a914f-bf86-4f0e-acd5-e0766b0efcb6
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_automation_public_access" {
  name                 = "deny-automation-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/955a914f-bf86-4f0e-acd5-e0766b0efcb6"
  display_name         = "Automation Accounts Should Disable Public Network Access"

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILT-IN: Azure Batch account should disable public network access
# Definition ID: 74c5a0ae-5e48-4738-b093-65e23a060488
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group_policy_assignment" "deny_batch_public_access" {
  name                 = "deny-batch-public-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/74c5a0ae-5e48-4738-b093-65e23a060488"
  display_name         = "Azure Batch Accounts Should Disable Public Network Access"

  parameters = jsonencode({
    effect = { value = var.deny_public_access_effect }
  })
}
