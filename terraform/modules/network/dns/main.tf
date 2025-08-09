resource "google_dns_managed_zone" "private_zones" {
  for_each = var.private_zones

  project     = var.project_id
  name        = each.key
  dns_name    = each.value.dns_name
  description = each.value.description

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = var.vpc_id
    }
  }

  dynamic "forwarding_config" {
    for_each = lookup(each.value, "forwarding_config", null) != null ? [each.value.forwarding_config] : []
    content {
      dynamic "target_name_servers" {
        for_each = forwarding_config.value.target_name_servers
        content {
          ipv4_address    = target_name_servers.value.ipv4_address
          forwarding_path = lookup(target_name_servers.value, "forwarding_path", null)
        }
      }
    }
  }
}

resource "google_dns_record_set" "records" {
  for_each = var.dns_records

  project      = var.project_id
  managed_zone = google_dns_managed_zone.private_zones[each.value.zone_key].name
  name         = each.value.name
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas
}
