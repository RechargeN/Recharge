locals {
  # Trust requires both immutable ids. Without them the condition is false.
  condition = (
    var.repository_id != null && var.repository_owner_id != null
    ? "assertion.repository_id == '${var.repository_id}' && assertion.repository_owner_id == '${var.repository_owner_id}'"
    : "false"
  )
}

resource "google_iam_workload_identity_pool" "github" {
  count = var.enabled ? 1 : 0

  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions"
  description               = "Environment-local trust for verified GitHub Actions workflows."
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count = var.enabled ? 1 : 0

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  attribute_condition                = local.condition

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository_id"    = "assertion.repository_id"
    "attribute.repository_owner" = "assertion.repository_owner_id"
    "attribute.workflow_ref"     = "assertion.workflow_ref"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
