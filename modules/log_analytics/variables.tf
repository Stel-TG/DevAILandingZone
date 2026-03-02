variable "name" {
  type        = string
  description = "Name of the Log Analytics Workspace."
}
variable "resource_group_name" {
  type        = string
  description = "Resource group for the workspace."
}
variable "location" {
  type        = string
  description = "Azure region."
}
variable "sku" {
  type        = string
  default     = "PerGB2018"
  description = "Pricing SKU."
}
variable "retention_days" {
  type        = number
  default     = 90
  description = "Data retention in days."
}
variable "enable_security_center_solution" {
  type    = bool
  default = true
}
variable "enable_container_insights_solution" {
  type    = bool
  default = true
}
variable "tags" {
  type    = map(string)
  default = {}
}