variable "name"               { type = string }
variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "sku_name" {
  type        = string
  default     = "Developer_1"
  description = "APIM SKU. Developer_1 for non-prod, Premium_1 for production with zone redundancy."
}
variable "publisher_name" {
  type    = string
  default = "AI Platform Team"
}
variable "publisher_email" { type = string }
variable "subnet_id" {
  type        = string
  description = "Subnet ID for APIM VNet integration (api-management subnet)"
}
variable "pe_subnet_id" {
  type        = string
  default     = ""
  description = "Subnet ID for APIM private endpoint (private-endpoints subnet)"
}
variable "pe_name" {
  type    = string
  default = ""
}
variable "deploy_private_endpoint" {
  type    = bool
  default = true
}
variable "log_analytics_workspace_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}