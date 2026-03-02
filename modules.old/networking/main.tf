###############################################################################
# MODULE: NETWORKING
# Provisions the spoke VNET (10.226.214.0/24) with ten subnets.
#
# VNET address space: 10.226.214.0/24  (256 IPs: .0 – .255)
#
#   Subnet                       CIDR                    Range                  Usable
#   ─────────────────────────    ──────────────────────  ─────────────────────  ──────
#   private-endpoints            10.226.214.0/27         .0   – .31             27
#   ai-foundry-agent             10.226.214.32/28        .32  – .47             11
#   api-management               10.226.214.48/29        .48  – .55              3
#   container-app-environment    10.226.214.64/27        .64  – .95             27
#   application-gateway          10.226.214.96/28        .96  – .111            11
#   build-agent                  10.226.214.112/29       .112 – .119             3
#   jumpbox                      10.226.214.120/29       .120 – .127             3
#   databricks-public            10.226.214.128/28       .128 – .143            11  (reserved)
#   databricks-private           10.226.214.144/28       .144 – .159            11  (reserved)
#   aml-compute                  10.226.214.160/28       .160 – .175            11  (AML Compute Instances)
#
#   Total allocated: 168 IPs  |  Unallocated: 88 IPs (.176 – .255)
#
# NOTE: Hub VNET peering is intentionally NOT configured here.
#       Peering is managed separately via scripts\setup-peering.ps1 so that
#       hub-subscription credentials can be handled independently, and the
#       peering lifecycle is decoupled from core spoke deployment.
###############################################################################

# -----------------------------------------------------------------------------
# SPOKE VNET
# /24 address space = 256 IPs total, divided into ten workload subnets.
# 88 IPs remain unallocated (.176 – .255) for future growth.
# -----------------------------------------------------------------------------
resource "azurerm_virtual_network" "spoke" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space  # ["10.226.214.0/24"]

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

