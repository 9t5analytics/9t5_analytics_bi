import os
import logging
from google.cloud import bigquery
from google.cloud.bigquery import LoadJobConfig, SourceFormat
from dotenv import load_dotenv
from utils.gcs import get_gcs_client


load_dotenv()
logger = logging.getLogger(__name__)


def get_bg_client():
    """
    Creates and returns a BigQuery client.
    Uses Application Default Credentials automatically.
    """
    return bigquery.Client(project=os.getenv("GCP_PROJECT_ID"))

def load_gcs_to_bigquery(table_name, blob_path, write_disposition):
    """
    Loads a parquet file from GCS into a BigQuery table.
    table_name        - the target BigQuery table name
    blob_path         - the GCS path returned by upload_dataframe_to_gcs()
    write_disposition - WRITE_TRUNCATE for full refresh, WRITE_APPEND for incremental
    """

    bucket_name = os.getenv("GCS_BUCKET_NAME")
    dataset_id = os.getenv("BQ_DATASET_ID")
    project_id = os.getenv("GCP_PROJECT_ID")

    # Full GCS URI - BigQuery needs the full path including gs://
    gcs_uri = f"gs://{bucket_name}/{blob_path}"

    # Full BigQuery table reference
    table_ref = f"{project_id}.{dataset_id}.{table_name}"

    # Configure the load job
    job_config = LoadJobConfig(
        source_format       = SourceFormat.PARQUET,
        write_disposition   = write_disposition,
        autodetect          = True,
    )

    # Run the load job
    client = get_bg_client()
    load_job = client.load_table_from_uri(gcs_uri, table_ref, job_config=job_config)

    # wait for the job to compelete
    load_job.result()

    logger.info(f"Loaded {table_name} into BigQuery ({write_disposition})")


def run_load (uploaded_tables):
    """
    Runs BigQuery load jobs for all uploaded tables.

    uploaded_tables - a dictionary of:
        {
            "table_name": {
                "blob_path": "raw/tbl_claim/2024-01-15/tbl_claim.parquet",
                "incremental": False
            }
        }
    """
    logger.info("Starting Bigquery Load")

    for table_name, metadata in uploaded_tables.items():
        blob_path = metadata["blob_path"]
        incremental = metadata["incremental"]

        write_disposition = (
            bigquery.WriteDisposition.WRITE_APPEND
            if incremental
            else bigquery.WriteDisposition.WRITE_TRUNCATE
        )

        load_gcs_to_bigquery(table_name, blob_path, write_disposition)
    logger.info("BigQuery load complete")
