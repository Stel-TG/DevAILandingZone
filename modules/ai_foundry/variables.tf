variable "resource_group_name"          { type = string }
variable "location"                       { type = string }
variable "hub_name"                       { type = string }
variable "project_name"                   { type = string }
variable "managed_identity_name"          { type = string }
variable "agent_service_name"             { type = string }
variable "sku"                            { type = string; default = "Basic" }
variable "storage_account_id"             { type = string }
variable "key_vault_id"                   { type = string }
variable "application_insights_id"        { type = string }
variable "log_analytics_workspace_id"     { type = string }
variable "pe_subnet_id"                   { type = string }
variable "pe_name"                        { type = string }
variable "container_app_environment_id"   { type = string; default = "" }
variable "openai_endpoint"                { type = string; default = "" }
variable "openai_resource_id"             { type = string; default = "" }
variable "ai_search_endpoint"             { type = string; default = "" }
variable "ai_search_id"                   { type = string; default = "" }
variable "cosmos_db_endpoint"             { type = string; default = "" }
variable "agent_service_image"            { type = string; default = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest" }
variable "tags"                           { type = map(string); default = {} }
