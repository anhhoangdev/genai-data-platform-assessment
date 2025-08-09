output "pool_name" {
  description = "Full name of the Workload Identity Pool"
  value       = google_iam_workload_identity_pool.pool.name
}

output "provider_name" {
  description = "Full name of the Workload Identity Provider"
  value       = google_iam_workload_identity_pool_provider.provider.name
}

output "pool_id" {
  description = "ID of the Workload Identity Pool"
  value       = google_iam_workload_identity_pool.pool.workload_identity_pool_id
}

output "provider_id" {
  description = "ID of the Workload Identity Provider"
  value       = google_iam_workload_identity_pool_provider.provider.workload_identity_pool_provider_id
}
