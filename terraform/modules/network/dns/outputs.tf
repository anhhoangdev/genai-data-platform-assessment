output "private_zones" {
  description = "Map of created private DNS zones"
  value = {
    for k, zone in google_dns_managed_zone.private_zones : k => {
      name     = zone.name
      dns_name = zone.dns_name
      id       = zone.id
    }
  }
}

output "dns_records" {
  description = "Map of created DNS records"
  value = {
    for k, record in google_dns_record_set.records : k => {
      name    = record.name
      type    = record.type
      ttl     = record.ttl
      rrdatas = record.rrdatas
    }
  }
}
