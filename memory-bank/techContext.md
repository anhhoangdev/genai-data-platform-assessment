# Tech Context

- Cloud: GCP (IAM, VPC, Compute Engine, KMS, Secret Manager, Filestore, Cloud DNS)
- IaC: Terraform (>=1.6) with modular structure, Ansible (>=2.15)
- Security: Workload Identity Federation, CMEK encryption, deny-by-default networking
- CI/CD: GitHub Actions with WIF authentication (no service account keys)
- Compute: VM-based with FreeIPA auth, NFS shared storage, MIG autoscaling; Dask; optional Metaflow
- Data tutorials: Vector DBs (e.g., ChromaDB)
- Docs: ctx_doc_style; Docusaurus (optional viewer)
- Local: Linux; Node.js; Python 3.10+
- Infrastructure Status: A01 complete with Phase-0 foundation + Phase-1 VMs + comprehensive documentation
- Documentation Status: Master stakeholder report and technical deep-dive with embedded Mermaid diagrams
- Prompt Logs: Formatted user-only extracts for examiner review and GenAI transparency
