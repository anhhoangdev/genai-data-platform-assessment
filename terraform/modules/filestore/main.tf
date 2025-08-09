terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_filestore_instance" "nfs" {
  name     = var.name
  project  = var.project_id
  location = var.location
  tier     = var.tier

  file_shares {
    name        = "export"
    capacity_gb = var.capacity_home_gb + var.capacity_shared_gb
    nfs_export_options {
      ip_ranges   = var.allowed_cidrs
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }

  networks {
    network           = var.vpc_name
    modes             = ["MODE_IPV4"]
    reserved_ip_range = var.reserved_ip_range
  }
}


