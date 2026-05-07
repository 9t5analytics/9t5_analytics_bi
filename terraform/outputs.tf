output "gcs_bucket_name" {
    value = google_storage_bucket.data_lake.name
    description = "GCS data lake bucket name"
}

output "bq_dataset_id" {
    value = google_bigquery_dataset.analytics.dataset_id
    description = "BigQuery dataset ID"
}

output "pipeline_sa_email" {
    value = google_service_account.pipeline_sa.email
    description = "Pipeline service account email"
}