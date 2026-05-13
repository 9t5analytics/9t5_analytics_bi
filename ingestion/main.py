import logging
from dotenv import load_dotenv
from extract import run_extraction
from load import run_load


# Load environment variables
load_dotenv()

# Configure logging for the entire application

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)

logger = logging.getLogger(__name__)


def main ():
    """
    Main entry point for the ingestion pipeline.
    Runs extraction from MySQL then loads into BigQuery.
    """
    logger.info("Pipeline started")

    # Step 1 - Extract from MySQL and upload to GCS
    uploaded_tables = run_extraction()

     # Step 2 - Load from GCS into BigQuery

    run_load(uploaded_tables)

    logger.info("Pipeline completed successfully")

if __name__ == "__main__":
    main()