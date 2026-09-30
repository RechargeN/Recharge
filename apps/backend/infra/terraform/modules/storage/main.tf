# Runtime media bucket. Objects are reached only through the Media module, never
# by a public prefix: public access is prevented and access is bucket-level uniform.
resource "google_storage_bucket" "media" {
  count = var.enabled ? 1 : 0

  project                     = var.project_id
  name                        = "${var.project_id}-media"
  location                    = var.media_location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = var.labels

  lifecycle {
    prevent_destroy = true
  }
}

# Recovery/export bucket: disabled until the recovery decision is accepted.
resource "google_storage_bucket" "recovery" {
  count = var.enabled && var.recovery_enabled ? 1 : 0

  project                     = var.project_id
  name                        = "${var.project_id}-recovery"
  location                    = var.recovery_location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = var.labels

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}
