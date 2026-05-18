variable "project_id" {
    description = "GCP Project ID"
    type        = string
}


variable "region" {
  description = "GCP Region for all resources"
    type      = string
  default     = "europe-west1"
}

variable "gcs_bucket_name" {
    description = "GCS Data Lake Bucket Name"
    type        = string
}
  
variable "bq_dataset_id" {
    description = "BigQuery Dataset ID"
    type        = string
    default     = "analytics"
}

variable "superset_machine_type" {
    description = "Superset Machine Type"
    type        = string
    default     = "e2-small"
}

variable "mysql_host" {
  description = "Railway MySQL host"
  type        = string
}

variable "mysql_database" {
  description = "Railway MySQL database name"
  type        = string
}

variable "mysql_user" {
  description = "Railway MySQL username"
  type        = string
}

variable "mysql_port" {
  description = "Railway MySQL port"
  type        = string
  default     = "10357"
}