variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name" {
  description = "Dataproc cluster name"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "subnetwork_uri" {
  description = "Subnetwork URI for cluster nodes"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for cluster nodes"
  type        = string
}

variable "master_config" {
  description = "Master node configuration"
  type = object({
    num_instances    = number
    machine_type     = string
    boot_disk_type   = string
    boot_disk_size_gb = number
  })
  default = {
    num_instances    = 1
    machine_type     = "n2-standard-4"
    boot_disk_type   = "pd-balanced"
    boot_disk_size_gb = 100
  }
}

variable "worker_config" {
  description = "Worker node configuration"
  type = object({
    num_instances    = number
    machine_type     = string
    boot_disk_type   = string
    boot_disk_size_gb = number
  })
  default = {
    num_instances    = 2
    machine_type     = "n2-standard-4"
    boot_disk_type   = "pd-balanced"
    boot_disk_size_gb = 100
  }
}

variable "init_actions" {
  description = "List of initialization actions"
  type        = list(string)
  default     = []
}

variable "metadata" {
  description = "Metadata for cluster nodes"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Network tags for cluster nodes"
  type        = list(string)
  default     = ["dataproc"]
}

variable "labels" {
  description = "Labels to apply to the cluster"
  type        = map(string)
  default     = {}
}

variable "software_properties" {
  description = "Software configuration properties"
  type        = map(string)
  default     = {}
}

variable "enable_component_gateway" {
  description = "Enable Component Gateway for web UIs"
  type        = bool
  default     = true
}

variable "internal_ip_only" {
  description = "Use internal IPs only (no public IPs)"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}
