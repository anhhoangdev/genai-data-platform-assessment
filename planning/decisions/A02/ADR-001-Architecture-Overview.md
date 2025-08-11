# ADR-001: A02 Scalable Python Compute Platform Architecture Overview

**Status:** Implemented  
**Date:** 2025-01-15  
**Decision Makers:** Platform Engineering Team  

## Context

Designing a scalable, cost-effective distributed Python compute platform to support 20-30 data engineers with requirements for:
- Ephemeral Dask clusters for elastic compute
- Integration with existing A01 infrastructure (FreeIPA, NFS, networking)
- Cloud Composer orchestration for workflow management
- Cost optimization through pay-per-use model
- Support for diverse workloads (ETL, ML training, analytics)

## Decision

Implement an **ephemeral compute architecture** with persistent orchestration layer:

### Core Architecture Pattern
- **Orchestration Layer**: Cloud Composer 2 (managed Airflow) for workflow scheduling
- **Compute Layer**: Ephemeral Dataproc clusters with Dask framework
- **Storage Integration**: Dual access to Filestore NFS and GCS buckets
- **Cost Model**: Auto-scaling clusters that scale to zero when idle

### Key Design Principles
1. **Ephemeral by Design**: Clusters created on-demand, destroyed after job completion
2. **A01 Integration**: Leverage existing VPC, security, and storage infrastructure
3. **Developer Experience**: Familiar Python/Pandas API with minimal code changes
4. **Cost Optimization**: 60-80% cost reduction vs persistent clusters

## Architecture Components

### 1. Orchestration Layer
```
Cloud Composer 2 Environment
├── Private IP configuration (10.10.1.0/24)
├── Airflow 2.0+ with Dask DAG examples
├── Integration with A01 service accounts and KMS
└── Access via IAP through bastion host
```

### 2. Compute Layer
```
Ephemeral Dataproc Clusters
├── Master Node: n2-standard-4 (Dask Scheduler, YARN RM)
├── Worker Nodes: 2-10 n2-standard-4 (auto-scaling)
├── Dask Framework: distributed Python execution
├── Storage: 100GB pd-balanced + local SSD caching
└── Network: Private IPs only, Cloud NAT egress
```

### 3. Storage Integration
```
Hybrid Storage Strategy
├── Filestore NFS: /shared/* for persistent collaboration
├── GCS Buckets: Object storage for large datasets
├── Local SSD: Temporary/cache storage during processing
└── Memory: 14GB per worker for in-memory operations
```

### 4. Access Patterns
```
Users → Composer UI (via IAP) → DAG Triggers
Users → Bastion → Dataproc (Component Gateway)
Dataproc → Filestore NFS (shared data)
Dataproc → GCS (via Private Google Access)
Dataproc → FreeIPA (service accounts, no user auth)
```

## Technical Decisions

### Compute Platform: Dataproc + Dask
**Rationale:**
- Managed Hadoop/YARN infrastructure reduces operational overhead
- Dask provides familiar Python API with distributed execution
- Auto-scaling capabilities for cost optimization
- Integration with GCP security and networking

**Alternatives Considered:**
- **Google Kubernetes Engine**: More complex operations, less cost-effective for batch workloads
- **Compute Engine VMs**: Requires manual cluster management and job scheduling
- **Cloud Functions/Cloud Run**: Limited for long-running, memory-intensive workloads

### Orchestration: Cloud Composer 2
**Rationale:**
- Managed Airflow service with enterprise features
- Strong integration with GCP services (Dataproc, GCS, IAM)
- Familiar workflow patterns for data engineering teams
- Built-in monitoring and logging

**Alternatives Considered:**
- **Self-managed Airflow**: Higher operational burden, security complexity
- **Cloud Workflows**: Limited for complex data processing pipelines
- **Pub/Sub + Cloud Functions**: Lacks workflow visualization and dependency management

### Storage Strategy: Hybrid NFS + GCS
**Rationale:**
- **NFS**: Low-latency access for shared code, configurations, and intermediate results
- **GCS**: Cost-effective storage for large datasets and long-term archival
- **Local SSD**: High-performance temporary storage during processing

### Cost Optimization Strategy
**Ephemeral Cluster Lifecycle:**
1. **Trigger**: Composer DAG initiates cluster creation
2. **Execution**: Cluster processes workload with auto-scaling
3. **Completion**: Cluster automatically terminated
4. **Cost**: Pay only for actual compute time (5-60 minutes typical)

**Resource Right-Sizing:**
- Workload-specific cluster configurations
- Preemptible instances for fault-tolerant jobs
- Intelligent instance type selection based on job characteristics

## Integration with A01 Infrastructure

### Network Integration
- **VPC**: Shared `vpc-data-platform` with A01
- **Subnets**: New `subnet-dataproc` (10.10.3.0/24) for cluster nodes
- **Firewall**: Composer and Dataproc-specific rules added to existing security model
- **DNS**: Services registered in existing `corp.internal` private zone

### Security Integration
- **IAM**: Dataproc service accounts with minimal required permissions
- **Encryption**: CMEK encryption for cluster disks using existing KMS keys
- **Access**: All access through existing IAP + bastion pattern
- **Authentication**: Service account-based (no user authentication on clusters)

### Storage Integration
- **Filestore**: Existing NFS mounts available on all cluster nodes
- **Directory Structure**: 
  ```
  /shared/data/        # Raw datasets and processed outputs
  /shared/projects/    # Shared code and notebooks
  /shared/dask-tmp/    # Temporary Dask computation results
  ```

## Performance Characteristics

### Cluster Specifications
- **Master Node**: 4 vCPU, 16GB RAM, 100GB disk
- **Worker Nodes**: 4 vCPU, 14GB available for Dask, 100GB disk + local SSD
- **Auto-scaling**: 2 minimum, 10 maximum workers
- **Network**: 10 Gbps between nodes within same zone

### Expected Performance
- **Startup Time**: 3-5 minutes for cluster provisioning
- **Processing Speed**: 5-10x faster than single-machine workflows
- **Throughput**: 50-100 GB/hour per worker node for typical ETL workloads
- **Concurrent Users**: Support for 20-30 engineers with resource quotas

### Resource Allocation
- **Per-User Limits**: 3 workers max, 42GB memory total
- **Queue Management**: YARN Fair Scheduler with priority queues
- **Cost Controls**: Per-user budget alerts and job timeout limits

## Operational Model

### Day 1 Operations
- Terraform deployment of Composer environment
- Ansible configuration of cluster templates and DAGs
- User onboarding with example Dask workflows

### Day 2 Operations
- **Monitoring**: Cloud Monitoring integration with Dask metrics
- **Logging**: Centralized logging via Cloud Logging
- **Alerting**: Budget alerts and cluster failure notifications
- **Maintenance**: Automated Dataproc image updates and security patches

### Cost Management
- **Budget Controls**: Per-project and per-user spending limits
- **Usage Tracking**: Detailed cost attribution by user and workload type
- **Optimization**: Regular review of instance types and cluster configurations

## Consequences

### Benefits
- **Cost Efficiency**: 60-80% reduction in compute costs vs persistent clusters
- **Elasticity**: Automatic scaling based on demand
- **Developer Productivity**: Familiar Python API with distributed execution
- **Integration**: Seamless integration with existing A01 platform
- **Operational Simplicity**: Managed services reduce maintenance overhead

### Trade-offs
- **Startup Latency**: 3-5 minute cluster creation time for each job
- **Learning Curve**: Teams need to understand distributed computing concepts
- **Complexity**: Additional orchestration layer and cluster management
- **Vendor Lock-in**: Tight coupling with GCP managed services

### Risks and Mitigations
- **Risk**: Dataproc cluster creation failures
  - **Mitigation**: Retry logic in Composer DAGs, monitoring and alerting
- **Risk**: Cost overruns from uncontrolled scaling
  - **Mitigation**: Per-user quotas, budget alerts, automatic timeouts
- **Risk**: Performance degradation with network storage
  - **Mitigation**: Local SSD caching, intelligent data placement

## Implementation Status

### Phase 1: Foundation (Completed ✅)
- Cloud Composer environment deployment
- Dataproc cluster templates configuration
- Basic Dask DAG examples
- Integration with A01 VPC and security

### Phase 2: Production Readiness (Completed ✅)
- Auto-scaling configuration and testing
- Monitoring and alerting setup
- Cost tracking and budget controls
- Performance optimization and benchmarking

### Phase 3: User Onboarding (Completed ✅)
- Documentation and tutorials
- Example workloads and best practices
- Training materials for development teams

## References

- [A02 Main Report](../../docs/reports/A02/report_A02.md)
- [A02 Architecture Details](../../docs/reports/A02/report_A02_part01_architecture.md)
- [A02 Architecture Diagrams](../../docs/reports/A02/report_A02_diagram.md)
- [Dask DAG Examples](../../dask-cluster/dags/)
- [Dask Job Examples](../../dask-cluster/jobs/)
