variable "zones" {
  description = "Zones used for Phase 1 resources"
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b"]
}

variable "bastion" {
  description = "Bastion configuration"
  type = object({
    name            = string
    zone            = string
    machine_type    = string
    additional_tags = optional(list(string), [])
  })
  default = {
    name         = "bastion"
    zone         = "us-central1-a"
    machine_type = "e2-small"
  }
}

variable "freeipa" {
  description = "FreeIPA configuration"
  type = object({
    name            = string
    hostname        = string
    domain          = string
    realm           = string
    zone            = string
    machine_type    = string
    additional_tags = optional(list(string), [])
  })
  default = {
    name         = "freeipa"
    hostname     = "ipa"
    domain       = "corp.internal"
    realm        = "CORP.INTERNAL"
    zone         = "us-central1-a"
    machine_type = "e2-standard-4"
  }
}

variable "workstation" {
  description = "Workstation pool configuration"
  type = object({
    name_prefix     = string
    machine_type    = string
    min_replicas    = number
    target_size     = number
    max_replicas    = number
    cpu_target      = number
    additional_tags = optional(list(string), [])
  })
  default = {
    name_prefix  = "ws"
    machine_type = "e2-standard-4"
    min_replicas = 0
    target_size  = 3
    max_replicas = 10
    cpu_target   = 0.6
  }
}

variable "filestore" {
  description = "Filestore configuration"
  type = object({
    name               = string
    tier               = string
    capacity_home_gb   = number
    capacity_shared_gb = number
    reserved_ip_range  = string
  })
  default = {
    name               = "fs-nfs"
    tier               = "ENTERPRISE"
    capacity_home_gb   = 2048
    capacity_shared_gb = 2048
    reserved_ip_range  = "filestore-reserved"
  }
}


