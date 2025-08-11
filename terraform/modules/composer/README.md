# Cloud Composer Module

This module creates a private Cloud Composer 2 environment for orchestrating data workflows.

## Features

- Private IP configuration with no public endpoint
- KMS encryption support
- Configurable environment size
- Private Service Connect for secure access

## Usage

```hcl
module "composer" {
  source = "./modules/composer"

  project_id            = var.project_id
  name                  = "data-platform-composer"
  region                = var.region
  network_id            = module.vpc.vpc_id
  subnetwork_id         = module.vpc.subnets["management"].id
  service_account_email = module.iam_service_accounts.emails["sa_composer"]
  kms_key_id            = module.kms.crypto_key_id
  
  environment_size = "ENVIRONMENT_SIZE_SMALL"
  image_version    = "composer-2.6.5-airflow-2.7.3"
  
  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}
```

## Private IP Ranges

The module uses the following default private IP ranges:
- Cloud SQL: 10.20.0.0/24
- Web Server: 10.20.1.0/28
- Composer Network: 10.20.2.0/24
- Master: 10.20.3.0/28

These can be customized via the `private_ip_ranges` variable.
