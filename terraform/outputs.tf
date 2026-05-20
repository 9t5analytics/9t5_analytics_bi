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

output "artifact_registry_url" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/analytics-pipeline"
  description = "Artifact Registry URL for pipeline images"
}

output "superset_ip" {
  value       = google_compute_address.superset.address
  description = "Static IP address for Superset VM"
}

output "superset_vm_name" {
  value       = google_compute_instance.superset.name
  description = "Superset VM instance name"
}