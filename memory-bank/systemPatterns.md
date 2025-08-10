# System Patterns

## Infrastructure Patterns
- **Modular Infrastructure**: Separate Terraform modules per component with clear interfaces and proper outputs
- **Security-First Design**: Zero service account keys, CMEK encryption, deny-by-default networking, IAP-only access
- **Phased Deployment**: Phase-0 (foundation) → Phase-1 (VMs/services) → Documentation - NOW COMPLETED through comprehensive documentation
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

## Documentation Patterns
- **Dual-Audience Reports**: Stakeholder master report with business focus; technical deep-dive for engineers
- **Embedded Diagrams**: Mermaid charts integrated directly in reports (network, security, coordination, executive overview)
- **Style Compliance**: Strict adherence to `ctx_doc_style.md` with YAML front matter, details blocks, bullets-only content
- **Cross-Linking**: Navigation between reports with consistent terminology and file references
- **Prompt Transparency**: Formatted user-only logs for examiner review of GenAI usage
- **Visual Communication**: Network topology, security flows, deployment timelines, and stakeholder-friendly overviews
