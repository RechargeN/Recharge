locals {
  manifest_path = "${path.module}/../../../../config/manifests/execution-manifest.json"
  manifest      = jsondecode(file(local.manifest_path))
  env           = local.manifest.environments["dev"]

  labels = {
    application = "recharge"
    environment = "dev"
    managed_by  = "terraform"
    stage       = "3-1-execution-manifest"
  }

  # Authorization is an execution precondition, NEVER resource cardinality.
  authorization = try(jsondecode(file(var.authorization_record_path)), null)
  authorization_valid = try(
    local.authorization.schemaVersion == 1
    && local.authorization.status == "approved"
    && local.authorization.recordRef == var.authorization_ref
    && length(local.authorization.owner) > 0
    && length(local.authorization.ownerApprovalEvidenceRef) > 0
    && local.authorization.environment == var.environment_id
    && var.project_id != null
    && local.authorization.projectId == var.project_id
    && local.authorization.manifestSha256 == filesha256(local.manifest_path)
    && var.manifest_sha256 == filesha256(local.manifest_path)
    && var.authorization_record_sha256 == filesha256(var.authorization_record_path)
    && can(regex("^[0-9a-f]{40}$", var.release_commit_sha))
    && local.authorization.commitSha == var.release_commit_sha
    && local.authorization.dataScope == "synthetic"
    && local.authorization.push == false && local.authorization.merge == false
    && local.authorization.marketActivation == false
    && contains(local.authorization.operations, "plan")
    && contains(local.authorization.operations, "apply")
    && alltrue([for op in local.authorization.operations : contains(["plan", "apply"], op)])
    && timecmp(local.authorization.issuedAtUtc, plantimestamp()) <= 0
    && timecmp(local.authorization.expiresAtUtc, plantimestamp()) > 0,
    false
  )
  manifest_authorized = (
    local.manifest.authority.apply == "allowed"
    && local.manifest.authority.provisioning == "authorized"
    && local.env.authorized == true
    && local.env.projectId == var.project_id
  )
  provisioning_authorized = local.authorization_valid && local.manifest_authorized
}

# No provisioner, command or network action: the builtin resource is a blocking
# precondition. The checked-in Draft manifest always fails this gate. An owner
# record is an attestation, not a cryptographic signature: protected execution
# must verify its provenance and exact reviewed plan before apply.
resource "terraform_data" "execution_guard" {
  input = var.environment_id
  lifecycle {
    precondition {
      condition     = local.authorization_valid
      error_message = "Execution denied: missing, expired, mismatched or incomplete owner record."
    }
    precondition {
      condition     = local.manifest_authorized
      error_message = "Execution denied: this Draft manifest grants no provisioning/apply authority."
    }
  }
}

module "project_baseline" {
  depends_on = [terraform_data.execution_guard]
  source     = "../../modules/project_baseline"

  enabled    = true
  labels     = local.labels
  project_id = var.project_id
  services   = toset(["artifactregistry.googleapis.com", "billingbudgets.googleapis.com", "cloudbuild.googleapis.com", "cloudfunctions.googleapis.com", "cloudresourcemanager.googleapis.com", "cloudscheduler.googleapis.com", "eventarc.googleapis.com", "firebase.googleapis.com", "firebaseappcheck.googleapis.com", "firestore.googleapis.com", "iam.googleapis.com", "iamcredentials.googleapis.com", "logging.googleapis.com", "monitoring.googleapis.com", "pubsub.googleapis.com", "run.googleapis.com", "secretmanager.googleapis.com", "storage.googleapis.com", "sts.googleapis.com"])
}

module "firestore" {
  depends_on = [terraform_data.execution_guard]
  source     = "../../modules/firestore"

  enabled                = true
  labels                 = local.labels
  project_id             = var.project_id
  location_id            = local.manifest.locationPolicy.firestore.location
  point_in_time_recovery = var.point_in_time_recovery
}

module "storage" {
  depends_on = [terraform_data.execution_guard]
  source     = "../../modules/storage"

  enabled           = true
  labels            = local.labels
  project_id        = var.project_id
  media_location    = local.manifest.locationPolicy.mediaStorage.location
  recovery_location = local.manifest.locationPolicy.recoveryStorage.location
  recovery_enabled  = var.recovery_bucket_enabled
}

module "runtime_identities" {
  depends_on = [terraform_data.execution_guard]
  source     = "../../modules/runtime_identities"

  enabled          = true
  labels           = local.labels
  project_id       = var.project_id
  service_accounts = local.env.serviceAccounts
}

module "ci_wif" {
  depends_on = [terraform_data.execution_guard]
  source     = "../../modules/ci_wif"

  enabled             = true
  labels              = local.labels
  project_id          = var.project_id
  pool_id             = local.env.workloadIdentity.poolName
  provider_id         = local.env.workloadIdentity.providerName
  repository_id       = var.github_repository_id
  repository_owner_id = var.github_repository_owner_id
  environment_id      = var.environment_id
  project_number      = var.project_number
}

module "budget_alerts" {
  depends_on = [terraform_data.execution_guard]
  source     = "../../modules/budget_alerts"

  enabled                  = true && var.billing_account_id != null && var.project_number != null
  labels                   = local.labels
  billing_account_id       = var.billing_account_id
  project_number           = var.project_number
  display_name             = "budget-guardrail-dev"
  amount_eur               = local.env.budget.guardrailMonthlyEur
  thresholds_percent       = local.env.budget.thresholdsPercent
  notification_channel_ids = var.notification_channel_ids
}

module "secret_containers" {
  depends_on = [terraform_data.execution_guard]
  source     = "../../modules/secret_containers"

  enabled    = true
  labels     = local.labels
  project_id = var.project_id
  location   = local.manifest.locationPolicy.functions.region
  references = local.env.secretReferences
}

module "app_check" {
  depends_on = [terraform_data.execution_guard]
  source     = "../../modules/app_check"

  enabled    = true
  labels     = local.labels
  project_id = var.project_id
  mode       = local.env.appCheck.mode
}

module "state_bucket" {
  depends_on = [terraform_data.execution_guard]
  source     = "../../modules/state_bucket"

  enabled    = true
  labels     = local.labels
  project_id = var.project_id
  location   = local.env.stateBucket.location
}
