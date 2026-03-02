###############################################################################
# MODULE: JUMP BOX VM
#
# Deploys a Linux jump box VM for secure administrative access to the spoke
# VNET. All direct management of private resources (AML Studio, APIM portal,
# Container App logs) must route through this VM via Azure Bastion or
# a VPN/ExpressRoute connection from the hub.
#
# Key configuration:
#   - Ubuntu 22.04 LTS image
#   - No public IP — accessed via Azure Bastion or hub VPN
#   - Azure AD / Entra login enabled (passwordless SSH)
#   - System-assigned identity for KeyVault reads
#   - Auto-shutdown at 22:00 UTC for cost management (configurable)
#   - OS disk encrypted with platform-managed key
###############################################################################

resource "azurerm_network_interface" "jumpbox" {
  name                = var.nic_name
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "jumpbox-ip"
    subnet_id                     = var.subnet_id   # jump-box subnet
    private_ip_address_allocation = "Dynamic"
    # No public IP — access only via Bastion or hub VPN
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                            = var.name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.vm_size   # "Standard_B2ms" default
  admin_username                  = var.admin_username
  disable_password_authentication = true   # SSH key only

  network_interface_ids = [azurerm_network_interface.jumpbox.id]

  # System-assigned identity for KV secret reads and Portal auth
  identity {
    type = "SystemAssigned"
  }

  os_disk {
    name                 = "osdisk-${var.name}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }

  # Ubuntu 22.04 LTS
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  # AAD login extension for passwordless Entra ID access
  # Allows using `az ssh vm` with Entra ID credentials
  tags = var.tags
}

# AAD/Entra ID Login extension
resource "azurerm_virtual_machine_extension" "aad_login" {
  name                 = "AADSSHLoginForLinux"
  virtual_machine_id   = azurerm_linux_virtual_machine.jumpbox.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# AUTO-SHUTDOWN SCHEDULE
# Reduces costs by shutting down the jump box during off-hours.
# Adjust timezone and time to match your team's working hours.
# -----------------------------------------------------------------------------
resource "azurerm_dev_test_global_vm_shutdown_schedule" "jumpbox" {
  virtual_machine_id    = azurerm_linux_virtual_machine.jumpbox.id
  location              = var.location
  enabled               = var.auto_shutdown_enabled

  daily_recurrence_time = var.auto_shutdown_time   # "2200" = 22:00 UTC
  timezone              = var.auto_shutdown_timezone

  notification_settings {
    enabled = false
  }

  tags = var.tags
}
