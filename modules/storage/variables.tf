variable "name"                       { type = string }
variable "resource_group_name"        { type = string }
variable "location"                   { type = string }
variable "account_tier" {
  type    = string
  default = "Standard"
}
variable "account_replication_type" {
  type    = string
  default = "GRS"
}
variable "is_hns_enabled" {
  type    = bool
  default = true
}
variable "allowed_subnet_ids" {
  type    = list(string)
  default = []
}
variable "log_analytics_workspace_id" {
  type    = string
  default = null
}
variable "tags" {
  type    = map(string)
  default = {}
}
