terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

data "google_compute_image" "ubuntu" {
  family  = var.image_family
  project = var.image_project
}

resource "google_compute_instance" "bastion" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone

  tags = concat(["vm-managed", "bastion"], var.additional_tags)

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = var.boot_disk_gb
      type  = var.boot_disk_type
    }
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  network_interface {
    subnetwork = var.subnetwork_self_link
    # No public IP
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = merge(var.metadata, {
    enable-oslogin = var.enable_os_login ? "TRUE" : "FALSE"
  })

  metadata_startup_script = var.startup_script

  labels = merge({
    role        = "bastion",
    environment = var.environment
  }, var.labels)
}


