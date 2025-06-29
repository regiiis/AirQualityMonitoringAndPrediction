import boto3
import logging
from datetime import datetime
from typing import List

from ..ports.file_storage_port import FileStoragePort

logger = logging.getLogger(__name__)


class S3StorageAdapter(FileStoragePort):
    """AWS S3 specific implementation"""

    def __init__(self, bucket_name: str):
        self.bucket_name = bucket_name
        self.s3_client = boto3.client("s3")

    def get_file_content(self, file_path: str) -> str:
        """Get file content from S3"""
        try:
            response = self.s3_client.get_object(Bucket=self.bucket_name, Key=file_path)
            return response["Body"].read().decode("utf-8")
        except Exception as e:
            logger.error(f"Error downloading {file_path}: {e}")
            raise

    def store_file(
        self, file_path: str, content: str, content_type: str = "text/plain"
    ) -> bool:
        """Store file to S3"""
        try:
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=file_path,
                Body=content.encode("utf-8"),
                ContentType=content_type,
            )
            return True
        except Exception as e:
            logger.error(f"Error storing {file_path}: {e}")
            return False

    def list_files(self, prefix: str) -> List[str]:
        """List files in S3 with prefix"""
        try:
            paginator = self.s3_client.get_paginator("list_objects_v2")
            pages = paginator.paginate(Bucket=self.bucket_name, Prefix=prefix)

            files = []
            for page in pages:
                if "Contents" in page:
                    files.extend([obj["Key"] for obj in page["Contents"]])
            return files
        except Exception as e:
            logger.error(f"Error listing files with prefix {prefix}: {e}")
            return []

    def get_file_timestamp_from_path(self, file_path: str) -> int:
        """Extract timestamp from airq_YYYYMMDD_HHMMSS.json format"""
        filename = file_path.split("/")[-1]
        parts = filename.replace(".json", "").split("_")

        if len(parts) >= 3 and parts[0] == "airq":
            date_str = parts[1]  # 20250626
            time_str = parts[2]  # 221008
            dt = datetime.strptime(f"{date_str}_{time_str}", "%Y%m%d_%H%M%S")
            return int(dt.timestamp())

        raise ValueError(f"Cannot parse timestamp from {file_path}")
