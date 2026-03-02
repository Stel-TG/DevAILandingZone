variable "name"               { type = string }
variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "sku" {
  type    = string
  default = "standard"
}
variable "pe_name"                    { type = string }
variable "pe_subnet_id"               { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "apps_identity_principal_id" {
  type    = string
  default = ""
}
variable "tags" {
  type    = map(string)
  default = {}
}