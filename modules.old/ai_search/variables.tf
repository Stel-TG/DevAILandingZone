variable "name"                        { type = string }
variable "resource_group_name"         { type = string }
variable "location"                    { type = string }
variable "sku"                         { type = string; default = "standard" }
variable "replica_count"               { type = number; default = 1 }
variable "partition_count"             { type = number; default = 1 }
variable "pe_subnet_id"                { type = string }
variable "pe_name"                     { type = string }
variable "log_analytics_workspace_id"  { type = string }
variable "tags"                        { type = map(string); default = {} }
