output "vpc_id" {
  description = "ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "vpc_self_link" {
  description = "Self link of the VPC network"
  value       = google_compute_network.vpc.self_link
}

output "subnets" {
  description = "Map of subnet details"
  value = {
    for k, subnet in google_compute_subnetwork.subnets : k => {
      id         = subnet.id
      name       = subnet.name
      self_link  = subnet.self_link
      cidr_range = subnet.ip_cidr_range
      region     = subnet.region
    }
  }
}
