variable "zone_name" {
  description = "Private managed zone name"
  type        = string
}

variable "a_records" {
  description = "List of A records"
  type = list(object({
    name    = string
    ttl     = number
    rrdatas = list(string)
  }))
  default = []
}

variable "srv_records" {
  description = "List of SRV records"
  type = list(object({
    name    = string
    ttl     = number
    rrdatas = list(string)
  }))
  default = []
}


