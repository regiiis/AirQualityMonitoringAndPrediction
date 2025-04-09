# lambda/validator/validator.py
import json
import boto3
import logging
import os
from jsonschema import validate

# Set up logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Schema definition based on your API spec
SENSOR_READING_SCHEMA = {
    "type": "object",
    "required": ["measurements", "units", "metadata"],
    "properties": {
        "measurements": {
            "type": "object",
            "required": ["temperature", "humidity", "voltage", "current", "power"],
            # Additional schema details from your API spec
        },
        "units": {"type": "object"},
        "metadata": {
            "type": "object",
            "required": ["device_id", "timestamp", "location", "version"],
            "properties": {
                "device_id": {"type": "string"},
                "timestamp": {"type": "integer"},
                "location": {"type": "string"},
                "version": {"type": "string"},
            },
        },
    },
}


def handler(event, context):
    try:
        logger.info("Received event: %s", json.dumps(event))

        # Parse request body
        body = json.loads(event["body"])

        # Validate against schema
        validate(instance=body, schema=SENSOR_READING_SCHEMA)

        # If validation passes, forward to storage function
        lambda_client = boto3.client("lambda")
        storage_function_name = os.environ["STORAGE_FUNCTION_NAME"]

        # Invoke storage lambda
        response = lambda_client.invoke(
            FunctionName=storage_function_name,
            InvocationType="RequestResponse",
            Payload=json.dumps(body),
        )

        if response:
            pass

        # Return success response
        return {
            "statusCode": 201,
            "body": json.dumps({"id": context.aws_request_id, "success": True}),
            "headers": {"Content-Type": "application/json"},
        }

    except Exception as e:
        logger.error("Error: %s", str(e))

        # Return error response
        return {
            "statusCode": 400,
            "body": json.dumps(
                {
                    "error": "validation_error",
                    "message": "Invalid request payload",
                    "details": {"error": str(e)},
                }
            ),
            "headers": {"Content-Type": "application/json"},
        }
