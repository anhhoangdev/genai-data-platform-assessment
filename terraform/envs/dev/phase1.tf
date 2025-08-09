locals {
  services_subnet_self_link  = module.vpc.subnets["services"].self_link
  workloads_subnet_self_link = module.vpc.subnets["workloads"].self_link
  workloads_cidr             = module.vpc.subnets["workloads"].cidr_range
  services_cidr              = module.vpc.subnets["services"].cidr_range
}

# Service accounts for Phase 1
module "phase1_service_accounts" {
  source     = "../../modules/iam_service_accounts"
  project_id = var.project_id

  service_accounts = {
    sa_bastion = {
      display_name = "Bastion Instance SA"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ]
    }
    sa_freeipa = {
      display_name = "FreeIPA Instance SA"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ]
    }
    sa_workstation = {
      display_name = "Workstation Instance SA"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ]
    }
  }
}

# Secret-level IAM bindings
resource "google_secret_manager_secret_iam_member" "freeipa_admin_secret_access" {
  secret_id = module.secrets.secret_ids["freeipa_admin_password"]
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.phase1_service_accounts.service_accounts["sa_freeipa"].email}"
}

resource "google_secret_manager_secret_iam_member" "ipa_enrollment_otp_access" {
  secret_id = module.secrets.secret_ids["ipa_enrollment_otp"]
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.phase1_service_accounts.service_accounts["sa_workstation"].email}"
}

# Bastion instance
module "bastion" {
  source               = "../../modules/bastion"
  name                 = var.bastion.name
  zone                 = var.bastion.zone
  subnetwork_self_link = local.services_subnet_self_link
  machine_type         = var.bastion.machine_type
  service_account_email = module.phase1_service_accounts.service_accounts["sa_bastion"].email
  additional_tags      = var.bastion.additional_tags
}

# FreeIPA VM
module "freeipa" {
  source               = "../../modules/freeipa_vm"
  name                 = var.freeipa.name
  hostname             = var.freeipa.hostname
  domain               = var.freeipa.domain
  realm                = var.freeipa.realm
  region               = var.region
  zone                 = var.freeipa.zone
  subnetwork_self_link = local.services_subnet_self_link
  machine_type         = var.freeipa.machine_type
  service_account_email = module.phase1_service_accounts.service_accounts["sa_freeipa"].email
  additional_tags      = var.freeipa.additional_tags
}

# Filestore NFS
module "filestore" {
  source              = "../../modules/filestore"
  project_id          = var.project_id
  location            = var.region
  name                = var.filestore.name
  tier                = var.filestore.tier
  capacity_home_gb    = var.filestore.capacity_home_gb
  capacity_shared_gb  = var.filestore.capacity_shared_gb
  vpc_name            = module.vpc.vpc_name
  reserved_ip_range   = var.filestore.reserved_ip_range
  allowed_cidrs       = [local.workloads_cidr, local.services_cidr]
}

# Workstation instance template
module "workstation_template" {
  source               = "../../modules/instance_template_workstation"
  name_prefix          = var.workstation.name_prefix
  machine_type         = var.workstation.machine_type
  subnetwork_self_link = local.workloads_subnet_self_link
  service_account_email = module.phase1_service_accounts.service_accounts["sa_workstation"].email
  additional_tags      = var.workstation.additional_tags
}

# Workstation MIG
module "workstation_mig" {
  source                      = "../../modules/mig_workstation"
  name                        = "${var.workstation.name_prefix}-mig"
  region                      = var.region
  zones                       = var.zones
  instance_template_self_link = module.workstation_template.instance_template_self_link
  target_size                 = var.workstation.target_size
  min_replicas                = var.workstation.min_replicas
  max_replicas                = var.workstation.max_replicas
  cpu_target_utilization      = var.workstation.cpu_target
}

# DNS records (A and SRV)
module "dns_records" {
  source    = "../../modules/dns_records"
  zone_name = module.dns.private_zones["corp_internal"].name

  a_records = [
    {
      name    = "ipa.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = [module.freeipa.internal_ip]
    },
    {
      name    = "bastion.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = [module.bastion.internal_ip]
    },
    {
      name    = "nfs.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = [module.filestore.ip_address]
    }
  ]

  srv_records = [
    {
      name    = "_kerberos._udp.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = ["0 0 88 ipa.${var.freeipa.domain}."]
    },
    {
      name    = "_kerberos._tcp.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = ["0 0 88 ipa.${var.freeipa.domain}."]
    },
    {
      name    = "_ldap._tcp.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = ["0 0 389 ipa.${var.freeipa.domain}."]
    }
  ]
}

# Allow Google health checks to reach SSH on workers
resource "google_compute_firewall" "allow_hc_to_workers" {
  name    = "allow-hc-ssh-workers"
  network = module.vpc.vpc_name

  direction = "INGRESS"
  priority  = 1150

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["worker"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}


