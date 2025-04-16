# lambda/validator/validator.py
import json
import boto3
import logging
import os
from jsonschema import validate

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


def format_response(status_code, body):
    """Helper to format API response consistently"""
    return {
        "statusCode": status_code,
        "body": json.dumps(body),
        "headers": {"Content-Type": "application/json"},
    }


def data_validator(body, data_schema=SENSOR_DATA_SCHEMA):
    """
    Validate the incoming payload against the defined schema.
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


def handler(event, context):
    """Process and validate incoming API data, then forward to storage"""
    try:
        logger.info("Received event: %s", json.dumps(event))

        # Get storage lambda name from environment variable
        storage_lambda = os.environ.get("SENSOR_DATA_STORAGE_S3")
        if not storage_lambda:
            logger.error("Missing SENSOR_DATA_STORAGE_S3 environment variable")
            return format_response(
                500, {"error": "config_error", "message": "Lambda configuration error"}
            )

        # Parse request body
        try:
            body = json.loads(event["body"])
        except json.JSONDecodeError as e:
            return format_response(400, {"error": "invalid_json", "message": str(e)})

        # Validate data
        validation = data_validator(body)
        if not validation["valid"]:
            logger.error("Validation failed: %s", validation["error"])
            return format_response(
                400, {"error": validation["error"], "message": validation["message"]}
            )

        # Call storage Lambda
        lambda_client = boto3.client("lambda")
        try:
            response = lambda_client.invoke(
                FunctionName=storage_lambda,
                InvocationType="RequestResponse",
                Payload=json.dumps(body),
            )
        except Exception as e:
            logger.error("Error invoking storage lambda: %s", str(e))
            return format_response(502, {"error": "storage_error", "message": str(e)})

        # Check storage response
        payload = json.loads(response["Payload"].read().decode())
        if payload.get("statusCode") != 200:  # Check the actual Lambda response
            logger.error("Storage lambda error: %s", response["StatusCode"])
            return format_response(
                502, {"error": "storage_error", "message": "Failed to store data"}
            )

        logger.info("Data stored successfully")
        return format_response(201, {"id": context.aws_request_id, "success": True})

    except Exception as e:
        logger.error("Unhandled error: %s", str(e))
        return format_response(
            500, {"error": "server_error", "message": "Internal server error"}
        )
