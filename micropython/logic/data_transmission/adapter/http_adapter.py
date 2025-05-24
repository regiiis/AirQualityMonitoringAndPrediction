"""
HTTP Adapter implementation for data transmission

This module provides an adapter for sending data over HTTP/HTTPS.
"""

# Mulit env lib import
try:
    import urequests as request  # type: ignore
except ImportError:
    pass

try:
    import ujson as json  # type: ignore
except ImportError:
    import json

try:
    import network  # type: ignore
except ImportError:
    # Mock network module for non-MicroPython environments
    class WLAN:
        def __init__(self, interface=None):
            pass

        def isconnected(self):
            return False

    class NetworkModule:
        STA_IF = 0
        AP_IF = 1
        WLAN = WLAN

    network = NetworkModule()

try:
    from data_transmission.port.transmissionport import TransmissionPort  # type: ignore
except ImportError:
    from micropython.logic.data_transmission.port.transmissionport import (
        TransmissionPort,
    )  # type: ignore


class HttpAdapter(TransmissionPort):
    """
    HTTP/HTTPS adapter for data transmission.

    Implements the TransmissionPort interface using the urequests library.
    """

    def __init__(
        self,
        name: str,
        endpoint: str,
        api_key: str,
        headers: dict,
        timeout: int = 10,
    ):
        """
        Initialize HTTP adapter with server details.

        Args:
            name: Name for this transmission service
            endpoint: Full URL of API endpoint (without the path)
            api_key: Optional API key for authentication (X-API-Key header)
            headers: Optional HTTP headers to include
            timeout: Request timeout in seconds
        """
        self._name = name

        # Ensure endpoint doesn't end with a slash
        self._endpoint = endpoint.rstrip("/")
        self._readings_endpoint = self._endpoint
        self._timeout = timeout

        # Initialize headers
        self._headers = headers or {}
        if "Content-Type" not in self._headers:
            self._headers["Content-Type"] = "application/json"

        # Add API key to X-API-Key header if provided (ApiKeyAuth scheme)
        if api_key:
            self._headers["X-API-Key"] = api_key

    @property
    def name(self):
        return self._name

    @property
    def endpoint(self):
        return self._endpoint

    def is_ready(self):
        """Check if network is available"""
        try:
            wlan = network.WLAN(network.STA_IF)
            return wlan.isconnected()
        except Exception:
            return False

    def test_connection(self):
        """Test server connection with a HEAD request to the readings endpoint"""
        if not self.is_ready():
            return False

        try:
            # Test connection to the readings endpoint specifically
            response = request.head(
                self._readings_endpoint, headers=self._headers, timeout=self._timeout
            )
            success = 200 <= response.status_code < 300
            response.close()
            return success
        except Exception as e:
            print(f"Connection test failed: {e}")
            return False

    def send_data(self, payload) -> dict:
        """
        Send data to server via HTTP POST

        Args:
            payload: Dictionary containing data to send

        Returns:
            Dict with status information
        """
        if not self.is_ready():
            return {"success": False, "error": "Network not connected"}

        try:
            # Convert payload to JSON
            json_data = json.dumps(payload)

            # Print debug information
            print(f"Request Headers: {self._headers}")
            print(f"Payload Preview: {str(json_data)[:100]}...")

            # Send POST request to the readings endpoint
            print(f"Sending data to {self._readings_endpoint}")
            response = request.post(
                self._readings_endpoint,
                headers=self._headers,
                data=json_data,
                timeout=self._timeout,
            )

            return response

        except Exception as e:
            print(f"Error sending data: {e}")
            return {"success": False, "error": str(e)}

    def validate_response(self, response) -> dict:
        """
        Validate the response from the server.
        Args:
            response: The HTTP response object
        Returns:
            A dictionary with success status, status code, and response data
        """
        try:
            # Process response
            status_code = response.status_code
            success = 200 <= status_code < 300

            # Get response body
            try:
                response_data = response.json()
            except ValueError:
                # If not JSON, get the text content
                try:
                    response_text = response.text
                    response_data = {"text": response_text}
                    # If we got a 400 error, this is the error message
                    if status_code == 400 and response_text:
                        response_data["error"] = response_text
                except Exception:
                    response_data = {"error": "Could not read response body"}

            response.close()

            # Return result with better error info
            result = {
                "success": success,
                "status_code": status_code,
                "data": response_data,
            }

            # Add error info for non-success responses
            if not success:
                # Try to extract the error message in different ways
                error_msg = (
                    response_data.get("error")
                    or response_data.get("message")
                    or response_data.get("text")
                )
                if not error_msg and isinstance(response_data, dict):
                    error_msg = str(response_data)
                result["error"] = error_msg or f"HTTP Error {status_code}"

            return result

        except Exception as e:
            print(f"Error processing response: {e}")
            return {"success": False, "error": str(e)}
