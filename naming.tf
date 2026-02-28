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
    # ── Core infrastructure ───────────────────────────────────────────────────
    resource_group          = "rg-${var.project_name}-${var.environment}-${var.location_short}"
    virtual_network         = "vnet-${var.project_name}-${var.environment}-${var.location_short}"
    network_security_group  = "nsg-${var.project_name}-${var.environment}-${var.location_short}"
    network_watcher         = "nw-${var.project_name}-${var.environment}-${var.location_short}"
    route_table             = "rt-${var.project_name}-${var.environment}-${var.location_short}"

    # ── Monitoring and observability ──────────────────────────────────────────
    log_analytics_workspace = "law-${var.project_name}-${var.environment}-${var.location_short}"
    application_insights    = "appi-${var.project_name}-${var.environment}-${var.location_short}"
    monitor_action_group    = "ag-${var.project_name}-${var.environment}-${var.location_short}"

    # ── Security and identity ─────────────────────────────────────────────────
    key_vault               = "kv-${var.project_name}-${var.environment}-${var.location_short}"
    purview_account         = "pview-${var.project_name}-${var.environment}-${var.location_short}"

    # User-assigned managed identities (per workload)
    managed_identity_foundry  = "id-foundry-${var.project_name}-${var.environment}-${var.location_short}"
    managed_identity_apps     = "id-apps-${var.project_name}-${var.environment}-${var.location_short}"
    managed_identity_build    = "id-build-${var.project_name}-${var.environment}-${var.location_short}"

    # ── Storage (no hyphens allowed, max 24 chars lowercase alphanumeric) ─────
    storage_account         = lower(replace("st${var.project_name}${var.environment}${var.location_short}", "-", ""))
    storage_account_foundry = lower(replace("stfnd${var.project_name}${var.environment}${var.location_short}", "-", ""))
    container_registry      = lower(replace("cr${var.project_name}${var.environment}${var.location_short}", "-", ""))

    # ── AI and ML services ────────────────────────────────────────────────────
    machine_learning_workspace = "mlw-${var.project_name}-${var.environment}-${var.location_short}"
    cognitive_services         = "ais-${var.project_name}-${var.environment}-${var.location_short}"
    openai_service             = "oai-${var.project_name}-${var.environment}-${var.location_short}"

    # ── AI Foundry ────────────────────────────────────────────────────────────
    # AI Foundry hub (azurerm_ai_foundry) — umbrella resource
    ai_foundry_hub            = "aif-${var.project_name}-${var.environment}-${var.location_short}"
    # AI Foundry Project — logical grouping of models, connections, agents
    ai_foundry_project        = "aifp-${var.project_name}-${var.environment}-${var.location_short}"
    # AI Foundry Agent Service — hosts and runs Foundry agents
    ai_foundry_agent_service  = "aifas-${var.project_name}-${var.environment}-${var.location_short}"

    # ── AI Search ─────────────────────────────────────────────────────────────
    ai_search                 = "srch-${var.project_name}-${var.environment}-${var.location_short}"

    # ── Cosmos DB ─────────────────────────────────────────────────────────────
    cosmos_db_account         = "cosmos-${var.project_name}-${var.environment}-${var.location_short}"

    # ── Container App Environment and microservices ───────────────────────────
    container_app_environment = "cae-${var.project_name}-${var.environment}-${var.location_short}"
    container_app_frontend    = "ca-frontend-${var.project_name}-${var.environment}-${var.location_short}"
    container_app_orchestrator= "ca-orchestrator-${var.project_name}-${var.environment}-${var.location_short}"
    container_app_sk          = "ca-sk-${var.project_name}-${var.environment}-${var.location_short}"
    container_app_mcp         = "ca-mcp-${var.project_name}-${var.environment}-${var.location_short}"
    container_app_ingestion   = "ca-ingestion-${var.project_name}-${var.environment}-${var.location_short}"

    # ── App Configuration ─────────────────────────────────────────────────────
    app_configuration         = "appcs-${var.project_name}-${var.environment}-${var.location_short}"

    # ── API Management ────────────────────────────────────────────────────────
    api_management            = "apim-${var.project_name}-${var.environment}-${var.location_short}"

    # ── Application Gateway / WAF ─────────────────────────────────────────────
    app_gateway               = "agw-${var.project_name}-${var.environment}-${var.location_short}"
    app_gateway_waf_policy    = "wafpol-${var.project_name}-${var.environment}-${var.location_short}"
    app_gateway_public_ip     = "pip-agw-${var.project_name}-${var.environment}-${var.location_short}"

    # ── Jump box ─────────────────────────────────────────────────────────────
    jumpbox_vm                = "vm-jumpbox-${var.project_name}-${var.environment}-${var.location_short}"
    jumpbox_nic               = "nic-jumpbox-${var.project_name}-${var.environment}-${var.location_short}"
    jumpbox_nsg               = "nsg-jumpbox-${var.project_name}-${var.environment}-${var.location_short}"

    # ── Build agent ───────────────────────────────────────────────────────────
    build_agent_vm            = "vm-build-${var.project_name}-${var.environment}-${var.location_short}"
    build_agent_nic           = "nic-build-${var.project_name}-${var.environment}-${var.location_short}"
    build_agent_nsg           = "nsg-build-${var.project_name}-${var.environment}-${var.location_short}"

    # ── Private endpoints ─────────────────────────────────────────────────────
    pe_key_vault              = "pe-kv-${var.project_name}-${var.environment}-${var.location_short}"
    pe_storage_blob           = "pe-stblob-${var.project_name}-${var.environment}-${var.location_short}"
    pe_storage_file           = "pe-stfile-${var.project_name}-${var.environment}-${var.location_short}"
    pe_storage_dfs            = "pe-stdfs-${var.project_name}-${var.environment}-${var.location_short}"
    pe_container_registry     = "pe-cr-${var.project_name}-${var.environment}-${var.location_short}"
    pe_machine_learning       = "pe-mlw-${var.project_name}-${var.environment}-${var.location_short}"
    pe_cognitive_services     = "pe-ais-${var.project_name}-${var.environment}-${var.location_short}"
    pe_openai                 = "pe-oai-${var.project_name}-${var.environment}-${var.location_short}"
    pe_log_analytics          = "pe-law-${var.project_name}-${var.environment}-${var.location_short}"
    pe_ai_foundry             = "pe-aif-${var.project_name}-${var.environment}-${var.location_short}"
    pe_ai_search              = "pe-srch-${var.project_name}-${var.environment}-${var.location_short}"
    pe_cosmos_db              = "pe-cosmos-${var.project_name}-${var.environment}-${var.location_short}"
    pe_app_configuration      = "pe-appcs-${var.project_name}-${var.environment}-${var.location_short}"
    pe_apim                   = "pe-apim-${var.project_name}-${var.environment}-${var.location_short}"
    pe_container_app_env      = "pe-cae-${var.project_name}-${var.environment}-${var.location_short}"

    # ── AML Compute (no-public-IP interactive dev) ────────────────────────────
    aml_compute_instance      = "ci-dev-${var.project_name}-${var.environment}-${var.location_short}"

    # ── Policy assignments ────────────────────────────────────────────────────
    policy_allowed_locations  = "pa-allowed-locations-${var.environment}"
    policy_required_tags      = "pa-required-tags-${var.environment}"
    policy_deny_public_ai     = "pa-deny-public-ai-${var.environment}"
  }
}
