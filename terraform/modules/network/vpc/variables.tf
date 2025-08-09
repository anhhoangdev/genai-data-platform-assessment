variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "mtu" {
  description = "Maximum Transmission Unit for the VPC"
  type        = number
  default     = 1460
}

variable "subnets" {
  description = "Map of subnets to create"
  type = map(object({
    name                     = string
    cidr_range              = string
    region                  = string
    purpose                 = optional(string)
    private_ip_google_access = optional(bool, true)
    secondary_ranges = optional(list(object({
      range_name    = string
      ip_cidr_range = string
    })), [])
  }))
}
