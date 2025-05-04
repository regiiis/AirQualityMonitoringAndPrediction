"""
API-HTTP Service - HTTP implementation with API contract validation

This module provides a service that enforces the API contract when sending data.
"""

# Mulit env lib import
try:
    from typing import Dict, Any, Optional
except ImportError:
    pass
try:
    from data_transmission.adapter.http_adapter import HttpAdapter  # type: ignore
except ImportError:
    from micropython.logic.data_transmission.adapter.http_adapter import HttpAdapter  # type: ignore
try:
    from data_transmission.adapter.api_contract_adapter import ApiContractAdapter  # type: ignore
except ImportError:
    from micropython.logic.data_transmission.adapter.api_contract_adapter import (
        ApiContractAdapter,
    )  # type: ignore


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
            api_key: API key for X-API-Key header authentication as specified in the OpenAPI spec
            headers: Additional HTTP headers to include
            timeout: Request timeout in seconds
        """
        self._http_adapter = HttpAdapter(name, endpoint, api_key, headers, timeout)
        self._contract_adapter = ApiContractAdapter()
        self._name = name
        self._readings_endpoint = f"{endpoint.rstrip('/')}"

    @property
    def name(self):
        return self._name

    @property
    def endpoint(self):
        """Get the endpoint being used for API communication"""
        return self._readings_endpoint

    def is_ready(self):
        """Check if the HTTP adapter is ready for transmission"""
        return self._http_adapter.is_ready()

    def test_connection(self):
        """Test server connection to the readings endpoint"""
        return self._http_adapter.test_connection()

    def send_data(
        self,
        hyt221: dict,
        ina219_1: dict,
        ina219_2: dict,
        metadata: dict,
    ) -> Dict[str, Any]:
        """
        Validate and send data to server via HTTP POST

        Validates the payload against the SensorReading schema defined in the API spec
        and sends it to the /readings endpoint as specified in the API paths.

        Args:
            payload: Dictionary containing sensor data that must conform to the SensorReading schema

        Returns:
            Dict with status information including success and any response data
        """
        try:
            # Validate the payload against the API contract
            validated_payload = self._contract_adapter.create_sensor_payload(
                hyt221=hyt221, ina219_1=ina219_1, ina219_2=ina219_2, metadata=metadata
            )

            # Send the validated payload using the HTTP adapter
            return self._http_adapter.send_data(validated_payload)

        except ValueError as e:
            return {"success": False, "error": f"API contract validation error: {e}"}
