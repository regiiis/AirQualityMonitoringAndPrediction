"""
API-HTTP Adapter - HTTP implementation with API contract validation

This module provides an HTTP adapter that enforces the API contract.
"""

from typing import Dict, Any, Optional

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
        """Initialize the API HTTP adapter"""
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

            # Send the validated payload
            return super().send_data(validated_payload)

        except ValueError as e:
            return {"success": False, "error": f"API contract validation error: {e}"}
