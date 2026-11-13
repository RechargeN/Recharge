# One state bucket per environment, in that environment's own project. Created by
# a separately authorized bootstrap (local state first, then migration); versioned,
# never public and protected from destroy.
resource "google_storage_bucket" "state" {
  count = var.enabled ? 1 : 0

  project                     = var.project_id
  name                        = "${var.project_id}-tfstate"
  location                    = var.location
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
