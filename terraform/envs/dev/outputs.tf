output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

# Service account outputs
output "service_accounts" {
  description = "Created service accounts"
  value       = module.iam_service_accounts.service_accounts
  sensitive   = true
}

output "tf_cicd_service_account_email" {
  description = "Email of the Terraform CI/CD service account"
  value       = module.iam_service_accounts.emails["tf_cicd"]
}

# WIF outputs for GitHub Actions
output "wif_provider_name" {
  description = "Workload Identity Provider name for GitHub Actions"
  value       = module.wif.provider_name
}

output "wif_pool_name" {
  description = "Workload Identity Pool name"
  value       = module.wif.pool_name
}

# Network outputs
output "vpc_id" {
  description = "VPC network ID"
  value       = module.vpc.vpc_id
}

output "vpc_name" {
  description = "VPC network name"
  value       = module.vpc.vpc_name
}

output "subnets" {
  description = "Created subnets"
  value       = module.vpc.subnets
}

# Security outputs
output "kms_keyring_id" {
  description = "KMS keyring ID"
  value       = module.kms.keyring_id
}

output "kms_crypto_key_id" {
  description = "KMS crypto key ID"
  value       = module.kms.crypto_key_id
}

output "secret_ids" {
  description = "Created secret IDs"
  value       = module.secrets.secret_ids
  sensitive   = true
}

# DNS outputs
output "private_dns_zones" {
  description = "Created private DNS zones"
  value       = module.dns.private_zones
}

# Phase 1 preparation outputs
output "phase_1_inputs" {
  description = "Required inputs for Phase 1 deployment"
  value = {
    vpc_id                = module.vpc.vpc_id
    vpc_name              = module.vpc.vpc_name
    services_subnet_id    = module.vpc.subnets["services"].id
    workloads_subnet_id   = module.vpc.subnets["workloads"].id
    private_dns_zone_name = module.dns.private_zones["corp_internal"].name
    tf_service_account    = module.iam_service_accounts.emails["tf_cicd"]
    secrets = {
      freeipa_admin_password = module.secrets.secret_names["freeipa_admin_password"]
      ansible_vault_password = module.secrets.secret_names["ansible_vault_password"]
      ipa_enrollment_otp     = module.secrets.secret_names["ipa_enrollment_otp"]
    }
  }
}

# Phase 2 outputs (A02)
output "composer_environment_name" {
  value       = try(module.composer.name, null)
  description = "Name of the Cloud Composer environment"
}

output "composer_dag_gcs_prefix" {
  value       = try(module.composer.dag_gcs_prefix, null)
  description = "GCS prefix for Composer DAGs"
}

output "dataproc_staging_bucket" {
  value       = try(google_storage_bucket.dataproc_staging.name, null)
  description = "Name of the Dataproc staging bucket"
}

output "dev_dataproc_cluster_name" {
  value       = var.create_dev_dataproc_cluster ? try(google_dataproc_cluster.dev_cluster[0].name, null) : null
  description = "Name of the development Dataproc cluster (if created)"
}
