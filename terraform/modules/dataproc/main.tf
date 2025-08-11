terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_dataproc_cluster" "cluster" {
  name    = var.name
  project = var.project_id
  region  = var.region
  labels  = var.labels

  cluster_config {
    gce_cluster_config {
      subnetwork       = var.subnetwork_uri
      internal_ip_only = var.internal_ip_only
      service_account  = var.service_account_email
      tags             = var.tags
      metadata         = var.metadata
    }

    master_config {
      num_instances    = var.master_config.num_instances
      machine_type     = var.master_config.machine_type
      
      disk_config {
        boot_disk_type    = var.master_config.boot_disk_type
        boot_disk_size_gb = var.master_config.boot_disk_size_gb
      }
    }

    worker_config {
      num_instances    = var.worker_config.num_instances
      machine_type     = var.worker_config.machine_type
      
      disk_config {
        boot_disk_type    = var.worker_config.boot_disk_type
        boot_disk_size_gb = var.worker_config.boot_disk_size_gb
      }
    }

    # Initialization actions
    dynamic "initialization_action" {
      for_each = var.init_actions
      content {
        script      = initialization_action.value
        timeout_sec = 600
      }
    }

    # Enable Component Gateway for web UIs
    endpoint_config {
      enable_http_port_access = var.enable_component_gateway
    }

    # Software configuration
    software_config {
      properties = merge(
        {
          "dataproc:dataproc.logging.stackdriver.enable"    = "true"
          "dataproc:dataproc.monitoring.stackdriver.enable" = "true"
        },
        var.software_properties
      )
    }

    # Encryption configuration
    dynamic "encryption_config" {
      for_each = var.kms_key_id != null ? [1] : []
      content {
        gce_pd_kms_key_name = var.kms_key_id
      }
    }
  }
}
