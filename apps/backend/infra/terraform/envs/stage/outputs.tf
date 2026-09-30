output "provisioning_authorized" {
  description = "False unless project id, authorization reference and manifest hash are all supplied."
  value       = local.provisioning_authorized
}

output "managed_resource_count" {
  description = "Resources this root would manage right now; zero while the gate is closed."
  value = sum([
    length(module.project_baseline.enabled_services),
    module.firestore.database_created ? 1 : 0,
    module.storage.media_bucket_created ? 1 : 0,
    module.storage.recovery_bucket_created ? 1 : 0,
    length(module.runtime_identities.account_names),
    module.budget_alerts.budget_created ? 1 : 0,
    length(module.secret_containers.secret_ids),
    module.app_check.configured ? 1 : 0,
    module.state_bucket.state_bucket_created ? 1 : 0,
  ])
}

output "trust_condition" {
  value = module.ci_wif.trust_condition
}
