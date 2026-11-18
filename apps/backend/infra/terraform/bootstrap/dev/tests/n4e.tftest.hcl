# Offline mocked N4e tests (dev). Synthetic records are not owner consent or cloud evidence.
mock_provider "google" {
  mock_resource "google_project" { defaults = { number = "420479958348" } }
}
mock_provider "google" { alias = "budget" }
mock_provider "google-beta" {}
mock_provider "external" {}

override_data {
  target = data.external.budget_delivery
  values = { result = { status = "delivered-and-owner-acknowledged" } }
}

variables {
  project_id                      = "recharge-dev-n2a01"
  billing_account_id              = "000000-000000-000000"
  notification_email              = "synthetic@example.invalid"
  authorization_record_path       = "tests/synthetic-n2c-base-record.json"
  authorization_record_sha256     = filesha256("tests/synthetic-n2c-base-record.json")
  manifest_sha256                 = "9ff3f547118d045a571addbc494d1beed0fe34ca2ff6efadafb54a258e9bac39"
  release_commit_sha              = "0000000000000000000000000000000000000000"
  delivery_receipt_path           = "tests/never-created-receipt.json"
  n2c_enabled                     = true
  n2c_authorization_record_path   = "tests/synthetic-n2c-record.json"
  n2c_authorization_record_sha256 = filesha256("tests/synthetic-n2c-record.json")
  n3b_enabled                     = true
  n3b_image_digest                = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  n3b_operator_email              = "operator@example.invalid"
  n3b_authorization_record_path   = "tests/synthetic-n3b-phase2-record.json"
  n3b_authorization_record_sha256 = filesha256("tests/synthetic-n3b-phase2-record.json")
  n4c_authorization_record_path   = "tests/synthetic-n4c-record.json"
  n4c_authorization_record_sha256 = filesha256("tests/synthetic-n4c-record.json")
  n4c_enabled                     = true
  n4e_authorization_record_path   = "tests/synthetic-n4e-record.json"
  n4e_authorization_record_sha256 = filesha256("tests/synthetic-n4e-record.json")
}

run "n4e_absent_by_default" {
  command = plan
  assert {
    condition = (length(terraform_data.n4e_guard) + length(google_monitoring_custom_service.n4e)
      + length(google_monitoring_slo.n4e) + length(google_monitoring_alert_policy.n4e_fast_burn)
      + length(google_monitoring_alert_policy.n4e_slow_burn) + length(google_monitoring_uptime_check_config.n4e)
    + length(google_monitoring_alert_policy.n4e_probe) + length(google_monitoring_alert_policy.n4e_server_errors)) == 0
    error_message = "N4e creates nothing unless explicitly enabled."
  }
}

run "n4e_shape" {
  command = plan
  variables {
    n4e_enabled = true
  }
  assert {
    condition     = toset(keys(google_monitoring_slo.n4e)) == toset(["auth-availability", "commands-availability", "reads-availability", "commands-latency", "reads-latency"])
    error_message = "Five SLOs: availability of auth, commands and reads; latency of commands and reads."
  }
  assert {
    condition = (google_monitoring_slo.n4e["commands-availability"].goal == 0.999
      && google_monitoring_slo.n4e["reads-latency"].goal == 0.95
      && google_monitoring_slo.n4e["commands-latency"].request_based_sli[0].distribution_cut[0].range[0].max == 1500
      && google_monitoring_slo.n4e["reads-latency"].request_based_sli[0].distribution_cut[0].range[0].max == 750
    && google_monitoring_slo.n4e["auth-availability"].rolling_period_days == 28)
    error_message = "Goals and bounds follow the SLO model (99.9 %, p95 1.5 s / 750 ms, 28 days)."
  }
  assert {
    condition = (length(google_monitoring_alert_policy.n4e_fast_burn[0].conditions) == 3
      && length(google_monitoring_alert_policy.n4e_latency_fast_burn[0].conditions) == 2
      && google_monitoring_alert_policy.n4e_fast_burn[0].conditions[0].condition_threshold[0].threshold_value == 10
      && google_monitoring_alert_policy.n4e_fast_burn[0].conditions[0].condition_threshold[0].duration == "300s"
      && google_monitoring_alert_policy.n4e_slow_burn[0].conditions[0].condition_threshold[0].threshold_value == 2
    && google_monitoring_alert_policy.n4e_slow_burn[0].conditions[0].condition_threshold[0].duration == "7200s")
    error_message = "Fast burn 10x over 1 h held 5 min (availability Critical, latency Warning); slow burn 2x over 24 h held 2 h."
  }
  assert {
    condition = (length(google_monitoring_uptime_check_config.n4e) == 3
      && google_monitoring_uptime_check_config.n4e["booking"].content_matchers[0].content == "\"UNAUTHENTICATED\""
      && google_monitoring_uptime_check_config.n4e["booking"].http_check[0].accepted_response_status_codes[0].status_value == 401
    && google_monitoring_uptime_check_config.n4e["booking"].monitored_resource[0].labels.host == "europe-west1-recharge-dev-n2a01.cloudfunctions.net")
    error_message = "Three probes that expect the app's own 401 body for an invalid token."
  }
  assert {
    condition = (length(google_monitoring_alert_policy.n4e_fast_burn[0].notification_channels) == 1
      && length(google_monitoring_alert_policy.n4e_probe[0].notification_channels) == 1
      && google_monitoring_alert_policy.n4e_fast_burn[0].severity == "CRITICAL"
      && google_monitoring_alert_policy.n4e_probe[0].severity == "CRITICAL"
      && length(google_monitoring_alert_policy.n4e_latency_fast_burn[0].notification_channels) == 0
      && length(google_monitoring_alert_policy.n4e_slow_burn[0].notification_channels) == 0
    && length(google_monitoring_alert_policy.n4e_server_errors[0].notification_channels) == 0)
    error_message = "Owner e-mail only for Critical: probes and availability fast burn; the rest stays in Monitoring."
  }
}

run "n4e_round1_shape" {
  command = plan
  variables {
    n4e_enabled = true
  }
  assert {
    condition = (length(google_monitoring_alert_policy.n4e_budget_spent) == 2
      && google_monitoring_alert_policy.n4e_budget_spent["50"].conditions[0].condition_threshold[0].threshold_value == 0.5
      && google_monitoring_alert_policy.n4e_budget_spent["75"].conditions[0].condition_threshold[0].threshold_value == 0.25
    && length(google_monitoring_alert_policy.n4e_budget_spent["50"].conditions) == 5)
    error_message = "Two budget-spent policies (50 % and 75 % spent), one condition per SLO."
  }
  assert {
    condition = (length(google_monitoring_alert_policy.n4e_telemetry_absent[0].conditions) == 3
      && google_monitoring_alert_policy.n4e_telemetry_absent[0].conditions[0].condition_absent[0].duration == "1800s"
      && google_monitoring_alert_policy.n4e_telemetry_absent[0].conditions[0].condition_absent[0].aggregations[0].cross_series_reducer == "REDUCE_SUM"
      && length(google_monitoring_alert_policy.n4e_telemetry_absent[0].notification_channels) == 0
      && length(google_monitoring_alert_policy.n4e_budget_spent["75"].notification_channels) == 0
    && length(google_monitoring_alert_policy.n4e_media_tools) == 1)
    error_message = "Missing telemetry for both probed services (30 min) and the media tools failure alert."
  }
}

run "n4e_needs_booking" {
  command = plan
  variables {
    n4e_enabled = true
    n4c_enabled = false
  }
  expect_failures = [terraform_data.n4e_guard]
}

run "n4e_production_denied" {
  command = plan
  variables {
    n4e_enabled                     = true
    n4e_authorization_record_path   = "tests/synthetic-n4e-production-record.json"
    n4e_authorization_record_sha256 = filesha256("tests/synthetic-n4e-production-record.json")
  }
  expect_failures = [terraform_data.n4e_guard]
}

run "n4e_automatic_deletion_denied" {
  command = plan
  variables {
    n4e_enabled                     = true
    n4e_authorization_record_path   = "tests/synthetic-n4e-deletion-record.json"
    n4e_authorization_record_sha256 = filesha256("tests/synthetic-n4e-deletion-record.json")
  }
  expect_failures = [terraform_data.n4e_guard]
}

run "n4e_record_digest_denied" {
  command = plan
  variables {
    n4e_enabled                     = true
    n4e_authorization_record_sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
  }
  expect_failures = [terraform_data.n4e_guard]
}
