import boto3
import logging
from datetime import datetime, timedelta
from typing import List

from ..ports.file_storage_port import FileStoragePort

logger = logging.getLogger(__name__)


class S3StorageAdapter(FileStoragePort):
    """
    AWS S3 file filtering and download.

    This adapter provides efficient file operations for S3, leveraging filename-based
    filtering to minimize data transfer and API calls. Optimized for airq sensor data
    files with naming convention: airq_YYYYMMDD_HHMMSS.json

    Key Features:
    - Date-based S3 prefix filtering for performance optimization
    - Filename-based timestamp parsing to avoid duplicate processing
    - Paginated S3 operations for handling large datasets
    - Comprehensive error handling and logging
    """

    def __init__(self, bucket_name: str):
        """
        Initialize S3 storage adapter.

        Args:
            bucket_name (str): AWS S3 bucket name where files are stored

        Raises:
            Exception: If S3 client initialization fails (AWS credentials, permissions)
        """
        self.bucket_name = bucket_name
        self.s3_client = boto3.client("s3")

    def get_file_content(self, file_path: str) -> str:
        """
        Download and return the content of a file from S3.

        This method downloads the actual JSON content from S3 for processing.
        Used in the consolidation pipeline to retrieve sensor data files.

        Args:
            file_path (str): S3 key/path to the file (e.g., "raw-data/airq_20250629_143022.json")

        Returns:
            str: File content as UTF-8 decoded string (JSON format)

        Raises:
            Exception: If file download fails (file not found, network issues, permissions)

        Example:
            >>> adapter = S3StorageAdapter("my-sensor-bucket")
            >>> content = adapter.get_file_content("raw-data/airq_20250629_143022.json")
            >>> json_data = json.loads(content)
        """
        try:
            response = self.s3_client.get_object(Bucket=self.bucket_name, Key=file_path)
            return response["Body"].read().decode("utf-8")
        except Exception as e:
            logger.error(f"Error downloading {file_path}: {e}")
            raise

    def store_file(
        self, file_path: str, content: str, content_type: str = "text/plain"
    ) -> bool:
        """
        Upload file content to S3.

        Stores processed data (like consolidated CSV files) back to S3.
        Used to save consolidation results and metadata.

        Args:
            file_path (str): S3 key/path where file should be stored
            content (str): File content to upload (UTF-8 string)
            content_type (str, optional): MIME type for the file. Defaults to "text/plain".
                                        Use "text/csv" for CSV files.

        Returns:
            bool: True if upload successful, False otherwise

        Example:
            >>> adapter = S3StorageAdapter("my-sensor-bucket")
            >>> csv_content = "timestamp,temperature,humidity\\n..."
            >>> success = adapter.store_file("consolidated/sensor_data.csv", csv_content, "text/csv")
        """
        try:
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=file_path,
                Body=content.encode("utf-8"),
                ContentType=content_type,
            )
            logger.info(f"Successfully stored {file_path}")
            return True
        except Exception as e:
            logger.error(f"Error storing {file_path}: {e}")
            return False

    def list_files(self, prefix: str) -> List[str]:
        """
        List all files in S3 with given prefix.

        This method retrieves all file paths matching the prefix. Should only be used
        for initial consolidation runs or when you need all files. For incremental
        updates, use list_files_after_timestamp() for better performance.

        Args:
            prefix (str): S3 key prefix to filter files (e.g., "raw-data/")

        Returns:
            List[str]: List of S3 file paths/keys matching the prefix

        Note:
            This method can be expensive for large datasets. For incremental processing,
            prefer list_files_after_timestamp() which uses optimized filtering.

        Example:
            >>> adapter = S3StorageAdapter("my-sensor-bucket")
            >>> all_files = adapter.list_files("raw-data/")
            >>> print(f"Found {len(all_files)} total files")
        """
        try:
            logger.info(f"Listing all files with prefix: {prefix}")
            paginator = self.s3_client.get_paginator("list_objects_v2")
            pages = paginator.paginate(Bucket=self.bucket_name, Prefix=prefix)

            files = []
            for page in pages:
                if "Contents" in page:
                    files.extend([obj["Key"] for obj in page["Contents"]])

            logger.info(f"Found {len(files)} total files")
            return files
        except Exception as e:
            logger.error(f"Error listing files with prefix {prefix}: {e}")
            return []

    def list_files_after_timestamp(self, prefix: str, last_entry: int) -> List[str]:
        """
        List files created after a specific timestamp.

        Uses date-based S3 prefixes combined with filename
        timestamp parsing to minimize data transfer and processing.

        Algorithm:
        1. Convert timestamp to date range (last_entry_date to today)
        2. For each date, create S3 prefix: "{prefix}airq_{YYYYMMDD}_"
        3. Download only files matching each daily prefix
        4. Parse filename timestamps and filter exactly

        Args:
            prefix (str): S3 key prefix for file location (e.g., "raw-data/")
            last_entry (int): Unix timestamp - only return files newer than this

        Returns:
            List[str]: List of file paths created after the timestamp, sorted by date

        Example:
            >>> adapter = S3StorageAdapter("my-sensor-bucket")
            >>> last_timestamp = 1719410222  # 2025-06-26 14:30:22
            >>> new_files = adapter.list_files_after_timestamp("raw-data/", last_timestamp)
            >>> print(f"Found {len(new_files)} new files since last consolidation")
        """
        try:
            after_datetime = datetime.fromtimestamp(last_entry)
            logger.info(
                f"Looking for files after: {after_datetime} (timestamp: {last_entry})"
            )

            # Use filename-based optimization
            files = self._list_files_by_date_range(prefix, after_datetime)

            logger.info(f"Found {len(files)} files after timestamp {last_entry}")
            return files

        except Exception as e:
            logger.error(f"Error listing files after timestamp: {e}")
            return []

    def _list_files_by_date_range(
        self, prefix: str, after_datetime: datetime
    ) -> List[str]:
        """
        Get files using date-based S3 prefixes.

        - Only queries S3 for dates between last_entry and today
        - Uses S3 prefixes to minimize data transfer
        - Handles same-day processing to avoid duplicates

        Args:
            prefix (str): Base S3 prefix for files
            after_datetime (datetime): Only return files after this datetime

        Returns:
            List[str]: Filtered list of file paths

        Internal Method - Used by list_files_after_timestamp()
        """
        files = []

        start_date = after_datetime.date()
        end_date = datetime.now().date()

        logger.info(f"Checking date range: {start_date} to {end_date}")

        current_date = start_date
        while current_date <= end_date:
            date_str = current_date.strftime("%Y%m%d")

            # Create date-specific S3 prefix
            date_based_s3_prefix = f"{prefix}airq_{date_str}_"

            logger.debug(f"Checking S3 prefix: {date_based_s3_prefix}")

            # Get files for this specific date and filter by exact timestamp
            files_from_date = self._get_files_for_date_prefix(
                date_based_s3_prefix, after_datetime.timestamp()
            )
            files.extend(files_from_date)

            current_date += timedelta(days=1)

        return files

    def _get_files_for_date_prefix(
        self, date_prefix: str, last_entry: float
    ) -> List[str]:
        """
        Get files for a specific date prefix and filter by exact timestamp.

        This method handles the S3 API interaction for a single date and performs
        timestamp filtering to prevent duplicate processing.

        Args:
            date_prefix (str): S3 prefix for specific date (e.g., "raw-data/airq_20250629_")
            last_entry (float): Unix timestamp for precise filtering

        Returns:
            List[str]: Files from this date that are newer than last_entry timestamp

        Process:
        1. Query S3 with date-specific prefix (only gets ~144 files vs 100,000+)
        2. For each file, parse timestamp from filename
        3. Include only files with timestamp > last_entry
        4. Skip files with invalid naming convention

        Internal Method - Used by _list_files_by_date_range()
        """
        try:
            # Query S3 with date-specific prefix for maximum efficiency
            paginator = self.s3_client.get_paginator("list_objects_v2")
            pages = paginator.paginate(Bucket=self.bucket_name, Prefix=date_prefix)

            files = []
            for page in pages:
                if "Contents" in page:
                    for obj in page["Contents"]:
                        key = obj["Key"]

                        # Parse timestamp from filename (fast string operation)
                        try:
                            file_timestamp = self._get_file_timestamp_from_path(key)
                            if file_timestamp > last_entry:
                                files.append(key)
                        except ValueError as e:
                            logger.debug(
                                f"Skipping file with invalid name format: {key} - {e}"
                            )
                            continue

            logger.debug(f"Found {len(files)} files for prefix {date_prefix}")
            return files

        except Exception as e:
            logger.error(f"Error getting files for date prefix {date_prefix}: {e}")
            return []

    def _get_file_timestamp_from_path(self, file_path: str) -> int:
        """
        Extract Unix timestamp from sensor data filename.

        Parses the airq_YYYYMMDD_HHMMSS.json filename format to extract the
        timestamp.

        Args:
            file_path (str): Full S3 path or filename to parse

        Returns:
            int: Unix timestamp extracted from filename

        Raises:
            ValueError: If filename doesn't match expected format

        Examples:
            >>> adapter = S3StorageAdapter("bucket")
            >>> timestamp = adapter._get_file_timestamp_from_path("raw-data/airq_20250629_143022.json")
            >>> print(timestamp)  # 1719666622
            >>> datetime.fromtimestamp(timestamp)  # 2025-06-29 14:30:22

            >>> # Also works with just filename
            >>> timestamp = adapter._get_file_timestamp_from_path("airq_20250629_143022.json")
        """
        try:
            # Extract filename from full path
            filename = file_path.split("/")[-1]

            # Remove .json extension
            name_without_ext = filename.replace(".json", "")

            # Split by underscore: ["airq", "20250629", "143022"]
            parts = name_without_ext.split("_")

            if len(parts) >= 3 and parts[0] == "airq":
                date_str = parts[1]  # "20250629"
                time_str = parts[2]  # "143022"

                # Parse datetime from strings
                dt = datetime.strptime(f"{date_str}_{time_str}", "%Y%m%d_%H%M%S")
                return int(dt.timestamp())
            else:
                raise ValueError(
                    "Filename doesn't match airq_YYYYMMDD_HHMMSS.json format"
                )

        except (IndexError, ValueError) as e:
            raise ValueError(f"Cannot parse timestamp from {file_path}: {e}")
