# Secrets Module

Creates Secret Manager secrets with CMEK encryption and IAM bindings.

## Usage

```hcl
module "secrets" {
  source     = "../../modules/secrets"
  project_id = var.project_id
  location   = var.region
  kms_key_id = module.kms.crypto_key_id
  
  secrets = {
    freeipa_admin_password = {
      labels = {
        env   = "dev"
        owner = "platform"
        type  = "authentication"
      }
      iam_bindings = [
        {
          role   = "roles/secretmanager.secretAccessor"
          member = "serviceAccount:${module.iam_service_accounts.emails["tf_cicd"]}"
        }
      ]
    }
    ansible_vault_password = {
      labels = {
        env   = "dev"
        owner = "platform"
        type  = "configuration"
      }
    }
  }
}
```

## Features

- CMEK encryption with provided KMS key
- User-managed replication
- Configurable IAM bindings per secret
- Labels for organization and compliance
- Optional initial values (ignored after creation)
