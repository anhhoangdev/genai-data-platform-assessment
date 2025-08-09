# KMS Module

Creates a KMS key ring and crypto key for Customer-Managed Encryption Keys (CMEK).

## Usage

```hcl
module "kms" {
  source     = "../../modules/kms"
  project_id = var.project_id
  location   = var.region
  
  keyring_name = "sec-core"
  key_name     = "secrets-cmek"
  
  key_iam_bindings = {
    terraform_sa = {
      role   = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
      member = "serviceAccount:${module.iam_service_accounts.emails["tf_cicd"]}"
    }
  }
}
```

## Features

- Automatic 90-day key rotation by default
- Secret Manager service agent access automatically granted
- Lifecycle protection to prevent accidental key deletion
- Additional IAM bindings configurable
