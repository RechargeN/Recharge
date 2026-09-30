# Enables the APIs of one environment project. It does not create the project:
# project creation needs an organization and billing decision that is not made.
resource "google_project_service" "api" {
  for_each = var.enabled ? var.services : toset([])

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}
