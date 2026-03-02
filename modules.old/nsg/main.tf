###############################################################################
# MODULE: NETWORK SECURITY GROUP
# Creates NSGs for each subnet with rules allowing required traffic.
# Default: deny all inbound internet, allow Azure service tags.
# The aml-compute subnet gets additional rules required by AML compute nodes.
###############################################################################

resource "azurerm_network_security_group" "subnets" {
  for_each = var.subnets

  name                = "nsg-${each.key}-${var.vnet_name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow Azure Active Directory (required for managed identity auth)
  security_rule {
    name                       = "Allow-AAD-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureActiveDirectory"
  }

  # Allow Azure Monitor (required for diagnostic settings)
  security_rule {
    name                       = "Allow-Monitor-Outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureMonitor"
  }

  # ── AML Compute Instance rules (aml-compute subnet only) ──────────────────
  # BatchNodeManagement inbound: required for Azure Batch to provision and
  # manage compute nodes (applies to both Compute Clusters and Instances).
  dynamic "security_rule" {
    for_each = each.key == "aml-compute" ? [1] : []
    content {
      name                       = "Allow-BatchNodeManagement-Inbound"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["29876", "29877"]
      source_address_prefix      = "BatchNodeManagement"
      destination_address_prefix = "VirtualNetwork"
    }
  }

  # AzureMachineLearning inbound: AML control plane heartbeat and job dispatch
  dynamic "security_rule" {
    for_each = each.key == "aml-compute" ? [1] : []
    content {
      name                       = "Allow-AML-Inbound"
      priority                   = 210
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "44224"
      source_address_prefix      = "AzureMachineLearning"
      destination_address_prefix = "VirtualNetwork"
    }
  }

  # VirtualNetwork inbound: node-to-node communication within the compute subnet
  dynamic "security_rule" {
    for_each = each.key == "aml-compute" ? [1] : []
    content {
      name                       = "Allow-VNet-Inbound"
      priority                   = 220
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    }
  }

  # AzureMachineLearning outbound: compute nodes report status, submit metrics
  dynamic "security_rule" {
    for_each = each.key == "aml-compute" ? [1] : []
    content {
      name                       = "Allow-AML-Outbound"
      priority                   = 200
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "AzureMachineLearning"
    }
  }
  # ── End AML Compute rules ─────────────────────────────────────────────────

  # Deny all other inbound internet traffic
  security_rule {
    name                       = "Deny-Internet-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = var.tags
}

# Associate NSG with each subnet
resource "azurerm_subnet_network_security_group_association" "assoc" {
  for_each = var.subnets

  subnet_id                 = var.subnet_ids[each.key]
  network_security_group_id = azurerm_network_security_group.subnets[each.key].id
}
