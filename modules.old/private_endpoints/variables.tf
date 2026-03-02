variable "resource_group_name"  { type = string }
variable "location"             { type = string }
variable "subnet_id"            { type = string }
variable "hub_vnet_id"          { type = string }
variable "tags"                 { type = map(string); default = {} }

# ── Core services ──────────────────────────────────────────────────────────────
variable "key_vault_id"          { type = string; default = null; description = "Key Vault resource ID. null = skip PE." }
variable "storage_account_id"    { type = string; default = null; description = "Storage Account resource ID. null = skip PE." }
variable "container_registry_id" { type = string; default = null; description = "Container Registry resource ID. null = skip PE." }

# ── AI / ML services ───────────────────────────────────────────────────────────
variable "machine_learning_id"   { type = string; default = null; description = "AML Workspace resource ID. null = skip PE." }
variable "cognitive_services_id" { type = string; default = null; description = "Cognitive Services account resource ID. null = skip PE." }
variable "openai_id"             { type = string; default = null; description = "Azure OpenAI resource ID. null = skip PE." }
variable "ai_foundry_id"         { type = string; default = null; description = "AI Foundry Hub (AML workspace) resource ID. null = skip PE." }

# ── AI Foundry dependencies ────────────────────────────────────────────────────
variable "ai_search_id"          { type = string; default = null; description = "Azure AI Search resource ID. null = skip PE." }
variable "cosmos_db_id"          { type = string; default = null; description = "Cosmos DB account resource ID. null = skip PE." }

# ── GenAI app dependencies ─────────────────────────────────────────────────────
variable "app_configuration_id"  { type = string; default = null; description = "App Configuration store resource ID. null = skip PE." }

# ── Ingress and observability ──────────────────────────────────────────────────
variable "log_analytics_id"      { type = string; default = null; description = "Log Analytics Workspace resource ID. null = skip PE." }
variable "api_management_id"     { type = string; default = null; description = "API Management service resource ID. null = skip PE." }
