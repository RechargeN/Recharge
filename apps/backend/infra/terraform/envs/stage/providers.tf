provider "google" {
  # No credentials, impersonation or access token is ever configured here. The
  # project is null until the approved provisioning slice, and no resource exists
  # while the authorization gate is closed.
  project = var.project_id
  region  = local.manifest.locationPolicy.functions.region
}
