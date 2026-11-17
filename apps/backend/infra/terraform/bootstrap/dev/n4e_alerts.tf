# N4e: service monitoring for dev, the same set as staging (owner-approved debt plan 2026-11-17).
# Request-based SLOs over the Cloud Run metrics of the deployed Functions,
# fast and slow burn-rate alerts, two synthetic uptime probes and one log alert
# for server-side failures. Everything notifies the existing staging e-mail
# channel. Monitoring only: no IAM, no data, nothing that changes the runtime.
# Numbers follow BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md (BCK05-OD-03,
# Proposed) and docs/runbooks/staging-monitoring-alerts-cost.md.
# Behind var.n4e_enabled and a separate owner-issued N4e record.
locals {
  n4e_on       = var.n4e_enabled
  n4e_approval = try(jsondecode(file(var.n4e_authorization_record_path)), null)
  n4e_record_valid = try(
    local.n4e_approval.status == "approved"
    && local.n4e_approval.schemaVersion == 1
    && local.n4e_approval.stage == "n4e"
    && local.n4e_approval.environment == "dev"
    && local.n4e_approval.projectId == var.project_id
    && var.project_id == local.n2c_project
    && local.n4e_approval.commitSha == var.release_commit_sha
    && local.n4e_approval.manifestSha256 == filesha256(local.manifest_path)
    && var.n4e_authorization_record_sha256 == filesha256(var.n4e_authorization_record_path)
    && local.n4e_approval.operations == ["plan"]
    && length(local.n4e_approval.ownerApprovalEvidenceRef) > 0
    && local.n4e_approval.dataScope == "synthetic"
    && local.n4e_approval.automaticDeletion == false
    && local.n4e_approval.push == false && local.n4e_approval.merge == false
    && local.n4e_approval.marketActivation == false
    && local.n4e_approval.production == false
    && timecmp(local.n4e_approval.issuedAtUtc, plantimestamp()) <= 0
    && timecmp(local.n4e_approval.expiresAtUtc, plantimestamp()) > 0,
    false
  )

  # Cloud Run service names of the deployed Functions (lower-case function names).
  # Excluded: bookingloadv1 (synthetic load ingress) and reconcilepushv1 (scheduler).
  n4e_journeys = {
    auth = ["establishidentitysessionv1", "refreshidentitysessionv1", "recoveridentitysessionsv1",
    "revokeidentitysessionv1", "readidentitysessionv1"]
    commands = ["createinternalbookingv1", "cancelinternalbookingv1", "reconfirminternalbookingv1",
      "contentcommandv1", "mediacommandv1", "uploadmediabytesv1", "notificationscommandv1",
    "pushdevicecommandv1", "sendselftestnotificationv1"]
    reads = ["getmybookingv1", "listmybookingsv1", "geteventavailabilityv1", "contentqueryv1",
    "mediaqueryv1", "notificationsqueryv1"]
  }
  n4e_service_filter = {
    for journey, services in local.n4e_journeys :
    journey => "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=one_of(${join(",", [for s in services : "\"${s}\""])})"
  }
  # Availability: 5xx and 429 (instance limit reached) are bad; 4xx such as 401 is
  # the service answering correctly.
  n4e_availability = {
    for journey in keys(local.n4e_journeys) : journey => {
      total = "metric.type=\"run.googleapis.com/request_count\" AND ${local.n4e_service_filter[journey]}"
      bad   = "metric.type=\"run.googleapis.com/request_count\" AND ${local.n4e_service_filter[journey]} AND (metric.labels.response_code_class=\"5xx\" OR metric.labels.response_code=\"429\")"
    }
  }
  # Latency: share of requests under the p95 bound of the SLO model.
  n4e_latency = {
    commands = 1500
    reads    = 750
  }
  n4e_slos = merge(
    { for j in keys(local.n4e_journeys) : "${j}-availability" => { kind = "availability", journey = j, goal = 0.999 } },
    { for j, ms in local.n4e_latency : "${j}-latency" => { kind = "latency", journey = j, goal = 0.95, max_ms = ms } },
  )
  n4e_probe_host = "europe-west1-${local.n2c_project}.cloudfunctions.net"
  n4e_probes = {
    booking = { path = "/createInternalBookingV1", headers = { Authorization = "Bearer n4e-uptime-invalid-token" } }
    session = { path = "/readIdentitySessionV1", headers = { Authorization = "Bearer n4e-uptime-invalid-token", "X-Recharge-Identity-Provider" = "google" } }
  }
  n4e_runbook = "Runbook: docs/runbooks/staging-monitoring-alerts-cost.md (dev and staging; budget alerts do not cap spend)."
}

resource "terraform_data" "n4e_guard" {
  count = local.n4e_on ? 1 : 0
  input = "n4e-dev-monitoring"
  lifecycle {
    precondition {
      condition     = local.n4e_record_valid
      error_message = "Missing or mismatched N4e record (stage, project, commit, manifest, scope or expiry)."
    }
    precondition {
      condition     = local.n2c_on && local.n4c_on
      error_message = "N4e monitors the deployed identity and Booking runtimes (N2c and N4c)."
    }
  }
}

resource "google_monitoring_custom_service" "n4e" {
  count        = local.n4e_on ? 1 : 0
  depends_on   = [terraform_data.n4e_guard]
  project      = google_project.dev.project_id
  service_id   = "recharge-dev-functions"
  display_name = "Recharge dev Functions"
}

resource "google_monitoring_slo" "n4e" {
  for_each            = local.n4e_on ? local.n4e_slos : {}
  project             = google_project.dev.project_id
  service             = google_monitoring_custom_service.n4e[0].service_id
  slo_id              = each.key
  display_name        = "${each.key} (${each.value.goal * 100} %, rolling 28 days)"
  goal                = each.value.goal
  rolling_period_days = 28

  request_based_sli {
    dynamic "good_total_ratio" {
      for_each = each.value.kind == "availability" ? [1] : []
      content {
        total_service_filter = local.n4e_availability[each.value.journey].total
        bad_service_filter   = local.n4e_availability[each.value.journey].bad
      }
    }
    dynamic "distribution_cut" {
      for_each = each.value.kind == "latency" ? [1] : []
      content {
        distribution_filter = "metric.type=\"run.googleapis.com/request_latencies\" AND ${local.n4e_service_filter[each.value.journey]}"
        range {
          max = each.value.max_ms
        }
      }
    }
  }
}

# Fast burn: 10x the sustainable rate over one hour, held for 5 minutes.
resource "google_monitoring_alert_policy" "n4e_fast_burn" {
  count                 = local.n4e_on ? 1 : 0
  project               = google_project.dev.project_id
  display_name          = "dev-slo-fast-burn"
  combiner              = "OR"
  enabled               = true
  severity              = "CRITICAL"
  notification_channels = [google_monitoring_notification_channel.budget_email.name]
  dynamic "conditions" {
    for_each = local.n4e_slos
    content {
      display_name = "${conditions.key} burn >= 10x over 1 h"
      condition_threshold {
        filter          = "select_slo_burn_rate(\"${google_monitoring_slo.n4e[conditions.key].name}\", \"3600s\")"
        comparison      = "COMPARISON_GT"
        threshold_value = 10
        duration        = "300s"
      }
    }
  }
  alert_strategy {
    auto_close = "3600s"
  }
  documentation {
    content   = "Fast error-budget burn. Stop releases and assess as an incident. ${local.n4e_runbook}"
    mime_type = "text/markdown"
  }
}

# Slow burn: 2x the sustainable rate over 24 hours, held for 2 hours.
resource "google_monitoring_alert_policy" "n4e_slow_burn" {
  count                 = local.n4e_on ? 1 : 0
  project               = google_project.dev.project_id
  display_name          = "dev-slo-slow-burn"
  combiner              = "OR"
  enabled               = true
  severity              = "WARNING"
  notification_channels = [google_monitoring_notification_channel.budget_email.name]
  dynamic "conditions" {
    for_each = local.n4e_slos
    content {
      display_name = "${conditions.key} burn >= 2x over 24 h"
      condition_threshold {
        filter          = "select_slo_burn_rate(\"${google_monitoring_slo.n4e[conditions.key].name}\", \"86400s\")"
        comparison      = "COMPARISON_GT"
        threshold_value = 2
        duration        = "7200s"
      }
    }
  }
  alert_strategy {
    auto_close = "86400s"
  }
  documentation {
    content   = "Slow error-budget burn. Open an owned task and review the next release. ${local.n4e_runbook}"
    mime_type = "text/markdown"
  }
}

# Synthetic probes: an invalid token must get 401. This is the low-traffic
# signal of the SLO model (synthetic evidence when real traffic is too low).
resource "google_monitoring_uptime_check_config" "n4e" {
  for_each         = local.n4e_on ? local.n4e_probes : {}
  depends_on       = [terraform_data.n4e_guard]
  project          = google_project.dev.project_id
  display_name     = "dev-probe-${each.key}"
  timeout          = "10s"
  period           = "300s"
  selected_regions = ["EUROPE", "USA_VIRGINIA", "USA_OREGON"]

  http_check {
    path                = each.value.path
    port                = 443
    use_ssl             = true
    validate_ssl        = true
    request_method      = "POST"
    content_type        = "USER_PROVIDED"
    custom_content_type = "application/json"
    body                = base64encode("{\"data\":{}}")
    headers             = each.value.headers
    mask_headers        = true
    accepted_response_status_codes {
      status_value = 401
    }
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = google_project.dev.project_id
      host       = local.n4e_probe_host
    }
  }

  # mask_headers makes the API return "******" for every header, so Terraform
  # would rewrite the headers on every plan. They hold no secret (an invalid
  # token by design); changes to them go through a new resource version.
  lifecycle {
    ignore_changes = [http_check[0].headers]
  }
}

resource "google_monitoring_alert_policy" "n4e_probe" {
  count                 = local.n4e_on ? 1 : 0
  project               = google_project.dev.project_id
  display_name          = "dev-probe-failed"
  combiner              = "OR"
  enabled               = true
  severity              = "ERROR"
  notification_channels = [google_monitoring_notification_channel.budget_email.name]
  dynamic "conditions" {
    for_each = google_monitoring_uptime_check_config.n4e
    content {
      display_name = "${conditions.key} probe fails in more than one region"
      condition_threshold {
        filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND metric.labels.check_id=\"${conditions.value.uptime_check_id}\""
        comparison      = "COMPARISON_GT"
        threshold_value = 1
        duration        = "600s"
        aggregations {
          alignment_period     = "1200s"
          per_series_aligner   = "ALIGN_NEXT_OLDER"
          cross_series_reducer = "REDUCE_COUNT_FALSE"
          group_by_fields      = ["resource.label.*"]
        }
      }
    }
  }
  alert_strategy {
    auto_close = "1800s"
  }
  documentation {
    content   = "A dev Function stopped answering 401 to an invalid token (503 means the runtime is off or failing). ${local.n4e_runbook}"
    mime_type = "text/markdown"
  }
}

# Server-side failures: error logs and the closed-fail markers of the cloud
# entries (`dev_*_failure`, logged when a request ends in 503).
resource "google_monitoring_alert_policy" "n4e_server_errors" {
  count                 = local.n4e_on ? 1 : 0
  project               = google_project.dev.project_id
  display_name          = "dev-server-errors"
  combiner              = "OR"
  enabled               = true
  severity              = "ERROR"
  notification_channels = [google_monitoring_notification_channel.budget_email.name]
  conditions {
    display_name = "error log or closed-fail marker in a Cloud Run service"
    condition_matched_log {
      filter = "resource.type=\"cloud_run_revision\" AND (severity>=ERROR OR jsonPayload.message=~\"^dev_[a-z0-9_]+_failure$\")"
    }
  }
  alert_strategy {
    notification_rate_limit { period = "1800s" }
    auto_close = "1800s"
  }
  documentation {
    content   = "Server-side failure in dev (also the signal for a suspected invariant breach). ${local.n4e_runbook}"
    mime_type = "text/markdown"
  }
}

# ---- N4e round 1 (owner-approved debt plan 2026-11-17) ----

# Error budget consumed: remaining fraction below 50 % and below 25 % (75 % spent).
resource "google_monitoring_alert_policy" "n4e_budget_spent" {
  for_each              = local.n4e_on ? { "50" = 0.5, "75" = 0.25 } : {}
  project               = google_project.dev.project_id
  display_name          = "dev-slo-budget-${each.key}-percent-spent"
  combiner              = "OR"
  enabled               = true
  severity              = each.key == "75" ? "ERROR" : "WARNING"
  notification_channels = [google_monitoring_notification_channel.budget_email.name]
  dynamic "conditions" {
    for_each = local.n4e_slos
    content {
      display_name = "${conditions.key} error budget ${each.key} % spent"
      condition_threshold {
        filter          = "select_slo_budget_fraction(\"${google_monitoring_slo.n4e[conditions.key].name}\")"
        comparison      = "COMPARISON_LT"
        threshold_value = each.value
        duration        = "0s"
      }
    }
  }
  alert_strategy {
    auto_close = "86400s"
  }
  documentation {
    content   = "Error budget ${each.key} % spent: ${each.key == "75" ? "reliability work only, except approved safety and security fixes" : "no expansion and no risky flags for that journey"}. ${local.n4e_runbook}"
    mime_type = "text/markdown"
  }
}

# Missing telemetry: the probes call these two services every 5 minutes, so no
# request metric for 30 minutes means the probes or the metric pipeline stopped.
resource "google_monitoring_alert_policy" "n4e_telemetry_absent" {
  count                 = local.n4e_on ? 1 : 0
  project               = google_project.dev.project_id
  display_name          = "dev-telemetry-absent"
  combiner              = "OR"
  enabled               = true
  severity              = "ERROR"
  notification_channels = [google_monitoring_notification_channel.budget_email.name]
  dynamic "conditions" {
    for_each = toset(["createinternalbookingv1", "readidentitysessionv1"])
    content {
      display_name = "no request metric from ${conditions.value} for 30 min"
      condition_absent {
        filter   = "metric.type=\"run.googleapis.com/request_count\" AND resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${conditions.value}\""
        duration = "1800s"
        aggregations {
          alignment_period   = "300s"
          per_series_aligner = "ALIGN_SUM"
        }
      }
    }
  }
  alert_strategy {
    auto_close = "3600s"
  }
  documentation {
    content   = "No telemetry: a monitoring incident, never a green status. ${local.n4e_runbook}"
    mime_type = "text/markdown"
  }
}

# Media scanner/processor failures (database absent, crash): covers quarantined uploads.
resource "google_monitoring_alert_policy" "n4e_media_tools" {
  count                 = local.n4e_on ? 1 : 0
  project               = google_project.dev.project_id
  display_name          = "dev-media-tools-failure"
  combiner              = "OR"
  enabled               = true
  severity              = "ERROR"
  notification_channels = [google_monitoring_notification_channel.budget_email.name]
  conditions {
    display_name = "media tools request with a failure class"
    condition_matched_log {
      filter = "resource.type=\"cloud_run_revision\" AND jsonPayload.kind=\"media-tools-request\" AND jsonPayload.failureClass:*"
    }
  }
  alert_strategy {
    notification_rate_limit { period = "3600s" }
    auto_close = "3600s"
  }
  documentation {
    content   = "Scanner or processor failure (no signature database or crash): uploads go to quarantine. Run the mirror job, then retryProcessing. ${local.n4e_runbook}"
    mime_type = "text/markdown"
  }
}

