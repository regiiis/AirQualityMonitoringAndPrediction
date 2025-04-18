from app.handlers.data_ingestion import data_validator
from app.handlers.data_ingestion import data_storer
import json
import logging
import os

# Set up logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """
    Data ingestion handler function to validate incoming data and store it in S3.
    """
    try:
        logger.info("Received event: %s", json.dumps(event))

        # Parse request body
        try:
            body = json.loads(event["body"]) if "body" in event else event
        except json.JSONDecodeError as e:
            return data_validator.format_response(
                400, {"error": "invalid_json", "message": str(e)}
            )

        # Validate data
        validation = data_validator.data_validator(body)
        if not validation["valid"]:
            return data_validator.format_response(
                400, {"error": validation["error"], "message": validation["message"]}
            )

        # Get S3 bucket name from environment variable
        bucket_name = os.environ.get("S3_BUCKET_NAME")
        if not bucket_name:
            return data_validator.format_response(
                500, {"error": "config_error", "message": "S3 configuration error"}
            )

        # Store data
        storage_result = data_storer.store_data(validation["data"], bucket_name)
        if not storage_result["success"]:
            return data_validator.format_response(
                502, {"error": "storage_error", "message": storage_result["message"]}
            )

        return data_validator.format_response(
            201,
            {
                "id": context.aws_request_id,
                "success": True,
                "filename": storage_result["filename"],
            },
        )

    except Exception as e:
        logger.error("Unhandled error: %s", str(e))
        return data_validator.format_response(
            500, {"error": "server_error", "message": "Internal server error"}
        )
