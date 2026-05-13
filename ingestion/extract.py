import os
import logging
import pandas as pd
from datetime import datetime, timezone
from dotenv import load_dotenv
from utils.gcs import upload_dataframe_to_gcs, get_gcs_client
from sqlalchemy import create_engine

# Loading environment variables from .env file
load_dotenv()

logger = logging.getLogger(__name__)

#Tables Configuration

# Tables that get full refresh every run
FULL_REFRESH_TABLES = [
    "tbl_customer",
    "tbl_customer_vehicle",
    "tbl_customer_vehicle_insurance",
    "tbl_customer_vehicle_driver",
    "tbl_claim",
    "tbl_claim_driver",
    "tbl_thirdparty_car",
    "tbl_thirdparty_owner",
    "tbl_thirdparty_driver",
    "tbl_police_detail",
    "tbl_witness",
    "tbl_vehicle_after_accident",
    "tbl_claim_notes",
    "tbl_subscriptions",
    "tbl_payments",
    "tbl_claimstatus",
    "tbl_organization",
    "tbl_claimfault",
    "tbl_accidenttype",
    "tbl_vehicletype",
    "tbl_insurance",
    "tbl_premiumperiod",
    "tbl_policystatus",
    "tbl_policy",
    "tbl_valuationtype",
]

# Tables that use incremental loading based on created_at
INCREMENTAL_TABLES = [
    "tbl_claim_status_log",
    "tbl_payment_log",
    "tbl_activity_log",
]

# tbl_admin with specific columns only - no PII or auth tokens
ADMIN_COLUMNS = [
    "id",
    "organization_id",
    "firstName",
    "lastName",
    "role",
    "permission",
    "isActive",
    "created_at",
    "last_login",
]

# ── MySQL Connection ──────────────────────────────────────────────────────────────

def get_mysql_connection():
    """
    Creates and returns a SQLAlchemy engine for MySQL.
    pandas works natively with SQLAlchemy connections.
    """
    host     = os.getenv("MYSQL_HOST")
    port     = os.getenv("MYSQL_PORT", "3306")
    database = os.getenv("MYSQL_DATABASE")
    user     = os.getenv("MYSQL_USER")
    password = os.getenv("MYSQL_PASSWORD")

    connection_string = f"mysql+pymysql://{user}:{password}@{host}:{port}/{database}"
    engine = create_engine(connection_string)
    return engine

# ── Watermark Helpers ───────────────────────────────────────────────

def get_watermark(table_name, bucket_name):
    """
    Reads the last successful run timestamp for an
    incremental table from GCS.
    Returns None if no watermark exists yet (first run).
    """
    client = get_gcs_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(f"watermarks/{table_name}.txt")

    if blob.exists():
        watermark = blob.download_as_text()
        logger.info(f"Current watermark for {table_name}: {watermark}")
        return watermark    
    logger.info(f"No existing watermark for {table_name} - full load")
    return None

def update_watermark(table_name, bucket_name, timestamp):
    """
    Writes the current timestamp as the new watermark
    for an incremental table in GCS.
    """
    client = get_gcs_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(f"watermarks/{table_name}.txt")
    blob.upload_from_string(timestamp)
    logger.info(f"Updated watermark for {table_name} to {timestamp}")


# ── Extraction Functions ────────────────────────────────────────────

def extract_full_refresh (connection, table_name):
    """
    Extracts all rows from a table.
    Used for tables where rows get updated.
    """

    query = f"SELECT * FROM {table_name}"
    logger.info(f"Extracting full refresh: {table_name}")
    return pd.read_sql(query, connection)


def extract_incremental (connection, table_name, watermark):
    """
    Extracts only new rows since the last watermark.
    Used for append-only log tables.
    """
    if watermark:
        query = f"""
            SELECT *
            FROM {table_name}
            WHERE created_at > '{watermark}'
            ORDER by created_at ASC
        """
        logger.info(f"Extracting incremental: {table_name} since {watermark}")

    else:
        query = f"SELECT * FROM {table_name} ORDER BY created_at ASC"
        logger.info(f"Extracting full load: {table_name} (first run)")

    return pd.read_sql(query, connection)

def extract_admin(connection):
    """
    Extracts tbl_admin with specific columns only.
    Excludes PII and authentication credentials.
    """
    columns = ", ".join(ADMIN_COLUMNS)
    query = f"SELECT {columns} from tbl_admin"
    logger.info("Extracting tbl_admin with selected columns only")
    return pd.read_sql(query, connection)


# ── Main Extract Function ───────────────────────────────────────────
def run_extraction():
    """
    Runs the full extraction for all tables.
    Connects to MySQL, extracts each table,
    uploads to GCS, updates watermarks.
    """
    bucket_name = os.getenv("GCS_BUCKET_NAME")
    run_timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    logger.info("Starting extraction from MySQL")
    # Open one MySQL connection for the entire run
    connection = get_mysql_connection()

    uploaded_tables = {}

    try:
        # ── Full refresh tables
        for table_name in FULL_REFRESH_TABLES:
            df = extract_full_refresh(connection, table_name)
            blob_path = upload_dataframe_to_gcs(df, table_name, bucket_name)
            uploaded_tables[table_name] = {
                "blob_path": blob_path,
                "incremental": False
            }
            logger.info(f"Complete: {table_name} ({len(df)} rows)")
    
    # ── tbl_admin with column selection
        df_admin = extract_admin (connection)
        blob_path = upload_dataframe_to_gcs(df_admin, "tbl_admin", bucket_name)
        uploaded_tables["tbl_admin"] = {
            "blob_path": blob_path,
            "incremental": False
        }
        logger.info(f"Completed: tbl_admin ({len(df_admin)} rows)")

     # ── Incremental tables

        for table_name in INCREMENTAL_TABLES:
            watermark = get_watermark(table_name, bucket_name)
            df = extract_incremental(connection, table_name, watermark)

            if df.empty:
                logger.info(f"No New rows for {table_name} - skipping upload")
                continue

            blob_path = upload_dataframe_to_gcs(df, table_name, bucket_name)
            uploaded_tables[table_name] = {
                "blob_path": blob_path,
                "incremental": True
            }
            update_watermark(table_name, bucket_name, run_timestamp)
            logger.info(f"Completed: {table_name} ({len(df)} rows)")

    finally:
        connection.close()
        logger.info("MySQL connection closed")

    logger.info("Extraction Complete")
    return uploaded_tables