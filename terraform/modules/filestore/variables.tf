variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Filestore location (region or zone, e.g., us-central1)"
  type        = string
}

variable "name" {
  description = "Filestore instance name"
  type        = string
}

variable "tier" {
  description = "Filestore tier (ENTERPRISE or HIGH_SCALE_SSD)"
  type        = string
  default     = "ENTERPRISE"
}

variable "capacity_home_gb" {
  description = "Capacity for home export (GB)"
  type        = number
}

variable "capacity_shared_gb" {
  description = "Capacity for shared export (GB)"
  type        = number
}

variable "vpc_name" {
  description = "VPC network name"
  type        = string
}

variable "reserved_ip_range" {
  description = "Reserved IP range name for Filestore"
  type        = string
}

variable "allowed_cidrs" {
  description = "Allowed client CIDRs for NFS"
  type        = list(string)
}


