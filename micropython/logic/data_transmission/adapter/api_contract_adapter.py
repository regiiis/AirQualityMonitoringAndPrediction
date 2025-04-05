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

            # Check for required fields
            expected_fields = [
                "device_id",
                "timestamp",
                "measurements",
                "units",
                "metadata",
            ]
            available_fields = [data for data in expected_fields if data not in payload]

            if available_fields:
                raise ValueError(
                    "Missing required data: " + ", ".join(available_fields)
                )

            # Measurements must be an object
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
        device_id: str = None,
        timestamp: int = None,
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
            # Validate required device_id
            if not device_id:
                raise ValueError("device_id is required")

            # Create measurements object
            measurements = {}

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
            if ina219_1 and "measurements" in ina219_2:
                ina_measurements = ina219_2.get("measurements", {})
                measurement_name = ina_measurements.get("measurement:", "")
                if not measurement_name and "measurement" in ina_measurements:
                    measurement_name = ina_measurements.get("measurement")

                # Use a default name if none is provided
                if not measurement_name:
                    raise ValueError("measurement name is required")

                # Process voltage - create as a dictionary with the measurement name as the key
                if "voltage" in ina_measurements:
                    voltage_dict = {}
                    try:
                        voltage_dict[measurement_name] = float(
                            ina_measurements["voltage"]
                        )
                        measurements["voltage"] = voltage_dict
                    except (TypeError, ValueError):
                        raise ValueError("voltage must be a number")

                # Process current - create as a dictionary with the measurement name as the key
                if "current" in ina_measurements:
                    current_dict = {}
                    try:
                        current_dict[measurement_name] = float(
                            ina_measurements["current"]
                        )
                        measurements["current"] = current_dict
                    except (TypeError, ValueError):
                        raise ValueError("current must be a number")

                # Process power
                if "power" in ina_measurements:
                    try:
                        measurements["power"] = float(ina_measurements["power"])
                    except (TypeError, ValueError):
                        raise ValueError("power must be a number")

            # Extract INA219 data (measurement, voltage, current, power)
            if ina219_2 and "measurements" in ina219_2:
                ina_measurements = ina219_2.get("measurements", {})
                measurement_name = ina_measurements.get("measurement:", "")
                if not measurement_name and "measurement" in ina_measurements:
                    measurement_name = ina_measurements.get("measurement")

                # Use a default name if none is provided
                if not measurement_name:
                    raise ValueError("measurement name is required")

                # Process voltage - create as a dictionary with the measurement name as the key
                if "voltage" in ina_measurements:
                    voltage_dict = {}
                    try:
                        voltage_dict[measurement_name] = float(
                            ina_measurements["voltage"]
                        )
                        measurements["voltage"] = voltage_dict
                    except (TypeError, ValueError):
                        raise ValueError("voltage must be a number")

                # Process current - create as a dictionary with the measurement name as the key
                if "current" in ina_measurements:
                    current_dict = {}
                    try:
                        current_dict[measurement_name] = float(
                            ina_measurements["current"]
                        )
                        measurements["current"] = current_dict
                    except (TypeError, ValueError):
                        raise ValueError("current must be a number")

                # Process power
                if "power" in ina_measurements:
                    try:
                        measurements["power"] = float(ina_measurements["power"])
                    except (TypeError, ValueError):
                        raise ValueError("power must be a number")

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

            # Add units from HYT221
            if hyt221 and "units" in hyt221:
                units.update(hyt221.get("units", {}))

            # Add units from INA219
            if ina219_1 and "units" in ina219_1:
                units.update(ina219_1.get("units", {}))

            payload["units"] = units

            # Final validation
            return self.validate_payload(payload)

        except ValueError as ve:
            # Re-raise validation errors
            raise ValueError(f"Payload validation error: {ve}")
        except Exception as e:
            # Convert unexpected errors
            raise ValueError(f"Error creating sensor payload: {str(e)}")
