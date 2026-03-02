variable "resource_group_name"        { type = string }
variable "location"                    { type = string }
variable "subscription_id"             { type = string }
variable "network_watcher_name"        { type = string }
variable "log_analytics_workspace_id"  { type = string }
variable "security_contact_emails" {
  type    = list(string)
  default = []
}
variable "deploy_purview" {
  type    = bool
  default = false
}
variable "purview_account_name" {
  type    = string
  default = ""
}
variable "tags" {
  type    = map(string)
  default = {}
}
