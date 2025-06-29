import os
import logging

from .domain.consolidation_service import ConsolidationService
from .domain.models.file_metadata import FileMetadata
from .adapters.s3_storage_adapter import S3StorageAdapter
from .adapters.json_processor_adapter import AdvancedJsonProcessorAdapter

logger = logging.getLogger(__name__)


class FilesToCSV:
    def __init__(self, bucket_name: str = None, consolidated_file_name: str = None):
        """
        Initialize FilesToCSV service with dependency injection.
        """
        # Get configuration
        self.bucket_name = bucket_name or os.getenv("SOURCE_BUCKET_NAME")
        self.consolidated_file_name = consolidated_file_name or os.getenv(
            "CONSOLIDATED_FILE_NAME"
        )

        if not self.bucket_name:
            raise ValueError("SOURCE_BUCKET_NAME environment variable is required")
        if not self.consolidated_file_name:
            raise ValueError("CONSOLIDATED_FILE_NAME environment variable is required")

        # Dependency injection - easy to swap implementations
        self.storage = S3StorageAdapter(self.bucket_name)
        self.json_processor = AdvancedJsonProcessorAdapter(
            preserve_types=True, null_value=""
        )

        # Core business logic service
        self.consolidation_service = ConsolidationService(
            self.storage, self.json_processor
        )

        logger.info(f"Initialized FilesToCSV for bucket: {self.bucket_name}")

    def run_consolidation(self, source_prefix: str = "raw-data/") -> dict:
        """
        Run the complete consolidation process.
        """
        try:
            logger.info("Starting JSON to CSV consolidation process...")

            # Get existing metadata if consolidated file exists
            existing_metadata = self._get_existing_metadata()

            # Run consolidation
            result = self.consolidation_service.consolidate_files(
                source_prefix=source_prefix,
                consolidated_file_path=self.consolidated_file_name,
                existing_metadata=existing_metadata,
            )

            if result.success:
                logger.info(
                    f"Consolidation completed: {result.files_processed} files processed"
                )
                return {
                    "status": "success",
                    "files_processed": result.files_processed,
                    "total_records": result.metadata.total_records,
                    "columns": result.metadata.columns,
                }
            else:
                logger.error(f"Consolidation failed: {result.error_message}")
                return {"status": "error", "error": result.error_message}

        except Exception as e:
            logger.error(f"Error in consolidation process: {str(e)}")
            return {"status": "error", "error": str(e)}

    def _get_existing_metadata(self) -> FileMetadata:
        """Get metadata from existing consolidated file"""
        try:
            content = self.storage.get_file_content(self.consolidated_file_name)
            lines = content.split("\n")

            if lines and lines[0].startswith("#"):
                import json

                metadata_str = lines[0][1:]  # Remove '#'
                metadata_dict = json.loads(metadata_str)
                return FileMetadata.from_dict(metadata_dict)

        except Exception as e:
            logger.info(f"No existing metadata found: {e}")

        return None


def main():
    """Entry point for ECS task"""
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
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )
    main()
