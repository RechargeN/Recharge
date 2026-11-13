# App Check is an abuse signal, never authority. It is configured only after a
# recorded decision names the mode for this environment.
resource "google_firebase_app_check_service_config" "firestore" {
  count = var.enabled && var.mode != null ? 1 : 0

  project          = var.project_id
  service_id       = "firestore.googleapis.com"
  enforcement_mode = var.mode
}
