variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "firewall_rules" {
  description = "List of firewall rules to create"
  type = list(object({
    name          = string
    direction     = string
    priority      = number
    source_ranges = optional(list(string))
    target_tags   = optional(list(string))
    source_tags   = optional(list(string))
    allow = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
    deny = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
  }))
  default = []
}
