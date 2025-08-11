# ADR-003: Cloud Composer Orchestration Architecture

**Status:** Implemented  
**Date:** 2025-01-15  
**Decision Makers:** Platform Engineering Team, Data Engineering Team  

## Context

Following the architectural decisions in ADR-001 and ADR-002, we need to establish the orchestration layer for managing ephemeral Dask clusters and data pipeline workflows. Key requirements:

- Managed Airflow service for workflow orchestration
- Integration with ephemeral Dataproc cluster lifecycle
- Support for diverse data pipeline patterns
- Resource management and cost control
- Developer-friendly DAG development and deployment

## Decision

Implement **Cloud Composer 2** as the central orchestration platform with custom operators and workflow patterns optimized for ephemeral compute:

### Core Orchestration Strategy
- **Platform**: Cloud Composer 2 (managed Airflow 2.x)
- **Architecture**: Private IP configuration integrated with A01 VPC
- **Workflow Patterns**: Custom DAG templates for common data pipeline types
- **Resource Management**: Intelligent cluster sizing and lifecycle management

## Technical Implementation

### 1. Cloud Composer Environment Configuration

#### Environment Specifications
```yaml
Composer Environment:
  name: data-platform-composer
  location: us-central1
  node_config:
    zone: us-central1-b
    machine_type: n1-standard-2
    disk_size_gb: 100
    node_count: 3
  
  software_config:
    airflow_version: 2.7.3
    python_version: 3.10
    image_version: composer-2.4.8-airflow-2.7.3
    
  private_environment_config:
    enable_private_ip: true
    master_ipv4_cidr_block: 172.16.0.0/28
    cloud_sql_ipv4_cidr_block: 172.16.0.16/28
    
  network_config:
    network: projects/PROJECT_ID/global/networks/vpc-data-platform
    subnetwork: projects/PROJECT_ID/regions/us-central1/subnetworks/subnet-services
    
  encryption_config:
    kms_key_name: projects/PROJECT_ID/locations/us-central1/keyRings/sec-core/cryptoKeys/secrets-cmek
```

#### Airflow Configuration Overrides
```python
# airflow.cfg optimizations for ephemeral compute
AIRFLOW_CONFIG = {
    'core': {
        'max_active_runs_per_dag': 10,
        'max_active_tasks_per_dag': 50,
        'parallelism': 64,
        'dagbag_import_timeout': 180,
        'killed_task_cleanup_time': 300
    },
    'scheduler': {
        'dag_dir_list_interval': 60,
        'catchup_by_default': False,
        'max_threads': 4,
        'parsing_processes': 2
    },
    'webserver': {
        'workers': 2,
        'worker_timeout': 120,
        'web_server_port': 8080
    },
    'celery': {
        'worker_concurrency': 4,
        'worker_autoscale': '8,2'
    }
}
```

### 2. Custom Airflow Operators

#### Ephemeral Dataproc Operator
```python
class EphemeralDataprocDaskOperator(BaseOperator):
    """
    Custom operator for managing ephemeral Dataproc clusters with Dask
    """
    
    template_fields = ['cluster_name', 'job_args', 'pyspark_job']
    
    def __init__(
        self,
        cluster_name: str,
        job_file: str,
        cluster_config: dict = None,
        job_args: list = None,
        auto_delete: bool = True,
        **kwargs
    ):
        super().__init__(**kwargs)
        self.cluster_name = cluster_name
        self.job_file = job_file
        self.cluster_config = cluster_config or DEFAULT_CLUSTER_CONFIG
        self.job_args = job_args or []
        self.auto_delete = auto_delete
    
    def execute(self, context):
        """Execute Dask job on ephemeral cluster"""
        
        # 1. Create cluster
        cluster_client = DataprocClusterManagerClient()
        cluster_operation = self._create_cluster(cluster_client, context)
        
        # 2. Wait for cluster ready
        self._wait_for_cluster_ready(cluster_operation)
        
        # 3. Submit Dask job
        job_client = JobControllerClient()
        job_operation = self._submit_dask_job(job_client, context)
        
        # 4. Monitor job execution
        job_result = self._monitor_job(job_operation)
        
        # 5. Cleanup cluster (if auto_delete)
        if self.auto_delete:
            self._delete_cluster(cluster_client)
        
        return job_result
    
    def _create_cluster(self, client, context):
        """Create optimized Dataproc cluster for Dask workloads"""
        
        cluster_config = {
            'project_id': Variable.get('gcp_project_id'),
            'cluster_name': self.cluster_name,
            'config': {
                'master_config': {
                    'num_instances': 1,
                    'machine_type': 'n2-standard-4',
                    'disk_config': {
                        'boot_disk_type': 'pd-balanced',
                        'boot_disk_size_gb': 100
                    }
                },
                'worker_config': {
                    'num_instances': self._calculate_initial_workers(context),
                    'machine_type': 'n2-standard-4',
                    'disk_config': {
                        'boot_disk_type': 'pd-balanced',
                        'boot_disk_size_gb': 100,
                        'num_local_ssds': 1
                    }
                },
                'software_config': {
                    'image_version': '2.1-debian11',
                    'properties': self._get_dask_properties(),
                    'optional_components': ['ZEPPELIN']
                },
                'initialization_actions': [
                    'gs://dataproc-initialization-actions/dask/dask.sh',
                    f'gs://{Variable.get("scripts_bucket")}/configure-nfs.sh'
                ],
                'endpoint_config': {
                    'enable_http_port_access': True
                },
                'security_config': {
                    'kerberos_config': {
                        'enable_kerberos': False
                    }
                },
                'autoscaling_config': {
                    'policy_uri': f'projects/{Variable.get("gcp_project_id")}/regions/us-central1/autoscalingPolicies/dask-autoscaling'
                }
            }
        }
        
        return client.create_cluster(
            request={
                'project_id': cluster_config['project_id'],
                'region': 'us-central1',
                'cluster': cluster_config
            }
        )
```

#### Intelligent Cluster Sizing
```python
class ClusterSizingStrategy:
    """Determine optimal cluster configuration based on job characteristics"""
    
    def __init__(self):
        self.sizing_rules = {
            'small_etl': {
                'data_size_gb': (0, 10),
                'workers': 2,
                'machine_type': 'n2-standard-2'
            },
            'medium_etl': {
                'data_size_gb': (10, 100),
                'workers': 4,
                'machine_type': 'n2-standard-4'
            },
            'large_etl': {
                'data_size_gb': (100, 1000),
                'workers': 8,
                'machine_type': 'n2-standard-4'
            },
            'ml_training': {
                'memory_intensive': True,
                'workers': 6,
                'machine_type': 'n2-highmem-4'
            },
            'interactive': {
                'low_latency': True,
                'workers': 2,
                'machine_type': 'n2-standard-4',
                'preemptible': False
            }
        }
    
    def calculate_cluster_size(self, job_metadata: dict) -> dict:
        """Calculate optimal cluster configuration"""
        
        workload_type = job_metadata.get('workload_type', 'medium_etl')
        data_size = job_metadata.get('data_size_gb', 50)
        memory_required = job_metadata.get('memory_gb', 32)
        
        # Select base configuration
        base_config = self.sizing_rules.get(workload_type, self.sizing_rules['medium_etl'])
        
        # Apply dynamic adjustments
        if data_size > 500:
            base_config['workers'] = min(base_config['workers'] * 2, 15)
        
        if memory_required > 64:
            base_config['machine_type'] = 'n2-highmem-8'
        
        return base_config
```

### 3. DAG Templates and Patterns

#### Standard ETL Pipeline Template
```python
def create_etl_dag(
    dag_id: str,
    input_path: str,
    output_path: str,
    processing_script: str,
    schedule_interval: str = None,
    **kwargs
) -> DAG:
    """Standard ETL pipeline template"""
    
    default_args = {
        'owner': 'data-platform',
        'depends_on_past': False,
        'email_on_failure': True,
        'email_on_retry': False,
        'retries': 2,
        'retry_delay': timedelta(minutes=5),
        'max_active_runs': 3
    }
    
    dag = DAG(
        dag_id=dag_id,
        default_args=default_args,
        description=f'ETL pipeline for {dag_id}',
        schedule_interval=schedule_interval,
        start_date=datetime(2024, 1, 1),
        catchup=False,
        tags=['etl', 'dask', 'production']
    )
    
    # Data validation task
    validate_input = GCSObjectExistenceSensor(
        task_id='validate_input_data',
        bucket=input_path.split('/')[2],
        object=input_path.split('/', 3)[3],
        timeout=300,
        dag=dag
    )
    
    # Main processing task
    process_data = EphemeralDataprocDaskOperator(
        task_id='process_data',
        cluster_name=f'etl-{dag_id}-{{{{ ds_nodash }}}}',
        job_file=processing_script,
        job_args=[
            '--input-path', input_path,
            '--output-path', output_path,
            '--execution-date', '{{ ds }}'
        ],
        cluster_config={
            'workload_type': 'medium_etl',
            'data_size_gb': kwargs.get('estimated_data_size', 50)
        },
        dag=dag
    )
    
    # Data quality validation
    validate_output = DaskDataQualityOperator(
        task_id='validate_output_quality',
        data_path=output_path,
        quality_rules=kwargs.get('quality_rules', []),
        dag=dag
    )
    
    # Success notification
    notify_success = EmailOperator(
        task_id='notify_success',
        to=['data-team@company.com'],
        subject=f'ETL Pipeline {dag_id} Completed Successfully',
        html_content='Pipeline completed successfully. Data available at {{ params.output_path }}',
        params={'output_path': output_path},
        dag=dag
    )
    
    # Task dependencies
    validate_input >> process_data >> validate_output >> notify_success
    
    return dag
```

#### ML Training Pipeline Template
```python
def create_ml_training_dag(
    dag_id: str,
    model_config: dict,
    training_data_path: str,
    model_output_path: str,
    **kwargs
) -> DAG:
    """ML training pipeline template with experiment tracking"""
    
    dag = DAG(
        dag_id=dag_id,
        default_args={
            'owner': 'ml-platform',
            'retries': 1,
            'retry_delay': timedelta(minutes=10)
        },
        description=f'ML training pipeline for {model_config["model_name"]}',
        schedule_interval=kwargs.get('schedule_interval'),
        start_date=datetime(2024, 1, 1),
        catchup=False,
        tags=['ml', 'training', 'dask']
    )
    
    # Feature engineering
    feature_engineering = EphemeralDataprocDaskOperator(
        task_id='feature_engineering',
        cluster_name=f'ml-features-{dag_id}-{{{{ ds_nodash }}}}',
        job_file='gs://scripts/feature_engineering.py',
        job_args=[
            '--data-path', training_data_path,
            '--output-path', f'{model_output_path}/features/',
            '--config', json.dumps(model_config)
        ],
        cluster_config={
            'workload_type': 'ml_training',
            'memory_gb': model_config.get('memory_requirement', 64)
        },
        dag=dag
    )
    
    # Model training
    train_model = EphemeralDataprocDaskOperator(
        task_id='train_model',
        cluster_name=f'ml-training-{dag_id}-{{{{ ds_nodash }}}}',
        job_file='gs://scripts/train_model.py',
        job_args=[
            '--features-path', f'{model_output_path}/features/',
            '--model-output', f'{model_output_path}/model/',
            '--experiment-name', dag_id,
            '--run-id', '{{ run_id }}'
        ],
        cluster_config={
            'workload_type': 'ml_training',
            'memory_gb': model_config.get('memory_requirement', 64),
            'gpu_enabled': model_config.get('use_gpu', False)
        },
        dag=dag
    )
    
    # Model validation
    validate_model = MLModelValidationOperator(
        task_id='validate_model',
        model_path=f'{model_output_path}/model/',
        validation_metrics=model_config.get('validation_metrics', []),
        threshold_config=model_config.get('quality_thresholds', {}),
        dag=dag
    )
    
    # Model registration
    register_model = MLModelRegistryOperator(
        task_id='register_model',
        model_name=model_config['model_name'],
        model_path=f'{model_output_path}/model/',
        model_version='{{ ds }}',
        metadata={
            'training_dag': dag_id,
            'run_id': '{{ run_id }}',
            'data_path': training_data_path
        },
        dag=dag
    )
    
    feature_engineering >> train_model >> validate_model >> register_model
    
    return dag
```

### 4. Resource Management and Cost Control

#### Dynamic Resource Allocation
```python
class ResourceManager:
    """Manage cluster resources and enforce quotas"""
    
    def __init__(self):
        self.user_quotas = self._load_user_quotas()
        self.active_clusters = {}
        
    def request_cluster(self, user: str, cluster_spec: dict) -> dict:
        """Validate and approve cluster creation request"""
        
        user_quota = self.user_quotas.get(user, self.user_quotas['default'])
        current_usage = self._get_current_usage(user)
        
        # Check quota limits
        if current_usage['clusters'] >= user_quota['max_clusters']:
            raise QuotaExceededException(f"User {user} exceeds cluster limit")
        
        if current_usage['total_cores'] + cluster_spec['cores'] > user_quota['max_cores']:
            raise QuotaExceededException(f"User {user} exceeds core limit")
        
        # Optimize cluster configuration
        optimized_spec = self._optimize_cluster_spec(cluster_spec, user_quota)
        
        # Track allocation
        self._track_allocation(user, optimized_spec)
        
        return optimized_spec
    
    def _optimize_cluster_spec(self, spec: dict, quota: dict) -> dict:
        """Optimize cluster spec within quota constraints"""
        
        # Apply cost optimization
        if spec.get('cost_sensitive', True):
            spec['preemptible_percentage'] = min(
                spec.get('preemptible_percentage', 50),
                quota.get('max_preemptible_percentage', 80)
            )
        
        # Right-size based on historical usage
        historical_efficiency = self._get_historical_efficiency(spec['workload_type'])
        if historical_efficiency < 0.7:  # Low efficiency
            spec['workers'] = max(2, int(spec['workers'] * 0.8))
        
        return spec
```

#### Cost Tracking and Budgets
```python
class CostTracker:
    """Track and control costs for ephemeral compute"""
    
    def __init__(self):
        self.cost_cache = {}
        self.budget_alerts = {}
    
    def track_cluster_cost(self, cluster_name: str, user: str, 
                          start_time: datetime, end_time: datetime) -> float:
        """Calculate and track cluster costs"""
        
        duration_hours = (end_time - start_time).total_seconds() / 3600
        
        # Get cluster configuration
        cluster_config = self._get_cluster_config(cluster_name)
        
        # Calculate base cost
        master_cost = self._calculate_instance_cost(
            cluster_config['master_machine_type'], duration_hours
        )
        
        worker_cost = self._calculate_instance_cost(
            cluster_config['worker_machine_type'], 
            duration_hours,
            instances=cluster_config['worker_count'],
            preemptible=cluster_config.get('preemptible', False)
        )
        
        # Add storage costs
        storage_cost = self._calculate_storage_cost(cluster_config, duration_hours)
        
        total_cost = master_cost + worker_cost + storage_cost
        
        # Update user budget tracking
        self._update_user_budget(user, total_cost)
        
        return total_cost
    
    def check_budget_alerts(self, user: str) -> list:
        """Check if user is approaching budget limits"""
        
        alerts = []
        user_spending = self._get_user_monthly_spending(user)
        user_budget = self._get_user_budget(user)
        
        if user_spending > user_budget * 0.8:
            alerts.append({
                'level': 'warning',
                'message': f'User {user} has used 80% of monthly budget'
            })
        
        if user_spending > user_budget * 0.95:
            alerts.append({
                'level': 'critical',
                'message': f'User {user} has used 95% of monthly budget'
            })
        
        return alerts
```

### 5. Monitoring and Alerting Integration

#### DAG Performance Monitoring
```python
# Custom metrics for Composer performance
COMPOSER_METRICS = {
    'dag_execution_time': 'histogram',
    'cluster_creation_time': 'histogram',
    'job_success_rate': 'gauge',
    'cluster_utilization': 'gauge',
    'cost_per_job': 'histogram',
    'queue_depth': 'gauge'
}

def emit_custom_metrics(dag_run, task_instance):
    """Emit custom metrics for monitoring"""
    
    from airflow.providers.google.cloud.hooks.stackdriver import StackdriverHook
    
    metrics_hook = StackdriverHook()
    
    # DAG execution metrics
    if dag_run.state == 'success':
        execution_time = (dag_run.end_date - dag_run.start_date).total_seconds()
        metrics_hook.write_time_series_data([{
            'metric': {
                'type': 'custom.googleapis.com/dask/dag_execution_time',
                'labels': {
                    'dag_id': dag_run.dag_id,
                    'user': dag_run.conf.get('user', 'unknown')
                }
            },
            'points': [{
                'value': {'double_value': execution_time}
            }]
        }])
```

#### Alerting Configuration
```yaml
Alerting Rules:
  - name: composer_dag_failures
    rules:
      - alert: DagFailureRate
        expr: dag_failure_rate > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High DAG failure rate detected"
          
  - name: cluster_costs
    rules:
      - alert: HighUserSpending
        expr: user_monthly_spending > user_budget * 0.9
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "User approaching budget limit"
          
  - name: resource_utilization
    rules:
      - alert: LowClusterUtilization
        expr: avg_cluster_cpu_utilization < 0.3
        for: 10m
        labels:
          severity: info
        annotations:
          summary: "Consider reducing cluster size"
```

## Integration with A01 Infrastructure

### Network Integration
```yaml
Network Configuration:
  vpc_network: vpc-data-platform
  subnetwork: subnet-services
  private_ip_only: true
  authorized_networks:
    - cidr_block: 10.10.1.0/24  # Management subnet
      display_name: "A01 management subnet"
  
Firewall Rules:
  - name: allow-composer-to-dataproc
    direction: EGRESS
    source_tags: [composer-worker]
    target_tags: [dataproc-cluster]
    ports: [22, 8080, 8088, 8787]  # SSH, YARN, Dask dashboard
```

### Security Integration
```python
# Integration with A01 security model
SECURITY_CONFIG = {
    'service_accounts': {
        'composer_sa': 'composer-worker@project.iam.gserviceaccount.com',
        'dataproc_sa': 'dataproc-worker@project.iam.gserviceaccount.com'
    },
    'kms_integration': {
        'encryption_key': 'projects/project/locations/region/keyRings/sec-core/cryptoKeys/secrets-cmek',
        'encrypt_composer_disk': True,
        'encrypt_dataproc_disk': True
    },
    'secrets_manager': {
        'dask_config': 'projects/project/secrets/dask-config',
        'ml_api_keys': 'projects/project/secrets/ml-platform-keys'
    }
}
```

## Consequences

### Benefits Achieved
- **Workflow Orchestration**: Centralized management of all data pipelines
- **Cost Optimization**: Intelligent cluster sizing and lifecycle management
- **Developer Experience**: Template-based DAG development with best practices
- **Monitoring**: Comprehensive visibility into pipeline performance and costs
- **Integration**: Seamless integration with A01 infrastructure and security

### Operational Considerations
- **Learning Curve**: Teams need Airflow knowledge for custom DAG development
- **Complexity**: Orchestration layer adds system complexity
- **Debugging**: Distributed pipeline debugging requires specialized tools
- **Resource Management**: Need ongoing monitoring and quota management

### Future Enhancements
- **Advanced Scheduling**: ML-based workload prediction and scheduling
- **Multi-region Support**: Cross-region pipeline execution
- **Real-time Streaming**: Integration with streaming data platforms
- **Advanced Monitoring**: Custom dashboards and anomaly detection

## References

- [ADR-001: A02 Architecture Overview](ADR-001-Architecture-Overview.md)
- [ADR-002: Dask Dataproc Implementation](ADR-002-Dask-Dataproc-Implementation.md)
- [Cloud Composer Documentation](https://cloud.google.com/composer/docs)
- [Airflow Best Practices](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html)
- [A02 DAG Examples](../../dask-cluster/dags/)
