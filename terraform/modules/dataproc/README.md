# Dataproc Module

This module creates a Dataproc cluster configured for private IP operation with optional Dask support.

## Features

- Private IP only configuration
- Component Gateway for web UI access
- Initialization actions support (Dask, NFS, etc.)
- KMS encryption support
- Stackdriver logging and monitoring enabled by default

## Usage

```hcl
module "dataproc" {
  source = "./modules/dataproc"

  project_id            = var.project_id
  name                  = "dask-cluster"
  region                = var.region
  subnetwork_uri        = module.vpc.subnets["services"].self_link
  service_account_email = module.iam_service_accounts.emails["sa_dataproc_runtime"]
  
  master_config = {
    num_instances    = 1
    machine_type     = "n2-standard-4"
    boot_disk_type   = "pd-balanced"
    boot_disk_size_gb = 100
  }
  
  worker_config = {
    num_instances    = 2
    machine_type     = "n2-standard-4"
    boot_disk_type   = "pd-balanced"
    boot_disk_size_gb = 100
  }
  
  init_actions = [
    "gs://goog-dataproc-initialization-actions-${var.region}/dask/dask.sh",
    "gs://goog-dataproc-initialization-actions-${var.region}/nfs/nfs.sh"
  ]
  
  metadata = {
    nfs_server      = module.filestore.ip_address
    nfs_export_dir  = "/export/shared"
    nfs_mount_point = "/mnt/shared"
  }
  
  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "dask-compute"
  }
}
```

## Note on Ephemeral Clusters

This module can be used to create a persistent cluster for development/testing, but in production, 
clusters should be created ephemerally via Airflow/Composer DAGs using the DataprocCreateClusterOperator.
