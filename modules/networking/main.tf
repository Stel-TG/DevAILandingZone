###############################################################################
# MODULE: NETWORKING
# Provisions the spoke VNET (10.226.214.192/26) with four /28 subnets.
#
# VNET address space: 10.226.214.192/26  (64 IPs: .192 – .255)
#
#   Subnet              CIDR                    Range
#   ──────────────────  ──────────────────────  ─────────────────────────
#   machine-learning    10.226.214.192/28       .192 – .207  (14 usable)
#   private-endpoints   10.226.214.208/28       .208 – .223  (14 usable)
#   databricks-public   10.226.214.224/28       .224 – .239  (14 usable)
#   databricks-private  10.226.214.240/28       .240 – .255  (14 usable)
#
# NOTE: Hub VNET peering is intentionally NOT configured here.
#       Peering is managed separately via scripts\setup-peering.ps1 so that
#       hub-subscription credentials can be handled independently, and the
#       peering lifecycle is decoupled from core spoke deployment.
###############################################################################

# -----------------------------------------------------------------------------
# SPOKE VNET
# /26 address space = 64 IPs total, divided into four /28 workload subnets.
# -----------------------------------------------------------------------------
resource "azurerm_virtual_network" "spoke" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space  # ["10.226.214.192/26"]

  tags = var.tags
}

# -----------------------------------------------------------------------------
# SUBNETS
# Created dynamically from the subnets variable map.
# The private-endpoints subnet has network policies disabled so private
# endpoint NICs can receive traffic correctly.
# -----------------------------------------------------------------------------
resource "azurerm_subnet" "subnets" {
  for_each = var.subnets

  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [each.value.address_prefix]
  service_endpoints    = each.value.service_endpoints

  # Private endpoint network policies must be disabled on the PE subnet
  private_endpoint_network_policies = each.key == "private-endpoints" ? "Disabled" : "Enabled"
}

