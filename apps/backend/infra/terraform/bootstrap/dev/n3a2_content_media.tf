# N3a.2: grants of the dev Content + Media runtime (codebase n3a2-content-media,
# deployed by the Firebase CLI, never by Terraform). The account itself comes from
# the manifest (runtime-media, deployed: true) through module.runtime_identities.
# Behind var.n3a2_enabled and a separate owner-issued N3a.2 record; needs the N3b
# services (phase 2) for the invoker grants. No delete permission anywhere: the
# runtime creates, reads and updates records and objects, it never removes (D-07).
locals {
  n3a2_on       = var.n3a2_enabled
  n3a2_member   = "serviceAccount:runtime-media@${local.n2c_project}.iam.gserviceaccount.com"
  n3a2_approval = try(jsondecode(file(var.n3a2_authorization_record_path)), null)
  n3a2_record_valid = try(
    local.n3a2_approval.status == "approved"
    && local.n3a2_approval.schemaVersion == 1
    && local.n3a2_approval.stage == "n3a2"
    && local.n3a2_approval.environment == "dev"
    && local.n3a2_approval.projectId == var.project_id
    && var.project_id == local.n2c_project
    && local.n3a2_approval.commitSha == var.release_commit_sha
    && local.n3a2_approval.manifestSha256 == filesha256(local.manifest_path)
    && var.n3a2_authorization_record_sha256 == filesha256(var.n3a2_authorization_record_path)
    && local.n3a2_approval.operations == ["plan"]
    && length(local.n3a2_approval.ownerApprovalEvidenceRef) > 0
    && local.n3a2_approval.dataScope == "synthetic"
    && local.n3a2_approval.publication == false
    && local.n3a2_approval.automaticDeletion == false
    && local.n3a2_approval.push == false && local.n3a2_approval.merge == false
    && local.n3a2_approval.marketActivation == false
    && timecmp(local.n3a2_approval.issuedAtUtc, plantimestamp()) <= 0
    && timecmp(local.n3a2_approval.expiresAtUtc, plantimestamp()) > 0,
    false
  )
}

resource "terraform_data" "n3a2_guard" {
  count = local.n3a2_on ? 1 : 0
  input = "n3a2-dev-content-media"
  lifecycle {
    precondition {
      condition     = local.n3a2_record_valid
      error_message = "Missing or mismatched N3a.2 dev record (stage, project, commit, manifest, scope or expiry)."
    }
    precondition {
      condition     = local.n3b_services_on
      error_message = "N3a.2 needs the N3b scanner/processor services (N3b phase 2)."
    }
    precondition {
      condition     = google_project.dev.number == local.n2c_project_number
      error_message = "Project number differs from the reviewed recharge-dev-n2a01 number."
    }
  }
}

resource "google_project_iam_custom_role" "n3a2_data" {
  count       = local.n3a2_on ? 1 : 0
  depends_on  = [terraform_data.n3a2_guard]
  project     = google_project.dev.project_id
  role_id     = "devMediaChainData"
  title       = "Dev Content/Media records (no delete)"
  permissions = ["datastore.databases.get", "datastore.entities.create", "datastore.entities.get", "datastore.entities.list", "datastore.entities.update"]
}

resource "google_project_iam_custom_role" "n3a2_objects" {
  count       = local.n3a2_on ? 1 : 0
  depends_on  = [terraform_data.n3a2_guard]
  project     = google_project.dev.project_id
  role_id     = "devMediaObjectWriter"
  title       = "Dev media objects create/read (no delete)"
  permissions = ["storage.objects.create", "storage.objects.get"]
}

resource "google_project_iam_member" "n3a2_data" {
  count      = local.n3a2_on ? 1 : 0
  depends_on = [google_project_iam_custom_role.n3a2_data]
  project    = google_project.dev.project_id
  role       = "projects/${local.n2c_project}/roles/devMediaChainData"
  member     = local.n3a2_member
  condition {
    title      = "dev_default_database_only"
    expression = "resource.name == \"projects/${local.n2c_project}/databases/(default)\""
  }
}

resource "google_storage_bucket_iam_member" "n3a2_objects" {
  count      = local.n3a2_on ? 1 : 0
  depends_on = [google_project_iam_custom_role.n3a2_objects]
  bucket     = "${local.n2c_project}-media"
  role       = "projects/${local.n2c_project}/roles/devMediaObjectWriter"
  member     = local.n3a2_member
}

# verifyIdToken(checkRevoked) reads the Firebase user, as for runtime-identity (N2c).
resource "google_project_iam_member" "n3a2_auth" {
  count      = local.n3a2_on ? 1 : 0
  depends_on = [terraform_data.n3a2_guard]
  project    = google_project.dev.project_id
  role       = "projects/${local.n2c_project}/roles/devIdentityFirebaseVerifier"
  member     = local.n3a2_member
}

resource "google_secret_manager_secret_iam_member" "n3a2_tools_token" {
  count     = local.n3a2_on ? 1 : 0
  project   = google_project.dev.project_id
  secret_id = module.n3b_secret.secret_ids[0]
  role      = "roles/secretmanager.secretAccessor"
  member    = local.n3a2_member
}

resource "google_cloud_run_v2_service_iam_member" "n3a2_invoker" {
  for_each = local.n3a2_on && local.n3b_services_on ? local.n3b_services : {}
  project  = google_project.dev.project_id
  location = local.n3b_region
  name     = google_cloud_run_v2_service.n3b[each.key].name
  role     = "roles/run.invoker"
  member   = local.n3a2_member
}
