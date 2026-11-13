# Create-only ownership: this module owns the database itself. Rules, indexes and
# TTL policies are owned by the Firebase CLI from the verified release artifact
# and are deliberately absent here (no double management).
resource "google_firestore_database" "default" {
  count = var.enabled ? 1 : 0

  project                           = var.project_id
  name                              = "(default)"
  location_id                       = var.location_id
  type                              = "FIRESTORE_NATIVE"
  database_edition                  = "STANDARD"
  concurrency_mode                  = "PESSIMISTIC"
  delete_protection_state           = "DELETE_PROTECTION_ENABLED"
  point_in_time_recovery_enablement = var.point_in_time_recovery ? "POINT_IN_TIME_RECOVERY_ENABLED" : "POINT_IN_TIME_RECOVERY_DISABLED"
  deletion_policy                   = "ABANDON"

  lifecycle {
    prevent_destroy = true
  }
}
