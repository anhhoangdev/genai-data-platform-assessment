output "name" {
  description = "The name of the Composer environment"
  value       = google_composer_environment.composer.name
}

output "id" {
  description = "The ID of the Composer environment"
  value       = google_composer_environment.composer.id
}

output "gke_cluster" {
  description = "The GKE cluster used by the Composer environment"
  value       = google_composer_environment.composer.config[0].gke_cluster
}

output "airflow_uri" {
  description = "The URI of the Apache Airflow Web UI hosted within the environment (private endpoint)"
  value       = google_composer_environment.composer.config[0].airflow_uri
}

output "dag_gcs_prefix" {
  description = "The DAGs folder GCS prefix"
  value       = google_composer_environment.composer.config[0].dag_gcs_prefix
}
