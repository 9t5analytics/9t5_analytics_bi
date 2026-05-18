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

    uniform_bucket_level_access = true 
    
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

# ── Artifact Registry (Container Registry) ─────────────────────────
resource "google_artifact_registry_repository" "pipeline" {
  repository_id = "analytics-pipeline"
  location      = var.region
  format        = "DOCKER"
  description   = "Docker images for analytics pipeline"
}

# ── Cloud Run Job ───────────────────────────────────────────────────
resource "google_cloud_run_v2_job" "pipeline" {
  name     = "analytics-pipeline"
  location = var.region

  template {
    template {
      service_account = google_service_account.pipeline_sa.email

      containers {
        # Image will be updated by GitHub Actions on each push
        image = "${var.region}-docker.pkg.dev/${var.project_id}/analytics-pipeline/pipeline:latest"

        # Non-sensitive environment variables
        env {
          name  = "GCP_PROJECT_ID"
          value = var.project_id
        }
        env {
          name  = "GCS_BUCKET_NAME"
          value = var.gcs_bucket_name
        }
        env {
          name  = "BQ_DATASET_ID"
          value = var.bq_dataset_id
        }
        env {
          name  = "MYSQL_HOST"
          value = var.mysql_host
        }
        env {
          name  = "MYSQL_PORT"
          value = "10357"
        }
        env {
          name  = "MYSQL_DATABASE"
          value = var.mysql_database
        }
        env {
          name  = "MYSQL_USER"
          value = var.mysql_user
        }
        env {
          name  = "MYSQL_PORT"
          value = var.mysql_port
        }
        # Sensitive - pulled from Secret Manager
        env {
          name = "MYSQL_PASSWORD"
          value_source {
            secret_key_ref {
              secret  = "mysql-password"
              version = "latest"
            }
          }
        }

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }
      }

      # Maximum time the job can run before being killed
      timeout = "3600s"
    }
  }
}

# ── Cloud Scheduler ─────────────────────────────────────────────────
resource "google_cloud_scheduler_job" "pipeline_trigger" {
  name      = "analytics-pipeline-daily"
  region    = var.region
  schedule  = "0 2 * * *"
  time_zone = "UTC"

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/analytics-pipeline:run"

    oauth_token {
      service_account_email = google_service_account.pipeline_sa.email
    }
  }
}

# ── IAM: Allow pipeline SA to trigger Cloud Run jobs ───────────────
resource "google_project_iam_member" "pipeline_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.pipeline_sa.email}"
}

# ── IAM: Allow pipeline SA to access Secret Manager ────────────────
resource "google_project_iam_member" "pipeline_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.pipeline_sa.email}"
}