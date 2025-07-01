import logging
from typing import Dict, Any, List

from ports.json_processor_port import JsonProcessorPort

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
        Flatten nested JSON into CSV-compatible structure matching existing CSV columns.

        Specifically handles sensor data JSON structure:
        - metadata.* → direct column names (timestamp, device_id, location, version, http_client_reset)
        - measurements.temperature → temperature
        - measurements.humidity → humidity
        - measurements.power.Battery → battery_power
        - measurements.power.PV → pv_power
        - measurements.current.Battery → battery_current
        - measurements.current.PV → pv_current
        - measurements.voltage.Battery → battery_voltage
        - measurements.voltage.PV → pv_voltage

        Args:
            json_data: Nested JSON object to flatten

        Returns:
            Flattened dictionary with CSV column names
        """
        result = {}

        # Handle metadata fields - direct mapping
        if "metadata" in json_data:
            metadata = json_data["metadata"]
            result["timestamp"] = metadata.get("timestamp")
            result["device_id"] = metadata.get("device_id")
            result["location"] = metadata.get("location")
            result["version"] = metadata.get("version")
            result["http_client_reset"] = metadata.get("http_client_reset")

        # Handle measurements
        if "measurements" in json_data:
            measurements = json_data["measurements"]

            # Direct measurements
            result["temperature"] = measurements.get("temperature")
            result["humidity"] = measurements.get("humidity")

            # Power measurements
            if "power" in measurements:
                power = measurements["power"]
                result["battery_power"] = power.get("Battery", 0.0)
                result["pv_power"] = power.get("PV", 0.0)
            else:
                result["battery_power"] = 0.0
                result["pv_power"] = 0.0

            # Current measurements
            if "current" in measurements:
                current = measurements["current"]
                result["battery_current"] = current.get("Battery", 0.0)
                result["pv_current"] = current.get("PV", 0.0)
            else:
                result["battery_current"] = 0.0
                result["pv_current"] = 0.0

            # Voltage measurements
            if "voltage" in measurements:
                voltage = measurements["voltage"]
                result["battery_voltage"] = voltage.get("Battery", 0.0)
                result["pv_voltage"] = voltage.get("PV", 0.0)
            else:
                result["battery_voltage"] = 0.0
                result["pv_voltage"] = 0.0

        return result

    def _flatten_recursive(
        self, json_data: Dict[str, Any], parent_key: str = "", separator: str = "_"
    ) -> Dict[str, Any]:
        """Standard recursive flattening logic."""
        items = []

        for key, value in json_data.items():
            new_key = f"{parent_key}{separator}{key}" if parent_key else key

            if isinstance(value, dict):
                # Recursively flatten nested dictionaries
                items.extend(self._flatten_recursive(value, new_key, separator).items())
            elif isinstance(value, list):
                # Handle lists by indexing elements
                for i, item in enumerate(value):
                    if isinstance(item, dict):
                        items.extend(
                            self._flatten_recursive(
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
