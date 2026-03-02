variable "name"                       { type = string }
variable "resource_group_name"        { type = string }
variable "location"                   { type = string }
variable "offer_type" {
  type    = string
  default = "Standard"
}
variable "kind" {
  type    = string
  default = "GlobalDocumentDB"
}
variable "consistency_level" {
  type    = string
  default = "Session"
}
variable "pe_subnet_id"               { type = string }
variable "pe_name"                    { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "databases" {
  type = map(object({ throughput = number; containers = list(string) }))
  default = {}
}
variable "tags" {
  type    = map(string)
  default = {}
}
