"""
Adapter implementation for HYT221 humidity/temperature sensor

This module provides an adapter for the HYT221 humidity and temperature sensor
that implements the I2CSensorPort interface, allowing it to be used within
the application's port-adapter architecture.
"""

from machine import Pin, SoftI2C  # type: ignore
import time
from data_collection.port.sensorport import I2CSensorPort  # type: ignore


class HYT221Adapter(I2CSensorPort):
    """
    Adapter for the HYT221 humidity and temperature sensor.

    This adapter provides a standardized interface to the HYT221 sensor
    following the ports and adapters pattern. It handles I2C communication
    and data conversion.
    """

    def __init__(self, sensor, measurement, i2c_address, scl, sda):
        """
        Initialize the HYT221 sensor adapter.

        Args:
            sensor: Identifier for the sensor type (e.g., "hyt221")
            measurement: Description of what's being measured (e.g., "Humidity & Temperature")
            i2c_address: The I2C address of the sensor (default is 0x28)
            scl: The pin number for the I2C clock line
            sda: The pin number for the I2C data line
        """
        self._sensor = sensor
        self._measurement = measurement
        self._i2c_address = i2c_address
        self._scl = scl
        self._sda = sda

    @property
    def sensor(self) -> str:
        """
        Get the sensor type identifier.

        Returns:
            str: The sensor type (e.g., "hyt221")
        """
        return self._sensor

    @property
    def measurement(self) -> str:
        """
        Get the measurement description.

        Returns:
            str: Description of what's being measured
        """
        return self._measurement

    @property
    def i2c_address(self) -> int:
        """
        Get the I2C address of the sensor.

        Returns:
            int: I2C address in hexadecimal (e.g., 0x28)
        """
        return self._i2c_address

    @property
    def scl(self) -> int:
        """
        Get the SCL pin number.

        Returns:
            int: GPIO pin number for I2C clock line
        """
        return self._scl

    @property
    def sda(self) -> int:
        """
        Get the SDA pin number.

        Returns:
            int: GPIO pin number for I2C data line
        """
        return self._sda

    def is_ready(self) -> bool:
        """
        Check if the sensor is available on the I2C bus.

        Returns:
            bool: True if sensor responds, False otherwise
        """
        try:
            i2c = SoftI2C(scl=Pin(self._scl), sda=Pin(self._sda))
            devices = i2c.scan()
            return self._i2c_address in devices
        except Exception:
            return False

    def read(self):
        """
        Read humidity and temperature from the HYT221 sensor.

        Returns:
            dict: Dictionary containing:
                - humidity: Relative humidity percentage (0-100%)
                - temperature: Temperature in degrees Celsius
                - units: Dictionary mapping values to their units
                - error: Error message if reading failed
        """
        try:
            self._i2c = SoftI2C(scl=Pin(self._scl), sda=Pin(self._sda))

            # Trigger a measurement
            self._i2c.writeto(self._i2c_address, b"\x00")
            time.sleep(0.1)  # Wait for the measurement to complete

            # Read 4 bytes of data
            data = self._i2c.readfrom(self._i2c_address, 4)

            # Parse the data
            humidity = ((data[0] & 0x3F) << 8) | data[1]
            temperature = (data[2] << 6) | (data[3] >> 2)

            # Convert to human-readable values
            humidity = humidity * 100 / 16383.0
            temperature = temperature * 165 / 16383.0 - 40

            return {
                "measurements": {"humidity": humidity, "temperature": temperature},
                "units": {"humidity": "1/100", "temperature": "C"},
            }
        except Exception as e:
            print(f"Error reading HYT221 sensor: {e}")
            return {"error": str(e)}
