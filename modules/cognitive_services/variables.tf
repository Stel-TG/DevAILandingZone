variable "name"                       { type = string }
variable "resource_group_name"        { type = string }
variable "location"                   { type = string }
variable "sku_name"                   { type = string; default = "S0" }
variable "allowed_subnet_ids"         { type = list(string); default = [] }
variable "log_analytics_workspace_id" { type = string; default = null }
variable "tags"                       { type = map(string); default = {} }
