# N3c: grants of the dev Notifications runtime (codebase n3c-notifications,
# deployed by the Firebase CLI, never by Terraform). The account comes from the
# manifest (runtime-notifications, deployed: true) through module.runtime_identities.
# Behind var.n3c_enabled and a separate owner-issued N3c record. FCM
# (fcm.googleapis.com) is already on as a recorded provider side effect, so no
# API is enabled here. No delete permission: the runtime creates, reads and
# updates inbox, preference and push records, it never removes them (D-07).
locals {
  n3c_on       = var.n3c_enabled
  n3c_member   = "serviceAccount:runtime-notifications@${local.n2c_project}.iam.gserviceaccount.com"
  n3c_approval = try(jsondecode(file(var.n3c_authorization_record_path)), null)
  n3c_record_valid = try(
    local.n3c_approval.status == "approved"
    && local.n3c_approval.schemaVersion == 1
    && local.n3c_approval.stage == "n3c"
    && local.n3c_approval.environment == "stage"
    && local.n3c_approval.projectId == var.project_id
    && var.project_id == local.n2c_project
    && local.n3c_approval.commitSha == var.release_commit_sha
    && local.n3c_approval.manifestSha256 == filesha256(local.manifest_path)
    && var.n3c_authorization_record_sha256 == filesha256(var.n3c_authorization_record_path)
    && local.n3c_approval.operations == ["plan"]
    && length(local.n3c_approval.ownerApprovalEvidenceRef) > 0
    && local.n3c_approval.dataScope == "synthetic"
    && local.n3c_approval.automaticDeletion == false
    && local.n3c_approval.push == false && local.n3c_approval.merge == false
    && local.n3c_approval.marketActivation == false
    && local.n3c_approval.production == false
    && timecmp(local.n3c_approval.issuedAtUtc, plantimestamp()) <= 0
    && timecmp(local.n3c_approval.expiresAtUtc, plantimestamp()) > 0,
    false
  )
}

resource "terraform_data" "n3c_guard" {
  count = local.n3c_on ? 1 : 0
  input = "n3c-dev-notifications"
  lifecycle {
    precondition {
      condition     = local.n3c_record_valid
      error_message = "Missing or mismatched N3c dev record (stage, project, commit, manifest, scope or expiry)."
    }
    precondition {
      condition     = local.n2c_on
      error_message = "N3c needs the N2c identity runtime (Firebase user reader role, Sessions)."
    }
    precondition {
      condition     = google_project.stage.number == local.n2c_project_number
      error_message = "Project number differs from the staging project number."
    }
  }
}

resource "google_project_iam_custom_role" "n3c_data" {
  count       = local.n3c_on ? 1 : 0
  depends_on  = [terraform_data.n3c_guard]
  project     = google_project.stage.project_id
  role_id     = "devNotificationsData"
  title       = "Dev Notifications records (no delete)"
  permissions = ["datastore.databases.get", "datastore.entities.create", "datastore.entities.get", "datastore.entities.list", "datastore.entities.update"]
}

resource "google_project_iam_custom_role" "n3c_fcm" {
  count       = local.n3c_on ? 1 : 0
  depends_on  = [terraform_data.n3c_guard]
  project     = google_project.stage.project_id
  role_id     = "devNotificationsFcmSender"
  title       = "Dev FCM message sender"
  permissions = ["cloudmessaging.messages.create"]
}

resource "google_project_iam_member" "n3c_data" {
  count      = local.n3c_on ? 1 : 0
  depends_on = [google_project_iam_custom_role.n3c_data, module.runtime_identities]
  project    = google_project.stage.project_id
  role       = "projects/${local.n2c_project}/roles/devNotificationsData"
  member     = local.n3c_member
  condition {
    title      = "dev_default_database_only"
    expression = "resource.name == \"projects/${local.n2c_project}/databases/(default)\""
  }
}

resource "google_project_iam_member" "n3c_fcm" {
  count      = local.n3c_on ? 1 : 0
  depends_on = [google_project_iam_custom_role.n3c_fcm, module.runtime_identities]
  project    = google_project.stage.project_id
  role       = "projects/${local.n2c_project}/roles/devNotificationsFcmSender"
  member     = local.n3c_member
}

# verifyIdToken(checkRevoked) reads the Firebase user, as for runtime-identity (N2c).
resource "google_project_iam_member" "n3c_auth" {
  count      = local.n3c_on ? 1 : 0
  depends_on = [terraform_data.n3c_guard, module.runtime_identities]
  project    = google_project.stage.project_id
  role       = "projects/${local.n2c_project}/roles/devIdentityFirebaseVerifier"
  member     = local.n3c_member
}
