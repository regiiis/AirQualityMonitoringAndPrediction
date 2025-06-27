import boto3
import logging
from datetime import datetime
from typing import List, Dict, Any
from data_consolidation.modules.files_to_csv_port import FilesToCSVPort

logger = logging.getLogger(__name__)


class FilesToCSVAdapter(FilesToCSVPort):
    def __init__(self, bucket_name: str, consolidated_file_name: str):
        self.bucket_name = bucket_name
        self.consolidated_file_name = consolidated_file_name
        self.s3_client = boto3.client("s3")
        logger.info(f"Initialized FilesToCSVAdapter for bucket: {bucket_name}")

    def get_file(self, file_name: str) -> str:
        """
        Download a CSV file from S3 bucket and return its content.

        Args:
            file_name (str): The name of the file in the S3 bucket.

        Returns:
            str: Content of the CSV file
        """
        try:
            logger.info(f"Downloading file: {file_name}")
            response = self.s3_client.get_object(Bucket=self.bucket_name, Key=file_name)
            content = response["Body"].read().decode("utf-8")
            logger.info(f"Successfully downloaded file: {file_name}")
            return content
        except Exception as e:
            logger.error(f"Error downloading file {file_name}: {str(e)}")
            raise

    def get_metadata(self, file_name: str) -> Dict[str, Any]:
        """
        Get the metadata of a CSV file from S3. Metadata is stored in the first line and starts with "#".

        Args:
            file_name (str): The name of the file in the S3 bucket.
        Returns:
            dict: Metadata of the file.
        """
        metadata = {}
        try:
            logger.info(f"Getting metadata for file: {file_name}")
            content = self.get_file(file_name)
            lines = content.split("\n")

            if lines and lines[0].startswith("#"):
                metadata_str = lines[0][1:]  # Remove the leading '#'
                metadata_items = metadata_str.split(",")
                for item in metadata_items:
                    if "=" in item:
                        key, value = item.split("=", 1)
                        metadata[key.strip()] = value.strip()

            logger.info(f"Retrieved metadata: {metadata}")
            return metadata
        except Exception as e:
            logger.error(f"Error reading metadata from {file_name}: {str(e)}")
            return {}

    def update_metadata(self, file_name: str, metadata: Dict[str, Any]) -> bool:
        """
        Update the metadata of a CSV file in S3.

        Args:
            file_name (str): The name of the file in the S3 bucket.
            metadata (dict): Metadata to update.

        Returns:
            bool: True if update is successful, False otherwise.
        """
        try:
            logger.info(f"Updating metadata for file: {file_name}")

            # Get current file content
            try:
                content = self.get_file(file_name)
                lines = content.split("\n")
            except Exception:
                # File doesn't exist, create new one
                lines = []

            # Update metadata line
            new_metadata_str = ", ".join(
                [f"{key}={value}" for key, value in metadata.items()]
            )
            metadata_line = f"#{new_metadata_str}"

            if lines and lines[0].startswith("#"):
                lines[0] = metadata_line
            else:
                lines.insert(0, metadata_line)

            # Upload updated content
            updated_content = "\n".join(lines)
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=file_name,
                Body=updated_content.encode("utf-8"),
                ContentType="text/csv",
            )

            logger.info(f"Successfully updated metadata for: {file_name}")
            return True
        except Exception as e:
            logger.error(f"Error updating metadata in {file_name}: {str(e)}")
            return False

    def get_new_files(self, prefix: str, metadata: Dict[str, Any]) -> List[str]:
        """
        Get all files in S3 bucket that have been added since the last metadata entry.

        Args:
            prefix (str): The prefix to filter files in the S3 bucket.
            metadata (dict): Metadata containing the last entry date.

        Returns:
            list: List of new file names.
        """
        try:
            logger.info(f"Getting new files with prefix: {prefix}")

            last_entry = metadata.get("last_entry", "01.01.2020_00:00:00")
            logger.info(f"Looking for files newer than: {last_entry}")

            # Parse last entry date
            last_entry_date = datetime.strptime(last_entry.split("_")[0], "%d.%m.%Y")

            # List objects in S3 bucket
            paginator = self.s3_client.get_paginator("list_objects_v2")
            pages = paginator.paginate(Bucket=self.bucket_name, Prefix=prefix)

            new_files = []
            for page in pages:
                if "Contents" in page:
                    for obj in page["Contents"]:
                        # Compare file modification date with last entry
                        file_date = obj["LastModified"].replace(tzinfo=None)
                        if file_date > last_entry_date:
                            new_files.append(obj["Key"])

            logger.info(f"Found {len(new_files)} new files")
            return new_files

        except Exception as e:
            logger.error(f"Error listing new files: {str(e)}")
            return []

    def consolidate_files(self, file_names: List[str]) -> str:
        """
        Consolidate multiple CSV files into a single CSV file.

        Args:
            file_names (list): List of file names to consolidate.

        Returns:
            str: Content of the consolidated file.
        """
        try:
            logger.info(f"Consolidating {len(file_names)} files")

            consolidated_data = []

            for file_name in file_names:
                logger.info(f"Processing file: {file_name}")
                content = self.get_file(file_name)

                # Skip metadata line and empty lines
                lines = [
                    line
                    for line in content.split("\n")
                    if line.strip() and not line.startswith("#")
                ]

                consolidated_data.extend(lines)

            # Create consolidated content with metadata
            current_time = datetime.now()
            metadata = {
                "created": current_time.strftime("%d.%m.%Y"),
                "updated": current_time.strftime("%d.%m.%Y"),
                "last_entry": current_time.strftime("%d.%m.%Y_%H:%M:%S"),
                "description": f"Consolidated data from {len(file_names)} files",
            }

            metadata_line = "#" + ", ".join([f"{k}={v}" for k, v in metadata.items()])
            consolidated_content = metadata_line + "\n" + "\n".join(consolidated_data)

            logger.info("File consolidation completed")
            return consolidated_content

        except Exception as e:
            logger.error(f"Error consolidating files: {str(e)}")
            raise

    def store_consolidated_file(
        self, file_name: str, bucket_name: str
    ) -> Dict[str, Any]:
        """
        Store the consolidated CSV file in an S3 bucket.

        Args:
            file_name (str): The name of the consolidated file.
            bucket_name (str): The S3 bucket name.

        Returns:
            dict: Result with success status and metadata.
        """
        try:
            logger.info(f"Storing consolidated file: {file_name}")

            # This assumes consolidated content is already generated
            # In a real implementation, you'd get this from consolidate_files
            consolidated_content = self.consolidate_files(
                []
            )  # This needs the actual file list

            # Upload to S3
            self.s3_client.put_object(
                Bucket=bucket_name,
                Key=file_name,
                Body=consolidated_content.encode("utf-8"),
                ContentType="text/csv",
            )

            # Get metadata of stored file
            metadata = self.get_metadata(file_name)

            logger.info(f"Successfully stored consolidated file: {file_name}")
            return {"success": True, "filename": file_name, "metadata": metadata}

        except Exception as e:
            logger.error(f"Error storing consolidated file {file_name}: {str(e)}")
            return {"success": False, "error": str(e)}
