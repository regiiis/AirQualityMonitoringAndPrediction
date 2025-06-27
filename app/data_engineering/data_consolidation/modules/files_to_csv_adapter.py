import boto3

from app.data_engineering.modules.files_to_csv_port import FilesToCSVPort
from abc import abstractmethod


@abstractmethod
class FilesToCSVAdapter(FilesToCSVPort):
    def __init__(self, db_name, file_name):
        self.db_name = db_name
        self.file_name = file_name
        self.s3_client = boto3.client("s3")

    def get_file(self, file_name):
        """
        Download a CSV file from S3 bucket.

        Args:
            file_name (str): The name of the file in the S3 bucket.

        Returns:
            bool: True if download is successful, False otherwise.
        """
        try:
            self.s3_client.download_file(self.bucket_name, file_name)
            return True
        except Exception as e:
            print(f"Error downloading file {file_name}: {str(e)}")
            return False

    def get_metadata(self, file_name):
        """
        Get the metadata of a CSV file. Metadata is stored in the first line and starts with "#".
        The file is loaded into variable `file_name`.

        Metadata:
         - created: dd.mm.yyyy,
         - updated: dd.mm.yyyy,
         - last_entry: dd.mm.yyyy_hh:mm:ss,
         - description: "description of the file"

        Args:
            file_name (str): The name of the file in the S3 bucket.
        Returns:
            dict: Metadata of the file.
        """
        metadata = {}
        try:
            with open(file_name, "r") as file:
                first_line = file.readline().strip()
                if first_line.startswith("#"):
                    metadata_str = first_line[1:]  # Remove the leading '#'
                    metadata_items = metadata_str.split(",")
                    for item in metadata_items:
                        key, value = item.split("=")
                        metadata[key.strip()] = value.strip()
        except Exception as e:
            print(f"Error reading metadata from {file_name}: {str(e)}")
        return metadata

    def update_metadata(self, file_name, metadata):
        """
        Update the metadata of a CSV file. Metadata is stored in the first line and starts with "#".
        The file is loaded into variable `file_name`.

        Metadata:
         - created: dd.mm.yyyy,
         - updated: dd.mm.yyyy,
         - last_entry: dd.mm.yyyy_hh:mm:ss,
         - description: "description of the file"

        Args:
            file_name (str): The name of the file in the S3 bucket.
            metadata (dict): Metadata to update.

        Returns:
            bool: True if update is successful, False otherwise.
        """
        try:
            with open(file_name, "r+") as file:
                lines = file.readlines()
                if lines:
                    # Update the first line with new metadata
                    new_metadata_str = ", ".join(
                        [f"{key}={value}" for key, value in metadata.items()]
                    )
                    lines[0] = f"#{new_metadata_str}\n"
                    file.seek(0)
                    file.writelines(lines)
                else:
                    print("File is empty, cannot update metadata.")
            return True
        except Exception as e:
            print(f"Error updating metadata in {file_name}: {str(e)}")
            return False

    def get_new_files(self, prefix, metadata):
        """
        Load all files in S3 bucket that have been added since the last metadata{last_entry: dd.mm.yyyy_hh:mm:ss}.

        Args:
            prefix (str): The prefix to filter files in the S3 bucket.
            metadata (dict): Metadata containing the last entry date.

        Returns:
            list: List of new file names.
        """
        try:
            last_entry = metadata.get("last_entry", None)
            if not last_entry:
                print("No last entry date found in metadata.")
                return []
            last_entry_date = last_entry.split("_")[0]  # Extract date part
            last_entry_date = last_entry_date.replace(
                ".", "-"
            )  # Convert to a format suitable for comparison
            # List all abject that are newer than the last entry date
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name, Prefix=prefix
            )
            if "Contents" not in response:
                print("No files found in the specified prefix.")
                return []
            new_files = []
            for obj in response["Contents"]:
                file_date = obj["LastModified"].strftime(
                    "%d-%m-%Y"
                )  # Convert to dd-mm-yyyy format
                if file_date > last_entry_date:
                    new_files.append(obj["Key"])
            if not new_files:
                print("No new files found since the last entry date.")
            else:
                print(f"New files found since {last_entry_date}")

            return new_files
        except Exception as e:
            print(f"Error listing new files: {str(e)}")
            return []

    def consolidate_files(self, prefix):
        """
        Consolidate files from S3 bucket with the given prefix.

        Args:
            prefix (str): The prefix to filter files in the S3 bucket.

        Returns:
            list: List of consolidated file names.
        """
        try:
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name, Prefix=prefix
            )
            if "Contents" not in response:
                return []

            consolidated_files = []
            for obj in response["Contents"]:
                consolidated_files.append(obj["Key"])

            return consolidated_files
        except Exception as e:
            print(f"Error consolidating files: {str(e)}")
            return []

    def store_consolidated_file(self, file_name, bucket_name):
        """
        Store a consolidated CSV file in the S3 bucket.

        Args:
            file_name (str): The name of the consolidated file.
            bucket_name (str): The name of the S3 bucket.

        Returns:
            dict: Metadata of the stored file.
        """
        try:
            self.s3_client.upload_file(file_name, bucket_name, file_name)
            metadata = self.get_metadata(file_name)
            return metadata
        except Exception as e:
            print(f"Error storing consolidated file {file_name}: {str(e)}")
            return {}
