output "firewall_rules" {
  description = "Map of created firewall rules"
  value = {
    for k, rule in google_compute_firewall.rules : k => {
      name      = rule.name
      id        = rule.id
      direction = rule.direction
      priority  = rule.priority
    }
  }
}
