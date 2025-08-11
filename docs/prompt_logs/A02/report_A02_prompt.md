
# Phase 1: Planning

## 1. User Prompt

> # Mode: PLAN
>
> You are my Senior Data Architect and Platform Engineer mentor.
>
> I’m sharing a description of an AWS MWAA (Airflow) + Dask hybrid architecture for periodic, parallel data processing pipelines.
> Please break it down step-by-step, explaining how it works, its limitations, and key design decisions.

---

## 2. User Prompt

> Take the AWS MWAA + Dask architecture we just discussed and redesign it using GCP services instead of AWS.

---

## 3. User Prompt

> Here’s a GCP blog on scalable Python data processing using Dask:
> [https://cloud.google.com/blog/products/data-analytics/improve-data-science-experience-using-scalable-python-data-processing](https://cloud.google.com/blog/products/data-analytics/improve-data-science-experience-using-scalable-python-data-processing)
> Show me how to integrate the approach in the blog into the GCP architecture you proposed.

---

## 4. User Prompt

> Here’s the full documentation for my current A01 GCP data platform.
> Review it and suggest how Dask could be integrated.

---

## 5. User Prompt

> Given the current A01 platform, explain exactly how Dask can be integrated without breaking the existing environment.

---

## 6. User Prompt

> In the MWAA + Dask example from earlier, was Dataproc used, or is it running entirely on AWS services?

---

## 7. User Prompt

> Here’s the A01 platform specification again.
> Propose how to add a Dask cluster to this environment, step-by-step.

---

## 8. User Prompt

> I’ve chosen Option B: Dask on Dataproc.
> Write a detailed LLM prompt that includes my current A01 context, the integration goals, constraints, and expected outputs.

---

## 9. User Prompt

> Based on Option B (Dask on Dataproc), describe the end-to-end expected workflow for running a distributed job in my environment.

---

## 10. User Prompt

> Design the workflow for how developers will submit and run Dask jobs in this setup.
> Consider GitLab (or similar) integration to sync code into Composer/DAGs and package for Dataproc execution.

---

## 11. User Prompt

> **Context**
>
> We have an existing secure GCP data platform named **A01** running in a single GCP project.
>
> **Current Architecture**
>
> * **VPC:** `data-platform` with subnets:
>
>   * `management` — IAP, Bastion, FreeIPA
>   * `services` — Filestore Enterprise (NFS v4.1)
>   * `workstations` — MIG (0–10 developer VMs)
> * **Identity:** FreeIPA for LDAP/Kerberos (PAM/SSSD) authentication.
> * **Ingress:** IAP-only SSH, no public SSH.
> * **Automation:** Terraform (infra), Ansible (config), GitHub Actions with Workload Identity Federation (WIF).
> * **Storage:** Filestore NFS for home directories, optional GCS.
> * **Security:** CMEK via KMS, deny-by-default firewall.
> * **Monitoring:** Cloud Monitoring, Cloud Logging, custom exporters.
>
> **New Goals — Ephemeral Compute Layer with Dask on Dataproc (Task A02)**
>
> 1. Integrate **Cloud Composer (Managed Airflow)** into A01’s VPC for orchestration.
> 2. Use Composer DAGs to:
>
>    * Create ephemeral **Dataproc cluster** with **Dask init-action** and Component Gateway.
>    * Submit distributed Python workloads using `YarnCluster` + `dask.distributed.Client`.
>    * Auto-scale cluster dynamically (`cluster.adapt()`) or set fixed worker count.
>    * Delete the cluster after job completion.
> 3. Ensure Dask workers can access data from:
>
>    * Filestore (NFS mount from `services` subnet), **or**
>    * GCS buckets for cloud-native workflows.
> 4. Keep all **network traffic private**:
>
>    * Private IP Dataproc
>    * Private Composer
> 5. Maintain **security & IAM standards**:
>
>    * WIF for automation
>    * CMEK encryption
>    * Deny-by-default firewall
>    * No service account keys
> 6. Implement **monitoring & observability**:
>
>    * Dask dashboard via Component Gateway
>    * Metrics in Cloud Monitoring
>    * Logs in Cloud Logging
>
> **Constraints**
>
> * Preserve existing FreeIPA/MIG developer workflows.
> * Do not expose Dataproc or Composer to the public internet.
> * Provision all infra via Terraform, store DAG logic in GitHub repo.
> * Use GCP-managed services wherever possible.
> * Keep compute costs low by scaling to zero when idle.
>
> **Expected Output from LLM**
>
> 1. **High-Level Architecture Diagram**
>
>    * Mermaid diagram showing how Dataproc + Dask integrates into A01’s existing network and components.
> 2. **Terraform Resource Plan**
>
>    * For adding Composer and Dataproc integration into A01 infra.
>    * Includes:
>
>      * Private IP Composer environment in `management` or `services` subnet.
>      * Dataproc cluster template with Dask init-action.
>      * Firewall rules for Dataproc ↔ Filestore/GCS access.
> 3. **Sample Airflow DAG (Python)**
>
>    * Creates ephemeral Dataproc + Dask cluster.
>    * Executes a parallel Python job (reads from Filestore or GCS).
>    * Tears down the cluster on completion.
> 4. **Security & Networking Notes**
>
>    * How to keep Dataproc and Composer private.
>    * How to allow NFS and GCS access from Dataproc workers.
>    * IAM/WIF role setup for Composer to manage Dataproc without SA keys.
> 5. **Monitoring Strategy**
>
>    * Dask dashboard access (Component Gateway, private only).
>    * GCP Monitoring & Logging integration.
>    * Alerting on job failures, cluster provisioning errors, and resource saturation.

want me to wrap the other prompt sections the same way?
