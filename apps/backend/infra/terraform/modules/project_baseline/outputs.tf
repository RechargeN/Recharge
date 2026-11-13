output "enabled_services" {
  description = "Services this module enables; empty when the gate is closed."
  value       = sort(keys(google_project_service.api))
}
