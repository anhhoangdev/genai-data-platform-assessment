# Phase 2: A02 - Dask Compute Platform
# This file contains resources for ephemeral compute with Dask on Dataproc

# Service accounts for A02
module "phase2_service_accounts" {
  source     = "../../modules/iam_service_accounts"
  project_id = var.project_id

  service_accounts = {
    sa_composer = {
      display_name = "Composer Orchestrator"
      description  = "Service account for Cloud Composer environment"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/dataproc.editor",
        "roles/storage.objectViewer",
        "roles/compute.networkUser"
      ]
    }
    sa_dataproc_runtime = {
      display_name = "Dataproc Runtime"
      description  = "Service account for Dataproc cluster nodes"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/storage.objectViewer",
        "roles/dataproc.worker"
      ]
    }
  }

  depends_on = [module.apis]
}

# Allow Composer SA to impersonate Dataproc runtime SA
resource "google_service_account_iam_member" "composer_can_use_dataproc_sa" {
  service_account_id = module.phase2_service_accounts.service_accounts["sa_dataproc_runtime"].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${module.phase2_service_accounts.service_accounts["sa_composer"].email}"
}

# Private Cloud Composer 2 environment
module "composer" {
  source = "../../modules/composer"

  project_id            = var.project_id
  name                  = "${var.environment}-a02-composer"
  region                = var.region
  network_id            = module.vpc.vpc_id
  subnetwork_id         = module.vpc.subnets["services"].id
  service_account_email = module.phase2_service_accounts.service_accounts["sa_composer"].email
  kms_key_id            = module.kms.crypto_key_id

  environment_size = "ENVIRONMENT_SIZE_SMALL"
  image_version    = "composer-2.6.5-airflow-2.7.3"

  labels = {
    environment = var.environment
    phase       = "2"
    component   = "orchestration"
    task        = "a02"
  }

  depends_on = [
    module.vpc,
    module.kms,
    module.phase2_service_accounts
  ]
}

# GCS bucket for Dataproc staging and job files
resource "google_storage_bucket" "dataproc_staging" {
  name     = "${var.project_id}-dataproc-staging"
  project  = var.project_id
  location = var.region

  uniform_bucket_level_access = true
  
  encryption {
    default_kms_key_name = module.kms.crypto_key_id
  }

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment = var.environment
    phase       = "2"
    component   = "storage"
    task        = "a02"
  }

  depends_on = [module.kms]
}

# Grant Dataproc SA access to staging bucket
resource "google_storage_bucket_iam_member" "dataproc_staging_access" {
  bucket = google_storage_bucket.dataproc_staging.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.phase2_service_accounts.service_accounts["sa_dataproc_runtime"].email}"
}

# Grant Composer SA access to staging bucket
resource "google_storage_bucket_iam_member" "composer_staging_access" {
  bucket = google_storage_bucket.dataproc_staging.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.phase2_service_accounts.service_accounts["sa_composer"].email}"
}

# Optional: Create a sample Dataproc cluster for development/testing
# In production, clusters should be created ephemerally via Airflow DAGs
resource "google_dataproc_cluster" "dev_cluster" {
  count = var.create_dev_dataproc_cluster ? 1 : 0

  name    = "${var.environment}-dask-dev"
  project = var.project_id
  region  = var.region

  cluster_config {
    gce_cluster_config {
      subnetwork       = module.vpc.subnets["services"].self_link
      internal_ip_only = true
      service_account  = module.phase2_service_accounts.service_accounts["sa_dataproc_runtime"].email
      tags             = ["dataproc"]
      
      metadata = {
        # NFS mount configuration
        nfs_server      = module.filestore.ip_address
        nfs_export_dir  = "/export/shared"
        nfs_mount_point = "/mnt/shared"
      }
    }

    master_config {
      num_instances = 1
      machine_type  = "n2-standard-4"
      
      disk_config {
        boot_disk_type    = "pd-balanced"
        boot_disk_size_gb = 100
      }
    }

    worker_config {
      num_instances = 2
      machine_type  = "n2-standard-4"
      
      disk_config {
        boot_disk_type    = "pd-balanced"
        boot_disk_size_gb = 100
      }
    }

    # Initialization actions
    initialization_action {
      script      = "gs://goog-dataproc-initialization-actions-${var.region}/dask/dask.sh"
      timeout_sec = 600
    }

    initialization_action {
      script      = "gs://goog-dataproc-initialization-actions-${var.region}/nfs/nfs.sh"
      timeout_sec = 600
    }

    # Enable Component Gateway for web UIs
    endpoint_config {
      enable_http_port_access = true
    }

    # Software configuration
    software_config {
      properties = {
        "dataproc:dataproc.logging.stackdriver.enable"    = "true"
        "dataproc:dataproc.monitoring.stackdriver.enable" = "true"
      }
    }

    # Encryption configuration
    encryption_config {
      gce_pd_kms_key_name = module.kms.crypto_key_id
    }
  }

  labels = {
    environment = var.environment
    phase       = "2"
    component   = "compute"
    task        = "a02"
    purpose     = "development"
  }

  depends_on = [
    module.vpc,
    module.kms,
    module.phase2_service_accounts,
    module.filestore
  ]
}
