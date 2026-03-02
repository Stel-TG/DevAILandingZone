variable "name"                         { type = string }
variable "nic_name"                      { type = string }
variable "resource_group_name"           { type = string }
variable "location"                      { type = string }
variable "subnet_id"                     { type = string; description = "Subnet ID for build agent NIC (build-agent subnet)" }
variable "build_identity_id"             { type = string; description = "Resource ID of the user-assigned managed identity for the build agent" }
variable "build_identity_principal_id"   { type = string; description = "Principal ID of the build identity for RBAC assignments" }
variable "vm_size"                       { type = string; default = "Standard_D4s_v5" }
variable "admin_username"                { type = string; default = "azureuser" }
variable "admin_ssh_public_key"          { type = string; description = "SSH public key for admin access" }
variable "auto_shutdown_enabled"         { type = bool;   default = true }
variable "auto_shutdown_time"            { type = string; default = "2200" }
variable "auto_shutdown_timezone"        { type = string; default = "UTC" }
variable "container_registry_id"         { type = string; default = "" }
variable "container_app_environment_id"  { type = string; default = "" }
variable "tags"                          { type = map(string); default = {} }
