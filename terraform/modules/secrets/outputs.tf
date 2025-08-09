output "secret_ids" {
  description = "Map of secret names to their resource IDs"
  value = {
    for k, secret in google_secret_manager_secret.secrets : k => secret.id
  }
}

output "secret_names" {
  description = "Map of secret names to their secret IDs"
  value = {
    for k, secret in google_secret_manager_secret.secrets : k => secret.secret_id
  }
}
