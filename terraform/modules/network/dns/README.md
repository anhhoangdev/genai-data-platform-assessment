# DNS Module

Creates private DNS zones and records for internal service discovery.

## Usage

```hcl
module "dns" {
  source     = "../../modules/network/dns"
  project_id = var.project_id
  vpc_id     = module.vpc.vpc_id
  
  private_zones = {
    corp_internal = {
      dns_name    = "corp.internal."
      description = "Private zone for platform services"
    }
  }
  
  dns_records = {
    # Records will be added in Phase 1 when VMs are created
  }
}
```

## Features

- Private DNS zones visible only within the VPC
- Support for DNS forwarding to external name servers
- A, AAAA, CNAME, and other record types supported
- Phase 1 TODO: Add FreeIPA DNS forwarding configuration
