# lambda/validator/validator.py
import json
import logging
from jsonschema import validate  # type: ignore

# Set up logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

SENSOR_DATA_SCHEMA = {
    "type": "object",
    "required": ["measurements", "units", "metadata"],
    "properties": {
        "measurements": {
            "type": "object",
            "required": ["temperature", "humidity", "voltage", "current", "power"],
            "properties": {
                "temperature": {"type": "number"},
                "humidity": {"type": "number"},
                "voltage": {
                    "type": "object",
                    "properties": {
                        "battery": {"type": "number"},
                        "solar": {"type": "number"},
                    },
                },
                "current": {
                    "type": "object",
                    "properties": {
                        "battery": {"type": "number"},
                        "solar": {"type": "number"},
                    },
                },
                "power": {
                    "type": "object",
                    "properties": {
                        "battery": {"type": "number"},
                        "solar": {"type": "number"},
                    },
                },
            },
        },
        "units": {"type": "object"},
        "metadata": {
            "type": "object",
            "required": ["device_id", "timestamp", "location", "version"],
            "properties": {
                "device_id": {"type": "string"},
                "timestamp": {"type": "number"},
                "location": {"type": "string"},
                "version": {"type": "string"},
            },
        },
    },
}


def data_validator(body, data_schema=SENSOR_DATA_SCHEMA):
    """
    Validate the incoming payload against the defined schema.

    Args:
        body (dict): The data to validate
        data_schema (dict): JSON schema to validate against (defaults to SENSOR_DATA_SCHEMA)

    Returns:
        dict: Result with validation status and data or error details
    """
    try:
        # Validate the payload against the schema
        validate(instance=body, schema=data_schema)
        return {"valid": True, "data": body}

    except json.JSONDecodeError as e:
        logger.error("JSON parsing error: %s", str(e))
        return {"valid": False, "error": "invalid_json", "message": str(e)}

    except ValueError as e:
        logger.error("Schema validation error: %s", str(e))
        return {"valid": False, "error": "schema_validation", "message": str(e)}

    except Exception as e:
        logger.error("Unexpected validation error: %s", str(e))
        return {"valid": False, "error": "validation_error", "message": str(e)}
