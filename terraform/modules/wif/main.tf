resource "google_iam_workload_identity_pool" "pool" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = var.pool_display_name
  description               = var.pool_description
}

resource "google_iam_workload_identity_pool_provider" "provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = var.provider_display_name
  description                        = var.provider_description
  
  attribute_mapping   = var.attribute_mapping
  attribute_condition = var.attribute_condition
  
  oidc {
    issuer_uri = var.issuer_uri
  }
}

resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = var.target_service_account_email
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.pool.name}/${var.principal_set_filter}"
}
