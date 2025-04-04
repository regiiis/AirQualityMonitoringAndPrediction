"""
Transmission Port definition - Abstract interface for data transmission

This module defines the interface (port) that data transmission implementations
must adhere to, following the Ports and Adapters pattern.
"""

try:
    # Use mock abc module when running on ESP32
    from modules.mock_abc import ABC, abstractmethod  # type: ignore
except ImportError:
    # Use real abc module when running on CI/CD pipeline
    from abc import ABC, abstractmethod  # type: ignore

from typing import Dict, Any


class TransmissionPort(ABC):
    """
    Base abstract interface that all data transmission services must implement.

    This is the "port" in the ports and adapters pattern that defines
    the contract between the application and transmission implementations.
    """

    @property
    @abstractmethod
    def name(self) -> str:
        """Get the transmission service name"""
        raise NotImplementedError("Abstract method")

    @property
    @abstractmethod
    def endpoint(self) -> str:
        """Get the server endpoint URL. It should be the complete URL"""
        raise NotImplementedError("Abstract method")

    @abstractmethod
    def is_ready(self) -> bool:
        """
        Check if the transmission service is ready to send data

        Returns:
            bool: True if ready, False otherwise
        """
        raise NotImplementedError("Abstract method")

    @abstractmethod
    def test_connection(self) -> bool:
        """
        Test connectivity to the server

        Returns:
            bool: True if connection successful, False otherwise
        """
        raise NotImplementedError("Abstract method")

    @abstractmethod
    def send_data(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Send data to the server

        Args:
            payload: Dictionary containing the data to send

        Returns:
            Dict[str, Any]: Response information
        """
        raise NotImplementedError("Abstract method")
