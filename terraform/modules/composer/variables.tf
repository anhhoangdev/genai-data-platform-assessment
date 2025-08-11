variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name" {
  description = "Composer environment name"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "network_id" {
  description = "VPC network ID"
  type        = string
}

variable "subnetwork_id" {
  description = "Subnetwork ID for Composer nodes"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for Composer"
  type        = string
}

variable "environment_size" {
  description = "Environment size (ENVIRONMENT_SIZE_SMALL, ENVIRONMENT_SIZE_MEDIUM, ENVIRONMENT_SIZE_LARGE)"
  type        = string
  default     = "ENVIRONMENT_SIZE_SMALL"
}

variable "image_version" {
  description = "Composer image version"
  type        = string
  default     = "composer-2.6.5-airflow-2.7.3"
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "private_ip_ranges" {
  description = "Private IP ranges for Composer components"
  type = object({
    cloud_sql_ipv4_cidr_block              = string
    web_server_ipv4_cidr_block             = string
    cloud_composer_network_ipv4_cidr_block = string
    master_ipv4_cidr_block                 = string
  })
  default = {
    cloud_sql_ipv4_cidr_block              = "10.20.0.0/24"
    web_server_ipv4_cidr_block             = "10.20.1.0/28"
    cloud_composer_network_ipv4_cidr_block = "10.20.2.0/24"
    master_ipv4_cidr_block                 = "10.20.3.0/28"
  }
}

variable "labels" {
  description = "Labels to apply to the environment"
  type        = map(string)
  default     = {}
}
