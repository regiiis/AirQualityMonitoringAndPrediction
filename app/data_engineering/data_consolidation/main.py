import os
import logging
import json

from .domain.consolidation_service import ConsolidationService
from .domain.models.file_metadata import FileMetadata
from .adapters.s3_storage_adapter import S3StorageAdapter
from .adapters.json_processor_adapter import JsonProcessorAdapter

logger = logging.getLogger(__name__)


class FilesToCSV:
    """
    Main service for JSON to CSV consolidation with optimized S3 file processing.

    Orchestrates the complete consolidation pipeline: file discovery, processing,
    and CSV generation. Supports both initial and incremental consolidation.
    """

    def __init__(self, bucket_name: str = None, consolidated_file_name: str = None):
        """
        Initialize consolidation service with S3 configuration.

        Args:
            bucket_name: S3 bucket name (defaults to SOURCE_BUCKET_NAME env var)
            consolidated_file_name: Output CSV path (defaults to CONSOLIDATED_FILE_NAME env var)

        Raises:
            ValueError: If required configuration is missing
        """
        # Get configuration from parameters or environment
        self.bucket_name = bucket_name or os.getenv("SOURCE_BUCKET_NAME")
        self.consolidated_file_name = consolidated_file_name or os.getenv(
            "CONSOLIDATED_FILE_NAME"
        )

        if not self.bucket_name:
            raise ValueError("SOURCE_BUCKET_NAME environment variable is required")
        if not self.consolidated_file_name:
            raise ValueError("CONSOLIDATED_FILE_NAME environment variable is required")

        # Initialize dependencies with dependency injection
        self.storage = S3StorageAdapter(self.bucket_name)
        self.json_processor = JsonProcessorAdapter()
        self.consolidation_service = ConsolidationService(
            self.storage, self.json_processor
        )

        logger.info(f"Initialized FilesToCSV for bucket: {self.bucket_name}")

    def run_consolidation(self, source_prefix: str = "raw-data/") -> dict:
        """
        Execute complete consolidation process with optimized file discovery.

        Args:
            source_prefix: S3 prefix for source JSON files

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

            # Get existing metadata for incremental processing
            existing_metadata = self._get_existing_metadata()

            if existing_metadata:
                logger.info(
                    f"Found existing consolidation with {existing_metadata.total_records} records"
                )
                logger.info(f"Last entry: {existing_metadata.last_entry}")
            else:
                logger.info("No existing consolidation found - will process all files")

            # Execute consolidation
            result = self.consolidation_service.consolidate_files(
                source_prefix=source_prefix,
                consolidated_file_path=self.consolidated_file_name,
                existing_metadata=existing_metadata,
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

    def _get_existing_metadata(self) -> FileMetadata:
        """
        Extract metadata from existing consolidated CSV file.

        Reads the first line of the consolidated CSV to get metadata
        for incremental processing. Handles cases where no previous
        consolidation exists.

        Returns:
            FileMetadata object or None if no existing file found
        """
        try:
            content = self.storage.get_file_content(self.consolidated_file_name)
            lines = content.split("\n")

            if lines and lines[0].startswith("#"):
                metadata_str = lines[0][1:]  # Remove '#' prefix
                metadata_dict = json.loads(metadata_str)
                return FileMetadata.from_dict(metadata_dict)

        except Exception as e:
            logger.info(f"No existing metadata found: {e}")

        return None


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
