variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Location for the KMS key ring"
  type        = string
}

variable "keyring_name" {
  description = "Name of the KMS key ring"
  type        = string
}

variable "key_name" {
  description = "Name of the KMS crypto key"
  type        = string
}

variable "rotation_period" {
  description = "Key rotation period in seconds (e.g., 7776000s for 90 days)"
  type        = string
  default     = "7776000s"
}

variable "key_iam_bindings" {
  description = "Additional IAM bindings for the crypto key"
  type = map(object({
    role   = string
    member = string
  }))
  default = {}
}
