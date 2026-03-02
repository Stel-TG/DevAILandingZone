variable "resource_group_id" { type = string }
variable "machine_learning_id" {
  type    = string
  default = null
}
variable "storage_account_id" {
  type    = string
  default = null
}
variable "key_vault_id" {
  type    = string
  default = null
}
variable "openai_id" {
  type    = string
  default = null
}
variable "data_scientist_group_id" {
  type    = string
  default = null
}
variable "ml_engineer_group_id" {
  type    = string
  default = null
}
variable "data_engineer_group_id" {
  type    = string
  default = null
}
variable "ai_app_developer_group_id" {
  type    = string
  default = null
}
variable "platform_admin_group_id" {
  type    = string
  default = null
}
variable "rbac_assignments" {
  type    = list(any)
  default = []
}