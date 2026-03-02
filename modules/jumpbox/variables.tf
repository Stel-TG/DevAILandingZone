variable "name"                 { type = string }
variable "nic_name"             { type = string }
variable "resource_group_name"  { type = string }
variable "location"             { type = string }
variable "subnet_id" {
  type        = string
  description = "Subnet ID for jump box NIC (jump-box subnet)"
}
variable "vm_size" {
  type    = string
  default = "Standard_B2ms"
}
variable "admin_username" {
  type    = string
  default = "azureuser"
}
variable "admin_ssh_public_key" {
  type        = string
  description = "SSH public key for admin access. Generate with: ssh-keygen -t rsa -b 4096"
}
variable "auto_shutdown_enabled" {
  type    = bool
  default = true
}
variable "auto_shutdown_time" {
  type    = string
  default = "2200"
}
variable "auto_shutdown_timezone" {
  type    = string
  default = "UTC"
}
variable "tags" {
  type    = map(string)
  default = {}
}
