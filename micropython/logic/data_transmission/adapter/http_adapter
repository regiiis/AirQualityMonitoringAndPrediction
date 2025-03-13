"""
HTTP Adapter implementation for data transmission

This module provides a concrete adapter for sending data over HTTP/HTTPS.
"""

import urequests  # type: ignore
import ujson  # type: ignore
import time
from typing import Dict, Any, Optional

from data_transmission.port.transmissionport import TransmissionPort


class HttpAdapter(TransmissionPort):
    """
    HTTP/HTTPS adapter for data transmission.

    Implements the TransmissionPort interface using the urequests library.
    """

    def __init__(
        self,
        name: str,
        endpoint: str,
        api_key: Optional[str] = None,
        headers: Optional[Dict[str, str]] = None,
        timeout: int = 10
    ):
        """
        Initialize HTTP adapter with server details.

        Args:
            name: Name for this transmission service
            endpoint: Full URL of API endpoint
            api_key: Optional API key for authentication
            headers: Optional HTTP headers to include
            timeout: Request timeout in seconds
        """
        self._name = name
        self._endpoint = endpoint
        self._timeout = timeout

        # Initialize headers
        self._headers = headers or {}
        if "Content-Type" not in self._headers:
            self._headers["Content-Type"] = "application/json"

        # Add API key to headers if provided
        if api_key:
            self._headers["Authorization"] = f"Bearer {api_key}"

    @property
    def name(self) -> str:
        return self._name

    @property
    def endpoint(self) -> str:
        return self._endpoint

    def is_ready(self) -> bool:
        """Check if network is available"""
        try:
            import network  # type: ignore
            wlan = network.WLAN(network.STA_IF)
            return wlan.isconnected()
        except Exception:
            return False

    def test_connection(self) -> bool:
        """Test server connection with a HEAD request"""
        if not self.is_ready():
            return False

        try:
            response = urequests.head(
                self._endpoint,
                headers=self._headers,
                timeout=self._timeout
            )
            success = 200 <= response.status_code < 300
            response.close()
            return success
        except Exception as e:
            print(f"Connection test failed: {e}")
            return False

    def send_data(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Send data to server via HTTP POST

        Args:
            payload: Dictionary containing data to send

        Returns:
            Dict with status information
        """
        if not self.is_ready():
            return {
                "success": False,
                "error": "Network not connected"
            }

        try:
            # Add timestamp if not included
            if "timestamp" not in payload:
                payload["timestamp"] = time.time()

            # Convert payload to JSON
            json_data = ujson.dumps(payload)

            # Send POST request
            print(f"Sending data to {self._endpoint}...")
            response = urequests.post(
                self._endpoint,
                headers=self._headers,
                data=json_data,
                timeout=self._timeout
            )

            # Process response
            status_code = response.status_code
            success = 200 <= status_code < 300

            try:
                response_data = response.json()
            except ValueError:
                response_data = {"text": response.text}

            response.close()

            # Return result
            return {
                "success": success,
                "status_code": status_code,
                "data": response_data
            }

        except Exception as e:
            print(f"Error sending data: {e}")
            return {
                "success": False,
                "error": str(e)
            }
