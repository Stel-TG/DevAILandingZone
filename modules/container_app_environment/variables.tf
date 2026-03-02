variable "name"                         { type = string }
variable "resource_group_name"           { type = string }
variable "location"                      { type = string }
variable "subnet_id" {
  type        = string
  description = "Subnet ID for CAE VNet integration (container-app-environment subnet)"
}
variable "pe_subnet_id" {
  type        = string
  description = "Subnet ID for the CAE private endpoint (private-endpoints subnet)"
}
variable "pe_name"                       { type = string }
variable "log_analytics_workspace_id"    { type = string }

variable "apps_identity_id" {
  type        = string
  description = "Resource ID of the user-assigned managed identity for microservices"
}
variable "apps_identity_client_id" {
  type        = string
  description = "Client ID of the apps managed identity (used in env vars)"
}

# Microservice app names
variable "frontend_app_name"     { type = string }
variable "orchestrator_app_name" { type = string }
variable "sk_app_name"           { type = string }
variable "mcp_app_name"          { type = string }
variable "ingestion_app_name"    { type = string }

# Container images — point to your Container Registry
variable "frontend_image" {
  type    = string
  default = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}
variable "orchestrator_image" {
  type    = string
  default = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}
variable "sk_image" {
  type    = string
  default = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}
variable "mcp_image" {
  type    = string
  default = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}
variable "ingestion_image" {
  type    = string
  default = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

# Service endpoints wired to microservices at runtime
variable "openai_endpoint" {
  type    = string
  default = ""
}
variable "ai_search_endpoint" {
  type    = string
  default = ""
}
variable "cosmos_db_endpoint" {
  type    = string
  default = ""
}
variable "storage_endpoint" {
  type    = string
  default = ""
}
variable "app_insights_connection_string" {
  type    = string
  default = ""
}
variable "app_configuration_endpoint" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
