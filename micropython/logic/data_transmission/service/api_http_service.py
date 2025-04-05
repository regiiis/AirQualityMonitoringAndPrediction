"""
API-HTTP Service - HTTP implementation with API contract validation

This module provides a service that enforces the API contract when sending data.
"""

from typing import Dict, Any, Optional

from data_transmission.adapter.http_adapter import HttpAdapter  # type: ignore
from data_transmission.adapter.api_contract_adapter import ApiContractAdapter  # type: ignore


class ApiHttpService:
    """
    HTTP service with API contract validation.

    Uses HttpAdapter for HTTP operations and ApiContractAdapter for validation
    to ensure all data sent conforms to the API specification.
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
        Initialize the API HTTP service

        Args:
            name: Name for this transmission service
            endpoint: Full URL of API endpoint (without the path)
            api_key: Optional API key for X-API-Key authentication
            headers: Optional HTTP headers to include
            timeout: Request timeout in seconds
        """
        self._http_adapter = HttpAdapter(name, endpoint, api_key, headers, timeout)
        self._contract_adapter = ApiContractAdapter()
        self._name = name

    @property
    def name(self):
        return self._name

    def is_ready(self):
        """Check if the HTTP adapter is ready for transmission"""
        return self._http_adapter.is_ready()

    def test_connection(self):
        """Test server connection"""
        return self._http_adapter.test_connection()

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
            validated_payload = self._contract_adapter.validate_payload(payload)

            # Send the validated payload using the HTTP adapter
            return self._http_adapter.send_data(validated_payload)

        except ValueError as e:
            return {"success": False, "error": f"API contract validation error: {e}"}
