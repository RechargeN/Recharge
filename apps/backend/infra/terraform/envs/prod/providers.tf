provider "google" {
  # No credentials here. Current Draft roots cannot plan/apply; tests use a
  # mocked provider. No real provider plan is part of local validation.
  project = var.project_id
  region  = local.manifest.locationPolicy.functions.region
}
