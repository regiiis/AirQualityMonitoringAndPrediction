import boto3
import logging
from typing import List

from ..ports.file_storage_port import FileStoragePort

logger = logging.getLogger(__name__)


class S3StorageAdapter(FileStoragePort):
    """
    AWS S3 file operations adapter.

    Provides basic S3 file operations for the consolidation service.
    Focus on simplicity and reliability over optimization.

    Key Features:
    - Simple file listing and filtering
    - Direct S3 operations without complex optimizations
    - Uses S3 LastModified timestamps for filtering
    - Comprehensive error handling and logging

    Methods:
        get_file_content(file_path: str) -> str:
            Download and return the content of a file from S3.
        store_file(file_path: str, content: str, content_type: str) -> bool:
            Upload file content to S3.
        list_files() -> List[str]:
            List all JSON files in the configured source location.
        list_files_after_timestamp(last_entry: int) -> List[str]:
            List files newer than the given timestamp using S3 LastModified.
    """

    def __init__(
        self,
        bucket_name: str,
        sensor_data_path: str,
        consolidated_path: str,
        consolidated_filename: str,
    ):
        """
        Initialize S3 storage adapter.

        Args:
            bucket_name: S3 bucket name
            sensor_data_path: Where sensor JSON files are stored (e.g., "data/sensor/")
            consolidated_path: Where CSV files are stored (e.g., "data/consolidated/")
            consolidated_filename: Name of the consolidated CSV file (e.g., "consolidated_sensor_data.csv")
        """
        if not bucket_name:
            raise ValueError("bucket_name is required")
        if not sensor_data_path:
            raise ValueError("sensor_data_path is required")
        if not consolidated_path:
            raise ValueError("consolidated_path is required")
        if not consolidated_filename:
            raise ValueError("consolidated_filename is required")

        self.bucket_name = bucket_name
        self.sensor_data_path = sensor_data_path
        self.consolidated_path = consolidated_path
        self.consolidated_filename = consolidated_filename
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

    def store_file(self, file_path: str, content: str, content_type: str) -> bool:
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

    def list_files(self) -> List[str]:
        """
        List all JSON files in the sensor data path.
        Simple method for initial consolidation.
        """
        try:
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name, Prefix=self.sensor_data_path
            )

            files = []
            if "Contents" in response:
                for obj in response["Contents"]:
                    if obj["Key"].endswith(".json"):
                        files.append(obj["Key"])

            return files
        except Exception as e:
            logger.error(f"Error listing files: {e}")
            return []

    def list_files_after_timestamp(self, last_entry: int) -> List[str]:
        """
        List files newer than the given timestamp.
        Simple approach - get all files and filter by S3 LastModified.
        """
        try:
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name, Prefix=self.sensor_data_path
            )

            files = []
            if "Contents" in response:
                for obj in response["Contents"]:
                    # Use S3's LastModified timestamp for filtering
                    if (
                        obj["Key"].endswith(".json")
                        and obj["LastModified"].timestamp() > last_entry
                    ):
                        files.append(obj["Key"])

            return files
        except Exception as e:
            logger.error(f"Error listing files after timestamp: {e}")
            return []
