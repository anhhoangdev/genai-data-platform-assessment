variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Location for secret replication"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for CMEK encryption"
  type        = string
}

variable "secrets" {
  description = "Map of secrets to create"
  type = map(object({
    labels        = optional(map(string), {})
    initial_value = optional(string, null)
    iam_bindings = optional(list(object({
      role   = string
      member = string
    })), [])
  }))
  default = {}
}
