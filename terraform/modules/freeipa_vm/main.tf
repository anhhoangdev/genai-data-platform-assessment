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

resource "google_compute_address" "ip_internal" {
  name         = "${var.name}-ip"
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork_self_link
  region       = var.region
}

resource "google_compute_instance" "freeipa" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone

  tags = concat(["vm-managed", "freeipa"], var.additional_tags)

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
    network_ip = google_compute_address.ip_internal.address
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = merge(var.metadata, {
    enable-oslogin = var.enable_os_login ? "TRUE" : "FALSE"
    hostname       = "${var.hostname}.${var.domain}"
  })

  # Use cloud-init to prepare the system; IPA install handled via Ansible to avoid secrets in state
  metadata_startup_script = var.startup_script

  labels = merge({
    role        = "freeipa",
    environment = var.environment
  }, var.labels)
}


