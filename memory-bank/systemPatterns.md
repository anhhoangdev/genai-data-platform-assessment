# System Patterns

## Infrastructure Patterns
- **Modular Infrastructure**: Separate Terraform modules per component with clear interfaces and proper outputs
- **Security-First Design**: Zero service account keys, CMEK encryption, deny-by-default networking, IAP-only access
- **Phased Deployment**: Phase-0 (foundation) → Phase-1 (VMs/services) → Phase-2 (applications) - NOW COMPLETED through Phase-1
- **Infrastructure as Code**: All infrastructure provisioned via Terraform with GitHub Actions CI/CD
- **Workload Identity Federation**: GitHub Actions authentication without long-lived secrets

## Authentication & Access Patterns
- **Centralized Authentication**: FreeIPA domain controller with Kerberos/LDAP integration
- **Zero Trust Network**: IAP tunnel access, no public IPs, bastion jump pattern
- **Dynamic Service Discovery**: GCE dynamic inventory for Ansible automation
- **Automated Enrollment**: FreeIPA OTP generation and Secret Manager integration
- **VM-based Compute**: Persistent VMs with FreeIPA authentication and NFS shared storage

## Storage & Data Patterns
- **Shared NFS Storage**: Filestore with autofs automation for transparent mounting
- **Directory Structure**: `/export/home` for user directories, `/export/shared` for team collaboration
- **Permission Management**: PAM integration with automatic home directory creation
- **Data Engineering Layout**: Structured shared directories (data/, projects/, models/)

## Operational Patterns
- **Configuration as Code**: Complete Ansible automation (8 roles covering all aspects)
- **Deterministic Operations**: Fixed workstation selection, predictable IAP tunneling
- **Secret Rotation**: Automated OTP renewal and Secret Manager version management
- **Comprehensive Documentation**: Multi-file reports with Mermaid diagrams and deployment checklists
- **AI Support**: Prompts stored in `prompt_logs/`, version-controlled and structured
- **Memory Bank Workflow**: Complete context preservation across Cursor sessions
- **Dependency Management**: Explicit Terraform dependencies for reliable deployment ordering

## Production Readiness Patterns
- **Enterprise Access Control**: Google Group-based IAP authorization
- **Monitoring Integration**: Google Ops Agent on all VMs, structured logging
- **Scalable Compute**: MIG-based workstations with autoscaling (0-10 instances)
- **Fault Tolerance**: Multi-zone deployment, health checks, auto-healing policies
