# IAM Service Accounts Module

Creates service accounts with project-level IAM role bindings.

## Usage

```hcl
module "iam_service_accounts" {
  source     = "../../modules/iam_service_accounts"
  project_id = var.project_id
  
  service_accounts = {
    tf_cicd = {
      display_name = "Terraform CI/CD"
      description  = "Service account for Terraform operations in CI/CD"
      roles = [
        "roles/serviceusage.serviceUsageAdmin",
        "roles/iam.serviceAccountAdmin",
        "roles/iam.workloadIdentityPoolAdmin",
        "roles/secretmanager.admin",
        "roles/cloudkms.admin",
        "roles/compute.networkAdmin",
        "roles/dns.admin"
      ]
    }
  }
}
```

## Notes

- Roles are bound at the project level
- Service account emails are output for use in other modules
- Use least privilege principle and review roles regularly
