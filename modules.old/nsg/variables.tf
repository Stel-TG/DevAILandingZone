variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "vnet_name"           { type = string }
variable "subnets"             { type = map(any) }
variable "subnet_ids"          { type = map(string); default = {} }
variable "tags"                { type = map(string); default = {} }
