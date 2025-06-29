import os
import logging
from data_consolidation.modules.files_to_csv_adapter import FilesToCSVAdapter

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class FilesToCSV:
    def __init__(self, bucket_name: str = False, consolidated_file_name: str = False):
        """
        Initialize FilesToCSV service.

        Args:
            bucket_name: S3 bucket name for source files
            consolidated_file_name: Name for the consolidated output file
        """
        if not bucket_name:
            self.bucket_name = os.getenv("SOURCE_BUCKET_NAME")
            if not bucket_name:
                raise ValueError("SOURCE_BUCKET_NAME environment variable is required")

        if not consolidated_file_name:
            self.consolidated_file_name = os.getenv("CONSOLIDATED_FILE_NAME", False)
            if not consolidated_file_name:
                raise ValueError(
                    "CONSOLIDATED_FILE_NAME environment variable is required"
                )
        self.adapter = FilesToCSVAdapter(bucket_name, consolidated_file_name)
        logger.info(f"Initialized FilesToCSV with bucket: {bucket_name}")

    def get_file(self, file_name: str):
        """Get file from S3 bucket."""
        try:
            return self.adapter.get_file(file_name)
        except Exception as e:
            logger.error(f"Error getting file {file_name}: {str(e)}")
            raise

    def get_metadata(self, file_name: str):
        """Get metadata from file."""
        try:
            return self.adapter.get_metadata(file_name)
        except Exception as e:
            logger.error(f"Error getting metadata for {file_name}: {str(e)}")
            raise

    def update_metadata(self, file_name: str, metadata: dict):
        """Update file metadata."""
        try:
            return self.adapter.update_metadata(file_name, metadata)
        except Exception as e:
            logger.error(f"Error updating metadata for {file_name}: {str(e)}")
            raise

    def get_new_files(self, prefix: str, metadata: dict):
        """Get new files since last consolidation."""
        try:
            return self.adapter.get_new_files(prefix, metadata)
        except Exception as e:
            logger.error(f"Error getting new files with prefix {prefix}: {str(e)}")
            raise

    def consolidate_files(self, file_names: list):
        """Consolidate multiple files."""
        try:
            return self.adapter.consolidate_files(file_names)
        except Exception as e:
            logger.error(f"Error consolidating files: {str(e)}")
            raise

    def store_consolidated_file(self, file_name: str, bucket_name: str):
        """Store consolidated file."""
        try:
            return self.adapter.store_consolidated_file(file_name, bucket_name)
        except Exception as e:
            logger.error(f"Error storing consolidated file {file_name}: {str(e)}")
            raise

    def run_consolidation(self, source_prefix: str = "raw-data/"):
        """
        Run the complete consolidation process.

        Args:
            source_prefix: S3 prefix for source files
        """
        try:
            logger.info("Starting data consolidation process...")

            # Get current metadata to find new files
            try:
                metadata = self.get_metadata(self.consolidated_file_name)
                logger.info(f"Found existing metadata: {metadata}")
            except Exception:
                # No existing consolidated file, start fresh
                metadata = {"last_entry": "01.01.2020_00:00:00"}
                logger.info("No existing metadata found, starting fresh consolidation")

            # Get new files to process
            new_files = self.get_new_files(source_prefix, metadata)

            if not new_files:
                logger.info("No new files to consolidate")
                return {"status": "success", "message": "No new files to process"}

            logger.info(f"Found {len(new_files)} new files to consolidate")

            # Consolidate files
            # consolidated_data = self.consolidate_files(new_files)

            # Store consolidated file
            result = self.store_consolidated_file(
                self.consolidated_file_name, self.bucket_name
            )

            logger.info("Data consolidation completed successfully")
            return {
                "status": "success",
                "files_processed": len(new_files),
                "result": result,
            }

        except Exception as e:
            logger.error(f"Error in consolidation process: {str(e)}")
            raise


def main():
    """Main entry point for the data consolidation service."""
    try:
        # Get configuration from environment variables
        bucket_name = os.getenv("SOURCE_BUCKET_NAME")
        consolidated_file_name = os.getenv(
            "CONSOLIDATED_FILE_NAME", "consolidated_data.csv"
        )
        source_prefix = os.getenv("SOURCE_PREFIX", "raw-data/")

        if not bucket_name:
            raise ValueError("SOURCE_BUCKET_NAME environment variable is required")

        logger.info("Starting data consolidation service...")
        logger.info(f"Source bucket: {bucket_name}")
        logger.info(f"Consolidated file: {consolidated_file_name}")
        logger.info(f"Source prefix: {source_prefix}")

        # Initialize and run consolidation
        consolidator = FilesToCSV(bucket_name, consolidated_file_name)
        result = consolidator.run_consolidation(source_prefix)

        logger.info(f"Consolidation completed: {result}")

    except Exception as e:
        logger.error(f"Fatal error in main: {str(e)}")
        raise


if __name__ == "__main__":
    main()
