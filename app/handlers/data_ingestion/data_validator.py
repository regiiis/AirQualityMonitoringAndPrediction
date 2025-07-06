# lambda/validator/validator.py
import json
import logging
from jsonschema import validate

# Set up logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def data_validator(body, data_schema_path: str):
    """
    Validate the incoming payload against the defined schema.

    Args:
        body (dict): The data to validate
        data_schema (dict): JSON schema to validate against (defaults to SENSOR_DATA_SCHEMA)

    Returns:
        dict: Result with validation status and data or error details
    """
    try:
        # Load the JSON payload from path
        SENSOR_DATA_SCHEMA = open(data_schema_path, "r")
        data_schema = json.load(SENSOR_DATA_SCHEMA)
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
