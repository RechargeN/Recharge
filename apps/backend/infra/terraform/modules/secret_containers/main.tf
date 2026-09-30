# Containers only: a secret version (the value) is never created by this code.
resource "google_secret_manager_secret" "reference" {
  for_each = var.enabled ? { for item in var.references : item.referenceName => item } : {}

  project   = var.project_id
  secret_id = each.key
  labels    = merge(var.labels, { owner_role = replace(lower(each.value.ownerRole), " ", "_") })

  replication {
    user_managed {
      replicas {
        location = var.location
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}
