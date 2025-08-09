terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_compute_health_check" "ssh" {
  name               = "${var.name}-ssh-hc"
  check_interval_sec = 10
  timeout_sec        = 5
  tcp_health_check {
    port = 22
  }
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

resource "google_compute_region_instance_group_manager" "mig" {
  name                      = var.name
  base_instance_name        = var.name
  region                    = var.region
  distribution_policy_zones = var.zones

  version {
    instance_template = var.instance_template_self_link
  }

  target_size = var.target_size

  auto_healing_policies {
    health_check      = google_compute_health_check.ssh.self_link
    initial_delay_sec = 60
  }
}

resource "google_compute_region_autoscaler" "autoscaler" {
  name   = "${var.name}-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.mig.self_link

  autoscaling_policy {
    min_replicas    = var.min_replicas
    max_replicas    = var.max_replicas
    cooldown_period = 60
    cpu_utilization {
      target = var.cpu_target_utilization
    }
  }
}

output "mig_name" {
  value = google_compute_region_instance_group_manager.mig.name
}


