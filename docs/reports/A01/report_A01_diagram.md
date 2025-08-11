---
title: report_A01_diagram
---

# A01 - Architecture Diagrams

---
## System Architecture
---

### High-Level Platform Overview
<details>
<summary>Complete GCP data platform architecture showing all components and relationships</summary>

---
- **System Overview**: Comprehensive view of the entire GCP data platform
- **Security Boundaries**: IAP-protected access, VPC isolation, deny-by-default firewall
- **User Flow**: 20-30 engineers accessing through IAP → Bastion → Workstations
- **Storage Integration**: Filestore NFS for shared home directories and collaboration
- **Identity Management**: FreeIPA centralized authentication with LDAP/Kerberos

```mermaid
    graph TB
    subgraph Internet["Internet Access"]
        User["Engineers (20–30)<br/>OAuth2 Identity"]
    end

    subgraph GCP["GCP Project: data-platform"]
        KMS["Cloud KMS<br/>(CMEK Encryption)"]
        SM["Secret Manager<br/>(Runtime Config)"]
        WIF["Workload Identity Federation<br/>(GitHub Actions)"]
        
        subgraph VPC["VPC: data-platform<br/>10.0.0.0/16"]
        subgraph MGMT["Subnet: management<br/>10.0.1.0/24"]
            IAP["IAP TCP Forwarding<br/>OAuth2 Gateway"]
            Bastion["Bastion VM<br/>e2-micro<br/>Ubuntu 22.04"]
            FreeIPA["FreeIPA Server<br/>e2-standard-2<br/>CORP.INTERNAL"]
        end

        subgraph SRV["Subnet: services<br/>10.0.2.0/24"]
            Filestore["Filestore Enterprise<br/>4TB Capacity<br/>NFS v4.1"]
        end

        subgraph WS["Subnet: workstations<br/>10.0.3.0/24"]
            MIG["Workstation MIG<br/>0-10 instances<br/>e2-standard-4<br/>Auto-scaling"]
        end
        end

        subgraph APIs["GCP APIs"]
        ComputeAPI["Compute Engine API"]
        FileAPI["Filestore API"]
        IAMAPI["IAM API"]
        KMSAPI["KMS API"]
        end
    end

    User -->|"OAuth2 Auth"| IAP
    IAP -->|"TCP Forward SSH"| Bastion
    Bastion -->|"LDAP/Kerberos"| FreeIPA
    Bastion -->|"SSH Jump"| MIG
    MIG -->|"SSSD Auth"| FreeIPA
    MIG -->|"NFS v4.1 Mount"| Filestore
    
    WIF -->|"OIDC Token"| APIs
    APIs -->|"Terraform Deploy"| VPC
    APIs -->|"Ansible Config"| Bastion
    APIs -->|"Ansible Config"| FreeIPA
    APIs -->|"Ansible Config"| MIG
    
    KMS -.->|"CMEK"| Filestore
    SM -.->|"Secrets"| Bastion
    SM -.->|"Secrets"| FreeIPA

    classDef security fill:#ffe6e6,stroke:#ff4444,stroke-width:2px
    classDef compute fill:#e6f3ff,stroke:#4488ff,stroke-width:2px
    classDef storage fill:#e6ffe6,stroke:#44ff44,stroke-width:2px
    classDef network fill:#fff0e6,stroke:#ff8844,stroke-width:2px
    
    class IAP,FreeIPA,KMS,WIF security
    class Bastion,MIG compute
    class Filestore,SM storage
    class VPC,MGMT,SRV,WS network
```

---

</details>

### Network Topology and Security
<details>
<summary>Detailed network architecture with security zones and firewall rules</summary>

---
- **VPC Design**: Single VPC with three purpose-built subnets
- **Firewall Strategy**: Deny-by-default with explicit allow rules
- **NAT Gateway**: Outbound internet access for package updates
- **Private Google Access**: GCP API access without public IPs
- **Network Security**: Internal traffic flows with minimal external exposure

```mermaid
graph LR
  subgraph Internet["Internet"]
    GitHub["GitHub Actions<br/>CI/CD Pipeline"]
    PackageRepos["Package Repositories<br/>APT, PyPI, etc."]
  end

  subgraph GCP["GCP Project"]
    subgraph VPC["VPC: data-platform (10.0.0.0/16)"]
      subgraph MGMT["management (10.0.1.0/24)"]
        IAP_EP["IAP Endpoint<br/>35.235.240.0/20"]
        Bastion_VM["bastion-vm<br/>10.0.1.10"]
        FreeIPA_VM["freeipa-vm<br/>10.0.1.20"]
      end
      
      subgraph SRV["services (10.0.2.0/24)"]
        NFS_EP["Filestore Endpoint<br/>10.0.2.10"]
      end
      
      subgraph WS["workstations (10.0.3.0/24)"]
        WS_Pool["Workstation Pool<br/>10.0.3.10-19"]
      end
      
      NAT["Cloud NAT<br/>Outbound Only"]
      Router["Cloud Router"]
    end
    
    subgraph FW["Firewall Rules"]
      FW1["allow-iap-ssh<br/>22/tcp from IAP"]
      FW2["allow-internal<br/>All ports internal"]
      FW3["allow-nfs<br/>2049/tcp to services"]
      FW4["deny-all<br/>Default DENY"]
    end
    
    PGA["Private Google Access<br/>199.36.153.8/30"]
  end

  GitHub -.->|"WIF Auth"| PGA
  Internet -->|"OAuth2"| IAP_EP
  IAP_EP -->|"SSH:22"| Bastion_VM
  Bastion_VM -->|"SSH:22"| WS_Pool
  Bastion_VM <-->|"LDAP:389,636<br/>Kerberos:88,464"| FreeIPA_VM
  WS_Pool <-->|"LDAP:389,636"| FreeIPA_VM
  WS_Pool -->|"NFS:2049"| NFS_EP
  
  WS_Pool -->|"Via NAT"| NAT
  Bastion_VM -->|"Via NAT"| NAT
  FreeIPA_VM -->|"Via NAT"| NAT
  NAT --> Router
  Router -.->|"Outbound"| PackageRepos

  classDef subnet fill:#f0f8ff,stroke:#4682b4,stroke-width:2px
  classDef firewall fill:#ffe4e1,stroke:#dc143c,stroke-width:1px
  classDef nat fill:#f0fff0,stroke:#32cd32,stroke-width:2px
  
  class MGMT,SRV,WS subnet
  class FW1,FW2,FW3,FW4 firewall
  class NAT,Router nat
```

---

</details>

### Authentication and Authorization Flow
<details>
<summary>Complete authentication sequence from user login to resource access</summary>

---
- **Identity Provider**: Google OAuth2 for initial authentication
- **Central Directory**: FreeIPA LDAP for user accounts and groups
- **Session Management**: Kerberos tickets for SSO across platform
- **Access Control**: Group-based permissions with principle of least privilege
- **Audit Trail**: Complete logging of authentication and authorization events

```mermaid
sequenceDiagram
    autonumber
    participant U as User<br/>(Engineer)
    participant G as Google OAuth2
    participant IAP as IAP TCP Forwarding
    participant B as Bastion VM
    participant IPA as FreeIPA Server
    participant W as Workstation
    participant NFS as Filestore NFS

    Note over U,NFS: Initial Platform Access
    U->>G: Authenticate with Google Account
    G-->>U: OAuth2 Token
    U->>IAP: Request SSH tunnel with token
    IAP->>IAP: Validate OAuth2 token
    IAP-->>U: Establish TCP tunnel to bastion:22

    Note over U,IPA: Platform Authentication
    U->>B: SSH via IAP tunnel
    B->>IPA: PAM authentication request (SSSD)
    IPA->>IPA: Lookup user in LDAP
    IPA-->>B: User exists, group memberships
    B->>IPA: Request Kerberos ticket (kinit)
    IPA-->>B: TGT (Ticket Granting Ticket)
    B-->>U: Login successful, shell access

    Note over U,NFS: Resource Access
    U->>W: SSH jump to workstation
    W->>IPA: SSSD authentication request
    IPA-->>W: User validated, Kerberos TGS
    W->>NFS: Mount home directory (autofs)
    NFS->>NFS: Validate Kerberos ticket
    NFS-->>W: NFS mount successful
    W-->>U: Workstation ready, home dir mounted

    Note over U,NFS: Session Management
    rect rgb(240,248,255)
        Note over U,IPA: Kerberos ticket renewal (every 24h)
        IPA->>IPA: Automatic ticket renewal
        Note over U,NFS: Seamless SSO across platform
    end
```

---

</details>

---
## Infrastructure Components
---

### Compute Architecture
<details>
<summary>Detailed compute resource design and scaling strategy</summary>

---
- **Bastion Configuration**: Single e2-micro instance for secure access
- **FreeIPA Sizing**: e2-standard-2 for LDAP/Kerberos services
- **Workstation Fleet**: Auto-scaling MIG supporting 0-10 concurrent users
- **Performance Targets**: Support for 20-30 engineers with peak usage patterns
- **Cost Optimization**: Scale-to-zero capability during off-hours

```mermaid
graph TB
    subgraph "Compute Resources"
        subgraph "Management Tier"
            B["Bastion VM<br/>e2-micro<br/>1 vCPU, 1GB RAM<br/>Ubuntu 22.04 LTS"]
            IPA["FreeIPA Server<br/>e2-standard-2<br/>2 vCPU, 8GB RAM<br/>Ubuntu 22.04 LTS"]
        end
        
        subgraph "Workstation Tier"
            Template["Instance Template<br/>e2-standard-4<br/>4 vCPU, 16GB RAM<br/>100GB SSD Boot<br/>Ubuntu 22.04 LTS"]
            
            subgraph "MIG Auto-scaling"
                MIG["Managed Instance Group<br/>Min: 0 instances<br/>Max: 10 instances<br/>Target CPU: 60%"]
                
                subgraph "Active Instances"
                    WS1["workstation-001<br/>Active User Session"]
                    WS2["workstation-002<br/>Active User Session"]
                    WS3["workstation-003<br/>Available"]
                    WSN["workstation-N<br/>Scale as needed"]
                end
            end
        end
    end
    
    subgraph "Scaling Logic"
        Monitor["Cloud Monitoring<br/>CPU, Memory, User Load"]
        Scaler["Auto-scaler<br/>Scale up: >60% CPU<br/>Scale down: <30% CPU"]
        LB["Health Checks<br/>TCP:22 SSH<br/>User Session Count"]
    end
    
    Template --> MIG
    MIG --> WS1
    MIG --> WS2  
    MIG --> WS3
    MIG -.-> WSN
    
    Monitor --> Scaler
    Scaler --> MIG
    LB --> MIG
    
    classDef mgmt fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
    classDef compute fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef scaling fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    
    class B,IPA mgmt
    class Template,MIG,WS1,WS2,WS3,WSN compute
    class Monitor,Scaler,LB scaling
```

---

</details>

### Storage Architecture
<details>
<summary>Comprehensive storage design with performance and capacity planning</summary>

---
- **Filestore Enterprise**: High-performance NFS for user home directories
- **Capacity Planning**: 4TB total (2TB home + 2TB shared) supporting 30 users
- **Performance Specs**: 1000 IOPS, 100 MB/s throughput per TB
- **Backup Strategy**: Daily snapshots with 30-day retention
- **Access Patterns**: Optimized for development workloads and collaboration

```mermaid
graph LR
    subgraph "Storage Layer"
        subgraph "Filestore Enterprise"
            FS["Filestore Instance<br/>Tier: ENTERPRISE<br/>Total: 4TB<br/>Location: us-central1"]
            
            subgraph "File Shares"
                HOME["Home Directories<br/>2TB Allocated<br/>/home/users<br/>Individual quotas"]
                SHARED["Shared Storage<br/>2TB Allocated<br/>/shared/data<br/>Team collaboration"]
            end
        end
        
        subgraph "Performance Characteristics"
            PERF["Performance Specs<br/>4000 IOPS total<br/>400 MB/s throughput<br/>Sub-ms latency"]
            
            subgraph "Access Patterns"
                READ["Read Operations<br/>Code repositories<br/>Configuration files<br/>Data analysis"]
                WRITE["Write Operations<br/>Development output<br/>Log files<br/>Jupyter notebooks"]
            end
        end
    end
    
    subgraph "Client Access"
        subgraph "NFS Clients"
            WS1["Workstation 1<br/>autofs mount<br/>/home/user1"]
            WS2["Workstation 2<br/>autofs mount<br/>/home/user2"]
            WSN["Workstation N<br/>autofs mount<br/>/home/userN"]
        end
        
        subgraph "Mount Configuration"
            AUTOFS["autofs Service<br/>On-demand mounting<br/>Automatic unmounting<br/>User home dirs"]
            FSTAB["Shared Mounts<br/>/etc/fstab<br/>Persistent mounts<br/>Team directories"]
        end
    end
    
    subgraph "Backup & Protection"
        SNAP["Daily Snapshots<br/>Automated schedule<br/>30-day retention<br/>Point-in-time recovery"]
        MONITOR["Storage Monitoring<br/>Capacity usage<br/>IOPS utilization<br/>Performance metrics"]
    end
    
    FS --> HOME
    FS --> SHARED
    FS --> PERF
    
    HOME --> WS1
    HOME --> WS2
    HOME --> WSN
    SHARED --> WS1
    SHARED --> WS2
    SHARED --> WSN
    
    AUTOFS --> WS1
    AUTOFS --> WS2
    AUTOFS --> WSN
    FSTAB --> SHARED
    
    FS --> SNAP
    FS --> MONITOR
    
    classDef storage fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef perf fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef client fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef backup fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    
    class FS,HOME,SHARED storage
    class PERF,READ,WRITE perf
    class WS1,WS2,WSN,AUTOFS,FSTAB client
    class SNAP,MONITOR backup
```

---

</details>

---
## Security Model
---

### Security Architecture
<details>
<summary>Comprehensive security design with defense-in-depth approach</summary>

---
- **Zero Trust Network**: No trust assumptions, verify every access request
- **Defense in Depth**: Multiple security layers with different controls
- **Principle of Least Privilege**: Minimal required permissions only
- **Encryption Everywhere**: Data at rest, in transit, and in processing
- **Audit and Compliance**: Complete activity logging and monitoring

```mermaid
graph TB
    subgraph "Security Layers"
        subgraph "Perimeter Security"
            IAP_SEC["IAP Protection<br/>OAuth2 Authentication<br/>Context-aware access<br/>No VPN required"]
            FW["Firewall Rules<br/>Deny-by-default<br/>Explicit allow rules<br/>Internal segmentation"]
        end
        
        subgraph "Identity & Access"
            GOOGLE["Google Workspace<br/>Primary identity<br/>MFA enforcement<br/>Admin policies"]
            FREEIPA["FreeIPA Directory<br/>LDAP user accounts<br/>Kerberos SSO<br/>Group management"]
            RBAC["Role-Based Access<br/>Engineer groups<br/>Admin separation<br/>Temporary elevation"]
        end
        
        subgraph "Data Protection"
            CMEK["Customer-Managed Keys<br/>Cloud KMS encryption<br/>Key rotation<br/>Access logging"]
            TLS["TLS Encryption<br/>All network traffic<br/>Certificate management<br/>Perfect forward secrecy"]
            NFS_SEC["NFS Security<br/>Kerberos authentication<br/>Encrypted transport<br/>Access controls"]
        end
        
        subgraph "Infrastructure Security"
            WIF_SEC["Workload Identity<br/>No service account keys<br/>OIDC-based auth<br/>GitHub Actions"]
            OS_SEC["OS Hardening<br/>Security updates<br/>Minimal packages<br/>Audit logging"]
            SECRET_MGR["Secret Management<br/>Cloud Secret Manager<br/>Runtime injection<br/>Rotation policies"]
        end
    end
    
    subgraph "Monitoring & Compliance"
        AUDIT["Audit Logging<br/>Cloud Audit Logs<br/>IAP access logs<br/>SSH session logs"]
        SIEM["Security Monitoring<br/>Cloud Security Center<br/>Anomaly detection<br/>Incident response"]
        COMPLIANCE["Compliance Framework<br/>SOC 2 Type II<br/>ISO 27001<br/>Regular assessments"]
    end
    
    IAP_SEC --> GOOGLE
    GOOGLE --> FREEIPA
    FREEIPA --> RBAC
    
    FW --> TLS
    TLS --> NFS_SEC
    NFS_SEC --> CMEK
    
    WIF_SEC --> SECRET_MGR
    SECRET_MGR --> OS_SEC
    
    RBAC --> AUDIT
    CMEK --> AUDIT
    WIF_SEC --> AUDIT
    
    AUDIT --> SIEM
    SIEM --> COMPLIANCE
    
    classDef perimeter fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef identity fill:#f3e5f5,stroke:#6a1b9a,stroke-width:2px
    classDef data fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef infra fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
    classDef monitor fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    
    class IAP_SEC,FW perimeter
    class GOOGLE,FREEIPA,RBAC identity
    class CMEK,TLS,NFS_SEC data
    class WIF_SEC,OS_SEC,SECRET_MGR infra
    class AUDIT,SIEM,COMPLIANCE monitor
```

---

</details>

### Threat Model and Mitigations
<details>
<summary>Security threat analysis and corresponding mitigation strategies</summary>

---
- **External Threats**: Internet-based attacks, credential theft, social engineering
- **Internal Threats**: Privilege escalation, data exfiltration, insider threats
- **Infrastructure Threats**: Service outages, configuration drift, supply chain attacks
- **Data Threats**: Unauthorized access, data corruption, compliance violations

```mermaid
graph LR
    subgraph "Threat Landscape"
        subgraph "External Threats"
            EXT1["Internet Attacks<br/>DDoS, Port scanning<br/>Brute force SSH<br/>Vulnerability exploits"]
            EXT2["Credential Theft<br/>Phishing attacks<br/>Token compromise<br/>Session hijacking"]
        end
        
        subgraph "Internal Threats"
            INT1["Privilege Escalation<br/>Sudo exploitation<br/>Container escape<br/>Service account abuse"]
            INT2["Data Exfiltration<br/>Unauthorized access<br/>Data copying<br/>Covert channels"]
        end
        
        subgraph "Infrastructure Threats"
            INF1["Service Outages<br/>Single points of failure<br/>Cascade failures<br/>Resource exhaustion"]
            INF2["Configuration Drift<br/>Manual changes<br/>Inconsistent state<br/>Security gaps"]
        end
    end
    
    subgraph "Mitigation Controls"
        subgraph "Network Controls"
            NET1["IAP Protection<br/>No direct SSH<br/>OAuth2 required<br/>Context-aware"]
            NET2["Firewall Rules<br/>Deny-by-default<br/>Minimal exposure<br/>Internal segmentation"]
        end
        
        subgraph "Identity Controls"
            ID1["Multi-Factor Auth<br/>Google Workspace MFA<br/>Hardware tokens<br/>Risk-based auth"]
            ID2["Least Privilege<br/>Role-based access<br/>Just-in-time elevation<br/>Regular review"]
        end
        
        subgraph "Data Controls"
            DATA1["Encryption at Rest<br/>CMEK with KMS<br/>Key rotation<br/>Access logging"]
            DATA2["Encryption in Transit<br/>TLS everywhere<br/>Certificate pinning<br/>Perfect forward secrecy"]
        end
        
        subgraph "Operational Controls"
            OPS1["Infrastructure as Code<br/>Terraform for all changes<br/>Version control<br/>Peer review"]
            OPS2["Continuous Monitoring<br/>Security alerts<br/>Anomaly detection<br/>Incident response"]
        end
    end
    
    EXT1 --> NET1
    EXT1 --> NET2
    EXT2 --> ID1
    EXT2 --> ID2
    
    INT1 --> ID2
    INT1 --> OPS2
    INT2 --> DATA1
    INT2 --> DATA2
    
    INF1 --> OPS1
    INF1 --> OPS2
    INF2 --> OPS1
    
    classDef threat fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef mitigation fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    
    class EXT1,EXT2,INT1,INT2,INF1,INF2 threat
    class NET1,NET2,ID1,ID2,DATA1,DATA2,OPS1,OPS2 mitigation
```

---

</details>

---
## Deployment Architecture
---

### Deployment Pipeline
<details>
<summary>Complete CI/CD pipeline architecture with GitOps workflow</summary>

---
- **Source Control**: GitHub repository with branch protection
- **CI/CD Platform**: GitHub Actions with Workload Identity Federation
- **Infrastructure as Code**: Terraform for resource provisioning
- **Configuration Management**: Ansible for system configuration
- **Deployment Strategy**: Phased rollout with validation gates

```mermaid
graph LR
    subgraph "Source Control"
        GIT["GitHub Repository<br/>Infrastructure code<br/>Ansible playbooks<br/>Documentation"]
        
        subgraph "Branch Strategy"
            MAIN["main branch<br/>Production code<br/>Protected branch<br/>Required reviews"]
            DEV["development<br/>Feature branches<br/>Testing changes<br/>Integration testing"]
        end
    end
    
    subgraph "CI/CD Pipeline"
        subgraph "GitHub Actions"
            TRIGGER["Workflow Triggers<br/>Push to main<br/>Pull requests<br/>Manual dispatch"]
            
            subgraph "Pipeline Stages"
                VALIDATE["Validation Stage<br/>Terraform validate<br/>Ansible lint<br/>Security scan"]
                PLAN["Planning Stage<br/>Terraform plan<br/>Change review<br/>Cost estimation"]
                DEPLOY["Deployment Stage<br/>Terraform apply<br/>Ansible execution<br/>Validation tests"]
            end
        end
        
        subgraph "Authentication"
            WIF_AUTH["Workload Identity<br/>OIDC tokens<br/>No service keys<br/>Temporary credentials"]
            GCP_AUTH["GCP Authentication<br/>Project-level access<br/>Least privilege<br/>Audit logging"]
        end
    end
    
    subgraph "Target Environment"
        subgraph "Infrastructure Layer"
            TF["Terraform State<br/>Remote backend<br/>State locking<br/>Version tracking"]
            GCP_INFRA["GCP Infrastructure<br/>VPC, VMs, Storage<br/>Managed services<br/>Security policies"]
        end
        
        subgraph "Configuration Layer"
            ANSIBLE["Ansible Execution<br/>Host configuration<br/>Service setup<br/>User management"]
            INVENTORY["Dynamic Inventory<br/>GCP plugin<br/>Auto-discovery<br/>Group assignment"]
        end
    end
    
    GIT --> TRIGGER
    MAIN --> TRIGGER
    DEV --> TRIGGER
    
    TRIGGER --> VALIDATE
    VALIDATE --> PLAN
    PLAN --> DEPLOY
    
    DEPLOY --> WIF_AUTH
    WIF_AUTH --> GCP_AUTH
    GCP_AUTH --> TF
    GCP_AUTH --> ANSIBLE
    
    TF --> GCP_INFRA
    ANSIBLE --> INVENTORY
    INVENTORY --> GCP_INFRA
    
    classDef source fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef pipeline fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
    classDef auth fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef target fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    
    class GIT,MAIN,DEV source
    class TRIGGER,VALIDATE,PLAN,DEPLOY pipeline
    class WIF_AUTH,GCP_AUTH auth
    class TF,GCP_INFRA,ANSIBLE,INVENTORY target
```

---

</details>

### Multi-Phase Deployment Strategy
<details>
<summary>Detailed deployment phases with dependencies and validation checkpoints</summary>

---
- **Phase 0**: Foundation security and API enablement
- **Phase 1**: Core infrastructure provisioning
- **Phase 2**: Service configuration and integration
- **Phase 3**: Production hardening and monitoring
- **Phase 4**: User onboarding and documentation

```mermaid
gantt
    title A01 GCP Data Platform - Comprehensive Deployment Timeline
    dateFormat  YYYY-MM-DD
    axisFormat  %m/%d

    section Phase 0: Foundation
    Enable APIs                    :milestone, apis, 2025-01-20, 0d
    Configure KMS & CMEK          :foundation1, 2025-01-20, 4h
    Setup Workload Identity       :foundation2, after foundation1, 4h
    Apply Organization Policies   :foundation3, after foundation2, 2h
    Validate Security Foundation  :milestone, sec_validate, after foundation3, 0d

    section Phase 1: Infrastructure
    Provision VPC & Subnets       :infra1, after sec_validate, 2h
    Deploy Bastion VM            :infra2, after infra1, 2h
    Deploy FreeIPA VM            :infra3, after infra2, 2h
    Provision Filestore          :infra4, after infra3, 3h
    Create Workstation Template  :infra5, after infra4, 2h
    Deploy MIG                   :infra6, after infra5, 2h
    Infrastructure Complete      :milestone, infra_done, after infra6, 0d

    section Phase 2: Configuration
    Configure Bastion            :config1, after infra_done, 3h
    Install FreeIPA Server       :config2, after infra_done, 6h
    Configure Workstation Image  :config3, after config2, 4h
    Setup NFS Client Mounts      :config4, after config3, 2h
    Join Workstations to IPA     :config5, after config4, 3h
    Install Development Tools    :config6, after config5, 3h
    Configuration Complete       :milestone, config_done, after config6, 0d

    section Phase 3: Hardening
    Security Audit               :harden1, after config_done, 4h
    Performance Testing          :harden2, after config_done, 6h
    Setup Monitoring Dashboards :harden3, after config_done, 4h
    Configure Alerting           :harden4, after harden3, 3h
    Backup Configuration         :harden5, after harden4, 3h
    Disaster Recovery Testing    :harden6, after harden5, 4h
    Production Ready            :milestone, prod_ready, after harden6, 0d

    section Phase 4: Onboarding
    Create Admin Accounts        :onboard1, after prod_ready, 2h
    Create Test User Accounts    :onboard2, after onboard1, 2h
    Validate User Access Flows   :onboard3, after onboard2, 4h
    Finalize Documentation       :onboard4, after onboard3, 6h
    Conduct Training Sessions    :onboard5, after onboard4, 8h
    Platform Launch             :milestone, launch, after onboard5, 0d
```

---

</details>

---
## Performance Architecture
---

### Performance Specifications
<details>
<summary>Detailed performance requirements and capacity planning for 20-30 engineers</summary>

---
- **User Capacity**: Support 20-30 concurrent engineers
- **Response Time**: <2 seconds for authentication, <1 second for file operations
- **Throughput**: Handle 1000+ file operations per minute
- **Availability**: 99.9% uptime SLA with 4-hour recovery time
- **Scalability**: Auto-scale workstations based on demand

```mermaid
graph TB
    subgraph "Performance Targets"
        subgraph "User Experience"
            AUTH["Authentication<br/>IAP Login: <3s<br/>SSH Connection: <2s<br/>Kerberos Auth: <1s"]
            FILES["File Operations<br/>NFS Read: <500ms<br/>NFS Write: <1s<br/>Home Dir Access: <200ms"]
            COMPUTE["Compute Performance<br/>Workstation Boot: <2min<br/>IDE Launch: <30s<br/>Terminal Response: <100ms"]
        end
        
        subgraph "System Capacity"
            CONCURRENT["Concurrent Users<br/>Peak: 30 users<br/>Sustained: 20 users<br/>Burst: 40 users"]
            STORAGE["Storage Performance<br/>4000 IOPS available<br/>400 MB/s throughput<br/>1TB concurrent access"]
            NETWORK["Network Performance<br/>1 Gbps per workstation<br/>10 Gbps aggregate<br/>Sub-ms latency"]
        end
    end
    
    subgraph "Resource Allocation"
        subgraph "Per-User Resources"
            WORKSTATION["Workstation Specs<br/>4 vCPU, 16GB RAM<br/>100GB local SSD<br/>Dedicated instance"]
            HOME_QUOTA["Home Directory<br/>50GB user quota<br/>100GB soft limit<br/>Automatic cleanup"]
            CPU_SHARE["CPU Allocation<br/>Guaranteed 2 vCPU<br/>Burstable to 4 vCPU<br/>Fair share scheduling"]
        end
        
        subgraph "Shared Resources"
            FILESTORE_PERF["Filestore Performance<br/>4TB total capacity<br/>4000 IOPS pool<br/>400 MB/s bandwidth"]
            FREEIPA_PERF["FreeIPA Performance<br/>1000 auth/minute<br/>10k LDAP queries/minute<br/>99.99% availability"]
            NETWORK_SHARED["Network Bandwidth<br/>10 Gbps total<br/>Quality of Service<br/>Traffic shaping"]
        end
    end
    
    subgraph "Monitoring & Alerting"
        METRICS["Performance Metrics<br/>Response time monitoring<br/>Resource utilization<br/>User experience tracking"]
        ALERTS["Performance Alerts<br/>Response time >2s<br/>CPU usage >80%<br/>Storage >85% full"]
        CAPACITY["Capacity Planning<br/>Growth projections<br/>Resource forecasting<br/>Scaling decisions"]
    end
    
    AUTH --> WORKSTATION
    FILES --> HOME_QUOTA
    COMPUTE --> CPU_SHARE
    
    CONCURRENT --> FILESTORE_PERF
    STORAGE --> FREEIPA_PERF
    NETWORK --> NETWORK_SHARED
    
    WORKSTATION --> METRICS
    FILESTORE_PERF --> METRICS
    FREEIPA_PERF --> METRICS
    
    METRICS --> ALERTS
    ALERTS --> CAPACITY
    
    classDef target fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef resource fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
    classDef monitor fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    
    class AUTH,FILES,COMPUTE,CONCURRENT,STORAGE,NETWORK target
    class WORKSTATION,HOME_QUOTA,CPU_SHARE,FILESTORE_PERF,FREEIPA_PERF,NETWORK_SHARED resource
    class METRICS,ALERTS,CAPACITY monitor
```

---

</details>

---
## Monitoring Architecture
---

### Comprehensive Monitoring Stack
<details>
<summary>Complete observability solution with metrics, logs, and alerts</summary>

---
- **Metrics Collection**: Cloud Monitoring with custom metrics from all components
- **Log Aggregation**: Cloud Logging with structured logs and correlation
- **Alerting Strategy**: Tiered alerts with escalation and on-call rotation
- **Dashboard Design**: Role-based dashboards for operators and executives
- **Incident Response**: Automated detection with manual escalation procedures

```mermaid
graph TB
    subgraph "Data Collection"
        subgraph "Infrastructure Metrics"
            VM_METRICS["VM Metrics<br/>CPU, Memory, Disk<br/>Network I/O<br/>Process monitoring"]
            NFS_METRICS["NFS Metrics<br/>IOPS, Latency<br/>Throughput<br/>Connection count"]
            NET_METRICS["Network Metrics<br/>Bandwidth utilization<br/>Packet loss<br/>Connection tracking"]
        end
        
        subgraph "Application Metrics"
            IPA_METRICS["FreeIPA Metrics<br/>Authentication rate<br/>LDAP query time<br/>Service health"]
            SSH_METRICS["SSH Metrics<br/>Session count<br/>Login failures<br/>Connection duration"]
            USER_METRICS["User Metrics<br/>Active sessions<br/>Resource usage<br/>File access patterns"]
        end
        
        subgraph "Security Metrics"
            AUDIT_LOGS["Audit Logs<br/>IAP access logs<br/>SSH session logs<br/>Privilege escalation"]
            SEC_EVENTS["Security Events<br/>Failed authentications<br/>Unusual access patterns<br/>Policy violations"]
        end
    end
    
    subgraph "Processing & Storage"
        subgraph "Cloud Monitoring"
            COLLECT["Metrics Collection<br/>1-minute intervals<br/>Custom metrics<br/>Auto-discovery"]
            STORE["Time Series Storage<br/>13-month retention<br/>High availability<br/>Query optimization"]
        end
        
        subgraph "Cloud Logging"
            LOG_COLLECT["Log Collection<br/>Structured logging<br/>JSON formatting<br/>Correlation IDs"]
            LOG_STORE["Log Storage<br/>30-day retention<br/>Full-text search<br/>Export capability"]
        end
    end
    
    subgraph "Analysis & Alerting"
        subgraph "Dashboards"
            OPS_DASH["Operations Dashboard<br/>System health<br/>Performance metrics<br/>Capacity planning"]
            SEC_DASH["Security Dashboard<br/>Threat detection<br/>Access monitoring<br/>Compliance status"]
            EXEC_DASH["Executive Dashboard<br/>SLA compliance<br/>Cost tracking<br/>User satisfaction"]
        end
        
        subgraph "Alerting"
            CRITICAL["Critical Alerts<br/>System down<br/>Security breach<br/>Data loss"]
            WARNING["Warning Alerts<br/>Performance degradation<br/>Capacity thresholds<br/>Configuration drift"]
            INFO["Info Alerts<br/>Maintenance windows<br/>Usage reports<br/>Trend notifications"]
        end
    end
    
    VM_METRICS --> COLLECT
    NFS_METRICS --> COLLECT
    NET_METRICS --> COLLECT
    IPA_METRICS --> COLLECT
    SSH_METRICS --> COLLECT
    USER_METRICS --> COLLECT
    
    AUDIT_LOGS --> LOG_COLLECT
    SEC_EVENTS --> LOG_COLLECT
    
    COLLECT --> STORE
    LOG_COLLECT --> LOG_STORE
    
    STORE --> OPS_DASH
    STORE --> SEC_DASH
    STORE --> EXEC_DASH
    LOG_STORE --> SEC_DASH
    
    STORE --> CRITICAL
    STORE --> WARNING
    STORE --> INFO
    
    classDef collect fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef process fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
    classDef analyze fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    
    class VM_METRICS,NFS_METRICS,NET_METRICS,IPA_METRICS,SSH_METRICS,USER_METRICS,AUDIT_LOGS,SEC_EVENTS collect
    class COLLECT,STORE,LOG_COLLECT,LOG_STORE process
    class OPS_DASH,SEC_DASH,EXEC_DASH,CRITICAL,WARNING,INFO analyze
```

---

</details>
