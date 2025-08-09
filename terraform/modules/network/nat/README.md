# NAT Module

Creates a Cloud Router and Cloud NAT for outbound internet access from private instances.

## Usage

```hcl
module "nat" {
  source     = "../../modules/network/nat"
  project_id = var.project_id
  region     = var.region
  vpc_id     = module.vpc.vpc_id
  
  router_name = "router-data-platform"
  nat_name    = "nat-data-platform"
}
```

## Features

- Auto-allocated external IP addresses
- Configured for all subnetworks by default
- Error-only logging enabled
- Support for custom subnetwork configuration
