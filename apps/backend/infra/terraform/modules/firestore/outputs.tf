output "database_created" {
  value = length(google_firestore_database.default) == 1
}
