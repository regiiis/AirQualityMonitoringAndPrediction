"""
Data Ingestion Lambda Function.

This module provides the entry point for the Air Quality Monitoring system's data ingestion process.
It receives data from API Gateway, validates the payload against a schema, and stores valid data in S3.

Environment Variables:
    S3_BUCKET_NAME: Name of the S3 bucket where sensor data will be stored
"""

try:
    import data_validator  # type: ignore
except ImportError:
    from app.handlers.data_ingestion import data_validator  # type: ignore
try:
    import data_storer  # type: ignore
except ImportError:
    from app.handlers.data_ingestion import data_storer  # type: ignore

import json
import logging
import os

# Set up logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """
    Process incoming sensor data through validation and storage.

    This function serves as the Lambda entry point that:
    1. Parses and validates the incoming data against the sensor schema
    2. Stores validated data to the configured S3 bucket
    3. Returns appropriate HTTP responses for different scenarios

    Args:
        event (dict): Lambda event object containing the API Gateway request
            Expected to contain a 'body' key with JSON payload or be a direct JSON payload
        context (LambdaContext): AWS Lambda runtime context object providing
            metadata about the invocation, function, and execution environment

    Returns:
        dict: API Gateway proxy response with:
            statusCode (int): HTTP status code (201 success, 4xx/5xx errors)
            body (str): JSON string with response data or error details
            headers (dict): Response headers including Content-Type

    Raises:
        No exceptions are raised as all are caught and returned as error responses.
    """
    try:
        logger.info("Received event: %s", json.dumps(event))
        sensor_data_schema_path = "/data/sensor_data_schema.json"

        # Parse request body
        try:
            body = json.loads(event["body"]) if "body" in event else event
        except json.JSONDecodeError as e:
            return _format_response(400, {"error": "invalid_json", "message": str(e)})

        # Validate data
        validation = data_validator.data_validator(
            body, sensor_data_schema_path=sensor_data_schema_path
        )
        if not validation["valid"]:
            return _format_response(
                400, {"error": validation["error"], "message": validation["message"]}
            )

        # Get S3 bucket name from environment variable
        bucket_name = os.environ.get("SENSOR_DATA_STORAGE_S3")
        if not bucket_name:
            return _format_response(
                500, {"error": "config_error", "message": "S3 configuration error"}
            )

        # Store data
        storage_result = data_storer.store_data(validation["data"], bucket_name)
        if not storage_result["success"]:
            return _format_response(
                502, {"error": "storage_error", "message": storage_result["message"]}
            )

        return _format_response(
            201,
            {
                "id": context.aws_request_id,
                "success": True,
                "filename": storage_result["filename"],
            },
        )

    except Exception as e:
        logger.error("Unhandled error: %s", str(e))
        return _format_response(
            500, {"error": "server_error", "message": "Internal server error"}
        )


def _format_response(status_code, body):
    """
    Format a response for API Gateway.

    Args:
        status_code (int): HTTP status code
        body (dict): Response body as a dictionary

    Returns:
        dict: Formatted response for API Gateway
    """
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }
