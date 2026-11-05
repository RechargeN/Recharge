# N2c runtime prerequisites only. The five Session functions are deployed by the
# Firebase CLI from n2c-identity-runtime/firebase.n2c.json (runbook: Functions are
# not managed by Terraform). This file grants exactly what that deployment needs.
locals {
  n2c_runtime_member = "serviceAccount:runtime-identity@${local.n2c_project}.iam.gserviceaccount.com"
  # Gen2 builds of a project created after the 2024 Cloud Build change run as the
  # default compute account. It gets three build roles, scoped by condition; the
  # roles/editor it once had stays removed.
  n2c_build_member  = "serviceAccount:${local.n2c_project_number}-compute@developer.gserviceaccount.com"
  n2c_source_bucket = "gcf-v2-sources-${local.n2c_project_number}-${local.n2c_region}"
}

# Container only; the value is added once by the owner via stdin (never HCL/state).
module "n2c_secret" {
  depends_on = [google_project_service.n2c]
  source     = "../../modules/secret_containers"
  enabled    = local.n2c_on
  labels     = merge(local.labels, { stage = "n2c-identity" })
  project_id = google_project.dev.project_id
  location   = local.n2c_region
  references = [{
    logicalName   = "devAuthIngressHmac"
    referenceName = "DEV_AUTH_INGRESS_HMAC"
    ownerRole     = "Platform"
    valuePresent  = false
  }]
}

resource "google_project_iam_custom_role" "n2c_auth_verify" {
  count       = local.n2c_on ? 1 : 0
  depends_on  = [terraform_data.n2c_guard]
  project     = google_project.dev.project_id
  role_id     = "devIdentityFirebaseVerifier"
  title       = "Dev Identity Firebase user state reader"
  permissions = ["firebaseauth.users.get"]
}

resource "google_project_iam_custom_role" "n2c_session_data" {
  count       = local.n2c_on ? 1 : 0
  depends_on  = [terraform_data.n2c_guard]
  project     = google_project.dev.project_id
  role_id     = "devIdentitySessionData"
  title       = "Dev Identity Session transactions"
  permissions = ["datastore.databases.get", "datastore.entities.create", "datastore.entities.get", "datastore.entities.list", "datastore.entities.update"]
}

resource "google_project_iam_member" "n2c_runtime_auth" {
  count   = local.n2c_on ? 1 : 0
  project = google_project.dev.project_id
  role    = google_project_iam_custom_role.n2c_auth_verify[0].name
  member  = local.n2c_runtime_member
}

resource "google_project_iam_member" "n2c_runtime_database" {
  count   = local.n2c_on ? 1 : 0
  project = google_project.dev.project_id
  role    = google_project_iam_custom_role.n2c_session_data[0].name
  member  = local.n2c_runtime_member
  condition {
    title      = "dev_default_database_only"
    expression = "resource.name == \"projects/${local.n2c_project}/databases/(default)\""
  }
}

resource "google_secret_manager_secret_iam_member" "n2c_runtime_ingress" {
  count     = local.n2c_on ? 1 : 0
  project   = google_project.dev.project_id
  secret_id = module.n2c_secret.secret_ids[0]
  role      = "roles/secretmanager.secretAccessor"
  member    = local.n2c_runtime_member
}

resource "google_project_iam_member" "n2c_build_logging" {
  count      = local.n2c_on ? 1 : 0
  depends_on = [terraform_data.n2c_guard]
  project    = google_project.dev.project_id
  role       = "roles/logging.logWriter"
  member     = local.n2c_build_member
}

resource "google_project_iam_member" "n2c_build_source" {
  count      = local.n2c_on ? 1 : 0
  depends_on = [terraform_data.n2c_guard]
  project    = google_project.dev.project_id
  role       = "roles/storage.objectViewer"
  member     = local.n2c_build_member
  condition {
    title      = "gcf_v2_sources_only"
    expression = "resource.name.startsWith(\"projects/_/buckets/${local.n2c_source_bucket}\")"
  }
}

resource "google_project_iam_member" "n2c_build_artifacts" {
  count      = local.n2c_on ? 1 : 0
  depends_on = [terraform_data.n2c_guard]
  project    = google_project.dev.project_id
  role       = "roles/artifactregistry.writer"
  member     = local.n2c_build_member
  condition {
    title      = "gcf_artifacts_only"
    expression = "resource.name.startsWith(\"projects/${local.n2c_project}/locations/${local.n2c_region}/repositories/gcf-artifacts\")"
  }
}
