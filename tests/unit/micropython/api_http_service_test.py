"""
Unit tests for ApiHttpService
"""

import pytest
from unittest.mock import MagicMock, patch

from micropython.logic.data_transmission.service.api_http_service import ApiHttpService

# Fix the import paths to match actual imports in api_http_service.py
HTTP_ADAPTER_PATH = (
    "micropython.logic.data_transmission.service.api_http_service.HttpAdapter"
)
CONTRACT_ADAPTER_PATH = (
    "micropython.logic.data_transmission.service.api_http_service.ApiContractAdapter"
)


@pytest.fixture
def test_data():
    """Test data for all tests"""
    return {
        "ina219_1": {"voltage": 3.3, "current": 0.5, "power": 1.65},
        "ina219_2": {"voltage": 5.0, "current": 0.2, "power": 1.0},
        "hyt221": {"temperature": 25.4, "humidity": 68.7},
        "metadata": {"device_id": "test-device-01", "timestamp": 1714239072},
    }


@patch(HTTP_ADAPTER_PATH)
@patch(CONTRACT_ADAPTER_PATH)
def test_api_http_service_initialization(
    mock_contract_adapter_class, mock_http_adapter_class
):
    """Test ApiHttpService initializes correctly"""
    # Execute
    service = ApiHttpService(
        name="TestService",
        endpoint="https://api.example.com/v1",
        api_key="test-api-key",
    )

    # Assert
    assert service.name == "TestService"
    assert service.endpoint.endswith("/readings")
    # Use called instead of assert_called_once() for more diagnostic information
    assert mock_http_adapter_class.called, "HttpAdapter was not called"
    assert mock_contract_adapter_class.called, "ApiContractAdapter was not called"


@patch(HTTP_ADAPTER_PATH)
@patch(CONTRACT_ADAPTER_PATH)
def test_api_http_service_send_data_success(
    mock_contract_adapter_class, mock_http_adapter_class, test_data
):
    """Test successful data sending"""
    # Setup mocks
    mock_http = MagicMock()
    mock_http.send_data.return_value = {
        "success": True,
        "status_code": 201,
        "data": {"id": "reading-123"},
    }
    mock_http_adapter_class.return_value = mock_http

    mock_contract = MagicMock()
    # Set return value for the method that's actually called
    mock_contract.create_sensor_payload.return_value = {"validated": "payload"}
    mock_contract_adapter_class.return_value = mock_contract

    # Create service
    service = ApiHttpService(
        name="TestService",
        endpoint="https://api.example.com/v1",
        api_key="test-api-key",
    )

    # Execute
    result = service.send_data(
        ina219_1=test_data["ina219_1"],
        ina219_2=test_data["ina219_2"],
        hyt221=test_data["hyt221"],
        metadata=test_data["metadata"],
    )

    # Assert the correct method was called
    assert mock_contract.create_sensor_payload.called, (
        "create_sensor_payload was not called"
    )
    assert mock_http.send_data.called, "send_data was not called"
    assert result["success"] is True
    assert result["status_code"] == 201
