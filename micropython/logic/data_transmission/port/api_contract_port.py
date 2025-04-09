"""
API Validation Port - Abstract interface for API schema validation

This module defines the interface (port) that API validation implementations
must adhere to, following the Ports and Adapters (Hexagonal) architecture pattern.

The port ensures that all validation adapters implement consistent methods for
validating payloads against the API specification and creating properly formatted
data structures.
"""

try:
    # Use mock abc module when running on ESP32
    from modules.mock_abc import ABC, abstractmethod  # type: ignore
except ImportError:
    # Use real abc module when running on CI/CD pipeline
    from abc import ABC, abstractmethod  # type: ignore


class ApiValidationPort(ABC):
    """
    Base abstract interface that all API validation services must implement.

    This is the "port" in the ports and adapters pattern that defines
    the contract between the application and API contract validation implementations.
    It ensures consistent validation and payload creation across different
    validation strategies.
    """

    @abstractmethod
    def validate_payload(self, payload: dict) -> dict:
        """
        Validate a payload against API schema definition

        Expected payload structure:
        {
            "measurements": {
                "temperature": float,
                "humidity": float,
                "voltage": {
                    "battery": float,
                    "solar": float
                },
                "current": {
                    "battery": float,
                    "solar": float
                },
                "power": {
                    "battery": float,
                    "solar": float
                }
            },
            "units": {
                "temperature": str,
                "humidity": str,
                "voltage": str,
                "current": str,
                "power": str
            },
            "metadata": {
                "device_id": str,
                "timestamp": int,
                "location": str,
                "version": str
            }
        }

        Args:
            payload: Dictionary containing the data to validate

        Returns:
            Dictionary: Validated payload

        Raises:
            ValueError: If payload doesn't match the schema requirements
        """

        raise NotImplementedError("Abstract method")

    @abstractmethod
    def create_sensor_payload(
        self,
        ina219_1: dict,
        ina219_2: dict,
        hyt221: dict,
        metadata: dict,
    ) -> dict:
        """
        Create a properly formatted sensor reading payload

        Args:
            data: Dictionary containing sensor data to format

        Returns:
            Dictionary: Properly formatted sensor reading payload

        Raises:
            ValueError: If parameters are invalid or can't create a valid payload
        """

        raise NotImplementedError("Abstract method")
