variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC network for private DNS zones"
  type        = string
}

variable "private_zones" {
  description = "Map of private DNS zones to create"
  type = map(object({
    dns_name    = string
    description = optional(string, "Private DNS zone")
    forwarding_config = optional(object({
      target_name_servers = list(object({
        ipv4_address    = string
        forwarding_path = optional(string)
      }))
    }))
  }))
  default = {}
}

variable "dns_records" {
  description = "Map of DNS records to create"
  type = map(object({
    zone_key = string
    name     = string
    type     = string
    ttl      = number
    rrdatas  = list(string)
  }))
  default = {}
}
