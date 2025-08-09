output "keyring_id" {
  description = "ID of the KMS key ring"
  value       = google_kms_key_ring.keyring.id
}

output "keyring_name" {
  description = "Name of the KMS key ring"
  value       = google_kms_key_ring.keyring.name
}

output "crypto_key_id" {
  description = "ID of the KMS crypto key"
  value       = google_kms_crypto_key.key.id
}

output "crypto_key_name" {
  description = "Name of the KMS crypto key"
  value       = google_kms_crypto_key.key.name
}
