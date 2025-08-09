variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "service_accounts" {
  description = "Map of service accounts to create with their roles"
  type = map(object({
    display_name = string
    description  = optional(string, "")
    roles        = list(string)
  }))
  default = {}
}
