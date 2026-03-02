variable "resource_group_name"        { type = string }
variable "location"                   { type = string }
variable "subnet_id"                  { type = string; default = "" }
variable "private_dns_zone_id"        { type = string; default = "" }
variable "private_dns_zone_ids"       { type = map(string); default = {} }
variable "log_analytics_workspace_id" { type = string; default = "" }
variable "tags"                       { type = map(string); default = {} }
