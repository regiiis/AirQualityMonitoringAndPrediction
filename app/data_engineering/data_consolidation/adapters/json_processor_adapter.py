import logging
from typing import Dict, Any, List

from ..ports.json_processor_port import JsonProcessorPort

logger = logging.getLogger(__name__)


class JsonProcessorAdapter(JsonProcessorPort):
    """
    JSON to CSV conversion adapter for nested sensor data.

    Flattens nested JSON objects into CSV-compatible flat structure.
    Handles arrays, nested objects, and proper CSV escaping.
    """

    def flatten_json(
        self, json_data: Dict[str, Any], parent_key: str = "", separator: str = "_"
    ) -> Dict[str, Any]:
        """
        Flatten nested JSON into single-level dictionary.

        Args:
            json_data: Nested JSON object to flatten
            parent_key: Current parent key for recursion (internal use)
            separator: Key separator for nested levels

        Returns:
            Flattened dictionary with concatenated keys

        Examples:
            {"a": {"b": 1}} → {"a_b": 1}
            {"a": [1, 2]} → {"a_0": 1, "a_1": 2}
        """
        items = []

        for key, value in json_data.items():
            new_key = f"{parent_key}{separator}{key}" if parent_key else key

            if isinstance(value, dict):
                # Recursively flatten nested dictionaries
                items.extend(self.flatten_json(value, new_key, separator).items())
            elif isinstance(value, list):
                # Handle lists by indexing elements
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

    def get_flattened_headers(self, flattened_data: Dict[str, Any]) -> List[str]:
        """
        Extract sorted headers from flattened data.

        Returns:
            Alphabetically sorted list of column headers
        """
        return sorted(flattened_data.keys())

    def json_to_csv_row(
        self, flattened_data: Dict[str, Any], headers: List[str]
    ) -> List[str]:
        """
        Convert flattened data to CSV row values.

        Args:
            flattened_data: Single-level dictionary with values
            headers: Ordered list of column headers

        Returns:
            List of CSV-escaped string values in header order
        """
        row_values = []

        for header in headers:
            value = flattened_data.get(header, "")
            escaped_value = self._escape_csv_value(value)
            row_values.append(escaped_value)

        return row_values

    def _escape_csv_value(self, value: Any) -> str:
        """
        Escape value for RFC 4180 CSV format.

        Args:
            value: Any value to escape

        Returns:
            CSV-safe string with proper quote escaping
        """
        if value is None:
            return ""

        str_value = str(value)

        # Wrap in quotes if contains special characters
        if (
            "," in str_value
            or '"' in str_value
            or "\n" in str_value
            or "\r" in str_value
        ):
            escaped_value = str_value.replace('"', '""')
            return f'"{escaped_value}"'

        return str_value
