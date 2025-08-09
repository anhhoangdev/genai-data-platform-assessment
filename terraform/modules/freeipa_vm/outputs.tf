output "instance_name" {
  description = "FreeIPA instance name"
  value       = google_compute_instance.freeipa.name
}

output "internal_ip" {
  description = "Internal IP address"
  value       = google_compute_instance.freeipa.network_interface[0].network_ip
}

output "fqdn" {
  description = "FQDN of the FreeIPA server"
  value       = "${var.hostname}.${var.domain}"
}

output "self_link" {
  description = "Self link of the FreeIPA instance"
  value       = google_compute_instance.freeipa.self_link
}


