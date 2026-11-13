# N3b: dev-cloud Media tools (ClamAV scanner, sharp processor, database mirror job)
# for recharge-staging-y9y2y only. Two phases, both behind a separate owner-issued N3b
# record and var.n3b_enabled:
#   phase 1 (image digest empty): APIs, identities, buckets, Artifact Registry,
#            secret container and IAM - what the Cloud Build of the image needs;
#   phase 2 (var.n3b_image_digest set, recorded in the N3b record): the two
#            private Cloud Run services, the mirror Cloud Run job and its weekly
#            schedule, all pinned to that digest.
# Nothing deletes: no cleanup or lifecycle rules (D-07), deletion_policy PREVENT,
# create-only mirror writes. min 0 / max 1 instances and request-based CPU keep
# the idle cost at zero (D-05, EUR 5 guardrail). Cloud Run IAM is the gate
# (ingress all, no allUsers); the per-service secret is a second factor.
locals {
  n3b_on          = var.n3b_enabled
  n3b_services_on = local.n3b_on && var.n3b_image_digest != ""
  n3b_project     = "recharge-staging-y9y2y"
  n3b_region      = "europe-west1"
  n3b_image       = "europe-west1-docker.pkg.dev/${local.n3b_project}/media-tools/media-tools@${var.n3b_image_digest}"
  n3b_accounts = {
    "media-tools-build"     = "N3b Cloud Build of the media-tools image"
    "media-tools-scanner"   = "N3b ClamAV scanner service (reads the database mirror)"
    "media-tools-processor" = "N3b sharp processor service (no data access)"
    "clamav-mirror"         = "N3b ClamAV database mirror job and its schedule"
  }
  n3b_member = {
    for name, _ in local.n3b_accounts :
    name => "serviceAccount:${name}@${local.n3b_project}.iam.gserviceaccount.com"
  }
  n3b_mirror_bucket = "${local.n3b_project}-clamav-mirror"
  n3b_build_bucket  = "${local.n3b_project}-media-tools-build"
  n3b_approval      = try(jsondecode(file(var.n3b_authorization_record_path)), null)
  n3b_record_valid = try(
    local.n3b_approval.status == "approved"
    && local.n3b_approval.schemaVersion == 1
    && local.n3b_approval.stage == "n3b"
    && local.n3b_approval.environment == "stage"
    && local.n3b_approval.projectId == var.project_id
    && var.project_id == local.n3b_project
    && local.n3b_approval.commitSha == var.release_commit_sha
    && local.n3b_approval.manifestSha256 == filesha256(local.manifest_path)
    && var.n3b_authorization_record_sha256 == filesha256(var.n3b_authorization_record_path)
    && local.n3b_approval.operations == ["plan"]
    && length(local.n3b_approval.ownerApprovalEvidenceRef) > 0
    && local.n3b_approval.dataScope == "synthetic"
    && local.n3b_approval.imageDigest == var.n3b_image_digest
    && local.n3b_approval.ingress == "all-with-iam"
    && local.n3b_approval.minInstances == 0
    && local.n3b_approval.maxInstances == 1
    && local.n3b_approval.automaticDeletion == false
    && local.n3b_approval.aiModeration == false
    && local.n3b_approval.push == false && local.n3b_approval.merge == false
    && local.n3b_approval.marketActivation == false
    && timecmp(local.n3b_approval.issuedAtUtc, plantimestamp()) <= 0
    && timecmp(local.n3b_approval.expiresAtUtc, plantimestamp()) > 0,
    false
  )
}

resource "terraform_data" "n3b_guard" {
  count = local.n3b_on ? 1 : 0
  input = "n3b-dev-media-tools"
  lifecycle {
    precondition {
      condition     = local.n3b_record_valid
      error_message = "Missing or mismatched N3b dev record (stage, project, commit, manifest, image, scope or expiry)."
    }
    precondition {
      condition     = local.n2c_on
      error_message = "N3b reuses the Cloud Run, Artifact Registry, Cloud Build and Secret Manager APIs of N2c."
    }
    precondition {
      condition     = google_project.stage.number == local.n2c_project_number
      error_message = "Project number differs from the staging project number."
    }
    precondition {
      condition     = var.n3b_image_digest == "" || can(regex("^sha256:[0-9a-f]{64}$", var.n3b_image_digest))
      error_message = "The image is pinned by an exact sha256 digest."
    }
    precondition {
      condition     = !local.n3b_services_on || can(regex("^[^@\\s]+@[^@\\s]+$", var.n3b_operator_email))
      error_message = "Phase 2 needs the operator account that runs the smoke (invoker only)."
    }
  }
}

resource "google_project_service" "n3b" {
  for_each           = local.n3b_on ? toset(["cloudscheduler.googleapis.com"]) : toset([])
  depends_on         = [terraform_data.n3b_guard]
  project            = google_project.stage.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "n3b" {
  for_each        = local.n3b_on ? local.n3b_accounts : {}
  depends_on      = [terraform_data.n3b_guard]
  project         = google_project.stage.project_id
  account_id      = each.key
  display_name    = each.value
  deletion_policy = "PREVENT"
}

# Docker repository of the one media-tools image. No cleanup policy (D-07);
# tags are immutable; automatic vulnerability scanning stays off (cost).
resource "google_artifact_registry_repository" "n3b_media_tools" {
  count           = local.n3b_on ? 1 : 0
  depends_on      = [terraform_data.n3b_guard]
  project         = google_project.stage.project_id
  location        = local.n3b_region
  repository_id   = "media-tools"
  format          = "DOCKER"
  description     = "N3b media-tools image (scanner, processor, mirror job)"
  labels          = merge(local.labels, { stage = "n3b-media-tools" })
  deletion_policy = "PREVENT"
  docker_config {
    immutable_tags = true
  }
  vulnerability_scanning_config {
    enablement_config = "DISABLED"
  }
  lifecycle { prevent_destroy = true }
}

# Official ClamAV databases only, content-addressed and append-only.
resource "google_storage_bucket" "n3b_clamav_mirror" {
  count                       = local.n3b_on ? 1 : 0
  depends_on                  = [terraform_data.n3b_guard]
  project                     = google_project.stage.project_id
  name                        = local.n3b_mirror_bucket
  location                    = "EUROPE-WEST1"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  deletion_policy             = "PREVENT"
  labels                      = merge(local.labels, { stage = "n3b-media-tools" })
  lifecycle { prevent_destroy = true }
}

# Explicit Cloud Build source staging (instead of the auto-created _cloudbuild bucket).
resource "google_storage_bucket" "n3b_build_staging" {
  count                       = local.n3b_on ? 1 : 0
  depends_on                  = [terraform_data.n3b_guard]
  project                     = google_project.stage.project_id
  name                        = local.n3b_build_bucket
  location                    = "EUROPE-WEST1"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  deletion_policy             = "PREVENT"
  labels                      = merge(local.labels, { stage = "n3b-media-tools" })
  lifecycle { prevent_destroy = true }
}

# Container only; the owner adds the value once via stdin (never HCL/state).
module "n3b_secret" {
  depends_on = [terraform_data.n3b_guard]
  source     = "../../modules/secret_containers"
  enabled    = local.n3b_on
  labels     = merge(local.labels, { stage = "n3b-media-tools" })
  project_id = google_project.stage.project_id
  location   = local.n3b_region
  references = [{
    logicalName   = "mediaToolsToken"
    referenceName = "MEDIA_TOOLS_TOKEN"
    ownerRole     = "Platform"
    valuePresent  = false
  }]
}

# Create/read/list only: the mirror job can neither overwrite nor delete.
resource "google_project_iam_custom_role" "n3b_mirror_writer" {
  count       = local.n3b_on ? 1 : 0
  depends_on  = [terraform_data.n3b_guard]
  project     = google_project.stage.project_id
  role_id     = "devClamavMirrorWriter"
  title       = "Dev ClamAV mirror append-only writer"
  permissions = ["storage.objects.create", "storage.objects.get", "storage.objects.list"]
}

resource "google_project_iam_member" "n3b_build_logging" {
  count   = local.n3b_on ? 1 : 0
  project = google_project.stage.project_id
  role    = "roles/logging.logWriter"
  member  = local.n3b_member["media-tools-build"]
}

resource "google_artifact_registry_repository_iam_member" "n3b_build_push" {
  count      = local.n3b_on ? 1 : 0
  project    = google_project.stage.project_id
  location   = local.n3b_region
  repository = google_artifact_registry_repository.n3b_media_tools[0].repository_id
  role       = "roles/artifactregistry.writer"
  member     = local.n3b_member["media-tools-build"]
}

resource "google_storage_bucket_iam_member" "n3b_build_source" {
  count  = local.n3b_on ? 1 : 0
  bucket = google_storage_bucket.n3b_build_staging[0].name
  role   = "roles/storage.objectViewer"
  member = local.n3b_member["media-tools-build"]
}

resource "google_storage_bucket_iam_member" "n3b_scanner_mirror" {
  count  = local.n3b_on ? 1 : 0
  bucket = google_storage_bucket.n3b_clamav_mirror[0].name
  role   = "roles/storage.objectViewer"
  member = local.n3b_member["media-tools-scanner"]
}

resource "google_storage_bucket_iam_member" "n3b_mirror_writer" {
  count      = local.n3b_on ? 1 : 0
  depends_on = [google_project_iam_custom_role.n3b_mirror_writer]
  bucket     = google_storage_bucket.n3b_clamav_mirror[0].name
  # Literal id (known at plan time, so the independent checker can read it).
  role   = "projects/${local.n3b_project}/roles/devClamavMirrorWriter"
  member = local.n3b_member["clamav-mirror"]
}

resource "google_secret_manager_secret_iam_member" "n3b_token" {
  for_each  = local.n3b_on ? toset(["media-tools-scanner", "media-tools-processor"]) : toset([])
  project   = google_project.stage.project_id
  secret_id = module.n3b_secret.secret_ids[0]
  role      = "roles/secretmanager.secretAccessor"
  member    = local.n3b_member[each.key]
}

# ---------- phase 2: services, job, schedule (pinned image digest) ----------

locals {
  n3b_services = {
    "media-scanner" = {
      mode        = "scanner"
      account     = "media-tools-scanner"
      memory      = "4Gi"
      concurrency = 2
      timeout     = "60s"
    }
    "media-processor" = {
      mode        = "processor"
      account     = "media-tools-processor"
      memory      = "1Gi"
      concurrency = 1
      timeout     = "30s"
    }
  }
}

resource "google_cloud_run_v2_service" "n3b" {
  for_each             = local.n3b_services_on ? local.n3b_services : {}
  depends_on           = [google_secret_manager_secret_iam_member.n3b_token, google_storage_bucket_iam_member.n3b_scanner_mirror]
  project              = google_project.stage.project_id
  location             = local.n3b_region
  name                 = each.key
  ingress              = "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = false
  deletion_protection  = true
  deletion_policy      = "PREVENT"
  labels               = merge(local.labels, { stage = "n3b-media-tools" })
  template {
    service_account                  = google_service_account.n3b[each.value.account].email
    execution_environment            = "EXECUTION_ENVIRONMENT_GEN2"
    max_instance_request_concurrency = each.value.concurrency
    timeout                          = each.value.timeout
    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
    containers {
      image = local.n3b_image
      ports {
        container_port = 8080
      }
      resources {
        limits            = { cpu = "1", memory = each.value.memory }
        cpu_idle          = true
        startup_cpu_boost = true
      }
      env {
        name  = "RECHARGE_TOOLS_MODE"
        value = each.value.mode
      }
      env {
        name = "RECHARGE_TOOLS_TOKEN"
        value_source {
          secret_key_ref {
            secret  = module.n3b_secret.secret_ids[0]
            version = "latest"
          }
        }
      }
      startup_probe {
        tcp_socket {
          port = 8080
        }
        initial_delay_seconds = 0
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = 24
      }
    }
  }
}

# Invoker: only the operator who runs the smoke (later also runtime-media, by a
# separate reviewed change). No allUsers / allAuthenticatedUsers.
resource "google_cloud_run_v2_service_iam_member" "n3b_operator" {
  for_each = local.n3b_services_on ? local.n3b_services : {}
  project  = google_project.stage.project_id
  location = local.n3b_region
  name     = google_cloud_run_v2_service.n3b[each.key].name
  role     = "roles/run.invoker"
  member   = "user:${var.n3b_operator_email}"
}

resource "google_cloud_run_v2_job" "n3b_mirror" {
  count               = local.n3b_services_on ? 1 : 0
  depends_on          = [google_storage_bucket_iam_member.n3b_mirror_writer]
  project             = google_project.stage.project_id
  location            = local.n3b_region
  name                = "clamav-mirror"
  deletion_protection = true
  deletion_policy     = "PREVENT"
  labels              = merge(local.labels, { stage = "n3b-media-tools" })
  template {
    task_count  = 1
    parallelism = 1
    template {
      service_account       = google_service_account.n3b["clamav-mirror"].email
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
      timeout               = "900s"
      max_retries           = 1
      containers {
        image = local.n3b_image
        resources {
          limits = { cpu = "1", memory = "2Gi" }
        }
        env {
          name  = "RECHARGE_TOOLS_MODE"
          value = "mirror"
        }
      }
    }
  }
}

resource "google_cloud_run_v2_job_iam_member" "n3b_mirror_schedule" {
  count    = local.n3b_services_on ? 1 : 0
  project  = google_project.stage.project_id
  location = local.n3b_region
  name     = google_cloud_run_v2_job.n3b_mirror[0].name
  role     = "roles/run.invoker"
  member   = local.n3b_member["clamav-mirror"]
}

# Twice a week keeps the newest daily within the 7-day freshness rule (§7).
resource "google_cloud_scheduler_job" "n3b_mirror" {
  count            = local.n3b_services_on ? 1 : 0
  depends_on       = [google_project_service.n3b, google_cloud_run_v2_job_iam_member.n3b_mirror_schedule]
  project          = google_project.stage.project_id
  region           = local.n3b_region
  name             = "clamav-mirror-twice-weekly"
  description      = "N3b: refresh the private ClamAV database mirror (append-only)"
  schedule         = "17 4 * * 1,4"
  time_zone        = "Etc/UTC"
  attempt_deadline = "180s"
  deletion_policy  = "PREVENT"
  # No retry_config: retry_count 0 is the API default, and an explicit block
  # with 0 reads back as absent (perpetual diff, 2026-11-07).
  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${local.n3b_project}/locations/${local.n3b_region}/jobs/clamav-mirror:run"
    oauth_token {
      service_account_email = google_service_account.n3b["clamav-mirror"].email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }
}

output "n3b_media_tools" {
  description = "Public facts for the owner scripts (no secrets)."
  value = local.n3b_on ? {
    repository    = "europe-west1-docker.pkg.dev/${local.n3b_project}/media-tools/media-tools"
    build_account = google_service_account.n3b["media-tools-build"].email
    build_bucket  = local.n3b_build_bucket
    mirror_bucket = local.n3b_mirror_bucket
    scanner_url   = local.n3b_services_on ? google_cloud_run_v2_service.n3b["media-scanner"].uri : null
    processor_url = local.n3b_services_on ? google_cloud_run_v2_service.n3b["media-processor"].uri : null
    image         = local.n3b_services_on ? local.n3b_image : null
    phase         = local.n3b_services_on ? 2 : 1
  } : null
}
