# Variables for Phase 2 (A02 - Dask Compute Platform)

variable "create_dev_dataproc_cluster" {
  description = "Whether to create a development Dataproc cluster (for testing)"
  type        = bool
  default     = false
}

variable "composer_config" {
  description = "Cloud Composer configuration"
  type = object({
    environment_size = string
    image_version    = string
    private_ip_ranges = object({
      cloud_sql_ipv4_cidr_block              = string
      web_server_ipv4_cidr_block             = string
      cloud_composer_network_ipv4_cidr_block = string
      master_ipv4_cidr_block                 = string
    })
  })
  default = {
    environment_size = "ENVIRONMENT_SIZE_SMALL"
    image_version    = "composer-2.6.5-airflow-2.7.3"
    private_ip_ranges = {
      cloud_sql_ipv4_cidr_block              = "10.20.0.0/24"
      web_server_ipv4_cidr_block             = "10.20.1.0/28"
      cloud_composer_network_ipv4_cidr_block = "10.20.2.0/24"
      master_ipv4_cidr_block                 = "10.20.3.0/28"
    }
  }
}

variable "dataproc_staging_bucket_name" {
  description = "Name for the Dataproc staging bucket (will be prefixed with project ID)"
  type        = string
  default     = "dataproc-staging"
}
