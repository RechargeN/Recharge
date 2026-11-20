# N4c: grants of the Booking runtime (codebase n4c-booking, deployed by the
# Firebase CLI, never by Terraform). The account comes from the manifest
# (runtime-booking, deployed: true) through module.runtime_identities.
# Behind var.n4c_enabled and a separate owner-issued N4c record.
# Owner decision 2026-11-16: this is the only runtime with the Firestore delete
# permission. Cancelling a Booking removes the active-Booking pointer of the user
# in the same transaction. It is functional, not retention: automatic deletion
# (TTL, cleanup policies) stays off.
locals {
  n4c_on       = var.n4c_enabled
  n4c_member   = "serviceAccount:runtime-booking@${local.n2c_project}.iam.gserviceaccount.com"
  n4c_approval = try(jsondecode(file(var.n4c_authorization_record_path)), null)
  n4c_record_valid = try(
    local.n4c_approval.status == "approved"
    && local.n4c_approval.schemaVersion == 1
    && local.n4c_approval.stage == "n4c"
    && local.n4c_approval.environment == "dev"
    && local.n4c_approval.projectId == var.project_id
    && var.project_id == local.n2c_project
    && local.n4c_approval.commitSha == var.release_commit_sha
    && local.n4c_approval.manifestSha256 == filesha256(local.manifest_path)
    && var.n4c_authorization_record_sha256 == filesha256(var.n4c_authorization_record_path)
    && local.n4c_approval.operations == ["plan"]
    && length(local.n4c_approval.ownerApprovalEvidenceRef) > 0
    && local.n4c_approval.dataScope == "synthetic"
    && local.n4c_approval.automaticDeletion == false
    && local.n4c_approval.push == false && local.n4c_approval.merge == false
    && local.n4c_approval.marketActivation == false
    && local.n4c_approval.production == false
    && timecmp(local.n4c_approval.issuedAtUtc, plantimestamp()) <= 0
    && timecmp(local.n4c_approval.expiresAtUtc, plantimestamp()) > 0,
    false
  )
}

resource "terraform_data" "n4c_guard" {
  count = local.n4c_on ? 1 : 0
  input = "n4c-dev-booking"
  lifecycle {
    precondition {
      condition     = local.n4c_record_valid
      error_message = "Missing or mismatched N4c dev record (stage, project, commit, manifest, scope or expiry)."
    }
    precondition {
      condition     = local.n2c_on
      error_message = "N4c needs the N2c identity runtime (Firebase user reader role, Sessions)."
    }
    precondition {
      condition     = google_project.dev.number == local.n2c_project_number
      error_message = "Project number differs from the reviewed recharge-dev-n2a01 number."
    }
  }
}

resource "google_project_iam_custom_role" "n4c_data" {
  count       = local.n4c_on ? 1 : 0
  depends_on  = [terraform_data.n4c_guard]
  project     = google_project.dev.project_id
  role_id     = "devBookingData"
  title       = "Dev Booking records (delete of own pointers)"
  permissions = ["datastore.databases.get", "datastore.entities.create", "datastore.entities.delete", "datastore.entities.get", "datastore.entities.list", "datastore.entities.update"]
}

resource "google_project_iam_member" "n4c_data" {
  count      = local.n4c_on ? 1 : 0
  depends_on = [google_project_iam_custom_role.n4c_data, module.runtime_identities]
  project    = google_project.dev.project_id
  role       = "projects/${local.n2c_project}/roles/devBookingData"
  member     = local.n4c_member
  condition {
    title      = "dev_default_database_only"
    expression = "resource.name == \"projects/${local.n2c_project}/databases/(default)\""
  }
}

# verifyIdToken(checkRevoked) reads the Firebase user, as for runtime-identity (N2c).
resource "google_project_iam_member" "n4c_auth" {
  count      = local.n4c_on ? 1 : 0
  depends_on = [terraform_data.n4c_guard, module.runtime_identities]
  project    = google_project.dev.project_id
  role       = "projects/${local.n2c_project}/roles/devIdentityFirebaseVerifier"
  member     = local.n4c_member
}

# Round 2.2 (owner approval 2026-11-19): the Booking runtime account receives the
# Firestore events of its two triggers (outbox delivery, Content effects handoff).
resource "google_project_iam_member" "n4c_eventarc" {
  count      = local.n4c_on ? 1 : 0
  depends_on = [terraform_data.n4c_guard, module.runtime_identities]
  project    = google_project.dev.project_id
  role       = "roles/eventarc.eventReceiver"
  member     = local.n4c_member
}

# Round 3 (owner approval 2026-11-19): Eventarc invokes the two Firestore
# trigger services as runtime-booking, which therefore may invoke exactly these
# two Cloud Run services (Firebase deploy creates them; no project-level grant).
resource "google_cloud_run_v2_service_iam_member" "n4c_invoker_effects" {
  count      = local.n4c_on ? 1 : 0
  depends_on = [terraform_data.n4c_guard, module.runtime_identities]
  project    = google_project.dev.project_id
  location   = "europe-west1"
  name       = "consumecontenteffectv1"
  role       = "roles/run.invoker"
  member     = local.n4c_member
}

resource "google_cloud_run_v2_service_iam_member" "n4c_invoker_outbox" {
  count      = local.n4c_on ? 1 : 0
  depends_on = [terraform_data.n4c_guard, module.runtime_identities]
  project    = google_project.dev.project_id
  location   = "europe-west1"
  name       = "consumeeventbookingoutboxv1"
  role       = "roles/run.invoker"
  member     = local.n4c_member
}
