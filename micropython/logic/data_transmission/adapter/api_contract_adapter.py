"""
API Contract Adapter - Implementation of API contract validation

This module creates payloads that conform to the API specification.
"""

import time
from data_transmission.port.api_validation_port import ApiValidationPort  # type: ignore


class ApiContractAdapter(ApiValidationPort):
    """
    Implementation of API contract creation.

    This adapter ensures payloads are created according to the schema defined
    in the OpenAPI specification.
    """

    def validate_payload(self, payload: dict) -> dict:
        """
        Validate essential requirements for API compatibility

        Only checks critical requirements that would cause API failures.
        Full schema validation happens in unit tests.

        Args:
            payload: Dictionary containing the data to validate

        Returns:
            Dictionary: Validated payload

        Raises:
            ValueError: If payload is critically invalid
        """
        try:
            # Check payload is a dictionary
            if not isinstance(payload, dict):
                raise ValueError("Payload must be a dictionary")

            # Missing required fields
            required_fields = ["device_id", "timestamp", "measurements"]

            missing_fields = []
            for field in required_fields:
                if field not in payload:
                    missing_fields.append(field)

            if missing_fields:
                raise ValueError(
                    f"Missing required fields: {', '.join(missing_fields)}"
                )

            # Measurements must be an object
            try:
                measurements = payload.get("measurements", {})
                if not isinstance(measurements, dict):
                    raise ValueError("'measurements' must be a dictionary")
            except Exception as e:
                raise ValueError(f"Invalid measurements field: {e}")

            # Check that measurements fields are present
            missing_fields = []
            for field in ["temperature", "humidity", "voltage", "current"]:
                if field not in measurements:
                    missing_fields.append(field)

            if missing_fields:
                raise ValueError(
                    f"Missing required measurements: {', '.join(missing_fields)}"
                )

            return payload

        except ValueError:
            raise
        except Exception as e:
            raise ValueError(f"Validation error: {e}")

    def create_sensor_payload(self, data: dict) -> dict:
        """
        Create a properly formatted sensor reading payload

        Args:
            data: Dictionary containing sensor data with fields:
                - device_id: Unique identifier for the sensor device
                - timestamp: Optional Unix timestamp (will use current time if None)
                - temperature: Optional temperature reading in Celsius
                - humidity: Optional humidity reading (percentage)
                - voltage: Optional voltage readings as dictionary
                - current: Optional current reading in milliamps
                - metadata: Optional additional metadata

        Returns:
            Dictionary: Properly formatted sensor reading payload

        Raises:
            ValueError: If parameters are invalid
        """
        # Extract all parameters together for clarity
        device_id = data.get("device_id")
        timestamp = data.get("timestamp")
        temperature = data.get("temperature")
        humidity = data.get("humidity")
        voltage = data.get("voltage")
        current = data.get("current")
        metadata = data.get("metadata")

        try:
            # Validate required device_id
            if not device_id:
                raise ValueError("device_id is required")

            # Create measurements object
            measurements = {}

            # Process temperature with better error handling
            if temperature is not None:
                try:
                    measurements["temperature"] = float(temperature)
                except (TypeError, ValueError):
                    raise ValueError("temperature must be a number")

            # Process humidity with better error handling
            if humidity is not None:
                try:
                    measurements["humidity"] = float(humidity)
                except (TypeError, ValueError):
                    raise ValueError("humidity must be a number")

            # Process voltage (dictionary of readings)
            if voltage is not None:
                # Initialize the voltage object
                measurements["voltage"] = {}

                # Process each voltage source
                for source, value in voltage.items():
                    try:
                        measurements["voltage"][source] = float(value)
                    except (TypeError, ValueError):
                        raise ValueError(f"voltage[{source}] must be a numeric value")

            # Process current (can be single value or dictionary)
            if current is not None:
                if isinstance(current, dict):
                    # Process multiple current readings
                    validated_current = {}
                    for source, value in current.items():
                        try:
                            validated_current[source] = float(value)
                        except (TypeError, ValueError):
                            raise ValueError(
                                f"current[{source}] must be a numeric value"
                            )
                    measurements["current"] = validated_current
                else:
                    # Single current reading
                    try:
                        measurements["current"] = float(current)
                    except (TypeError, ValueError):
                        raise ValueError("current must be a numeric value")

            # Process timestamp with better error handling
            if timestamp is None:
                try:
                    timestamp = int(time.time())
                except Exception:
                    # Fallback for time.time() failure
                    print("Warning: using default timestamp")
                    timestamp = 0
            else:
                try:
                    timestamp = int(timestamp)
                except (TypeError, ValueError):
                    raise ValueError("timestamp must be an integer")

            # Create the payload structure
            payload = {
                "device_id": str(device_id),
                "timestamp": timestamp,
                "measurements": measurements,
                "units": {},
                "metadata": {},
            }

            # Add appropriate units based on measurements
            units = {}
            if "temperature" in measurements:
                units["temperature"] = "C"
            if "humidity" in measurements:
                units["humidity"] = "1/100"
            if "voltage" in measurements:
                units["voltage"] = "V"
            if "current" in measurements:
                units["current"] = "mA"
            if units:
                payload["units"] = units

            # Process metadata safely
            if metadata:
                if isinstance(metadata, dict):
                    payload["metadata"] = metadata
                else:
                    print("Warning: metadata ignored - must be a dictionary")

            # Final validation
            return self.validate_payload(payload)

        except ValueError as ve:
            # Re-raise validation errors
            raise ValueError(f"Payload validation error: {ve}")
        except Exception as e:
            # Convert unexpected errors
            raise ValueError(f"Error creating sensor payload: {str(e)}")
