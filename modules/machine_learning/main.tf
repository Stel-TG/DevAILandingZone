###############################################################################
# MODULE: AZURE MACHINE LEARNING WORKSPACE
# Primary workload for chatbot refactoring.
# Chatbots currently use public network access in prod; this dev environment
# proves the private endpoint migration path before prod cutover.
#
# Private endpoint migration strategy:
#   - AML workspace:          public_network_access_enabled = false (PE only)
#   - AML managed VNet:       AllowOnlyApprovedOutbound — compute clusters reach
#                             services via AML-managed private endpoints (separate
#                             from spoke subnet PEs, no spoke IP consumption)
#   - Compute Instances:      no_public_ip = true, injected into aml-compute subnet
#                             so developers reach spoke PEs directly during testing
#   - OpenAI, AI Search,
#     Cosmos DB:              accessed via spoke PEs; approved as managed outbound
#                             rules so compute clusters reach them the same way
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

  # All access via private endpoint — mirrors target prod state
  public_network_access_enabled = false

  # System-assigned identity for MSI-based auth to Key Vault, Storage, ACR
  identity {
    type = "SystemAssigned"
  }

  # Managed VNet: compute clusters reach all services via AML-managed PEs.
  # AllowOnlyApprovedOutbound blocks everything except explicitly approved rules,
  # validating that chatbots work with zero public egress — same as prod target.
  managed_network {
    isolation_mode = "AllowOnlyApprovedOutbound"
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# MANAGED NETWORK OUTBOUND RULES
# Approve private endpoint egress from AML managed VNet to each service
# the chatbots call. AML creates its own managed PEs for these rules —
# they do not consume IPs in the spoke private-endpoints subnet.
# -----------------------------------------------------------------------------

# OpenAI — chatbot LLM inference
resource "azurerm_machine_learning_workspace_network_outbound_rule_private_endpoint" "openai" {
  count = var.openai_resource_id != null ? 1 : 0

  name                    = "openai-outbound"
  workspace_id            = azurerm_machine_learning_workspace.this.id
  service_resource_id     = var.openai_resource_id
  spark_enabled           = false
  sub_resource_type       = "account"
}

# AI Search — chatbot RAG retrieval
resource "azurerm_machine_learning_workspace_network_outbound_rule_private_endpoint" "ai_search" {
  count = var.ai_search_resource_id != null ? 1 : 0

  name                    = "ai-search-outbound"
  workspace_id            = azurerm_machine_learning_workspace.this.id
  service_resource_id     = var.ai_search_resource_id
  spark_enabled           = false
  sub_resource_type       = "searchService"
}

# Cosmos DB — chatbot conversation memory and session state
resource "azurerm_machine_learning_workspace_network_outbound_rule_private_endpoint" "cosmos_db" {
  count = var.cosmos_db_resource_id != null ? 1 : 0

  name                    = "cosmos-db-outbound"
  workspace_id            = azurerm_machine_learning_workspace.this.id
  service_resource_id     = var.cosmos_db_resource_id
  spark_enabled           = false
  sub_resource_type       = "Sql"
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
# COMPUTE CLUSTER (CPU)
# Batch training cluster. Scales to 0 when idle.
# Lives in AML managed VNet — reaches services via managed outbound rules above.
# -----------------------------------------------------------------------------
resource "azurerm_machine_learning_compute_cluster" "cpu" {
  count = var.deploy_cpu_cluster ? 1 : 0

  name                          = "cc-cpu-${var.name}"
  location                      = var.location
  vm_priority                   = var.cpu_cluster_priority
  vm_size                       = var.cpu_cluster_vm_size
  machine_learning_workspace_id = azurerm_machine_learning_workspace.this.id

  scale_settings {
    min_node_count                       = 0
    max_node_count                       = var.cpu_cluster_max_nodes
    scale_down_nodes_after_idle_duration = "PT15M"
  }

  identity {
    type = "SystemAssigned"
  }
}

# -----------------------------------------------------------------------------
# COMPUTE CLUSTER (GPU) — optional
# -----------------------------------------------------------------------------
resource "azurerm_machine_learning_compute_cluster" "gpu" {
  count = var.deploy_gpu_cluster ? 1 : 0

  name                          = "cc-gpu-${var.name}"
  location                      = var.location
  vm_priority                   = "LowPriority"
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

# -----------------------------------------------------------------------------
# COMPUTE INSTANCE (interactive dev)
# No-public-IP compute instance injected into the aml-compute spoke subnet.
# Developers connect via Azure Bastion / VPN to the jumpbox, then SSH to the
# compute instance, allowing them to:
#   1. Run chatbot code interactively (Jupyter / VS Code Remote)
#   2. Verify private endpoint DNS resolution for all services
#   3. Confirm zero public network egress from chatbot code paths
#
# Each instance NIC consumes 1 IP from the aml-compute subnet (/28, 11 usable).
# -----------------------------------------------------------------------------
resource "azurerm_machine_learning_compute_instance" "dev" {
  count = var.deploy_compute_instance ? 1 : 0

  name                          = "ci-dev-${var.name}"
  location                      = var.location
  machine_learning_workspace_id = azurerm_machine_learning_workspace.this.id
  virtual_machine_size          = var.compute_instance_vm_size

  # Inject NIC into spoke aml-compute subnet — no public IP assigned
  subnet_resource_id = var.aml_compute_subnet_id

  # SSH access only via jumpbox / Bastion — no direct internet path
  ssh {
    public_key = var.admin_ssh_public_key
  }

  identity {
    type = "SystemAssigned"
  }
}
