# N2c: dev Identity registration inside the existing N2b ownership root.
# Disabled unless var.n2c_enabled AND a separate owner-issued N2c record is valid.
# No OAuth client secret, App Check debug token or Secret Manager payload is ever
# written by this code or stored in state: those are owner console/stdin steps.
locals {
  n2c_on             = var.n2c_enabled
  n2c_project        = "recharge-dev-n2a01"
  n2c_project_number = "420479958348"
  n2c_region         = "europe-west1"
  n2c_package        = "com.recharge.app.recharge.dev"
  # apksigner of the reviewed dev debug APK (Android Debug certificate); lowercase hex.
  n2c_debug_sha1   = "2667b9c54eaaa70e8955035058928b1d5501ae88"
  n2c_debug_sha256 = "23b74a246731835937d3feccb11ba3d39092315e4c2e945b5c715e7b124cae17"
  n2c_apis = toset([
    "apikeys.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "firebaseappcheck.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
  ])
  # Client-side Firebase surfaces used by the dev APK; nothing else accepts this key.
  n2c_key_services = toset([
    "firebaseappcheck.googleapis.com",
    "firebaseinstallations.googleapis.com",
    "identitytoolkit.googleapis.com",
    "securetoken.googleapis.com",
  ])
  n2c_approval = try(jsondecode(file(var.n2c_authorization_record_path)), null)
  n2c_record_valid = try(
    local.n2c_approval.status == "approved"
    && local.n2c_approval.schemaVersion == 1
    && local.n2c_approval.stage == "n2c"
    && local.n2c_approval.environment == "dev"
    && local.n2c_approval.projectId == var.project_id
    && var.project_id == local.n2c_project
    && local.n2c_approval.commitSha == var.release_commit_sha
    && local.n2c_approval.manifestSha256 == filesha256(local.manifest_path)
    && var.n2c_authorization_record_sha256 == filesha256(var.n2c_authorization_record_path)
    && local.n2c_approval.operations == ["plan"]
    && length(local.n2c_approval.ownerApprovalEvidenceRef) > 0
    && local.n2c_approval.dataScope == "synthetic"
    && local.n2c_approval.appCheckEnforcement == false
    && local.n2c_approval.push == false && local.n2c_approval.merge == false
    && local.n2c_approval.marketActivation == false
    && timecmp(local.n2c_approval.issuedAtUtc, plantimestamp()) <= 0
    && timecmp(local.n2c_approval.expiresAtUtc, plantimestamp()) > 0,
    false
  )
}

resource "terraform_data" "n2c_guard" {
  count = local.n2c_on ? 1 : 0
  input = "n2c-dev-identity"
  lifecycle {
    precondition {
      condition     = local.n2c_record_valid
      error_message = "Missing or mismatched N2c dev record (stage, project, commit, manifest, scope or expiry)."
    }
    precondition {
      condition     = google_project.dev.number == local.n2c_project_number
      error_message = "Project number differs from the reviewed recharge-dev-n2a01 number."
    }
  }
}

resource "google_project_service" "n2c" {
  for_each           = local.n2c_on ? local.n2c_apis : toset([])
  depends_on         = [terraform_data.n2c_guard, google_firebase_project.dev]
  project            = google_project.dev.project_id
  service            = each.value
  disable_on_destroy = false
}

# Initializes Firebase Auth as Identity Platform. Only Google (owner console) is
# meant to be enabled; email, anonymous and phone (SMS cost) stay disabled.
resource "google_identity_platform_config" "n2c" {
  count                      = local.n2c_on ? 1 : 0
  provider                   = google-beta
  depends_on                 = [terraform_data.n2c_guard, google_firebase_project.dev]
  project                    = google_project.dev.project_id
  autodelete_anonymous_users = true
  authorized_domains         = ["${local.n2c_project}.firebaseapp.com", "${local.n2c_project}.web.app"]
  sign_in {
    allow_duplicate_emails = false
    email {
      enabled           = false
      password_required = true
    }
    anonymous {
      enabled = false
    }
    phone_number {
      enabled = false
    }
  }
}

# Public Android configuration key (it ships inside the APK); restricted to the
# dev package + debug certificate and to the client Firebase APIs above.
resource "google_apikeys_key" "n2c_android" {
  count        = local.n2c_on ? 1 : 0
  provider     = google-beta
  depends_on   = [google_project_service.n2c]
  project      = google_project.dev.project_id
  name         = "recharge-dev-android"
  display_name = "Recharge dev Android (restricted)"
  restrictions {
    android_key_restrictions {
      allowed_applications {
        package_name     = local.n2c_package
        sha1_fingerprint = local.n2c_debug_sha1
      }
    }
    dynamic "api_targets" {
      for_each = local.n2c_key_services
      content {
        service = api_targets.value
      }
    }
  }
}

resource "google_firebase_android_app" "n2c_dev" {
  count           = local.n2c_on ? 1 : 0
  provider        = google-beta
  depends_on      = [terraform_data.n2c_guard, google_firebase_project.dev]
  project         = google_project.dev.project_id
  display_name    = "Recharge Dev Android"
  package_name    = local.n2c_package
  api_key_id      = google_apikeys_key.n2c_android[0].uid
  sha1_hashes     = [local.n2c_debug_sha1]
  sha256_hashes   = [local.n2c_debug_sha256]
  deletion_policy = "ABANDON"
  lifecycle { prevent_destroy = true }
}

output "n2c_public_client_configuration" {
  description = "Public client configuration for --dart-define (no secrets)."
  value = local.n2c_on ? {
    android_app_id   = google_firebase_android_app.n2c_dev[0].app_id
    api_key_uid      = google_apikeys_key.n2c_android[0].uid
    project_number   = google_project.dev.number
    package_name     = local.n2c_package
    apply_authorized = false
  } : null
}

# The key string is public client configuration, but keep it out of plan/CLI noise.
output "n2c_android_api_key" {
  value     = local.n2c_on ? google_apikeys_key.n2c_android[0].key_string : null
  sensitive = true
}
