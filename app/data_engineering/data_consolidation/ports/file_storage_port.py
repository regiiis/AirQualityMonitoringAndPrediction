from abc import ABC, abstractmethod
from typing import List


class FileStoragePort(ABC):
    """
    Port for file storage operations.

    Defines the interface for file storage implementations (S3, local, etc.)
    with focus on simplicity and clean separation of concerns.
    """

    @abstractmethod
    def get_file_content(self, file_path: str) -> str:
        """
        Download file content.

        Args:
            file_path: Path/key to file

        Returns:
            File content as string
        """
        pass

    @abstractmethod
    def store_file(
        self, file_path: str, content: str, content_type: str = "text/plain"
    ) -> bool:
        """
        Store file content.

        Args:
            file_path: Path/key where to store file
            content: File content to store
            content_type: MIME type of content

        Returns:
            True if successful, False otherwise
        """
        pass

    @abstractmethod
    def list_files(self) -> List[str]:
        """
        List all files in the configured source location.

        Returns:
            List of file paths
        """
        pass

    @abstractmethod
    def list_files_with_prefix(self, prefix: str) -> List[str]:
        """
        List files starting with a specific prefix.

        Args:
            prefix: Prefix to filter files (e.g., "airq_20250629")

        Returns:
            List of file paths matching the prefix
        """
        pass
