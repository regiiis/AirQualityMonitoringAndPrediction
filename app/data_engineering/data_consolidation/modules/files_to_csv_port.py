from abc import ABC, abstractmethod
from typing import List, Dict, Any


class FilesToCSVPort(ABC):
    """
    Abstract base class for file to CSV conversion and metadata management.
    """

    @abstractmethod
    def get_file(self, file_name: str) -> Any:
        """
        Get the content of a CSV file.

        Args:
            file_name (str): The name of the file in the S3 bucket.

        Returns:
            Any: Content of the CSV file (could be string, list of rows, etc.)
        """
        pass

    @abstractmethod
    def get_metadata(self, file_name: str) -> Dict[str, Any]:
        """
        Get the metadata of a CSV file.

        Args:
            file_name (str): The name of the file in the S3 bucket.

        Returns:
            dict: Metadata of the file.
        """
        pass

    @abstractmethod
    def update_metadata(self, file_name: str, metadata: Dict[str, Any]) -> bool:
        """
        Update the metadata of a CSV file.

        Args:
            file_name (str): The name of the file in the S3 bucket.
            metadata (dict): Metadata to update.

        Returns:
            bool: True if update is successful, False otherwise.
        """
        pass

    @abstractmethod
    def get_new_files(self, prefix: str, metadata: Dict[str, Any]) -> List[str]:
        """
        Load all files in S3 bucket that have been added since the last metadata entry.

        Args:
            prefix (str): The prefix to filter files.
            metadata (dict): Metadata to compare against.

        Returns:
            list: List of new files.
        """
        pass

    @abstractmethod
    def consolidate_files(self, file_names: List[str]) -> str:
        """
        Consolidate multiple CSV files into a single CSV file.

        Args:
            file_names (list): List of file names to consolidate.

        Returns:
            str: Name of the consolidated file.
        """
        pass

    @abstractmethod
    def store_consolidated_file(
        self, file_name: str, bucket_name: str
    ) -> Dict[str, Any]:
        """
        Store the consolidated CSV file in an S3 bucket.

        Args:
            file_name (str): The name of the consolidated file.
            bucket_name (str): The S3 bucket name.

        Returns:
            dict: Result with success status and filename or error message.
        """
        pass
