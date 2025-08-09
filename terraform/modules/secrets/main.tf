resource "google_secret_manager_secret" "secrets" {
  for_each = var.secrets

  project   = var.project_id
  secret_id = each.key

  labels = each.value.labels

  replication {
    user_managed {
      replicas {
        location = var.location
        customer_managed_encryption {
          kms_key_name = var.kms_key_id
        }
      }
    }
  }
}

# Create initial versions for secrets that have initial values
resource "google_secret_manager_secret_version" "initial_versions" {
  for_each = {
    for k, v in var.secrets : k => v
    if v.initial_value != null
  }

  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = each.value.initial_value

  lifecycle {
    ignore_changes = [secret_data]
  }
}

# IAM bindings for secret access
resource "google_secret_manager_secret_iam_member" "secret_accessors" {
  for_each = local.flattened_iam_bindings

  project   = var.project_id
  secret_id = google_secret_manager_secret.secrets[each.value.secret_key].secret_id
  role      = each.value.role
  member    = each.value.member
}

locals {
  # Flatten IAM bindings for each secret
  flattened_iam_bindings = merge([
    for secret_key, secret_config in var.secrets : {
      for idx, binding in secret_config.iam_bindings : "${secret_key}-${idx}" => {
        secret_key = secret_key
        role       = binding.role
        member     = binding.member
      }
    }
  ]...)
}
