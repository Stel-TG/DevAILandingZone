variable "resource_group_id"   { type = string }
variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "allowed_locations"   { type = list(string) }
variable "environment"         { type = string }
variable "tags"                { type = map(string); default = {} }
