output "configured" {
  value = length(google_firebase_app_check_service_config.firestore) == 1
}
