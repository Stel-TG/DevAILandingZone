variable "resource_group_name" { type = string }
variable "location"             { type = string }
variable "key_vault_name"       { type = string }
variable "tenant_id"            { type = string }
variable "sku_name" {
  type    = string
  default = "standard"
}
variable "soft_delete_retention_days" {
  type    = number
  default = 90
}
variable "purge_protection_enabled" {
  type    = bool
  default = true
}
variable "enable_rbac_authorization" {
  type    = bool
  default = true
}
variable "subnet_id"                  { type = string }
variable "private_dns_zone_id" {
  type    = string
  default = ""
}
variable "log_analytics_workspace_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}