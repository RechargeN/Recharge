# Offline mocked N3c tests. Synthetic records are not owner consent or cloud evidence.
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
  n3c_authorization_record_path   = "tests/synthetic-n3c-record.json"
  n3c_authorization_record_sha256 = filesha256("tests/synthetic-n3c-record.json")
}

run "n3c_absent_by_default" {
  command = plan
  assert {
    condition = (length(terraform_data.n3c_guard) + length(google_project_iam_custom_role.n3c_data)
      + length(google_project_iam_custom_role.n3c_fcm) + length(google_project_iam_member.n3c_data)
    + length(google_project_iam_member.n3c_fcm) + length(google_project_iam_member.n3c_auth)) == 0
    error_message = "N3c grants nothing unless explicitly enabled."
  }
}

run "n3c_grants_shape" {
  command = plan
  variables {
    n3c_enabled = true
  }
  assert {
    condition = (toset(google_project_iam_custom_role.n3c_data[0].permissions) == toset(["datastore.databases.get", "datastore.entities.create", "datastore.entities.get", "datastore.entities.list", "datastore.entities.update"])
    && toset(google_project_iam_custom_role.n3c_fcm[0].permissions) == toset(["cloudmessaging.messages.create"]))
    error_message = "Records create/read/update only, never delete; FCM send only."
  }
  assert {
    condition = (google_project_iam_member.n3c_data[0].member == "serviceAccount:runtime-notifications@recharge-dev-n2a01.iam.gserviceaccount.com"
      && google_project_iam_member.n3c_data[0].condition[0].expression == "resource.name == \"projects/recharge-dev-n2a01/databases/(default)\""
      && google_project_iam_member.n3c_fcm[0].role == "projects/recharge-dev-n2a01/roles/devNotificationsFcmSender"
      && google_project_iam_member.n3c_fcm[0].member == "serviceAccount:runtime-notifications@recharge-dev-n2a01.iam.gserviceaccount.com"
    && google_project_iam_member.n3c_auth[0].role == "projects/recharge-dev-n2a01/roles/devIdentityFirebaseVerifier")
    error_message = "Exact runtime-notifications grants on the default database, FCM and the Firebase user reader."
  }
  assert {
    condition     = contains(module.runtime_identities.account_names, "runtime-notifications")
    error_message = "The manifest runtime-notifications identity is created."
  }
}

run "n3c_needs_n2c" {
  command = plan
  variables {
    n3c_enabled = true
    n2c_enabled = false
    n3b_enabled = false
  }
  expect_failures = [terraform_data.n3c_guard]
}

run "n3c_production_denied" {
  command = plan
  variables {
    n3c_enabled                     = true
    n3c_authorization_record_path   = "tests/synthetic-n3c-production-record.json"
    n3c_authorization_record_sha256 = filesha256("tests/synthetic-n3c-production-record.json")
  }
  expect_failures = [terraform_data.n3c_guard]
}

run "n3c_automatic_deletion_denied" {
  command = plan
  variables {
    n3c_enabled                     = true
    n3c_authorization_record_path   = "tests/synthetic-n3c-deletion-record.json"
    n3c_authorization_record_sha256 = filesha256("tests/synthetic-n3c-deletion-record.json")
  }
  expect_failures = [terraform_data.n3c_guard]
}

run "n3c_record_digest_denied" {
  command = plan
  variables {
    n3c_enabled                     = true
    n3c_authorization_record_sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
  }
  expect_failures = [terraform_data.n3c_guard]
}
