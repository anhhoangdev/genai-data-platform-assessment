resource "google_service_account" "accounts" {
  for_each = var.service_accounts

  project      = var.project_id
  account_id   = each.key
  display_name = each.value.display_name
  description  = each.value.description
}

resource "google_project_iam_member" "account_bindings" {
  for_each = local.flattened_bindings

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.accounts[each.value.account_key].email}"

  depends_on = [google_service_account.accounts]
}

locals {
  # Flatten the bindings to create individual IAM bindings
  flattened_bindings = merge([
    for account_key, account_config in var.service_accounts : {
      for idx, role in account_config.roles : "${account_key}-${idx}" => {
        account_key = account_key
        role        = role
      }
    }
  ]...)
}
