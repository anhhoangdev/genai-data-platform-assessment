variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "required_services" {
  description = "List of GCP APIs to enable"
  type        = list(string)
  default = [
    "serviceusage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "file.googleapis.com",
    "iap.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com"
  ]
}

variable "kms" {
  description = "KMS configuration"
  type = object({
    keyring_name = string
    key_name     = string
  })
  default = {
    keyring_name = "sec-core"
    key_name     = "secrets-cmek"
  }
}

variable "service_accounts" {
  description = "Service accounts to create"
  type = map(object({
    display_name = string
    description  = optional(string, "")
    roles        = list(string)
  }))
  default = {
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

variable "wif" {
  description = "Workload Identity Federation configuration"
  type = object({
    pool_id               = string
    provider_id           = string
    pool_display_name     = optional(string)
    provider_display_name = optional(string)
    attribute_condition   = string
  })
  default = {
    pool_id               = "github-pool"
    provider_id           = "github-provider"
    pool_display_name     = "GitHub Actions Pool"
    provider_display_name = "GitHub Actions Provider"
    attribute_condition   = "attribute.repository == \"your-org/your-repo\""
  }
}

variable "secrets" {
  description = "Secrets to create in Secret Manager"
  type = map(object({
    labels = map(string)
  }))
  default = {
    freeipa_admin_password = {
      labels = {
        env   = "dev"
        owner = "platform"
        type  = "authentication"
      }
    }
    ansible_vault_password = {
      labels = {
        env   = "dev"
        owner = "platform"
        type  = "configuration"
      }
    }
    ipa_enrollment_otp = {
      labels = {
        env   = "dev"
        owner = "platform"
        type  = "authentication"
      }
    }
  }
}

variable "network" {
  description = "Network configuration"
  type = object({
    vpc_name = string
    subnets = map(object({
      name                     = string
      cidr_range               = string
      region                   = string
      private_ip_google_access = optional(bool, true)
    }))
    firewall_rules = list(object({
      name          = string
      direction     = string
      priority      = number
      source_ranges = optional(list(string))
      target_tags   = optional(list(string))
      source_tags   = optional(list(string))
      allow = optional(list(object({
        protocol = string
        ports    = optional(list(string))
      })), [])
      deny = optional(list(object({
        protocol = string
        ports    = optional(list(string))
      })), [])
    }))
    nat = object({
      router_name = string
      nat_name    = string
    })
    dns = object({
      private_zones = map(object({
        dns_name    = string
        description = optional(string, "Private DNS zone")
      }))
      dns_records = map(object({
        zone_key = string
        name     = string
        type     = string
        ttl      = number
        rrdatas  = list(string)
      }))
    })
  })
  default = {
    vpc_name = "vpc-data-platform"
    subnets = {
      services = {
        name                     = "subnet-services"
        cidr_range               = "10.10.1.0/24"
        region                   = "us-central1"
        private_ip_google_access = true
      }
      workloads = {
        name                     = "subnet-workloads"
        cidr_range               = "10.10.2.0/24"
        region                   = "us-central1"
        private_ip_google_access = true
      }
    }
    firewall_rules = [
      {
        name          = "deny-all-ingress"
        direction     = "INGRESS"
        priority      = 65534
        source_ranges = ["0.0.0.0/0"]
        target_tags   = ["vm-managed"]
        deny = [
          {
            protocol = "all"
          }
        ]
      },
      {
        name          = "allow-iap-ssh-bastion"
        direction     = "INGRESS"
        priority      = 1000
        source_ranges = ["35.235.240.0/20"]
        target_tags   = ["bastion"]
        allow = [
          {
            protocol = "tcp"
            ports    = ["22"]
          }
        ]
      },
      {
        name        = "allow-ssh-bastion-to-workers"
        direction   = "INGRESS"
        priority    = 1100
        source_tags = ["bastion"]
        target_tags = ["worker"]
        allow = [
          {
            protocol = "tcp"
            ports    = ["22"]
          }
        ]
      },
      {
        name          = "allow-freeipa-services"
        direction     = "INGRESS"
        priority      = 1200
        source_ranges = ["10.10.1.0/24", "10.10.2.0/24"]
        target_tags   = ["freeipa"]
        allow = [
          {
            protocol = "tcp"
            ports    = ["53", "88", "389", "443", "464", "636"]
          },
          {
            protocol = "udp"
            ports    = ["53", "88", "464"]
          }
        ]
      }
    ]
    nat = {
      router_name = "router-data-platform"
      nat_name    = "nat-data-platform"
    }
    dns = {
      private_zones = {
        corp_internal = {
          dns_name    = "corp.internal."
          description = "Private zone for platform services"
        }
      }
      dns_records = {
        # Phase 1 TODO: Add DNS records for VMs after creation
      }
    }
  }
}
