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
    Service for consolidating JSON files into a single CSV file.
    """

    def __init__(self, storage: FileStoragePort, json_processor: JsonProcessorPort):
        self.storage = storage
        self.json_processor = json_processor

    def consolidate_files(
        self,
        source_prefix: str,
        consolidated_file_path: str,
        existing_metadata: FileMetadata = None,
    ) -> ConsolidationResult:
        """
        Main consolidation logic - pure business rules
        """
        try:
            logger.info(f"Starting consolidation for prefix: {source_prefix}")

            # 1. Determine which files to process
            new_files = self._get_new_files(source_prefix, existing_metadata)

            if not new_files:
                return ConsolidationResult(
                    success=True,
                    csv_content="",
                    metadata=existing_metadata or self._create_empty_metadata(),
                    files_processed=0,
                    error_message="No new files to process",
                )

            # 2. Process files (pure business logic)
            csv_content, new_metadata = self._process_files(new_files)

            # 3. Store result
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
        """Determine which files are new since last consolidation"""
        all_files = self.storage.list_files(prefix)
        json_files = [f for f in all_files if f.endswith(".json")]

        if not existing_metadata:
            return json_files

        # Filter files newer than last entry
        last_entry_timestamp = int(existing_metadata.last_entry.timestamp())
        new_files = []

        for file_path in json_files:
            try:
                file_timestamp = self.storage.get_file_timestamp_from_path(file_path)
                if file_timestamp > last_entry_timestamp:
                    new_files.append(file_path)
            except Exception as e:
                logger.warning(f"Could not parse timestamp from {file_path}: {e}")

        return new_files

    def _process_files(self, file_paths: List[str]) -> Tuple[str, FileMetadata]:
        """Process files into CSV - pure business logic"""
        all_flattened_data = []
        all_keys = set()
        latest_timestamp = None

        # First pass: collect all data and keys
        for file_path in file_paths:
            try:
                content = self.storage.get_file_content(file_path)
                json_data = json.loads(content)
                flattened = self.json_processor.flatten_json(json_data)

                all_flattened_data.append(flattened)
                all_keys.update(flattened.keys())

                # Track latest timestamp
                timestamp = flattened.get("metadata_timestamp", 0)
                if isinstance(timestamp, (int, float)) and timestamp > 0:
                    if latest_timestamp is None or timestamp > latest_timestamp:
                        latest_timestamp = timestamp

            except (json.JSONDecodeError, Exception) as e:
                logger.error(f"Error processing {file_path}: {e}")
                continue

        # Generate CSV
        sorted_keys = sorted(all_keys)
        csv_rows = [",".join(sorted_keys)]  # Header

        for flattened_data in all_flattened_data:
            row = self.json_processor.json_to_csv_row(flattened_data, sorted_keys)
            csv_rows.append(",".join(row))

        # Create metadata
        current_time = datetime.now()
        metadata = FileMetadata(
            created_at=current_time,
            last_entry=datetime.fromtimestamp(latest_timestamp)
            if latest_timestamp
            else current_time,
            description=f"Consolidated data from {len(file_paths)} JSON files",
            total_records=len(csv_rows) - 1,
            columns=len(sorted_keys),
            files_processed=len(file_paths),
        )

        # Combine metadata and CSV
        metadata_line = f"#{json.dumps(metadata.to_dict(), separators=(',', ': '))}"
        csv_content = metadata_line + "\n" + "\n".join(csv_rows)

        return csv_content, metadata

    def _create_empty_metadata(self) -> FileMetadata:
        """Create empty metadata for when no existing data exists"""
        return FileMetadata(
            created_at=datetime.now(),
            last_entry=datetime(2020, 1, 1),
            description="Empty consolidation",
            total_records=0,
            columns=0,
            files_processed=0,
        )
