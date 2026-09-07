import os
import subprocess
import gzip
import shutil
import logging
from datetime import datetime, timezone
from google.cloud import storage
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


def get_gcs_client():
    return storage.Client(project=os.getenv("GCP_PROJECT_ID"))


def run_backup():
    # Connection details
    host        = os.getenv("MYSQL_HOST")
    port        = os.getenv("MYSQL_PORT", "10357")
    database    = os.getenv("MYSQL_DATABASE")
    user        = os.getenv("MYSQL_USER")
    password    = os.getenv("MYSQL_PASSWORD")
    bucket_name = os.getenv("GCS_BUCKET_NAME")

    # File paths
    today           = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    backup_filename = f"{database}_{today}.sql"
    compressed_file = f"/tmp/{backup_filename}.gz"
    blob_path       = f"backups/{today}/{backup_filename}.gz"

    logger.info(f"Starting backup of {database}")

    # Run mysqldump
    logger.info("Running mysqldump...")
    dump_command = [
        "mysqldump",
        f"--host={host}",
        f"--port={port}",
        f"--user={user}",
        f"--password={password}",
        "--ssl",
        "--ssl-verify-server-cert=false",
        "--single-transaction",
        "--routines",
        "--triggers",
        database
    ]

    with gzip.open(compressed_file, "wb") as gz_file:
        result = subprocess.run(
            dump_command,
            stdout=gz_file,
            stderr=subprocess.PIPE
        )

    if result.returncode != 0:
        error = result.stderr.decode()
        raise Exception(f"mysqldump failed: {error}")

    logger.info(f"Dump completed — compressed to {compressed_file}")

    # Upload to GCS
    logger.info(f"Uploading to gs://{bucket_name}/{blob_path}")
    client = get_gcs_client()
    bucket = client.bucket(bucket_name)
    blob   = bucket.blob(blob_path)
    blob.upload_from_filename(compressed_file)

    # Clean up temp file
    os.remove(compressed_file)

    logger.info(f"Backup complete — gs://{bucket_name}/{blob_path}")


if __name__ == "__main__":
    run_backup()