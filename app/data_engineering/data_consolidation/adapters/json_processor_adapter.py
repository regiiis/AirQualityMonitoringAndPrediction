import logging
from typing import Dict, Any, List

from ..ports.json_processor_port import JsonProcessorPort

logger = logging.getLogger(__name__)


class JsonProcessorAdapter(JsonProcessorPort):
    """
    Concrete implementation of JSON processing operations.
    Pure business logic without external dependencies.
    """

    def flatten_json(
        self, json_data: Dict[str, Any], parent_key: str = "", separator: str = "_"
    ) -> Dict[str, Any]:
        """
        Flatten nested JSON structure into a single-level dictionary.

        Example:
            Input:  {"a": {"b": 1, "c": 2}, "d": 3}
            Output: {"a_b": 1, "a_c": 2, "d": 3}
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

    def json_to_csv_row(
        self, flattened_data: Dict[str, Any], headers: List[str]
    ) -> List[str]:
        """
        Convert flattened JSON data to CSV row values.

        Args:
            flattened_data: {"metadata_timestamp": 12345, "measurements_temperature": 27.32}
            headers: ["metadata_timestamp", "measurements_temperature", "measurements_humidity"]

        Returns:
            ["12345", "27.32", ""] # Empty string for missing values
        """
        row_values = []

        for header in headers:
            value = flattened_data.get(header, "")
            escaped_value = self.escape_csv_value(value)
            row_values.append(escaped_value)

        return row_values

    def escape_csv_value(self, value: Any) -> str:
        """
        Escape a value for safe CSV format.

        Rules:
        - Convert to string
        - If contains comma, quote, or newline -> wrap in quotes
        - Escape internal quotes by doubling them
        """
        if value is None:
            return ""

        # Convert to string
        str_value = str(value)

        # Check if escaping is needed
        if (
            "," in str_value
            or '"' in str_value
            or "\n" in str_value
            or "\r" in str_value
        ):
            # Escape internal quotes by doubling them
            escaped_value = str_value.replace('"', '""')
            return f'"{escaped_value}"'

        return str_value


class AdvancedJsonProcessorAdapter(JsonProcessorPort):
    """
    Advanced JSON processor with additional features like type preservation and custom formatting.
    """

    def __init__(self, preserve_types: bool = False, null_value: str = ""):
        self.preserve_types = preserve_types
        self.null_value = null_value

    def flatten_json(
        self, json_data: Dict[str, Any], parent_key: str = "", separator: str = "_"
    ) -> Dict[str, Any]:
        """Enhanced flattening with type preservation option"""
        items = []

        for key, value in json_data.items():
            new_key = f"{parent_key}{separator}{key}" if parent_key else key

            if isinstance(value, dict):
                items.extend(self.flatten_json(value, new_key, separator).items())
            elif isinstance(value, list):
                # Enhanced list handling
                if not value:  # Empty list
                    items.append((new_key, "[]" if self.preserve_types else ""))
                else:
                    for i, item in enumerate(value):
                        if isinstance(item, dict):
                            items.extend(
                                self.flatten_json(
                                    item, f"{new_key}{separator}{i}", separator
                                ).items()
                            )
                        else:
                            items.append((f"{new_key}{separator}{i}", item))
            elif value is None:
                items.append((new_key, self.null_value))
            else:
                items.append((new_key, value))

        return dict(items)

    def json_to_csv_row(
        self, flattened_data: Dict[str, Any], headers: List[str]
    ) -> List[str]:
        """Enhanced CSV row generation with type handling"""
        row_values = []

        for header in headers:
            value = flattened_data.get(header, self.null_value)

            # Type-specific formatting
            if self.preserve_types:
                if isinstance(value, bool):
                    value = str(value).lower()  # true/false instead of True/False
                elif isinstance(value, (int, float)):
                    value = str(value)
                elif value is None:
                    value = self.null_value

            escaped_value = self.escape_csv_value(value)
            row_values.append(escaped_value)

        return row_values

    def escape_csv_value(self, value: Any) -> str:
        """Enhanced CSV escaping with better type handling"""
        if value is None:
            return self.null_value

        # Handle different types
        if isinstance(value, bool):
            str_value = str(value).lower() if self.preserve_types else str(value)
        elif isinstance(value, (int, float)):
            str_value = str(value)
        else:
            str_value = str(value)

        # Enhanced escaping rules
        needs_quoting = any(char in str_value for char in [",", '"', "\n", "\r", "\t"])

        if needs_quoting:
            # Escape quotes and wrap in quotes
            escaped_value = str_value.replace('"', '""')
            return f'"{escaped_value}"'

        return str_value
