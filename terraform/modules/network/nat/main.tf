resource "google_compute_router" "router" {
  project = var.project_id
  name    = var.router_name
  region  = var.region
  network = var.vpc_id
}

resource "google_compute_router_nat" "nat" {
  project = var.project_id
  name    = var.nat_name
  router  = google_compute_router.router.name
  region  = var.region
  
  nat_ip_allocate_option             = var.nat_ip_allocate_option
  source_subnetwork_ip_ranges_to_nat = var.source_subnetwork_ip_ranges_to_nat
  
  dynamic "subnetwork" {
    for_each = var.subnetworks
    content {
      name                    = subnetwork.value.name
      source_ip_ranges_to_nat = subnetwork.value.source_ip_ranges_to_nat
    }
  }
  
  log_config {
    enable = var.enable_logging
    filter = var.log_filter
  }
}
