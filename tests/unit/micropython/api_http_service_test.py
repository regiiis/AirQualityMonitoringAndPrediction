"""
Unit tests for ApiHttpService
"""

import pytest
from unittest.mock import MagicMock, patch

from micropython.logic.data_transmission.service.api_http_service import (
    ApiHttpService,
)  # type: ignore


@pytest.fixture
def mock_http_adapter():
    """Create a mock HTTP adapter"""
    adapter = MagicMock()
    adapter.send_data.return_value = {"success": True, "status_code": 201}
    adapter.is_ready.return_value = True
    adapter.test_connection.return_value = True
    return adapter


@pytest.fixture
def mock_contract_adapter():
    """Create a mock contract adapter"""
    adapter = MagicMock()
    adapter.validate_payload.return_value = {"valid": "payload"}
    return adapter


@patch("micropython.logic.data_transmission.adapter.http_adapter.HttpAdapter")
@patch(
    "micropython.logic.data_transmission.adapter.api_contract_adapter.ApiContractAdapter"
)
def test_api_http_service_initialization(
    mock_contract_adapter_class, mock_http_adapter_class
):
    """Test ApiHttpService initializes correctly"""
    # Setup
    mock_http_adapter_class.return_value = MagicMock()
    mock_contract_adapter_class.return_value = MagicMock()

    # Execute
    service = ApiHttpService(
        name="TestService",
        endpoint="https://api.example.com/v1",
        api_key="test-api-key",
    )

    # Assert
    assert service.name == "TestService"
    assert "readings" in service.endpoint
    mock_http_adapter_class.assert_called_once()
    mock_contract_adapter_class.assert_called_once()


@patch("micropython.logic.data_transmission.adapter.http_adapter.HttpAdapter")
@patch(
    "micropython.logic.data_transmission.adapter.api_contract_adapter.ApiContractAdapter"
)
def test_api_http_service_send_data_success(
    mock_contract_adapter_class, mock_http_adapter_class
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
    mock_contract.validate_payload.return_value = {"validated": "payload"}
    mock_contract_adapter_class.return_value = mock_contract

    service = ApiHttpService(
        name="TestService",
        endpoint="https://api.example.com/v1",
        api_key="test-api-key",
    )

    # Execute
    test_payload = {"test": "data"}
    result = service.send_data(test_payload)

    # Assert
    mock_contract.validate_payload.assert_called_once_with(test_payload)
    mock_http.send_data.assert_called_once_with({"validated": "payload"})
    assert result["success"] is True
    assert result["status_code"] == 201


@patch("micropython.logic.data_transmission.adapter.http_adapter.HttpAdapter")
@patch(
    "micropython.logic.data_transmission.adapter.api_contract_adapter.ApiContractAdapter"
)
def test_api_http_service_validation_error(
    mock_contract_adapter_class, mock_http_adapter_class
):
    """Test handling of validation error"""
    # Setup mocks
    mock_http = MagicMock()
    mock_http_adapter_class.return_value = mock_http

    mock_contract = MagicMock()
    mock_contract.validate_payload.side_effect = ValueError("Invalid payload")
    mock_contract_adapter_class.return_value = mock_contract

    service = ApiHttpService(
        name="TestService",
        endpoint="https://api.example.com/v1",
        api_key="test-api-key",
    )

    # Execute
    test_payload = {"invalid": "data"}
    result = service.send_data(test_payload)

    # Assert
    mock_contract.validate_payload.assert_called_once_with(test_payload)
    mock_http.send_data.assert_not_called()
    assert result["success"] is False
    assert "API contract validation error" in result["error"]
