###############################################################################
# MODULE: AZURE MACHINE LEARNING WORKSPACE
# Single AML workspace that integrates all platform services.
# Managed virtual network mode: "AllowOnlyApprovedOutbound" for production.
# System-assigned managed identity enables access to Key Vault and Storage.
###############################################################################

resource "azurerm_machine_learning_workspace" "this" {
  name                    = var.name
  location                = var.location
  resource_group_name     = var.resource_group_name
  application_insights_id = var.application_insights_id
  key_vault_id            = var.key_vault_id
  storage_account_id      = var.storage_account_id
  container_registry_id   = var.container_registry_id
  sku_name                = var.sku_name

  # Disable public network access; all access via private endpoint
  public_network_access_enabled = false

  # System-assigned identity for MSI-based auth to Key Vault, Storage, ACR
  identity {
    type = "SystemAssigned"
  }

  # Managed VNET for compute cluster and compute instance isolation
  managed_network {
    isolation_mode = "AllowOnlyApprovedOutbound"
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# DIAGNOSTIC SETTINGS
# Route AML workspace activity and audit logs to Log Analytics.
# Captures model training events, dataset registrations, and access logs.
# -----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "aml" {
  count = var.log_analytics_workspace_id != null ? 1 : 0

  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_machine_learning_workspace.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # AmlComputeClusterNodeEvent: GPU/CPU utilization and node lifecycle events
  enabled_log { category = "AmlComputeClusterNodeEvent" }
  # AmlComputeJobEvent: Training run start/stop/failure tracking
  enabled_log { category = "AmlComputeJobEvent" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# -----------------------------------------------------------------------------
# COMPUTE CLUSTER
# CPU cluster for batch training. Auto-scales to 0 when idle to reduce cost.
# Low-priority VMs reduce cost by ~80% for fault-tolerant workloads.
# -----------------------------------------------------------------------------
resource "azurerm_machine_learning_compute_cluster" "cpu" {
  count = var.deploy_cpu_cluster ? 1 : 0

  name                          = "cc-cpu-${var.name}"
  location                      = var.location
  vm_priority                   = var.cpu_cluster_priority # "LowPriority" or "Dedicated"
  vm_size                       = var.cpu_cluster_vm_size
  machine_learning_workspace_id = azurerm_machine_learning_workspace.this.id

  # Scale to 0 when idle; max nodes controlled by var
  scale_settings {
    min_node_count                       = 0
    max_node_count                       = var.cpu_cluster_max_nodes
    scale_down_nodes_after_idle_duration = "PT15M" # 15 minutes
  }

  identity {
    type = "SystemAssigned"
  }
}

# -----------------------------------------------------------------------------
# COMPUTE CLUSTER: GPU (optional for model training at scale)
# -----------------------------------------------------------------------------
resource "azurerm_machine_learning_compute_cluster" "gpu" {
  count = var.deploy_gpu_cluster ? 1 : 0

  name                          = "cc-gpu-${var.name}"
  location                      = var.location
  vm_priority                   = "LowPriority" # GPU low-priority for cost optimization
  vm_size                       = var.gpu_cluster_vm_size
  machine_learning_workspace_id = azurerm_machine_learning_workspace.this.id

  scale_settings {
    min_node_count                       = 0
    max_node_count                       = var.gpu_cluster_max_nodes
    scale_down_nodes_after_idle_duration = "PT15M"
  }

  identity {
    type = "SystemAssigned"
  }
}
