# ADR-001: GCP Data Platform Architecture Overview

**Status:** Implemented  
**Date:** 2025-01-15  
**Decision Makers:** Platform Engineering Team  

## Context

Designing a VM-based GCP Data Platform to support 20-30 data engineers with requirements for:
- Centralized authentication via FreeIPA
- Shared NFS storage for collaboration  
- Secure access patterns with zero public IPs
- Infrastructure as Code deployment
- Production-ready operational procedures

## Decision

Implement a **two-phase architecture** with security-first design principles:

### Phase 0: Security Foundation
- Modular Terraform infrastructure with 15+ modules
- Workload Identity Federation (no service account keys)
- Customer-managed encryption (CMEK) for all secrets
- Deny-by-default networking with explicit allow rules
- Private VPC with Cloud NAT for egress

### Phase 1: Compute & Services Layer  
- Bastion host with IAP-only access
- FreeIPA domain controller with static IP
- Workstation MIG with autoscaling (0-10 instances)
- Filestore NFS with 4TB capacity and structured exports
- Complete Ansible automation for configuration management

## Architecture Components

### Network Design
```
VPC: vpc-data-platform
├── subnet-services (10.10.1.0/24) - Bastion, FreeIPA
├── subnet-workloads (10.10.2.0/24) - Workstations, Filestore
├── Private DNS: corp.internal
└── Cloud NAT for egress traffic
```

### Access Patterns
```
Users → IAP → Bastion (jump host) → Workstations
Users → IAP → Bastion → FreeIPA enrollment
Workstations → Filestore NFS (autofs)
Workstations → FreeIPA (Kerberos/LDAP)
```

### Service Accounts
- `sa_bastion`: Logging/monitoring only
- `sa_freeipa`: Secret Manager access for admin password and OTP management
- `sa_workstation`: Secret Manager access for enrollment OTP

## Rationale

### Security-First Approach
- **Zero Trust**: No public IPs, IAP tunnel access only
- **Least Privilege**: Service accounts with minimal required permissions
- **Defense in Depth**: Multiple security layers (IAP, firewall, authentication)

### Operational Excellence  
- **Infrastructure as Code**: 100% Terraform/Ansible automation
- **Immutable Infrastructure**: VM templates with consistent configuration
- **Scalability**: MIG-based workstations adapt to demand
- **Monitoring**: Google Ops Agent on all instances

### Data Engineering Optimized
- **Shared Storage**: NFS with team collaboration directories
- **User Experience**: Transparent home directory mounting via autofs
- **Development Tools**: Code-server and JupyterLab pre-installed
- **Authentication**: Single sign-on via FreeIPA

## Consequences

### Positive
- Enterprise-grade security posture
- Scalable to 20-30+ users
- Complete automation reduces operational overhead
- Familiar VM-based environment for traditional data engineers

### Negative  
- Higher complexity than containerized solutions
- VM licensing costs vs. serverless alternatives
- Requires FreeIPA domain administration knowledge

### Mitigation
- Comprehensive documentation and runbooks
- Automated FreeIPA user enrollment process
- Monitoring and alerting for operational awareness

## Implementation Status

✅ **Phase 0**: Complete security foundation deployed  
✅ **Phase 1**: Complete VM infrastructure deployed  
✅ **Production Hardening**: IAP access, NFS automation, FreeIPA enrollment  
🚧 **Documentation**: Architecture documentation in progress

## Related Decisions

- ADR-002: Terraform Module Structure
- ADR-003: FreeIPA Integration Strategy  
- ADR-004: Network Security Model
- ADR-005: Ansible Automation Approach
