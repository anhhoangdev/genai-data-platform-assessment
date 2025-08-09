output "service_accounts" {
  description = "Map of service account details"
  value = {
    for k, sa in google_service_account.accounts : k => {
      email      = sa.email
      name       = sa.name
      unique_id  = sa.unique_id
      account_id = sa.account_id
    }
  }
}

output "emails" {
  description = "Map of service account emails"
  value = {
    for k, sa in google_service_account.accounts : k => sa.email
  }
}
