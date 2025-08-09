# Workload Identity Federation Module

Creates a Workload Identity Pool and Provider for secure CI/CD access without service account keys.

## Usage

```hcl
module "wif" {
  source     = "../../modules/wif"
  project_id = var.project_id
  
  pool_id     = "github-pool"
  provider_id = "github-provider"
  
  attribute_condition           = "attribute.repository == \"org/repo\""
  target_service_account_email  = module.iam_service_accounts.emails["tf_cicd"]
}
```

## GitHub Actions Setup

After applying this module, configure your GitHub repository with the following secrets:

- `WIF_PROVIDER`: The provider name output
- `WIF_SERVICE_ACCOUNT`: The target service account email

Then use in your workflow:

```yaml
- id: auth
  uses: google-github-actions/auth@v1
  with:
    workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
    service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
```
