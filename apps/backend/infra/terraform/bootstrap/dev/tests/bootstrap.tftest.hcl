# Offline mocked tests. This record is not owner consent or cloud evidence.
mock_provider "google" {
  mock_resource "google_project" { defaults = { number = "123456789012" } }
}
mock_provider "google" { alias = "budget" }
mock_provider "google-beta" {}
mock_provider "external" {}
variables {
  project_id                  = "recharge-dev-selftest0"
  billing_account_id          = "000000-000000-000000"
  notification_email          = "synthetic@example.invalid"
  authorization_record_path   = "tests/synthetic-plan-record.json"
  authorization_record_sha256 = filesha256("tests/synthetic-plan-record.json")
  manifest_sha256             = "e9f365d3cf585d826ac602deb72cf91fe50b744aa7e511f338bf9e4a9532199c"
  release_commit_sha          = "0000000000000000000000000000000000000000"
  delivery_receipt_path       = "tests/never-created-receipt.json"
}
run "full_graph" {
  command = plan
  override_data {
    target = data.external.budget_delivery
    values = { result = { status = "delivered-and-owner-acknowledged" } }
  }
  assert {
    condition     = google_firebase_project.dev.project == "recharge-dev-selftest0"
    error_message = "Firebase registration absent or wrong target."
  }
  assert {
    condition     = module.ci_wif.trust_condition == "false"
    error_message = "WIF must remain disabled."
  }
  assert {
    condition     = google_pubsub_topic_iam_member.budget_publisher.member == "serviceAccount:billing-budget-alert@system.gserviceaccount.com" && google_pubsub_topic_iam_member.budget_publisher.role == "roles/pubsub.publisher"
    error_message = "Only Cloud Billing may publish via this binding."
  }
  assert {
    condition     = google_pubsub_subscription.budget_evidence.message_retention_duration == "86400s"
    error_message = "Bounded evidence retention required."
  }
}
run "wif_stays_hard_denied" {
  command = plan
  assert {
    condition     = module.ci_wif.provider_disabled == true && module.ci_wif.provider_attribute_condition == "false && assertion.sub != ''" && module.ci_wif.trust_condition == "false"
    error_message = "Claim-referencing wire condition must remain identically false and provider disabled."
  }
}
run "wrong_billing_denied" {
  command = plan
  variables { billing_account_id = "111111-111111-111111" }
  expect_failures = [terraform_data.review_guard]
}
run "wrong_manifest_denied" {
  command = plan
  variables { manifest_sha256 = "wrong" }
  expect_failures = [terraform_data.review_guard]
}
run "missing_record_denied" {
  command = plan
  variables { authorization_record_path = "tests/absent.json" }
  expect_failures = [terraform_data.review_guard]
}
run "delivery_failure_denied" {
  command = apply
  override_data {
    target = data.external.budget_delivery
    values = { result = { status = "blocked" } }
  }
  expect_failures = [terraform_data.budget_delivery_gate]
}
