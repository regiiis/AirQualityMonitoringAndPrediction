import os
import json
import logging
import boto3
import uuid

# Set up logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def format_response(status_code, body):
    """Helper to format API response consistently"""
    return {
        "statusCode": status_code,
        "body": json.dumps(body),
        "headers": {"Content-Type": "application/json"},
    }


def handler(event, context):
    """
    Main handler function to store the incoming data to S3.
    """
    body = json.loads(event) if isinstance(event, str) else event

    try:
        # Get S3 bucket name from environment variable
        bucket_name = os.environ.get("SENSOR_DATA_STORAGE_S3")
        if not bucket_name:
            logger.error("Missing SENSOR_DATA_STORAGE_S3 environment variable")
            return format_response(
                500, {"error": "config_error", "message": "S3 configuration error"}
            )

        # Create S3 client
        s3_client = boto3.client("s3")

        # Generate a unique filename for the data
        filename = f"data/{uuid.uuid4()}.json"

        try:
            # Store the data in S3
            s3_client.put_object(
                Bucket=bucket_name,
                Key=filename,
                Body=json.dumps(body),
                ContentType="application/json",
            )
        except Exception as e:
            logger.error("Error storing data in S3: %s", str(e))
            return format_response(502, {"error": "storage_error", "message": str(e)})

        logger.info("Data stored successfully in S3: %s", filename)

        return format_response(
            200, {"message": "Data stored successfully", "filename": filename}
        )

    except Exception as e:
        logger.error("Error storing data in S3: %s", str(e))
        return format_response(502, {"error": "storage_error", "message": str(e)})
