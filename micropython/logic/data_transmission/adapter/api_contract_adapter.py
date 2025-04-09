"""
API Contract Adapter - Implementation of API contract validation

This module creates payloads that conform to the API specification.
"""

try:
    from typing import Dict, Any
except ImportError:
    pass

try:
    from micropython.logic.data_transmission.port.api_contract_port import (  # type: ignore
        ApiValidationPort,
    )
except ImportError:
    from micropython.logic.data_transmission.port.api_contract_port import (  # type: ignore
        ApiValidationPort,
    )


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

            # Check for required fields
            expected_fields = ["measurements", "units", "metadata"]
            available_fields = [data for data in expected_fields if data not in payload]

            if available_fields:
                raise ValueError(
                    "Missing required data: " + ", ".join(available_fields)
                )

            try:
                measurements = payload.get("measurements", {})
                if not isinstance(measurements, dict):
                    raise ValueError("'measurements' must be a dictionary")
            except Exception as e:
                raise ValueError(f"Invalid measurements field: {e}")

            # Check that measurements fields are present
            expected_fields = ["temperature", "humidity", "voltage", "current", "power"]
            available_fields = [
                field for field in expected_fields if field not in measurements
            ]
            if available_fields:
                raise ValueError(
                    "Missing required measurements fields: "
                    + ", ".join(available_fields)
                )

            try:
                metadata = payload.get("metadata", {})
                if not isinstance(metadata, dict):
                    raise ValueError("'metadata' must be a dictionary")
            except Exception as e:
                raise ValueError(f"Invalid metadata field: {e}")

            # Check that measurements fields are present
            expected_fields = ["device_id", "timestamp", "location", "version"]
            available_fields = [
                field for field in expected_fields if field not in metadata
            ]
            if available_fields:
                raise ValueError(
                    "Missing required measurements fields: "
                    + ", ".join(available_fields)
                )

            # Check that measurements fields are present
            expected_types = {
                "device_id": str,
                "timestamp": int,
                "location": str,
                "version": str,
            }
            wrong_types = []
            for field, expected_type in expected_types.items():
                if field in metadata:
                    if not isinstance(metadata[field], expected_type):
                        wrong_types.append(
                            f"{field} (expected {expected_type.__name__}, got {type(metadata[field]).__name__})"
                        )

            if wrong_types:
                raise ValueError(
                    "Metadata fields with incorrect types: " + ", ".join(wrong_types)
                )

            return payload
        except ValueError:
            raise
        except Exception as e:
            raise ValueError(f"Validation error: {e}")

    def create_sensor_payload(
        self,
        hyt221: dict,
        ina219_1: dict,
        ina219_2: dict,
        metadata: dict,
    ) -> dict:
        """
        Create a properly formatted sensor reading payload from HYT221 and INA219 sensor readings

        Args:
            hyt221: Dictionary containing HYT221 sensor data (temperature, humidity)
            ina219: Dictionary containing INA219 sensor data (voltage, current, power)
            device_id: Unique identifier for the sensor device
            timestamp: Optional Unix timestamp (will use current time if None)

        Returns:
            Dictionary: Properly formatted sensor reading payload

        Raises:
            ValueError: If parameters are invalid
        """
        try:
            # Create measurements object
            measurements: Dict[str, Any] = {}

            # Extract HYT221 data (temperature and humidity)
            if hyt221 and "measurements" in hyt221:
                hyt_measurements = hyt221.get("measurements", {})

                # Process temperature
                if "temperature" in hyt_measurements:
                    try:
                        measurements["temperature"] = float(
                            hyt_measurements["temperature"]
                        )
                    except (TypeError, ValueError):
                        raise ValueError("temperature must be a number")

                # Process humidity
                if "humidity" in hyt_measurements:
                    try:
                        measurements["humidity"] = float(hyt_measurements["humidity"])
                    except (TypeError, ValueError):
                        raise ValueError("humidity must be a number")

            # Extract INA219 data (measurement, voltage, current, power)
            if ina219_1 and "measurements" in ina219_1:
                ina_measurements = ina219_1.get("measurements", {})
                measurement_name = ina_measurements.get("measurement", "")
                if not measurement_name and "measurement" in ina_measurements:
                    raise ValueError(
                        "measurement name is missing in ina219_1 measurements"
                    )

                # Process voltage
                if "voltage" in ina_measurements:
                    try:
                        # Ensure we're working with a dictionary of the right type
                        if "voltage" not in measurements:
                            measurements["voltage"] = {}

                        # Now we can safely add the value
                        voltage_value = float(ina_measurements["voltage"])
                        measurements["voltage"][measurement_name] = voltage_value
                    except (TypeError, ValueError):
                        raise ValueError("voltage must be a number")

                # Process current
                if "current" in ina_measurements:
                    try:
                        # Ensure we're working with a dictionary of the right type
                        if "current" not in measurements:
                            measurements["current"] = {}

                        # Now we can safely add the value
                        current_value = float(ina_measurements["current"])
                        measurements["current"][measurement_name] = current_value
                    except (TypeError, ValueError):
                        raise ValueError("current must be a number")

                # Process power
                if "power" in ina_measurements:
                    try:
                        # Ensure we're working with a dictionary of the right type
                        if "power" not in measurements:
                            measurements["power"] = {}

                        power_value = float(ina_measurements["power"])
                        measurements["power"][measurement_name] = power_value
                    except (TypeError, ValueError):
                        raise ValueError("power must be a number")

            # Extract INA219 data from second sensor
            if ina219_2 and "measurements" in ina219_2:
                ina_measurements = ina219_2.get("measurements", {})
                measurement_name = ina_measurements.get("measurement", "")
                if not measurement_name and "measurement" in ina_measurements:
                    raise ValueError(
                        "measurement name is missing in ina219_2 measurements"
                    )

                # Process voltage for second sensor
                if "voltage" in ina_measurements:
                    try:
                        if "voltage" not in measurements:
                            measurements["voltage"] = {}

                        voltage_value = float(ina_measurements["voltage"])
                        measurements["voltage"][measurement_name] = voltage_value
                    except (TypeError, ValueError):
                        raise ValueError("voltage must be a number")

                # Process current for second sensor
                if "current" in ina_measurements:
                    try:
                        if "current" not in measurements:
                            measurements["current"] = {}

                        current_value = float(ina_measurements["current"])
                        measurements["current"][measurement_name] = current_value
                    except (TypeError, ValueError):
                        raise ValueError("current must be a number")

                # Process power for second sensor
                if "power" in ina_measurements:
                    try:
                        # Ensure we're working with a dictionary of the right type
                        if "power" not in measurements:
                            measurements["power"] = {}

                        # Now we can safely add the value
                        power_value = float(ina_measurements["power"])
                        measurements["power"][measurement_name] = power_value
                    except (TypeError, ValueError):
                        raise ValueError("power must be a number")

            # Validate metadata
            if "device_id" not in metadata:
                raise ValueError("Missing device_id in metadata.")

            if "timestamp" not in metadata:
                raise ValueError("Missing timestamp in metadata.")

            if "location" not in metadata:
                raise ValueError("Missing location in metadata.")

            if "version" not in metadata:
                raise ValueError("Missing version in metadata.")

            # Add units
            units = {}

            # Add units from HYT221
            if hyt221 and "units" in hyt221:
                units.update(hyt221.get("units", {}))

            # Add units from INA219
            if ina219_1 and "units" in ina219_1:
                units.update(ina219_1.get("units", {}))

            # Create the payload structure
            payload = {
                "measurements": measurements,
                "units": units,
                "metadata": metadata,
            }

            # Final validation
            return self.validate_payload(payload)

        except ValueError as ve:
            # Re-raise validation errors
            raise ValueError(f"Payload validation error: {ve}")
        except Exception as e:
            # Convert unexpected errors
            raise ValueError(f"Error creating sensor payload: {str(e)}")
