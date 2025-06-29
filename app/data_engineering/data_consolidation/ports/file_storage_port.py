from abc import ABC, abstractmethod
from typing import List


class FileStoragePort(ABC):
    """
    Port for file storage operations with optimized filtering capabilities.

    Defines the interface for file storage implementations (S3, local, etc.)
    with focus on efficient timestamp-based file discovery.
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
    def list_files(self, prefix: str) -> List[str]:
        """
        List all files with given prefix.

        Args:
            prefix: Path prefix to filter files

        Returns:
            List of file paths matching prefix
        """
        pass

    @abstractmethod
    def list_files_after_timestamp(
        self, prefix: str, after_timestamp: int
    ) -> List[str]:
        """
        Efficiently list files created after given timestamp.

        Core optimization method that should minimize data transfer
        and API calls by leveraging implementation-specific features.

        Args:
            prefix: Path prefix to filter files
            after_timestamp: Unix timestamp - only return files newer than this

        Returns:
            List of file paths created after the timestamp
        """
        pass
