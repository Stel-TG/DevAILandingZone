variable "name"                                { type = string }
variable "resource_group_name"                 { type = string }
variable "location"                            { type = string }
variable "public_ip_name"                      { type = string }
variable "waf_policy_name"                     { type = string }
variable "subnet_id"                           { type = string; description = "Subnet ID for Application Gateway (application-gateway subnet)" }
variable "log_analytics_workspace_id"          { type = string }

variable "capacity"                            { type = number; default = 2 }
variable "autoscale_min"                       { type = number; default = 2 }
variable "autoscale_max"                       { type = number; default = 10 }

variable "apim_private_ip_addresses"           { type = list(string); default = [] }
variable "apim_gateway_hostname"               { type = string; default = "" }
variable "host_names"                          { type = list(string); default = [] }

variable "ssl_certificate_key_vault_secret_id" {
  type        = string
  default     = ""
  description = "Key Vault secret ID for the TLS certificate PFX. Leave empty to skip SSL cert binding (dev)."
}

variable "gateway_identity_id" {
  type        = string
  description = "User-assigned managed identity resource ID. Needs Key Vault Certificate User role for SSL cert access."
}

variable "tags" { type = map(string); default = {} }
