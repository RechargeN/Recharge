# Offline mocked N3a.2 tests. Synthetic records are not owner consent or cloud evidence.
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
  project_id                       = "recharge-dev-n2a01"
  billing_account_id               = "000000-000000-000000"
  notification_email               = "synthetic@example.invalid"
  authorization_record_path        = "tests/synthetic-n2c-base-record.json"
  authorization_record_sha256      = filesha256("tests/synthetic-n2c-base-record.json")
  manifest_sha256                  = "8733c3bf3d8c87fc4d598bd8f8731666a9f98d17d0c82beee54e0be91bc4af19"
  release_commit_sha               = "0000000000000000000000000000000000000000"
  delivery_receipt_path            = "tests/never-created-receipt.json"
  n2c_enabled                      = true
  n2c_authorization_record_path    = "tests/synthetic-n2c-record.json"
  n2c_authorization_record_sha256  = filesha256("tests/synthetic-n2c-record.json")
  n3b_enabled                      = true
  n3b_image_digest                 = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  n3b_operator_email               = "operator@example.invalid"
  n3b_authorization_record_path    = "tests/synthetic-n3b-phase2-record.json"
  n3b_authorization_record_sha256  = filesha256("tests/synthetic-n3b-phase2-record.json")
  n3a2_authorization_record_path   = "tests/synthetic-n3a2-record.json"
  n3a2_authorization_record_sha256 = filesha256("tests/synthetic-n3a2-record.json")
}

run "n3a2_absent_by_default" {
  command = plan
  assert {
    condition = (length(terraform_data.n3a2_guard) + length(google_project_iam_custom_role.n3a2_data)
      + length(google_project_iam_custom_role.n3a2_objects) + length(google_project_iam_member.n3a2_data)
      + length(google_storage_bucket_iam_member.n3a2_objects) + length(google_project_iam_member.n3a2_auth)
    + length(google_secret_manager_secret_iam_member.n3a2_tools_token) + length(google_cloud_run_v2_service_iam_member.n3a2_invoker)) == 0
    error_message = "N3a.2 grants nothing unless explicitly enabled."
  }
}

run "n3a2_grants_shape" {
  command = plan
  variables {
    n3a2_enabled = true
  }
  assert {
    condition = (toset(google_project_iam_custom_role.n3a2_data[0].permissions) == toset(["datastore.databases.get", "datastore.entities.create", "datastore.entities.get", "datastore.entities.list", "datastore.entities.update"])
    && toset(google_project_iam_custom_role.n3a2_objects[0].permissions) == toset(["storage.objects.create", "storage.objects.get"]))
    error_message = "Records and objects: create/read/update only, never delete."
  }
  assert {
    condition = (google_project_iam_member.n3a2_data[0].member == "serviceAccount:runtime-media@recharge-dev-n2a01.iam.gserviceaccount.com"
      && google_project_iam_member.n3a2_data[0].condition[0].expression == "resource.name == \"projects/recharge-dev-n2a01/databases/(default)\""
      && google_storage_bucket_iam_member.n3a2_objects[0].bucket == "recharge-dev-n2a01-media"
      && google_project_iam_member.n3a2_auth[0].role == "projects/recharge-dev-n2a01/roles/devIdentityFirebaseVerifier"
    && google_secret_manager_secret_iam_member.n3a2_tools_token[0].secret_id == "MEDIA_TOOLS_TOKEN")
    error_message = "Exact runtime-media grants on the default database, the media bucket and the tools secret."
  }
  assert {
    condition     = toset(keys(google_cloud_run_v2_service_iam_member.n3a2_invoker)) == toset(["media-scanner", "media-processor"]) && alltrue([for m in google_cloud_run_v2_service_iam_member.n3a2_invoker : m.role == "roles/run.invoker" && m.member == "serviceAccount:runtime-media@recharge-dev-n2a01.iam.gserviceaccount.com"])
    error_message = "runtime-media may invoke the two tool services only."
  }
}

run "n3a2_needs_n3b_services" {
  command = plan
  variables {
    n3a2_enabled                    = true
    n3b_image_digest                = ""
    n3b_authorization_record_path   = "tests/synthetic-n3b-record.json"
    n3b_authorization_record_sha256 = filesha256("tests/synthetic-n3b-record.json")
  }
  expect_failures = [terraform_data.n3a2_guard]
}

run "n3a2_publication_denied" {
  command = plan
  variables {
    n3a2_enabled                     = true
    n3a2_authorization_record_path   = "tests/synthetic-n3a2-publication-record.json"
    n3a2_authorization_record_sha256 = filesha256("tests/synthetic-n3a2-publication-record.json")
  }
  expect_failures = [terraform_data.n3a2_guard]
}

run "n3a2_record_digest_denied" {
  command = plan
  variables {
    n3a2_enabled                     = true
    n3a2_authorization_record_sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
  }
  expect_failures = [terraform_data.n3a2_guard]
}
