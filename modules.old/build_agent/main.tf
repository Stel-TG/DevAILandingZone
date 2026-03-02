###############################################################################
# MODULE: BUILD AGENT VM
#
# Deploys a self-hosted CI/CD build agent VM in the dedicated build-agent
# subnet. Used for pipelines that need VNet-level access to private resources
# (Container Registry, AML, Key Vault) during builds and deployments.
#
# Key configuration:
#   - Ubuntu 22.04 LTS with Azure DevOps or GitHub Actions agent pre-installed
#   - No public IP — pipeline jobs initiated from hub or via VPN
#   - User-assigned managed identity with push rights to Container Registry
#     and deploy rights to Container Apps
#   - Auto-shutdown schedule to control costs
###############################################################################

resource "azurerm_network_interface" "build" {
  name                = var.nic_name
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "build-agent-ip"
    subnet_id                     = var.subnet_id   # build-agent subnet
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "build" {
  name                            = var.name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.vm_size   # "Standard_D4s_v5" for faster builds
  admin_username                  = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.build.id]

  identity {
    type         = "UserAssigned"
    identity_ids = [var.build_identity_id]
  }

  os_disk {
    name                 = "osdisk-${var.name}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128   # Larger disk for build caches and container layers
  }

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

  # Cloud-init script installs Docker, Azure CLI, and CI agent
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io azure-cli git curl jq

    # Add azureuser to docker group for Docker builds
    usermod -aG docker ${var.admin_username}

    # Install Azure DevOps agent (update URL for your org if using ADO)
    # For GitHub Actions: replace with actions-runner installation
    echo "Build agent VM provisioned. Install CI agent via your pipeline bootstrap script."
  EOF
  )

  tags = var.tags
}

# Auto-shutdown to avoid cost overruns on build VMs
resource "azurerm_dev_test_global_vm_shutdown_schedule" "build" {
  virtual_machine_id    = azurerm_linux_virtual_machine.build.id
  location              = var.location
  enabled               = var.auto_shutdown_enabled

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.auto_shutdown_timezone

  notification_settings {
    enabled = false
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# RBAC: Build identity -> Container Registry (push images)
# Allows the build agent to push built container images to ACR.
# -----------------------------------------------------------------------------
resource "azurerm_role_assignment" "build_acr_push" {
  count                = var.container_registry_id != "" ? 1 : 0
  scope                = var.container_registry_id
  role_definition_name = "AcrPush"
  principal_id         = var.build_identity_principal_id
  description          = "Build agent pushes container images to ACR"
}

# -----------------------------------------------------------------------------
# RBAC: Build identity -> Container App Environment (deploy)
# Allows the build agent to deploy new container app revisions.
# -----------------------------------------------------------------------------
resource "azurerm_role_assignment" "build_cae_contributor" {
  count                = var.container_app_environment_id != "" ? 1 : 0
  scope                = var.container_app_environment_id
  role_definition_name = "Contributor"
  principal_id         = var.build_identity_principal_id
  description          = "Build agent deploys container app revisions"
}
