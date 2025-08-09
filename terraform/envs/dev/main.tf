terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
module "apis" {
  source     = "../../modules/apis"
  project_id = var.project_id
  services   = var.required_services
}

# Create KMS resources for CMEK
module "kms" {
  source     = "../../modules/kms"
  project_id = var.project_id
  location   = var.region

  keyring_name = var.kms.keyring_name
  key_name     = var.kms.key_name

  depends_on = [module.apis]
}

# Create service accounts
module "iam_service_accounts" {
  source     = "../../modules/iam_service_accounts"
  project_id = var.project_id

  service_accounts = var.service_accounts

  depends_on = [module.apis]
}

# Setup Workload Identity Federation
module "wif" {
  source     = "../../modules/wif"
  project_id = var.project_id

  pool_id                      = var.wif.pool_id
  provider_id                  = var.wif.provider_id
  pool_display_name            = var.wif.pool_display_name
  provider_display_name        = var.wif.provider_display_name
  attribute_condition          = var.wif.attribute_condition
  target_service_account_email = module.iam_service_accounts.emails["tf_cicd"]

  depends_on = [module.iam_service_accounts]
}

# Create secrets with CMEK encryption
module "secrets" {
  source     = "../../modules/secrets"
  project_id = var.project_id
  location   = var.region
  kms_key_id = module.kms.crypto_key_id

  secrets = {
    for secret_name, secret_config in var.secrets : secret_name => {
      labels = secret_config.labels
      iam_bindings = [
        {
          role   = "roles/secretmanager.secretAccessor"
          member = "principalSet://iam.googleapis.com/${module.wif.pool_name}/*"
        }
      ]
    }
  }

  depends_on = [module.kms, module.wif]
}

# Create VPC and subnets
module "vpc" {
  source     = "../../modules/network/vpc"
  project_id = var.project_id
  vpc_name   = var.network.vpc_name
  subnets    = var.network.subnets

  depends_on = [module.apis]
}

# Create firewall rules
module "firewall" {
  source     = "../../modules/network/firewall"
  project_id = var.project_id
  vpc_name   = module.vpc.vpc_name

  firewall_rules = var.network.firewall_rules

  depends_on = [module.vpc]
}

# Create Cloud NAT for private instances
module "nat" {
  source     = "../../modules/network/nat"
  project_id = var.project_id
  region     = var.region
  vpc_id     = module.vpc.vpc_id

  router_name = var.network.nat.router_name
  nat_name    = var.network.nat.nat_name

  depends_on = [module.vpc]
}

# Create private DNS zones
module "dns" {
  source     = "../../modules/network/dns"
  project_id = var.project_id
  vpc_id     = module.vpc.vpc_id

  private_zones = var.network.dns.private_zones
  dns_records   = var.network.dns.dns_records

  depends_on = [module.vpc]
}
