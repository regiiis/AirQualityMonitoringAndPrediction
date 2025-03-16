"""
Sensor Port definition - Abstract interface for all sensors

This module defines the interfaces (ports) that sensor implementations
must adhere to, following the Ports and Adapters (Hexagonal) architecture pattern.

The interfaces provide a clear contract between the application core logic
and the various sensor implementations, enabling clean separation of concerns
and facilitating testing and maintenance.
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
    All concrete sensor adapters must implement this interface to be
        usable within the application.
    """

    @property
    @abstractmethod
    def sensor(self) -> str:
        """
        Get the sensor type identifier.

                Returns:
                    str: The sensor type (e.g., "hyt221", "ina219")
        """
        raise NotImplementedError("Abstract method")

    @property
    @abstractmethod
    def measurement(self) -> str:
        """
        Get the measurement description.

                Returns:
                    str: Description of what's being measured (e.g., "Humidity & Temperature")
        """
        raise NotImplementedError("Abstract method")

    @property
    @abstractmethod
    def protocol(self) -> str:
        """
        Get the communication protocol type used by the sensor.

        Returns:
            str: Communication protocol identifier ("i2c", "uart", "spi", etc.)
        """
        raise NotImplementedError("Abstract method")

    @abstractmethod
    def read(self) -> Dict[str, Dict[str, Any]]:
        """
           Read data from the sensor.

                Implementations should handle all communication with the sensor hardware,
                data conversion, and error handling within this method.

                Returns:
                    Dict[str, Any]: Key-value pairs containing:
                        - Measurement names and their values
        - Units information
                        - Error details if the reading fails
        """
        raise NotImplementedError("Abstract method")

    @abstractmethod
    def is_ready(self) -> bool:
        """
        Check if the sensor is available and ready to provide readings.

        Implementations should verify the physical presence and operational
        status of the sensor hardware.

        Returns:
            bool: True if sensor is present and ready, False otherwise
        """
        raise NotImplementedError("Abstract method")

    def print(self) -> None:
        """
        Print sensor readings to console (default implementation).

        This is a concrete method that uses the abstract read() method
        to format and display sensor readings. Displays units first,
        followed by measurement values.

        Expected dictionary structure from read():
            {
                "measurements": {"key1": value1, "key2": value2, ...},
                "units": {"key1": "unit1", "key2": "unit2", ...}
            }
        """
        try:
            readings = self.read()
            print(f"--- {self.sensor} - {self.measurement} ---")

            # Print units first if available
            if "units" in readings:
                print(f"units: {readings['units']}")

            # Then print measurement values
            if "measurements" in readings:
                for key, value in readings["measurements"].items():
                    if isinstance(value, float):
                        print(f"{key}: {value:.2f}")
                    else:
                        print(f"{key}: {value}")

            # Handle any error messages
            if "error" in readings:
                print(f"error: {readings['error']}")

        except Exception as e:
            print(f"Error reading {self.sensor} sensor: {e}")


class I2CSensorPort(SensorPort):
    """
    Interface for I2C-based sensors.

    Extends the base SensorPort with I2C-specific properties and
    provides a default implementation for the protocol property.
    Concrete I2C sensor adapters should implement this interface.
    """

    @property
    def protocol(self) -> str:
        """
        Get the communication protocol type.

                Returns:
                    str: "i2c" - indicates this sensor uses I2C protocol
        """
        return "i2c"

    @property
    @abstractmethod
    def i2c_address(self) -> int:
        """
        Get the I2C address of the sensor.

                Returns:
                    int: I2C address in hexadecimal (e.g., 0x28, 0x40)
        """
        raise NotImplementedError("Abstract method")

    @property
    @abstractmethod
    def scl(self) -> int:
        """
        Get the SCL pin number for I2C clock line.

                Returns:
                    int: GPIO pin number for I2C clock line
        """
        raise NotImplementedError("Abstract method")

    @property
    @abstractmethod
    def sda(self) -> int:
        """
        Get the SDA pin number for I2C data line.

                Returns:
                    int: GPIO pin number for I2C data line
        """
        raise NotImplementedError("Abstract method")


class UARTSensorPort(SensorPort):
    """
    Interface for UART-based sensors.

    Extends the base SensorPort with UART-specific properties and
    provides a default implementation for the protocol property.
    Concrete UART sensor adapters should implement this interface.
    """

    @property
    def protocol(self) -> str:
        """
        Get the communication protocol type.

                Returns:
                    str: "uart" - indicates this sensor uses UART protocol
        """
        return "uart"

    @property
    @abstractmethod
    def rx(self) -> int:
        """
        Get the RX pin number for receiving data.

                Returns:
                    int: GPIO pin number for UART receive line
        """
        raise NotImplementedError("Abstract method")

    @property
    @abstractmethod
    def tx(self) -> int:
        """
        Get the TX pin number for transmitting data.

                Returns:
                    int: GPIO pin number for UART transmit line
        """
        raise NotImplementedError("Abstract method")

    @property
    @abstractmethod
    def baud_rate(self) -> int:
        """
        Get the baud rate for UART communication.

                Returns:
                    int: Communication speed in bits per second (e.g., 9600, 115200)
        """
        raise NotImplementedError("Abstract method")
