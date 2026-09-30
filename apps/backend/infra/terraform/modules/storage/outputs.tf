output "media_bucket_created" {
  value = length(google_storage_bucket.media) == 1
}

output "recovery_bucket_created" {
  value = length(google_storage_bucket.recovery) == 1
}
