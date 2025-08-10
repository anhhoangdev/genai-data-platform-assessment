---
title: report_A01
---

---
## Architecture
---
### Architecture Diagram
<details>
<summary>System topology and component mapping</summary>

---
- **Diagram source**: `docs/diagrams/A01/architecture.mmd`
- **Technical Explanation**:
  - VPC `data-platform` segmented into subnets: `management` (IAP, Bastion, FreeIPA), `services` (Filestore), `workstations` (MIG 0–10 instances)
  - Access via IAP TCP forwarding terminates at Bastion; SSH ingress locked to IAP-only; deny-by-default firewall enforced across subnets
  - Centralized auth with FreeIPA; PAM/SSSD on Bastion/Workstations perform LDAP/Kerberos lookups for login and sudo policies
  - Filestore Enterprise provides NFS v4.1 shared storage; autofs mounts user home directories on workstations for transparent access
  - CI/CD uses GitHub Actions with WIF (no SA keys) to access GCP APIs; Terraform provisions infra; Ansible configures hosts
  - CMEK via KMS applied where supported; Secret Manager supplies runtime configuration and sensitive values
- **Business Summary**:
  - Secure-by-default access pattern using IAP eliminates public SSH and reduces attack surface
  - Single sign-on via FreeIPA increases productivity and simplifies account lifecycle management
  - Shared Filestore home directories enable seamless collaboration and reproducible developer environments
  - No service account keys (WIF) and CMEK encryption align with enterprise security and compliance controls
  - Elastic workstation pool supports 20–30 engineers with cost-efficient autoscaling
- **Diagram**:
  ```mermaid
  graph TB
  subgraph Internet["Users (Corp / VPN)"]
    User["Engineers (20–30)"]
  end

  subgraph GCP["GCP Project"]
    KMS["KMS (CMEK)"]
    SM["Secret Manager"]
    WIF["Workload Identity Federation (GitHub Actions)"]

    subgraph VPC["VPC: data-platform"]
      subgraph MGMT["Subnet: management"]
        IAP["IAP TCP Forwarding"]
        Bastion["Bastion VM"]
        FreeIPA["FreeIPA Server"]
      end

      subgraph SRV["Subnet: services"]
        Filestore["Filestore Enterprise (NFS v4.1)"]
      end

      subgraph WS["Subnet: workstations"]
        MIG["Workstation MIG (0–10 instances)"]
      end
    end

    APIs["GCP APIs (Terraform/Ansible targets)"]
  end

  User -->|"OAuth2"| IAP
  IAP -->|"TCP Forwarding (SSH)"| Bastion
  Bastion -->|"LDAP/Kerberos (PAM/SSSD)"| FreeIPA
  MIG -->|"LDAP/Kerberos (SSSD)"| FreeIPA
  MIG -->|"NFS v4.1 via autofs (home dirs)"| Filestore
  Bastion -.->|"Admin/Bootstrap"| Filestore

  WIF -->|"OIDC"| APIs
  APIs -->|"Provision"| VPC
  APIs -->|"Provision"| Bastion
  APIs -->|"Provision"| FreeIPA
  APIs -->|"Provision"| Filestore
  APIs -->|"Provision"| MIG

  KMS -->|"CMEK"| Filestore
  SM -->|"Runtime Secrets"| Bastion
  SM -->|"Runtime Secrets"| FreeIPA

  classDef boundary fill:#f7f7f7,stroke:#bbb,stroke-width:1px;
  class VPC,MGMT,SRV,WS boundary;

---

</details>

## Implementation Plan
---
### Coordination Workflow (Terraform → Ansible)
<details>
<summary>Execution order and orchestration</summary>

---
- **Diagram source**: `docs/diagrams/A01/coordination_workflow.mmd`
- **Technical Explanation**:
  - Phase 0 establishes the security foundation: enable APIs, provision KMS/CMEK, configure WIF, and apply org-level policies
  - Phase 1 provisions core infrastructure: VPC/subnets, Bastion, FreeIPA VM, Filestore, and Workstation MIG
  - Phase 2 applies configuration via Ansible roles in parallel: Bastion hardening, FreeIPA server setup, workstation join to IPA with autofs and dev tools
  - Phase 3 validates and hardens: security audit, performance testing, monitoring, backups, and DR testing
  - Phase 4 completes onboarding and docs: admin/test accounts, access validation, documentation, and training
  - Terraform drives immutable infra; Ansible configures OS/services; each step is idempotent and safe to re-run
- **Business Summary**:
  - Predictable, staged rollouts reduce deployment risk and improve auditability
  - Parallelizable steps accelerate time-to-value while preserving control points for validation
  - Clear separation of infra (Terraform) and config (Ansible) simplifies maintenance and change management
- **Diagram**:
  ```mermaid
  flowchart LR
    subgraph TF["Terraform"]
      P0["Phase 0: Foundation Security\n- Enable APIs\n- KMS/CMEK\n- WIF (GitHub ↔ GCP)\n- Org Policies"]
      P1["Phase 1: Infra Provision\n- VPC & Subnets\n- Bastion VM\n- FreeIPA VM\n- Filestore\n- Workstation MIG"]
    end

    subgraph ANS["Ansible"]
      P2A["Phase 2A: Bastion Config\n- Common base\n- IAP SSH hardening\n- NFS tools"]
      P2B["Phase 2B: FreeIPA Config\n- Server install\n- Realm setup\n- PAM/SSSD policies"]
      P2C["Phase 2C: Workstation Config\n- Join to IPA\n- autofs NFS home\n- Dev tools (Code-server/JupyterLab)"]
    end

    subgraph P3["Phase 3: Production Hardening"]
      P3A["Security Audit"]
      P3B["Performance Testing"]
      P3C["Monitoring Setup"]
      P3D["Backup Strategy"]
      P3E["DR Testing"]
    end

    subgraph P4["Phase 4: Onboarding & Docs"]
      P4A["Admin Accounts"]
      P4B["Test Accounts"]
      P4C["Access Validation"]
      P4D["Documentation"]
      P4E["Training"]
    end

    P0 --> P1
    P1 --> P2A
    P1 --> P2B
    P1 --> P2C
    P2A --> P3A
    P2C --> P3B
    P2C --> P3C
    P2C --> P3D
    P3D --> P3E
    P3A --> P4A
    P3A --> P4D
    P2B --> P4B
    P4A --> P4B --> P4C --> P4E
    TF -. orchestrates .-> ANS
  ```
---

</details>

---
## Deployment Guide
---
### Deployment Guide
<details>
<summary>Checklist, instructions, validations, and timeline</summary>

---
- **Pre-deployment checklist**:
  - GCP project with billing enabled; required APIs: Compute Engine, Filestore, KMS, IAM, Cloud Resource Manager
  - KMS keyring/keys prepared for CMEK; IAM grants for Terraform service identity via WIF
  - GitHub Actions WIF pool and provider configured; no service account keys
  - Terraform backend configured (remote state); vars validated; environment tooling installed (TF>=1.6, Ansible>=2.15)
  - Secret Manager entries created for sensitive values; org policy constraints reviewed
- **Phase-by-phase instructions**:
  - Phase 0: Initialize backend; apply `foundation` to enable APIs, KMS/CMEK, WIF
  - Phase 1: Apply `network`, `bastion`, `freeipa`, `filestore`, `workstations` modules; respect dependencies
  - Phase 2: Run Ansible roles per host group with tags: bastion hardening; FreeIPA server install; workstation join, autofs, dev tools
  - Phase 3: Execute security audit, performance tests, monitoring setup, backup policy; perform DR test
  - Phase 4: Create admin/test accounts; validate access; finalize documentation and deliver training
- **Validation checklist**:
  - IAP SSH to bastion works; no direct public SSH; firewall rules deny-by-default
  - User login on bastion/workstations resolves via FreeIPA (PAM/SSSD); `id` returns expected groups
  - Workstation autofs mounts Filestore home; NFS performance within target SLOs
  - Dev tools (code-server, JupyterLab) accessible per policy; monitoring & alerts active
- **Timeline (Gantt)**:
  ```mermaid
  gantt
    title A01 GCP Data Platform - Optimized Deployment Plan
    dateFormat  YYYY-MM-DD
    axisFormat  %m/%d

    section Phase 0
    Foundation Security     :phase0, 2025-01-20, 1d

    section Phase 1
    Bastion + Network       :p1a, after phase0, 4h
    FreeIPA VM Provision    :p1b, after p1a, 4h
    Filestore Provisioning  :p1c, after p1a, 4h
    Workstation MIG         :p1d, after p1c, 4h

    section Phase 2
    Bastion Config          :p2a, after p1a, 2h
    FreeIPA Config          :p2b, after p1b, 4h
    Workstation Config      :p2c, after p1d, 4h

    section Phase 3
    Security Audit          :p3a, after p2a, 4h
    Performance Testing     :p3b, after p2c, 4h
    Monitoring Setup        :p3c, after p2c, 4h
    Backup Strategy         :p3d, after p2c, 4h
    DR Testing              :p3e, after p3d, 4h

    section Phase 4
    Admin Accounts          :p4a, after p3a, 2h
    Test Accounts           :p4b, after p4a, 2h
    Access Validation       :p4c, after p4b, 3h
    Documentation           :p4d, after p3a, 4h
    Training                :p4e, after p4d, 4h
  ```
---

</details>

## Operations
---
### Runbooks
<details>
<summary>Day-2 operations procedures</summary>

---
- User onboarding (FreeIPA): create user, assign groups, verify login via IAP → bastion → workstation; ensure home dir created on first login via autofs
- User offboarding: disable user in FreeIPA, remove from groups, archive and retain NFS home per retention policy, revoke IAP access group
- Workstation lifecycle: scale MIG as needed; to recycle an instance, cordon (via label/group), drain user sessions, recreate instance to remediate drift
- Password and auth: support `ipa` password reset; guide users on Kerberos `kinit`, `klist`, ticket renewal; enforce password policies in FreeIPA
- NFS troubleshooting: verify autofs maps, test `showmount -e` and `mount -t nfs4`; check Filestore health and network ACLs/firewall
- FreeIPA maintenance: monitor services; apply updates during maintenance windows; back up with `ipa-backup`; maintain a recovery SOP
- Change management: all infra changes via Terraform; config changes via Ansible with tags; record changes and validation in change log
---

</details>

### Backups & DR
<details>
<summary>Data protection, recovery objectives, and testing</summary>

---
- Filestore protection: daily snapshots with weekly/monthly retention; define `RPO` and `RTO` targets aligned to business impact
- FreeIPA backup: periodic `ipa-backup` archives stored securely; document restore steps and verify integrity
- Configuration state: Terraform remote state with backups; Ansible inventories and roles versioned in Git
- DR exercises: quarterly restore tests for Filestore snapshots and FreeIPA backups; document outcomes and remediation actions
- Cross-region considerations: assess replication requirements and costs; document failover procedure if required by SLA
---

</details>

### Access Management
<details>
<summary>RBAC model and privileged access controls</summary>

---
- Identity source: FreeIPA as system of record for users, groups, and sudo policies; Cloud IAM for GCP resource permissions
- Group-based access: map engineering cohorts to FreeIPA groups; align IAP access to group membership; least-privilege by default
- Privileged access: define admin groups with time-bounded elevation; enforce MFA where applicable; maintain break-glass account with sealed procedures
- Auditability: log IAP access, SSH sessions, sudo invocations, and FreeIPA changes; centralize logs and alerts in Cloud Logging/Monitoring
- Join/leave process: documented workflows for onboarding/offboarding; periodic review of group memberships and dormant accounts
---

</details>

### SLOs & Reporting
<details>
<summary>Service objectives, KPIs, and review cadence</summary>

---
- Availability SLO: `99.9%` platform uptime; authentication median response `<2s`; define error budget and burn alerts
- Performance SLOs: NFS latency within target (read/write) for typical workloads; workstation readiness time within agreed bounds
- Operational KPIs: deployment success rate, mean time to recover (`MTTR`), incident count, backup success rate, DR test success
- Reporting cadence: monthly service report to stakeholders with SLOs, KPIs, costs, and improvement actions
- Cost governance: track Filestore and MIG spend; scale policies reviewed monthly for cost/performance balance
---

</details>
## Monitoring
---
### Monitoring & Alerts
<details>
<summary>Observability coverage and alerting policies</summary>

---
- Stack: Cloud Monitoring dashboards and alerting; Cloud Logging for audit and system logs; optional exporters for FreeIPA metrics
- Key metrics: VM CPU, memory, disk; Filestore IOPS/throughput/latency; FreeIPA service health; authentication failure rate; IAP access logs
- Synthetic checks: periodic SSH via IAP, FreeIPA LDAP bind checks, NFS mount and read/write probes from a canary workstation
- Alert policies: graded severities with clear runbooks; include rate-based alerts for login failures and NFS saturation
- Dashboards: per-component (bastion, FreeIPA, Filestore, MIG) and executive overview for availability and capacity
---

</details>
## Security
---
### Integration Flow (Auth + NFS)
<details>
<summary>Authentication and NFS interaction flows</summary>

---
- **Diagram source**: `docs/diagrams/A01/integration_flow.mmd`
- **Technical Explanation**:
  - Users authenticate through IAP; IAP establishes a TCP-forwarded SSH session to bastion
  - Bastion uses PAM/SSSD to consult FreeIPA for identity, group membership, and policy
  - Users hop to workstations; SSSD on workstations integrates with FreeIPA for Kerberos/LDAP
  - autofs mounts NFS home directories from Filestore (NFS v4.1) for a consistent home across the fleet
  - Kerberos ticket lifecycle (kinit/renewal) ensures secure session operations for users and services
- **Business Summary**:
  - Unified SSO controls access centrally, reducing admin overhead and audit complexity
  - No public SSH exposure; ingress is restricted to IAP, minimizing attack surface
  - Shared home directories streamline collaboration and tool consistency across the team
- **Diagram**:
  ```mermaid
  sequenceDiagram
    autonumber
    participant U as User
    participant IAP as IAP (TCP Forwarding)
    participant B as Bastion
    participant IPA as FreeIPA
    participant W as Workstation
    participant N as Filestore (NFS)

    U->>IAP: Authenticate (OAuth2)
    IAP->>B: Establish SSH (IAP TCP tunnel)
    B->>IPA: PAM/SSSD lookup (LDAP/Kerberos)
    IPA-->>B: AuthZ/AuthN response
    Note over B,IPA: Access controlled via IPA policies

    U->>W: SSH jump via Bastion
    W->>IPA: SSSD join/lookup (Kerberos/LDAP)
    IPA-->>W: Realm config / tickets

    W->>N: autofs mount NFS home (v4.1)
    N-->>W: Home directory mounted
    Note over W,N: Transparent home directories for users

    rect rgb(240,240,240)
    Note over U,W: Ticket lifecycle (kinit, renewal)
    end
  ```
---

</details>

## Risks
---
### Risk Register (Summary)
<details>
<summary>Top risks, impact, and mitigations (stakeholder view)</summary>

---
- FreeIPA availability: single-server failure could impact logins; mitigation: frequent backups, documented recovery, evaluate warm standby
- NFS performance bottlenecks under peak load; mitigation: monitor IOPS/latency, scale Filestore tier/capacity, optimize autofs and client mounts
- Misconfigured IAP/firewall exposing services; mitigation: deny-by-default rules, change review, automated validation checks
- WIF/OIDC configuration drift breaks CI/CD; mitigation: version-controlled identity settings, validation pipeline, fallback manual deploy SOP
- Cost overrun from MIG growth; mitigation: autoscaling bounds, usage dashboards, periodic right-sizing reviews
- Operational error during changes; mitigation: change windows, peer review, staged rollouts, fast rollback via Terraform/Ansible
---

</details>

 
### Risk Register
<details>
<summary>Top risks, impact, and mitigations</summary>

---
- FreeIPA availability: single-server failure could impact logins; mitigation: frequent backups, documented recovery, evaluate warm standby
- NFS performance bottlenecks under peak load; mitigation: monitor IOPS/latency, scale Filestore tier/capacity, optimize autofs and client mounts
- Misconfigured IAP/firewall exposing services; mitigation: deny-by-default rules, change review, automated validation checks
- WIF/OIDC configuration drift breaks CI/CD; mitigation: version-controlled identity settings, validation pipeline, fallback manual deploy SOP
- Cost overrun from MIG growth; mitigation: autoscaling bounds, usage dashboards, periodic right-sizing reviews
- Operational error during changes; mitigation: change windows, peer review, staged rollouts, fast rollback via Terraform/Ansible
---

</details>
## Appendices
---
### Related Technical Deep Dive
<details>
<summary>Link to full engineering details</summary>

---
- For complete technical details (network, security, deployment, ops), see: `report_A01_technical.md`
- This stakeholder report remains focused on outcomes, timelines, and risk posture
---

</details>
### Executive Overview Diagram
<details>
<summary>Stakeholder-friendly overview</summary>

---
- **Diagram source**: `docs/diagrams/A01/exec_overview.mmd`
- **Technical Explanation**:
  - Access is mediated by IAP to a hardened bastion before reaching auto-scaling workstations
  - FreeIPA provides centralized identity and policy; Filestore provides a shared NFS collaboration space
  - Security features include WIF (no SA keys), CMEK encryption, and deny-by-default firewall policies
- **Business Summary**:
  - Executive view: secure, scalable developer platform with centralized control and predictable cost
  - Directly supports 20–30 engineers with consistent tooling and SSO, improving onboarding and productivity
  - Aligns with enterprise security controls and audit requirements without sacrificing developer velocity
- **Diagram**:
  ```mermaid
  graph LR
    Users["Users (20–30 Engineers)"] --> IAP["IAP (Secure Access)"] --> Bastion["Bastion"] --> Workstations["Workstations (MIG)"]
    Workstations --> Filestore["Filestore (Shared NFS)"]
    Workstations -. SSO .- FreeIPA["FreeIPA (SSO)"]

    subgraph Security["Security Features"]
      WIF["WIF (No SA Keys)"]
      CMEK["CMEK Encryption"]
      FW["Deny-by-default Firewall"]
    end

    WIF --- IAP
    CMEK --- Filestore
    FW --- Bastion
    FW --- Workstations

    classDef highlight fill:#f5faff,stroke:#7fb3ff,stroke-width:1px;
    class IAP,Bastion,Workstations,Filestore,FreeIPA highlight;
  ```
---

</details>

### Overview
<details>
<summary>Scope, assumptions, and objectives</summary>

---
- Assumptions
- Constraints
- Objectives
---

#### Context
- Background and related systems
---

</details>
