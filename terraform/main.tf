terraform {
    required_providers {
      google = {
        source   = "hashicorp/google"
        version = "~> 5.0"
      }
    }
}

provider "google" {

    project = var.project_id
    region  = var.region
}

resource "google_storage_bucket" "data_lake" {
    name = var.gcs_bucket_name
    location = var.region
    force_destroy = false
    
      lifecycle_rule {
        condition {
          age = 90
        }
        action {
          type = "Delete"
        }
      }
    versioning {
        enabled = false
    }
}

resource "google_bigquery_dataset" "analytics" {
    dataset_id = var.bq_dataset_id
    location   = var.region
    description = "Dataset for analytics"
}

resource "google_service_account" "pipeline_sa" {
    account_id   = "pipeline-sa"
    display_name = "Analytics Pipeline Service Account"
}

resource "google_storage_bucket_iam_member" "pipeline_gcs_access" {
    bucket = google_storage_bucket.data_lake.name
    role   = "roles/storage.objectAdmin"
    member = "serviceAccount:${google_service_account.pipeline_sa.email}"
}

resource "google_bigquery_dataset_iam_member" "pipeline_bq_access" {
    dataset_id = google_bigquery_dataset.analytics.dataset_id
    role       = "roles/bigquery.dataEditor"
    member     = "serviceAccount:${google_service_account.pipeline_sa.email}"
}

resource "google_project_iam_member" "pipeline_bq_job_user" {
    project = var.project_id
    role    = "roles/bigquery.jobUser"
    member  = "serviceAccount:${google_service_account.pipeline_sa.email}"
}