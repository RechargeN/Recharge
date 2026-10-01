output "provisioning_authorized" {
  description = "True only with a valid bound owner record AND an authorized execution manifest."
  value       = local.provisioning_authorized
}

output "managed_resource_count" {
  description = "Desired resources, independent of execution permission. A closed gate fails the plan."
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
