variable "resource_group_name"  { type = string }
variable "location"              { type = string }
variable "foundry_identity_name" { type = string }
variable "apps_identity_name"    { type = string }
variable "build_identity_name"   { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}