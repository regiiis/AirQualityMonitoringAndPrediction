from abc import ABC, abstractmethod
from typing import Dict, Any, List


class JsonProcessorPort(ABC):
    """
    Port for JSON processing operations.
    """

    @abstractmethod
    def flatten_json(
        self, json_data: Dict[str, Any], parent_key: str = "", separator: str = "_"
    ) -> Dict[str, Any]:
        """
        Flatten nested JSON structure into a single-level dictionary.

        Args:
            json_data: The nested JSON data
            parent_key: Parent key for nested items
            separator: Separator for nested keys

        Returns:
            dict: Flattened dictionary
        """
        pass

    @abstractmethod
    def get_flattened_headers(self, flattened_data: Dict[str, Any]) -> List[str]:
        """
        Extract headers from flattened JSON data.

        Args:
            flattened_data: Flattened JSON data dictionary

        Returns:
            list: List of headers (keys) in the flattened data
        """
        pass

    @abstractmethod
    def json_to_csv_row(
        self, flattened_data: Dict[str, Any], headers: List[str]
    ) -> List[str]:
        """
        Convert flattened JSON data to CSV row values.

        Args:
            flattened_data: Flattened JSON data dictionary
            headers: List of CSV column headers in order

        Returns:
            list: List of string values for CSV row
        """
        pass

    @abstractmethod
    def _escape_csv_value(self, value: Any) -> str:
        """
        Escape a value for safe CSV format.

        Args:
            value: Raw value to escape

        Returns:
            str: CSV-safe escaped string
        """
        pass
