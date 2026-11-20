# Offline mocked N3b tests. Synthetic records are not owner consent or cloud evidence.
mock_provider "google" {
  mock_resource "google_project" {
    defaults        = { number = "420479958348" }
    override_during = plan
  }
}
mock_provider "google" { alias = "budget" }
mock_provider "google-beta" {}
mock_provider "external" {}

override_data {
  target = data.external.budget_delivery
  values = { result = { status = "delivered-and-owner-acknowledged" } }
}

variables {
  project_id                      = "recharge-staging-y9y2y"
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
  n3b_authorization_record_path   = "tests/synthetic-n3b-record.json"
  n3b_authorization_record_sha256 = filesha256("tests/synthetic-n3b-record.json")
}

run "n3b_absent_by_default" {
  command = plan
  assert {
    condition = (length(terraform_data.n3b_guard) + length(google_project_service.n3b) + length(google_service_account.n3b)
      + length(google_artifact_registry_repository.n3b_media_tools) + length(google_storage_bucket.n3b_clamav_mirror)
      + length(google_storage_bucket.n3b_build_staging) + length(google_project_iam_custom_role.n3b_mirror_writer)
      + length(google_project_iam_member.n3b_build_logging) + length(google_artifact_registry_repository_iam_member.n3b_build_push)
      + length(google_storage_bucket_iam_member.n3b_build_source) + length(google_storage_bucket_iam_member.n3b_scanner_mirror)
      + length(google_storage_bucket_iam_member.n3b_mirror_writer) + length(google_secret_manager_secret_iam_member.n3b_token)
      + length(google_cloud_run_v2_service.n3b) + length(google_cloud_run_v2_service_iam_member.n3b_operator)
    + length(google_cloud_run_v2_job.n3b_mirror) + length(google_cloud_scheduler_job.n3b_mirror)) == 0
    error_message = "N3b must create nothing unless explicitly enabled."
  }
  assert {
    condition     = length(module.n3b_secret.secret_ids) == 0
    error_message = "No N3b secret container without N3b."
  }
}

run "n3b_phase1_shape" {
  command = plan
  variables {
    n3b_enabled = true
  }
  assert {
    condition     = length(google_cloud_run_v2_service.n3b) + length(google_cloud_run_v2_job.n3b_mirror) + length(google_cloud_scheduler_job.n3b_mirror) + length(google_cloud_run_v2_service_iam_member.n3b_operator) == 0
    error_message = "Phase 1 has no services, job or schedule (no image digest yet)."
  }
  assert {
    condition     = toset(keys(google_service_account.n3b)) == toset(["media-tools-build", "media-tools-scanner", "media-tools-processor", "clamav-mirror"]) && alltrue([for a in google_service_account.n3b : a.deletion_policy == "PREVENT"])
    error_message = "Exactly the four N3b identities, never deleted by Terraform."
  }
  assert {
    condition     = toset(keys(google_project_service.n3b)) == toset(["cloudscheduler.googleapis.com"])
    error_message = "Only Cloud Scheduler is new; the other APIs belong to N2c."
  }
  assert {
    condition = (google_artifact_registry_repository.n3b_media_tools[0].repository_id == "media-tools"
      && google_artifact_registry_repository.n3b_media_tools[0].location == "europe-west1"
      && google_artifact_registry_repository.n3b_media_tools[0].docker_config[0].immutable_tags == true
      && length(google_artifact_registry_repository.n3b_media_tools[0].cleanup_policies) == 0
    && google_artifact_registry_repository.n3b_media_tools[0].vulnerability_scanning_config[0].enablement_config == "DISABLED")
    error_message = "Repository: immutable tags, no cleanup (D-07), no paid scanning."
  }
  assert {
    condition = alltrue([for b in [google_storage_bucket.n3b_clamav_mirror[0], google_storage_bucket.n3b_build_staging[0]] :
      b.public_access_prevention == "enforced" && b.uniform_bucket_level_access == true && b.force_destroy == false
    && length(b.lifecycle_rule) == 0 && b.location == "EUROPE-WEST1" && b.deletion_policy == "PREVENT"])
    error_message = "Private, uniform, regional buckets without lifecycle deletion."
  }
  assert {
    condition     = toset(google_project_iam_custom_role.n3b_mirror_writer[0].permissions) == toset(["storage.objects.create", "storage.objects.get", "storage.objects.list"])
    error_message = "The mirror job can create and read, never overwrite or delete."
  }
  assert {
    condition = (google_project_iam_member.n3b_build_logging[0].role == "roles/logging.logWriter"
      && google_project_iam_member.n3b_build_logging[0].member == "serviceAccount:media-tools-build@recharge-staging-y9y2y.iam.gserviceaccount.com"
      && google_artifact_registry_repository_iam_member.n3b_build_push[0].role == "roles/artifactregistry.writer"
      && google_artifact_registry_repository_iam_member.n3b_build_push[0].member == "serviceAccount:media-tools-build@recharge-staging-y9y2y.iam.gserviceaccount.com"
      && google_storage_bucket_iam_member.n3b_build_source[0].bucket == "recharge-staging-y9y2y-media-tools-build"
      && google_storage_bucket_iam_member.n3b_build_source[0].role == "roles/storage.objectViewer"
      && google_storage_bucket_iam_member.n3b_scanner_mirror[0].bucket == "recharge-staging-y9y2y-clamav-mirror"
      && google_storage_bucket_iam_member.n3b_scanner_mirror[0].role == "roles/storage.objectViewer"
      && google_storage_bucket_iam_member.n3b_scanner_mirror[0].member == "serviceAccount:media-tools-scanner@recharge-staging-y9y2y.iam.gserviceaccount.com"
    && google_storage_bucket_iam_member.n3b_mirror_writer[0].member == "serviceAccount:clamav-mirror@recharge-staging-y9y2y.iam.gserviceaccount.com")
    error_message = "Build, scanner and mirror grants are resource-level and exact."
  }
  assert {
    condition     = toset(keys(google_secret_manager_secret_iam_member.n3b_token)) == toset(["media-tools-scanner", "media-tools-processor"]) && tolist(module.n3b_secret.secret_ids) == tolist(["MEDIA_TOOLS_TOKEN"])
    error_message = "Only the two services read the token secret; container only, never a value."
  }
}

run "n3b_phase2_shape" {
  command = plan
  variables {
    n3b_enabled                     = true
    n3b_image_digest                = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    n3b_operator_email              = "operator@example.invalid"
    n3b_authorization_record_path   = "tests/synthetic-n3b-phase2-record.json"
    n3b_authorization_record_sha256 = filesha256("tests/synthetic-n3b-phase2-record.json")
  }
  assert {
    condition     = toset(keys(google_cloud_run_v2_service.n3b)) == toset(["media-scanner", "media-processor"])
    error_message = "Exactly the two private tool services."
  }
  assert {
    condition = alltrue([for s in google_cloud_run_v2_service.n3b :
      s.ingress == "INGRESS_TRAFFIC_ALL" && s.invoker_iam_disabled == false && s.deletion_protection == true
      && s.template[0].scaling[0].min_instance_count == 0 && s.template[0].scaling[0].max_instance_count == 1
      && s.template[0].containers[0].image == "europe-west1-docker.pkg.dev/recharge-staging-y9y2y/media-tools/media-tools@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      && s.template[0].containers[0].resources[0].cpu_idle == true
    && s.template[0].containers[0].resources[0].limits.cpu == "1"])
    error_message = "IAM-gated, scale 0..1, request-based CPU, image pinned by digest."
  }
  assert {
    condition = (google_cloud_run_v2_service.n3b["media-scanner"].template[0].containers[0].resources[0].limits.memory == "4Gi"
      && google_cloud_run_v2_service.n3b["media-scanner"].template[0].max_instance_request_concurrency == 2
      && google_cloud_run_v2_service.n3b["media-scanner"].template[0].timeout == "60s"
      && google_cloud_run_v2_service.n3b["media-processor"].template[0].containers[0].resources[0].limits.memory == "1Gi"
      && google_cloud_run_v2_service.n3b["media-processor"].template[0].max_instance_request_concurrency == 1
    && google_cloud_run_v2_service.n3b["media-processor"].template[0].timeout == "30s")
    error_message = "Reviewed sizes: scanner 1 vCPU/4 GiB x2, processor 1 vCPU/1 GiB x1."
  }
  assert {
    condition     = alltrue([for m in google_cloud_run_v2_service_iam_member.n3b_operator : m.role == "roles/run.invoker" && m.member == "user:operator@example.invalid"])
    error_message = "Only the operator may invoke; never allUsers."
  }
  assert {
    condition = (google_cloud_run_v2_job.n3b_mirror[0].template[0].template[0].max_retries == 1
      && google_cloud_run_v2_job.n3b_mirror[0].template[0].template[0].timeout == "900s"
      && google_cloud_run_v2_job_iam_member.n3b_mirror_schedule[0].member == "serviceAccount:clamav-mirror@recharge-staging-y9y2y.iam.gserviceaccount.com"
      && google_cloud_scheduler_job.n3b_mirror[0].schedule == "17 4 * * 1,4"
    && google_cloud_scheduler_job.n3b_mirror[0].http_target[0].uri == "https://run.googleapis.com/v2/projects/recharge-staging-y9y2y/locations/europe-west1/jobs/clamav-mirror:run")
    error_message = "Mirror job: bounded, twice weekly, run by its own account."
  }
}

run "n3b_requires_n2c" {
  command = plan
  variables {
    n3b_enabled = true
    n2c_enabled = false
  }
  expect_failures = [terraform_data.n3b_guard]
}

run "n3b_wrong_stage_denied" {
  command = plan
  variables {
    n3b_enabled                     = true
    n3b_authorization_record_path   = "tests/synthetic-n3b-wrong-stage-record.json"
    n3b_authorization_record_sha256 = filesha256("tests/synthetic-n3b-wrong-stage-record.json")
  }
  expect_failures = [terraform_data.n3b_guard]
}

run "n3b_automatic_deletion_denied" {
  command = plan
  variables {
    n3b_enabled                     = true
    n3b_authorization_record_path   = "tests/synthetic-n3b-deletion-record.json"
    n3b_authorization_record_sha256 = filesha256("tests/synthetic-n3b-deletion-record.json")
  }
  expect_failures = [terraform_data.n3b_guard]
}

run "n3b_min_instances_denied" {
  command = plan
  variables {
    n3b_enabled                     = true
    n3b_authorization_record_path   = "tests/synthetic-n3b-scale-record.json"
    n3b_authorization_record_sha256 = filesha256("tests/synthetic-n3b-scale-record.json")
  }
  expect_failures = [terraform_data.n3b_guard]
}

run "n3b_unrecorded_image_denied" {
  command = plan
  variables {
    n3b_enabled        = true
    n3b_image_digest   = "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    n3b_operator_email = "operator@example.invalid"
  }
  expect_failures = [terraform_data.n3b_guard]
}

run "n3b_phase2_needs_operator" {
  command = plan
  variables {
    n3b_enabled                     = true
    n3b_image_digest                = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    n3b_authorization_record_path   = "tests/synthetic-n3b-phase2-record.json"
    n3b_authorization_record_sha256 = filesha256("tests/synthetic-n3b-phase2-record.json")
  }
  expect_failures = [terraform_data.n3b_guard]
}

run "n3b_other_project_denied" {
  command = plan
  variables {
    project_id                  = "recharge-dev-selftest0"
    authorization_record_path   = "tests/synthetic-plan-record.json"
    authorization_record_sha256 = filesha256("tests/synthetic-plan-record.json")
    n2c_enabled                 = false
    n3b_enabled                 = true
  }
  expect_failures = [var.project_id]
}
