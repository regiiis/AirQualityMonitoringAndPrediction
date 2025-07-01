import json
import logging
from datetime import datetime
from typing import List, Tuple
import pandas as pd
from io import StringIO

from ports.file_storage_port import FileStoragePort
from ports.json_processor_port import JsonProcessorPort
from domain.models.file_metadata import FileMetadata, ConsolidationResult

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

                    # Fix: convert last_entry to Unix timestamp if it's a MicroPython timestamp
                    last_entry = metadata_dict.get("last_entry")
                    # If last_entry is an int and less than a plausible Unix timestamp (e.g., < 1_000_000_000), treat as MicroPython timestamp
                    if isinstance(last_entry, int) and last_entry < 1_000_000_000:
                        metadata_dict["last_entry"] = (
                            self._micropython_to_unix_timestamp(last_entry)
                        )

                    try:
                        existing_metadata = FileMetadata.from_dict(metadata_dict)
                        logger.info(
                            f"Successfully extracted metadata: {existing_metadata.total_records} records, last entry: {existing_metadata.last_entry}"
                        )
                    except Exception:
                        raise
                    # Load CSV as DataFrame, skipping the first metadata line
                    csv_data = "\n".join(lines[1:])
                    if csv_data.strip():
                        df_existing = pd.read_csv(StringIO(csv_data))
                    else:
                        df_existing = pd.DataFrame()
                    return self._append_new_data(
                        consolidated_filename, existing_metadata, df_existing
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
                csv_content="",
                metadata=self._create_empty_metadata(),
                files_processed=0,
                error_message=str(e),
            )

    def _append_new_data(
        self,
        consolidated_filename: str,
        existing_metadata: FileMetadata,
        df_existing: pd.DataFrame,
    ) -> ConsolidationResult:
        """Incremental consolidation - only process new files."""
        logger.info("Performing incremental consolidation")

        # Get the last entry timestamp as Unix timestamp
        last_entry_unix = int(existing_metadata.last_entry.timestamp())
        logger.info(f"Last entry Unix timestamp: {last_entry_unix}")

        # Optimize: Get files newer than last_entry using intelligent filtering
        new_files = self._get_new_files(last_entry_unix)

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
        csv_content, updated_metadata, df_new = self._process_json_files(
            new_files, existing_metadata
        )

        # Ensure column consistency when combining DataFrames
        if not df_existing.empty and not df_new.empty:
            # Get all unique columns from both DataFrames
            all_columns = list(
                set(df_existing.columns.tolist() + df_new.columns.tolist())
            )
            all_columns.sort()  # Sort for consistent ordering

            # Reindex both DataFrames to have the same columns
            df_existing_aligned = df_existing.reindex(
                columns=all_columns, fill_value=None
            )
            df_new_aligned = df_new.reindex(columns=all_columns, fill_value=None)

            # Combine the aligned DataFrames
            df_final = pd.concat(
                [df_existing_aligned, df_new_aligned], ignore_index=True
            )
        elif not df_existing.empty:
            df_final = df_existing
        else:
            df_final = df_new

        metadata_line = (
            f"#{json.dumps(updated_metadata.to_dict(), separators=(',', ': '))}"
        )
        csv_str = metadata_line + "\n" + df_final.to_csv(index=False)
        success = self.storage.store_file(consolidated_filename, csv_str, "text/csv")

        return ConsolidationResult(
            success=success,
            csv_content=csv_str,
            metadata=updated_metadata,
            files_processed=len(new_files),
        )

    def _get_new_files(self, last_entry_unix: int) -> List[str]:
        """
        Get files newer than the given timestamp using content-based filtering.

        This method gets all files and filters them by checking the actual JSON content
        timestamps (not filename timestamps) to ensure accurate filtering.
        """
        # Convert Unix timestamp back to MicroPython timestamp for comparison
        last_entry_micropython = last_entry_unix - 946684800
        logger.info(
            f"Looking for files with MicroPython timestamps newer than: {last_entry_micropython}"
        )

        # Get all files (we'll filter by content, not filename)
        all_files = self.storage.list_files()
        new_files = []

        logger.info(f"Checking {len(all_files)} files for content timestamps")

        for file_path in all_files:
            try:
                # Get the file content and check the actual JSON timestamp
                content = self.storage.get_file_content(file_path)
                json_data = json.loads(content)
                flattened = self.json_processor.flatten_json(json_data)

                # Get the timestamp from the JSON content
                json_timestamp = flattened.get("timestamp", 0)

                if (
                    isinstance(json_timestamp, (int, float))
                    and json_timestamp > last_entry_micropython
                ):
                    new_files.append(file_path)
                    logger.info(
                        f"Including file {file_path} with timestamp {json_timestamp}"
                    )
                else:
                    logger.info(
                        f"Skipping file {file_path} with timestamp {json_timestamp} (not newer than {last_entry_micropython})"
                    )

            except Exception as e:
                logger.warning(f"Error checking timestamp for {file_path}: {e}")
                continue

        logger.info(f"Found {len(new_files)} files newer than last entry")
        return new_files

    def _process_json_files(
        self, file_paths: List[str], existing_metadata: FileMetadata = None
    ) -> Tuple[str, FileMetadata, pd.DataFrame]:
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
                    # Convert MicroPython timestamp to Unix timestamp if needed
                    if timestamp < 1_000_000_000:  # Likely MicroPython timestamp
                        timestamp = self._micropython_to_unix_timestamp(int(timestamp))

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

        # Always define sorted_keys
        sorted_keys = sorted(all_keys) if all_keys else []
        # DataFrame for all data
        df = pd.DataFrame(all_flattened_data, columns=sorted_keys)

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
        csv_content = metadata_line + "\n" + df.to_csv(index=False)
        return csv_content, new_metadata, df

    def _get_file_timestamp_from_path(self, file_path: str) -> int:
        """
        Extract Unix timestamp from sensor-data JSON filename.

        Parses the airq_YYYYMMDD_HHMMSS.json filename format to extract timestamp.

        Args:
            file_path: S3 key path (e.g., "raw-data/airq_20250629_143022.json")

        Returns:
            Unix timestamp (seconds since 1970-01-01)

        Raises:
            ValueError: If filename doesn't match expected format
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

    #######################################################
    # Private methods for initial consolidation
    #######################################################

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
        csv_content, metadata, df = self._process_json_files(
            all_files, existing_metadata=None
        )
        metadata_line = f"#{json.dumps(metadata.to_dict(), separators=(',', ': '))}"
        csv_str = metadata_line + "\n" + df.to_csv(index=False)
        success = self.storage.store_file(consolidated_filename, csv_str, "text/csv")

        return ConsolidationResult(
            success=success,
            csv_content=csv_str,
            metadata=metadata,
            files_processed=len(all_files),
        )

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
