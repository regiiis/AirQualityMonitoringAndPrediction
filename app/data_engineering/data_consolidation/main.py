import os
import logging

from .domain.consolidation_service import ConsolidationService
from .adapters.s3_storage_adapter import S3StorageAdapter
from .adapters.json_processor_adapter import JsonProcessorAdapter

logger = logging.getLogger(__name__)


class FilesToCSV:
    """
    Main service for JSON to CSV consolidation with optimized S3 file processing.

    Orchestrates the complete consolidation pipeline: file discovery, processing,
    and CSV generation. Supports both initial and incremental consolidation.
    """

    def __init__(
        self,
        bucket_name: str = None,
        sensor_data_path: str = None,
        consolidated_path: str = None,
        consolidated_filename: str = None,
    ):
        """
        Initialize consolidation service with complete S3 configuration.

        Args:
            bucket_name: S3 bucket (or SOURCE_BUCKET_NAME env var)
            sensor_data_path: Sensor data location (or sensor_data_path env var, default: "raw-data/")
            consolidated_path: CSV storage path (or CONSOLIDATED_PATH env var, default: "consolidated/")
            consolidated_filename: CSV filename (or CONSOLIDATED_FILENAME env var, default: "sensor_data.csv")

        Raises:
            ValueError: If required configuration is missing
        """
        # Load configuration from parameters or environment
        try:
            self.bucket_name = bucket_name or os.getenv("SOURCE_BUCKET_NAME", None)
            self.sensor_data_path = sensor_data_path or os.getenv(
                "SENSOR_DATA_PATH", None
            )
            self.consolidated_path = consolidated_path or os.getenv(
                "CONSOLIDATED_PATH", None
            )
            self.consolidated_filename = consolidated_filename or os.getenv(
                "CONSOLIDATED_FILENAME", None
            )
        except Exception as e:
            logger.error(f"Error loading configuration: {e}")
            raise ValueError(
                "Failed to load configuration from environment variables or parameters"
            )

        # Validate required configuration
        if not self.bucket_name:
            raise ValueError("SOURCE_BUCKET_NAME environment variable is required")
        if not self.sensor_data_path:
            raise ValueError("SENSOR_DATA_PATH environment variable is required")
        if not self.consolidated_path:
            raise ValueError("CONSOLIDATED_PATH environment variable is required")
        if not self.consolidated_filename:
            raise ValueError("CONSOLIDATED_FILENAME environment variable is required")

        # Ensure trailing slash for paths
        if not self.sensor_data_path.endswith("/"):
            self.sensor_data_path += "/"
        if not self.consolidated_path.endswith("/"):
            self.consolidated_path += "/"

        # Initialize dependencies with complete configuration
        self.storage = S3StorageAdapter(
            bucket_name=self.bucket_name,
            sensor_data_path=self.sensor_data_path,
            consolidated_path=self.consolidated_path,
            consolidated_filename=self.consolidated_filename,
        )
        self.json_processor = JsonProcessorAdapter()
        self.consolidation_service = ConsolidationService(
            self.storage, self.json_processor
        )

        logger.info("Initialized FilesToCSV:")
        logger.info(f"  Bucket: {self.bucket_name}")
        logger.info(f"  Source: {self.sensor_data_path}")
        logger.info(f"  Output: {self.consolidated_path}{self.consolidated_filename}")

    def run_consolidation(self) -> dict:
        """
        Execute complete consolidation process using pre-configured paths.

        Returns:
            Dict with consolidation results:
            - status: "success" or "error"
            - files_processed: Number of files processed
            - total_records: Total records in consolidated CSV
            - columns: Number of CSV columns
            - last_entry: ISO timestamp of most recent data
            - error: Error message (if status is "error")
        """
        try:
            logger.info("Starting JSON to CSV consolidation process...")

            # Execute consolidation - service will handle file existence check internally
            result = self.consolidation_service.consolidate_files(
                consolidated_filename=f"{self.consolidated_path}{self.consolidated_filename}"
            )

            if result.success:
                logger.info("Consolidation completed successfully!")
                logger.info(f"Files processed: {result.files_processed}")
                logger.info(f"Total records: {result.metadata.total_records}")
                logger.info(f"Columns: {result.metadata.columns}")
                return {
                    "status": "success",
                    "files_processed": result.files_processed,
                    "total_records": result.metadata.total_records,
                    "columns": result.metadata.columns,
                    "last_entry": result.metadata.last_entry.isoformat(),
                }
            else:
                logger.error(f"Consolidation failed: {result.error_message}")
                return {"status": "error", "error": result.error_message}

        except Exception as e:
            logger.error(f"Error in consolidation process: {str(e)}")
            return {"status": "error", "error": str(e)}


def main():
    """
    Entry point for ECS task execution.

    Initializes the consolidation service and runs the complete process.
    Exits with code 1 on failure for proper ECS task status reporting.
    """
    try:
        service = FilesToCSV()
        result = service.run_consolidation()

        if result["status"] == "success":
            logger.info(f"Consolidation successful: {result}")
        else:
            logger.error(f"Consolidation failed: {result}")
            exit(1)

    except Exception as e:
        logger.error(f"Fatal error: {e}")
        exit(1)


if __name__ == "__main__":
    # Configure logging for standalone execution
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )
    main()
