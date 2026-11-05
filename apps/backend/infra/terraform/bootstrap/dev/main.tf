# Single dev-only ownership root for the reviewed N2b bootstrap. Do not also
# apply envs/dev to this project/state. No runtime deployment or data seeding.
locals {
  manifest_path = "${path.module}/../../../../config/manifests/execution-manifest.json"
  manifest      = jsondecode(file(local.manifest_path))
  dev           = local.manifest.environments.dev
  approval      = try(jsondecode(file(var.authorization_record_path)), null)
  labels        = { application = "recharge", environment = "dev", managed_by = "terraform", stage = "n2b-bootstrap" }
  record_valid = try(
    local.approval.status == "approved"
    && local.approval.schemaVersion == 1
    && local.approval.environment == "dev"
    && local.approval.projectId == var.project_id
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

provider "google-beta" {
  project               = var.project_id
  region                = local.manifest.locationPolicy.functions.region
  user_project_override = false
}

resource "terraform_data" "review_guard" {
  input = "dev-review-only"
  lifecycle {
    precondition {
      condition     = local.record_valid && local.dev.budget.guardrailMonthlyEur == 5 && local.manifest.locationPolicy.recoveryStorage.state == "disabled"
      error_message = "Missing or mismatched dev-only plan record, budget or recovery scope."
    }
  }
}

resource "google_project" "dev" {
  depends_on          = [terraform_data.review_guard]
  project_id          = var.project_id
  name                = "Recharge dev"
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
  project            = google_project.dev.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_monitoring_notification_channel" "budget_email" {
  depends_on   = [google_project_service.cost_bootstrap]
  project      = google_project.dev.project_id
  display_name = "dev-budget-incident-email"
  type         = "email"
  labels       = { email_address = var.notification_email }
  lifecycle {
    prevent_destroy = true
  }
}

resource "google_pubsub_topic" "budget" {
  depends_on = [google_project_service.cost_bootstrap]
  project    = google_project.dev.project_id
  name       = "dev-budget-events"
  message_storage_policy { allowed_persistence_regions = ["europe-west1"] }
  lifecycle { prevent_destroy = true }
}
resource "google_pubsub_topic_iam_member" "budget_publisher" {
  project = google_project.dev.project_id
  topic   = google_pubsub_topic.budget.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:billing-budget-alerts@system.gserviceaccount.com"
}
resource "google_pubsub_subscription" "budget_evidence" {
  project                    = google_project.dev.project_id
  name                       = "dev-budget-evidence"
  topic                      = google_pubsub_topic.budget.id
  message_retention_duration = "86400s"
  expiration_policy { ttl = "" }
  lifecycle { prevent_destroy = true }
}

module "budget_alerts" {
  depends_on               = [google_pubsub_topic_iam_member.budget_publisher]
  source                   = "../../modules/budget_alerts"
  enabled                  = true
  labels                   = local.labels
  billing_account_id       = var.billing_account_id
  project_number           = google_project.dev.number
  display_name             = "budget-guardrail-dev"
  amount_eur               = local.dev.budget.guardrailMonthlyEur
  thresholds_percent       = local.dev.budget.thresholdsPercent
  notification_channel_ids = [google_monitoring_notification_channel.budget_email.name]
  pubsub_topic             = google_pubsub_topic.budget.id
}

# A one-shot synthetic Logging entry tests this exact email channel. The entry
# is a separately enumerated post-approval operator action, never sent by plan.
resource "google_monitoring_alert_policy" "channel_test" {
  depends_on            = [module.budget_alerts]
  project               = google_project.dev.project_id
  display_name          = "dev-budget-channel-delivery-test"
  combiner              = "OR"
  enabled               = true
  notification_channels = [google_monitoring_notification_channel.budget_email.name]
  conditions {
    display_name = "explicit synthetic delivery probe only"
    condition_matched_log {
      filter = "logName=\"projects/${var.project_id}/logs/dev-budget-channel-test\" AND jsonPayload.kind=\"n2b-email-delivery-probe\""
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
    projectId        = google_project.dev.project_id
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
  project_id = google_project.dev.project_id
  location   = local.dev.stateBucket.location
}

module "project_baseline" {
  depends_on = [module.state_bucket]
  source     = "../../modules/project_baseline"
  enabled    = true
  labels     = local.labels
  project_id = google_project.dev.project_id
  # Infrastructure only; no Functions/build/AI/provider/ingestion activation.
  services = toset(["firestore.googleapis.com", "storage.googleapis.com", "iam.googleapis.com", "firebase.googleapis.com"])
}

resource "google_firebase_project" "dev" {
  provider   = google-beta
  project    = google_project.dev.project_id
  depends_on = [module.project_baseline]
  lifecycle { prevent_destroy = true }
}

module "firestore" {
  depends_on             = [google_firebase_project.dev]
  source                 = "../../modules/firestore"
  enabled                = true
  labels                 = local.labels
  project_id             = google_project.dev.project_id
  location_id            = local.manifest.locationPolicy.firestore.location
  point_in_time_recovery = true
}

module "storage" {
  depends_on        = [module.project_baseline]
  source            = "../../modules/storage"
  enabled           = true
  labels            = local.labels
  project_id        = google_project.dev.project_id
  media_location    = local.manifest.locationPolicy.mediaStorage.location
  recovery_location = local.manifest.locationPolicy.recoveryStorage.location
  recovery_enabled  = false
}

module "runtime_identities" {
  depends_on       = [module.project_baseline]
  source           = "../../modules/runtime_identities"
  enabled          = true
  labels           = local.labels
  project_id       = google_project.dev.project_id
  service_accounts = local.dev.serviceAccounts
}

module "ci_wif" {
  depends_on          = [module.project_baseline]
  source              = "../../modules/ci_wif"
  enabled             = true
  labels              = local.labels
  project_id          = google_project.dev.project_id
  pool_id             = local.dev.workloadIdentity.poolName
  provider_id         = local.dev.workloadIdentity.providerName
  repository_id       = null
  repository_owner_id = null
  environment_id      = "dev"
  project_number      = google_project.dev.number
  # Intentionally disabled trust; no bindings, keys, OIDC exchange or main bypass.
}

output "review_inventory" {
  value = {
    project_id        = google_project.dev.project_id
    project_number    = google_project.dev.number
    budget_name       = module.budget_alerts.budget_name
    topic_name        = google_pubsub_topic.budget.id
    subscription_name = google_pubsub_subscription.budget_evidence.id
    channel_name      = google_monitoring_notification_channel.budget_email.name
    wif_condition     = module.ci_wif.trust_condition
    apply_authorized  = false
  }
}
