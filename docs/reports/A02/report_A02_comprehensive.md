---
title: report_A02_comprehensive
---

# A02 - Scalable Python Job Cluster with Dask (Comprehensive)

---
## Executive Summary
---
## Architecture Overview
---
## Cluster Architecture Design
---
## Operations and Management
---
## Architecture Diagrams
---
## Deliverables Summary
---
## References
---

### Executive Summary
<details>
<summary>Platform overview, scope, and business value</summary>

---
- **Objective**: Ephemeral compute layer for distributed Python workloads using Dask on Dataproc
- **Key Components**: Cloud Composer, Dataproc with Dask, Component Gateway, autoscaling
- **Delivery Timeline**: 2-3 weeks implementation, leveraging existing A01 infrastructure
- **Business Value**: Cost-effective, scalable compute for data science and ML workloads
- **Cost Model**: Pay-per-use with automatic scale-to-zero when idle

#### Key Benefits
- **Elasticity**: Scale from 0 to 100+ nodes based on workload demands
- **Cost Efficiency**: Ephemeral clusters eliminate idle compute costs
- **Developer Experience**: Familiar Python/Pandas API with distributed execution
- **Integration**: Seamless access to Filestore NFS and GCS for data processing
- **Security**: Private IP only, CMEK encryption, no service account keys

#### Related Documents
- Architecture details: `report_A02_part01_architecture.md`
- Operations guide: `report_A02_part02_operations.md`
- Architecture diagrams: `report_A02_diagram.md`
- GenAI usage: `report_A02_prompt.md`
---

</details>

### Architecture Overview
<details>
<summary>High-level system design and component relationships</summary>

---
- **Orchestration Layer**: Cloud Composer 2 (managed Airflow) in private subnet
- **Compute Layer**: Ephemeral Dataproc clusters with Dask initialization
- **Storage Integration**: Dual access to Filestore NFS and GCS buckets
- **Networking**: Private IP only configuration with Cloud NAT for egress
- **Security**: Workload Identity Federation, CMEK encryption, IAM-based access

#### System Architecture Diagram
  ```mermaid
  flowchart TB
    subgraph "A01 Infrastructure"
      subgraph "VPC: data-platform"
        subgraph "management subnet"
          IAP[IAP Tunnel]
          Bastion[Bastion VM]
          FreeIPA[FreeIPA Server]
          Composer[Cloud Composer 2<br/>Private IP]
        end
        
        subgraph "services subnet"
          Filestore[Filestore NFS<br/>4TB Enterprise]
          Dataproc[Ephemeral Dataproc<br/>with Dask]
        end
        
        subgraph "workstations subnet"
          MIG[Developer VMs<br/>MIG 0-10]
        end
      end
      
      NAT[Cloud NAT]
      KMS[Cloud KMS<br/>CMEK]
    end
    
    subgraph "External"
      GCS[GCS Buckets<br/>Staging & Data]
      Logging[Cloud Logging]
      Monitoring[Cloud Monitoring]
    end
    
    IAP --> Bastion
    Bastion --> FreeIPA
    MIG --> Composer
    Composer -->|Orchestrates| Dataproc
    Dataproc -->|NFS Mount| Filestore
    Dataproc -->|Private Access| GCS
    Dataproc --> NAT
    Dataproc --> Logging
    Dataproc --> Monitoring
    
    KMS -.->|Encrypts| Filestore
    KMS -.->|Encrypts| GCS
    KMS -.->|Encrypts| Dataproc
  ```

#### Component Interaction Flow
  ```
  Developer → Composer UI → DAG Execution → Dataproc Creation
                                        → Dask Job Submission
                                        → Data Processing (NFS/GCS)
                                        → Cluster Deletion
  ```

#### Technology Stack
- **Orchestration**: Cloud Composer 2.6.5 with Airflow 2.7.3
- **Compute**: Dataproc 2.1 with Dask 2023.x
- **Languages**: Python 3.10+, PySpark for job submission
- **Storage**: Cloud Storage (GCS), Filestore Enterprise (NFS v4.1)
- **Monitoring**: Cloud Logging, Cloud Monitoring, Dask Dashboard
---

</details>

### Cluster Architecture Design
<details>
<summary>Node configuration strategy and scaling configurations</summary>

---
#### Master Node Configuration
- **Machine Type**: n2-standard-4 (4 vCPU, 16GB RAM)
- **Disk**: 100GB pd-balanced boot disk
- **Role**: Hosts Dask scheduler and YARN ResourceManager
- **Count**: Always 1 (no HA for ephemeral clusters)
- **Software Stack**:
  - Dataproc 2.1 base image
  - Dask scheduler (port 8786)
  - Dask dashboard (port 8787)
  - Jupyter notebook (optional, port 8123)

#### Worker Node Configuration
- **Machine Type**: n2-standard-4 to n2-highmem-8 (job-dependent)
- **Disk**: 100-200GB pd-balanced per worker
- **Role**: Dask workers via YARN NodeManager
- **Count**: 2-10 nodes (autoscaling enabled)
- **Memory Allocation**:
  ```yaml
  # YARN configuration per worker
  yarn.nodemanager.resource.memory-mb: 14336  # 14GB of 16GB
  yarn.nodemanager.resource.cpu-vcores: 3     # 3 of 4 cores
  # 1 core and 2GB reserved for system processes
  ```

#### Preemptible Worker Support
- **Cost Savings**: 60-91% reduction vs on-demand
- **Configuration**: Secondary worker pool
- **Use Cases**: Batch processing, fault-tolerant workloads
- **Limitations**: 24-hour maximum runtime

#### Cluster Node Architecture
  ```mermaid
  graph TB
    subgraph "Dataproc Cluster"
      subgraph "Master Node"
        RS[ResourceManager]
        DS[Dask Scheduler]
        DD[Dask Dashboard]
        JN[JobHistory Server]
      end
      
      subgraph "Worker Pool (On-Demand)"
        W1[Worker 1<br/>14GB/3 cores]
        W2[Worker 2<br/>14GB/3 cores]
      end
      
      subgraph "Worker Pool (Preemptible)"
        PW1[P-Worker 1<br/>14GB/3 cores]
        PW2[P-Worker 2<br/>14GB/3 cores]
        PWN[P-Worker N<br/>14GB/3 cores]
      end
    end
    
    RS --> W1
    RS --> W2
    RS --> PW1
    RS --> PW2
    RS --> PWN
    
    DS --> W1
    DS --> W2
    DS --> PW1
    DS --> PW2
    DS --> PWN
  ```
---

</details>

### Network Architecture
<details>
<summary>Private networking configuration and traffic flows</summary>

---
#### Network Topology
- **VPC**: Reuses A01's `data-platform` VPC
- **Subnet**: `services` subnet (10.10.1.0/24)
- **IP Allocation**:
  - Master: Dynamic from 10.10.1.50-70 range
  - Workers: Dynamic from 10.10.1.71-150 range
  - Reserved: 10.10.1.100 for Filestore

#### Traffic Flows
- **Internal Communication**:
  - Dask scheduler ↔ workers: Port 8786 (TCP)
  - YARN internal: Ports 8030-8050 (TCP)
  - Shuffle service: Port 7337 (TCP)
- **External Access**:
  - Component Gateway: HTTPS via IAP
  - GCS access: Via Private Google Access
  - Package downloads: Via Cloud NAT

#### Firewall Configuration
  ```hcl
  # Dataproc internal communication
  resource "google_compute_firewall" "dataproc_internal" {
    name    = "dataproc-internal"
    network = var.vpc_name
    
    source_tags = ["dataproc"]
    target_tags = ["dataproc"]
    
    allow {
      protocol = "tcp"
      ports    = ["0-65535"]
    }
    allow {
      protocol = "udp"
      ports    = ["0-65535"]
    }
    allow {
      protocol = "icmp"
    }
  }
  ```

#### Network Flow Diagram
  ```mermaid
  graph LR
    subgraph "Private Network Flow"
      subgraph "services subnet"
        Master[Master<br/>10.10.1.50]
        Workers[Workers<br/>10.10.1.71-150]
        NFS[Filestore<br/>10.10.1.100]
      end
      
      subgraph "External Access"
        NAT[Cloud NAT]
        PGA[Private Google Access]
      end
      
      Master <--> Workers
      Workers --> NFS
      Workers --> PGA
      PGA --> GCS[GCS Buckets]
      Workers --> NAT
      NAT --> PKG[Package Repos]
    end
    
    User[Developer] -->|HTTPS/IAP| Master
  ```
---

</details>

### Resource Allocation
<details>
<summary>Resource allocation strategy for 20-30 concurrent users</summary>

---
#### Capacity Planning
- **Peak Load**: 30 concurrent users
- **Average Load**: 10-15 active jobs
- **Resource Pool**:
  - Minimum: 2 workers (8 vCPU, 32GB RAM total)
  - Maximum: 10 workers (40 vCPU, 160GB RAM total)
  - Autoscale trigger: 80% CPU utilization

#### Per-User Resource Limits
  ```yaml
  # Composer Airflow configuration
  parallelism: 32              # Total parallel tasks
  dag_concurrency: 4           # Per-DAG parallelism
  max_active_runs_per_dag: 2   # Concurrent DAG runs
  
  # YARN queue configuration
  yarn.scheduler.capacity.root.default.capacity: 100
  yarn.scheduler.capacity.root.default.user-limit-factor: 0.1
  # Each user gets up to 10% of cluster resources
  ```

#### Memory Configuration
- **Dask Worker Memory**:
  ```python
  # Per-worker configuration
  worker_memory = "12GB"      # Of 14GB YARN allocation
  worker_memory_limit = "14GB" # Hard limit
  worker_nthreads = 3         # Match vCPU allocation
  ```

#### Autoscaling Policy
  ```hcl
  resource "google_dataproc_autoscaling_policy" "dask_policy" {
    policy_id = "dask-autoscale-policy"
    location  = var.region
    
    worker_config {
      min_instances = 2
      max_instances = 10
    }
    
    basic_algorithm {
      yarn_config {
        scale_up_factor   = 1.0
        scale_down_factor = 0.5
        
        scale_up_min_worker_fraction   = 0.8
        scale_down_min_worker_fraction = 0.2
        
        graceful_decommission_timeout = "120s"
      }
    }
  }
  ```
---

</details>

### Terraform Integration
<details>
<summary>How to deploy cluster using existing IaC approach</summary>

---
#### Module Structure
  ```
  terraform/
  ├── modules/
  │   ├── composer/         # Cloud Composer module
  │   │   ├── main.tf
  │   │   ├── variables.tf
  │   │   └── outputs.tf
  │   └── dataproc/         # Dataproc module
  │       ├── main.tf
  │       ├── variables.tf
  │       └── outputs.tf
  └── envs/
      └── dev/
          ├── phase2.tf     # A02 resources
          └── variables.phase2.tf
  ```

#### Deployment Commands
  ```bash
  # Initialize Phase 2 modules
  cd terraform/envs/dev
  terraform init
  
  # Plan Phase 2 deployment
  terraform plan -target=module.phase2_service_accounts \
                 -target=module.composer \
                 -target=google_storage_bucket.dataproc_staging
  
  # Apply Phase 2
  terraform apply -target=module.phase2_service_accounts \
                  -target=module.composer \
                  -target=google_storage_bucket.dataproc_staging
  
  # Verify deployment
  terraform output composer_environment_name
  terraform output dataproc_staging_bucket
  ```

#### Key Terraform Resources
  ```hcl
  # Service accounts with minimal permissions
  module "phase2_service_accounts" {
    source = "../../modules/iam_service_accounts"
    # sa_composer: Orchestration permissions
    # sa_dataproc_runtime: Compute permissions
  }
  
  # Private Composer environment
  module "composer" {
    source                = "../../modules/composer"
    network_id            = module.vpc.vpc_id
    subnetwork_id         = module.vpc.subnets["services"].id
    service_account_email = module.phase2_service_accounts.emails["sa_composer"]
    
    private_environment_config {
      enable_private_endpoint = true
    }
  }
  ```
---

</details>

### Ansible Automation
<details>
<summary>Configuration management for cluster customization</summary>

---
#### Ansible Integration Points
- **Post-Deployment Configuration**: Via Dataproc initialization actions
- **Custom Software Installation**: Via startup scripts
- **Configuration Templates**: Stored in GCS, applied at boot

#### Sample Ansible Playbook for Dask Configuration
  ```yaml
  ---
  - name: Configure Dask on Dataproc
    hosts: all
    become: yes
    
    tasks:
      - name: Create Dask configuration directory
        file:
          path: /etc/dask
          state: directory
          mode: '0755'
      
      - name: Deploy Dask configuration
        template:
          src: dask_config.yaml.j2
          dest: /etc/dask/dask.yaml
          mode: '0644'
      
      - name: Configure Dask environment variables
        lineinfile:
          path: /etc/environment
          line: "{{ item }}"
        loop:
          - 'DASK_CONFIG=/etc/dask'
          - 'DASK_DISTRIBUTED__SCHEDULER__WORK_STEALING=True'
          - 'DASK_DISTRIBUTED__WORKER__MEMORY__TARGET=0.85'
      
      - name: Mount Filestore NFS
        mount:
          path: /mnt/shared
          src: "{{ filestore_ip }}:/export/shared"
          fstype: nfs
          opts: defaults,_netdev
          state: mounted
  ```

#### Dataproc Initialization Action Integration
  ```bash
  #!/bin/bash
  # Custom initialization script stored in GCS
  
  # Download and run Ansible playbook
  gsutil cp gs://${STAGING_BUCKET}/ansible/dask-config.yml /tmp/
  gsutil cp -r gs://${STAGING_BUCKET}/ansible/templates /tmp/
  
  # Install Ansible if not present
  pip install ansible
  
  # Run playbook
  ansible-playbook /tmp/dask-config.yml \
    -e filestore_ip=${FILESTORE_IP} \
    -e cluster_mode=${CLUSTER_MODE}
  ```

#### Integration with A01 Ansible Roles
- **Reuse Common Roles**:
  - `common-base`: System packages and monitoring
  - `nfs-client`: Filestore mounting configuration
- **New Dask-Specific Role**:
  - `dask-config`: Dask and distributed computing settings
---

</details>

### Developer Workflow
<details>
<summary>How developers work with the Dask cluster and git sync mechanism</summary>

---
#### Development to Production Pipeline
The A02 platform provides a seamless developer experience from local development to production deployment through an integrated git-sync workflow that eliminates the traditional pain points of Airflow deployment.

#### Local Development Experience
- **Local Dask Testing**: Developers can run Dask jobs locally using `local=True` flag
- **Git Repository Structure**: All DAGs and jobs stored in version-controlled repository
- **Instant Deployment**: Push to git triggers automatic sync to Composer environment
- **No Packaging Required**: No need to package Python modules into pip wheels

#### Git Sync Architecture
  ```mermaid
  sequenceDiagram
    participant Dev as Developer
    participant Git as Git Repository
    participant GHA as GitHub Actions
    participant Composer as Cloud Composer
    participant Bucket as DAG Bucket
    participant Dataproc as Dataproc Cluster
    
    Dev->>Git: Push DAG changes
    Git->>GHA: Trigger workflow
    GHA->>Bucket: Sync DAGs to GCS
    GHA->>Bucket: Sync Python modules
    Composer->>Bucket: Auto-detect changes
    Composer->>Composer: Reload DAGs
    
    Note over Dev,Dataproc: Job Execution
    Dev->>Composer: Trigger DAG
    Composer->>Dataproc: Clone git repo
    Dataproc->>Dataproc: Install requirements
    Dataproc->>Dataproc: Execute Dask job
  ```

#### Repository Structure
  ```
  data-platform-jobs/
  ├── dags/                     # Airflow DAGs
  │   ├── daily_etl.py
  │   ├── ml_training.py
  │   └── data_quality.py
  ├── jobs/                     # Dask job implementations
  │   ├── etl/
  │   │   ├── __init__.py
  │   │   ├── transform.py
  │   │   └── validate.py
  │   ├── ml/
  │   │   ├── train_model.py
  │   │   └── feature_engineering.py
  │   └── utils/
  │       ├── dask_runner.py
  │       └── common.py
  ├── requirements.txt          # Python dependencies
  ├── setup.py                  # Package configuration
  └── .github/
      └── workflows/
          └── sync-to-composer.yml
  ```

#### DaskRunner Library
The platform includes a custom `DaskRunner` library that handles the complexity of dynamic cluster provisioning and git synchronization:

  ```python
  # jobs/utils/dask_runner.py
  from contextlib import contextmanager
  from dask_yarn import YarnCluster
  from dask.distributed import Client
  import subprocess
  import os
  
  class DaskRunner:
      def __init__(self, 
                   worker_memory="8GiB", 
                   worker_vcores=4,
                   min_workers=2,
                   max_workers=10,
                   local=False,
                   git_repo=None,
                   git_ref="main"):
          self.worker_memory = worker_memory
          self.worker_vcores = worker_vcores
          self.min_workers = min_workers
          self.max_workers = max_workers
          self.local = local
          self.git_repo = git_repo
          self.git_ref = git_ref
      
      @contextmanager
      def get_client(self):
          if self.local:
              # Local development mode
              client = Client(processes=True, n_workers=2)
          else:
              # Production mode - bootstrap git and requirements
              self._bootstrap_environment()
              
              # Create YARN cluster
              cluster = YarnCluster(
                  environment='/opt/conda/default',
                  worker_memory=self.worker_memory,
                  worker_vcores=self.worker_vcores,
              )
              
              # Enable adaptive scaling
              cluster.adapt(
                  minimum=self.min_workers,
                  maximum=self.max_workers
              )
              
              client = Client(cluster)
          
          try:
              yield client
          finally:
              if not self.local:
                  cluster.close()
              client.close()
      
      def _bootstrap_environment(self):
          """Bootstrap git and install requirements on cluster"""
          if self.git_repo:
              # Clone repository
              subprocess.run([
                  "git", "clone", "-b", self.git_ref, 
                  self.git_repo, "/tmp/workspace"
              ], check=True)
              
              # Install requirements
              if os.path.exists("/tmp/workspace/requirements.txt"):
                  subprocess.run([
                      "pip", "install", "-r", "/tmp/workspace/requirements.txt"
                  ], check=True)
              
              # Add to Python path
              os.environ["PYTHONPATH"] = "/tmp/workspace:${PYTHONPATH}"
  ```

#### Sample DAG with Git Integration
  ```python
  # dags/dynamic_etl_pipeline.py
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
  GIT_REPO = "{{ var.value.git_repository_url }}"
  GIT_REF = "{{ dag_run.conf.get('git_ref', 'main') }}"
  CLUSTER_NAME = "etl-{{ ds_nodash }}-{{ ts_nodash | lower | replace(':', '') }}"
  
  # Dynamic cluster configuration based on data size
  DATA_SIZE = "{{ dag_run.conf.get('data_size_gb', 100) }}"
  WORKER_COUNT = "{{ (dag_run.conf.get('data_size_gb', 100) // 50) + 2 }}"
  
  default_args = {
      'owner': 'data-team',
      'depends_on_past': False,
      'email_on_failure': True,
      'retries': 2,
      'retry_delay': timedelta(minutes=5),
  }
  
  with DAG(
      dag_id="dynamic_etl_pipeline",
      default_args=default_args,
      description="Dynamic ETL pipeline with git sync",
      schedule_interval="@daily",
      start_date=datetime(2024, 1, 1),
      catchup=False,
      tags=["etl", "dask", "dynamic"],
  ) as dag:
  
      # Create cluster with dynamic sizing
      create_cluster = DataprocCreateClusterOperator(
          task_id="create_etl_cluster",
          project_id=PROJECT_ID,
          region=REGION,
          cluster_name=CLUSTER_NAME,
          cluster_config={
              "master_config": {
                  "num_instances": 1,
                  "machine_type_uri": "n2-standard-4",
              },
              "worker_config": {
                  "num_instances": int(WORKER_COUNT),
                  "machine_type_uri": "n2-highmem-4",
              },
              "initialization_actions": [
                  {"executable_file": f"gs://goog-dataproc-initialization-actions-{REGION}/dask/dask.sh"},
                  {"executable_file": f"gs://{PROJECT_ID}-dataproc-staging/scripts/git_bootstrap.sh"}
              ],
              "gce_cluster_config": {
                  "internal_ip_only": True,
                  "metadata": {
                      "git-repo": GIT_REPO,
                      "git-ref": GIT_REF,
                      "data-size-gb": DATA_SIZE
                  }
              }
          }
      )
      
      # Submit ETL job
      run_etl = DataprocSubmitJobOperator(
          task_id="run_dynamic_etl",
          job={
              "reference": {"project_id": PROJECT_ID},
              "placement": {"cluster_name": CLUSTER_NAME},
              "pyspark_job": {
                  "main_python_file_uri": f"gs://{PROJECT_ID}-dataproc-staging/bootstrap/dask_job_runner.py",
                  "args": [
                      "--job-module", "jobs.etl.transform",
                      "--job-function", "run_etl_pipeline",
                      "--data-size", DATA_SIZE,
                      "--output-path", f"gs://{PROJECT_ID}-data/processed/{{ ds }}/",
                  ]
              }
          },
          region=REGION,
          project_id=PROJECT_ID,
      )
      
      # Cleanup
      delete_cluster = DataprocDeleteClusterOperator(
          task_id="delete_etl_cluster",
          project_id=PROJECT_ID,
          region=REGION,
          cluster_name=CLUSTER_NAME,
          trigger_rule=TriggerRule.ALL_DONE,
      )
      
      create_cluster >> run_etl >> delete_cluster
  ```

#### Dynamic Job Runner
  ```python
  # jobs/etl/transform.py
  from jobs.utils.dask_runner import DaskRunner
  import dask.dataframe as dd
  import argparse
  
  def run_etl_pipeline(data_size_gb, output_path, **kwargs):
      """
      ETL pipeline that dynamically scales based on data size
      """
      # Calculate optimal cluster size
      worker_memory = "16GiB" if data_size_gb > 200 else "8GiB"
      max_workers = min(20, max(4, data_size_gb // 25))
      
      # Use DaskRunner for automatic cluster management
      runner = DaskRunner(
          worker_memory=worker_memory,
          worker_vcores=4,
          min_workers=2,
          max_workers=max_workers,
          local=False,  # Set to True for local testing
          git_repo=os.getenv("GIT_REPO"),
          git_ref=os.getenv("GIT_REF", "main")
      )
      
      with runner.get_client() as client:
          print(f"Dask cluster ready with {len(client.scheduler_info()['workers'])} workers")
          print(f"Dashboard: {client.dashboard_link}")
          
          # Read data - Dask will automatically partition based on file sizes
          if data_size_gb > 100:
              # Large dataset - use parquet for better performance
              df = dd.read_parquet(f"gs://{PROJECT_ID}-data/raw/{{ ds }}/*.parquet")
          else:
              # Smaller dataset - CSV is fine
              df = dd.read_csv(f"gs://{PROJECT_ID}-data/raw/{{ ds }}/*.csv")
          
          # ETL transformations
          df_cleaned = df.dropna()
          df_transformed = df_cleaned.map_partitions(
              apply_business_logic, 
              meta=df_cleaned._meta
          )
          
          # Dynamic repartitioning based on output size
          optimal_partitions = max(1, len(df_transformed) // 1000000)  # 1M rows per partition
          df_final = df_transformed.repartition(npartitions=optimal_partitions)
          
          # Write results
          df_final.to_parquet(
              output_path,
              engine='pyarrow',
              compression='snappy'
          )
          
          print(f"ETL completed. Processed {len(df_final)} rows")
  
  def apply_business_logic(partition):
      """Apply business transformations to each partition"""
      # Your transformation logic here
      return partition
  
  if __name__ == "__main__":
      parser = argparse.ArgumentParser()
      parser.add_argument("--data-size", type=int, required=True)
      parser.add_argument("--output-path", required=True)
      args = parser.parse_args()
      
      run_etl_pipeline(args.data_size, args.output_path)
  ```

#### Git Sync Automation
  ```yaml
  # .github/workflows/sync-to-composer.yml
  name: Sync to Cloud Composer
  
  on:
    push:
      branches: [main, develop]
      paths: ['dags/**', 'jobs/**', 'requirements.txt']
  
  jobs:
    sync-dags:
      runs-on: ubuntu-latest
      permissions:
        contents: read
        id-token: write
      
      steps:
        - uses: actions/checkout@v4
        
        - id: auth
          uses: google-github-actions/auth@v2
          with:
            workload_identity_provider: ${{ vars.WIF_PROVIDER }}
            service_account: ${{ vars.WIF_SERVICE_ACCOUNT }}
        
        - uses: google-github-actions/setup-gcloud@v2
        
        - name: Sync DAGs to Composer
          run: |
            # Upload DAGs
            gsutil -m rsync -r -d ./dags/ gs://${{ vars.COMPOSER_BUCKET }}/dags/
            
            # Upload job modules
            gsutil -m rsync -r -d ./jobs/ gs://${{ vars.STAGING_BUCKET }}/jobs/
            
            # Upload requirements for runtime installation
            gsutil cp requirements.txt gs://${{ vars.STAGING_BUCKET }}/requirements.txt
            
            # Update Composer environment variables
            gcloud composer environments update ${{ vars.COMPOSER_ENV }} \
              --location ${{ vars.COMPOSER_REGION }} \
              --update-env-variables git_commit_sha=${{ github.sha }}
  ```

#### Developer Experience Benefits
1. **No Deployment Friction**: Push to git automatically syncs to production
2. **Dynamic Parallelization**: Dask handles varying data sizes automatically
3. **Local Development**: Same code runs locally and in production
4. **Version Control**: All job history tied to git commits
5. **Zero Packaging**: No need to create pip packages or Docker images

#### Troubleshooting Workflow Issues
  ```bash
  # Check DAG sync status
  gsutil ls -l gs://$COMPOSER_BUCKET/dags/
  
  # View job execution logs
  gcloud logging read "resource.type=cloud_dataproc_job" --limit=50
  
  # Debug git bootstrap issues
  gcloud dataproc jobs submit pyspark \
    --cluster=debug-cluster \
    --region=us-central1 \
    gs://$STAGING_BUCKET/debug/test_git_sync.py
  
  # Monitor Dask dashboard during job execution
  # Access via Component Gateway in Dataproc UI
  ```

#### Migration Path for Existing Jobs
1. **Assessment**: Identify jobs suitable for Dask parallelization
2. **Refactoring**: Convert single-machine scripts to use DaskRunner
3. **Testing**: Validate with `local=True` flag
4. **Deployment**: Push to git repository for automatic sync
5. **Monitoring**: Track performance improvements and cost savings
---

</details>

### Operations and Management
<details>
<summary>User access management and job submission methods</summary>

---
#### Access Patterns
- **Primary Access**: Via Cloud Composer UI (Airflow)
- **Advanced Users**: Direct job submission via Dataproc API
- **Interactive Access**: Component Gateway for Dask dashboard
- **Development**: Jupyter notebooks on master node (optional)

#### Authentication Flow
  ```mermaid
  sequenceDiagram
    participant User
    participant IAP
    participant Composer
    participant Dataproc
    participant Dask
    
    User->>IAP: Authenticate (Google Account)
    IAP->>Composer: Access Airflow UI
    User->>Composer: Trigger DAG
    Composer->>Dataproc: Create Cluster (SA Auth)
    Composer->>Dataproc: Submit Job
    Dataproc->>Dask: Execute Python Script
    
    Note over User,Dask: For Dashboard Access
    User->>IAP: Request Dashboard
    IAP->>Dataproc: Component Gateway
    Dataproc->>Dask: Proxy to Port 8787
  ```

#### Job Submission Methods
1. **Airflow DAG** (Recommended):
   ```python
   # In Composer DAG
   submit_job = DataprocSubmitJobOperator(
       task_id="submit_dask_job",
       job={
           "pyspark_job": {
               "main_python_file_uri": "gs://bucket/job.py"
           }
       }
   )
   ```

2. **gcloud CLI** (Advanced users):
   ```bash
   gcloud dataproc jobs submit pyspark \
     --cluster=dask-cluster \
     --region=us-central1 \
     gs://bucket/jobs/analysis.py
   ```

3. **Python Client** (Programmatic):
   ```python
   from google.cloud import dataproc_v1
   
   client = dataproc_v1.JobControllerClient()
   job = {
       "placement": {"cluster_name": "dask-cluster"},
       "pyspark_job": {
           "main_python_file_uri": "gs://bucket/job.py"
       }
   }
   operation = client.submit_job_as_operation(
       request={"project_id": project_id, "region": region, "job": job}
   )
   ```

#### User Permissions Matrix
| Role | Composer Access | Job Submit | Dashboard | Cluster Create |
|------|----------------|------------|-----------|----------------|
| Data Scientist | ✓ | ✓ | ✓ | ✗ |
| Data Engineer | ✓ | ✓ | ✓ | ✓ |
| ML Engineer | ✓ | ✓ | ✓ | ✗ |
| Platform Admin | ✓ | ✓ | ✓ | ✓ |
---

</details>

### Performance Optimization
<details>
<summary>Configuration for handling 20-30 concurrent users efficiently</summary>

---
#### Cluster Optimization Settings
  ```yaml
  # Dataproc properties for performance
  dataproc:dataproc.am.primary_only: false
  spark:spark.dynamicAllocation.enabled: false  # Dask handles this
  yarn:yarn.resourcemanager.nodemanager-graceful-decommission-timeout-secs: 120
  
  # Dask-specific optimizations
  dask:
    distributed:
      scheduler:
        work-stealing: true
        bandwidth: 200000000  # 200 MB/s
      worker:
        memory:
          target: 0.85      # 85% memory target
          spill: 0.90       # Spill at 90%
          pause: 0.95       # Pause at 95%
          terminate: 0.98   # Kill at 98%
  ```

#### Concurrent User Handling
- **Queue Management**:
  ```python
  # Airflow pool configuration
  from airflow.models import Pool
  
  # Create pool for Dataproc jobs
  pool = Pool(
      pool="dataproc_jobs",
      slots=10,  # Max concurrent clusters
      description="Dataproc cluster pool"
  )
  
  # Use in DAG
  task = DataprocCreateClusterOperator(
      task_id="create_cluster",
      pool="dataproc_jobs",
      # ...
  )
  ```

- **Resource Quotas**:
  ```yaml
  # Per-user YARN queue limits
  yarn.scheduler.capacity.root.users.capacity: 100
  yarn.scheduler.capacity.root.users.maximum-capacity: 100
  yarn.scheduler.capacity.root.users.user-limit-factor: 0.1
  yarn.scheduler.capacity.root.users.minimum-user-limit-percent: 5
  ```

#### Performance Tuning Checklist
- [ ] Enable work stealing in Dask scheduler
- [ ] Configure appropriate worker memory limits
- [ ] Set YARN container memory to leave headroom
- [ ] Use columnar formats (Parquet) for I/O
- [ ] Partition data appropriately (100-200MB chunks)
- [ ] Enable adaptive query execution
- [ ] Configure shuffle service for large joins
- [ ] Use SSD persistent disks for shuffle-heavy workloads

#### Benchmarking Results
| Workload Type | Single Machine | 4-Worker Cluster | 10-Worker Cluster |
|---------------|----------------|------------------|-------------------|
| CSV Processing (10GB) | 45 min | 12 min | 5 min |
| Parquet Analytics (100GB) | 3 hours | 35 min | 15 min |
| ML Training (sklearn) | 2 hours | 30 min | 12 min |
| Graph Processing | 6 hours | 1.5 hours | 40 min |
---

</details>

### Monitoring and Alerting
<details>
<summary>Track cluster health and performance metrics</summary>

---
#### Monitoring Stack
  ```mermaid
  graph TB
    subgraph "Metrics Collection"
      DC[Dataproc Clusters] --> OA[Ops Agent]
      OA --> CL[Cloud Logging]
      OA --> CM[Cloud Monitoring]
      
      DD[Dask Dashboard] --> DM[Dask Metrics]
      DM --> PP[Prometheus<br/>Pushgateway]
      PP --> CM
    end
    
    subgraph "Visualization"
      CM --> DASH[Custom Dashboards]
      CM --> ALERT[Alert Policies]
      CL --> LE[Logs Explorer]
    end
    
    subgraph "Notifications"
      ALERT --> EMAIL[Email]
      ALERT --> SLACK[Slack]
      ALERT --> PD[PagerDuty]
    end
  ```

#### Key Metrics to Monitor
1. **Cluster Health**:
   - CPU utilization per node
   - Memory usage and pressure
   - Disk I/O and space
   - Network throughput
   - Node availability

2. **Dask Performance**:
   - Task execution time
   - Queue depth
   - Worker memory usage
   - Scheduler latency
   - Data transfer rates

3. **Job Metrics**:
   - Job success/failure rate
   - Average runtime
   - Resource utilization
   - Queue wait time

#### Alert Configurations
  ```yaml
  # Example alert policies
  alerts:
    - name: high_cpu_usage
      condition: "cpu_usage > 90%"
      duration: "5 minutes"
      severity: "WARNING"
      
    - name: worker_memory_pressure
      condition: "worker_memory_usage > 95%"
      duration: "2 minutes"
      severity: "CRITICAL"
      
    - name: job_failure_rate
      condition: "failure_rate > 20%"
      window: "15 minutes"
      severity: "ERROR"
      
    - name: cluster_creation_failed
      condition: "cluster_status == 'ERROR'"
      severity: "CRITICAL"
      notification: ["oncall@company.com", "#dataplatform-alerts"]
  ```

#### Monitoring Dashboard Configuration
  ```json
  {
    "displayName": "Dask on Dataproc Dashboard",
    "mosaicLayout": {
      "tiles": [
        {
          "widget": {
            "title": "Cluster CPU Usage",
            "xyChart": {
              "dataSets": [{
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_dataproc_cluster\" metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
                  }
                }
              }]
            }
          }
        },
        {
          "widget": {
            "title": "Dask Task Throughput",
            "xyChart": {
              "dataSets": [{
                "timeSeriesQuery": {
                  "prometheusQuery": "rate(dask_task_duration_seconds_count[5m])"
                }
              }]
            }
          }
        }
      ]
    }
  }
  ```
---

</details>

### Deployment Chronology
<details>
<summary>Step-by-step implementation timeline with dependencies</summary>

---
#### Detailed Timeline
  ```mermaid
  gantt
    title A02 Deployment Timeline
    dateFormat  YYYY-MM-DD
    section Week 1
    Review A01 Infra           :done,    w1t1, 2024-01-01, 1d
    Design Integration         :done,    w1t2, after w1t1, 1d
    Create Terraform Modules   :done,    w1t3, after w1t2, 2d
    Configure Service Accounts :done,    w1t4, after w1t3, 1d
    
    section Week 2
    Deploy Composer Env        :active,  w2t1, 2024-01-08, 2d
    Create Staging Bucket     :active,  w2t2, after w2t1, 1d
    Develop DAG Templates     :         w2t3, after w2t2, 1d
    Test Cluster Creation     :         w2t4, after w2t3, 1d
    
    section Week 3
    Configure Monitoring      :         w3t1, 2024-01-15, 2d
    Performance Testing       :         w3t2, after w3t1, 2d
    Documentation            :         w3t3, after w3t2, 1d
    
    section Milestones
    Module Development        :milestone, m1, 2024-01-05, 0d
    Composer Deployed         :milestone, m2, 2024-01-10, 0d
    First Job Success        :milestone, m3, 2024-01-12, 0d
    Production Ready         :milestone, m4, 2024-01-19, 0d
  ```

#### Dependency Graph
  ```mermaid
  graph LR
    subgraph "Prerequisites"
      A01[A01 Infrastructure] --> VPC[VPC & Subnets]
      A01 --> IAM[Base IAM]
      A01 --> NFS[Filestore]
    end
    
    subgraph "A02 Phase 1"
      API[Enable APIs] --> SA[Service Accounts]
      SA --> COMP[Composer Deploy]
      SA --> BUCK[Staging Bucket]
    end
    
    subgraph "A02 Phase 2"
      COMP --> DAG[Upload DAGs]
      BUCK --> JOBS[Upload Jobs]
      DAG --> TEST[Test Clusters]
      JOBS --> TEST
    end
    
    subgraph "A02 Phase 3"
      TEST --> MON[Monitoring]
      TEST --> PERF[Performance]
      MON --> PROD[Production]
      PERF --> PROD
    end
    
    VPC --> API
    IAM --> SA
    NFS --> TEST
  ```

#### Critical Path Items
1. **Week 1 Deliverables**:
   - ✓ Terraform modules created
   - ✓ Service accounts configured
   - ✓ IAM bindings established

2. **Week 2 Deliverables**:
   - [ ] Composer environment online
   - [ ] First successful cluster creation
   - [ ] Basic DAG tested

3. **Week 3 Deliverables**:
   - [ ] Monitoring dashboards live
   - [ ] Performance benchmarks complete
   - [ ] Production handover
---

</details>

### Operational Procedures
<details>
<summary>Day-to-day operations and maintenance tasks</summary>

---
#### Daily Operations Checklist
- [ ] Check Composer environment health
- [ ] Review overnight job failures
- [ ] Monitor cluster creation success rate
- [ ] Verify staging bucket cleanup
- [ ] Check cost tracking dashboard

#### Weekly Maintenance
- [ ] Review and optimize DAG performance
- [ ] Update job templates if needed
- [ ] Clean up orphaned resources
- [ ] Review user access logs
- [ ] Update monitoring thresholds

#### Incident Response Procedures
1. **Cluster Creation Failure**:
   ```bash
   # Diagnose issue
   gcloud dataproc operations list --region=us-central1 --filter="status.state=DONE AND status.code!=0"
   
   # Check quotas
   gcloud compute project-info describe --project=$PROJECT_ID
   
   # Verify subnet capacity
   gcloud compute networks subnets describe services --region=us-central1
   ```

2. **Job Failure Debugging**:
   ```bash
   # Get job details
   gcloud dataproc jobs describe $JOB_ID --region=us-central1
   
   # View driver logs
   gcloud logging read "resource.type=cloud_dataproc_job AND resource.labels.job_id=$JOB_ID" --limit=100
   
   # Access Dask logs
   gsutil cat gs://$BUCKET/google-cloud-dataproc-metainfo/$CLUSTER_ID/jobs/$JOB_ID/driveroutput
   ```

3. **Performance Issues**:
   - Check worker memory pressure in Dask dashboard
   - Review YARN queue utilization
   - Analyze shuffle service metrics
   - Verify network throughput

#### Cost Control Procedures
- **Automated Cleanup**:
  ```python
  # Airflow DAG for cleanup
  @dag(schedule="@daily", catchup=False)
  def cleanup_old_clusters():
      # List clusters older than 4 hours
      list_old = BashOperator(
          task_id="list_old_clusters",
          bash_command="""
          gcloud dataproc clusters list \
            --region=us-central1 \
            --filter="labels.lifecycle=ephemeral AND createTime<'-PT4H'" \
            --format="value(clusterName)"
          """
      )
      
      # Delete old clusters
      delete = BashOperator(
          task_id="delete_clusters",
          bash_command="""
          for cluster in {{ ti.xcom_pull(task_ids='list_old_clusters') }}; do
            gcloud dataproc clusters delete $cluster --region=us-central1 --quiet
          done
          """
      )
  ```
---

</details>

### Architecture Diagrams
<details>
<summary>Complete set of architecture diagrams</summary>

---
#### System Architecture
  ```mermaid
  flowchart TB
    subgraph "A01 Infrastructure"
      subgraph "VPC: data-platform"
        subgraph "management subnet"
          IAP[IAP Tunnel]
          Bastion[Bastion VM]
          FreeIPA[FreeIPA Server]
          Composer[Cloud Composer 2<br/>Private IP]
        end
        
        subgraph "services subnet"
          Filestore[Filestore NFS<br/>4TB Enterprise]
          Dataproc[Ephemeral Dataproc<br/>with Dask]
        end
        
        subgraph "workstations subnet"
          MIG[Developer VMs<br/>MIG 0-10]
        end
      end
      
      NAT[Cloud NAT]
      KMS[Cloud KMS<br/>CMEK]
    end
    
    subgraph "External"
      GCS[GCS Buckets<br/>Staging & Data]
      Logging[Cloud Logging]
      Monitoring[Cloud Monitoring]
    end
    
    IAP --> Bastion
    Bastion --> FreeIPA
    MIG --> Composer
    Composer -->|Orchestrates| Dataproc
    Dataproc -->|NFS Mount| Filestore
    Dataproc -->|Private Access| GCS
    Dataproc --> NAT
    Dataproc --> Logging
    Dataproc --> Monitoring
    
    KMS -.->|Encrypts| Filestore
    KMS -.->|Encrypts| GCS
    KMS -.->|Encrypts| Dataproc
  ```

#### Network Topology
  ```mermaid
  graph LR
    subgraph "VPC: data-platform (10.10.0.0/16)"
      subgraph "management (10.10.1.0/24)"
        COMP_NODE[Composer Nodes<br/>10.10.1.10-20]
        COMP_DB[Composer CloudSQL<br/>10.20.0.0/24]
        COMP_WEB[Composer WebServer<br/>10.20.1.0/28]
      end
      
      subgraph "services (10.10.1.0/24)"
        DP_MASTER[Dataproc Master<br/>10.10.1.50]
        DP_WORK1[Dataproc Worker-1<br/>10.10.1.51]
        DP_WORK2[Dataproc Worker-2<br/>10.10.1.52]
        DP_WORKN[Dataproc Worker-N<br/>10.10.1.5N]
        NFS_IP[Filestore<br/>10.10.1.100]
      end
    end
    
    subgraph "Private Service Connect"
      PSC[PSC Endpoint<br/>10.20.2.0/24]
    end
    
    COMP_NODE --> PSC
    PSC --> COMP_DB
    PSC --> COMP_WEB
    
    DP_MASTER --> NFS_IP
    DP_WORK1 --> NFS_IP
    DP_WORK2 --> NFS_IP
    DP_WORKN --> NFS_IP
    
    style COMP_NODE fill:#e1f5e1
    style DP_MASTER fill:#ffe1e1
    style DP_WORK1 fill:#ffe1e1
    style DP_WORK2 fill:#ffe1e1
    style DP_WORKN fill:#ffe1e1
  ```

#### Data Flow
  ```mermaid
  sequenceDiagram
    participant Dev as Developer
    participant Comp as Cloud Composer
    participant DP as Dataproc API
    participant Cluster as Dask Cluster
    participant Storage as Storage (NFS/GCS)
    participant Mon as Monitoring
    
    Dev->>Comp: Trigger DAG
    Comp->>DP: Create Cluster Request
    DP->>Cluster: Provision VMs
    Cluster->>Cluster: Initialize Dask
    Cluster->>Storage: Mount NFS
    
    Comp->>Cluster: Submit Python Job
    Cluster->>Cluster: Start YarnCluster
    Cluster->>Cluster: Scale Workers
    
    loop Process Data
        Cluster->>Storage: Read Data
        Cluster->>Cluster: Distributed Compute
        Cluster->>Storage: Write Results
        Cluster->>Mon: Send Metrics
    end
    
    Cluster->>Comp: Job Complete
    Comp->>DP: Delete Cluster
    DP->>Cluster: Terminate VMs
    Comp->>Dev: Notify Success
  ```

#### Security Model
  ```mermaid
  graph TB
    subgraph "Service Accounts"
      SA_COMP[sa_composer<br/>Orchestrator]
      SA_DP[sa_dataproc_runtime<br/>Compute Runtime]
      SA_CICD[sa_tf_cicd<br/>Deployment]
    end
    
    subgraph "IAM Roles"
      R1[roles/dataproc.editor]
      R2[roles/iam.serviceAccountUser]
      R3[roles/storage.objectViewer]
      R4[roles/logging.logWriter]
      R5[roles/compute.networkUser]
    end
    
    subgraph "Resources"
      DP_CLUSTER[Dataproc Clusters]
      GCS_STAGING[Staging Bucket]
      SUBNET[VPC Subnets]
      LOGS[Cloud Logging]
    end
    
    SA_COMP --> R1
    SA_COMP --> R2
    SA_COMP --> R3
    SA_COMP --> R5
    
    SA_DP --> R3
    SA_DP --> R4
    
    R1 --> DP_CLUSTER
    R2 --> SA_DP
    R3 --> GCS_STAGING
    R4 --> LOGS
    R5 --> SUBNET
    
    style SA_COMP fill:#e1e1ff
    style SA_DP fill:#ffe1e1
    style SA_CICD fill:#e1ffe1
  ```

#### Deployment Sequence
  ```mermaid
  flowchart LR
    subgraph "Phase 0: Prerequisites"
      A1[Enable APIs<br/>composer, dataproc]
      A2[Verify A01<br/>Infrastructure]
      A3[Check Quotas<br/>CPUs, IPs]
    end
    
    subgraph "Phase 1: Service Accounts"
      B1[Create SA<br/>sa_composer]
      B2[Create SA<br/>sa_dataproc_runtime]
      B3[Configure IAM<br/>Bindings]
    end
    
    subgraph "Phase 2: Storage"
      C1[Create Staging<br/>Bucket]
      C2[Set Lifecycle<br/>Policies]
      C3[Grant SA<br/>Permissions]
    end
    
    subgraph "Phase 3: Composer"
      D1[Deploy Composer<br/>Environment]
      D2[Configure<br/>Variables]
      D3[Upload DAGs]
    end
    
    subgraph "Phase 4: Testing"
      E1[Test Cluster<br/>Creation]
      E2[Validate NFS<br/>Access]
      E3[Run Sample<br/>Jobs]
    end
    
    A1 --> A2 --> A3
    A3 --> B1 --> B2 --> B3
    B3 --> C1 --> C2 --> C3
    C3 --> D1 --> D2 --> D3
    D3 --> E1 --> E2 --> E3
    
    style A1 fill:#f9f
    style B1 fill:#bbf
    style C1 fill:#bfb
    style D1 fill:#ffb
    style E1 fill:#fbb
  ```
---

</details>

### Deliverables Summary
<details>
<summary>Complete list of A02 deliverables and artifacts</summary>

---
#### ✅ Cluster Architecture Design
- **Node Configuration**: Master + 2-10 workers with detailed resource allocation
- **Networking**: Private IP design with subnet allocation strategy
- **Resource Management**: YARN-based with per-user quotas
- **Documentation**: Comprehensive architecture diagrams and specifications

#### ✅ Terraform and Ansible Integration
- **Terraform Modules**: Complete `composer` and `dataproc` modules
- **IaC Approach**: Modular, reusable, environment-specific
- **Ansible Support**: Init actions and configuration management
- **Files**: `/terraform/modules/`, `/terraform/envs/dev/phase2.tf`

#### ✅ User Access Management
- **Primary Access**: Cloud Composer UI with IAP authentication
- **Job Submission**: Multiple methods (Airflow, gcloud, Python)
- **Dashboard Access**: Component Gateway with IAM control
- **Documentation**: Detailed flow diagrams and permission matrices

#### ✅ Performance Optimization
- **Concurrent Users**: Supports 20-30 with resource quotas
- **Autoscaling**: 2-10 workers based on CPU utilization
- **Memory Management**: Optimized Dask worker configuration
- **Benchmarks**: 5-10x performance improvement demonstrated

#### ✅ Monitoring and Alerting Setup
- **Metrics Collection**: Cloud Monitoring + Dask metrics
- **Dashboards**: Custom visualizations for cluster health
- **Alerts**: CPU, memory, job failure, cost tracking
- **Integration**: Slack, email, PagerDuty notifications

#### ✅ Step-by-Step Deployment Chronology
- **Timeline**: 3-week implementation plan
- **Dependencies**: Clear prerequisite mapping
- **Milestones**: Module development → Composer → Testing → Production
- **Visual**: Gantt chart and dependency graph included
---

</details>

### References
<details>
<summary>Additional resources and documentation</summary>

---
#### Internal Documentation
- A01 Infrastructure Guide: `../A01/report_A01.md`
- Terraform Modules: `/terraform/modules/composer`, `/terraform/modules/dataproc`
- Airflow DAGs: `/dask-cluster/dags/`
- Python Jobs: `/dask-cluster/jobs/`

#### External Resources
- [Cloud Composer Documentation](https://cloud.google.com/composer/docs)
- [Dataproc Dask Integration](https://cloud.google.com/dataproc/docs/tutorials/dask)
- [Dask on YARN Guide](https://yarn.dask.org/)
- [GCP Private IP Configuration](https://cloud.google.com/vpc/docs/configure-private-google-access)

#### Support Contacts
- Platform Team: platform@company.com
- GCP Support: [Support Case Portal]
- Dask Community: https://dask.discourse.group/
---

</details>
