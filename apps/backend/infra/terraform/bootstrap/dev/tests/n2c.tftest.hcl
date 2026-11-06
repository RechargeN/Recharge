# Offline mocked N2c tests. Synthetic records are not owner consent or cloud evidence.
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
  manifest_sha256                 = "be112c05b5de0293573a899fd0ecd83e0aad08e81631c7e2c299e62010df230e"
  release_commit_sha              = "0000000000000000000000000000000000000000"
  delivery_receipt_path           = "tests/never-created-receipt.json"
  n2c_authorization_record_path   = "tests/synthetic-n2c-record.json"
  n2c_authorization_record_sha256 = filesha256("tests/synthetic-n2c-record.json")
}

run "n2c_absent_by_default" {
  command = plan
  variables {
    n2c_authorization_record_path   = ""
    n2c_authorization_record_sha256 = ""
  }
  assert {
    condition = (length(terraform_data.n2c_guard) + length(google_project_service.n2c) + length(google_identity_platform_config.n2c)
      + length(google_apikeys_key.n2c_android) + length(google_firebase_android_app.n2c_dev) + length(google_project_iam_member.n2c_runtime_auth)
      + length(google_project_iam_member.n2c_runtime_database) + length(google_project_iam_member.n2c_build_logging)
    + length(google_project_iam_member.n2c_build_source) + length(google_artifact_registry_repository_iam_member.n2c_build_artifacts)) == 0
    error_message = "N2c must create nothing unless explicitly enabled."
  }
  assert {
    condition     = length(module.n2c_secret.secret_ids) == 0
    error_message = "No secret container without N2c."
  }
}

run "n2c_registration_shape" {
  command = plan
  variables {
    n2c_enabled = true
  }
  assert {
    condition     = toset(keys(google_project_service.n2c)) == toset(["apikeys.googleapis.com", "artifactregistry.googleapis.com", "cloudbuild.googleapis.com", "cloudfunctions.googleapis.com", "firebaseappcheck.googleapis.com", "run.googleapis.com", "secretmanager.googleapis.com"])
    error_message = "Exactly the reviewed N2c APIs."
  }
  assert {
    condition = (google_identity_platform_config.n2c[0].sign_in[0].email[0].enabled == false
      && google_identity_platform_config.n2c[0].sign_in[0].anonymous[0].enabled == false
    && google_identity_platform_config.n2c[0].sign_in[0].phone_number[0].enabled == false)
    error_message = "Email, anonymous and phone (SMS cost) sign-in stay disabled."
  }
  assert {
    condition = (google_apikeys_key.n2c_android[0].restrictions[0].android_key_restrictions[0].allowed_applications[0].package_name == "com.recharge.app.recharge.dev"
      && google_apikeys_key.n2c_android[0].restrictions[0].android_key_restrictions[0].allowed_applications[0].sha1_fingerprint == "2667b9c54eaaa70e8955035058928b1d5501ae88"
      && length(google_apikeys_key.n2c_android[0].restrictions[0].android_key_restrictions[0].allowed_applications) == 1
    && toset([for t in google_apikeys_key.n2c_android[0].restrictions[0].api_targets : t.service]) == toset(["firebaseappcheck.googleapis.com", "firebaseinstallations.googleapis.com", "identitytoolkit.googleapis.com", "securetoken.googleapis.com"]))
    error_message = "API key restricted to the dev package, debug SHA-1 and client Firebase APIs."
  }
  assert {
    condition = (google_firebase_android_app.n2c_dev[0].package_name == "com.recharge.app.recharge.dev"
      && tolist(google_firebase_android_app.n2c_dev[0].sha1_hashes) == tolist(["2667b9c54eaaa70e8955035058928b1d5501ae88"])
    && tolist(google_firebase_android_app.n2c_dev[0].sha256_hashes) == tolist(["23b74a246731835937d3feccb11ba3d39092315e4c2e945b5c715e7b124cae17"]))
    error_message = "Android app binds the dev package and debug certificate (lowercase hex)."
  }
  assert {
    condition = (google_project_iam_member.n2c_build_logging[0].member == "serviceAccount:420479958348-compute@developer.gserviceaccount.com"
      && google_project_iam_member.n2c_build_source[0].role == "roles/storage.objectViewer"
      && google_project_iam_member.n2c_build_source[0].condition[0].expression == "resource.name.startsWith(\"projects/_/buckets/gcf-v2-sources-420479958348-europe-west1\")"
      && google_artifact_registry_repository_iam_member.n2c_build_artifacts[0].repository == "gcf-artifacts"
      && google_artifact_registry_repository_iam_member.n2c_build_artifacts[0].location == "europe-west1"
      && google_artifact_registry_repository_iam_member.n2c_build_artifacts[0].role == "roles/artifactregistry.writer"
    && google_artifact_registry_repository_iam_member.n2c_build_artifacts[0].member == "serviceAccount:420479958348-compute@developer.gserviceaccount.com")
    error_message = "Build account gets only three narrow build roles (source bucket condition, gcf-artifacts repository)."
  }
  assert {
    condition     = tolist(module.n2c_secret.secret_ids) == tolist(["DEV_AUTH_INGRESS_HMAC"])
    error_message = "Only the ingress secret container, never a value."
  }
  assert {
    condition     = toset(google_project_iam_custom_role.n2c_auth_verify[0].permissions) == toset(["firebaseauth.users.get"])
    error_message = "Runtime Firebase permission is user read only."
  }
  assert {
    condition     = google_project_iam_member.n2c_runtime_database[0].condition[0].expression == "resource.name == \"projects/recharge-dev-n2a01/databases/(default)\""
    error_message = "Session data access is scoped to the default database."
  }
}

run "n2c_wrong_stage_denied" {
  command = plan
  variables {
    n2c_enabled                     = true
    n2c_authorization_record_path   = "tests/synthetic-n2c-wrong-stage-record.json"
    n2c_authorization_record_sha256 = filesha256("tests/synthetic-n2c-wrong-stage-record.json")
  }
  expect_failures = [terraform_data.n2c_guard]
}

run "n2c_app_check_enforcement_denied" {
  command = plan
  variables {
    n2c_enabled                     = true
    n2c_authorization_record_path   = "tests/synthetic-n2c-enforce-record.json"
    n2c_authorization_record_sha256 = filesha256("tests/synthetic-n2c-enforce-record.json")
  }
  expect_failures = [terraform_data.n2c_guard]
}

run "n2c_record_digest_denied" {
  command = plan
  variables {
    n2c_enabled                     = true
    n2c_authorization_record_sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
  }
  expect_failures = [terraform_data.n2c_guard]
}

run "n2c_other_project_denied" {
  command = plan
  variables {
    project_id                  = "recharge-dev-selftest0"
    authorization_record_path   = "tests/synthetic-plan-record.json"
    authorization_record_sha256 = filesha256("tests/synthetic-plan-record.json")
    n2c_enabled                 = true
  }
  expect_failures = [terraform_data.n2c_guard]
}
