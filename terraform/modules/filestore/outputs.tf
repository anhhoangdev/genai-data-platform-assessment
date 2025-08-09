output "ip_address" {
  description = "Filestore IP address"
  value       = google_filestore_instance.nfs.networks[0].ip_addresses[0]
}

output "exports" {
  description = "Export paths"
  value = {
    home   = "/home"
    shared = "/shared"
  }
}


