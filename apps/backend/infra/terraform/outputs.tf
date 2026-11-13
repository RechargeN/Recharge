output "logical_environment_identity" {
  description = "Non-secret logical identity; never a cloud project identifier."
  value       = local.logical_environment_identity
}

output "binding_state" {
  description = "R1 is always unbound."
  value       = local.binding_state
}

output "resource_location_policy" {
  description = "Policy input only; no resource exists in R1."
  value = {
    firestore = var.firestore_location
    functions = var.functions_region
  }
}
