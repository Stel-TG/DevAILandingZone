variable "name"                       { type = string }
variable "resource_group_name"        { type = string }
variable "location"                   { type = string }
variable "sku_name"                   { type = string; default = "Basic" }
variable "key_vault_id"               { type = string }
variable "storage_account_id"         { type = string }
variable "application_insights_id"    { type = string }
variable "container_registry_id"      { type = string; default = null }
variable "log_analytics_workspace_id" { type = string; default = null }
variable "allowed_subnet_ids"         { type = list(string); default = [] }
variable "deploy_cpu_cluster"         { type = bool; default = true }
variable "deploy_gpu_cluster"         { type = bool; default = false }
variable "cpu_cluster_vm_size"        { type = string; default = "Standard_DS3_v2" }
variable "cpu_cluster_max_nodes"      { type = number; default = 4 }
variable "cpu_cluster_priority"       { type = string; default = "LowPriority" }
variable "gpu_cluster_vm_size"        { type = string; default = "Standard_NC6s_v3" }
variable "gpu_cluster_max_nodes"      { type = number; default = 2 }
variable "tags"                       { type = map(string); default = {} }
