variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
}

variable "pool_display_name" {
  description = "Display name for the Workload Identity Pool"
  type        = string
  default     = null
}

variable "pool_description" {
  description = "Description for the Workload Identity Pool"
  type        = string
  default     = "Workload Identity Pool for CI/CD"
}

variable "provider_id" {
  description = "Workload Identity Provider ID"
  type        = string
}

variable "provider_display_name" {
  description = "Display name for the Workload Identity Provider"
  type        = string
  default     = null
}

variable "provider_description" {
  description = "Description for the Workload Identity Provider"
  type        = string
  default     = "OIDC provider for GitHub Actions"
}

variable "issuer_uri" {
  description = "OIDC issuer URI"
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "attribute_mapping" {
  description = "Attribute mapping for the OIDC provider"
  type        = map(string)
  default = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }
}

variable "attribute_condition" {
  description = "Attribute condition to restrict access"
  type        = string
}

variable "principal_set_filter" {
  description = "Principal set filter for the workload identity binding"
  type        = string
  default     = "*"
}

variable "target_service_account_email" {
  description = "Email of the service account to grant workload identity access to"
  type        = string
}
