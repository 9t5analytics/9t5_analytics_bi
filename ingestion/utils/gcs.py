import os
import logging
from datetime import datetime
from google.cloud import storage

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def get_gcs_client():
    """
    Create and return a GCS Client
    Uses Application Default Credetials automatically
    """
    return storage.Client(project=os.getenv("GCP_PROJECT_ID"))


def upload_dataframe_to_gcs(dataframe, table_name, bucket_name):

    """
    Uploads a pandas DataFrame as a parquet file to GCS.

    Returns the GCS path where the file was uploaded.
    """

    # Build the path using today's date

    today = datetime.utcnow().strftime("%Y-%m-%d")
    blob_path = f"raw/{table_name}/{today}/{table_name}.parquet"

    # Converting dataframe to parguet file in memory
    parquet_bytes = dataframe.to_parquet(index=False)

    # Upload the parquet file to GCS
    client = get_gcs_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(blob_path)
    blob.upload_from_string(parquet_bytes, content_type="application/octet-stream")
    

    logger.info(f"Uploaded {table_name} to gs://{bucket_name}/{blob_path}")

    return blob_path