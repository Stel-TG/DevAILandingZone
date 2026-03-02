###############################################################################
# MODULE: AZURE POLICY — INPUT VARIABLES
###############################################################################

variable "resource_group_id" {
  description = "Resource ID of the resource group all policy assignments are scoped to."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group (used for display purposes)."
  type        = string
}

variable "location" {
  description = "Primary Azure region for the landing zone."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev | test | staging | prod). Used in policy names."
  type        = string
}

variable "allowed_locations" {
  description = "List of Azure regions permitted for resource deployment."
  type        = list(string)
  default     = ["canadacentral", "canadaeast", "eastus", "eastus2"]
}

variable "deny_public_access_effect" {
  description = <<-DESC
    Policy effect for all Deny Public Network Access assignments.

    "Deny"     — Block the resource operation at ARM if publicNetworkAccess
                 is not explicitly "Disabled". Use in prod.
    "Audit"    — Allow the operation but log a compliance violation. Use
                 when onboarding existing resources before enforcing Deny.
    "Disabled" — Policy assignments exist but take no action. Use for
                 break-glass / troubleshooting only.
  DESC
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Deny", "Audit", "Disabled"], var.deny_public_access_effect)
    error_message = "deny_public_access_effect must be Deny, Audit, or Disabled."
  }
}

variable "tags" {
  description = "Tags applied to any taggable policy resources."
  type        = map(string)
  default     = {}
}
