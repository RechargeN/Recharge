output "secret_ids" {
  value = sort(keys(google_secret_manager_secret.reference))
}
