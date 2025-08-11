# Dask Cluster on GCP Dataproc

This directory contains the implementation of task A02 - Scalable Python Job Cluster using Dask on Google Cloud Dataproc.

## Overview

The solution provides:
- Ephemeral Dataproc clusters with Dask for distributed computing
- Cloud Composer (Airflow) orchestration
- Private IP configuration with no public internet exposure
- Integration with existing A01 infrastructure (VPC, Filestore, IAM)
- Cost optimization through auto-scaling and ephemeral resources

## Directory Structure

```
dask-cluster/
├── dags/                         # Airflow DAGs for Composer
│   ├── dask_dataproc_ephemeral.py    # Basic ephemeral cluster pattern
│   └── dask_dataproc_autoscale.py    # Advanced autoscaling pattern
├── jobs/                         # Python jobs that run on Dataproc
│   ├── dask_yarn_example.py          # Simple Dask job example
│   └── dask_large_scale_processing.py # Complex processing with adaptive scaling
└── README.md                     # This file
```

## Architecture

The solution integrates with the existing A01 infrastructure:

1. **Orchestration**: Cloud Composer in the `management` subnet
2. **Compute**: Ephemeral Dataproc clusters in the `services` subnet
3. **Storage**: Access to Filestore (NFS) and GCS buckets
4. **Security**: Private IPs only, CMEK encryption, WIF authentication

## Deployment

### Prerequisites

1. Complete A01 infrastructure deployment
2. Enable required APIs:
   ```bash
   gcloud services enable composer.googleapis.com dataproc.googleapis.com
   ```

### Terraform Deployment

1. Navigate to the Terraform environment:
   ```bash
   cd terraform/envs/dev
   ```

2. Initialize and plan:
   ```bash
   terraform init
   terraform plan -target=module.phase2_service_accounts -target=module.composer -target=google_storage_bucket.dataproc_staging
   ```

3. Apply Phase 2 resources:
   ```bash
   terraform apply -target=module.phase2_service_accounts -target=module.composer -target=google_storage_bucket.dataproc_staging
   ```

### Upload DAGs and Jobs

1. Get the Composer DAGs bucket:
   ```bash
   export DAGS_BUCKET=$(terraform output -raw composer_dag_gcs_prefix)
   ```

2. Upload DAGs:
   ```bash
   gsutil cp dask-cluster/dags/*.py ${DAGS_BUCKET}dags/
   ```

3. Upload job scripts:
   ```bash
   export STAGING_BUCKET=$(terraform output -raw dataproc_staging_bucket)
   gsutil cp dask-cluster/jobs/*.py gs://${STAGING_BUCKET}/jobs/
   ```

## Usage

### Running a Basic Dask Job

1. Access Composer UI (via IAP or Cloud Console)
2. Trigger the `dask_dataproc_ephemeral` DAG
3. Monitor progress in Airflow UI
4. Access Dask dashboard via Dataproc Component Gateway

### Configuring Jobs

DAGs use Airflow variables for configuration:
- `gcp_project_id`: Your GCP project ID
- `gcp_region`: Deployment region
- `dataproc_staging_bucket`: Staging bucket name
- `subnetwork_services_uri`: Services subnet URI
- `dataproc_runtime_sa_email`: Dataproc service account email
- `filestore_ip_address`: Filestore IP for NFS mounting

### Monitoring

1. **Airflow UI**: DAG execution status
2. **Dataproc UI**: Cluster status and Component Gateway
3. **Cloud Logging**: Application and system logs
4. **Cloud Monitoring**: Metrics and alerts

## Security Considerations

- All clusters use private IPs only
- No service account keys - uses Workload Identity Federation
- CMEK encryption for all data at rest
- Network isolation via VPC and firewall rules
- IAM roles follow principle of least privilege

## Cost Optimization

- Clusters are ephemeral - created per job and deleted after
- Autoscaling based on workload
- Preemptible workers can be configured for non-critical jobs
- Staging bucket has 7-day lifecycle policy

## Troubleshooting

### Common Issues

1. **Cluster creation fails**: Check subnet permissions and quotas
2. **Job submission fails**: Verify staging bucket permissions
3. **NFS mount fails**: Check Filestore export settings
4. **Dask connection issues**: Ensure YARN ports are not blocked

### Debug Commands

```bash
# Check Composer environment
gcloud composer environments describe a02-composer --location=us-central1

# List Dataproc clusters
gcloud dataproc clusters list --region=us-central1

# View cluster logs
gcloud logging read "resource.type=cloud_dataproc_cluster" --limit=50
```

## Next Steps

1. Create production autoscaling policies
2. Implement job-specific cluster configurations
3. Add monitoring dashboards and alerts
4. Integrate with CI/CD for job deployment
