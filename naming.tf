###############################################################################
# NAMING CONVENTIONS
# Centralized naming patterns for all Azure resource types.
# Based on Microsoft Cloud Adoption Framework naming conventions.
# Reference: https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming
#
# Pattern: <prefix>-<project>-<environment>-<location_short>
# Storage accounts and container registries omit hyphens (alphanumeric only).
###############################################################################

locals {
  naming_convention = {
    # Core infrastructure
    resource_group          = "rg-${var.project_name}-${var.environment}-${var.location_short}"
    virtual_network         = "vnet-${var.project_name}-${var.environment}-${var.location_short}"
    network_security_group  = "nsg-${var.project_name}-${var.environment}-${var.location_short}"

    # Monitoring and observability
    log_analytics_workspace = "law-${var.project_name}-${var.environment}-${var.location_short}"
    application_insights    = "appi-${var.project_name}-${var.environment}-${var.location_short}"
    monitor_action_group    = "ag-${var.project_name}-${var.environment}-${var.location_short}"

    # Security and identity
    key_vault               = "kv-${var.project_name}-${var.environment}-${var.location_short}"
    # Key Vault names: 3-24 chars, alphanumeric + hyphens. No hyphens in auto-gen.

    # Storage (no hyphens allowed, max 24 chars lowercase alphanumeric)
    storage_account         = lower(replace("st${var.project_name}${var.environment}${var.location_short}", "-", ""))
    container_registry      = lower(replace("cr${var.project_name}${var.environment}${var.location_short}", "-", ""))

    # AI and ML services
    machine_learning_workspace = "mlw-${var.project_name}-${var.environment}-${var.location_short}"
    cognitive_services         = "ais-${var.project_name}-${var.environment}-${var.location_short}"
    openai_service             = "oai-${var.project_name}-${var.environment}-${var.location_short}"

    # Private endpoints follow pattern: pe-<service>-<project>-<env>
    pe_key_vault            = "pe-kv-${var.project_name}-${var.environment}-${var.location_short}"
    pe_storage_blob         = "pe-stblob-${var.project_name}-${var.environment}-${var.location_short}"
    pe_storage_file         = "pe-stfile-${var.project_name}-${var.environment}-${var.location_short}"
    pe_storage_dfs          = "pe-stdfs-${var.project_name}-${var.environment}-${var.location_short}"
    pe_container_registry   = "pe-cr-${var.project_name}-${var.environment}-${var.location_short}"
    pe_machine_learning     = "pe-mlw-${var.project_name}-${var.environment}-${var.location_short}"
    pe_cognitive_services   = "pe-ais-${var.project_name}-${var.environment}-${var.location_short}"
    pe_openai               = "pe-oai-${var.project_name}-${var.environment}-${var.location_short}"
    pe_log_analytics        = "pe-law-${var.project_name}-${var.environment}-${var.location_short}"

    # Policy assignments
    policy_allowed_locations = "pa-allowed-locations-${var.environment}"
    policy_required_tags     = "pa-required-tags-${var.environment}"
    policy_deny_public_ai    = "pa-deny-public-ai-${var.environment}"
  }
}
