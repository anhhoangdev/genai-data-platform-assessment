"""
Ephemeral Dask on Dataproc DAG

This DAG demonstrates the pattern for running Dask workloads on ephemeral Dataproc clusters:
1. Create a private IP Dataproc cluster with Dask initialization
2. Submit a Python job that uses dask-yarn for distributed computing
3. Delete the cluster upon completion

The cluster is configured with:
- Private IP only (no public IPs)
- Component Gateway for Dask dashboard access
- NFS mount for shared storage (Filestore)
- Stackdriver logging and monitoring
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.google.cloud.operators.dataproc import (
    DataprocCreateClusterOperator,
    DataprocDeleteClusterOperator,
    DataprocSubmitJobOperator,
)
from airflow.utils.trigger_rule import TriggerRule

# Configuration
PROJECT_ID = "{{ var.value.gcp_project_id }}"
REGION = "{{ var.value.gcp_region }}"
STAGING_BUCKET = "{{ var.value.dataproc_staging_bucket }}"
SUBNETWORK_URI = "{{ var.value.subnetwork_services_uri }}"  # projects/<proj>/regions/<region>/subnetworks/services
SERVICE_ACCOUNT_EMAIL = "{{ var.value.dataproc_runtime_sa_email }}"
FILESTORE_IP = "{{ var.value.filestore_ip_address }}"

# Dynamic cluster name with timestamp to ensure uniqueness
CLUSTER_NAME = "dask-{{ ds_nodash }}-{{ ts_nodash | lower | replace(':', '') }}"

# Cluster configuration
CLUSTER_CONFIG = {
    "gce_cluster_config": {
        "subnetwork_uri": SUBNETWORK_URI,
        "internal_ip_only": True,
        "service_account": SERVICE_ACCOUNT_EMAIL,
        "tags": ["dataproc"],
        "metadata": {
            # NFS mount configuration for Filestore
            "nfs_server": FILESTORE_IP,
            "nfs_export_dir": "/export/shared",
            "nfs_mount_point": "/mnt/shared"
        }
    },
    "master_config": {
        "num_instances": 1,
        "machine_type_uri": "n2-standard-4",
        "disk_config": {
            "boot_disk_type": "pd-balanced",
            "boot_disk_size_gb": 100
        }
    },
    "worker_config": {
        "num_instances": 2,  # Start with 2 workers, can scale via dask-yarn
        "machine_type_uri": "n2-standard-4",
        "disk_config": {
            "boot_disk_type": "pd-balanced",
            "boot_disk_size_gb": 100
        }
    },
    "initialization_actions": [
        {
            "executable_file": f"gs://goog-dataproc-initialization-actions-{REGION}/dask/dask.sh",
            "execution_timeout": "10m"
        },
        {
            "executable_file": f"gs://goog-dataproc-initialization-actions-{REGION}/nfs/nfs.sh",
            "execution_timeout": "10m"
        }
    ],
    "endpoint_config": {
        "enable_http_port_access": True  # Enable Component Gateway
    },
    "software_config": {
        "properties": {
            # Enable Stackdriver logging and monitoring
            "dataproc:dataproc.logging.stackdriver.enable": "true",
            "dataproc:dataproc.monitoring.stackdriver.enable": "true",
            # Dask-specific configurations
            "dask:dask.scheduler.port": "8786",
            "dask:dask.dashboard.port": "8787"
        }
    }
}

# Job configuration - runs a Dask job via PySpark submit
DASK_JOB = {
    "reference": {"project_id": PROJECT_ID},
    "placement": {"cluster_name": CLUSTER_NAME},
    "pyspark_job": {
        "main_python_file_uri": f"gs://{STAGING_BUCKET}/jobs/dask_yarn_example.py",
        "args": [
            "--input", f"gs://{STAGING_BUCKET}/data/sample_input.csv",
            "--output", f"gs://{STAGING_BUCKET}/output/{{ ds }}/results.csv"
        ],
        "properties": {
            "spark.submit.deployMode": "client"
        }
    }
}

# Default arguments for the DAG
default_args = {
    "owner": "data-platform",
    "depends_on_past": False,
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

# DAG definition
with DAG(
    dag_id="dask_dataproc_ephemeral",
    default_args=default_args,
    description="Run Dask workloads on ephemeral Dataproc clusters",
    schedule_interval=None,  # Manual trigger
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["a02", "dask", "dataproc", "ephemeral"],
) as dag:

    # Task 1: Create Dataproc cluster with Dask
    create_cluster = DataprocCreateClusterOperator(
        task_id="create_dataproc_cluster",
        project_id=PROJECT_ID,
        region=REGION,
        cluster_name=CLUSTER_NAME,
        cluster_config=CLUSTER_CONFIG,
        labels={
            "environment": "production",
            "component": "dask",
            "lifecycle": "ephemeral"
        }
    )

    # Task 2: Submit Dask job
    submit_dask_job = DataprocSubmitJobOperator(
        task_id="submit_dask_job",
        job=DASK_JOB,
        region=REGION,
        project_id=PROJECT_ID,
    )

    # Task 3: Delete cluster (always runs, even if job fails)
    delete_cluster = DataprocDeleteClusterOperator(
        task_id="delete_dataproc_cluster",
        project_id=PROJECT_ID,
        region=REGION,
        cluster_name=CLUSTER_NAME,
        trigger_rule=TriggerRule.ALL_DONE,  # Always delete cluster
    )

    # Task dependencies
    create_cluster >> submit_dask_job >> delete_cluster
