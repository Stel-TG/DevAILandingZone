variable "vnet_name"           { type = string }
variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "vnet_address_space"  { type = list(string) }
variable "hub_vnet_id"         { type = string }
variable "hub_vnet_name"       { type = string }
variable "hub_resource_group"  { type = string }
variable "hub_subscription_id" { type = string }
variable "subnets" {
  type = map(object({
    address_prefix    = string
    service_endpoints = list(string)
  }))
}
variable "tags" {
  type    = map(string)
  default = {}
}
