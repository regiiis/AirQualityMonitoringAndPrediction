import json
import logging
from datetime import datetime
from typing import List, Tuple

from ..ports.file_storage_port import FileStoragePort
from ..ports.json_processor_port import JsonProcessorPort
from .models.file_metadata import FileMetadata, ConsolidationResult

logger = logging.getLogger(__name__)


class ConsolidationService:
    """
    Core business logic for JSON to CSV file consolidation.

    Handles incremental processing, metadata tracking, and optimized file discovery.
    Supports both initial consolidation and incremental updates.
    """

    def __init__(self, storage: FileStoragePort, json_processor: JsonProcessorPort):
        """
        Initialize consolidation service with required dependencies.

        Args:
            storage: File storage implementation (S3, local, etc.)
            json_processor: JSON processing implementation
        """
        self.storage = storage
        self.json_processor = json_processor

    def consolidate_files(
        self,
        source_prefix: str,
        consolidated_file_path: str,
        existing_metadata: FileMetadata = None,
    ) -> ConsolidationResult:
        """
        Consolidate JSON files into single CSV with metadata tracking.

        Args:
            source_prefix: S3 prefix for source JSON files
            consolidated_file_path: Output path for consolidated CSV
            existing_metadata: Previous consolidation metadata for incremental updates

        Returns:
            ConsolidationResult with success status, CSV content, and metadata
        """
        try:
            logger.info(f"Starting consolidation for prefix: {source_prefix}")

            # 1. Get new files using optimized method
            new_files = self._get_new_files(source_prefix, existing_metadata)

            if not new_files:
                logger.info("No new files to process")
                return ConsolidationResult(
                    success=True,
                    csv_content="",
                    metadata=existing_metadata or self._create_empty_metadata(),
                    files_processed=0,
                    error_message="No new files to process",
                )

            logger.info(f"Processing {len(new_files)} new files")

            # 2. Process files into CSV
            csv_content, new_metadata = self._process_files(
                new_files, existing_metadata
            )

            # 3. Store consolidated result
            success = self.storage.store_file(
                consolidated_file_path, csv_content, "text/csv"
            )

            return ConsolidationResult(
                success=success,
                csv_content=csv_content,
                metadata=new_metadata,
                files_processed=len(new_files),
                error_message=None if success else "Failed to store consolidated file",
            )

        except Exception as e:
            logger.error(f"Consolidation failed: {e}")
            return ConsolidationResult(
                success=False,
                csv_content="",
                metadata=existing_metadata or self._create_empty_metadata(),
                files_processed=0,
                error_message=str(e),
            )

    def _get_new_files(
        self, prefix: str, existing_metadata: FileMetadata = None
    ) -> List[str]:
        """
        Get new files since last consolidation using optimized filtering.

        Args:
            prefix: S3 prefix for source files
            existing_metadata: Previous consolidation metadata

        Returns:
            List of file paths to process
        """
        if not existing_metadata:
            # First run - get all JSON files
            logger.info("First consolidation run: getting all files")
            all_files = self.storage.list_files(prefix)
            json_files = [f for f in all_files if f.endswith(".json")]
            logger.info(f"Found {len(json_files)} JSON files for initial consolidation")
            return json_files

        # Incremental run - use timestamp-based filtering
        last_entry_timestamp = int(existing_metadata.last_entry.timestamp())
        logger.info(
            f"Incremental consolidation: looking for files after timestamp {last_entry_timestamp}"
        )
        logger.info(f"Last entry date: {existing_metadata.last_entry}")

        new_files = self.storage.list_files_after_timestamp(
            prefix, last_entry_timestamp
        )
        logger.info(f"Found {len(new_files)} new files since last consolidation")

        return new_files

    def _process_files(
        self, file_paths: List[str], existing_metadata: FileMetadata = None
    ) -> Tuple[str, FileMetadata]:
        """
        Process JSON files into CSV format with metadata tracking.

        Args:
            file_paths: List of file paths to process
            existing_metadata: Previous consolidation metadata

        Returns:
            Tuple of (CSV content string, updated metadata)
        """
        all_flattened_data = []
        all_keys = set()
        latest_timestamp = None
        processed_count = 0

        logger.info(f"Processing {len(file_paths)} files...")

        # Process each file
        for file_path in file_paths:
            try:
                content = self.storage.get_file_content(file_path)
                json_data = json.loads(content)
                flattened = self.json_processor.flatten_json(json_data)

                all_flattened_data.append(flattened)
                all_keys.update(flattened.keys())
                processed_count += 1

                # Track latest timestamp from data
                timestamp = flattened.get("metadata_timestamp", 0)
                if isinstance(timestamp, (int, float)) and timestamp > 0:
                    if latest_timestamp is None or timestamp > latest_timestamp:
                        latest_timestamp = timestamp

                if processed_count % 100 == 0:
                    logger.info(
                        f"Processed {processed_count}/{len(file_paths)} files..."
                    )

            except (json.JSONDecodeError, Exception) as e:
                logger.error(f"Error processing {file_path}: {e}")
                continue

        logger.info(f"Successfully processed {processed_count} files")

        # Generate CSV content
        sorted_keys = sorted(all_keys)
        csv_rows = [",".join(sorted_keys)]  # Header row

        for flattened_data in all_flattened_data:
            row = self.json_processor.json_to_csv_row(flattened_data, sorted_keys)
            csv_rows.append(",".join(row))

        # Create/update metadata
        current_time = datetime.now()
        if existing_metadata:
            # Update existing metadata for incremental consolidation
            new_metadata = FileMetadata(
                created_at=existing_metadata.created_at,
                last_entry=datetime.fromtimestamp(latest_timestamp)
                if latest_timestamp
                else current_time,
                description=f"Updated: processed {processed_count} new files",
                total_records=existing_metadata.total_records + len(all_flattened_data),
                columns=len(sorted_keys),
                files_processed=existing_metadata.files_processed + processed_count,
            )
        else:
            # Create new metadata for initial consolidation
            new_metadata = FileMetadata(
                created_at=current_time,
                last_entry=datetime.fromtimestamp(latest_timestamp)
                if latest_timestamp
                else current_time,
                description=f"Initial consolidation: processed {processed_count} files",
                total_records=len(all_flattened_data),
                columns=len(sorted_keys),
                files_processed=processed_count,
            )

        # Combine metadata header with CSV content
        metadata_line = f"#{json.dumps(new_metadata.to_dict(), separators=(',', ': '))}"
        csv_content = metadata_line + "\n" + "\n".join(csv_rows)

        return csv_content, new_metadata

    def _create_empty_metadata(self) -> FileMetadata:
        """
        Create empty metadata for error cases.

        Returns:
            FileMetadata with default values
        """
        return FileMetadata(
            created_at=datetime.now(),
            last_entry=datetime(2020, 1, 1),
            description="Empty consolidation",
            total_records=0,
            columns=0,
            files_processed=0,
        )
