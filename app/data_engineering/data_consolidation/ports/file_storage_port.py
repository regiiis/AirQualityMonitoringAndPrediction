from abc import ABC, abstractmethod
from typing import List, Dict, Any


class FileStoragePort(ABC):
    """Port for file storage operations (technology agnostic)"""

    @abstractmethod
    def get_file_content(self, file_path: str) -> str:
        """Get raw file content"""
        pass

    @abstractmethod
    def store_file(
        self, file_path: str, content: str, content_type: str = "text/plain"
    ) -> bool:
        """Store file content"""
        pass

    @abstractmethod
    def list_files(self, prefix: str) -> List[str]:
        """List files with given prefix"""
        pass

    @abstractmethod
    def get_file_timestamp_from_path(self, file_path: str) -> int:
        """Extract timestamp from file path (implementation specific)"""
        pass


class JsonProcessorPort(ABC):
    """Port for JSON processing operations (pure logic)"""

    @abstractmethod
    def flatten_json(self, json_data: Dict[str, Any]) -> Dict[str, Any]:
        """Flatten nested JSON structure"""
        pass

    @abstractmethod
    def json_to_csv_row(
        self, flattened_data: Dict[str, Any], headers: List[str]
    ) -> List[str]:
        """Convert flattened JSON to CSV row"""
        pass

    @abstractmethod
    def escape_csv_value(self, value: Any) -> str:
        """Escape value for CSV format"""
        pass
