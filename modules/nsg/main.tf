###############################################################################
# MODULE: NETWORK SECURITY GROUP
# Creates NSGs for each subnet with rules allowing required traffic.
# Default: deny all inbound internet, allow Azure service tags.
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
