locals {
  manifest_path = "${path.module}/../../../../config/manifests/execution-manifest.json"
  manifest      = jsondecode(file(local.manifest_path))
  env           = local.manifest.environments["stage"]

  labels = {
    application = "recharge"
    environment = "stage"
    managed_by  = "terraform"
    stage       = "3-1-execution-manifest"
  }

  # The gate. Writing this code does not authorize applying it: every module below
  # receives `enabled = local.provisioning_authorized`, which is false unless a
  # project id, an authorization record reference and the exact manifest hash are
  # all supplied.
  provisioning_authorized = (
    var.project_id != null
    && var.authorization_ref != null
    && var.manifest_sha256 == filesha256(local.manifest_path)
  )
}

check "authorization_is_complete_or_absent" {
  assert {
    condition     = var.authorization_ref == null || (var.project_id != null && var.manifest_sha256 != null)
    error_message = "An authorization reference needs a project id and the manifest hash it covers."
  }
}

check "nothing_is_authorized_in_the_manifest" {
  assert {
    condition     = local.manifest.authority.apply == "denied" && local.env.authorized == false
    error_message = "The manifest itself never authorizes apply."
  }
}

module "project_baseline" {
  source = "../../modules/project_baseline"

  enabled    = local.provisioning_authorized
  labels     = local.labels
  project_id = var.project_id
  services   = toset(["artifactregistry.googleapis.com", "billingbudgets.googleapis.com", "cloudbuild.googleapis.com", "cloudfunctions.googleapis.com", "cloudresourcemanager.googleapis.com", "cloudscheduler.googleapis.com", "eventarc.googleapis.com", "firebase.googleapis.com", "firebaseappcheck.googleapis.com", "firestore.googleapis.com", "iam.googleapis.com", "iamcredentials.googleapis.com", "logging.googleapis.com", "monitoring.googleapis.com", "pubsub.googleapis.com", "run.googleapis.com", "secretmanager.googleapis.com", "storage.googleapis.com", "sts.googleapis.com"])
}

module "firestore" {
  source = "../../modules/firestore"

  enabled                = local.provisioning_authorized
  labels                 = local.labels
  project_id             = var.project_id
  location_id            = local.manifest.locationPolicy.firestore.location
  point_in_time_recovery = var.point_in_time_recovery
}

module "storage" {
  source = "../../modules/storage"

  enabled           = local.provisioning_authorized
  labels            = local.labels
  project_id        = var.project_id
  media_location    = local.manifest.locationPolicy.mediaStorage.location
  recovery_location = local.manifest.locationPolicy.recoveryStorage.location
  recovery_enabled  = var.recovery_bucket_enabled
}

module "runtime_identities" {
  source = "../../modules/runtime_identities"

  enabled          = local.provisioning_authorized
  labels           = local.labels
  project_id       = var.project_id
  service_accounts = local.env.serviceAccounts
}

module "ci_wif" {
  source = "../../modules/ci_wif"

  enabled             = local.provisioning_authorized
  labels              = local.labels
  project_id          = var.project_id
  pool_id             = local.env.workloadIdentity.poolName
  provider_id         = local.env.workloadIdentity.providerName
  repository_id       = var.github_repository_id
  repository_owner_id = var.github_repository_owner_id
}

module "budget_alerts" {
  source = "../../modules/budget_alerts"

  enabled                  = local.provisioning_authorized && var.billing_account_id != null && var.project_number != null
  labels                   = local.labels
  billing_account_id       = var.billing_account_id
  project_number           = var.project_number
  display_name             = "budget-guardrail-stage"
  amount_eur               = local.env.budget.guardrailMonthlyEur
  thresholds_percent       = local.env.budget.thresholdsPercent
  notification_channel_ids = var.notification_channel_ids
}

module "secret_containers" {
  source = "../../modules/secret_containers"

  enabled    = local.provisioning_authorized
  labels     = local.labels
  project_id = var.project_id
  location   = local.manifest.locationPolicy.functions.region
  references = local.env.secretReferences
}

module "app_check" {
  source = "../../modules/app_check"

  enabled    = local.provisioning_authorized
  labels     = local.labels
  project_id = var.project_id
  mode       = local.env.appCheck.mode
}

module "state_bucket" {
  source = "../../modules/state_bucket"

  enabled    = local.provisioning_authorized
  labels     = local.labels
  project_id = var.project_id
  location   = local.env.stateBucket.location
}
