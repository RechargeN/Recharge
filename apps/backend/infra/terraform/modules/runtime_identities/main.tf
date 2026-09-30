locals {
  # A deployed module needs its own identity; the deploy identity always exists.
  # Modules that are library-only have no runtime and therefore no identity.
  wanted = {
    for account in var.service_accounts : account.name => account
    if account.deployed || account.kind == "deploy"
  }
}

# Accounts only. No role binding is written: the exact role decision of
# BCK05-OD-02 is still pending, so an account carries no permission here.
resource "google_service_account" "account" {
  for_each = var.enabled ? local.wanted : {}

  project      = var.project_id
  account_id   = each.key
  display_name = substr(each.value.purpose, 0, 100)
  disabled     = false
}
