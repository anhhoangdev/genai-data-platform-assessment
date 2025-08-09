# System Patterns

- **Modular Infrastructure**: Separate Terraform modules per component with clear interfaces
- **Security-First Design**: Zero service account keys, CMEK encryption, deny-by-default networking
- **Phased Deployment**: Phase-0 (foundation) → Phase-1 (VMs/services) → Phase-2 (applications)
- **Infrastructure as Code**: All infrastructure provisioned via Terraform with GitHub Actions CI/CD
- **Workload Identity Federation**: GitHub Actions authentication without long-lived secrets
- **VM-based Compute**: Persistent VMs with FreeIPA authentication and NFS shared storage
- **Comprehensive Documentation**: Multi-file reports with Mermaid diagrams and deployment checklists
- **AI Support**: Prompts stored in `prompt_logs/`, version-controlled and structured
- **Memory Bank Workflow**: Complete context preservation across Cursor sessions
- **Dependency Management**: Explicit Terraform dependencies for reliable deployment ordering
