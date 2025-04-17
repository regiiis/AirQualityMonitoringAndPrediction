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


def store_data(data, bucket_name):
    """
    Store data to S3 bucket

    Args:
        data (dict): The data to store
        bucket_name (str): The S3 bucket name

    Returns:
        dict: Result with success status and filename or error message
    """
    try:
        # Create S3 client
        s3_client = boto3.client("s3")

        # Generate a unique filename
        filename = f"data/{uuid.uuid4()}.json"

        # Store the data in S3
        s3_client.put_object(
            Bucket=bucket_name,
            Key=filename,
            Body=json.dumps(data),
            ContentType="application/json",
        )

        logger.info(f"Successfully stored data to {bucket_name}/{filename}")
        return {"success": True, "filename": filename}
    except Exception as e:
        logger.error(f"Error storing data in S3: {str(e)}")
        return {"success": False, "message": str(e)}
