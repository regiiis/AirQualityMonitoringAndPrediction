import boto3
import json
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
        Download a JSON file from S3 bucket and return its content.

        Args:
            file_name (str): The name of the file in the S3 bucket.

        Returns:
            str: Content of the JSON file
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
        Get the metadata of the consolidated CSV file from S3.
        For JSON source files, we extract timestamp from filename.

        Args:
            file_name (str): The name of the file in the S3 bucket.
        Returns:
            dict: Metadata of the file.
        """
        metadata = {}
        try:
            logger.info(f"Getting metadata for file: {file_name}")

            # If it's the consolidated CSV file, read metadata from first line
            if file_name.endswith(".csv"):
                content = self.get_file(file_name)
                lines = content.split("\n")

                if lines and lines[0].startswith("#"):
                    metadata_str = lines[0][1:]  # Remove the leading '#'

                    try:
                        # Parse as JSON directly - much cleaner!
                        metadata = json.loads(metadata_str)
                        logger.info(f"Successfully parsed JSON metadata: {metadata}")
                    except json.JSONDecodeError as e:
                        logger.error(f"Failed to parse JSON metadata: {e}")
                        # Fall back to key=value format for backward compatibility
                        logger.info("Falling back to key=value parsing")
                        metadata_items = metadata_str.split(",")
                        for item in metadata_items:
                            if "=" in item:
                                key, value = item.split("=", 1)
                                metadata[key.strip()] = value.strip()

            # If it's a JSON source file, extract timestamp from filename
            elif file_name.endswith(".json"):
                # Extract timestamp from filename: airq_20250626_221008.json
                parts = file_name.replace(".json", "").split("_")
                if len(parts) >= 3:
                    date_str = parts[1]  # 20250626
                    time_str = parts[2]  # 221008

                    # Convert to datetime
                    dt = datetime.strptime(f"{date_str}_{time_str}", "%Y%m%d_%H%M%S")
                    metadata["timestamp"] = dt.strftime("%d.%m.%Y_%H:%M:%S")
                    metadata["date"] = dt.strftime("%d.%m.%Y")

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

            # Create metadata line as JSON (much cleaner than key=value!)
            metadata_line = f"#{json.dumps(metadata, separators=(',', ': '))}"

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
        Get all JSON files in S3 bucket that have been added since the last consolidation.

        Args:
            prefix (str): The prefix to filter files in the S3 bucket.
            metadata (dict): Metadata containing the last entry date.

        Returns:
            list: List of new file names.
        """
        try:
            logger.info(f"Getting new JSON files with prefix: {prefix}")

            last_entry = metadata.get("last_entry", "01.01.2020_00:00:00")
            logger.info(f"Looking for files newer than: {last_entry}")

            # Parse last entry date - convert from DD.MM.YYYY_HH:MM:SS format
            last_entry_dt = datetime.strptime(last_entry, "%d.%m.%Y_%H:%M:%S")

            # List objects in S3 bucket
            paginator = self.s3_client.get_paginator("list_objects_v2")
            pages = paginator.paginate(Bucket=self.bucket_name, Prefix=prefix)

            new_files = []
            for page in pages:
                if "Contents" in page:
                    for obj in page["Contents"]:
                        # Only process JSON files
                        if not obj["Key"].endswith(".json"):
                            continue

                        # Extract timestamp from filename: airq_20250626_221008.json
                        try:
                            filename = obj["Key"].split("/")[
                                -1
                            ]  # Get filename without path
                            parts = filename.replace(".json", "").split("_")

                            if len(parts) >= 3 and parts[0] == "airq":
                                date_str = parts[1]  # 20250626
                                time_str = parts[2]  # 221008

                                # Convert to datetime
                                file_dt = datetime.strptime(
                                    f"{date_str}_{time_str}", "%Y%m%d_%H%M%S"
                                )

                                # Compare with last entry
                                if file_dt > last_entry_dt:
                                    new_files.append(obj["Key"])
                                    logger.info(
                                        f"Found new file: {obj['Key']} ({file_dt})"
                                    )
                        except Exception as e:
                            logger.warning(
                                f"Could not parse timestamp from {obj['Key']}: {e}"
                            )
                            continue

            logger.info(f"Found {len(new_files)} new files")
            return new_files

        except Exception as e:
            logger.error(f"Error listing new files: {str(e)}")
            return []

    def flatten_json(
        self, json_data: dict, parent_key: str = "", separator: str = "_"
    ) -> dict:
        """
        Flatten a nested JSON object into a single-level dictionary.

        Args:
            json_data: The nested JSON data
            parent_key: Parent key for nested items
            separator: Separator for nested keys

        Returns:
            dict: Flattened dictionary
        """
        items = []

        for key, value in json_data.items():
            new_key = f"{parent_key}{separator}{key}" if parent_key else key

            if isinstance(value, dict):
                # Recursively flatten nested dictionaries
                items.extend(self.flatten_json(value, new_key, separator).items())
            elif isinstance(value, list):
                # Handle lists (if any)
                for i, item in enumerate(value):
                    if isinstance(item, dict):
                        items.extend(
                            self.flatten_json(
                                item, f"{new_key}{separator}{i}", separator
                            ).items()
                        )
                    else:
                        items.append((f"{new_key}{separator}{i}", item))
            else:
                items.append((new_key, value))

        return dict(items)

    def consolidate_files(self, file_names: List[str]) -> str:
        """
        Consolidate files with dynamic CSV header generation.
        """
        try:
            logger.info(f"Consolidating {len(file_names)} JSON files into CSV")

            all_flattened_data = []
            all_keys = set()

            # First pass: collect all possible keys
            for file_name in file_names:
                content = self.get_file(file_name)
                try:
                    json_data = json.loads(content)
                    flattened = self.flatten_json(json_data)
                    all_flattened_data.append((file_name, flattened))
                    all_keys.update(flattened.keys())
                except json.JSONDecodeError as e:
                    logger.error(f"Error parsing JSON from {file_name}: {e}")
                    continue

            # Create CSV header from all found keys
            sorted_keys = sorted(all_keys)
            csv_header = ",".join(sorted_keys)
            csv_rows = [csv_header]

            # Second pass: create CSV rows
            for file_name, flattened_data in all_flattened_data:
                row_values = []
                for key in sorted_keys:
                    value = flattened_data.get(key, "")
                    # Escape commas and quotes in CSV values
                    if isinstance(value, str) and ("," in value or '"' in value):
                        value = f'"{value.replace('"', '""')}"'
                    row_values.append(str(value))

                csv_rows.append(",".join(row_values))

            # Create final content
            current_time = datetime.now()
            metadata = {
                "created": current_time.strftime("%d.%m.%Y"),
                "updated": current_time.strftime("%d.%m.%Y"),
                "description": f"Consolidated data from {len(file_names)} JSON files",
                "total_records": len(csv_rows) - 1,
                "columns": len(sorted_keys),
            }

            metadata_line = "#" + ", ".join([f"{k}={v}" for k, v in metadata.items()])
            consolidated_content = metadata_line + "\n" + "\n".join(csv_rows)

            logger.info(
                f"Dynamic consolidation completed: {len(csv_rows) - 1} records, {len(sorted_keys)} columns"
            )
            return consolidated_content

        except Exception as e:
            logger.error(f"Error in dynamic consolidation: {str(e)}")
            raise

    def store_consolidated_file(
        self, file_name: str, bucket_name: str, new_files: List[str] = None
    ) -> Dict[str, Any]:
        """
        Store the consolidated CSV file in an S3 bucket.

        Args:
            file_name (str): The name of the consolidated file.
            bucket_name (str): The S3 bucket name.
            new_files (list): List of new files to consolidate.

        Returns:
            dict: Result with success status and metadata.
        """
        try:
            logger.info(f"Storing consolidated file: {file_name}")

            if not new_files:
                logger.warning("No new files provided for consolidation")
                return {"success": False, "error": "No files to consolidate"}

            # Generate consolidated content
            consolidated_content = self.consolidate_files(new_files)

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
