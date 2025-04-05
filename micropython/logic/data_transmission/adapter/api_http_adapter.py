"""
API-HTTP Adapter - HTTP implementation with API contract validation

This module provides an HTTP adapter that enforces the API contract.
"""

from typing import Dict, Any, Optional
import urequests  # type: ignore
import ujson  # type: ignore
import time

from data_transmission.adapter.http_adapter import HttpAdapter  # type: ignore
from data_transmission.adapter.api_contract_adapter import ApiContractAdapter  # type: ignore


class ApiHttpAdapter(HttpAdapter):
    """
    HTTP adapter with API contract validation.

    Extends the HttpAdapter to ensure all data sent conforms to the
    API specification.
    """

    def __init__(
        self,
        name: str,
        endpoint: str,
        api_key: Optional[str] = None,
        headers: Optional[Dict[str, str]] = None,
        timeout: int = 10,
    ):
        """
        Initialize the API HTTP adapter

        Args:
            name: Name for this transmission service
            endpoint: Full URL of API endpoint (without the path)
            api_key: Optional API key for X-API-Key authentication
            headers: Optional HTTP headers to include
            timeout: Request timeout in seconds
        """
        super().__init__(name, endpoint, api_key, headers, timeout)
        self._contract = ApiContractAdapter()

    def send_data(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Validate and send data to server via HTTP POST

        Args:
            payload: Dictionary containing data to send

        Returns:
            Dict with status information
        """
        try:
            # Validate the payload against the API contract
            validated_payload = self._contract.validate_payload(payload)

            # Send API POST
            return self._send_api_post(validated_payload)

        except ValueError as e:
            return {"success": False, "error": f"API contract validation error: {e}"}

    def _send_api_post(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Send data to the API endpoint via HTTP POST with robust error handling

        Args:
            payload: Validated payload ready to be sent

        Returns:
            Dict with status information and response data
        """

        if not self.is_ready():
            return {"success": False, "error": "Network not connected"}

        try:
            # Prepare request
            print(f"Sending API data to {self._endpoint}...")
            json_data = ujson.dumps(payload)

            # Execute the POST request
            response = urequests.post(
                self._endpoint,
                headers=self._headers,
                data=json_data,
                timeout=self._timeout,
            )

            # Process response
            status_code = response.status_code
            success = 200 <= status_code < 300

            try:
                response_data = response.json()
            except ValueError:
                response_data = {"text": response.text}
            finally:
                response.close()

            # Return detailed result
            return {
                "success": success,
                "status_code": status_code,
                "data": response_data,
                "timestamp": time.time(),
            }

        except OSError as e:
            # Network or connection error
            return {
                "success": False,
                "error": f"Network error: {e}",
                "retry_suggested": True,
            }
        except MemoryError:
            # Memory allocation error (common on constrained devices)
            return {
                "success": False,
                "error": "Device memory error",
                "retry_suggested": False,
            }
        except Exception as e:
            # Generic error handler
            return {"success": False, "error": f"API POST error: {str(e)}"}
