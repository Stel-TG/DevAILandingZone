variable "name"               { type = string }
variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "sku_name" {
  type    = string
  default = "Basic"
}
variable "key_vault_id"            { type = string }
variable "storage_account_id"      { type = string }
variable "application_insights_id" { type = string }
variable "container_registry_id" {
  type    = string
  default = null
}
variable "log_analytics_workspace_id" {
  type    = string
  default = null
}
variable "allowed_subnet_ids" {
  type    = list(string)
  default = []
}
variable "deploy_cpu_cluster" {
  type    = bool
  default = true
}
variable "deploy_gpu_cluster" {
  type    = bool
  default = false
}
variable "cpu_cluster_vm_size" {
  type    = string
  default = "Standard_DS3_v2"
}
variable "cpu_cluster_max_nodes" {
  type    = number
  default = 4
}
variable "cpu_cluster_priority" {
  type    = string
  default = "LowPriority"
}
variable "gpu_cluster_vm_size" {
  type    = string
  default = "Standard_NC6s_v3"
}
variable "gpu_cluster_max_nodes" {
  type    = number
  default = 2
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "deploy_compute_instance" {
  type        = bool
  default     = true
  description = "Deploy an AML Compute Instance with no public IP into the aml-compute subnet."
}
variable "compute_instance_vm_size" {
  type        = string
  default     = "Standard_DS3_v2"
  description = "VM size for the AML Compute Instance used for interactive dev."
}
variable "aml_compute_subnet_id" {
  type        = string
  default     = null
  description = "Subnet ID for the AML Compute Instance NIC (aml-compute subnet)."
}
variable "admin_ssh_public_key" {
  type        = string
  default     = ""
  description = "SSH public key for Compute Instance access via jumpbox / Bastion."
}
variable "openai_resource_id" {
  type        = string
  default     = null
  description = "Azure OpenAI resource ID. Creates AML managed outbound PE rule."
}
variable "ai_search_resource_id" {
  type        = string
  default     = null
  description = "Azure AI Search resource ID. Creates AML managed outbound PE rule."
}
variable "cosmos_db_resource_id" {
  type        = string
  default     = null
  description = "Cosmos DB account resource ID. Creates AML managed outbound PE rule."
}