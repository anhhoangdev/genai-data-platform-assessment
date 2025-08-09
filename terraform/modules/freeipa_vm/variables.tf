variable "name" {
  description = "Instance name"
  type        = string
}

variable "hostname" {
  description = "Host shortname (will be combined with domain)"
  type        = string
}

variable "domain" {
  description = "DNS domain (e.g., corp.internal)"
  type        = string
}

variable "realm" {
  description = "Kerberos realm (e.g., CORP.INTERNAL)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "zone" {
  description = "Compute zone"
  type        = string
}

variable "subnetwork_self_link" {
  description = "Self link of the subnetwork"
  type        = string
}

variable "machine_type" {
  description = "Machine type"
  type        = string
}

variable "image_family" {
  description = "Image family for Ubuntu"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "image_project" {
  description = "Project hosting the image family"
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "boot_disk_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

variable "boot_disk_type" {
  description = "Boot disk type"
  type        = string
  default     = "pd-balanced"
}

variable "service_account_email" {
  description = "Service account email"
  type        = string
}

variable "startup_script" {
  description = "Metadata startup script"
  type        = string
  default     = <<-EOT
#!/usr/bin/env bash
set -euo pipefail
curl -sS https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh | bash -s -- --also-install
apt-get update -y
apt-get install -y chrony
touch /var/tmp/ansible_ready
EOT
}

variable "enable_os_login" {
  description = "Enable OS Login"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Additional labels"
  type        = map(string)
  default     = {}
}

variable "additional_tags" {
  description = "Additional network tags"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "dev"
}

variable "metadata" {
  description = "Additional instance metadata"
  type        = map(string)
  default     = {}
}


