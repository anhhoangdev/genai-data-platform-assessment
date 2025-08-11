title: report_A01_part1
---

---

## Deployment (Engine)
---
### Deployment (Engine)
<details>
<summary>Prerequisites, module layout, Ansible roles, sequence, validation, rollback</summary>

---

#### Prerequisites
- Tooling: Terraform >= `1.6`, Ansible >= `2.15`, gcloud SDK
- Access: GCP project with billing; contributor/editor as appropriate; IAP access group membership
- Configuration: Terraform backend (remote state), environment variables and tfvars; Ansible inventories and group_vars
- Security: `WIF` configured for GitHub Actions; no SA keys; Secret Manager entries prepared
- KMS: Keyring/keys created for `CMEK`; IAM grants applied

---

#### Terraform Modules
- Foundation (Phase 0): enable APIs, `WIF`, `KMS/CMEK`, org policies
- Network: VPC, subnets (`management`, `services`, `workstations`), firewall rules (deny-by-default)
- Bastion: VM instance, IAP-only ingress, OS hardening base
- FreeIPA: server VM, bootstrap disks, network
- Filestore: Enterprise tier, export policy to subnets
- Workstations: MIG (0–10), template with SSSD/autofs prerequisites

---

#### Ansible Playbooks
- Bastion: `common-base`, hardening, IAP SSH config, NFS tools
- FreeIPA: server install, realm setup, DNS, PAM/SSSD policies
- Workstations: IPA client join, autofs maps for NFS home, developer tools (Code-server/JupyterLab)
- Idempotency: reruns safe; use tags for targeted changes (for example `--tags filestore-bootstrap`)

---

#### Coordination Workflow
- Diagram
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

#### Validation Steps
- IAP SSH to bastion succeeds; no public SSH; firewall rules deny-by-default
- Bastion/workstation login resolves via FreeIPA; `id <user>` shows expected groups
- Workstation autofs mounts Filestore home; read/write within SLOs
- Dev tools (code-server, JupyterLab) reachable as per policy; dashboards/alerts active

---

#### Rollback Procedures
- Terraform: targeted destroy/apply for failed modules; preserve state integrity; explicit approvals
- Ansible: re-run roles with known good vars/tags; for workstations, recreate instances via MIG to remediate drift
- Data: Filestore snapshots for restore; verify before resuming operations
- Identity: restore FreeIPA from `ipa-backup` if needed; rotate passwords/keys as part of recovery

---

</details>

---
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

---
## Operations (Deep)
---
### Operations (Deep)
<details>
<summary>Runbooks, data protection, access controls, SLOs</summary>

---

#### Runbooks
- User onboarding (FreeIPA): create user, assign groups, verify login via IAP → bastion → workstation; ensure home dir created on first login via autofs
- User offboarding: disable user in FreeIPA, remove from groups, archive and retain NFS home per retention policy, revoke IAP access group
- Workstation lifecycle: scale MIG as needed; to recycle an instance, cordon (via label/group), drain user sessions, recreate instance to remediate drift
- Password and auth: support `ipa` password reset; guide users on Kerberos `kinit`, `klist`, ticket renewal; enforce password policies in FreeIPA
- NFS troubleshooting: verify autofs maps, test `showmount -e` and `mount -t nfs4`; check Filestore health and network ACLs/firewall
- FreeIPA maintenance: monitor services; apply updates during maintenance windows; back up with `ipa-backup`; maintain a recovery SOP
- Change management: all infra changes via Terraform; config changes via Ansible with tags; record changes and validation in change log

---

#### Backups & DR
- Filestore protection: daily snapshots with weekly/monthly retention; define `RPO` and `RTO` targets aligned to business impact
- FreeIPA backup: periodic `ipa-backup` archives stored securely; document restore steps and verify integrity
- Configuration state: Terraform remote state with backups; Ansible inventories and roles versioned in Git
- DR exercises: quarterly restore tests for Filestore snapshots and FreeIPA backups; document outcomes and remediation actions
- Cross-region considerations: assess replication requirements and costs; document failover procedure if required by SLA

---

#### Access Management
- Identity source: FreeIPA as system of record for users, groups, and sudo policies; Cloud IAM for GCP resource permissions
- Group-based access: map engineering cohorts to FreeIPA groups; align IAP access to group membership; least-privilege by default
- Privileged access: define admin groups with time-bounded elevation; enforce MFA where applicable; maintain break-glass account with sealed procedures
- Auditability: log IAP access, SSH sessions, sudo invocations, and FreeIPA changes; centralize logs and alerts in Cloud Logging/Monitoring
- Join/leave process: documented workflows for onboarding/offboarding; periodic review of group memberships and dormant accounts

---

#### SLOs & Reporting
- Availability SLO: `99.9%` platform uptime; authentication median response `<2s`; define error budget and burn alerts
- Performance SLOs: NFS latency within target (read/write) for typical workloads; workstation readiness time within agreed bounds
- Operational KPIs: deployment success rate, mean time to recover (`MTTR`), incident count, backup success rate, DR test success
- Reporting cadence: monthly service report to stakeholders with SLOs, KPIs, costs, and improvement actions
- Cost governance: track Filestore and MIG spend; scale policies reviewed monthly for cost/performance balance

---

</details>

---
## Risks
---
### Risk Register (Technical)
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

---
## Appendices
---
### Executive Overview Diagram (Reference)
<details>
<summary>Stakeholder-friendly overview</summary>

---
- Diagram
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


