---
title: report_A02_diagram
---

# A02 - Dask Cluster Architecture Diagrams

---
## System Architecture
---

### Complete Integration with A01 Platform
<details>
<summary>Comprehensive view of A02 Dask cluster integration with existing A01 infrastructure</summary>

---
- **Integration Strategy**: Seamless integration with existing A01 VPC, security, and identity
- **Network Isolation**: Private IP deployment with existing firewall and NAT configuration
- **Identity Reuse**: Leverages A01's IAP, FreeIPA, and WIF for unified access control
- **Storage Integration**: Access to both Filestore NFS and Cloud Storage

```mermaid
    graph TB
    subgraph "Internet/Users"
        Users["Engineers (20-30)<br/>Google Workspace OAuth"]
        GitHub["GitHub Actions<br/>CI/CD Pipeline"]
    end

    subgraph "A01 + A02 Integrated Platform"
        subgraph "Security Layer"
        IAP["IAP Identity Proxy<br/>OAuth2 Gateway"]
        WIF["Workload Identity Federation<br/>GitHub → GCP Auth"]
        KMS["Cloud KMS<br/>Customer-Managed Keys"]
        end
        
        subgraph "VPC: data-platform (10.0.0.0/16)"
        subgraph "management subnet (10.0.1.0/24)"
            Bastion["Bastion VM<br/>SSH Gateway"]
            FreeIPA["FreeIPA Server<br/>LDAP/Kerberos"]
            Composer["Cloud Composer 2<br/>Airflow Orchestration"]
        end
        
        subgraph "services subnet (10.0.2.0/24)"
            Filestore["Filestore Enterprise<br/>4TB NFS Storage"]
            DataprocCluster["Ephemeral Dataproc<br/>Dask Clusters"]
        end
        
        subgraph "workstations subnet (10.0.3.0/24)"
            WorkstationMIG["Developer VMs<br/>Auto-scaling 0-10"]
        end
        
        NAT["Cloud NAT<br/>Outbound Internet"]
        end
        
        subgraph "Cloud Services"
        GCS["Cloud Storage<br/>Data Lake + Staging"]
        Monitoring["Cloud Monitoring<br/>Metrics + Alerts"]
        Logging["Cloud Logging<br/>Centralized Logs"]
        end
    end

    Users -->|"OAuth2 Auth"| IAP
    GitHub -->|"OIDC Token"| WIF
    
    IAP --> Bastion
    IAP --> Composer
    Bastion --> FreeIPA
    Bastion --> WorkstationMIG
    
    Composer -->|"Create/Delete"| DataprocCluster
    DataprocCluster -->|"NFS Mount"| Filestore
    DataprocCluster -->|"Private Access"| GCS
    DataprocCluster --> NAT
    
    WorkstationMIG --> FreeIPA
    WorkstationMIG --> Filestore
    WorkstationMIG --> Composer
    
    DataprocCluster --> Monitoring
    DataprocCluster --> Logging
    Composer --> Monitoring
    Composer --> Logging
    
    KMS -.->|"CMEK Encryption"| Filestore
    KMS -.->|"CMEK Encryption"| GCS
    KMS -.->|"CMEK Encryption"| DataprocCluster

    classDef security fill:#ffe6e6,stroke:#ff4444,stroke-width:2px
    classDef compute fill:#e6f3ff,stroke:#4488ff,stroke-width:2px
    classDef storage fill:#e6ffe6,stroke:#44ff44,stroke-width:2px
    classDef new fill:#fff0e6,stroke:#ff8844,stroke-width:3px
    
    class IAP,WIF,KMS,FreeIPA security
    class Bastion,WorkstationMIG,DataprocCluster compute
    class Filestore,GCS storage
    class Composer,DataprocCluster new
```

---

</details>

### Dask Cluster Internal Architecture
<details>
<summary>Detailed view of ephemeral Dataproc cluster with Dask framework</summary>

---
- **Cluster Composition**: Master node with scheduler + auto-scaling worker pool
- **Resource Management**: YARN integration with Dask distributed computing
- **Performance Optimization**: Optimized for 20-30 concurrent users
- **Cost Efficiency**: Ephemeral deployment with scale-to-zero capability

```mermaid
graph TB
  subgraph "Ephemeral Dataproc Cluster"
    subgraph "Master Node (n2-standard-4)"
      RM["YARN ResourceManager<br/>Cluster Coordination"]
      DS["Dask Scheduler<br/>Task Distribution"]
      DD["Dask Dashboard<br/>Port 8787"]
      JH["Job History Server<br/>Monitoring"]
      CG["Component Gateway<br/>External Access"]
    end
    
    subgraph "Worker Pool (Auto-scaling 2-10)"
      subgraph "Primary Workers (On-Demand)"
        W1["Worker 1<br/>n2-standard-4<br/>14GB RAM / 3 vCPU"]
        W2["Worker 2<br/>n2-standard-4<br/>14GB RAM / 3 vCPU"]
      end
      
      subgraph "Secondary Workers (Preemptible)"
        PW1["Preemptible Worker 1<br/>n2-standard-4<br/>14GB RAM / 3 vCPU"]
        PW2["Preemptible Worker 2<br/>n2-standard-4<br/>14GB RAM / 3 vCPU"]
        PWN["Preemptible Worker N<br/>Scale based on demand"]
      end
    end
  end
  
  subgraph "External Access"
    IAP_Access["IAP Tunnel"]
    ComposerUI["Composer Airflow UI"]
    DaskDash["Dask Dashboard Access"]
  end
  
  subgraph "Storage Access"
    NFSMount["NFS Mount<br/>/mnt/shared"]
    GCSAccess["GCS Buckets<br/>Private Access"]
    LocalSSD["Local SSD Cache<br/>375GB per worker"]
  end
  
  RM --> W1
  RM --> W2
  RM --> PW1
  RM --> PW2
  RM --> PWN
  
  DS <--> W1
  DS <--> W2
  DS <--> PW1
  DS <--> PW2
  DS <--> PWN
  
  IAP_Access --> CG
  CG --> DD
  ComposerUI --> RM
  ComposerUI --> DS
  
  W1 --> NFSMount
  W2 --> NFSMount
  PW1 --> NFSMount
  PW2 --> NFSMount
  PWN --> NFSMount
  
  W1 --> GCSAccess
  W2 --> GCSAccess
  PW1 --> GCSAccess
  PW2 --> GCSAccess
  PWN --> GCSAccess
  
  W1 --> LocalSSD
  W2 --> LocalSSD
  PW1 --> LocalSSD
  PW2 --> LocalSSD
  PWN --> LocalSSD

  classDef master fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
  classDef worker fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
  classDef preempt fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
  classDef storage fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
  classDef access fill:#fce4ec,stroke:#c2185b,stroke-width:2px
  
  class RM,DS,DD,JH,CG master
  class W1,W2 worker
  class PW1,PW2,PWN preempt
  class NFSMount,GCSAccess,LocalSSD storage
  class IAP_Access,ComposerUI,DaskDash access
```

---

</details>

---
## Data Flow Architecture
---

### Job Execution Workflow
<details>
<summary>End-to-end data processing workflow from job submission to completion</summary>

---
- **Orchestration**: Airflow DAGs trigger ephemeral cluster creation
- **Job Submission**: Multiple pathways for submitting distributed Python jobs
- **Data Processing**: Efficient data movement between storage systems
- **Resource Cleanup**: Automatic cluster deletion after job completion

```mermaid
    sequenceDiagram
    autonumber
    participant User as Engineer
    participant IAP as IAP Proxy
    participant Composer as Cloud Composer
    participant Dataproc as Dataproc API
    participant Cluster as Dask Cluster
    participant Storage as Storage (NFS/GCS)
    participant Monitor as Monitoring

    Note over User,Monitor: Job Submission Phase
    User->>IAP: Authenticate via Google Workspace
    IAP->>Composer: Access Airflow UI
    User->>Composer: Trigger DAG with parameters
    Composer->>Dataproc: Create ephemeral cluster
    Dataproc-->>Composer: Cluster creation success
    
    Note over User,Monitor: Job Execution Phase
    Composer->>Cluster: Submit Dask job
    Cluster->>Storage: Load input data
    Storage-->>Cluster: Data chunks
    Cluster->>Cluster: Distributed processing
    Cluster->>Storage: Write output data
    
    Note over User,Monitor: Monitoring and Access
    User->>IAP: Request Dask Dashboard
    IAP->>Cluster: Component Gateway proxy
    Cluster-->>User: Real-time job progress
    Cluster->>Monitor: Metrics and logs
    
    Note over User,Monitor: Cleanup Phase
    Cluster-->>Composer: Job completion signal
    Composer->>Dataproc: Delete cluster
    Dataproc-->>Composer: Deletion confirmed
    Composer-->>User: Job completion notification
```

---

</details>

### Performance and Scaling Patterns
<details>
<summary>Resource scaling and performance optimization patterns</summary>

---
- **Auto-scaling Logic**: Dynamic worker allocation based on workload
- **Resource Optimization**: Efficient CPU, memory, and storage utilization
- **Cost Management**: Preemptible instances and ephemeral deployment
- **Performance Monitoring**: Real-time metrics driving optimization decisions

```mermaid
graph LR
  subgraph "Scaling Triggers"
    CPU["CPU Usage > 80%<br/>for 3 minutes"]
    Memory["Memory Usage > 75%<br/>for 2 minutes"]
    Queue["Job Queue Depth > 5<br/>pending tasks"]
    Custom["Custom Metrics<br/>Application-specific"]
  end
  
  subgraph "Scaling Decisions"
    ScaleUp["Scale Up Decision<br/>Add 1-2 workers"]
    ScaleDown["Scale Down Decision<br/>Remove idle workers"]
    ScaleOut["Scale Out Decision<br/>Create new cluster"]
  end
  
  subgraph "Resource Types"
    Primary["Primary Workers<br/>On-demand instances<br/>Always available"]
    Secondary["Secondary Workers<br/>Preemptible instances<br/>Cost optimization"]
    GPU["GPU Workers<br/>For ML workloads<br/>High-performance"]
  end
  
  subgraph "Performance Optimization"
    DataLoc["Data Locality<br/>Schedule tasks near data"]
    WorkSteal["Work Stealing<br/>Dynamic load balancing"]
    MemOpt["Memory Optimization<br/>Spill to local SSD"]
    NetOpt["Network Optimization<br/>Parallel data transfer"]
  end
  
  CPU --> ScaleUp
  Memory --> ScaleUp
  Queue --> ScaleOut
  Custom --> ScaleDown
  
  ScaleUp --> Secondary
  ScaleOut --> Primary
  ScaleDown --> Secondary
  
  Primary --> DataLoc
  Secondary --> WorkSteal
  GPU --> MemOpt
  
  DataLoc --> NetOpt
  WorkSteal --> NetOpt
  MemOpt --> NetOpt

  classDef trigger fill:#ffebee,stroke:#c62828,stroke-width:2px
  classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
  classDef resource fill:#f3e5f5,stroke:#6a1b9a,stroke-width:2px
  classDef optimize fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
  
  class CPU,Memory,Queue,Custom trigger
  class ScaleUp,ScaleDown,ScaleOut decision
  class Primary,Secondary,GPU resource
  class DataLoc,WorkSteal,MemOpt,NetOpt optimize
```

---

</details>

---
## Monitoring Architecture
---

### Comprehensive Observability Stack
<details>
<summary>Multi-layered monitoring with metrics, logs, and distributed tracing</summary>

---
- **Metrics Collection**: Cluster health, job performance, and resource utilization
- **Log Aggregation**: Centralized logging with correlation and analysis
- **Real-time Dashboards**: Custom visualizations for different stakeholder needs
- **Alerting Strategy**: Tiered alerts with escalation and on-call integration

```mermaid
graph TB
  subgraph "Data Sources"
    subgraph "Infrastructure Metrics"
      VM["VM Metrics<br/>CPU, Memory, Disk, Network"]
      Dataproc["Dataproc Metrics<br/>Cluster health, YARN"]
      Composer["Composer Metrics<br/>DAG success rate, queue"]
    end
    
    subgraph "Application Metrics"
      Dask["Dask Metrics<br/>Task execution, worker load"]
      Python["Python App Metrics<br/>Custom business metrics"]
      Jobs["Job Metrics<br/>Runtime, success rate"]
    end
    
    subgraph "Log Sources"
      SysLogs["System Logs<br/>OS, services, security"]
      AppLogs["Application Logs<br/>Dask, Python jobs"]
      AuditLogs["Audit Logs<br/>IAP, API calls"]
    end
  end
  
  subgraph "Collection and Processing"
    subgraph "Metrics Pipeline"
      CloudMon["Cloud Monitoring<br/>Metrics ingestion"]
      Prometheus["Prometheus<br/>Custom metrics"]
      Pushgateway["Pushgateway<br/>Batch job metrics"]
    end
    
    subgraph "Logging Pipeline"
      CloudLog["Cloud Logging<br/>Log aggregation"]
      Fluentd["Fluentd<br/>Log shipping"]
      LogParser["Log Parsing<br/>Structured data"]
    end
  end
  
  subgraph "Visualization and Alerting"
    subgraph "Dashboards"
      OpsDash["Operations Dashboard<br/>Infrastructure health"]
      UserDash["User Dashboard<br/>Job progress, queues"]
      ExecDash["Executive Dashboard<br/>Usage, costs, SLAs"]
    end
    
    subgraph "Alerting"
      Critical["Critical Alerts<br/>System down, job failures"]
      Warning["Warning Alerts<br/>Performance degradation"]
      Info["Info Alerts<br/>Capacity, usage trends"]
    end
  end
  
  VM --> CloudMon
  Dataproc --> CloudMon
  Composer --> CloudMon
  Dask --> Prometheus
  Python --> Prometheus
  Jobs --> Pushgateway
  
  SysLogs --> CloudLog
  AppLogs --> Fluentd
  AuditLogs --> CloudLog
  
  CloudMon --> OpsDash
  CloudMon --> UserDash
  CloudMon --> ExecDash
  Prometheus --> OpsDash
  Pushgateway --> UserDash
  
  CloudMon --> Critical
  CloudMon --> Warning
  Prometheus --> Warning
  CloudLog --> Info
  
  CloudLog --> OpsDash
  LogParser --> UserDash

  classDef source fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
  classDef collect fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
  classDef visual fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
  classDef alert fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
  
  class VM,Dataproc,Composer,Dask,Python,Jobs,SysLogs,AppLogs,AuditLogs source
  class CloudMon,Prometheus,Pushgateway,CloudLog,Fluentd,LogParser collect
  class OpsDash,UserDash,ExecDash visual
  class Critical,Warning,Info alert
```

---

</details>

---
## Cost Optimization Architecture
---

### Multi-Tier Cost Management
<details>
<summary>Comprehensive cost optimization strategy with automated controls</summary>

---
- **Ephemeral Clusters**: Scale-to-zero capability eliminates idle costs
- **Instance Type Optimization**: Mix of on-demand and preemptible instances
- **Resource Right-Sizing**: Dynamic allocation based on workload requirements
- **Cost Monitoring**: Real-time cost tracking with budget alerts

```mermaid
graph TB
  subgraph "Cost Optimization Strategies"
    subgraph "Compute Optimization"
      Ephemeral["Ephemeral Clusters<br/>Auto-delete after jobs<br/>Zero idle costs"]
      Preemptible["Preemptible Instances<br/>70% cost savings<br/>Fault-tolerant jobs"]
      RightSize["Right-sizing<br/>Match resources to workload<br/>CPU/Memory optimization"]
    end
    
    subgraph "Storage Optimization"
      Lifecycle["Storage Lifecycle<br/>Auto-tier old data<br/>Delete temporary files"]
      Compression["Data Compression<br/>Reduce storage footprint<br/>Network transfer"]
      Dedup["Deduplication<br/>Eliminate redundant data<br/>Shared datasets"]
    end
    
    subgraph "Network Optimization"
      Regional["Regional Processing<br/>Minimize egress costs<br/>Data locality"]
      Caching["Data Caching<br/>Reduce repeated transfers<br/>Local SSD cache"]
      Compression2["Network Compression<br/>Reduce bandwidth usage<br/>Cost per GB"]
    end
  end
  
  subgraph "Cost Monitoring and Control"
    subgraph "Real-time Tracking"
      Usage["Usage Monitoring<br/>Resource consumption<br/>Per-user tracking"]
      Budgets["Budget Alerts<br/>Spending thresholds<br/>Automated notifications"]
      Forecasting["Cost Forecasting<br/>Predictive modeling<br/>Capacity planning"]
    end
    
    subgraph "Automated Controls"
      AutoScale["Auto-scaling Policies<br/>Scale down idle resources<br/>Schedule-based scaling"]
      Quotas["Resource Quotas<br/>Per-user limits<br/>Team allocations"]
      Approval["Approval Workflows<br/>Large resource requests<br/>Cost governance"]
    end
  end
  
  subgraph "Cost Allocation"
    subgraph "Chargeback Model"
      UserCosts["User-level Costs<br/>Individual usage tracking<br/>Transparent billing"]
      ProjectCosts["Project-level Costs<br/>Team budget allocation<br/>Cost centers"]
      Optimization["Optimization Recommendations<br/>Cost reduction suggestions<br/>Automated actions"]
    end
  end
  
  Ephemeral --> Usage
  Preemptible --> Usage
  RightSize --> Budgets
  
  Lifecycle --> Forecasting
  Compression --> AutoScale
  Dedup --> Quotas
  
  Regional --> Approval
  Caching --> UserCosts
  Compression2 --> ProjectCosts
  
  Usage --> UserCosts
  Budgets --> ProjectCosts
  Forecasting --> Optimization
  
  AutoScale --> Optimization
  Quotas --> Optimization
  Approval --> Optimization

  classDef compute fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
  classDef storage fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
  classDef network fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
  classDef monitor fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
  classDef control fill:#ffebee,stroke:#c62828,stroke-width:2px
  classDef allocate fill:#e0f2f1,stroke:#00695c,stroke-width:2px
  
  class Ephemeral,Preemptible,RightSize compute
  class Lifecycle,Compression,Dedup storage
  class Regional,Caching,Compression2 network
  class Usage,Budgets,Forecasting monitor
  class AutoScale,Quotas,Approval control
  class UserCosts,ProjectCosts,Optimization allocate
```

---

</details>

---
## Developer Workflow Architecture
---

### End-to-End Development Experience
<details>
<summary>Complete developer workflow from code to production deployment</summary>

---
- **Development Environment**: Integrated development with existing A01 workstations
- **Job Development**: Local development with seamless scaling to distributed execution
- **Git Integration**: Automated deployment of DAGs and job code
- **Monitoring Access**: Real-time visibility into job execution and performance

```mermaid
flowchart LR
  subgraph "Development Phase"
    Local["Local Development<br/>A01 Workstations<br/>Dask local mode"]
    Test["Local Testing<br/>Small datasets<br/>Algorithm validation"]
    Commit["Git Commit<br/>Code + DAGs<br/>Version control"]
  end
  
  subgraph "CI/CD Pipeline"
    PR["Pull Request<br/>Code review<br/>Automated testing"]
    Build["Build & Test<br/>Unit tests<br/>Integration tests"]
    Deploy["Deploy to Staging<br/>Composer DAG sync<br/>Job validation"]
  end
  
  subgraph "Production Execution"
    Trigger["Job Trigger<br/>Scheduled or manual<br/>Composer UI"]
    Scale["Auto-scaling<br/>Ephemeral clusters<br/>Resource allocation"]
    Execute["Distributed Execution<br/>Dask framework<br/>Parallel processing"]
  end
  
  subgraph "Monitoring & Feedback"
    Monitor["Real-time Monitoring<br/>Dask dashboard<br/>Performance metrics"]
    Logs["Log Analysis<br/>Error tracking<br/>Debug information"]
    Optimize["Performance Optimization<br/>Resource tuning<br/>Cost analysis"]
  end
  
  Local --> Test
  Test --> Commit
  Commit --> PR
  PR --> Build
  Build --> Deploy
  Deploy --> Trigger
  Trigger --> Scale
  Scale --> Execute
  Execute --> Monitor
  Monitor --> Logs
  Logs --> Optimize
  Optimize --> Local

  classDef dev fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
  classDef cicd fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
  classDef prod fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
  classDef monitor fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
  
  class Local,Test,Commit dev
  class PR,Build,Deploy cicd
  class Trigger,Scale,Execute prod
  class Monitor,Logs,Optimize monitor
```

---

</details>
