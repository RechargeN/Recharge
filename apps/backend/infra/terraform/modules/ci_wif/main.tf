locals {
  configured = (
    var.repository_id == "1213588766"
    && var.repository_owner_id == "277012929"
    && can(regex("^[0-9]+$", var.project_number))
    && contains(["dev", "stage", "prod"], var.environment_id)
  )
  audience = "https://iam.googleapis.com/projects/${coalesce(var.project_number, "unconfigured")}/locations/global/workloadIdentityPools/${var.pool_id}/providers/${var.provider_id}"
  subject  = "repo:RechargeN@277012929/Recharge@1213588766:environment:backend-${var.environment_id}"
  clauses = [
    "assertion.iss == 'https://token.actions.githubusercontent.com'",
    "assertion.aud == '${local.audience}'",
    "assertion.sub == '${local.subject}'",
    "assertion.repository_id == '1213588766'",
    "assertion.repository_owner_id == '277012929'",
    "assertion.repository_visibility == 'public'",
    "assertion.workflow_ref == 'RechargeN/Recharge/.github/workflows/backend-deploy.yml@refs/heads/main'",
    "assertion.ref == 'refs/heads/main'",
    "assertion.environment == 'backend-${var.environment_id}'",
    var.environment_id == "dev" ? "assertion.event_name in ['push', 'workflow_dispatch']" : "assertion.event_name == 'workflow_dispatch'",
  ]
  condition = local.configured ? join(" && ", local.clauses) : "false"
}

# Desired topology, not permission to execute. Root execution_guard blocks apply.
resource "google_iam_workload_identity_pool" "github" {
  count                     = var.enabled ? 1 : 0
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions"
  description               = "Environment-local trust for the exact accepted deployment workflow."
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count                              = var.enabled ? 1 : 0
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  disabled                           = !local.configured
  attribute_condition                = local.condition
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository_id"    = "assertion.repository_id"
    "attribute.repository_owner" = "assertion.repository_owner_id"
    "attribute.workflow_ref"     = "assertion.workflow_ref"
  }
  oidc {
    issuer_uri        = "https://token.actions.githubusercontent.com"
    allowed_audiences = [local.audience]
  }
}
