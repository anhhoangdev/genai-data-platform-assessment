resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = var.vpc_name
  auto_create_subnetworks = false
  mtu                     = var.mtu

  routing_mode = "REGIONAL"
}

resource "google_compute_subnetwork" "subnets" {
  for_each = var.subnets

  project       = var.project_id
  name          = each.value.name
  ip_cidr_range = each.value.cidr_range
  region        = each.value.region
  network       = google_compute_network.vpc.id

  purpose                  = lookup(each.value, "purpose", null)
  private_ip_google_access = lookup(each.value, "private_ip_google_access", true)

  dynamic "secondary_ip_range" {
    for_each = lookup(each.value, "secondary_ranges", [])
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
}
