# Firewall Module

Creates VPC firewall rules with allow/deny rules.

## Usage

```hcl
module "firewall" {
  source     = "../../modules/network/firewall"
  project_id = var.project_id
  vpc_name   = module.vpc.vpc_name
  
  firewall_rules = [
    {
      name          = "deny-all-ingress"
      direction     = "INGRESS"
      priority      = 65534
      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["vm-managed"]
      deny = [
        {
          protocol = "all"
        }
      ]
    },
    {
      name          = "allow-iap-ssh"
      direction     = "INGRESS"
      priority      = 1000
      source_ranges = ["35.235.240.0/20"]
      target_tags   = ["bastion"]
      allow = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    }
  ]
}
```

## Rule Priority Guidelines

- 0-999: High priority explicit allows
- 1000-64999: Standard rules
- 65000+: Deny-all baselines
