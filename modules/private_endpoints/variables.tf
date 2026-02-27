variable "resource_group_name"  { type = string }
variable "location"             { type = string }
variable "subnet_id"            { type = string }
variable "hub_vnet_id"          { type = string }
variable "key_vault_id"         { type = string; default = null }
variable "storage_account_id"   { type = string; default = null }
variable "container_registry_id" { type = string; default = null }
variable "machine_learning_id"  { type = string; default = null }
variable "cognitive_services_id" { type = string; default = null }
variable "openai_id"            { type = string; default = null }
variable "log_analytics_id"     { type = string; default = null }
variable "tags"                 { type = map(string); default = {} }
