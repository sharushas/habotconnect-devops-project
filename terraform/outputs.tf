output "d0_raw_landing_bucket_name" {
  description = "The name of the GCS Raw Landing Bucket"
  value       = google_storage_bucket.d0_raw_landing.name
}

output "d1_staged_dataset_id" {
  description = "The dataset ID of the staging BigQuery dataset"
  value       = google_bigquery_dataset.d1_staged_enforced.dataset_id
}

output "student_onboarding_table_id" {
  description = "The full ID of the student onboarding table"
  value       = google_bigquery_table.student_onboarding_staged.id
}