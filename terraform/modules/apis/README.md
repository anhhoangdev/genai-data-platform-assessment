# APIs Module

Enables required GCP APIs for the data platform foundation.

## Usage

```hcl
module "apis" {
  source     = "../../modules/apis"
  project_id = var.project_id
  services   = var.required_services
}
```

## APIs Enabled

- Service Usage API
- Cloud Resource Manager API
- IAM API
- IAM Credentials API
- Security Token Service API
- Secret Manager API
- Cloud KMS API
- Compute Engine API
- Cloud DNS API
- Filestore API
- Cloud IAP API
- Cloud Logging API
- Cloud Monitoring API
