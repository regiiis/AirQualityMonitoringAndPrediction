"""
Unit tests for API Contract Adapter functionality
"""

import json
import pytest
import yaml
import os
from pathlib import Path
from jsonschema import validate

from micropython.logic.data_transmission.adapter.api_contract_adapter import (
    ApiContractAdapter,
)  # type: ignore

# Get the root directory of the project
ROOT_DIR = Path(__file__).parent.parent.parent.parent


@pytest.fixture
def openapi_spec_dict():
    """Fixture to provide the OpenAPI specification as a dictionary"""
    api_spec_path = os.path.join(ROOT_DIR, "api-spec.yaml")
    with open(api_spec_path, "r") as f:
        api_spec_dict = yaml.safe_load(f)
    return api_spec_dict


@pytest.fixture
def mock_hyt221_data():
    """Mock data for HYT221 temperature and humidity sensor"""
    return {
        "measurements": {"temperature": 23.5, "humidity": 45.2},
        "units": {"temperature": "C", "humidity": "1/100"},
    }


@pytest.fixture
def mock_ina219_1_data():
    """Mock data for first INA219 voltage and current sensor"""
    return {
        "measurements": {
            "measurement": "battery",
            "voltage": 3.72,
            "current": 0.2,
            "power": 0.4,
        },
        "units": {"voltage": "V", "current": "mA", "power": "mW"},
    }


@pytest.fixture
def mock_ina219_2_data():
    """Mock data for second INA219 voltage and current sensor"""
    return {
        "measurements": {
            "measurement": "solar",
            "voltage": 4.8,
            "current": 0.1,
            "power": 0.5,
        },
        "units": {"voltage": "V", "current": "mA", "power": "mW"},
    }


@pytest.fixture
def mock_metadata():
    """Mock metadata"""
    return {
        "device_id": "esp32-001",
        "timestamp": 1679580000,
        "location": "living_room",
        "version": "v1.2.3",
    }


# First, add a fixture for the ApiContractAdapter
@pytest.fixture
def api_contract_adapter():
    """Fixture to provide an instance of ApiContractAdapter"""
    return ApiContractAdapter()


def test_create_sensor_payload_schema_validation(
    mock_hyt221_data,
    mock_ina219_1_data,
    mock_ina219_2_data,
    mock_metadata,
    openapi_spec_dict,
):
    """Test that created payload conforms to the API schema"""
    # Create a payload with the adapter
    adapter = ApiContractAdapter()

    payload = adapter.create_sensor_payload(
        hyt221=mock_hyt221_data,
        ina219_1=mock_ina219_1_data,
        ina219_2=mock_ina219_2_data,
        metadata=mock_metadata,
    )

    # Print the payload for debugging
    print("\nGenerated payload:")
    print(json.dumps(payload, indent=2))

    # Get the SensorReading schema directly from the dict
    sensor_schema = openapi_spec_dict["components"]["schemas"]["SensorReading"]

    # Validate using jsonschema directly
    validate(instance=payload, schema=sensor_schema)

    # Additional specific assertions
    assert payload["measurements"]["temperature"] == 23.5
    assert payload["measurements"]["humidity"] == 45.2
    assert payload["measurements"]["voltage"]["battery"] == 3.72
    assert payload["measurements"]["voltage"]["solar"] == 4.8
    assert payload["measurements"]["current"]["battery"] == 0.2
    assert payload["measurements"]["current"]["solar"] == 0.1
    assert payload["measurements"]["power"]["battery"] == 0.4
    assert payload["measurements"]["power"]["solar"] == 0.5
    assert payload["metadata"]["device_id"] == "esp32-001"
    assert payload["metadata"]["timestamp"] == 1679580000
    assert payload["metadata"]["location"] == "living_room"
    assert payload["metadata"]["version"] == "v1.2.3"


def test_validate_payload_with_invalid_data(
    api_contract_adapter,
    mock_hyt221_data,
    mock_ina219_1_data,
    mock_ina219_2_data,
    mock_metadata,
):
    """Test the validate_payload method with invalid data"""
    invalid_metadata = {
        "device_id": "esp32-001",
        "timestamp": "wrong_data_type",  # Invalid type
        "location": "living_room",
        "version": "v1.2.3",
    }

    with pytest.raises(ValueError):
        api_contract_adapter.create_sensor_payload(
            hyt221=mock_hyt221_data,
            ina219_1=mock_ina219_1_data,
            ina219_2=mock_ina219_2_data,
            metadata=invalid_metadata,
        )


def test_create_sensor_payload_with_missing_data(
    api_contract_adapter, mock_hyt221_data, mock_metadata
):
    """Test creating a payload with missing sensor data"""
    # Missing INA219 data
    with pytest.raises(ValueError):
        api_contract_adapter.create_sensor_payload(
            hyt221=mock_hyt221_data,
            ina219_1=None,
            ina219_2=None,
            metadata=mock_metadata,
        )
