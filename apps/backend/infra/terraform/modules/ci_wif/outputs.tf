output "trust_condition" {
  description = "The attribute condition; \"false\" while repository ids are unknown."
  value       = local.condition
}

output "provider_attribute_condition" {
  description = "Wire CEL; the unconfigured branch is identically false while referencing a claim required by Google API."
  value       = try(google_iam_workload_identity_pool_provider.github[0].attribute_condition, null)
}
output "provider_disabled" {
  value = try(google_iam_workload_identity_pool_provider.github[0].disabled, true)
}
