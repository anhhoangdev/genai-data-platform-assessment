# VPC Module

Creates a VPC network with custom subnets.

## Usage

```hcl
module "vpc" {
  source     = "../../modules/network/vpc"
  project_id = var.project_id
  vpc_name   = "vpc-data-platform"
  
  subnets = {
    services = {
      name                     = "subnet-services"
      cidr_range              = "10.10.1.0/24"
      region                  = var.region
      private_ip_google_access = true
    }
    workloads = {
      name                     = "subnet-workloads"
      cidr_range              = "10.10.2.0/24"
      region                  = var.region
      private_ip_google_access = true
    }
  }
}
```

## Features

- Custom subnet creation with configurable CIDR ranges
- Private Google Access enabled by default
- Support for secondary IP ranges
- Regional routing mode
