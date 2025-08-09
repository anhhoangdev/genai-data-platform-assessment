resource "google_kms_key_ring" "keyring" {
  project  = var.project_id
  name     = var.keyring_name
  location = var.location
}

resource "google_kms_crypto_key" "key" {
  name     = var.key_name
  key_ring = google_kms_key_ring.keyring.id
  purpose  = "ENCRYPT_DECRYPT"

  rotation_period = var.rotation_period

  lifecycle {
    prevent_destroy = true
  }
}

# Grant Secret Manager service agent access to the key
data "google_project" "project" {
  project_id = var.project_id
}

resource "google_kms_crypto_key_iam_member" "secret_manager_key_access" {
  crypto_key_id = google_kms_crypto_key.key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-secretmanager.iam.gserviceaccount.com"
}

# Additional IAM bindings for the key
resource "google_kms_crypto_key_iam_member" "key_bindings" {
  for_each = var.key_iam_bindings

  crypto_key_id = google_kms_crypto_key.key.id
  role          = each.value.role
  member        = each.value.member
}
