variable "name_prefix" {
  description = "Name prefix for the instance template"
  type        = string
}

variable "machine_type" {
  description = "Machine type"
  type        = string
}

variable "subnetwork_self_link" {
  description = "Subnetwork self link"
  type        = string
}

variable "service_account_email" {
  description = "Service account email"
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

variable "startup_script" {
  description = "Startup script"
  type        = string
  default     = <<-EOT
#!/usr/bin/env bash
set -euo pipefail
curl -sS https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh | bash -s -- --also-install
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip git tmux htop unzip curl jq
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
  description = "Additional metadata"
  type        = map(string)
  default     = {}
}


