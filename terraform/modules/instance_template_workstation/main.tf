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

resource "google_compute_instance_template" "tpl" {
  name_prefix  = var.name_prefix
  machine_type = var.machine_type

  tags = concat(["vm-managed", "worker", "workstation"], var.additional_tags)

  disk {
    source_image = data.google_compute_image.ubuntu.self_link
    disk_size_gb = var.boot_disk_gb
    disk_type    = var.boot_disk_type
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = var.subnetwork_self_link
    # No access_config block = no public IP
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = merge(var.metadata, {
    enable-oslogin = var.enable_os_login ? "TRUE" : "FALSE"
  })

  metadata_startup_script = var.startup_script

  labels = merge({
    role        = "workstation",
    environment = var.environment
  }, var.labels)
}

output "instance_template_self_link" {
  value = google_compute_instance_template.tpl.self_link
}


