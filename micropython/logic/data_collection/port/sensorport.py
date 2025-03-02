"""
Sensor Port definition - Abstract interface for all sensors

This module defines the interfaces (ports) that sensor implementations
must adhere to, following the Ports and Adapters pattern.
"""

try:
    from modules.mock_abc import ABC, abstractmethod  # type: ignore
except ImportError:
    from abc import ABC, abstractmethod  # type: ignore

from typing import Dict, Any


class SensorPort(ABC):
    """
    Base abstract interface that all sensors must implement.

    This is the "port" in the ports and adapters pattern that defines
    the contract between the application and sensor implementations.
    """

    @property
    @abstractmethod
    def name(self) -> str:
        """Get the sensor name"""
        pass

    @property
    @abstractmethod
    def protocol(self) -> str:
        """
        Get the communication protocol type

        Returns:
            str: "i2c", "uart", "spi", etc.
        """
        pass

    @abstractmethod
    def read(self) -> Dict[str, Any]:
        """
        Read data from the sensor

        Returns:
            Dict[str, Any]: Key-value pairs of measurement names and their values
        """
        pass

    @abstractmethod
    def is_ready(self) -> bool:
        """
        Check if the sensor is available and ready to provide readings

        Returns:
            bool: True if sensor is ready, False otherwise
        """
        pass

    def print(self) -> None:
        """
        Print sensor readings to console (default implementation)
        """
        try:
            readings = self.read()
            print(f"--- {self.name} Readings ---")
            for key, value in readings.items():
                if isinstance(value, float):
                    print(f"{key}: {value:.2f}")
                else:
                    print(f"{key}: {value}")
        except Exception as e:
            print(f"Error reading {self.name} sensor: {e}")


class I2CSensorPort(SensorPort):
    """
    Interface for I2C-based sensors
    """

    @property
    def protocol(self) -> str:
        """Get the communication protocol type"""
        return "i2c"

    @property
    @abstractmethod
    def i2c_address(self) -> int:
        """Get the I2C address"""
        pass

    @property
    @abstractmethod
    def scl(self) -> int:
        """Get the SCL pin number"""
        pass

    @property
    @abstractmethod
    def sda(self) -> int:
        """Get the SDA pin number"""
        pass


class UARTSensorPort(SensorPort):
    """
    Interface for UART-based sensors
    """

    @property
    def protocol(self) -> str:
        """Get the communication protocol type"""
        return "uart"

    @property
    @abstractmethod
    def rx(self) -> int:
        """Get the RX pin number"""
        pass

    @property
    @abstractmethod
    def tx(self) -> int:
        """Get the TX pin number"""
        pass

    @property
    @abstractmethod
    def baud_rate(self) -> int:
        """Get the baud rate for UART communication"""
        pass
