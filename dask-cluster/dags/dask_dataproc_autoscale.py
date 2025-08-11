"""
Autoscaling Dask on Dataproc DAG

This DAG demonstrates advanced patterns for Dask on Dataproc:
- Dataproc autoscaling for cost optimization
- Dynamic Dask cluster scaling via dask-yarn
- Processing large datasets from GCS
- Using Dask's adaptive scaling features
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
SUBNETWORK_URI = "{{ var.value.subnetwork_services_uri }}"
SERVICE_ACCOUNT_EMAIL = "{{ var.value.dataproc_runtime_sa_email }}"

# Dynamic cluster name
CLUSTER_NAME = "dask-autoscale-{{ ds_nodash }}-{{ ts_nodash | lower | replace(':', '') }}"

# Autoscaling cluster configuration
CLUSTER_CONFIG = {
    "gce_cluster_config": {
        "subnetwork_uri": SUBNETWORK_URI,
        "internal_ip_only": True,
        "service_account": SERVICE_ACCOUNT_EMAIL,
        "tags": ["dataproc", "autoscale"]
    },
    "master_config": {
        "num_instances": 1,
        "machine_type_uri": "n2-highmem-4",  # Higher memory for scheduler
        "disk_config": {
            "boot_disk_type": "pd-ssd",
            "boot_disk_size_gb": 100
        }
    },
    "worker_config": {
        "num_instances": 2,  # Minimum workers
        "machine_type_uri": "n2-standard-8",  # More cores for parallel processing
        "disk_config": {
            "boot_disk_type": "pd-balanced",
            "boot_disk_size_gb": 200
        }
    },
    # Autoscaling policy
    "autoscaling_config": {
        "policy_uri": f"projects/{PROJECT_ID}/regions/{REGION}/autoscalingPolicies/dask-autoscale-policy"
    },
    "initialization_actions": [
        {
            "executable_file": f"gs://goog-dataproc-initialization-actions-{REGION}/dask/dask.sh",
            "execution_timeout": "10m"
        }
    ],
    "endpoint_config": {
        "enable_http_port_access": True
    },
    "software_config": {
        "properties": {
            "dataproc:dataproc.logging.stackdriver.enable": "true",
            "dataproc:dataproc.monitoring.stackdriver.enable": "true",
            # Configure YARN for better Dask integration
            "yarn:yarn.nodemanager.resource.memory-mb": "30720",  # 30GB per node
            "yarn:yarn.nodemanager.resource.cpu-vcores": "7",     # Leave 1 core for system
            "dask:dask.scheduler.port": "8786",
            "dask:dask.dashboard.port": "8787"
        }
    }
}

# Job for large-scale data processing
LARGE_SCALE_JOB = {
    "reference": {"project_id": PROJECT_ID},
    "placement": {"cluster_name": CLUSTER_NAME},
    "pyspark_job": {
        "main_python_file_uri": f"gs://{STAGING_BUCKET}/jobs/dask_large_scale_processing.py",
        "args": [
            "--input-pattern", f"gs://{STAGING_BUCKET}/large-data/{{ ds }}/*.parquet",
            "--output-path", f"gs://{STAGING_BUCKET}/processed/{{ ds }}/",
            "--min-workers", "2",
            "--max-workers", "10",
            "--adaptive-scaling", "true"
        ],
        "properties": {
            "spark.submit.deployMode": "client",
            # Increase driver memory for Dask scheduler
            "spark.driver.memory": "8g",
            "spark.driver.cores": "4"
        }
    }
}

default_args = {
    "owner": "data-platform",
    "depends_on_past": False,
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=10),
}

with DAG(
    dag_id="dask_dataproc_autoscale",
    default_args=default_args,
    description="Large-scale Dask processing with autoscaling",
    schedule_interval="@daily",  # Daily processing
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["a02", "dask", "dataproc", "autoscale", "production"],
) as dag:

    # Create autoscaling Dataproc cluster
    create_cluster = DataprocCreateClusterOperator(
        task_id="create_autoscaling_cluster",
        project_id=PROJECT_ID,
        region=REGION,
        cluster_name=CLUSTER_NAME,
        cluster_config=CLUSTER_CONFIG,
        labels={
            "environment": "production",
            "component": "dask",
            "lifecycle": "ephemeral",
            "scaling": "auto"
        }
    )

    # Submit large-scale processing job
    process_large_data = DataprocSubmitJobOperator(
        task_id="process_large_scale_data",
        job=LARGE_SCALE_JOB,
        region=REGION,
        project_id=PROJECT_ID,
    )

    # Delete cluster
    delete_cluster = DataprocDeleteClusterOperator(
        task_id="delete_autoscaling_cluster",
        project_id=PROJECT_ID,
        region=REGION,
        cluster_name=CLUSTER_NAME,
        trigger_rule=TriggerRule.ALL_DONE,
    )

    create_cluster >> process_large_data >> delete_cluster
