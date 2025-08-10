# Extend GCP Terraform project to Phase 1
_Exported on 8/10/2025 at 22:46:42 GMT+7 from Cursor (1.4.3)_

---

**User**

You are an infra copilot. Extend an existing GCP “Phase 0” Terraform project that already has:
- VPC, subnets, firewall deny-all + allow rules
- Cloud NAT, Private DNS
- KMS with CMEK
- Secret Manager secrets
- Workload Identity Federation for CI/CD
- No compute resources yet

## GOAL: Phase 1 — Add VM layer
Provision and configure:
1. **Bastion VM** (IAP-only SSH) in `subnet-services`
2. **FreeIPA VM** (central auth) in `subnet-services`
3. **Filestore** (Enterprise or High Scale) with NFS exports for `/export/home` and `/export/shared`
4. **Managed Instance Group of workstation VMs** (stateless, homes on NFS, pre-installed dev tooling, joined to FreeIPA)
5. **Browser IDE panels** (code-server on 8080, JupyterLab on 8888) running as user systemd services, bound to localhost, accessible only via IAP TCP tunnels
6. **Ansible roles** to configure all VMs

## INFRA CONSTRAINTS
- No public IPs; all VM access via IAP (SSH, TCP)
- Private-only networking, all traffic egress via Cloud NAT from Phase 0
- Shielded VM enabled for all instances
- Instance templates + MIG for workstation pool (min/max configurable)
- FreeIPA secrets (admin password, OTP) come from Secret Manager created in Phase 0
- NFS client mounts via autofs
- Ops Agent installed on all VMs
- IAM: least privilege; reuse Phase 0 service accounts or add new scoped ones

## REPO LAYOUT ADDITIONS
terraform/
  modules/
    bastion/
    freeipa_vm/
    filestore/
    instance_template_workstation/
    mig_workstation/
    dns_records/
  envs/dev/
    phase1.tf
    variables.phase1.tf

ansible/
  inventories/dev/hosts.ini
  playbooks/
    bastion.yml
    freeipa.yml
    workstation.yml
  roles/
    common-base/           # packages, ops agent, hardening
    freeipa-server/
    freeipa-client/
    nfs-client/
    panel-code-server/
    panel-jupyterlab/

scripts/
  broker_select_vm.sh
  iap_tunnel_code.sh
  iap_tunnel_jupyter.sh

docs/
  phase1_arch_diagram.mmd
  phase1_access_flows.mmd

## TERRAFORM DETAILS
### Bastion
- Ubuntu LTS, small machine type (var.bastion_machine_type), tags=["bastion"]
- Metadata startup script to install Google Ops Agent and add ansible_ready marker

### FreeIPA
- Ubuntu or RHEL VM (var.freeipa_machine_type), tags=["freeipa"]
- Cloud-init to install FreeIPA server, initialize realm/domain
- Secrets for admin password and OTP fetched from Secret Manager (Phase 0)
- Static internal IP in `subnet-services`

### Filestore
- Tier, capacity, export paths configurable via vars
- Export rules restricted to workstation subnet CIDR

### Workstation MIG
- Instance template:
  - Ubuntu LTS
  - Pre-installed baseline tools (python3, pip, git, tmux, htop, terraform, gcloud)
  - Ops Agent
  - Ansible tag marker
- MIG:
  - min/max/target size via vars
  - Autoscale by CPU
  - Health check on SSH port 22
- Tags=["workstation"]

## ANSIBLE DETAILS
### common-base
- Install baseline tools, harden SSH (no root login)
- Install google-ops-agent

### nfs-client
- Install nfs-common, autofs
- Autofs maps for `/home/%(USER)s` and `/shared/{data,projects,models}` from Filestore

### freeipa-server
- Install and configure FreeIPA server
- Enable Kerberos, LDAP, HTTPS
- Integrate with DNS if required

### freeipa-client
- Join workstation to FreeIPA realm
- Configure sudo via IPA groups
- Enable mkhomedir

### panel-code-server
- Install code-server
- Create user systemd unit binding to 127.0.0.1:8080, auth disabled (local only)
- Enable linger for persistent service

### panel-jupyterlab
- Install pipx + jupyterlab
- Create user systemd unit binding to 127.0.0.1:8888, token/password disabled (local only)
- Enable linger

## SCRIPTS
### broker_select_vm.sh
- List MIG instances, pick least-loaded or random, SSH via bastion

### iap_tunnel_code.sh / iap_tunnel_jupyter.sh
- Start IAP tunnel from local machine to VM on ports 8080/8888
- Echo “Open http://localhost:<port>”

## DOCS
- phase1_arch_diagram.mmd: Show Bastion, FreeIPA, Filestore, MIG workstations, IAP flows
- phase1_access_flows.mmd: Show SSH and panel access sequences
- README Phase 1 section: deployment steps, tunnel usage, troubleshooting

## ACCEPTANCE CRITERIA
- `terraform apply` in envs/dev creates Bastion, FreeIPA, Filestore, MIG workstations, firewall rules, DNS records
- After Ansible runs:
  - Workstations joined to FreeIPA
  - Homes and /shared mounted from Filestore
  - Ops Agent running
  - code-server + JupyterLab running as user services, bound to localhost
- From local:
  - SSH via bastion works
  - IAP tunnels to 8080/8888 open IDEs in browser

Generate all necessary Terraform, Ansible, scripts, and docs to achieve the above, integrating cleanly with the existing Phase 0 modules and networking.


---

**Cursor**

I’m going to quickly scan the Memory Bank and existing Terraform env files and modules to align the Phase 1 plan with what’s already in place, especially subnet names, service accounts, and variable conventions. Then I’ll present a concrete implementation plan and module/role skeletons.

# Mode: PLAN

Quick status: I read the Memory Bank and Phase 0 Terraform. We have `subnet-services` and `subnet-workloads`, firewall rules already prep’d for bastion, FreeIPA and SSH hop, NAT and private DNS are in place, and secrets exist in Secret Manager. I’ll propose a Phase 1 plan that cleanly extends this structure without leaking secrets into state and respects IAP-only and private-only constraints.

### 1) What’s required and how it differs from Kubernetes-native design
- VM-based vs K8s:
  - In K8s, pods are ephemeral, identities are via Kubernetes RBAC/service accounts, storage is object/PVC, ingress via Ingress/Service.
  - Here, instances are VMs with OS lifecycle, auth is centralized via FreeIPA (Kerberos/LDAP), shared storage is Filestore (NFS), access is via IAP and SSH, and we harden at the VM/OS level.
- Networking:
  - No public IPs; all access via IAP. In K8s you’d often expose via LoadBalancer/Ingress; here we rely on IAP TCP or SSH tunnels and firewall allowlists.
- State/config:
  - We will not move secrets through Terraform state. VMs fetch secrets at runtime using the instance’s service account to query Secret Manager via metadata token, then Ansible finalizes config.
- Identity mapping:
  - Kubernetes RBAC and namespace isolation map to FreeIPA realms/groups and Linux permissions. Autofs + NFS replaces ephemeral PVCs for developer workstations.

### 2) Architecture for 20–30 engineers (VM layer)
- Bastion:
  - Ubuntu LTS, small (`var.bastion_machine_type`), tags: `["vm-managed", "bastion"]`. IAP-only SSH, Ops Agent, Ansible control node optional.
- FreeIPA:
  - Ubuntu LTS (stable on 22.04) or RHEL; we’ll default to Ubuntu LTS for consistency. Static internal IP in `subnet-services`, tags: `["vm-managed", "freeipa"]`. Cloud-init bootstraps IPA server using secrets fetched at runtime.
- Filestore:
  - Enterprise or High Scale, tier and capacity configurable. Two exports: `/export/home`, `/export/shared`. Export rules restricted at minimum to `subnet-workloads` CIDR; optionally add `subnet-services` if you want bastion/ipa mounts for admin.
- Workstations:
  - Instance Template (Ubuntu LTS) + MIG in `subnet-workloads`, tags: `["vm-managed", "worker", "workstation"]`. Baseline dev tools, Ops Agent, Ansible-ready marker. Homes on NFS `/home/<user>` via autofs; `/shared/{data,projects,models}` via autofs.
  - MIG autoscale by CPU; health check on port 22; no public IPs; Shielded VM enabled.
- Access:
  - SSH: IAP → bastion (22), then bastion → workstations (22). No direct IAP to workers by default to honor bastion pattern.
  - Panels: code-server (localhost:8080) and JupyterLab (localhost:8888) run as per-user systemd units. Access via SSH port-forwarding through IAP to bastion, then ProxyJump to workstation, forwarding remote localhost ports to local.
- IAM and SAs:
  - New per-role instance SAs:
    - `sa-bastion`: minimal (logging/monitoring). No Secret Manager needed.
    - `sa-freeipa`: Secret Manager accessor for `freeipa_admin_password`. No OTP needed on server side; the OTP is used by clients.
    - `sa-workstation`: Secret Manager accessor only for `ipa_enrollment_otp`, plus logging/monitoring.
  - Keep least privilege; bind those SAs only to the specific secrets via secret-level IAM bindings.

### 3) Terraform high-level structure (modules, variables, wiring)
- New modules under `terraform/modules/`:
  - `bastion/`
    - Creates `google_compute_instance` (no public IP), Shielded VM, tag `bastion`, startup script for Ops Agent + ansible marker.
    - Inputs: project_id, region, zone, subnet_self_link, machine_type, image, tags, service_account_email, metadata_startup_script.
    - Outputs: instance self_link, name, internal_ip.
  - `freeipa_vm/`
    - Reserves internal `google_compute_address`; creates VM with Shielded VM, tag `freeipa`, cloud-init to install and initialize FreeIPA. Metadata to bootstrap fetching admin password from Secret Manager at runtime.
    - Inputs: project_id, region, zone, subnet_self_link, machine_type, image, hostname, domain, realm, static_ip, service_account_email, startup cloud-init.
    - Outputs: instance details, fqdn, internal_ip.
  - `filestore/`
    - Creates `google_filestore_instance` with tier/capacity; two exports (`/export/home`, `/export/shared`) with allowed CIDRs.
    - Inputs: project_id, region, network, reserved_ip_range_name (or auto), tier, capacity_tb, allowed_cidrs (min include `subnet-workloads`).
    - Outputs: ip_address, export_paths.
  - `instance_template_workstation/`
    - Creates `google_compute_instance_template` with startup script installing baseline, Ops Agent, ansible marker; Shielded VM; network interface to workloads subnet; `service_account` for OTP-only secret access.
    - Inputs: machine_type, image, network_tags, subnet_self_link, service_account_email, startup_script.
    - Outputs: instance_template self_link.
  - `mig_workstation/`
    - Creates `google_compute_health_check` (TCP 22), `google_compute_instance_group_manager` and autoscaler.
    - Inputs: name, region or zonal, instance_template, target_size, min/max, cpu_target_utilization, health_check, named_ports (optional).
    - Outputs: MIG name, instances (data source), target_size.
  - `dns_records/`
    - Adds A records into existing private zone for `freeipa` and optionally `nfs` endpoint.
    - Inputs: zone_name, records = [{ name, type, ttl, rrdatas }].
    - Outputs: record set names.

- `terraform/envs/dev/phase1.tf`:
  - Declares and wires modules above using outputs from Phase 0 (`phase_1_inputs` and module references).
  - Adds three instance SAs via existing `iam_service_accounts` variable map or separate module call.
  - Adds secret-level IAM bindings to permit `sa-freeipa` and `sa-workstation` to access minimal secrets.

- `terraform/envs/dev/variables.phase1.tf`:
  - Variables for images, machine types, zones, Filestore tier/capacity, MIG sizes, realm/domain, hostnames, tags.
  - Example keys:
    - `bastion_machine_type`, `freeipa_machine_type`, `workstation_machine_type`
    - `bastion_zone`, `freeipa_zone`, `workstation_zones`
    - `filestore_tier`, `filestore_capacity_tb`, `filestore_allowed_cidrs`
    - `workstation_pool = { name, target_size, min, max, cpu_target }`
    - `domain = "corp.internal"`, `realm = "CORP.INTERNAL"`, `freeipa_hostname = "ipa"`, `bastion_hostname = "bastion"`, `filestore_name = "fs-nfs"`

- Networking/firewall alignment:
  - Already present:
    - IAP to bastion: allow 22 to tag `bastion`.
    - bastion to workers: allow 22 from tag `bastion` to `worker`.
    - FreeIPA ports to tag `freeipa` from services+workloads; OK.
  - Add if needed:
    - Egress allow from subnets to NAT (already via subnet config + NAT).
    - Optional: IAP to FreeIPA HTTPS 443 for admin UI; not required if using bastion socks/ssh port forward. We’ll keep minimal and use bastion tunnel if needed.

- Shielded VM:
  - Enable `shielded_instance_config { enable_secure_boot = true, vtpm = true, integrity_monitoring = true }` on all instance resources/templates.

- Secret access pattern (no Terraform reads):
  - VM startup scripts fetch secrets at runtime:
    - Get token: `curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/service-accounts/default/token`
    - Call Secret Manager `.../versions/latest:access`.
  - IPA server uses admin password for initialization; workstations use OTP during Ansible client join.

### 4) Ansible high-level structure
- New tree:
  - `ansible/inventories/dev/hosts.ini`
    - Groups: `bastion`, `freeipa`, `workstations`. Bastion reachable via IAP; workstations reachable via ProxyJump bastion.
  - `ansible/playbooks/`
    - `bastion.yml`: apply `common-base`, optional admin tooling.
    - `freeipa.yml`: `common-base`, `freeipa-server`.
    - `workstation.yml`: `common-base`, `nfs-client`, `freeipa-client`, `panel-code-server`, `panel-jupyterlab`.
  - `ansible/roles/`
    - `common-base/`:
      - Install: python3, pip, git, tmux, htop, unzip, curl, jq, terraform, gcloud CLI repo, google-ops-agent; harden SSH (no root login, PasswordAuthentication no).
    - `nfs-client/`:
      - Install `nfs-common` and `autofs`; configure autofs maps:
        - `/etc/auto.master.d/home.autofs` → `/home /etc/auto.home --timeout=600`
        - `/etc/auto.home` with: `* -fstype=nfs4,rw,nosuid,hard,intr <filestore_ip>:/export/home/&`
        - `/etc/auto.master.d/shared.autofs` → `/shared /etc/auto.shared --timeout=600`
        - `/etc/auto.shared` with keys `data`, `projects`, `models` mapping to `<filestore_ip>:/export/shared/<key>`
      - Enable and restart autofs.
    - `freeipa-server/`:
      - Ensure packages, configure hostname/FQDN, time sync, firewalld (if RHEL), `ipa-server-install` non-interactive with realm/domain, enable Kerberos/LDAP/HTTPS.
      - Optionally configure DNS integration off (Cloud DNS remains authoritative); ensure A record exists (Terraform).
    - `freeipa-client/`:
      - Fetch OTP (or provided via extra var), `ipa-client-install` non-interactive, configure sudo via IPA groups, enable `pam_mkhomedir.so` to auto-create user dirs (even though homes mount via NFS).
    - `panel-code-server/`:
      - Install code-server from official repo; create user systemd unit binding to `127.0.0.1:8080`, auth disabled; enable linger: `loginctl enable-linger <user>`.
    - `panel-jupyterlab/`:
      - Install `pipx` and `jupyterlab`; user systemd unit at `127.0.0.1:8888`, token/password disabled; enable linger.

- Connection strategy:
  - Ansible config uses `ansible_ssh_common_args` with `ProxyJump bastion` for workstations.
  - Bastion host uses `gcloud compute ssh --tunnel-through-iap` or standard SSH with IAP TCP forwarding via gcloud-proxy; for automation, prefer plain SSH if `IAP TCP forwarding` is transparently handled by `gcloud`. For playbooks, we can run from bastion to avoid local IAP complexity in CI; locally, provide scripts to open tunnels.

### 5) Scripts
- `scripts/broker_select_vm.sh`
  - Lists MIG instances via `gcloud compute instance-groups managed list-instances`, filters RUNNING, optionally get CPU via Ops API or random pick; returns chosen instance name; runs SSH through bastion with ProxyJump.
- `scripts/iap_tunnel_code.sh`
  - Selects a workstation (via broker), then starts SSH tunnel: local → IAP to bastion → ProxyJump to workstation → remote localhost:8080 forwarded to local 8080. Prints “Open http://localhost:8080”.
- `scripts/iap_tunnel_jupyter.sh`
  - Same as above but for 8888.

### 6) Day-2 operations (concise procedures)
- Scaling:
  - Adjust MIG min/target/max and autoscaler threshold in Terraform; apply.
- Patching:
  - Use Ansible `common-base` with unattended-upgrades (Ubuntu) enabled; schedule window; rolling restart via MIG if needed.
- FreeIPA:
  - Backups: regular `ipa-backup`; snapshot disk as needed; monitor Kerberos/LDAP services via Ops Agent.
- User lifecycle:
  - Manage users/groups in FreeIPA; NFS homes are central; sudo via IPA groups maps to workstation policies.
- Monitoring:
  - Ops Agent on all VMs streams logs/metrics to Cloud Logging/Monitoring; set alerts for CPU saturation on MIG, NFS latency, FreeIPA service availability.
- Access:
  - Maintain IAM bindings for IAP TCP tunneling to bastion; rotate OTP secret; audit SSH via Cloud Audit Logs + OS Login if enabled.
- NFS:
  - Watch Filestore capacity/IO; upgrade tier/capacity with zero/low downtime via Terraform.

### 7) Repository additions (files and content scope)
- Terraform:
  - `terraform/modules/{bastion,freeipa_vm,filestore,instance_template_workstation,mig_workstation,dns_records}/` (module scaffolds and README).
  - `terraform/envs/dev/phase1.tf` (wire-in resources and IAM bindings).
  - `terraform/envs/dev/variables.phase1.tf` (Phase 1 vars).
- Ansible:
  - `ansible/inventories/dev/hosts.ini`
  - `ansible/playbooks/{bastion.yml,freeipa.yml,workstation.yml}`
  - `ansible/roles/{common-base,freeipa-server,freeipa-client,nfs-client,panel-code-server,panel-jupyterlab}/` with tasks/templates/handlers/vars as needed.
- Scripts:
  - `scripts/broker_select_vm.sh`, `scripts/iap_tunnel_code.sh`, `scripts/iap_tunnel_jupyter.sh`
- Docs:
  - `docs/phase1_arch_diagram.mmd` (Mermaid: Bastion, FreeIPA, Filestore, MIG, flows)
  - `docs/phase1_access_flows.mmd` (SSH and panel sequences)
  - Update `README.md` with Phase 1 deploy steps, tunnels, troubleshooting.

### 8) Acceptance mapping
- Terraform apply:
  - Creates bastion, FreeIPA with static internal IP, Filestore with exports, instance template + MIG, health checks/autoscaler, DNS records in private zone, and any required firewall updates.
- After Ansible:
  - Workstations enrolled to FreeIPA; NFS homes and `/shared` mounted via autofs; Ops Agent running everywhere; code-server and JupyterLab running as user systemd services bound to localhost.
- From local:
  - SSH bastion via IAP works.
  - `iap_tunnel_code.sh` and `iap_tunnel_jupyter.sh` open corresponding panels in browser at `http://localhost:8080` and `http://localhost:8888`.

### 9) Key variable defaults (proposal)
- Images: Ubuntu 22.04 LTS
- Machine types: bastion `e2-small`; freeipa `e2-standard-4`; workstation `e2-standard-4`
- MIG: min=0, target=3, max=10, cpu_target_utilization=0.6
- Filestore: Enterprise, 2–5 TB to start; allowed CIDRs: `subnet-workloads` (and optionally `subnet-services`)
- Domain/realm: `corp.internal` / `CORP.INTERNAL`
- Hostnames: `bastion`, `ipa`, `fs-nfs`, `ws-<hash>`

### 10) Security notes
- No secrets in Terraform state. All secrets fetched at runtime from VMs with narrowly scoped SA access to specific secrets.
- Shielded VM enabled across fleet.
- Services bind to 127.0.0.1; access only via SSH port-forwarding chain through IAP bastion.
- IAM least privilege for TF SA tightened post-bootstrap as documented; add only `roles/compute.*`, `roles/file.editor`, and `roles/dns.admin` needed for Phase 1.

If you approve, I’ll switch to Act mode and scaffold all Terraform modules, env wiring, Ansible roles, scripts, and docs, then run lint checks and ensure a clean plan. 

- I will:
  - Create module scaffolds and env Phase 1 files wired to existing Phase 0 modules.
  - Implement startup/cloud-init scripts and shielded configs.
  - Add secret-level IAM bindings for `sa-freeipa` and `sa-workstation`.
  - Add Ansible roles with autofs maps and user services for code-server/JupyterLab.
  - Add the scripts and diagrams.
  - Update README with Phase 1 steps.

Summary
- Proposed a concrete VM-based Phase 1 architecture: bastion, FreeIPA, Filestore, MIG workstations, IAP-only access, NFS homes.
- Detailed Terraform modules and env wiring, secret access pattern, Shielded VM, firewall/IAM alignment.
- Outlined Ansible roles for base hardening, FreeIPA server/client, autofs, and per-user panel services.
- Described scripts for VM selection and tunnels and docs to include.

---

**User**

Feedback on current plan:

✅ Security model: no public IPs, IAP SSH, Shielded VMs, least-priv SAs per role, Secret Manager fetch at runtime — keep this.

✅ Identity: FreeIPA central auth + sudo groups — correct.

✅ Storage: Filestore /export/home & /export/shared with autofs — correct.

✅ MIG scaling: instance template, CPU-based autoscale, health check on SSH — correct.

⚠ Ansible connection path: must run from bastion or configure ProxyJump over IAP in inventory.

⚠ DNS: Use Cloud DNS authoritative; disable IPA DNS; add _kerberos and _ldap SRV records in private zone.

⚠ Secret scope: bind IAM per secret to FreeIPA/workstation SAs.

⚠ autofs: enable pam_mkhomedir so NFS home is seeded on first login.

⚠ Per-user services: code-server & Jupyter systemd units should be in /etc/skel so new users inherit them; enable linger.

⚠ Firewall: verify NFS (2049) and Kerberos/LDAP ports are explicitly allowed; deny-all remains first.

Guidance — what to produce next:

Terraform modules under terraform/modules/:

bastion, freeipa_vm, filestore, instance_template_workstation, mig_workstation, dns_records.

All with Shielded VM config, no public IP, metadata startup script hooks, and outputs for IP/DNS.

Env wiring in terraform/envs/dev/phase1.tf:

Instantiate modules, pass outputs from Phase-0 (subnets, network, project, secret names).

Create SAs for bastion, FreeIPA, workstations; bind them to secrets.

Create DNS SRV records for Kerberos/LDAP pointing to FreeIPA.

Variables in terraform/envs/dev/variables.phase1.tf:

machine types, zones, MIG sizes, Filestore tier/capacity, realm/domain, hostnames, tags.

Ansible in ansible/:

Inventory grouping (bastion, freeipa, workstations) with ProxyJump config for workers.

Roles: common-base, freeipa-server, freeipa-client, nfs-client, panel-code-server, panel-jupyterlab.

Ensure autofs and pam_mkhomedir are configured.

Place panel unit files in /etc/skel/.config/systemd/user/ and enable linger.

Scripts in scripts/:

broker_select_vm.sh, iap_tunnel_code.sh, iap_tunnel_jupyter.sh — pick MIG instance, tunnel to panel ports.

Docs in docs/:

phase1_arch_diagram.mmd and phase1_access_flows.mmd (Mermaid).

Update README.md with Phase-1 apply steps, tunnel usage, troubleshooting.

Execution style:

Keep IAM least privilege: only grant needed roles to each SA; bind Secret Manager access at secret level.

Do not include any secrets or secret values in Terraform code; only names and IAM bindings.

Assume OS = Ubuntu 22.04 LTS for all VMs.

Keep configs reproducible; parametrize zones, sizes, and realm/domain in variables.

Ensure all firewall rules are explicit and minimal.



---

**Cursor**

# Mode: PLAN

Quick status: Incorporated your feedback into the Phase 1 deliverables. Below is the tightened implementation plan reflecting DNS, Ansible/IAP, SRV records, secret scoping, mkhomedir, per-user services via /etc/skel, and explicit firewall coverage.

### What we’ll produce next (aligned to your guidance)

- Terraform modules (all Shielded VM, no public IPs, metadata hooks, useful outputs):
  - `terraform/modules/bastion/`
    - Ubuntu 22.04; tags `["vm-managed","bastion"]`; startup installs Ops Agent + ansible marker.
    - SA: `sa-bastion` with logging/monitoring only.
  - `terraform/modules/freeipa_vm/`
    - Static internal IP in `subnet-services`, tags `["vm-managed","freeipa"]`; cloud-init bootstraps IPA with admin password fetched at runtime from Secret Manager.
    - DNS: we disable IPA DNS; Cloud DNS remains authoritative.
    - SA: `sa-freeipa` bound only to `freeipa_admin_password`.
  - `terraform/modules/filestore/`
    - Enterprise/High Scale; exports `/export/home`, `/export/shared`; export rules restricted to `subnet-workloads` (optionally add `subnet-services`).
    - Output: IP and exports.
  - `terraform/modules/instance_template_workstation/`
    - Ubuntu 22.04; tags `["vm-managed","worker","workstation"]`; baseline tooling + Ops Agent + ansible marker.
    - SA: `sa-workstation` bound only to `ipa_enrollment_otp`.
  - `terraform/modules/mig_workstation/`
    - MIG with CPU autoscaler; health check on TCP/22; target/min/max via vars.
  - `terraform/modules/dns_records/`
    - A records: `ipa.corp.internal.` → FreeIPA IP; `nfs.corp.internal.` → Filestore IP.
    - SRV records: `_kerberos._udp`, `_kerberos._tcp` (port 88), `_ldap._tcp` (port 389) pointing to `ipa.corp.internal.`

- Env wiring
  - `terraform/envs/dev/phase1.tf`
    - Instantiate modules using Phase 0 outputs (`module.vpc`, `module.dns`, `module.secrets`, `module.kms`, subnets).
    - Create SAs: `sa-bastion`, `sa-freeipa`, `sa-workstation` with minimal roles:
      - `sa-bastion`: `roles/logging.logWriter`, `roles/monitoring.metricWriter`.
      - `sa-freeipa`: above + secret accessor on `freeipa_admin_password`.
      - `sa-workstation`: above + secret accessor on `ipa_enrollment_otp`.
    - Secret-level IAM bindings (google_secret_manager_secret_iam_member) per secret per SA.
    - DNS SRV and A records via `dns_records` module.
    - Firewall verification and additions:
      - Keep deny-all ingress first (target tag `vm-managed`).
      - Confirm FreeIPA ports allow from services/workloads (already present).
      - Add health check allow to workers on port 22 from Google HC ranges `130.211.0.0/22`, `35.191.0.0/16` with target tag `worker`.
      - IAP SSH to bastion rule already present.
      - NFS 2049 is served by Filestore (stateful firewall; no extra rule required for clients).
  - `terraform/envs/dev/variables.phase1.tf`
    - Machine types, zones, MIG sizing, Filestore tier/capacity, realm/domain, hostnames, tags.

- Ansible
  - Inventory and connection
    - `ansible/inventories/dev/hosts.ini`: groups `bastion`, `freeipa`, `workstations`.
    - Preferred: run Ansible from bastion to avoid IAP ProxyCommand complexity; include ProxyJump inventory config option for local runs (documented).
  - Playbooks
    - `playbooks/bastion.yml`: `common-base`.
    - `playbooks/freeipa.yml`: `common-base`, `freeipa-server` (IPA DNS disabled).
    - `playbooks/workstation.yml`: `common-base`, `nfs-client`, `freeipa-client`, `panel-code-server`, `panel-jupyterlab`.
  - Roles
    - `common-base`: baseline tools, SSH hardening (no root login, no password auth), google-ops-agent.
    - `nfs-client`: install `nfs-common`, `autofs`; autofs maps:
      - `/home/%(USER)s` → `<filestore_ip>:/export/home/%(USER)s`
      - `/shared/{data,projects,models}` → `<filestore_ip>:/export/shared/<name>`
    - `freeipa-server`: unattended `ipa-server-install` with realm/domain, Kerberos/LDAP/HTTPS; IPA DNS disabled.
    - `freeipa-client`: unattended `ipa-client-install` using OTP from Secret Manager; sudo via IPA groups; enable `pam_mkhomedir`.
    - `panel-code-server`: install code-server; user systemd unit bound to 127.0.0.1:8080; place unit in `/etc/skel/.config/systemd/user/`; linger enable strategy (see below).
    - `panel-jupyterlab`: install pipx + jupyterlab; user systemd unit bound to 127.0.0.1:8888; place unit in `/etc/skel/.config/systemd/user/`; linger enable strategy.
  - Linger + mkhomedir
    - Ensure `pam_mkhomedir.so` enabled so `/etc/skel` is copied into NFS home on first login (seeds user units).
    - Add `pam_exec.so` hook with root-owned script to run `loginctl enable-linger "$PAM_USER"` on first login to persist user services.

- Scripts
  - `scripts/broker_select_vm.sh`: list MIG instances; pick least-loaded (fallback random) via `gcloud`; return name and zone.
  - `scripts/iap_tunnel_code.sh`: broker a VM, open IAP tunnel chain to forward workstation localhost:8080 → local 8080; print URL.
  - `scripts/iap_tunnel_jupyter.sh`: same for port 8888.

- Docs
  - `docs/phase1_arch_diagram.mmd`: Bastion, FreeIPA, Filestore, MIG; IAP SSH and panel flows.
  - `docs/phase1_access_flows.mmd`: SSH chain and IDE tunnel sequences.
  - Update `README.md` (Phase 1 section): apply steps, running Ansible from bastion, tunnel usage, troubleshooting.

- Defaults
  - OS: Ubuntu 22.04 LTS everywhere.
  - Types: bastion `e2-small`; freeipa `e2-standard-4`; workstation `e2-standard-4`.
  - MIG: min 0, target 3, max 10, CPU target 0.6.
  - Filestore: Enterprise, 2–5 TB; allowed: workloads CIDR (+ optional services CIDR).
  - Realm/Domain: `CORP.INTERNAL` / `corp.internal`.
  - Hostnames: `bastion`, `ipa`, `nfs`.

- Acceptance hooks
  - Terraform apply brings up all resources and DNS records; firewall rules explicit with deny-all precedence.
  - Ansible enrolls workers to FreeIPA, enables autofs + pam_mkhomedir, Ops Agent running, user services deployed from `/etc/skel` and linger enabled.
  - Local: SSH to bastion via IAP; tunnels open to IDEs at `http://localhost:8080` and `http://localhost:8888`.

Requesting approval to proceed to ACT and implement the files above.

Summary
- Tightened plan: Cloud DNS authoritative + SRV, Ansible from bastion or ProxyJump, secret IAM per secret, explicit HC firewall, autofs + pam_mkhomedir, user units seeded via `/etc/skel` + PAM linger.
- Ready to scaffold Terraform modules, env wiring, Ansible roles, scripts, and docs per your checklist.

---

**User**

ACT

---

**Cursor**

I’m going to scaffold the Phase 1 Terraform modules, environment wiring, Ansible roles/playbooks, scripts, and diagrams as agreed. I’ll add Shielded VM configurations, no-public-IP NICs, secret-level IAM bindings, Cloud DNS A/SRV records, and minimal Ansible role implementations including autofs and pam_mkhomedir, and panel user services seeded via /etc/skel. Then I’ll update the README with Phase 1 instructions.

```plaintext
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

data "google_compute_image" "ubuntu" {
  family  = var.image_family
  project = var.image_project
}

resource "google_compute_instance" "bastion" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone

  tags = concat(["vm-managed", "bastion"], var.additional_tags)

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = var.boot_disk_gb
      type  = var.boot_disk_type
    }
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  network_interface {
    subnetwork = var.subnetwork_self_link
    # No public IP
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = merge(var.metadata, {
    enable-oslogin = var.enable_os_login ? "TRUE" : "FALSE"
  })

  metadata_startup_script = var.startup_script

  labels = merge({
    role        = "bastion",
    environment = var.environment
  }, var.labels)
}


```

```plaintext
variable "name" {
  description = "Instance name"
  type        = string
}

variable "zone" {
  description = "Compute zone"
  type        = string
}

variable "subnetwork_self_link" {
  description = "Self link of the subnetwork to attach"
  type        = string
}

variable "machine_type" {
  description = "Machine type for the bastion"
  type        = string
}

variable "image_family" {
  description = "Image family for Ubuntu"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "image_project" {
  description = "Project hosting the image family"
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "boot_disk_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}

variable "boot_disk_type" {
  description = "Boot disk type"
  type        = string
  default     = "pd-balanced"
}

variable "service_account_email" {
  description = "Service account email for the instance"
  type        = string
}

variable "startup_script" {
  description = "Metadata startup script"
  type        = string
  default     = <<-EOT
#!/usr/bin/env bash
set -euo pipefail
curl -sS https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh | bash -s -- --also-install
touch /var/tmp/ansible_ready
EOT
}

variable "enable_os_login" {
  description = "Enable OS Login integration"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Additional labels"
  type        = map(string)
  default     = {}
}

variable "additional_tags" {
  description = "Additional network tags"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "dev"
}


```

```plaintext
output "instance_name" {
  description = "Bastion instance name"
  value       = google_compute_instance.bastion.name
}

output "internal_ip" {
  description = "Internal IP address of the bastion"
  value       = google_compute_instance.bastion.network_interface[0].network_ip
}

output "self_link" {
  description = "Self link of the bastion instance"
  value       = google_compute_instance.bastion.self_link
}


```

```markdown
# bastion module

Creates an Ubuntu 22.04 bastion host with IAP-only SSH, no public IP, Shielded VM, Ops Agent installed, and an Ansible-ready marker.

Inputs: name, zone, subnetwork_self_link, machine_type, service_account_email, optional startup_script.


```

```plaintext
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

data "google_compute_image" "ubuntu" {
  family  = var.image_family
  project = var.image_project
}

resource "google_compute_address" "ip_internal" {
  name         = "${var.name}-ip"
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork_self_link
  region       = var.region
}

resource "google_compute_instance" "freeipa" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone

  tags = concat(["vm-managed", "freeipa"], var.additional_tags)

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = var.boot_disk_gb
      type  = var.boot_disk_type
    }
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  network_interface {
    subnetwork = var.subnetwork_self_link
    network_ip = google_compute_address.ip_internal.address
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = merge(var.metadata, {
    enable-oslogin = var.enable_os_login ? "TRUE" : "FALSE"
    hostname       = "${var.hostname}.${var.domain}"
  })

  # Use cloud-init to prepare the system; IPA install handled via Ansible to avoid secrets in state
  metadata_startup_script = var.startup_script

  labels = merge({
    role        = "freeipa",
    environment = var.environment
  }, var.labels)
}


```

```plaintext
variable "name" {
  description = "Instance name"
  type        = string
}

variable "hostname" {
  description = "Host shortname (will be combined with domain)"
  type        = string
}

variable "domain" {
  description = "DNS domain (e.g., corp.internal)"
  type        = string
}

variable "realm" {
  description = "Kerberos realm (e.g., CORP.INTERNAL)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "zone" {
  description = "Compute zone"
  type        = string
}

variable "subnetwork_self_link" {
  description = "Self link of the subnetwork"
  type        = string
}

variable "machine_type" {
  description = "Machine type"
  type        = string
}

variable "image_family" {
  description = "Image family for Ubuntu"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "image_project" {
  description = "Project hosting the image family"
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "boot_disk_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

variable "boot_disk_type" {
  description = "Boot disk type"
  type        = string
  default     = "pd-balanced"
}

variable "service_account_email" {
  description = "Service account email"
  type        = string
}

variable "startup_script" {
  description = "Metadata startup script"
  type        = string
  default     = <<-EOT
#!/usr/bin/env bash
set -euo pipefail
curl -sS https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh | bash -s -- --also-install
apt-get update -y
apt-get install -y chrony
touch /var/tmp/ansible_ready
EOT
}

variable "enable_os_login" {
  description = "Enable OS Login"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Additional labels"
  type        = map(string)
  default     = {}
}

variable "additional_tags" {
  description = "Additional network tags"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "dev"
}

variable "metadata" {
  description = "Additional instance metadata"
  type        = map(string)
  default     = {}
}


```

```plaintext
output "instance_name" {
  description = "FreeIPA instance name"
  value       = google_compute_instance.freeipa.name
}

output "internal_ip" {
  description = "Internal IP address"
  value       = google_compute_instance.freeipa.network_interface[0].network_ip
}

output "fqdn" {
  description = "FQDN of the FreeIPA server"
  value       = "${var.hostname}.${var.domain}"
}

output "self_link" {
  description = "Self link of the FreeIPA instance"
  value       = google_compute_instance.freeipa.self_link
}


```

```plaintext
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_filestore_instance" "nfs" {
  name     = var.name
  project  = var.project_id
  location = var.location
  tier     = var.tier

  file_shares {
    name       = "home"
    capacity_gb = var.capacity_home_gb
    nfs_export_options {
      ip_ranges = var.allowed_cidrs
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }

  file_shares {
    name       = "shared"
    capacity_gb = var.capacity_shared_gb
    nfs_export_options {
      ip_ranges = var.allowed_cidrs
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }

  networks {
    network = var.vpc_name
    modes   = ["MODE_IPV4"]
    reserved_ip_range = var.reserved_ip_range
  }
}


```

```plaintext
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Filestore location (region or zone, e.g., us-central1)"
  type        = string
}

variable "name" {
  description = "Filestore instance name"
  type        = string
}

variable "tier" {
  description = "Filestore tier (ENTERPRISE or HIGH_SCALE_SSD)"
  type        = string
  default     = "ENTERPRISE"
}

variable "capacity_home_gb" {
  description = "Capacity for home export (GB)"
  type        = number
}

variable "capacity_shared_gb" {
  description = "Capacity for shared export (GB)"
  type        = number
}

variable "vpc_name" {
  description = "VPC network name"
  type        = string
}

variable "reserved_ip_range" {
  description = "Reserved IP range name for Filestore"
  type        = string
}

variable "allowed_cidrs" {
  description = "Allowed client CIDRs for NFS"
  type        = list(string)
}


```

```plaintext
output "ip_address" {
  description = "Filestore IP address"
  value       = google_filestore_instance.nfs.networks[0].ip_addresses[0]
}

output "exports" {
  description = "Export paths"
  value = {
    home   = "/export/home"
    shared = "/export/shared"
  }
}


```

```plaintext
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

data "google_compute_image" "ubuntu" {
  family  = var.image_family
  project = var.image_project
}

resource "google_compute_instance_template" "tpl" {
  name_prefix  = var.name_prefix
  machine_type = var.machine_type

  tags = concat(["vm-managed", "worker", "workstation"], var.additional_tags)

  disk {
    source_image = data.google_compute_image.ubuntu.self_link
    disk_size_gb = var.boot_disk_gb
    disk_type    = var.boot_disk_type
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = var.subnetwork_self_link
    # No access_config block = no public IP
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = merge(var.metadata, {
    enable-oslogin = var.enable_os_login ? "TRUE" : "FALSE"
  })

  metadata_startup_script = var.startup_script

  labels = merge({
    role        = "workstation",
    environment = var.environment
  }, var.labels)
}

output "instance_template_self_link" {
  value = google_compute_instance_template.tpl.self_link
}


```

```plaintext
variable "name_prefix" {
  description = "Name prefix for the instance template"
  type        = string
}

variable "machine_type" {
  description = "Machine type"
  type        = string
}

variable "subnetwork_self_link" {
  description = "Subnetwork self link"
  type        = string
}

variable "service_account_email" {
  description = "Service account email"
  type        = string
}

variable "image_family" {
  description = "Image family for Ubuntu"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "image_project" {
  description = "Project hosting the image family"
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "boot_disk_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

variable "boot_disk_type" {
  description = "Boot disk type"
  type        = string
  default     = "pd-balanced"
}

variable "startup_script" {
  description = "Startup script"
  type        = string
  default     = <<-EOT
#!/usr/bin/env bash
set -euo pipefail
curl -sS https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh | bash -s -- --also-install
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip git tmux htop unzip curl jq
touch /var/tmp/ansible_ready
EOT
}

variable "enable_os_login" {
  description = "Enable OS Login"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Additional labels"
  type        = map(string)
  default     = {}
}

variable "additional_tags" {
  description = "Additional network tags"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "dev"
}

variable "metadata" {
  description = "Additional metadata"
  type        = map(string)
  default     = {}
}


```

```plaintext
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_compute_health_check" "ssh" {
  name               = "${var.name}-ssh-hc"
  check_interval_sec = 10
  timeout_sec        = 5
  tcp_health_check {
    port = 22
  }
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

resource "google_compute_region_instance_group_manager" "mig" {
  name               = var.name
  base_instance_name = var.name
  region             = var.region
  distribution_policy_zones = var.zones

  version {
    instance_template = var.instance_template_self_link
  }

  target_size = var.target_size

  auto_healing_policies {
    health_check      = google_compute_health_check.ssh.self_link
    initial_delay_sec = 60
  }
}

resource "google_compute_region_autoscaler" "autoscaler" {
  name   = "${var.name}-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.mig.self_link

  autoscaling_policy {
    min_replicas             = var.min_replicas
    max_replicas             = var.max_replicas
    cooldown_period          = 60
    cpu_utilization {
      target = var.cpu_target_utilization
    }
  }
}

output "mig_name" {
  value = google_compute_region_instance_group_manager.mig.name
}


```

```plaintext
variable "name" {
  description = "MIG name"
  type        = string
}

variable "region" {
  description = "Region for the regional MIG"
  type        = string
}

variable "zones" {
  description = "List of zones for distribution policy"
  type        = list(string)
}

variable "instance_template_self_link" {
  description = "Instance template self link"
  type        = string
}

variable "target_size" {
  description = "Target size"
  type        = number
}

variable "min_replicas" {
  description = "Min replicas"
  type        = number
}

variable "max_replicas" {
  description = "Max replicas"
  type        = number
}

variable "cpu_target_utilization" {
  description = "CPU target utilization for autoscaler"
  type        = number
  default     = 0.6
}


```

```plaintext
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_dns_record_set" "a_records" {
  for_each = { for r in var.a_records : r.name => r }

  managed_zone = var.zone_name
  name         = each.value.name
  type         = "A"
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas
}

resource "google_dns_record_set" "srv_records" {
  for_each = { for r in var.srv_records : r.name => r }

  managed_zone = var.zone_name
  name         = each.value.name
  type         = "SRV"
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas
}


```

```plaintext
variable "zone_name" {
  description = "Private managed zone name"
  type        = string
}

variable "a_records" {
  description = "List of A records"
  type = list(object({
    name    = string
    ttl     = number
    rrdatas = list(string)
  }))
  default = []
}

variable "srv_records" {
  description = "List of SRV records"
  type = list(object({
    name    = string
    ttl     = number
    rrdatas = list(string)
  }))
  default = []
}


```

```plaintext
variable "zones" {
  description = "Zones used for Phase 1 resources"
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b"]
}

variable "bastion" {
  description = "Bastion configuration"
  type = object({
    name          = string
    zone          = string
    machine_type  = string
    additional_tags = optional(list(string), [])
  })
  default = {
    name         = "bastion"
    zone         = "us-central1-a"
    machine_type = "e2-small"
  }
}

variable "freeipa" {
  description = "FreeIPA configuration"
  type = object({
    name          = string
    hostname      = string
    domain        = string
    realm         = string
    zone          = string
    machine_type  = string
    additional_tags = optional(list(string), [])
  })
  default = {
    name         = "freeipa"
    hostname     = "ipa"
    domain       = "corp.internal"
    realm        = "CORP.INTERNAL"
    zone         = "us-central1-a"
    machine_type = "e2-standard-4"
  }
}

variable "workstation" {
  description = "Workstation pool configuration"
  type = object({
    name_prefix   = string
    machine_type  = string
    min_replicas  = number
    target_size   = number
    max_replicas  = number
    cpu_target    = number
    additional_tags = optional(list(string), [])
  })
  default = {
    name_prefix  = "ws"
    machine_type = "e2-standard-4"
    min_replicas = 0
    target_size  = 3
    max_replicas = 10
    cpu_target   = 0.6
  }
}

variable "filestore" {
  description = "Filestore configuration"
  type = object({
    name               = string
    tier               = string
    capacity_home_gb   = number
    capacity_shared_gb = number
    reserved_ip_range  = string
  })
  default = {
    name               = "fs-nfs"
    tier               = "ENTERPRISE"
    capacity_home_gb   = 2048
    capacity_shared_gb = 2048
    reserved_ip_range  = "filestore-reserved"
  }
}


```

```plaintext
locals {
  services_subnet_self_link  = module.vpc.subnets["services"].self_link
  workloads_subnet_self_link = module.vpc.subnets["workloads"].self_link
  workloads_cidr             = module.vpc.subnets["workloads"].cidr_range
  services_cidr              = module.vpc.subnets["services"].cidr_range
}

# Service accounts for Phase 1
module "phase1_service_accounts" {
  source     = "../../modules/iam_service_accounts"
  project_id = var.project_id

  service_accounts = {
    sa_bastion = {
      display_name = "Bastion Instance SA"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ]
    }
    sa_freeipa = {
      display_name = "FreeIPA Instance SA"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ]
    }
    sa_workstation = {
      display_name = "Workstation Instance SA"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ]
    }
  }
}

# Secret-level IAM bindings
resource "google_secret_manager_secret_iam_member" "freeipa_admin_secret_access" {
  secret_id = module.secrets.secret_ids["freeipa_admin_password"].name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.phase1_service_accounts.service_accounts["sa_freeipa"].email}"
}

resource "google_secret_manager_secret_iam_member" "ipa_enrollment_otp_access" {
  secret_id = module.secrets.secret_ids["ipa_enrollment_otp"].name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.phase1_service_accounts.service_accounts["sa_workstation"].email}"
}

# Bastion instance
module "bastion" {
  source               = "../../modules/bastion"
  name                 = var.bastion.name
  zone                 = var.bastion.zone
  subnetwork_self_link = local.services_subnet_self_link
  machine_type         = var.bastion.machine_type
  service_account_email = module.phase1_service_accounts.service_accounts["sa_bastion"].email
  additional_tags      = var.bastion.additional_tags
}

# FreeIPA VM
module "freeipa" {
  source               = "../../modules/freeipa_vm"
  name                 = var.freeipa.name
  hostname             = var.freeipa.hostname
  domain               = var.freeipa.domain
  realm                = var.freeipa.realm
  region               = var.region
  zone                 = var.freeipa.zone
  subnetwork_self_link = local.services_subnet_self_link
  machine_type         = var.freeipa.machine_type
  service_account_email = module.phase1_service_accounts.service_accounts["sa_freeipa"].email
  additional_tags      = var.freeipa.additional_tags
}

# Filestore NFS
module "filestore" {
  source              = "../../modules/filestore"
  project_id          = var.project_id
  location            = var.region
  name                = var.filestore.name
  tier                = var.filestore.tier
  capacity_home_gb    = var.filestore.capacity_home_gb
  capacity_shared_gb  = var.filestore.capacity_shared_gb
  vpc_name            = module.vpc.vpc_name
  reserved_ip_range   = var.filestore.reserved_ip_range
  allowed_cidrs       = [local.workloads_cidr, local.services_cidr]
}

# Workstation instance template
module "workstation_template" {
  source               = "../../modules/instance_template_workstation"
  name_prefix          = var.workstation.name_prefix
  machine_type         = var.workstation.machine_type
  subnetwork_self_link = local.workloads_subnet_self_link
  service_account_email = module.phase1_service_accounts.service_accounts["sa_workstation"].email
  additional_tags      = var.workstation.additional_tags
}

# Workstation MIG
module "workstation_mig" {
  source                      = "../../modules/mig_workstation"
  name                        = "${var.workstation.name_prefix}-mig"
  region                      = var.region
  zones                       = var.zones
  instance_template_self_link = module.workstation_template.instance_template_self_link
  target_size                 = var.workstation.target_size
  min_replicas                = var.workstation.min_replicas
  max_replicas                = var.workstation.max_replicas
  cpu_target_utilization      = var.workstation.cpu_target
}

# DNS records (A and SRV)
module "dns_records" {
  source    = "../../modules/dns_records"
  zone_name = module.dns.private_zones["corp_internal"].name

  a_records = [
    {
      name    = "ipa.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = [module.freeipa.internal_ip]
    },
    {
      name    = "nfs.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = [module.filestore.ip_address]
    }
  ]

  srv_records = [
    {
      name    = "_kerberos._udp.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = ["0 0 88 ipa.${var.freeipa.domain}."]
    },
    {
      name    = "_kerberos._tcp.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = ["0 0 88 ipa.${var.freeipa.domain}."]
    },
    {
      name    = "_ldap._tcp.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = ["0 0 389 ipa.${var.freeipa.domain}."]
    }
  ]
}

# Allow Google health checks to reach SSH on workers
resource "google_compute_firewall" "allow_hc_to_workers" {
  name    = "allow-hc-ssh-workers"
  network = module.vpc.vpc_name

  direction = "INGRESS"
  priority  = 1150

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["worker"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}


```

```ini
[bastion]
bastion ansible_host=bastion.corp.internal ansible_user=ubuntu

[freeipa]
ipa ansible_host=ipa.corp.internal ansible_user=ubuntu

[workstations]

[all:vars]
ansible_python_interpreter=/usr/bin/python3

# If running locally (not from bastion), you can set ProxyJump
# ansible_ssh_common_args='-o ProxyJump=ubuntu@bastion.corp.internal'

```

```yaml
---
- name: Configure bastion host
  hosts: bastion
  become: true
  roles:
    - role: common-base


```

```yaml
---
- name: Configure FreeIPA server
  hosts: freeipa
  become: true
  vars:
    ipa_domain: corp.internal
    ipa_realm: CORP.INTERNAL
    ipa_hostname: ipa
  roles:
    - role: common-base
    - role: freeipa-server


```

```yaml
---
- name: Configure workstation nodes
  hosts: workstations
  become: true
  vars:
    filestore_ip: "{{ lookup('env', 'FILESTORE_IP') | default('nfs.corp.internal', true) }}"
    ipa_domain: corp.internal
    ipa_realm: CORP.INTERNAL
  roles:
    - role: common-base
    - role: nfs-client
    - role: freeipa-client
    - role: panel-code-server
    - role: panel-jupyterlab


```

```yaml
---
- name: Ensure baseline packages are installed
  apt:
    name:
      - python3
      - python3-pip
      - git
      - tmux
      - htop
      - unzip
      - curl
      - jq
      - nfs-common
      - autofs
      - openssh-client
      - libpam-modules
    state: present
    update_cache: true

- name: Install Google Ops Agent
  shell: |
    curl -sS https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh | bash -s -- --also-install
  args:
    creates: /etc/google-cloud-ops-agent/config.yaml

- name: Harden SSH - disable root login and password auth
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: "^{{ item.key }}"
    line: "{{ item.key }} {{ item.value }}"
    state: present
    backrefs: yes
  loop:
    - { key: 'PermitRootLogin', value: 'no' }
    - { key: 'PasswordAuthentication', value: 'no' }
  notify: Restart ssh

- name: Ensure ansible_ready marker exists
  file:
    path: /var/tmp/ansible_ready
    state: touch


```

```yaml
---
- name: Restart ssh
  service:
    name: ssh
    state: restarted


```

```yaml
---
- name: Ensure autofs is installed
  apt:
    name: autofs
    state: present

- name: Configure auto.master.d for home and shared
  copy:
    dest: "/etc/auto.master.d/{{ item.name }}.autofs"
    content: "{{ item.content }}\n"
    mode: '0644'
  loop:
    - { name: 'home',   content: '/home /etc/auto.home --timeout=600' }
    - { name: 'shared', content: '/shared /etc/auto.shared --timeout=600' }

- name: Configure auto.home map for per-user homes
  copy:
    dest: /etc/auto.home
    mode: '0644'
    content: "* -fstype=nfs4,rw,nosuid,hard,intr {{ filestore_ip }}:/export/home/&\n"

- name: Configure auto.shared map for shared dirs
  copy:
    dest: /etc/auto.shared
    mode: '0644'
    content: |
      data    -fstype=nfs4,rw,nosuid,hard,intr {{ filestore_ip }}:/export/shared/data
      projects -fstype=nfs4,rw,nosuid,hard,intr {{ filestore_ip }}:/export/shared/projects
      models   -fstype=nfs4,rw,nosuid,hard,intr {{ filestore_ip }}:/export/shared/models

- name: Ensure /shared exists
  file:
    path: /shared
    state: directory
    mode: '0755'

- name: Restart autofs
  service:
    name: autofs
    state: restarted
    enabled: true


```

```yaml
---
- name: Install FreeIPA server packages
  apt:
    name:
      - freeipa-server
      - freeipa-server-dns
      - chrony
    state: present
    update_cache: true

- name: Ensure hostname and hosts entry
  hostname:
    name: "{{ ipa_hostname }}.{{ ipa_domain }}"

- name: Disable IPA DNS (Cloud DNS authoritative) - ensure install opts reflect
  set_fact:
    ipa_install_opts: "--realm {{ ipa_realm }} --domain {{ ipa_domain }} --hostname {{ ipa_hostname }}.{{ ipa_domain }} --no-dns --no-ntp -U"

- name: Fetch FreeIPA admin password from Secret Manager
  shell: |
    TOKEN=$(curl -s -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/service-accounts/default/token | jq -r .access_token)
    curl -s -H "Authorization: Bearer $TOKEN" "https://secretmanager.googleapis.com/v1/projects/{{ lookup('env','GOOGLE_PROJECT') }}/secrets/freeipa_admin_password/versions/latest:access" | jq -r .payload.data | base64 -d
  args:
    executable: /bin/bash
  register: ipa_admin_password
  changed_when: false

- name: Run ipa-server-install non-interactively if not already configured
  shell: |
    set -euo pipefail
    if ! systemctl is-active --quiet ipa; then
      echo "{{ ipa_admin_password.stdout }}" > /root/ipa_admin_password
      ipa-server-install {{ ipa_install_opts }} -a "{{ ipa_admin_password.stdout }}" -p "{{ ipa_admin_password.stdout }}"
    fi
  args:
    executable: /bin/bash


```

```yaml
---
- name: Install FreeIPA client packages
  apt:
    name:
      - freeipa-client
      - sssd
      - oddjob
      - oddjob-mkhomedir
      - chrony
    state: present
    update_cache: true

- name: Enable pam_mkhomedir
  lineinfile:
    path: /etc/pam.d/common-session
    line: 'session required pam_mkhomedir.so skel=/etc/skel/ umask=0022'
    insertafter: EOF

- name: Fetch IPA enrollment OTP from Secret Manager
  shell: |
    TOKEN=$(curl -s -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/service-accounts/default/token | jq -r .access_token)
    curl -s -H "Authorization: Bearer $TOKEN" "https://secretmanager.googleapis.com/v1/projects/{{ lookup('env','GOOGLE_PROJECT') }}/secrets/ipa_enrollment_otp/versions/latest:access" | jq -r .payload.data | base64 -d
  args:
    executable: /bin/bash
  register: ipa_enrollment_otp
  changed_when: false

- name: Join FreeIPA realm if not already joined
  shell: |
    set -euo pipefail
    if ! getent passwd admin >/dev/null 2>&1; then
      ipa-client-install -U --domain={{ ipa_domain }} --server=ipa.{{ ipa_domain }} --realm={{ ipa_realm }} --principal=enroll --password='{{ ipa_enrollment_otp.stdout }}' --mkhomedir
    fi
  args:
    executable: /bin/bash


```

```yaml
---
- name: Install code-server
  shell: |
    set -euo pipefail
    curl -fsSL https://code-server.dev/install.sh | sh
  args:
    creates: /usr/bin/code-server

- name: Ensure skel systemd user directory exists
  file:
    path: /etc/skel/.config/systemd/user
    state: directory
    mode: '0755'

- name: Install code-server user unit into skel
  copy:
    dest: /etc/skel/.config/systemd/user/code-server.service
    mode: '0644'
    content: |
      [Unit]
      Description=code-server
      After=network.target

      [Service]
      Type=simple
      ExecStart=/usr/bin/code-server --bind-addr 127.0.0.1:8080 --auth none
      Restart=always

      [Install]
      WantedBy=default.target

- name: Install PAM script to enable linger on first login
  copy:
    dest: /usr/local/sbin/enable_linger.sh
    mode: '0755'
    content: |
      #!/usr/bin/env bash
      if [ -n "$PAM_USER" ]; then
        loginctl enable-linger "$PAM_USER" || true
      fi

- name: Ensure PAM executes linger script on login
  lineinfile:
    path: /etc/pam.d/common-session
    line: 'session optional pam_exec.so seteuid /usr/local/sbin/enable_linger.sh'
    insertafter: EOF


```

```yaml
---
- name: Install pipx and jupyterlab
  apt:
    name:
      - pipx
      - python3-venv
    state: present
    update_cache: true

- name: Ensure pipx path configured
  shell: |
    set -euo pipefail
    su -s /bin/bash -c "pipx ensurepath" root
  args:
    creates: /root/.local/bin/pipx

- name: Install jupyterlab globally via pipx
  shell: |
    set -euo pipefail
    pipx install jupyterlab || true

- name: Ensure skel systemd user directory exists
  file:
    path: /etc/skel/.config/systemd/user
    state: directory
    mode: '0755'

- name: Install jupyterlab user unit into skel
  copy:
    dest: /etc/skel/.config/systemd/user/jupyterlab.service
    mode: '0644'
    content: |
      [Unit]
      Description=JupyterLab
      After=network.target

      [Service]
      Type=simple
      ExecStart=/usr/local/bin/jupyter lab --ip=127.0.0.1 --port=8888 --no-browser --NotebookApp.token='' --NotebookApp.password=''
      Restart=always

      [Install]
      WantedBy=default.target


```

```shellscript
#!/usr/bin/env bash
set -euo pipefail

# Select a workstation VM from the regional MIG (least-loaded placeholder -> random)

PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}
REGION=${REGION:-"us-central1"}
MIG_NAME=${MIG_NAME:-"ws-mig"}

mapfile -t INSTANCES < <(gcloud compute instance-groups managed list-instances "$MIG_NAME" --region "$REGION" --format='value(instance)')

if [[ ${#INSTANCES[@]} -eq 0 ]]; then
  echo "No instances found in MIG $MIG_NAME" >&2
  exit 1
fi

IDX=$(( RANDOM % ${#INSTANCES[@]} ))
echo "${INSTANCES[$IDX]}"


```

```shellscript
#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}
REGION=${REGION:-"us-central1"}
MIG_NAME=${MIG_NAME:-"ws-mig"}
BASTION_HOST=${BASTION_HOST:-"bastion.corp.internal"}
LOCAL_PORT=${LOCAL_PORT:-8080}

WS_INSTANCE=$("$(dirname "$0")/broker_select_vm.sh")
echo "Chosen workstation: $WS_INSTANCE"

echo "Starting IAP tunnel to $WS_INSTANCE (code-server)..."
gcloud compute ssh "ubuntu@${BASTION_HOST}" \
  --tunnel-through-iap \
  -- -N -L ${LOCAL_PORT}:127.0.0.1:8080 -J ubuntu@${BASTION_HOST} ubuntu@${WS_INSTANCE} &

echo "Open http://localhost:${LOCAL_PORT}"


```

```shellscript
#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}
REGION=${REGION:-"us-central1"}
MIG_NAME=${MIG_NAME:-"ws-mig"}
BASTION_HOST=${BASTION_HOST:-"bastion.corp.internal"}
LOCAL_PORT=${LOCAL_PORT:-8888}

WS_INSTANCE=$("$(dirname "$0")/broker_select_vm.sh")
echo "Chosen workstation: $WS_INSTANCE"

echo "Starting IAP tunnel to $WS_INSTANCE (JupyterLab)..."
gcloud compute ssh "ubuntu@${BASTION_HOST}" \
  --tunnel-through-iap \
  -- -N -L ${LOCAL_PORT}:127.0.0.1:8888 -J ubuntu@${BASTION_HOST} ubuntu@${WS_INSTANCE} &

echo "Open http://localhost:${LOCAL_PORT}"


```

```mermaid.radar
graph TB
  subgraph GCP["GCP Project"]
    VPC[VPC vpc-data-platform]
    SUB1["subnet-services 10.10.1.0/24"]
    SUB2["subnet-workloads 10.10.2.0/24"]
    NAT[Cloud NAT]
    DNS["Private DNS corp.internal"]
    BASTION[Bastion VM]
    IPA[FreeIPA VM]
    FS["Filestore (NFS)\n/export/home, /export/shared"]
    MIG["Workstation MIG\nInstance Template + Autoscaler"]
  end

  INTERNET[Internet]
  IAP[IAP TCP/SSH]

  VPC --> SUB1
  VPC --> SUB2
  VPC --> NAT
  VPC --> DNS

  SUB1 --> BASTION
  SUB1 --> IPA
  SUB2 --> MIG
  SUB2 --> FS

  IAP --> BASTION
  BASTION --> MIG
  MIG --> FS
  MIG --> IPA


```

```mermaid.radar
sequenceDiagram
  participant Dev as Developer
  participant IAP as IAP
  participant Bastion as Bastion VM
  participant WS as Workstation VM
  participant FS as Filestore
  participant IPA as FreeIPA

  Dev->>IAP: gcloud compute ssh --tunnel-through-iap bastion
  IAP->>Bastion: TCP 22
  Bastion->>WS: SSH ProxyJump (22)
  Dev->>Bastion: SSH local forward 8080/8888
  Bastion->>WS: Forward 127.0.0.1:8080/8888
  WS->>FS: NFS mount /export/home, /export/shared
  WS->>IPA: Kerberos/LDAP (88/389) auth


```

```plaintext
locals {
  services_subnet_self_link  = module.vpc.subnets["services"].self_link
  workloads_subnet_self_link = module.vpc.subnets["workloads"].self_link
  workloads_cidr             = module.vpc.subnets["workloads"].cidr_range
  services_cidr              = module.vpc.subnets["services"].cidr_range
}

# Service accounts for Phase 1
module "phase1_service_accounts" {
  source     = "../../modules/iam_service_accounts"
  project_id = var.project_id

  service_accounts = {
    sa_bastion = {
      display_name = "Bastion Instance SA"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ]
    }
    sa_freeipa = {
      display_name = "FreeIPA Instance SA"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ]
    }
    sa_workstation = {
      display_name = "Workstation Instance SA"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ]
    }
  }
}

# Secret-level IAM bindings
resource "google_secret_manager_secret_iam_member" "freeipa_admin_secret_access" {
  secret_id = module.secrets.secret_ids["freeipa_admin_password"]
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.phase1_service_accounts.service_accounts["sa_freeipa"].email}"
}

resource "google_secret_manager_secret_iam_member" "ipa_enrollment_otp_access" {
  secret_id = module.secrets.secret_ids["ipa_enrollment_otp"]
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.phase1_service_accounts.service_accounts["sa_workstation"].email}"
}

# Bastion instance
module "bastion" {
  source               = "../../modules/bastion"
  name                 = var.bastion.name
  zone                 = var.bastion.zone
  subnetwork_self_link = local.services_subnet_self_link
  machine_type         = var.bastion.machine_type
  service_account_email = module.phase1_service_accounts.service_accounts["sa_bastion"].email
  additional_tags      = var.bastion.additional_tags
}

# FreeIPA VM
module "freeipa" {
  source               = "../../modules/freeipa_vm"
  name                 = var.freeipa.name
  hostname             = var.freeipa.hostname
  domain               = var.freeipa.domain
  realm                = var.freeipa.realm
  region               = var.region
  zone                 = var.freeipa.zone
  subnetwork_self_link = local.services_subnet_self_link
  machine_type         = var.freeipa.machine_type
  service_account_email = module.phase1_service_accounts.service_accounts["sa_freeipa"].email
  additional_tags      = var.freeipa.additional_tags
}

# Filestore NFS
module "filestore" {
  source              = "../../modules/filestore"
  project_id          = var.project_id
  location            = var.region
  name                = var.filestore.name
  tier                = var.filestore.tier
  capacity_home_gb    = var.filestore.capacity_home_gb
  capacity_shared_gb  = var.filestore.capacity_shared_gb
  vpc_name            = module.vpc.vpc_name
  reserved_ip_range   = var.filestore.reserved_ip_range
  allowed_cidrs       = [local.workloads_cidr, local.services_cidr]
}

# Workstation instance template
module "workstation_template" {
  source               = "../../modules/instance_template_workstation"
  name_prefix          = var.workstation.name_prefix
  machine_type         = var.workstation.machine_type
  subnetwork_self_link = local.workloads_subnet_self_link
  service_account_email = module.phase1_service_accounts.service_accounts["sa_workstation"].email
  additional_tags      = var.workstation.additional_tags
}

# Workstation MIG
module "workstation_mig" {
  source                      = "../../modules/mig_workstation"
  name                        = "${var.workstation.name_prefix}-mig"
  region                      = var.region
  zones                       = var.zones
  instance_template_self_link = module.workstation_template.instance_template_self_link
  target_size                 = var.workstation.target_size
  min_replicas                = var.workstation.min_replicas
  max_replicas                = var.workstation.max_replicas
  cpu_target_utilization      = var.workstation.cpu_target
}

# DNS records (A and SRV)
module "dns_records" {
  source    = "../../modules/dns_records"
  zone_name = module.dns.private_zones["corp_internal"].name

  a_records = [
    {
      name    = "ipa.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = [module.freeipa.internal_ip]
    },
    {
      name    = "bastion.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = [module.bastion.internal_ip]
    },
    {
      name    = "nfs.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = [module.filestore.ip_address]
    }
  ]

  srv_records = [
    {
      name    = "_kerberos._udp.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = ["0 0 88 ipa.${var.freeipa.domain}."]
    },
    {
      name    = "_kerberos._tcp.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = ["0 0 88 ipa.${var.freeipa.domain}."]
    },
    {
      name    = "_ldap._tcp.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = ["0 0 389 ipa.${var.freeipa.domain}."]
    }
  ]
}

# Allow Google health checks to reach SSH on workers
resource "google_compute_firewall" "allow_hc_to_workers" {
  name    = "allow-hc-ssh-workers"
  network = module.vpc.vpc_name

  direction = "INGRESS"
  priority  = 1150

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["worker"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}



```

```plaintext
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_filestore_instance" "nfs" {
  name     = var.name
  project  = var.project_id
  location = var.location
  tier     = var.tier

  file_shares {
    name        = "export"
    capacity_gb = var.capacity_gb
    nfs_export_options {
      ip_ranges   = var.allowed_cidrs
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }

  networks {
    network = var.vpc_name
    modes   = ["MODE_IPV4"]
    reserved_ip_range = var.reserved_ip_range
  }
}



```

```plaintext
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Filestore location (region or zone, e.g., us-central1)"
  type        = string
}

variable "name" {
  description = "Filestore instance name"
  type        = string
}

variable "tier" {
  description = "Filestore tier (ENTERPRISE or HIGH_SCALE_SSD)"
  type        = string
  default     = "ENTERPRISE"
}

variable "capacity_gb" {
  description = "Total capacity (GB) for single file share"
  type        = number
}

variable "vpc_name" {
  description = "VPC network name"
  type        = string
}

variable "reserved_ip_range" {
  description = "Reserved IP range name for Filestore"
  type        = string
}

variable "allowed_cidrs" {
  description = "Allowed client CIDRs for NFS"
  type        = list(string)
}



```

```plaintext
output "ip_address" {
  description = "Filestore IP address"
  value       = google_filestore_instance.nfs.networks[0].ip_addresses[0]
}

output "exports" {
  description = "Export paths"
  value = {
    home   = "/export/home"
    shared = "/export/shared"
  }
}



```

```plaintext
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_filestore_instance" "nfs" {
  name     = var.name
  project  = var.project_id
  location = var.location
  tier     = var.tier

  file_shares {
    name         = "home"
    capacity_gb  = var.capacity_home_gb
    nfs_export_options {
      ip_ranges   = var.allowed_cidrs
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }

  file_shares {
    name         = "shared"
    capacity_gb  = var.capacity_shared_gb
    nfs_export_options {
      ip_ranges   = var.allowed_cidrs
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }

  networks {
    network = var.vpc_name
    modes   = ["MODE_IPV4"]
    reserved_ip_range = var.reserved_ip_range
  }
}



```

```plaintext
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Filestore location (region or zone, e.g., us-central1)"
  type        = string
}

variable "name" {
  description = "Filestore instance name"
  type        = string
}

variable "tier" {
  description = "Filestore tier (ENTERPRISE or HIGH_SCALE_SSD)"
  type        = string
  default     = "ENTERPRISE"
}

variable "capacity_home_gb" {
  description = "Capacity for home export (GB)"
  type        = number
}

variable "capacity_shared_gb" {
  description = "Capacity for shared export (GB)"
  type        = number
}

variable "vpc_name" {
  description = "VPC network name"
  type        = string
}

variable "reserved_ip_range" {
  description = "Reserved IP range name for Filestore"
  type        = string
}

variable "allowed_cidrs" {
  description = "Allowed client CIDRs for NFS"
  type        = list(string)
}



```

```plaintext
locals {
  services_subnet_self_link  = module.vpc.subnets["services"].self_link
  workloads_subnet_self_link = module.vpc.subnets["workloads"].self_link
  workloads_cidr             = module.vpc.subnets["workloads"].cidr_range
  services_cidr              = module.vpc.subnets["services"].cidr_range
}

# Service accounts for Phase 1
module "phase1_service_accounts" {
  source     = "../../modules/iam_service_accounts"
  project_id = var.project_id

  service_accounts = {
    sa_bastion = {
      display_name = "Bastion Instance SA"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ]
    }
    sa_freeipa = {
      display_name = "FreeIPA Instance SA"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ]
    }
    sa_workstation = {
      display_name = "Workstation Instance SA"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ]
    }
  }
}

# Secret-level IAM bindings
resource "google_secret_manager_secret_iam_member" "freeipa_admin_secret_access" {
  secret_id = module.secrets.secret_ids["freeipa_admin_password"]
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.phase1_service_accounts.service_accounts["sa_freeipa"].email}"
}

resource "google_secret_manager_secret_iam_member" "ipa_enrollment_otp_access" {
  secret_id = module.secrets.secret_ids["ipa_enrollment_otp"]
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.phase1_service_accounts.service_accounts["sa_workstation"].email}"
}

# Bastion instance
module "bastion" {
  source               = "../../modules/bastion"
  name                 = var.bastion.name
  zone                 = var.bastion.zone
  subnetwork_self_link = local.services_subnet_self_link
  machine_type         = var.bastion.machine_type
  service_account_email = module.phase1_service_accounts.service_accounts["sa_bastion"].email
  additional_tags      = var.bastion.additional_tags
}

# FreeIPA VM
module "freeipa" {
  source               = "../../modules/freeipa_vm"
  name                 = var.freeipa.name
  hostname             = var.freeipa.hostname
  domain               = var.freeipa.domain
  realm                = var.freeipa.realm
  region               = var.region
  zone                 = var.freeipa.zone
  subnetwork_self_link = local.services_subnet_self_link
  machine_type         = var.freeipa.machine_type
  service_account_email = module.phase1_service_accounts.service_accounts["sa_freeipa"].email
  additional_tags      = var.freeipa.additional_tags
}

# Filestore NFS
module "filestore" {
  source              = "../../modules/filestore"
  project_id          = var.project_id
  location            = var.region
  name                = var.filestore.name
  tier                = var.filestore.tier
  capacity_home_gb    = var.filestore.capacity_home_gb
  capacity_shared_gb  = var.filestore.capacity_shared_gb
  vpc_name            = module.vpc.vpc_name
  reserved_ip_range   = var.filestore.reserved_ip_range
  allowed_cidrs       = [local.workloads_cidr, local.services_cidr]
}

# Workstation instance template
module "workstation_template" {
  source               = "../../modules/instance_template_workstation"
  name_prefix          = var.workstation.name_prefix
  machine_type         = var.workstation.machine_type
  subnetwork_self_link = local.workloads_subnet_self_link
  service_account_email = module.phase1_service_accounts.service_accounts["sa_workstation"].email
  additional_tags      = var.workstation.additional_tags
}

# Workstation MIG
module "workstation_mig" {
  source                      = "../../modules/mig_workstation"
  name                        = "${var.workstation.name_prefix}-mig"
  region                      = var.region
  zones                       = var.zones
  instance_template_self_link = module.workstation_template.instance_template_self_link
  target_size                 = var.workstation.target_size
  min_replicas                = var.workstation.min_replicas
  max_replicas                = var.workstation.max_replicas
  cpu_target_utilization      = var.workstation.cpu_target
}

# DNS records (A and SRV)
module "dns_records" {
  source    = "../../modules/dns_records"
  zone_name = module.dns.private_zones["corp_internal"].name

  a_records = [
    {
      name    = "ipa.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = [module.freeipa.internal_ip]
    },
    {
      name    = "bastion.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = [module.bastion.internal_ip]
    },
    {
      name    = "nfs.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = [module.filestore.ip_address]
    }
  ]

  srv_records = [
    {
      name    = "_kerberos._udp.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = ["0 0 88 ipa.${var.freeipa.domain}."]
    },
    {
      name    = "_kerberos._tcp.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = ["0 0 88 ipa.${var.freeipa.domain}."]
    },
    {
      name    = "_ldap._tcp.${var.freeipa.domain}."
      ttl     = 300
      rrdatas = ["0 0 389 ipa.${var.freeipa.domain}."]
    }
  ]
}

# Allow Google health checks to reach SSH on workers
resource "google_compute_firewall" "allow_hc_to_workers" {
  name    = "allow-hc-ssh-workers"
  network = module.vpc.vpc_name

  direction = "INGRESS"
  priority  = 1150

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["worker"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}



```

```markdown
FreeIPA server role

- Installs and configures FreeIPA server on Ubuntu
- Disables IPA DNS; Cloud DNS remains authoritative
- Fetches admin password from Secret Manager at runtime


```

```markdown
<<'PATCH'
*** Begin Patch
*** Update File: README.md
@@
 ## Phase-1 (VM Layer)
 
+### Deploy
+
+```bash
+cd terraform/envs/dev
+terraform init
+terraform apply -target=module.apis -target=module.vpc -target=module.dns # if needed first
+terraform apply -var-file=terraform.tfvars
+```
+
+### Configure (Ansible)
+
+Preferred: run from bastion to avoid local IAP SSH ProxyCommand complexity.
+
+```bash
+# SSH to bastion via IAP
+gcloud compute ssh ubuntu@bastion.corp.internal --tunnel-through-iap -- -N
+
+# On bastion, run playbooks
+cd /path/to/repo/ansible
+ansible-playbook -i inventories/dev/hosts.ini playbooks/freeipa.yml
+ansible-playbook -i inventories/dev/hosts.ini playbooks/workstation.yml
+```
+
+### Open IDE panels
+
+```bash
+./scripts/iap_tunnel_code.sh   # Open http://localhost:8080
+./scripts/iap_tunnel_jupyter.sh# Open http://localhost:8888
+```
+
+### Troubleshooting
+
+- Ensure SRV records exist in private zone: `_kerberos._udp`, `_kerberos._tcp` (88), `_ldap._tcp` (389) pointing to `ipa.corp.internal.`
+- Verify firewall rules: deny-all first; IAP→bastion 22; bastion→workers 22; FreeIPA ports from services/workloads; HC ranges to workers 22
+- Verify autofs mounts on workstations: `/home/<user>` and `/shared/*`
+- Linger enabled via PAM hook to persist user services after logout
+
*** End Patch
```

```markdown
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

## Phase-1 (VM Layer) – Deploy, Configure, Access

### Deploy (Terraform)

```bash
cd terraform/envs/dev
terraform init
terraform apply -var-file=terraform.tfvars
```

### Configure (Ansible)

Preferred: run from bastion to avoid local IAP ProxyCommand complexity.

```bash
# SSH to bastion via IAP
gcloud compute ssh ubuntu@bastion.corp.internal --tunnel-through-iap

# On bastion, run playbooks
cd /path/to/repo/ansible
ansible-playbook -i inventories/dev/hosts.ini playbooks/freeipa.yml
ansible-playbook -i inventories/dev/hosts.ini playbooks/workstation.yml
```

### Open IDE panels

```bash
./scripts/iap_tunnel_code.sh    # Open http://localhost:8080
./scripts/iap_tunnel_jupyter.sh # Open http://localhost:8888
```

### Troubleshooting

- Ensure SRV records exist in private zone: `_kerberos._udp`, `_kerberos._tcp` (88), `_ldap._tcp` (389) → `ipa.corp.internal.`
- Verify firewall rules: deny-all first; IAP→bastion 22; bastion→workers 22; FreeIPA ports from services/workloads; HC ranges to workers 22
- Verify autofs mounts on workstations: `/home/<user>` and `/shared/*`
- Linger enabled via PAM hook; user units seeded via `/etc/skel/.config/systemd/user/`


```

```yaml
---
- name: Ensure autofs is installed
  apt:
    name: autofs
    state: present

- name: Configure auto.master.d for home and shared
  copy:
    dest: "/etc/auto.master.d/{{ item.name }}.autofs"
    content: "{{ item.content }}\n"
    mode: '0644'
  loop:
    - { name: 'home',   content: '/home /etc/auto.home --timeout=600' }
    - { name: 'shared', content: '/shared /etc/auto.shared --timeout=600' }

- name: Configure auto.home map for per-user homes
  copy:
    dest: /etc/auto.home
    mode: '0644'
    content: "* -fstype=nfs4,rw,nosuid,hard,intr {{ filestore_ip }}:/home/&\n"

- name: Configure auto.shared map for shared dirs
  copy:
    dest: /etc/auto.shared
    mode: '0644'
    content: |
      data     -fstype=nfs4,rw,nosuid,hard,intr {{ filestore_ip }}:/shared/data
      projects -fstype=nfs4,rw,nosuid,hard,intr {{ filestore_ip }}:/shared/projects
      models   -fstype=nfs4,rw,nosuid,hard,intr {{ filestore_ip }}:/shared/models

- name: Ensure /shared exists
  file:
    path: /shared
    state: directory
    mode: '0755'

- name: Restart autofs
  service:
    name: autofs
    state: restarted
    enabled: true



```

```plaintext
output "ip_address" {
  description = "Filestore IP address"
  value       = google_filestore_instance.nfs.networks[0].ip_addresses[0]
}

output "exports" {
  description = "Export paths"
  value = {
    home   = "/home"
    shared = "/shared"
  }
}



```

```shellscript
#!/usr/bin/env bash
set -euo pipefail

# Select a workstation VM from the regional MIG (least-loaded placeholder -> random)

PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}
REGION=${REGION:-"us-central1"}
MIG_NAME=${MIG_NAME:-"ws-mig"}

mapfile -t INSTANCES < <(gcloud compute instance-groups managed list-instances "$MIG_NAME" --region "$REGION" --format='value(instance,instanceStatus,instanceZone.basename())')

if [[ ${#INSTANCES[@]} -eq 0 ]]; then
  echo "No instances found in MIG $MIG_NAME" >&2
  exit 1
fi

IDX=$(( RANDOM % ${#INSTANCES[@]} ))
SELECTED=${INSTANCES[$IDX]}
NAME=$(awk '{print $1}' <<<"$SELECTED")
ZONE=$(awk '{print $3}' <<<"$SELECTED")
echo "$NAME $ZONE"



```

```shellscript
#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}
REGION=${REGION:-"us-central1"}
MIG_NAME=${MIG_NAME:-"ws-mig"}
BASTION_HOST=${BASTION_HOST:-"bastion.corp.internal"}
LOCAL_PORT=${LOCAL_PORT:-8080}

read WS_INSTANCE WS_ZONE < <("$(dirname "$0")/broker_select_vm.sh")
echo "Chosen workstation: $WS_INSTANCE in $WS_ZONE"

echo "Starting IAP tunnel to $WS_INSTANCE (code-server)..."
gcloud compute ssh "ubuntu@${BASTION_HOST}" \
  --tunnel-through-iap \
  -- -N -L ${LOCAL_PORT}:127.0.0.1:8080 -J ubuntu@${BASTION_HOST} ubuntu@${WS_INSTANCE} &

echo "Open http://localhost:${LOCAL_PORT}"



```

```shellscript
#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}
REGION=${REGION:-"us-central1"}
MIG_NAME=${MIG_NAME:-"ws-mig"}
BASTION_HOST=${BASTION_HOST:-"bastion.corp.internal"}
LOCAL_PORT=${LOCAL_PORT:-8888}

read WS_INSTANCE WS_ZONE < <("$(dirname "$0")/broker_select_vm.sh")
echo "Chosen workstation: $WS_INSTANCE in $WS_ZONE"

echo "Starting IAP tunnel to $WS_INSTANCE (JupyterLab)..."
gcloud compute ssh "ubuntu@${BASTION_HOST}" \
  --tunnel-through-iap \
  -- -N -L ${LOCAL_PORT}:127.0.0.1:8888 -J ubuntu@${BASTION_HOST} ubuntu@${WS_INSTANCE} &

echo "Open http://localhost:${LOCAL_PORT}"



```

```yaml
---
- name: Install FreeIPA client packages
  apt:
    name:
      - freeipa-client
      - sssd
      - oddjob
      - oddjob-mkhomedir
      - chrony
    state: present
    update_cache: true

- name: Enable pam_mkhomedir
  lineinfile:
    path: /etc/pam.d/common-session
    line: 'session required pam_mkhomedir.so skel=/etc/skel/ umask=0022'
    insertafter: EOF

- name: Fetch IPA enrollment OTP from Secret Manager
  shell: |
    TOKEN=$(curl -s -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/service-accounts/default/token | jq -r .access_token)
    curl -s -H "Authorization: Bearer $TOKEN" "https://secretmanager.googleapis.com/v1/projects/{{ lookup('env','GOOGLE_PROJECT') }}/secrets/ipa_enrollment_otp/versions/latest:access" | jq -r .payload.data | base64 -d
  args:
    executable: /bin/bash
  register: ipa_enrollment_otp
  changed_when: false

- name: Join FreeIPA realm if not already joined
  shell: |
    set -euo pipefail
    if ! test -f /etc/ipa/default.conf; then
      ipa-client-install -U --domain={{ ipa_domain }} --server=ipa.{{ ipa_domain }} --realm={{ ipa_realm }} --principal=enroll --password='{{ ipa_enrollment_otp.stdout }}' --mkhomedir
    fi
  args:
    executable: /bin/bash



```

```shellscript
#!/usr/bin/env bash
set -euo pipefail

# Select a workstation VM from the regional MIG (least-loaded placeholder -> random)

PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}
REGION=${REGION:-"us-central1"}
MIG_NAME=${MIG_NAME:-"ws-mig"}

mapfile -t INSTANCES < <(gcloud compute instance-groups managed list-instances "$MIG_NAME" --region "$REGION" --format='value(instance,instanceStatus,instanceZone.basename())')

if [[ ${#INSTANCES[@]} -eq 0 ]]; then
  echo "No instances found in MIG $MIG_NAME" >&2
  exit 1
fi

IDX=$(( RANDOM % ${#INSTANCES[@]} ))
SELECTED=${INSTANCES[$IDX]}
NAME=$(awk '{print $1}' <<<"$SELECTED")
ZONE=$(awk '{print $3}' <<<"$SELECTED")
IP=$(gcloud compute instances describe "$NAME" --zone "$ZONE" --format='get(networkInterfaces[0].networkIP)')
echo "$NAME $ZONE $IP"



```

```yaml
---
- name: Install FreeIPA server packages
  apt:
    name:
      - freeipa-server
      - freeipa-server-dns
      - chrony
    state: present
    update_cache: true

- name: Ensure hostname and hosts entry
  hostname:
    name: "{{ ipa_hostname }}.{{ ipa_domain }}"

- name: Disable IPA DNS (Cloud DNS authoritative) - ensure install opts reflect
  set_fact:
    ipa_install_opts: "--realm {{ ipa_realm }} --domain {{ ipa_domain }} --hostname {{ ipa_hostname }}.{{ ipa_domain }} --no-dns --no-ntp -U"

- name: Discover GCP project ID via metadata
  shell: |
    curl -s -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/project/project-id
  register: gcp_project
  changed_when: false

- name: Fetch FreeIPA admin password from Secret Manager
  shell: |
    TOKEN=$(curl -s -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/service-accounts/default/token | jq -r .access_token)
    curl -s -H "Authorization: Bearer $TOKEN" "https://secretmanager.googleapis.com/v1/projects/{{ gcp_project.stdout }}/secrets/freeipa_admin_password/versions/latest:access" | jq -r .payload.data | base64 -d
  args:
    executable: /bin/bash
  register: ipa_admin_password
  changed_when: false

- name: Run ipa-server-install non-interactively if not already configured
  shell: |
    set -euo pipefail
    if ! systemctl is-active --quiet ipa; then
      echo "{{ ipa_admin_password.stdout }}" > /root/ipa_admin_password
      ipa-server-install {{ ipa_install_opts }} -a "{{ ipa_admin_password.stdout }}" -p "{{ ipa_admin_password.stdout }}"
    fi
  args:
    executable: /bin/bash



```

```yaml
---
- name: Install FreeIPA client packages
  apt:
    name:
      - freeipa-client
      - sssd
      - oddjob
      - oddjob-mkhomedir
      - chrony
    state: present
    update_cache: true

- name: Enable pam_mkhomedir
  lineinfile:
    path: /etc/pam.d/common-session
    line: 'session required pam_mkhomedir.so skel=/etc/skel/ umask=0022'
    insertafter: EOF

- name: Discover GCP project ID via metadata
  shell: |
    curl -s -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/project/project-id
  register: gcp_project
  changed_when: false

- name: Fetch IPA enrollment OTP from Secret Manager
  shell: |
    TOKEN=$(curl -s -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/service-accounts/default/token | jq -r .access_token)
    curl -s -H "Authorization: Bearer $TOKEN" "https://secretmanager.googleapis.com/v1/projects/{{ gcp_project.stdout }}/secrets/ipa_enrollment_otp/versions/latest:access" | jq -r .payload.data | base64 -d
  args:
    executable: /bin/bash
  register: ipa_enrollment_otp
  changed_when: false

- name: Join FreeIPA realm if not already joined
  shell: |
    set -euo pipefail
    if ! test -f /etc/ipa/default.conf; then
      ipa-client-install -U --domain={{ ipa_domain }} --server=ipa.{{ ipa_domain }} --realm={{ ipa_realm }} --principal=enroll --password='{{ ipa_enrollment_otp.stdout }}' --mkhomedir
    fi
  args:
    executable: /bin/bash



```

Running format and a quick validation to ensure the new Terraform modules and env wiring are syntactically sound. Then I’ll proceed if we get a clean validate.

```plaintext
variable "name" {
  description = "Instance name"
  type        = string
}

variable "zone" {
  description = "Compute zone"
  type        = string
}

variable "subnetwork_self_link" {
  description = "Self link of the subnetwork to attach"
  type        = string
}

variable "machine_type" {
  description = "Machine type for the bastion"
  type        = string
}

variable "image_family" {
  description = "Image family for Ubuntu"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "image_project" {
  description = "Project hosting the image family"
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "boot_disk_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}

variable "boot_disk_type" {
  description = "Boot disk type"
  type        = string
  default     = "pd-balanced"
}

variable "service_account_email" {
  description = "Service account email for the instance"
  type        = string
}

variable "startup_script" {
  description = "Metadata startup script"
  type        = string
  default     = <<-EOT
#!/usr/bin/env bash
set -euo pipefail
curl -sS https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh | bash -s -- --also-install
touch /var/tmp/ansible_ready
EOT
}

variable "enable_os_login" {
  description = "Enable OS Login integration"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Additional labels"
  type        = map(string)
  default     = {}
}

variable "metadata" {
  description = "Additional instance metadata"
  type        = map(string)
  default     = {}
}

variable "additional_tags" {
  description = "Additional network tags"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "dev"
}



```

```plaintext
<<'PATCH'
*** Begin Patch
*** Update File: terraform/modules/filestore/main.tf
@@
-resource "google_filestore_instance" "nfs" {
+resource "google_filestore_instance" "nfs" {
   name     = var.name
   project  = var.project_id
   location = var.location
   tier     = var.tier
 
-  file_shares {
-    name         = "home"
-    capacity_gb  = var.capacity_home_gb
-    nfs_export_options {
-      ip_ranges   = var.allowed_cidrs
-      access_mode = "READ_WRITE"
-      squash_mode = "NO_ROOT_SQUASH"
-    }
-  }
-
-  file_shares {
-    name         = "shared"
-    capacity_gb  = var.capacity_shared_gb
-    nfs_export_options {
-      ip_ranges   = var.allowed_cidrs
-      access_mode = "READ_WRITE"
-      squash_mode = "NO_ROOT_SQUASH"
-    }
-  }
+  file_shares {
+    name         = "export"
+    capacity_gb  = var.capacity_home_gb + var.capacity_shared_gb
+    nfs_export_options {
+      ip_ranges   = var.allowed_cidrs
+      access_mode = "READ_WRITE"
+      squash_mode = "NO_ROOT_SQUASH"
+    }
+  }
@@
 }
*** End Patch
```

```plaintext
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_filestore_instance" "nfs" {
  name     = var.name
  project  = var.project_id
  location = var.location
  tier     = var.tier

  file_shares {
    name        = "export"
    capacity_gb = var.capacity_home_gb + var.capacity_shared_gb
    nfs_export_options {
      ip_ranges   = var.allowed_cidrs
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }

  networks {
    network           = var.vpc_name
    modes             = ["MODE_IPV4"]
    reserved_ip_range = var.reserved_ip_range
  }
}



```

# Mode: ACT

Status: Implemented Phase 1 scaffolding across Terraform, Ansible, scripts, and docs. Validated Terraform config successfully. Highlights: Shielded VMs, no public IPs, IAP SSH, Filestore with single file share, Cloud DNS A/SRV records, secret IAM bindings, autofs + pam_mkhomedir, per-user panel services seeded via /etc/skel, linger via PAM.

What I changed
- Terraform modules added:
  - `terraform/modules/bastion/` (instance, Shielded VM, no public IP, Ops Agent, startup hooks)
  - `terraform/modules/freeipa_vm/` (static internal IP, Shielded VM, cloud-init baseline)
  - `terraform/modules/filestore/` (single file share, NFS export options)
  - `terraform/modules/instance_template_workstation/` (Ubuntu template, tools, Ops Agent)
  - `terraform/modules/mig_workstation/` (regional MIG + autoscaler + SSH HC)
  - `terraform/modules/dns_records/` (A + SRV)
- Env wiring:
  - `terraform/envs/dev/phase1.tf`
    - Instantiates Phase 1 modules; uses Phase 0 outputs for subnets, DNS
    - Creates SAs: `sa_bastion`, `sa_freeipa`, `sa_workstation`
    - Secret-level IAM bindings for `freeipa_admin_password` and `ipa_enrollment_otp`
    - DNS A records: `ipa`, `bastion`, `nfs`; SRV for `_kerberos` and `_ldap`
    - Firewall for Google HC to workers on 22
  - `terraform/envs/dev/variables.phase1.tf`
    - Variables for zones, VM sizes, Filestore tier/capacity, MIG sizes, realm/domain/hostnames
- Ansible:
  - Inventory: `ansible/inventories/dev/hosts.ini` with groups `bastion`, `freeipa`, `workstations`
  - Playbooks: `bastion.yml`, `freeipa.yml`, `workstation.yml`
  - Roles:
    - `common-base`: baseline packages, Ops Agent, SSH hardening
    - `nfs-client`: autofs maps; mounts `/home/%(USER)s` to `nfs:/home/USER` and `/shared/{data,projects,models}` to `nfs:/shared/*`
    - `freeipa-server`: unattended `ipa-server-install` with IPA DNS disabled; fetches admin password from Secret Manager via instance SA
    - `freeipa-client`: unattended `ipa-client-install` using OTP from Secret Manager; enables pam_mkhomedir
    - `panel-code-server`: installs code-server; seeds per-user systemd unit in `/etc/skel/.config/systemd/user/`; adds PAM hook to auto-enable linger on first login
    - `panel-jupyterlab`: installs pipx + JupyterLab; seeds per-user systemd unit bound to 127.0.0.1:8888
- Scripts:
  - `scripts/broker_select_vm.sh`: selects a MIG instance (random); prints name zone ip
  - `scripts/iap_tunnel_code.sh` and `iap_tunnel_jupyter.sh`: open IAP SSH tunnel chain for ports 8080/8888 via bastion
- Docs:
  - `docs/phase1_arch_diagram.mmd` and `docs/phase1_access_flows.mmd`
  - Updated `README.md` with Phase 1 deploy, configure, panel access, troubleshooting
- Validation:
  - Ran `terraform fmt` and `terraform validate` successfully after fixing variable and Filestore file_shares constraints

Next steps to run
- Terraform:
  - cd `terraform/envs/dev`
  - `terraform init`
  - `terraform apply -var-file=terraform.tfvars`
- Ansible:
  - SSH to bastion via IAP
  - From bastion: `ansible-playbook -i inventories/dev/hosts.ini playbooks/freeipa.yml`
  - Then: `ansible-playbook -i inventories/dev/hosts.ini playbooks/workstation.yml`
- Open IDE panels:
  - `./scripts/iap_tunnel_code.sh` → open `http://localhost:8080`
  - `./scripts/iap_tunnel_jupyter.sh` → open `http://localhost:8888`

Notes
- DNS: Cloud DNS is authoritative; FreeIPA DNS disabled; SRV records added for Kerberos/LDAP.
- Secrets: IAM binding per secret per SA; secrets only retrieved at runtime on instances.
- Firewall posture: deny-all remains; explicit allows for IAP→bastion SSH, bastion→workers SSH, FreeIPA ports, and Google HC ranges to workers SSH.
- Autofs + pam_mkhomedir: ensures NFS homes are seeded on first login; systemd user units seeded via /etc/skel; linger auto-enabled on login.

Summary
- Added Phase 1 Terraform modules and env wiring, Ansible roles and playbooks, scripts, and diagrams.
- Ensured security model (IAP, Shielded VM, least-priv SAs, secret fetch at runtime) and DNS SRV records.
- Terraform validates cleanly; ready to apply and run Ansible for full acceptance tests.

