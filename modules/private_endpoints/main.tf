###############################################################################
# MODULE: PRIVATE ENDPOINTS
# Creates private endpoints and DNS zone configurations for all services.
# DNS zones are linked to the hub VNET so on-premises and hub clients can
# resolve private endpoint FQDNs without additional DNS infrastructure.
#
# Each resource type uses a specific DNS zone:
#   Key Vault:            privatelink.vaultcore.azure.net
#   Storage (blob):       privatelink.blob.core.windows.net
#   Storage (dfs):        privatelink.dfs.core.windows.net
#   Container Registry:   privatelink.azurecr.io
#   AML Workspace:        privatelink.api.azureml.ms
#   Cognitive Services:   privatelink.cognitiveservices.azure.com
#   OpenAI:               privatelink.openai.azure.com
#   Log Analytics:        privatelink.ods.opinsights.azure.com
###############################################################################

# Local map: service name -> {resource_id, subresource, dns_zone}
# Only include entries where resource_id is non-null (service deployed)
locals {
  pe_definitions = {
    for k, v in {
      key_vault = {
        id          = var.key_vault_id
        subresource = "vault"
        dns_zone    = "privatelink.vaultcore.azure.net"
      }
      storage_blob = {
        id          = var.storage_account_id
        subresource = "blob"
        dns_zone    = "privatelink.blob.core.windows.net"
      }
      storage_dfs = {
        id          = var.storage_account_id
        subresource = "dfs"
        dns_zone    = "privatelink.dfs.core.windows.net"
      }
      container_registry = {
        id          = var.container_registry_id
        subresource = "registry"
        dns_zone    = "privatelink.azurecr.io"
      }
      machine_learning = {
        id          = var.machine_learning_id
        subresource = "amlworkspace"
        dns_zone    = "privatelink.api.azureml.ms"
      }
      cognitive_services = {
        id          = var.cognitive_services_id
        subresource = "account"
        dns_zone    = "privatelink.cognitiveservices.azure.com"
      }
      openai = {
        id          = var.openai_id
        subresource = "account"
        dns_zone    = "privatelink.openai.azure.com"
      }
    } : k => v if v.id != null
  }
}

# -----------------------------------------------------------------------------
# PRIVATE DNS ZONES
# One zone per unique DNS zone value. Hosted in spoke subscription.
# -----------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "zones" {
  for_each = toset(values(local.pe_definitions)[*].dns_zone)

  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link DNS zones to hub VNET for resolution from hub-connected networks
resource "azurerm_private_dns_zone_virtual_network_link" "hub_links" {
  for_each = azurerm_private_dns_zone.zones

  name                  = "link-hub-${replace(each.key, ".", "-")}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = var.hub_vnet_id
  registration_enabled  = false # Only resolve, don't auto-register

  tags = var.tags
}

# -----------------------------------------------------------------------------
# PRIVATE ENDPOINTS
# One endpoint per service (some services require multiple for different subresources)
# -----------------------------------------------------------------------------
resource "azurerm_private_endpoint" "endpoints" {
  for_each = local.pe_definitions

  name                = "pe-${each.key}-${var.resource_group_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-${each.key}"
    private_connection_resource_id = each.value.id
    is_manual_connection           = false
    subresource_names              = [each.value.subresource]
  }

  private_dns_zone_group {
    name                 = "pdz-${each.key}"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones[each.value.dns_zone].id]
  }

  tags = var.tags
}
