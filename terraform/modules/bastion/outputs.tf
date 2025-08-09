output "instance_name" {
  description = "Bastion instance name"
  value       = google_compute_instance.bastion.name
}

output "internal_ip" {
  description = "Internal IP address of the bastion"
  value       = google_compute_instance.bastion.network_interface[0].network_ip
}

output "self_link" {
  description = "Self link of the bastion instance"
  value       = google_compute_instance.bastion.self_link
}


