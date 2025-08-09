terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_dns_record_set" "a_records" {
  for_each = { for r in var.a_records : r.name => r }

  managed_zone = var.zone_name
  name         = each.value.name
  type         = "A"
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas
}

resource "google_dns_record_set" "srv_records" {
  for_each = { for r in var.srv_records : r.name => r }

  managed_zone = var.zone_name
  name         = each.value.name
  type         = "SRV"
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas
}


