terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_composer_environment" "composer" {
  name    = var.name
  project = var.project_id
  region  = var.region
  labels  = var.labels

  config {
    software_config {
      image_version = var.image_version
    }

    environment_size = var.environment_size

    node_config {
      network         = var.network_id
      subnetwork      = var.subnetwork_id
      service_account = var.service_account_email

      # Enable private Google access
      # This is inherited from subnet configuration
    }

    private_environment_config {
      enable_private_endpoint                = true
      cloud_sql_ipv4_cidr_block              = var.private_ip_ranges.cloud_sql_ipv4_cidr_block
      web_server_ipv4_cidr_block             = var.private_ip_ranges.web_server_ipv4_cidr_block
      cloud_composer_network_ipv4_cidr_block = var.private_ip_ranges.cloud_composer_network_ipv4_cidr_block
      master_ipv4_cidr_block                 = var.private_ip_ranges.master_ipv4_cidr_block
    }

    encryption_config {
      kms_key_name = var.kms_key_id
    }
  }
}
