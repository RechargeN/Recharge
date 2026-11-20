# N4a (owner-approved 2026-11-13): the staging ownership root, a copy of the
# reviewed dev bootstrap for recharge-staging-y9y2y only. Do not also apply
# envs/stage to this project/state. No production resource, no Emulator data.
locals {
  manifest_path = "${path.module}/../../../../config/manifests/execution-manifest.json"
  manifest      = jsondecode(file(local.manifest_path))
  env           = local.manifest.environments.stage
  approval      = try(jsondecode(file(var.authorization_record_path)), null)
  labels        = { application = "recharge", environment = "stage", managed_by = "terraform", stage = "n4a-staging-bootstrap" }
  record_valid = try(
    local.approval.status == "approved"
    && local.approval.schemaVersion == 1
    && local.approval.environment == "stage"
    && local.approval.projectId == var.project_id
    && var.project_id == "recharge-staging-y9y2y"
    && local.approval.billingAccountId == var.billing_account_id
    && local.approval.commitSha == var.release_commit_sha
    && can(regex("^[a-f0-9]{40}$", var.release_commit_sha))
    && local.approval.manifestSha256 == filesha256(local.manifest_path)
    && var.manifest_sha256 == filesha256(local.manifest_path)
    && var.authorization_record_sha256 == filesha256(var.authorization_record_path)
    && local.approval.operations == ["plan"]
    && length(local.approval.ownerApprovalEvidenceRef) > 0
    && local.approval.dataScope == "synthetic"
    && local.approval.push == false && local.approval.merge == false
    && local.approval.marketActivation == false
    && timecmp(local.approval.issuedAtUtc, plantimestamp()) <= 0
    && timecmp(local.approval.expiresAtUtc, plantimestamp()) > 0,
    false
  )
}

provider "google" {
  project = var.project_id
  region  = local.manifest.locationPolicy.functions.region
  # Process-only ADC; no credential value or quota-project override in config.
}

# Budget API requires a quota project for user ADC. This alias only affects
# budget calls after the cost_bootstrap API dependency; no ADC file mutation.
provider "google" {
  alias                 = "budget"
  project               = var.project_id
  billing_project       = var.project_id
  user_project_override = true
}

provider "google-beta" {
  project               = var.project_id
  region                = local.manifest.locationPolicy.functions.region
  billing_project       = var.project_id
  user_project_override = true
}

resource "terraform_data" "review_guard" {
  input = "stage-review-only"
  lifecycle {
    precondition {
      condition     = local.record_valid && local.env.budget.guardrailMonthlyEur == 5 && local.manifest.locationPolicy.recoveryStorage.state == "disabled"
      error_message = "Missing or mismatched staging plan record, budget or recovery scope."
    }
  }
}

resource "google_project" "stage" {
  depends_on          = [terraform_data.review_guard]
  project_id          = var.project_id
  name                = "Recharge staging"
  billing_account     = var.billing_account_id
  auto_create_network = false
  deletion_policy     = "PREVENT"
  labels              = merge(local.labels, { firebase = "enabled" })
  lifecycle {
    prevent_destroy = true
  }
}

# Only APIs needed for initial cost controls, before any ordinary resources.
resource "google_project_service" "cost_bootstrap" {
  for_each           = toset(["billingbudgets.googleapis.com", "monitoring.googleapis.com", "serviceusage.googleapis.com", "cloudresourcemanager.googleapis.com", "pubsub.googleapis.com", "logging.googleapis.com", "cloudbilling.googleapis.com"])
  project            = google_project.stage.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_monitoring_notification_channel" "budget_email" {
  depends_on   = [google_project_service.cost_bootstrap]
  project      = google_project.stage.project_id
  display_name = "stage-budget-incident-email"
  type         = "email"
  labels       = { email_address = var.notification_email }
  lifecycle {
    prevent_destroy = true
  }
}

resource "google_pubsub_topic" "budget" {
  depends_on = [google_project_service.cost_bootstrap]
  project    = google_project.stage.project_id
  name       = "stage-budget-events"
  message_storage_policy { allowed_persistence_regions = ["europe-west1"] }
  lifecycle { prevent_destroy = true }
}
resource "google_pubsub_topic_iam_member" "budget_publisher" {
  project = google_project.stage.project_id
  topic   = google_pubsub_topic.budget.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:billing-budget-alert@system.gserviceaccount.com"
}
resource "google_pubsub_subscription" "budget_evidence" {
  project                    = google_project.stage.project_id
  name                       = "stage-budget-evidence"
  topic                      = google_pubsub_topic.budget.id
  message_retention_duration = "86400s"
  expiration_policy { ttl = "" }
  lifecycle { prevent_destroy = true }
}

module "budget_alerts" {
  providers                = { google = google.budget }
  depends_on               = [google_pubsub_topic_iam_member.budget_publisher]
  source                   = "../../modules/budget_alerts"
  enabled                  = true
  labels                   = local.labels
  billing_account_id       = var.billing_account_id
  project_number           = google_project.stage.number
  display_name             = "budget-guardrail-stage"
  amount_eur               = local.env.budget.guardrailMonthlyEur
  thresholds_percent       = local.env.budget.thresholdsPercent
  notification_channel_ids = [google_monitoring_notification_channel.budget_email.name]
  pubsub_topic             = google_pubsub_topic.budget.id
}

# A one-shot synthetic Logging entry tests this exact email channel. The entry
# is a separately enumerated post-approval operator action, never sent by plan.
resource "google_monitoring_alert_policy" "channel_test" {
  depends_on            = [module.budget_alerts]
  project               = google_project.stage.project_id
  display_name          = "stage-budget-channel-delivery-test"
  combiner              = "OR"
  enabled               = true
  notification_channels = [google_monitoring_notification_channel.budget_email.name]
  conditions {
    display_name = "explicit synthetic delivery probe only"
    condition_matched_log {
      filter = "logName=\"projects/${var.project_id}/logs/stage-budget-channel-test\" AND jsonPayload.kind=\"n2b-email-delivery-probe\""
    }
  }
  alert_strategy {
    notification_rate_limit { period = "300s" }
    auto_close = "1800s"
  }
}

# Deferred until budget/channel have been created. This program only reads a
# private operator receipt; it cannot send mail, write cloud state or forge ack.
# The approved apply operator performs the separately enumerated delivery test
# and records the owner's actual acknowledgement while this gate waits.
data "external" "budget_delivery" {
  depends_on = [module.budget_alerts, google_monitoring_notification_channel.budget_email, google_pubsub_subscription.budget_evidence, google_monitoring_alert_policy.channel_test]
  program    = ["node", "${path.module}/../../../../scripts/wait-dev-budget-delivery.mjs"]
  query = {
    projectId        = google_project.stage.project_id
    budgetName       = module.budget_alerts.budget_name
    channelName      = google_monitoring_notification_channel.budget_email.name
    topicName        = google_pubsub_topic.budget.id
    subscriptionName = google_pubsub_subscription.budget_evidence.id
    receiptPath      = var.delivery_receipt_path
  }
}

resource "terraform_data" "budget_delivery_gate" {
  input = data.external.budget_delivery.result
  lifecycle {
    precondition {
      condition     = data.external.budget_delivery.result.status == "delivered-and-owner-acknowledged"
      error_message = "STOP: budget configuration, delivery test and owner acknowledgement have not passed. Ordinary resources remain absent."
    }
  }
}

module "state_bucket" {
  depends_on = [terraform_data.budget_delivery_gate]
  source     = "../../modules/state_bucket"
  enabled    = true
  labels     = local.labels
  project_id = google_project.stage.project_id
  location   = local.env.stateBucket.location
}

module "project_baseline" {
  depends_on = [module.state_bucket]
  source     = "../../modules/project_baseline"
  enabled    = true
  labels     = local.labels
  project_id = google_project.stage.project_id
  # Infrastructure only; no Functions/build/AI/provider/ingestion activation.
  services = toset(["firestore.googleapis.com", "storage.googleapis.com", "iam.googleapis.com", "firebase.googleapis.com"])
}

resource "google_firebase_project" "stage" {
  provider   = google-beta
  project    = google_project.stage.project_id
  depends_on = [module.project_baseline]
  lifecycle { prevent_destroy = true }
}

module "firestore" {
  depends_on             = [google_firebase_project.stage]
  source                 = "../../modules/firestore"
  enabled                = true
  labels                 = local.labels
  project_id             = google_project.stage.project_id
  location_id            = local.manifest.locationPolicy.firestore.location
  point_in_time_recovery = true
}

module "storage" {
  depends_on        = [module.project_baseline]
  source            = "../../modules/storage"
  enabled           = true
  labels            = local.labels
  project_id        = google_project.stage.project_id
  media_location    = local.manifest.locationPolicy.mediaStorage.location
  recovery_location = local.manifest.locationPolicy.recoveryStorage.location
  recovery_enabled  = false
}

module "runtime_identities" {
  depends_on       = [module.project_baseline]
  source           = "../../modules/runtime_identities"
  enabled          = true
  labels           = local.labels
  project_id       = google_project.stage.project_id
  service_accounts = local.env.serviceAccounts
}

module "ci_wif" {
  depends_on          = [module.project_baseline]
  source              = "../../modules/ci_wif"
  enabled             = true
  labels              = local.labels
  project_id          = google_project.stage.project_id
  pool_id             = local.env.workloadIdentity.poolName
  provider_id         = local.env.workloadIdentity.providerName
  repository_id       = null
  repository_owner_id = null
  environment_id      = "stage"
  project_number      = google_project.stage.number
  # Intentionally disabled trust; no bindings, keys, OIDC exchange or main bypass.
}

output "review_inventory" {
  value = {
    project_id        = google_project.stage.project_id
    project_number    = google_project.stage.number
    budget_name       = module.budget_alerts.budget_name
    topic_name        = google_pubsub_topic.budget.id
    subscription_name = google_pubsub_subscription.budget_evidence.id
    channel_name      = google_monitoring_notification_channel.budget_email.name
    wif_condition     = module.ci_wif.trust_condition
    apply_authorized  = false
  }
}
