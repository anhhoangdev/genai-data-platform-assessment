# GenAI Technical Assessment – Data Platform Engineering

**Author:** Tran Hoang Anh  
**Position Applied:** Data Engineer / Infra Engineer  
**Assessment Duration:** August 8–13, 2025  
**GitHub Repo:** [github.com/anhhoangdev/genai-data-platform-assessment](https://github.com/anhhoangdev/genai-data-platform-assessment)

---

## 📌 About This Assignment

This repository contains my submission for the GenAI-powered technical assessment, covering key infrastructure and data engineering tasks. Each task demonstrates:

- 🔍 System design and architectural planning
- 🤖 Effective use of GenAI tools (Claude 3.5 Sonnet, Cursor, GitHub Copilot)
- 🧠 Analytical thinking and tradeoff evaluation
- 📝 Clear, structured documentation and rationale

---

## 📂 Repository Structure

### Multi-File Report Organization
```
docs/reports/
├── A01/                             # GCP Infrastructure
│   ├── report_A01.md               # Main overview (300-500 lines)
│   ├── report_A01_part01_architecture.md
│   ├── report_A01_part02_deployment.md
│   ├── report_A01_part03_operations.md
│   └── report_A01_diagram.md       # Mermaid diagrams
├── A02/                             # Dask Cluster
│   ├── report_A02.md
│   ├── report_A02_part01_architecture.md
│   ├── report_A02_part02_integration.md
│   ├── report_A02_part03_performance.md
│   └── report_A02_diagram.md
└── B01/                             # Vector Database Tutorial
    ├── report_B01.md
    ├── report_B01_part01_concepts.md
    ├── report_B01_part02_tools.md
    ├── report_B01_part03_implementation.md
    └── report_B01_diagram.md
```

### Centralized GenAI Documentation
```
prompt_logs/
├── prompt_A01_main.md              # Strategic GenAI overview for A01
├── prompt_A01_part01_architecture.md
├── prompt_A01_part02_deployment.md
├── prompt_A02_main.md              # Strategic GenAI overview for A02
├── prompt_A02_part01_architecture.md
├── prompt_B01_main.md              # Strategic GenAI overview for B01
└── prompt_B01_part01_concepts.md
```

### Infrastructure Code
```
terraform/                          # A01 GCP Infrastructure
├── modules/
│   ├── iam/
│   ├── vpc/
│   ├── gke/
│   └── freeipa/
└── main.tf

dask-cluster/                        # A02 Compute Platform
├── helm/
└── configs/

vector-db-tutorial/                  # B01 Educational Content
├── README.md
└── chromadb_demo.ipynb
```

---

## ✅ Task Deliverables

| Task Code | Name | Focus | Report Lines |
|-----------|------|-------|--------------|
| **A01** | GCP Infrastructure | Terraform, IAM, VPC, GKE, FreeIPA, NFS | 1000-1500 |
| **A02** | Dask Cluster | Scalable Python compute with multi-user support | 1000-1500 |
| **B01** | Vector DB Tutorial | ChromaDB, concepts, tools, implementation | 1000-1500 |

### Content Requirements per Task
- **Main report**: 300-500 lines (executive summary + cross-references)
- **Part files**: 400-600 lines each (focused technical content)
- **Prompt logs**: Strategic GenAI usage and decision rationale
- **Diagrams**: Mermaid charts for architecture visualization

---

## 🧠 GenAI Strategy & Documentation

### Design Rationale: Centralized Prompt Logs

**Why separate `prompt_logs/` directory?**
- **Examiner efficiency**: Single location to review all GenAI usage across tasks
- **Traceability**: Clear naming convention links prompts to specific report sections
- **Comparative analysis**: Easy to compare prompt strategies across A01/A02/B01
- **Cleaner navigation**: Reduces duplication and improves repository organization

### GenAI Tool Usage
GenAI tools were used strategically for:
- 🔍 **Research & comparison**: Tool evaluation, best practices, architecture patterns
- 🏗️ **Architecture design**: System topology, component selection, integration patterns
- 🛠️ **Code scaffolding**: Terraform modules, Ansible roles, configuration templates
- ✍️ **Documentation**: Technical writing, structure optimization, diagram generation
- 🔄 **Iteration & refinement**: Quality improvement, consistency checks, validation

### Prompt Engineering Approach
- **Strategic prompts**: High-level architecture and planning decisions
- **Implementation prompts**: Specific code generation and configuration
- **Validation prompts**: Review, optimization, and quality assurance
- **Documentation prompts**: Technical writing and cross-referencing

---
