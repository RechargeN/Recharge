output "state_bucket_created" {
  value = length(google_storage_bucket.state) == 1
}
