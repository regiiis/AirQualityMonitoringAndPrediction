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
        consolidated_filename: str,
    ) -> ConsolidationResult:
        """
        Consolidate JSON files into single CSV with metadata tracking.

        Logic:
        1. Try to download existing CSV file directly
        2. If download succeeds -> Extract metadata -> Incremental consolidation
        3. If download fails (file doesn't exist) -> Initial consolidation (process all files)
        """
        try:
            logger.info(f"Starting consolidation for file: {consolidated_filename}")

            # Try to download the existing CSV file directly
            try:
                logger.info(
                    f"Attempting to download existing CSV: {consolidated_filename}"
                )
                content = self.storage.get_file_content(consolidated_filename)
                logger.info("Existing CSV file found, extracting metadata...")

                # Extract metadata from the downloaded file
                lines = content.split("\n")
                if lines and lines[0].startswith("#"):
                    metadata_str = lines[0][1:]  # Remove '#' prefix
                    metadata_dict = json.loads(metadata_str)
                    existing_metadata = FileMetadata.from_dict(metadata_dict)
                    logger.info(
                        f"Successfully extracted metadata: {existing_metadata.total_records} records, last entry: {existing_metadata.last_entry}"
                    )

                    # Incremental consolidation - process only new files
                    logger.info(
                        f"Found existing CSV with {existing_metadata.total_records} records"
                    )
                    logger.info(f"Last entry: {existing_metadata.last_entry}")
                    return self._append_new_data(
                        consolidated_filename, existing_metadata
                    )
                else:
                    logger.warning(
                        "CSV file exists but has no metadata header - treating as new file"
                    )
                    # Fall through to initial consolidation

            except Exception as e:
                logger.info(
                    f"No existing CSV file found ({consolidated_filename}): {e}"
                )
                # Fall through to initial consolidation

            # Initial consolidation - process all files
            logger.info("No existing CSV found - performing initial consolidation")
            return self._generate_initial_csv(consolidated_filename)

        except Exception as e:
            logger.error(f"Consolidation failed: {e}")
            return ConsolidationResult(
                success=False,
                error_message=str(e),
            )

    def _generate_initial_csv(self, consolidated_filename: str) -> ConsolidationResult:
        """Simple initial consolidation - process ALL files in sensor data path."""
        logger.info("Performing initial consolidation of all sensor data")

        all_files = self.storage.list_files()

        if not all_files:
            logger.info("No files found in sensor data path")
            return ConsolidationResult(
                success=True,
                csv_content="",
                metadata=self._create_empty_metadata(),
                files_processed=0,
            )

        logger.info(f"Processing {len(all_files)} files for initial consolidation")
        csv_content, metadata = self._process_files(all_files, existing_metadata=None)

        # Use store_file directly - consolidated_filename is already the full path
        success = self.storage.store_file(
            consolidated_filename, csv_content, "text/csv"
        )

        return ConsolidationResult(
            success=success,
            csv_content=csv_content,
            metadata=metadata,
            files_processed=len(all_files),
        )

    def _append_new_data(
        self, consolidated_filename: str, existing_metadata: FileMetadata
    ) -> ConsolidationResult:
        """Incremental consolidation - only process new files."""
        logger.info("Performing incremental consolidation")

        # Convert MicroPython timestamp to Unix timestamp for S3 comparison
        micropython_timestamp = int(existing_metadata.last_entry.timestamp())
        unix_timestamp = self._micropython_to_unix_timestamp(micropython_timestamp)

        logger.info(f"Last entry MicroPython timestamp: {micropython_timestamp}")
        logger.info(f"Converted to Unix timestamp for S3 comparison: {unix_timestamp}")

        new_files = self.storage.list_files_after_timestamp(unix_timestamp)

        if not new_files:
            logger.info("No new files to process")
            return ConsolidationResult(
                success=True,
                csv_content="",
                metadata=existing_metadata,
                files_processed=0,
                error_message="No new files to process",
            )

        logger.info(f"Processing {len(new_files)} new files")
        csv_content, updated_metadata = self._process_files(
            new_files, existing_metadata
        )

        # Use store_file directly - consolidated_filename is already the full path
        success = self.storage.store_file(
            consolidated_filename, csv_content, "text/csv"
        )

        return ConsolidationResult(
            success=success,
            csv_content=csv_content,
            metadata=updated_metadata,
            files_processed=len(new_files),
        )

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

    def _micropython_to_unix_timestamp(self, mp_timestamp: int) -> int:
        """
        Convert MicroPython timestamp to Unix timestamp.

        MicroPython epoch starts at Jan 1, 2000
        Unix epoch starts at Jan 1, 1970
        Difference is 946684800 seconds (30 years)

        Args:
            mp_timestamp: MicroPython timestamp (seconds since 2000-01-01)

        Returns:
            Unix timestamp (seconds since 1970-01-01)
        """
        return mp_timestamp + 946684800

    def _get_file_timestamp_from_path(self, file_path: str) -> int:
        """
        Extract Unix timestamp from sensor data filename.

        Parses the airq_YYYYMMDD_HHMMSS.json filename format to extract timestamp.
        """
        try:
            filename = file_path.split("/")[-1]
            name_without_ext = filename.replace(".json", "")
            parts = name_without_ext.split("_")

            if len(parts) >= 3 and parts[0] == "airq":
                date_str = parts[1]  # "20250629"
                time_str = parts[2]  # "143022"
                dt = datetime.strptime(f"{date_str}_{time_str}", "%Y%m%d_%H%M%S")
                return int(dt.timestamp())
            else:
                raise ValueError(
                    "Filename doesn't match airq_YYYYMMDD_HHMMSS.json format"
                )
        except (IndexError, ValueError) as e:
            raise ValueError(f"Cannot parse timestamp from {file_path}: {e}")
