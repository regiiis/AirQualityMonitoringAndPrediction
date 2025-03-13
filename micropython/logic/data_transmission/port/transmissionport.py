"""
Transmission Port definition - Abstract interface for data transmission

This module defines the interface (port) that data transmission implementations
must adhere to, following the Ports and Adapters pattern.
"""

try:
    from modules.mock_abc import ABC, abstractmethod  # type: ignore
except ImportError:
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
        pass

    @property
    @abstractmethod
    def endpoint(self) -> str:
        """Get the server endpoint URL. It should be the complete URL"""
        pass

    @abstractmethod
    def is_ready(self) -> bool:
        """
        Check if the transmission service is ready to send data

        Returns:
            bool: True if ready, False otherwise
        """
        pass

    @abstractmethod
    def test_connection(self) -> bool:
        """
        Test connectivity to the server

        Returns:
            bool: True if connection successful, False otherwise
        """
        pass

    @abstractmethod
    def send_data(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Send data to the server

        Args:
            payload: Dictionary containing the data to send

        Returns:
            Dict[str, Any]: Response information
        """
        pass
