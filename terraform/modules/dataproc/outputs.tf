output "name" {
  description = "The name of the Dataproc cluster"
  value       = google_dataproc_cluster.cluster.name
}

output "id" {
  description = "The ID of the Dataproc cluster"
  value       = google_dataproc_cluster.cluster.id
}

output "master_instance_names" {
  description = "List of master instance names"
  value       = google_dataproc_cluster.cluster.cluster_config[0].master_config[0].instance_names
}

output "worker_instance_names" {
  description = "List of worker instance names"
  value       = try(google_dataproc_cluster.cluster.cluster_config[0].worker_config[0].instance_names, [])
}

output "config_bucket" {
  description = "The GCS bucket used for cluster config and temp data"
  value       = google_dataproc_cluster.cluster.cluster_config[0].bucket
}

output "cluster_uuid" {
  description = "The cluster UUID"
  value       = google_dataproc_cluster.cluster.cluster_uuid
}
